# M3 Detailed Design — macOS and sync

Status: Agreed (2026-11-18); implementation not started.
Parent docs: [high-level-design.md](../high-level-design.md) · [engineering-guidelines.md](../engineering-guidelines.md) · [m1-design.md](m1-design.md) · [m2-design.md](m2-design.md)

M3 brings Filbert to the Mac and lets one person's devices share their projects through their own Google Drive. It also adds Google Photos import on the Mac. It is built in three phases, each ending with a usable app: **macOS** (offline, no network), then **sync**, then **Google Photos**.

**Exit criteria** (HLD §11): create a project on the Mac, continue on the phone, and see changes on both; conflicts are resolved through the prompt; nothing is lost when both devices edit offline.

---

## 1. Scope

**In scope**

- macOS app: the M1 and M2 features, a desktop layout adapted from the phone's, keyboard shortcuts, file-picker and drag-and-drop import, Export to a file.
- Google Sign-In, asked for only when the user turns on sync or first uses Google Photos on the Mac; Sync settings.
- The sync engine (`packages/sync_engine`) over Drive `appDataFolder`: push, pull through the Changes API, blobs before records, tombstones, conflict detection, duplicate default names.
- Conflict prompt (per record, newest preselected) and a badge for pending conflicts.
- Background sync on Android (WorkManager), if a token can be had without the app open (§6.6).
- Google Photos import through the Photos Picker API, on macOS only (§9).

**Out of scope (later milestones)**

project backup, export and import (M8, §8) · iOS and web (M9, M10) · macOS distribution channel (§2, proposal 7) · sharing to other apps (M6) · notebook, final image (M7) · merge projects · other sync backends · a cellular-data setting for downloads (§6.5).

---

## 2. Decisions

### Chosen by Brian (2026-11-18)

| Topic | Decision |
|---|---|
| Milestone shape | **One M3 in three phases**: macOS first (no network), then sign-in and sync, then conflicts and Google Photos (Mac). |
| Mac layout | **Same screens as the phone, adapted**: wider grids, the aid panel docked beside the photo on wide windows, hover tooltips, keyboard shortcuts, a resizable window with a minimum size. No master-detail. |
| Mac export | Export… offers **Save to file…** (a standard save dialog) instead of Save to gallery; Save as new image is unchanged. |
| Google Photos | **macOS only** (2026-11-18): Android's system photo picker, which Filbert already uses, shows Google Photos and downloads picked cloud photos itself, so the API would only duplicate it there (§9). |
| Project backup | **Export and import**: a `.zip` per project that Filbert can import back, always as a new copy (§8). **Moved to a new M8** (2026-11-18), between the notebook (M7) and iOS (now M9); web is now M10. |

### Proposed and approved by Brian (2026-11-18)

| # | Topic | Proposal | Why |
|---|---|---|---|
| 1 | Drive layout | **Flat**: every file at the root of `appDataFolder`, named by kind and id (`project-<uuid>.json`, `blob-<uuid>.jpg`, …), with `appProperties` `{kind, id}` (§6.2). Resolves HLD §12. | Two offline devices each creating a `projects/` folder would make two folders with the same name; flat files need no folder ids and the Changes API lists files without paths anyway. |
| 2 | Original downloads | **Eager**: after each pull, originals download in the background, thumbnails first; a photo opened before its original arrives downloads it first (§6.5). Resolves HLD §12. | At the easel the phone may be offline; lazy downloads would leave photos missing exactly then. Projects hold tens of photos, not thousands. |
| 3 | Change tracking | **No dirty flags in repositories.** `sync_state` keeps the hash of each record's JSON as last synced; a record is changed locally when its current JSON hashes differently (§6.3). | Nothing in M1/M2's write paths changes, and a write can't forget to mark itself dirty. Hashing a few hundred small records per sync is cheap. |
| 4 | View prefs in sync | Synced, but **newest wins without a prompt**; two live rows for one project (made on two devices offline) keep the newer and tombstone the other (§6.4). Settles m2-design §4.1. | Grid and opacity settings aren't worth interrupting the painter for. |
| 5 | Device name | Filled from the device (`device_info_plus`: model on Android, computer name on Mac), editable in Settings. Settles m1-design §4.1. | Conflict choices need a recognizable label without asking the user up front. |
| 6 | Android export of a backup (M8) | Through the **share sheet** (`share_plus`), so the user picks Files, Drive or another app; Mac uses a save dialog. Import uses a file picker on both. | Android's file pickers can't save a large file without holding it in memory; the share sheet hands over the file. `share_plus` is in the HLD for M6 anyway. |
| 7 | macOS distribution | **Defer** to the first public release (HLD §12 said M3). M3 builds a **sandboxed** app, which keeps both the Mac App Store and a notarized DMG open. | No one but Brian runs the Mac app in M3; the sandbox is what the App Store requires and works for a DMG too. |
| 8 | CI for macOS | A **macOS build job** (`flutter build macos --debug`) on PRs; the macOS integration test runs locally. | Proves the Mac app compiles. macOS runners use 10× the minutes on a private repo, so they only build. |

### Deviations from the high-level design

1. **Flat Drive layout** instead of folders (HLD §6.2 showed folders as "logical"; proposal 1). (HLD §6.2 and §12 updated.)
2. **No dirty flag** (HLD §4 said local bookkeeping holds a dirty flag): change is detected by hash (proposal 3). (HLD §4 updated.)
3. **macOS distribution decision moves** past M3 (proposal 7). (HLD §12 updated.)
4. **Project backup moves to a new M8**, with Import project added to Export project (HLD §6.3 had export only, in M3). iOS and web become M9 and M10. (HLD §6.3, §7, §11, §12 updated.)

---

## 3. macOS app (phase 1)

### 3.1 Platform setup

- `flutter create --platforms=macos .` adds `macos/`. Minimum macOS: Flutter 3.50's minimum, unless a plugin needs more.
- **App Sandbox** on, with entitlements: outgoing network (phase 2), user-selected files read/write (import, export), keychain sharing (Google Sign-In, phase 2).
- OpenCV: dartcv4's build hooks build OpenCV for macOS (arm64 and x86_64); canvas detection and export are already tested on the Mac host by `flutter test`. T1 confirms the app build and checks the eval on the Mac app as on Android.
- Files: the same `FileStore` layout under the app container (`path_provider`).
- **No camera** on the Mac: the Take photo actions are hidden. Add photos and the reference slot open a file picker for images (`image_picker` on macOS, which uses `file_selector`).

### 3.2 Desktop layout

The same routes and screens as the phone. Width breakpoints follow Material's window size classes:

| Width | Changes |
|---|---|
| < 600 dp | As the phone |
| 600–839 dp | Project list and photo grid get more columns (thumbnail target ≈ 180 dp) |
| ≥ 840 dp | Above, plus the photo screen docks the aid panel at the right (≈ 320 dp) instead of above the toolbar; the project setup form is capped at ≈ 640 dp wide and centered |

- Window: resizable, minimum 800 × 600; opens at 1200 × 800. (Not remembered between launches in M3, which would need a window-management package.)
- **Mouse on the photo screen**: the chrome shows when the pointer moves and hides after the same idle time as on the phone; it stays while the pointer is over the chrome or a panel is open. Zoom with the trackpad pinch, Ctrl/⌘ + scroll, or double-click; drag pans. Press and hold still shows the original (mouse button held without moving).
- Every icon button gets a tooltip naming the action and its shortcut.
- Menus, sheets and dialogs are the phone's; bottom sheets (Export…, add photos) become centered dialogs at ≥ 600 dp.

### 3.3 Keyboard shortcuts

| Where | Keys |
|---|---|
| Project list | ⌘N new project · Return opens the focused project |
| Project screen | ⌘O add photos · Delete deletes the selected photo (with the usual undo snackbar) · Esc back |
| Photo screen | ← / → previous / next photo · Esc closes a panel, else goes back · ⌘Z undo · ⇧⌘Z redo · ⌘E Export… · G grid · B gray · V values · C colors · O compare · Space (hold) shows the original · ⌘+ / ⌘− / ⌘0 zoom in / out / fit |
| Crop screen | Return applies · Esc cancels |
| Everywhere | ⌘, Settings · ⌘W closes the window, which quits the app (single window) |

Shortcuts are `Shortcuts`/`Actions` on each screen, so they also work on Android with a hardware keyboard. The photo screen's shortcuts are disabled while a text field has focus.

### 3.4 Drag and drop

- Dropping image files (JPEG, PNG, HEIC) on the **project screen** adds them as photos, the same as Add photos (including auto-crop on add, if on). Dropping onto the empty reference slot sets the first one as the reference.
- Dropping on the **project list** creates a new project with the first image as its reference and the rest as photos, then opens it.
- Other files are ignored; if nothing in the drop is an image, a snackbar says "Filbert can only add photos."
- Package `desktop_drop` (HLD §3.3).

### 3.5 Export on the Mac

- Export… (m2-design §3.5) shows **Save to file…** in place of Save to gallery: a save dialog (`file_selector`'s `getSaveLocation`) preset to the Pictures folder and the gallery file name rule; JPEG at the same size and quality. Snackbar "Saved." with **Show in Finder**.
- `GallerySaver` stays the Android path; `ExportDestination` chooses by platform.

---

## 4. Data model

Drift schema version **3**, with a migration and migration test. Only local tables are added; synced tables are unchanged.

### 4.1 `sync_state` (local only)

One row per synced record that has been pushed or pulled.

| Column | Type | Notes |
|---|---|---|
| `kind` | TEXT | `project` · `image` · `view_prefs` |
| `record_id` | TEXT | Primary key with `kind` |
| `drive_file_id` | TEXT | |
| `remote_version` | INTEGER | Drive's file `version` when last pushed or pulled |
| `synced_hash` | TEXT | Hash of the record JSON (§6.1) when last pushed or pulled |

### 4.2 `blob_sync` (local only)

| Column | Type | Notes |
|---|---|---|
| `blob_id` | TEXT | Primary key |
| `drive_file_id` | TEXT | Null until uploaded |
| `thumb_file_id` | TEXT | Null until uploaded |
| `state` | TEXT | `local` (not uploaded) · `synced` · `remoteOnly` (known, not downloaded) · `missing` (purged on Drive and not local) |

### 4.3 `sync_conflicts` (local only)

| Column | Type | Notes |
|---|---|---|
| `kind`, `record_id` | TEXT | Primary key |
| `remote_json` | TEXT | The remote version of the record |
| `remote_version` | INTEGER | |
| `detected_at` | INTEGER | |

While a conflict is pending the local record is what the app shows and edits; pushing that record is held until the conflict is resolved.

### 4.4 `app_meta` keys

`sync_enabled`, `sync_account` (email, for display only; tokens stay with the sign-in SDK), `changes_page_token`, `last_sync_at`, `device_name` (now filled, proposal 5).

---

## 5. Record format

One JSON form per record, used by sync (§6) and later by project backups (M8, §8), in `packages/sync_engine` (`RecordCodec`):

```json
{ "schemaVersion": 1, "kind": "image", "id": "0193…",
  "createdAt": 1763450000000, "updatedAt": 1763450000000,
  "updatedByDeviceId": "0193…", "deletedAt": null,
  "projectId": "0193…", "blobId": "0193…", "mimeType": "image/jpeg",
  "width": 4000, "height": 3000, "source": "camera", "capturedAt": 1763449000000,
  "edits": { … }, "derivedFrom": { … } }
```

- Field names are camelCase and stable; they are not Drift's generated `toJson` (HLD §6.3 suggested it), so renaming a Dart field can't change the format. `edits`, `derivedFrom` and view prefs embed their existing JSON (m1-design §4.2, m2-design §4.2–4.3) as objects.
- Readers ignore unknown fields. A record with a higher `schemaVersion` than the app knows is kept as-is in `sync_state` but not applied; Settings shows "Update Filbert to sync everything." A lower one is migrated on read.
- The hash (§6.3) is SHA-256 of the record's canonical JSON (keys sorted), with the same `stableHash` approach as M2's caches.

---

## 6. Sync

### 6.1 Structure

```
packages/sync_engine (pure Dart)          lib/features/sync (app)
  SyncEngine                                DriftLocalStore      implements LocalStore
  RecordCodec                               DriveRemoteStore     implements RemoteStore
  LocalStore, RemoteStore (interfaces)      SyncController       triggers, status, Riverpod
  FakeRemoteStore (tests)                   conflicts UI, settings
```

- `LocalStore`: read and write records and their sync state in one transaction, list blobs, open and save blob files.
- `RemoteStore`: list changes since a page token, read and write a record file, upload and download a blob and thumbnail, delete a file.
- The engine's tests (HLD §10) run several simulated devices against one `FakeRemoteStore`, which can drop or interrupt requests.

### 6.2 Drive layout (proposal 1)

```
appDataFolder/
  manifest.json                   { "schemaVersion": 1, "createdBy": "<app version>" }
  project-<uuid>.json
  image-<uuid>.json
  viewprefs-<uuid>.json
  blob-<blob-uuid>.<ext>          original (immutable)
  thumb-<blob-uuid>.jpg           the existing 512 px thumbnail
```

- Each file has `appProperties` `{kind, id}`, so a change can be identified without downloading it.
- Drive allows two files with one name. A retried create could make a duplicate; the engine looks up a record's file by name before creating it, and when it finds duplicates keeps the one with the highest `version` and deletes the rest.

### 6.3 One sync pass

1. **Pull**: list changes since `changes_page_token` (`spaces=appDataFolder`); download each changed record file. The first sync on a device lists every file instead.
2. **Reconcile** each pulled record, comparing local JSON hash with `synced_hash` (changed locally?) and Drive's `version` with `remote_version` (changed remotely?):

   | Local | Remote | Result |
   |---|---|---|
   | — (unknown) | new | insert |
   | unchanged | changed | overwrite local |
   | changed | unchanged | keep local; pushed in step 3 |
   | changed | changed | **conflict** (§6.4), unless the two JSONs are equal |

3. **Push**: every local record whose hash differs from `synced_hash` (or has no `sync_state`) and has no pending conflict. Upload its blob and thumbnail first if `blob_sync` says `local`, then the record. Just before updating a record file, re-read its `version`; if it moved, go back to step 2 for that record.
4. Save the new page token and `last_sync_at`.

- Records are applied in dependency order (projects, then images, then view prefs) in one Drift transaction per batch, so the UI's streams update once. An image whose project hasn't arrived yet waits for the next pass.
- Drive v3 has no conditional update (to verify in T8), so step 3's re-read leaves a small race between one person's devices; a lost race overwrites the other device's push, which is the accepted cost (it needs two devices pushing the same record within the same second).
- Turning sync on with projects already on the device merges them: everything local is pushed, everything remote is pulled. Nothing is deleted.

### 6.4 Conflicts

- **Projects and images**: both versions are kept (§4.3) and the user chooses (§7). Applies also to deleted-on-one-edited-on-the-other.
- **View prefs**: newer `updatedAt` wins, no prompt (proposal 4).
- **New images on both devices**: separate records, no conflict (HLD §4.2).
- **Duplicate default names** (HLD §6.6): after a pull, if two live projects both have `nameIsDefault` and the same name, the one created later is renumbered ("2026-11-12 (2)") by whichever device notices; the renumbering is an ordinary edit and syncs. Both devices compute the same answer (ties broken by id), so they don't fight.
- **Reference photo**: `referenceImageId` pointing at an image this device doesn't have yet is kept and resolves when the image arrives; pointing at a deleted image shows no reference (as now).

### 6.5 Blobs

- Originals and thumbnails are immutable, so they never conflict: upload once, download once.
- **Downloads** (proposal 2): after a pull, thumbnails of new images download first (so the grids fill in), then originals, newest project first. Previews are rendered locally from the original, as now. A photo opened, cropped or exported before its original arrives shows its thumbnail with a progress ring and downloads it next.
- Uploads use Drive's resumable upload, so an interrupted 15 MB original resumes instead of restarting.
- **Purge on Drive**: a device's purge job (m1-design §4.4) also deletes the Drive blob and thumbnail of images tombstoned for over **60 days** (local purge stays at 30, so a device can restore from Drive for a month after purging locally). A restored image whose blob is gone everywhere shows "This photo is no longer available" in place of the photo (`blob_sync.state = missing`). (Resolves m1-design §4.4's open restore case.)

### 6.6 When sync runs

- At launch and on resume; 5 s after the last local change (debounced); every 15 min while the app is open; **Sync now** in Settings.
- **Android background**: a WorkManager periodic task (every 6 h, on any network) running one sync pass in a background isolate with its own Drift connection. It needs an access token without UI; T11 checks that `google_sign_in` can give one there. If it can't, background sync is dropped from M3 (sync on open and resume still covers the exit criteria) and noted for later.
- Only one pass runs at a time; a trigger during a pass queues one more.
- Failures (offline, token expired, Drive quota) leave everything as it was; the status in Settings says what happened and the next trigger retries, backing off up to 15 min.

### 6.7 Sign-in (`AuthService`)

- `google_sign_in` 7.x: sign in (authentication), then ask for scopes when needed (authorization): `drive.appdata` when turning on sync; `photospicker.mediaitems.readonly` at first Google Photos import (macOS only, so Android only ever asks for Drive). API calls use the access token through `extension_google_sign_in_as_googleapis_auth` and `googleapis` (Drive v3).
- Tokens stay with the platform SDK (Credential Manager on Android, the keychain on macOS); Filbert stores only the account email for display.
- **Google Cloud project** (Brian sets up, §11): OAuth clients for Android (package name + SHA-1 of the debug and release keys), macOS, and a web client id that Android needs as `serverClientId`. The consent screen stays in *testing* mode with Brian as a test user during M3; T7 records the scopes' classification (sensitive or not) and what verification public release needs (HLD §6.7).
- **Sign out** (Settings): stops sync and forgets the account; local data stays. Signing in with a different account later treats it as a new remote (all local records are pushed there).

---

## 7. Sync UX

### 7.1 Settings → Sync

- Off: **Sync with Google Drive** explains in one line ("Keep projects in step across your devices, using your own Google Drive.") and a **Turn on** button, which signs in and asks for Drive access.
- On: account email · **Sync now** · last synced ("Synced 2 minutes ago" / "Offline — will sync when connected" / an error) · **Device name** (editable) · **Turn off sync** (keeps local data and what's on Drive) · **Sign out**.
- A thin progress bar under the app bar of the project list while a pass with downloads is running.

### 7.2 Conflicts

- Pending conflicts show as a badge on the project list's app bar (a small "sync" icon with a count). The work isn't blocked.
- Tapping it opens **Conflicts**: one card per record, e.g. "Harbour at dusk — changed on this Mac and on Pixel 11". The card shows both versions side by side with device name and time:
  - project: the fields that differ (name, size, notes, reference photo);
  - image: the two crops rendered as previews from the same original (or "Deleted on Pixel 11, 3 h ago").
- The newer one is preselected; **Keep selected** resolves it. Keeping the local version pushes it over the remote; keeping the remote applies it (and records the local edits in undo history first, as m1-design §4.2 does for any outside change, so the other crop can still be undone back to).

---

## 8. Project backup (moved to M8)

Not built in M3. Kept here as the agreed starting point for M8's design; it reuses §5's record format.

- **Export project** (project screen menu): writes `<project name>-<yyyyMMdd>.zip`:

  ```
  manifest.json            { "schemaVersion": 1, "kind": "filbert-project", "exportedBy": "<app version>", "exportedAt": … }
  project.json             §5 format
  viewprefs.json           if any
  images/<image-uuid>.json live images only
  originals/<blob-uuid>.<ext>
  ```

  On the Mac a save dialog; on Android the share sheet (proposal 6). Built in an isolate (`archive` package), streamed to a temp file, so a large project doesn't sit in memory.
- **Import project** (project list menu): a file picker for `.zip`; validates the manifest, then imports as a **new project with new ids** (name unchanged, or with a number if a project of that name exists), each original through the normal import path. New ids mean an import never collides with a synced or tombstoned record.
- Edits, derived-from info and view prefs carry over; undo history doesn't (it's local).
- A zip that isn't a Filbert backup, or has a higher `schemaVersion`, is refused with a message.

---

## 9. Google Photos import

- **macOS only.** On Android, the system photo picker already lists Google Photos (where Google Photos is the phone's cloud media provider, on recent Android) and hands Filbert the downloaded file, so Android keeps M1's picker. On older phones without that, users can share or export from the Google Photos app.
- On the Mac, **Add photos** and the reference slot gain **Google Photos**, beside the file picker; the first use signs in (or adds the scope to the sync account).
- Flow (Photos Picker API, HLD §8.1): create a session (`POST /v1/sessions`) → open its `pickerUri` in the browser (`url_launcher`) → poll the session at its `pollingConfig` interval until `mediaItemsSet` (a sheet in Filbert says "Choose photos in Google Photos…" with Cancel) → list the picked items → download each at full size (`baseUrl=d`, with the access token) → import through the existing path with `source = googlePhotos` and `capturedAt` from the item's `createTime` → delete the session.
- Videos are skipped. Picking for the reference slot takes the first photo.
- `PhotoSource` gets a `pickFromGooglePhotos()` (fake in tests); the REST calls use `http` and are tested against recorded responses.

---

## 10. Services and providers (new or changed)

| Service | Responsibility |
|---|---|
| `AuthService` | Sign in/out, scopes, access token, account email (§6.7) |
| `SyncEngine` (package) | One sync pass (§6.3) |
| `DriftLocalStore`, `DriveRemoteStore` | The engine's local and Drive sides |
| `SyncController` | Triggers, one pass at a time, status stream, Sync now (§6.6) |
| `ConflictRepository` | Watch and resolve pending conflicts |
| `BlobDownloader` | Download queue with priority for an opened photo (§6.5) |
| `PhotoSource` | + `pickFromGooglePhotos` |
| `ExportDestination` | Gallery on Android, save dialog on macOS (§3.5) |

---

## 11. Before starting (Brian)

- Phase 1 (macOS): Xcode installed; an Apple developer team in Xcode (a free personal team is enough to run a sandboxed, keychain-using app locally).
- Phase 2 (sync), by T7: a Google Cloud project with the Drive API and Photos Picker API enabled, the OAuth consent screen in testing mode with your account as test user, and OAuth client ids (Android debug SHA-1, macOS, web). I'll write the exact steps in T7; client ids aren't secrets but go in a config file, not code.

---

## 12. Testing

| What | How |
|---|---|
| Sync engine | Pure-Dart tests with 2–3 simulated devices on `FakeRemoteStore`: offline edits on both, every row of §6.3's table, conflicts, deletion vs edit, tombstones, interrupted uploads and resumes, duplicate files on Drive, duplicate default names, higher and lower `schemaVersion`, first sync merging existing local data |
| Record format | Round trip for every record kind; unknown fields ignored; canonical hash stable |
| Drift side | `DriftLocalStore` tests on an in-memory database; migration test for schema 3 |
| Drive side | `DriveRemoteStore` against recorded HTTP responses; a manual check against Brian's real Drive in T8 |
| Google Photos | Picker client against recorded responses; manual check in the Mac app |
| macOS UI | Widget tests at desktop sizes (1200 × 800, 800 × 600): docked panel, shortcuts, drag and drop (simulated drop events), Save to file with a fake |
| Conflicts UI | Widget tests: badge, cards, preselection, both choices |
| Integration | `app_flow_test.dart` also on macOS (locally); a sync flow with a fake remote on CI's emulator; the exit criteria checked by Brian on the Mac and the Pixel 11 against real Drive |

---

## 13. Packages

Approved by Brian (2026-11-18); versions are checked in the task that adds them.

| Package | Use | Task |
|---|---|---|
| `file_selector` | Save dialog (Mac export) | T4 |
| `desktop_drop` | Drag and drop on macOS | T3 |
| `device_info_plus` | Default device name | T6 |
| `google_sign_in` | Sign-in and scopes | T7 |
| `googleapis`, `extension_google_sign_in_as_googleapis_auth` | Drive v3 client using the sign-in token | T7, T8 |
| `http` | Photos Picker REST, resumable uploads | T8, T12 |
| `workmanager` | Android background sync | T11 |
| `url_launcher` | Open the Photos picker; Show in Finder | T4, T12 |
| `crypto` | SHA-256 for record hashes (§5), in `sync_engine` | T5 |

---

## 14. Open items

| Item | When |
|---|---|
| Does Drive v3 support a conditional update (If-Match or similar)? If so, use it in §6.3 step 3 | T8 |
| Can `google_sign_in` give an access token in a WorkManager isolate? | T11 |
| Classification of `drive.appdata` and `photospicker.mediaitems.readonly`; verification needed for public release | T7 |
| Does HEIC import work on macOS through the existing decode path? | T1 |
| Later ideas: the Photos Picker API on Android, if the system picker's Google Photos support proves patchy on phones painters use; remember the window size; a cellular-data setting for original downloads; merge projects | Later milestone |

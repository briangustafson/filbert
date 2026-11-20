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
| 5 | Device name | Filled from the device (`device_info_plus`: model on Android, computer name on Mac) on the first launch after the update (T6), editable in Settings → Sync (T7). Settles m1-design §4.1. | Conflict choices need a recognizable label without asking the user up front. |
| 6 | Android export of a backup (M8) | Through the **share sheet** (`share_plus`), so the user picks Files, Drive or another app; Mac uses a save dialog. Import uses a file picker on both. | Android's file pickers can't save a large file without holding it in memory; the share sheet hands over the file. `share_plus` is in the HLD for M6 anyway. |
| 7 | macOS distribution | **Defer** to the first public release (HLD §12 said M3). M3 builds a **sandboxed** app, which keeps both the Mac App Store and a notarized DMG open. | No one but Brian runs the Mac app in M3; the sandbox is what the App Store requires and works for a DMG too. |
| 8 | CI for macOS | A **macOS build job** (`flutter build macos --debug`, `.github/workflows/macos.yml`) on every PR and on main, and by hand; the macOS integration test runs locally. | Proves the Mac app compiles. In T1 it became run-by-hand, since macOS runners used 10× the minutes on a private repo; back on PRs since the repo went public (2026-11-19), where they're free. |

### Deviations from the high-level design

1. **Flat Drive layout** instead of folders (HLD §6.2 showed folders as "logical"; proposal 1). (HLD §6.2 and §12 updated.)
2. **No dirty flag** (HLD §4 said local bookkeeping holds a dirty flag): change is detected by hash (proposal 3). (HLD §4 updated.)
3. **macOS distribution decision moves** past M3 (proposal 7). (HLD §12 updated.)
4. **Project backup moves to a new M8**, with Import project added to Export project (HLD §6.3 had export only, in M3). iOS and web become M9 and M10. (HLD §6.3, §7, §11, §12 updated.)

---

## 3. macOS app (phase 1)

### 3.1 Platform setup

- `flutter create --platforms=macos .` added `macos/` (T1). **Minimum macOS 12.0** (Flutter 3.50's; no plugin needs more). Bundle id `com.example.filbert`, as on Android; the app is named **Filbert**. Plugins build through Swift Package Manager (no CocoaPods).
- **App Sandbox** on. T1's entitlements: user-selected files read/write (`com.apple.security.files.user-selected.read-write`; the debug and profile builds also have Flutter's `network.server` for the debugger). Phase 2 adds outgoing network and keychain sharing (Google Sign-In).
- OpenCV: dartcv4's build hooks build OpenCV for macOS; debug builds are for this Mac's chip only (arm64), a universal build is for release. The app bundles it as `dartcv.framework`. The detection eval gives the same score on the Mac as in CI (78.3%, T1).
- **Keep-list hazard** (seen in T1): a profile or release build writes `.dart_tool/hooks_runner/shared/dartcv4/dartcv_keep.txt`, the OpenCV functions that build used, and later builds of the same target leave out the rest. `flutter test` and macOS debug builds share the host target, so after a profile run (e.g. `tool/render_benchmark.dart`) the Mac build stripped functions the tests need (`cv_imread`). Delete that file after any profile or release build.
- Files: the same `FileStore` layout under the app container (`~/Library/Containers/com.example.filbert/Data/`); the database is `Documents/filbert.sqlite` there.
- **No camera** on the Mac: `PhotoSource.canTakePhoto` is false, so the project list's Take photo is hidden and Add photos / Add reference skip the camera-or-device sheet and open the file picker (`image_picker`, which uses `file_selector` on macOS).
- **The user's files are never deleted.** Android's picker hands over temporary copies, which import deletes; the macOS picker returns the user's own files. `PickedPhoto.temporary` says which, and import deletes only temporary copies (found and fixed in T1, before any Mac import ran).
- **HEIC** decodes through the platform decoder on macOS too: the HEIC metadata, render and import tests run on the Mac host (T1).

### 3.2 Desktop layout

The same routes and screens as the phone. Width breakpoints follow Material's window size classes (`WindowWidth` in `lib/app/layout.dart`, T2):

| Width | Changes |
|---|---|
| < 600 dp (compact) | As the phone |
| 600–839 dp (medium) | The project list and photo grid already add columns as the window widens; photo thumbnails grow from 140 to 180 dp. The project header (name, size, start notes) and Settings are capped at 640 dp and centred; the photo grid stays full width. Bottom sheets become centred dialogs (480 dp wide) |
| ≥ 840 dp (expanded) | Above, plus the photo screen docks an open aid panel at the right (320 dp, over the photo, below the top bar); tapping the photo or Back still closes it |

- The Mac's minimum window (800 × 600) is medium, so the Mac never shows the phone layout. Widget tests run at 800 × 600 by default, so most tests see it too.
- Window: resizable, minimum 800 × 600; opens at 1200 × 800, centred (`MainFlutterWindow.swift`). (Not remembered between launches in M3, which would need a window-management package.)
- **Mouse on the photo screen** (T2): moving the pointer shows the chrome and restarts its hide timer (the phone's 3 s); it stays while the pointer is over the top bar, the toolbar, a panel or an arrow, or while a panel is open. **Previous / next buttons** appear at the left and right edges with the chrome once a mouse has moved, since Flutter doesn't drag pages with a mouse; a touch hides them again, so phones never show them. (Added in T2; T3 added the arrow keys.) Zoom: `InteractiveViewer`'s own handling of the trackpad pinch and the mouse wheel, plus double-click; dragging pans when zoomed. Press and hold still shows the original.
- Every icon-only button has a tooltip naming its action (checked in T2); T3 added the shortcut to it on a desktop.
- Menus and dialogs are the phone's. Bottom sheets (the size picker, Export…, the add-photos choice) open through `showAdaptiveSheet` (`lib/app/adaptive_sheet.dart`): a sheet on phones, a centred dialog from 600 dp. Export's refusal to close mid-render guards the dialog too.

### 3.3 Keyboard shortcuts

| Where | Keys |
|---|---|
| Project list | ⌘N new project · Return opens the focused project |
| Project screen | ⌘O add photos · Delete (or Backspace) deletes the photo whose tile has keyboard focus (Tab moves it), with the usual undo snackbar · Esc back |
| Photo screen | ← / → previous / next photo · Esc closes a panel, else goes back · ⌘Z undo · ⇧⌘Z redo · ⌘E Export… · G grid · B gray · V values · C colors · O compare · Space (hold) shows the original · ⌘+ / ⌘− / ⌘0 zoom in / out / fit |
| Crop screen | Return applies · Esc cancels |
| Settings | Esc back |
| Everywhere | ⌘, Settings · ⌘W closes the window, which quits the app (single window) |

As built in T3:

- Each screen wraps itself in `KeyBindings` (`lib/app/shortcuts.dart`), a focus scope that takes focus when the screen appears and handles its list of `KeyBinding`s. It is a small handler of its own rather than `Shortcuts`/`Actions` so that a key it doesn't use goes on unhandled, to a text field as text. ⌘ is Ctrl off Apple platforms, so the shortcuts also work on Android with a hardware keyboard.
- While a text field has focus, only ⌘ shortcuts that don't edit text work (⌘N, ⌘O, ⌘,); letters, arrows, Delete, ⌘Z and Esc are the field's, and Esc then leaves the field. Return and Space are left to a focused button or card, which they activate (so Return opens the focused project).
- ⌘+ is also ⌘= with or without Shift, and the keypad's + and −. Zoom steps by 1.5× about the centre, from fit to the photo's maximum.
- On the Mac, ⌘W is the menu's Window → Close, and the app menu's Settings… (renamed from Preferences…) opens Settings through the `filbert/menu` channel.
- On a desktop, tooltips name the keys ("Back (Esc)", "Grid (G)", "New project (⌘N)"); phones keep the plain tooltips.

### 3.4 Drag and drop

- Dropping image files (JPEG, PNG, HEIC) on the **project screen** adds them as photos, the same as Add photos (including auto-crop on add, if on). Dropping onto the empty reference slot sets the first one as the reference.
- Dropping on the **project list** creates a new project with the first image as its reference and the rest as photos, then opens it.
- Other files are ignored; if nothing in the drop is an image, a snackbar says "Filbert can only add photos."
- Package `desktop_drop` 0.8 (HLD §3.3); 0.9 needs `cross_file` 0.4, which `image_picker` doesn't allow yet.

As built in T3 (`PhotoDropTarget`, `lib/features/photos/ui/photo_drop.dart`):

- Drops are taken on a desktop only, and only by the screen on top (not the project list under a project, nor while a dialog is open).
- While files are over it, the screen is outlined with what a drop will do: "Drop to add photos", "Drop to set the reference" over the empty slot, "Drop to start a project" on the list.
- Images are `.jpg`, `.jpeg`, `.png`, `.heic` and `.heif`. A Finder file is the user's own (`PickedPhoto.temporary` false, never deleted) and is read under the security-scoped bookmark that comes with the drop. A promised file (dragged from Photos, for example) is the app's own copy, so import deletes it like a picker copy.
- A dropped reference on a project with a size opens Crop in Rectangle mode, and dropped photos open Crop in Corners mode with Find canvas if auto-crop on add is on, as with Add photos. A project started from a drop is deleted again if none of its files could be added.

### 3.5 Export on the Mac

- Export… (m2-design §3.5) shows **Save to file…** in place of Save to gallery, with Save as new image below it; the Mac never asks for Photos access. Save to file… opens a save dialog (`file_selector`'s `getSaveLocation`, JPEG only) with the gallery file name rule; JPEG at the same size and quality. Snackbar "Saved." with **Show in Finder**.
- The dialog opens in the folder of the last Save to file… (`app_meta` `export_folder`, §4.5), the first time in Pictures (`$HOME/Pictures`: in the sandbox HOME is the container, whose Pictures links to the user's).
- The dialog comes first and the render after, so cancelling costs nothing and leaves the sheet open. The sandbox lets the app write only the exact path the dialog returns, so the name is never changed after it.
- Show in Finder opens the Finder with the file selected (`NSWorkspace.activateFileViewerSelecting`, over the `filbert/finder` channel), so `url_launcher` isn't needed until T12.
- `ExportDestination` (`lib/features/export/data/export_destination.dart`) is the gallery where `GallerySaver.available`, else a file; `GallerySaver` stays the Android path.

---

## 4. Data model

Drift schema version **3**, with a migration and migration test. Only local tables are added; synced tables are unchanged.

### 4.1 `sync_state` (local only)

One row per synced record that has been pushed or pulled.

| Column | Type | Notes |
|---|---|---|
| `kind` | TEXT | `project` · `image` · `viewPrefs` (the record format's `kind`, §5) |
| `record_id` | TEXT | Primary key with `kind` |
| `drive_file_id` | TEXT | |
| `remote_version` | INTEGER | Drive's file `version` when last pushed or pulled |
| `synced_hash` | TEXT | Hash of the record JSON (§5) when last pushed or pulled; null if the remote version was never applied |
| `held_json` | TEXT | A pulled version not applied yet, retried every pass: from a newer Filbert (§5), or an image or view prefs whose project hasn't arrived (§6.3). Added in T5 |

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

### 4.4 Built in T6

- Drift schema 3 (`from2To3` creates the three tables; migration test v2 → v3). The Dart table classes are `SyncStates`, `BlobSyncs` and `SyncConflicts`, keeping the SQL names above.
- `DriftLocalStore` (`lib/features/sync/data/drift_local_store.dart`) is the engine's `LocalStore`: rows to records and back (`size` nested), a batch in one transaction in dependency order with tombstones first within a kind (so the one-live-view-prefs index never trips mid-batch), originals through `FileStore`, thumbnails from the renderer (§6.5).
- A pulled change to an image's edits goes into its local undo history (decided in T6), so Undo returns to what this device had; the history itself stays local (m1-design §4.2). The history code moved to `EditHistoryTable`, shared with the image repository.
- The database stores canvas sizes as REAL, so a 16 × 20 canvas reads back as 16.0 × 20.0; the canonical JSON (§5) writes whole-number decimals as integers, so such a record hashes the same however it was written.

### 4.5 `app_meta` keys

`sync_enabled`, `sync_account` (email, for display only; tokens stay with the sign-in SDK), `changes_page_token`, `last_sync_at`, `device_name` (now filled, proposal 5); `export_folder` (T4, §3.5: where the Mac's save dialog opens).

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
- Readers ignore unknown fields. A record with a higher `schemaVersion` than the app knows is kept as-is in `sync_state` (`held_json`) but not applied, and isn't pushed over; Settings shows "Update Filbert to sync everything." A lower one is migrated on read.
- The hash (§6.3) is SHA-256 (`crypto`) of the record's canonical JSON: keys sorted at every level, no spaces, whole-number decimals as integers (§4.4). A second hash leaves out `updatedAt` and `updatedByDeviceId`, so the same change made on two devices compares equal (§6.3).

As built in T5 (`packages/sync_engine`, `RecordCodec`):

- A record is one `SyncRecord`: the common columns typed, the kind's own fields as JSON values, pinned down by `RecordCodec.fieldsOf` (names, types, which may be null). The engine reads only `projectId`, `blobId`, `mimeType`, `name` and `nameIsDefault`.
- Project fields: `name`, `nameIsDefault`, `size`, `startNotes`, `referenceImageId`. `size` mirrors the app's `ProjectSize`: `{"kind": "none"}`, `{"kind": "ratio", "w": 4, "h": 5}` or `{"kind": "physical", "width": 16, "height": 20, "unit": "in"}`, not the table's flat columns.
- Image fields: `projectId`, `blobId`, `mimeType`, `width`, `height`, `source`, `capturedAt`, `edits`, `derivedFrom`. View prefs: `projectId`, `prefs`.
- The JSON `kind` is `project`, `image` or `viewPrefs`; file names use `project-`, `image-`, `viewprefs-` (§6.2).

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
  thumb-<blob-uuid>.jpg           512 px thumbnail of the unedited original (§6.5)
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

- Records are applied in dependency order (projects, then images, then view prefs) in one Drift transaction per batch, so the UI's streams update once. An image (or view prefs) whose project hasn't arrived yet is held (`held_json`) and retried every pass.
- As built in T5:
  - **Equal JSONs** means equal apart from `updatedAt` and `updatedByDeviceId` (§5), so the same edit on two devices, such as the same renumbered name, isn't a conflict; the remote copy is taken.
  - **A lost reply**: a remote version last written by this device, no newer than the local record, is this device's own push whose reply was lost (an interrupted create or update), not a remote edit; the local record is kept and pushed if it changed since.
  - **Duplicates** are handled in the pull (two files for one record in the changes) and before a create (a lookup by name finds a file a lost reply left behind).
  - **Echoes**: a changed file at the version `sync_state` already has is this device's own push; it isn't read.
  - **What a failure keeps**: the pull is one batch with its page token, then each upload and each pushed record saves its state as it goes, so a failed request (`RemoteUnavailable`) stops the pass without losing work and the next pass carries on.
  - **Blobs**: an original found on Drive by name (an upload whose reply was lost) isn't uploaded again. Resuming a half-done upload is the Drive store's (T8); the engine only retries.
- Drive v3 has no conditional update (to verify in T8), so step 3's re-read leaves a small race between one person's devices; a lost race overwrites the other device's push, which is the accepted cost (it needs two devices pushing the same record within the same second).
- Turning sync on with projects already on the device merges them: everything local is pushed, everything remote is pulled. Nothing is deleted.

### 6.4 Conflicts

- **Projects and images**: both versions are kept (§4.3) and the user chooses (§7). Applies also to deleted-on-one-edited-on-the-other.
- **View prefs**: newer `updatedAt` wins, no prompt (proposal 4); ties broken by id.
- **Two view prefs records for one project** (each device made one before syncing; m2-design §4.1 left this to M3): the newer is kept and the other tombstoned, and the tombstone syncs. Every device picks the same one (ties broken by id), and the schema's one-live-row-per-project rule always holds.
- **New images on both devices**: separate records, no conflict (HLD §4.2).
- **Duplicate default names** (HLD §6.6): after a pull, if two live projects both have `nameIsDefault` and the same name, the one created later is renumbered ("2026-11-12 (2)") by whichever device notices; the renumbering is an ordinary edit and syncs. Both devices compute the same answer (ties broken by id), so they don't fight.
- **Reference photo**: `referenceImageId` pointing at an image this device doesn't have yet is kept and resolves when the image arrives; pointing at a deleted image shows no reference (as now).

### 6.5 Blobs

- Originals and thumbnails are immutable, so they never conflict: upload once, download once.
- **Thumbnails on Drive** (decided in T6): of the unedited original, uploaded once with it, so they never go stale. A device shows one with the image's crop and rotation applied locally (T9), so the grid is cropped from the start; it's softer for a tight crop until the original arrives and the usual thumbnail is rendered from it. (Uploading the edited view instead would mean a new upload per edit.)
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
| `file_selector` | Save dialog (Mac export), 1.1 | T4 |
| `desktop_drop` | Drag and drop on macOS (0.8; see §3.4) | T3 |
| `device_info_plus` | Default device name | T6 |
| `google_sign_in` | Sign-in and scopes | T7 |
| `googleapis`, `extension_google_sign_in_as_googleapis_auth` | Drive v3 client using the sign-in token | T7, T8 |
| `http` | Photos Picker REST, resumable uploads | T8, T12 |
| `workmanager` | Android background sync | T11 |
| `url_launcher` | Open the Photos picker (Show in Finder is native, §3.5) | T12 |
| `crypto` | SHA-256 for record hashes (§5), in `sync_engine` | T5 |

---

## 14. Open items

| Item | When |
|---|---|
| Does Drive v3 support a conditional update (If-Match or similar)? If so, use it in §6.3 step 3 | T8 |
| Can `google_sign_in` give an access token in a WorkManager isolate? | T11 |
| Classification of `drive.appdata` and `photospicker.mediaitems.readonly`; verification needed for public release | T7 |
| ~~Does HEIC import work on macOS through the existing decode path?~~ Yes (T1, §3.1) | — |
| Later ideas: the Photos Picker API on Android, if the system picker's Google Photos support proves patchy on phones painters use; remember the window size; a cellular-data setting for original downloads; merge projects | Later milestone |

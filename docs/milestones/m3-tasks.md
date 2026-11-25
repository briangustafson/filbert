# M3 Tasks — macOS and sync

Design: [m3-design.md](m3-design.md) · Rules: [engineering-guidelines.md](../engineering-guidelines.md)

Each task is roughly one PR. Workflow per task: short plan → approval → implement → tests pass and `flutter analyze` clean → tick the box. Tasks are listed in dependency order; "Depends on" names the tasks that must be merged first.

## Before starting

See m3-design §11: Xcode and an Apple developer team for phase 1; a Google Cloud project with OAuth clients by T7 (steps written in T7).

## Tasks

### Phase 1 — macOS

- [x] **T1 — macOS target**
  - `flutter create --platforms=macos .`; App Sandbox with the entitlements in §3.1; minimum macOS recorded.
  - The app builds and runs on the Mac with the M1 and M2 features; Take photo hidden; Add photos and the reference slot open a file picker (§3.1). Check HEIC import (§14).
  - `integration_test/app_flow_test.dart` runs on macOS locally; CI gains a macOS build job (proposal 8).
  - *Done when:* both flows pass on macOS; auto-crop and export work in the Mac app; CI's macOS build is green.
  - Depends on: —
  - *Result:* macOS 12.0+, sandboxed, OpenCV bundled (m3-design §3.1). Import on the Mac would have deleted the user's picked file (Android hands over temp copies); `PickedPhoto.temporary` now guards it. No camera: Add photos opens the file picker directly; Export… shows only Save as new image until T4. Both integration flows pass on macOS (locally) and the emulator; eval 78.3% on the Mac; HEIC decodes. The macOS build is a manual workflow (`macos.yml`, Run workflow), per your choice; it can first run once on `main`. A stale dartcv4 keep-list broke host tests after the Mac build; recorded in §3.1.

- [x] **T2 — Desktop layout**
  - Width breakpoints (§3.2): more grid columns; the aid panel docked at the right at ≥ 840 dp; centered setup form; bottom sheets as dialogs at ≥ 600 dp; window 1200 × 800, minimum 800 × 600.
  - Mouse on the photo screen: chrome on pointer movement, trackpad and ⌘-scroll zoom, double-click zoom, hold for the original; tooltips on icon buttons.
  - *Done when:* widget tests at 1200 × 800 and 800 × 600 alongside the phone sizes; checked in the Mac app.
  - Depends on: T1
  - *Result:* `WindowWidth` classes and `MaxWidth`; header and Settings capped at 640 dp; 180 dp thumbnails from 600 dp; `showAdaptiveSheet` for the size picker, Export… and the add-photos choice; the aid panel docked at the right from 840 dp; the chrome follows the mouse; window 1200 × 800 (minimum 800 × 600). Added: previous / next buttons for a mouse, since Flutter doesn't drag pages with one (m3-design §3.2). Tests at 1200 × 800, 800 × 600 and 400 dp (`test/app/desktop_layout_test.dart`); both integration flows pass on macOS. Not yet checked by hand in the Mac app (trackpad zoom and panning in particular).

- [x] **T3 — Keyboard shortcuts and drag and drop**
  - The shortcuts in §3.3 with `Shortcuts`/`Actions`, disabled while typing.
  - Drag and drop (§3.4) with `desktop_drop`: onto the project screen, the reference slot, and the project list.
  - *Done when:* widget tests for each shortcut and for simulated drops; checked in the Mac app.
  - Depends on: T2
  - *Result:* `KeyBindings` per screen (a small handler of its own, so unused keys still reach text fields) with every §3.3 shortcut, plus Esc on Settings; Delete acts on the keyboard-focused tile; tooltips name the keys on a desktop. The Mac menu gained Window → Close (⌘W) and a working Settings… (was a dead Preferences…). `PhotoDropTarget` on the project screen, its empty reference slot and the project list, with a highlight saying what a drop does; Finder files are read under their security-scoped bookmark and never deleted. `desktop_drop` 0.8.4, as 0.9 conflicts with `image_picker` (§3.4). Tests: `test/app/shortcuts_test.dart` (21) and `test/features/photos/photo_drop_test.dart` (9); both integration flows pass on the emulator; the Mac debug build compiles. Not yet checked by hand in the Mac app (a real Finder drop in particular).

- [x] **T4 — Export to a file on the Mac**
  - `ExportDestination`: gallery on Android, **Save to file…** on macOS with `file_selector` (§3.5); snackbar with Show in Finder.
  - *Done when:* widget tests with a fake destination; a file saved from the Mac app matches the live view.
  - Depends on: T1
  - *Result:* `ExportDestination` (gallery, or a file where there's no gallery); Save to file… asks where first, then renders; the dialog opens in the last export's folder (`export_folder`), else Pictures; "Saved." with Show in Finder, native, so `url_launcher` waits for T12 (§3.5). `file_selector` 1.1.0. Tests drive the real `FileExportDestination` with a fake dialog and a temp folder (`export_sheet_test.dart`, `export_destination_test.dart`); 605 tests pass; the Mac debug build compiles. Not yet checked by hand in the Mac app (a saved file against the live view).

### Phase 2 — Sync

- [x] **T5 — Sync engine package**
  - `packages/sync_engine`: `RecordCodec` (§5), `LocalStore` / `RemoteStore` interfaces, `SyncEngine` (one pass, §6.3), conflict detection and view-prefs rule (§6.4), duplicate default names, blobs before records, duplicate Drive files, schema versions; `FakeRemoteStore` with dropped and interrupted requests.
  - *Done when:* the multi-device tests in §12 pass (`dart test` in the package, in CI).
  - Depends on: —
  - *Result:* `SyncRecord` + `RecordCodec` (generic record, fields pinned per kind; nested `size`; SHA-256 hashes, one without the stamps), `LocalStore` / `RemoteStore`, `SyncEngine.syncOnce()` and `resolveConflict()` (for T10). Added in m3-design: `sync_state.held_json` for too-new records and images before their project (§4.1), the lost-reply and equal-content rules (§6.3), duplicate view prefs (§6.4). `package:sync_engine/testing.dart` has `FakeRemoteStore` (dropped and interrupted requests), `MemoryLocalStore`, and 28 shared multi-device scenarios that T6 runs against Drift; 48 tests in all, in CI. Retrying a failed upload is the engine's; resuming one is T8's.

- [x] **T6 — Schema v3 and the Drift side**
  - Drift schema 3: `sync_state`, `blob_sync`, `sync_conflicts`, new `app_meta` keys (§4); migration and migration test.
  - `DriftLocalStore` implementing the engine's `LocalStore`; device name from `device_info_plus`, editable in Settings (proposal 5).
  - *Done when:* store tests on an in-memory database; the engine's tests also pass against `DriftLocalStore` with the fake remote.
  - Depends on: T5
  - *Result:* schema 3 with `sync_state` (+ `held_json`), `blob_sync`, `sync_conflicts`, and the sync `app_meta` keys; migration test v2 → v3. `DriftLocalStore` and `localStoreProvider`; all 28 engine scenarios pass with each device on its own Drift database (`test/features/sync/drift_local_store_test.dart`). Decided: Drive thumbnails are of the unedited original, cropped on the receiving device (§6.5, display in T9); a pulled crop goes into the undo history; the device name defaults from `device_info_plus` 13.3.0 at launch and is edited in T7. The canonical JSON now writes whole-number decimals as integers (§4.4). Checked: the app upgrades to schema 3 on the emulator; integration flows pass there; the Mac debug build compiles.

- [x] **T7 — Google Sign-In and Sync settings**
  - Write the Google Cloud setup steps for you (§11); record the scope classification (§14).
  - `AuthService` with `google_sign_in` on Android and macOS: sign in, ask for `drive.appdata`, sign out (§6.7).
  - Settings → Sync (§7.1): Turn on, account, Turn off, Sign out, device name (status and Sync now come in T9).
  - *Done when:* widget tests with a fake `AuthService`; sign-in checked on the emulator and the Mac with your test account.
  - Depends on: T6
  - *Result:* `google_sign_in` 7.2; `AuthService` (`lib/core/auth/`) with restore, sign in, Drive authorization, a silent access token for T8 and sign out; Settings → Sync with Turn on, account, Device name, Turn off sync and Sign out; Turn on with another account clears the sync bookkeeping (m3-design §6.7). Decided: keep `com.example.filbert` through M3; the client ids are committed; your Apple team id lives in an untracked `Signing.xcconfig`, and without it the Mac app builds unsigned (`CODE_SIGNING_ALLOWED = NO`), as on CI; Drive access is asked for only by Turn on, and the launch-time restore comes with T9's launch trigger. `drive.appdata` is non-sensitive. Setup steps in `docs/google-cloud-setup.md`. `googleapis` moves to T8. Checked: sign-in on the Mac and on your phone, after adding your account as a test user (the "has not completed the Google verification process" block). 679 tests pass.

- [x] **T8 — Drive remote store**
  - `DriveRemoteStore`: flat `appDataFolder` layout with `appProperties` (§6.2), Changes API with page tokens, record read/write, resumable blob uploads, downloads, deletes. Answer the conditional-update question (§14).
  - *Done when:* tests against recorded responses; one manual sync pass between the emulator and the Mac against your real Drive (from a debug button or test).
  - Depends on: T5, T7
  - *Result:* `DriveRemoteStore` on `googleapis` 19.0 with `DriveAuthClient` (token per request, one retry after a 401), so `extension_google_sign_in_as_googleapis_auth` isn't used; `RemoteStore.download` added for T9; `manifest.json` written on a first sync. Decided: resumable uploads in 4 MB pieces, restarting on the next pass after an interruption; hand-written Drive-shaped test responses, no recordings; Sync now (debug) in Settings until T9. Answered: Drive v3 has no conditional update (m3-design §6.3, §14). Checked: a project made on the Mac reached your phone, and a rename on the phone reached the Mac, with Sync now (debug); photos show the broken-image tile until T9 downloads them. 697 tests pass.

- [x] **T9 — Sync controller, status and downloads**
  - `SyncController`: triggers (launch, resume, debounced change, every 15 min, Sync now), one pass at a time, backoff, status in Settings and the project-list progress bar (§6.6, §7.1).
  - `BlobDownloader`: thumbnails then originals, priority for an opened photo, placeholder while downloading; Drive purge at 60 days and the "no longer available" case (§6.5).
  - *Done when:* widget tests with fakes; a project created on the Mac appears with its photos on the emulator and an edit on the emulator shows on the Mac.
  - Depends on: T8
  - *Result:* `SyncController` (launch, resume, 5 s after a change, every 15 min, Sync now; one pass at a time; backoff from 30 s to 15 min), `BlobDownloader`, `BlobAvailabilityService` and `DrivePurge` (m3-design §6.5–6.6); Settings → Sync shows the status, Sync now and Sign in when Google wants a new sign-in; the debug button is gone. Decided: Drive thumbnails in `blob-thumbs/`, deleted when the original arrives; photos render from them, cropped, until then; Crop and Export wait for the original; local changes are noticed from Drift's table updates; `RemoteUnavailable` carries a reason. Found in the manual check: Riverpod 3 paused the unlistened controller, so the app didn't sync at launch; the app now listens to it, with a test. Checked: photos from the Mac downloaded on your phone, and edits reached the other device, without tapping Sync now. 727 tests pass.

- [ ] **T10 — Conflicts UI**
  - Badge on the project list, Conflicts screen with side-by-side cards (project fields; image crops rendered from the original; deletions), newest preselected, Keep selected (§7.2).
  - *Done when:* widget tests for the badge, cards and both choices; a conflict made by editing offline on the emulator and the Mac resolves through the prompt.
  - Depends on: T9

- [ ] **T11 — Android background sync**
  - First, find out whether `google_sign_in` gives an access token in a WorkManager isolate (§14). If yes: a periodic task (6 h, any network) running one pass with its own Drift connection. If no: record it in m3-design §6.6 and move it to the notes.
  - *Done when:* a change made on the Mac reaches the emulator with Filbert in the background (forcing the job with `adb`), or the decision is recorded.
  - Depends on: T9

### Phase 3 — Google Photos (Mac)

- [ ] **T12 — Google Photos import (macOS)**
  - Photos Picker session, browser hand-off, polling sheet with Cancel, full-size downloads, import with `source = googlePhotos`, session cleanup; on the Mac, Add photos and the reference slot gain Google Photos (§9). Android keeps the system picker, which already shows Google Photos.
  - *Done when:* client tests against recorded responses; photos picked in the Mac app land in a project.
  - Depends on: T7

### Wrap-up

- [ ] **T13 — Integration test and M3 wrap-up**
  - Integration: the app flow on macOS (locally) and a sync flow on CI's emulator with a fake remote.
  - Check M3 exit criteria (HLD §11) on the Mac and the Pixel 11 against real Drive, including both devices editing offline; fix polish issues found.
  - Update docs (HLD §6.2, §12 and anything else changed); resolve or carry forward open items (m3-design §14).
  - *Done when:* integration tests pass; exit criteria confirmed by you.
  - Depends on: T10, T11, T12

## Changes between tasks

Done between T6 and T7, each its own PR:
- **App icon** for Android and macOS (`assets/icon/`, `flutter_launcher_icons`).
- **Snackbars sit above the bottom controls** on Crop and the photo screen, and Revert shows no snackbar (m1-design §3.5).
- **Compare turns off when you leave the photo screen**; Grid and the tone aid are still saved per project (m2-design §3.1).
- **One Crop screen** with Rectangle and Corners modes and Find canvas, replacing Crop/rotate and the auto-crop review (m1-design §3.7).
- **New app icon**: a filbert brush on teal.

Done between T9 and T10, in one PR:
- **Deleted photos are purged after 5 days**, both locally and on Drive (were 30 and 60; m1-design §4.4, m3-design §6.5).
- **A purged original that's on Drive becomes "on Drive only"**, so a restore on another device downloads it again (it showed a spinner forever).
- **A project's cover is its reference photo** if it has one, else the most recently taken photo (m1-design §3.2).

## Notes and later ideas

(Add ideas that come up during M3 but belong to a later milestone here, rather than building them now.)

- Right-click menus on the Mac for project cards and photo tiles (today a long press, which a mouse can do but nobody expects).
- Upgrade `desktop_drop` to 0.9.2 once `file_selector` and `image_picker` allow `cross_file` 0.4: it removes the Kotlin Gradle Plugin warning on Android builds, and needs a small rewrite of `PhotoDropTarget` for its new API.
- Crop's Corners mode: ratio chips for the output's ratio (today the project's ratio, or the quad's own shape without one).

- Carried over from M2: clamp panning to the photo's edges when zoomed; pinch/pan under the manual crop; frame pacing and the render benchmark on a mid-range phone; centered grid origin; tap a swatch to highlight its areas; wipe or side-by-side compare; aids on thumbnails; a faster Gray export; compare overlay at preview resolution when zoomed; gallery saving on Android 7–10 untested on a device (m2-tasks notes).
- Project backup (export and import) moved to the new M8 (2026-11-18); its agreed design is m3-design §8, with `archive` and `share_plus` (approved for it).
- From the M3 design: remember the window size; a cellular-data setting for original downloads; merge projects (m3-design §14).

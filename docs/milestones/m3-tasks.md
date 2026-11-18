# M3 Tasks — macOS and sync

Design: [m3-design.md](m3-design.md) · Rules: [engineering-guidelines.md](../engineering-guidelines.md)

Each task is roughly one PR. Workflow per task: short plan → approval → implement → tests pass and `flutter analyze` clean → tick the box. Tasks are listed in dependency order; "Depends on" names the tasks that must be merged first.

## Before starting

See m3-design §11: Xcode and an Apple developer team for phase 1; a Google Cloud project with OAuth clients by T7 (steps written in T7).

## Tasks

### Phase 1 — macOS

- [ ] **T1 — macOS target**
  - `flutter create --platforms=macos .`; App Sandbox with the entitlements in §3.1; minimum macOS recorded.
  - The app builds and runs on the Mac with the M1 and M2 features; Take photo hidden; Add photos and the reference slot open a file picker (§3.1). Check HEIC import (§14).
  - `integration_test/app_flow_test.dart` runs on macOS locally; CI gains a macOS build job (proposal 8).
  - *Done when:* both flows pass on macOS; auto-crop and export work in the Mac app; CI's macOS build is green.
  - Depends on: —

- [ ] **T2 — Desktop layout**
  - Width breakpoints (§3.2): more grid columns; the aid panel docked at the right at ≥ 840 dp; centered setup form; bottom sheets as dialogs at ≥ 600 dp; window 1200 × 800, minimum 800 × 600.
  - Mouse on the photo screen: chrome on pointer movement, trackpad and ⌘-scroll zoom, double-click zoom, hold for the original; tooltips on icon buttons.
  - *Done when:* widget tests at 1200 × 800 and 800 × 600 alongside the phone sizes; checked in the Mac app.
  - Depends on: T1

- [ ] **T3 — Keyboard shortcuts and drag and drop**
  - The shortcuts in §3.3 with `Shortcuts`/`Actions`, disabled while typing.
  - Drag and drop (§3.4) with `desktop_drop`: onto the project screen, the reference slot, and the project list.
  - *Done when:* widget tests for each shortcut and for simulated drops; checked in the Mac app.
  - Depends on: T2

- [ ] **T4 — Export to a file on the Mac**
  - `ExportDestination`: gallery on Android, **Save to file…** on macOS with `file_selector` (§3.5); snackbar with Show in Finder.
  - *Done when:* widget tests with a fake destination; a file saved from the Mac app matches the live view.
  - Depends on: T1

### Phase 2 — Sync

- [ ] **T5 — Sync engine package**
  - `packages/sync_engine`: `RecordCodec` (§5), `LocalStore` / `RemoteStore` interfaces, `SyncEngine` (one pass, §6.3), conflict detection and view-prefs rule (§6.4), duplicate default names, blobs before records, duplicate Drive files, schema versions; `FakeRemoteStore` with dropped and interrupted requests.
  - *Done when:* the multi-device tests in §12 pass (`dart test` in the package, in CI).
  - Depends on: —

- [ ] **T6 — Schema v3 and the Drift side**
  - Drift schema 3: `sync_state`, `blob_sync`, `sync_conflicts`, new `app_meta` keys (§4); migration and migration test.
  - `DriftLocalStore` implementing the engine's `LocalStore`; device name from `device_info_plus`, editable in Settings (proposal 5).
  - *Done when:* store tests on an in-memory database; the engine's tests also pass against `DriftLocalStore` with the fake remote.
  - Depends on: T5

- [ ] **T7 — Google Sign-In and Sync settings**
  - Write the Google Cloud setup steps for you (§11); record the scope classification (§14).
  - `AuthService` with `google_sign_in` on Android and macOS: sign in, ask for `drive.appdata`, sign out (§6.7).
  - Settings → Sync (§7.1): Turn on, account, Turn off, Sign out, device name (status and Sync now come in T9).
  - *Done when:* widget tests with a fake `AuthService`; sign-in checked on the emulator and the Mac with your test account.
  - Depends on: T6

- [ ] **T8 — Drive remote store**
  - `DriveRemoteStore`: flat `appDataFolder` layout with `appProperties` (§6.2), Changes API with page tokens, record read/write, resumable blob uploads, downloads, deletes. Answer the conditional-update question (§14).
  - *Done when:* tests against recorded responses; one manual sync pass between the emulator and the Mac against your real Drive (from a debug button or test).
  - Depends on: T5, T7

- [ ] **T9 — Sync controller, status and downloads**
  - `SyncController`: triggers (launch, resume, debounced change, every 15 min, Sync now), one pass at a time, backoff, status in Settings and the project-list progress bar (§6.6, §7.1).
  - `BlobDownloader`: thumbnails then originals, priority for an opened photo, placeholder while downloading; Drive purge at 60 days and the "no longer available" case (§6.5).
  - *Done when:* widget tests with fakes; a project created on the Mac appears with its photos on the emulator and an edit on the emulator shows on the Mac.
  - Depends on: T8

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

## Notes and later ideas

(Add ideas that come up during M3 but belong to a later milestone here, rather than building them now.)

- Carried over from M2: clamp panning to the photo's edges when zoomed; pinch/pan under the manual crop; frame pacing and the render benchmark on a mid-range phone; centered grid origin; tap a swatch to highlight its areas; wipe or side-by-side compare; aids on thumbnails; the snackbar covering the aid toolbar; a faster Gray export; compare overlay at preview resolution when zoomed; gallery saving on Android 7–10 untested on a device (m2-tasks notes).
- Project backup (export and import) moved to the new M8 (2026-11-18); its agreed design is m3-design §8, with `archive` and `share_plus` (approved for it).
- From the M3 design: remember the window size; a cellular-data setting for original downloads; merge projects (m3-design §14).

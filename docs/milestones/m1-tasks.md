# M1 Tasks — Core projects, photos, and cropping (Android)

Design: [m1-design.md](m1-design.md) · Rules: [engineering-guidelines.md](../engineering-guidelines.md)

Each task is roughly one PR. Workflow per task: short plan → approval → implement → tests pass and `flutter analyze` clean → tick the box. Tasks are listed in dependency order; "Depends on" names the tasks that must be merged first.

## Before starting

- [x] **You:** install the Flutter SDK (stable) and Android Studio; have an emulator or a phone with USB debugging enabled. (Needed for T1.)
- [ ] **You:** collect 20–40 photos of paintings on an easel / wall / in progress, covering the situations in m1-design §6.4. (Needed for T13.)

## Tasks

### Foundation

- [x] **T1 — Project skeleton and CI**
  - `flutter create` (org `com.example`, name `filbert`, Android only); Pub workspace with an empty `packages/canvas_detect`.
  - Add M1 dependencies (m1-design §7) at latest stable, except `opencv_dart` (added in T7); `flutter_lints`; `build_runner` working.
  - App shell: `go_router` with placeholder screens for every M1 route (§3.1); Material 3 neutral-gray theme, light/dark following system.
  - GitHub Actions: pub get → build_runner → analyze → test → Android debug build.
  - *Done when:* app launches on the emulator and navigates between placeholder screens; CI is green.
  - Depends on: —

- [x] **T2 — Core: ids, clock, device, database v1, edit model**
  - `IdGenerator` (UUIDv7), `Clock`, `DeviceInfo`; providers for each.
  - Drift database with all M1 tables (§4.1), schema v1 dump committed, migration test harness.
  - `Edits` model and JSON format (§4.2) with validation.
  - *Done when:* unit tests cover id format, `Edits` round-trip/version handling, and the schema dump; device id is created once and persists.
  - Depends on: T1

- [x] **T3 — ProjectRepository**
  - `watchAll`, `watch`, `create` (defaults + default-name numbering, §4.3), `update` (clears `name_is_default` on rename), `delete`/`restore` (tombstones).
  - *Done when:* repository tests pass for naming, numbering, tombstone filtering, and restore.
  - Depends on: T2

### Projects UI

- [ ] **T4 — Project list screen**
  - Grid sorted by `updatedAt`, placeholder thumbnails, empty state.
  - **New project** creates instantly and opens the project screen.
  - Long-press → confirm delete → snackbar with Undo.
  - *Done when:* widget tests cover empty/non-empty states and delete + undo; works on the emulator.
  - Depends on: T3

- [ ] **T5 — Project screen header and size picker**
  - Inline name edit, start notes (collapsed/expanded), auto-save.
  - Size picker (§3.4): size / ratio / none, presets, custom, portrait/landscape, units by locale.
  - Delete project from the overflow menu.
  - *Done when:* widget tests for the size picker and name editing; values persist across app restarts.
  - Depends on: T4

### Photos

- [ ] **T6 — File store, photo source, import**
  - `FileStore`: blob storage with atomic writes; cache directories.
  - `PhotoSource` wrapping `image_picker` (camera and multi-select picker).
  - `ImageRepository.import`, `watchForProject`, `delete`/`restore`, `setAsReference` (reference rules, §3.3).
  - EXIF orientation and capture time; check HEIC decoding (resolves open item in §9).
  - Purge job for items tombstoned > 30 days (§4.4).
  - *Done when:* import, reference-rule, and purge tests pass; HEIC decision recorded in m1-design.
  - Depends on: T3

- [ ] **T7 — OpenCV integration and ImageRenderer**
  - Add `opencv_dart` (deferred from T1: heavy native build, and the spike decides which package it lives in).
  - Spike first: confirm `opencv_dart` works in the app and whether it runs under plain `dart test`; record the outcome in m1-design §6.1 (resolves open item).
  - `ImageRenderer` in a background isolate: decode, apply edits via homography + `warpPerspective`, quarter turns, encode; preview and thumbnail caches keyed by edits hash.
  - *Done when:* golden tests for axis-aligned crop, straightened crop, perspective quad, and quarter turns; preview latency measured on a device and recorded.
  - Depends on: T2, T6

- [ ] **T8 — Reference slot, photo grid, adding photos**
  - Project screen reference slot (add / replace / remove) and photo grid with thumbnails.
  - **Add photo** sheet (take photo / choose from device, multi-select) with import progress.
  - **Take photo** on the project list (new project + photo in one step).
  - Project-list cards show real thumbnails.
  - *Done when:* widget tests for the reference slot rules; adding from camera and picker works on a device.
  - Depends on: T5, T6, T7

- [ ] **T9 — Photo screen**
  - Full-screen edited view, pinch/double-tap zoom, swipe through the project's photos (reference first).
  - Auto-hiding chrome; press and hold to show the original.
  - Menu: Set as reference, Delete (with undo).
  - *Done when:* widget tests for menu visibility and swipe order; smooth on a device.
  - Depends on: T8

### Editing

- [ ] **T10 — Undo, redo, revert**
  - `ImageRepository.setEdits`, `undo`, `redo`, `revert` backed by `image_edit_history` (50-entry cap, redo-tail discard).
  - Photo screen menu items appear only when applicable.
  - *Done when:* history tests pass (push, undo, redo, discard, cap, revert-then-undo).
  - Depends on: T9

- [ ] **T11 — Manual crop screen**
  - Crop rectangle with aspect lock (project ratio default, presets, freeform, orientation toggle).
  - Straighten slider (±45°) and Rotate 90°; output stored as a quad + `quarterTurns`.
  - Cancel / Reset / Apply (Apply pushes an undoable edit).
  - *Done when:* widget tests for handles and aspect lock; quad math unit-tested; apply → undo works on a device.
  - Depends on: T10

- [ ] **T12 — Auto-crop review screen (with stub detector)**
  - `CanvasDetector` interface in `packages/canvas_detect` with a stub implementation (inset full-image quad, low confidence).
  - Review screen (§3.8): draggable corner handles, magnifier loupe, low-confidence hint, Full image / Reset / Apply.
  - Debug-only **Copy corners as JSON**.
  - Photo screen menu item **Auto-crop**.
  - *Done when:* widget tests for handles and buttons; applying a hand-adjusted quad produces a correct perspective-corrected preview.
  - Depends on: T11

- [ ] **T13 — Canvas detection and evaluation set**
  - **You + Claude:** annotate the collected photos using Copy corners as JSON; commit downscaled fixtures and `expected.json` (§6.4).
  - OpenCV detector (§6.2) with pure-Dart scoring; runs in an isolate.
  - Evaluation tool (§6.5) and CI step that fails below the committed baseline.
  - *Done when:* success rate ≥ 80% on the set (or the achieved rate and plan agreed with you), baseline committed, detection < 500 ms on a mid-range phone.
  - Depends on: T12

### Flows and wrap-up

- [ ] **T14 — Add-photo flow and settings**
  - After adding grid photos: auto-crop review queue ("1 of 3", Skip). After adding a reference: manual crop at the project ratio (Skip; skipped if no size).
  - Settings screen: auto-crop on add, units, About.
  - *Done when:* widget tests for the queue and setting toggle; the full flow works on a device.
  - Depends on: T8, T11, T13

- [ ] **T15 — Integration test and M1 wrap-up**
  - Emulator integration test: new project → add photo → auto-crop review → apply → undo → revert.
  - Check M1 exit criteria (HLD §11) on a real phone; fix polish issues found.
  - Update docs for anything that changed during M1; resolve or carry forward remaining open items.
  - *Done when:* integration test passes in CI; exit criteria confirmed by you.
  - Depends on: T14

## Notes and later ideas

(Add ideas that come up during M1 but belong to a later milestone here, rather than building them now.)

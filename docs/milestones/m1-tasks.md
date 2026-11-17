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
  - Add M1 dependencies (m1-design §7) at latest stable, except OpenCV (added in T7 as `dartcv4`); `flutter_lints`; `build_runner` working.
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

- [x] **T4 — Project list screen**
  - Grid sorted by `updatedAt`, placeholder thumbnails, empty state.
  - **New project** creates instantly and opens the project screen.
  - Long-press → confirm delete → snackbar with Undo.
  - *Done when:* widget tests cover empty/non-empty states and delete + undo; works on the emulator.
  - Depends on: T3

- [x] **T5 — Project screen header and size picker**
  - Inline name edit, start notes (collapsed/expanded), auto-save.
  - Size picker (§3.4): size / ratio / none, presets, custom, portrait/landscape, units by locale.
  - Delete project from the overflow menu.
  - *Done when:* widget tests for the size picker and name editing; values persist across app restarts.
  - Depends on: T4

### Photos

- [x] **T6 — File store, photo source, import**
  - `FileStore`: blob storage with atomic writes; cache directories.
  - `PhotoSource` wrapping `image_picker` (camera and multi-select picker).
  - `ImageRepository.import`, `watchForProject`, `delete`/`restore`, `setAsReference` (reference rules, §3.3).
  - EXIF orientation and capture time; check HEIC decoding (resolves open item in §9).
  - Purge job for items tombstoned > 30 days (§4.4).
  - *Done when:* import, reference-rule, and purge tests pass; HEIC decision recorded in m1-design.
  - Depends on: T3

- [x] **T7 — OpenCV integration and ImageRenderer**
  - Add OpenCV (deferred from T1: heavy native build, and the spike decides which package it lives in). Done as `dartcv4`, the pure-Dart package behind `opencv_dart` (m1-design §7).
  - Spike first: confirm OpenCV works in the app and whether it runs under plain `dart test`; record the outcome in m1-design §6.1 (resolves open item).
  - `ImageRenderer` in a background isolate: decode, apply edits via homography + `warpPerspective`, quarter turns, encode; preview and thumbnail caches keyed by edits hash.
  - *Done when:* golden tests for axis-aligned crop, straightened crop, perspective quad, and quarter turns; preview latency measured on a device and recorded.
  - Depends on: T2, T6

- [x] **T8 — Reference slot, photo grid, adding photos**
  - Project screen reference slot (add / replace / remove) and photo grid with thumbnails.
  - **Add photo** sheet (take photo / choose from device, multi-select) with import progress.
  - **Take photo** on the project list (new project + photo in one step); add its line to the empty state.
  - Project-list cards show real thumbnails.
  - Render each new photo's thumbnail and preview in the background right after import, so they're ready before they're shown (cold previews take ≈ 0.3–0.9 s, m1-design §5.1).
  - Call `PhotoSource.retrieveLost()` on start-up and import what it returns (photos taken while Android killed the app).
  - The picker leaves an empty folder per pick in the app cache after import deletes the file; clear `image_picker`'s cache folders (e.g. on start-up).
  - *Done when:* widget tests for the reference slot rules; adding from camera and picker works on a device.
  - Depends on: T5, T6, T7

- [x] **T9 — Photo screen**
  - Full-screen edited view, pinch/double-tap zoom, swipe through the project's photos (reference first).
  - While a preview renders, show the thumbnail scaled up.
  - Auto-hiding chrome; press and hold to show the original.
  - Menu: Set as reference, Delete (with undo).
  - *Done when:* widget tests for menu visibility and swipe order; smooth on a device.
  - Depends on: T8

### Editing

- [x] **T10 — Undo, redo, revert**
  - `ImageRepository.setEdits`, `undo`, `redo`, `revert` backed by `image_edit_history` (50-entry cap, redo-tail discard).
  - Photo screen menu items appear only when applicable.
  - *Done when:* history tests pass (push, undo, redo, discard, cap, revert-then-undo).
  - Depends on: T9

- [x] **T11 — Manual crop screen**
  - Crop rectangle with aspect lock (project ratio default, presets, freeform, orientation toggle).
  - Straighten slider (±45°) and Rotate 90°; output stored as a quad + `quarterTurns`.
  - Cancel / Reset / Apply (Apply pushes an undoable edit).
  - On a device, also check undo / redo / revert from the photo menu (T10 couldn't: nothing created edits before this task).
  - *Done when:* widget tests for handles and aspect lock; quad math unit-tested; apply → undo works on a device.
  - Depends on: T10

- [x] **T12 — Auto-crop review screen (with stub detector)**
  - `CanvasDetector` interface in `packages/canvas_detect` with a stub implementation (inset full-image quad, low confidence).
  - Review screen (§3.8): draggable corner handles, magnifier loupe, low-confidence hint, Full image / Reset / Apply.
  - Debug-only **Copy corners as JSON**.
  - Photo screen menu item **Auto-crop**.
  - *Done when:* widget tests for handles and buttons; applying a hand-adjusted quad produces a correct perspective-corrected preview.
  - Depends on: T11

- [x] **T13 — Canvas detection and evaluation set**
  - **You + Claude:** annotate the collected photos using Copy corners as JSON (debug build; the copied `file` is `<imageId>.<ext>`, renamed to the fixture's name); commit downscaled fixtures and `expected.json` (§6.4).
  - OpenCV detector (§6.2) with pure-Dart scoring; runs in an isolate.
  - Evaluation tool (§6.5) and CI step that fails below the committed baseline.
  - *Done when:* success rate ≥ 80% on the set (or the achieved rate and plan agreed with you), baseline committed, detection < 500 ms on a mid-range phone.
  - Depends on: T12
  - *Result (agreed with you):* 72.8% of runs within 2%, measured over 10 runs per photo with invisible noise because the detector is unstable (§6.5); stability is T13b. 15 references are approved detector proposals, 3 hand-marked (§6.4). ~120 ms per photo on a Mac; the mid-range-phone timing moves to T15's real-phone checks.
  - *Later:* calibrate confidence (wrong answers can score high), dark canvases on busy backgrounds, more evaluation photos (hand-marked).

- [x] **T13b — Detection stability**
  - Make the detector's answer stable under tiny pixel differences: near-ties between candidates are currently decided by hard cut-offs (nested-quad tolerance, thresholded edge counts, the inner-edge rule). Candidates: smooth scoring instead of thresholds; a consensus across slightly varied inputs.
  - Judge every change by the noise-averaged evaluation (§6.5).
  - *Done when:* ≥ 80% of runs within 2% (or the achieved rate agreed with you), no photo that passes on its clean run failing on noisy ones, baseline updated.
  - Depends on: T13
  - *Result (agreed with you):* 78.3% of runs within 2% (was 72.8%), 78.4% of noisy runs agree with the clean run (was 61%), ~110 ms on a Mac. Chroma instead of saturation, gradual edge support, 10% nested-quad tolerance, wider first refinement search (m1-design §6.2). 06 and 15 still flip occasionally: consensus would fix that but triples the time, so it's left out. References for 03, 08 and 10 corrected with your approval (§6.4). Also fixed: the tools passed the detector a view of OpenCV memory the garbage collector could free (the app wasn't affected).

### Flows and wrap-up

- [x] **T14 — Add-photo flow and settings**
  - After adding grid photos: auto-crop review queue ("1 of 3", Skip). After adding a reference: manual crop at the project ratio (Skip; skipped if no size).
  - Settings screen: auto-crop on add, units, About.
  - *Done when:* widget tests for the queue and setting toggle; the full flow works on a device.
  - Depends on: T8, T11, T13

- [ ] **T15 — Integration test and M1 wrap-up**
  - Emulator integration test: new project → add photo → auto-crop review → apply → undo → revert.
  - Check M1 exit criteria (HLD §11) on a real phone; fix polish issues found. Run `tool/render_benchmark.dart` on it and record preview latency (m1-design §5.1); time canvas detection there too (target < 500 ms, §6.2).
  - Try `dartcv4`'s `treeshake: true` in a release build and record the APK size.
  - Update docs for anything that changed during M1; resolve or carry forward remaining open items.
  - *Done when:* integration test passes in CI; exit criteria confirmed by you.
  - Depends on: T14

## Notes and later ideas

(Add ideas that come up during M1 but belong to a later milestone here, rather than building them now.)

- Photo screen polish: when zoomed, panning can reach the black letterbox around the photo; clamp panning to the photo's edges as photo viewers usually do (T9).
- Manual crop: pinch/pan the photo under the crop for precise placement (§3.7 mentions it; deferred in T11). Handles alone work for canvas-sized crops.
- Photo screen: check frame pacing (swipe, zoom) on a real mid-range phone in profile mode; the emulator's GPU made raster timing meaningless (T15).

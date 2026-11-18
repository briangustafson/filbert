# M2 Tasks — Viewing aids and compare (Android)

Design: [m2-design.md](m2-design.md) · Rules: [engineering-guidelines.md](../engineering-guidelines.md)

Each task is roughly one PR. Workflow per task: short plan → approval → implement → tests pass and `flutter analyze` clean → tick the box. Tasks are listed in dependency order; "Depends on" names the tasks that must be merged first.

## Before starting

Nothing needed from you: M2 uses the same emulator and Pixel 11 as M1.

## Tasks

### Foundation

- [x] **T1 — Safe OpenCV calls (dartcv4 temporary-size hazard)**
  - Wrap the dartcv4 calls that take a size, point or criteria record and that M1 or M2 use (`resize`, `gaussianBlur`, `getStructuringElement`, `warpPerspective`, `kmeans`), so the native struct stays alive until the call returns (m1-design §7, m2-design §9).
  - Route `packages/canvas_detect` and `lib/core/imaging` through the wrappers; a test fails if code calls the wrapped functions directly.
  - Draft an upstream issue for dartcv4 for you to file.
  - *Done when:* wrappers have unit tests; the eval score is unchanged (baseline 0.783); CI integration job green.
  - Depends on: —
  - *Result:* `package:canvas_detect/safe_cv.dart` wrappers; the guard test scans the resolved dartcv4 source (28 hazardous functions, plus `Async` variants and a few classes) and fails on direct calls; `dartcv4` pinned to exactly 2.3.1. Eval unchanged (78.3%). Upstream issue drafted for you to file (m1-design §7).

- [x] **T2 — Schema v2: view prefs and derived images**
  - Drift schema 2: `view_prefs` table (§4.1); `images.source` gains `derived`; `images.derived_from_json` (§4.3). Migration plus migration test.
  - `ViewPrefs` model and JSON (§4.2): defaults, optional fields, unknown fields ignored, unknown `v` → defaults.
  - `ViewPrefsRepository`: `watch(projectId)` (defaults without a row), `update` (creates the row on first change, stamps only the row, debounced ≈ 500 ms).
  - *Done when:* repository, JSON and migration tests pass; the project list order doesn't change when prefs change.
  - Depends on: —
  - *Result:* one live row per project is enforced by a partial unique index; `watch` shows changes before they're written, and pending writes are flushed when the app is hidden (§4.2). The typed `derived_from_json` model comes with its first writer, T9.

- [x] **T3 — Tone math and palette**
  - `lib/core/imaging/tone.dart`: sRGB → L\*, gray, value bands, nearest palette color in Lab (§5.1).
  - `PaletteService`: k-means in Lab on a 256 px downscale of the preview, fixed seed, swatches ordered by L\*; memory and disk cache (§5.2).
  - *Done when:* unit tests for known L\* values, band edges, determinism, and recovering the colors of a synthetic flat-color image; palette time on the emulator recorded.
  - Depends on: T1
  - *Result:* k-means in plain Dart with its own seeded generator instead of OpenCV `kmeans`, which dartcv4 can't seed (m2-design §5.2). Emulator, worst-case photo: 120 ms for 8 colors, 140 ms for 16.

### Live view

- [x] **T4 — Photo screen aid toolbar and state**
  - Bottom toolbar with the chrome: Grid · Gray · Values · Colors · Compare (§3.1); Gray/Values/Colors exclusive; panels open and close as in §3.1–§3.2 (contents wired up in later tasks); chrome doesn't auto-hide while a panel is open; aids reset when leaving the photo screen; hold shows the original without aids.
  - Values and Colors panels (band and color steppers) read and write `ViewPrefs`.
  - Photo menu gains **Export…** only in T9 (menu items appear when built).
  - *Done when:* widget tests for exclusivity, panel toggling, chrome timing and reset, on a normal and a narrow (400 dp) screen.
  - Depends on: T2
  - *Result:* tap rules and Back closing a panel added to m2-design §3.1. The Values panel shows the band grays and the Colors panel the photo's palette (both already available). Grid and Compare panels are empty until T6/T7; hold-for-original hiding the aids comes with T5, when aids draw something.

- [x] **T5 — Live tone view (fragment shader)**
  - First, find out whether `flutter test` can run fragment shaders on the host; record the answer in m2-design §5.3 and choose the shader test (§7).
  - `shaders/view_aids.frag`: gray, values, colors (palette uniforms) over the preview; the photo page uses it only when a tone aid is on; zoom and detail renders still work; band strip and swatches in the panels.
  - *Done when:* shader output matches `tone.dart` within a tolerance (golden or emulator test); toggling and changing bands is instant on the emulator.
  - Depends on: T3, T4
  - *Result:* `flutter test` runs the shader on the host, so it's tested directly against `tone.dart` (within 2/255). Drawn by a `CustomPainter` (`ShadedImage`), since `ImageFilter.shader` needs Impeller (m2-design §5.3). On emulator-5554: Gray, Values and Colors switch at once, bands change at once, zoom with the detail render works.

- [x] **T6 — Grid**
  - Grid geometry (divisions; spacing from the project's physical size with partial cells; aspect-mismatch note; export widths) as pure Dart, shared with export (§3.3).
  - `CustomPainter` over the photo in the zoom transform; constant on-screen width; Grid panel (mode, rows/cols, spacing in the project's unit, diagonals, color, width) saved in `ViewPrefs`. Spacing mode only offered for projects with a physical size.
  - *Done when:* geometry unit tests; widget and golden tests of the overlay and panel.
  - Depends on: T4
  - *Result:* `GridLayout` (pure Dart, for T8 too) and `GridPainter` outside the zoom transform. Added in m2-design §3.3: the canvas's long side goes with the photo's, the note at > 2% aspect difference, spacing steps of ½ in / 1 cm. Overlay goldens in `test/goldens/grid/` (M1 tolerance). Checked on emulator-5554: lines stay 1 dp when zoomed; the panel fits.

- [x] **T7 — Compare**
  - Compare photo: default reference (else the most recent other photo), chosen from the panel's thumbnails, saved in `ViewPrefs` with the opacity; falls back when the photo is deleted; hidden (with a note) when viewing the compare photo itself; Compare button hidden with no other photo.
  - Overlay stretched to this photo's frame, blended in the shader with tone applied to each photo (§3.4).
  - *Done when:* widget tests for the default, fallback and self cases; blend checked like T5; swiping keeps the compare photo.
  - Depends on: T5
  - *Result:* the same shader takes a second sampler and palette; each photo is toned, then mixed in sRGB (m2-design §3.4, §5.3). `CompareTarget` resolves the photo per page. Blend tested against `tone.dart` at 0/30/50/100 % (within 2/255). On emulator-5554: overlay at 50 %, slider, Values and Colors on both photos, the note on the compare photo itself, swiping keeps the choice.

### Export

- [x] **T8 — RenderService (full-resolution export)**
  - `RenderService.export(image, ExportOptions)` in an isolate: full-size render (≤ 6000 px) → tone → compare blend → grid → JPEG 92; per-run cache in `<appCache>/exports/`, cleared at launch (§5.4).
  - Measure time and memory at 48 MP with compare on the Pixel 11 (extend `tool/render_benchmark.dart`); lower the cap if needed and record it in §5.4.
  - *Done when:* golden tests for each aid, compare, and grid on the synthetic pattern; CPU output matches the live view's math.
  - Depends on: T3, T6, T7
  - *Result:* `OpenCvRenderService` with `ExportOptions` (m2-design §5.4). Tone by tables from `tone.dart` (`tone_map.dart`): Values and Colors equal it exactly, Gray within rounding. Goldens in `test/goldens/export/` (M1 tolerance). 48 MP at 6000 px with Values + Compare + grid: 1.4 s and +252 MB on the Pixel 11 (5.5 s on the emulator), so the 6000 px cap stays (§5.4).

- [x] **T9 — Export sheet, Save to gallery, Save as new image**
  - Photo menu → **Export…**: Include checklist preset to the aids that are on; progress and errors in the sheet (§3.5).
  - `GallerySaver` with `gal` (choose 3.0.x or 2.3.3, §8): album "Filbert", file name rule, permission handling on Android 7–10 (API ≤ 29).
  - `ImageRepository.importDerived`: new photo with `source = derived` and `derived_from_json`; snackbar with **Open**.
  - *Done when:* widget tests with a fake `GallerySaver`; repository test for derived import; saving to the gallery checked on the emulator.
  - Depends on: T2, T8
  - *Result:* `gal` 3.0.1 (m2-design §8). The storage permission applies up to Android 10 (API 29), not 9, per `gal`'s README; the Settings button is a small method channel, not a package (§5.5). On emulator-5554: Colors + Grid saved to `Pictures/Filbert/` at full size and matching the live view; Save as new image added the photo and Open showed it. The Android 7–10 permission path is tested with the fake only.

### Wrap-up

- [x] **T10 — Integration test and M2 wrap-up**
  - Extend the emulator integration test: turn on Values and Compare, export as a new image, check it appears in the project.
  - Check M2 exit criteria (HLD §11) on the Pixel 11; fix polish issues found.
  - Update docs for anything that changed during M2; resolve or carry forward open items (m2-design §9).
  - *Done when:* integration test passes in CI; exit criteria confirmed by you.
  - Depends on: T9
  - *Result:* exit criteria confirmed by you on a Pixel 11 (2026-11-18). Integration test `integration_test/app_flow_test.dart` (renamed from `m1_flow_test.dart`; CI job `integration`) runs the M1 flow and the M2 flow: reference and photo → Values and Compare → Save as new image → the derived photo checked and opened. Later ideas and unchanged polish carried forward below (m2-design §9).

## Notes and later ideas

(Add ideas that come up during M2 but belong to a later milestone here, rather than building them now.)

- Carried over from M1: clamp panning to the photo's edges when zoomed; pinch/pan the photo under the manual crop; frame pacing and `tool/render_benchmark.dart` on a mid-range phone (m1-tasks notes).
- From the M2 design: centered grid origin; tap a swatch to highlight its areas; wipe or side-by-side compare; aids on thumbnails (m2-design §9).
- Polish noticed while building M2 (not done): the snackbar briefly covers the aid toolbar; Gray export is the slowest tone (≈ 1 s at 48 MP on the Pixel 11) and a 16-bit luminance table would speed it up (m2-design §5.4); the compare overlay stays at preview resolution when zoomed (§5.3).
- Not tested on a device: saving to the gallery on Android 7–10, where storage permission is asked (T9; fake only).

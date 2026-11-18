# M2 Detailed Design — Viewing aids and compare (Android)

Status: Draft v1 (2026-11-17)
Parent docs: [high-level-design.md](../high-level-design.md) · [engineering-guidelines.md](../engineering-guidelines.md) · [m1-design.md](m1-design.md)

M2 lets a painter check a photo at the easel — gridlines, grayscale, limited values, limited colors, and an overlay comparing any two project photos — and export what they see, to the device gallery or as a new photo in the project. Everything stays local; sync is M3.

**Exit criteria** (HLD §11): a painter can check values and compare progress to the reference at the easel, and export what they see.

---

## 1. Scope

**In scope**

- Viewing aids on the photo screen, shown live: **grid**, **grayscale**, **limited values** (value bands), **limited colors** (palette), **compare** (overlay with adjustable opacity).
- Aid settings remembered per project (grid, band count, color count, compare photo, opacity).
- `RenderService`: full-resolution export of a photo with its edits and any selected aids.
- **Export** sheet: choose which aids to include, then **Save to gallery** or **Save as new image**.
- Fix the dartcv4 temporary-size hazard (m1-design §7) before adding more OpenCV calls.

**Out of scope (later milestones)**

Sync of aid settings and derived images (M3; the data is sync-ready) · sharing to other apps (M6) · print (M5) · AI (M4) · aids on the project screen's thumbnails.

---

## 2. Decisions made for M2

Agreed with Brian on 2026-11-17.

| Topic | Decision |
|---|---|
| Limited values | **Equal steps of perceived lightness** (CIELAB L\*), 2–9 bands, default 5. Each band is shown as the gray at its middle L\*. |
| Limited colors | **Palette by k-means** in CIELAB, 2–16 colors, default 8, with the palette shown as swatches. Computed once per (photo, edits, count) and cached; mapping pixels to it is live. |
| Aid controls | A **bottom toolbar** shown with the chrome: Grid · Gray · Values · Colors · Compare. Tap toggles; the active aid's settings sit in a small panel above the bar. |
| Compare | **Overlay only**: the other photo drawn over this one, stretched to the same frame, with an opacity slider. Default photo: the reference. |
| What's remembered | Aid **settings** per project (synced from M3). Which aids are **on** resets when leaving the photo screen. |
| Grid | **Divisions** (rows × columns) for any project, or **spacing** (e.g. every 2 in) when the project has a physical size. Optional diagonals. Color white / black / gray / red; width thin / medium / thick. |
| Gallery | Package **`gal`** (Android MediaStore; iOS/macOS later), album "Filbert". |
| Export | One **Export…** menu item: an Include checklist preset to what's on screen, then Save to gallery or Save as new image. |
| Live rendering | GPU fragment shader over the preview (HLD §5.2); export recomputes the same math on the CPU with OpenCV (§5.3). |

### Deviations from the high-level design

1. **Aid settings get their own table**, not a `Project.viewPrefs` field (HLD §4.1). Changing a grid shouldn't reorder the project list (sorted by `updated_at`, m1-design §4.3a) or conflict in M3 with an edit to the project's name or notes on another device. (HLD §4.1 updated.)
2. **Grayscale is a lightness view, not a color matrix.** HLD §5.2 mentioned color-matrix filters; a matrix on gamma-encoded RGB misjudges value (saturated blues and yellows most). The shader computes L\* instead (§5.1). (HLD §5.2 updated.)

---

## 3. User experience

### 3.1 Photo screen toolbar

- With the chrome (tap to show; m1-design §3.5), a bottom bar appears: **Grid · Gray · Values · Colors · Compare**, icons with short labels.
- **Gray, Values and Colors are one choice**: turning one on turns the others off (they are alternative ways to show tone). Grid and Compare combine with any of them.
- Tapping an aid that is off turns it on and opens its panel; tapping it again while its panel is open turns it off. Tapping an aid that is on but whose panel is closed opens its panel (it stays on). Gray has no panel, so it just toggles; turning any aid on closes another aid's open panel. Tapping elsewhere on the photo closes the panel and hides the chrome, as now; Android Back with a panel open closes the panel instead of leaving the screen.
- While a panel is open the chrome doesn't auto-hide. With the chrome hidden, the aids stay on.
- Aids stay on while swiping between photos, and apply to whichever photo is shown. Leaving the photo screen turns them all off.
- **Press and hold** still shows the original, without aids (the plain unedited photo).
- When zoomed, aids zoom with the photo; grid lines stay the same on-screen width.

### 3.2 Panels

| Aid | Panel |
|---|---|
| Grid | Mode: **Divisions** (rows, columns: 1–20 each, default 4 × 4) or **Spacing** (only when the project has a physical size: a length in the project's unit, default 2 in / 5 cm). Diagonals on/off. Color (white, black, gray, red; default white). Width (thin, medium, thick; default thin). |
| Gray | No panel (nothing to adjust). |
| Values | Bands: stepper 2–9, default 5; a strip showing the band grays. |
| Colors | Colors: stepper 2–16, default 8; the palette as swatches, ordered dark to light. A spinner on the swatches while the palette computes (≈ 0.1–0.3 s). |
| Compare | A row of thumbnails of the project's other photos, reference first (the compared one outlined); the row scrolls sideways, since a project can have many photos. Opacity slider 0–100 % in whole percent, default 50 %. |

Panels are compact (one or two rows) so most of the photo stays visible; on a narrow phone they wrap rather than scroll sideways. A panel's stepper keeps its place at the bottom left while the swatches beside it wrap upwards, so repeated taps on − / + stay on the buttons.

### 3.3 Grid

- Drawn over the edited photo, which is assumed to be the canvas (crop or auto-crop first).
- **Divisions**: rows × columns of equal cells.
- **Spacing**: square cells of the given length, computed from the project's physical width (cell px = photo width px × spacing ÷ canvas width). The canvas's longer side goes with the photo's longer side, so a portrait canvas photographed in landscape still gets cells of the right size (T6). Lines start at the top-left corner; the last row and column may be partial. If the photo's proportions differ from the canvas's by more than 2% (not cropped to the project's size), the squares still use the width, and the panel says "Crop to the project's size for an exact grid." A project without a physical size shows a saved spacing grid as divisions.
- **Spacing steps** (panel): half inches or whole centimetres, from one step up to the canvas's shorter side.
- **Diagonals**: both diagonals of every cell.
- **Width** on screen: thin 1 dp, medium 2 dp, thick 3 dp, regardless of zoom (the grid is painted outside the zoom transform, at the photo's zoomed position). Colors: white, black, mid-gray (#808080), red (#E53935). Holding the photo hides the grid with the other aids. In exports, the line is the same fraction of the image as on a phone screen: width px = dp × long edge ÷ 800.

### 3.4 Compare

- Turning Compare on overlays the project's compare photo (default: the reference; if this photo is the reference, the most recent other photo). With no other photo, the Compare button isn't shown.
- The overlay is the other photo's edited view **stretched to this photo's frame**: both are crops of the same canvas, so stretching lines them up even if their pixel sizes differ.
- Opacity 0 % shows only this photo, 100 % only the other. The two are mixed as displayed (sRGB), like a layer's opacity in a photo editor; the export does the same (T7).
- Tapping a thumbnail saves that photo as the compare photo. A saved photo that is deleted falls back to the default without clearing the setting, so restoring it brings it back. Without a reference, the default is the most recent photo other than the one shown. (`CompareTarget` in `lib/features/view_aids/domain/compare_target.dart`.)
- Swiping keeps the same compare photo, so every progress photo can be checked against the reference in turn. When the shown photo is the compare photo itself, the overlay is hidden and the panel says "This is the photo you're comparing with."
- Gray / Values / Colors are applied to **each photo before blending**, so value maps of both photos overlap. (Colors uses each photo's own palette.)

### 3.5 Export

- Photo menu → **Export…** opens a bottom sheet:
  - **Include**: Grid · Gray, Values or Colors (whichever is on; one line) · Compare overlay. Each item appears only if that aid is on, preset to checked. With no aids on, the sheet shows no checklist.
  - **Save to gallery**: renders and saves to the gallery album "Filbert"; snackbar "Saved to the gallery."
  - **Save as new image**: renders and adds the result to the project as a new photo; as the newest photo it appears first in the grid (after the reference). Snackbar "Saved as a new photo" with **Open**.
- Rendering shows a progress indicator in the sheet (full-resolution renders take about a second); the sheet can't be dismissed mid-render, and errors show in the sheet.
- Output: JPEG, quality 92, long edge capped at 6000 px (bounds memory for 48 MP photos; enough for a 24 in print at 250 dpi). Gallery file name: `<project name>-<yyyyMMdd-HHmmss>.jpg`, the name stripped of characters not allowed in file names.

### 3.6 Menu

Photo menu after M2: Crop/rotate · Auto-crop · Undo · Redo · Revert to original · **Export…** · Set as reference · Delete. Undo, Redo and Revert concern edits only; aids are not part of undo history.

---

## 4. Data model

Drift schema version **2**, with a migration and a migration test (engineering guidelines; m1-design §4.1).

### 4.1 `view_prefs` (new, synced from M3)

One row per project that has changed an aid setting. Common columns (`id` UUIDv7, `created_at`, `updated_at`, `updated_by_device_id`, `deleted_at`) plus:

| Column | Type | Notes |
|---|---|---|
| `project_id` | TEXT | Unique among live rows (partial unique index `WHERE deleted_at IS NULL`) |
| `prefs_json` | TEXT | §4.2 |

- No row means defaults. The row is created on the first change.
- Changes stamp the row only, not the project, so the project list order is unaffected.
- If sync (M3) delivers two rows for one project, the newer `updated_at` wins; M3 decides details.

### 4.2 `prefs_json`

```json
{
  "v": 1,
  "grid": { "mode": "divisions", "rows": 4, "cols": 4, "spacing": 2.0,
            "diagonals": false, "color": "white", "width": "thin" },
  "values": { "bands": 5 },
  "colors": { "count": 8 },
  "compare": { "imageId": "0193…", "opacity": 0.5 }
}
```

- Every field is optional; missing fields take defaults, unknown fields are ignored (forward-compatible), and an unknown `v` falls back to defaults rather than erroring (settings are not worth blocking on).
- `spacing` is in the project's unit. `compare.imageId` that no longer points at a live photo in the project falls back to the default.
- Writes are debounced (≈ 500 ms) so dragging the opacity slider doesn't write on every frame. `ViewPrefsRepository.watch` shows a change at once, before it's written; pending writes are flushed when the app is hidden, since Android may then kill it.

### 4.3 Derived images

- `images.source` gains `derived` (enum `ImageOrigin.derived`).
- New nullable column `derived_from_json`:

  ```json
  { "v": 1, "imageId": "0193…", "edits": { … }, "aids": { "tone": "values", "bands": 5, "grid": { … }, "compareImageId": "0193…", "opacity": 0.5 } }
  ```

  It records where the image came from; the app doesn't re-render from it.
- A derived image is an ordinary photo: its blob is the rendered JPEG, its edits start empty, it can be cropped, deleted, set as the reference, and compared. `captured_at` is null; `created_at` is the save time.

---

## 5. Rendering

### 5.1 Shared math

One pure-Dart reference (`lib/core/imaging/tone.dart`) defines the tone math; the shader and the CPU export implement the same formulas, and unit tests pin them:

- **sRGB → L\***: decode sRGB to linear, Y = 0.2126 R + 0.7152 G + 0.0722 B, L\* = CIE formula (0–100).
- **Gray**: output the sRGB gray with the same Y (so its L\* is unchanged).
- **Values, N bands**: band k = min(N − 1, ⌊L\* · N / 100⌋); shown as the gray whose L\* is the band's middle, (k + 0.5) · 100 / N.
- **Colors**: palette from k-means (§5.2); each pixel becomes the palette color nearest in CIELAB (ΔE76, i.e. Euclidean distance in Lab).

### 5.2 Palette

- Computed in an isolate from the cached preview, decoded with OpenCV and downscaled to 256 px on the long edge (area averaging), by k-means in CIELAB written in Dart (`lib/core/imaging/palette.dart`, decided in T3): identical pixels are grouped and weighted; k-means++ starting points from a fixed seed, using our own xorshift32 generator so the sequence can't change with the Dart SDK; 3 attempts, keeping the tightest; each stops after 20 rounds or once no color moves more than 0.1 ΔE. So the same photo always gives the same palette. OpenCV's `kmeans` wasn't used because dartcv4 can't seed the generator it draws from, and the Dart version also runs on web. An image with fewer distinct colors than asked gives fewer swatches.
- Time (T3, emulator-5554, profile build, a noisy 12 MP synthetic photo, so a worst case): median 120 ms for 8 colors, 140 ms for 16, including the isolate start and the preview decode.
- Cached in memory per (image id, edits hash, count) and on disk next to previews (`previews/<imageId>-<editsHash>-palette-<n>.json`), so export and later visits reuse it.
- Swatches are ordered by L\*.

### 5.3 Live view (GPU)

- One fragment shader (`shaders/view_aids.frag`, declared under `flutter: shaders:`) draws the photo with the tone mode, and for compare a second photo blended at the opacity: sample both, apply tone to each, mix.
- Inputs: the preview image(s) as samplers, mode, band count, palette (up to 16 colors as uniforms), opacity.
- The photo page draws through the shader only while a tone aid or compare is on; otherwise it keeps M1's plain image path. Zoom and the detail render (m1-design §3.5) work the same with the shader.
- The grid is a `CustomPainter` (`GridPainter`) above the zoomable photo, placing lines through the zoom transform so their width stays constant. Its geometry (`GridLayout`, `lib/features/view_aids/domain/grid_layout.dart`) is pure Dart, shared with the export.
- **How it draws (T5).** `ShadedImage` (`lib/features/view_aids/ui/`) decodes the shown file through Flutter's image cache (the same key as the plain `Image.file`, so switching aids reuses the decode) and paints it with a `CustomPainter` whose paint has the shader, inside the same zoom transform. Flutter's simpler `ImageFiltered` + `ImageFilter.shader` was rejected: it needs Impeller, and `flutter test` runs on Skia, where it throws. While a new file decodes, the previous image stays (like `gaplessPlayback`). Colors shows the plain photo until the palette is ready, then keeps the last palette while a new count computes. Holding shows the plain original, even for an unedited photo.
- **Uniforms**: size, mode (gray, values, colors, or plain for Compare alone), bands, palette count, then the palette as `vec4` arrays (Lab for the nearest match, sRGB to draw); then compare on/off, opacity, and the compare photo's own palette the same way. Set by index in `tone_shader.dart` (`AidParams`).
- **Compare (T7).** The compare photo's preview is the second sampler, decoded at the same width as the shown photo and sampled at the same coordinates, so it stretches to this photo's frame. Zoomed in, the overlay stays at preview resolution (no detail render for it). Until it has decoded, the photo is drawn without the blend.
- **Testing (resolved in T5)**: `flutter test` runs fragment shaders on the host (drawn into an image with `PictureRecorder`), so the shader is tested directly against `tone.dart` (§7). Checked on the Mac test host; CI's Linux host runs the same test.

### 5.4 `RenderService` (export, CPU)

```
original + edits ─▶ full-size render (existing pipeline, ≤ 6000 px) ─▶ tone (gray / values / palette) ─▶ compare blend ─▶ grid ─▶ JPEG
```

- Interface `RenderService.export(image, ExportOptions) → File` (JPEG, quality 92), behind a provider; `OpenCvRenderService` (`lib/features/export/data/`) reuses M1's decode and warp at full size, in isolates. `ExportOptions.fromAids` builds the options from the aids that are on; `without(...)` drops what the export sheet unchecks (T9).
- Order (T8): the compare photo is decoded, warped, stretched and toned in one isolate first, and comes back as BGR bytes; then this photo is decoded, warped and toned, the two mixed, the grid drawn and the JPEG encoded in a second. So only one decoded original is in memory at a time.
- Tone on the CPU (`lib/core/imaging/tone_map.dart`): tables built from `tone.dart` instead of a `pow` per pixel. Luminance is a sum of three lookups; Gray and Values compare it with precomputed luminance thresholds; Colors keeps a 16 MB table of the nearest palette color per 24-bit color, filled as colors are met. Values and Colors equal `tone.dart` exactly, Gray within rounding (tested on every gray, a cube walk and random colors). Colors uses the live view's palette (`PaletteService`, same cache).
- Compare: the other photo rendered at the same output size (stretched), tone applied (its own palette for Colors), then mixed in sRGB at the opacity, as the live view does (§3.4).
- Grid: OpenCV antialiased lines (`cv.line`, `LINE_AA`, sub-pixel positions) at the export width (§3.3), rounded to whole pixels.
- Cached as `<appCache>/exports/<imageId>-<editsHash>-<optionsHash>.jpg` while the app runs (the options hash covers only the settings in use, and the compare photo's edits); cleared at the next launch, from `main.dart` (exports are one-off).
- Memory: a 6000 × 4500 RGBA frame is ≈ 108 MB; with the order above, compare adds one BGR frame (≈ 81 MB) rather than a second original.
- **Measured (T8)** with `tool/render_benchmark.dart` (profile build, synthetic noisy photos, no crop, so the full 6000 px; median of 3 runs; memory is the process's resident set above its level before the export, sampled every 10 ms, so short spikes may be missed). Emulator-5554 (arm64, Apple-silicon Mac):

  | Original | Plain | Gray | Values | Colors (16) | Values + Compare + grid |
  |---|---|---|---|---|---|
  | 12 MP | 1.3 s, +135 MB | 2.0 s, +95 MB | 1.5 s, +96 MB | 1.1 s, +97 MB | 2.6 s, +101 MB |
  | 48 MP | 1.9 s, +182 MB | 3.7 s, +120 MB | 2.4 s, +119 MB | 2.3 s, +203 MB | 5.5 s, +142 MB |

  The process peaked at 658 MB over the whole benchmark (which also renders previews and runs detection). The 6000 px cap stays unless the Pixel 11 run (§9) says otherwise. Gray is the slowest tone (a search over 255 thresholds per pixel); a 16-bit luminance table would make it faster if needed.

### 5.5 Destinations

- **`GallerySaver`** (interface; `gal` implementation): `save(File, {album})`. On Android 10+ no permission is needed; on 7–9 `gal` asks for storage permission, and a refusal shows "Filbert needs permission to save to the gallery" with a Settings link.
- **Save as new image**: `ImageRepository.importDerived(projectId, file, derivedFrom)`, the M1 import path (blob, thumbnail, preview) with `source = derived`.

---

## 6. Services and providers (new or changed)

| Service | Responsibility |
|---|---|
| `ViewPrefsRepository` | `watch(projectId)`, `update(projectId, prefs)`; defaults when there's no row |
| `PaletteService` | `palette(image, count)` → cached k-means palette (§5.2) |
| `RenderService` | Full-resolution export with aids (§5.4) |
| `GallerySaver` | Saves a file to the device gallery (§5.5) |
| `ImageRepository` | + `importDerived` |
| View-aids state | A notifier per photo-screen session: which aids are on, which panel is open (not persisted) |

---

## 7. Testing

| What | How |
|---|---|
| Tone math | Unit tests on `tone.dart`: L\* of known colors, band edges, palette nearest-color |
| Palette | Unit tests: deterministic for a fixed image; recovers the colors of a synthetic image made of N flat colors |
| Export | Golden tests of `RenderService` output for each aid and compare, on the synthetic test pattern (m1-design §5.1 approach) |
| Shader | `tone_shader_test.dart`: a 32 × 32 image of colors spread over the sRGB cube drawn through the shader in each mode; every pixel within 2/255 of `tone.dart` |
| Grid geometry | Unit tests: divisions, spacing with partial cells, aspect mismatch, export widths |
| View prefs | Repository tests: defaults, debounce, unknown fields; migration test for schema 2 |
| UI | Widget tests: toolbar exclusivity (Gray/Values/Colors), panels, compare default photo and hidden-on-self, export sheet presets; narrow phone (400 dp, as in M1) |
| Gallery | Fake `GallerySaver` in widget tests; manual check on the emulator (Android 15) |
| Integration | Extend `integration_test/m1_flow_test.dart` (or add `m2_flow_test.dart`): turn on Values and Compare, export as a new image, check it appears |

---

## 8. Packages

| Package | Use | Status |
|---|---|---|
| `gal` | Save to gallery | Agreed. Latest is 3.0.1 (published 2026-11-15); the task checks it, else uses 2.3.3 |

No other new packages: k-means is plain Dart, drawing uses `dartcv4`, and shaders are built into Flutter.

---

## 9. Open items to resolve during implementation

| Item | When |
|---|---|
| ~~dartcv4 temporary-size hazard (m1-design §7, §9)~~ Fixed in T1: call such functions through `package:canvas_detect/safe_cv.dart`, which includes `kmeans` | — |
| ~~Seeding OpenCV `kmeans`~~ Resolved in T3: k-means is written in Dart with its own seeded generator (§5.2) | — |
| ~~Can `flutter test` run fragment shaders on the host?~~ Yes (T5), §5.3 | — |
| Export memory and time at 48 MP with compare: measured on the emulator in T8 (§5.4: 5.5 s, +142 MB); the Pixel 11 run is Brian's (`flutter run --profile -d <pixel> -t tool/render_benchmark.dart`, then reinstall the app and clear the dartcv4 keep-list). Lower the 6000 px cap if it's too slow or too big there | T8 / T10 |
| `gal` 3.0.1 vs 2.3.3 | Gallery task |
| Later ideas (not M2): centered grid origin; tap a swatch to highlight its areas; wipe / side-by-side compare; aids on thumbnails | — |

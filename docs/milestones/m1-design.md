# M1 Detailed Design — Core projects, photos, and cropping (Android)

Status: Draft v1 (2026-11-13)
Parent docs: [high-level-design.md](../high-level-design.md) · [engineering-guidelines.md](../engineering-guidelines.md)

M1 delivers a local-only Android app in which a painter can create projects, add a reference photo and progress photos, auto-crop or manually crop them, and undo any edit. The data model is sync-ready, but there is no sync, sign-in, or network access in M1.

---

## 1. Scope

**In scope**

- Flutter project skeleton, CI, Pub workspace with `packages/canvas_detect`.
- Project list; create (instant, with defaults), rename, edit setup, delete with undo.
- Project setup fields: name, size or aspect ratio, start notes — all optional and editable at any time.
- Reference photo slot; add photos from the system camera or device photo picker; delete photos.
- Full-screen photo screen with minimal chrome and an M1 menu.
- Manual crop/rotate (project ratio by default; presets; freeform; fine rotation).
- Auto-crop: OpenCV canvas detection, corner-adjust review, perspective correction.
- Non-destructive edits: immutable originals, undo/redo (saved locally), revert to original.
- Settings: auto-crop on add (on/off), units (auto by locale / in / cm).

**Out of scope (later milestones)**

Gridlines, grayscale, limited colors, compare, export/save-to-gallery, "Save as new image" (M2) · sync, sign-in, Google Photos, macOS (M3) · AI (M4) · print (M5) · sharing (M6) · final image, final notes, notebook (M7).

---

## 2. Decisions made for M1

| Topic | Decision |
|---|---|
| Undo history | Persisted locally in SQLite per image; **never synced**. The current edit state syncs (M3). Revert to original always available. |
| Quick use | "New project" creates a project instantly with defaults and opens it; nothing is required. A **Take photo** action on the project list creates a project with that photo in one step. |
| Camera | System camera via `image_picker`; no in-app camera in M1. |
| Auto-crop trigger | Runs automatically on photos added to the project's photo grid and opens the review screen; a setting turns this off. Photos added to the reference slot open manual crop at the project's ratio instead (skipped if the project has no size). |
| Application ID | `com.example.filbert` placeholder; must be replaced before the first Play Store upload. |
| Auto-crop test set | ~20–40 of the user's real photos, downscaled to ~1600 px long edge, committed to `packages/canvas_detect/test/fixtures/` with expected corners. |
| Theme | Material 3 with a neutral-gray palette (no saturated accents near images, to avoid skewing color/value perception); light and dark, follows system. |
| Android minSdk | Flutter default (currently 24); photo picker via the AndroidX backport. |
| Import | Original bytes stored unchanged; EXIF orientation applied on decode; thumbnails generated locally. |
| Delete | Confirm dialog, then an **Undo** snackbar. Records are tombstoned; local files are purged 30 days after deletion. |
| Photo menu | Crop/rotate, Auto-crop, Undo, Redo, Revert to original, Set as reference, Delete. Later features are added when built, never shown disabled. |
| Packages | `packages/canvas_detect` created in M1; `packages/sync_engine` deferred to M3. |

### Deviations from the high-level design

1. **No `Image.role` field.** Which image is the reference is stored only on the project (`Project.referenceImageId`); M7 will add `Project.finalImageId` the same way. A single pointer on the project avoids two sources of truth that could disagree after sync. `derived` images (M2) will be identified by a `derivedFrom` field. (HLD §4.1 updated.)
2. **Fine rotation is expressed by the crop quad**, not a separate angle. A rotated rectangular crop is just a quad, so one representation covers manual crop, fine rotation, and perspective auto-crop. Quarter turns remain a separate output rotation. (HLD §5.1 updated.)

---

## 3. User experience

### 3.1 Navigation

`go_router` routes:

| Route | Screen |
|---|---|
| `/` | Project list |
| `/projects/:projectId` | Project screen |
| `/projects/:projectId/images/:imageId` | Photo screen |
| `/projects/:projectId/images/:imageId/crop` | Manual crop |
| `/projects/:projectId/images/:imageId/autocrop` | Auto-crop review |
| `/settings` | Settings |

Routes use ids only, so they stay valid across renames and can be deep-linked later.

### 3.2 Project list

- Grid of project cards sorted by `updatedAt` (newest first). Card: thumbnail (latest photo, else the reference, else a placeholder), name, last-updated date.
- **New project** (FAB): creates a project with defaults and opens the project screen.
- **Take photo** (app-bar action): opens the system camera; on success creates a new project, adds the photo to its grid, and runs the add-photo flow (§3.6).
- Long-press a card → Delete (confirm → snackbar with Undo).
- Empty state explains the two actions in one line each.
- Overflow menu → Settings.
- Implementation notes (T4):
  - Card date is `MaterialLocalizations.formatShortDate` of `updatedAt` (e.g. "Nov 15, 2026"); no `intl` dependency.
  - Long-press opens a small menu (currently just **Delete**) so later actions can join it; Delete → confirm dialog → tombstone → snackbar with **Undo** that disappears after 6 s.
  - The empty state mentions only **New project** until **Take photo** ships (T8).

### 3.3 Project screen

- **Header**: name (tap to edit inline); size/ratio chip (tap opens the size picker); start notes (collapsed preview, tap to expand/edit). Edits save automatically.
  - Name saves on Enter, on tapping outside, or on leaving the screen; a blank name restores the previous one.
  - Start notes save 600 ms after typing stops and immediately on tapping outside or leaving the screen. Each save bumps `updatedAt`, so the project moves to the top of the list.
  - **Delete project** (overflow) uses the same confirm + Undo flow as the list, then returns to the list where the snackbar appears.
  - A missing or deleted project shows "This project no longer exists" with a way back.
- **Reference slot**: empty state with **Add reference** (Take photo / Choose from device). When filled: thumbnail; tap opens the photo screen; menu has Replace and Remove. Remove clears the pointer but keeps the image in the project (it moves to the photo grid). Replace keeps the old image in the grid.
- **Photos grid**: every live image except the current reference, newest first. Tap opens the photo screen.
- **Add photo** (FAB): bottom sheet with Take photo / Choose from device (multi-select).
- Overflow: Delete project.

### 3.4 Size picker

- Toggle: **Size** or **Aspect ratio** (or **None**).
- Size presets (shown in in or cm by locale/setting): 8×10, 9×12, 11×14, 12×16, 16×20, 18×24, 24×30, 24×36, 30×40, plus metric presets when in cm (e.g. 20×25, 30×40, 40×50, 50×70, 60×80). **Custom** with width/height fields.
- Ratio presets: 1:1, 4:5, 3:4, 2:3, 5:7, 9:16; **Custom**.
- Portrait/landscape toggle swaps width and height.
- Stored already oriented (width and height as displayed).
- Implementation notes (T5):
  - Presets and **None** save and close in one tap; **Custom** saves on **Save**; closing the sheet otherwise changes nothing. The orientation toggle re-saves the current size immediately (squares are left alone) and also turns the preset chips.
  - An **in / cm** toggle sits next to the orientation toggle in Size mode; it switches the preset list and the custom unit but doesn't save by itself.
  - Custom values: 0.1–1000, decimals allowed (`,` or `.`), for sizes and ratio terms; invalid input shows an inline error and disables **Save**. A saved size that isn't a preset reopens as **Custom**, pre-filled.
  - Default unit for new sizes: inches when the device region is US, LR, or MM, otherwise cm (`preferredLengthUnitProvider`; the Units setting in T14 overrides it). An existing size keeps its own unit.

### 3.5 Photo screen

- Full-screen image, the *edited* view (crop applied). Pinch to zoom, double-tap to toggle fit/100%, swipe left/right through the project's photos (reference first, then grid order).
- Tap toggles minimal chrome: back button and a menu button. Chrome auto-hides.
- **Press and hold** shows the original (unedited) image while held.
- Menu: Crop/rotate · Auto-crop · Undo · Redo · Revert to original · Set as reference · Delete. Undo/Redo/Revert appear only when applicable.

### 3.6 Add-photo flow

1. User picks one or more photos (or takes one).
2. Each is imported (§5.2); thumbnails appear immediately with a progress indicator.
3. If added to the **grid** and "auto-crop on add" is on: the auto-crop review screen opens for each new photo in turn (queue with "1 of 3"; **Skip** leaves it uncropped).
4. If added to the **reference slot** and the project has a size/ratio: manual crop opens locked to that ratio (**Skip** allowed).

### 3.7 Manual crop

- Crop rectangle over the image with an aspect lock: project ratio (default if set), the ratio presets, or Freeform. Orientation toggle for the lock.
- Drag corners/edges; pinch/pan the image underneath.
- **Straighten** slider (±45°) and **Rotate 90°** button.
- Buttons: Cancel, Reset, Apply. Apply pushes a new edit state (undoable).

### 3.8 Auto-crop review

- The photo with the detected quad drawn as an outline and four large draggable handles; a magnifier loupe appears under the finger while dragging.
- If detection confidence is low, the quad starts slightly inset from the image edges and a hint says "Couldn't find the canvas edges — drag the corners."
- Buttons: Cancel, **Full image**, **Reset** (to detected), **Apply**. Apply pushes a new edit state with perspective correction.
- Debug builds only: **Copy corners as JSON**, used to create fixture entries for the evaluation set (§6.4).

### 3.9 Settings

- Auto-crop photos when added (default on).
- Units: Automatic (locale) / Inches / Centimeters.
- About (version, licenses).

---

## 4. Data model

### 4.1 Drift tables

Common columns on synced tables: `id TEXT PRIMARY KEY` (UUIDv7), `created_at`, `updated_at` (UTC epoch ms), `updated_by_device_id TEXT`, `deleted_at` (nullable).

**`projects`**

| Column | Type | Notes |
|---|---|---|
| `name` | TEXT | |
| `name_is_default` | BOOL | Cleared when the user edits the name |
| `size_kind` | TEXT | `none` / `ratio` / `physical` |
| `ratio_w`, `ratio_h` | REAL? | When `size_kind = ratio` |
| `width`, `height` | REAL? | When `size_kind = physical` |
| `unit` | TEXT? | `in` / `cm`, when physical |
| `start_notes` | TEXT | Empty string by default |
| `reference_image_id` | TEXT? | Points at an image in this project |

**`images`**

| Column | Type | Notes |
|---|---|---|
| `project_id` | TEXT | FK → projects |
| `blob_id` | TEXT | UUIDv7 of the original file |
| `mime_type` | TEXT | e.g. `image/jpeg`, `image/heic`, `image/png` |
| `width`, `height` | INT | Pixel size **after** EXIF orientation |
| `source` | TEXT | `camera` / `device` |
| `captured_at` | INT? | From EXIF when available |
| `edits_json` | TEXT | Current edit state (§4.2) |

**`image_edit_history`** (local only, never synced)

| Column | Type | Notes |
|---|---|---|
| `image_id` | TEXT | FK → images |
| `seq` | INT | Position in the history |
| `edits_json` | TEXT | Edit state at that position |

Plus a per-image cursor (`image_edit_cursor`: `image_id`, `seq`) for redo. History is capped at 50 entries per image; pushing a new state after undoing discards the redo tail.

**`app_meta`** (local only, key/value): `device_id` (UUIDv7, created on first launch), `device_name`, `auto_crop_on_add`, `units`.

Drift schema version starts at 1. A migration test harness (Drift's schema dumps + `SchemaVerifier`) is set up in M1 even though there are no migrations yet.

Implementation notes (T2):

- Tables live in `lib/core/db/tables.dart`; generated data classes are `ProjectRecord`, `ImageRecord`, `ImageEditHistoryEntry`, `ImageEditCursorEntry`, `AppMetaEntry`.
- Timestamps are `INTEGER` UTC epoch milliseconds (not Drift `DateTime` columns); repositories convert.
- Enums are stored as text: `size_kind` and `source` by enum name; `unit` as `in` / `cm`.
- **Relationships are declared but not enforced** (`PRAGMA foreign_keys` stays off); `images.project_id` is indexed. Sync can deliver an image before its project, and records are tombstoned rather than deleted, so repositories keep references consistent instead of SQLite.
- `device_name` is left unset in M1; M3 decides how to fill it (it is only shown in sync conflict UI).
- The device id is created on first launch and loaded in `main()` before `runApp`, then supplied as a `deviceInfoProvider` override so repositories read it synchronously.
- Schema workflow: `build.yaml` configures `make-migrations`. After changing tables, bump `schemaVersion`, write the migration, then run `dart run drift_dev make-migrations` to add the new dump to `drift_schemas/` and generate step tests under `test/drift/`. `test/drift/app_database/migration_test.dart` fails if `schemaVersion` has no committed dump or the live schema differs from it.

Sync bookkeeping is **not** added in M1. M3 adds it in a separate table keyed by record id, and the first sync uploads everything, so no change tracking is needed before then.

### 4.2 Edit state (`edits_json`)

```json
{
  "v": 1,
  "crop": {
    "quad": [[0.06, 0.04], [0.95, 0.07], [0.93, 0.96], [0.04, 0.94]],
    "output": { "aspectW": 4, "aspectH": 5 }
  },
  "quarterTurns": 0
}
```

- Coordinates are normalized (0–1) in the **EXIF-oriented original** pixel space, ordered top-left, top-right, bottom-right, bottom-left.
- `crop` absent = full image. A rectangular manual crop is an axis-aligned quad; a straightened crop is a rotated rectangle; auto-crop is any convex quad.
- `output` fixes the output aspect ratio (used when the project has a size or the crop was ratio-locked). If absent, output size is estimated from the quad's edge lengths.
- `quarterTurns` (0–3) rotates the output.
- Rendering: compute the homography from `quad` to the output rectangle, warp, then apply quarter turns.
- `v` allows the format to evolve; unknown versions are rejected with a clear error rather than misread.

The `Edits` Dart class (immutable, `toJson`/`fromJson`) lives in `lib/core/imaging/`.

### 4.3 Default project names

- Format: ISO date `yyyy-MM-dd` (sorts correctly, locale-neutral).
- If a live project already has that name, append ` (2)`, ` (3)`, …
- `name_is_default` is true until the user edits the name.
- The date is the device's **local** calendar date. The suffix is the lowest free number ≥ 2 among live projects (a freed number is reused). The check and insert run in one transaction.
- Names are **not unique**: restoring a deleted project, renaming, or sync can produce duplicates, which is allowed. Numbering only applies when generating a default name.

### 4.3a Project repository behavior (T3)

- The UI sees a domain `Project` (`lib/features/projects/domain/`) with a sealed `ProjectSize` (`NoSize` / `RatioSize` / `PhysicalSize`), never Drift's `ProjectRecord`.
- `update` changes only the fields passed; any name change clears `name_is_default`; blank names and non-positive sizes are rejected; an update that changes nothing writes nothing.
- `delete` / `restore` set or clear `deleted_at` and also bump `updated_at` / `updated_by_device_id` (needed for sync). Consequence: a project restored with Undo moves to the top of the list.
- Deleting a project does not tombstone its images; they are unreachable while the project is deleted and return with it. The purge job (§4.4) handles both cases.
- `referenceImageId` is changed only by `ImageRepository.setAsReference` (T6), not by `ProjectRepository.update`.

### 4.4 Files

| Path | Contents | Lifetime |
|---|---|---|
| `<appSupport>/blobs/<blobId>.<ext>` | Originals, byte-for-byte | Until purged after deletion |
| `<appCache>/thumbs/<imageId>-<editsHash>-<px>.jpg` | Thumbnails of the edited view | Cache; regenerated on demand |
| `<appCache>/previews/<imageId>-<editsHash>.jpg` | Display render, ~2048 px long edge | Cache; regenerated on demand |

- Writes go to a temp file and are renamed into place (no partial files).
- Cache keys include a hash of `edits_json`, so changing an edit naturally invalidates them.
- **Purge job** (on app start, at most daily): delete blob files and caches for images whose image or project has been tombstoned for over 30 days. Tombstoned *records* are kept (they're small and M3 needs them).

---

## 5. Services and providers

All are interfaces exposed through Riverpod providers (overridable in tests).

| Service | Responsibility |
|---|---|
| `IdGenerator` | UUIDv7 ids |
| `Clock` | Current time (fakeable) |
| `DeviceInfo` | Device id and name from `app_meta` |
| `ProjectRepository` | `watchAll`, `watch(id)`, `create`, `update`, `delete`, `restore`; default-name logic |
| `ImageRepository` | `watchForProject`, `import`, `setEdits` (pushes history), `undo`, `redo`, `revert`, `setAsReference`, `delete`, `restore` |
| `PhotoSource` | `takePhoto()`, `pickFromDevice({multiple})` → temp files (wraps `image_picker`) |
| `FileStore` | Blob storage, atomic writes, purge |
| `ImageRenderer` | Produces previews and thumbnails from original + edits, off the UI isolate |
| `CanvasDetector` | From `packages/canvas_detect`: `detect(image) → Detection(quad, confidence)` |
| `SettingsRepository` | `app_meta` settings as a stream |

### 5.1 Rendering

- `ImageRenderer` runs in a background isolate: decode (EXIF-oriented), apply edits with OpenCV `warpPerspective` at preview resolution, encode JPEG, cache.
- The photo screen shows the cached preview; the full-resolution original is decoded only when zooming beyond the preview's resolution (tiles/regions not needed in M1; decode at a capped size).
- This makes the GPU viewing aids in M2 simple: they apply on top of an already-cropped preview.
- Full-resolution export rendering arrives with M2's export features, using the same code path at full size.

### 5.2 Import

1. `PhotoSource` returns temp files.
2. For each: generate `blobId`, copy bytes into `blobs/` atomically, read dimensions and EXIF (orientation, capture time), insert the `images` row with empty edits, in a transaction with the project's `updated_at`.
3. Generate the thumbnail in the background; the grid shows a placeholder until it's ready.
4. HEIC from the camera is stored as-is; decoding relies on Android's platform decoder (verify in task; fall back to converting to JPEG on import if OpenCV can't read it).

---

## 6. Auto-crop (`packages/canvas_detect`)

### 6.1 Package structure

```
packages/canvas_detect/
  lib/canvas_detect.dart        public API: CanvasDetector, Detection, Quad
  lib/src/opencv_detector.dart  OpenCV implementation
  lib/src/scoring.dart          candidate scoring (pure Dart)
  bin/evaluate.dart             evaluation CLI
  test/fixtures/                photos + expected.json
```

If `opencv_dart` cannot run under plain `dart test` (to verify in the first auto-crop task), the OpenCV implementation moves to a small Flutter package `packages/canvas_detect_opencv`, and the evaluation runs as a Flutter test instead of a CLI. The interface and scoring stay pure Dart.

### 6.2 Algorithm (initial)

1. Downscale to ~1000 px on the long edge.
2. Build edge maps from both grayscale and saturation channels (canvas vs. wall often differ more in saturation than brightness): Gaussian blur → Canny with median-based automatic thresholds → small dilation.
3. **Contour candidates**: `findContours` → `approxPolyDP` → keep convex quadrilaterals.
4. **Line candidates** (for edges broken by easel clamps, hands, or frames): Hough/LSD lines → cluster into near-horizontal and near-vertical groups → intersect pairs into candidate quads.
5. **Score** each candidate (in `scoring.dart`):
   - area fraction of the image (prefer large; reject < 15%),
   - corner angles plausible for a rectangle under perspective,
   - edge support (fraction of each side lying on strong edges),
   - aspect match to the project's ratio when known (soft penalty),
   - image-border penalty (sides lying exactly on the photo's edge are suspicious).
6. Pick the best; refine corners at full resolution with `cornerSubPix`.
7. Confidence = normalized best score; below a threshold → low-confidence result (§3.8).

Performance target: under 500 ms on a mid-range phone, run in an isolate.

### 6.3 Output aspect ratio

When applying an auto-crop:

- If the project has a size or ratio → use it for `output`.
- Otherwise → estimate from the quad (average opposite edge lengths) for M1. A proper perspective-aware aspect estimate can be added later if results look stretched.

### 6.4 Evaluation set

- `test/fixtures/expected.json`: `[{ "file": "easel-01.jpg", "corners": [[x,y]×4], "notes": "clamp covers top edge" }]` in normalized coordinates.
- Photos: 20–40 real shots covering an easel, a wall, an angled view, a busy studio, framed and unframed work, poor lighting, partial occlusion. Downscaled to ~1600 px; EXIF stripped except orientation.
- Corners are created with the debug **Copy corners as JSON** action (§3.8) after manual adjustment.
- **Repo visibility**: these are the user's paintings. If the repository is ever made public, decide whether to keep them (see §9).

### 6.5 Metrics

- Per photo: maximum corner error as a percentage of the image diagonal.
- Success = max corner error ≤ 2% of the diagonal.
- Report success rate and mean error; the CLI prints a table and exits non-zero if the success rate drops below the committed baseline.
- Initial target: ≥ 80% success on the set; tuned during M1 and recorded as the baseline.

---

## 7. Project setup and tooling

- `flutter create` with org `com.example`, app name `filbert`; Android only (other platforms added in their milestones).
- Pub workspace at the repo root: the app plus `packages/canvas_detect`.
- Dependencies (latest stable at the time of the setup task; versions recorded in `pubspec.yaml`): `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`, `build_runner`, `drift`, `drift_flutter`, `drift_dev`, `go_router`, `image_picker`, `uuid`, `path_provider`, `opencv_dart`, `flutter_lints`, `material_ui`. Any additional package needs confirmation.
- `material_ui` is Flutter's Material library, now shipped as a package; `package:flutter/material.dart` is deprecated since Flutter 3.47, and `flutter create` adds `material_ui` by default. Import `package:material_ui/material_ui.dart`, never `package:flutter/material.dart`.
- `opencv_dart` is added in the rendering task (T7) rather than the setup task. It is a heavy native build, nothing uses it earlier, and the T7 spike decides whether it belongs in the app or in `packages/canvas_detect_opencv` (§6.1).
- Flutter version: 3.50.0 stable, pinned in CI (`.github/workflows/ci.yml`); bump it there and locally together.
- CI (GitHub Actions, using `subosito/flutter-action`): `flutter pub get` → `build_runner` → `flutter analyze` → `flutter test` (app, then `dart test` in `packages/canvas_detect`) → `canvas_detect` evaluation (from T13) → Android debug build.

---

## 8. Testing

| Area | Tests |
|---|---|
| `Edits` model | JSON round-trip, version handling, quad validation |
| Data layer (`ProjectRepository`, `ImageRepository`) | Create/rename/delete/restore, default names and numbering, reference pointer rules (remove/replace keeps image), tombstones exclude records from watches |
| Undo/redo | Push, undo, redo, redo-tail discard, 50-entry cap, revert-then-undo |
| Import | Atomic copy, EXIF orientation dimensions, failure cleans up temp files |
| Purge | Only purges records tombstoned > 30 days; never purges live data |
| Rendering | Golden tests: axis-aligned crop, straightened crop, perspective quad, quarter turns |
| Canvas detection | Unit tests for scoring; evaluation run against fixtures |
| Widgets | Project list (empty/non-empty), project screen reference slot, size picker, crop handles |
| Integration (emulator) | New project → add photo → auto-crop review → apply → undo → revert |
| Migrations | Schema v1 dump committed; harness ready for v2 |

---

## 9. Open items to resolve during implementation

| Item | Resolve in |
|---|---|
| Does `opencv_dart` run under plain `dart test`? (affects §6.1 package split) | First auto-crop task |
| Can OpenCV decode camera HEIC on Android, or should import convert to JPEG? | Import task |
| Preview-render latency on a mid-range phone; adjust preview size if needed | Rendering task |
| Real application ID before the first Play Store upload | Before release |
| If the repo becomes public: keep the painting fixtures in it, or move them out? | Before making the repo public |

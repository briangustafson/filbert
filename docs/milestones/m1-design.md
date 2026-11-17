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
  - The empty state has one line per action (**New project**, **Take photo**).
- Implementation notes (T8):
  - **Take photo** opens the camera first and creates the project only once there is a photo, so cancelling leaves no empty project. If the photo can't be imported, the new project is deleted again and a snackbar says so.
  - Covers come from one query (`ImageRepository.watchCovers`): per live project, the newest live photo other than the reference, else the live reference.

### 3.3 Project screen

- **Header**: name (tap to edit inline); size/ratio chip (tap opens the size picker); start notes (collapsed preview, tap to expand/edit). Edits save automatically.
  - Name saves on Enter, on tapping outside, or on leaving the screen; a blank name restores the previous one.
  - Start notes save 600 ms after typing stops and immediately on tapping outside or leaving the screen. Each save bumps `updatedAt`, so the project moves to the top of the list.
  - **Delete project** (overflow) uses the same confirm + Undo flow as the list, then returns to the list where the snackbar appears.
  - A missing or deleted project shows "This project no longer exists" with a way back.
- **Reference slot**: empty state with **Add reference** (Take photo / Choose from device). When filled: thumbnail; tap opens the photo screen; menu has Replace and Remove. Remove clears the pointer but keeps the image in the project (it moves to the photo grid). Replace keeps the old image in the grid. Deleting the reference image keeps the pointer, so Undo restores it as the reference; while it is deleted the slot shows as empty, and setting a new reference in the meantime wins (the restored image then goes to the grid).
- **Photos grid**: every live image except the current reference, newest first. Tap opens the photo screen.
- **Add photo** (FAB): bottom sheet with Take photo / Choose from device (multi-select).
- Overflow: Delete project.
- Implementation notes (T8):
  - The reference tile has the edited view's proportions (up to 280 dp tall); a "⋮" button on it holds **Replace** and **Remove**. Replace opens the same sheet as Add reference; the reference is always a single photo (the picker opens in single mode).
  - Grid tiles are square and cropped to fill; the grid shows "No photos yet…" when empty.
  - While importing, the Photos heading shows "Adding 2 of 5…" with a progress bar; photos are imported one at a time, so each tile appears as it lands. Failures are summed in one snackbar ("2 photos couldn't be added.").
  - Thumbnails: one size everywhere, 512 px on the long edge (`standardThumbnailPx`), so each image has one cached thumbnail. A tile shows a small spinner while its thumbnail renders and a broken-image icon if rendering fails.
  - After each import, the photo's thumbnail is rendered in the background, then (once all thumbnails are queued) its preview. The renderer runs at most two renders at once (each holds a decoded photo), queueing the rest.

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
  - Width comes first everywhere (T15): a "Width × height" ("Width : height" for ratios) caption sits above the presets, and each preset chip, like the project screen's size chip, shows a small rectangle drawn at the size's proportions (`ProportionShape`), so "9 × 12" visibly stands tall and "12 × 9" lies wide.
  - Default unit for new sizes: inches when the device region is US, LR, or MM, otherwise cm (`preferredLengthUnitProvider`), unless the Units setting picks one (§3.9). An existing size keeps its own unit.

### 3.5 Photo screen

- Full-screen image, the *edited* view (crop applied). Pinch to zoom, double-tap to toggle fit/100%, swipe left/right through the project's photos (reference first, then grid order).
- Tap toggles minimal chrome: back button and a menu button. Chrome auto-hides.
- **Press and hold** shows the original (unedited) image while held.
- Menu: Crop/rotate · Auto-crop · Undo · Redo · Revert to original · Set as reference · Delete. Undo/Redo/Revert appear only when applicable.
- Implementation notes (T9):
  - Swiping doesn't change the route: it stays on the photo that was opened, and Back returns to the project. Menu actions apply to the photo shown.
  - Each page shows the thumbnail scaled up at once, then the 2048 px preview. Fitted to the screen, images are decoded at screen size (less GPU and memory while swiping); once zoomed, at full resolution.
  - Zoom: `InteractiveViewer` per page; swiping is off while zoomed. Double-tap toggles fit ↔ 100% of the full-resolution edited view (at least 2×), centred on the tap. Zooming past the preview's resolution requests a **detail** render (up to 4096 px, cached as `previews/<imageId>-<editsHash>-4096.jpg`) and swaps it in.
  - Press and hold shows the original (a preview rendered with no edits) with an "Original" label; for an unedited photo nothing changes.
  - Chrome (back, menu) hides after 3 s and with it Android's system bars (immersive mode); a tap toggles both. Android shows its own one-time "Viewing full screen" notice the first time. The background is always black.
  - Menu so far: **Crop/rotate** (T11) · **Undo** · **Redo** · **Revert to original** (each only when it applies, T10) · **Set as reference** (hidden for the reference) · **Delete**. Revert shows a snackbar with **Undo**; Undo and Redo show nothing, since the photo visibly changes. Delete moves to the next photo (else the previous, else back to the project) and shows a snackbar with **Undo** for 6 s; a deleted reference returns as the reference.
  - Smoothness on the emulator (profile mode, performance overlay): the UI thread averages < 1 ms per frame; raster time is dominated by the emulator's GPU (the plain project screen is slower than the photo screen), so frame pacing needs a real phone (T15).

### 3.6 Add-photo flow

1. User picks one or more photos (or takes one).
2. Each is imported (§5.2); thumbnails appear immediately with a progress indicator.
3. If added to the **grid** and "auto-crop on add" is on: the auto-crop review screen opens for each new photo in turn (queue with "1 of 3"; **Skip** leaves it uncropped).
4. If added to the **reference slot** and the project has a size/ratio: manual crop opens locked to that ratio (**Skip** allowed).

Implementation notes (T8):

- `PhotoImports` (a keep-alive Riverpod notifier in `features/photos/data/`) runs every add: camera, picker, import with progress, background renders, and start-up recovery. Its state is the imports in progress, by project.
- **Photos taken while Android killed the app:** before the camera opens, the target (project + grid or reference, or "new project") is saved in `app_meta.pending_capture`, and cleared when the camera returns. On start-up, `retrieveLost()` photos are imported into that target (a new project if it is gone or none was saved), and a snackbar offers **Open**. Verified on the emulator by killing the app process while the camera was open.
- **Picker leftovers:** `image_picker` copies each picked photo into `<cache>/<uuid>/` and writes camera photos as `<cache>/<uuid><digits>.<ext>`; import deletes the photo but not the folder. On start-up, after recovery, entries with exactly those names are deleted; nothing else in the cache (the render caches live there too).
- The Android photo picker shows **Done** even in single-photo mode, but allows only one selection.

Implementation notes (T14):

- `afterAddRoute` (`features/photos/ui/add_photos.dart`) decides what opens after an add, for the project screen's Add photo / Add reference and the project list's Take photo. Photos recovered at start-up (above) don't open anything: they keep the snackbar with **Open**, so launching the app never lands on an unexpected screen.
- **Review queue:** carried in the review route's query, `…/autocrop?queue=<id>,<id>&of=<total>` (`ReviewQueue`), so nothing global holds it. In queue mode the review screen shows "2 of 3" under its title (not for a single photo) and **Skip**; Apply and Skip go on to the next photo; Cancel, Android back, or finishing the last photo return to the project screen.
- **New reference:** `…/crop?after=add` adds **Skip**; Apply, Skip, Cancel and back all return to the project. The lock starts at the project's ratio, as manual crop always does (§3.7).

### 3.7 Manual crop

- Crop rectangle over the image with an aspect lock: project ratio (default if set), the ratio presets, or Freeform. Orientation toggle for the lock.
- Drag corners/edges; pinch/pan the image underneath.
- **Straighten** slider (±45°) and **Rotate 90°** button.
- Buttons: Cancel, Reset, Apply. Apply pushes a new edit state (undoable).
- Implementation notes (T11):
  - **Geometry** (`lib/core/imaging/crop_geometry.dart`, pixel space of the original): the screen shows the photo straightened (rotated clockwise by the angle) and then turned by `quarterTurns`; the crop is an axis-aligned rectangle there. Apply stores its corners in the original (a rotated rectangle, ordered as the warp sees them) plus `quarterTurns`, and `output` when ratio-locked. The whole, unrotated photo is stored as no crop. Reopening reads the quad back (angle from its top edge); a quad that isn't a straightened rectangle within ±45° (a perspective crop) can't be shown, so the screen starts from the whole photo with a hint that Apply replaces it.
  - The crop must stay inside the tilted photo and inside the unrotated frame (the photo is clipped to it on screen). Straightening shrinks the crop about its centre as needed and lets it grow back within the same slider gesture.
  - **Handles:** corners (32 dp reach), edges (24 dp), inside = move; drags are measured from the touch-down point. Freeform: a corner moves its two edges, an edge only itself; moves and freeform resizes slide along an edge they hit. Locked: a corner keeps the opposite corner fixed; an edge keeps the opposite edge fixed and grows around the dragged edge's middle. Minimum crop 48 dp.
  - **Aspect lock:** chips for Project (if the project has a size or ratio), Original (the photo's own ratio), Freeform, and the ratio presets. A preset takes the current crop's orientation; a portrait/landscape button flips a non-square lock. Default: the project's ratio as stored (it describes the painting as seen, so it applies to the displayed photo), else Freeform; an uncropped photo opens with the largest crop of the default proposed.
  - Rotate 90° turns the photo, the crop and the lock together. Reset returns to unstraightened, unturned, with the default proposed.
  - Pinch/pan of the photo underneath is deferred (see m1-tasks, later ideas).
  - Verified on the emulator: crop + straighten → Apply renders exactly the region shown; Undo / Redo / Revert (and Undo from its snackbar) from the photo menu; reopening shows the saved crop and angle.

### 3.8 Auto-crop review

- The photo with the detected quad drawn as an outline and four large draggable handles; a magnifier loupe appears under the finger while dragging.
- If detection confidence is low, the quad starts slightly inset from the image edges and a hint says "Couldn't find the canvas edges — drag the corners."
- Buttons: Cancel, **Full image**, **Reset** (to detected), **Apply**. Apply pushes a new edit state with perspective correction.
- Debug builds only: **Copy corners as JSON**, used to create fixture entries for the evaluation set (§6.4).
- Implementation notes (T12):
  - The photo is shown turned by the image's `quarterTurns` (kept on Apply), so corners are dragged on the photo as seen; they're stored in the unturned original, ordered as the warp sees them (`review_geometry.dart`).
  - Starting corners: the photo's existing crop if it has one (manual or auto), else the detection. A low-confidence or failed detection starts 5% inset from the edges, with the hint. **Reset** returns to the detection (or the inset guess); **Full image** puts the corners on the photo's corners, and Apply then removes the crop (keeping the turn). Apply stores the project's ratio as `output` when the project has a size or ratio (§6.3).
  - Drags that would make the quad invalid (outside the photo, crossed, concave, degenerate) are refused. A 2.5× magnifier loupe (Flutter's `RawMagnifier`) floats 110 dp above the finger (below it near the top, kept on screen sideways).
  - Detection decodes the original with the platform decoder (HEIC, EXIF orientation) at ≤ 1000 px and passes RGBA pixels to the detector, with the project's ratio as an aspect hint.
  - **Copy corners as JSON** writes one `expected.json` entry: `{"file": "<imageId>.<ext>", "corners": [[x, y] × 4], "notes": ""}` (corners in the EXIF-oriented original, 4 decimals). Rename `file` to the fixture's name.
  - Verified on the emulator: hint with the stub, dragging with the loupe, Apply on a trapezoid renders it as a rectangle.

### 3.9 Settings

- Auto-crop photos when added (default on).
- Units: Automatic (locale) / Inches / Centimeters.
- About (version, licenses).
- Implementation notes (T14):
  - Stored in `app_meta` (`auto_crop_on_add` `true`/`false`, `units` `auto`/`in`/`cm`) through `SettingsStore` (`lib/core/settings/`); `appSettingsProvider` watches them, so changes apply at once. Missing or unknown values read as the defaults.
  - **Units** applies to new physical sizes (the size picker's default unit, §3.4); **Automatic** is the device region (inches in the US, Liberia and Myanmar, else centimeters). Existing sizes keep their own unit.
  - Units is a row showing the current choice, opening a dialog with the three options. **About Filbert** opens Flutter's About dialog with the version (`package_info_plus`) and **View licenses**.

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

Implementation notes (T10):

- Rows are successive edit states; the cursor points at the row matching the image's current `edits_json`. The first edit records the state before it (seq 0), so it can be undone. **Cap: 50 undo steps** (51 rows); older rows are dropped.
- `setEdits` is a no-op for unchanged edits and discards rows above the cursor. If the image's edits no longer match the row at the cursor (e.g. changed by a future sync), the current edits are recorded first, so undo returns to what the user last saw.
- `revert` is `setEdits(Edits.none)`, so it is undoable; reverting an unedited image does nothing.
- Every change to `edits_json` stamps the image (`updated_at`, `updated_by_device_id`) but not the project, so editing doesn't reorder the project list (as with deleting a photo).
- History survives deleting and restoring the image. Rows of purged images are not removed yet (local-only and small).

**`app_meta`** (local only, key/value): `device_id` (UUIDv7, created on first launch), `device_name`, `auto_crop_on_add`, `units`, `last_purge_at` (epoch ms of the last purge run, §4.4), `pending_capture` (JSON target of an open camera session, §3.6).

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
  - Runs in the background after `runApp`; `app_meta.last_purge_at` enforces the daily limit. Exactly 30 days is not yet purged.
  - A record restored after its files were purged would have no original. In M1 the only restore is the 6-second Undo, so this can't happen; M3 must handle it (e.g. re-download from Drive, or refuse restore).

---

## 5. Services and providers

All are interfaces exposed through Riverpod providers (overridable in tests).

| Service | Responsibility |
|---|---|
| `IdGenerator` | UUIDv7 ids |
| `Clock` | Current time (fakeable) |
| `DeviceInfo` | Device id and name from `app_meta` |
| `ProjectRepository` | `watchAll`, `watch(id)`, `create`, `update`, `delete`, `restore`; default-name logic |
| `ImageRepository` | `watchForProject`, `watchCovers`, `import`, `setEdits` (pushes history), `undo`, `redo`, `revert`, `setAsReference`, `delete`, `restore` |
| `PhotoSource` | `takePhoto()`, `pickFromDevice({multiple})` → temp files, `retrieveLost()`, `clearLeftovers()` (wraps `image_picker`) |
| `FileStore` | Blob storage, atomic writes, purge |
| `ImageRenderer` | Produces previews and thumbnails from original + edits, off the UI isolate |
| `PhotoImports` | Adding photos: camera/picker, import progress, background renders, lost-photo recovery (§3.6) |
| `PendingCaptureStore` | Where an open camera session's photo goes (`app_meta.pending_capture`) |
| `CanvasDetector` | From `packages/canvas_detect`: `detect(image) → Detection(quad, confidence)` |
| `SettingsRepository` | `app_meta` settings as a stream |

### 5.1 Rendering

- `ImageRenderer` runs in a background isolate: decode (EXIF-oriented), apply edits with OpenCV `warpPerspective` at preview resolution, encode JPEG, cache.
- The photo screen shows the cached preview; the full-resolution original is decoded only when zooming beyond the preview's resolution (tiles/regions not needed in M1; decode at a capped size).
- This makes the GPU viewing aids in M2 simple: they apply on top of an already-cropped preview.
- Full-resolution export rendering arrives with M2's export features, using the same code path at full size.

Implementation notes (T7):

- **Split:** `RenderPlan` (`lib/core/imaging/render_geometry.dart`, pure arithmetic) sizes the render; `render_pipeline.dart` (OpenCV, no Flutter) warps, turns and encodes; `OpenCvImageRenderer` (`lib/features/photos/data/image_renderer.dart`) decodes, runs the pipeline in `Isolate.run`, and caches. The renderer lives in the photos feature because it takes a `ProjectImage`.
- **Decoding uses Flutter's platform decoder, not OpenCV.** OpenCV 4.13 (as built by `dartcv4`) cannot decode HEIC, and the platform decoder applies EXIF orientation exactly as the stored dimensions do (§5.2). The decoder only runs on the root isolate; it decodes off the UI thread, and the RGBA pixels are handed to the isolate as `TransferableTypedData`.
- **Sizes:** output size comes from `output` (same area as the quad estimate, at that aspect) or the quad's average opposite edges (§6.3); it is fitted to the long edge (2048 px for previews, the requested px for thumbnails) and never upscaled past the original. The original is decoded at the scale the output needs, so the warp runs near 1:1, capped at 4096 px on the long edge (bounds memory for a small crop of a large photo).
- **Geometry:** normalized 0 and 1 are the image's outer edges; OpenCV corners use pixel-edge coordinates (−0.5 … size − 0.5), so an empty edit reproduces the source exactly. Warp is bilinear with replicated borders; quarter turns are clockwise, applied after the warp. JPEG quality 90.
- **Cache:** files are named by `editsHash` (64-bit FNV-1a of the canonical edits JSON; stable across runs, unlike `String.hashCode`). An existing file is reused; concurrent requests for the same file share one render; writes are temp-file-then-rename.
- **Goldens** (`test/core/imaging/render_pipeline_test.dart`, PNGs in `test/goldens/render/`) render a synthetic test pattern, so input is identical on every OS, and compare the warped pixels before JPEG encoding with a small tolerance (max channel diff 8, mean < 0.5). Update with `flutter test --update-goldens <file>`. The perspective case also checks that a pattern projected onto a quad comes back flat.
- **Latency** (`tool/render_benchmark.dart`, profile mode, synthetic photos; median of warm runs). Emulator: arm64 API 37 on an Apple-silicon Mac (T7). Phone: Pixel 11, a high-end phone (T15); a mid-range phone is not measured yet:

  | Original | No edits (emulator) | Perspective crop (emulator) | No edits (Pixel 11) | Perspective crop (Pixel 11) |
  |---|---|---|---|---|
  | 12 MP | ≈ 0.3–0.45 s | ≈ 0.4–0.6 s | ≈ 0.11 s | ≈ 0.18 s |
  | 48 MP | ≈ 0.5–0.6 s | ≈ 0.5–0.85 s | ≈ 0.35 s | ≈ 0.38 s |

  Platform decoding is about half of it (≈ 0.35 s at 48 MP on the emulator, ≈ 0.08 s at 12 MP and ≈ 0.2 s at 48 MP on the Pixel 11). One-time costs per launch: ≈ 0.4–0.6 s for the first OpenCV call (library load; 35 ms on the Pixel 11) and ≈ 2.8 s for the first platform decode on the emulator. Preview size stays at 2048 px. Because a cold preview is noticeably slow, T8/T9 should render previews and thumbnails in the background right after import or an edit, and show the thumbnail while a preview renders.
- On Android, OpenCV logs `could not open directory …base.apk!/lib/…` errors once at load while looking for optional plugins; they are harmless.

### 5.2 Import

1. `PhotoSource` returns temp files.
2. For each: generate `blobId`, copy bytes into `blobs/` atomically, read dimensions and EXIF (orientation, capture time), insert the `images` row with empty edits, in a transaction with the project's `updated_at`.
3. Generate the thumbnail in the background; the grid shows a placeholder until it's ready.
4. HEIC from the camera is stored as-is; decoding relies on Android's platform decoder (verify in task; fall back to converting to JPEG on import if OpenCV can't read it).

Implementation notes (T6):

- **Metadata** (`ImageMetadataReader`): format from magic bytes (JPEG, PNG, HEIC/HEIF, WebP; anything else is rejected); size from Flutter's `ImageDescriptor` (header parse, no full decode); orientation and `DateTimeOriginal` (+ `OffsetTimeOriginal`, else device-local) from EXIF via the `exif` package. **`ImageDescriptor` already applies EXIF orientation**, so its size is the displayed size and is stored as-is — verified with orientation-6/8 fixtures on the test host and on Android (API 37 emulator).
- **HEIC (resolved for import):** the Android photo picker hands over HEIC files unchanged (byte-identical), and the platform decoder reads them. HEIC is stored as-is; no conversion at import. (Flutter's test host decodes HEIC on macOS but not on Linux, so the two HEIC-decoding tests are skipped in CI; format detection is tested everywhere.) OpenCV can't decode HEIC, so rendering decodes with the platform decoder (§5.1, T7).
- **Photo picker:** `PhotoSource` uses its own `ImagePickerAndroid` instance with `useAndroidPhotoPicker = true` (Android 16+ always uses it). `retrieveLost()` can't tell camera from picker, so recovered photos are recorded as `camera`.
- **Import** is per photo: a file that can't be read, or a failed insert, fails alone (its copied blob is removed) and the others continue; the picked temp file is always deleted. `asReference` (exactly one photo) sets the pointer in the same transaction. Import bumps the project's `updated_at`; deleting or restoring an image does not.
- **Grid order:** newest first by `created_at` (when added), not `captured_at`.

---

## 6. Auto-crop (`packages/canvas_detect`)

### 6.1 Package structure

```
packages/canvas_detect/
  lib/canvas_detect.dart        public API: CanvasDetector, Detection, Quad
  lib/src/opencv_detector.dart  OpenCV implementation (candidates, pipeline)
  lib/src/scoring.dart          candidate scoring and choice (pure Dart)
  lib/src/refine.dart           side fitting and inset (pure Dart)
  lib/src/geometry.dart, edge_map.dart   helpers (pure Dart)
  bin/evaluate.dart             evaluation CLI
  tool/                         fixture, review-sheet and tuning tools
  test/fixtures/                photos + expected.json + baseline.json
```

Run the package's scripts from `packages/canvas_detect` (`dart run bin/evaluate.dart`): `dart run` from the repo root crashes on macOS (a Dart SDK bug in the native-assets runner), and so does `dart analyze` inside the package; use `flutter analyze packages/canvas_detect` from the root.

API (T12): `CanvasDetector.detect(DetectorImage, {aspectHint})` → `Detection(quad, confidence)`; `DetectorImage` is 8-bit RGBA, EXIF-oriented (the app decodes, since OpenCV can't read HEIC); corners are normalized `Corner`s in a `Quad` (TL, TR, BR, BL); `Detection.isLowConfidence` below 0.5. `StubCanvasDetector` (5% inset, confidence 0) stands in until T13; the app reaches the detector through `canvasDetectorProvider`.

**Resolved in T7:** OpenCV runs under plain `dart test`, so everything stays in `packages/canvas_detect` (no `canvas_detect_opencv` split) and the evaluation can be a CLI. The package depends on `dartcv4` — the pure-Dart bindings that `opencv_dart` wraps for Flutter — which builds its native library through Dart build hooks, so the same dependency works in `dart test`, `flutter test`, and the app. `packages/canvas_detect/test/opencv_smoke_test.dart` keeps this checked in CI.

### 6.2 Algorithm

As built in T13, made stable in T13b (`OpenCvCanvasDetector`; the app passes a copy ≤ 1000 px on the long edge, §3.8):

1. Work on a copy ≤ 1000 px on the long edge.
2. **Binary edges:** Gaussian blur of grayscale and **chroma** (max − min of R, G, B) → Canny with median-based thresholds → OR → 3×3 dilation. (Canvas vs. wall often differ more in colour than brightness.) Chroma replaced HSV saturation in T13b: saturation divides by brightness, so in dark areas a ±1 pixel change swings it wildly and turns noise into edges and spurious candidates. *Tried and dropped:* Lab-channel edges after a bilateral filter (the auto-crop prototype's approach) picked up too much background clutter; Canny thresholds from a gradient-strength percentile were worse at every setting tried.
3. **Contour candidates:** `findContours` → convex hull → `approxPolyDP` (several tolerances) → quadrilaterals.
4. **Line candidates** (edges broken by clamps, hands, frames): `HoughLinesP` segments clustered into near-horizontal and near-vertical lines, plus the strongest standard-Hough lines (finds long faint edges), plus the photo's borders (canvases running off the photo); every pair × pair is a candidate.
5. **Score** (`scoring.dart`, tunables in `ScoringParams`): edge support per side (ends skipped; each point counts gradually, from 0 at half the edge threshold to 1 at 1.5×, so tiny image changes move the score a little instead of flipping points in or out), as 0.5·mean + 0.5·weakest side; × area^0.3 (rejected < 15%); × corner-angle term; × a **rectangle-plausibility** term: the quad must be the image of a rectangle through a camera with a focal length 0.6–1.6× the long edge (Zhang & He's whiteboard method; > 3° from a right angle in 3D is penalised); × aspect match when the project has a ratio; × a penalty per side on the photo border (at most one).
6. **Choose:** the best, unless a quad **nested just inside it** (≥ 80% of its area) scores within 10% — the outer one is then usually a ledge, the canvas's side or a frame (from the prototype, limited to thin steps so shapes painted in the picture don't win).
7. **Refine** at the input resolution, coarse then fine (search 1.6%, then 0.3% of the diagonal; wide enough to reach the canvas from a ledge a little below it): each side is fitted (robust line fit, sub-pixel peaks) to the edge it lies on, and corners are the intersections of neighbouring sides — more reliable than refining corners alone, which clamps and the easel often cover. Where a side has two strong edges close together (face and side of the canvas), the innermost one at least 0.6× as strong wins.
8. **Inset** every side by 0.1% of the diagonal: a crop missing a sliver of canvas looks better than one showing background.
9. **Not used: consensus.** Detecting on three slightly varied copies (as is, lightly blurred, 85% size) and taking each corner's median removed the last run-to-run flips in T13b but tripled the time (~305 ms on a Mac) without passing more photos, so it was left out. If stability matters more later, run the copies in parallel isolates, or only for close calls.
10. **Confidence** = min(normalized score, weakest side's support). *Not calibrated:* on the evaluation set no signal (score, weakest side, margin over a different quad) separated right from wrong answers, so wrong detections can score high; revisit with more photos (§9).

Performance target: under 500 ms on a mid-range phone, run in an isolate.

### 6.3 Output aspect ratio

When applying an auto-crop:

- If the project has a size or ratio → use it for `output`.
- Otherwise → estimate from the quad (average opposite edge lengths) for M1. A proper perspective-aware aspect estimate can be added later if results look stretched.

### 6.4 Evaluation set

- `test/fixtures/expected.json`: `[{ "file": "easel-01.jpg", "corners": [[x,y]×4], "notes": "clamp covers top edge" }]` in normalized coordinates.
- Photos: 20–40 real shots covering an easel, a wall, an angled view, a busy studio, framed and unframed work, poor lighting, partial occlusion. Downscaled to ~1600 px; EXIF stripped except orientation.
- Corners are created with the debug **Copy corners as JSON** action (§3.8) after manual adjustment.
- **How the T13 set was made:** 18 photos (`tool/make_eval_fixtures.dart` downscales originals kept in the git-ignored `eval-originals/` and strips all metadata). For 15, the detector's proposals were reviewed on zoomed review sheets (`tool/annotation_sheets.dart`) and approved as the reference; the 3 it gets wrong (14, 16, 17: dark canvas against a dark, busy yard) were marked by hand in the app. `notes` says which. So the set measures the detector honestly on those 3 and guards against regressions on the other 15; new photos should be hand-marked.
- **Corrections (T13b):** three approved proposals had corners outside the canvas that the review missed: 03's top-left (57 px above), 08's bottom (20–35 px below), 10's right side (20–37 px outside). The improved detector found the true corners; after checking zoomed sheets the user approved the corrections, and `notes` records each. Detector-proposed references can share the detector's mistakes, another reason to hand-mark new photos.
- **Repo visibility**: these are the user's paintings. If the repository is ever made public, decide whether to keep them (see §9).

### 6.5 Metrics

- Per photo: maximum corner error as a percentage of the image diagonal.
- Success = max corner error ≤ 2% of the diagonal.
- Report success rate and mean error; the CLI prints a table and exits non-zero if the success rate drops below the committed baseline.
- Initial target: ≥ 80% success on the set; tuned during M1 and recorded as the baseline.
- As built (T13, T13b): `dart run bin/evaluate.dart [--runs N] [--check | --write-baseline]` downscales each fixture to the app's 1000 px and runs it N times (default 10): once as decoded, then with different invisible ±1 pixel noise. It prints passes, **stable** runs (noisy runs within 0.5% of the clean run's answer), median and worst error, confidence and time per photo, and lists photos that pass clean but fail with noise; the success rate is over all runs. `--check` fails if the rate drops more than 0.05 below `test/fixtures/baseline.json` (decoders differ between the Mac that records the baseline and CI's Linux); CI runs it.
- **Why several runs:** in T13 the detector was unstable: near-ties between candidates decided by hard cut-offs, and saturation noise in dark areas, meant a ±1 pixel difference (another platform's JPEG decoder, Android's decoder in the app) could change the answer. On one run per photo the Mac got 15 / 18 and CI 14 / 18, with different photos failing. T13b reduced this (below); the evaluation keeps several runs so it stays honest.
- T13 baseline: 72.8% of runs (131 / 180); 61% of noisy runs agreed with the clean run.
- **Baseline (T13b, agreed):** 78.3% of runs (141 / 180), 78.4% stable, median error 0.24%, ~110 ms per photo on an M-series Mac. 13 photos pass every run; 06 fails 2 of 10 runs, 15 (bottom on the ledge) 7 of 10; 14, 16, 17 (dark canvas against a dark, busy yard) fail. Below the 80% target; agreed with the user rather than adding consensus (§6.2). Verified in the app on the emulator (T13).

---

## 7. Project setup and tooling

- `flutter create` with org `com.example`, app name `filbert`; Android only (other platforms added in their milestones).
- Pub workspace at the repo root: the app plus `packages/canvas_detect`.
- Dependencies (latest stable at the time of the setup task; versions recorded in `pubspec.yaml`): `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`, `build_runner`, `drift`, `drift_flutter`, `drift_dev`, `go_router`, `image_picker`, `uuid`, `path_provider`, `dartcv4`, `flutter_lints`, `material_ui`, `exif`, `image_picker_android`. Any additional package needs confirmation.
- `exif` (pure Dart; JPEG/HEIC/PNG/WebP) reads orientation and capture time without decoding pixels. `image_picker_android` is listed directly only to switch on Android's photo picker (it is already part of `image_picker`).
- `material_ui` is Flutter's Material library, now shipped as a package; `package:flutter/material.dart` is deprecated since Flutter 3.47, and `flutter create` adds `material_ui` by default. Import `package:material_ui/material_ui.dart`, never `package:flutter/material.dart`.
- OpenCV is added in the rendering task (T7) rather than the setup task: it is a heavy native build and nothing uses it earlier.
- OpenCV comes from `dartcv4` (the pure-Dart package behind `opencv_dart`), used by both the app and `packages/canvas_detect`. Its build hook compiles a small C wrapper with CMake and links OpenCV static libraries that it downloads prebuilt from the maintainer's GitHub releases (`rainyl/opencv.full`); the first build per target takes a few minutes, later builds are cached in `.dart_tool/hooks_runner`. Settings live under `hooks: user_defines: dartcv4:` in the root `pubspec.yaml`: the default modules (core, imgproc, imgcodecs) cover M1 including T13; CMake and Ninja come from the Android SDK (`prefer_android_cmake` / `prefer_android_ninja`); macOS uses the Ninja generator (the default, Xcode, isn't needed). Size: `libdartcv.so` is ≈ 9.5 MB per ABI uncompressed (arm64, debug); the arm64 profile APK is 32.8 MB. Tree-shaking (`treeshake: true`, tried in T15): release APKs split per ABI go from 30.8 to 27.2 MB for arm64 (`libdartcv.so` 9.5 → 5.9 MB). Only arm64 compared cleanly; the other ABIs' baselines were already built with a keep-list (next point). The app worked with it on the emulator, but it is **not enabled**. See the next point.
- **dartcv4 keep-list hazard (2.3.0+, found in T15).** Every AOT build (profile or release) makes dartcv4's link hook write the native functions that build calls to `.dart_tool/hooks_runner/shared/dartcv4/dartcv_keep.txt`; every later native build of OpenCV, for any target and **with or without `treeshake`**, exports only those functions. So after a profile or release build, the next rebuild of the library (new target, changed dependencies or hook options) can lack functions other code calls, and fails at runtime with `Couldn't resolve native function`. Seen in T15: the benchmark lacked `cv_randu`, and the macOS library used by `flutter test` lost `cv_getPerspectiveTransform`. CI is unaffected (it makes no AOT builds). **Workaround:** after any profile or release build, run `rm -rf .dart_tool/hooks_runner/shared/dartcv4/{dartcv_keep.txt,build,link}` (the next build recompiles OpenCV, ≈ 10 minutes per target).
- Flutter version: 3.50.0 stable, pinned in CI (`.github/workflows/ci.yml`); bump it there and locally together.
- CI (GitHub Actions, using `subosito/flutter-action`): `flutter pub get` → `build_runner` → `flutter analyze` → `flutter test` (app, then `dart test` in `packages/canvas_detect`) → `canvas_detect` evaluation (from T13) → Android debug build.
  - Runs on `main` are never cancelled (superseded PR runs are), because only caches saved on `main` are shared with PRs.
  - A second job, `integration` (T15), runs `flutter test integration_test` on an x86_64 API 35 emulator (`reactivecircus/android-emulator-runner`, KVM). It runs alongside the first job, caches its own OpenCV build (x86_64), and caches a booted AVD snapshot.
  - Since OpenCV (T7), CI frees disk space first (each native OpenCV build takes ~1 GB and the runner has ~14 GB free; without this the APK build ran out of space), caches `.dart_tool/hooks_runner` keyed on the pubspec files so OpenCV is rebuilt only when dependencies change, and builds the debug APK for arm64 only.

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
| Integration (emulator; `integration_test/m1_flow_test.dart`, T15) | New project → add photo → auto-crop review → apply → undo → redo → revert. Real database (in memory), files (temp folder), rendering and OpenCV detection; only the photo picker is faked, handing over a generated canvas photo (`test/support/synthetic_canvas.dart`, checked on the host by `synthetic_canvas_test.dart`) |
| Migrations | Schema v1 dump committed; harness ready for v2 |

---

## 9. Open items to resolve during implementation

| Item | Resolve in |
|---|---|
| ~~Does `opencv_dart` run under plain `dart test`?~~ Resolved in T7: yes, via `dartcv4`; no package split (§6.1). | — |
| ~~Can OpenCV decode camera HEIC?~~ Resolved: import stores HEIC as-is (T6); OpenCV can't decode it, so rendering uses the platform decoder (T7, §5.1). | — |
| ~~Preview-render latency on a real phone~~ Resolved in T15: ≈ 0.1–0.4 s on a Pixel 11 (§5.1). | — |
| ~~Detection time on a real phone (target < 500 ms)~~ Resolved in T15 (`tool/render_benchmark.dart`): on a Pixel 11 ≈ 0.14 s (12 MP) and ≈ 0.21 s (48 MP) including decode, ≈ 0.09 s for the detector itself; emulator ≈ 0.2–0.3 s; Mac ≈ 0.12 s. | — |
| Preview latency and detection time on a mid-range phone: only a high-end Pixel 11 was measured; with detection at under half the target there, a mid-range phone is expected to pass, but check it when one is available (same benchmark; also frame pacing, see m1-tasks notes) | After M1 |
| Detection confidence calibration (wrong answers can score high, §6.2), dark canvases on busy backgrounds, the remaining flips (06, 15); needs more evaluation photos | After M1 |
| dartcv4's keep-list (§7) breaks native builds after any profile or release build; until dartcv4 fixes it, clear it after such builds. Tree-shaking (≈ 3.6 MB off the arm64 APK) depends on the same list, so enable it only once that's fixed, or with a release process that builds from a clean cache twice and smoke-tests the result | Before release |
| Real application ID before the first Play Store upload | Before release |
| If the repo becomes public: keep the painting fixtures in it, or move them out? | Before making the repo public |

# Filbert Paint Studio — High-Level Design

Status: Draft v1 (2026-11-12)
Source requirements: [paint-app-product-description.md](paint-app-product-description.md)
Rules for implementation: [engineering-guidelines.md](engineering-guidelines.md)

This document captures the architecture, technology choices, integration approach, and milestone plan for Filbert Paint Studio ("Filbert" for short). Each milestone will get its own detailed design and implementation plan; those documents may refine anything here, but should call out deviations explicitly.

---

## 1. Goals and non-goals

**Goals**

- Help oil painters through prep, in-progress, and completion stages with simple, focused photo tools.
- Every feature is optional and usable on its own (e.g. someone who only wants auto-crop or print prep should find that path immediately).
- Run on Android first, then macOS, iOS, and web, from one codebase.
- Let a user move between devices mid-project, with data synced through storage the user already owns.
- Integrate with other apps (camera, Google Photos, AI assistants, Instagram, printers) without Filbert operating any server.

**Non-goals**

- No Filbert backend, accounts, or hosted service. ("App only, not a service.")
- No in-app LLM calls in the first release (hand-off only — see §8.3). The design keeps the door open for bring-your-own-API-key later.
- No general-purpose photo editor (exposure, retouching, layers). Edits are limited to what painters need: crop/perspective/rotate and viewing aids.
- No multi-user collaboration; sync is between one user's own devices.

---

## 2. Decision summary

| Area | Decision |
|---|---|
| App framework | **Flutter** (Dart), single codebase for Android, macOS, iOS, web |
| State management / DI | **Riverpod** (with `riverpod_generator`) |
| Local metadata store | **SQLite via Drift**; image files on disk (OPFS on web) |
| Edit model | Non-destructive: originals immutable, edits stored as parameters, rendered on demand |
| Identity | **UUIDv7** for every record (projects, images, prompts); names are plain mutable fields |
| Sync | User's **Google Drive `appDataFolder`**; per-record JSON + immutable image blobs; incremental via Drive Changes API |
| Conflicts | Images merged as a union; deletions as tombstones; same-record conflicts prompt the user, preselecting the newest |
| Sign-in | Google Sign-In, requested only when the user enables sync or Google Photos import |
| Google Photos | **Google Photos Picker API** (the Library API no longer allows reading a user's library) |
| Auto-crop | **OpenCV** (FFI via `dartcv4`, the pure-Dart core of `opencv_dart`; OpenCV.js on web) + own corner-adjust UI + perspective correction |
| Live viewing aids | GPU: Flutter color filters / fragment shaders |
| Export rendering | `image` package + OpenCV, full resolution, to temp JPEG/PNG/PDF |
| Ask AI | **Hand-off** via share sheet (+ clipboard/URL fallback), behind an `AiProvider` interface for a future API-key mode |
| Instagram | Share intent / share sheet on mobile; export + open instagram.com on desktop/web |
| Print | `printing` + `pdf` packages: true-size PDF with tiling, overlap, alignment marks, scale-check ruler |
| CI | GitHub Actions: analyze, unit, widget, and golden tests |

---

## 3. Architecture

### 3.1 Layers

```
┌──────────────────────────────────────────────────────────────────┐
│ UI (Flutter widgets)                                             │
│  Project list · Project screen · Photo screen · Crop · Compare   │
│  Ask AI · Print setup · Share · Notebook · Settings · Conflicts  │
├──────────────────────────────────────────────────────────────────┤
│ State (Riverpod providers / notifiers)                           │
│  watch DB streams, expose AsyncValue to UI, hold view state      │
├──────────────────────────────────────────────────────────────────┤
│ Domain services (pure Dart, interface-first, fakeable in tests)  │
│  ProjectRepository · ImageRepository · RenderService             │
│  CanvasDetector · SyncEngine · AiProvider · ShareService         │
│  PrintService · PhotoSource                                      │
├──────────────────────────────────────────────────────────────────┤
│ Infrastructure                                                   │
│  Drift/SQLite · FileStore · Google Drive client · Photos Picker  │
│  OpenCV (FFI / JS) · camera · share_plus · printing · platform   │
│  channels (Android intents, macOS/iOS share sheet)               │
└──────────────────────────────────────────────────────────────────┘
```

Rules:

- UI talks only to providers; providers talk only to domain services; only infrastructure touches plugins, files, or the network.
- Every domain service is an interface delivered by a Riverpod provider, so tests and future alternatives (e.g. an API-key `AiProvider`, a Dropbox `SyncBackend`) swap in by overriding one provider.
- The DB is the single source of truth for the UI. Sync writes to the DB; Drift's reactive queries push changes to the screen automatically.

### 3.2 Code layout (proposed)

```
lib/
  app/              routing (go_router), theme, app shell
  core/
    db/             Drift schema, DAOs, migrations
    files/          FileStore (originals, renders cache, thumbnails)
    ids/            UUIDv7 generation
    imaging/        edit model, RenderService, shaders
  features/
    projects/  photo_viewer/  crop/  autocrop/  view_aids/  compare/
    ai/  print/  share/  notebook/  sync/  settings/
packages/
  sync_engine/      pure-Dart sync logic (no Flutter dependency; created in M3)
  canvas_detect/    detector interface + OpenCV implementations
```

The sync engine and canvas detector are separate packages so they can be tested heavily in isolation.

### 3.3 Key packages (to be validated per milestone)

`flutter_riverpod`, `riverpod_generator`, `drift`, `drift_flutter`, `go_router`, `camera` / `image_picker`, `file_picker`, `desktop_drop` (macOS), `google_sign_in`, `googleapis` (Drive v3), `http` (Photos Picker REST), `share_plus`, `gal` (save to gallery, M2), `printing`, `pdf`, `dartcv4`, `image`, `path_provider`, `workmanager` (Android background sync), `uuid`.

---

## 4. Data model

All records carry `id` (UUIDv7), `createdAt`, `updatedAt`, `updatedByDeviceId`, and `deletedAt` (tombstone; null when live). Local-only sync bookkeeping (dirty flag, last-synced remote revision) lives in separate columns that are never uploaded.

### 4.1 Entities

**Project**

| Field | Notes |
|---|---|
| `name` | Mutable display name |
| `nameIsDefault` | True while the name is the auto-generated date name (used for duplicate-name handling, §6.6) |
| `sizeSpec` | Either an aspect ratio (`w:h`) or a physical size (`w`, `h`, `unit` = in/cm) |
| `startNotes` | Goals, focus, style; optionally included in AI prompts |
| `finalNotes` | Post-completion notes (M7) |
| `status` | `inProgress` / `completed` |
| `referenceImageId` | Optional. The only record of which image is the reference (images carry no role field, so there's one source of truth after sync) |
| `finalImageId` | Optional (M7); same approach as `referenceImageId` |

**ViewPrefs** (M2) — per-project viewing-aid settings (grid, value bands, color count, compare photo and opacity) as their own record keyed by project, so changing them neither reorders the project list nor conflicts with project edits during sync. See [milestones/m2-design.md](milestones/m2-design.md) §4.1.

**Image** (metadata; the pixels live in a blob)

| Field | Notes |
|---|---|
| `projectId` | Owning project |
| `blobId` | Points at the immutable original file |
| `width`, `height`, `capturedAt`, `source` | Source = camera / device / googlePhotos / derived |
| `edits` | Current edit state (§5.1) |
| `derivedFrom` | For "Save as new image" copies: source image id + edit snapshot |

**Prompt** (M4) — user's custom AI prompts (built-in prompts ship as app assets).

**Device** (local) — this device's id and display name, used to label conflict choices.

### 4.2 Why images are separate records

Images are stored as their own records (not a list inside the project record) so that adding photos on two devices never conflicts: each new photo is a brand-new record and the sync result is simply the union. Only edits to the *same* image or the *same* project fields can conflict.

---

## 5. Image pipeline

### 5.1 Non-destructive edits

- Originals are written once and never modified.
- An image's `edits` field holds parameters:
  - `crop`: four corner points in normalized original coordinates, plus an optional output aspect ratio. One quad covers rectangular crops, straightened (fine-rotated) crops, and perspective-corrected auto-crops.
  - `quarterTurns`: 90° rotations applied to the output.
- **Undo**: each change pushes the previous edit state onto a per-image history (capped at 50 entries), stored locally and **never synced**. **Revert to original** is always available because the original is retained. The current edit state always syncs.

See [milestones/m1-design.md](milestones/m1-design.md) §4.2 for the exact format.

### 5.2 Permanent edits vs. viewing aids

| Kind | Examples | Stored where | Applied when |
|---|---|---|---|
| Permanent edits | crop, perspective, rotation | `Image.edits` | Always (display + export) |
| Viewing aids | grayscale, limited colors/values, gridlines, compare overlay | `ViewPrefs` (settings) / transient view state (on/off) | On screen when toggled; on export only if selected |

Viewing aids render live on the GPU (a fragment shader over the cropped image; grayscale is computed as perceived lightness, not a color matrix), so toggling and adjusting is instant even on large photos. Display uses a downsampled decode sized to the screen; thumbnails are cached.

"Limited values" are equal steps of perceived lightness (CIELAB L\*); "limited colors" is a k-means palette in CIELAB. See [milestones/m2-design.md](milestones/m2-design.md) §5.

### 5.3 Rendering for export

Anything leaving the app (share, print, AI, save to gallery, "Save as new image") goes through one `RenderService`:

```
original blob + edits + selected viewing aids ──▶ full-res render ──▶ temp JPEG/PNG (or PDF) ──▶ destination
```

- Each destination screen shows an **Include** checklist (grid, grayscale, limited colors) preset with sensible defaults: Instagram = clean color; Print = grid on if it's currently shown; AI = current view.
- Renders are cached locally per (image, edits, aids) key, so repeated exports are instant. Renders are **never synced**; each device renders for itself, which keeps Drive usage small.
- **Save as new image** persists a render as a new `derived` image record with its own blob, which then syncs like any photo.

### 5.4 Auto-crop

- `CanvasDetector` interface → OpenCV implementation (FFI on Android/macOS/iOS via `dartcv4`; OpenCV.js on web).
- Pipeline (initial): downscale → blur → edge detection + contour/line finding → choose the best convex quadrilateral (scored by area, rectangularity, and match to the project's aspect ratio when known) → return four corners plus a confidence score.
- UI: show detected corners as draggable handles with a magnifier loupe; user confirms; result is stored as the `crop` quad. Perspective correction happens at render time.
- Works on any image in a project (new camera shots or imported photos), not just at capture time.
- Quality is tracked with a test set of real painting photos (easel, wall, angled shots, busy studios) and expected corners; accuracy is reported in CI. If OpenCV heuristics prove insufficient, a small ML model can be added later behind the same interface.

---

## 6. Sync between devices

### 6.1 Approach

- Storage: the user's own Google Drive, in the hidden **`appDataFolder`** (scope `drive.appdata`). It doesn't clutter their Drive, costs Filbert nothing, and counts against the user's own quota.
- Sync is opt-in. With sync off, the app is fully functional offline with no sign-in.
- The local SQLite DB is always the source of truth for the UI; sync is a background process reconciling it with Drive.

### 6.2 Remote layout (logical)

```
appDataFolder/
  manifest.json                 schemaVersion, created-by app version
  projects/<project-uuid>.json  project record
  images/<image-uuid>.json      image metadata record (incl. edits)
  blobs/<blob-uuid>.<ext>       original image files (immutable)
  thumbs/<blob-uuid>.jpg        small previews for fast project lists
  prompts/<prompt-uuid>.json    custom AI prompts (M4)
```

Every JSON record includes `schemaVersion` so devices running different app versions can read each other's data (older apps ignore unknown fields; breaking changes bump the version and newer apps migrate on read). The physical Drive layout (folders vs. flat files with `appProperties`) is an M3 decision.

### 6.3 Export/import

Records are converted with Drift's generated `toJson()` / `fromJson()`. The same code powers a local **Export project** feature (JSON + images in a folder or `.zip`), giving users a readable backup independent of sync.

### 6.4 Sync algorithm (outline)

1. **Trigger**: app open, app resume, after local changes (debounced), periodic background (Android `WorkManager`; best-effort on iOS), and a manual **Sync now**.
2. **Push**: for each dirty local record — upload any new blobs **first**, then the record JSON (so a record never references a missing blob). Use the remote revision we last saw as a precondition; if the remote changed since, treat as a potential conflict instead of overwriting.
3. **Pull**: fetch remote changes since the stored page token using the **Drive Changes API** (`spaces=appDataFolder`). Apply each changed record to the DB in a transaction. Blobs download lazily (thumbnail first; originals on open or eagerly on Wi-Fi, per a setting).
4. **Reconcile**:
   - Remote record we don't have → insert.
   - Changed remotely, not locally → overwrite local.
   - Changed locally, not remotely → keep local (pushed in step 2).
   - Changed on both → **conflict** (§6.5).
5. Store the new page token.

### 6.5 Conflict handling

- **New images on both devices**: no conflict; the union is kept.
- **Same record edited on both** (e.g. project renamed on both, notes edited on both, same image re-cropped on both): the user is shown both versions with device name and time, and the **most recently updated one is preselected**. Conflicts are resolved per record, and pending conflicts are surfaced unobtrusively (badge) rather than blocking work.
- **Deleted on one, edited on the other**: also prompted; the more recent action is preselected.
- **Deletions** are tombstones (`deletedAt`) so deleted items don't reappear from another device. Blobs of tombstoned images are purged from Drive after a grace period.
- "Most recent" uses device clocks; since it is only a suggestion to the user, modest clock skew is acceptable.

### 6.6 Duplicate project names

Two devices offline can each create a project with the default name (e.g. "2026-11-12"). They have different UUIDs, so both survive sync. Then:

- If **both** names are still auto-generated defaults (`nameIsDefault`), the newer one is renumbered ("2026-11-12 (2)") — the same rule used on a single device.
- If the user typed either name, nothing is renamed; the list distinguishes them by thumbnail and date.

A **Merge projects** action (move images from one project into another) is a possible future addition, not scheduled.

### 6.7 Authentication

- Google Sign-In, asking only for the scopes needed: `drive.appdata` when sync is enabled, the Photos Picker scope when Google Photos import is first used (incremental authorization).
- Tokens are stored by the platform sign-in SDK / secure storage, never in the DB or synced data.
- Before public release, the Google Cloud OAuth consent screen needs verification for the requested scopes; scope classification and verification requirements will be confirmed in M3.

---

## 7. Platforms

| Concern | Android (M1) | macOS (M3) | iOS (M8) | Web (M9) |
|---|---|---|---|---|
| Camera | `camera` / `image_picker` | Import from files / Photos picker (no camera flow) | `camera` / `image_picker` | File input with `capture` |
| Device photos | System photo picker | File picker + drag-and-drop | PHPicker | File picker |
| Local DB | Drift (native SQLite) | Drift (native) | Drift (native) | Drift (SQLite WASM + OPFS) |
| Image files | App documents dir | App container | App documents dir | OPFS |
| Auto-crop | OpenCV FFI | OpenCV FFI | OpenCV FFI | OpenCV.js |
| Background sync | WorkManager | While running | BGTaskScheduler (best-effort) | While open |
| Share | Android intents | NSSharingServicePicker | UIActivityViewController | Web Share API (where supported) + download fallback |
| Print | Android print framework | macOS print dialog | AirPrint | Browser print |
| Distribution | Google Play | Mac App Store or notarized DMG (TBD) | App Store | Static hosting (TBD) |

Desktop layouts (macOS, web on large screens) use the extra space — e.g. side panel for tools, keyboard shortcuts — but share the same feature code.

Web is still "app only": it is served as static files with no backend. Hosting choice (e.g. GitHub Pages) and the OAuth web client origin are M9 decisions.

---

## 8. Integrations with other apps

### 8.1 Photo sources

- **Device / camera**: platform pickers and camera plugin (table above). Imported photos are copied into Filbert's file store so the project doesn't depend on the original staying in the gallery.
- **Google Photos (M3)**: via the **Photos Picker API**. Since March 2025, third-party apps can no longer browse a user's library through the Library API; the Picker is the supported path. Flow: create a picker session → open the session's `pickerUri` (in a browser / custom tab) → poll the session until the user finishes → list the picked media items → download each at full resolution using the auth token → copy into the project.

### 8.2 Sharing out (general)

`ShareService` wraps per-platform sharing of one or more rendered files plus optional text. It always prepares files via `RenderService` (§5.3), so sharing never mutates originals.

### 8.3 Ask AI (M4) — hand-off mode

1. User picks a built-in prompt or writes their own; optionally includes the reference photo (and project start notes) and selects viewing aids via the Include checklist.
2. Filbert renders the image(s) and composes the prompt text.
3. Hand-off:
   - **Android / iOS**: share sheet with images + text, so the user picks the Claude or ChatGPT app (or any other).
   - **macOS / web**: share sheet / Web Share where available; otherwise fallback.
   - **Fallback (all platforms)**: the prompt text is always also copied to the clipboard (some share targets drop text), and on desktop/web the app offers to open `claude.ai` or `chatgpt.com` with the rendered images saved/copied for attaching.
4. Since answers don't come back automatically, the project notes offer a quick **Paste AI response** action.

**Future API-key mode**: `AiProvider` is an interface with a `HandoffAiProvider` implementation now. A later `ApiKeyAiProvider` (user-supplied Claude/OpenAI key stored in secure storage, called directly from the device — still no Filbert server) would return responses in-app and save them to the notebook. The prompt-building and image-selection code is shared by both.

### 8.4 Instagram (M6)

- **Android**: share intent targeted at the Instagram app (single image or multiple images for a carousel). The exact intent forms for feed vs. stories, and multi-image behavior, are verified in M6.
- **iOS**: share sheet (Instagram's share extension).
- **macOS / web**: no Instagram app; export the rendered images (and copy a caption) and open instagram.com, which supports posting from the browser.
- The share screen lets the user choose the final photo plus optionally the reference and any progress photos, in order. An optional "reference vs. final" side-by-side composite is a nice-to-have for M6.

### 8.5 Printing (M5)

- Output is a PDF built with the `pdf` package and sent via `printing` (or saved/shared for a print shop).
- Modes: **true size** (matches the project's physical size), **custom size**, or **fit to page**.
- **Tiling** when the print is larger than the paper: choose paper size (Letter, Legal, Tabloid, A4, A3, …), margins, and overlap; each page gets row/column labels, alignment/crop marks, and an overview page showing the layout.
- A **scale-check ruler** is printed on each page so users can confirm the printer didn't apply "fit to page" scaling; the UI reminds users to print at 100%.
- Viewing aids (grid, grayscale) can be included via the Include checklist; the grid can be specified in physical units (e.g. 2-inch squares) to match the canvas.

---

## 9. Privacy and security

- No Filbert servers; no analytics in v1 (any future crash reporting would be opt-in).
- User data lives only on their devices and in their own Drive `appDataFolder`.
- OAuth tokens and any future API keys live in platform secure storage only.
- Minimal, incremental Google scopes, requested at the moment the related feature is first used.

---

## 10. Testing strategy

- **Unit tests**: repositories, edit model, render parameter math, prompt building, print tiling math.
- **Sync engine**: pure-Dart tests against a fake Drive backend covering offline edits on multiple simulated devices, conflicts, tombstones, interrupted uploads, schema-version mismatches, and duplicate default names.
- **Golden tests**: rendered output of crop/perspective, grayscale, limited colors, grid, and print pages.
- **Auto-crop evaluation**: a curated photo set with expected corners; CI reports detection accuracy so regressions are visible.
- **Widget / integration tests**: key flows on an Android emulator (create project → add photo → auto-crop → undo).
- **CI**: GitHub Actions running `flutter analyze` and the test suites on each push; platform builds added as each platform lands.

---

## 11. Milestones

Each milestone ends with a usable, shippable app on its platforms. Detailed design and implementation docs will be written per milestone.

### M1 — Core projects, photos, and cropping (Android)

- App skeleton: Flutter project, Riverpod, Drift, routing, theme, CI.
- Sync-ready data model from day one: UUIDv7 ids, timestamps, tombstones, `schemaVersion`, device id (sync itself comes in M3).
- Project list; create, rename, and delete projects.
- Project setup: name (date default with numbering), size or aspect ratio (common presets + custom), start notes.
- Select a reference photo (device or camera, or none); add more photos to a project; delete photos.
- Full-screen photo screen with minimal UI and a menu.
- Manual crop/rotate: defaults to the project's aspect ratio; common ratios and freeform.
- Auto-crop: OpenCV canvas detection, corner adjustment, perspective correction.
- Non-destructive edits: originals retained, undo, revert to original.

**Exit criteria**: a user can run a full project on an Android phone — create, add reference and progress photos, auto-crop them — and all edits are undoable.

### M2 — Viewing aids and compare (Android)

- Gridlines (by count or physical spacing tied to canvas size; color/width).
- Grayscale view.
- Limited values / limited colors.
- Compare: overlay any two project photos with adjustable transparency.
- `RenderService` export pipeline; **Save as new image**; save render to device gallery.

**Exit criteria**: a painter can check values and compare progress to the reference at the easel, and export what they see.

### M3 — macOS and sync

- macOS app: desktop layout, file picker and drag-and-drop import, keyboard shortcuts.
- Google Sign-In (incremental scopes); settings to enable/disable sync.
- Sync engine over Drive `appDataFolder`: push/pull, Changes API, lazy blob download, background sync on Android.
- Conflict UI; duplicate-name handling.
- Google Photos import via the Photos Picker API (Android + macOS).
- Export project (JSON + images).

**Exit criteria**: create a project on the Mac, continue on the phone, and see changes on both; conflicts are resolved through the prompt; nothing is lost when both devices edit offline.

### M4 — Ask AI (hand-off)

- Built-in prompt library + custom prompts (synced).
- Include reference / start notes / viewing aids options.
- Hand-off via share sheet with clipboard and URL fallbacks per platform.
- Paste AI response into notes.
- `AiProvider` interface in place for future API-key mode.

### M5 — Print setup

- True-size, custom-size, and fit-to-page modes.
- Tiling across paper sizes with overlap, labels, alignment marks, overview page, scale-check ruler.
- PDF export for print shops; print dialog on each platform.

### M6 — Share to Instagram

- Choose final / reference / progress photos and order; carousel where supported.
- Android intent and iOS-ready share path; desktop export + open instagram.com.
- Optional side-by-side reference/final composite.

### M7 — Notebook

- Mark an image as the final painting; mark project completed.
- Final notes.
- Browsable log of past projects (gallery view, timeline of progress photos per project), search and filter by name/notes/date/status.

### M8 — iOS

- iOS build: camera, PHPicker, share sheet, AirPrint, best-effort background sync.
- App Store packaging.

### M9 — Web

- Drift on SQLite WASM + OPFS; OPFS image storage.
- OpenCV.js canvas detector.
- Web Share API with download/clipboard fallbacks; browser printing.
- Google Sign-In for web; static hosting.

---

## 12. Open questions and future work

| Item | When to decide |
|---|---|
| Does per-image undo history sync, or stay local? | M1 design |
| Physical Drive layout (folders vs. flat files with `appProperties`); eager vs. lazy original downloads | M3 design |
| Google OAuth scope classification and verification requirements | M3 |
| macOS distribution: Mac App Store vs. notarized DMG | M3 |
| Exact Instagram intent behavior (feed vs. stories, multi-image) | M6 |
| Web hosting and OAuth origin | M9 |
| Future: bring-your-own-API-key AI mode | After M4 |
| Future: Merge projects action | Unscheduled |
| Future: additional sync backends (Dropbox, iCloud, WebDAV) behind a `SyncBackend` interface | Unscheduled |
| Future: ML-based canvas detection if OpenCV accuracy is insufficient | Based on M1 evaluation |

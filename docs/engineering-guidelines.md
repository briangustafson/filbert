# Filbert — Engineering Guidelines

The rules every change must follow. Rationale lives in [high-level-design.md](high-level-design.md); this doc is the short, prescriptive version. Milestone docs may add rules; if one changes a rule here, update this doc in the same change.

## Settled technology

- Flutter (Dart), Riverpod with `riverpod_generator`, Drift (SQLite), `go_router`.
- Images as files on disk (OPFS on web); metadata in SQLite.
- Auto-crop: OpenCV (`opencv_dart` FFI; OpenCV.js on web) behind a `CanvasDetector` interface.
- Sync (M3+): user's Google Drive `appDataFolder`; Google Photos via the Photos Picker API.
- AI: hand-off via share sheet only, behind an `AiProvider` interface (API-key mode is future work).
- Adding a package not listed in the design docs requires confirmation.

## Architecture

- Layers: UI → Riverpod providers → domain services → infrastructure. UI never touches Drift, files, plugins, or network directly.
- Every domain service is an interface exposed through a provider, so tests can override it.
- The DB is the UI's source of truth; screens watch Drift streams.
- Pure-Dart logic that must be heavily tested (sync engine, canvas detection) lives in `packages/`, not `lib/`.

```
lib/app/        routing, theme, shell
lib/core/       db/, files/, ids/, imaging/
lib/features/   one folder per feature (projects, photo_viewer, crop, autocrop, ...)
packages/       canvas_detect/ (M1), sync_engine/ (M3)
```

## Data (sync-ready from M1)

- Every record id is a **UUIDv7**; never key anything by name.
- Every record has `createdAt`, `updatedAt`, `updatedByDeviceId`, `deletedAt`. Deletion sets `deletedAt` (tombstone); never hard-delete synced records.
- Image records are separate from project records (never an embedded list), so new images on two devices merge without conflict.
- **Originals are immutable.** Crop/rotation/perspective live in `Image.edits` as parameters; renders are derived, cached locally, and never synced. Undo history is local only.
- Designations like "the reference" live as a pointer on the project (`referenceImageId`), never as a flag on the image.
- Viewing aids (grid, grayscale, limited colors, compare) are view state, not edits; they're applied on export only when selected.
- Serialized records carry `schemaVersion`. Schema changes require a Drift migration and a migration test.
- Local-only sync bookkeeping (dirty flags, remote revisions) is never serialized.

## Code

- Follow `flutter_lints`; `flutter analyze` must be clean.
- Generated files (`*.g.dart`, `*.drift.dart`) come from `build_runner`; never hand-edit them.
- No secrets or tokens in the DB, logs, or synced data; use platform secure storage.
- Each feature must be usable on its own (e.g. a user who only wants auto-crop).

## Testing

- Unit tests for domain logic; golden tests for anything that renders images (crop, filters, grid, print pages).
- Auto-crop changes are checked against the evaluation photo set; report accuracy before/after.
- Sync logic is tested against a fake Drive backend with multiple simulated devices.

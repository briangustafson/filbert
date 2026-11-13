# Filbert Paint Studio ("Filbert")

Flutter app for oil painters. Android first, then macOS, iOS, web. App only — no Filbert backend.

## Docs

- Before any code change, read `docs/engineering-guidelines.md` (the rules) and the current milestone's `docs/milestones/mN-design.md` and `mN-tasks.md`.
- Background: `docs/high-level-design.md`, `docs/paint-app-product-description.md`.

## Workflow

- Ask before any decision the docs don't settle (packages, schema, UX, algorithms); give a recommendation.
- One task from `mN-tasks.md` at a time, ≈ one PR: short plan → approval → implement → test → tick the checkbox.
- Done means tests pass and `flutter analyze` is clean.
- Stay in the current milestone's scope; note later ideas in the task file.
- If a change alters a design decision or rule, update the doc in the same change.
- Never commit or push unless asked.

## Commands

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```

(The Flutter project is created by the first M1 task.)

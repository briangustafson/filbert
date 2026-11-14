# Filbert Paint Studio

A Flutter app for oil painters. See [docs/](docs/) for the product description, design, and milestone plans, and [CLAUDE.md](CLAUDE.md) for the development workflow.

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
(cd packages/canvas_detect && dart test)
```

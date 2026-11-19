# Filbert Paint Studio

A Flutter app for oil painters. See [docs/](docs/) for the product description, design, and milestone plans, and [CLAUDE.md](CLAUDE.md) for the development workflow.

This project is still in active development. It will be available to use soon — stay tuned!

All rights reserved: the code is public to read but not yet licensed for use, copying or distribution.

```bash
flutter pub get
dart run build_runner build
flutter analyze
flutter test
(cd packages/canvas_detect && dart test)
(cd packages/sync_engine && dart test)
```

The end-to-end test runs on an Android emulator. Afterwards it uninstalls the app, which deletes the app's data on that device, so never point it at a phone you use:

```bash
flutter test integration_test -d emulator-5554
```

import 'package:material_ui/material_ui.dart';

/// Material 3 with a neutral-gray palette: no saturated accents near images,
/// so the UI doesn't skew the painter's color/value perception (m1-design §2).
abstract final class FilbertTheme {
  static final ThemeData light = _build(Brightness.light);
  static final ThemeData dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.grey,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
      ),
    );
  }
}

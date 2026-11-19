import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../app/layout.dart';
import '../../app/shortcuts.dart';
import '../../core/settings/app_settings.dart';

part 'settings_screen.g.dart';

/// App settings (m1-design §3.9): auto-crop on add, units, About.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(appSettingsProvider).value ?? const AppSettings();
    final store = ref.read(settingsStoreProvider);
    return KeyBindings(
      bindings: [
        KeyBinding(
          const SingleActivator(LogicalKeyboardKey.escape),
          () => Navigator.maybePop(context),
        ),
      ],
      child: Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: MaxWidth(
          child: ListView(
            children: [
              SwitchListTile(
                title: const Text('Auto-crop photos when added'),
                subtitle: const Text(
                  'Find the painting in new photos and show it for review',
                ),
                value: settings.autoCropOnAdd,
                onChanged: store.setAutoCropOnAdd,
              ),
              ListTile(
                title: const Text('Units'),
                subtitle: Text(unitsLabel(settings.units)),
                onTap: () async {
                  final chosen = await showUnitsDialog(context, settings.units);
                  if (chosen != null) await store.setUnits(chosen);
                },
              ),
              const Divider(),
              ListTile(
                title: const Text('About Filbert'),
                onTap: () => _showAbout(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAbout(BuildContext context, WidgetRef ref) async {
    final version = await ref.read(appVersionProvider.future);
    if (!context.mounted) return;
    showAboutDialog(
      context: context,
      applicationName: 'Filbert Paint Studio',
      applicationVersion: version,
    );
  }
}

String unitsLabel(UnitsSetting units) => switch (units) {
  UnitsSetting.automatic => 'Automatic',
  UnitsSetting.inches => 'Inches',
  UnitsSetting.centimeters => 'Centimeters',
};

/// Picks a [UnitsSetting]; null if dismissed.
Future<UnitsSetting?> showUnitsDialog(
  BuildContext context,
  UnitsSetting current,
) => showDialog<UnitsSetting>(
  context: context,
  builder: (context) => SimpleDialog(
    title: const Text('Units'),
    children: [
      RadioGroup<UnitsSetting>(
        groupValue: current,
        onChanged: (value) => Navigator.pop(context, value),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final units in UnitsSetting.values)
              RadioListTile<UnitsSetting>(
                value: units,
                title: Text(unitsLabel(units)),
                subtitle: units == UnitsSetting.automatic
                    ? const Text('From your region')
                    : null,
              ),
          ],
        ),
      ),
    ],
  ),
);

/// The app's version, e.g. "1.0.0 (1)".
@Riverpod(keepAlive: true)
Future<String> appVersion(Ref ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
}

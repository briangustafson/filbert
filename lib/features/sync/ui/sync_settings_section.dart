import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sync_engine/sync_engine.dart' show RemoteUnavailable;

import '../../../core/auth/auth_service.dart';
import '../data/sync_providers.dart';
import '../data/sync_settings.dart';

/// Settings → Sync (m3-design §7.1). Sync now and the last-synced status
/// come with the sync controller (T9).
class SyncSettingsSection extends ConsumerStatefulWidget {
  const SyncSettingsSection({super.key});

  static const explanation =
      'Keep projects in step across your devices, using your own Google '
      'Drive.';
  static const driveDeclinedMessage =
      'Sync needs access to Filbert’s own folder on your Google Drive.';
  static const failedMessage =
      'Couldn’t sign in to Google. Check your connection and try again.';

  @override
  ConsumerState<SyncSettingsSection> createState() =>
      _SyncSettingsSectionState();
}

class _SyncSettingsSectionState extends ConsumerState<SyncSettingsSection> {
  /// A sign-in or sign-out is in progress.
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(syncSettingsProvider).value ?? const SyncSettings();
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        'Sync with Google Drive',
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
    if (!settings.enabled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          ListTile(
            title: const Text(SyncSettingsSection.explanation),
            trailing: FilledButton(
              onPressed: _busy ? null : _turnOn,
              child: const Text('Turn on'),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        ListTile(
          leading: const Icon(Icons.cloud_done_outlined),
          title: Text(settings.account ?? ''),
          subtitle: const Text('Sync is on'),
        ),
        ListTile(
          leading: const Icon(Icons.devices_outlined),
          title: const Text('Device name'),
          subtitle: Text(settings.deviceName ?? ''),
          onTap: () => _rename(settings.deviceName ?? ''),
        ),
        ListTile(
          leading: const Icon(Icons.cloud_off_outlined),
          title: const Text('Turn off sync'),
          subtitle: const Text('Projects stay on this device and on Drive'),
          enabled: !_busy,
          onTap: () => ref.read(syncSetupProvider).turnOff(),
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Sign out'),
          enabled: !_busy,
          onTap: () => _whileBusy(ref.read(syncSetupProvider).signOut),
        ),
        // Until the sync controller (T9): one pass by hand, debug builds
        // only (m3-tasks T8).
        if (kDebugMode)
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Sync now (debug)'),
            enabled: !_busy,
            onTap: _syncOnce,
          ),
      ],
    );
  }

  Future<void> _syncOnce() => _whileBusy(() async {
    try {
      final report = await ref.read(syncEngineProvider).syncOnce();
      debugPrint('Sync now (debug): $report');
      _say('$report');
    } on RemoteUnavailable catch (e) {
      debugPrint('Sync now (debug) failed: $e');
      _say('Sync failed: $e');
    }
  });

  Future<void> _turnOn() => _whileBusy(() async {
    final TurnOnResult result;
    try {
      result = await ref.read(syncSetupProvider).turnOn();
    } on AuthFailed catch (e) {
      debugPrint('Turn on sync: $e');
      _say(SyncSettingsSection.failedMessage);
      return;
    }
    if (result == TurnOnResult.driveDeclined) {
      _say(SyncSettingsSection.driveDeclinedMessage);
    }
  });

  Future<void> _rename(String current) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _DeviceNameDialog(current),
    );
    if (name != null) await ref.read(syncSetupProvider).setDeviceName(name);
  }

  Future<void> _whileBusy(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Edits the device name; pops the new name, or null.
class _DeviceNameDialog extends StatefulWidget {
  const _DeviceNameDialog(this.current);

  final String current;

  @override
  State<_DeviceNameDialog> createState() => _DeviceNameDialogState();
}

class _DeviceNameDialogState extends State<_DeviceNameDialog> {
  late final _controller = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.pop(context, _controller.text);

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Device name'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 40,
      decoration: const InputDecoration(
        helperText: 'Shown on your other devices when a change conflicts',
      ),
      onSubmitted: (_) => _save(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(onPressed: _save, child: const Text('Save')),
    ],
  );
}

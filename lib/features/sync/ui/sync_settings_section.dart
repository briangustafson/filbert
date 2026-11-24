import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sync_engine/sync_engine.dart' show UnavailableReason;

import '../../../core/auth/auth_service.dart';
import '../../../core/clock/clock.dart';
import '../data/sync_controller.dart';
import '../data/sync_settings.dart';

/// Settings → Sync (m3-design §7.1).
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

  /// Keeps "Synced 2 minutes ago" current.
  late final Timer _tick = Timer.periodic(
    const Duration(seconds: 30),
    (_) => setState(() {}),
  );

  @override
  void initState() {
    super.initState();
    _tick;
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(syncSettingsProvider).value ?? const SyncSettings();
    final status = ref.watch(syncControllerProvider);
    final clock = ref.watch(clockProvider);
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
          leading: Icon(
            status.failure == null
                ? Icons.cloud_done_outlined
                : Icons.cloud_off_outlined,
          ),
          title: Text(settings.account ?? ''),
          subtitle: Text(
            syncStatusText(status, settings.lastSyncAt, clock.now()),
          ),
          trailing: status.failure == UnavailableReason.notAuthorized
              ? FilledButton(
                  onPressed: _busy ? null : _turnOn,
                  child: const Text('Sign in'),
                )
              : null,
        ),
        ListTile(
          leading: const Icon(Icons.sync),
          title: const Text('Sync now'),
          enabled: !_busy && !status.syncing,
          onTap: () => ref.read(syncControllerProvider.notifier).syncNow(),
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
      ],
    );
  }

  Future<void> _turnOn() => _whileBusy(() async {
    final TurnOnResult result;
    try {
      result = await ref.read(syncSetupProvider).turnOn();
    } on AuthFailed catch (e) {
      debugPrint('Turn on sync: $e');
      _say(SyncSettingsSection.failedMessage);
      return;
    }
    switch (result) {
      case TurnOnResult.driveDeclined:
        _say(SyncSettingsSection.driveDeclinedMessage);
      case TurnOnResult.on:
        // Signing in again while sync was on: try at once.
        unawaited(ref.read(syncControllerProvider.notifier).syncNow());
      case TurnOnResult.cancelled:
        break;
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

/// The status line under the account (m3-design §7.1).
String syncStatusText(SyncStatus status, int? lastSyncAt, DateTime now) {
  if (status.syncing) return 'Syncing…';
  switch (status.failure) {
    case UnavailableReason.offline:
      return 'Offline — will sync when connected';
    case UnavailableReason.notAuthorized:
      return 'Google needs you to sign in again';
    case UnavailableReason.storageFull:
      return 'Your Google Drive is full';
    case UnavailableReason.other:
      return 'Couldn’t sync — will try again';
    case null:
      break;
  }
  if (lastSyncAt == null) return 'Not synced yet';
  final ago = now.difference(
    DateTime.fromMillisecondsSinceEpoch(lastSyncAt, isUtc: true),
  );
  String plural(int n, String unit) => '$n $unit${n == 1 ? '' : 's'} ago';
  return 'Synced ${switch (ago) {
    _ when ago.inMinutes < 1 => 'just now',
    _ when ago.inHours < 1 => plural(ago.inMinutes, 'minute'),
    _ when ago.inDays < 1 => plural(ago.inHours, 'hour'),
    _ => plural(ago.inDays, 'day'),
  }}';
}

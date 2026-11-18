import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'system_settings.g.dart';

/// Opens the app's page in the system settings, e.g. to allow a permission
/// that was refused (m2-design §5.5).
abstract interface class SystemSettings {
  Future<void> open();
}

/// Android: a method channel in `MainActivity.kt`.
class ChannelSystemSettings implements SystemSettings {
  const ChannelSystemSettings();

  static const _channel = MethodChannel('filbert/app_settings');

  @override
  Future<void> open() => _channel.invokeMethod<void>('open');
}

@Riverpod(keepAlive: true)
SystemSettings systemSettings(Ref ref) => const ChannelSystemSettings();

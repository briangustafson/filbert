import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// The default name other devices see in sync conflicts (m3-design
/// proposal 5): the phone's model on Android, the computer's name on the
/// Mac. Editable in Settings → Sync (T7).
Future<String> platformDeviceName([DeviceInfoPlugin? plugin]) async {
  final info = plugin ?? DeviceInfoPlugin();
  try {
    final name = switch (defaultTargetPlatform) {
      TargetPlatform.android => (await info.androidInfo).model,
      TargetPlatform.macOS => (await info.macOsInfo).computerName,
      TargetPlatform.iOS => (await info.iosInfo).name,
      _ => '',
    };
    return name.trim().isEmpty ? fallbackDeviceName : name.trim();
  } on Object catch (e) {
    debugPrint('Reading the device name failed: $e');
    return fallbackDeviceName;
  }
}

const fallbackDeviceName = 'This device';

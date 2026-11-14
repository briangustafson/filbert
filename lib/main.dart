import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'core/clock/clock.dart';
import 'core/db/app_database.dart';
import 'core/device/device_info.dart';
import 'core/ids/id_generator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase.open();
  final device = await StoredDeviceInfo.loadOrCreate(
    db,
    UuidV7IdGenerator(const SystemClock()),
  );

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        deviceInfoProvider.overrideWithValue(device),
      ],
      child: const FilbertApp(),
    ),
  );
}

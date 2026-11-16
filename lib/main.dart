import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'core/clock/clock.dart';
import 'core/db/app_database.dart';
import 'core/device/device_info.dart';
import 'core/files/file_store.dart';
import 'core/ids/id_generator.dart';
import 'features/photos/data/purge_job.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const clock = SystemClock();
  final db = AppDatabase.open();
  final device = await StoredDeviceInfo.loadOrCreate(
    db,
    UuidV7IdGenerator(clock),
  );
  final files = await LocalFileStore.open();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        deviceInfoProvider.overrideWithValue(device),
        fileStoreProvider.overrideWithValue(files),
      ],
      child: const FilbertApp(),
    ),
  );

  // Background housekeeping; never blocks start-up.
  unawaited(
    PurgeJob(db: db, files: files, clock: clock).runIfDue().catchError((
      Object e,
      StackTrace s,
    ) {
      debugPrint('Purge failed: $e');
      return 0;
    }),
  );
}

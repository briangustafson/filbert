import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'tables.dart';

export 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Projects, Images, ImageEditHistory, ImageEditCursor, AppMeta],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// The app's on-device database (in the app support directory).
  AppDatabase.open() : super(driftDatabase(name: 'filbert'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) => m.createAll());
}

@Riverpod(keepAlive: true)
AppDatabase database(Ref ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
}

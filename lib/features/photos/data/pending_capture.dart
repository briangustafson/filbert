import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/app_meta_keys.dart';

part 'pending_capture.g.dart';

/// Where a camera photo is going, saved before the camera opens so a photo
/// recovered after Android killed the app lands in the right place
/// (m1-design §3.6).
sealed class PendingCapture {
  const PendingCapture();

  Map<String, Object?> toJson();

  static PendingCapture? fromJson(Object? json) {
    if (json is! Map) return null;
    return switch (json['target']) {
      'newProject' => const CaptureForNewProject(),
      'grid' ||
      'reference' when json['projectId'] is String => CaptureForProject(
        json['projectId'] as String,
        asReference: json['target'] == 'reference',
      ),
      _ => null,
    };
  }
}

/// A photo for a new project (the project list's Take photo).
class CaptureForNewProject extends PendingCapture {
  const CaptureForNewProject();

  @override
  Map<String, Object?> toJson() => {'target': 'newProject'};

  @override
  bool operator ==(Object other) => other is CaptureForNewProject;

  @override
  int get hashCode => (CaptureForNewProject).hashCode;
}

/// A photo for an existing project's grid or reference slot.
class CaptureForProject extends PendingCapture {
  const CaptureForProject(this.projectId, {this.asReference = false});

  final String projectId;
  final bool asReference;

  @override
  Map<String, Object?> toJson() => {
    'target': asReference ? 'reference' : 'grid',
    'projectId': projectId,
  };

  @override
  bool operator ==(Object other) =>
      other is CaptureForProject &&
      other.projectId == projectId &&
      other.asReference == asReference;

  @override
  int get hashCode => Object.hash(projectId, asReference);
}

/// Stores at most one [PendingCapture]. Local-only (`app_meta`).
abstract interface class PendingCaptureStore {
  Future<void> save(PendingCapture capture);

  /// The saved capture, if any; malformed values read as null.
  Future<PendingCapture?> read();

  Future<void> clear();
}

class DriftPendingCaptureStore implements PendingCaptureStore {
  DriftPendingCaptureStore(this._db);

  final AppDatabase _db;

  @override
  Future<void> save(PendingCapture capture) => _db
      .into(_db.appMeta)
      .insertOnConflictUpdate(
        AppMetaCompanion.insert(
          key: AppMetaKeys.pendingCapture,
          value: jsonEncode(capture.toJson()),
        ),
      );

  @override
  Future<PendingCapture?> read() async {
    final row =
        await (_db.select(_db.appMeta)
              ..where((m) => m.key.equals(AppMetaKeys.pendingCapture)))
            .getSingleOrNull();
    if (row == null) return null;
    try {
      return PendingCapture.fromJson(jsonDecode(row.value));
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> clear() => (_db.delete(
    _db.appMeta,
  )..where((m) => m.key.equals(AppMetaKeys.pendingCapture))).go();
}

@Riverpod(keepAlive: true)
PendingCaptureStore pendingCaptureStore(Ref ref) =>
    DriftPendingCaptureStore(ref.watch(databaseProvider));

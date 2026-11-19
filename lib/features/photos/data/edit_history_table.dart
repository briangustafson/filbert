import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../domain/project_image.dart';

/// An image's local undo history (m1-design §4.2): never synced. Shared by
/// the image repository and the sync store, which records an edit pulled
/// from another device so Undo returns to what this device had (T6).
class EditHistoryTable {
  EditHistoryTable(this._db);

  final AppDatabase _db;

  static const maxUndoSteps = 50;

  /// Records a change of the image's edits from [before] to [after]. If
  /// [before] isn't the row at the cursor (no history yet, or changed by
  /// sync without it), it's recorded first, so undo returns to it.
  Future<void> recordChange(String imageId, String before, String after) async {
    var at = await cursor(imageId);
    final atCursor = at == null ? null : await entry(imageId, at);
    if (atCursor == null ||
        Edits.fromJsonString(atCursor) != Edits.fromJsonString(before)) {
      at = await push(imageId, at, before);
    }
    await push(imageId, at, after);
  }

  /// Appends [json] after [cursor] (dropping any redo rows), moves the
  /// cursor to it, trims to [maxUndoSteps], and returns the new cursor.
  Future<int> push(String imageId, int? cursor, String json) async {
    final seq = cursor == null ? 0 : cursor + 1;
    await (_db.delete(_db.imageEditHistory)..where(
          (h) => h.imageId.equals(imageId) & h.seq.isBiggerOrEqualValue(seq),
        ))
        .go();
    await _db
        .into(_db.imageEditHistory)
        .insert(
          ImageEditHistoryCompanion.insert(
            imageId: imageId,
            seq: seq,
            editsJson: json,
          ),
        );
    await (_db.delete(_db.imageEditHistory)..where(
          (h) =>
              h.imageId.equals(imageId) &
              h.seq.isSmallerThanValue(seq - maxUndoSteps),
        ))
        .go();
    await setCursor(imageId, seq);
    return seq;
  }

  Future<int?> cursor(String imageId) async {
    final row = await (_db.select(
      _db.imageEditCursor,
    )..where((c) => c.imageId.equals(imageId))).getSingleOrNull();
    return row?.seq;
  }

  Future<void> setCursor(String imageId, int seq) => _db
      .into(_db.imageEditCursor)
      .insertOnConflictUpdate(
        ImageEditCursorCompanion.insert(imageId: imageId, seq: seq),
      );

  Future<String?> entry(String imageId, int seq) async {
    final row =
        await (_db.select(_db.imageEditHistory)
              ..where((h) => h.imageId.equals(imageId) & h.seq.equals(seq)))
            .getSingleOrNull();
    return row?.editsJson;
  }
}

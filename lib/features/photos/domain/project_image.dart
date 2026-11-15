import '../../../core/imaging/edits.dart';
import '../../../core/imaging/image_origin.dart';

export '../../../core/imaging/edits.dart';
export '../../../core/imaging/image_origin.dart';

/// A photo in a project (m1-design §4.1). The original file is immutable;
/// [edits] describes how to render it.
class ProjectImage {
  const ProjectImage({
    required this.id,
    required this.projectId,
    required this.blobId,
    required this.mimeType,
    required this.width,
    required this.height,
    required this.origin,
    required this.capturedAt,
    required this.edits,
    required this.createdAt,
    required this.updatedAt,
    required this.updatedByDeviceId,
  });

  final String id;
  final String projectId;

  /// Id of the original file in the blob store.
  final String blobId;
  final String mimeType;

  /// Pixel size of the original after EXIF orientation.
  final int width;
  final int height;
  final ImageOrigin origin;
  final DateTime? capturedAt;
  final Edits edits;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String updatedByDeviceId;

  @override
  bool operator ==(Object other) =>
      other is ProjectImage &&
      other.id == id &&
      other.projectId == projectId &&
      other.blobId == blobId &&
      other.mimeType == mimeType &&
      other.width == width &&
      other.height == height &&
      other.origin == origin &&
      other.capturedAt == capturedAt &&
      other.edits == edits &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.updatedByDeviceId == updatedByDeviceId;

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    blobId,
    mimeType,
    width,
    height,
    origin,
    capturedAt,
    edits,
    createdAt,
    updatedAt,
    updatedByDeviceId,
  );

  @override
  String toString() => 'ProjectImage($id, ${width}x$height, $mimeType)';
}

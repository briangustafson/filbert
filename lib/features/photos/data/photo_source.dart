import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/imaging/image_origin.dart';

part 'photo_source.g.dart';

/// A photo handed over by the camera or picker, as a temporary file that
/// import copies and then deletes.
class PickedPhoto {
  const PickedPhoto({required this.path, required this.origin});

  final String path;
  final ImageOrigin origin;

  @override
  String toString() => 'PickedPhoto($path, ${origin.name})';
}

/// System camera and photo picker (m1-design §5). Photos come back
/// unmodified: no resizing or re-encoding, metadata kept.
abstract interface class PhotoSource {
  /// Opens the system camera; null if the user cancels.
  Future<PickedPhoto?> takePhoto();

  /// Opens the device photo picker; empty if the user cancels.
  Future<List<PickedPhoto>> pickFromDevice({bool multiple = true});

  /// Photos from a camera or picker session that finished after Android
  /// killed the app (call on start-up; M1 T8).
  Future<List<PickedPhoto>> retrieveLost();

  /// Deletes what the picker and camera leave in the app cache after their
  /// photos were imported (or abandoned). Call after [retrieveLost].
  Future<void> clearLeftovers();
}

class ImagePickerPhotoSource implements PhotoSource {
  /// Uses Android's Photo Picker (AndroidX backport on older versions)
  /// instead of the Files app, per m1-design §2.
  ImagePickerPhotoSource()
    : _android = Platform.isAndroid ? _photoPicker() : null;

  final ImagePickerAndroid? _android;
  final _picker = ImagePicker();

  static ImagePickerAndroid _photoPicker() =>
      ImagePickerAndroid()..useAndroidPhotoPicker = true;

  @override
  Future<PickedPhoto?> takePhoto() async {
    final file = await (_android != null
        ? _android.getImageFromSource(source: ImageSource.camera)
        : _picker.pickImage(source: ImageSource.camera));
    return file == null
        ? null
        : PickedPhoto(path: file.path, origin: ImageOrigin.camera);
  }

  @override
  Future<List<PickedPhoto>> pickFromDevice({bool multiple = true}) async {
    final List<XFile> files;
    if (multiple) {
      files = await (_android != null
          ? _android.getMultiImageWithOptions()
          : _picker.pickMultiImage());
    } else {
      final file = await (_android != null
          ? _android.getImageFromSource(source: ImageSource.gallery)
          : _picker.pickImage(source: ImageSource.gallery));
      files = [?file];
    }
    return [
      for (final f in files)
        PickedPhoto(path: f.path, origin: ImageOrigin.device),
    ];
  }

  @override
  Future<List<PickedPhoto>> retrieveLost() async {
    final response = await (_android != null
        ? _android.getLostData()
        : _picker.retrieveLostData());
    if (response.isEmpty || response.files == null) return const [];
    // The response doesn't say whether it came from the camera or the
    // picker. Android kills the app mostly while the camera is open, so
    // treat lost photos as camera photos.
    return [
      for (final f in response.files!)
        PickedPhoto(path: f.path, origin: ImageOrigin.camera),
    ];
  }

  @override
  Future<void> clearLeftovers() async {
    await deletePickerLeftovers(await getApplicationCacheDirectory());
  }
}

/// `image_picker` (Android) copies each picked photo into a new
/// `<cache>/<uuid>/` folder and writes camera photos to
/// `<cache>/<uuid><digits>.<ext>`. Import deletes the photo itself, which
/// leaves the folders behind. Deletes those folders and files, and nothing
/// else (the render caches share this directory). Returns how many entries
/// were deleted.
Future<int> deletePickerLeftovers(Directory cacheDir) async {
  if (!await cacheDir.exists()) return 0;
  var deleted = 0;
  await for (final entity in cacheDir.list()) {
    final name = entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
    final matches = switch (entity) {
      Directory() => _pickerFolder.hasMatch(name),
      File() => _cameraFile.hasMatch(name),
      _ => false,
    };
    if (!matches) continue;
    try {
      await entity.delete(recursive: true);
      deleted++;
    } on FileSystemException {
      // Best effort; tried again next launch.
    }
  }
  return deleted;
}

const _uuid = '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}';
final _pickerFolder = RegExp('^$_uuid\$');
final _cameraFile = RegExp('^$_uuid-?[0-9]*\\.[A-Za-z0-9]+\$');

@Riverpod(keepAlive: true)
PhotoSource photoSource(Ref ref) => ImagePickerPhotoSource();

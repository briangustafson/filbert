import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
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
}

@Riverpod(keepAlive: true)
PhotoSource photoSource(Ref ref) => ImagePickerPhotoSource();

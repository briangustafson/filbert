import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/settings/app_settings.dart';
import 'gallery_saver.dart';

part 'export_destination.g.dart';

enum ExportDestinationKind {
  /// The phone's photo gallery (Android, m2-design §3.5).
  gallery,

  /// A file the user picks in a save dialog (the Mac, m3-design §3.5).
  file,
}

/// Where Export… saves a rendered JPEG. The export sheet asks for a
/// [chooseLocation] first, so a cancelled dialog costs no render; then it
/// renders and calls [save].
abstract interface class ExportDestination {
  ExportDestinationKind get kind;

  /// Where to save an export named [fileName]: the name itself for the
  /// gallery, or the path picked in a save dialog. Null if cancelled.
  Future<String?> chooseLocation(String fileName);

  /// Saves the JPEG [file] at [location]. Throws [GallerySaveException] for
  /// the gallery, [FileSystemException] for a file.
  Future<void> save(File file, String location);

  /// Shows a saved file in the Finder, selected. Files only.
  Future<void> reveal(String location);
}

/// The gallery album exports go to.
const galleryAlbum = 'Filbert';

class GalleryExportDestination implements ExportDestination {
  const GalleryExportDestination(this._gallery);

  final GallerySaver _gallery;

  @override
  ExportDestinationKind get kind => ExportDestinationKind.gallery;

  @override
  Future<String?> chooseLocation(String fileName) async => fileName;

  @override
  Future<void> save(File file, String location) =>
      _gallery.save(file, album: galleryAlbum, fileName: location);

  @override
  Future<void> reveal(String location) async {}
}

/// Opens a save dialog: the path chosen, or null if cancelled.
typedef SaveDialog = Future<String?> Function({
  required String suggestedName,
  String? initialDirectory,
});

Future<String?> _fileSelectorDialog({
  required String suggestedName,
  String? initialDirectory,
}) async => (await getSaveLocation(
  suggestedName: suggestedName,
  initialDirectory: initialDirectory,
  confirmButtonText: 'Save',
  acceptedTypeGroups: const [
    XTypeGroup(
      label: 'JPEG',
      extensions: ['jpg', 'jpeg'],
      uniformTypeIdentifiers: ['public.jpeg'],
    ),
  ],
))?.path;

/// Save to file… (m3-design §3.5): a save dialog opening in the folder of
/// the last export, else Pictures. The sandbox lets the app write only the
/// path the dialog returns, so the name is never changed after it.
class FileExportDestination implements ExportDestination {
  FileExportDestination(
    this._settings, {
    this._dialog = _fileSelectorDialog,
    String? picturesFolder,
    this._finder = const MethodChannel('filbert/finder'),
  }) : _pictures = picturesFolder ?? _defaultPictures();

  final SettingsStore _settings;
  final SaveDialog _dialog;
  final String? _pictures;
  final MethodChannel _finder;

  /// In the sandbox HOME is the app's container, whose Pictures links to
  /// the user's.
  static String? _defaultPictures() {
    final home = Platform.environment['HOME'];
    return home == null ? null : '$home/Pictures';
  }

  @override
  ExportDestinationKind get kind => ExportDestinationKind.file;

  @override
  Future<String?> chooseLocation(String fileName) async => _dialog(
    suggestedName: fileName,
    initialDirectory: await _settings.exportFolder() ?? _pictures,
  );

  @override
  Future<void> save(File file, String location) async {
    await file.copy(location);
    await _settings.setExportFolder(File(location).parent.path);
  }

  @override
  Future<void> reveal(String location) =>
      _finder.invokeMethod<void>('reveal', location);
}

/// The gallery where there is one, else a file.
@Riverpod(keepAlive: true)
ExportDestination exportDestination(Ref ref) {
  final gallery = ref.watch(gallerySaverProvider);
  return gallery.available
      ? GalleryExportDestination(gallery)
      : FileExportDestination(ref.watch(settingsStoreProvider));
}

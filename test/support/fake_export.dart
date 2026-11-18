import 'dart:async';
import 'dart:io';

import 'package:filbert/core/platform/system_settings.dart';
import 'package:filbert/features/export/data/gallery_saver.dart';
import 'package:filbert/features/export/data/render_service.dart';
import 'package:filbert/features/export/domain/export_options.dart';
import 'package:filbert/features/photos/domain/project_image.dart';

import 'fixtures.dart';

/// Hands back a fixture file for every export, recording the requests.
/// [gate], when set, holds each export until it completes.
class FakeRenderService implements RenderService {
  FakeRenderService({File? file}) : file = file ?? fixtureImage('no_exif.jpg');

  final File file;
  final requests = <(ProjectImage, ExportOptions)>[];
  Completer<void>? gate;
  Object? failNext;

  @override
  Future<File> export(ProjectImage image, ExportOptions options) async {
    requests.add((image, options));
    await gate?.future;
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
    return file;
  }
}

class FakeGallerySaver implements GallerySaver {
  final saved = <({String path, String album, String fileName})>[];
  GallerySaveFailure? failNext;

  @override
  Future<void> save(
    File file, {
    required String album,
    required String fileName,
  }) async {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw GallerySaveException(failure);
    }
    saved.add((path: file.path, album: album, fileName: fileName));
  }
}

class FakeSystemSettings implements SystemSettings {
  var opened = 0;

  @override
  Future<void> open() async => opened++;
}

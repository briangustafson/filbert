import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/adaptive_sheet.dart';
import '../../../core/platform/system_settings.dart';
import '../../../core/clock/clock.dart';
import '../../photos/data/image_repository.dart';
import '../../photos/domain/project_image.dart';
import '../../projects/data/project_providers.dart';
import '../../view_aids/data/view_aids_providers.dart';
import '../../view_aids/domain/view_aids.dart';
import '../data/export_destination.dart';
import '../data/gallery_saver.dart';
import '../data/render_service.dart';
import '../domain/export_options.dart';
import '../domain/gallery_file_name.dart';

/// What an export ended with, for the photo screen's snackbar.
sealed class ExportOutcome {
  const ExportOutcome();
}

class SavedToGallery extends ExportOutcome {
  const SavedToGallery();
}

/// Saved by Save to file… at [path] (m3-design §3.5).
class SavedToFile extends ExportOutcome {
  const SavedToFile(this.path);

  final String path;
}

class SavedAsNewPhoto extends ExportOutcome {
  const SavedAsNewPhoto(this.photo);

  final ProjectImage photo;
}

/// Opens the export sheet for [image] (m2-design §3.5); null if closed
/// without exporting.
Future<ExportOutcome?> showExportSheet(
  BuildContext context,
  ProjectImage image,
) => showAdaptiveSheet<ExportOutcome>(
  context,
  // Tapping outside asks to close, which the sheet refuses mid-render;
  // dragging can't be refused, so it's off.
  enableDrag: false,
  builder: (_) => ExportSheet(image: image),
);

/// Include checklist (the aids that are on), Save to gallery (Save to
/// file… on the Mac, m3-design §3.5), Save as new image; progress and
/// errors in place (m2-design §3.5).
class ExportSheet extends ConsumerStatefulWidget {
  const ExportSheet({super.key, required this.image});

  final ProjectImage image;

  @override
  ConsumerState<ExportSheet> createState() => _ExportSheetState();
}

enum _Item { grid, tone, compare }

class _ExportSheetState extends ConsumerState<ExportSheet> {
  final _unchecked = <_Item>{};
  var _busy = false;
  String? _error;
  var _offerSettings = false;

  String get _projectId => widget.image.projectId;

  /// The options for the aids that are on, as the photo screen shows them.
  ExportOptions? _baseOptions() {
    final prefs = ref.watch(viewPrefsProvider(_projectId)).value;
    final project = ref.watch(projectProvider(_projectId)).value;
    if (prefs == null || project == null) return null;
    final aids = ref.watch(viewAidsStateProvider(_projectId));
    return ExportOptions.fromAids(
      aids,
      prefs,
      size: project.size,
      compareWith: ref.watch(compareTargetProvider(widget.image))?.overlay,
    );
  }

  ExportOptions _options(ExportOptions base) => base.without(
    grid: _unchecked.contains(_Item.grid),
    tone: _unchecked.contains(_Item.tone),
    compare: _unchecked.contains(_Item.compare),
  );

  Future<void> _run(
    ExportOptions options,
    Future<ExportOutcome> Function(ExportOptions options) save,
  ) async {
    setState(() {
      _busy = true;
      _error = null;
      _offerSettings = false;
    });
    try {
      final outcome = await save(options);
      if (mounted) Navigator.of(context).pop(outcome);
    } on _ExportError catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
        _offerSettings = e.offerSettings;
      });
    }
  }

  /// Save to gallery, or Save to file…: where first (a cancelled dialog
  /// renders nothing), then the render and the save.
  Future<void> _saveToDestination(ExportOptions options) async {
    final destination = ref.read(exportDestinationProvider);
    final project = ref.read(projectProvider(_projectId)).value;
    final location = await destination.chooseLocation(
      galleryFileName(project?.name ?? '', ref.read(clockProvider).now()),
    );
    if (location == null || !mounted) return;
    await _run(options, (options) async {
      final file = await _render(options);
      try {
        await destination.save(file, location);
      } on GallerySaveException catch (e) {
        throw switch (e.failure) {
          GallerySaveFailure.permissionDenied => const _ExportError(
            'Filbert needs permission to save to the gallery.',
            offerSettings: true,
          ),
          GallerySaveFailure.notEnoughSpace => const _ExportError(
            "There isn't enough space on the device.",
          ),
          GallerySaveFailure.other => const _ExportError(
            "Couldn't save to the gallery.",
          ),
        };
      } on FileSystemException catch (e) {
        debugPrint('Save to file failed: $e');
        throw const _ExportError("Couldn't save the file.");
      }
      return switch (destination.kind) {
        ExportDestinationKind.gallery => const SavedToGallery(),
        ExportDestinationKind.file => SavedToFile(location),
      };
    });
  }

  Future<ExportOutcome> _saveAsNewPhoto(ExportOptions options) async {
    final file = await _render(options);
    try {
      final photo = await ref
          .read(imageRepositoryProvider)
          .importDerived(
            _projectId,
            file,
            derivedFromJson: options.derivedFromJson(widget.image),
          );
      return SavedAsNewPhoto(photo);
    } on Object {
      throw const _ExportError("Couldn't save the new photo.");
    }
  }

  Future<File> _render(ExportOptions options) async {
    try {
      return await ref
          .read(renderServiceProvider)
          .export(widget.image, options);
    } on Object {
      throw const _ExportError("Couldn't export this photo.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = _baseOptions();
    final theme = Theme.of(context);
    final destination = ref.read(exportDestinationProvider).kind;
    final items = base == null
        ? const <(_Item, String)>[]
        : [
            if (base.grid != null) (_Item.grid, 'Grid'),
            if (base.tone != ToneAid.none)
              (
                _Item.tone,
                switch (base.tone) {
                  ToneAid.gray => 'Gray',
                  ToneAid.valueBands => 'Values (${base.bands} bands)',
                  ToneAid.colors => 'Colors (${base.colors} colors)',
                  ToneAid.none => '',
                },
              ),
            if (base.compareWith != null) (_Item.compare, 'Compare overlay'),
          ];
    final ready = base != null && !_busy;

    return PopScope(
      canPop: !_busy,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Export', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Full size, as a JPEG.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (items.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Include', style: theme.textTheme.titleSmall),
                for (final (item, label) in items)
                  CheckboxListTile(
                    key: ValueKey('export-include-${item.name}'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(label),
                    value: !_unchecked.contains(item),
                    onChanged: _busy
                        ? null
                        : (on) => setState(
                            () => on == true
                                ? _unchecked.remove(item)
                                : _unchecked.add(item),
                          ),
                  ),
              ],
              const SizedBox(height: 16),
              if (_busy)
                const _Progress()
              else ...[
                if (_error case final error?)
                  _ErrorRow(
                    message: error,
                    onSettings: _offerSettings
                        ? () => ref.read(systemSettingsProvider).open()
                        : null,
                  ),
                FilledButton.icon(
                  key: ValueKey('export-${destination.name}'),
                  icon: Icon(switch (destination) {
                    ExportDestinationKind.gallery =>
                      Icons.photo_library_outlined,
                    ExportDestinationKind.file => Icons.save_alt,
                  }),
                  label: Text(switch (destination) {
                    ExportDestinationKind.gallery => 'Save to gallery',
                    ExportDestinationKind.file => 'Save to file…',
                  }),
                  onPressed: ready
                      ? () => _saveToDestination(_options(base))
                      : null,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const ValueKey('export-new-photo'),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Save as new image'),
                  onPressed: ready
                      ? () => _run(_options(base), _saveAsNewPhoto)
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ExportError implements Exception {
  const _ExportError(this.message, {this.offerSettings = false});

  final String message;
  final bool offerSettings;
}

class _Progress extends StatelessWidget {
  const _Progress();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 20),
    child: Column(
      children: [
        LinearProgressIndicator(semanticsLabel: 'Exporting'),
        SizedBox(height: 12),
        Text('Exporting at full size…'),
      ],
    ),
  );
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.message, this.onSettings});

  final String message;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: colors.error)),
          ),
          if (onSettings != null)
            TextButton(onPressed: onSettings, child: const Text('Settings')),
        ],
      ),
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../photo_viewer/photo_order.dart';
import '../../photos/data/image_providers.dart';
import '../../photos/domain/project_image.dart';
import '../../photos/ui/image_thumbnail.dart';
import '../../projects/data/project_providers.dart';
import '../data/view_aids_providers.dart';
import '../domain/view_prefs.dart';

/// The Compare panel (m2-design §3.2, §3.4): the project's other photos as
/// thumbnails, the compared one marked, and the overlay's opacity.
class ComparePanel extends ConsumerWidget {
  const ComparePanel({
    super.key,
    required this.image,
    required this.compare,
    required this.onChanged,
  });

  /// The photo shown.
  final ProjectImage image;
  final ComparePrefs compare;
  final ValueChanged<ComparePrefs> onChanged;

  static const thumbSize = 48.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(compareTargetProvider(image));
    final photos = ref.watch(projectImagesProvider(image.projectId)).value;
    final referenceId = ref
        .watch(projectProvider(image.projectId))
        .value
        ?.referenceImageId;
    final others = [
      for (final p in photoOrder(referenceId, photos ?? const []))
        if (p.id != image.id) p,
    ];
    final percent = (compare.opacity * 100).round();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (target?.isShown ?? false)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              "This is the photo you're comparing with.",
              style: TextStyle(color: Colors.white70),
            ),
          ),
        // One row that scrolls: a project can have many photos.
        SizedBox(
          height: thumbSize + 8,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: others.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final photo = others[i];
              return _Thumb(
                key: ValueKey('compare-thumb-${photo.id}'),
                photo: photo,
                isReference: photo.id == referenceId,
                selected: target?.photo?.id == photo.id,
                onTap: () =>
                    onChanged(compare.copyWith(imageId: () => photo.id)),
              );
            },
          ),
        ),
        Row(
          children: [
            const Text('Opacity'),
            Expanded(
              child: Slider(
                key: const ValueKey('compare-opacity'),
                value: compare.opacity,
                divisions: 100,
                activeColor: Colors.white,
                inactiveColor: Colors.white24,
                thumbColor: Colors.white,
                semanticFormatterCallback: (v) => '${(v * 100).round()} %',
                onChanged: (v) => onChanged(
                  compare.copyWith(opacity: (v * 100).round() / 100),
                ),
              ),
            ),
            SizedBox(
              width: 44,
              child: ExcludeSemantics(
                child: Text(
                  '$percent %',
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    super.key,
    required this.photo,
    required this.isReference,
    required this.selected,
    required this.onTap,
  });

  final ProjectImage photo;
  final bool isReference;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: isReference ? 'Compare with the reference' : 'Compare with photo',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: ComparePanel.thumbSize + 8,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ExcludeSemantics(child: ImageThumbnail(image: photo)),
                if (isReference)
                  const Positioned(
                    right: 2,
                    bottom: 2,
                    child: Icon(Icons.star, size: 14, color: Colors.white),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

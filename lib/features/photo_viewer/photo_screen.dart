import 'package:material_ui/material_ui.dart';

import '../../app/placeholder_screen.dart';
import '../../app/routes.dart';

class PhotoScreen extends StatelessWidget {
  const PhotoScreen({
    super.key,
    required this.projectId,
    required this.imageId,
  });

  final String projectId;
  final String imageId;

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: 'Photo',
      details: ['Project: $projectId', 'Image: $imageId'],
      links: [
        (label: 'Crop/rotate', location: Routes.crop(projectId, imageId)),
        (label: 'Auto-crop', location: Routes.autocrop(projectId, imageId)),
      ],
    );
  }
}

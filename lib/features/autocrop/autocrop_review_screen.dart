import 'package:material_ui/material_ui.dart';

import '../../app/placeholder_screen.dart';

class AutocropReviewScreen extends StatelessWidget {
  const AutocropReviewScreen({
    super.key,
    required this.projectId,
    required this.imageId,
  });

  final String projectId;
  final String imageId;

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: 'Auto-crop',
      details: ['Project: $projectId', 'Image: $imageId'],
    );
  }
}

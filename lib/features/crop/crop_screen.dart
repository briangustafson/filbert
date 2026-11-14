import 'package:material_ui/material_ui.dart';

import '../../app/placeholder_screen.dart';

class CropScreen extends StatelessWidget {
  const CropScreen({super.key, required this.projectId, required this.imageId});

  final String projectId;
  final String imageId;

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: 'Crop',
      details: ['Project: $projectId', 'Image: $imageId'],
    );
  }
}

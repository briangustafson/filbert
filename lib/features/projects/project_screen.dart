import 'package:material_ui/material_ui.dart';

import '../../app/placeholder_screen.dart';
import '../../app/routes.dart';

/// Sample id used by placeholder links until real images exist (M1 T8).
const placeholderImageId = 'sample-image';

class ProjectScreen extends StatelessWidget {
  const ProjectScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: 'Project',
      details: ['Project: $projectId'],
      links: [
        (
          label: 'Open photo',
          location: Routes.photo(projectId, placeholderImageId),
        ),
      ],
    );
  }
}

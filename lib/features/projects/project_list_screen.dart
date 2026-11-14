import 'package:material_ui/material_ui.dart';

import '../../app/placeholder_screen.dart';
import '../../app/routes.dart';

/// Sample id used by placeholder links until real projects exist (M1 T4).
const placeholderProjectId = 'sample-project';

class ProjectListScreen extends StatelessWidget {
  const ProjectListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: 'Projects',
      links: [
        (label: 'Open project', location: Routes.project(placeholderProjectId)),
        (label: 'Settings', location: Routes.settings),
      ],
    );
  }
}

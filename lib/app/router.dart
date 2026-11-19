import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/autocrop/review_queue.dart';
import '../features/crop/crop_screen.dart';
import '../features/photo_viewer/photo_screen.dart';
import '../features/projects/ui/project_list_screen.dart';
import '../features/projects/ui/project_screen.dart';
import '../features/settings/settings_screen.dart';
import 'routes.dart';

part 'router.g.dart';

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final router = GoRouter(
    initialLocation: Routes.projectList,
    routes: [
      GoRoute(
        path: Routes.projectList,
        builder: (context, state) => const ProjectListScreen(),
        routes: [
          GoRoute(
            path: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: 'projects/:projectId',
            builder: (context, state) =>
                ProjectScreen(projectId: state.pathParameters['projectId']!),
            routes: [
              GoRoute(
                path: 'images/:imageId',
                builder: (context, state) => PhotoScreen(
                  projectId: state.pathParameters['projectId']!,
                  imageId: state.pathParameters['imageId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'crop',
                    builder: (context, state) => CropScreen(
                      projectId: state.pathParameters['projectId']!,
                      imageId: state.pathParameters['imageId']!,
                      afterAdd: state.uri.queryParameters['after'] == 'add',
                      queue: ReviewQueue.fromQuery(state.uri.queryParameters),
                      findCanvas: state.uri.queryParameters['find'] == 'canvas',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}

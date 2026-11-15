import 'package:filbert/app/app.dart';
import 'package:filbert/features/projects/data/project_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_project_repository.dart';

/// Pumps the whole app with in-memory fakes and returns its container.
Future<ProviderContainer> pumpFilbertApp(
  WidgetTester tester, {
  FakeProjectRepository? projects,
}) async {
  final container = ProviderContainer(
    overrides: [
      projectRepositoryProvider.overrideWithValue(
        projects ?? FakeProjectRepository(),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const FilbertApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

import 'package:filbert/features/photos/data/image_renderer.dart';
import 'package:filbert/features/photos/ui/image_thumbnail.dart';
import 'package:filbert/features/sync/data/blob_availability.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_photos.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fake_sync.dart';

void main() {
  Future<FakeImageRenderer> pumpThumb(
    WidgetTester tester, {
    required bool hang,
  }) async {
    final renderer = FakeImageRenderer(hang: hang);
    final image = FakeImageRepository(FakeProjectRepository()).seed('p');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          imageRendererProvider.overrideWithValue(renderer),
          blobAvailabilityServiceProvider.overrideWithValue(
            FakeBlobAvailability(),
          ),
        ],
        child: MaterialApp(
          home: SizedBox(
            width: 100,
            height: 100,
            child: ImageThumbnail(image: image),
          ),
        ),
      ),
    );
    await tester.pump();
    return renderer;
  }

  testWidgets('asks for the standard thumbnail; spinner while rendering', (
    tester,
  ) async {
    final renderer = await pumpThumb(tester, hang: true);
    expect(renderer.requests, ['thumbnail img1 $standardThumbnailPx']);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('a failed render shows a broken image', (tester) async {
    await pumpThumb(tester, hang: false);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
  });
}

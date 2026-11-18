import 'package:filbert/features/photos/domain/project_image.dart';
import 'package:filbert/features/view_aids/domain/compare_target.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_photos.dart';
import '../../support/fake_project_repository.dart';

void main() {
  late ProjectImage ref, older, newer;
  late List<ProjectImage> photos; // newest first

  setUp(() {
    final projects = FakeProjectRepository();
    final images = FakeImageRepository(projects);
    final id = projects.seed('Still life').id;
    ref = images.seed(id);
    older = images.seed(id);
    newer = images.seed(id);
    photos = [newer, older, ref];
  });

  CompareTarget resolve(
    ProjectImage shown, {
    String? saved,
    String? referenceId,
    List<ProjectImage>? among,
  }) => CompareTarget.resolve(
    savedId: saved,
    shown: shown,
    photos: among ?? photos,
    referenceId: referenceId,
  );

  test('the default is the reference', () {
    final t = resolve(older, referenceId: ref.id);
    expect(t.photo, ref);
    expect(t.overlay, ref);
    expect(t.isShown, isFalse);
  });

  test('on the reference, the most recent other photo', () {
    expect(resolve(ref, referenceId: ref.id).photo, newer);
  });

  test('without a reference, the most recent other photo', () {
    expect(resolve(older).photo, newer);
    expect(resolve(newer).photo, older);
  });

  test('a deleted reference is not the default', () {
    final live = [newer, older];
    expect(resolve(older, referenceId: ref.id, among: live).photo, newer);
  });

  test('the saved photo wins', () {
    expect(resolve(newer, saved: older.id, referenceId: ref.id).photo, older);
  });

  test('a deleted saved photo falls back to the default', () {
    final live = [newer, ref];
    final t = resolve(newer, saved: older.id, referenceId: ref.id, among: live);
    expect(t.photo, ref);
  });

  test('on the saved photo itself: no overlay', () {
    final t = resolve(older, saved: older.id, referenceId: ref.id);
    expect(t.isShown, isTrue);
    expect(t.photo, older);
    expect(t.overlay, isNull);
  });

  test('the only photo: nothing to compare', () {
    final t = resolve(ref, referenceId: ref.id, among: [ref]);
    expect(t.photo, isNull);
    expect(t.overlay, isNull);
  });
}

import 'package:filbert/features/photo_viewer/photo_order.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_photos.dart';
import '../../support/fake_project_repository.dart';

void main() {
  final images = FakeImageRepository(FakeProjectRepository());
  final a = images.seed('p'), b = images.seed('p'), c = images.seed('p');

  test('reference first, then the given (grid) order', () {
    expect(photoOrder(b.id, [c, b, a]), [b, c, a]);
    expect(photoOrder(null, [c, b, a]), [c, b, a]);
    expect(photoOrder('gone', [c, b, a]), [c, b, a]);
  });

  test('after a delete: next, else previous, else nothing', () {
    expect(neighbourAfterDelete(['a', 'b', 'c'], 'b'), 'c');
    expect(neighbourAfterDelete(['a', 'b', 'c'], 'c'), 'b');
    expect(neighbourAfterDelete(['a'], 'a'), isNull);
    expect(neighbourAfterDelete(['a'], 'x'), isNull);
  });
}

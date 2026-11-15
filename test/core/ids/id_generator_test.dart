import 'package:filbert/core/clock/clock.dart';
import 'package:filbert/core/ids/id_generator.dart';
import 'package:flutter_test/flutter_test.dart';

final _uuidV7 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void main() {
  test('ids are lowercase UUIDv7 with the RFC 9562 variant', () {
    final ids = UuidV7IdGenerator(const SystemClock());
    for (var i = 0; i < 100; i++) {
      expect(ids.newId(), matches(_uuidV7));
    }
  });

  test('ids are unique', () {
    final ids = UuidV7IdGenerator(FakeClock());
    final generated = {for (var i = 0; i < 10000; i++) ids.newId()};
    expect(generated, hasLength(10000));
  });

  test('ids embed the clock time and sort by it', () {
    final clock = FakeClock(DateTime.utc(2026, 11, 14, 12));
    final ids = UuidV7IdGenerator(clock);

    final first = ids.newId();
    clock.advance(const Duration(milliseconds: 1));
    final second = ids.newId();
    clock.advance(const Duration(days: 400));
    final third = ids.newId();

    expect([third, first, second]..sort(), [first, second, third]);

    // The first 48 bits are the Unix time in milliseconds.
    final ms = int.parse(first.replaceAll('-', '').substring(0, 12), radix: 16);
    expect(ms, DateTime.utc(2026, 11, 14, 12).millisecondsSinceEpoch);
  });

  test('SystemClock returns UTC', () {
    expect(const SystemClock().now().isUtc, isTrue);
  });
}

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'clock.g.dart';

/// Source of the current time. Always UTC. Fake it in tests.
abstract interface class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

/// A [Clock] whose time only changes when told to.
class FakeClock implements Clock {
  FakeClock([DateTime? start])
    : _now = (start ?? DateTime.utc(2026, 1, 1)).toUtc();

  DateTime _now;

  @override
  DateTime now() => _now;

  void set(DateTime time) => _now = time.toUtc();

  void advance(Duration duration) => _now = _now.add(duration);
}

@Riverpod(keepAlive: true)
Clock clock(Ref ref) => const SystemClock();

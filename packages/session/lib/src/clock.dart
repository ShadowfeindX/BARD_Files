/// Source of the current time (04 §Interfaces), injected so tests and replays
/// never read the system clock.
abstract interface class Clock {
  /// The current time.
  DateTime now();
}

/// The real clock.
final class SystemClock implements Clock {
  /// Creates the system clock.
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

/// A clock a test moves by hand.
final class FakeClock implements Clock {
  /// Creates a clock at [start].
  FakeClock([DateTime? start]) : _now = start ?? DateTime.utc(2026, 10, 21);

  DateTime _now;

  @override
  DateTime now() => _now;

  /// Moves the clock forward by [by].
  void advance(Duration by) => _now = _now.add(by);
}

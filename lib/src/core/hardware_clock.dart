import '../exceptions/hardware_exception.dart';

/// Time source used by hardware programs and backend event logs.
abstract interface class HardwareClock {
  /// Monotonic time elapsed since this clock was created.
  Duration get elapsed;

  /// Waits for, or virtually advances by, [duration].
  Future<void> delay(Duration duration);
}

/// A monotonic wall-clock implementation for host backends.
final class SystemHardwareClock implements HardwareClock {
  SystemHardwareClock() {
    _stopwatch.start();
  }

  final Stopwatch _stopwatch = Stopwatch();

  @override
  Duration get elapsed => _stopwatch.elapsed;

  @override
  Future<void> delay(Duration duration) {
    if (duration.isNegative) {
      throw InvalidHardwareArgumentException(
        argument: 'duration',
        value: duration,
        message: 'A delay cannot be negative.',
      );
    }
    return Future<void>.delayed(duration);
  }
}

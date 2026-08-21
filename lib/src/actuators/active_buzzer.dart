import '../core/hardware_clock.dart';
import '../exceptions/hardware_exception.dart';
import '../gpio/gpio.dart';
import 'actuator.dart';

/// A binary active buzzer driven by a digital output.
final class ActiveBuzzer implements Actuator {
  ActiveBuzzer(
    this.output, {
    required this.clock,
    this.ownsOutput = false,
  });

  final DigitalOutput output;
  final HardwareClock clock;
  final bool ownsOutput;
  bool _closed = false;

  @override
  bool get isClosed => _closed;

  Future<void> on() {
    _ensureOpen('turn on');
    return output.high();
  }

  Future<void> off() {
    _ensureOpen('turn off');
    return output.low();
  }

  Future<void> beep(Duration duration) async {
    _ensureOpen('beep');
    if (duration.isNegative) {
      throw InvalidHardwareArgumentException(
        argument: 'duration',
        value: duration,
        message: 'A beep duration cannot be negative.',
      );
    }
    await on();
    try {
      await clock.delay(duration);
    } finally {
      await off();
    }
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    if (!output.isClosed) {
      await output.low();
      if (ownsOutput) {
        await output.close();
      }
    }
    _closed = true;
  }

  void _ensureOpen(String operation) {
    if (_closed) {
      throw ResourceClosedException('active-buzzer', operation: operation);
    }
  }
}

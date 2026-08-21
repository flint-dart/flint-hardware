import '../core/hardware_board.dart';
import '../exceptions/hardware_exception.dart';
import '../pwm/pwm.dart';
import 'actuator.dart';

/// A positional hobby-servo abstraction over a PWM channel.
final class Servo implements Actuator {
  Servo(
    this.channel, {
    this.minimumPulse = const Duration(microseconds: 500),
    this.maximumPulse = const Duration(microseconds: 2400),
    this.ownsChannel = false,
  }) {
    if (minimumPulse <= Duration.zero || maximumPulse <= minimumPulse) {
      throw InvalidHardwareArgumentException(
        argument: 'pulseRange',
        value: '$minimumPulse..$maximumPulse',
        message: 'Servo pulse bounds must be positive and increasing.',
      );
    }
  }

  /// Acquires a 50 Hz PWM channel from [board].
  factory Servo.attach(
    HardwareBoard board,
    int pin, {
    Duration minimumPulse = const Duration(microseconds: 500),
    Duration maximumPulse = const Duration(microseconds: 2400),
  }) =>
      Servo(
        board.pwm.open(pin, frequencyHz: 50),
        minimumPulse: minimumPulse,
        maximumPulse: maximumPulse,
        ownsChannel: true,
      );

  final PwmChannel channel;
  final Duration minimumPulse;
  final Duration maximumPulse;
  final bool ownsChannel;
  bool _closed = false;
  double? _lastAngle;

  @override
  bool get isClosed => _closed;

  double? get lastAngle => _lastAngle;

  /// Sets an angle in the inclusive 0 through 180 degree range.
  Future<void> angle(num degrees) async {
    _ensureOpen('set angle');
    if (!degrees.isFinite || degrees < 0 || degrees > 180) {
      throw InvalidHardwareArgumentException(
        argument: 'degrees',
        value: degrees,
        message: 'Servo angle must be between 0 and 180 degrees.',
      );
    }
    if (channel.frequencyHz != 50) {
      await channel.setFrequency(50);
    }
    final double fraction = degrees / 180;
    final double pulseMicroseconds = minimumPulse.inMicroseconds +
        ((maximumPulse - minimumPulse).inMicroseconds * fraction);
    final double periodMicroseconds = 1000000 / channel.frequencyHz;
    await channel.setDutyCycle(pulseMicroseconds / periodMicroseconds);
    if (!channel.isEnabled) {
      await channel.enable();
    }
    _lastAngle = degrees.toDouble();
  }

  Future<void> detach() async {
    _ensureOpen('detach');
    if (channel.isEnabled) {
      await channel.disable();
    }
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    if (!channel.isClosed) {
      if (channel.isEnabled) {
        await channel.disable();
      }
      if (ownsChannel) {
        await channel.close();
      }
    }
    _closed = true;
  }

  void _ensureOpen(String operation) {
    if (_closed) {
      throw ResourceClosedException('servo', operation: operation);
    }
  }
}

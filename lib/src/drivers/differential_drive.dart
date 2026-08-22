import '../gpio/gpio.dart';

/// Motor speed command pair for two-wheel differential drive.
final class MotorPowerPair {
  const MotorPowerPair({
    required this.leftSpeed,
    required this.rightSpeed,
    required this.leftDirection,
    required this.rightDirection,
  });

  final double leftSpeed; // 0.0 to 1.0
  final double rightSpeed; // 0.0 to 1.0
  final DigitalLevel leftDirection;
  final DigitalLevel rightDirection;

  @override
  String toString() =>
      'MotorPower(left: ${(leftSpeed * 100).toStringAsFixed(1)}% [${leftDirection.name}], right: ${(rightSpeed * 100).toStringAsFixed(1)}% [${rightDirection.name}])';
}

/// High-level 2-wheel Differential Drive Motor Controller driver (L298N, TB6612FNG, DRV8833).
final class DifferentialDrive {
  const DifferentialDrive({
    required this.leftPwmPin,
    required this.leftDirPin,
    required this.rightPwmPin,
    required this.rightDirPin,
    this.pwmFrequencyHz = 10000,
  });

  final int leftPwmPin;
  final int leftDirPin;
  final int rightPwmPin;
  final int rightDirPin;
  final int pwmFrequencyHz;

  /// Computes left and right motor speeds and directions given forward velocity (-1.0 to 1.0) and turn rate (-1.0 to 1.0).
  MotorPowerPair computeKinematics({
    required double forward,
    required double turn,
  }) {
    final double clampedForward = forward.clamp(-1.0, 1.0);
    final double clampedTurn = turn.clamp(-1.0, 1.0);

    // Standard differential drive mixer:
    // Left = Forward + Turn
    // Right = Forward - Turn
    double left = clampedForward + clampedTurn;
    double right = clampedForward - clampedTurn;

    // Normalize if exceeds 1.0
    final double maxMag = [left.abs(), right.abs(), 1.0].reduce((a, b) => a > b ? a : b);
    left /= maxMag;
    right /= maxMag;

    return MotorPowerPair(
      leftSpeed: left.abs(),
      rightSpeed: right.abs(),
      leftDirection: left >= 0.0 ? DigitalLevel.high : DigitalLevel.low,
      rightDirection: right >= 0.0 ? DigitalLevel.high : DigitalLevel.low,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'driver': 'DifferentialDrive',
        'leftPwmPin': leftPwmPin,
        'leftDirPin': leftDirPin,
        'rightPwmPin': rightPwmPin,
        'rightDirPin': rightDirPin,
        'pwmFrequencyHz': pwmFrequencyHz,
      };
}

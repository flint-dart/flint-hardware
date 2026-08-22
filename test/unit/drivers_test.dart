import 'package:flint_hardware/flint_hardware.dart';
import 'package:test/test.dart';

void main() {
  group('Robotics Drivers Pack', () {
    test('Hcsr04Sonar accurately calculates distance and checks obstacle proximity', () {
      const sonar = Hcsr04Sonar(triggerPin: 5, echoPin: 18);

      // 1000 µs echo duration -> (1000 * 0.0343) / 2 = 17.15 cm
      final distance = sonar.microsecondsToCentimeters(1000);
      expect(distance, closeTo(17.15, 0.01));

      // Obstacle detection
      expect(sonar.isObstacleNear(10.0, thresholdCm: 15.0), isTrue);
      expect(sonar.isObstacleNear(30.0, thresholdCm: 15.0), isFalse);
    });

    test('DifferentialDrive mixes forward and turn rates into motor power pairs', () {
      const diffDrive = DifferentialDrive(
        leftPwmPin: 18,
        leftDirPin: 21,
        rightPwmPin: 19,
        rightDirPin: 22,
      );

      // Straight forward 80%
      final straight = diffDrive.computeKinematics(forward: 0.8, turn: 0.0);
      expect(straight.leftSpeed, closeTo(0.8, 0.01));
      expect(straight.rightSpeed, closeTo(0.8, 0.01));
      expect(straight.leftDirection, DigitalLevel.high);
      expect(straight.rightDirection, DigitalLevel.high);

      // Pivot turn right
      final turnRight = diffDrive.computeKinematics(forward: 0.0, turn: 0.5);
      expect(turnRight.leftSpeed, closeTo(0.5, 0.01));
      expect(turnRight.rightSpeed, closeTo(0.5, 0.01));
      expect(turnRight.leftDirection, DigitalLevel.high);
      expect(turnRight.rightDirection, DigitalLevel.low);
    });

    test('Mpu6050Imu and Vector3D models motion telemetry', () {
      const imu = Mpu6050Imu(sdaPin: 21, sclPin: 22);
      expect(imu.sdaPin, 21);
      expect(imu.sclPin, 22);
      expect(imu.i2cAddress, 0x68);

      const reading = ImuMotionReading(
        accelerometerG: Vector3D(0.0, 0.0, 1.0), // 1G gravity downwards
        gyroscopeDegPerSec: Vector3D(0.0, 15.0, 0.0), // 15 deg/s pitch
      );

      expect(reading.accelerometerG.z, 1.0);
      expect(reading.gyroscopeDegPerSec.y, 15.0);
    });

    test('Dht22Sensor and DhtReading converts Celsius to Fahrenheit', () {
      const dht = Dht22Sensor(pin: 4);
      expect(dht.pin, 4);

      const reading = DhtReading(
        temperatureCelsius: 25.0,
        relativeHumidityPercent: 60.0,
      );

      expect(reading.temperatureCelsius, 25.0);
      expect(reading.temperatureFahrenheit, 77.0); // (25 * 9/5) + 32 = 77
      expect(reading.relativeHumidityPercent, 60.0);
    });

    test('FirmwareBuilder configures robotics drivers with 1-line builders', () {
      final robot = FirmwareBuilder('rover_test', target: BoardTarget.esp32);

      final sonar = robot.sonar(triggerPin: 5, echoPin: 18);
      final imu = robot.imu(sdaPin: 21, sclPin: 22);
      final drive = robot.differentialDrive(
        leftPwmPin: 18,
        leftDirPin: 21,
        rightPwmPin: 19,
        rightDirPin: 22,
      );
      final dht = robot.dht22(pin: 4);

      expect(sonar.triggerPin, 5);
      expect(imu.i2cAddress, 0x68);
      expect(drive.leftPwmPin, 18);
      expect(dht.pin, 4);

      final program = robot.build();
      expect(program.operations.length, 7); // trigger, echo, leftPwm, leftDir, rightPwm, rightDir, dhtPin
    });
  });
}

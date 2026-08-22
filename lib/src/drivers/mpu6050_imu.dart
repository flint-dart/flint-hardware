/// 3D Vector for acceleration and angular velocity.
final class Vector3D {
  const Vector3D(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  Map<String, Object?> toJson() => <String, Object?>{
        'x': x,
        'y': y,
        'z': z,
      };

  @override
  String toString() => 'Vector3D(x: ${x.toStringAsFixed(2)}, y: ${y.toStringAsFixed(2)}, z: ${z.toStringAsFixed(2)})';
}

/// 6-Axis motion reading from an IMU sensor.
final class ImuMotionReading {
  const ImuMotionReading({
    required this.accelerometerG,
    required this.gyroscopeDegPerSec,
    this.temperatureC = 25.0,
  });

  final Vector3D accelerometerG;
  final Vector3D gyroscopeDegPerSec;
  final double temperatureC;

  Map<String, Object?> toJson() => <String, Object?>{
        'accel': accelerometerG.toJson(),
        'gyro': gyroscopeDegPerSec.toJson(),
        'temperatureC': temperatureC,
      };

  @override
  String toString() =>
      'ImuMotionReading(accel: $accelerometerG, gyro: $gyroscopeDegPerSec, temp: ${temperatureC.toStringAsFixed(1)}°C)';
}

/// 6-Axis Inertial Measurement Unit (IMU) driver for MPU6050 / MPU6500.
final class Mpu6050Imu {
  const Mpu6050Imu({
    this.sdaPin = 21,
    this.sclPin = 22,
    this.i2cAddress = 0x68,
    this.accelScaleG = 2,
    this.gyroScaleDps = 250,
  });

  final int sdaPin;
  final int sclPin;
  final int i2cAddress;
  final int accelScaleG;
  final int gyroScaleDps;

  Map<String, Object?> toJson() => <String, Object?>{
        'driver': 'MPU6050',
        'sdaPin': sdaPin,
        'sclPin': sclPin,
        'i2cAddress': '0x${i2cAddress.toRadixString(16).toUpperCase()}',
        'accelScaleG': accelScaleG,
        'gyroScaleDps': gyroScaleDps,
      };
}

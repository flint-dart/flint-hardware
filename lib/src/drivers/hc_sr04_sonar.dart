/// Ultrasonic Distance Sensor driver (HC-SR04 / US-015).
final class Hcsr04Sonar {
  const Hcsr04Sonar({
    required this.triggerPin,
    required this.echoPin,
    this.maxDistanceCm = 400.0,
    this.minDistanceCm = 2.0,
  });

  final int triggerPin;
  final int echoPin;
  final double maxDistanceCm;
  final double minDistanceCm;

  /// Helper to convert round-trip echo pulse duration in microseconds to centimeters.
  /// Formula: Distance (cm) = (Duration (µs) * Speed of Sound (0.0343 cm/µs)) / 2
  double microsecondsToCentimeters(int echoMicroseconds) {
    if (echoMicroseconds <= 0) {
      return maxDistanceCm;
    }
    final double calculated = (echoMicroseconds * 0.0343) / 2.0;
    return calculated.clamp(minDistanceCm, maxDistanceCm);
  }

  /// Checks if an object is within a danger proximity threshold.
  bool isObstacleNear(double measuredCm, {double thresholdCm = 15.0}) {
    return measuredCm > 0.0 && measuredCm <= thresholdCm;
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'driver': 'HC-SR04',
        'triggerPin': triggerPin,
        'echoPin': echoPin,
        'maxDistanceCm': maxDistanceCm,
        'minDistanceCm': minDistanceCm,
      };
}

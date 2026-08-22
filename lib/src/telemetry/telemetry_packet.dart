import 'dart:convert';

/// A timestamped metrics packet holding robot state for Flutter dashboards.
final class TelemetryPacket {
  TelemetryPacket({
    required this.robotName,
    required this.currentState,
    this.batteryPercent = 100,
    this.leftMotorSpeed = 0.0,
    this.rightMotorSpeed = 0.0,
    this.servoAngleDegrees = 90.0,
    this.distanceSensorCm,
    this.aiDetectedLabel,
    this.aiConfidence,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory TelemetryPacket.fromJson(Map<String, Object?> json) {
    return TelemetryPacket(
      robotName: json['robotName']! as String,
      currentState: json['currentState']! as String,
      batteryPercent: (json['batteryPercent'] as num?)?.toInt() ?? 100,
      leftMotorSpeed: (json['leftMotorSpeed'] as num?)?.toDouble() ?? 0.0,
      rightMotorSpeed: (json['rightMotorSpeed'] as num?)?.toDouble() ?? 0.0,
      servoAngleDegrees: (json['servoAngleDegrees'] as num?)?.toDouble() ?? 90.0,
      distanceSensorCm: (json['distanceSensorCm'] as num?)?.toDouble(),
      aiDetectedLabel: json['aiDetectedLabel'] as String?,
      aiConfidence: (json['aiConfidence'] as num?)?.toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp']! as String)
          : null,
    );
  }

  final String robotName;
  final String currentState;
  final int batteryPercent;
  final double leftMotorSpeed;
  final double rightMotorSpeed;
  final double servoAngleDegrees;
  final double? distanceSensorCm;
  final String? aiDetectedLabel;
  final double? aiConfidence;
  final DateTime timestamp;

  Map<String, Object?> toJson() => <String, Object?>{
        'robotName': robotName,
        'currentState': currentState,
        'batteryPercent': batteryPercent,
        'leftMotorSpeed': leftMotorSpeed,
        'rightMotorSpeed': rightMotorSpeed,
        'servoAngleDegrees': servoAngleDegrees,
        'distanceSensorCm': distanceSensorCm,
        'aiDetectedLabel': aiDetectedLabel,
        'aiConfidence': aiConfidence,
        'timestamp': timestamp.toIso8601String(),
      };

  String serializeJson() => jsonEncode(toJson());

  @override
  String toString() =>
      'TelemetryPacket($robotName, state: $currentState, battery: $batteryPercent%, left: $leftMotorSpeed, right: $rightMotorSpeed)';
}

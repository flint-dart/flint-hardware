import 'package:flint_hardware/flint_hardware.dart';
import 'package:test/test.dart';

void main() {
  group('TelemetryBridge & TelemetryPacket', () {
    test('serializes and deserializes TelemetryPacket accurately', () {
      final packet = TelemetryPacket(
        robotName: 'FlintRover',
        currentState: 'patrol',
        batteryPercent: 88,
        leftMotorSpeed: 0.75,
        rightMotorSpeed: 0.75,
        servoAngleDegrees: 45.0,
        distanceSensorCm: 22.4,
        aiDetectedLabel: 'person',
        aiConfidence: 0.94,
      );

      final jsonString = packet.serializeJson();
      expect(jsonString, contains('"robotName":"FlintRover"'));
      expect(jsonString, contains('"batteryPercent":88'));

      final parsed = TelemetryPacket.fromJson(packet.toJson());
      expect(parsed.robotName, 'FlintRover');
      expect(parsed.currentState, 'patrol');
      expect(parsed.batteryPercent, 88);
      expect(parsed.leftMotorSpeed, 0.75);
      expect(parsed.aiDetectedLabel, 'person');
      expect(parsed.aiConfidence, 0.94);
    });

    test('ingests raw stream chunks into strongly-typed telemetry packets', () async {
      final bridge = TelemetryBridge(robotName: 'FlintRover');

      final packets = <TelemetryPacket>[];
      bridge.telemetryStream.listen(packets.add);

      const rawSerialLog = '''
[Flint Log] Starting telemetry stream...
{"robotName":"FlintRover","currentState":"cruising","batteryPercent":99,"leftMotorSpeed":0.5,"rightMotorSpeed":0.5,"servoAngleDegrees":90.0}
[Flint Log] Motor tick completed.
{"robotName":"FlintRover","currentState":"avoidance","batteryPercent":98,"leftMotorSpeed":0.0,"rightMotorSpeed":0.8,"servoAngleDegrees":45.0}
''';

      bridge.ingestRawChunk(rawSerialLog);

      // Yield microtasks
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(packets.length, 2);
      expect(packets[0].currentState, 'cruising');
      expect(packets[0].batteryPercent, 99);
      expect(packets[1].currentState, 'avoidance');

      bridge.close();
    });
  });
}

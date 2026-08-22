import 'dart:async';
import 'dart:convert';

import 'telemetry_packet.dart';

/// Bidirectional bridge connecting embedded robot telemetry to Flutter / Web UIs.
final class TelemetryBridge {
  TelemetryBridge({required this.robotName});

  final String robotName;
  final StreamController<TelemetryPacket> _telemetryStreamController =
      StreamController<TelemetryPacket>.broadcast();
  final StreamController<String> _commandStreamController =
      StreamController<String>.broadcast();

  Stream<TelemetryPacket> get telemetryStream =>
      _telemetryStreamController.stream;
  Stream<String> get commandStream => _commandStreamController.stream;

  /// Ingests raw serial, WebSocket, or BLE string chunks from the robot.
  void ingestRawChunk(String chunk) {
    for (final String line in chunk.split('\n')) {
      final String trimmed = line.trim();
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        try {
          final Map<String, Object?> jsonMap =
              jsonDecode(trimmed) as Map<String, Object?>;
          final TelemetryPacket packet = TelemetryPacket.fromJson(jsonMap);
          _telemetryStreamController.add(packet);
        } on FormatException {
          // Ignore partial or non-JSON log lines
        }
      }
    }
  }

  /// Broadcasts a newly generated telemetry packet from the robot.
  void publish(TelemetryPacket packet) {
    _telemetryStreamController.add(packet);
  }

  /// Sends a command down to the robot controller.
  void sendCommand(String command) {
    _commandStreamController.add(command);
  }

  /// Closes active stream controllers.
  void close() {
    _telemetryStreamController.close();
    _commandStreamController.close();
  }
}

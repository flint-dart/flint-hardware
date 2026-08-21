import 'dart:typed_data';

enum SerialParity { none, odd, even }

/// Portable serial framing configuration.
final class SerialConfig {
  const SerialConfig({
    this.baudRate = 115200,
    this.dataBits = 8,
    this.stopBits = 1,
    this.parity = SerialParity.none,
  });

  final int baudRate;
  final int dataBits;
  final int stopBits;
  final SerialParity parity;
}

/// Factory for acquiring serial ports.
abstract interface class SerialController {
  SerialPort open(String name, {SerialConfig config = const SerialConfig()});
}

/// A scoped byte-oriented serial port.
abstract class SerialPort {
  String get name;
  SerialConfig get config;
  bool get isClosed;

  Future<void> write(List<int> data);
  Future<Uint8List> read(int maxBytes);
  Stream<Uint8List> get received;
  Future<void> close();
}

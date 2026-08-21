import 'dart:typed_data';

/// Factory for acquiring I2C controllers.
abstract interface class I2cController {
  I2cBus open(int busNumber);
}

/// A scoped I2C bus.
abstract class I2cBus {
  int get busNumber;
  bool get isClosed;

  /// Performs one combined write/read transaction at a 7-bit [address].
  Future<Uint8List> transfer(
    int address, {
    List<int> write = const <int>[],
    int readLength = 0,
  });

  Future<void> close();
}

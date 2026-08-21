import 'dart:typed_data';

enum SpiMode { mode0, mode1, mode2, mode3 }

enum SpiBitOrder { mostSignificantFirst, leastSignificantFirst }

/// Factory for acquiring SPI buses and chip-select resources.
abstract interface class SpiController {
  SpiBus open({
    required int busNumber,
    required int chipSelect,
    SpiMode mode = SpiMode.mode0,
    SpiBitOrder bitOrder = SpiBitOrder.mostSignificantFirst,
    int frequencyHz = 1000000,
  });
}

/// A scoped full-duplex SPI endpoint.
abstract class SpiBus {
  int get busNumber;
  int get chipSelect;
  SpiMode get mode;
  SpiBitOrder get bitOrder;
  int get frequencyHz;
  bool get isClosed;

  Future<Uint8List> transfer(List<int> data);
  Future<void> close();
}

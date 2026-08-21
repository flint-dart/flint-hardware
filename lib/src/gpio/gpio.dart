/// A digital logic level.
enum DigitalLevel {
  low,
  high;

  bool get isHigh => this == DigitalLevel.high;

  DigitalLevel get inverted => isHigh ? DigitalLevel.low : DigitalLevel.high;
}

/// Input bias requested from a GPIO backend.
enum PinPull { none, up, down }

/// GPIO edges that can produce input events.
enum PinEdge { rising, falling, both }

/// One digital input transition.
final class GpioEdgeEvent {
  const GpioEdgeEvent({
    required this.pin,
    required this.edge,
    required this.level,
    required this.elapsed,
  });

  final int pin;
  final PinEdge edge;
  final DigitalLevel level;
  final Duration elapsed;
}

/// Factory for acquiring digital pins.
abstract interface class GpioController {
  DigitalOutput output(
    int pin, {
    DigitalLevel initialLevel = DigitalLevel.low,
  });

  DigitalInput input(
    int pin, {
    PinPull pull = PinPull.none,
    PinEdge? trigger,
  });
}

/// A scoped GPIO resource.
abstract interface class GpioPin {
  int get number;
  bool get isClosed;
  Future<void> close();
}

/// A digital output pin with portable convenience operations.
abstract class DigitalOutput implements GpioPin {
  DigitalLevel get level;

  Future<void> write(DigitalLevel level);

  Future<void> high() => write(DigitalLevel.high);

  Future<void> low() => write(DigitalLevel.low);

  Future<void> toggle() => write(level.inverted);
}

/// A digital input pin and its configured edge stream.
abstract class DigitalInput implements GpioPin {
  PinPull get pull;
  PinEdge? get trigger;
  DigitalLevel get lastLevel;
  Stream<GpioEdgeEvent> get edges;
  Future<DigitalLevel> read();
}

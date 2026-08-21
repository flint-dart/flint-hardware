/// A typed source of hardware measurements.
abstract interface class Sensor<T> {
  String get id;
  bool get isClosed;
  Future<T> read();
  Future<void> close();
}

/// Data model shared by future physical and simulated DHT22 drivers.
final class Dht22Reading {
  const Dht22Reading({
    required this.temperatureCelsius,
    required this.relativeHumidity,
  });

  final double temperatureCelsius;
  final double relativeHumidity;

  double get temperature => temperatureCelsius;
  double get humidity => relativeHumidity;
}

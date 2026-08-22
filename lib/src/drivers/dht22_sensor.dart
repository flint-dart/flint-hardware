/// Temperature and relative humidity reading.
final class DhtReading {
  const DhtReading({
    required this.temperatureCelsius,
    required this.relativeHumidityPercent,
  });

  final double temperatureCelsius;
  final double relativeHumidityPercent;

  double get temperatureFahrenheit => (temperatureCelsius * 9.0 / 5.0) + 32.0;

  Map<String, Object?> toJson() => <String, Object?>{
        'temperatureC': temperatureCelsius,
        'temperatureF': temperatureFahrenheit,
        'humidityPercent': relativeHumidityPercent,
      };

  @override
  String toString() =>
      'DhtReading(${temperatureCelsius.toStringAsFixed(1)}°C / ${temperatureFahrenheit.toStringAsFixed(1)}°F, humidity: ${relativeHumidityPercent.toStringAsFixed(1)}%)';
}

/// Digital Temperature and Relative Humidity sensor driver (DHT11 / DHT22 / AM2302).
final class Dht22Sensor {
  const Dht22Sensor({required this.pin});

  final int pin;

  Map<String, Object?> toJson() => <String, Object?>{
        'driver': 'DHT22',
        'pin': pin,
      };
}

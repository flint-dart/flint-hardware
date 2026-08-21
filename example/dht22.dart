import 'package:flint_hardware/flint_hardware.dart';

Future<void> main() async {
  final SimulatedBoard board = SimulatedBoard();

  // This is explicit simulator data. A timing-verified physical DHT22 driver
  // is planned and is not represented as implemented by this example.
  final SimulatedSensor<Dht22Reading> sensor = board.sensor<Dht22Reading>(
    'dht22:4',
    const Dht22Reading(
      temperatureCelsius: 26.4,
      relativeHumidity: 63.2,
    ),
  );
  final Dht22Reading reading = await sensor.read();

  print('Temperature: ${reading.temperature} C');
  print('Humidity: ${reading.humidity}%');
  await board.close();
}

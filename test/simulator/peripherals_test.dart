import 'dart:typed_data';

import 'package:flint_hardware/flint_hardware.dart';
import 'package:test/test.dart';

void main() {
  group('simulated peripheral capabilities', () {
    test('PWM validates and records state', () async {
      final SimulatedBoard board = SimulatedBoard();
      final PwmChannel pwm = board.pwm.open(18, frequencyHz: 50);

      await pwm.setDutyCycle(0.075);
      await pwm.enable();

      expect(pwm.dutyCycle, closeTo(0.075, 0.000001));
      expect(pwm.isEnabled, isTrue);
      expect(
        () => pwm.setDutyCycle(1.1),
        throwsA(isA<InvalidHardwareArgumentException>()),
      );
      await board.close();
    });

    test('I2C requires an explicit responder for reads', () async {
      final SimulatedBoard board = SimulatedBoard();
      final I2cBus bus = board.i2c.open(0);

      await expectLater(
        bus.transfer(0x44, readLength: 2),
        throwsA(isA<HardwareException>()),
      );
      board.i2c.registerDevice(
        0,
        0x44,
        (Uint8List write, int readLength) => <int>[0x12, 0x34],
      );

      expect(
        await bus.transfer(0x44, write: <int>[0x01], readLength: 2),
        orderedEquals(<int>[0x12, 0x34]),
      );
      await board.close();
    });

    test('SPI uses an explicit full-duplex responder', () async {
      final SimulatedBoard board = SimulatedBoard();
      board.spi.registerDevice(
        1,
        5,
        (Uint8List write) => write.reversed.toList(),
      );
      final SpiBus spi = board.spi.open(busNumber: 1, chipSelect: 5);

      expect(
        await spi.transfer(<int>[1, 2, 3]),
        orderedEquals(<int>[3, 2, 1]),
      );
      await board.close();
    });

    test('serial injection drives stream and buffered reads', () async {
      final SimulatedBoard board = SimulatedBoard();
      final SerialPort port = board.serial.open('loopback');
      final Future<Uint8List> event = port.received.first;

      board.serial.inject('loopback', <int>[65, 66, 67]);

      expect(await event, orderedEquals(<int>[65, 66, 67]));
      expect(await port.read(2), orderedEquals(<int>[65, 66]));
      expect(await port.read(2), orderedEquals(<int>[67]));
      await board.close();
    });

    test('analog inputs and sensors never invent configured data', () async {
      final SimulatedBoard board = SimulatedBoard();
      final AnalogInput analog = board.analog.input(34);

      await expectLater(
        analog.readRaw(),
        throwsA(isA<HardwareException>()),
      );
      board.analog.setRawValue(34, 2048);
      expect(await analog.readRaw(), 2048);
      expect(await analog.readNormalized(), closeTo(2048 / 4095, 0.000001));

      final SimulatedSensor<Dht22Reading> sensor = board.sensor<Dht22Reading>(
        'dht22:4',
        const Dht22Reading(
          temperatureCelsius: 25,
          relativeHumidity: 60,
        ),
      );
      sensor.setValue(
        const Dht22Reading(
          temperatureCelsius: 26,
          relativeHumidity: 61,
        ),
      );
      expect((await sensor.read()).temperature, 26);
      await board.close();
    });
  });
}

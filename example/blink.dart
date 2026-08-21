import 'package:flint_hardware/flint_hardware.dart';

Future<void> main() async {
  final SimulatedBoard board = SimulatedBoard();
  final DigitalOutput led = board.gpio.output(2);

  for (int count = 0; count < 3; count++) {
    await led.high();
    await board.clock.delay(const Duration(milliseconds: 500));
    await led.low();
    await board.clock.delay(const Duration(milliseconds: 500));
  }

  for (final HardwareEvent event in board.events) {
    print(event);
  }
  await board.close();
}

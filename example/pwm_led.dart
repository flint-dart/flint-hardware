import 'package:flint_hardware/flint_hardware.dart';

Future<void> main() async {
  final SimulatedBoard board = SimulatedBoard();
  final PwmChannel led = board.pwm.open(2, frequencyHz: 1000);
  await led.enable();

  for (int step = 0; step <= 10; step++) {
    await led.setDutyCycle(step / 10);
    await board.clock.delay(const Duration(milliseconds: 50));
  }

  print('Final duty cycle: ${led.dutyCycle}');
  await board.close();
}

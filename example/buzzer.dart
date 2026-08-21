import 'package:flint_hardware/flint_hardware.dart';

Future<void> main() async {
  final SimulatedBoard board = SimulatedBoard();
  final DigitalOutput output = board.gpio.output(18);
  final ActiveBuzzer buzzer = ActiveBuzzer(output, clock: board.clock);

  await buzzer.beep(const Duration(milliseconds: 250));
  print('Buzzer state: ${output.level.name}');

  await buzzer.close();
  await board.close();
}

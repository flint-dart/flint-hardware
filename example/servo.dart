import 'package:flint_hardware/flint_hardware.dart';

Future<void> main() async {
  final SimulatedBoard board = SimulatedBoard();
  final Servo servo = Servo.attach(board, 18);

  await servo.angle(0);
  await servo.angle(90);
  await servo.angle(180);

  print('Servo angle: ${servo.lastAngle} degrees');
  await servo.close();
  await board.close();
}

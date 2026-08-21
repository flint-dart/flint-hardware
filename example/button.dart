import 'dart:async';

import 'package:flint_hardware/flint_hardware.dart';

Future<void> main() async {
  final SimulatedBoard board = SimulatedBoard();
  final DigitalInput button = board.gpio.input(
    4,
    pull: PinPull.up,
    trigger: PinEdge.both,
  );
  final DigitalOutput led = board.gpio.output(2);

  final StreamSubscription<GpioEdgeEvent> subscription =
      button.edges.listen((GpioEdgeEvent event) {
    unawaited(led.write(event.level.inverted));
  });

  await board.gpio.driveInput(4, DigitalLevel.low);
  await board.gpio.driveInput(4, DigitalLevel.high);
  await subscription.cancel();

  print('LED after button release: ${led.level.name}');
  await board.close();
}

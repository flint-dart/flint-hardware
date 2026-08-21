import 'package:flint_hardware/flint_hardware.dart';
import 'package:test/test.dart';

void main() {
  group('simulated GPIO', () {
    test('records configuration, state, reads, and virtual timing', () async {
      final SimulatedBoard board = SimulatedBoard();
      final DigitalOutput output = board.gpio.output(2);

      await output.high();
      await board.clock.delay(const Duration(milliseconds: 250));
      await output.low();

      expect(output.level, DigitalLevel.low);
      expect(board.clock.elapsed, const Duration(milliseconds: 250));
      expect(
        board.events.map((HardwareEvent event) => event.operation),
        containsAllInOrder(<String>[
          'open',
          'output',
          'write',
          'advance',
          'write',
        ]),
      );

      await board.close();
      expect(output.isClosed, isTrue);
      expect(board.isClosed, isTrue);
    });

    test('emits only configured input edges', () async {
      final SimulatedBoard board = SimulatedBoard();
      final DigitalInput input = board.gpio.input(
        4,
        pull: PinPull.down,
        trigger: PinEdge.rising,
      );

      final Future<GpioEdgeEvent> rising = input.edges.first;
      await board.gpio.driveInput(4, DigitalLevel.high);
      final GpioEdgeEvent event = await rising;
      await board.gpio.driveInput(4, DigitalLevel.low);

      expect(event.pin, 4);
      expect(event.edge, PinEdge.rising);
      expect(await input.read(), DigitalLevel.low);
      await board.close();
    });

    test('enforces pin ownership and permits reacquisition after close',
        () async {
      final SimulatedBoard board = SimulatedBoard();
      final DigitalOutput first = board.gpio.output(2);

      expect(
        () => board.gpio.input(2),
        throwsA(isA<ResourceConflictException>()),
      );
      await first.close();
      final DigitalInput second = board.gpio.input(2);
      expect(second.number, 2);

      await second.close();
      await second.close();
      expect(
        second.read,
        throwsA(isA<ResourceClosedException>()),
      );
      await board.close();
      await board.close();
    });

    test('rejects invalid pins', () async {
      final SimulatedBoard board = SimulatedBoard();
      expect(
        () => board.gpio.output(-1),
        throwsA(isA<InvalidHardwareArgumentException>()),
      );
      await board.close();
    });
  });
}

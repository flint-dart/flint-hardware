import 'package:flint_hardware/flint_hardware.dart';
import 'package:test/test.dart';

void main() {
  test('active buzzer uses board time and leaves output low', () async {
    final SimulatedBoard board = SimulatedBoard();
    final DigitalOutput output = board.gpio.output(18);
    final ActiveBuzzer buzzer = ActiveBuzzer(output, clock: board.clock);

    await buzzer.beep(const Duration(milliseconds: 100));

    expect(output.level, DigitalLevel.low);
    expect(board.clock.elapsed, const Duration(milliseconds: 100));
    await buzzer.close();
    await board.close();
  });

  test('servo maps angles onto the configured pulse range', () async {
    final SimulatedBoard board = SimulatedBoard();
    final Servo servo = Servo.attach(board, 18);
    final PwmChannel channel = servo.channel;

    await servo.angle(0);
    expect(channel.dutyCycle, closeTo(0.025, 0.000001));
    await servo.angle(180);
    expect(channel.dutyCycle, closeTo(0.12, 0.000001));
    expect(servo.lastAngle, 180);

    expect(
      () => servo.angle(181),
      throwsA(isA<InvalidHardwareArgumentException>()),
    );
    await servo.close();
    expect(channel.isClosed, isTrue);
    await board.close();
  });
}

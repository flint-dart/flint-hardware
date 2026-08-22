import 'package:flint_hardware/flint_hardware.dart';
import 'package:test/test.dart';

void main() {
  group('RobotStateMachine', () {
    test('transitions between states on dispatched events', () {
      final fsm = RobotStateMachine(initialStateName: 'patrol');

      bool enteredAvoidance = false;
      bool exitedPatrol = false;

      fsm.state('patrol')
        ..onExit(() => exitedPatrol = true)
        ..onEvent(const ObstacleDetectedEvent(distanceCm: 10), transitionTo: 'avoidance');

      fsm.state('avoidance')
        ..onEnter(() => enteredAvoidance = true)
        ..onEvent(const CustomRobotEvent('path_clear'), transitionTo: 'patrol');

      expect(fsm.currentState, 'patrol');

      // Dispatch event
      final transitioned = fsm.dispatch(const ObstacleDetectedEvent(distanceCm: 10));

      expect(transitioned, isTrue);
      expect(fsm.currentState, 'avoidance');
      expect(exitedPatrol, isTrue);
      expect(enteredAvoidance, isTrue);

      // Return to patrol
      fsm.dispatch(const CustomRobotEvent('path_clear'));
      expect(fsm.currentState, 'patrol');

      fsm.close();
    });

    test('executes onTick for active state', () {
      final fsm = RobotStateMachine(initialStateName: 'cruising');
      int tickCount = 0;

      fsm.state('cruising').onTick(() => tickCount++);

      fsm.tick();
      fsm.tick();
      fsm.tick();

      expect(tickCount, 3);
      fsm.close();
    });
  });
}

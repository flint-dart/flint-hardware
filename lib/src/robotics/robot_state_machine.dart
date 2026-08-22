import 'dart:async';

/// Base class for events that trigger state transitions in a robot.
abstract class RobotEvent {
  const RobotEvent();

  String get name;
}

/// Built-in standard robotics events.
final class ObstacleDetectedEvent extends RobotEvent {
  const ObstacleDetectedEvent({this.distanceCm = 15.0});

  final double distanceCm;

  @override
  String get name => 'obstacle_detected';
}

final class LowBatteryEvent extends RobotEvent {
  const LowBatteryEvent({this.batteryPercent = 15});

  final int batteryPercent;

  @override
  String get name => 'low_battery';
}

final class TargetAcquiredEvent extends RobotEvent {
  const TargetAcquiredEvent({required this.targetLabel});

  final String targetLabel;

  @override
  String get name => 'target_acquired';
}

final class CustomRobotEvent extends RobotEvent {
  const CustomRobotEvent(this.eventName);

  final String eventName;

  @override
  String get name => eventName;
}

/// Represents an individual state in the robot's lifecycle.
final class RobotState {
  RobotState(this.name);

  final String name;
  void Function()? onEnterAction;
  void Function()? onTickAction;
  void Function()? onExitAction;

  final Map<String, String> _eventTransitions = <String, String>{};
  final Map<Duration, String> _timeoutTransitions = <Duration, String>{};

  /// Action executed when entering this state.
  void onEnter(void Function() action) {
    onEnterAction = action;
  }

  /// Periodic loop tick action while in this state.
  void onTick(void Function() action) {
    onTickAction = action;
  }

  /// Cleanup action executed when exiting this state.
  void onExit(void Function() action) {
    onExitAction = action;
  }

  /// Transition to another state when a named event or RobotEvent triggers.
  void onEvent(Object event, {required String transitionTo}) {
    final String eventName = event is RobotEvent ? event.name : event.toString();
    _eventTransitions[eventName] = transitionTo;
  }

  /// Transition to another state after a timeout duration has elapsed.
  void after(Duration duration, {required String transitionTo}) {
    _timeoutTransitions[duration] = transitionTo;
  }
}

/// High-level, type-safe state machine for robotics coordination.
final class RobotStateMachine {
  RobotStateMachine({required this.initialStateName})
      : _currentStateName = initialStateName;

  final String initialStateName;
  final Map<String, RobotState> _states = <String, RobotState>{};
  String _currentStateName;
  final StreamController<String> _stateChangeController =
      StreamController<String>.broadcast();

  String get currentState => _currentStateName;
  Stream<String> get onStateChanged => _stateChangeController.stream;

  /// Defines or configures a named state.
  RobotState state(String name, [void Function(RobotState state)? configure]) {
    final RobotState state = _states.putIfAbsent(name, () => RobotState(name));
    if (configure != null) {
      configure(state);
    }
    return state;
  }

  /// Dispatches an event to trigger transitions in the current state.
  bool dispatch(RobotEvent event) {
    final RobotState? activeState = _states[_currentStateName];
    if (activeState == null) {
      return false;
    }

    final String? nextState = activeState._eventTransitions[event.name];
    if (nextState != null && _states.containsKey(nextState)) {
      transitionTo(nextState);
      return true;
    }
    return false;
  }

  /// Manually transitions the state machine to a target state.
  void transitionTo(String nextStateName) {
    if (!_states.containsKey(nextStateName)) {
      throw ArgumentError('State "$nextStateName" does not exist in state machine.');
    }
    if (_currentStateName == nextStateName) {
      return;
    }

    final RobotState? previousState = _states[_currentStateName];
    previousState?.onExitAction?.call();

    _currentStateName = nextStateName;
    final RobotState? newState = _states[_currentStateName];
    newState?.onEnterAction?.call();

    _stateChangeController.add(_currentStateName);
  }

  /// Executes one tick of the active state.
  void tick() {
    final RobotState? activeState = _states[_currentStateName];
    activeState?.onTickAction?.call();
  }

  /// Closes stream controllers.
  void close() {
    _stateChangeController.close();
  }
}

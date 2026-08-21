/// A stateful hardware device that owns or coordinates output resources.
abstract interface class Actuator {
  bool get isClosed;
  Future<void> close();
}

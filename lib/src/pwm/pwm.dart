/// Factory for acquiring PWM outputs.
abstract interface class PwmController {
  PwmChannel open(
    int pin, {
    double frequencyHz = 1000,
    double dutyCycle = 0,
  });
}

/// A scoped PWM channel.
abstract class PwmChannel {
  int get pin;
  double get frequencyHz;
  double get dutyCycle;
  bool get isEnabled;
  bool get isClosed;

  Future<void> setFrequency(double frequencyHz);
  Future<void> setDutyCycle(double dutyCycle);
  Future<void> enable();
  Future<void> disable();
  Future<void> close();
}

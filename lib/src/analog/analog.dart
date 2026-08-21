/// Factory for acquiring analog inputs.
abstract interface class AnalogController {
  AnalogInput input(int pin);
}

/// A scoped analog input.
abstract class AnalogInput {
  int get pin;
  int get resolutionBits;
  bool get isClosed;

  Future<int> readRaw();

  /// Reads a normalized value in the inclusive range 0.0 through 1.0.
  Future<double> readNormalized();
  Future<void> close();
}

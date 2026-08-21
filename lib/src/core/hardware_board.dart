import '../analog/analog.dart';
import '../gpio/gpio.dart';
import '../i2c/i2c.dart';
import '../pwm/pwm.dart';
import '../serial/serial.dart';
import '../spi/spi.dart';
import 'board_descriptor.dart';
import 'hardware_clock.dart';

/// Backend-independent entry point for hardware capabilities.
abstract interface class HardwareBoard {
  BoardDescriptor get descriptor;
  HardwareClock get clock;
  GpioController get gpio;
  PwmController get pwm;
  I2cController get i2c;
  SpiController get spi;
  SerialController get serial;
  AnalogController get analog;
  bool get isClosed;

  /// Closes all resources still owned by this board.
  Future<void> close();
}

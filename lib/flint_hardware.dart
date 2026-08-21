/// Portable hardware abstractions, a deterministic simulator, and Flint's
/// experimental ESP-IDF firmware tooling.
library;

export 'src/actuators/active_buzzer.dart';
export 'src/actuators/actuator.dart';
export 'src/actuators/servo.dart';
export 'src/analog/analog.dart';
export 'src/backends/esp32/esp32_firmware.dart';
export 'src/backends/simulator/simulated_board.dart';
export 'src/compiler/firmware_program.dart';
export 'src/core/board_descriptor.dart';
export 'src/core/hardware_board.dart';
export 'src/core/hardware_clock.dart';
export 'src/core/hardware_event.dart';
export 'src/exceptions/hardware_exception.dart';
export 'src/gpio/gpio.dart';
export 'src/i2c/i2c.dart';
export 'src/pwm/pwm.dart';
export 'src/sensors/sensor.dart';
export 'src/serial/serial.dart';
export 'src/spi/spi.dart';

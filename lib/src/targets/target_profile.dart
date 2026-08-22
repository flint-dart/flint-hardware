import '../core/board_descriptor.dart';
import '../exceptions/hardware_exception.dart';

/// Supported hardware chip and board targets in Flint.
enum BoardTarget {
  esp32('esp32', 'Espressif ESP32 DevKit (Xtensa LX6)'),
  esp32Cam('esp32_cam', 'AI-Thinker ESP32-CAM (OV2640 / PSRAM)'),
  esp32s3('esp32s3', 'Espressif ESP32-S3 (Xtensa LX7 / AI Vector)'),
  rp2040('rp2040', 'Raspberry Pi Pico (Dual ARM Cortex-M0+)'),
  stm32f4('stm32f4', 'STMicroelectronics STM32F4 Discovery (ARM Cortex-M4F)'),
  nrf52840('nrf52840', 'Nordic Semiconductor nRF52840 (ARM Cortex-M4 / BLE)');

  const BoardTarget(this.identifier, this.displayName);

  final String identifier;
  final String displayName;

  static BoardTarget fromIdentifier(String value) {
    for (final BoardTarget target in BoardTarget.values) {
      if (target.identifier == value || target.name == value) {
        return target;
      }
    }
    throw InvalidHardwareArgumentException(
      argument: 'target',
      value: value,
      message: 'Unknown board target "$value". Supported targets: '
          '${BoardTarget.values.map((t) => t.identifier).join(', ')}.',
    );
  }
}

/// Specifications and constraints for a physical board target.
abstract class TargetProfile {
  const TargetProfile();

  BoardTarget get target;
  String get architecture;
  int get flashSizeBytes;
  int get sramSizeBytes;
  Set<HardwareCapability> get capabilities;
  Set<int> get permittedDigitalOutputPins;
  Set<int> get permittedDigitalInputPins;
  Set<int> get permittedPwmPins;

  void validatePinForOutput(int pin) {
    if (!permittedDigitalOutputPins.contains(pin)) {
      throw InvalidHardwareArgumentException(
        argument: 'pin',
        value: pin,
        message: 'GPIO $pin is not permitted for digital output on ${target.displayName}.',
      );
    }
  }

  void validatePinForInput(int pin) {
    if (!permittedDigitalInputPins.contains(pin)) {
      throw InvalidHardwareArgumentException(
        argument: 'pin',
        value: pin,
        message: 'GPIO $pin is not permitted for digital input on ${target.displayName}.',
      );
    }
  }

  void validatePinForPwm(int pin) {
    if (!permittedPwmPins.contains(pin)) {
      throw InvalidHardwareArgumentException(
        argument: 'pin',
        value: pin,
        message: 'GPIO $pin does not support PWM output on ${target.displayName}.',
      );
    }
  }
}

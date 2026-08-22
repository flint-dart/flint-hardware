import '../core/board_descriptor.dart';
import '../exceptions/hardware_exception.dart';
import 'target_profile.dart';

/// Board profile for standard Espressif ESP32 DevKit.
final class Esp32Profile extends TargetProfile {
  const Esp32Profile();

  @override
  BoardTarget get target => BoardTarget.esp32;

  @override
  String get architecture => 'xtensa-lx6';

  @override
  int get flashSizeBytes => 4 * 1024 * 1024; // 4MB

  @override
  int get sramSizeBytes => 520 * 1024; // 520KB

  @override
  Set<HardwareCapability> get capabilities => const <HardwareCapability>{
        HardwareCapability.gpio,
        HardwareCapability.gpioEdges,
        HardwareCapability.pwm,
        HardwareCapability.i2c,
        HardwareCapability.spi,
        HardwareCapability.serial,
        HardwareCapability.analogInput,
      };

  @override
  Set<int> get permittedDigitalOutputPins => const <int>{
        0, 1, 2, 3, 4, 5, 12, 13, 14, 15, 16, 17, 18, 19, 21, 22, 23, 25, 26, 27, 32, 33,
      };

  @override
  Set<int> get permittedDigitalInputPins => const <int>{
        0, 1, 2, 3, 4, 5, 12, 13, 14, 15, 16, 17, 18, 19, 21, 22, 23, 25, 26, 27, 32, 33, 34, 35, 36, 39,
      };

  @override
  Set<int> get permittedPwmPins => permittedDigitalOutputPins;
}

/// Board profile for AI-Thinker ESP32-CAM (Camera + PSRAM).
final class Esp32CamProfile extends TargetProfile {
  const Esp32CamProfile();

  @override
  BoardTarget get target => BoardTarget.esp32Cam;

  @override
  String get architecture => 'xtensa-lx6';

  @override
  int get flashSizeBytes => 4 * 1024 * 1024;

  @override
  int get sramSizeBytes => 4 * 1024 * 1024; // 520KB internal + 4MB PSRAM

  @override
  Set<HardwareCapability> get capabilities => const <HardwareCapability>{
        HardwareCapability.gpio,
        HardwareCapability.pwm,
        HardwareCapability.serial,
      };

  @override
  Set<int> get permittedDigitalOutputPins => const <int>{
        2, 4, 12, 13, 14, 15, 16, 33, // Pin 33 is on-board red LED, Pin 4 is flashlight LED
      };

  @override
  Set<int> get permittedDigitalInputPins => const <int>{
        2, 4, 12, 13, 14, 15, 16, 33,
      };

  @override
  Set<int> get permittedPwmPins => const <int>{2, 4, 12, 13, 14, 15, 16, 33};
}

/// Board profile for Raspberry Pi Pico (RP2040).
final class Rp2040Profile extends TargetProfile {
  const Rp2040Profile();

  @override
  BoardTarget get target => BoardTarget.rp2040;

  @override
  String get architecture => 'arm-cortex-m0plus';

  @override
  int get flashSizeBytes => 2 * 1024 * 1024; // 2MB QSPI Flash

  @override
  int get sramSizeBytes => 264 * 1024; // 264KB SRAM

  @override
  Set<HardwareCapability> get capabilities => const <HardwareCapability>{
        HardwareCapability.gpio,
        HardwareCapability.gpioEdges,
        HardwareCapability.pwm,
        HardwareCapability.i2c,
        HardwareCapability.spi,
        HardwareCapability.serial,
        HardwareCapability.analogInput,
      };

  @override
  Set<int> get permittedDigitalOutputPins => const <int>{
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 25, 26, 27, 28,
      };

  @override
  Set<int> get permittedDigitalInputPins => permittedDigitalOutputPins;

  @override
  Set<int> get permittedPwmPins => permittedDigitalOutputPins;
}

/// Board profile for STMicroelectronics STM32F4 Discovery.
final class Stm32F4Profile extends TargetProfile {
  const Stm32F4Profile();

  @override
  BoardTarget get target => BoardTarget.stm32f4;

  @override
  String get architecture => 'arm-cortex-m4f';

  @override
  int get flashSizeBytes => 1024 * 1024; // 1MB Flash

  @override
  int get sramSizeBytes => 192 * 1024; // 192KB SRAM

  @override
  Set<HardwareCapability> get capabilities => const <HardwareCapability>{
        HardwareCapability.gpio,
        HardwareCapability.gpioEdges,
        HardwareCapability.pwm,
        HardwareCapability.i2c,
        HardwareCapability.spi,
        HardwareCapability.serial,
        HardwareCapability.analogInput,
      };

  @override
  Set<int> get permittedDigitalOutputPins => const <int>{
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
      };

  @override
  Set<int> get permittedDigitalInputPins => permittedDigitalOutputPins;

  @override
  Set<int> get permittedPwmPins => permittedDigitalOutputPins;
}

/// Board profile for Nordic Semiconductor nRF52840 (BLE SoC).
final class Nrf52840Profile extends TargetProfile {
  const Nrf52840Profile();

  @override
  BoardTarget get target => BoardTarget.nrf52840;

  @override
  String get architecture => 'arm-cortex-m4';

  @override
  int get flashSizeBytes => 1024 * 1024; // 1MB Flash

  @override
  int get sramSizeBytes => 256 * 1024; // 256KB SRAM

  @override
  Set<HardwareCapability> get capabilities => const <HardwareCapability>{
        HardwareCapability.gpio,
        HardwareCapability.gpioEdges,
        HardwareCapability.pwm,
        HardwareCapability.i2c,
        HardwareCapability.spi,
        HardwareCapability.serial,
        HardwareCapability.analogInput,
      };

  @override
  Set<int> get permittedDigitalOutputPins => const <int>{
        13, 14, 15, 16, // On-board LEDs on nRF52840 DK (P0.13 - P0.16)
        11, 12, 24, 25, // Buttons
      };

  @override
  Set<int> get permittedDigitalInputPins => permittedDigitalOutputPins;

  @override
  Set<int> get permittedPwmPins => permittedDigitalOutputPins;
}

/// Registry of target profiles.
abstract final class TargetRegistry {
  static const Map<BoardTarget, TargetProfile> profiles = <BoardTarget, TargetProfile>{
    BoardTarget.esp32: Esp32Profile(),
    BoardTarget.esp32Cam: Esp32CamProfile(),
    BoardTarget.rp2040: Rp2040Profile(),
    BoardTarget.stm32f4: Stm32F4Profile(),
    BoardTarget.nrf52840: Nrf52840Profile(),
  };

  static TargetProfile getProfile(BoardTarget target) {
    final TargetProfile? profile = profiles[target];
    if (profile == null) {
      throw HardwareException(
        code: HardwareErrorCode.unsupportedCapability,
        message: 'No board profile registered for target ${target.identifier}.',
        operation: 'getProfile',
      );
    }
    return profile;
  }
}

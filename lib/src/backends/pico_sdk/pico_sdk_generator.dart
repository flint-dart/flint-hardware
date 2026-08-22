import 'dart:io';

import '../../compiler/firmware_program.dart';
import '../../exceptions/hardware_exception.dart';
import '../../gpio/gpio.dart';
import '../../targets/board_profiles.dart';
import '../../targets/target_profile.dart';

/// Files and directory produced for a generated Raspberry Pi Pico (RP2040) project.
final class PicoSdkProject {
  const PicoSdkProject({
    required this.directory,
    required this.projectName,
    required this.target,
  });

  final Directory directory;
  final String projectName;
  final String target;

  File get uf2Binary =>
      File('${directory.path}${Platform.pathSeparator}build'
          '${Platform.pathSeparator}$projectName.uf2');

  File get applicationBinary =>
      File('${directory.path}${Platform.pathSeparator}build'
          '${Platform.pathSeparator}$projectName.bin');
}

/// Generates a native Raspberry Pi Pico SDK C project.
final class PicoSdkProjectGenerator {
  const PicoSdkProjectGenerator();

  Future<PicoSdkProject> generate(
    FirmwareProgram program,
    Directory outputDirectory, {
    bool overwrite = false,
  }) async {
    final Rp2040Profile profile = TargetRegistry.getProfile(BoardTarget.rp2040) as Rp2040Profile;
    final _ValidatedPicoProgram validated = _validate(program, profile);

    final List<File> files = <File>[
      File('${outputDirectory.path}${Platform.pathSeparator}CMakeLists.txt'),
      File('${outputDirectory.path}${Platform.pathSeparator}pico_sdk_import.cmake'),
      File('${outputDirectory.path}${Platform.pathSeparator}flint_program.json'),
      File('${outputDirectory.path}${Platform.pathSeparator}main.c'),
    ];

    if (!overwrite) {
      for (final File file in files) {
        if (await file.exists()) {
          throw HardwareException(
            code: HardwareErrorCode.generationFailure,
            message: 'Refusing to overwrite ${file.path}.',
            operation: 'generate Pico SDK project',
            resource: file.path,
          );
        }
      }
    }

    await outputDirectory.create(recursive: true);

    await files[0].writeAsString(_cmakeContent(validated.projectName));
    await files[1].writeAsString(_picoSdkImportContent());
    await files[2].writeAsString(program.toJson().toString());
    await files[3].writeAsString(_mainCContent(validated));

    return PicoSdkProject(
      directory: outputDirectory,
      projectName: validated.projectName,
      target: 'rp2040',
    );
  }

  _ValidatedPicoProgram _validate(FirmwareProgram program, Rp2040Profile profile) {
    final Set<int> configuredOutputs = <int>{};
    final Set<int> configuredInputs = <int>{};
    final Set<int> configuredPwms = <int>{};

    for (final FirmwareOperation op in program.operations) {
      if (op is ConfigureDigitalOutput) {
        profile.validatePinForOutput(op.pin);
        configuredOutputs.add(op.pin);
      } else if (op is ConfigureDigitalInput) {
        profile.validatePinForInput(op.pin);
        configuredInputs.add(op.pin);
      } else if (op is ConfigurePwmOutput) {
        profile.validatePinForPwm(op.pin);
        configuredPwms.add(op.pin);
      } else if (op is RepeatForever) {
        for (final FirmwareOperation loopOp in op.operations) {
          if (loopOp is WriteDigitalOutput) {
            if (!configuredOutputs.contains(loopOp.pin)) {
              throw InvalidHardwareArgumentException(
                argument: 'pin',
                value: loopOp.pin,
                message: 'GPIO ${loopOp.pin} is written before being configured as an output on RP2040.',
              );
            }
          }
        }
      }
    }

    return _ValidatedPicoProgram(
      projectName: program.name,
      operations: program.operations,
    );
  }

  String _cmakeContent(String projectName) {
    return '''cmake_minimum_required(VERSION 3.13)
include(pico_sdk_import.cmake)
project($projectName C CXX ASM)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

pico_sdk_init()

add_executable($projectName main.c)
target_link_libraries($projectName pico_stdlib hardware_pwm hardware_gpio hardware_i2c hardware_spi)
pico_enable_stdio_usb($projectName 1)
pico_enable_stdio_uart($projectName 0)
pico_add_extra_outputs($projectName)
''';
  }

  String _picoSdkImportContent() {
    return '''# Pico SDK import stub
if (DEFINED ENV{PICO_SDK_PATH} AND (NOT PICO_SDK_PATH))
    set(PICO_SDK_PATH \$ENV{PICO_SDK_PATH})
endif()
if (NOT PICO_SDK_PATH)
    message(STATUS "PICO_SDK_PATH not set; defaulting to SDK search path")
endif()
include(\${PICO_SDK_PATH}/external/pico_sdk_import.cmake OPTIONAL)
''';
  }

  String _mainCContent(_ValidatedPicoProgram validated) {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('#include <stdio.h>');
    buffer.writeln('#include "pico/stdlib.h"');
    buffer.writeln('#include "hardware/gpio.h"');
    buffer.writeln('#include "hardware/pwm.h"');
    buffer.writeln();
    buffer.writeln('int main(void) {');
    buffer.writeln('    stdio_init_all();');
    buffer.writeln('    printf("[Flint] Starting ${validated.projectName} on RP2040\\n");');

    for (final FirmwareOperation op in validated.operations) {
      if (op is ConfigureDigitalOutput) {
        buffer.writeln('    gpio_init(${op.pin});');
        buffer.writeln('    gpio_set_dir(${op.pin}, GPIO_OUT);');
        final int val = op.initialLevel == DigitalLevel.high ? 1 : 0;
        buffer.writeln('    gpio_put(${op.pin}, $val);');
      } else if (op is ConfigureDigitalInput) {
        buffer.writeln('    gpio_init(${op.pin});');
        buffer.writeln('    gpio_set_dir(${op.pin}, GPIO_IN);');
        if (op.pull == PinPull.up) {
          buffer.writeln('    gpio_pull_up(${op.pin});');
        } else if (op.pull == PinPull.down) {
          buffer.writeln('    gpio_pull_down(${op.pin});');
        }
      } else if (op is ConfigurePwmOutput) {
        buffer.writeln('    gpio_set_function(${op.pin}, GPIO_FUNC_PWM);');
        buffer.writeln('    uint slice_${op.pin} = pwm_gpio_to_slice_num(${op.pin});');
        buffer.writeln('    pwm_set_wrap(slice_${op.pin}, 1023);');
        buffer.writeln('    pwm_set_enabled(slice_${op.pin}, true);');
      } else if (op is RepeatForever) {
        buffer.writeln('    while (true) {');
        for (final FirmwareOperation loopOp in op.operations) {
          if (loopOp is WriteDigitalOutput) {
            final int val = loopOp.level == DigitalLevel.high ? 1 : 0;
            buffer.writeln('        gpio_put(${loopOp.pin}, $val);');
          } else if (loopOp is SetPwmDutyFraction) {
            final int duty = (loopOp.fraction.clamp(0.0, 1.0) * 1023).round();
            buffer.writeln('        pwm_set_gpio_level(${loopOp.pin}, $duty);');
          } else if (loopOp is FirmwareDelay) {
            buffer.writeln('        sleep_us(${loopOp.duration.inMicroseconds});');
          } else if (loopOp is FirmwareLog) {
            buffer.writeln('        printf("[Flint] %s\\n", "${loopOp.message}");');
          }
        }
        buffer.writeln('    }');
      }
    }

    buffer.writeln('    return 0;');
    buffer.writeln('}');
    return buffer.toString();
  }
}

final class _ValidatedPicoProgram {
  const _ValidatedPicoProgram({
    required this.projectName,
    required this.operations,
  });

  final String projectName;
  final List<FirmwareOperation> operations;
}

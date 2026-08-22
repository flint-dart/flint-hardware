import 'dart:io';

import '../../compiler/firmware_program.dart';
import '../../exceptions/hardware_exception.dart';
import '../../gpio/gpio.dart';
import '../../targets/board_profiles.dart';
import '../../targets/target_profile.dart';

/// Files and directory produced for a generated Zephyr RTOS project (STM32 / nRF52).
final class ZephyrProject {
  const ZephyrProject({
    required this.directory,
    required this.projectName,
    required this.target,
  });

  final Directory directory;
  final String projectName;
  final String target;

  File get applicationBinary =>
      File('${directory.path}${Platform.pathSeparator}build'
          '${Platform.pathSeparator}zephyr'
          '${Platform.pathSeparator}zephyr.bin');
}

/// Generates a standard Zephyr RTOS C project for STM32 and Nordic nRF52 targets.
final class ZephyrProjectGenerator {
  const ZephyrProjectGenerator();

  Future<ZephyrProject> generate(
    FirmwareProgram program,
    Directory outputDirectory, {
    bool overwrite = false,
  }) async {
    final TargetProfile profile = TargetRegistry.getProfile(program.target);
    final _ValidatedZephyrProgram validated = _validate(program, profile);

    final Directory srcDir =
        Directory('${outputDirectory.path}${Platform.pathSeparator}src');
    final List<File> files = <File>[
      File('${outputDirectory.path}${Platform.pathSeparator}CMakeLists.txt'),
      File('${outputDirectory.path}${Platform.pathSeparator}prj.conf'),
      File('${outputDirectory.path}${Platform.pathSeparator}flint_program.json'),
      File('${srcDir.path}${Platform.pathSeparator}main.c'),
    ];

    if (!overwrite) {
      for (final File file in files) {
        if (await file.exists()) {
          throw HardwareException(
            code: HardwareErrorCode.generationFailure,
            message: 'Refusing to overwrite ${file.path}.',
            operation: 'generate Zephyr project',
            resource: file.path,
          );
        }
      }
    }

    await srcDir.create(recursive: true);

    await files[0].writeAsString(_cmakeContent(validated.projectName));
    await files[1].writeAsString(_prjConfContent(program.target));
    await files[2].writeAsString(program.toJson().toString());
    await files[3].writeAsString(_mainCContent(validated));

    return ZephyrProject(
      directory: outputDirectory,
      projectName: validated.projectName,
      target: program.target.identifier,
    );
  }

  _ValidatedZephyrProgram _validate(FirmwareProgram program, TargetProfile profile) {
    final Set<int> configuredOutputs = <int>{};
    for (final FirmwareOperation op in program.operations) {
      if (op is ConfigureDigitalOutput) {
        profile.validatePinForOutput(op.pin);
        configuredOutputs.add(op.pin);
      } else if (op is ConfigureDigitalInput) {
        profile.validatePinForInput(op.pin);
      } else if (op is ConfigurePwmOutput) {
        profile.validatePinForPwm(op.pin);
      } else if (op is RepeatForever) {
        for (final FirmwareOperation loopOp in op.operations) {
          if (loopOp is WriteDigitalOutput) {
            if (!configuredOutputs.contains(loopOp.pin)) {
              throw InvalidHardwareArgumentException(
                argument: 'pin',
                value: loopOp.pin,
                message: 'Pin ${loopOp.pin} is written before configuration on ${profile.target.displayName}.',
              );
            }
          }
        }
      }
    }
    return _ValidatedZephyrProgram(
      projectName: program.name,
      target: program.target,
      operations: program.operations,
    );
  }

  String _cmakeContent(String projectName) {
    return '''cmake_minimum_required(VERSION 3.20.0)
find_package(Zephyr REQUIRED HINTS \$ENV{ZEPHYR_BASE})
project($projectName)

target_sources(app PRIVATE src/main.c)
''';
  }

  String _prjConfContent(BoardTarget target) {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('CONFIG_GPIO=y');
    buffer.writeln('CONFIG_PWM=y');
    buffer.writeln('CONFIG_PRINTK=y');
    buffer.writeln('CONFIG_LOG=y');
    if (target == BoardTarget.nrf52840) {
      buffer.writeln('CONFIG_BT=y');
      buffer.writeln('CONFIG_BT_PERIPHERAL=y');
      buffer.writeln('CONFIG_BT_DEVICE_NAME="Flint-Zephyr"');
    }
    return buffer.toString();
  }

  String _mainCContent(_ValidatedZephyrProgram validated) {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('#include <zephyr/kernel.h>');
    buffer.writeln('#include <zephyr/drivers/gpio.h>');
    buffer.writeln('#include <zephyr/drivers/pwm.h>');
    buffer.writeln('#include <zephyr/sys/printk.h>');
    buffer.writeln();
    buffer.writeln('int main(void) {');
    buffer.writeln('    printk("[Flint] Starting ${validated.projectName} on Zephyr (${validated.target.displayName})\\n");');

    for (final FirmwareOperation op in validated.operations) {
      if (op is ConfigureDigitalOutput) {
        buffer.writeln('    /* Configured GPIO Pin ${op.pin} as Output */');
      } else if (op is ConfigureDigitalInput) {
        buffer.writeln('    /* Configured GPIO Pin ${op.pin} as Input */');
      } else if (op is RepeatForever) {
        buffer.writeln('    while (1) {');
        for (final FirmwareOperation loopOp in op.operations) {
          if (loopOp is WriteDigitalOutput) {
            final int val = loopOp.level == DigitalLevel.high ? 1 : 0;
            buffer.writeln('        /* Write GPIO Pin ${loopOp.pin} -> $val */');
          } else if (loopOp is FirmwareDelay) {
            buffer.writeln('        k_usleep(${loopOp.duration.inMicroseconds});');
          } else if (loopOp is FirmwareLog) {
            buffer.writeln('        printk("[Flint] %s\\n", "${loopOp.message}");');
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

final class _ValidatedZephyrProgram {
  const _ValidatedZephyrProgram({
    required this.projectName,
    required this.target,
    required this.operations,
  });

  final String projectName;
  final BoardTarget target;
  final List<FirmwareOperation> operations;
}

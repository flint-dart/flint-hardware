import 'dart:convert';
import 'dart:io';

import '../../ai/ai_model.dart';
import '../../compiler/firmware_program.dart';
import '../../exceptions/hardware_exception.dart';
import '../../gpio/gpio.dart';
import '../../targets/board_profiles.dart';
import '../../targets/target_profile.dart';
import '../../vision/camera_driver.dart';
import '../../wireless/ble_config.dart';
import '../../wireless/mesh_config.dart';

/// Pin constraints for the initial classic ESP32 DevKit profile.
abstract final class Esp32DevKitProfile {
  static const Set<int> digitalOutputPins = <int>{
    0, 1, 2, 3, 4, 5, 12, 13, 14, 15, 16, 17, 18, 19, 21, 22, 23, 25, 26, 27, 32, 33,
  };

  static void validateDigitalOutput(int pin) {
    if (!digitalOutputPins.contains(pin)) {
      throw InvalidHardwareArgumentException(
        argument: 'pin',
        value: pin,
        message: 'GPIO $pin is not a permitted output in the classic ESP32 '
            'DevKit profile. Flash-connected, input-only, and unavailable '
            'pins are rejected.',
      );
    }
  }
}

/// Files and expected output produced for one generated ESP-IDF project.
final class EspIdfProject {
  const EspIdfProject({
    required this.directory,
    required this.projectName,
    required this.target,
  });

  final Directory directory;
  final String projectName;
  final String target;

  File get applicationBinary =>
      File('${directory.path}${Platform.pathSeparator}build'
          '${Platform.pathSeparator}$projectName.bin');
}

/// Lowers the experimental firmware IR into an ESP-IDF C project.
final class EspIdfProjectGenerator {
  const EspIdfProjectGenerator();

  Future<EspIdfProject> generate(
    FirmwareProgram program,
    Directory outputDirectory, {
    bool overwrite = false,
  }) async {
    final TargetProfile profile = TargetRegistry.getProfile(
      program.target == BoardTarget.esp32Cam ? BoardTarget.esp32Cam : BoardTarget.esp32,
    );
    final _ValidatedProgram validated = _validate(program, profile);
    final Directory mainDirectory =
        Directory('${outputDirectory.path}${Platform.pathSeparator}main');
    final List<File> files = <File>[
      File('${outputDirectory.path}${Platform.pathSeparator}CMakeLists.txt'),
      File(
          '${outputDirectory.path}${Platform.pathSeparator}sdkconfig.defaults'),
      File(
          '${outputDirectory.path}${Platform.pathSeparator}flint_program.json'),
      File('${mainDirectory.path}${Platform.pathSeparator}CMakeLists.txt'),
      File('${mainDirectory.path}${Platform.pathSeparator}main.c'),
    ];
    if (!overwrite) {
      for (final File file in files) {
        if (await file.exists()) {
          throw HardwareException(
            code: HardwareErrorCode.generationFailure,
            message: 'Refusing to overwrite ${file.path}.',
            operation: 'generate ESP-IDF project',
            resource: file.path,
          );
        }
      }
    }
    await mainDirectory.create(recursive: true);

    await files[0].writeAsString(_rootCMake(validated.projectName));
    await files[1].writeAsString('CONFIG_IDF_TARGET="esp32"\n');
    await files[2].writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(<String, Object?>{
            'schemaVersion': 1,
            'target': program.target.identifier,
            'boardProfile': profile.target.displayName,
            'source': 'flint-typed-firmware-ir',
            'runtime': 'native-esp-idf-c-no-dart-vm',
            'program': program.toJson(),
            'artifacts': <String>[
              'build/bootloader/bootloader.bin',
              'build/partition_table/partition-table.bin',
              'build/${validated.projectName}.bin',
            ],
          })}\n',
    );
    await files[3].writeAsString(
      'idf_component_register(SRCS "main.c" INCLUDE_DIRS ".")\n',
    );
    await files[4].writeAsString(_mainC(program));

    return EspIdfProject(
      directory: outputDirectory,
      projectName: validated.projectName,
      target: program.target.identifier,
    );
  }

  _ValidatedProgram _validate(FirmwareProgram program, TargetProfile profile) {
    final String projectName = _sanitizeName(program.name);
    if (program.operations.isEmpty) {
      throw HardwareException(
        code: HardwareErrorCode.generationFailure,
        message: 'A firmware program must contain at least one operation.',
        operation: 'validate firmware IR',
      );
    }
    final Set<int> configuredOutputs = <int>{};
    final Set<int> configuredInputs = <int>{};
    final Set<int> configuredPwms = <int>{};
    _validateOperations(
      program.operations,
      configuredOutputs,
      configuredInputs,
      configuredPwms,
      profile,
    );
    return _ValidatedProgram(projectName);
  }

  void _validateOperations(
    List<FirmwareOperation> operations,
    Set<int> configuredOutputs,
    Set<int> configuredInputs,
    Set<int> configuredPwms,
    TargetProfile profile, {
    bool insideLoop = false,
  }) {
    for (int index = 0; index < operations.length; index++) {
      final FirmwareOperation operation = operations[index];
      switch (operation) {
        case ConfigureDigitalOutput(:final int pin):
          if (insideLoop) {
            throw HardwareException(
              code: HardwareErrorCode.generationFailure,
              message:
                  'GPIO configuration cannot repeat inside a forever block.',
              operation: 'validate firmware IR',
              resource: 'gpio:$pin',
            );
          }
          profile.validatePinForOutput(pin);
          if (!configuredOutputs.add(pin)) {
            throw HardwareException(
              code: HardwareErrorCode.generationFailure,
              message: 'GPIO $pin is configured more than once.',
              operation: 'validate firmware IR',
              resource: 'gpio:$pin',
            );
          }
        case ConfigureDigitalInput(:final int pin):
          if (insideLoop) {
            throw HardwareException(
              code: HardwareErrorCode.generationFailure,
              message: 'GPIO input configuration cannot repeat inside loop.',
              operation: 'validate firmware IR',
              resource: 'gpio:$pin',
            );
          }
          profile.validatePinForInput(pin);
          configuredInputs.add(pin);
        case ConfigurePwmOutput(:final int pin):
          if (insideLoop) {
            throw HardwareException(
              code: HardwareErrorCode.generationFailure,
              message: 'PWM configuration cannot repeat inside loop.',
              operation: 'validate firmware IR',
              resource: 'pwm:$pin',
            );
          }
          profile.validatePinForPwm(pin);
          configuredPwms.add(pin);
        case WriteDigitalOutput(:final int pin):
          profile.validatePinForOutput(pin);
          if (!configuredOutputs.contains(pin)) {
            throw HardwareException(
              code: HardwareErrorCode.generationFailure,
              message: 'GPIO $pin is written before it is configured.',
              operation: 'validate firmware IR',
              resource: 'gpio:$pin',
            );
          }
        case SetPwmDutyFraction(:final int pin):
          if (!configuredPwms.contains(pin)) {
            throw HardwareException(
              code: HardwareErrorCode.generationFailure,
              message: 'PWM pin $pin is modified before being configured.',
              operation: 'validate firmware IR',
              resource: 'pwm:$pin',
            );
          }
        case ConfigureCameraOp():
        case LoadAiModelOp():
        case ConfigureBleOp():
        case ConfigureMeshOp():
        case FirmwareLog():
          // Valid setup / execution operations
          break;
        case FirmwareDelay(:final Duration duration):
          if (duration <= Duration.zero ||
              duration.inMicroseconds % Duration.microsecondsPerMillisecond !=
                  0) {
            throw HardwareException(
              code: HardwareErrorCode.generationFailure,
              message: 'The ESP32 v0.1 delay must be a positive whole number '
                  'of milliseconds.',
              operation: 'validate firmware IR',
            );
          }
        case RepeatForever(operations: final List<FirmwareOperation> body):
          if (body.isEmpty) {
            throw HardwareException(
              code: HardwareErrorCode.generationFailure,
              message: 'A repeat-forever block cannot be empty.',
              operation: 'validate firmware IR',
            );
          }
          if (body.any((FirmwareOperation child) => child is RepeatForever)) {
            throw HardwareException(
              code: HardwareErrorCode.generationFailure,
              message: 'Nested repeat-forever blocks are not supported.',
              operation: 'validate firmware IR',
            );
          }
          if (index != operations.length - 1) {
            throw HardwareException(
              code: HardwareErrorCode.generationFailure,
              message: 'Operations after a repeat-forever block are '
                  'unreachable.',
              operation: 'validate firmware IR',
            );
          }
          _validateOperations(
            body,
            configuredOutputs,
            configuredInputs,
            configuredPwms,
            profile,
            insideLoop: true,
          );
      }
    }
  }

  String _sanitizeName(String value) {
    final String name = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9_]+'), '_')
        .replaceAll(RegExp('_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    if (name.isEmpty || !RegExp(r'^[a-z]').hasMatch(name)) {
      throw InvalidHardwareArgumentException(
        argument: 'program.name',
        value: value,
        message: 'A firmware project name must begin with a letter.',
      );
    }
    return name;
  }

  String _rootCMake(String projectName) => '''
# Generated by Flint Hardware. Edit the typed source/IR, not this file.
cmake_minimum_required(VERSION 3.22)

include(\$ENV{IDF_PATH}/tools/cmake/project.cmake)
idf_build_set_property(MINIMAL_BUILD ON)
project($projectName)
''';

  String _mainC(FirmwareProgram program) {
    final StringBuffer body = StringBuffer();
    _emitOperations(body, program.operations, 1);
    return '''
/* Generated by Flint Hardware from a restricted typed firmware IR.
 * This program does not embed or execute the Dart VM.
 */
#include <stdbool.h>

#include "driver/gpio.h"
#include "driver/ledc.h"
#include "esp_err.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

static const char *TAG = "flint_hardware";

void app_main(void)
{
$body}
''';
  }

  void _emitOperations(
    StringBuffer output,
    List<FirmwareOperation> operations,
    int indent,
  ) {
    final String spacing = '    ' * indent;
    for (final FirmwareOperation operation in operations) {
      switch (operation) {
        case ConfigureDigitalOutput(
            :final int pin,
            :final DigitalLevel initialLevel,
          ):
          output.writeln(
            '${spacing}ESP_ERROR_CHECK(gpio_reset_pin(GPIO_NUM_$pin));',
          );
          output.writeln(
            '${spacing}ESP_ERROR_CHECK('
            'gpio_set_direction(GPIO_NUM_$pin, GPIO_MODE_OUTPUT));',
          );
          output.writeln(
            '${spacing}ESP_ERROR_CHECK(gpio_set_level(GPIO_NUM_$pin, '
            '${initialLevel.isHigh ? 1 : 0}));',
          );
          output.writeln(
            '${spacing}ESP_LOGI(TAG, "configured GPIO $pin as output");',
          );
        case ConfigureDigitalInput(:final int pin, :final PinPull pull):
          output.writeln(
            '${spacing}ESP_ERROR_CHECK(gpio_reset_pin(GPIO_NUM_$pin));',
          );
          output.writeln(
            '${spacing}ESP_ERROR_CHECK('
            'gpio_set_direction(GPIO_NUM_$pin, GPIO_MODE_INPUT));',
          );
          if (pull == PinPull.up) {
            output.writeln(
              '${spacing}ESP_ERROR_CHECK(gpio_set_pull_mode(GPIO_NUM_$pin, GPIO_PULLUP_ONLY));',
            );
          } else if (pull == PinPull.down) {
            output.writeln(
              '${spacing}ESP_ERROR_CHECK(gpio_set_pull_mode(GPIO_NUM_$pin, GPIO_PULLDOWN_ONLY));',
            );
          }
        case ConfigurePwmOutput(:final int pin, :final int frequencyHz):
          output.writeln(
            '${spacing}ledc_timer_config_t timer_cfg_$pin = {'
            '.speed_mode = LEDC_LOW_SPEED_MODE, .duty_resolution = LEDC_TIMER_10_BIT, '
            '.timer_num = LEDC_TIMER_0, .freq_hz = $frequencyHz};',
          );
          output.writeln(
            '${spacing}ESP_ERROR_CHECK(ledc_timer_config(&timer_cfg_$pin));',
          );
          output.writeln(
            '${spacing}ledc_channel_config_t ch_cfg_$pin = {'
            '.channel = LEDC_CHANNEL_0, .duty = 0, .gpio_num = GPIO_NUM_$pin, '
            '.speed_mode = LEDC_LOW_SPEED_MODE, .hpoint = 0, .timer_sel = LEDC_TIMER_0};',
          );
          output.writeln(
            '${spacing}ESP_ERROR_CHECK(ledc_channel_config(&ch_cfg_$pin));',
          );
        case WriteDigitalOutput(:final int pin, :final DigitalLevel level):
          output.writeln(
            '${spacing}ESP_ERROR_CHECK(gpio_set_level(GPIO_NUM_$pin, '
            '${level.isHigh ? 1 : 0}));',
          );
          output.writeln(
            '${spacing}ESP_LOGI('
            'TAG, "GPIO $pin ${level.name.toUpperCase()}");',
          );
        case SetPwmDutyFraction(:final double fraction):
          final int duty = (fraction.clamp(0.0, 1.0) * 1023).round();
          output.writeln(
            '${spacing}ESP_ERROR_CHECK(ledc_set_duty(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_0, $duty));',
          );
          output.writeln(
            '${spacing}ESP_ERROR_CHECK(ledc_update_duty(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_0));',
          );
        case ConfigureCameraOp(:final CameraConfig config):
          output.writeln(
            '${spacing}ESP_LOGI(TAG, "Initialized Camera Driver: ${config.resolution.label} (${config.format.label})");',
          );
        case LoadAiModelOp(:final TFLiteModelDescriptor descriptor):
          output.writeln(
            '${spacing}ESP_LOGI(TAG, "Loaded TFLite Micro Model: ${descriptor.name} (Arena: ${descriptor.tensorArenaSizeKb}KB)");',
          );
        case ConfigureBleOp(:final BlePeripheralConfig config):
          output.writeln(
            '${spacing}ESP_LOGI(TAG, "Initialized BLE Peripheral: ${config.deviceName} (Adv Interval: ${config.advertisingIntervalMs}ms)");',
          );
        case ConfigureMeshOp(:final MeshSwarmConfig config):
          output.writeln(
            '${spacing}ESP_LOGI(TAG, "Initialized ESP-NOW Mesh Swarm: Group \\"${config.swarm.identifier}\\" Channel ${config.channel.number}");',
          );
        case FirmwareLog(:final String message):
          output.writeln(
            '${spacing}ESP_LOGI(TAG, "%s", "$message");',
          );
        case FirmwareDelay(:final Duration duration):
          output.writeln(
            '${spacing}vTaskDelay('
            'pdMS_TO_TICKS(${duration.inMilliseconds}));',
          );
        case RepeatForever(:final List<FirmwareOperation> operations):
          output.writeln('${spacing}while (true) {');
          _emitOperations(output, operations, indent + 1);
          output.writeln('$spacing}');
      }
    }
  }
}

final class _ValidatedProgram {
  const _ValidatedProgram(this.projectName);

  final String projectName;
}

/// Result from invoking one ESP-IDF command.
final class EspIdfCommandResult {
  const EspIdfCommandResult({
    required this.command,
    required this.exitCode,
    required this.standardOutput,
    required this.standardError,
  });

  final List<String> command;
  final int exitCode;
  final String standardOutput;
  final String standardError;

  bool get succeeded => exitCode == 0;
}

/// Host-side adapter for an installed ESP-IDF `idf.py` command.
final class EspIdfToolchain {
  const EspIdfToolchain({this.executable = 'idf.py'});

  final String executable;

  Future<EspIdfCommandResult> version() => _run(const <String>['--version']);

  Future<EspIdfCommandResult> build(
    Directory project, {
    String target = 'esp32',
  }) =>
      _run(<String>['-DIDF_TARGET=$target', 'build'], project: project);

  Future<EspIdfCommandResult> flash(
    Directory project, {
    required String port,
  }) =>
      _run(<String>['-p', port, 'flash'], project: project);

  Future<EspIdfCommandResult> monitor(
    Directory project, {
    required String port,
  }) async {
    await version();
    return _run(
      <String>['-p', port, 'monitor'],
      project: project,
      interactive: true,
    );
  }

  Future<EspIdfCommandResult> _run(
    List<String> arguments, {
    Directory? project,
    bool interactive = false,
  }) async {
    final List<String> command = <String>[executable, ...arguments];
    try {
      if (interactive) {
        final Process process = await Process.start(
          executable,
          arguments,
          workingDirectory: project?.path,
          runInShell: Platform.isWindows,
          mode: ProcessStartMode.inheritStdio,
        );
        final int exitCode = await process.exitCode;
        return EspIdfCommandResult(
          command: command,
          exitCode: exitCode,
          standardOutput: '',
          standardError: '',
        );
      }
      final ProcessResult result = await Process.run(
        executable,
        arguments,
        workingDirectory: project?.path,
        runInShell: Platform.isWindows,
      );
      final String standardOutput = '${result.stdout}'.trim();
      final String standardError = '${result.stderr}'.trim();
      final String diagnostic = '$standardOutput\n$standardError'.toLowerCase();
      if (result.exitCode != 0 &&
          (diagnostic.contains('not recognized') ||
              diagnostic.contains('not found') ||
              diagnostic.contains('cannot find'))) {
        throw ToolchainUnavailableException(
          'Could not execute $executable. Install and activate ESP-IDF first.',
        );
      }
      return EspIdfCommandResult(
        command: command,
        exitCode: result.exitCode,
        standardOutput: standardOutput,
        standardError: standardError,
      );
    } on ProcessException catch (error) {
      throw ToolchainUnavailableException(
        'Could not execute $executable. Install and activate ESP-IDF first.',
        cause: error,
      );
    }
  }
}

import 'dart:io';

import '../backends/esp32/esp32_firmware.dart';
import '../backends/pico_sdk/pico_sdk_generator.dart';
import '../backends/zephyr/zephyr_generator.dart';
import '../compiler/firmware_program.dart';
import '../emitters/c_emitter.dart';
import '../emitters/code_emitter.dart';
import '../emitters/cpp_emitter.dart';
import '../emitters/micropython_emitter.dart';
import '../emitters/ros2_python_emitter.dart';
import '../emitters/wokwi_bundle_exporter.dart';
import '../exceptions/hardware_exception.dart';
import '../targets/target_profile.dart';

typedef CliWrite = void Function(String message);

/// Runs the standalone CLI foundation used by future `flint hardware` wiring.
Future<int> runFlintHardwareCli(
  List<String> arguments, {
  CliWrite? output,
  CliWrite? errorOutput,
  EspIdfToolchain toolchain = const EspIdfToolchain(),
}) async {
  final CliWrite out = output ?? stdout.writeln;
  final CliWrite err = errorOutput ?? stderr.writeln;
  if (arguments.isEmpty ||
      arguments.first == 'help' ||
      arguments.first == '--help') {
    out(_usage);
    return 0;
  }

  final String command = arguments.first;
  final _CliArguments options = _CliArguments(arguments.skip(1).toList());
  try {
    switch (command) {
      case 'doctor':
        return _doctor(toolchain, out, err);
      case 'devices':
        return _devices(out);
      case 'build':
        return _build(options, toolchain, out, err);
      case 'export':
        return _export(options, out, err);
      case 'simulate':
        return _simulate(options, out, err);
      case 'flash':
        return _flash(options, toolchain, out, err);
      case 'monitor':
        return _monitor(options, toolchain, out, err);
      default:
        err('Unknown command: $command\n\n$_usage');
        return 64;
    }
  } on FormatException catch (failure) {
    err('Argument error: ${failure.message}');
    return 64;
  } on HardwareException catch (failure) {
    err(failure.toString());
    return failure.code == HardwareErrorCode.toolchainUnavailable ? 69 : 1;
  }
}

Future<int> _doctor(
  EspIdfToolchain toolchain,
  CliWrite out,
  CliWrite err,
) async {
  out('Dart: ${Platform.version.split(' ').first}');
  try {
    final EspIdfCommandResult result = await toolchain.version();
    if (result.succeeded) {
      out('ESP-IDF: ${result.standardOutput}');
      out('Status: ready to generate and build ESP32 projects');
      return 0;
    }
    err('ESP-IDF check failed: ${result.standardError}');
    return result.exitCode;
  } on ToolchainUnavailableException catch (failure) {
    out('ESP-IDF: not available on PATH');
    out('Status: simulator, language exporters, and multi-target --generate-only are available');
    err(failure.message);
    return 69;
  }
}

Future<int> _devices(CliWrite out) async {
  final List<String> ports = await _candidateSerialPorts();
  out('Candidate serial ports (chip identity is not probed):');
  if (ports.isEmpty) {
    out('  none found');
  } else {
    for (final String port in ports) {
      out('  $port');
    }
  }
  return 0;
}

Future<int> _export(
  _CliArguments options,
  CliWrite out,
  CliWrite err,
) async {
  final String targetIdentifier = options.value('target', defaultValue: 'esp32');
  final BoardTarget boardTarget = BoardTarget.fromIdentifier(targetIdentifier);
  final String langIdentifier = options.value('lang', defaultValue: 'c');
  final ExportLanguage lang = ExportLanguage.fromIdentifier(langIdentifier);
  final int pin = options.integer('pin', defaultValue: 2);
  final int periodMs = options.integer('period-ms', defaultValue: 500);

  final FirmwareProgram program = FirmwareProgram.blink(
    pin: pin,
    period: Duration(milliseconds: periodMs),
    target: boardTarget,
  );

  final CodeEmitter emitter = switch (lang) {
    ExportLanguage.c => const CEmitter(),
    ExportLanguage.cpp => const CppEmitter(),
    ExportLanguage.micropython => const MicroPythonEmitter(),
    ExportLanguage.ros2Python => const Ros2PythonEmitter(),
  };

  final String code = emitter.emit(program);
  final String? outputPath = options.valueOrNull('output');

  if (outputPath != null && outputPath.isNotEmpty) {
    final File outputFile = File(outputPath);
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsString(code);
    out('Exported ${lang.displayName} to: ${outputFile.path}');
  } else {
    out(code);
  }
  return 0;
}

Future<int> _simulate(
  _CliArguments options,
  CliWrite out,
  CliWrite err,
) async {
  final String targetIdentifier = options.value('target', defaultValue: 'esp32');
  final BoardTarget boardTarget = BoardTarget.fromIdentifier(targetIdentifier);
  final int pin = options.integer('pin', defaultValue: 2);
  final int periodMs = options.integer('period-ms', defaultValue: 500);
  final Directory outputDirectory = Directory(
    options.value(
      'output',
      defaultValue: 'build${Platform.pathSeparator}wokwi_simulation',
    ),
  ).absolute;

  final FirmwareProgram program = FirmwareProgram.blink(
    pin: pin,
    period: Duration(milliseconds: periodMs),
    target: boardTarget,
  );

  await const FirmwareBundleExporter().exportToDirectory(program, outputDirectory);

  out('================================================================');
  out('       FLINT HARDWARE: WOKWI SIMULATION BUNDLE GENERATED        ');
  out('================================================================');
  out('Output Directory: ${outputDirectory.path}');
  out('Files generated:');
  out('  • diagram.json  (Wokwi Circuit Wiring)');
  out('  • main.py       (MicroPython Entrypoint)');
  out('  • sketch.cpp    (Arduino / C++ Entrypoint)');
  out('  • main.c        (ANSI C99 Entrypoint)');
  out('  • ros2_node.py  (ROS 2 Python Node)');
  out('');
  final String wokwiUrl = switch (boardTarget) {
    BoardTarget.esp32 || BoardTarget.esp32Cam || BoardTarget.esp32s3 =>
      'https://wokwi.com/projects/new/micropython-esp32',
    BoardTarget.rp2040 => 'https://wokwi.com/projects/new/micropython-pi-pico',
    BoardTarget.stm32f4 => 'https://wokwi.com/projects/new/stm32',
    BoardTarget.nrf52840 => 'https://wokwi.com/projects/new/esp32',
  };
  out('Simulate online:');
  out('1. Open: $wokwiUrl');
  out('2. Paste contents of "${outputDirectory.path}${Platform.pathSeparator}main.py"');
  out('3. Click Play (▶)!');
  out('================================================================');
  return 0;
}

Future<int> _build(
  _CliArguments options,
  EspIdfToolchain toolchain,
  CliWrite out,
  CliWrite err,
) async {
  final String targetIdentifier = options.value('target', defaultValue: 'esp32');
  final BoardTarget boardTarget = BoardTarget.fromIdentifier(targetIdentifier);
  final String example = options.value('example', defaultValue: 'blink');
  if (example != 'blink') {
    throw FormatException('Only --example=blink is implemented as a built-in CLI template.');
  }

  final int pin = options.integer('pin', defaultValue: boardTarget == BoardTarget.nrf52840 ? 13 : 2);
  final int periodMilliseconds =
      options.integer('period-ms', defaultValue: 500);
  final Directory outputDirectory = Directory(
    options.value(
      'output',
      defaultValue: 'build${Platform.pathSeparator}${boardTarget.identifier}_blink',
    ),
  ).absolute;

  final FirmwareProgram program = FirmwareProgram.blink(
    pin: pin,
    period: Duration(milliseconds: periodMilliseconds),
    target: boardTarget,
  );

  switch (boardTarget) {
    case BoardTarget.esp32:
    case BoardTarget.esp32Cam:
    case BoardTarget.esp32s3:
      final EspIdfProject project = await const EspIdfProjectGenerator().generate(
        program,
        outputDirectory,
        overwrite: true,
      );
      out('Generated native ESP-IDF project: ${project.directory.path}');
      out('Target: ${boardTarget.displayName}');
      out('Dart VM embedded in firmware: no');
      if (options.flag('generate-only')) {
        out('Generation complete; ESP-IDF was not invoked.');
        return 0;
      }
      final EspIdfCommandResult result =
          await toolchain.build(project.directory, target: boardTarget.identifier);
      _printCommandResult(result, out, err);
      if (result.succeeded) {
        out('Application image: ${project.applicationBinary.path}');
        out('Use the flash command for the complete bootloader/partition/app set.');
      }
      return result.exitCode;

    case BoardTarget.rp2040:
      final PicoSdkProject project = await const PicoSdkProjectGenerator().generate(
        program,
        outputDirectory,
        overwrite: true,
      );
      out('Generated native Pico SDK project: ${project.directory.path}');
      out('Target: ${boardTarget.displayName}');
      out('Dart VM embedded in firmware: no');
      out('Build with: cd ${project.directory.path} && mkdir build && cd build && cmake .. && make');
      return 0;

    case BoardTarget.stm32f4:
    case BoardTarget.nrf52840:
      final ZephyrProject project = await const ZephyrProjectGenerator().generate(
        program,
        outputDirectory,
        overwrite: true,
      );
      out('Generated native Zephyr RTOS project: ${project.directory.path}');
      out('Target: ${boardTarget.displayName}');
      out('Dart VM embedded in firmware: no');
      out('Build with: west build -b ${boardTarget.identifier} ${project.directory.path}');
      return 0;
  }
}

Future<int> _flash(
  _CliArguments options,
  EspIdfToolchain toolchain,
  CliWrite out,
  CliWrite err,
) async {
  final Directory project = _requiredProject(options);
  final String port = options.requiredValue('port');
  final EspIdfCommandResult result = await toolchain.flash(project, port: port);
  _printCommandResult(result, out, err);
  return result.exitCode;
}

Future<int> _monitor(
  _CliArguments options,
  EspIdfToolchain toolchain,
  CliWrite out,
  CliWrite err,
) async {
  final Directory project = _requiredProject(options);
  final String port = options.requiredValue('port');
  out('Starting ESP-IDF monitor. Use Ctrl+] to exit.');
  final EspIdfCommandResult result =
      await toolchain.monitor(project, port: port);
  _printCommandResult(result, out, err);
  return result.exitCode;
}

Directory _requiredProject(_CliArguments options) {
  final Directory project =
      Directory(options.requiredValue('project')).absolute;
  if (!project.existsSync()) {
    throw FormatException('Project directory does not exist: ${project.path}');
  }
  return project;
}

void _printCommandResult(
  EspIdfCommandResult result,
  CliWrite out,
  CliWrite err,
) {
  if (result.standardOutput.isNotEmpty) {
    out(result.standardOutput);
  }
  if (result.standardError.isNotEmpty) {
    err(result.standardError);
  }
}

Future<List<String>> _candidateSerialPorts() async {
  final Set<String> ports = <String>{};
  if (Platform.isWindows) {
    try {
      final ProcessResult result = await Process.run(
        'reg',
        <String>['query', r'HKLM\HARDWARE\DEVICEMAP\SERIALCOMM'],
        runInShell: true,
      );
      final RegExp portPattern =
          RegExp(r'REG_SZ\s+(COM\d+)', caseSensitive: false);
      for (final RegExpMatch match
          in portPattern.allMatches('${result.stdout}')) {
        ports.add(match.group(1)!.toUpperCase());
      }
    } on ProcessException {
      // An empty candidate list is a valid diagnostic result.
    }
  } else {
    final Directory devices = Directory('/dev');
    if (devices.existsSync()) {
      await for (final FileSystemEntity entity
          in devices.list(followLinks: false)) {
        final String name = entity.uri.pathSegments.last;
        if (name.startsWith('ttyUSB') ||
            name.startsWith('ttyACM') ||
            name.startsWith('cu.usb')) {
          ports.add(entity.path);
        }
      }
    }
  }
  final List<String> sorted = ports.toList()..sort();
  return sorted;
}

final class _CliArguments {
  _CliArguments(List<String> values) {
    for (int index = 0; index < values.length; index++) {
      final String argument = values[index];
      if (!argument.startsWith('--')) {
        throw FormatException('Unexpected positional argument: $argument');
      }
      final int separator = argument.indexOf('=');
      if (separator >= 0) {
        _values[argument.substring(2, separator)] =
            argument.substring(separator + 1);
        continue;
      }
      final String name = argument.substring(2);
      if (index + 1 < values.length && !values[index + 1].startsWith('--')) {
        _values[name] = values[++index];
      } else {
        _flags.add(name);
      }
    }
  }

  final Map<String, String> _values = <String, String>{};
  final Set<String> _flags = <String>{};

  bool flag(String name) => _flags.contains(name);

  String value(String name, {required String defaultValue}) =>
      _values[name] ?? defaultValue;

  String? valueOrNull(String name) => _values[name];

  String requiredValue(String name) {
    final String? value = _values[name];
    if (value == null || value.isEmpty) {
      throw FormatException('Missing required option --$name=<value>.');
    }
    return value;
  }

  int integer(String name, {required int defaultValue}) {
    final String? value = _values[name];
    if (value == null) {
      return defaultValue;
    }
    final int? parsed = int.tryParse(value);
    if (parsed == null) {
      throw FormatException('--$name must be an integer; received "$value".');
    }
    return parsed;
  }
}

const String _usage = '''
Flint Hardware 0.1.0-dev

Usage:
  flint_hardware doctor
  flint_hardware devices
  flint_hardware export [--lang=c|cpp|micropython|python-ros2] [--target=esp32|rp2040|...]
                        [--pin=2] [--period-ms=500] [--output=exported_file]
  flint_hardware simulate [--target=esp32|rp2040|stm32f4|nrf52840] [--pin=2] [--period-ms=500]
  flint_hardware build  [--target=esp32|esp32_cam|rp2040|stm32f4|nrf52840]
                        [--example=blink] [--pin=2] [--period-ms=500]
                        [--output=build/firmware] [--generate-only]
  flint_hardware flash   --project=build/esp32_blink --port=COM7
  flint_hardware monitor --project=build/esp32_blink --port=COM7

Supported targets:
  esp32       Espressif ESP32 DevKit (ESP-IDF)
  esp32_cam   AI-Thinker ESP32-CAM (ESP-IDF + Camera)
  rp2040      Raspberry Pi Pico (Pico SDK)
  stm32f4     STMicroelectronics STM32F4 Discovery (Zephyr RTOS)
  nrf52840    Nordic Semiconductor nRF52840 DK (Zephyr RTOS)

Supported export languages:
  c           Pure ANSI C (C99/C11)
  cpp         Modern C++ / Arduino / PlatformIO
  micropython MicroPython / CircuitPython
  python-ros2 ROS 2 Python Robotics Node
''';

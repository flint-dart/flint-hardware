import 'dart:io';

import '../backends/esp32/esp32_firmware.dart';
import '../compiler/firmware_program.dart';
import '../exceptions/hardware_exception.dart';

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
    out('Status: simulator and --generate-only are available');
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

Future<int> _build(
  _CliArguments options,
  EspIdfToolchain toolchain,
  CliWrite out,
  CliWrite err,
) async {
  final String target = options.value('target', defaultValue: 'esp32');
  final String example = options.value('example', defaultValue: 'blink');
  if (target != 'esp32') {
    throw FormatException('Only --target=esp32 is implemented in v0.1.');
  }
  if (example != 'blink') {
    throw FormatException('Only --example=blink is implemented in v0.1.');
  }
  final int pin = options.integer('pin', defaultValue: 2);
  final int periodMilliseconds =
      options.integer('period-ms', defaultValue: 500);
  final Directory outputDirectory = Directory(
    options.value(
      'output',
      defaultValue: 'build${Platform.pathSeparator}esp32_blink',
    ),
  ).absolute;
  final FirmwareProgram program = FirmwareProgram.blink(
    pin: pin,
    period: Duration(milliseconds: periodMilliseconds),
  );
  final EspIdfProject project = await const EspIdfProjectGenerator().generate(
    program,
    outputDirectory,
    overwrite: true,
  );
  out('Generated native ESP-IDF project: ${project.directory.path}');
  out('Dart VM embedded in firmware: no');
  if (options.flag('generate-only')) {
    out('Generation complete; ESP-IDF was not invoked.');
    return 0;
  }

  final EspIdfCommandResult result =
      await toolchain.build(project.directory, target: target);
  _printCommandResult(result, out, err);
  if (result.succeeded) {
    out('Application image: ${project.applicationBinary.path}');
    out('Use the flash command for the complete bootloader/partition/app set.');
  }
  return result.exitCode;
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
  flint_hardware build [--target=esp32] [--example=blink] [--pin=2]
                       [--period-ms=500] [--output=build/esp32_blink]
                       [--generate-only]
  flint_hardware flash --project=build/esp32_blink --port=COM7
  flint_hardware monitor --project=build/esp32_blink --port=COM7

`build` generates native ESP-IDF C. It does not compile general Dart source or
embed the Dart VM in ESP32 firmware.
''';

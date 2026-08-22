import 'dart:convert';
import 'dart:io';

import '../compiler/firmware_program.dart';
import '../targets/target_profile.dart';
import 'c_emitter.dart';
import 'cpp_emitter.dart';
import 'micropython_emitter.dart';
import 'ros2_python_emitter.dart';

/// Automatically generates Wokwi diagram.json by inspecting the hardware IR pins.
final class WokwiDiagramGenerator {
  const WokwiDiagramGenerator();

  Map<String, Object?> generate(FirmwareProgram program) {
    final List<Map<String, Object?>> parts = <Map<String, Object?>>[];
    final List<List<String>> connections = <List<String>>[];

    // 1. Base MCU Board
    final String boardType = switch (program.target) {
      BoardTarget.esp32 || BoardTarget.esp32Cam || BoardTarget.esp32s3 => 'board-esp32-devkit-c-v4',
      BoardTarget.rp2040 => 'board-pi-pico',
      BoardTarget.stm32f4 => 'board-stm32-f401re',
      BoardTarget.nrf52840 => 'board-nordic-nrf52840-dk',
    };

    parts.add(<String, Object?>{
      'type': boardType,
      'id': 'mcu',
      'top': 0,
      'left': 0,
      'attrs': <String, Object?>{},
    });

    int partIndex = 0;
    int topOffset = 100;

    for (final FirmwareOperation op in program.operations) {
      if (op is ConfigureDigitalOutput) {
        final String partId = 'led_${op.pin}';
        parts.add(<String, Object?>{
          'type': 'wokwi-led',
          'id': partId,
          'top': topOffset,
          'left': 50 + (partIndex * 60),
          'attrs': <String, Object?>{'color': 'blue'},
        });
        connections.add(<String>['mcu:${op.pin}', '$partId:A', 'green', 'v0']);
        connections.add(<String>['mcu:GND.1', '$partId:C', 'black', 'v0']);
        partIndex++;
        topOffset += 40;
      } else if (op is ConfigurePwmOutput) {
        if (op.frequencyHz <= 100) {
          // Standard Servo (50Hz / 100Hz)
          final String partId = 'servo_${op.pin}';
          parts.add(<String, Object?>{
            'type': 'wokwi-servo',
            'id': partId,
            'top': 80,
            'left': 200 + (partIndex * 80),
            'attrs': <String, Object?>{},
          });
          connections.add(<String>['mcu:${op.pin}', '$partId:PWM', 'orange', 'v0']);
          connections.add(<String>['mcu:5V', '$partId:V+', 'red', 'v0']);
          connections.add(<String>['mcu:GND.2', '$partId:GND', 'black', 'v0']);
          partIndex++;
        }
      } else if (op is ConfigureDigitalInput) {
        // Auto-wire Ultrasonic Sonar or Input Sensor
        final String partId = 'sensor_${op.pin}';
        parts.add(<String, Object?>{
          'type': 'wokwi-hc-sr04',
          'id': partId,
          'top': 160,
          'left': 150 + (partIndex * 40),
          'attrs': <String, Object?>{},
        });
        connections.add(<String>['mcu:${op.pin}', '$partId:ECHO', 'yellow', 'v0']);
        connections.add(<String>['mcu:5V', '$partId:VCC', 'red', 'v0']);
        connections.add(<String>['mcu:GND.1', '$partId:GND', 'black', 'v0']);
        partIndex++;
      }
    }

    return <String, Object?>{
      'version': 1,
      'author': 'Eulogia Tech - Flint Hardware Auto-Generator',
      'editor': 'wokwi',
      'parts': parts,
      'connections': connections,
    };
  }
}

/// Framework-level tool that exports an entire multi-language & Wokwi simulation bundle.
final class FirmwareBundleExporter {
  const FirmwareBundleExporter();

  Future<void> exportToDirectory(
    FirmwareProgram program,
    Directory outputDirectory,
  ) async {
    await outputDirectory.create(recursive: true);

    // 1. Export MicroPython
    final String pyCode = const MicroPythonEmitter().emit(program);
    await File('${outputDirectory.path}/main.py').writeAsString(pyCode);

    // 2. Export Arduino / PlatformIO C++
    final String cppCode = const CppEmitter().emit(program);
    await File('${outputDirectory.path}/sketch.cpp').writeAsString(cppCode);

    // 3. Export Pure ANSI C
    final String cCode = const CEmitter().emit(program);
    await File('${outputDirectory.path}/main.c').writeAsString(cCode);

    // 4. Export ROS 2 Node
    final String rosCode = const Ros2PythonEmitter().emit(program);
    await File('${outputDirectory.path}/ros2_node.py').writeAsString(rosCode);

    // 5. Auto-Generate Wokwi diagram.json based on IR pins
    final Map<String, Object?> diagram = const WokwiDiagramGenerator().generate(program);
    final String diagramJson = const JsonEncoder.withIndent('  ').convert(diagram);
    await File('${outputDirectory.path}/diagram.json').writeAsString(diagramJson);
  }
}

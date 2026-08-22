import '../compiler/firmware_program.dart';

/// Target language for source code export.
enum ExportLanguage {
  c('c', 'ANSI C (C99/C11 Portable Source)'),
  cpp('cpp', 'Modern C++ / Arduino / PlatformIO'),
  micropython('micropython', 'MicroPython / CircuitPython'),
  ros2Python('python-ros2', 'ROS 2 Python Robotics Node');

  const ExportLanguage(this.identifier, this.displayName);

  final String identifier;
  final String displayName;

  static ExportLanguage fromIdentifier(String value) {
    for (final ExportLanguage lang in ExportLanguage.values) {
      if (lang.identifier == value || lang.name == value) {
        return lang;
      }
    }
    throw FormatException(
      'Unknown export language "$value". Supported: '
      '${ExportLanguage.values.map((l) => l.identifier).join(', ')}.',
    );
  }
}

/// Abstract code emitter from FirmwareProgram IR to concrete source code.
abstract interface class CodeEmitter {
  String emit(FirmwareProgram program);
}

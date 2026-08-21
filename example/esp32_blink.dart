import 'dart:io';

import 'package:flint_hardware/flint_hardware.dart';

Future<void> main() async {
  final FirmwareProgram program = FirmwareProgram.blink(pin: 2);
  final EspIdfProject project = await const EspIdfProjectGenerator().generate(
    program,
    Directory('build/esp32_blink'),
    overwrite: true,
  );

  print('Generated ${project.directory.path}');
  print('This is native ESP-IDF C generation, not Dart VM firmware.');
}

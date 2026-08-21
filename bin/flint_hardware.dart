import 'dart:io';

import 'package:flint_hardware/src/cli/flint_hardware_cli.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await runFlintHardwareCli(arguments);
}

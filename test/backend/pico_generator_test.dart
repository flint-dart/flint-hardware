import 'dart:io';

import 'package:flint_hardware/flint_hardware.dart';
import 'package:test/test.dart';

void main() {
  group('PicoSdkProjectGenerator', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('flint_pico_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('generates valid Pico SDK project files for RP2040', () async {
      final program = FirmwareProgram.blink(
        pin: 25, // On-board LED on Raspberry Pi Pico
        period: const Duration(milliseconds: 250),
        target: BoardTarget.rp2040,
      );

      final project = await const PicoSdkProjectGenerator().generate(
        program,
        tempDir,
        overwrite: true,
      );

      expect(project.projectName, 'flint_blink');
      expect(project.target, 'rp2040');
      expect(File('${tempDir.path}/CMakeLists.txt').existsSync(), isTrue);
      expect(File('${tempDir.path}/main.c').existsSync(), isTrue);

      final mainC = await File('${tempDir.path}/main.c').readAsString();
      expect(mainC, contains('gpio_init(25)'));
      expect(mainC, contains('gpio_set_dir(25, GPIO_OUT)'));
      expect(mainC, contains('pico/stdlib.h'));
    });

    test('validates RP2040 pin permissions', () async {
      final builder = FirmwareBuilder('pico_invalid', target: BoardTarget.rp2040);
      builder.digitalOutput(99); // Invalid GPIO on RP2040

      expect(
        () => const PicoSdkProjectGenerator().generate(builder.build(), tempDir),
        throwsA(isA<InvalidHardwareArgumentException>()),
      );
    });
  });
}

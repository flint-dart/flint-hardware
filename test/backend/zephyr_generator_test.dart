import 'dart:io';

import 'package:flint_hardware/flint_hardware.dart';
import 'package:test/test.dart';

void main() {
  group('ZephyrProjectGenerator', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('flint_zephyr_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('generates valid Zephyr RTOS project for STM32F4', () async {
      final program = FirmwareProgram.blink(
        pin: 12, // LED on STM32F4 Discovery (PD12)
        period: const Duration(milliseconds: 500),
        target: BoardTarget.stm32f4,
      );

      final project = await const ZephyrProjectGenerator().generate(
        program,
        tempDir,
        overwrite: true,
      );

      expect(project.projectName, 'flint_blink');
      expect(project.target, 'stm32f4');
      expect(File('${tempDir.path}/CMakeLists.txt').existsSync(), isTrue);
      expect(File('${tempDir.path}/prj.conf').existsSync(), isTrue);
      expect(File('${tempDir.path}/src/main.c').existsSync(), isTrue);

      final prjConf = await File('${tempDir.path}/prj.conf').readAsString();
      expect(prjConf, contains('CONFIG_GPIO=y'));
    });

    test('generates Bluetooth enabled prj.conf for Nordic nRF52840', () async {
      final program = FirmwareProgram.blink(
        pin: 13, // LED1 on nRF52840 DK (P0.13)
        period: const Duration(milliseconds: 1000),
        target: BoardTarget.nrf52840,
      );

      final project = await const ZephyrProjectGenerator().generate(
        program,
        tempDir,
        overwrite: true,
      );

      expect(project.target, 'nrf52840');
      final prjConf = await File('${tempDir.path}/prj.conf').readAsString();
      expect(prjConf, contains('CONFIG_BT=y'));
      expect(prjConf, contains('CONFIG_BT_PERIPHERAL=y'));
    });
  });
}

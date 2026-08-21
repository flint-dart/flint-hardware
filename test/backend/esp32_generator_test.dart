import 'dart:convert';
import 'dart:io';

import 'package:flint_hardware/flint_hardware.dart';
import 'package:test/test.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory =
        await Directory.systemTemp.createTemp('flint_hardware_test_');
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('generates a transparent ESP-IDF blink project', () async {
    final EspIdfProject project = await const EspIdfProjectGenerator().generate(
      FirmwareProgram.blink(
        pin: 2,
        period: const Duration(milliseconds: 250),
      ),
      temporaryDirectory,
    );

    final String rootCMake = await File(
      '${temporaryDirectory.path}${Platform.pathSeparator}CMakeLists.txt',
    ).readAsString();
    final String mainC = await File(
      '${temporaryDirectory.path}${Platform.pathSeparator}main'
      '${Platform.pathSeparator}main.c',
    ).readAsString();
    final Map<String, Object?> manifest = (jsonDecode(await File(
      '${temporaryDirectory.path}${Platform.pathSeparator}flint_program.json',
    ).readAsString()) as Map<Object?, Object?>)
        .cast<String, Object?>();

    expect(rootCMake, contains(r'include($ENV{IDF_PATH}'));
    expect(mainC, contains('void app_main(void)'));
    expect(mainC, contains('GPIO_NUM_2'));
    expect(mainC, contains('\n    ESP_ERROR_CHECK(gpio_reset_pin'));
    expect(mainC, contains('\n        ESP_ERROR_CHECK(gpio_set_level'));
    expect(mainC, contains('pdMS_TO_TICKS(250)'));
    expect(mainC, contains('does not embed or execute the Dart VM'));
    expect(manifest['runtime'], 'native-esp-idf-c-no-dart-vm');
    expect(project.applicationBinary.path, endsWith('flint_blink.bin'));
  });

  test('refuses unsafe output pins and write-before-configure', () async {
    await expectLater(
      const EspIdfProjectGenerator().generate(
        FirmwareProgram.blink(pin: 6),
        temporaryDirectory,
      ),
      throwsA(isA<InvalidHardwareArgumentException>()),
    );
    await expectLater(
      const EspIdfProjectGenerator().generate(
        const FirmwareProgram(
          name: 'invalid',
          operations: <FirmwareOperation>[
            WriteDigitalOutput(2, DigitalLevel.high),
          ],
        ),
        temporaryDirectory,
      ),
      throwsA(isA<HardwareException>()),
    );
  });

  test('rejects unreachable and repeated configuration operations', () async {
    await expectLater(
      const EspIdfProjectGenerator().generate(
        const FirmwareProgram(
          name: 'unreachable',
          operations: <FirmwareOperation>[
            ConfigureDigitalOutput(2),
            RepeatForever(<FirmwareOperation>[
              WriteDigitalOutput(2, DigitalLevel.high),
            ]),
            WriteDigitalOutput(2, DigitalLevel.low),
          ],
        ),
        temporaryDirectory,
      ),
      throwsA(isA<HardwareException>()),
    );
    await expectLater(
      const EspIdfProjectGenerator().generate(
        const FirmwareProgram(
          name: 'reconfigure',
          operations: <FirmwareOperation>[
            RepeatForever(<FirmwareOperation>[
              ConfigureDigitalOutput(2),
            ]),
          ],
        ),
        temporaryDirectory,
      ),
      throwsA(isA<HardwareException>()),
    );
  });

  test('does not overwrite generated files unless authorized', () async {
    const EspIdfProjectGenerator generator = EspIdfProjectGenerator();
    await generator.generate(FirmwareProgram.blink(), temporaryDirectory);

    await expectLater(
      generator.generate(FirmwareProgram.blink(), temporaryDirectory),
      throwsA(isA<HardwareException>()),
    );
    await generator.generate(
      FirmwareProgram.blink(period: const Duration(seconds: 1)),
      temporaryDirectory,
      overwrite: true,
    );
  });
}

import 'package:flint_hardware/flint_hardware.dart';
import 'package:test/test.dart';

void main() {
  group('FirmwareBuilder (Zero-Boilerplate Declarative API)', () {
    test('builds an Edge AI & Computer Vision pipeline declaratively', () {
      final builder = FirmwareBuilder('cam_ai_bot', target: BoardTarget.esp32Cam);

      builder.camera(
        resolution: CameraResolution.qvga,
        format: PixelFormat.rgb565,
        frameRate: 15,
      );

      final model = builder.tfliteModel(
        name: 'person_detector',
        assetPath: 'models/person.tflite',
        inputShape: const [1, 96, 96, 1],
        outputShape: const [1, 2],
        tensorArenaSizeKb: 128,
      );

      final ledPin = builder.digitalOutput(33);

      builder.loop((ctx) {
        ctx.setDigital(ledPin, DigitalLevel.high);
        ctx.delay(const Duration(milliseconds: 100));
        ctx.setDigital(ledPin, DigitalLevel.low);
        ctx.delay(const Duration(milliseconds: 100));
      });

      final program = builder.build();

      expect(program.name, 'cam_ai_bot');
      expect(program.target, BoardTarget.esp32Cam);
      expect(model.name, 'person_detector');
      expect(model.tensorArenaSizeKb, 128);
      expect(program.operations.length, 4); // Camera, Model, Output, Loop
    });

    test('builds Bluetooth LE and Mesh Swarm configurations with zero magic strings', () {
      final builder = FirmwareBuilder('swarm_robot', target: BoardTarget.nrf52840);

      // Declarative BLE with typed services and characteristics
      builder.bluetooth(
        deviceName: 'FlintRover',
        services: [
          BleService.battery(initialLevelPercent: 95),
          BleService.deviceInfo(manufacturer: 'Eulogia', model: 'Rover-X1'),
        ],
      );

      // Declarative Mesh Swarm with typed SwarmId and WifiChannel
      builder.meshSwarm(
        swarm: SwarmId.robotics,
        channel: WifiChannel.ch6,
      );

      final program = builder.build();

      expect(program.target, BoardTarget.nrf52840);
      expect(program.operations.any((op) => op is ConfigureBleOp), isTrue);
      expect(program.operations.any((op) => op is ConfigureMeshOp), isTrue);
    });
  });

  group('Target Registry & Profiles', () {
    test('resolves target profiles correctly', () {
      final esp32 = TargetRegistry.getProfile(BoardTarget.esp32);
      final rp2040 = TargetRegistry.getProfile(BoardTarget.rp2040);
      final stm32 = TargetRegistry.getProfile(BoardTarget.stm32f4);
      final nrf52 = TargetRegistry.getProfile(BoardTarget.nrf52840);

      expect(esp32.architecture, 'xtensa-lx6');
      expect(rp2040.architecture, 'arm-cortex-m0plus');
      expect(stm32.architecture, 'arm-cortex-m4f');
      expect(nrf52.architecture, 'arm-cortex-m4');
    });

    test('validates pin capabilities per board', () {
      final esp32 = TargetRegistry.getProfile(BoardTarget.esp32);
      expect(() => esp32.validatePinForOutput(2), returnsNormally);
      expect(
        () => esp32.validatePinForOutput(34), // Pin 34 is input-only on ESP32
        throwsA(isA<InvalidHardwareArgumentException>()),
      );
    });
  });
}

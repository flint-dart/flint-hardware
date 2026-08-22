import 'package:flint_hardware/flint_hardware.dart';

void main() {
  print('=== Flint Hardware: Elegant Declarative Multi-MCU Demo ===\n');

  // 1. Declarative Edge AI & Vision Pipeline on ESP32-CAM (Zero Boilerplate)
  final visionApp = FirmwareBuilder('cam_security_guard', target: BoardTarget.esp32Cam);

  // Configure on-board camera with 1 line
  visionApp.camera(
    resolution: CameraResolution.qvga,
    format: PixelFormat.rgb565,
    frameRate: 15,
  );

  // Load quantized TFLite Micro model
  final personModel = visionApp.tfliteModel(
    name: 'person_detect',
    assetPath: 'models/person_detect.tflite',
    inputShape: const [1, 96, 96, 1],
    outputShape: const [1, 2],
    quantization: TensorQuantization.int8,
    tensorArenaSizeKb: 128,
  );

  final flashLed = visionApp.digitalOutput(4); // On-board high-power flashlight LED

  visionApp.loop((ctx) {
    ctx.log('Frame captured -> Running TFLite inference...');
    ctx.setDigital(flashLed, DigitalLevel.high);
    ctx.delay(const Duration(milliseconds: 100));
    ctx.setDigital(flashLed, DigitalLevel.low);
    ctx.delay(const Duration(milliseconds: 900));
  });

  final visionProgram = visionApp.build();
  print('Built Vision Program: ${visionProgram.name} for target ${visionProgram.target.displayName}');
  print('Loaded AI Model: ${personModel.name} (Arena: ${personModel.tensorArenaSizeKb}KB)\n');

  // 2. Declarative Bluetooth LE & Swarm Mesh (Zero Strings)
  final bleMeshApp = FirmwareBuilder('nrf_swarm_beacon', target: BoardTarget.nrf52840);

  // Strongly-typed BLE Services
  bleMeshApp.bluetooth(
    deviceName: 'Flint-Swarm-01',
    services: [
      BleService.battery(initialLevelPercent: 95),
      BleService.deviceInfo(manufacturer: 'Eulogia', model: 'Rover-X1'),
    ],
  );

  // Strongly-typed Swarm Domain & Radio Channel (No magic strings!)
  bleMeshApp.meshSwarm(
    swarm: SwarmId.robotics,
    channel: WifiChannel.ch6,
  );

  final statusLed = bleMeshApp.digitalOutput(13); // LED1 on nRF52840 DK
  bleMeshApp.loop((ctx) {
    ctx.setDigital(statusLed, DigitalLevel.high);
    ctx.delay(const Duration(milliseconds: 500));
    ctx.setDigital(statusLed, DigitalLevel.low);
    ctx.delay(const Duration(milliseconds: 500));
  });

  final bleProgram = bleMeshApp.build();
  print('Built BLE/Mesh Program: ${bleProgram.name} for target ${bleProgram.target.displayName}');
  print('Operations configured: ${bleProgram.operations.length}');
  print('\n=== All Flint Hardware declarative builders verified! ===');
}

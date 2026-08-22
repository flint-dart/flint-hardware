import 'dart:io';

import 'package:flint_hardware/flint_hardware.dart';

void main() async {
  print('===============================================================');
  print('   FLINT HARDWARE: AUTONOMOUS ROVER WITH ROBOTICS DRIVERS     ');
  print('===============================================================\n');

  // 1. Declarative Autonomous Rover
  final rover = FirmwareBuilder('autonomous_explorer', target: BoardTarget.esp32);

  // A. Ultrasonic Distance Sonar (HC-SR04)
  final sonar = rover.sonar(triggerPin: 5, echoPin: 18);

  // B. 6-Axis IMU (MPU6050)
  final imu = rover.imu(sdaPin: 21, sclPin: 22);

  // C. 2-Wheel Differential Drive (L298N)
  final drive = rover.differentialDrive(
    leftPwmPin: 14,
    leftDirPin: 27,
    rightPwmPin: 12,
    rightDirPin: 26,
  );

  // D. Environmental Sensor (DHT22)
  final dht = rover.dht22(pin: 4);

  // E. Radar Sweeping Servo & Status LED
  final scanServo = rover.pwmOutput(13, frequencyHz: 50);
  final statusLed = rover.digitalOutput(2);

  // F. Wireless Swarm Mesh & BLE Telemetry
  rover.meshSwarm(swarm: SwarmId.robotics, channel: WifiChannel.ch6);
  rover.bluetooth(
    deviceName: 'Flint-Explorer-01',
    services: [
      BleService.battery(initialLevelPercent: 100),
      BleService.deviceInfo(manufacturer: 'Eulogia Tech', model: 'Rover-Explorer-Pro'),
    ],
  );

  // 2. Autonomous Navigation Control Loop
  rover.loop((ctx) {
    ctx.log('[Rover] Cruising forward...');
    ctx.setDigital(statusLed, DigitalLevel.high);
    ctx.setPwm(drive.leftPwmPin, 0.75);
    ctx.setPwm(drive.rightPwmPin, 0.75);
    ctx.setDigital(drive.leftDirPin, DigitalLevel.high);
    ctx.setDigital(drive.rightDirPin, DigitalLevel.high);
    ctx.delay(const Duration(seconds: 1));

    ctx.log('[Rover] Ultrasonic sonar sweep: checking distance...');
    ctx.setPwm(scanServo, 0.05); // Sweep left
    ctx.delay(const Duration(milliseconds: 300));
    ctx.setPwm(scanServo, 0.10); // Sweep right
    ctx.delay(const Duration(milliseconds: 300));
  });

  // 3. Export Simulation & Multi-Language Bundle in 1 Line!
  final outputDir = Directory('build/rover_explorer_demo');
  await rover.exportBundle(outputDir);

  print('✔ Configured Ultrasonic Sonar on Trigger: ${sonar.triggerPin}, Echo: ${sonar.echoPin}');
  print('✔ Configured 6-Axis IMU (MPU6050) on SDA: ${imu.sdaPin}, SCL: ${imu.sclPin}');
  print('✔ Configured Differential Drive on Left: ${drive.leftPwmPin}, Right: ${drive.rightPwmPin}');
  print('✔ Configured DHT22 Sensor on Pin: ${dht.pin}\n');
  print('✔ [Flint] Complete simulation bundle exported to ${outputDir.path}/');
  print('  Open https://wokwi.com/projects/new/micropython-esp32 to simulate!');
}

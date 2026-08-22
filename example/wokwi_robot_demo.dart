import 'dart:io';

import 'package:flint_hardware/flint_hardware.dart';

void main() async {
  // 1. Pure Application-Level Declarative Robot Definition
  final robot = FirmwareBuilder('wokwi_flint_bot', target: BoardTarget.esp32);

  // Peripherals
  final statusLed = robot.digitalOutput(2);
  final scanServo = robot.pwmOutput(13, frequencyHz: 50); // SG90 Servo
  final leftMotorPwm = robot.pwmOutput(18, frequencyHz: 10000);
  final rightMotorPwm = robot.pwmOutput(19, frequencyHz: 10000);

  // Wireless Swarm & BLE
  robot.meshSwarm(swarm: SwarmId.robotics, channel: WifiChannel.ch6);
  robot.bluetooth(
    deviceName: 'Flint-Bot-Wokwi',
    services: [
      BleService.battery(initialLevelPercent: 98),
      BleService.deviceInfo(manufacturer: 'Eulogia Tech', model: 'Flint-Rover-V1'),
    ],
  );

  // Autonomous Control Loop
  robot.loop((ctx) {
    ctx.log('[Robot] Moving forward...');
    ctx.setDigital(statusLed, DigitalLevel.high);
    ctx.setPwm(leftMotorPwm, 0.8);
    ctx.setPwm(rightMotorPwm, 0.8);
    ctx.setPwm(scanServo, 0.075);
    ctx.delay(const Duration(milliseconds: 1000));

    ctx.log('[Robot] Scanning left and right...');
    ctx.setDigital(statusLed, DigitalLevel.low);
    ctx.setPwm(scanServo, 0.025);
    ctx.delay(const Duration(milliseconds: 500));
    ctx.setPwm(scanServo, 0.125);
    ctx.delay(const Duration(milliseconds: 500));
  });

  // 2. Framework Dev-Level 1-Line Export (Auto-generates Python, C++, C, ROS 2, and Wokwi diagram.json)
  await robot.exportBundle(Directory('build/wokwi_robot_demo'));

  print('✔ [Flint] Complete simulation bundle exported to build/wokwi_robot_demo/');
  print('  Open https://wokwi.com/projects/new/micropython-esp32 to simulate!');
}

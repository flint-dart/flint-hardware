<p align="center">
  <img src="https://raw.githubusercontent.com/flint-dart/flint-hardware/main/doc/flint_logo.png" alt="Flint Hardware Logo" width="160" onerror="this.style.display='none'"/>
</p>

<h1 align="center">Flint Hardware</h1>

<p align="center">
  <strong>The modern, declarative Dart framework for Embedded Systems, Edge AI, IoT Swarms, and Robotics.</strong>
</p>

<p align="center">
  <a href="https://pub.dev/packages/flint_hardware"><img src="https://img.shields.io/pub/v/flint_hardware.svg" alt="Pub Version"></a>
  <a href="https://github.com/flint-dart/flint-hardware/actions"><img src="https://img.shields.io/badge/tests-38%2F38%20passing-brightgreen.svg" alt="Tests Status"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="MIT License"></a>
  <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-3.4+-0175C2.svg" alt="Dart Version"></a>
</p>

---

## ⚡ What is Flint Hardware?

**Flint Hardware brings the elegance, type-safety, and productivity of Dart into the physical world.**

Traditionally, building embedded hardware and robots required dealing with complex C/C++ toolchains, FreeRTOS pointers, memory leaks, fragile CMake scripts, and board-specific vendor lock-in.

Flint completely changes this:
1. **You write pure Declarative Dart**: Clean, type-safe code with zero C boilerplate and zero magic strings.
2. **You test with 1-Click Simulation**: Instant virtual execution in [Wokwi](https://wokwi.com/) and in-memory Dart tests with auto-generated circuit diagrams.
3. **You compile to Production Native Binaries**: Seamlessly emits native ESP-IDF, Raspberry Pi Pico SDK, Zephyr RTOS, ANSI C99, Arduino C++, MicroPython, or ROS 2 Python nodes.

---

## 🌟 Key Features

* 🚀 **Multi-MCU Native Generation**: Native `.bin`, `.elf`, and `.uf2` toolchains for **ESP32**, **ESP32-CAM**, **ESP32-S3**, **Raspberry Pi Pico (RP2040)**, **STM32F4**, and **Nordic nRF52840**.
* 🌐 **Universal Multi-Language Exporters**: Export your hardware logic into **ANSI C (C99)**, **Arduino C++**, **MicroPython**, or **ROS 2 Python Nodes (`rclpy`)**.
* 🎮 **1-Click Wokwi Simulation**: Automatic circuit generation (`diagram.json`) and instant browser simulation via `flint_hardware simulate`.
* 🤖 **Plug-and-Play Robotics Drivers**: 1-line drivers for Ultrasonic Sonar (`HC-SR04`), 6-Axis IMUs (`MPU6050`), 2-Wheel Differential Drive (`L298N`), and Environmental Sensors (`DHT22`).
* 🧠 **Edge AI & Computer Vision**: Native descriptors for Quantized TinyML / TFLite Micro models and camera pipelines (`QVGA`, `VGA`, `RGB565`, `JPEG`).
* 📡 **Zero-String Mesh & Bluetooth LE**: Type-safe swarm mesh (`SwarmId.robotics`) and standard BLE GATT telemetry services with zero magic strings.
* 🔄 **Robotics State Machines**: Declarative state machines (`RobotStateMachine`) with typed event transitions and timeout guards.
* 📊 **Live Flutter Telemetry Bridge**: Real-time streaming of robot telemetry packets into Flutter mobile and web apps.

---

## 🏁 Quickstart: Build a Robot in 60 Seconds

### 1. Installation

Add `flint_hardware` to your `pubspec.yaml`:

```yaml
dependencies:
  flint_hardware: ^0.0.1-dev
```

Or install via terminal:
```bash
dart pub add flint_hardware
```

---

### 2. Define an Autonomous Robot in Pure Dart

Create `robot.dart`:

```dart
import 'dart:io';
import 'package:flint_hardware/flint_hardware.dart';

void main() async {
  // 1. Declare Robot Hardware
  final robot = FirmwareBuilder('rover_flint_01', target: BoardTarget.esp32);

  // Peripherals & Sensors (Zero Boilerplate!)
  final statusLed = robot.digitalOutput(2);
  final sonar = robot.sonar(triggerPin: 5, echoPin: 18);
  final drive = robot.differentialDrive(
    leftPwmPin: 14, leftDirPin: 27,
    rightPwmPin: 12, rightDirPin: 26,
  );
  final scanServo = robot.pwmOutput(13, frequencyHz: 50);

  // Wireless Swarm Mesh & BLE Telemetry
  robot.meshSwarm(swarm: SwarmId.robotics, channel: WifiChannel.ch6);
  robot.bluetooth(
    deviceName: 'Flint-Rover',
    services: [
      BleService.battery(initialLevelPercent: 95),
      BleService.deviceInfo(manufacturer: 'Eulogia Tech', model: 'Rover-V1'),
    ],
  );

  // Real-Time Control Loop
  robot.loop((ctx) {
    ctx.log('[Rover] Cruising forward...');
    ctx.setDigital(statusLed, DigitalLevel.high);
    ctx.setPwm(drive.leftPwmPin, 0.8);
    ctx.setPwm(drive.rightPwmPin, 0.8);
    ctx.setPwm(scanServo, 0.075); // 90° center
    ctx.delay(const Duration(seconds: 1));

    ctx.log('[Rover] Scanning surroundings...');
    ctx.setDigital(statusLed, DigitalLevel.low);
    ctx.setPwm(scanServo, 0.025); // 0° left
    ctx.delay(const Duration(milliseconds: 500));
    ctx.setPwm(scanServo, 0.125); // 180° right
    ctx.delay(const Duration(milliseconds: 500));
  });

  // 2. Export Complete Simulation & Multi-Language Bundle (1 Line!)
  await robot.exportBundle(Directory('build/robot_demo'));
  print('✔ Complete simulation bundle exported to build/robot_demo/');
}
```

Run the Dart script:
```bash
dart run robot.dart
```

---

## 🎮 1-Click Simulation in Wokwi (No Hardware Required!)

You can simulate your code right in your web browser with zero hardware:

```bash
# Auto-generates diagram.json circuit map and launches simulation
dart run bin/flint_hardware.dart simulate --target=esp32 --pin=2
```

1. Open **[https://wokwi.com/projects/new/micropython-esp32](https://wokwi.com/projects/new/micropython-esp32)**.
2. Paste the contents of `build/robot_demo/main.py`.
3. Click **Play (▶)** and watch your virtual robot run in real-time!

---

## 🤖 Robotics State Machine Example

Model robot behaviors cleanly with state transitions, event triggers, and tick loops:

```dart
import 'package:flint_hardware/flint_hardware.dart';

void main() {
  final fsm = RobotStateMachine(initialStateName: 'patrol');

  // 1. Define Patrol State
  fsm.state('patrol')
    ..onTick(() => print('Cruising forward at 80% speed...'))
    ..onEvent(const ObstacleDetectedEvent(distanceCm: 12), transitionTo: 'avoidance');

  // 2. Define Avoidance State
  fsm.state('avoidance')
    ..onEnter(() => print('Emergency stop! Sweeping obstacle sensor...'))
    ..onEvent(const CustomRobotEvent('path_clear'), transitionTo: 'patrol');

  // 3. Dispatch an Event
  fsm.dispatch(const ObstacleDetectedEvent(distanceCm: 12));
  print('Active State: ${fsm.currentState}'); // Output: 'avoidance'
}
```

---

## 📊 Live Flutter Telemetry Bridge

Connect embedded robot metrics directly into a **Flutter UI Dashboard** or Web UI:

```dart
import 'package:flint_hardware/flint_hardware.dart';

void main() {
  final bridge = TelemetryBridge(robotName: 'FlintRover');

  // Listen to live telemetry stream in your Flutter widgets
  bridge.telemetryStream.listen((TelemetryPacket packet) {
    print('Robot: ${packet.robotName} | Battery: ${packet.batteryPercent}% | State: ${packet.currentState}');
  });

  // Ingest incoming data from Serial, Bluetooth, or WebSockets
  bridge.ingestRawChunk('{"robotName":"FlintRover","currentState":"patrol","batteryPercent":92}');
}
```

---

## 🛠️ Flint CLI Command Reference

| Command | Purpose | Example |
| :--- | :--- | :--- |
| `doctor` | Checks local toolchain availability (ESP-IDF, GCC, Python) | `dart run flint_hardware doctor` |
| `devices` | Lists connected serial USB boards and COM ports | `dart run flint_hardware devices` |
| `simulate` | Generates Wokwi `diagram.json` and simulation bundle | `dart run flint_hardware simulate --target=esp32` |
| `export` | Exports hardware logic to C, C++, MicroPython, or ROS 2 | `dart run flint_hardware export --lang=micropython --target=rp2040` |
| `build` | Generates native CMake/C firmware projects | `dart run flint_hardware build --target=rp2040 --generate-only` |
| `flash` | Flashes compiled binary to physical hardware over USB | `dart run flint_hardware flash --project=build/esp32 --port=COM3` |

---

## 📚 Beginner Hardware Guide

Are you completely new to hardware, voltages, pins, and sensors?  
👉 Read our **[Beginner's Guide to Embedded Hardware](doc/beginner_hardware_guide.md)** for a friendly, step-by-step introduction to physical computing!

---

## 📄 License

Flint Hardware is open-source software licensed under the **[MIT License](LICENSE)**.  
Developed and maintained with ❤️ by **[Eulogia Tech](https://github.com/flint-dart)**.

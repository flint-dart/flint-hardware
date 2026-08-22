import 'dart:io';

import '../ai/ai_model.dart';
import '../drivers/dht22_sensor.dart';
import '../drivers/differential_drive.dart';
import '../drivers/hc_sr04_sonar.dart';
import '../drivers/mpu6050_imu.dart';
import '../emitters/wokwi_bundle_exporter.dart';
import '../gpio/gpio.dart';
import '../targets/target_profile.dart';
import '../vision/camera_driver.dart';
import '../wireless/ble_config.dart';
import '../wireless/mesh_config.dart';
import 'firmware_program.dart';

/// Fluent, elegant builder for embedded firmware without C boilerplate.
final class FirmwareBuilder {
  FirmwareBuilder(this.name, {this.target = BoardTarget.esp32});

  final String name;
  final BoardTarget target;
  final List<FirmwareOperation> _setupOps = <FirmwareOperation>[];
  final List<FirmwareOperation> _loopOps = <FirmwareOperation>[];

  /// Configures a digital output pin.
  int digitalOutput(int pin, {DigitalLevel initialLevel = DigitalLevel.low}) {
    _setupOps.add(ConfigureDigitalOutput(pin, initialLevel: initialLevel));
    return pin;
  }

  /// Configures a digital input pin.
  int digitalInput(int pin, {PinPull pull = PinPull.none}) {
    _setupOps.add(ConfigureDigitalInput(pin, pull: pull));
    return pin;
  }

  /// Configures a PWM output pin.
  int pwmOutput(int pin, {int frequencyHz = 5000, int resolutionBits = 10}) {
    _setupOps.add(ConfigurePwmOutput(
      pin,
      frequencyHz: frequencyHz,
      resolutionBits: resolutionBits,
    ));
    return pin;
  }

  /// Configures on-board camera with zero boilerplate.
  void camera({
    CameraResolution resolution = CameraResolution.qvga,
    PixelFormat format = PixelFormat.rgb565,
    int frameRate = 15,
  }) {
    _setupOps.add(ConfigureCameraOp(CameraConfig(
      resolution: resolution,
      format: format,
      frameRate: frameRate,
    )));
  }

  /// Loads an on-device Edge AI / TinyML model.
  TFLiteModelDescriptor tfliteModel({
    required String name,
    required String assetPath,
    required List<int> inputShape,
    required List<int> outputShape,
    TensorQuantization quantization = TensorQuantization.int8,
    int tensorArenaSizeKb = 64,
  }) {
    final TFLiteModelDescriptor descriptor = TFLiteModelDescriptor(
      name: name,
      assetPath: assetPath,
      inputShape: inputShape,
      outputShape: outputShape,
      quantization: quantization,
      tensorArenaSizeKb: tensorArenaSizeKb,
    );
    _setupOps.add(LoadAiModelOp(descriptor));
    return descriptor;
  }

  /// Declares a Bluetooth Low Energy (BLE) peripheral with services.
  void bluetooth({
    required String deviceName,
    required List<BleService> services,
    int advertisingIntervalMs = 100,
  }) {
    _setupOps.add(ConfigureBleOp(BlePeripheralConfig(
      deviceName: deviceName,
      services: services,
      advertisingIntervalMs: advertisingIntervalMs,
    )));
  }

  /// Configures a Wi-Fi Mesh / ESP-NOW peer-to-peer swarm declaratively.
  void meshSwarm({
    SwarmId swarm = SwarmId.robotics,
    WifiChannel channel = WifiChannel.ch1,
    bool encrypt = false,
  }) {
    _setupOps.add(ConfigureMeshOp(MeshSwarmConfig(
      swarm: swarm,
      channel: channel,
      encrypt: encrypt,
    )));
  }

  /// Configures an Ultrasonic Distance Sensor (HC-SR04).
  Hcsr04Sonar sonar({required int triggerPin, required int echoPin}) {
    digitalOutput(triggerPin);
    digitalInput(echoPin);
    return Hcsr04Sonar(triggerPin: triggerPin, echoPin: echoPin);
  }

  /// Configures a 6-Axis IMU (MPU6050).
  Mpu6050Imu imu({int sdaPin = 21, int sclPin = 22, int i2cAddress = 0x68}) {
    return Mpu6050Imu(sdaPin: sdaPin, sclPin: sclPin, i2cAddress: i2cAddress);
  }

  /// Configures a 2-Wheel Differential Drive Robot Motor Controller (L298N / TB6612FNG).
  DifferentialDrive differentialDrive({
    required int leftPwmPin,
    required int leftDirPin,
    required int rightPwmPin,
    required int rightDirPin,
    int pwmFrequencyHz = 10000,
  }) {
    pwmOutput(leftPwmPin, frequencyHz: pwmFrequencyHz);
    digitalOutput(leftDirPin);
    pwmOutput(rightPwmPin, frequencyHz: pwmFrequencyHz);
    digitalOutput(rightDirPin);
    return DifferentialDrive(
      leftPwmPin: leftPwmPin,
      leftDirPin: leftDirPin,
      rightPwmPin: rightPwmPin,
      rightDirPin: rightDirPin,
      pwmFrequencyHz: pwmFrequencyHz,
    );
  }

  /// Configures a Digital Temperature & Humidity Sensor (DHT22 / AM2302).
  Dht22Sensor dht22({required int pin}) {
    digitalInput(pin);
    return Dht22Sensor(pin: pin);
  }

  /// Defines the repeating real-time execution loop.
  void loop(void Function(FirmwareLoopContext loop) body) {
    final FirmwareLoopContext context = FirmwareLoopContext();
    body(context);
    _loopOps.addAll(context._operations);
  }

  /// Compiles the builder into a validated FirmwareProgram.
  FirmwareProgram build() {
    final List<FirmwareOperation> allOps = <FirmwareOperation>[
      ..._setupOps,
      if (_loopOps.isNotEmpty) RepeatForever(_loopOps),
    ];
    return FirmwareProgram(
      name: name,
      target: target,
      operations: allOps,
    );
  }

  /// Framework-level export: compiles and generates all multi-language & Wokwi simulation files.
  Future<void> exportBundle(Directory outputDirectory) async {
    final FirmwareProgram program = build();
    await const FirmwareBundleExporter().exportToDirectory(program, outputDirectory);
  }
}

/// Context for building real-time loop routines.
final class FirmwareLoopContext {
  final List<FirmwareOperation> _operations = <FirmwareOperation>[];

  void setDigital(int pin, DigitalLevel level) {
    _operations.add(WriteDigitalOutput(pin, level));
  }

  void setPwm(int pin, double fraction) {
    _operations.add(SetPwmDutyFraction(pin, fraction));
  }

  void delay(Duration duration) {
    _operations.add(FirmwareDelay(duration));
  }

  void log(String message) {
    _operations.add(FirmwareLog(message));
  }
}

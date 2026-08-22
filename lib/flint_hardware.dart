/// Portable hardware abstractions, multi-MCU code generators (ESP-IDF, Zephyr, Pico SDK),
/// multi-language emitters (C, C++, MicroPython, ROS 2 Python), Edge AI/Vision descriptors,
/// wireless mesh, and deterministic simulator.
library;

export 'src/actuators/active_buzzer.dart';
export 'src/actuators/actuator.dart';
export 'src/actuators/servo.dart';
export 'src/ai/ai_model.dart';
export 'src/analog/analog.dart';
export 'src/backends/esp32/esp32_firmware.dart';
export 'src/backends/pico_sdk/pico_sdk_generator.dart';
export 'src/backends/simulator/simulated_board.dart';
export 'src/backends/zephyr/zephyr_generator.dart';
export 'src/compiler/firmware_builder.dart';
export 'src/compiler/firmware_program.dart';
export 'src/core/board_descriptor.dart';
export 'src/core/hardware_board.dart';
export 'src/core/hardware_clock.dart';
export 'src/core/hardware_event.dart';
export 'src/drivers/dht22_sensor.dart';
export 'src/drivers/differential_drive.dart';
export 'src/drivers/hc_sr04_sonar.dart';
export 'src/drivers/mpu6050_imu.dart';
export 'src/emitters/c_emitter.dart';
export 'src/emitters/code_emitter.dart';
export 'src/emitters/cpp_emitter.dart';
export 'src/emitters/micropython_emitter.dart';
export 'src/emitters/ros2_python_emitter.dart';
export 'src/emitters/wokwi_bundle_exporter.dart';
export 'src/exceptions/hardware_exception.dart';
export 'src/gpio/gpio.dart';
export 'src/i2c/i2c.dart';
export 'src/pwm/pwm.dart';
export 'src/robotics/robot_state_machine.dart';
export 'src/sensors/sensor.dart';
export 'src/serial/serial.dart';
export 'src/spi/spi.dart';
export 'src/targets/board_profiles.dart';
export 'src/targets/target_profile.dart';
export 'src/telemetry/telemetry_bridge.dart';
export 'src/telemetry/telemetry_packet.dart';
export 'src/vision/camera_driver.dart';
export 'src/wireless/ble_config.dart';
export 'src/wireless/mesh_config.dart';

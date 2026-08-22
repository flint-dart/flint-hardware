import 'package:flint_hardware/flint_hardware.dart';
import 'package:test/test.dart';

void main() {
  group('Multi-Language Code Emitters', () {
    late FirmwareProgram program;

    setUp(() {
      final builder = FirmwareBuilder('sensor_node', target: BoardTarget.esp32);
      builder.digitalOutput(2);
      builder.pwmOutput(4, frequencyHz: 5000);
      builder.meshSwarm(swarm: SwarmId.robotics, channel: WifiChannel.ch6);
      builder.loop((ctx) {
        ctx.setDigital(2, DigitalLevel.high);
        ctx.setPwm(4, 0.5);
        ctx.delay(const Duration(milliseconds: 500));
        ctx.setDigital(2, DigitalLevel.low);
        ctx.delay(const Duration(milliseconds: 500));
      });
      program = builder.build();
    });

    test('CEmitter emits portable ANSI C99 code', () {
      const emitter = CEmitter();
      final code = emitter.emit(program);

      expect(code, contains('#include <stdio.h>'));
      expect(code, contains('void flint_sensor_node_init(void)'));
      expect(code, contains('void flint_sensor_node_run(void)'));
      expect(code, contains('/* GPIO 2 -> Output'));
    });

    test('CppEmitter emits Arduino/PlatformIO C++ code', () {
      const emitter = CppEmitter();
      final code = emitter.emit(program);

      expect(code, contains('#include <Arduino.h>'));
      expect(code, contains('void setup()'));
      expect(code, contains('void loop()'));
      expect(code, contains('pinMode(PIN_2, OUTPUT)'));
      expect(code, contains('digitalWrite(PIN_2, HIGH)'));
    });

    test('MicroPythonEmitter emits valid MicroPython script', () {
      const emitter = MicroPythonEmitter();
      final code = emitter.emit(program);

      expect(code, contains('from machine import Pin, PWM'));
      expect(code, contains('pin_2 = Pin(2, Pin.OUT, value=0)'));
      expect(code, contains('pwm_4 = PWM(Pin(4))'));
      expect(code, contains('while True:'));
      expect(code, contains('pin_2.value(1)'));
      expect(code, contains('time.sleep(0.5)'));
    });

    test('Ros2PythonEmitter emits valid ROS 2 rclpy Node', () {
      const emitter = Ros2PythonEmitter();
      final code = emitter.emit(program);

      expect(code, contains('import rclpy'));
      expect(code, contains('from rclpy.node import Node'));
      expect(code, contains('class SensorNodeNode(Node):'));
      expect(code, contains('self.pub_gpio_2 = self.create_publisher(Bool, "flint/gpio_2/state", 10)'));
      expect(code, contains('rclpy.spin(node)'));
    });
  });
}

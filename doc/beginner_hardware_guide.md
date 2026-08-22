# Beginner's Guide to Embedded Hardware & Robotics with Flint

Welcome to the physical world! If you are a software developer coming from Dart, Flutter, JavaScript, or Python, hardware might feel intimidating with talk of registers, memory buffers, C pointers, soldering, and voltages.

**Flint Hardware** eliminates that pain. It gives you a clean, type-safe, and visual way to build hardware and robots without needing to write low-level C code.

---

## 1. Hardware 101: The Core Mental Model

A computer (like your laptop or phone) runs an Operating System (Windows, macOS, Linux, Android) with gigabytes of RAM. 

A **Microcontroller (MCU)** (like an ESP32, Raspberry Pi Pico, or STM32) is a miniature chip with:
* A few hundred kilobytes of memory (RAM).
* Built-in pins (GPIOs) that physically connect to electricity.
* The ability to control the real world in microseconds!

```text
 ┌─────────────────────────────────────────────────────────────┐
 │                     YOUR FLINT CODE                         │
 │           "Turn on LED on Pin 2 and move Servo"             │
 └──────────────────────────────┬──────────────────────────────┘
                                │
 ┌──────────────────────────────▼──────────────────────────────┐
 │                  MICROCONTROLLER (MCU)                      │
 │    [ Pin 2: 3.3 Volts ] ────────────► [ Blue LED Lights Up ] │
 │    [ Pin 13: PWM Pulse ] ───────────► [ Servo Moves 90° ]   │
 └─────────────────────────────────────────────────────────────┘
```

---

## 2. The 4 Fundamental Hardware Concepts

### A. Digital I/O (Pins ON or OFF)
* **Digital Output**: The MCU supplies voltage (`DigitalLevel.high` = 3.3V) or turns it off (`DigitalLevel.low` = 0V).
  * *Use case*: Turning on LEDs, sounding buzzers, triggering relays.
* **Digital Input**: The MCU reads whether voltage is present or absent.
  * *Use case*: Push buttons, obstacle switches, motion detectors.

```dart
// Turn an LED on for 1 second, then off
final led = robot.digitalOutput(2);

robot.loop((ctx) {
  ctx.setDigital(led, DigitalLevel.high); // LED ON
  ctx.delay(Duration(seconds: 1));
  ctx.setDigital(led, DigitalLevel.low);  // LED OFF
  ctx.delay(Duration(seconds: 1));
});
```

---

### B. PWM (Pulse Width Modulation): Controlling Speed & Angles
Microcontrollers cannot output "half voltage" (e.g. 1.65V) directly. Instead, they switch voltage ON and OFF thousands of times per second. 
* **Duty Cycle**: The percentage of time the signal is ON.
  * `0.0` (0%) = Off
  * `0.5` (50%) = Half power / medium speed
  * `1.0` (100%) = Full speed
* *Use case*: DC Motor speed, LED brightness dimming, and precision Servo motors (SG90).

```dart
// 50Hz PWM is the worldwide standard for Servos (SG90 / MG996R)
final scanServo = robot.pwmOutput(13, frequencyHz: 50);

robot.loop((ctx) {
  ctx.setPwm(scanServo, 0.025); // 0° Left
  ctx.delay(Duration(milliseconds: 500));
  ctx.setPwm(scanServo, 0.075); // 90° Center
  ctx.delay(Duration(milliseconds: 500));
  ctx.setPwm(scanServo, 0.125); // 180° Right
  ctx.delay(Duration(milliseconds: 500));
});
```

---

### C. Sensors: Reading the Environment
Sensors translate physical reality (sound, heat, magnetic fields, light) into digital numbers.

| Sensor | How it Works | Flint 1-Liner |
| :--- | :--- | :--- |
| **HC-SR04 (Sonar)** | Sends an ultrasonic ping and listens for the echo bounce. | `final sonar = robot.sonar(triggerPin: 5, echoPin: 18);` |
| **MPU6050 (6-Axis IMU)** | Measures gravity (tilt/acceleration) and rotational spin (gyroscope). | `final imu = robot.imu(sdaPin: 21, sclPin: 22);` |
| **DHT22** | Measures air temperature (°C/°F) and relative humidity (%). | `final dht = robot.dht22(pin: 4);` |

---

### D. Robotics State Machines: Giving Robots Brains
A robot shouldn't just run an infinite messy loop with 50 nested `if-else` checks. It should have clear **States** and **Transitions**:

```text
       ┌───────────┐    Obstacle Detected (< 15cm)    ┌─────────────┐
       │  PATROL   │ ───────────────────────────────► │  AVOIDANCE  │
       │ (Forward) │ ◄─────────────────────────────── │  (Reverse)  │
       └───────────┘          Path is Clear           └─────────────┘
```

In Flint, you declare this cleanly:
```dart
final fsm = RobotStateMachine(initialStateName: 'patrol');

fsm.state('patrol')
  ..onTick(() => print('Cruising forward...'))
  ..onEvent(const ObstacleDetectedEvent(distanceCm: 15), transitionTo: 'avoidance');

fsm.state('avoidance')
  ..onEnter(() => print('Emergency stop! Sweeping sonar...'))
  ..onEvent(const CustomRobotEvent('path_clear'), transitionTo: 'patrol');
```

---

## 3. The 3 Golden Rules of Hardware Safety (Don't Fry Your Board!)

1. **Never short 3.3V / 5V directly to GND (Ground)**: Always put a resistor, LED, or load between power and ground.
2. **Mind the Voltage Limits**: ESP32 and Raspberry Pi Pico GPIO pins are **3.3V logic**. Connecting 5V directly to a standard ESP32 input pin can damage the pin. (Flint profiles warn you about this!).
3. **Power Motors Separately**: Motors consume large spikes of electrical current. Power your microcontrollers with a USB cable or regulated 5V, and power high-torque motors with a battery pack via a motor driver (L298N / TB6612).

---

## 4. Zero-Hardware Prototyping: Testing in Wokwi

You do **not** need to buy physical hardware to start building!

1. Write your robot logic in Dart.
2. Run the simulation CLI:
   ```bash
   dart run flint_hardware simulate --target=esp32 --pin=2
   ```
3. Open [Wokwi.com](https://wokwi.com/projects/new/micropython-esp32) and paste the generated `main.py` code.
4. Click **Play (▶)** and watch your virtual robot respond in real time!

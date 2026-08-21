# Flint Hardware

> Flint Hardware brings Dart into the physical world.

Flint Hardware is an experimental, Dart-first framework for physical
computing, embedded systems, IoT, and robotics. Its public APIs describe
hardware capabilities without binding applications to Linux, ESP-IDF,
Arduino, or a particular board.

This repository is an early `0.1.0-dev` foundation. It deliberately does not
claim that the Dart VM or normal Dart AOT output runs on an ESP32.

## Status

| Area | Status | What that means |
| --- | --- | --- |
| Public board API | Implemented | Explicit, backend-independent board and capability contracts |
| Simulator | Implemented | GPIO, PWM, buses, serial, analog values, sensors, events, and virtual time |
| ESP32 blink | Experimental | Generates a native ESP-IDF C project from a small typed firmware IR |
| ESP-IDF build/flash | Experimental | Delegates to an installed, supported `idf.py` toolchain |
| Linux native backend | Planned | Will live behind the same public interfaces |
| Arbitrary Dart to ESP32 firmware | Research | No supported Dart SDK target currently produces ESP32 firmware |

## Simulator example

```dart
import 'package:flint_hardware/flint_hardware.dart';

Future<void> main() async {
  final board = SimulatedBoard();
  final led = board.gpio.output(2);

  await led.high();
  await board.clock.delay(const Duration(seconds: 1));
  await led.low();

  await board.close();
}
```

Boards are explicit dependencies. This makes programs testable and avoids a
global `current` board whose selection rules would differ across hosts,
containers, SBCs, and firmware targets.

## Run it

```text
dart pub get
dart analyze
dart test
dart run example/blink.dart
dart run flint_hardware:flint_hardware doctor
dart run flint_hardware:flint_hardware build --target=esp32 --example=blink --pin=2 --generate-only
```

With ESP-IDF installed and activated, omit `--generate-only` to invoke
`idf.py build`. See [ESP32 support](docs/esp32.md) and the
[hardware lab guide](docs/hardware_lab.md) before wiring a board.

## Design

Applications depend on small capability interfaces. A simulator implements
them in Dart; a future Linux backend can implement them with native Linux APIs
and FFI; ESP32 firmware is produced through a restricted hardware IR and
ESP-IDF code generation. Native handles never cross the public boundary.

Read the [architecture](docs/architecture.md),
[upstream research](docs/upstream_research.md), and
[compiler design](docs/compiler_design.md) for the reasoning and limitations.

## Project direction

The first milestones cover GPIO, PWM, buttons, LEDs, and an active buzzer on
ESP32 DevKit hardware. DHT22 and SG90 support follow after timing-sensitive
driver and PWM validation. I2C, SPI, UART, ADC, networking, robotics, and Linux
SBC backends remain part of the architecture without being presented as
finished hardware support.

## License

Flint Hardware is MIT licensed. No source from `dart_periphery` or
`c-periphery` is copied into this package; their designs are credited in the
research notes.

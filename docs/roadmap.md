# Roadmap

## v0.1 foundation

- Portable board/capability contracts and stable exception model.
- Deterministic simulator with event logs and virtual time.
- GPIO and PWM APIs, simulated buses/serial/analog, basic actuator drivers.
- Typed firmware IR and generated ESP-IDF blink project.
- CLI doctor/build/flash/monitor foundation.
- Unit and simulator tests; hardware tests remain explicitly opt-in.

## Next milestone: physical I/O vertical slice

1. Pin a supported ESP-IDF release in CI and build generated projects.
2. Validate blink on both ESP32 DevKit boards.
3. Add generated digital input, pull configuration, and debounced edge events.
4. Generate LEDC PWM for LED fading and active-buzzer control.
5. Add serial monitor assertions and a hardware-in-loop test marker.
6. Record board manifests, USB bridge identifiers, and safe pin maps.

## Device drivers

- DHT22 driver after a timing primitive or RMT-based native implementation is
  designed and measured.
- SG90 servo after LEDC pulse width and power-supply behavior are validated.
- I2C, SPI, UART, and ADC IR operations, then representative devices.
- Linux SBC backend using GPIO character devices and isolated native bindings.

## Compiler v2

- Analyzer front end for a documented restricted Dart hardware subset.
- Source diagnostics, resource ownership analysis, bounded concurrency, and
  target capability checks.
- ESP-IDF components for GPIO, LEDC, I2C, SPI, UART, ADC, timers, and logging.
- Reproducible firmware manifests, size reports, flashing, monitoring, and OTA
  metadata.

## Long-term research

- Zephyr/FreeRTOS and RP2040/STM32 generators.
- A minimal Dart-semantics runtime only if memory/timing prototypes justify it.
- Hybrid Dart host plus controller firmware protocol.
- Robotics components, ROS 2 bridge, edge inference, and custom Eulogia boards.

# Architecture

## Decision

Flint Hardware separates portable application APIs, backend service
providers, and host-side firmware tooling.

```text
application / device driver / robotics layer
                   |
       portable capability interfaces
                   |
    +--------------+---------------+
    |              |               |
 simulator     Linux native    firmware IR
  backend        backend        + codegen
                                   |
                                ESP-IDF
```

The simulator and future Linux backend execute Dart at runtime. The initial
ESP32 path does not: host Dart constructs a deliberately restricted firmware
program, Flint validates it, and an ESP-IDF backend emits native source.

## Public boundary

`HardwareBoard` exposes a descriptor, capabilities, a clock, and controllers
for GPIO, PWM, I2C, SPI, serial, and analog input. Controllers create scoped
resources such as `DigitalOutput` and `PwmChannel`. Resource operations are
asynchronous even when a simulator completes them immediately; physical and
remote backends must not force a later API break.

Applications should receive a board explicitly:

```dart
Future<void> runBlink(HardwareBoard board) async {
  final led = board.gpio.output(2);
  try {
    await led.high();
  } finally {
    await led.close();
  }
}
```

There is no implicit board autodetection in v0.1. Detection belongs in CLI or
composition code because a machine can expose several boards at once.

## Backend rules

1. Public types cannot expose native pointers, file descriptors, Linux paths,
   ESP-IDF enums, or Arduino concepts.
2. Each board advertises capabilities; unsupported operations fail before
   acquiring a resource.
3. Backends own native memory and handles and translate errors into stable
   Flint exceptions with operation and resource context.
4. `close()` is idempotent. A board closes its outstanding children.
5. Backend operations preserve ordering per resource. Concurrency and ISR
   details remain backend responsibilities.
6. Drivers depend on capability interfaces, not concrete boards.

## Simulator

The simulator is a first-class backend, not a mock hidden in tests. It stores
pin configuration and state, PWM configuration, bus responses, serial data,
analog values, sensor readings, and an ordered event log. Its virtual clock
advances without wall-clock sleep, making timing assertions deterministic.

External input is explicit: tests drive an input pin, inject serial bytes,
register I2C/SPI responders, or change an analog/sensor value. This prevents a
test from accidentally passing because a simulator invented hardware data.

## Drivers and robotics

Drivers are composable objects over capabilities. An active buzzer uses a
digital output; a servo uses a PWM channel. Future motor drivers, IMUs,
encoders, and robot controllers can combine these objects without adding
motor-specific operations to `HardwareBoard`.

Robotics orchestration belongs above the device-driver layer. ROS 2 bridges,
vision, or remote control may run on Linux while a smaller ESP32 firmware
handles real-time I/O. The same logical device protocol can connect both.

## Native integration

The planned Linux package can use Dart FFI and Linux character devices or a
small C adapter. FFI loading and generated bindings stay inside that backend.
The public package must remain usable by the simulator without loading any
native library.

ESP32 uses native ESP-IDF components generated or linked at build time. A
host-side FFI binding cannot be reused inside firmware because no host Dart VM
is running there.

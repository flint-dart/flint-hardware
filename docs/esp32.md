# ESP32 backend foundation

## Current support

Flint v0.1 can generate an ESP-IDF GPIO blink project from a small typed
firmware program and can delegate build, flash, and monitor commands to an
installed ESP-IDF toolchain. Dart does not execute on the ESP32 in this path;
the generated application is native C using ESP-IDF and FreeRTOS.

The generated entry point is `app_main`, which ESP-IDF invokes after system
initialization and the FreeRTOS scheduler start. It uses `gpio_reset_pin`,
`gpio_set_direction`, `gpio_set_level`, and `vTaskDelay`. These APIs and the
startup model are documented by Espressif in the
[GPIO guide](https://docs.espressif.com/projects/esp-idf/en/stable/esp32/api-reference/peripherals/gpio.html)
and [startup guide](https://docs.espressif.com/projects/esp-idf/en/stable/esp32/api-guides/startup.html).

## Host setup

Install a supported ESP-IDF release using Espressif's
[Get Started guide](https://docs.espressif.com/projects/esp-idf/en/stable/esp32/get-started/index.html).
Activate its environment in the terminal so `idf.py` is on `PATH`, then run:

```text
dart run flint_hardware:flint_hardware doctor
dart run flint_hardware:flint_hardware build --target=esp32 --example=blink --pin=2
dart run flint_hardware:flint_hardware flash --project=build/esp32_blink --port=COM7
dart run flint_hardware:flint_hardware monitor --project=build/esp32_blink --port=COM7
```

On Linux a port is commonly `/dev/ttyUSB0`; on macOS it commonly starts with
`/dev/cu.`. The CLI lists candidate serial ports but does not yet prove that a
candidate is an ESP32.

## Backend map

| Flint concept | ESP-IDF direction | Status |
| --- | --- | --- |
| Digital output/input | GPIO driver | Blink output generated; general lowering planned |
| Edges/interrupts | GPIO ISR service | Research/planned |
| PWM | LEDC | API/simulator implemented; codegen planned |
| Servo | LEDC at 50 Hz | Simulator implemented; physical validation planned |
| I2C | New I2C master driver | Planned |
| SPI | SPI master driver | Planned |
| Serial | UART driver | Planned |
| Analog input | ADC oneshot/continuous drivers | Planned |
| Wi-Fi/Bluetooth | ESP-IDF protocol stacks | Research |

Espressif's [peripheral index](https://docs.espressif.com/projects/esp-idf/en/stable/esp32/api-reference/peripherals/index.html)
is the source of truth for target APIs. PWM should use LEDC rather than model a
Linux sysfs PWM chip/channel; the
[LEDC guide](https://docs.espressif.com/projects/esp-idf/en/stable/esp32/api-reference/peripherals/ledc.html)
documents its timer/channel configuration and duty updates.

## Pin policy

The initial classic ESP32 profile permits output only on GPIO 0-5, 12-19,
21-23, 25-27, and 32-33. GPIO 6-11 are normally connected to SPI flash and are
rejected. GPIO 34-39 are input-only. Board variants differ, so future board
manifests must replace broad chip assumptions.

GPIO 2 is convenient for the first external LED experiment but is also a
strapping pin on many modules. Keep the LED load weak through the documented
series resistor, disconnect experimental circuits if boot fails, and confirm
your exact DevKit schematic.

## Not implemented

There is no Dart VM on-device backend, arbitrary Dart source compiler,
interrupt lowering, Wi-Fi/Bluetooth abstraction, OTA flow, secure boot policy,
or verified DHT22 timing yet. The Linux backend is separate and cannot be used
on ESP32 firmware.

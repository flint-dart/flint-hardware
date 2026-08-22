# Hardware lab

## Safety first

- Disconnect USB power before changing wiring.
- ESP32 GPIO uses 3.3 V logic. Do not apply 5 V to a GPIO.
- Always put a 220 ohm or 330 ohm resistor in series with a basic LED.
- Check LED polarity: long lead/anode toward the GPIO through the resistor;
  short lead/cathode toward GND.
- Motors and servos can exceed the board regulator or USB current budget. Use
  an appropriate external supply and common ground before the SG90 test.
- DHT22 modules and bare sensors can have different pull-up requirements;
  identify the exact part before wiring.

## Experiment 1: external LED blink

Parts: ESP32 DevKit, breadboard, LED, 220/330 ohm resistor, two jumper wires,
USB data cable.

With power disconnected:

```text
GPIO2 ---- resistor ---- LED anode
GND   ------------------ LED cathode
```

Use the multimeter continuity/resistance mode if the breadboard rails or
resistor value are uncertain. Recheck for a direct GPIO-to-GND short.

Generate and build:

```text
dart pub get
dart run flint_hardware:flint_hardware doctor
dart run flint_hardware:flint_hardware build --target=esp32 --example=blink --pin=2 --period-ms=500
dart run flint_hardware:flint_hardware devices
dart run flint_hardware:flint_hardware flash --project=build/esp32_blink --port=COM7
dart run flint_hardware:flint_hardware monitor --project=build/esp32_blink --port=COM7
```

Replace `COM7` with the candidate port observed on this machine. A successful
test has a roughly 500 ms high/500 ms low cycle and log lines that match it.
If the board will not boot, disconnect the GPIO2 circuit and retry; GPIO2 is a
strapping pin on common ESP32 modules.

## Experiment 2: button controls LED

Planned after digital-input code generation. Use an internal pull-up where the
exact board supports it: button between the selected input GPIO and GND, LED as
above on a separate output. The program should treat pressed as LOW, debounce
the transition, and drive the LED. Do not copy a 5 V Arduino wiring diagram.

## Experiment 3: PWM LED fade

Planned LEDC code generation. Keep the same resistor/LED circuit on an
LEDC-capable output. Sweep duty cycle while keeping the configured frequency
within the validated profile.

## Experiment 4: active buzzer

Planned GPIO output path. First identify module voltage and current. A small
3.3 V active buzzer within GPIO current limits may be tested directly; higher
current or 5 V parts require a transistor driver and suitable supply. Never
assume the buzzer is safe to drive directly.

## Experiment 5: DHT22

Planned. Use GPIO4 only after confirming whether the sensor is a three-pin
module or a bare four-pin device and adding the required data pull-up. The
driver needs verified microsecond timing and checksum handling; simulator data
is not a physical driver.

## Experiment 6: SG90 servo

Planned. Signal can use GPIO18, but power the servo from an adequate external
5 V supply and connect supply ground to ESP32 ground. Do not power the servo
from a GPIO. Start with conservative 50 Hz pulses and validate endpoints before
commanding 0/180 degrees to avoid mechanical stalls.

## Recording results

For every physical run record board/module marking, ESP-IDF version, USB bridge
and port, wiring, supply voltage, generated manifest, firmware SHA, result,
and any measured timing. Physical integration tests must never run in normal
CI without an explicit hardware-lab flag.

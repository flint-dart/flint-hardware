# Firmware compiler design

## Reality check

A normal Dart AOT executable is not ESP32 firmware. The official
[`dart compile`](https://dart.dev/tools/dart-compile) documentation describes
self-contained executables for Windows, macOS, and Linux. Cross-compilation is
limited to Linux targets and the listed architectures are 32-bit Arm, Arm64,
RISC-V 64, and x64. A classic ESP32 uses a 32-bit Xtensa LX6; an ESP32-C3 uses
32-bit RISC-V. Neither is a supported Linux AOT firmware target, and ESP32 has
no Linux process environment in which the bundled Dart runtime could start.

The resource mismatch also matters. Espressif documents 520 KB of SRAM on a
classic ESP32, split between instruction and data use with less available to
an application. Porting a full production Dart VM, garbage collector, core
libraries, scheduler, and platform layer is a substantial runtime project, not
a linker flag.

## v1: typed IR to ESP-IDF

The practical first pipeline is:

```text
typed Flint firmware builder
          |
    validated hardware IR
          |
 target capability + pin checks
          |
  ESP-IDF C/component generator
          |
 idf.py + Espressif toolchain
          |
 bootloader.bin + partition-table.bin + application.bin
```

v0.1 implements the first narrow vertical slice: a typed blink program emits a
real ESP-IDF project. It proves validation, generation, build delegation, and
flashing without pretending to compile arbitrary Dart syntax.

The IR is the durable boundary. It should encode operations, types, timing,
resources, task ownership, and required capabilities independently of C or a
specific chip. Generators can lower it to ESP-IDF, Zephyr, or another backend.

## v2: constrained Dart authoring

Add a Dart analyzer front end for an explicitly restricted firmware subset.
Accepted code would use Flint annotations/builders and reject unsupported
features with source locations. The analyzer produces the same IR as the typed
builder. Restrictions are expected around reflection, dynamic invocation,
isolates, filesystem/network APIs, allocation in real-time sections, and
unbounded recursion.

This is compilation from a Dart-shaped, statically checked hardware language;
it is not general Dart semantics. The documentation and file extension or
project manifest must keep that distinction visible.

Code generation should initially use C/C++ and official vendor SDKs rather
than emit Xtensa or RISC-V machine code directly. ESP-IDF already supplies the
bootloader, partition table, FreeRTOS integration, peripheral drivers, image
format, flashing, security configuration, and chip-specific toolchains. Its
[build guide](https://docs.espressif.com/projects/esp-idf/en/stable/esp32/get-started/linux-macos-start-project.html)
shows that `idf.py build` creates the application, bootloader, and partition
table binaries required for a flashable project.

## Long term: runtime research

A purpose-built Dart runtime remains a research track. It would require:

- a supported 32-bit Xtensa and/or RISC-V code generator;
- an ESP-IDF/FreeRTOS platform layer, startup, timers, synchronization, and
  interrupt-safe bridges;
- a memory model and garbage collector proven within MCU RAM constraints;
- a defined subset or implementation of core libraries;
- snapshot/image generation compatible with the exact runtime build;
- debugging, stack traces, panic handling, OTA, secure boot, and reproducible
  toolchains;
- long-running conformance, timing, memory, and power testing.

An embedded runtime should be pursued only after measured prototypes beat the
restricted compiler on capability and developer value. A hybrid architecture
is likely useful regardless: full Dart on a host/SBC or phone, compact Flint
firmware on controllers, and a typed protocol between them.

## Firmware artifacts

ESP-IDF produces several `.bin` files, not one universally flashable blob. The
bootloader, partition table, and application have configured flash offsets.
`idf.py flash` handles the complete set. Flint may later offer a merged factory
image, but `build/firmware.bin` must never hide target, partition, security, or
offset metadata needed to flash it safely.

## Compiler gates

Before expanding the source language, require golden tests for generated
projects, IR validation tests, supported-board manifests, builds against pinned
ESP-IDF releases, hardware-in-loop tests, and size/timing budgets. Unsupported
syntax must be a compile error, never silently translated into different
semantics.

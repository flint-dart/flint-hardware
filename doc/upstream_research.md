# Upstream research

Research was performed against the `dart_periphery` main branch and
`c-periphery` master branch in August 2026. Flint's implementation is original;
no upstream source is included.

## What dart_periphery does well

[`dart_periphery`](https://github.com/pezi/dart_periphery) provides broad
Linux peripheral coverage and stays close to the well-documented C API. Its
GPIO implementation demonstrates several practices worth retaining as design
principles:

- typed GPIO direction, edge, bias, and drive values;
- explicit allocation/open/close/free lifecycle;
- cleanup on partial-open failures and `finally` blocks around temporary
  native allocations;
- translation of negative native return codes into Dart exceptions;
- support for Linux GPIO character devices rather than relying only on the
  deprecated sysfs path;
- tests and examples across GPIO, PWM, I2C, SPI, serial, MMIO, and devices.

The package bundles architecture-specific `libperiphery.so` binaries, selects
one with `Abi.current()`, extracts it to a temporary path, opens it with
`DynamicLibrary`, and maps C functions through `dart:ffi`. Dart's official
[C interop guide](https://dart.dev/interop/c-interop) confirms that FFI is for
Dart Native applications calling C libraries on a supported host platform.

## Limits for Flint's goals

`dart_periphery` intentionally declares only Linux support in its pubspec and
models the native `c-periphery` API closely. Consequently, its public surface
contains Linux device paths, chip indexes, file descriptors, native-handle
transfer helpers, synchronous polling, and per-peripheral exception families.
Loading the native library through module-level globals also means importing a
peripheral implementation can initiate platform-specific setup.

Those choices are reasonable for a Linux binding but cannot be Flint's common
API. They do not describe ESP-IDF peripherals, bare-metal/RTOS ownership, a
remote robot controller, or a deterministic simulator.

## c-periphery lessons

[`c-periphery`](https://github.com/vsergeev/c-periphery) is a small,
re-entrant Linux C library with no dependencies outside libc and Linux. Its
opaque handles and operation table cleanly separate common GPIO operations
from cdev/sysfs implementations. Its documented error values and `errno` plus
message access are useful backend patterns.

For a future Linux backend, prefer the GPIO character-device path and preserve
the distinction between close and free internally. Use generated bindings
where practical and pin the reviewed native source/binary version. Do not
place `c-periphery` types in the portable package.

## Licensing

`dart_periphery` uses a BSD 3-Clause license and carries Dart project notices.
`c-periphery` uses the MIT license and carries Ivan Sergeev's copyright.
Because Flint currently reuses ideas rather than source or binaries, only
attribution links are included. If a Linux backend later distributes either
project's code or binary, its exact license and required notices must ship in
the source and binary distribution.

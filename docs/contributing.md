# Contributing

## Development

```text
dart pub get
dart format --output=none --set-exit-if-changed .
dart analyze
dart test
```

Keep the portable API free of backend types. New capabilities require a
simulator implementation and tests before a physical backend is made public.
Use stable error codes and include operation/resource context without leaking
secrets or raw pointers.

Firmware generator changes require IR validation tests, golden assertions for
important generated fragments, and an ESP-IDF build in supported CI. Hardware
tests belong under an explicit integration tag and must document wiring and
safety assumptions.

## Upstream code and licenses

Do not paste code from a reference project. Record the source and license
before reusing any code, binary, generated binding, or substantial table. Add
the required notices to distributions. Design inspiration should be described
in `docs/upstream_research.md`.

## Pull requests

State whether a feature is implemented, experimental, planned, or research.
Do not describe generated native code as Dart firmware and do not claim support
for a board until the relevant target is built and physically verified.

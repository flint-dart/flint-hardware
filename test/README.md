# Test layout

- `unit/`: portable models, validation, and small device behavior.
- `simulator/`: complete programs and simulated peripheral behavior.
- `backend/`: generated/native backend tests that do not require hardware.
- `integration/`: opt-in physical tests tagged `physical`.

Normal `dart test` never requires an ESP32. A lab runner must explicitly enable
and configure physical tests rather than removing the safety skip globally.

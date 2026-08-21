import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import '../../analog/analog.dart';
import '../../core/board_descriptor.dart';
import '../../core/hardware_board.dart';
import '../../core/hardware_clock.dart';
import '../../core/hardware_event.dart';
import '../../exceptions/hardware_exception.dart';
import '../../gpio/gpio.dart';
import '../../i2c/i2c.dart';
import '../../pwm/pwm.dart';
import '../../sensors/sensor.dart';
import '../../serial/serial.dart';
import '../../spi/spi.dart';

typedef SimulatedI2cResponder = FutureOr<List<int>> Function(
  Uint8List write,
  int readLength,
);

typedef SimulatedSpiResponder = FutureOr<List<int>> Function(Uint8List write);

/// A manually advancing clock for deterministic hardware tests.
final class SimulatedClock implements HardwareClock {
  Duration _elapsed = Duration.zero;
  void Function(Duration duration)? _onAdvance;

  @override
  Duration get elapsed => _elapsed;

  @override
  Future<void> delay(Duration duration) async => advance(duration);

  /// Advances virtual time without sleeping.
  void advance(Duration duration) {
    if (duration.isNegative) {
      throw InvalidHardwareArgumentException(
        argument: 'duration',
        value: duration,
        message: 'Virtual time cannot move backwards.',
      );
    }
    _elapsed += duration;
    _onAdvance?.call(duration);
  }
}

/// A deterministic, in-memory implementation of every v0.1 capability.
final class SimulatedBoard implements HardwareBoard {
  SimulatedBoard({
    String id = 'simulated-0',
    String name = 'Flint simulated board',
    SimulatedClock? clock,
  })  : descriptor = BoardDescriptor(
          id: id,
          name: name,
          backend: 'simulator',
          capabilities: const <HardwareCapability>{
            HardwareCapability.gpio,
            HardwareCapability.gpioEdges,
            HardwareCapability.pwm,
            HardwareCapability.i2c,
            HardwareCapability.spi,
            HardwareCapability.serial,
            HardwareCapability.analogInput,
            HardwareCapability.sensors,
          },
        ),
        clock = clock ?? SimulatedClock() {
    gpio = SimulatedGpioController._(this);
    pwm = SimulatedPwmController._(this);
    i2c = SimulatedI2cController._(this);
    spi = SimulatedSpiController._(this);
    serial = SimulatedSerialController._(this);
    analog = SimulatedAnalogController._(this);
    this.clock._onAdvance = (Duration duration) {
      _record(
        HardwareEventKind.timing,
        'clock',
        'advance',
        <String, Object?>{'microseconds': duration.inMicroseconds},
      );
    };
    _record(HardwareEventKind.lifecycle, 'board:$id', 'open');
  }

  @override
  final BoardDescriptor descriptor;

  @override
  final SimulatedClock clock;

  @override
  late final SimulatedGpioController gpio;

  @override
  late final SimulatedPwmController pwm;

  @override
  late final SimulatedI2cController i2c;

  @override
  late final SimulatedSpiController spi;

  @override
  late final SimulatedSerialController serial;

  @override
  late final SimulatedAnalogController analog;

  final List<HardwareEvent> _events = <HardwareEvent>[];
  final StreamController<HardwareEvent> _eventController =
      StreamController<HardwareEvent>.broadcast(sync: true);
  final Set<_SimulatedResource> _resources = <_SimulatedResource>{};
  final Map<int, String> _pinOwners = <int, String>{};
  int _nextSequence = 0;
  bool _closed = false;

  @override
  bool get isClosed => _closed;

  /// A snapshot of all interactions in execution order.
  List<HardwareEvent> get events => List<HardwareEvent>.unmodifiable(_events);

  /// Live events for diagnostics and interactive simulator tooling.
  Stream<HardwareEvent> get eventStream => _eventController.stream;

  /// Creates a typed simulated sensor with an explicit initial value.
  SimulatedSensor<T> sensor<T>(String id, T initialValue) {
    _ensureOpen('create sensor');
    if (id.trim().isEmpty) {
      throw InvalidHardwareArgumentException(
        argument: 'id',
        value: id,
        message: 'A simulated sensor ID cannot be empty.',
      );
    }
    final SimulatedSensor<T> value =
        SimulatedSensor<T>._(this, id, initialValue);
    _register(value);
    _record(
      HardwareEventKind.configuration,
      'sensor:$id',
      'open',
      <String, Object?>{'value': initialValue},
    );
    return value;
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    for (final _SimulatedResource resource
        in List<_SimulatedResource>.of(_resources).reversed) {
      await resource.close();
    }
    _record(
      HardwareEventKind.lifecycle,
      'board:${descriptor.id}',
      'close',
    );
    _closed = true;
    clock._onAdvance = null;
    await _eventController.close();
  }

  void _ensureOpen(String operation) {
    if (_closed) {
      throw ResourceClosedException(
        'board:${descriptor.id}',
        operation: operation,
      );
    }
  }

  void _claimPin(int pin, String owner) {
    _ensurePin(pin);
    final String? existing = _pinOwners[pin];
    if (existing != null) {
      throw ResourceConflictException('gpio:$pin (owned by $existing)');
    }
    _pinOwners[pin] = owner;
  }

  void _releasePin(int pin) => _pinOwners.remove(pin);

  void _register(_SimulatedResource resource) => _resources.add(resource);

  void _unregister(_SimulatedResource resource) => _resources.remove(resource);

  void _record(
    HardwareEventKind kind,
    String resource,
    String operation, [
    Map<String, Object?> details = const <String, Object?>{},
  ]) {
    final HardwareEvent event = HardwareEvent(
      sequence: _nextSequence++,
      elapsed: clock.elapsed,
      kind: kind,
      resource: resource,
      operation: operation,
      details: details,
    );
    _events.add(event);
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }
}

abstract interface class _SimulatedResource {
  Future<void> close();
}

void _ensurePin(int pin) {
  if (pin < 0) {
    throw InvalidHardwareArgumentException(
      argument: 'pin',
      value: pin,
      message: 'A pin number must be non-negative.',
    );
  }
}

Uint8List _checkedBytes(List<int> values, String argument) {
  for (final int value in values) {
    if (value < 0 || value > 255) {
      throw InvalidHardwareArgumentException(
        argument: argument,
        value: value,
        message: 'Byte values must be between 0 and 255.',
      );
    }
  }
  return Uint8List.fromList(values);
}

final class SimulatedGpioController implements GpioController {
  SimulatedGpioController._(this._board);

  final SimulatedBoard _board;
  final Map<int, GpioPin> _pins = <int, GpioPin>{};

  @override
  SimulatedDigitalInput input(
    int pin, {
    PinPull pull = PinPull.none,
    PinEdge? trigger,
  }) {
    _board._ensureOpen('open GPIO input');
    _board._claimPin(pin, 'digital-input');
    final DigitalLevel initialLevel = switch (pull) {
      PinPull.up => DigitalLevel.high,
      PinPull.down || PinPull.none => DigitalLevel.low,
    };
    final SimulatedDigitalInput input = SimulatedDigitalInput._(
      _board,
      this,
      pin,
      pull,
      trigger,
      initialLevel,
    );
    _pins[pin] = input;
    _board._register(input);
    _board._record(
      HardwareEventKind.configuration,
      'gpio:$pin',
      'input',
      <String, Object?>{
        'pull': pull.name,
        'trigger': trigger?.name,
        'initialLevel': initialLevel.name,
      },
    );
    return input;
  }

  @override
  SimulatedDigitalOutput output(
    int pin, {
    DigitalLevel initialLevel = DigitalLevel.low,
  }) {
    _board._ensureOpen('open GPIO output');
    _board._claimPin(pin, 'digital-output');
    final SimulatedDigitalOutput output =
        SimulatedDigitalOutput._(_board, this, pin, initialLevel);
    _pins[pin] = output;
    _board._register(output);
    _board._record(
      HardwareEventKind.configuration,
      'gpio:$pin',
      'output',
      <String, Object?>{'initialLevel': initialLevel.name},
    );
    return output;
  }

  /// Simulates an external circuit changing an acquired input pin.
  Future<void> driveInput(int pin, DigitalLevel level) async {
    _board._ensureOpen('drive GPIO input');
    final GpioPin? resource = _pins[pin];
    if (resource is! SimulatedDigitalInput || resource.isClosed) {
      throw HardwareException(
        code: HardwareErrorCode.backendFailure,
        message: 'Pin $pin is not an open simulated digital input.',
        operation: 'drive input',
        resource: 'gpio:$pin',
      );
    }
    resource._drive(level);
  }

  void _release(int pin) => _pins.remove(pin);
}

final class SimulatedDigitalOutput extends DigitalOutput
    implements _SimulatedResource {
  SimulatedDigitalOutput._(
    this._board,
    this._controller,
    this.number,
    this._level,
  );

  final SimulatedBoard _board;
  final SimulatedGpioController _controller;

  @override
  final int number;

  DigitalLevel _level;
  bool _closed = false;

  @override
  bool get isClosed => _closed;

  @override
  DigitalLevel get level {
    _ensureOpen('get level');
    return _level;
  }

  @override
  Future<void> write(DigitalLevel level) async {
    _ensureOpen('write');
    final DigitalLevel previous = _level;
    _level = level;
    _board._record(
      HardwareEventKind.stateChange,
      'gpio:$number',
      'write',
      <String, Object?>{'from': previous.name, 'to': level.name},
    );
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _controller._release(number);
    _board._releasePin(number);
    _board._unregister(this);
    _board._record(HardwareEventKind.lifecycle, 'gpio:$number', 'close');
  }

  void _ensureOpen(String operation) {
    if (_closed) {
      throw ResourceClosedException('gpio:$number', operation: operation);
    }
    _board._ensureOpen(operation);
  }
}

final class SimulatedDigitalInput extends DigitalInput
    implements _SimulatedResource {
  SimulatedDigitalInput._(
    this._board,
    this._controller,
    this.number,
    this.pull,
    this.trigger,
    this._level,
  );

  final SimulatedBoard _board;
  final SimulatedGpioController _controller;
  final StreamController<GpioEdgeEvent> _edges =
      StreamController<GpioEdgeEvent>.broadcast(sync: true);

  @override
  final int number;

  @override
  final PinPull pull;

  @override
  final PinEdge? trigger;

  DigitalLevel _level;
  bool _closed = false;

  @override
  bool get isClosed => _closed;

  @override
  DigitalLevel get lastLevel {
    _ensureOpen('get last level');
    return _level;
  }

  @override
  Stream<GpioEdgeEvent> get edges => _edges.stream;

  @override
  Future<DigitalLevel> read() async {
    _ensureOpen('read');
    _board._record(
      HardwareEventKind.read,
      'gpio:$number',
      'read',
      <String, Object?>{'level': _level.name},
    );
    return _level;
  }

  void _drive(DigitalLevel level) {
    _ensureOpen('drive input');
    final DigitalLevel previous = _level;
    _level = level;
    _board._record(
      HardwareEventKind.stateChange,
      'gpio:$number',
      'drive',
      <String, Object?>{'from': previous.name, 'to': level.name},
    );
    if (previous == level) {
      return;
    }
    final PinEdge edge =
        level == DigitalLevel.high ? PinEdge.rising : PinEdge.falling;
    if (trigger == edge || trigger == PinEdge.both) {
      _edges.add(
        GpioEdgeEvent(
          pin: number,
          edge: edge,
          level: level,
          elapsed: _board.clock.elapsed,
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _controller._release(number);
    _board._releasePin(number);
    _board._unregister(this);
    await _edges.close();
    _board._record(HardwareEventKind.lifecycle, 'gpio:$number', 'close');
  }

  void _ensureOpen(String operation) {
    if (_closed) {
      throw ResourceClosedException('gpio:$number', operation: operation);
    }
    _board._ensureOpen(operation);
  }
}

final class SimulatedPwmController implements PwmController {
  SimulatedPwmController._(this._board);

  final SimulatedBoard _board;

  @override
  SimulatedPwmChannel open(
    int pin, {
    double frequencyHz = 1000,
    double dutyCycle = 0,
  }) {
    _board._ensureOpen('open PWM');
    _validateFrequency(frequencyHz);
    _validateDutyCycle(dutyCycle);
    _board._claimPin(pin, 'pwm');
    final SimulatedPwmChannel channel = SimulatedPwmChannel._(
      _board,
      pin,
      frequencyHz,
      dutyCycle,
    );
    _board._register(channel);
    _board._record(
      HardwareEventKind.configuration,
      'pwm:$pin',
      'open',
      <String, Object?>{
        'frequencyHz': frequencyHz,
        'dutyCycle': dutyCycle,
      },
    );
    return channel;
  }
}

final class SimulatedPwmChannel extends PwmChannel
    implements _SimulatedResource {
  SimulatedPwmChannel._(
    this._board,
    this.pin,
    this._frequencyHz,
    this._dutyCycle,
  );

  final SimulatedBoard _board;

  @override
  final int pin;

  double _frequencyHz;
  double _dutyCycle;
  bool _enabled = false;
  bool _closed = false;

  @override
  double get frequencyHz => _frequencyHz;

  @override
  double get dutyCycle => _dutyCycle;

  @override
  bool get isEnabled => _enabled;

  @override
  bool get isClosed => _closed;

  @override
  Future<void> setFrequency(double frequencyHz) async {
    _ensureOpen('set frequency');
    _validateFrequency(frequencyHz);
    _frequencyHz = frequencyHz;
    _board._record(
      HardwareEventKind.configuration,
      'pwm:$pin',
      'setFrequency',
      <String, Object?>{'frequencyHz': frequencyHz},
    );
  }

  @override
  Future<void> setDutyCycle(double dutyCycle) async {
    _ensureOpen('set duty cycle');
    _validateDutyCycle(dutyCycle);
    _dutyCycle = dutyCycle;
    _board._record(
      HardwareEventKind.stateChange,
      'pwm:$pin',
      'setDutyCycle',
      <String, Object?>{'dutyCycle': dutyCycle},
    );
  }

  @override
  Future<void> enable() async {
    _ensureOpen('enable');
    _enabled = true;
    _board._record(HardwareEventKind.stateChange, 'pwm:$pin', 'enable');
  }

  @override
  Future<void> disable() async {
    _ensureOpen('disable');
    _enabled = false;
    _board._record(HardwareEventKind.stateChange, 'pwm:$pin', 'disable');
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _enabled = false;
    _closed = true;
    _board._releasePin(pin);
    _board._unregister(this);
    _board._record(HardwareEventKind.lifecycle, 'pwm:$pin', 'close');
  }

  void _ensureOpen(String operation) {
    if (_closed) {
      throw ResourceClosedException('pwm:$pin', operation: operation);
    }
    _board._ensureOpen(operation);
  }
}

void _validateFrequency(num frequencyHz) {
  if (!frequencyHz.isFinite || frequencyHz <= 0) {
    throw InvalidHardwareArgumentException(
      argument: 'frequencyHz',
      value: frequencyHz,
      message: 'PWM frequency must be finite and greater than zero.',
    );
  }
}

void _validateDutyCycle(num dutyCycle) {
  if (!dutyCycle.isFinite || dutyCycle < 0 || dutyCycle > 1) {
    throw InvalidHardwareArgumentException(
      argument: 'dutyCycle',
      value: dutyCycle,
      message: 'PWM duty cycle must be between 0.0 and 1.0.',
    );
  }
}

final class SimulatedI2cController implements I2cController {
  SimulatedI2cController._(this._board);

  final SimulatedBoard _board;
  final Map<int, SimulatedI2cBus> _buses = <int, SimulatedI2cBus>{};
  final Map<(int, int), SimulatedI2cResponder> _responders =
      <(int, int), SimulatedI2cResponder>{};

  /// Registers an explicit device response for [busNumber] and [address].
  void registerDevice(
    int busNumber,
    int address,
    SimulatedI2cResponder responder,
  ) {
    _board._ensureOpen('register I2C device');
    _ensureBusNumber(busNumber);
    _ensureI2cAddress(address);
    _responders[(busNumber, address)] = responder;
  }

  @override
  SimulatedI2cBus open(int busNumber) {
    _board._ensureOpen('open I2C');
    _ensureBusNumber(busNumber);
    if (_buses.containsKey(busNumber)) {
      throw ResourceConflictException('i2c:$busNumber');
    }
    final SimulatedI2cBus bus = SimulatedI2cBus._(_board, this, busNumber);
    _buses[busNumber] = bus;
    _board._register(bus);
    _board._record(HardwareEventKind.configuration, 'i2c:$busNumber', 'open');
    return bus;
  }

  void _release(int busNumber) => _buses.remove(busNumber);
}

final class SimulatedI2cBus extends I2cBus implements _SimulatedResource {
  SimulatedI2cBus._(this._board, this._controller, this.busNumber);

  final SimulatedBoard _board;
  final SimulatedI2cController _controller;

  @override
  final int busNumber;

  bool _closed = false;

  @override
  bool get isClosed => _closed;

  @override
  Future<Uint8List> transfer(
    int address, {
    List<int> write = const <int>[],
    int readLength = 0,
  }) async {
    _ensureOpen('transfer');
    _ensureI2cAddress(address);
    if (readLength < 0) {
      throw InvalidHardwareArgumentException(
        argument: 'readLength',
        value: readLength,
        message: 'I2C read length must be non-negative.',
      );
    }
    final Uint8List bytes = _checkedBytes(write, 'write');
    final SimulatedI2cResponder? responder =
        _controller._responders[(busNumber, address)];
    if (responder == null && readLength > 0) {
      throw HardwareException(
        code: HardwareErrorCode.backendFailure,
        message: 'No simulated I2C responder is registered.',
        operation: 'transfer',
        resource: 'i2c:$busNumber/0x${address.toRadixString(16)}',
      );
    }
    final List<int> response =
        responder == null ? const <int>[] : await responder(bytes, readLength);
    final Uint8List checked = _checkedBytes(response, 'response');
    if (checked.length != readLength) {
      throw HardwareException(
        code: HardwareErrorCode.backendFailure,
        message:
            'The simulated I2C responder returned ${checked.length} bytes; '
            '$readLength were requested.',
        operation: 'transfer',
        resource: 'i2c:$busNumber/0x${address.toRadixString(16)}',
      );
    }
    _board._record(
      HardwareEventKind.transfer,
      'i2c:$busNumber/0x${address.toRadixString(16)}',
      'transfer',
      <String, Object?>{'write': bytes, 'read': checked},
    );
    return checked;
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _controller._release(busNumber);
    _board._unregister(this);
    _board._record(HardwareEventKind.lifecycle, 'i2c:$busNumber', 'close');
  }

  void _ensureOpen(String operation) {
    if (_closed) {
      throw ResourceClosedException('i2c:$busNumber', operation: operation);
    }
    _board._ensureOpen(operation);
  }
}

void _ensureBusNumber(int busNumber) {
  if (busNumber < 0) {
    throw InvalidHardwareArgumentException(
      argument: 'busNumber',
      value: busNumber,
      message: 'A bus number must be non-negative.',
    );
  }
}

void _ensureI2cAddress(int address) {
  if (address < 0x08 || address > 0x77) {
    throw InvalidHardwareArgumentException(
      argument: 'address',
      value: address,
      message: 'A normal 7-bit I2C address must be between 0x08 and 0x77.',
    );
  }
}

final class SimulatedSpiController implements SpiController {
  SimulatedSpiController._(this._board);

  final SimulatedBoard _board;
  final Map<(int, int), SimulatedSpiBus> _buses =
      <(int, int), SimulatedSpiBus>{};
  final Map<(int, int), SimulatedSpiResponder> _responders =
      <(int, int), SimulatedSpiResponder>{};

  void registerDevice(
    int busNumber,
    int chipSelect,
    SimulatedSpiResponder responder,
  ) {
    _board._ensureOpen('register SPI device');
    _ensureBusNumber(busNumber);
    _ensurePin(chipSelect);
    _responders[(busNumber, chipSelect)] = responder;
  }

  @override
  SimulatedSpiBus open({
    required int busNumber,
    required int chipSelect,
    SpiMode mode = SpiMode.mode0,
    SpiBitOrder bitOrder = SpiBitOrder.mostSignificantFirst,
    int frequencyHz = 1000000,
  }) {
    _board._ensureOpen('open SPI');
    _ensureBusNumber(busNumber);
    _ensurePin(chipSelect);
    if (frequencyHz <= 0) {
      throw InvalidHardwareArgumentException(
        argument: 'frequencyHz',
        value: frequencyHz,
        message: 'SPI frequency must be greater than zero.',
      );
    }
    final (int, int) key = (busNumber, chipSelect);
    if (_buses.containsKey(key)) {
      throw ResourceConflictException('spi:$busNumber/$chipSelect');
    }
    _board._claimPin(chipSelect, 'spi-chip-select');
    final SimulatedSpiBus bus = SimulatedSpiBus._(
      _board,
      this,
      busNumber,
      chipSelect,
      mode,
      bitOrder,
      frequencyHz,
    );
    _buses[key] = bus;
    _board._register(bus);
    _board._record(
      HardwareEventKind.configuration,
      'spi:$busNumber/$chipSelect',
      'open',
      <String, Object?>{
        'mode': mode.name,
        'bitOrder': bitOrder.name,
        'frequencyHz': frequencyHz,
      },
    );
    return bus;
  }

  void _release(int busNumber, int chipSelect) {
    _buses.remove((busNumber, chipSelect));
  }
}

final class SimulatedSpiBus extends SpiBus implements _SimulatedResource {
  SimulatedSpiBus._(
    this._board,
    this._controller,
    this.busNumber,
    this.chipSelect,
    this.mode,
    this.bitOrder,
    this.frequencyHz,
  );

  final SimulatedBoard _board;
  final SimulatedSpiController _controller;

  @override
  final int busNumber;

  @override
  final int chipSelect;

  @override
  final SpiMode mode;

  @override
  final SpiBitOrder bitOrder;

  @override
  final int frequencyHz;

  bool _closed = false;

  @override
  bool get isClosed => _closed;

  @override
  Future<Uint8List> transfer(List<int> data) async {
    _ensureOpen('transfer');
    final Uint8List bytes = _checkedBytes(data, 'data');
    final SimulatedSpiResponder? responder =
        _controller._responders[(busNumber, chipSelect)];
    if (responder == null) {
      throw HardwareException(
        code: HardwareErrorCode.backendFailure,
        message: 'No simulated SPI responder is registered.',
        operation: 'transfer',
        resource: 'spi:$busNumber/$chipSelect',
      );
    }
    final Uint8List response =
        _checkedBytes(await responder(bytes), 'response');
    _board._record(
      HardwareEventKind.transfer,
      'spi:$busNumber/$chipSelect',
      'transfer',
      <String, Object?>{'write': bytes, 'read': response},
    );
    return response;
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _controller._release(busNumber, chipSelect);
    _board._releasePin(chipSelect);
    _board._unregister(this);
    _board._record(
      HardwareEventKind.lifecycle,
      'spi:$busNumber/$chipSelect',
      'close',
    );
  }

  void _ensureOpen(String operation) {
    if (_closed) {
      throw ResourceClosedException(
        'spi:$busNumber/$chipSelect',
        operation: operation,
      );
    }
    _board._ensureOpen(operation);
  }
}

final class SimulatedSerialController implements SerialController {
  SimulatedSerialController._(this._board);

  final SimulatedBoard _board;
  final Map<String, SimulatedSerialPort> _ports =
      <String, SimulatedSerialPort>{};

  @override
  SimulatedSerialPort open(
    String name, {
    SerialConfig config = const SerialConfig(),
  }) {
    _board._ensureOpen('open serial');
    if (name.trim().isEmpty) {
      throw InvalidHardwareArgumentException(
        argument: 'name',
        value: name,
        message: 'A serial port name cannot be empty.',
      );
    }
    _validateSerialConfig(config);
    if (_ports.containsKey(name)) {
      throw ResourceConflictException('serial:$name');
    }
    final SimulatedSerialPort port =
        SimulatedSerialPort._(_board, this, name, config);
    _ports[name] = port;
    _board._register(port);
    _board._record(
      HardwareEventKind.configuration,
      'serial:$name',
      'open',
      <String, Object?>{'baudRate': config.baudRate},
    );
    return port;
  }

  /// Injects bytes as though they arrived from an external serial device.
  void inject(String name, List<int> data) {
    final SimulatedSerialPort? port = _ports[name];
    if (port == null || port.isClosed) {
      throw HardwareException(
        code: HardwareErrorCode.backendFailure,
        message: 'The simulated serial port is not open.',
        operation: 'inject',
        resource: 'serial:$name',
      );
    }
    port._inject(_checkedBytes(data, 'data'));
  }

  void _release(String name) => _ports.remove(name);
}

void _validateSerialConfig(SerialConfig config) {
  if (config.baudRate <= 0 ||
      config.dataBits < 5 ||
      config.dataBits > 8 ||
      (config.stopBits != 1 && config.stopBits != 2)) {
    throw InvalidHardwareArgumentException(
      argument: 'config',
      value:
          '${config.baudRate}/${config.dataBits}/${config.stopBits}/${config.parity.name}',
      message: 'Serial framing is outside the portable supported range.',
    );
  }
}

final class SimulatedSerialPort extends SerialPort
    implements _SimulatedResource {
  SimulatedSerialPort._(this._board, this._controller, this.name, this.config);

  final SimulatedBoard _board;
  final SimulatedSerialController _controller;
  final Queue<int> _receiveBuffer = Queue<int>();
  final StreamController<Uint8List> _received =
      StreamController<Uint8List>.broadcast(sync: true);

  @override
  final String name;

  @override
  final SerialConfig config;

  bool _closed = false;

  @override
  bool get isClosed => _closed;

  @override
  Stream<Uint8List> get received => _received.stream;

  @override
  Future<void> write(List<int> data) async {
    _ensureOpen('write');
    final Uint8List bytes = _checkedBytes(data, 'data');
    _board._record(
      HardwareEventKind.data,
      'serial:$name',
      'write',
      <String, Object?>{'data': bytes},
    );
  }

  @override
  Future<Uint8List> read(int maxBytes) async {
    _ensureOpen('read');
    if (maxBytes <= 0) {
      throw InvalidHardwareArgumentException(
        argument: 'maxBytes',
        value: maxBytes,
        message: 'Serial read size must be greater than zero.',
      );
    }
    final int count =
        maxBytes < _receiveBuffer.length ? maxBytes : _receiveBuffer.length;
    final Uint8List data = Uint8List(count);
    for (int index = 0; index < count; index++) {
      data[index] = _receiveBuffer.removeFirst();
    }
    _board._record(
      HardwareEventKind.read,
      'serial:$name',
      'read',
      <String, Object?>{'data': data},
    );
    return data;
  }

  void _inject(Uint8List data) {
    _ensureOpen('inject');
    _receiveBuffer.addAll(data);
    _received.add(Uint8List.fromList(data));
    _board._record(
      HardwareEventKind.data,
      'serial:$name',
      'receive',
      <String, Object?>{'data': data},
    );
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _controller._release(name);
    _board._unregister(this);
    await _received.close();
    _board._record(HardwareEventKind.lifecycle, 'serial:$name', 'close');
  }

  void _ensureOpen(String operation) {
    if (_closed) {
      throw ResourceClosedException('serial:$name', operation: operation);
    }
    _board._ensureOpen(operation);
  }
}

final class SimulatedAnalogController implements AnalogController {
  SimulatedAnalogController._(this._board);

  final SimulatedBoard _board;
  final Map<int, SimulatedAnalogInput> _inputs = <int, SimulatedAnalogInput>{};
  final Map<int, int> _values = <int, int>{};
  final Map<int, int> _resolutions = <int, int>{};

  /// Sets an explicit raw ADC value for a simulated input.
  void setRawValue(int pin, int value, {int resolutionBits = 12}) {
    _board._ensureOpen('drive analog input');
    _ensurePin(pin);
    if (resolutionBits <= 0 || resolutionBits > 31) {
      throw InvalidHardwareArgumentException(
        argument: 'resolutionBits',
        value: resolutionBits,
        message: 'ADC resolution must be between 1 and 31 bits.',
      );
    }
    final int maximum = (1 << resolutionBits) - 1;
    if (value < 0 || value > maximum) {
      throw InvalidHardwareArgumentException(
        argument: 'value',
        value: value,
        message: 'ADC value must fit the configured resolution.',
      );
    }
    _values[pin] = value;
    _resolutions[pin] = resolutionBits;
    _board._record(
      HardwareEventKind.stateChange,
      'analog:$pin',
      'drive',
      <String, Object?>{'raw': value, 'resolutionBits': resolutionBits},
    );
  }

  @override
  SimulatedAnalogInput input(int pin) {
    _board._ensureOpen('open analog input');
    _ensurePin(pin);
    if (_inputs.containsKey(pin)) {
      throw ResourceConflictException('analog:$pin');
    }
    _board._claimPin(pin, 'analog-input');
    final SimulatedAnalogInput input =
        SimulatedAnalogInput._(_board, this, pin);
    _inputs[pin] = input;
    _board._register(input);
    _board._record(
      HardwareEventKind.configuration,
      'analog:$pin',
      'open',
    );
    return input;
  }

  void _release(int pin) => _inputs.remove(pin);
}

final class SimulatedAnalogInput extends AnalogInput
    implements _SimulatedResource {
  SimulatedAnalogInput._(this._board, this._controller, this.pin);

  final SimulatedBoard _board;
  final SimulatedAnalogController _controller;

  @override
  final int pin;

  bool _closed = false;

  @override
  int get resolutionBits => _controller._resolutions[pin] ?? 12;

  @override
  bool get isClosed => _closed;

  @override
  Future<int> readRaw() async {
    _ensureOpen('read');
    final int? value = _controller._values[pin];
    if (value == null) {
      throw HardwareException(
        code: HardwareErrorCode.backendFailure,
        message: 'No simulated analog value has been set.',
        operation: 'read',
        resource: 'analog:$pin',
      );
    }
    _board._record(
      HardwareEventKind.read,
      'analog:$pin',
      'read',
      <String, Object?>{'raw': value, 'resolutionBits': resolutionBits},
    );
    return value;
  }

  @override
  Future<double> readNormalized() async {
    final int raw = await readRaw();
    return raw / ((1 << resolutionBits) - 1);
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _controller._release(pin);
    _board._releasePin(pin);
    _board._unregister(this);
    _board._record(HardwareEventKind.lifecycle, 'analog:$pin', 'close');
  }

  void _ensureOpen(String operation) {
    if (_closed) {
      throw ResourceClosedException('analog:$pin', operation: operation);
    }
    _board._ensureOpen(operation);
  }
}

/// A typed sensor whose values are controlled by the test or simulator host.
final class SimulatedSensor<T> implements Sensor<T>, _SimulatedResource {
  SimulatedSensor._(this._board, this.id, this._value);

  final SimulatedBoard _board;

  @override
  final String id;

  T _value;
  bool _closed = false;

  @override
  bool get isClosed => _closed;

  /// Changes the value returned by subsequent reads.
  void setValue(T value) {
    _ensureOpen('set value');
    _value = value;
    _board._record(
      HardwareEventKind.stateChange,
      'sensor:$id',
      'setValue',
      <String, Object?>{'value': value},
    );
  }

  @override
  Future<T> read() async {
    _ensureOpen('read');
    _board._record(
      HardwareEventKind.read,
      'sensor:$id',
      'read',
      <String, Object?>{'value': _value},
    );
    return _value;
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _board._unregister(this);
    _board._record(HardwareEventKind.lifecycle, 'sensor:$id', 'close');
  }

  void _ensureOpen(String operation) {
    if (_closed) {
      throw ResourceClosedException('sensor:$id', operation: operation);
    }
    _board._ensureOpen(operation);
  }
}

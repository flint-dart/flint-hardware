import '../exceptions/hardware_exception.dart';
import '../gpio/gpio.dart';

/// Target-independent firmware operations supported by the experimental IR.
sealed class FirmwareOperation {
  const FirmwareOperation();

  Map<String, Object?> toJson();
}

final class ConfigureDigitalOutput extends FirmwareOperation {
  const ConfigureDigitalOutput(
    this.pin, {
    this.initialLevel = DigitalLevel.low,
  });

  final int pin;
  final DigitalLevel initialLevel;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'operation': 'configureDigitalOutput',
        'pin': pin,
        'initialLevel': initialLevel.name,
      };
}

final class WriteDigitalOutput extends FirmwareOperation {
  const WriteDigitalOutput(this.pin, this.level);

  final int pin;
  final DigitalLevel level;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'operation': 'writeDigitalOutput',
        'pin': pin,
        'level': level.name,
      };
}

final class FirmwareDelay extends FirmwareOperation {
  const FirmwareDelay(this.duration);

  final Duration duration;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'operation': 'delay',
        'microseconds': duration.inMicroseconds,
      };
}

final class RepeatForever extends FirmwareOperation {
  const RepeatForever(this.operations);

  final List<FirmwareOperation> operations;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'operation': 'repeatForever',
        'operations': operations
            .map((FirmwareOperation operation) => operation.toJson())
            .toList(growable: false),
      };
}

/// A small, typed firmware IR. It is not an arbitrary Dart AST.
final class FirmwareProgram {
  const FirmwareProgram({required this.name, required this.operations});

  factory FirmwareProgram.blink({
    int pin = 2,
    Duration period = const Duration(milliseconds: 500),
  }) {
    if (period <= Duration.zero) {
      throw InvalidHardwareArgumentException(
        argument: 'period',
        value: period,
        message: 'Blink period must be greater than zero.',
      );
    }
    return FirmwareProgram(
      name: 'flint_blink',
      operations: <FirmwareOperation>[
        ConfigureDigitalOutput(pin),
        RepeatForever(<FirmwareOperation>[
          WriteDigitalOutput(pin, DigitalLevel.high),
          FirmwareDelay(period),
          WriteDigitalOutput(pin, DigitalLevel.low),
          FirmwareDelay(period),
        ]),
      ],
    );
  }

  final String name;
  final List<FirmwareOperation> operations;

  Map<String, Object?> toJson() => <String, Object?>{
        'name': name,
        'operations': operations
            .map((FirmwareOperation operation) => operation.toJson())
            .toList(growable: false),
      };
}

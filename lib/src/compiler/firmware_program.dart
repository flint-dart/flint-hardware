import '../ai/ai_model.dart';
import '../exceptions/hardware_exception.dart';
import '../gpio/gpio.dart';
import '../targets/target_profile.dart';
import '../vision/camera_driver.dart';
import '../wireless/ble_config.dart';
import '../wireless/mesh_config.dart';

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

final class ConfigureDigitalInput extends FirmwareOperation {
  const ConfigureDigitalInput(
    this.pin, {
    this.pull = PinPull.none,
  });

  final int pin;
  final PinPull pull;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'operation': 'configureDigitalInput',
        'pin': pin,
        'pull': pull.name,
      };
}

final class ConfigurePwmOutput extends FirmwareOperation {
  const ConfigurePwmOutput(
    this.pin, {
    this.frequencyHz = 5000,
    this.resolutionBits = 10,
  });

  final int pin;
  final int frequencyHz;
  final int resolutionBits;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'operation': 'configurePwmOutput',
        'pin': pin,
        'frequencyHz': frequencyHz,
        'resolutionBits': resolutionBits,
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

final class SetPwmDutyFraction extends FirmwareOperation {
  const SetPwmDutyFraction(this.pin, this.fraction);

  final int pin;
  final double fraction;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'operation': 'setPwmDutyFraction',
        'pin': pin,
        'fraction': fraction,
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

final class FirmwareLog extends FirmwareOperation {
  const FirmwareLog(this.message);

  final String message;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'operation': 'log',
        'message': message,
      };
}

final class ConfigureCameraOp extends FirmwareOperation {
  const ConfigureCameraOp(this.config);

  final CameraConfig config;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'operation': 'configureCamera',
        'config': config.toJson(),
      };
}

final class LoadAiModelOp extends FirmwareOperation {
  const LoadAiModelOp(this.descriptor);

  final TFLiteModelDescriptor descriptor;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'operation': 'loadAiModel',
        'model': descriptor.toJson(),
      };
}

final class ConfigureBleOp extends FirmwareOperation {
  const ConfigureBleOp(this.config);

  final BlePeripheralConfig config;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'operation': 'configureBle',
        'config': config.toJson(),
      };
}

final class ConfigureMeshOp extends FirmwareOperation {
  const ConfigureMeshOp(this.config);

  final MeshSwarmConfig config;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'operation': 'configureMesh',
        'config': config.toJson(),
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

/// A validated, target-agnostic firmware program.
final class FirmwareProgram {
  const FirmwareProgram({
    required this.name,
    required this.operations,
    this.target = BoardTarget.esp32,
  });

  factory FirmwareProgram.blink({
    int pin = 2,
    Duration period = const Duration(milliseconds: 500),
    BoardTarget target = BoardTarget.esp32,
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
      target: target,
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
  final BoardTarget target;
  final List<FirmwareOperation> operations;

  Map<String, Object?> toJson() => <String, Object?>{
        'name': name,
        'target': target.identifier,
        'operations': operations
            .map((FirmwareOperation operation) => operation.toJson())
            .toList(growable: false),
      };
}

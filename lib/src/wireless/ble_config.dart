import 'dart:convert';

/// GATT permissions and properties for BLE characteristics.
enum GattPermission {
  read,
  write,
  notify,
  indicate;
}

/// Standard Bluetooth SIG Assigned Services.
enum BleStandardService {
  battery(0x180F, 'Battery Service'),
  deviceInformation(0x180A, 'Device Information'),
  heartRate(0x180D, 'Heart Rate'),
  environmentalSensing(0x181A, 'Environmental Sensing'),
  nordicUart(0x0001, 'Nordic UART Service');

  const BleStandardService(this.assignedNumber, this.displayName);
  final int assignedNumber;
  final String displayName;
}

/// Standard Bluetooth SIG Assigned Characteristics.
enum BleStandardCharacteristic {
  batteryLevel(0x2A19, 'Battery Level'),
  modelNumber(0x2A24, 'Model Number String'),
  manufacturerName(0x2A29, 'Manufacturer Name String'),
  firmwareRevision(0x2A26, 'Firmware Revision String'),
  temperature(0x2A6E, 'Temperature'),
  humidity(0x2A6F, 'Humidity');

  const BleStandardCharacteristic(this.assignedNumber, this.displayName);
  final int assignedNumber;
  final String displayName;
}

/// Strongly-typed GATT UUID value.
final class GattUuid {
  const GattUuid._(this.hex);

  const GattUuid.custom(this.hex);

  factory GattUuid.fromService(BleStandardService service) =>
      GattUuid._(service.assignedNumber.toRadixString(16).toUpperCase().padLeft(4, '0'));

  factory GattUuid.fromCharacteristic(BleStandardCharacteristic characteristic) =>
      GattUuid._(characteristic.assignedNumber.toRadixString(16).toUpperCase().padLeft(4, '0'));

  final String hex;

  static const GattUuid battery = GattUuid._('180F');
  static const GattUuid batteryLevel = GattUuid._('2A19');
  static const GattUuid deviceInformation = GattUuid._('180A');
  static const GattUuid modelNumber = GattUuid._('2A24');
  static const GattUuid manufacturerName = GattUuid._('2A29');
  static const GattUuid firmwareRevision = GattUuid._('2A26');
  static const GattUuid temperature = GattUuid._('2A6E');
  static const GattUuid humidity = GattUuid._('2A6F');

  @override
  String toString() => hex;
}

/// A declarative Bluetooth Low Energy characteristic.
final class BleCharacteristic {
  const BleCharacteristic({
    required this.uuid,
    required this.permissions,
    this.initialValue = const <int>[],
    this.description = '',
  });

  factory BleCharacteristic.batteryLevel({int initialPercent = 100}) =>
      BleCharacteristic(
        uuid: GattUuid.batteryLevel,
        permissions: const <GattPermission>[GattPermission.read, GattPermission.notify],
        initialValue: <int>[initialPercent.clamp(0, 100)],
        description: 'Battery Level (0-100%)',
      );

  final GattUuid uuid;
  final List<GattPermission> permissions;
  final List<int> initialValue;
  final String description;

  Map<String, Object?> toJson() => <String, Object?>{
        'uuid': uuid.hex,
        'permissions': permissions.map((GattPermission p) => p.name).toList(),
        'initialValue': initialValue,
        'description': description,
      };
}

/// A declarative Bluetooth Low Energy service holding characteristics.
final class BleService {
  const BleService({
    required this.uuid,
    required this.characteristics,
  });

  /// Declarative Battery Service with 1-click instantiation.
  factory BleService.battery({int initialLevelPercent = 100}) => BleService(
        uuid: GattUuid.battery,
        characteristics: <BleCharacteristic>[
          BleCharacteristic.batteryLevel(initialPercent: initialLevelPercent),
        ],
      );

  /// Declarative Device Information Service.
  factory BleService.deviceInfo({
    String manufacturer = 'Eulogia',
    String model = 'Flint-Bot',
    String firmware = '1.0.0',
  }) =>
      BleService(
        uuid: GattUuid.deviceInformation,
        characteristics: <BleCharacteristic>[
          BleCharacteristic(
            uuid: GattUuid.manufacturerName,
            permissions: const <GattPermission>[GattPermission.read],
            initialValue: utf8.encode(manufacturer),
            description: 'Manufacturer Name',
          ),
          BleCharacteristic(
            uuid: GattUuid.modelNumber,
            permissions: const <GattPermission>[GattPermission.read],
            initialValue: utf8.encode(model),
            description: 'Model Number',
          ),
          BleCharacteristic(
            uuid: GattUuid.firmwareRevision,
            permissions: const <GattPermission>[GattPermission.read],
            initialValue: utf8.encode(firmware),
            description: 'Firmware Revision',
          ),
        ],
      );

  final GattUuid uuid;
  final List<BleCharacteristic> characteristics;

  Map<String, Object?> toJson() => <String, Object?>{
        'uuid': uuid.hex,
        'characteristics': characteristics.map((BleCharacteristic c) => c.toJson()).toList(),
      };
}

/// Complete BLE configuration for a peripheral device.
final class BlePeripheralConfig {
  const BlePeripheralConfig({
    required this.deviceName,
    required this.services,
    this.advertisingIntervalMs = 100,
  });

  final String deviceName;
  final List<BleService> services;
  final int advertisingIntervalMs;

  Map<String, Object?> toJson() => <String, Object?>{
        'deviceName': deviceName,
        'advertisingIntervalMs': advertisingIntervalMs,
        'services': services.map((BleService s) => s.toJson()).toList(),
      };
}

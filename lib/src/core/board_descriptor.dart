/// A hardware function that a board backend can provide.
enum HardwareCapability {
  gpio,
  gpioEdges,
  pwm,
  i2c,
  spi,
  serial,
  analogInput,
  sensors,
}

/// Immutable identity and capability metadata for a board backend.
final class BoardDescriptor {
  BoardDescriptor({
    required this.id,
    required this.name,
    required this.backend,
    required Set<HardwareCapability> capabilities,
  }) : capabilities = Set<HardwareCapability>.unmodifiable(capabilities);

  /// A stable identifier within the current process or project.
  final String id;

  /// A human-readable board name.
  final String name;

  /// The backend implementation name, such as `simulator`.
  final String backend;

  /// Functions that the backend implements.
  final Set<HardwareCapability> capabilities;

  /// Whether this board provides [capability].
  bool supports(HardwareCapability capability) =>
      capabilities.contains(capability);

  @override
  String toString() => '$name ($backend, $id)';
}

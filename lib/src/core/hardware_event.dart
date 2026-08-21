/// Broad event categories recorded by observable backends.
enum HardwareEventKind {
  configuration,
  stateChange,
  read,
  transfer,
  data,
  timing,
  lifecycle,
}

/// One ordered hardware interaction recorded by a backend.
final class HardwareEvent {
  HardwareEvent({
    required this.sequence,
    required this.elapsed,
    required this.kind,
    required this.resource,
    required this.operation,
    Map<String, Object?> details = const <String, Object?>{},
  }) : details = Map<String, Object?>.unmodifiable(details);

  final int sequence;
  final Duration elapsed;
  final HardwareEventKind kind;
  final String resource;
  final String operation;
  final Map<String, Object?> details;

  @override
  String toString() =>
      '#$sequence ${elapsed.inMicroseconds}us $resource $operation $details';
}

/// Stable, backend-independent hardware failure categories.
enum HardwareErrorCode {
  invalidArgument,
  unsupportedCapability,
  resourceConflict,
  resourceClosed,
  backendFailure,
  toolchainUnavailable,
  generationFailure,
}

/// Base exception for portable Flint Hardware failures.
class HardwareException implements Exception {
  const HardwareException({
    required this.code,
    required this.message,
    this.operation,
    this.resource,
    this.cause,
  });

  final HardwareErrorCode code;
  final String message;
  final String? operation;
  final String? resource;
  final Object? cause;

  @override
  String toString() {
    final StringBuffer output = StringBuffer('HardwareException(${code.name})');
    if (operation != null) {
      output.write(' during $operation');
    }
    if (resource != null) {
      output.write(' on $resource');
    }
    output.write(': $message');
    return output.toString();
  }
}

final class InvalidHardwareArgumentException extends HardwareException {
  InvalidHardwareArgumentException({
    required String argument,
    required Object? value,
    required String message,
  }) : super(
          code: HardwareErrorCode.invalidArgument,
          message: '$message ($argument: $value)',
          operation: 'validate',
        );
}

final class UnsupportedCapabilityException extends HardwareException {
  UnsupportedCapabilityException({
    required String capability,
    required String backend,
  }) : super(
          code: HardwareErrorCode.unsupportedCapability,
          message: 'The $backend backend does not support $capability.',
          operation: 'acquire',
          resource: capability,
        );
}

final class ResourceConflictException extends HardwareException {
  ResourceConflictException(String resource)
      : super(
          code: HardwareErrorCode.resourceConflict,
          message: 'The resource is already acquired.',
          operation: 'acquire',
          resource: resource,
        );
}

final class ResourceClosedException extends HardwareException {
  ResourceClosedException(String resource, {super.operation})
      : super(
          code: HardwareErrorCode.resourceClosed,
          message: 'The resource has been closed.',
          resource: resource,
        );
}

final class ToolchainUnavailableException extends HardwareException {
  ToolchainUnavailableException(String message, {super.cause})
      : super(
          code: HardwareErrorCode.toolchainUnavailable,
          message: message,
          operation: 'toolchain',
        );
}

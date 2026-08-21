import 'package:flint_hardware/flint_hardware.dart';
import 'package:test/test.dart';

void main() {
  test('board descriptors defensively copy capabilities', () {
    final Set<HardwareCapability> capabilities = <HardwareCapability>{
      HardwareCapability.gpio,
    };
    final BoardDescriptor descriptor = BoardDescriptor(
      id: 'test',
      name: 'Test board',
      backend: 'test',
      capabilities: capabilities,
    );

    capabilities.add(HardwareCapability.pwm);

    expect(descriptor.supports(HardwareCapability.gpio), isTrue);
    expect(descriptor.supports(HardwareCapability.pwm), isFalse);
    expect(
      () => descriptor.capabilities.add(HardwareCapability.serial),
      throwsUnsupportedError,
    );
  });

  test('system clock rejects negative delays', () {
    final SystemHardwareClock clock = SystemHardwareClock();
    expect(
      () => clock.delay(const Duration(microseconds: -1)),
      throwsA(isA<InvalidHardwareArgumentException>()),
    );
  });
}

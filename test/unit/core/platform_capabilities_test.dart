// test/unit/core/platform_capabilities_test.dart
import 'package:coldigui/core/platform/platform_capabilities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlatformCapabilities.web', () {
    test('isWeb e needsUserGestureForAudio', () {
      expect(PlatformCapabilities.web.isWeb, isTrue);
      expect(PlatformCapabilities.web.needsUserGestureForAudio, isTrue);
    });
  });

  group('PlatformCapabilities.native', () {
    test('supportsBackgroundAudio', () {
      expect(PlatformCapabilities.native.supportsBackgroundAudio, isTrue);
    });
  });

  group('currentPlatformCapabilities', () {
    test('na VM devolve .native', () {
      expect(currentPlatformCapabilities(), PlatformCapabilities.native);
    });
  });
}

import 'package:coldigui/core/constants/feature_flags.dart';
import 'package:coldigui/core/providers/feature_flags_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FeatureFlags', () {
    test('padrão: events e adminUpload desligados, social ligado', () {
      const flags = FeatureFlags();

      expect(flags.events, isFalse);
      expect(flags.social, isTrue);
      expect(flags.adminUpload, isFalse);
    });

    test('fromEnvironment lê os defaults quando nenhuma flag é definida', () {
      final flags = FeatureFlags.fromEnvironment();

      expect(flags.events, isFalse);
      expect(flags.social, isTrue);
      expect(flags.adminUpload, isFalse);
    });

    test('construtor aceita overrides explícitos', () {
      const flags = FeatureFlags(
        events: true,
        social: false,
        adminUpload: true,
      );

      expect(flags.events, isTrue);
      expect(flags.social, isFalse);
      expect(flags.adminUpload, isTrue);
    });
  });

  group('featureFlagsProvider', () {
    test('devolve FeatureFlags.fromEnvironment por padrão', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final flags = container.read(featureFlagsProvider);

      expect(flags.events, isFalse);
      expect(flags.social, isTrue);
      expect(flags.adminUpload, isFalse);
    });

    test('é sobreescrevível em teste', () {
      final container = ProviderContainer(
        overrides: [
          featureFlagsProvider.overrideWithValue(
            const FeatureFlags(events: true),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(featureFlagsProvider).events, isTrue);
    });
  });
}

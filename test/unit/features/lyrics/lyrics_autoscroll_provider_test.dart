import 'package:coldigui/features/lyrics/presentation/providers/lyrics_autoscroll_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('lyricsAutoscrollProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('começa parado na velocidade padrão do meio (8)', () {
      final state = container.read(lyricsAutoscrollProvider);
      expect(state.running, isFalse);
      expect(state.speed, kLyricsAutoscrollDefaultSpeed);
      expect(state.speed, 8);
    });

    test('toggle liga e desliga o autoscroll', () {
      final notifier = container.read(lyricsAutoscrollProvider.notifier);
      notifier.toggle();
      expect(container.read(lyricsAutoscrollProvider).running, isTrue);
      notifier.toggle();
      expect(container.read(lyricsAutoscrollProvider).running, isFalse);
    });

    test('setSpeed satura no teto (15) e piso (1)', () {
      final notifier = container.read(lyricsAutoscrollProvider.notifier);
      notifier.setSpeed(20);
      expect(container.read(lyricsAutoscrollProvider).speed, 15);
      notifier.setSpeed(-5);
      expect(container.read(lyricsAutoscrollProvider).speed, 1);
    });

    test('stop para o autoscroll', () {
      final notifier = container.read(lyricsAutoscrollProvider.notifier);
      notifier.toggle();
      expect(container.read(lyricsAutoscrollProvider).running, isTrue);
      notifier.stop();
      expect(container.read(lyricsAutoscrollProvider).running, isFalse);
    });
  });
}

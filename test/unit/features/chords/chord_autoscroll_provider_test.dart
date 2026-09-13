import 'package:coldigui/features/chords/presentation/providers/chord_autoscroll_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('chordAutoscrollProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('comeca parado, na velocidade padrao', () {
      final state = container.read(chordAutoscrollProvider);

      expect(state.running, isFalse);
      expect(state.speed, kChordAutoscrollDefaultSpeed);
    });

    test('toggle liga o autoscroll', () {
      container.read(chordAutoscrollProvider.notifier).toggle();

      expect(container.read(chordAutoscrollProvider).running, isTrue);
    });

    test('toggle duas vezes volta a desligado', () {
      final notifier = container.read(chordAutoscrollProvider.notifier);

      notifier.toggle();
      notifier.toggle();

      expect(container.read(chordAutoscrollProvider).running, isFalse);
    });

    test('setSpeed satura no teto', () {
      container.read(chordAutoscrollProvider.notifier).setSpeed(6);

      expect(container.read(chordAutoscrollProvider).speed, 5);
    });

    test('setSpeed satura no piso', () {
      container.read(chordAutoscrollProvider.notifier).setSpeed(0);

      expect(container.read(chordAutoscrollProvider).speed, 1);
    });

    test('stop desliga quando estava rodando', () {
      final notifier = container.read(chordAutoscrollProvider.notifier);
      notifier.toggle();

      notifier.stop();

      expect(container.read(chordAutoscrollProvider).running, isFalse);
    });

    test('stop nao faz nada quando ja estava parado', () {
      container.read(chordAutoscrollProvider.notifier).stop();

      expect(container.read(chordAutoscrollProvider).running, isFalse);
    });
  });
}

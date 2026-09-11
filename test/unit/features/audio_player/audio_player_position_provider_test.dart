import 'package:coldigui/features/audio_player/presentation/providers/audio_player_position_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AudioPlayerPosition', () {
    test('progress é 0 quando a duração é zero (evita divisão por zero)', () {
      const value = AudioPlayerPosition(
        position: Duration(seconds: 5),
        duration: Duration.zero,
      );
      expect(value.progress, 0);
    });

    test('progress é a razão posição/duração', () {
      const value = AudioPlayerPosition(
        position: Duration(seconds: 30),
        duration: Duration(seconds: 120),
      );
      expect(value.progress, closeTo(0.25, 0.0001));
    });

    test('progress não passa de 1 mesmo com posição além da duração', () {
      const value = AudioPlayerPosition(
        position: Duration(seconds: 200),
        duration: Duration(seconds: 100),
      );
      expect(value.progress, 1);
    });

    test('estado inicial é zero/zero', () {
      const value = AudioPlayerPosition();
      expect(value.position, Duration.zero);
      expect(value.duration, Duration.zero);
      expect(value.progress, 0);
    });
  });

  group('audioPlayerPositionProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('build() começa zerado', () {
      final state = container.read(audioPlayerPositionProvider);
      expect(state.position, Duration.zero);
      expect(state.duration, Duration.zero);
    });

    test('update() troca só o campo informado', () {
      final notifier = container.read(audioPlayerPositionProvider.notifier);

      notifier.update(position: const Duration(seconds: 3));
      expect(
        container.read(audioPlayerPositionProvider).position,
        const Duration(seconds: 3),
      );
      expect(
        container.read(audioPlayerPositionProvider).duration,
        Duration.zero,
      );

      notifier.update(duration: const Duration(seconds: 180));
      expect(
        container.read(audioPlayerPositionProvider).position,
        const Duration(seconds: 3),
        reason: 'atualizar a duração não pode mexer na posição',
      );
      expect(
        container.read(audioPlayerPositionProvider).duration,
        const Duration(seconds: 180),
      );
    });

    test('reset() volta pro zero/zero', () {
      final notifier = container.read(audioPlayerPositionProvider.notifier);
      notifier.update(
        position: const Duration(seconds: 10),
        duration: const Duration(seconds: 200),
      );

      notifier.reset();

      final state = container.read(audioPlayerPositionProvider);
      expect(state.position, Duration.zero);
      expect(state.duration, Duration.zero);
    });

    test('sucessivos updates de posição notificam cada troca', () {
      final notifier = container.read(audioPlayerPositionProvider.notifier);
      final states = <AudioPlayerPosition>[];
      container.listen(
        audioPlayerPositionProvider,
        (_, next) => states.add(next),
        fireImmediately: false,
      );

      notifier.update(position: const Duration(milliseconds: 200));
      notifier.update(position: const Duration(milliseconds: 400));
      notifier.update(position: const Duration(milliseconds: 600));

      expect(states.length, 3);
      expect(states.last.position, const Duration(milliseconds: 600));
    });
  });
}

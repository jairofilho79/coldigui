import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/features/app_shell/presentation/widgets/stage_wakelock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldHoldWakelock — rotas de palco', () {
    test('leitor PDF segura a tela ligada', () {
      expect(
        shouldHoldWakelock(path: RoutePaths.reader, playing: false),
        isTrue,
      );
    });

    test('leitor de cifras segura a tela ligada', () {
      expect(
        shouldHoldWakelock(path: RoutePaths.chords, playing: false),
        isTrue,
      );
    });

    test('reprodutor de áudio segura a tela ligada', () {
      expect(
        shouldHoldWakelock(path: RoutePaths.audio, playing: false),
        isTrue,
      );
    });
  });

  group('shouldHoldWakelock — fora do palco', () {
    test('home sem áudio libera a tela', () {
      expect(
        shouldHoldWakelock(path: RoutePaths.home, playing: false),
        isFalse,
      );
    });

    test('biblioteca sem áudio libera a tela', () {
      expect(
        shouldHoldWakelock(path: RoutePaths.library, playing: false),
        isFalse,
      );
    });

    test('áudio tocando segura a tela mesmo fora das rotas de palco', () {
      expect(shouldHoldWakelock(path: RoutePaths.home, playing: true), isTrue);
    });

    test('rota desconhecida sem áudio libera a tela', () {
      expect(shouldHoldWakelock(path: '/qualquer', playing: false), isFalse);
    });
  });
}

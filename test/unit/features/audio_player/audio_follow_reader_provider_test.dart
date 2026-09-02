import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_follow_reader_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container() async {
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('seguir o áudio vem ligado por padrão', () async {
    SharedPreferences.setMockInitialValues({});
    final container = await _container();

    expect(container.read(audioFollowReaderProvider), isTrue);
  });

  test('lê o valor persistido em SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({kAudioFollowReaderPrefsKey: false});
    final container = await _container();

    expect(container.read(audioFollowReaderProvider), isFalse);
  });

  test('toggle inverte o estado e persiste', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await container.read(audioFollowReaderProvider.notifier).toggle();

    expect(container.read(audioFollowReaderProvider), isFalse);
    expect(prefs.getBool(kAudioFollowReaderPrefsKey), isFalse);

    await container.read(audioFollowReaderProvider.notifier).toggle();

    expect(container.read(audioFollowReaderProvider), isTrue);
    expect(prefs.getBool(kAudioFollowReaderPrefsKey), isTrue);
  });

  test('estado sobrevive a um novo ProviderContainer', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final first = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(first.dispose);
    await first.read(audioFollowReaderProvider.notifier).setEnabled(false);

    final second = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(second.dispose);

    expect(second.read(audioFollowReaderProvider), isFalse);
  });

  group('shouldFollowAudioInReader', () {
    test('segue quando a faixa muda numa rota de leitura', () {
      expect(
        shouldFollowAudioInReader(
          enabled: true,
          isReaderRoute: true,
          previousGroupId: 'p1',
          nextGroupId: 'p2',
          currentMaterialPdfId: 'pdf-p1',
          targetMaterialPdfId: 'pdf-p2',
        ),
        isTrue,
      );
    });

    test('não segue com o toggle desligado', () {
      expect(
        shouldFollowAudioInReader(
          enabled: false,
          isReaderRoute: true,
          previousGroupId: 'p1',
          nextGroupId: 'p2',
          currentMaterialPdfId: 'pdf-p1',
          targetMaterialPdfId: 'pdf-p2',
        ),
        isFalse,
      );
    });

    test('não navega fora das rotas de leitura', () {
      expect(
        shouldFollowAudioInReader(
          enabled: true,
          isReaderRoute: false,
          previousGroupId: 'p1',
          nextGroupId: 'p2',
          currentMaterialPdfId: null,
          targetMaterialPdfId: 'pdf-p2',
        ),
        isFalse,
      );
    });

    test('não navega quando o grupo não mudou', () {
      expect(
        shouldFollowAudioInReader(
          enabled: true,
          isReaderRoute: true,
          previousGroupId: 'p1',
          nextGroupId: 'p1',
          currentMaterialPdfId: 'outro',
          targetMaterialPdfId: 'pdf-p1',
        ),
        isFalse,
      );
    });

    test('não navega sem material para o grupo', () {
      expect(
        shouldFollowAudioInReader(
          enabled: true,
          isReaderRoute: true,
          previousGroupId: 'p1',
          nextGroupId: 'p2',
          currentMaterialPdfId: 'pdf-p1',
          targetMaterialPdfId: null,
        ),
        isFalse,
      );
    });

    test('não navega quando o material já está aberto', () {
      expect(
        shouldFollowAudioInReader(
          enabled: true,
          isReaderRoute: true,
          previousGroupId: 'p1',
          nextGroupId: 'p2',
          currentMaterialPdfId: 'pdf-p2',
          targetMaterialPdfId: 'pdf-p2',
        ),
        isFalse,
      );
    });

    test('não navega com faixa sem grupo', () {
      expect(
        shouldFollowAudioInReader(
          enabled: true,
          isReaderRoute: true,
          previousGroupId: 'p1',
          nextGroupId: '',
          currentMaterialPdfId: 'pdf-p1',
          targetMaterialPdfId: 'pdf-p2',
        ),
        isFalse,
      );
    });
  });
}

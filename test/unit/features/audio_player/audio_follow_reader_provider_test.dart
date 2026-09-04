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
          sessionRestoredWithoutPlayback: false,
          enabled: true,
          isReaderRoute: true,
          previousGroupId: 'p1',
          nextGroupId: 'p2',
          currentMaterialGroupId: 'p1',
          targetMaterialPdfId: 'pdf-p2',
        ),
        isTrue,
      );
    });

    test('não segue com o toggle desligado', () {
      expect(
        shouldFollowAudioInReader(
          sessionRestoredWithoutPlayback: false,
          enabled: false,
          isReaderRoute: true,
          previousGroupId: 'p1',
          nextGroupId: 'p2',
          currentMaterialGroupId: 'p1',
          targetMaterialPdfId: 'pdf-p2',
        ),
        isFalse,
      );
    });

    test('não navega fora das rotas de leitura', () {
      expect(
        shouldFollowAudioInReader(
          sessionRestoredWithoutPlayback: false,
          enabled: true,
          isReaderRoute: false,
          previousGroupId: 'p1',
          nextGroupId: 'p2',
          currentMaterialGroupId: null,
          targetMaterialPdfId: 'pdf-p2',
        ),
        isFalse,
      );
    });

    test('não navega na restauração da sessão (fila restaurada sem play)', () {
      expect(
        shouldFollowAudioInReader(
          sessionRestoredWithoutPlayback: true,
          enabled: true,
          isReaderRoute: true,
          previousGroupId: null,
          nextGroupId: 'p2',
          currentMaterialGroupId: 'p1',
          targetMaterialPdfId: 'pdf-p2',
        ),
        isFalse,
      );
    });

    test('primeira faixa da sessão segue (A6)', () {
      // Louvor p1 aberto no leitor, usuário dá play no áudio de p2: não há
      // faixa anterior, mas a fila não veio de restauração.
      expect(
        shouldFollowAudioInReader(
          sessionRestoredWithoutPlayback: false,
          enabled: true,
          isReaderRoute: true,
          previousGroupId: null,
          nextGroupId: 'p2',
          currentMaterialGroupId: 'p1',
          targetMaterialPdfId: 'pdf-p2',
        ),
        isTrue,
      );
    });

    test('troca de faixa depois de uma restauração ainda parada não segue', () {
      expect(
        shouldFollowAudioInReader(
          sessionRestoredWithoutPlayback: true,
          enabled: true,
          isReaderRoute: true,
          previousGroupId: 'p1',
          nextGroupId: 'p2',
          currentMaterialGroupId: 'p1',
          targetMaterialPdfId: 'pdf-p2',
        ),
        isFalse,
      );
    });

    test('não navega quando o grupo não mudou', () {
      expect(
        shouldFollowAudioInReader(
          sessionRestoredWithoutPlayback: false,
          enabled: true,
          isReaderRoute: true,
          previousGroupId: 'p1',
          nextGroupId: 'p1',
          currentMaterialGroupId: 'p9',
          targetMaterialPdfId: 'pdf-p1',
        ),
        isFalse,
      );
    });

    test('não navega sem material para o grupo', () {
      expect(
        shouldFollowAudioInReader(
          sessionRestoredWithoutPlayback: false,
          enabled: true,
          isReaderRoute: true,
          previousGroupId: 'p1',
          nextGroupId: 'p2',
          currentMaterialGroupId: 'p1',
          targetMaterialPdfId: null,
        ),
        isFalse,
      );
    });

    test('não troca a cifra aberta pela partitura do mesmo louvor', () {
      expect(
        shouldFollowAudioInReader(
          sessionRestoredWithoutPlayback: false,
          enabled: true,
          isReaderRoute: true,
          previousGroupId: 'p1',
          nextGroupId: 'p2',
          // Cifra do louvor p2 aberta; o alvo é a partitura do mesmo p2.
          currentMaterialGroupId: 'p2',
          targetMaterialPdfId: 'pdf-p2-partitura',
        ),
        isFalse,
      );
    });

    test('não navega com faixa sem grupo', () {
      expect(
        shouldFollowAudioInReader(
          sessionRestoredWithoutPlayback: false,
          enabled: true,
          isReaderRoute: true,
          previousGroupId: 'p1',
          nextGroupId: '',
          currentMaterialGroupId: 'p1',
          targetMaterialPdfId: 'pdf-p2',
        ),
        isFalse,
      );
    });
  });
}

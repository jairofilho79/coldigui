import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/utils/url_sync_params.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/recently_opened_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_route_params_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _track = AudioTrack(
  audioId: 'audio-1',
  r2Key: 'assets/praises/p1/a.mp3',
  nome: 'Faixa',
  numero: '001',
  groupId: 'p1',
  categoria: 'Áudio',
  classificacao: 'ColAdultos',
);

/// Container com um listener vivo em [recentlyOpenedProvider]: no Riverpod
/// 3.3 um `ref.listen` dentro do `build` de um `Notifier` só dispara enquanto
/// o próprio notifier tem pelo menos um observador — sem isto os
/// `ref.listen(readerRouteParamsProvider, …)`/
/// `ref.listen(audioPlayerSessionProvider…)` internos ficariam mudos.
ProviderContainer _makeContainer(SharedPreferences prefs) {
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  container.listen(recentlyOpenedProvider, (_, _) {});
  return container;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('record dedupe: reabrir um id existente move para o topo', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = _makeContainer(prefs);
    final notifier = container.read(recentlyOpenedProvider.notifier);

    notifier.record('a');
    notifier.record('b');
    notifier.record('a');

    expect(container.read(recentlyOpenedProvider), ['a', 'b']);
  });

  test('teto de 5 ids — o mais antigo cai', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = _makeContainer(prefs);
    final notifier = container.read(recentlyOpenedProvider.notifier);

    for (var i = 1; i <= 6; i++) {
      notifier.record('id$i');
    }

    final state = container.read(recentlyOpenedProvider);
    expect(state.length, 5);
    expect(state.first, 'id6');
    expect(state.contains('id1'), isFalse);
  });

  test('persiste em SharedPreferences e relê num container novo', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = _makeContainer(prefs);

    container.read(recentlyOpenedProvider.notifier).record('a');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final reopened = _makeContainer(prefs);
    expect(reopened.read(recentlyOpenedProvider), ['a']);
  });

  test('JSON inválido no storage devolve lista vazia', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.recentlyOpened, '{not json');

    final container = _makeContainer(prefs);
    expect(container.read(recentlyOpenedProvider), isEmpty);
  });

  test(
    'readerRouteParamsProvider com pdfId grava o id (leitor e cifra)',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _makeContainer(prefs);

      container.read(readerRouteParamsProvider.notifier).update({
        UrlSyncParams.pdfId: 'x',
      });

      expect(container.read(recentlyOpenedProvider), ['x']);
    },
  );

  test('troca de faixa na sessão de áudio grava o audioId', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = _makeContainer(prefs);

    await container.read(audioPlayerSessionProvider.notifier).restoreQueue([
      _track,
    ]);

    expect(container.read(recentlyOpenedProvider), contains('audio-1'));
  });

  test('clear esvazia a lista', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = _makeContainer(prefs);
    final notifier = container.read(recentlyOpenedProvider.notifier);
    notifier.record('a');

    notifier.clear();

    expect(container.read(recentlyOpenedProvider), isEmpty);
  });
}

import 'dart:async';

import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Duplo do player: `errorStream` controlável e `setAudioSources` que só
/// completa quando o teste manda (é assim que duas `playQueue` se sobrepõem).
class _ControllablePlayer extends AudioPlayer {
  final errors = StreamController<PlayerException>.broadcast();
  final indexes = StreamController<int?>.broadcast();
  final setSourcesCalls = <List<AudioSource>>[];
  final pendingSetSources = <Completer<Duration?>>[];

  /// Quando `true`, `setAudioSources` espera um `complete` explícito do teste.
  bool blockSetSources = false;
  Object? playError;
  int playCalls = 0;

  @override
  Stream<PlayerException> get errorStream => errors.stream;

  @override
  Stream<int?> get currentIndexStream => indexes.stream;

  @override
  Future<Duration?> setAudioSources(
    List<AudioSource> audioSources, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
    ShuffleOrder? shuffleOrder,
  }) {
    setSourcesCalls.add(audioSources);
    if (!blockSetSources) return Future.value(null);
    final completer = Completer<Duration?>();
    pendingSetSources.add(completer);
    return completer.future;
  }

  @override
  Future<void> play() async {
    playCalls++;
    final error = playError;
    if (error != null) throw error;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> seek(Duration? position, {int? index}) async {}

  @override
  Future<void> seekToNext() async {
    throw StateError('sem plugin');
  }

  @override
  Future<void> seekToPrevious() async {
    throw StateError('sem plugin');
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    await errors.close();
    await indexes.close();
  }
}

AudioTrack _track(String id) => AudioTrack(
  audioId: id,
  r2Key: 'assets/praises/p1/$id.mp3',
  nome: id.toUpperCase(),
  numero: '001',
  groupId: 'p1',
  categoria: 'Áudio',
  classificacao: 'Coro',
);

/// `r2Key` absoluto e malformado: `Uri.parse` estoura em `_playbackUriForTrack`
/// — antes de `_applyQueue` marcar que está trocando as fontes.
AudioTrack _unparseableTrack(String id) => AudioTrack(
  audioId: id,
  r2Key: 'https://[::malformado',
  nome: id.toUpperCase(),
  numero: '002',
  groupId: 'p2',
  categoria: 'Áudio',
  classificacao: 'Coro',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ControllablePlayer player;

  Future<ProviderContainer> makeContainer() async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        audioSessionPlayerFactoryProvider.overrideWithValue(() => player),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    player = _ControllablePlayer();
  });

  test('playQueue sobreposta: só a segunda chamada aplica a fila', () async {
    final container = await makeContainer();
    final notifier = container.read(audioPlayerSessionProvider.notifier);

    final first = [_track('a1'), _track('a2')];
    final second = [_track('b1'), _track('b2')];

    player.blockSetSources = true;
    final firstCall = notifier.playQueue(first, startIndex: 1);
    // Deixa a primeira chegar até `setAudioSources`.
    await Future<void>.delayed(Duration.zero);
    final secondCall = notifier.playQueue(second, startIndex: 0);
    await Future<void>.delayed(Duration.zero);

    expect(player.pendingSetSources.length, 2);
    // A primeira completa depois da segunda ter começado — resultado atrasado.
    player.pendingSetSources[0].complete(null);
    player.pendingSetSources[1].complete(null);
    await Future.wait([firstCall, secondCall]);

    final state = container.read(audioPlayerSessionProvider);
    expect(state.queue.map((t) => t.audioId), ['b1', 'b2']);
    expect(state.currentIndex, 0);
    expect(
      player.playCalls,
      1,
      reason: 'a chamada superada não pode disparar play',
    );
  });

  test('carga que falha cedo não trava o índice da sessão', () async {
    final container = await makeContainer();
    final notifier = container.read(audioPlayerSessionProvider.notifier);

    // A: prende dentro de `setAudioSources`, já marcada como trocando fontes.
    player.blockSetSources = true;
    final callA = notifier.playQueue([_track('a1'), _track('a2')]);
    await Future<void>.delayed(Duration.zero);
    expect(player.pendingSetSources.length, 1);

    // B: supera A e estoura **antes** de marcar a troca de fontes.
    await notifier.playQueue([
      _unparseableTrack('b1'),
      _unparseableTrack('b2'),
    ]);
    expect(container.read(audioPlayerSessionProvider).errorMessage, isNotNull);

    // A termina depois de superada: não pode deixar a marca presa.
    player.pendingSetSources.single.complete(null);
    await callA;

    player.indexes.add(1);
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(audioPlayerSessionProvider).currentIndex,
      1,
      reason: 'a sessão precisa voltar a seguir o currentIndexStream',
    );
  });

  test('erro de fonte superada não pinta sobre a fila nova', () async {
    final container = await makeContainer();
    final notifier = container.read(audioPlayerSessionProvider.notifier);

    player.blockSetSources = true;
    final pending = notifier.playQueue([_track('a1')]);
    await Future<void>.delayed(Duration.zero);

    // Erro atrasado da fonte anterior, enquanto a nova ainda carrega.
    player.errors.add(PlayerException(1, 'MEDIA_ERR_ABORTED', 0));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(audioPlayerSessionProvider).errorMessage, isNull);

    player.pendingSetSources.single.complete(null);
    await pending;
    expect(container.read(audioPlayerSessionProvider).errorMessage, isNull);
  });

  test('intenção de reprodução do usuário limpa o erro visível', () async {
    final container = await makeContainer();
    final notifier = container.read(audioPlayerSessionProvider.notifier);

    await notifier.playQueue([_track('a1'), _track('a2')]);
    player.errors.add(PlayerException(1, 'MEDIA_ERR_NETWORK', 0));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(audioPlayerSessionProvider).errorMessage, isNotNull);

    await notifier.playPause();

    expect(
      container.read(audioPlayerSessionProvider).errorMessage,
      isNull,
      reason:
          'tocar de novo com sucesso tem que devolver o seek no lugar do erro',
    );
  });

  test('close durante a carga não deixa a fila voltar', () async {
    final container = await makeContainer();
    final notifier = container.read(audioPlayerSessionProvider.notifier);

    player.blockSetSources = true;
    final pending = notifier.playQueue([_track('a1')]);
    await Future<void>.delayed(Duration.zero);

    await notifier.close();
    player.pendingSetSources.single.complete(null);
    await pending;

    final state = container.read(audioPlayerSessionProvider);
    expect(state.queue, isEmpty);
    expect(state.playing, isFalse);
    expect(player.playCalls, 0);
  });

  test('errorStream do player vira erro visível e para a reprodução', () async {
    final container = await makeContainer();
    final notifier = container.read(audioPlayerSessionProvider.notifier);

    await notifier.playQueue([_track('a1')]);
    expect(container.read(audioPlayerSessionProvider).errorMessage, isNull);

    player.errors.add(PlayerException(1, 'MEDIA_ERR_DECODE', 0));
    await Future<void>.delayed(Duration.zero);

    final state = container.read(audioPlayerSessionProvider);
    expect(state.errorMessage, isNotNull);
    expect(state.playing, isFalse);
  });

  test('retryCurrent limpa o erro e reaplica a fila do índice atual', () async {
    final container = await makeContainer();
    final notifier = container.read(audioPlayerSessionProvider.notifier);

    await notifier.restoreQueue([_track('a1'), _track('a2')], startIndex: 1);
    player.errors.add(PlayerException(1, 'MEDIA_ERR_NETWORK', 1));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(audioPlayerSessionProvider).errorMessage, isNotNull);

    final callsBefore = player.setSourcesCalls.length;
    await notifier.retryCurrent();

    final state = container.read(audioPlayerSessionProvider);
    expect(state.errorMessage, isNull);
    expect(state.currentIndex, 1);
    expect(player.setSourcesCalls.length, callsBefore + 1);
    expect(
      state.restoredWithoutPlayback,
      isFalse,
      reason: 'tentar de novo é intenção do usuário (A6)',
    );
  });

  test('retryCurrent sem fila não faz nada', () async {
    final container = await makeContainer();
    await container.read(audioPlayerSessionProvider.notifier).retryCurrent();
    expect(player.setSourcesCalls, isEmpty);
  });

  test('playPause não propaga erro do player', () async {
    final container = await makeContainer();
    final notifier = container.read(audioPlayerSessionProvider.notifier);
    await notifier.playQueue([_track('a1')]);

    player.playError = StateError('sem plugin');
    await expectLater(notifier.playPause(), completes);
    expect(container.read(audioPlayerSessionProvider).errorMessage, isNotNull);
  });

  test('skipToNext não propaga erro do player', () async {
    final container = await makeContainer();
    final notifier = container.read(audioPlayerSessionProvider.notifier);
    await notifier.playQueue([_track('a1'), _track('a2')]);

    await expectLater(notifier.skipToNext(), completes);
    expect(container.read(audioPlayerSessionProvider).errorMessage, isNotNull);
  });

  test('skipToPrevious não propaga erro do player', () async {
    final container = await makeContainer();
    final notifier = container.read(audioPlayerSessionProvider.notifier);
    await notifier.playQueue([_track('a1'), _track('a2')], startIndex: 1);

    await expectLater(notifier.skipToPrevious(), completes);
    expect(container.read(audioPlayerSessionProvider).errorMessage, isNotNull);
  });

  test('skipToIndex e seek não propagam erro do player', () async {
    final container = await makeContainer();
    final notifier = container.read(audioPlayerSessionProvider.notifier);
    await notifier.playQueue([_track('a1'), _track('a2')]);

    player.playError = StateError('sem plugin');
    await expectLater(notifier.skipToIndex(1), completes);
    expect(container.read(audioPlayerSessionProvider).errorMessage, isNotNull);

    await expectLater(notifier.seek(const Duration(seconds: 2)), completes);
  });
}

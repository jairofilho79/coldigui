import 'dart:async';

import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/audio_player/data/datasources/audio_playback_position_store.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_position_provider.dart';
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
  final positions = StreamController<Duration>.broadcast();
  final durations = StreamController<Duration?>.broadcast();
  final playerStates = StreamController<PlayerState>.broadcast();
  final setSourcesCalls = <List<AudioSource>>[];
  final initialPositions = <Duration?>[];
  final pendingSetSources = <Completer<Duration?>>[];
  final seekCalls = <Duration?>[];
  final setSpeedCalls = <double>[];

  /// Quando `true`, `setAudioSources` espera um `complete` explícito do teste.
  bool blockSetSources = false;
  Object? playError;
  int playCalls = 0;

  /// Sobrescreve o getter do `AudioPlayer` real (lido por `playPause`) — o
  /// teste ajusta direto (`player.playing = true`) para escolher o ramo.
  @override
  bool playing = false;

  @override
  Stream<PlayerException> get errorStream => errors.stream;

  @override
  Stream<int?> get currentIndexStream => indexes.stream;

  @override
  Stream<Duration> get positionStream => positions.stream;

  @override
  Stream<Duration?> get durationStream => durations.stream;

  @override
  Stream<PlayerState> get playerStateStream => playerStates.stream;

  @override
  Future<Duration?> setAudioSources(
    List<AudioSource> audioSources, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
    ShuffleOrder? shuffleOrder,
  }) {
    setSourcesCalls.add(audioSources);
    initialPositions.add(initialPosition);
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
  Future<void> seek(Duration? position, {int? index}) async {
    seekCalls.add(position);
  }

  @override
  Future<void> setSpeed(double speed) async {
    setSpeedCalls.add(speed);
  }

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
    await positions.close();
    await durations.close();
    await playerStates.close();
  }
}

AudioTrack _track(String id, {Duration? duration}) => AudioTrack(
  audioId: id,
  r2Key: 'assets/praises/p1/$id.mp3',
  nome: id.toUpperCase(),
  numero: '001',
  groupId: 'p1',
  categoria: 'Áudio',
  classificacao: 'Coro',
  duration: duration,
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

  test(
    'troca em voo ignora o índice do player mesmo com carga superada',
    () async {
      final container = await makeContainer();
      final notifier = container.read(audioPlayerSessionProvider.notifier);

      // A: genuinamente dentro de `setAudioSources`.
      player.blockSetSources = true;
      final callA = notifier.playQueue([_track('a1'), _track('a2')]);
      await Future<void>.delayed(Duration.zero);

      // B: supera A e estoura antes de qualquer mexida no player.
      await notifier.playQueue([
        _unparseableTrack('b1'),
        _unparseableTrack('b2'),
      ]);

      // A troca de fontes de A continua em voo: o índice que o player cospe no
      // meio da troca é lixo e não pode mexer na sessão.
      player.indexes.add(1);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(audioPlayerSessionProvider).currentIndex,
        0,
        reason: 'com setAudioSources em voo, o currentIndexStream é ruído',
      );

      // Terminou a troca: o próximo índice vale de novo.
      player.pendingSetSources.single.complete(null);
      await callA;
      player.indexes.add(1);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(audioPlayerSessionProvider).currentIndex, 1);
    },
  );

  test(
    'duas cargas sobrepostas seguram a marca até as duas terminarem',
    () async {
      final container = await makeContainer();
      final notifier = container.read(audioPlayerSessionProvider.notifier);

      player.blockSetSources = true;
      final callA = notifier.playQueue([_track('a1'), _track('a2')]);
      await Future<void>.delayed(Duration.zero);
      final callB = notifier.playQueue([_track('b1'), _track('b2')]);
      await Future<void>.delayed(Duration.zero);
      expect(player.pendingSetSources.length, 2);

      // Só a primeira terminou: ainda há troca em voo (a segunda).
      player.pendingSetSources[0].complete(null);
      await callA;
      player.indexes.add(1);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(audioPlayerSessionProvider).currentIndex,
        0,
        reason: 'a segunda troca ainda está em voo',
      );

      player.pendingSetSources[1].complete(null);
      await callB;
      player.indexes.add(1);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(audioPlayerSessionProvider).currentIndex, 1);
    },
  );

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

  group('posição em provider próprio (A7)', () {
    test(
      'avançar a posição não muda a identidade do estado da sessão',
      () async {
        final container = await makeContainer();
        final notifier = container.read(audioPlayerSessionProvider.notifier);
        await notifier.playQueue([_track('a1')]);

        final before = container.read(audioPlayerSessionProvider);

        player.positions.add(const Duration(milliseconds: 200));
        await Future<void>.delayed(Duration.zero);
        player.positions.add(const Duration(milliseconds: 400));
        await Future<void>.delayed(Duration.zero);

        final after = container.read(audioPlayerSessionProvider);
        expect(
          identical(before, after),
          isTrue,
          reason:
              'o positionStream (~5 Hz) não pode mais trocar a identidade '
              'de AudioPlayerSessionState — só o provider de posição muda',
        );
        expect(
          container.read(audioPlayerPositionProvider).position,
          const Duration(milliseconds: 400),
        );
      },
    );

    test(
      'durationStream alimenta o provider de posição, não a sessão',
      () async {
        final container = await makeContainer();
        final notifier = container.read(audioPlayerSessionProvider.notifier);
        await notifier.playQueue([_track('a1')]);

        final before = container.read(audioPlayerSessionProvider);
        player.durations.add(const Duration(minutes: 3));
        await Future<void>.delayed(Duration.zero);

        expect(
          identical(before, container.read(audioPlayerSessionProvider)),
          isTrue,
        );
        expect(
          container.read(audioPlayerPositionProvider).duration,
          const Duration(minutes: 3),
        );
      },
    );

    test('nova fila zera o provider de posição', () async {
      final container = await makeContainer();
      final notifier = container.read(audioPlayerSessionProvider.notifier);
      await notifier.playQueue([_track('a1')]);

      player.positions.add(const Duration(seconds: 10));
      player.durations.add(const Duration(seconds: 200));
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(audioPlayerPositionProvider).position,
        const Duration(seconds: 10),
      );

      await notifier.playQueue([_track('a2')]);

      expect(
        container.read(audioPlayerPositionProvider).position,
        Duration.zero,
        reason: 'faixa nova não pode herdar a posição da faixa anterior',
      );
      expect(
        container.read(audioPlayerPositionProvider).duration,
        Duration.zero,
      );
    });

    test('stop() zera o provider de posição', () async {
      final container = await makeContainer();
      final notifier = container.read(audioPlayerSessionProvider.notifier);
      await notifier.playQueue([_track('a1')]);

      player.positions.add(const Duration(seconds: 42));
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(audioPlayerPositionProvider).position,
        const Duration(seconds: 42),
      );

      await notifier.stop();

      expect(
        container.read(audioPlayerPositionProvider).position,
        Duration.zero,
      );
    });

    test('close() zera o provider de posição', () async {
      final container = await makeContainer();
      final notifier = container.read(audioPlayerSessionProvider.notifier);
      await notifier.playQueue([_track('a1')]);

      player.positions.add(const Duration(seconds: 7));
      await Future<void>.delayed(Duration.zero);

      await notifier.close();

      expect(
        container.read(audioPlayerPositionProvider).position,
        Duration.zero,
      );
    });

    test('skipToPrevious volta pro início quando já passou de 3s (lê o '
        'provider de posição, não mais o estado da sessão)', () async {
      final container = await makeContainer();
      final notifier = container.read(audioPlayerSessionProvider.notifier);
      await notifier.playQueue([_track('a1'), _track('a2')], startIndex: 1);

      player.positions.add(const Duration(seconds: 5));
      await Future<void>.delayed(Duration.zero);

      await notifier.skipToPrevious();

      expect(
        container.read(audioPlayerSessionProvider).errorMessage,
        isNull,
        reason: 'seek(zero) do duplo de player não estoura',
      );
    });
  });

  group('MediaSessionPositionThrottle', () {
    test('primeiro shouldSend() sempre manda', () {
      final throttle = MediaSessionPositionThrottle(now: () => DateTime(2026));
      expect(throttle.shouldSend(), isTrue);
    });

    test('dentro de 1s sem force não manda de novo', () {
      var now = DateTime(2026);
      final throttle = MediaSessionPositionThrottle(now: () => now);

      expect(throttle.shouldSend(), isTrue);
      now = now.add(const Duration(milliseconds: 500));
      expect(throttle.shouldSend(), isFalse);
    });

    test('depois de 1s manda de novo', () {
      var now = DateTime(2026);
      final throttle = MediaSessionPositionThrottle(now: () => now);

      expect(throttle.shouldSend(), isTrue);
      now = now.add(const Duration(seconds: 1));
      expect(throttle.shouldSend(), isTrue);
    });

    test('force ignora a janela de 1s', () {
      var now = DateTime(2026);
      final throttle = MediaSessionPositionThrottle(now: () => now);

      expect(throttle.shouldSend(), isTrue);
      now = now.add(const Duration(milliseconds: 100));
      expect(throttle.shouldSend(force: true), isTrue);
    });

    test('reset() faz o próximo shouldSend() mandar na hora', () {
      var now = DateTime(2026);
      final throttle = MediaSessionPositionThrottle(now: () => now);

      expect(throttle.shouldSend(), isTrue);
      now = now.add(const Duration(milliseconds: 100));
      throttle.reset();
      expect(throttle.shouldSend(), isTrue);
    });

    test('minInterval customizado (5s, reuso pra posição persistida)', () {
      var now = DateTime(2026);
      final throttle = MediaSessionPositionThrottle(
        now: () => now,
        minInterval: const Duration(seconds: 5),
      );

      expect(throttle.shouldSend(), isTrue);
      now = now.add(const Duration(seconds: 3));
      expect(throttle.shouldSend(), isFalse);
      now = now.add(const Duration(seconds: 3));
      expect(throttle.shouldSend(), isTrue);
    });
  });

  group('seekBy (C12)', () {
    test('clamp no início: não passa de zero', () async {
      final container = await makeContainer();
      final notifier = container.read(audioPlayerSessionProvider.notifier);
      await notifier.playQueue([_track('a1')]);
      player.durations.add(const Duration(minutes: 1));
      player.positions.add(const Duration(seconds: 10));
      await Future<void>.delayed(Duration.zero);

      await notifier.seekBy(const Duration(seconds: -15));

      expect(player.seekCalls.single, Duration.zero);
    });

    test('clamp no fim: não passa da duração', () async {
      final container = await makeContainer();
      final notifier = container.read(audioPlayerSessionProvider.notifier);
      await notifier.playQueue([_track('a1')]);
      player.durations.add(const Duration(minutes: 1));
      player.positions.add(const Duration(seconds: 55));
      await Future<void>.delayed(Duration.zero);

      await notifier.seekBy(const Duration(seconds: 10));

      expect(player.seekCalls.single, const Duration(minutes: 1));
    });

    test('sem duração conhecida, +10s não trava em zero', () async {
      final container = await makeContainer();
      final notifier = container.read(audioPlayerSessionProvider.notifier);
      await notifier.playQueue([_track('a1')]);
      player.positions.add(const Duration(seconds: 10));
      await Future<void>.delayed(Duration.zero);

      await notifier.seekBy(const Duration(seconds: 10));

      expect(player.seekCalls.single, const Duration(seconds: 20));
    });
  });

  group('setSpeed (C12)', () {
    test('sessão nasce com velocidade 1.0', () async {
      final container = await makeContainer();
      expect(container.read(audioPlayerSessionProvider).speed, 1.0);
    });

    test('atualiza o estado e chama o player', () async {
      final container = await makeContainer();
      final notifier = container.read(audioPlayerSessionProvider.notifier);
      await notifier.playQueue([_track('a1')]);

      await notifier.setSpeed(1.5);

      expect(container.read(audioPlayerSessionProvider).speed, 1.5);
      expect(player.setSpeedCalls, contains(1.5));
    });

    test('é reaplicada em _applyQueue — troca de faixa não reseta', () async {
      final container = await makeContainer();
      final notifier = container.read(audioPlayerSessionProvider.notifier);
      await notifier.playQueue([_track('a1')]);
      await notifier.setSpeed(1.25);
      player.setSpeedCalls.clear();

      await notifier.playQueue([_track('a2')]);

      expect(
        container.read(audioPlayerSessionProvider).speed,
        1.25,
        reason: 'a velocidade escolhida persiste entre faixas',
      );
      expect(
        player.setSpeedCalls,
        contains(1.25),
        reason: '_applyQueue reaplica a velocidade na fonte nova',
      );
    });
  });

  group('posição persistida (C12)', () {
    test(
      'restoreQueue com trackId igual passa a posição gravada ao player',
      () async {
        final container = await makeContainer();
        final prefs = container.read(sharedPreferencesProvider);
        await AudioPlaybackPositionStore(
          prefs,
        ).write('a1', const Duration(seconds: 30));

        final notifier = container.read(audioPlayerSessionProvider.notifier);
        await notifier.restoreQueue([
          _track('a1', duration: const Duration(minutes: 3)),
        ]);

        expect(player.initialPositions.single, const Duration(seconds: 30));
      },
    );

    test(
      'restoreQueue com trackId diferente ignora a posição gravada',
      () async {
        final container = await makeContainer();
        final prefs = container.read(sharedPreferencesProvider);
        await AudioPlaybackPositionStore(
          prefs,
        ).write('b1', const Duration(seconds: 30));

        final notifier = container.read(audioPlayerSessionProvider.notifier);
        await notifier.restoreQueue([
          _track('a1', duration: const Duration(minutes: 3)),
        ]);

        expect(player.initialPositions.single, isNull);
      },
    );

    test('posição a menos de 5s do fim não é restaurada', () async {
      final container = await makeContainer();
      final prefs = container.read(sharedPreferencesProvider);
      await AudioPlaybackPositionStore(
        prefs,
      ).write('a1', const Duration(minutes: 3) - const Duration(seconds: 3));

      final notifier = container.read(audioPlayerSessionProvider.notifier);
      await notifier.restoreQueue([
        _track('a1', duration: const Duration(minutes: 3)),
      ]);

      expect(player.initialPositions.single, isNull);
    });

    // C12 fix round 1: `AudioTrack.duration` nunca é populado em produção —
    // o gate de "perto do fim" precisa da duração gravada no próprio store,
    // não da faixa.
    test('usa a duração gravada no store quando a faixa não tem duration '
        '(caso real de produção)', () async {
      final container = await makeContainer();
      final prefs = container.read(sharedPreferencesProvider);
      await AudioPlaybackPositionStore(prefs).write(
        'a1',
        const Duration(minutes: 1),
        duration: const Duration(minutes: 3),
      );

      final notifier = container.read(audioPlayerSessionProvider.notifier);
      await notifier.restoreQueue([_track('a1')]);

      expect(player.initialPositions.single, const Duration(minutes: 1));
    });

    test('posição a menos de 5s da duração gravada no store não é restaurada '
        '(faixa sem duration)', () async {
      final container = await makeContainer();
      final prefs = container.read(sharedPreferencesProvider);
      await AudioPlaybackPositionStore(prefs).write(
        'a1',
        const Duration(minutes: 3) - const Duration(seconds: 2),
        duration: const Duration(minutes: 3),
      );

      final notifier = container.read(audioPlayerSessionProvider.notifier);
      await notifier.restoreQueue([_track('a1')]);

      expect(player.initialPositions.single, isNull);
    });

    test('playQueue (tocar da lista/busca) começa sempre do zero', () async {
      final container = await makeContainer();
      final prefs = container.read(sharedPreferencesProvider);
      await AudioPlaybackPositionStore(
        prefs,
      ).write('a1', const Duration(seconds: 30));

      final notifier = container.read(audioPlayerSessionProvider.notifier);
      await notifier.playQueue([
        _track('a1', duration: const Duration(minutes: 3)),
      ]);

      expect(player.initialPositions.single, isNull);
    });

    test('stop() grava a posição atual antes de zerar', () async {
      final container = await makeContainer();
      final prefs = container.read(sharedPreferencesProvider);
      final notifier = container.read(audioPlayerSessionProvider.notifier);
      await notifier.playQueue([_track('a1')]);

      player.positions.add(const Duration(seconds: 55));
      await Future<void>.delayed(Duration.zero);

      await notifier.stop();

      final store = AudioPlaybackPositionStore(prefs);
      expect(store.read()?.trackId, 'a1');
      expect(store.read()?.position, const Duration(seconds: 55));
    });

    test('stop() grava também a duração observada (C12 fix round 1)', () async {
      final container = await makeContainer();
      final prefs = container.read(sharedPreferencesProvider);
      final notifier = container.read(audioPlayerSessionProvider.notifier);
      await notifier.playQueue([_track('a1')]);

      player.durations.add(const Duration(minutes: 3));
      player.positions.add(const Duration(seconds: 55));
      await Future<void>.delayed(Duration.zero);

      await notifier.stop();

      final store = AudioPlaybackPositionStore(prefs);
      expect(store.read()?.duration, const Duration(minutes: 3));
    });

    test('duração da faixa anterior não é gravada sob o id da faixa nova '
        '(C12 fix round 2)', () async {
      final container = await makeContainer();
      final prefs = container.read(sharedPreferencesProvider);
      final notifier = container.read(audioPlayerSessionProvider.notifier);
      await notifier.playQueue([_track('a1'), _track('a2')]);

      // Duração de a1 conhecida.
      player.durations.add(const Duration(seconds: 200));
      await Future<void>.delayed(Duration.zero);

      // O player avança sozinho pra faixa seguinte (troca em fila, sem
      // passar por _applyQueue) — durationStream ainda não emitiu nada
      // pra a2.
      player.indexes.add(1);
      await Future<void>.delayed(Duration.zero);

      player.playerStates.add(PlayerState(true, ProcessingState.ready));
      await Future<void>.delayed(Duration.zero);
      player.positions.add(const Duration(seconds: 5));
      await Future<void>.delayed(Duration.zero);

      final store = AudioPlaybackPositionStore(prefs);
      final result = store.read();
      expect(result?.trackId, 'a2');
      expect(
        result?.duration,
        isNull,
        reason: 'a duração de a1 não pode ser atribuída a a2',
      );
    });

    test(
      'pausar grava a posição imediatamente (não espera a janela de 5s)',
      () async {
        final container = await makeContainer();
        final prefs = container.read(sharedPreferencesProvider);
        final notifier = container.read(audioPlayerSessionProvider.notifier);
        await notifier.playQueue([_track('a1')]);

        player.playing = true;
        player.positions.add(const Duration(seconds: 12));
        await Future<void>.delayed(Duration.zero);

        await notifier.playPause();

        final store = AudioPlaybackPositionStore(prefs);
        expect(store.read()?.trackId, 'a1');
        expect(store.read()?.position, const Duration(seconds: 12));
      },
    );

    test(
      'grava a primeira posição tocando, mas não de novo antes de 5s',
      () async {
        final container = await makeContainer();
        final prefs = container.read(sharedPreferencesProvider);
        final notifier = container.read(audioPlayerSessionProvider.notifier);
        await notifier.playQueue([_track('a1')]);

        player.playerStates.add(PlayerState(true, ProcessingState.ready));
        await Future<void>.delayed(Duration.zero);
        expect(container.read(audioPlayerSessionProvider).playing, isTrue);

        player.positions.add(const Duration(seconds: 1));
        await Future<void>.delayed(Duration.zero);

        final store = AudioPlaybackPositionStore(prefs);
        expect(store.read()?.position, const Duration(seconds: 1));

        player.positions.add(const Duration(seconds: 2));
        await Future<void>.delayed(Duration.zero);

        expect(
          store.read()?.position,
          const Duration(seconds: 1),
          reason: 'dentro da janela de 5s a próxima gravação espera',
        );
      },
    );

    test('sem faixa em foco, nada é gravado', () async {
      final container = await makeContainer();
      final prefs = container.read(sharedPreferencesProvider);
      final notifier = container.read(audioPlayerSessionProvider.notifier);

      await notifier.stop();

      expect(AudioPlaybackPositionStore(prefs).read(), isNull);
    });
  });
}

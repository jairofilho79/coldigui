import 'dart:async';

import 'package:coldigui/core/network/device_connectivity.dart';
import 'package:coldigui/core/providers/device_connectivity_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/offline/data/providers/offline_audio_providers.dart';
import 'package:coldigui/features/offline/domain/entities/local_audio_source.dart';
import 'package:coldigui/features/offline/domain/repositories/offline_audio_repository.dart';
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

  /// Sobrescreve o getter do `AudioPlayer` real: no just_audio de verdade,
  /// `currentIndex` é o valor síncrono do mesmo subject que alimenta
  /// `currentIndexStream` — já reflete a troca antes do listener do stream
  /// rodar (C12 fix round 3). O teste ajusta direto, junto com `indexes.add`,
  /// pra simular essa ordem.
  @override
  int? currentIndex;

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

class _Connectivity implements DeviceConnectivity {
  _Connectivity(this.online);
  final bool online;
  @override
  Future<bool> hasConnection() async => online;
}

/// Só `lookup` importa aqui; o resto do contrato não é chamado.
class _LookupRepo implements OfflineAudioRepository {
  _LookupRepo(this.local);
  final Map<String, String> local;

  @override
  Future<LocalAudioSource?> lookup(String audioId) async {
    final key = local[audioId];
    return key == null
        ? null
        : LocalAudioSource(audioId: audioId, storageKey: key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _ControllablePlayer player;

  Future<ProviderContainer> makeContainer({
    required Map<String, String> local,
    required bool online,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        audioSessionPlayerFactoryProvider.overrideWithValue(() => player),
        offlineAudioRepositoryProvider.overrideWithValue(_LookupRepo(local)),
        deviceConnectivityProvider.overrideWithValue(_Connectivity(online)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    player = _ControllablePlayer();
  });

  Uri uriOf(AudioSource source) => (source as UriAudioSource).uri;

  test('faixa baixada toca por Uri.file; miss toca da rede', () async {
    final container = await makeContainer(
      local: {'a1': '/docs/plpcg_audio/assets/praises/p1/a1.mp3'},
      online: true,
    );

    await container.read(audioPlayerSessionProvider.notifier).playQueue([
      _track('a1'),
      _track('a2'),
    ]);

    final sources = player.setSourcesCalls.single;
    expect(
      uriOf(sources[0]),
      Uri.file('/docs/plpcg_audio/assets/praises/p1/a1.mp3'),
    );
    expect(uriOf(sources[1]).scheme, 'https');
    expect(container.read(audioPlayerSessionProvider).notDownloaded, isFalse);
  });

  test(
    'miss sem rede → erro «não baixado», nada é aplicado ao player',
    () async {
      final container = await makeContainer(local: const {}, online: false);

      await container.read(audioPlayerSessionProvider.notifier).playQueue([
        _track('a1'),
      ]);

      final state = container.read(audioPlayerSessionProvider);
      expect(state.notDownloaded, isTrue);
      expect(state.errorMessage, isNotNull);
      expect(player.setSourcesCalls, isEmpty);
    },
  );

  test(
    'miss sem rede mas com outra faixa local: só a ausente falha a fila',
    () async {
      final container = await makeContainer(
        local: {'a1': '/x/a1.mp3'},
        online: false,
      );

      await container.read(audioPlayerSessionProvider.notifier).playQueue([
        _track('a1'),
      ]);

      expect(container.read(audioPlayerSessionProvider).notDownloaded, isFalse);
      expect(
        uriOf(player.setSourcesCalls.single.single),
        Uri.file('/x/a1.mp3'),
      );
    },
  );
}

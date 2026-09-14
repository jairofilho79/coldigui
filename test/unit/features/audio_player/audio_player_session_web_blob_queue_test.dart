import 'dart:typed_data';

import 'package:coldigui/core/platform/platform_capabilities.dart';
import 'package:coldigui/core/platform/platform_capabilities_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/audio_player/data/audio_player_web_providers.dart';
import 'package:coldigui/features/audio_player/data/web_audio_source_resolver.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/offline/data/providers/offline_audio_providers.dart';
import 'package:coldigui/features/offline/domain/entities/local_audio_source.dart';
import 'package:coldigui/features/offline/domain/ports/audio_storage_port.dart';
import 'package:coldigui/features/offline/domain/repositories/offline_audio_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Duplo do player: só `setAudioSources` importa aqui (captura as fontes
/// aplicadas). Cópia mínima do duplo de
/// `audio_player_session_robustness_test.dart` — o resto do contrato do
/// `AudioPlayer` não é chamado neste teste.
class _ControllablePlayer extends AudioPlayer {
  final setSourcesCalls = <List<AudioSource>>[];

  @override
  bool playing = false;

  @override
  int? currentIndex;

  @override
  Future<Duration?> setAudioSources(
    List<AudioSource> audioSources, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
    ShuffleOrder? shuffleOrder,
  }) async {
    setSourcesCalls.add(audioSources);
    return null;
  }

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> seek(Duration? position, {int? index}) async {}

  @override
  Future<void> setSpeed(double speed) async {}

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

/// Repositório com 3 faixas sempre no aparelho — a chave de storage é
/// distinta por faixa (é ela que vira a chave do blob).
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

/// Bytes fixos por chave de storage — dispensa Cache API de verdade.
class _FakeAudioStoragePort implements AudioStoragePort {
  _FakeAudioStoragePort(this.bytesByKey);
  final Map<String, Uint8List> bytesByKey;

  @override
  Future<Uint8List?> readBytes(String storageKey) async =>
      bytesByKey[storageKey];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Fake de [WebAudioSourceResolver] (fix round 1) — sem `dart:js_interop`
/// disponível em `flutter test` puro (VM), a classe real não compila fora
/// do alvo web, então este fake implementa a mesma forma pública e regista
/// a ordem das chamadas: é isso que prova o contrato do fix (um `beginQueue`
/// só, antes de qualquer `resolveFromBytes`, sem revogar nada no meio da
/// fila) sem depender da Blob API do navegador.
class _FakeWebResolver implements WebAudioSourceResolver {
  final events = <String>[];

  @override
  FetchAudioBytesFn? get fetchBytes => null;

  @override
  void beginQueue() {
    events.add('beginQueue');
  }

  @override
  Uri? resolveFromBytes(String cacheKey, Uint8List bytes) {
    events.add('resolve:$cacheKey');
    return Uri.parse('blob:fake-store/$cacheKey');
  }

  @override
  Future<Uri> resolveForPlayback(
    String fetchUrl, {
    String? cacheKey,
    String? streamFallbackUrl,
  }) {
    throw UnimplementedError('não usado no fluxo local-first (O7)');
  }

  @override
  void revokeAll() {
    events.add('revokeAll');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _ControllablePlayer player;
  late _FakeWebResolver resolver;

  Future<ProviderContainer> makeContainer({
    required Map<String, String> local,
    required Map<String, Uint8List> bytesByKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        audioSessionPlayerFactoryProvider.overrideWithValue(() => player),
        platformCapabilitiesProvider.overrideWithValue(
          PlatformCapabilities.web,
        ),
        webAudioSourceResolverProvider.overrideWithValue(resolver),
        offlineAudioRepositoryProvider.overrideWithValue(_LookupRepo(local)),
        audioStoragePortProvider.overrideWithValue(
          _FakeAudioStoragePort(bytesByKey),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    player = _ControllablePlayer();
    resolver = _FakeWebResolver();
  });

  Uri uriOf(AudioSource source) => (source as UriAudioSource).uri;

  test('fila com 3 faixas baixadas: 1 beginQueue, 3 blobs distintos, nada revogado no meio', () async {
    final local = {
      'a1': 'assets/praises/p1/a1.mp3',
      'a2': 'assets/praises/p1/a2.mp3',
      'a3': 'assets/praises/p1/a3.mp3',
    };
    final bytesByKey = {
      for (final key in local.values) key: Uint8List.fromList([1, 2, 3]),
    };
    final container = await makeContainer(local: local, bytesByKey: bytesByKey);

    await container.read(audioPlayerSessionProvider.notifier).playQueue([
      _track('a1'),
      _track('a2'),
      _track('a3'),
    ]);

    // Só 1 `beginQueue` (a fila é resolvida uma vez); nenhum `revokeAll`
    // isolado no meio da resolução das 3 faixas — a CRÍTICA do round 1
    // era exatamente um trim por faixa derrubando o blob da faixa que
    // ia tocar antes de `setAudioSources`.
    expect(resolver.events.where((e) => e == 'beginQueue').length, 1);
    expect(resolver.events.first, 'beginQueue');
    // Nenhum `revokeAll` isolado — a única revogação é a do `beginQueue`
    // (que a implementação real do resolver compõe como `revokeAll()`),
    // nunca uma no meio da resolução das 3 faixas.
    expect(resolver.events.where((e) => e == 'revokeAll').length, 0);

    final resolveEvents = resolver.events
        .where((e) => e.startsWith('resolve:'))
        .toList();
    expect(resolveEvents, [
      'resolve:assets/praises/p1/a1.mp3',
      'resolve:assets/praises/p1/a2.mp3',
      'resolve:assets/praises/p1/a3.mp3',
    ]);

    final sources = player.setSourcesCalls.single;
    final uris = sources.map(uriOf).map((u) => u.toString()).toList();
    expect(uris.toSet().length, 3, reason: 'as 3 URIs devem ser distintas');
    expect(uris, [
      'blob:fake-store/assets/praises/p1/a1.mp3',
      'blob:fake-store/assets/praises/p1/a2.mp3',
      'blob:fake-store/assets/praises/p1/a3.mp3',
    ]);
  });
}

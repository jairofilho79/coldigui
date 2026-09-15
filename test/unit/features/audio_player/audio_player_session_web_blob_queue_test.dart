import 'dart:async';
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

/// Web sem exigência de gesto (fix round 2) — o teste de A→B→C não é sobre
/// o desbloqueio de iOS Safari (já coberto no fix round 1); usar
/// [PlatformCapabilities.web] de verdade dispararia
/// `unlockWebAudioIfNeeded` e resolveria a faixa inicial num caminho à
/// parte, complicando a orquestração do lookup controlável sem acrescentar
/// cobertura nova.
const _testWebCapabilities = PlatformCapabilities(
  isWeb: true,
  supportsBackgroundAudio: true,
  needsUserGestureForAudio: false,
  supportsFileSave: false,
  supportsFullscreenApi: true,
);

/// Lookup híbrido (fix round 2): [immediate] resolve na hora (como
/// [_LookupRepo]); os `audioId` em [controlled] ficam presos num
/// `Completer` até o teste completar manualmente — é assim que se segura
/// uma `_applyQueue` no meio da fila, pra outra geração pré-emptá-la.
class _HybridLookupRepo implements OfflineAudioRepository {
  _HybridLookupRepo({required this.immediate, required this.controlled});

  final Map<String, String> immediate;
  final Set<String> controlled;
  final pendingLookups = <String, Completer<LocalAudioSource?>>{};

  @override
  Future<LocalAudioSource?> lookup(String audioId) {
    if (controlled.contains(audioId)) {
      final completer = Completer<LocalAudioSource?>();
      pendingLookups[audioId] = completer;
      return completer.future;
    }
    final key = immediate[audioId];
    return Future.value(
      key == null ? null : LocalAudioSource(audioId: audioId, storageKey: key),
    );
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

/// Fake de [WebAudioSourceResolver] (fix rounds 1 e 2) — sem
/// `dart:js_interop` disponível em `flutter test` puro (VM), a classe real
/// não compila fora do alvo web, então este fake implementa a mesma forma
/// pública e reproduz o contrato de duas fases: [resolveFromBytes] escreve
/// em [pending] (nunca em [current] direto); [beginQueue] limpa só
/// [pending]; [commitQueue] promove [pending] → [current], revogando o que
/// estava lá. [events]/[beginRevokes]/[commitRevokes]/[commitPromotes]
/// registram cada chamada — é isso que prova o contrato sem depender da
/// Blob API do navegador.
class _FakeWebResolver implements WebAudioSourceResolver {
  final events = <String>[];
  final pending = <String, String>{};
  final current = <String, String>{};

  /// URIs que estavam em [pending] no momento de cada `beginQueue`.
  final beginRevokes = <List<String>>[];

  /// URIs que estavam em [current] no momento de cada `commitQueue`.
  final commitRevokes = <List<String>>[];

  /// URIs promovidas ([pending] no momento) por cada `commitQueue`.
  final commitPromotes = <List<String>>[];

  @override
  void beginQueue() {
    events.add('beginQueue');
    beginRevokes.add(List.of(pending.values));
    pending.clear();
  }

  @override
  Uri? resolveFromBytes(String cacheKey, Uint8List bytes) {
    events.add('resolve:$cacheKey');
    final cached = pending[cacheKey];
    if (cached != null) return Uri.parse(cached);
    final url = 'blob:fake-store/$cacheKey';
    pending[cacheKey] = url;
    return Uri.parse(url);
  }

  /// Mesma semântica de [resolveFromBytes] — a sessão real usa
  /// `resolveFromCache` no lugar de `readBytes` + `resolveFromBytes`
  /// (achado do review final), mas os testes deste arquivo não modelam
  /// miss de cache: reaproveita a mesma escrita em [pending].
  @override
  Future<Uri?> resolveFromCache(String storageKey) async =>
      resolveFromBytes(storageKey, Uint8List(0));

  @override
  void commitQueue() {
    events.add('commitQueue');
    commitRevokes.add(List.of(current.values));
    commitPromotes.add(List.of(pending.values));
    current
      ..clear()
      ..addAll(pending);
    pending.clear();
  }

  @override
  void revokeAll() {
    events.add('revokeAll');
    current.clear();
    pending.clear();
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

  test('A tocando → B pré-emptida por C: blobs de A só revogam no commit de C; '
      'pending de B nunca vira current', () async {
    final repo = _HybridLookupRepo(
      immediate: {'a1': 'a1.mp3', 'b1': 'b1.mp3', 'c1': 'c1.mp3'},
      controlled: {'b2'},
    );
    final storage = _FakeAudioStoragePort({
      for (final key in ['a1.mp3', 'b1.mp3', 'b2.mp3', 'c1.mp3'])
        key: Uint8List.fromList([1, 2, 3]),
    });
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        audioSessionPlayerFactoryProvider.overrideWithValue(() => player),
        platformCapabilitiesProvider.overrideWithValue(_testWebCapabilities),
        webAudioSourceResolverProvider.overrideWithValue(resolver),
        offlineAudioRepositoryProvider.overrideWithValue(repo),
        audioStoragePortProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(audioPlayerSessionProvider.notifier);

    Future<void> pumpUntil(bool Function() condition) async {
      for (var i = 0; i < 20 && !condition(); i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    // A: 1 faixa local, resolve e comita de vez — é o que está "tocando".
    await notifier.playQueue([_track('a1')]);
    final aUri = uriOf(player.setSourcesCalls.single.single).toString();
    expect(resolver.current.values, [aUri]);
    expect(resolver.pending, isEmpty);

    // B: 2 faixas — b1 resolve na hora (escreve em pending); b2 fica presa
    // no lookup controlado. B nunca chega perto do commit.
    final bFuture = notifier.playQueue([_track('b1'), _track('b2')]);
    await pumpUntil(() => repo.pendingLookups.containsKey('b2'));
    expect(
      repo.pendingLookups.containsKey('b2'),
      isTrue,
      reason: 'b2 deveria estar suspensa no lookup controlado',
    );
    expect(resolver.pending.keys, ['b1.mp3']);
    final bPendingUri = resolver.pending['b1.mp3'];

    // C: 1 faixa local, resolve e comita sem nunca esperar por B — supera
    // a geração de B antes que ela chegue perto de aplicar qualquer coisa.
    await notifier.playQueue([_track('c1')]);
    final cUri = uriOf(player.setSourcesCalls.last.single).toString();

    // O blob de A só é revogado agora — no commit de C, não antes (não no
    // beginQueue de B, nem no beginQueue de C).
    expect(resolver.commitRevokes.last, [aUri]);
    // O pending de b1 foi varrido pelo beginQueue de C — nunca promovido.
    expect(resolver.beginRevokes.last, [bPendingUri]);
    expect(resolver.commitPromotes.last, [cUri]);
    expect(resolver.current.values, [cUri]);
    expect(resolver.current.values, isNot(contains(bPendingUri)));
    expect(resolver.pending, isEmpty);

    // Libera o lookup de b2 (higiene do teste) — a geração de B já não é
    // mais a vigente, então o próximo `gen != _generation` descarta antes
    // de tocar em qualquer coisa (sem `setAudioSources` novo, sem commit).
    repo.pendingLookups['b2']!.complete(null);
    await bFuture;
    expect(player.setSourcesCalls.length, 2, reason: 'só A e C aplicaram');
    expect(resolver.current.values, [cUri]);
  });
}

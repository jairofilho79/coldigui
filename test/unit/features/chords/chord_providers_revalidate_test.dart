import 'package:coldigui/core/network/device_connectivity.dart';
import 'package:coldigui/core/providers/device_connectivity_provider.dart';
import 'package:coldigui/features/chords/data/datasources/chord_content_datasource.dart';
import 'package:coldigui/features/chords/data/datasources/chord_content_local_datasource.dart';
import 'package:coldigui/features/chords/data/providers/chord_providers.dart';
import 'package:coldigui/features/chords/domain/entities/chordpro_song.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cache em memória: `read` responde do mapa, `write` registra a ordem.
class _FakeLocal extends ChordContentLocalDatasource {
  _FakeLocal(this._entries) : super(null);

  final Map<String, ChordCacheEntry> _entries;
  final List<String> writes = [];

  @override
  ChordCacheEntry? read(String r2Key) => _entries[r2Key.trim()];

  @override
  void write(String r2Key, String content) {
    writes.add(content);
    _entries[r2Key.trim()] = ChordCacheEntry(
      content: content,
      fetchedAt: DateTime.now(),
    );
  }
}

/// Datasource com resposta roteirizada.
///
/// O [Dio] só existe para satisfazer o construtor — nenhuma request sai, porque
/// `fetchContent` está sobrescrito.
class _FakeRemote extends ChordContentDatasource {
  _FakeRemote(this._behavior) : super(Dio(), apiBase: '');

  final Future<String?> Function(String r2Key) _behavior;
  var calls = 0;

  @override
  Future<String?> fetchContent(String r2Key) {
    calls++;
    return _behavior(r2Key);
  }
}

class _FakeConnectivity implements DeviceConnectivity {
  _FakeConnectivity({required this.online});

  final bool online;

  @override
  Future<bool> hasConnection() async => online;
}

void main() {
  const key = 'coldigom/cifras/001.chord';
  const cifra = '{title: Louvor}\nLetra da cifra';

  ChordCacheEntry stale(String content) => ChordCacheEntry(
    content: content,
    fetchedAt: DateTime.now().subtract(kChordCacheTtl * 2),
  );

  ProviderContainer buildContainer({
    required _FakeLocal local,
    required _FakeRemote remote,
    bool online = true,
  }) {
    final container = ProviderContainer(
      overrides: [
        chordContentLocalDatasourceProvider.overrideWithValue(local),
        chordContentDatasourceProvider.overrideWithValue(remote),
        deviceConnectivityProvider.overrideWithValue(
          _FakeConnectivity(online: online),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('cifra 404 na revalidação grava marcador negativo e invalida', () async {
    final local = _FakeLocal({key: stale(cifra)});
    // `null` é conclusivo pelo contrato do datasource: a cifra sumiu do
    // servidor (404), não é falha de rede.
    final remote = _FakeRemote((_) async => null);
    final container = buildContainer(local: local, remote: remote);

    final sub = container.listen(
      chordSongProvider(key),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);

    final first = await container.read(chordSongProvider(key).future);
    expect(first, isA<ChordProSong>(), reason: 'o cache responde na hora');

    await pumpEventQueue();

    expect(local.writes, [
      '',
    ], reason: 'marcador negativo grava conteúdo vazio');
    expect(remote.calls, 1);
    expect(
      await container.read(chordSongProvider(key).future),
      isNull,
      reason: 'invalidateSelf faz o sheet aberto refletir a remoção',
    );
  });

  test(
    'marcador negativo já gravado só renova o fetchedAt na revalidação',
    () async {
      final local = _FakeLocal({key: stale('')});
      final remote = _FakeRemote((_) async => null);
      final container = buildContainer(local: local, remote: remote);

      final sub = container.listen(chordSongProvider(key), (_, _) {});
      addTearDown(sub.close);

      expect(await container.read(chordSongProvider(key).future), isNull);
      await pumpEventQueue();

      expect(local.writes, ['']);
      // Sem `fetchedAt` renovado, a próxima abertura passada a TTL repetiria
      // o mesmo GET condenado.
      expect(local.read(key)!.isStaleAt(DateTime.now()), isFalse);
      expect(remote.calls, 1);
    },
  );

  test('cifra inalterada na revalidação não escreve nem invalida', () async {
    final local = _FakeLocal({key: stale(cifra)});
    final remote = _FakeRemote((_) async => cifra);
    final container = buildContainer(local: local, remote: remote);

    final sub = container.listen(chordSongProvider(key), (_, _) {});
    addTearDown(sub.close);

    await container.read(chordSongProvider(key).future);
    await pumpEventQueue();

    expect(local.writes, isEmpty);
    expect(remote.calls, 1);
  });

  test('cifra alterada na revalidação troca o cache', () async {
    const nova = '{title: Louvor}\nLetra nova';
    final local = _FakeLocal({key: stale(cifra)});
    final remote = _FakeRemote((_) async => nova);
    final container = buildContainer(local: local, remote: remote);

    final sub = container.listen(chordSongProvider(key), (_, _) {});
    addTearDown(sub.close);

    await container.read(chordSongProvider(key).future);
    await pumpEventQueue();

    expect(local.writes, [nova]);
  });

  test('revalidação offline não chega a perguntar ao servidor', () async {
    final local = _FakeLocal({key: stale(cifra)});
    final remote = _FakeRemote((_) async => null);
    final container = buildContainer(
      local: local,
      remote: remote,
      online: false,
    );

    final sub = container.listen(chordSongProvider(key), (_, _) {});
    addTearDown(sub.close);

    await container.read(chordSongProvider(key).future);
    await pumpEventQueue();

    expect(remote.calls, 0);
    expect(local.writes, isEmpty);
  });

  test('falha transitória na revalidação preserva o cache', () async {
    final local = _FakeLocal({key: stale(cifra)});
    final remote = _FakeRemote(
      (r2Key) async =>
          throw ChordFetchFailedException(r2Key, StateError('sem rede')),
    );
    final container = buildContainer(local: local, remote: remote);

    final sub = container.listen(chordSongProvider(key), (_, _) {});
    addTearDown(sub.close);

    await container.read(chordSongProvider(key).future);
    await pumpEventQueue();

    expect(
      local.writes,
      isEmpty,
      reason: 'exceção não pode virar marcador negativo',
    );
  });
}

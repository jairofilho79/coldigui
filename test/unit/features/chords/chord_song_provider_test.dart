import 'package:coldigui/core/network/device_connectivity.dart';
import 'package:coldigui/core/providers/device_connectivity_provider.dart';
import 'package:coldigui/features/chords/data/datasources/chord_content_datasource.dart';
import 'package:coldigui/features/chords/data/datasources/chord_content_local_datasource.dart';
import 'package:coldigui/features/chords/data/providers/chord_providers.dart';
import 'package:coldigui/features/chords/domain/entities/chordpro_song.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _key = 'assets/praises/p1/m1.chord';
const _content = '{title: Comigo}\n\nA [Bb]noite vem,\n';
const _outroContent = '{title: Comigo}\n\nA [C]noite vem de novo,\n';

/// Datasource remoto de mentira: responde da tabela ou lança o erro pedido.
class _FakeRemote implements ChordContentDatasource {
  _FakeRemote({this.body, this.failure});

  String? body;
  Object? failure;
  int calls = 0;

  @override
  Future<String?> fetchContent(String r2Key) async {
    calls++;
    final failure = this.failure;
    if (failure != null) throw failure;
    return body;
  }

  @override
  Future<ChordProSong?> fetchSong(String r2Key) async {
    final content = await fetchContent(r2Key);
    return content == null ? null : parseChordSongOrNull(content);
  }
}

/// Cache em memória com a mesma superfície do datasource Isar.
class _FakeLocal implements ChordContentLocalDatasource {
  final rows = <String, ChordCacheEntry>{};
  int writes = 0;

  /// Semeia uma entrada como se tivesse sido buscada [idade] atrás.
  void seed(String r2Key, String content, {Duration idade = Duration.zero}) {
    rows[r2Key] = ChordCacheEntry(
      content: content,
      fetchedAt: DateTime.now().subtract(idade),
    );
  }

  @override
  ChordCacheEntry? read(String r2Key) => rows[r2Key];

  @override
  void write(String r2Key, String content) {
    writes++;
    rows[r2Key] = ChordCacheEntry(content: content, fetchedAt: DateTime.now());
  }
}

class _FakeConnectivity implements DeviceConnectivity {
  _FakeConnectivity(this.online);

  bool online;

  @override
  Future<bool> hasConnection() async => online;
}

ProviderContainer _container({
  required _FakeRemote remote,
  required _FakeLocal local,
  bool online = true,
}) {
  final container = ProviderContainer(
    overrides: [
      chordContentDatasourceProvider.overrideWithValue(remote),
      chordContentLocalDatasourceProvider.overrideWithValue(local),
      deviceConnectivityProvider.overrideWithValue(_FakeConnectivity(online)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Lê o provider segurando uma inscrição, como faz um widget, e a solta no fim.
///
/// O `pump()` no fim deixa o Riverpod rodar o descarte agendado (`Timer` de
/// duração zero): é ele que decide se o elemento sobreviveu (sucesso, com
/// `keepAlive`) ou morreu (erro, sem).
Future<AsyncValue<ChordProSong?>> _readWhileWatched(
  ProviderContainer container,
  String key,
) async {
  final sub = container.listen(chordSongProvider(key), (_, _) {});
  final AsyncValue<ChordProSong?> resultado;
  try {
    await container
        .read(chordSongProvider(key).future)
        .then<void>((_) {}, onError: (Object _) {});
    resultado = container.read(chordSongProvider(key));
  } finally {
    sub.close();
  }
  await container.pump();
  return resultado;
}

void main() {
  test('sucesso remoto grava no cache persistente', () async {
    final remote = _FakeRemote(body: _content);
    final local = _FakeLocal();
    final container = _container(remote: remote, local: local, online: false);

    final song = await container.read(chordSongProvider(_key).future);

    expect(song, isNotNull);
    expect(song!.title, 'Comigo');
    expect(local.rows[_key]?.content, _content);
  });

  test('cache local responde sem ir a rede (offline)', () async {
    final remote = _FakeRemote(failure: StateError('rede fora'));
    final local = _FakeLocal()..seed(_key, _content);
    final container = _container(remote: remote, local: local, online: false);

    final song = await container.read(chordSongProvider(_key).future);

    expect(song, isNotNull);
    expect(song!.title, 'Comigo');
    expect(remote.calls, 0);
  });

  test('erro sem cache vira AsyncError (nao "cifra inexistente")', () async {
    final remote = _FakeRemote(
      failure: const ChordFetchFailedException(_key, 'boom'),
    );
    final container = _container(remote: remote, local: _FakeLocal());

    await expectLater(
      container.read(chordSongProvider(_key).future),
      throwsA(isA<ChordFetchFailedException>()),
    );
    expect(
      container.read(chordSongProvider(_key)),
      isA<AsyncError<ChordProSong?>>(),
    );
  });

  test('erro nao e mantido vivo — nova leitura vai a rede de novo', () async {
    final remote = _FakeRemote(
      failure: const ChordFetchFailedException(_key, 'boom'),
    );
    final local = _FakeLocal();
    final container = _container(remote: remote, local: local, online: false);

    final primeira = await _readWhileWatched(container, _key);
    expect(primeira, isA<AsyncError<ChordProSong?>>());
    expect(remote.calls, 1);

    // Sem `invalidate`: soltar a inscrição basta, porque o elemento em erro
    // não sobrevive ao autoDispose.
    remote
      ..failure = null
      ..body = _content;

    final segunda = await _readWhileWatched(container, _key);

    expect(remote.calls, 2);
    expect(segunda.value?.title, 'Comigo');
    expect(local.rows[_key]?.content, _content);
  });

  test('sucesso fica quente: segunda leitura nao repete a rede', () async {
    final remote = _FakeRemote(body: _content);
    final local = _FakeLocal();
    final container = _container(remote: remote, local: local, online: false);

    await _readWhileWatched(container, _key);
    expect(remote.calls, 1);

    final segunda = await _readWhileWatched(container, _key);

    expect(remote.calls, 1, reason: 'keepAlive no sucesso mantém o elemento');
    expect(segunda.value?.title, 'Comigo');
  });

  test('404 vira null e grava marcador negativo', () async {
    final remote = _FakeRemote(body: null);
    final local = _FakeLocal();
    final container = _container(remote: remote, local: local, online: false);

    expect(await _readWhileWatched(container, _key), isA<AsyncData<dynamic>>());
    expect(await container.read(chordSongProvider(_key).future), isNull);
    expect(local.rows[_key]?.content, '');
  });

  test('marcador negativo responde sem rede na leitura seguinte', () async {
    final remote = _FakeRemote(body: null);
    final local = _FakeLocal()..seed(_key, '');
    final container = _container(remote: remote, local: local, online: false);

    expect(await container.read(chordSongProvider(_key).future), isNull);
    expect(remote.calls, 0);
  });

  test('cache velho revalida em background quando online', () async {
    final remote = _FakeRemote(body: _outroContent);
    final local = _FakeLocal()..seed(_key, _content, idade: kChordCacheTtl * 2);
    final container = _container(remote: remote, local: local, online: true);

    final first = await container.read(chordSongProvider(_key).future);
    expect(first, isNotNull);

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(remote.calls, greaterThan(0));
    expect(local.rows[_key]?.content, _outroContent);
  });

  test('cache dentro do TTL nao dispara GET', () async {
    final remote = _FakeRemote(body: _outroContent);
    final local = _FakeLocal()..seed(_key, _content);
    final container = _container(remote: remote, local: local, online: true);

    await container.read(chordSongProvider(_key).future);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(remote.calls, 0);
    expect(local.rows[_key]?.content, _content);
  });

  test('offline com cache velho nao revalida', () async {
    final remote = _FakeRemote(body: _outroContent);
    final local = _FakeLocal()..seed(_key, _content, idade: kChordCacheTtl * 2);
    final container = _container(remote: remote, local: local, online: false);

    await container.read(chordSongProvider(_key).future);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(remote.calls, 0);
    expect(local.rows[_key]?.content, _content);
  });

  test('r2Key vazio devolve null sem tocar em cache ou rede', () async {
    final remote = _FakeRemote(body: _content);
    final local = _FakeLocal();
    final container = _container(remote: remote, local: local);

    expect(await container.read(chordSongProvider('').future), isNull);
    expect(remote.calls, 0);
    expect(local.writes, 0);
  });
}

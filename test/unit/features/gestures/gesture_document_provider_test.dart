import 'package:coldigui/core/network/device_connectivity.dart';
import 'package:coldigui/core/providers/device_connectivity_provider.dart';
import 'package:coldigui/features/gestures/data/datasources/gesture_content_datasource.dart';
import 'package:coldigui/features/gestures/data/datasources/gesture_content_local_datasource.dart';
import 'package:coldigui/features/gestures/data/providers/gesture_providers.dart';
import 'package:coldigui/features/gestures/domain/entities/gesture_document.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _key = 'assets/praises/p1/m1.gestures';
const _content =
    '{"schema":"coldigom.gestures/1","title":"A","items":[{"type":"text","text":"x"}]}';
const _outro =
    '{"schema":"coldigom.gestures/1","title":"B","items":[{"type":"text","text":"y"}]}';

class _FakeRemote implements GestureContentDatasource {
  _FakeRemote({this.body, this.failure});

  String? body;
  Object? failure;
  int calls = 0;

  @override
  Future<String?> fetchContent(String r2Key) async {
    calls++;
    if (failure != null) throw failure!;
    return body;
  }
}

class _FakeLocal implements GestureContentLocalDatasource {
  final rows = <String, GestureCacheEntry>{};
  int writes = 0;

  void seed(String r2Key, String content, {Duration idade = Duration.zero}) {
    rows[r2Key] = GestureCacheEntry(
      content: content,
      fetchedAt: DateTime.now().subtract(idade),
    );
  }

  @override
  GestureCacheEntry? read(String r2Key) => rows[r2Key];

  @override
  void write(String r2Key, String content) {
    writes++;
    rows[r2Key] = GestureCacheEntry(
      content: content,
      fetchedAt: DateTime.now(),
    );
  }

  @override
  List<String> allKeysWithContent() => [
    for (final entry in rows.entries)
      if (entry.value.content.isNotEmpty) entry.key,
  ];
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
      gestureContentDatasourceProvider.overrideWithValue(remote),
      gestureContentLocalDatasourceProvider.overrideWithValue(local),
      deviceConnectivityProvider.overrideWithValue(_FakeConnectivity(online)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Lê segurando uma inscrição (como um widget) e solta no fim; o `pump()`
/// deixa o Riverpod decidir se o elemento sobreviveu (`keepAlive`) ou não.
Future<AsyncValue<GestureDocument?>> _readWhileWatched(
  ProviderContainer c,
  String key,
) async {
  final sub = c.listen(gestureDocumentProvider(key), (_, _) {});
  final AsyncValue<GestureDocument?> result;
  try {
    await c
        .read(gestureDocumentProvider(key).future)
        .then<void>((_) {}, onError: (Object _) {});
    result = c.read(gestureDocumentProvider(key));
  } finally {
    sub.close();
  }
  await c.pump();
  return result;
}

void main() {
  test('sucesso remoto grava no cache e parseia', () async {
    final remote = _FakeRemote(body: _content);
    final local = _FakeLocal();
    final result = await _readWhileWatched(
      _container(remote: remote, local: local),
      _key,
    );

    expect(result.value?.title, 'A');
    expect(local.rows[_key]?.content, _content);
  });

  test('404 grava marcador negativo e devolve null', () async {
    final local = _FakeLocal();
    final result = await _readWhileWatched(
      _container(remote: _FakeRemote(body: null), local: local),
      _key,
    );
    expect(result.value, isNull);
    expect(local.rows[_key]?.content, '');
  });

  test('cache fresco responde sem ir à rede', () async {
    final remote = _FakeRemote(body: _outro);
    final local = _FakeLocal()..seed(_key, _content);
    final result = await _readWhileWatched(
      _container(remote: remote, local: local),
      _key,
    );
    expect(result.value?.title, 'A');
    expect(remote.calls, 0);
  });

  test('marcador negativo em cache devolve null sem rede', () async {
    final remote = _FakeRemote(body: _content);
    final local = _FakeLocal()..seed(_key, '');
    final result = await _readWhileWatched(
      _container(remote: remote, local: local),
      _key,
    );
    expect(result.value, isNull);
    expect(remote.calls, 0);
  });

  test('cache stale + online revalida em background e troca o corpo', () async {
    final remote = _FakeRemote(body: _outro);
    final local = _FakeLocal()
      ..seed(_key, _content, idade: const Duration(hours: 25));
    final c = _container(remote: remote, local: local);

    final sub = c.listen(gestureDocumentProvider(_key), (_, _) {});
    addTearDown(sub.close);
    final first = await c.read(gestureDocumentProvider(_key).future);
    expect(first?.title, 'A');

    await Future<void>.delayed(Duration.zero);
    await c.pump();
    final second = await c.read(gestureDocumentProvider(_key).future);
    expect(second?.title, 'B');
    expect(local.rows[_key]?.content, _outro);
  });

  test('cache stale + offline não revalida', () async {
    final remote = _FakeRemote(body: _outro);
    final local = _FakeLocal()
      ..seed(_key, _content, idade: const Duration(hours: 25));
    await _readWhileWatched(
      _container(remote: remote, local: local, online: false),
      _key,
    );
    await Future<void>.delayed(Duration.zero);
    expect(remote.calls, 0);
  });

  test('falha de rede vira AsyncError que não gruda: próxima leitura tenta de novo', () async {
    final remote = _FakeRemote(
      failure: const GestureFetchFailedException(_key, 'rede'),
    );
    final local = _FakeLocal();
    final c = _container(remote: remote, local: local);

    final first = await _readWhileWatched(c, _key);
    expect(first.hasError, isTrue);
    expect(local.writes, 0);

    remote
      ..failure = null
      ..body = _content;
    final second = await _readWhileWatched(c, _key);
    expect(second.value?.title, 'A');
  });

  test('JSON inválido no cache é tratado como miss e busca na rede', () async {
    final remote = _FakeRemote(body: _content);
    final local = _FakeLocal()..seed(_key, '{nope');
    final result = await _readWhileWatched(
      _container(remote: remote, local: local),
      _key,
    );
    expect(result.value?.title, 'A');
    expect(local.rows[_key]?.content, _content);
  });

  test('revalidação com 404 grava marcador negativo e invalida', () async {
    final remote = _FakeRemote(body: null);
    final local = _FakeLocal()
      ..seed(_key, _content, idade: const Duration(hours: 25));
    final c = _container(remote: remote, local: local);

    final sub = c.listen(gestureDocumentProvider(_key), (_, _) {});
    addTearDown(sub.close);

    final first = await c.read(gestureDocumentProvider(_key).future);
    expect(first?.title, 'A', reason: 'o cache stale responde na hora');

    await pumpEventQueue();

    expect(local.rows[_key]?.content, '');
    expect(
      await c.read(gestureDocumentProvider(_key).future),
      isNull,
      reason: 'invalidateSelf faz a leitura aberta refletir a remoção',
    );
  });

  test('revalidação com corpo inválido não grava', () async {
    final remote = _FakeRemote(body: '{nope');
    final local = _FakeLocal()
      ..seed(_key, _content, idade: const Duration(hours: 25));
    final c = _container(remote: remote, local: local);

    final sub = c.listen(gestureDocumentProvider(_key), (_, _) {});
    addTearDown(sub.close);

    final first = await c.read(gestureDocumentProvider(_key).future);
    expect(first?.title, 'A');

    await pumpEventQueue();

    expect(
      local.rows[_key]?.content,
      _content,
      reason: 'corpo inválido não sobrescreve o cache',
    );
    expect((await c.read(gestureDocumentProvider(_key).future))?.title, 'A');
  });

  test('chave vazia devolve null sem tocar nada', () async {
    final remote = _FakeRemote(body: _content);
    final result = await _readWhileWatched(
      _container(remote: remote, local: _FakeLocal()),
      '',
    );
    expect(result.value, isNull);
    expect(remote.calls, 0);
  });
}

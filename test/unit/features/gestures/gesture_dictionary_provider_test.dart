import 'package:coldigui/core/network/device_connectivity.dart';
import 'package:coldigui/core/providers/device_connectivity_provider.dart';
import 'package:coldigui/features/gestures/data/datasources/gesture_content_datasource.dart';
import 'package:coldigui/features/gestures/data/datasources/gesture_dictionary_datasource.dart';
import 'package:coldigui/features/gestures/data/datasources/gesture_dictionary_local_datasource.dart';
import 'package:coldigui/features/gestures/data/providers/gesture_providers.dart';
import 'package:coldigui/features/gestures/domain/entities/gesture_dictionary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _v3 = '{"version":3,"gestures":[{"id":"aaaaaaaaaaaa","image":"a.png"}]}';
const _v4 = '{"version":4,"gestures":[{"id":"aaaaaaaaaaaa","image":"a.png"},{"id":"bbbbbbbbbbbb","image":"b.png"}]}';

class _FakeRemote implements GestureDictionaryDatasource {
  _FakeRemote(this.result, {this.failure});
  GestureDictionaryFetchResult result;
  Object? failure;
  final etagsSent = <String?>[];

  @override
  Future<GestureDictionaryFetchResult> fetch({String? etag}) async {
    etagsSent.add(etag);
    if (failure != null) throw failure!;
    return result;
  }
}

class _FakeLocal implements GestureDictionaryLocalDatasource {
  GestureDictionaryCacheEntry? row;
  int touches = 0;

  void seed(String content, {String? etag, Duration idade = Duration.zero}) {
    row = GestureDictionaryCacheEntry(content: content, etag: etag, fetchedAt: DateTime.now().subtract(idade));
  }

  @override
  GestureDictionaryCacheEntry? read() => row;

  @override
  void write({required String content, required String? etag}) {
    row = GestureDictionaryCacheEntry(content: content, etag: etag, fetchedAt: DateTime.now());
  }

  @override
  void touch() {
    touches++;
    final r = row;
    if (r != null) {
      row = GestureDictionaryCacheEntry(content: r.content, etag: r.etag, fetchedAt: DateTime.now());
    }
  }
}

class _FakeConnectivity implements DeviceConnectivity {
  _FakeConnectivity(this.online);
  final bool online;
  @override
  Future<bool> hasConnection() async => online;
}

ProviderContainer _container(_FakeRemote remote, _FakeLocal local, {bool online = true}) {
  final c = ProviderContainer(
    overrides: [
      gestureDictionaryDatasourceProvider.overrideWithValue(remote),
      gestureDictionaryLocalDatasourceProvider.overrideWithValue(local),
      deviceConnectivityProvider.overrideWithValue(_FakeConnectivity(online)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

/// Lê segurando uma inscrição (como a tela) e solta no fim; o `pump()` deixa
/// o Riverpod decidir se o elemento sobreviveu (`keepAlive`) ou não.
Future<GestureDictionary?> _readWhileWatched(ProviderContainer c) async {
  final sub = c.listen(gestureDictionaryProvider, (_, _) {});
  final GestureDictionary? result;
  try {
    result = await c.read(gestureDictionaryProvider.future);
  } finally {
    sub.close();
  }
  await c.pump();
  return result;
}

void main() {
  test('sem cache: busca, grava corpo+etag e devolve', () async {
    final remote = _FakeRemote(const GestureDictionaryFresh(body: _v3, etag: '"3"'));
    final local = _FakeLocal();
    final dict = await _container(remote, local).read(gestureDictionaryProvider.future);
    expect(dict?.version, 3);
    expect(local.row?.etag, '"3"');
    expect(remote.etagsSent, [null]);
  });

  test('cache fresco responde sem rede', () async {
    final remote = _FakeRemote(const GestureDictionaryFresh(body: _v4, etag: '"4"'));
    final local = _FakeLocal()..seed(_v3, etag: '"3"');
    final dict = await _container(remote, local).read(gestureDictionaryProvider.future);
    expect(dict?.version, 3);
    expect(remote.etagsSent, isEmpty);
  });

  test('cache stale + online: manda If-None-Match; 304 só toca fetchedAt', () async {
    final remote = _FakeRemote(const GestureDictionaryNotModified());
    final local = _FakeLocal()..seed(_v3, etag: '"3"', idade: const Duration(hours: 2));
    final c = _container(remote, local);
    final dict = await c.read(gestureDictionaryProvider.future);
    expect(dict?.version, 3);
    await Future<void>.delayed(Duration.zero);
    expect(remote.etagsSent, ['"3"']);
    expect(local.touches, 1);
  });

  test('cache stale + online: 200 troca o corpo e invalida', () async {
    final remote = _FakeRemote(const GestureDictionaryFresh(body: _v4, etag: '"4"'));
    final local = _FakeLocal()..seed(_v3, etag: '"3"', idade: const Duration(hours: 2));
    final c = _container(remote, local);
    final sub = c.listen(gestureDictionaryProvider, (_, _) {});
    addTearDown(sub.close);
    expect((await c.read(gestureDictionaryProvider.future))?.version, 3);
    await Future<void>.delayed(Duration.zero);
    await c.pump();
    expect((await c.read(gestureDictionaryProvider.future))?.version, 4);
    expect(local.row?.etag, '"4"');
  });

  test('sem cache e sem rede: devolve null, não erro', () async {
    final remote = _FakeRemote(const GestureDictionaryFresh(body: _v3, etag: null), failure: const GestureFetchFailedException('dictionary', 'rede'));
    final dict = await _container(remote, _FakeLocal()).read(gestureDictionaryProvider.future);
    expect(dict, isNull);
  });

  test('404 devolve null e não grava', () async {
    final local = _FakeLocal();
    final dict = await _container(_FakeRemote(const GestureDictionaryNotFound()), local).read(gestureDictionaryProvider.future);
    expect(dict, isNull);
    expect(local.row, isNull);
  });

  test('null (sem cache e sem rede) não gruda: próxima leitura tenta de novo', () async {
    final remote = _FakeRemote(
      const GestureDictionaryFresh(body: _v3, etag: '"3"'),
      failure: const GestureFetchFailedException('dictionary', 'rede'),
    );
    final local = _FakeLocal();
    final c = _container(remote, local);

    final first = await _readWhileWatched(c);
    expect(first, isNull);

    remote.failure = null;
    final second = await _readWhileWatched(c);
    expect(second?.version, 3);
  });
}

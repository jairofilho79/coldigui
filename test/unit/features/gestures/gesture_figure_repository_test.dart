import 'dart:typed_data';

import 'package:coldigui/features/gestures/data/datasources/gesture_figure_store.dart';
import 'package:coldigui/features/gestures/data/repositories/gesture_figure_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStore implements GestureFigureStorePort {
  final rows = <String, Uint8List>{};
  int writes = 0;

  @override
  Future<Uint8List?> read(String r2Key) async => rows[r2Key];

  @override
  Future<void> write(String r2Key, Uint8List bytes) async {
    writes++;
    rows[r2Key] = bytes;
  }

  @override
  Future<void> deleteAll() async => rows.clear();
}

class _FakeAdapter extends Interceptor {
  _FakeAdapter(this.routes, {this.offline = false});

  final Map<String, List<int>> routes;
  final bool offline;
  final requested = <String>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requested.add(options.path);
    if (offline) {
      handler.reject(DioException(requestOptions: options, type: DioExceptionType.connectionError));
      return;
    }
    final body = routes[options.path];
    if (body == null) {
      handler.reject(
        DioException(
          requestOptions: options,
          response: Response<dynamic>(requestOptions: options, statusCode: 404),
          type: DioExceptionType.badResponse,
        ),
      );
      return;
    }
    handler.resolve(
      Response<List<int>>(requestOptions: options, statusCode: 200, data: body),
    );
  }
}

GestureFigureRepository _repo(_MemoryStore store, _FakeAdapter adapter) {
  final dio = Dio()..interceptors.add(adapter);
  return GestureFigureRepository(store, dio, apiBase: 'https://plpcg.com');
}

void main() {
  const key = 'assets/cia/gestures/c687580e7682.png';
  const url = 'https://plpcg.com/api/coldigom/$key';

  test('hit no store não vai à rede', () async {
    final store = _MemoryStore()..rows[key] = Uint8List.fromList([7]);
    final adapter = _FakeAdapter(const {});
    expect(await _repo(store, adapter).get(key), [7]);
    expect(adapter.requested, isEmpty);
  });

  test('miss baixa pelo proxy, grava e devolve', () async {
    final store = _MemoryStore();
    final adapter = _FakeAdapter({url: [1, 2]});
    expect(await _repo(store, adapter).get(key), [1, 2]);
    expect(adapter.requested.single, url);
    expect(store.rows[key], [1, 2]);
  });

  test('404 e rede devolvem null sem lançar', () async {
    expect(await _repo(_MemoryStore(), _FakeAdapter(const {})).get(key), isNull);
    expect(await _repo(_MemoryStore(), _FakeAdapter(const {}, offline: true)).get(key), isNull);
  });

  test('chave vazia devolve null', () async {
    expect(await _repo(_MemoryStore(), _FakeAdapter(const {})).get(''), isNull);
  });

  test('prefetch baixa só o que falta e ignora falhas', () async {
    final store = _MemoryStore()..rows['a.png'] = Uint8List.fromList([0]);
    final adapter = _FakeAdapter({
      'https://plpcg.com/api/coldigom/b.png': [1],
      // c.png não existe → 404, ignorado.
    });
    await _repo(store, adapter).prefetch(['a.png', 'b.png', 'c.png', 'b.png']);
    expect(store.rows.keys, containsAll(['a.png', 'b.png']));
    expect(store.rows.containsKey('c.png'), isFalse);
    expect(adapter.requested.where((p) => p.endsWith('b.png')).length, 1);
  });
}

import 'package:coldigui/features/gestures/data/datasources/gesture_content_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Interceptor que responde da tabela [routes] sem tocar na rede.
class _FakeAdapter extends Interceptor {
  _FakeAdapter(this.routes, {this.offline = false});

  final Map<String, (int status, String body)> routes;
  final bool offline;
  final requestedPaths = <String>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requestedPaths.add(options.path);
    if (offline) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );
      return;
    }
    final route = routes[options.path];
    if (route == null) {
      handler.reject(
        DioException(
          requestOptions: options,
          response: Response<String>(requestOptions: options, statusCode: 404),
          type: DioExceptionType.badResponse,
        ),
      );
      return;
    }
    handler.resolve(
      Response<String>(
        requestOptions: options,
        statusCode: route.$1,
        data: route.$2,
      ),
    );
  }
}

GestureContentDatasource _datasource(_FakeAdapter adapter) {
  final dio = Dio()..interceptors.add(adapter);
  return GestureContentDatasource(dio, apiBase: 'https://plpcg.com');
}

void main() {
  const key = 'assets/praises/p1/m1.gestures';
  const url = 'https://plpcg.com/api/coldigom/$key';
  const body = '{"schema":"coldigom.gestures/1","items":[]}';

  test('200 devolve o corpo cru, buscando pelo proxy', () async {
    final adapter = _FakeAdapter({url: (200, body)});
    final content = await _datasource(adapter).fetchContent(key);
    expect(content, body);
    expect(adapter.requestedPaths.single, url);
  });

  test('404 devolve null', () async {
    expect(await _datasource(_FakeAdapter(const {})).fetchContent(key), isNull);
  });

  test('corpo vazio devolve null (lápide)', () async {
    expect(await _datasource(_FakeAdapter({url: (200, '  ')})).fetchContent(key), isNull);
  });

  test('chave vazia devolve null sem ir à rede', () async {
    final adapter = _FakeAdapter(const {});
    expect(await _datasource(adapter).fetchContent('  '), isNull);
    expect(adapter.requestedPaths, isEmpty);
  });

  test('queda de rede lança GestureFetchFailedException', () async {
    await expectLater(
      _datasource(_FakeAdapter(const {}, offline: true)).fetchContent(key),
      throwsA(isA<GestureFetchFailedException>()),
    );
  });

  test('500 lança GestureFetchFailedException', () async {
    await expectLater(
      _datasource(_FakeAdapter({url: (500, 'boom')})).fetchContent(key),
      throwsA(isA<GestureFetchFailedException>()),
    );
  });
}

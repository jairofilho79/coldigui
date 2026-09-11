import 'package:coldigui/features/gestures/data/datasources/gesture_content_datasource.dart';
import 'package:coldigui/features/gestures/data/datasources/gesture_dictionary_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAdapter extends Interceptor {
  _FakeAdapter({
    required this.status,
    this.body = '',
    this.etag,
    this.offline = false,
  });

  final int status;
  final String body;
  final String? etag;
  final bool offline;
  final requests = <RequestOptions>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requests.add(options);
    if (offline) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );
      return;
    }
    final response = Response<String>(
      requestOptions: options,
      statusCode: status,
      data: body,
      headers: Headers.fromMap({
        if (etag != null) 'etag': [etag!],
      }),
    );
    if (status >= 400) {
      handler.reject(
        DioException(
          requestOptions: options,
          response: response,
          type: DioExceptionType.badResponse,
        ),
      );
      return;
    }
    handler.resolve(response);
  }
}

GestureDictionaryDatasource _datasource(_FakeAdapter adapter) {
  final dio = Dio()..interceptors.add(adapter);
  return GestureDictionaryDatasource(dio, baseUrl: 'https://coldigom.test');
}

void main() {
  const body = '{"version":3,"gestures":[]}';

  test('200 devolve Fresh com corpo e etag, na URL certa', () async {
    final adapter = _FakeAdapter(status: 200, body: body, etag: '"v3"');
    final result = await _datasource(adapter).fetch();
    expect(result, isA<GestureDictionaryFresh>());
    final fresh = result as GestureDictionaryFresh;
    expect(fresh.body, body);
    expect(fresh.etag, '"v3"');
    expect(adapter.requests.single.path, 'https://coldigom.test/api/gestures/dictionary');
    expect(adapter.requests.single.headers.containsKey('If-None-Match'), isFalse);
  });

  test('manda If-None-Match quando há etag; 304 devolve NotModified', () async {
    final adapter = _FakeAdapter(status: 304);
    final result = await _datasource(adapter).fetch(etag: '"v3"');
    expect(result, isA<GestureDictionaryNotModified>());
    expect(adapter.requests.single.headers['If-None-Match'], '"v3"');
  });

  test('404 devolve NotFound', () async {
    expect(await _datasource(_FakeAdapter(status: 404)).fetch(), isA<GestureDictionaryNotFound>());
  });

  test('rede e 500 lançam GestureFetchFailedException', () async {
    await expectLater(
      _datasource(_FakeAdapter(status: 200, offline: true)).fetch(),
      throwsA(isA<GestureFetchFailedException>()),
    );
    await expectLater(
      _datasource(_FakeAdapter(status: 500)).fetch(),
      throwsA(isA<GestureFetchFailedException>()),
    );
  });

  test('baseUrl com barra final não duplica a barra', () async {
    final adapter = _FakeAdapter(status: 200, body: body);
    final dio = Dio()..interceptors.add(adapter);
    await GestureDictionaryDatasource(dio, baseUrl: 'https://x.test/').fetch();
    expect(adapter.requests.single.path, 'https://x.test/api/gestures/dictionary');
  });
}

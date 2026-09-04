import 'dart:typed_data';

import 'package:coldigui/core/network/retry_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adapter roteirizado: cada entrada de [script] é a resposta (ou o erro) da
/// n-ésima tentativa. Registra os métodos HTTP que realmente saíram.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.script);

  /// `int` = status devolvido; `DioExceptionType` = erro lançado.
  final List<Object> script;
  final List<String> methods = [];

  int get calls => methods.length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final step = script[methods.length.clamp(0, script.length - 1)];
    methods.add(options.method);
    if (step is DioExceptionType) {
      throw DioException(requestOptions: options, type: step);
    }
    return ResponseBody.fromString(
      '{}',
      step as int,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late List<Duration> waited;

  Dio dioWith(_ScriptedAdapter adapter, {int maxRetries = 2}) {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(
      RetryInterceptor(
        dio: dio,
        maxRetries: maxRetries,
        sleep: (d) async => waited.add(d),
      ),
    );
    return dio;
  }

  setUp(() => waited = []);

  test('backoff padrão é 300 ms e depois 900 ms', () {
    expect(RetryInterceptor.defaultBackoff, const [
      Duration(milliseconds: 300),
      Duration(milliseconds: 900),
    ]);
  });

  test('GET: duas falhas de conexão e sucesso = 3 tentativas', () async {
    final adapter = _ScriptedAdapter([
      DioExceptionType.connectionError,
      DioExceptionType.connectionError,
      200,
    ]);

    final response = await dioWith(adapter).get<Object?>('/manifest');

    expect(response.statusCode, 200);
    expect(adapter.calls, 3);
    expect(waited, const [
      Duration(milliseconds: 300),
      Duration(milliseconds: 900),
    ]);
  });

  test(
    'GET: falha persistente para em 3 tentativas e propaga o erro',
    () async {
      final adapter = _ScriptedAdapter([DioExceptionType.connectionError]);

      await expectLater(
        dioWith(adapter).get<Object?>('/manifest'),
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.connectionError,
          ),
        ),
      );
      expect(adapter.calls, 3);
    },
  );

  test('GET: timeout de conexão é retentado', () async {
    final adapter = _ScriptedAdapter([DioExceptionType.connectionTimeout, 200]);

    await dioWith(adapter).get<Object?>('/manifest');

    expect(adapter.calls, 2);
  });

  test('GET: timeout de recebimento é retentado', () async {
    final adapter = _ScriptedAdapter([DioExceptionType.receiveTimeout, 200]);

    await dioWith(adapter).get<Object?>('/manifest');

    expect(adapter.calls, 2);
  });

  test('GET: 503 é retentado', () async {
    final adapter = _ScriptedAdapter([503, 200]);

    final response = await dioWith(adapter).get<Object?>('/manifest');

    expect(response.statusCode, 200);
    expect(adapter.calls, 2);
  });

  test('GET: 404 não é retentado', () async {
    final adapter = _ScriptedAdapter([404]);

    await expectLater(
      dioWith(adapter).get<Object?>('/manifest'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.calls, 1);
  });

  test('GET: 401 não é retentado (é caso do AuthRefreshInterceptor)', () async {
    final adapter = _ScriptedAdapter([401]);

    await expectLater(
      dioWith(adapter).get<Object?>('/playlists'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.calls, 1);
  });

  test('POST não é retentado', () async {
    final adapter = _ScriptedAdapter([DioExceptionType.connectionError]);

    await expectLater(
      dioWith(adapter).post<Object?>('/playlists'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.calls, 1);
    expect(waited, isEmpty);
  });

  test('PUT e DELETE não são retentados', () async {
    final put = _ScriptedAdapter([DioExceptionType.connectionError]);
    await expectLater(
      dioWith(put).put<Object?>('/playlists/1'),
      throwsA(isA<DioException>()),
    );
    expect(put.calls, 1);

    final delete = _ScriptedAdapter([DioExceptionType.connectionError]);
    await expectLater(
      dioWith(delete).delete<Object?>('/playlists/1'),
      throwsA(isA<DioException>()),
    );
    expect(delete.calls, 1);
  });

  test('cancelamento não é retentado', () async {
    final adapter = _ScriptedAdapter([DioExceptionType.cancel]);

    await expectLater(
      dioWith(adapter).get<Object?>('/manifest'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.calls, 1);
  });

  test('opt-out via extra desliga o retry nesta request', () async {
    final adapter = _ScriptedAdapter([DioExceptionType.connectionError]);

    await expectLater(
      dioWith(adapter).get<Object?>(
        '/pdf',
        options: Options(extra: const {RetryInterceptor.disableKey: true}),
      ),
      throwsA(isA<DioException>()),
    );

    expect(adapter.calls, 1, reason: 'quem já retenta sozinho não pode dobrar');
    expect(waited, isEmpty);
  });

  test('extra com opt-out false continua retentando', () async {
    final adapter = _ScriptedAdapter([DioExceptionType.connectionError, 200]);

    await dioWith(adapter).get<Object?>(
      '/pdf',
      options: Options(extra: const {RetryInterceptor.disableKey: false}),
    );

    expect(adapter.calls, 2);
  });

  test('maxRetries: 0 desliga o retry', () async {
    final adapter = _ScriptedAdapter([DioExceptionType.connectionError]);

    await expectLater(
      dioWith(adapter, maxRetries: 0).get<Object?>('/manifest'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.calls, 1);
  });

  test('maxRetries maior que o backoff reusa o último intervalo', () async {
    final adapter = _ScriptedAdapter([DioExceptionType.connectionError]);

    await expectLater(
      dioWith(adapter, maxRetries: 4).get<Object?>('/manifest'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.calls, 5);
    expect(waited, const [
      Duration(milliseconds: 300),
      Duration(milliseconds: 900),
      Duration(milliseconds: 900),
      Duration(milliseconds: 900),
    ]);
  });
}

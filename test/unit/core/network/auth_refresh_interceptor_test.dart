import 'dart:typed_data';

import 'package:coldigui/core/network/auth_refresh_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adapter roteirizado que registra o `Authorization` de cada tentativa.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.statuses);

  final List<int> statuses;
  final List<String?> authHeaders = [];

  int get calls => authHeaders.length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final status = statuses[authHeaders.length.clamp(0, statuses.length - 1)];
    authHeaders.add(options.headers['Authorization'] as String?);
    return ResponseBody.fromString(
      '{}',
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late List<String> events;
  late bool sessionExpired;

  Dio dioWith(
    _ScriptedAdapter adapter, {
    required Future<String?> Function() refreshIdToken,
  }) {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(
      AuthRefreshInterceptor(
        dio: dio,
        refreshIdToken: refreshIdToken,
        isSessionExpired: () => sessionExpired,
        markSessionExpired: () {
          sessionExpired = true;
          events.add('sessionExpired');
        },
      ),
    );
    return dio;
  }

  Options auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  setUp(() {
    events = [];
    sessionExpired = false;
  });

  test('401 dispara refresh e repete a request com o Bearer novo', () async {
    final adapter = _ScriptedAdapter([401, 200]);
    final dio = dioWith(adapter, refreshIdToken: () async => 'token-novo');

    final response = await dio.get<Object?>(
      '/playlists',
      options: auth('token-velho'),
    );

    expect(response.statusCode, 200);
    expect(adapter.authHeaders, ['Bearer token-velho', 'Bearer token-novo']);
    expect(events, isEmpty);
  });

  test('refresh falhando devolve o 401 original ao chamador', () async {
    final adapter = _ScriptedAdapter([401]);
    final dio = dioWith(adapter, refreshIdToken: () async => null);

    await expectLater(
      dio.get<Object?>('/playlists', options: auth('token-velho')),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          401,
        ),
      ),
    );
    expect(adapter.calls, 1);
  });

  test(
    '401 depois do refresh marca sessão expirada e não tenta de novo',
    () async {
      var refreshes = 0;
      final adapter = _ScriptedAdapter([401, 401]);
      final dio = dioWith(
        adapter,
        refreshIdToken: () async {
          refreshes++;
          return 'token-novo';
        },
      );

      await expectLater(
        dio.get<Object?>('/playlists', options: auth('token-velho')),
        throwsA(isA<DioException>()),
      );

      expect(refreshes, 1);
      expect(adapter.calls, 2);
      expect(events, ['sessionExpired']);
    },
  );

  test('401 sem header Authorization não dispara refresh', () async {
    var refreshes = 0;
    final adapter = _ScriptedAdapter([401]);
    final dio = dioWith(
      adapter,
      refreshIdToken: () async {
        refreshes++;
        return 'token-novo';
      },
    );

    await expectLater(
      dio.get<Object?>('/publico'),
      throwsA(isA<DioException>()),
    );

    expect(refreshes, 0);
    expect(adapter.calls, 1);
    expect(events, isEmpty);
  });

  test('403 não dispara refresh (permissão, não token vencido)', () async {
    var refreshes = 0;
    final adapter = _ScriptedAdapter([403]);
    final dio = dioWith(
      adapter,
      refreshIdToken: () async {
        refreshes++;
        return 'token-novo';
      },
    );

    await expectLater(
      dio.get<Object?>('/playlists', options: auth('t')),
      throwsA(isA<DioException>()),
    );

    expect(refreshes, 0);
  });

  test('500 não dispara refresh', () async {
    var refreshes = 0;
    final adapter = _ScriptedAdapter([500]);
    final dio = dioWith(
      adapter,
      refreshIdToken: () async {
        refreshes++;
        return 'token-novo';
      },
    );

    await expectLater(
      dio.get<Object?>('/playlists', options: auth('t')),
      throwsA(isA<DioException>()),
    );

    expect(refreshes, 0);
  });

  test('token vazio conta como refresh falho', () async {
    final adapter = _ScriptedAdapter([401]);
    final dio = dioWith(adapter, refreshIdToken: () async => '');

    await expectLater(
      dio.get<Object?>('/playlists', options: auth('t')),
      throwsA(isA<DioException>()),
    );
    expect(adapter.calls, 1);
  });

  test('refresh que lança não vira um erro diferente do 401', () async {
    final adapter = _ScriptedAdapter([401]);
    final dio = dioWith(
      adapter,
      refreshIdToken: () async => throw StateError('sdk bloqueado'),
    );

    await expectLater(
      dio.get<Object?>('/playlists', options: auth('t')),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          401,
        ),
      ),
    );
  });

  test('sessão já expirada não tenta refresh de novo (Critical 1)', () async {
    sessionExpired = true;
    var refreshes = 0;
    final adapter = _ScriptedAdapter([401]);
    final dio = dioWith(
      adapter,
      refreshIdToken: () async {
        refreshes++;
        return 'token-novo';
      },
    );

    await expectLater(
      dio.get<Object?>('/playlists', options: auth('t')),
      throwsA(isA<DioException>()),
    );

    expect(refreshes, 0);
    expect(adapter.calls, 1);
  });

  test(
    'depois de um refresh falho, o 401 seguinte não chama refresh de novo',
    () async {
      var refreshes = 0;
      Future<String?> refresher() async {
        refreshes++;
        return null;
      }

      final first = _ScriptedAdapter([401]);
      await expectLater(
        dioWith(
          first,
          refreshIdToken: refresher,
        ).get<Object?>('/playlists', options: auth('t')),
        throwsA(isA<DioException>()),
      );
      expect(refreshes, 1);

      // O refresher real marca a sessão como expirada ao falhar.
      sessionExpired = true;

      final second = _ScriptedAdapter([401]);
      await expectLater(
        dioWith(
          second,
          refreshIdToken: refresher,
        ).get<Object?>('/playlists', options: auth('t')),
        throwsA(isA<DioException>()),
      );

      expect(refreshes, 1, reason: 'não pode tentar renovar de novo');
    },
  );

  test('POST autenticado também é repetido após refresh', () async {
    final adapter = _ScriptedAdapter([401, 200]);
    final dio = dioWith(adapter, refreshIdToken: () async => 'token-novo');

    final response = await dio.post<Object?>(
      '/playlists',
      data: {'nome': 'x'},
      options: auth('token-velho'),
    );

    expect(response.statusCode, 200);
    expect(adapter.authHeaders.last, 'Bearer token-novo');
  });
}

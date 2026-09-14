import 'dart:typed_data';

import 'package:coldigui/core/network/auth_unauthorized_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.status);
  final int status;

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async => ResponseBody.fromString(
    '{}',
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  late int calls;
  late List<String> rejectedTokens;
  late Dio dio;

  Dio build(int status) {
    calls = 0;
    rejectedTokens = [];
    return Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = _StatusAdapter(status)
      ..interceptors.add(
        AuthUnauthorizedInterceptor(
          onUnauthorized: (token) {
            calls++;
            rejectedTokens.add(token);
          },
        ),
      );
  }

  Future<void> get(String? bearer, {bool tolerate401 = false}) async {
    try {
      await dio.get<Object?>(
        '/api/playlists',
        options: Options(
          headers: bearer == null ? null : {'Authorization': 'Bearer $bearer'},
          validateStatus: tolerate401 ? (s) => s != null && s < 500 : null,
        ),
      );
    } on DioException {
      // O 401 continua chegando ao chamador — o interceptor não o engole.
    }
  }

  test('401 com Bearer sess_ dispara onUnauthorized com o token cru (caminho onError)', () async {
    dio = build(401);
    await get('sess_abc');
    expect(calls, 1);
    expect(rejectedTokens, ['sess_abc']);
  });

  test('401 com Bearer sess_ dispara também quando validateStatus tolera 401 (onResponse)', () async {
    dio = build(401);
    await get('sess_abc', tolerate401: true);
    expect(calls, 1);
    expect(rejectedTokens, ['sess_abc']);
  });

  test('401 sem Authorization (rota pública) não dispara', () async {
    dio = build(401);
    await get(null);
    expect(calls, 0);
  });

  test('401 com JWT do Google (POST /session) não dispara', () async {
    dio = build(401);
    await get('eyJhbGciOi.eyJzdWIi.sig');
    expect(calls, 0);
  });

  test('403 e 200 não disparam', () async {
    dio = build(403);
    await get('sess_abc');
    dio = build(200);
    await get('sess_abc');
    expect(calls, 0);
  });
}

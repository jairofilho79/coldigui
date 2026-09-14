import 'dart:convert';
import 'dart:typed_data';

import 'package:coldigui/features/auth/data/auth_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adapter que devolve sempre a mesma resposta, sem tocar na rede.
class _FixedAdapter implements HttpClientAdapter {
  _FixedAdapter(this.statusCode, [this.body]);

  final int statusCode;
  final Map<String, dynamic>? body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioWith(int statusCode, [Map<String, dynamic>? body]) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  dio.httpClientAdapter = _FixedAdapter(statusCode, body);
  return dio;
}

void main() {
  test('401 do Worker vira AuthUnauthorizedException', () async {
    final datasource = AuthRemoteDatasource(_dioWith(401));

    await expectLater(
      datasource.establishSession('token'),
      throwsA(
        isA<AuthUnauthorizedException>().having(
          (e) => e.statusCode,
          'statusCode',
          401,
        ),
      ),
    );
  });

  test('403 do Worker vira AuthUnauthorizedException', () async {
    final datasource = AuthRemoteDatasource(_dioWith(403));

    await expectLater(
      datasource.establishSession('token'),
      throwsA(isA<AuthUnauthorizedException>()),
    );
  });

  test('200 sem googleSub falha em vez de criar sessão vazia', () async {
    final datasource = AuthRemoteDatasource(
      _dioWith(200, {'email': 'a@b.com'}),
    );

    await expectLater(
      datasource.establishSession('token'),
      throwsA(isA<StateError>()),
    );
  });

  test('200 com googleSub devolve o usuário com o idToken enviado', () async {
    final datasource = AuthRemoteDatasource(
      _dioWith(200, {'googleSub': 'sub-1', 'email': 'a@b.com'}),
    );

    final user = await datasource.establishSession('token-1');

    expect(user.googleSub, 'sub-1');
    expect(user.sessionToken, 'token-1');
  });
}

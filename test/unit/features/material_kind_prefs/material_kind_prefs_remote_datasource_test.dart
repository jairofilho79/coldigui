import 'dart:convert';
import 'dart:typed_data';

import 'package:coldigui/core/constants/api_endpoints.dart';
import 'package:coldigui/features/auth/data/auth_remote_datasource.dart';
import 'package:coldigui/features/material_kind_prefs/data/datasources/material_kind_prefs_remote_datasource.dart';
import 'package:coldigui/features/material_kind_prefs/domain/entities/material_kind_prefs.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedAdapter implements HttpClientAdapter {
  _FixedAdapter(this.statusCode, this.body);

  final int statusCode;
  final Object? body;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
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

(MaterialKindPrefsRemoteDatasource, _FixedAdapter) _make(
  int status,
  Object? body,
) {
  final adapter = _FixedAdapter(status, body);
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  dio.httpClientAdapter = adapter;
  return (MaterialKindPrefsRemoteDatasource(dio), adapter);
}

void main() {
  const doc = {
    'kindIds': ['a', 'b'],
    'preferredTypes': {'a': 'chord'},
    'updatedAt': '2026-09-12T10:00:00.000Z',
    'version': 2,
  };

  test(
    'fetch 200 devolve o documento com pendingPush false e Bearer',
    () async {
      final (remote, adapter) = _make(200, doc);
      final prefs = await remote.fetch('tok');
      expect(prefs!.kindIds, ['a', 'b']);
      expect(prefs.preferredTypeByKind, {'a': 'chord'});
      expect(prefs.pendingPush, isFalse);
      expect(prefs.updatedAt, DateTime.utc(2026, 9, 12, 10));
      expect(adapter.lastRequest!.headers['Authorization'], 'Bearer tok');
      expect(adapter.lastRequest!.path, ApiEndpoints.materialKindPrefs);
    },
  );

  test('fetch 204 devolve null', () async {
    final (remote, _) = _make(204, null);
    expect(await remote.fetch('tok'), isNull);
  });

  test('put envia kindIds + preferredTypes + updatedAt e devolve o documento gravado', () async {
    final (remote, adapter) = _make(200, doc);
    final result = await remote.put(
      idToken: 'tok',
      prefs: MaterialKindPrefs.validated(
        kindIds: const ['a', 'b'],
        preferredTypeByKind: const {'a': 'chord'},
        updatedAt: DateTime.utc(2026, 9, 12, 10),
        pendingPush: true,
      ),
    );
    expect(result.kindIds, ['a', 'b']);
    expect(result.preferredTypeByKind, {'a': 'chord'});
    expect(result.pendingPush, isFalse);
    final sent = adapter.lastRequest!.data as Map;
    expect(sent.keys.toSet(), {'kindIds', 'preferredTypes', 'updatedAt'});
    expect(sent['preferredTypes'], {'a': 'chord'});
    expect(sent['updatedAt'], '2026-09-12T10:00:00.000Z');
    expect(adapter.lastRequest!.method, 'PUT');
  });

  test('put 409 vira MaterialKindPrefsConflict com o remoto', () async {
    final (remote, _) = _make(409, doc);
    await expectLater(
      remote.put(idToken: 'tok', prefs: MaterialKindPrefs.empty),
      throwsA(
        isA<MaterialKindPrefsConflict>().having(
          (c) => c.remote.kindIds,
          'remote',
          ['a', 'b'],
        ),
      ),
    );
  });

  test('401 vira AuthUnauthorizedException', () async {
    final (remote, _) = _make(401, {'error': 'unauthorized'});
    await expectLater(
      remote.fetch('tok'),
      throwsA(isA<AuthUnauthorizedException>()),
    );
  });
}

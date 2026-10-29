import 'dart:convert';
import 'dart:typed_data';

import 'package:coldigui/features/social/data/datasources/social_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adapter que devolve sempre a mesma resposta, sem tocar na rede.
class _FixedAdapter implements HttpClientAdapter {
  _FixedAdapter(this.statusCode, this.body);

  final int statusCode;
  final Object? body;

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

SocialRemoteDatasource _datasource(int statusCode, Object? body) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  dio.httpClientAdapter = _FixedAdapter(statusCode, body);
  return SocialRemoteDatasource(dio);
}

void main() {
  test(
    'fetchUserPlaylists ignora registro sem id e devolve os demais',
    () async {
      final datasource = _datasource(200, [
        {'id': 'ok-1', 'nome': 'A', 'pdfIds': [], 'audioIds': []},
        // Sem `id`: `PublicPlaylist.fromJson` lança FormatException.
        {'nome': 'Sem id'},
        {'id': 'ok-2', 'nome': 'B', 'pdfIds': [], 'audioIds': []},
      ]);

      final result = await datasource.fetchUserPlaylists(
        sessionToken: 'token',
        username: 'maria',
      );

      expect(result.map((p) => p.id), ['ok-1', 'ok-2']);
    },
  );

  test('fetchUserPlaylists sobrevive a lista inteira malformada', () async {
    final datasource = _datasource(200, [
      {'id': 42},
    ]);

    final result = await datasource.fetchUserPlaylists(
      sessionToken: 'token',
      username: 'maria',
    );

    expect(result, isEmpty);
  });
}

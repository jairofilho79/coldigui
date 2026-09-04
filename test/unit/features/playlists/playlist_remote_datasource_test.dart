import 'dart:convert';
import 'dart:typed_data';

import 'package:coldigui/features/playlists/data/datasources/playlist_remote_datasource.dart';
import 'package:coldigui/features/playlists/domain/entities/remote_playlist.dart';
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

PlaylistRemoteDatasource _datasource(int statusCode, Object? body) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  dio.httpClientAdapter = _FixedAdapter(statusCode, body);
  return PlaylistRemoteDatasource(dio);
}

Map<String, Object?> _row({
  String id = 'p1',
  String nome = 'Culto',
  String updatedAt = '2026-02-01T00:00:00.000Z',
  int version = 1,
}) => {
  'id': id,
  'nome': nome,
  'pdfIds': ['a'],
  'audioIds': <String>[],
  'salva': true,
  'favorita': false,
  'createdAt': '2026-01-01T00:00:00.000Z',
  'updatedAt': updatedAt,
  'version': version,
};

void main() {
  test('fetchAll ignora registro malformado e mantém os demais', () async {
    final datasource = _datasource(200, [
      _row(id: 'ok-1'),
      // Sem `nome` e com `createdAt` inválido: `fromJson` lança FormatException.
      {'id': 'ruim', 'createdAt': 42},
      _row(id: 'ok-2'),
    ]);

    final result = await datasource.fetchAll('token');

    expect(result.map((p) => p.id), ['ok-1', 'ok-2']);
  });

  test('fetchAll sobrevive a lista inteira malformada', () async {
    final datasource = _datasource(200, [
      {'id': 42},
    ]);

    expect(await datasource.fetchAll('token'), isEmpty);
  });

  test('upsert com 409 lança PlaylistConflictException com a linha remota', () {
    final datasource = _datasource(
      409,
      _row(id: 'p1', nome: 'Remoto', version: 9),
    );
    final local = RemotePlaylist.fromLegacyLists(
      id: 'p1',
      nome: 'Local',
      pdfIds: const ['a'],
      salva: true,
      favorita: false,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 5),
      version: 1,
    );

    expect(
      () => datasource.upsert(idToken: 'token', playlist: local),
      throwsA(
        isA<PlaylistConflictException>()
            .having((e) => e.remote.id, 'remote.id', 'p1')
            .having((e) => e.remote.version, 'remote.version', 9)
            .having((e) => e.remote.nome, 'remote.nome', 'Remoto'),
      ),
    );
  });

  test('409 com corpo ilegível continua sendo DioException', () {
    final datasource = _datasource(409, {'sem': 'nada útil'});
    final local = RemotePlaylist.fromLegacyLists(
      id: 'p1',
      nome: 'Local',
      pdfIds: const ['a'],
      salva: true,
      favorita: false,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 5),
      version: 1,
    );

    expect(
      () => datasource.upsert(idToken: 'token', playlist: local),
      throwsA(isA<DioException>()),
    );
  });

  test('erro que não é 409 sobe como DioException', () {
    final datasource = _datasource(500, null);
    final local = RemotePlaylist.fromLegacyLists(
      id: 'p1',
      nome: 'Local',
      pdfIds: const ['a'],
      salva: true,
      favorita: false,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 5),
      version: 1,
    );

    expect(
      () => datasource.upsert(idToken: 'token', playlist: local),
      throwsA(isA<DioException>()),
    );
  });
}

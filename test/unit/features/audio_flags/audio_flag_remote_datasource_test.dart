import 'dart:convert';
import 'dart:typed_data';

import 'package:coldigui/features/audio_flags/data/datasources/audio_flag_remote_datasource.dart';
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

AudioFlagRemoteDatasource _datasource(Object? body) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  dio.httpClientAdapter = _FixedAdapter(200, body);
  return AudioFlagRemoteDatasource(dio);
}

Map<String, Object?> _row({String id = 'f1', String audioId = 'aud-1'}) => {
  'id': id,
  'audioId': audioId,
  'positionMs': 1000,
  'label': 'refrão',
  'createdAt': '2026-01-01T00:00:00.000Z',
  'updatedAt': '2026-02-01T00:00:00.000Z',
  'version': 1,
};

void main() {
  test('fetchAll ignora flag malformada e mantém as demais', () async {
    final datasource = _datasource([
      _row(id: 'ok-1'),
      // `positionMs` não numérico: `fromJson` lança FormatException.
      {..._row(id: 'ruim'), 'positionMs': 'meio'},
      _row(id: 'ok-2'),
    ]);

    final result = await datasource.fetchAll('token');

    expect(result.map((f) => f.id), ['ok-1', 'ok-2']);
  });

  test('audioId vazio é descarte, não crash', () async {
    final datasource = _datasource([
      _row(id: 'ok-1'),
      _row(id: 'sem-audio', audioId: ''),
    ]);

    final result = await datasource.fetchAll('token');

    expect(result.map((f) => f.id), ['ok-1']);
  });

  test('data inválida derruba só o registro ruim', () async {
    final datasource = _datasource([
      {..._row(id: 'ruim'), 'updatedAt': 'ontem'},
      _row(id: 'ok-1'),
    ]);

    expect((await datasource.fetchAll('token')).single.id, 'ok-1');
  });

  test('lista inteira malformada devolve vazio', () async {
    final datasource = _datasource([
      {'id': 42},
    ]);

    expect(await datasource.fetchAll('token'), isEmpty);
  });
}

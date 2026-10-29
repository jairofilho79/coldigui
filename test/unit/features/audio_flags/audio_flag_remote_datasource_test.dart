import 'dart:convert';
import 'dart:typed_data';

import 'package:coldigui/features/audio_flags/data/datasources/audio_flag_remote_datasource.dart';
import 'package:coldigui/features/audio_flags/domain/entities/remote_audio_flag.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adapter que devolve sempre a mesma resposta, sem tocar na rede.
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

AudioFlagRemoteDatasource _datasource(Object? body) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  dio.httpClientAdapter = _FixedAdapter(200, body);
  return AudioFlagRemoteDatasource(dio);
}

/// Datasource com adapter exposto, para inspecionar a requisição/status.
(AudioFlagRemoteDatasource, _FixedAdapter) _withAdapter(
  int statusCode,
  Object? body,
) {
  final adapter = _FixedAdapter(statusCode, body);
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  dio.httpClientAdapter = adapter;
  return (AudioFlagRemoteDatasource(dio), adapter);
}

RemoteAudioFlag _flag({String id = 'f1'}) => RemoteAudioFlag(
  id: id,
  audioId: 'aud-1',
  positionMs: 1000,
  label: 'refrão',
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 2, 1),
  version: 1,
);

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

  test('fetchAll pede os tombstones com includeDeleted=1', () async {
    final (datasource, adapter) = _withAdapter(200, [_row()]);

    await datasource.fetchAll('token');

    expect(adapter.lastRequest?.queryParameters['includeDeleted'], '1');
  });

  test('deletedAt do wire chega na entidade', () async {
    final datasource = _datasource([
      {..._row(id: 'viva')},
      {..._row(id: 'morta'), 'deletedAt': '2026-05-01T00:00:00.000Z'},
    ]);

    final result = await datasource.fetchAll('token');

    expect(result.firstWhere((f) => f.id == 'viva').deletedAt, isNull);
    expect(
      result.firstWhere((f) => f.id == 'morta').deletedAt,
      DateTime.utc(2026, 5, 1),
    );
  });

  test('deletedAt ilegível descarta só o registro ruim', () async {
    final datasource = _datasource([
      {..._row(id: 'ruim'), 'deletedAt': 'ontem'},
      _row(id: 'ok-1'),
    ]);

    expect((await datasource.fetchAll('token')).single.id, 'ok-1');
  });

  test('409 com corpo legível vira AudioFlagConflictException', () async {
    final (datasource, _) = _withAdapter(409, {
      ..._row(),
      'updatedAt': '2026-03-01T00:00:00.000Z',
      'version': 7,
    });

    await expectLater(
      datasource.upsert(sessionToken: 'token', flag: _flag()),
      throwsA(
        isA<AudioFlagConflictException>().having(
          (e) => e.remote.version,
          'remote.version',
          7,
        ),
      ),
    );
  });

  test('409 sem corpo legível continua DioException', () async {
    final (datasource, _) = _withAdapter(409, {'id': 42});

    await expectLater(
      datasource.upsert(sessionToken: 'token', flag: _flag()),
      throwsA(isA<DioException>()),
    );
  });
}

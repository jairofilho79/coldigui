import 'dart:convert';
import 'dart:typed_data';

import 'package:coldigui/features/live/data/live_room_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adapter que devolve [status]/[body] e grava a request.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.status, this.body);
  final int status;
  final Map<String, Object?> body;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'ensureRoom faz POST /api/live/room com Bearer e devolve LiveRoomInfo',
    () async {
      final adapter = _RecordingAdapter(200, {
        'code': 'k7x2m9q',
        'url': 'https://plpcg.com/ao-vivo/k7x2m9q',
        'ownerName': 'Fulano',
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://plpcg.com'))
        ..httpClientAdapter = adapter;
      final ds = LiveRoomRemoteDatasource(dio, sessionToken: () => 'sess_x');
      final info = await ds.ensureRoom();
      expect(adapter.last!.method, 'POST');
      expect(adapter.last!.path, '/api/live/room');
      expect(adapter.last!.headers['Authorization'], 'Bearer sess_x');
      expect(info.code, 'k7x2m9q');
      expect(info.ownerName, 'Fulano');
    },
  );

  test('regenerate usa /regenerate', () async {
    final adapter = _RecordingAdapter(200, {
      'code': 'abcdefg',
      'url': 'u',
      'ownerName': 'F',
    });
    final dio = Dio(BaseOptions(baseUrl: 'https://plpcg.com'))
      ..httpClientAdapter = adapter;
    final info = await LiveRoomRemoteDatasource(
      dio,
      sessionToken: () => 'sess_x',
    ).regenerate();
    expect(adapter.last!.path, '/api/live/room/regenerate');
    expect(info.code, 'abcdefg');
  });

  test('sem token lança StateError sem bater na rede', () async {
    final adapter = _RecordingAdapter(200, {});
    final dio = Dio()..httpClientAdapter = adapter;
    await expectLater(
      LiveRoomRemoteDatasource(dio, sessionToken: () => null).ensureRoom(),
      throwsStateError,
    );
    expect(adapter.last, isNull);
  });

  test('401 propaga DioException', () async {
    final adapter = _RecordingAdapter(401, {'error': 'unauthorized'});
    final dio = Dio(BaseOptions(baseUrl: 'https://plpcg.com'))
      ..httpClientAdapter = adapter;
    await expectLater(
      LiveRoomRemoteDatasource(dio, sessionToken: () => 'sess_x').ensureRoom(),
      throwsA(isA<DioException>()),
    );
  });
}

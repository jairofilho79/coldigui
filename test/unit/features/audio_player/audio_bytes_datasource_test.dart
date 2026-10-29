import 'dart:typed_data';

import 'package:coldigui/core/network/retry_interceptor.dart';
import 'package:coldigui/features/audio_player/data/datasources/audio_bytes_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _BytesAdapter implements HttpClientAdapter {
  _BytesAdapter(this.bytes);
  final List<int> bytes;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    last = options;
    return ResponseBody.fromBytes(Uint8List.fromList(bytes), 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('web: proxy /api/coldigom/<key>, timeout de 120 s, retry do interceptor desligado', () async {
    final adapter = _BytesAdapter([1, 2, 3]);
    final dio = Dio()..httpClientAdapter = adapter;
    final ds = AudioBytesDatasource(
      dio,
      apiBase: 'https://plpcg.test',
      isWeb: true,
    );

    final bytes = await ds.fetch('assets/praises/p1/m1.mp3');

    expect(bytes, [1, 2, 3]);
    expect(
      adapter.last!.uri.toString(),
      'https://plpcg.test/api/coldigom/assets/praises/p1/m1.mp3',
    );
    expect(adapter.last!.receiveTimeout, const Duration(seconds: 120));
    expect(adapter.last!.extra[RetryInterceptor.disableKey], isTrue);
    expect(adapter.last!.responseType, ResponseType.bytes);
  });

  test('nativo: URL direta do worker', () async {
    final adapter = _BytesAdapter([9]);
    final dio = Dio()..httpClientAdapter = adapter;
    final ds = AudioBytesDatasource(
      dio,
      apiBase: 'https://plpcg.test',
      isWeb: false,
    );

    await ds.fetch('assets/praises/p1/m1.mp3');

    expect(adapter.last!.uri.toString(), isNot(contains('/api/coldigom/')));
    expect(adapter.last!.uri.path, endsWith('assets/praises/p1/m1.mp3'));
  });

  test('corpo vazio lança', () async {
    final dio = Dio()..httpClientAdapter = _BytesAdapter(const []);
    final ds = AudioBytesDatasource(dio, apiBase: '', isWeb: false);

    expect(ds.fetch('k'), throwsA(isA<StateError>()));
  });
}

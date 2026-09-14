import 'dart:convert';
import 'dart:typed_data';

import 'package:coldigui/features/playlists/data/datasources/share_link_shortener_remote.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adapter que devolve sempre a mesma resposta, sem tocar na rede.
class _FixedAdapter implements HttpClientAdapter {
  _FixedAdapter(this.statusCode, this.body);

  final int statusCode;
  final Object? body;

  /// Última requisição vista — é como o teste inspeciona headers/corpo.
  RequestOptions? lastRequest;
  Object? lastRequestBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    lastRequestBody = options.data;
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

/// Adapter que sempre lança — simula rede fora do ar / timeout (o runner de
/// testes não espera 3s de verdade: o `DioException` é sintetizado, como em
/// `test/unit/core/network/retry_interceptor_test.dart`).
class _ThrowingAdapter implements HttpClientAdapter {
  _ThrowingAdapter(this.type);

  final DioExceptionType type;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(requestOptions: options, type: type);
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioWith(HttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  test('POST /api/links com {query} e Authorization; devolve url', () async {
    final adapter = _FixedAdapter(201, {
      'code': 'abc1234',
      'url': 'https://plpcg.com/l/abc1234',
    });
    final shortener = ShareLinkShortenerRemote(
      _dioWith(adapter),
      sessionToken: () => 'tok-123',
    );

    final url = await shortener.shorten('shareitems=p%3Aa&sharename=Ensaio');

    expect(url, 'https://plpcg.com/l/abc1234');
    expect(adapter.lastRequest?.path, '/api/links');
    expect(adapter.lastRequest?.method, 'POST');
    expect(adapter.lastRequest?.headers['Authorization'], 'Bearer tok-123');
    expect(adapter.lastRequestBody, {
      'query': 'shareitems=p%3Aa&sharename=Ensaio',
    });
  });

  test('aceita 200 (reuso) do mesmo jeito que 201 (novo)', () async {
    final adapter = _FixedAdapter(200, {
      'code': 'abc1234',
      'url': 'https://plpcg.com/l/abc1234',
    });
    final shortener = ShareLinkShortenerRemote(
      _dioWith(adapter),
      sessionToken: () => 'tok-123',
    );

    final url = await shortener.shorten('shareitems=p%3Aa');

    expect(url, 'https://plpcg.com/l/abc1234');
  });

  test('sem sessionToken (anônimo) não manda header Authorization', () async {
    final adapter = _FixedAdapter(201, {
      'code': 'abc1234',
      'url': 'https://plpcg.com/l/abc1234',
    });
    final shortener = ShareLinkShortenerRemote(
      _dioWith(adapter),
      sessionToken: () => null,
    );

    await shortener.shorten('shareitems=p%3Aa');

    expect(adapter.lastRequest?.headers['Authorization'], isNull);
  });

  test('define sendTimeout/receiveTimeout de 3s por request', () async {
    final adapter = _FixedAdapter(201, {
      'code': 'abc1234',
      'url': 'https://plpcg.com/l/abc1234',
    });
    final shortener = ShareLinkShortenerRemote(
      _dioWith(adapter),
      sessionToken: () => 'tok',
    );

    await shortener.shorten('shareitems=p%3Aa');

    expect(adapter.lastRequest?.sendTimeout, shareLinkShortenerTimeout);
    expect(adapter.lastRequest?.receiveTimeout, shareLinkShortenerTimeout);
  });

  test('lança quando a resposta não tem url', () async {
    final adapter = _FixedAdapter(201, {'code': 'abc1234'});
    final shortener = ShareLinkShortenerRemote(
      _dioWith(adapter),
      sessionToken: () => 'tok',
    );

    expect(
      () => shortener.shorten('shareitems=p%3Aa'),
      throwsA(isA<FormatException>()),
    );
  });

  test('lança DioException em erro de rede/timeout', () async {
    final adapter = _ThrowingAdapter(DioExceptionType.receiveTimeout);
    final shortener = ShareLinkShortenerRemote(
      _dioWith(adapter),
      sessionToken: () => 'tok',
    );

    expect(
      () => shortener.shorten('shareitems=p%3Aa'),
      throwsA(isA<DioException>()),
    );
  });

  test('lança DioException em 4xx/5xx', () async {
    final adapter = _FixedAdapter(429, {'error': 'muitos links'});
    final shortener = ShareLinkShortenerRemote(
      _dioWith(adapter),
      sessionToken: () => 'tok',
    );

    expect(
      () => shortener.shorten('shareitems=p%3Aa'),
      throwsA(isA<DioException>()),
    );
  });
}

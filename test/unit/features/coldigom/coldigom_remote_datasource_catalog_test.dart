import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/features/coldigom/data/constants/coldigom_endpoints.dart';
import 'package:coldigui/features/coldigom/data/datasources/coldigom_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adapter fixo: devolve [statusCode] + [body] e guarda a última request.
class _FixedAdapter implements HttpClientAdapter {
  _FixedAdapter(this.statusCode, this.body, {this.etag});

  final int statusCode;
  final String body;
  final String? etag;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        if (etag != null) 'etag': [etag!],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

String _fixture() =>
    File('test/fixtures/coldigom_catalog_sample.json').readAsStringSync();

void main() {
  test('200 devolve ColdigomCatalogFresh com catálogo e etag', () async {
    final adapter = _FixedAdapter(200, _fixture(), etag: '"abc123"');
    final dio = Dio(BaseOptions(baseUrl: 'https://coldigom.test'))
      ..httpClientAdapter = adapter;
    final datasource = ColdigomRemoteDatasource(dio);

    final result = await datasource.fetchCatalog();

    expect(result, isA<ColdigomCatalogFresh>());
    final fresh = result as ColdigomCatalogFresh;
    expect(fresh.etag, '"abc123"');
    expect(fresh.catalog.praises, hasLength(3));
    expect(adapter.lastRequest!.path, ColdigomEndpoints.plpcgCatalog);
    expect(adapter.lastRequest!.receiveTimeout, const Duration(seconds: 60));
    expect(adapter.lastRequest!.headers.containsKey('If-None-Match'), isFalse);
  });

  test('manda If-None-Match e trata 304 como não modificado', () async {
    final adapter = _FixedAdapter(304, '', etag: '"abc123"');
    final dio = Dio(BaseOptions(baseUrl: 'https://coldigom.test'))
      ..httpClientAdapter = adapter;
    final datasource = ColdigomRemoteDatasource(dio);

    final result = await datasource.fetchCatalog(ifNoneMatch: '"abc123"');

    expect(result, isA<ColdigomCatalogNotModified>());
    expect(adapter.lastRequest!.headers['If-None-Match'], '"abc123"');
  });

  test('erro HTTP propaga como DioException', () async {
    final adapter = _FixedAdapter(500, jsonEncode({'error': 'x'}));
    final dio = Dio(BaseOptions(baseUrl: 'https://coldigom.test'))
      ..httpClientAdapter = adapter;
    final datasource = ColdigomRemoteDatasource(dio);

    expect(datasource.fetchCatalog(), throwsA(isA<DioException>()));
  });
}

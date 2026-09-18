import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/features/catalog/data/datasources/catalog_remote_datasource.dart';
import 'package:coldigui/features/coldigom/data/constants/coldigom_endpoints.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adapter fixo: devolve [statusCode] + [body] e guarda a última request.
class _FixedAdapter implements HttpClientAdapter {
  _FixedAdapter(this.statusCode, this.body, {this.etag, this.json = true});

  final int statusCode;
  final String body;
  final String? etag;
  final bool json;
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
        Headers.contentTypeHeader: [
          json ? Headers.jsonContentType : 'text/plain',
        ],
        if (etag != null) 'etag': [etag!],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _entry = {
  'nome': 'A Ti Senhor',
  'classificacao': 'Avulsos, GLTM',
  'numero': '',
  'categoria': 'Partitura',
  'pdf': 'https://coldigom.test/assets/praises/p1/m1.pdf',
  'pdfId': 'MzAxMDIwMjUvQSBUaSBTZW5ob3IucGRm',
  'groupId': 'avulso:a-ti-senhor',
  'shortId': '000b',
  'praiseId': 'p1',
  'materialId': 'm1',
};

CatalogRemoteDatasource _datasource(_FixedAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://coldigom.test'))
    ..httpClientAdapter = adapter;
  return CatalogRemoteDatasource(dio);
}

void main() {
  test('manifest: GET /api/plpcg/manifest, parse praiseId e ETag sem aspas',
      () async {
    final adapter = _FixedAdapter(
      200,
      jsonEncode([_entry, {..._entry, 'pdfId': ''}]),
      etag: '"abc123"',
    );

    final result = await _datasource(adapter).fetchManifestConditional();

    expect(adapter.lastRequest!.path, ColdigomEndpoints.plpcgManifest);
    expect(adapter.lastRequest!.headers.containsKey('If-None-Match'), isFalse);
    expect(result.etag, 'abc123');
    expect(result.louvores, hasLength(1), reason: 'entrada sem pdfId cai fora');
    final louvor = result.louvores!.single;
    expect(louvor.praiseId, 'p1');
    expect(louvor.materialId, 'm1');
    expect(louvor.pdf, 'https://coldigom.test/assets/praises/p1/m1.pdf');
    expect(louvor.shortId, '000b');
  });

  test('manifest: If-None-Match com aspas e 304 → notModified', () async {
    final adapter = _FixedAdapter(304, '');

    final result =
        await _datasource(adapter).fetchManifestConditional(ifNoneMatch: 'abc');

    expect(adapter.lastRequest!.headers['If-None-Match'], '"abc"');
    expect(result.louvores, isNull);
  });

  test('checksum: GET /api/plpcg/manifest/checksum devolve changed com hex',
      () async {
    final adapter = _FixedAdapter(200, 'deadbeef\n', json: false);

    final result = await _datasource(adapter).fetchChecksumConditional();

    expect(adapter.lastRequest!.path, ColdigomEndpoints.plpcgManifestChecksum);
    expect(result.status, ManifestChecksumStatus.changed);
    expect(result.checksum, 'deadbeef');
  });

  test('checksum: 204 com If-None-Match → unchanged', () async {
    final adapter = _FixedAdapter(204, '', json: false);

    final result = await _datasource(adapter)
        .fetchChecksumConditional(ifNoneMatch: 'deadbeef');

    expect(adapter.lastRequest!.headers['If-None-Match'], '"deadbeef"');
    expect(result.isUnchanged, isTrue);
  });

  test('checksum: falha de rede → unavailable, sem lançar', () async {
    final adapter = _FixedAdapter(500, 'boom', json: false);

    final result = await _datasource(adapter).fetchChecksumConditional();

    expect(result.status, ManifestChecksumStatus.unavailable);
  });

  test('fixture real: entradas duplicadas e sem praiseId passam pelo parser', () async {
    final adapter = _FixedAdapter(
      200,
      File('test/fixtures/manifest_coldigom_sample.json').readAsStringSync(),
    );

    final result = await _datasource(adapter).fetchManifestConditional();

    final louvores = result.louvores!;
    expect(louvores, hasLength(6));
    expect(louvores.where((l) => l.materialId == 'mp'), hasLength(2));
    expect(louvores.where((l) => l.praiseId == null), hasLength(1));
    expect(louvores.map((l) => l.effectiveGroupId).toSet(), contains('pf'));
  });
}

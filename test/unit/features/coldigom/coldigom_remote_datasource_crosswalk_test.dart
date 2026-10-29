import 'dart:convert';
import 'dart:typed_data';

import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/coldigom/data/constants/coldigom_endpoints.dart';
import 'package:coldigui/features/coldigom/data/datasources/coldigom_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Crosswalk falso: responde `items` para os ids de [urls] e guarda os pedidos.
/// [failOnCall] (1-based) devolve 500 nessa chamada.
class _CrosswalkAdapter implements HttpClientAdapter {
  _CrosswalkAdapter(this.urls, {this.failOnCall});

  final Map<String, String> urls;
  final int? failOnCall;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requests.length == failOnCall) {
      return ResponseBody.fromString(
        jsonEncode({'error': 'x'}),
        500,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    final ids = ((options.data as Map)['pdfIds'] as List).cast<String>();
    final items = {
      for (final id in ids)
        if (urls.containsKey(id))
          id: {'praiseId': 'p', 'materialId': 'm', 'url': urls[id]},
    };
    return ResponseBody.fromString(
      jsonEncode({'items': items}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Adapter fixo: devolve sempre [body] com [statusCode] 200.
class _FixedBodyAdapter implements HttpClientAdapter {
  _FixedBodyAdapter(this.body);

  final String body;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ColdigomRemoteDatasource _datasource(HttpClientAdapter adapter) =>
    ColdigomRemoteDatasource(
      Dio(BaseOptions(baseUrl: 'https://coldigom.test'))
        ..httpClientAdapter = adapter,
    );

void main() {
  final legadoA = encodePdfId('ColAdultos/001.pdf');
  final legadoMovido = encodePdfId('ColAdultos/002.pdf');
  final legadoSemPraise = encodePdfId('ColAdultos/003.pdf');
  final desconhecido = encodePdfId('ColAdultos/999.pdf');

  test(
    'POST no endpoint; id coldigom sai da URL; desconhecidos omitidos',
    () async {
      final adapter = _CrosswalkAdapter({
        legadoA: 'https://coldigom.test/assets/praises/p1/m1.pdf',
        // Material movido: o praise da resposta é outro, a URL manda.
        legadoMovido: 'https://coldigom.test/assets/praises/p9/m2.pdf',
        legadoSemPraise: 'https://coldigom.test/outra/coisa.pdf',
      });

      final resolved = await _datasource(adapter).resolveLegacyPdfIds([
        legadoA,
        legadoMovido,
        legadoSemPraise,
        desconhecido,
      ]);

      expect(resolved, {
        legadoA: encodePdfId('assets/praises/p1/m1.pdf'),
        legadoMovido: encodePdfId('assets/praises/p9/m2.pdf'),
      });
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, ColdigomEndpoints.plpcgCrosswalk);
    },
  );

  test('lotes de 500, sem repetidos', () async {
    final ids = [
      for (var i = 0; i < 1201; i++) encodePdfId('ColAdultos/$i.pdf'),
    ];
    final adapter = _CrosswalkAdapter(const {});

    await _datasource(adapter).resolveLegacyPdfIds([...ids, ids.first]);

    expect(
      adapter.requests.map((r) => ((r.data as Map)['pdfIds'] as List).length),
      [500, 500, 201],
    );
  });

  test('sem ids não toca a rede', () async {
    final adapter = _CrosswalkAdapter(const {});

    expect(await _datasource(adapter).resolveLegacyPdfIds(const []), isEmpty);
    expect(adapter.requests, isEmpty);
  });

  test('erro HTTP num lote propaga — sem resultado parcial', () async {
    final ids = [
      for (var i = 0; i < 1100; i++) encodePdfId('ColAdultos/$i.pdf'),
    ];
    final adapter = _CrosswalkAdapter({
      ids.first: 'https://coldigom.test/assets/praises/p1/m1.pdf',
    }, failOnCall: 2);

    await expectLater(
      _datasource(adapter).resolveLegacyPdfIds(ids),
      throwsA(isA<DioException>()),
    );
  });

  test('200 sem `items` mapa válido (ausente/null/tipo errado) lança — '
      'nunca vira "todos desconhecidos" (ruling pre-flight 5.2)', () async {
    for (final body in [
      jsonEncode({'ok': true}), // items ausente
      jsonEncode({'items': null}), // items null
      jsonEncode({'items': 'not-a-map'}), // items não é mapa
    ]) {
      final adapter = _FixedBodyAdapter(body);

      await expectLater(
        _datasource(adapter).resolveLegacyPdfIds([legadoA]),
        throwsA(isA<DioException>()),
        reason: 'body: $body',
      );
    }
  });
}

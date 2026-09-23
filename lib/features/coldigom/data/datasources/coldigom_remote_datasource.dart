import 'dart:math' show min;

import 'package:dio/dio.dart';

import '../../../../core/utils/pdf_id_codec.dart';
import '../constants/coldigom_endpoints.dart';
import '../models/coldigom_catalog_dto.dart';
import '../models/praise_dto.dart';

/// Query params de listagem `/api/praises` (filtros server-side).
class ColdigomPraisesQuery {
  const ColdigomPraisesQuery({
    this.q,
    this.tonalities = const {},
    this.rhythms = const {},
    this.categories = const {},
    this.tagIds = const {},
    this.materialKindIds = const {},
    this.page = 1,
    this.limit = 20,
    this.sort = 'number',
    this.order = 'asc',
  });

  final String? q;
  final Set<String> tonalities;
  final Set<String> rhythms;
  final Set<String> categories;
  final Set<String> tagIds;
  final Set<String> materialKindIds;
  final int page;
  final int limit;
  final String sort;
  final String order;

  Map<String, dynamic> toQueryParameters() {
    final params = <String, dynamic>{
      'page': page < 1 ? 1 : page,
      'limit': limit < 1 ? 20 : limit,
      'sort': sort,
      'order': order,
    };
    final trimmed = q?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      params['q'] = trimmed;
    }
    _putCsv(params, 'tonality', tonalities);
    _putCsv(params, 'rhythm', rhythms);
    _putCsv(params, 'category', categories);
    _putCsv(params, 'tags', tagIds);
    _putCsv(params, 'materialKinds', materialKindIds);
    return params;
  }

  static void _putCsv(
    Map<String, dynamic> params,
    String key,
    Set<String> values,
  ) {
    if (values.isEmpty) return;
    params[key] = values.join(',');
  }
}

/// Resultado de [ColdigomRemoteDatasource.fetchCatalog].
///
/// `sealed` para o use case de sync ter de tratar os dois desfechos —
/// «não mudou» não é erro, é a resposta mais comum.
sealed class ColdigomCatalogFetchResult {
  const ColdigomCatalogFetchResult();
}

/// `304` — o ETag local ainda é o do servidor; nada a gravar.
final class ColdigomCatalogNotModified extends ColdigomCatalogFetchResult {
  const ColdigomCatalogNotModified();
}

/// `200` — catálogo novo e o ETag que o acompanha (para o próximo pedido).
final class ColdigomCatalogFresh extends ColdigomCatalogFetchResult {
  const ColdigomCatalogFresh({required this.catalog, required this.etag});

  final ColdigomCatalogDto catalog;
  final String? etag;
}

/// Cliente HTTP da API coldigom (busca, catálogo, detalhe e kinds).
class ColdigomRemoteDatasource {
  const ColdigomRemoteDatasource(this._dio);

  final Dio _dio;

  /// Lista louvores com filtros server-side (`GET /api/praises`).
  ///
  /// [query.q] pode ser vazio — browse da biblioteca.
  Future<PraisesPageDto> listPraises(ColdigomPraisesQuery query) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ColdigomEndpoints.praises,
      queryParameters: query.toQueryParameters(),
    );

    final data = response.data;
    if (data == null) {
      return const PraisesPageDto(
        data: [],
        pagination: PraisesPaginationDto(
          page: 1,
          limit: 20,
          total: 0,
          totalPages: 1,
        ),
      );
    }

    return PraisesPageDto.fromJson(data);
  }

  /// Listagem PLPCG com materials slim (`GET /api/plpcg/praises`).
  ///
  /// Busca `q` ainda encontra por letra no servidor; a resposta traz um
  /// trecho curto (`lyrics_excerpt`, uma linha) quando o match foi na letra
  /// — nunca o texto completo. [cancelToken] aborta a requisição de verdade (a busca
  /// da Home cancela a página anterior a cada tecla nova); cancelar faz o Dio
  /// lançar `DioException` com `type == DioExceptionType.cancel`.
  Future<PlpcgPraisesPageDto> listPlpcgPraises(
    ColdigomPraisesQuery query, {
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ColdigomEndpoints.plpcgPraises,
      queryParameters: query.toQueryParameters(),
      cancelToken: cancelToken,
    );

    final data = response.data;
    if (data == null) {
      return const PlpcgPraisesPageDto(
        data: [],
        pagination: PraisesPaginationDto(
          page: 1,
          limit: 20,
          total: 0,
          totalPages: 1,
        ),
      );
    }

    return PlpcgPraisesPageDto.fromJson(data);
  }

  /// Dump do catálogo (`GET /api/plpcg/catalog`) com revalidação por ETag.
  ///
  /// [ifNoneMatch] é o ETag guardado do último sync; o Worker responde `304`
  /// sem corpo quando nada mudou. O `receiveTimeout` sobe para 60 s só aqui:
  /// o corpo tem ~2,5 MB (gzip ~500 KB) e o padrão de 30 s do
  /// `coldigomDioProvider` foi pensado para páginas de 20 itens.
  Future<ColdigomCatalogFetchResult> fetchCatalog({String? ifNoneMatch}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ColdigomEndpoints.plpcgCatalog,
      options: Options(
        receiveTimeout: const Duration(seconds: 60),
        headers: {'If-None-Match': ?ifNoneMatch},
        // 304 não é erro: sem isto o Dio lança `DioException.badResponse`.
        validateStatus: (status) => status == 200 || status == 304,
      ),
    );

    if (response.statusCode == 304) return const ColdigomCatalogNotModified();

    final data = response.data;
    if (data == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Resposta vazia do catálogo coldigom',
      );
    }
    return ColdigomCatalogFresh(
      catalog: ColdigomCatalogDto.fromJson(data),
      etag: response.headers.value('etag'),
    );
  }

  /// Tamanho máximo de um pedido ao crosswalk (o servidor devolve 400 acima).
  static const int crosswalkBatchSize = 500;

  /// Id coldigom de cada id legado de [legacyPdfIds] (contrato C9).
  ///
  /// `POST /api/plpcg/crosswalk` em lotes de [crosswalkBatchSize]. O id
  /// coldigom sai da `url` real do material ([coldigomPdfIdFromAssetUrl]) —
  /// é ela que acerta os materiais movidos. Desconhecidos (e URLs fora de
  /// `assets/praises/`) ficam de fora do mapa.
  ///
  /// Um erro HTTP em qualquer lote propaga como [DioException]: quem chama
  /// trata a rodada inteira como pendente, nunca um resultado parcial. Um
  /// `200` cujo corpo não traz um `items` mapa válido (ausente, `null` ou de
  /// outro tipo) também lança — nunca é tratado como "todos desconhecidos":
  /// quem chama apaga linhas do índice offline e prefs para ids
  /// desconhecidos, e um corpo malformado não pode disparar isso.
  Future<Map<String, String>> resolveLegacyPdfIds(
    Iterable<String> legacyPdfIds,
  ) async {
    final ids = legacyPdfIds.toSet().toList(growable: false);
    final resolved = <String, String>{};
    for (var start = 0; start < ids.length; start += crosswalkBatchSize) {
      final batch = ids.sublist(
        start,
        min(start + crosswalkBatchSize, ids.length),
      );
      final asked = batch.toSet();
      final response = await _dio.post<Map<String, dynamic>>(
        ColdigomEndpoints.plpcgCrosswalk,
        data: {'pdfIds': batch},
      );
      final items = response.data?['items'];
      if (items is! Map) {
        throw DioException(
          requestOptions: response.requestOptions,
          message: 'Resposta do crosswalk sem `items` mapa válido',
        );
      }
      for (final MapEntry(:key, :value) in items.entries) {
        if (key is! String || !asked.contains(key) || value is! Map) continue;
        final url = value['url'];
        if (url is! String) continue;
        final coldigomId = coldigomPdfIdFromAssetUrl(url);
        if (coldigomId != null) resolved[key] = coldigomId;
      }
    }
    return resolved;
  }

  /// Busca louvores por texto (`GET /api/praises?q=`).
  ///
  /// Mantido para compat; internamente usa [listPraises].
  Future<List<PraiseSummaryDto>> search({
    required String query,
    int limit = 20,
    int page = 1,
  }) async {
    final pageDto = await listPraises(
      ColdigomPraisesQuery(q: query, limit: limit, page: page),
    );
    return pageDto.data;
  }

  /// Detalhe com materiais (`GET /api/praises/:id`).
  Future<PraiseDetailDto> fetchDetail(String praiseId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ColdigomEndpoints.praiseDetail(praiseId),
    );

    final data = response.data;
    if (data == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Resposta vazia do coldigom',
      );
    }

    return PraiseDetailResponseDto.fromJson(data).data;
  }

  /// Kinds de material (`GET /api/materials/kinds`).
  Future<List<ColdigomMaterialKindDto>> fetchMaterialKinds() async {
    final response = await _dio.get<Map<String, dynamic>>(
      ColdigomEndpoints.materialKinds,
    );
    final data = response.data;
    if (data == null) return const [];
    final list = data['data'] as List<dynamic>? ?? const [];
    return [
      for (final item in list)
        ColdigomMaterialKindDto.fromJson(item as Map<String, dynamic>),
    ];
  }

  /// Types (`pdf`/`chord`/...) que de fato existem entre os materiais de
  /// [kindId] (`GET /api/materials/kinds/:kindId/types`). Calculado sob
  /// demanda pelo Worker a cada chamada — poucos registros por kind, sem
  /// necessidade de cache local.
  Future<List<String>> fetchMaterialTypesForKind(String kindId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ColdigomEndpoints.materialTypesForKind(kindId),
    );
    final data = response.data;
    if (data == null) return const [];
    final list = data['data'] as List<dynamic>? ?? const [];
    return list.whereType<String>().toList(growable: false);
  }
}

import 'package:dio/dio.dart';

import '../constants/coldigom_endpoints.dart';
import '../models/praise_dto.dart';

/// Cliente HTTP da API coldigom (busca e detalhe de louvores).
class ColdigomRemoteDatasource {
  const ColdigomRemoteDatasource(this._dio);

  final Dio _dio;

  /// Busca louvores por texto (`GET /api/praises?q=`).
  Future<List<PraiseSummaryDto>> search({
    required String query,
    int limit = 20,
    int page = 1,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ColdigomEndpoints.praises,
      queryParameters: {'q': query, 'limit': limit, 'page': page},
    );

    final data = response.data;
    if (data == null) return const [];

    return PraisesSearchResponseDto.fromJson(data).data;
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
}

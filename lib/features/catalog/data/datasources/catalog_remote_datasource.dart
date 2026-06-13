import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_config.dart';
import '../../domain/entities/louvor.dart';
import '../models/louvor_dto.dart';

/// Fonte remota do catálogo (Worker + D1) — UC-12.
///
/// Baixa `/api/catalog/louvores` via [Dio] e valida entradas antes de retornar.
class CatalogRemoteDatasource {
  const CatalogRemoteDatasource(this._dio);

  final Dio _dio;

  /// Baixa `/api/catalog/louvores` (Worker + D1), valida shape e filtra entradas inválidas.
  ///
  /// Entradas sem [Louvor.pdfId] não vazio ou com campos obrigatórios ausentes
  /// são ignoradas (paridade com `prepareLouvoresManifestPayload` do Svelte).
  Future<List<Louvor>> fetchManifest() async {
    if (AppConfig.apiBaseUrl.isEmpty) {
      throw StateError(
        'PLPCG_API_BASE_URL não definido. '
        'Use --dart-define=PLPCG_API_BASE_URL=https://...',
      );
    }

    final response = await _dio.get<dynamic>(ApiEndpoints.louvoresManifest);
    final data = response.data;

    if (data is! List) {
      throw const FormatException(
        'Resposta do catálogo deve ser um array JSON',
      );
    }

    final louvores = <Louvor>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;

      final pdfId = item['pdfId'];
      if (pdfId is! String || pdfId.isEmpty) continue;

      try {
        louvores.add(LouvorDto.fromJson(item).toEntity());
      } on Object {
        continue;
      }
    }

    return louvores;
  }

  /// Consulta `/api/catalog/checksum` (Worker + D1).
  ///
  /// Retorna hex SHA-256 em `200`; `null` se `204` (inalterado, header `If-None-Match`)
  /// ou em falha de rede.
  Future<String?> fetchChecksum() async {
    try {
      final response = await _dio.get<String>(
        ApiEndpoints.louvoresManifestChecksum,
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (status) => status == 200 || status == 204,
        ),
      );

      if (response.statusCode == 204) return null;
      return response.data?.trim();
    } on Object {
      return null;
    }
  }
}

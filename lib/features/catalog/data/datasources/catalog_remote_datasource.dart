import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_config.dart';
import '../../domain/entities/louvor.dart';
import '../models/louvor_dto.dart';

/// Fonte remota do catálogo (R2 / Cloudflare) — UC-12.
///
/// Baixa `louvores-manifest.json` via [Dio] e valida entradas antes de retornar.
class CatalogRemoteDatasource {
  const CatalogRemoteDatasource(this._dio);

  final Dio _dio;

  /// Baixa `louvores-manifest.json`, valida shape e filtra entradas inválidas.
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
        'louvores-manifest.json deve ser um array JSON',
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

  /// Consulta `/louvores-manifest.sha256`; retorna `null` se inalterado (204).
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

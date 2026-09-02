import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_config.dart';
import '../../domain/entities/louvor.dart';
import '../models/louvor_dto.dart';

/// Desfecho da consulta condicional a `/api/catalog/checksum` (UC-12).
enum ManifestChecksumStatus {
  /// `204`/`304` — o checksum enviado em `If-None-Match` continua válido.
  unchanged,

  /// `200` — o Worker devolveu um checksum diferente do enviado.
  changed,

  /// `503 checksum not configured` ou falha de rede — indecidível.
  ///
  /// Deve ser tratado como possível mudança (baixar o manifest).
  unavailable,
}

/// Resposta de `/api/catalog/checksum` com `If-None-Match` condicional.
@immutable
class ManifestChecksumResult {
  const ManifestChecksumResult(this.status, {this.checksum});

  final ManifestChecksumStatus status;

  /// Hex SHA-256 novo — preenchido só em [ManifestChecksumStatus.changed].
  final String? checksum;

  /// `true` quando o catálogo remoto é comprovadamente o mesmo já em cache.
  bool get isUnchanged => status == ManifestChecksumStatus.unchanged;
}

/// Resposta condicional de `/api/catalog/louvores` (UC-12).
@immutable
class ManifestFetchResult {
  const ManifestFetchResult({required this.louvores, this.etag});

  /// Manifest recebido; `null` quando o Worker respondeu `304 Not Modified`.
  const ManifestFetchResult.notModified() : louvores = null, etag = null;

  final List<Louvor>? louvores;

  /// Checksum extraído do header `ETag`, quando o Worker o expõe.
  final String? etag;
}

/// Fonte remota do catálogo (Worker + D1) — UC-12.
///
/// Baixa `/api/catalog/louvores` via [Dio] e valida entradas antes de retornar.
/// As variantes condicionais enviam `If-None-Match` para que o Worker possa
/// responder `304`/`204` e evitar o download de ~4600 itens (A1).
class CatalogRemoteDatasource {
  const CatalogRemoteDatasource(this._dio);

  final Dio _dio;

  /// Baixa `/api/catalog/louvores` (Worker + D1), valida shape e filtra entradas inválidas.
  ///
  /// Entradas sem [Louvor.pdfId] não vazio ou com campos obrigatórios ausentes
  /// são ignoradas (paridade com `prepareLouvoresManifestPayload` do Svelte).
  Future<List<Louvor>> fetchManifest() async {
    final result = await fetchManifestConditional();
    return result.louvores ?? const [];
  }

  /// Variante condicional de [fetchManifest] com `If-None-Match`.
  ///
  /// Retorna [ManifestFetchResult.notModified] em `304` — o chamador deve
  /// reaproveitar o cache Isar sem reescrevê-lo.
  Future<ManifestFetchResult> fetchManifestConditional({
    String? ifNoneMatch,
  }) async {
    if (AppConfig.apiBaseUrl.isEmpty) {
      throw StateError(
        'PLPCG_API_BASE_URL não definido. '
        'Use --dart-define=PLPCG_API_BASE_URL=https://...',
      );
    }

    final response = await _dio.get<dynamic>(
      ApiEndpoints.louvoresManifest,
      options: Options(
        headers: _ifNoneMatchHeaders(ifNoneMatch),
        validateStatus: (status) =>
            status != null &&
            (status == 304 || (status >= 200 && status < 300)),
      ),
    );

    if (response.statusCode == 304) {
      return const ManifestFetchResult.notModified();
    }

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

    return ManifestFetchResult(louvores: louvores, etag: _readEtag(response));
  }

  /// Consulta `/api/catalog/checksum` (Worker + D1).
  ///
  /// Retorna hex SHA-256 em `200`; `null` se `204` (inalterado, header `If-None-Match`)
  /// ou em falha de rede.
  Future<String?> fetchChecksum() async {
    final result = await fetchChecksumConditional();
    return result.checksum;
  }

  /// Variante condicional de [fetchChecksum] que distingue `204` de falha.
  ///
  /// Envia [ifNoneMatch] como `If-None-Match` quando informado; só assim o
  /// Worker pode responder `204` e dispensar o download do manifest (A1).
  Future<ManifestChecksumResult> fetchChecksumConditional({
    String? ifNoneMatch,
  }) async {
    try {
      final response = await _dio.get<String>(
        ApiEndpoints.louvoresManifestChecksum,
        options: Options(
          responseType: ResponseType.plain,
          headers: _ifNoneMatchHeaders(ifNoneMatch),
          validateStatus: (status) =>
              status == 200 || status == 204 || status == 304,
        ),
      );

      if (response.statusCode == 204 || response.statusCode == 304) {
        return const ManifestChecksumResult(ManifestChecksumStatus.unchanged);
      }

      final checksum = response.data?.trim();
      if (checksum == null || checksum.isEmpty) {
        debugPrint('[catalog] checksum remoto vazio — tratando como mudança');
        return const ManifestChecksumResult(ManifestChecksumStatus.unavailable);
      }

      if (ifNoneMatch != null && checksum == ifNoneMatch) {
        return const ManifestChecksumResult(ManifestChecksumStatus.unchanged);
      }

      return ManifestChecksumResult(
        ManifestChecksumStatus.changed,
        checksum: checksum,
      );
    } on Object catch (error) {
      debugPrint('[catalog] checksum indisponível: $error');
      return const ManifestChecksumResult(ManifestChecksumStatus.unavailable);
    }
  }

  /// `If-None-Match` no formato de ETag forte esperado pelo Worker.
  static Map<String, String>? _ifNoneMatchHeaders(String? checksum) {
    if (checksum == null || checksum.isEmpty) return null;
    return <String, String>{'If-None-Match': '"$checksum"'};
  }

  /// Lê o header `ETag` e devolve o checksum sem aspas.
  ///
  /// `null` quando o Worker não envia o header ou o CORS não o expõe.
  static String? _readEtag(Response<dynamic> response) {
    final raw = response.headers.value('etag')?.trim();
    if (raw == null || raw.isEmpty) return null;
    final unquoted = raw.startsWith('W/') ? raw.substring(2) : raw;
    final value = unquoted.replaceAll('"', '').trim();
    return value.isEmpty ? null : value;
  }
}

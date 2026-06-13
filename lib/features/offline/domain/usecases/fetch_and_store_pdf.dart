import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/offline_config.dart';
import '../../../pdf_opening/data/datasources/pdf_bytes_datasource.dart';
import '../entities/local_pdf_source.dart';
import '../repositories/offline_pdf_repository.dart';
import '../utils/offline_category_resolver.dart';

/// Cache on-demand: baixa PDF remoto, persiste em disco e indexa no Isar (Fase 3.3).
///
/// Fluxo: [PdfBytesDatasource.fetchBytes] → [OfflinePdfRepository.upsert]
/// (escrita atômica em `documents/plpcg_pdfs/`) → [LocalPdfSource] `fromCache: false`.
///
/// Chamado por [ResolvePdfForReader] em miss com rede. Falhas transitórias de rede
/// e HTTP ≥ 500 são retentadas até [OfflineConfig.maxRetryAttempts]; 4xx falham
/// imediatamente. Exceções de rede propagam como [DioException] para o resolver.
///
/// DI: [fetchAndStorePdfProvider].
class FetchAndStorePdf {
  /// [bytesDatasource] — HTTP remoto via Dio (compartilhado com UC-04/11).
  /// [repository] — escrita atômica + upsert [OfflinePdfIndex].
  const FetchAndStorePdf(this._bytesDatasource, this._repository);

  final PdfBytesDatasource _bytesDatasource;
  final OfflinePdfRepository _repository;

  /// Baixa [remotePath], persiste em [PdfLocalStore] e retorna path absoluto local.
  ///
  /// [pdfId] — identificador Base64 URL-safe do manifest.
  /// [remotePath] — path para [PdfBytesDatasource], ex.: `/assets/ColAdultos/001.pdf`
  /// (via [LouvorPdfPath.fromLouvor]).
  /// [category] — classificação Isar; se `null`, derivada do primeiro segmento de
  /// [PdfPathNormalizer.getPdfRelPath] (ex.: `ColAdultos`).
  Future<LocalPdfSource> call({
    required String pdfId,
    required String remotePath,
    String? category,
  }) async {
    final resolvedCategory =
        category ?? OfflineCategoryResolver.fromPdfId(pdfId);
    final bytes = await _fetchBytesWithRetry(remotePath);
    final entry = await _repository.upsert(
      pdfId: pdfId,
      bytes: bytes,
      category: resolvedCategory,
    );

    return LocalPdfSource(
      pdfId: pdfId,
      absolutePath: entry.absolutePath,
      fromCache: false,
    );
  }

  Future<Uint8List> _fetchBytesWithRetry(String remotePath) async {
    Object? lastError;

    for (var attempt = 1;
        attempt <= OfflineConfig.maxRetryAttempts;
        attempt++) {
      try {
        return await _bytesDatasource.fetchBytes(remotePath);
      } on DioException catch (e) {
        lastError = e;
        if (!_isRetryable(e) || attempt >= OfflineConfig.maxRetryAttempts) {
          rethrow;
        }
        await Future<void>.delayed(retryDelayForAttempt(attempt));
      } on Object catch (e) {
        lastError = e;
        rethrow;
      }
    }

    throw lastError ?? StateError('fetchBytes falhou sem erro capturado');
  }

  static bool _isRetryable(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return true;
    }

    final statusCode = e.response?.statusCode;
    return statusCode != null && statusCode >= 500;
  }
}

/// Backoff exponencial com jitter (±30%) para retentativas de fetch on-demand.
@visibleForTesting
Duration retryDelayForAttempt(int attempt, [Random? random]) {
  final jitter = (random ?? Random()).nextDouble() * 0.3;
  final delay =
      OfflineConfig.retryBackoffBase * (1 << (attempt - 1)) * (1.0 + jitter);
  if (delay > OfflineConfig.maxRetryDelay) {
    return OfflineConfig.maxRetryDelay;
  }
  if (delay < Duration.zero) {
    return Duration.zero;
  }
  return delay;
}

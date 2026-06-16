import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/offline_config.dart';
import '../../../pdf_opening/data/datasources/pdf_bytes_datasource.dart';
import '../../data/datasources/disk_space_checker.dart';
import '../../data/datasources/favorite_pdf_ids_resolver.dart';
import '../entities/local_pdf_source.dart';
import '../exceptions/offline_bulk_exceptions.dart';
import '../repositories/offline_pdf_repository.dart';
import '../utils/download_retry.dart';
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
  const FetchAndStorePdf(
    this._bytesDatasource,
    this._repository, {
    required DiskSpaceChecker diskSpaceChecker,
    required FavoritePdfIdsResolver favoritePdfIdsResolver,
    this.cacheQuotaBytes = OfflineConfig.defaultPdfCacheQuotaBytes,
  })  : _diskSpaceChecker = diskSpaceChecker,
        _favoritePdfIdsResolver = favoritePdfIdsResolver;

  final PdfBytesDatasource _bytesDatasource;
  final OfflinePdfRepository _repository;
  final DiskSpaceChecker _diskSpaceChecker;
  final FavoritePdfIdsResolver _favoritePdfIdsResolver;

  /// Quota LRU do cache on-demand — override em testes.
  final int cacheQuotaBytes;

  /// Baixa [remotePath], persiste em [PdfLocalStore] e retorna path absoluto local.
  ///
  /// [pdfId] — identificador Base64 URL-safe do manifest.
  /// [remotePath] — path para [PdfBytesDatasource], ex.: `/assets/ColAdultos/001.pdf`
  /// (via [LouvorPdfPath.fromLouvor]).
  /// [category] — classificação Isar; se `null`, derivada do primeiro segmento de
  /// [PdfPathNormalizer.getPdfRelPath] (ex.: `ColAdultos`).
  /// [persistentDownload] — quando `true`, omite a eviction LRU e mantém apenas a
  /// guarda de espaço físico em disco. Use em downloads bulk (UC-10 "baixar faltantes")
  /// para evitar que PDFs recém-persistidos sejam deletados para abrir espaço no cache.
  Future<LocalPdfSource> call({
    required String pdfId,
    required String remotePath,
    String? category,
    ProgressCallback? onProgress,
    bool persistentDownload = false,
  }) async {
    final protectedPdfIds = await _favoritePdfIdsResolver.resolve();
    final excludePdfIds = {...protectedPdfIds, pdfId};

    await _ensureDeviceDiskSpace();
    if (!persistentDownload) {
      await _ensureCacheQuota(excludePdfIds: excludePdfIds);
    }

    final resolvedCategory =
        category ?? OfflineCategoryResolver.fromPdfId(pdfId);
    final bytes =
        await _fetchBytesWithRetry(remotePath, onProgress: onProgress);

    await _ensureDeviceDiskSpace(requiredBytes: bytes.length);
    if (!persistentDownload) {
      await _ensureCacheQuota(
        excludePdfIds: excludePdfIds,
        incomingBytes: bytes.length,
      );
    }

    final entry = await _repository.upsert(
      pdfId: pdfId,
      bytes: bytes,
      category: resolvedCategory,
    );

    if (!persistentDownload) {
      await _trimCacheToQuota(excludePdfIds: excludePdfIds);
    }

    return LocalPdfSource(
      pdfId: pdfId,
      absolutePath: entry.absolutePath,
      fromCache: false,
    );
  }

  Future<void> _ensureDeviceDiskSpace({int requiredBytes = 0}) async {
    final freeBytes = await _diskSpaceChecker.getFreeBytes();
    if (freeBytes == null) return;

    final minimumRequired = max(
      OfflineConfig.minFreeDiskSpaceForPdfDownloadBytes,
      (requiredBytes * OfflineConfig.diskSpaceSafetyMargin).round(),
    );

    if (freeBytes < minimumRequired) {
      throw InsufficientDiskSpaceException(
        requiredBytes: minimumRequired,
        availableBytes: freeBytes,
      );
    }
  }

  Future<void> _ensureCacheQuota({
    required Set<String> excludePdfIds,
    int incomingBytes = 0,
  }) async {
    final quota = cacheQuotaBytes;
    var total = await _repository.totalCachedBytes();
    final projected = total + incomingBytes;

    if (projected <= quota) return;

    final bytesToFree = projected - quota;
    await _repository.evictOldestPdfs(
      targetBytes: bytesToFree,
      excludePdfIds: excludePdfIds,
    );
  }

  Future<void> _trimCacheToQuota({required Set<String> excludePdfIds}) async {
    final quota = cacheQuotaBytes;
    var total = await _repository.totalCachedBytes();

    if (total <= quota) return;

    await _repository.evictOldestPdfs(
      targetBytes: total - quota,
      excludePdfIds: excludePdfIds,
    );
  }

  Future<Uint8List> _fetchBytesWithRetry(
    String remotePath, {
    ProgressCallback? onProgress,
  }) async {
    Object? lastError;

    for (var attempt = 1;
        attempt <= OfflineConfig.maxRetryAttempts;
        attempt++) {
      try {
        return await _bytesDatasource.fetchBytes(
          remotePath,
          onReceiveProgress: onProgress,
        );
      } on DioException catch (e) {
        lastError = e;
        if (!isRetryableDioException(e) ||
            attempt >= OfflineConfig.maxRetryAttempts) {
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
}

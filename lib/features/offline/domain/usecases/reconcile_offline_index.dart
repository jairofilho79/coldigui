import 'package:flutter/foundation.dart';

import '../../../../core/constants/offline_config.dart';
import '../ports/pdf_storage_port.dart';
import '../../data/utils/reconcile_path_validator.dart';
import '../entities/offline_manifest.dart';
import '../entities/reconcile_result.dart';
import '../repositories/offline_pdf_repository.dart';
import '../utils/offline_category_resolver.dart';

/// UC-10 — Reconcile índice Isar vs disco (Fase 3.5 mínimo / 3.6 completo).
///
/// Remove entradas Isar sem arquivo válido; opcionalmente remove PDFs órfãos
/// no disco. Validação de disco em isolate via [compute].
class ReconcileOfflineIndex {
  ReconcileOfflineIndex(this._repository, this._store);

  final OfflinePdfRepository _repository;
  final PdfStoragePort _store;

  Future<ReconcileResult> call({
    OfflineMaterialPackage? materialPackage,
    String? materialCategory,
  }) async {
    final scopedPdfIds = _pdfIdsForScope(materialPackage);
    final allEntries = await _repository.listAll();
    final entries = scopedPdfIds == null
        ? allEntries
        : allEntries.where((e) => scopedPdfIds.contains(e.pdfId)).toList();

    final orphanPdfIds = <String>{};
    final indexedPaths = <String>{};
    final chunkSize = OfflineConfig.bulkIsarChunkSize;

    for (var i = 0; i < entries.length; i += chunkSize) {
      final end = (i + chunkSize < entries.length)
          ? i + chunkSize
          : entries.length;
      final chunk = entries.sublist(i, end);

      final pathEntries = chunk
          .map(
            (e) => ReconcilePathEntry(
              pdfId: e.pdfId,
              absolutePath: e.absolutePath,
            ),
          )
          .toList();

      final validation = await compute(validatePdfPathsChunk, pathEntries);
      orphanPdfIds.addAll(validation.invalidPdfIds);
      indexedPaths.addAll(validation.validAbsolutePaths);
    }

    var removedFromIndex = 0;
    if (orphanPdfIds.isNotEmpty) {
      final ids = orphanPdfIds.toList();
      for (var i = 0; i < ids.length; i += chunkSize) {
        final end = (i + chunkSize < ids.length) ? i + chunkSize : ids.length;
        removedFromIndex += await _repository.removeIndexEntries(
          ids.sublist(i, end).toSet(),
        );
      }
    }

    var orphanFiles = 0;
    final isScopedBulk =
        materialCategory != null &&
        scopedPdfIds != null &&
        materialPackage != null;

    if (isScopedBulk) {
      final diskOrphans = await _store.listOrphans(indexedPaths);
      for (final path in diskOrphans) {
        if (_pathBelongsToScope(path, scopedPdfIds)) {
          await _store.delete(path);
          orphanFiles++;
        }
      }
    } else if (scopedPdfIds == null) {
      final diskOrphans = await _store.listOrphans(indexedPaths);
      for (final path in diskOrphans) {
        await _store.delete(path);
        orphanFiles++;
      }
    }

    return ReconcileResult(
      removedFromIndex: removedFromIndex,
      orphanFiles: orphanFiles,
    );
  }

  Set<String>? _pdfIdsForScope(OfflineMaterialPackage? materialPackage) {
    if (materialPackage == null) return null;

    final ids = <String>{};
    for (final part in materialPackage.parts) {
      ids.addAll(part.pdfs);
    }
    return ids;
  }

  bool _pathBelongsToScope(String absolutePath, Set<String> scopedPdfIds) {
    for (final pdfId in scopedPdfIds) {
      final category = OfflineCategoryResolver.fromPdfId(pdfId);
      if (absolutePath.contains('/$category/')) {
        return true;
      }
    }
    return false;
  }
}

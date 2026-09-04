import 'package:flutter/foundation.dart';

import '../../../../core/constants/offline_config.dart';
import '../ports/pdf_storage_port.dart';
import '../../data/utils/reconcile_chunk_validation.dart';
import '../../data/utils/reconcile_path_validator.dart';
import '../entities/offline_manifest.dart';
import '../entities/reconcile_result.dart';
import '../repositories/offline_pdf_repository.dart';
import '../utils/offline_category_resolver.dart';

/// Motivo pelo qual um reconcile não chegou a rodar (spec C.1).
enum ReconcileSkipReason {
  /// Isar não abriu — o índice não é fonte de verdade confiável.
  indexUnavailable,

  /// Índice vazio com arquivos no disco — apagar tudo seria perda de dados.
  emptyIndexWithFiles,

  /// Outro dono segura o lock de manutenção offline.
  locked,
}

/// Resultado de [ReconcileOfflineIndex.call] — concluído ou pulado.
sealed class ReconcileOutcome {
  const ReconcileOutcome();
}

/// Reconcile executado até o fim.
class ReconcileDone extends ReconcileOutcome {
  const ReconcileDone({
    required this.removedFromIndex,
    required this.orphanFiles,
    required this.keptFiles,
  });

  /// Entradas removidas do índice Isar.
  final int removedFromIndex;

  /// Arquivos órfãos apagados do disco.
  final int orphanFiles;

  /// Arquivos indexados e válidos preservados.
  final int keptFiles;

  ReconcileResult get result => ReconcileResult(
    removedFromIndex: removedFromIndex,
    orphanFiles: orphanFiles,
  );
}

/// Reconcile abortado antes de apagar qualquer coisa.
class ReconcileSkipped extends ReconcileOutcome {
  const ReconcileSkipped(this.reason);

  final ReconcileSkipReason reason;
}

/// UC-10 — Reconcile índice Isar vs disco (Fase 3.5 mínimo / 3.6 completo).
///
/// Remove entradas Isar sem arquivo válido; opcionalmente remove PDFs órfãos
/// no disco. Validação de disco em isolate via [compute].
///
/// Reconcile **completo** nunca apaga arquivos quando o índice é indisponível
/// ou está vazio com arquivos no disco (spec C.1 / B5).
class ReconcileOfflineIndex {
  ReconcileOfflineIndex(this._repository, this._store);

  final OfflinePdfRepository _repository;
  final PdfStoragePort _store;

  /// [isIndexAvailable] vem de `isarAvailableProvider`: `false` aborta o
  /// reconcile completo em vez de tratar o disco inteiro como órfão.
  Future<ReconcileOutcome> call({
    OfflineMaterialPackage? materialPackage,
    String? materialCategory,
    bool isIndexAvailable = true,
  }) async {
    final scopedPdfIds = _pdfIdsForScope(materialPackage);
    final isFullReconcile = scopedPdfIds == null;

    if (isFullReconcile && !isIndexAvailable) {
      debugPrint('[offline] reconcile pulado: índice indisponível');
      return const ReconcileSkipped(ReconcileSkipReason.indexUnavailable);
    }

    final allEntries = await _repository.listAll();
    final entries = scopedPdfIds == null
        ? allEntries
        : allEntries.where((e) => scopedPdfIds.contains(e.pdfId)).toList();

    if (isFullReconcile && entries.isEmpty) {
      final filesOnDisk = await _store.listOrphans(const <String>{});
      if (filesOnDisk.isNotEmpty) {
        debugPrint(
          '[offline] reconcile pulado: índice vazio com '
          '${filesOnDisk.length} arquivos no disco',
        );
        return const ReconcileSkipped(ReconcileSkipReason.emptyIndexWithFiles);
      }
    }

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

      final validation = await validateReconcilePathChunk(pathEntries, _store);
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

    // Órfão é arquivo sem **nenhuma** entrada no índice: num reconcile
    // escopado, os PDFs indexados fora do escopo (outro pacote na mesma
    // pasta de categoria) também são protegidos (spec C.1).
    final protectedPaths = <String>{
      ...indexedPaths,
      if (!isFullReconcile)
        for (final entry in allEntries)
          if (!scopedPdfIds.contains(entry.pdfId)) entry.absolutePath,
    };

    if (isScopedBulk) {
      final diskOrphans = await _store.listOrphans(protectedPaths);
      for (final path in diskOrphans) {
        if (_pathBelongsToScope(path, scopedPdfIds)) {
          await _store.delete(path);
          orphanFiles++;
        }
      }
    } else if (scopedPdfIds == null) {
      final diskOrphans = await _store.listOrphans(protectedPaths);
      for (final path in diskOrphans) {
        await _store.delete(path);
        orphanFiles++;
      }
    }

    return ReconcileDone(
      removedFromIndex: removedFromIndex,
      orphanFiles: orphanFiles,
      keptFiles: indexedPaths.length,
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

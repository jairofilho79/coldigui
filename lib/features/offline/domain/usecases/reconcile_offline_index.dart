import 'package:flutter/foundation.dart';

import '../../../../core/constants/offline_config.dart';
import '../ports/pdf_storage_port.dart';
import '../../data/utils/reconcile_chunk_validation.dart';
import '../../data/utils/reconcile_path_validator.dart';
import '../entities/reconcile_result.dart';
import '../repositories/offline_pdf_repository.dart';

/// Motivo pelo qual um reconcile não chegou a rodar (spec C.1).
enum ReconcileSkipReason {
  /// Isar não abriu — o índice não é fonte de verdade confiável.
  indexUnavailable,

  /// Índice vazio com arquivos no disco — apagar tudo seria perda de dados.
  emptyIndexWithFiles,

  /// Índice pequeno demais para o disco (menos da metade dos arquivos): um
  /// Isar truncado transformaria o acervo inteiro em "órfão" (spec D.3).
  indexTooSmall,

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
/// Remove entradas Isar sem arquivo válido e apaga PDFs órfãos no disco.
/// Validação de disco em isolate via [compute].
///
/// Nunca apaga arquivos quando o índice é indisponível, está vazio com
/// arquivos no disco, ou cobre menos da metade do que está no disco
/// (spec C.1 / B5 / D.3).
class ReconcileOfflineIndex {
  ReconcileOfflineIndex(this._repository, this._store);

  final OfflinePdfRepository _repository;
  final PdfStoragePort _store;

  /// [isIndexAvailable] vem de `isarAvailableProvider`: `false` aborta o
  /// reconcile em vez de tratar o disco inteiro como órfão.
  Future<ReconcileOutcome> call({bool isIndexAvailable = true}) async {
    if (!isIndexAvailable) {
      debugPrint('[offline] reconcile pulado: índice indisponível');
      return const ReconcileSkipped(ReconcileSkipReason.indexUnavailable);
    }

    final entries = await _repository.listAll();

    // Um `listOrphans` com proteção vazia é a contagem de tudo que está no
    // disco — a mesma chamada serve às duas guardas.
    final filesOnDisk = await _store.listOrphans(const <String>{});
    if (filesOnDisk.isNotEmpty) {
      if (entries.isEmpty) {
        debugPrint(
          '[offline] reconcile pulado: índice vazio com '
          '${filesOnDisk.length} arquivos no disco',
        );
        return const ReconcileSkipped(ReconcileSkipReason.emptyIndexWithFiles);
      }
      // Índice cobrindo menos da metade do disco é índice truncado, não
      // acervo órfão: apagar a diferença seria perda de dados (spec D.3).
      if (entries.length * 2 < filesOnDisk.length) {
        debugPrint(
          '[offline] reconcile pulado: índice com ${entries.length} '
          'entradas para ${filesOnDisk.length} arquivos no disco',
        );
        return const ReconcileSkipped(ReconcileSkipReason.indexTooSmall);
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

    // Órfão é arquivo sem **nenhuma** entrada válida no índice (spec C.1).
    final protectedPaths = indexedPaths;

    var orphanFiles = 0;
    final diskOrphans = await _store.listOrphans(protectedPaths);
    for (final path in diskOrphans) {
      await _store.delete(path);
      orphanFiles++;
    }

    return ReconcileDone(
      removedFromIndex: removedFromIndex,
      orphanFiles: orphanFiles,
      keptFiles: indexedPaths.length,
    );
  }
}

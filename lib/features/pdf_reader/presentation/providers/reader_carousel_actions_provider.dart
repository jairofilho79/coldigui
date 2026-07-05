import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../catalog/domain/utils/find_louvor_by_pdf_id.dart';
import '../../../catalog/presentation/providers/louvores_manifest_provider.dart';
import '../../../offline/data/providers/offline_core_providers.dart';
import '../../../pdf_opening/data/providers/pdf_opening_providers.dart';
import '../../../pdf_opening/domain/utils/louvor_pdf_path.dart';
import '../../data/providers/carousel_reader_providers.dart';
import '../../domain/entities/carousel_reader_position.dart';

/// Orquestra navegação carousel no leitor (UC-11, Fase 4.7).
///
/// [navigateToPdfId] é o ponto único de troca de PDF — usado por setas/modal
/// em [CarouselChips] e por [openCarouselPdfInReader] no shell.
/// [navigateAdjacent] permanece para lookup via [NavigateCarouselInReader]
/// (repositório Isar); a UI do leitor prefere ids de [readerCarouselPositionProvider].
class ReaderCarouselActionsNotifier extends Notifier<void> {
  @override
  void build() {}

  /// Resolve rota `/leitor` para o louvor adjacente ou `null` se indisponível.
  Future<String?> navigateAdjacent({
    required String currentPdfId,
    required CarouselReaderDirection direction,
  }) async {
    final targetPdfId = await ref
        .read(navigateCarouselInReaderProvider)
        .resolveTarget(currentPdfId: currentPdfId, direction: direction);
    if (targetPdfId == null) return null;

    return navigateToPdfId(targetPdfId: targetPdfId);
  }

  /// Resolve rota `/leitor` para [targetPdfId] ou `null` se indisponível.
  ///
  /// Usado por [openCarouselPdfInReader] (shell/modal) e por
  /// [navigateAdjacent] (setas no leitor).
  Future<String?> navigateToPdfId({required String targetPdfId}) async {
    final louvor = findLouvorByPdfId(
      ref.read(louvoresManifestProvider).value?.louvores,
      targetPdfId,
    );
    if (louvor == null) return null;

    final remotePath = LouvorPdfPath.fromLouvor(louvor);
    final source = await ref.read(resolvePdfForReaderProvider)(
      pdfId: louvor.pdfId,
      remotePath: remotePath,
    );

    return ref
        .read(openPdfInReaderProvider)
        .call(
          pdfPath: source.absolutePath,
          pdfId: louvor.pdfId,
          titulo: louvor.nome,
        );
  }
}

/// Ações de navegação carousel dentro do leitor PDF (Fase 4.7).
final readerCarouselActionsProvider =
    NotifierProvider<ReaderCarouselActionsNotifier, void>(
      ReaderCarouselActionsNotifier.new,
    );

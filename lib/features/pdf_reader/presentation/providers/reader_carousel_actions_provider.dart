import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:coldigui/features/coldigom/data/coldigom_praise_cache_warmup.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';

import '../../../catalog/domain/utils/find_louvor_by_pdf_id.dart';
import '../../../catalog/presentation/providers/louvores_manifest_provider.dart';
import '../../../chords/presentation/utils/open_chord_in_reader.dart';
import '../../../offline/data/providers/offline_core_providers.dart';
import '../../../pdf_opening/data/providers/pdf_opening_providers.dart';
import '../../../pdf_opening/domain/utils/louvor_pdf_path.dart';

/// Orquestra navegação carousel no leitor (UC-11, Fase 4.7).
///
/// [navigateToPdfId] é o ponto único de troca de PDF — usado por setas/modal
/// em [CarouselChips] e por [openCarouselPdfInReader] no shell. O lookup por
/// repositório Isar saiu com o carousel (D3): a UI do leitor resolve os
/// vizinhos por [readerCarouselPositionProvider].
class ReaderCarouselActionsNotifier extends Notifier<void> {
  @override
  void build() {}

  /// Resolve rota `/leitor` para [targetPdfId] ou `null` se indisponível.
  ///
  /// Usado por [openCarouselPdfInReader] (shell/modal) e pelas setas do leitor.
  Future<String?> navigateToPdfId({required String targetPdfId}) async {
    // Este notifier devolve uma **rota** para quem chama navegar e não tem
    // `BuildContext`, então o desvio de cifra continua resolvido por rota aqui
    // em vez de passar pelo `openMaterialProvider` (que abre, não roteia).
    // Cifra com cache frio não tem para onde ir — não vira busca de PDF.
    final chordRoute = chordRouteFor(
      targetPdfId,
      ref.read(coldigomChordMaterialsCacheProvider),
    );
    if (chordRoute.isChord) return chordRoute.location;

    final louvor = findLouvorByPdfIdWithColdigom(
      ref.read(louvoresManifestProvider).value?.louvores,
      targetPdfId,
      coldigomCache: ref.read(coldigomLouvoresCacheProvider),
    );
    if (louvor == null) return null;

    // Best-effort: nunca bloqueia nem impede a troca de louvor (A3).
    warmupColdigomInBackground(
      ref.read(ensureColdigomPraiseMaterialsCachedProvider),
      louvor,
    );

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

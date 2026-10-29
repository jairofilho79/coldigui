import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:coldigui/features/coldigom/data/coldigom_praise_cache_warmup.dart';

import '../../../carousel/presentation/providers/carousel_focused_index_provider.dart';
import '../../../carousel/presentation/providers/carousel_items_provider.dart';
import '../../../catalog/presentation/providers/catalog_material_lookup_provider.dart';
import '../../../chords/presentation/utils/open_chord_in_reader.dart';
import '../../../gestures/presentation/utils/open_gesture_in_reader.dart';
import '../../../offline/data/providers/offline_core_providers.dart';
import '../../../pdf_opening/data/providers/pdf_opening_providers.dart';
import '../../../pdf_opening/domain/utils/louvor_pdf_path.dart';

/// Orquestra a troca de material dentro do leitor (UC-11, B.5).
///
/// [navigateToKey] é a porta de entrada de quem navega **pela lista** (setas,
/// teclado, chips): a chave identifica a ocorrência, então o mesmo louvor
/// repetido não colapsa. [navigateToPdfId] fica para quem só tem o id (deep
/// link, "seguir o áudio", abertura a partir do catálogo).
class ReaderCarouselActionsNotifier extends Notifier<void> {
  @override
  void build() {}

  /// Foca a ocorrência [key] na face de partituras e resolve a rota dela.
  ///
  /// `null` quando a chave não está (mais) na face — nada é focado nesse caso:
  /// mover o foco para um item que não existe só perderia a posição atual.
  Future<String?> navigateToKey({required String key}) async {
    final items = ref.read(carouselItemsProvider);
    final index = items.indexWhere((item) => item.key == key);
    if (index < 0) return null;

    ref.read(carouselFocusedIndexProvider.notifier).focusKey(key);
    return navigateToPdfId(targetPdfId: items[index].materialId);
  }

  /// Resolve rota `/leitor` (ou `/cifra`, `/gestos`) para [targetPdfId], ou `null`.
  ///
  /// Usado por [openCarouselPdfInReader] (shell/modal) e por [navigateToKey].
  Future<String?> navigateToPdfId({required String targetPdfId}) async {
    // Este notifier devolve uma **rota** para quem chama navegar e não tem
    // `BuildContext`, então o desvio de cifra continua resolvido por rota aqui
    // em vez de passar pelo `openMaterialProvider` (que abre, não roteia).
    // Cifra com cache frio não tem para onde ir — não vira busca de PDF.
    final lookup = ref.read(catalogMaterialLookupProvider);

    final chordRoute = chordRouteFor(targetPdfId, lookup.chordsById);
    if (chordRoute.isChord) return chordRoute.location;

    final gestureRoute = gestureRouteFor(targetPdfId, lookup.gesturesById);
    if (gestureRoute.isGesture) return gestureRoute.location;

    // O lookup lê o catálogo coldigom em memória em O(1) — nada de varrer o
    // catálogo a cada troca de louvor (A4).
    final louvor = lookup.louvor(targetPdfId);
    if (louvor == null) return null;

    // Best-effort: nunca bloqueia nem impede a troca de louvor (A3).
    warmupColdigomInBackground(
      ref.read(ensureColdigomPraiseMaterialsCachedProvider),
      louvor,
    );

    // `louvor.pdfId` é a chave de armazenamento (índice offline); a **rota**
    // leva o id pedido, o mesmo do chip do carrossel e da Lista ao Vivo.
    final remotePath = LouvorPdfPath.fromLouvor(louvor);
    final source = await ref.read(resolvePdfForReaderProvider)(
      pdfId: louvor.pdfId,
      remotePath: remotePath,
    );

    return ref
        .read(openPdfInReaderProvider)
        .call(
          pdfPath: source.absolutePath,
          pdfId: targetPdfId,
          titulo: louvor.nome,
        );
  }
}

/// Ações de navegação do leitor sobre a lista ativa (B.5).
final readerCarouselActionsProvider =
    NotifierProvider<ReaderCarouselActionsNotifier, void>(
      ReaderCarouselActionsNotifier.new,
    );

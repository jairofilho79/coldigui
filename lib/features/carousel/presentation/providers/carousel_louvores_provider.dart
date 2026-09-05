import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../playlists/domain/entities/playlist_entry.dart';
import '../../../playlists/domain/entities/playlist_media_face.dart';
import '../../../playlists/presentation/providers/active_playlist_editor.dart';
import '../../domain/entities/carousel_item.dart';
import 'carousel_items_provider.dart';

/// Debounce entre reordenações consecutivas antes de persistir.
///
/// Apelido de [activeReorderPersistDebounce] — o debounce mudou de lugar junto
/// com a persistência.
const carouselReorderPersistDebounce = activeReorderPersistDebounce;

/// Adaptador de compatibilidade sobre a lista ativa (some na Tarefa 16).
///
/// O carousel não tem mais estado próprio: [build] é a face de partituras da
/// lista ativa ([carouselItemsProvider]) e cada método delega ao
/// [ActivePlaylistEditor]. Como a API antiga fala em `pdfId` e não em chave,
/// todas as mutações miram a **primeira ocorrência** do id.
class CarouselLouvoresNotifier extends Notifier<List<CarouselItem>> {
  @override
  List<CarouselItem> build() => ref.watch(carouselItemsProvider);

  ActivePlaylistEditor get _editor =>
      ref.read(activePlaylistEditorProvider.notifier);

  /// No-op: a lista já é derivada — não há o que recarregar.
  Future<void> reload() async {}

  /// Adiciona [pdfId] à lista ativa. Retorna `false` se já existia.
  Future<bool> add(String pdfId) async {
    final outcome = await _editor.addToActive(pdfId);
    return outcome == AddToActiveOutcome.added;
  }

  /// Remove a primeira ocorrência de [pdfId] da seleção.
  Future<void> remove(String pdfId) =>
      _editor.removeByKey(entryKeyFor(pdfId, 0));

  /// Troca material na mesma posição da primeira ocorrência de [oldPdfId].
  Future<bool> replacePdfId(String oldPdfId, String newPdfId) =>
      _editor.replaceByKey(
        entryKeyFor(oldPdfId, 0),
        PlaylistEntry.classified(newPdfId),
      );

  /// Persiste nova ordem da face de partituras após drag-and-drop.
  Future<void> reorder(List<String> orderedPdfIds) => _editor.reorderFace(
    PlaylistMediaFace.pdf,
    [for (final id in orderedPdfIds) entryKeyFor(id, 0)],
  );

  /// Limpa toda a seleção — rascunho ativo é apagado, lista salva só desanexa.
  Future<void> clear() => _editor.deleteActiveDraft();
}

/// Face de partituras da lista ativa — adaptador dos consumidores antigos.
final carouselLouvoresProvider =
    NotifierProvider<CarouselLouvoresNotifier, List<CarouselItem>>(
      CarouselLouvoresNotifier.new,
    );

/// Apelido de [activeMaterialIdsProvider] — membership O(1) por id.
final carouselPdfIdsProvider = Provider<Set<String>>((ref) {
  return ref.watch(activeMaterialIdsProvider);
});

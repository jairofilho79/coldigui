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
/// [ActivePlaylistEditor]. Como a API antiga fala em `pdfId` e não em chave, as
/// chaves são resolvidas **na face que este adaptador serve** — nunca por
/// `entryKeyFor(id, 0)`, que é a primeira ocorrência na ordem única e pode ser
/// a entrada de áudio quando o mesmo id está nas duas faces.
class CarouselLouvoresNotifier extends Notifier<List<CarouselItem>> {
  @override
  List<CarouselItem> build() => ref.watch(carouselItemsProvider);

  ActivePlaylistEditor get _editor =>
      ref.read(activePlaylistEditorProvider.notifier);

  /// Chave da primeira ocorrência de [pdfId] **na face de partituras**.
  String? _keyFor(String pdfId) {
    for (final item in ref.read(carouselItemsProvider)) {
      if (item.materialId == pdfId) return item.key;
    }
    return null;
  }

  /// No-op: a lista já é derivada — não há o que recarregar.
  Future<void> reload() async {}

  /// Adiciona [pdfId] à lista ativa. Retorna `false` se já existia.
  Future<bool> add(String pdfId) async {
    final outcome = await _editor.addToActive(pdfId);
    return outcome == AddToActiveOutcome.added;
  }

  /// Remove a primeira ocorrência de [pdfId] na face de partituras.
  Future<void> remove(String pdfId) async {
    final key = _keyFor(pdfId);
    if (key == null) return;
    await _editor.removeByKey(key);
  }

  /// Troca material na mesma posição da primeira ocorrência de [oldPdfId].
  Future<bool> replacePdfId(String oldPdfId, String newPdfId) async {
    final key = _keyFor(oldPdfId);
    if (key == null) return false;
    return _editor.replaceByKey(key, PlaylistEntry.classified(newPdfId));
  }

  /// Persiste nova ordem da face de partituras após drag-and-drop.
  ///
  /// Consome as chaves por ocorrência: o n-ésimo [pdfId] repetido em
  /// [orderedPdfIds] vira a chave da n-ésima ocorrência dele na face.
  Future<void> reorder(List<String> orderedPdfIds) async {
    final pending = <String, List<String>>{};
    for (final item in ref.read(carouselItemsProvider)) {
      (pending[item.materialId] ??= <String>[]).add(item.key);
    }

    final orderedKeys = <String>[];
    for (final pdfId in orderedPdfIds) {
      final keys = pending[pdfId];
      if (keys == null || keys.isEmpty) continue;
      orderedKeys.add(keys.removeAt(0));
    }

    await _editor.reorderFace(PlaylistMediaFace.pdf, orderedKeys);
  }

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

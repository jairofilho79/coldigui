import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../catalog/domain/entities/louvor.dart';
import '../../../catalog/presentation/providers/louvores_manifest_provider.dart';
import '../../../playlists/presentation/providers/active_playlist_sync.dart';
import '../../data/providers/carousel_providers.dart';
import '../../domain/entities/carousel_item.dart';

/// Debounce entre reordenações consecutivas antes de persistir no Isar.
const carouselReorderPersistDebounce = Duration(milliseconds: 100);

/// Estado reativo do carousel enriquecido com labels do manifest (UC-05).
///
/// Cold start: lista vazia até `_reload()` via microtask. Reage a updates do
/// manifest para refrescar labels de chips existentes.
class CarouselLouvoresNotifier extends Notifier<List<CarouselItem>> {
  Timer? _reorderPersistTimer;
  List<String>? _pendingReorderPdfIds;
  int _reloadGeneration = 0;

  @override
  List<CarouselItem> build() {
    ref.listen(louvoresManifestProvider, (_, __) {
      unawaited(_reload());
    });
    ref.onDispose(() => _reorderPersistTimer?.cancel());
    Future.microtask(_reload);
    return const [];
  }

  Future<void> _reload() async {
    final generation = ++_reloadGeneration;
    final repository = ref.read(carouselRepositoryProvider);
    final metadata =
        _buildMetadataMap(ref.read(louvoresManifestProvider).value);
    final items = await repository.getOrderedItems(pdfIdToMetadata: metadata);
    if (generation != _reloadGeneration) return;
    state = items;
  }

  List<CarouselItem> _reorderItemsLocally(
    List<CarouselItem> items,
    List<String> orderedPdfIds,
  ) {
    final byId = {for (final item in items) item.pdfId: item};
    return [
      for (var i = 0; i < orderedPdfIds.length; i++)
        CarouselItem(
          pdfId: orderedPdfIds[i],
          sortOrder: i,
          numero: byId[orderedPdfIds[i]]!.numero,
          nome: byId[orderedPdfIds[i]]!.nome,
          categoria: byId[orderedPdfIds[i]]!.categoria,
          classificacao: byId[orderedPdfIds[i]]!.classificacao,
        ),
    ];
  }

  Future<void> _flushPendingReorder() async {
    final orderedPdfIds = _pendingReorderPdfIds;
    if (orderedPdfIds == null) return;
    _pendingReorderPdfIds = null;

    await ref.read(reorderCarouselProvider)(orderedPdfIds: orderedPdfIds);
    await syncActivePlaylistFromCarousel(ref);
  }

  /// Recarrega estado após mutação externa (ex.: [LoadPlaylistIntoCarousel]).
  Future<void> reload() => _reload();

  Map<String, CarouselItemMetadata> _buildMetadataMap(List<Louvor>? catalog) {
    if (catalog == null) return const {};
    return {
      for (final louvor in catalog)
        louvor.pdfId: CarouselItemMetadata(
          numero: louvor.numero,
          nome: louvor.nome,
          categoria: louvor.categoria,
          classificacao: louvor.classificacao,
        ),
    };
  }

  /// Adiciona [pdfId] ao carousel. Retorna `false` se já existia.
  Future<bool> add(String pdfId) async {
    final added = await ref.read(addLouvorToCarouselProvider)(pdfId: pdfId);
    if (added) {
      await _reload();
      await syncActivePlaylistFromCarousel(ref);
    }
    return added;
  }

  /// Remove [pdfId] da seleção.
  Future<void> remove(String pdfId) async {
    await ref.read(removeLouvorFromCarouselProvider)(pdfId: pdfId);
    await _reload();
    await syncActivePlaylistFromCarousel(ref);
  }

  /// Persiste nova ordem após drag-and-drop na UI.
  ///
  /// Atualiza [state] de forma otimista (sem `_reload`) e agrupa persistências
  /// Isar + sync da playlist ativa em [carouselReorderPersistDebounce].
  Future<void> reorder(List<String> orderedPdfIds) async {
    state = _reorderItemsLocally(state, orderedPdfIds);
    _pendingReorderPdfIds = orderedPdfIds;

    _reorderPersistTimer?.cancel();
    _reorderPersistTimer = Timer(carouselReorderPersistDebounce, () {
      unawaited(_flushPendingReorder());
    });
  }

  /// Limpa toda a seleção.
  Future<void> clear() async {
    await ref.read(clearCarouselProvider)();
    await _reload();
  }
}

/// Lista ordenada de louvores no carousel temporário (UC-05) — fonte de verdade.
///
/// Consumido por [LouvorCard] (`isAdded`), [showCarouselSelectionSheet] (modal),
/// [PlaylistListTile] (confirmação de substituição) e navegação via
/// [carouselFocusedIndexProvider].
///
/// A barra [CarouselChips] renderiza via [carouselLouvoresDisplayProvider]
/// (debounce de reordenação). [CarouselLouvoresNotifier.reorder] atualiza
/// [state] de forma otimista e persiste no Isar após
/// [carouselReorderPersistDebounce].
final carouselLouvoresProvider =
    NotifierProvider<CarouselLouvoresNotifier, List<CarouselItem>>(
  CarouselLouvoresNotifier.new,
);

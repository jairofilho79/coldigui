import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/color_extensions.dart';
import '../../../playlists/domain/entities/playlist_media_face.dart';
import '../../../playlists/presentation/providers/active_playlist_editor.dart';
import '../../domain/entities/carousel_item.dart';
import '../providers/carousel_focused_index_provider.dart';
import '../providers/carousel_items_provider.dart';
import 'carousel_louvor_chip.dart';
import 'carousel_selection_sheet.dart'
    show carouselSelectionReorderProxyDecorator;

/// Lista reordenável da face ativa (spec A.6 C7).
///
/// Extraído do corpo do modal de seleção temporária
/// ([showCarouselSelectionSheet], que agora só embrulha isto num
/// `AlertDialog`).
///
/// Mostra a face [face] da lista ativa ([carouselItemsProvider] para
/// [PlaylistMediaFace.pdf], [audioFaceItemsProvider] para
/// [PlaylistMediaFace.audio]). O item focado na face de partituras
/// ([carouselFocusedIndexProvider]) ganha destaque visual — a face de áudio
/// não tem conceito de foco equivalente, então nunca destaca.
///
/// Drag reordena e chama [ActivePlaylistEditor.reorderFace] com a nova ordem
/// de chaves; `×` remove por chave ([ActivePlaylistEditor.removeByKey]) e
/// avisa [onRemoved] (com a lista já sem a entrada); toque foca a ocorrência
/// e, se [onOpen] for informado, dispara a mesma navegação das chips do
/// carousel.
class ActiveListPanel extends ConsumerStatefulWidget {
  const ActiveListPanel({
    this.face = PlaylistMediaFace.pdf,
    this.onOpen,
    this.onRemoved,
    super.key,
  });

  final PlaylistMediaFace face;

  /// Toque no item — `null` desliga a navegação (o toque só foca).
  final Future<void> Function(CarouselItem item)? onOpen;

  /// Chamado depois que a remoção já foi persistida (`removeByKey`).
  final Future<void> Function(CarouselItem item)? onRemoved;

  @override
  ConsumerState<ActiveListPanel> createState() => _ActiveListPanelState();
}

class _ActiveListPanelState extends ConsumerState<ActiveListPanel> {
  Provider<List<CarouselItem>> get _itemsProvider =>
      widget.face == PlaylistMediaFace.audio
      ? audioFaceItemsProvider
      : carouselItemsProvider;

  void _handleReorder(int oldIndex, int newIndex) {
    final items = ref.read(_itemsProvider);
    final reordered = List<CarouselItem>.from(items);
    if (oldIndex < 0 || oldIndex >= reordered.length) return;
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex.clamp(0, reordered.length), moved);

    // `reorderFace` aplica o override otimista antes de persistir: a lista já
    // desenha a ordem nova sem esperar a escrita.
    unawaited(
      ref.read(activePlaylistEditorProvider.notifier).reorderFace(widget.face, [
        for (final item in reordered) item.key,
      ]),
    );
  }

  Future<void> _handleRemove(CarouselItem item) async {
    await ref.read(activePlaylistEditorProvider.notifier).removeByKey(item.key);
    if (!mounted) return;
    await widget.onRemoved?.call(item);
  }

  Future<void> _handleTap(CarouselItem item) async {
    ref.read(carouselFocusedIndexProvider.notifier).focusKey(item.key);
    await widget.onOpen!(item);
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(_itemsProvider);
    final focusedIndex = widget.face == PlaylistMediaFace.pdf
        ? ref.watch(carouselFocusedIndexProvider)
        : -1;

    return ReorderableListView.builder(
      shrinkWrap: true,
      buildDefaultDragHandles: false,
      proxyDecorator: carouselSelectionReorderProxyDecorator,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: items.length,
      onReorderItem: _handleReorder,
      itemBuilder: (context, index) {
        final item = items[index];
        final highlighted = index == focusedIndex;

        return ReorderableDragStartListener(
          // Chave por **ocorrência**: o mesmo louvor duas vezes na lista são
          // dois itens distintos para o `ReorderableListView`.
          key: ValueKey(item.key),
          index: index,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Container(
              key: ValueKey('activeListPanelItem-${item.key}'),
              decoration: highlighted
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.goldLight, width: 3),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.goldGlow,
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    )
                  : null,
              child: CarouselLouvorChip(
                item: item,
                showDragHandle: true,
                onTap: widget.onOpen == null ? null : () => _handleTap(item),
                onRemove: () => _handleRemove(item),
              ),
            ),
          ),
        );
      },
    );
  }
}

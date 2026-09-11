import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../playlists/domain/entities/playlist_media_face.dart';
import '../../../playlists/presentation/providers/active_playlist_editor.dart';
import '../../domain/entities/carousel_item.dart';
import '../providers/carousel_focused_index_provider.dart';
import '../providers/carousel_items_provider.dart';
import 'carousel_louvor_chip.dart';

/// Proxy transparente para [ReorderableListView.proxyDecorator] no modal de
/// seleção temporária.
///
/// O decorador padrão do Flutter envolve o item em [Material] com elevação
/// retangular; com chips pill ([CarouselLouvorChipVariant.modal]), isso deixa
/// uma borda/sombra visível fora das curvas durante o drag-and-drop.
///
/// Usado por [showCarouselSelectionSheet].
Widget carouselSelectionReorderProxyDecorator(
  Widget child,
  int index,
  Animation<double> animation,
) {
  return AnimatedBuilder(
    animation: animation,
    builder: (context, child) => Material(
      color: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      child: child,
    ),
    child: child,
  );
}

/// Abre modal com a **face de partituras** da lista ativa, reordenável.
///
/// [onItemTap] — toque no chip delega abertura/troca no leitor; o dialog é
/// fechado antes do callback e a entrada tocada já fica focada **pela sua
/// chave** ([CarouselFocusedIndexNotifier.focusKey]), para que duas ocorrências
/// do mesmo louvor não se confundam.
///
/// [onItemRemoved] recebe o `materialId` da entrada removida — é o que o caller
/// ([CarouselChips]) compara com o PDF aberto no leitor.
///
/// Reorder via handle de drag em [CarouselLouvorChip] (`showDragHandle: true`);
/// o proxy de drag usa [carouselSelectionReorderProxyDecorator] para evitar
/// artefato visual do `Material` padrão com chips pill.
Future<void> showCarouselSelectionSheet(
  BuildContext context, {
  Future<void> Function(String removedMaterialId)? onItemRemoved,
  Future<void> Function(CarouselItem item)? onItemTap,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _CarouselSelectionDialog(
      onItemRemoved: onItemRemoved,
      onItemTap: onItemTap == null
          ? null
          : (item) async {
              Navigator.of(dialogContext).pop();
              await onItemTap(item);
            },
    ),
  );
}

class _CarouselSelectionDialog extends ConsumerStatefulWidget {
  const _CarouselSelectionDialog({this.onItemRemoved, this.onItemTap});

  final Future<void> Function(String removedMaterialId)? onItemRemoved;
  final Future<void> Function(CarouselItem item)? onItemTap;

  @override
  ConsumerState<_CarouselSelectionDialog> createState() =>
      _CarouselSelectionDialogState();
}

class _CarouselSelectionDialogState
    extends ConsumerState<_CarouselSelectionDialog> {
  /// Reordenar é permutar: a nova ordem vai como **chaves** da face, e só da
  /// face de partituras — as entradas de áudio ficam onde estão.
  void _handleReorder(int oldIndex, int newIndex) {
    final reordered = List<CarouselItem>.from(ref.read(carouselItemsProvider));
    if (oldIndex < 0 || oldIndex >= reordered.length) return;
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex.clamp(0, reordered.length), moved);

    // `reorderFace` aplica o override otimista antes de persistir: o modal já
    // desenha a ordem nova sem esperar a escrita.
    unawaited(
      ref.read(activePlaylistEditorProvider.notifier).reorderFace(
        PlaylistMediaFace.pdf,
        [for (final item in reordered) item.key],
      ),
    );
  }

  Future<void> _handleRemove(CarouselItem item) async {
    await ref.read(activePlaylistEditorProvider.notifier).removeByKey(item.key);
    if (!mounted) return;

    if (ref.read(carouselItemsProvider).isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    await widget.onItemRemoved?.call(item.materialId);
  }

  Future<void> _handleTap(CarouselItem item) async {
    ref.read(carouselFocusedIndexProvider.notifier).focusKey(item.key);
    await widget.onItemTap!(item);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = ref.watch(carouselItemsProvider);

    return AlertDialog(
      title: Text(l10n.carouselListTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: ReorderableListView.builder(
          shrinkWrap: true,
          buildDefaultDragHandles: false,
          proxyDecorator: carouselSelectionReorderProxyDecorator,
          itemCount: items.length,
          onReorderItem: _handleReorder,
          itemBuilder: (context, index) {
            final item = items[index];
            return ReorderableDragStartListener(
              // Chave por **ocorrência**: o mesmo louvor duas vezes na lista
              // são dois itens distintos para o `ReorderableListView`.
              key: ValueKey(item.key),
              index: index,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: CarouselLouvorChip(
                  item: item,
                  showDragHandle: true,
                  onTap: widget.onItemTap == null
                      ? null
                      : () => _handleTap(item),
                  onRemove: () => _handleRemove(item),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.carouselListClose),
        ),
      ],
    );
  }
}

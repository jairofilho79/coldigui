import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/carousel_item.dart';
import '../providers/carousel_louvores_provider.dart';
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

/// Abre modal com lista vertical reordenável e remoção individual.
///
/// [onItemTap] — toque no chip delega abertura/troca no leitor; o dialog é
/// fechado antes do callback. O caller ([CarouselChips]) resolve o PDF ativo
/// no momento do toque e sincroniza [carouselFocusedIndexProvider] após navegar.
///
/// Reorder via handle de drag em [CarouselLouvorChip] (`showDragHandle: true`);
/// o proxy de drag usa [carouselSelectionReorderProxyDecorator] para evitar
/// artefato visual do `Material` padrão com chips pill.
Future<void> showCarouselSelectionSheet(
  BuildContext context, {
  Future<void> Function(String removedPdfId)? onItemRemoved,
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

  final Future<void> Function(String removedPdfId)? onItemRemoved;
  final Future<void> Function(CarouselItem item)? onItemTap;

  @override
  ConsumerState<_CarouselSelectionDialog> createState() =>
      _CarouselSelectionDialogState();
}

class _CarouselSelectionDialogState
    extends ConsumerState<_CarouselSelectionDialog> {
  void _handleReorder(int oldIndex, int newIndex) {
    final items = ref.read(carouselLouvoresProvider);
    final reordered = List<CarouselItem>.from(items);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    ref
        .read(carouselLouvoresProvider.notifier)
        .reorder(reordered.map((item) => item.pdfId).toList(growable: false));
  }

  Future<void> _handleRemove(String pdfId) async {
    await ref.read(carouselLouvoresProvider.notifier).remove(pdfId);
    if (!mounted) return;

    final remaining = ref.read(carouselLouvoresProvider);
    if (remaining.isEmpty && mounted) {
      Navigator.of(context).pop();
      return;
    }

    await widget.onItemRemoved?.call(pdfId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = ref.watch(carouselLouvoresProvider);

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
              key: ValueKey(item.pdfId),
              index: index,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: CarouselLouvorChip(
                  item: item,
                  showDragHandle: true,
                  onTap: widget.onItemTap == null
                      ? null
                      : () => widget.onItemTap!(item),
                  onRemove: () => _handleRemove(item.pdfId),
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

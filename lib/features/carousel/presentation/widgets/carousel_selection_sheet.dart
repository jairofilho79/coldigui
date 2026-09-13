import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/carousel_item.dart';
import '../providers/carousel_items_provider.dart';
import 'active_list_panel.dart';

/// Proxy transparente para [ReorderableListView.proxyDecorator] no modal de
/// seleção temporária e no painel lateral do leitor.
///
/// O decorador padrão do Flutter envolve o item em [Material] com elevação
/// retangular; com chips pill (variante modal do chip do carousel), isso
/// deixa uma borda/sombra visível fora das curvas durante o drag-and-drop.
///
/// Usado por [showCarouselSelectionSheet] e por `ActiveListPanel`.
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
/// O corpo (lista reordenável) é `ActiveListPanel` — spec A.6 C7 — reutilizado
/// também no painel lateral do leitor de PDF e da cifra.
///
/// [onItemTap] — toque no chip delega abertura/troca no leitor; o dialog é
/// fechado antes do callback e a entrada tocada já fica focada **pela sua
/// chave**, para que duas ocorrências do mesmo louvor não se confundam.
///
/// [onItemRemoved] recebe o `materialId` da entrada removida — é o que o
/// caller (`CarouselChips`) compara com o PDF aberto no leitor.
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
  /// Some sozinho quando a última entrada é removida — o desfazer não existe
  /// aqui, então uma lista vazia não tem mais o que mostrar.
  Future<void> _handleRemoved(CarouselItem item) async {
    if (!mounted) return;

    if (ref.read(carouselItemsProvider).isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    await widget.onItemRemoved?.call(item.materialId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.carouselListTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: ActiveListPanel(
          onOpen: widget.onItemTap,
          onRemoved: _handleRemoved,
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

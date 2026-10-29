import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../playlists/presentation/providers/active_playlist_editor.dart';
import '../../domain/entities/carousel_item.dart';
import '../providers/carousel_focused_index_provider.dart';
import '../providers/carousel_items_provider.dart';
import '../providers/currently_open_item_provider.dart';
import 'carousel_louvor_chip.dart';
import 'carousel_selection_sheet.dart'
    show carouselSelectionReorderProxyDecorator;

/// Lista reordenável da lista ativa (spec A.6 C7; sem faces desde a spec
/// 2026-09-12).
///
/// Mostra [carouselItemsProvider] inteiro — partitura, cifra, gesto e áudio na
/// ordem da lista. O item focado ([carouselFocusedIndexProvider]) ganha
/// destaque visual.
///
/// Drag reordena e chama [ActivePlaylistEditor.reorder] com a nova ordem de
/// chaves; `×` remove por chave ([ActivePlaylistEditor.removeByKey]) e avisa
/// [onRemoved]; toque foca a ocorrência e, se [onOpen] for informado, dispara
/// a mesma navegação do chip da barra.
///
/// Se o praise atualmente aberto não estiver na lista ativa, uma seção superior
/// com divisor horizontal identifica-o e permite adicioná-lo via `+`. Se estiver
/// na lista, ele recebe a tag "Atual" e o destaque nobre com aura dourada ([CurrentLouvorHighlight]).
class ActiveListPanel extends ConsumerStatefulWidget {
  const ActiveListPanel({this.onOpen, this.onRemoved, super.key});

  /// Toque no item — `null` desliga a navegação (o toque só foca).
  final Future<void> Function(CarouselItem item)? onOpen;

  /// Chamado depois que a remoção já foi persistida (`removeByKey`).
  final Future<void> Function(CarouselItem item)? onRemoved;

  @override
  ConsumerState<ActiveListPanel> createState() => _ActiveListPanelState();
}

class _ActiveListPanelState extends ConsumerState<ActiveListPanel> {
  void _handleReorder(int oldIndex, int newIndex) {
    final items = ref.read(carouselItemsProvider);
    final reordered = List<CarouselItem>.from(items);
    if (oldIndex < 0 || oldIndex >= reordered.length) return;
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex.clamp(0, reordered.length), moved);

    // `reorder` aplica o override otimista antes de persistir: a lista já
    // desenha a ordem nova sem esperar a escrita.
    unawaited(
      ref.read(activePlaylistEditorProvider.notifier).reorder([
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
    final items = ref.watch(carouselItemsProvider);
    final focusedIndex = ref.watch(carouselFocusedIndexProvider);
    final openItem = ref.watch(currentlyOpenItemProvider);
    final isInList = openItem != null &&
        items.any((item) => item.materialId == openItem.materialId);
    final showUnlistedSection = openItem != null && !isInList;

    // Determina a ocorrência do louvor atualmente ativo na lista:
    // 1. Se há um material aberto no leitor que pertence à lista, ele é o atual.
    // 2. Caso contrário (fora do leitor), o item focado no carrossel ([carouselFocusedIndexProvider]) é o atual.
    // Isso garante que o indicativo de louvor atual seja 100% consistente em qualquer tela.
    final currentKey = () {
      if (isInList) {
        if (focusedIndex >= 0 &&
            focusedIndex < items.length &&
            items[focusedIndex].materialId == openItem.materialId) {
          return items[focusedIndex].key;
        }
        return items.firstWhere((it) => it.materialId == openItem.materialId).key;
      }
      if (items.isNotEmpty && focusedIndex >= 0 && focusedIndex < items.length) {
        return items[focusedIndex].key;
      }
      return null;
    }();

    Widget? header;
    if (showUnlistedSection || items.isEmpty) {
      header = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showUnlistedSection) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.visibility_outlined,
                    size: 16,
                    color: AppColors.title,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Material em exibição (não está na lista)',
                    style: AppTypography.headline.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: CarouselLouvorChip(
                item: openItem,
                variant: CarouselLouvorChipVariant.modal,
                showDragHandle: false,
                isAdded: false,
                onAdd: () async {
                  await ref
                      .read(activePlaylistEditorProvider.notifier)
                      .addToActive(openItem.materialId, kind: openItem.kind);
                },
                onTap: widget.onOpen == null
                    ? null
                    : () => widget.onOpen!(openItem),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Divider(
                height: 1,
                thickness: 1,
                color: AppColors.title.withValues(alpha: 0.25),
              ),
            ),
          ],
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.queue_music,
                    size: 36,
                    color: AppColors.title.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nenhum louvor na lista atual',
                    style: AppTypography.body.copyWith(
                      color: AppColors.title.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (showUnlistedSection) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Toque no + acima para adicionar este louvor à lista',
                      style: AppTypography.body.copyWith(
                        fontSize: 12,
                        color: AppColors.title.withValues(alpha: 0.55),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            )
          else if (showUnlistedSection)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                'Lista atual (${items.length})',
                style: AppTypography.headline.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      );
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      header: header,
      buildDefaultDragHandles: false,
      proxyDecorator: carouselSelectionReorderProxyDecorator,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: items.length,
      onReorderItem: _handleReorder,
      itemBuilder: (context, index) {
        final item = items[index];
        final isCurrent = currentKey != null && item.key == currentKey;
        final isFirst = index == 0;

        final chip = CarouselLouvorChip(
          item: item,
          isCurrent: isCurrent,
          showDragHandle: true,
          dragHandleTargetId: isFirst ? 'active-list-reorder' : null,
          bodyTargetId: isFirst ? 'active-list-jump' : null,
          removeTargetId: isFirst ? 'active-list-remove' : null,
          onTap: widget.onOpen == null ? null : () => _handleTap(item),
          onRemove: () => _handleRemove(item),
        );

        final Widget itemBody = isCurrent
            ? CurrentLouvorHighlight(child: chip)
            : chip;

        return ReorderableDragStartListener(
          // Chave por **ocorrência**: o mesmo louvor duas vezes na lista são
          // dois itens distintos para o `ReorderableListView`.
          key: ValueKey(item.key),
          index: index,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Container(
              key: ValueKey('activeListPanelItem-${item.key}'),
              child: itemBody,
            ),
          ),
        );
      },
    );
  }
}

/// Destaque de louvor atual dentro da lista ativa.
///
/// O visual do contorno nobre e da etiqueta "Atual" é renderizado internamente
/// pelo próprio [CarouselLouvorChip] quando `isCurrent: true`, mantendo paridade
/// visual e dimensional com as etiquetas da tela de pesquisa ([ChipGroupLabel]).
class CurrentLouvorHighlight extends StatelessWidget {
  const CurrentLouvorHighlight({
    required this.child,
    this.tagText,
    super.key,
  });

  final Widget child;
  final String? tagText;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

/// Rótulo legado para manter compatibilidade com testes existentes.
typedef ZebradaHighlight = CurrentLouvorHighlight;

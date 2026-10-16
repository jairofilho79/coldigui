import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import '../../../../core/theme/color_extensions.dart';
import '../../../../core/tutorial/presentation/providers/tutorial_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../playlists/data/providers/playlist_providers.dart';
import '../../../playlists/presentation/providers/active_playlist_provider.dart';
import '../../../playlists/presentation/providers/playlists_provider.dart';
import '../../domain/entities/carousel_item.dart';
import '../providers/carousel_items_provider.dart';
import 'active_list_panel.dart';
import 'carousel_clear_choice_dialog.dart';

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

/// Abre modal com **a lista ativa inteira** (PDF, cifra, gesto e áudio
/// juntos, spec 2026-09-12 D1), reordenável.
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
  final SpotlightGuidePortalController _portalController =
      SpotlightGuidePortalController();

  @override
  void initState() {
    super.initState();
    try {
      ref
          .read(tutorialControllerProvider)
          .pushPortalController(_portalController);
    } catch (_) {}
  }

  @override
  void dispose() {
    try {
      if (_portalController.isShowing) {
        _portalController.hide();
      }
      ref
          .read(tutorialControllerProvider)
          .popPortalController(_portalController);
    } catch (_) {}
    super.dispose();
  }

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

    return SpotlightGuidePortal(
      controller: _portalController,
      child: AlertDialog(
        title: Row(
          children: [
            Expanded(child: Text(l10n.carouselListTitle)),
            SpotlightGuideTarget(
              id: 'active-list-info',
              child: IconButton(
                tooltip: 'Como gerenciar a lista',
                onPressed: () {
                  try {
                    final container =
                        ProviderScope.containerOf(context, listen: false);
                    container
                        .read(tutorialControllerProvider)
                        .startCarouselSelectionTutorial(context);
                  } catch (_) {}
                },
                icon: const Icon(Icons.info_outline, color: AppColors.title),
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(40, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ActiveListPanel(
            onOpen: widget.onItemTap,
            onRemoved: _handleRemoved,
          ),
        ),
        actions: [
          SpotlightGuideTarget(
            id: 'active-list-clear',
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: AppColors.title),
              onPressed: () async {
                final activeId = ref.read(activePlaylistIdProvider);
                var canDelete = false;
                if (activeId != null) {
                  final active = await ref
                      .read(playlistRepositoryProvider)
                      .getById(activeId);
                  canDelete = active != null && !active.salva;
                }
                if (!context.mounted) return;
                final choice = await showCarouselClearChoiceDialog(
                  context,
                  canDelete: canDelete,
                );
                if (choice == null || !context.mounted) return;
                final playlists = ref.read(playlistsProvider.notifier);
                switch (choice) {
                  case CarouselClearChoice.newList:
                    await playlists.startNewEmptySelection();
                  case CarouselClearChoice.deleteList:
                    await playlists.deleteActiveUnsavedPlaylist();
                }
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(l10n.carouselClear),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.carouselListClose),
          ),
        ],
      ),
    );
  }
}

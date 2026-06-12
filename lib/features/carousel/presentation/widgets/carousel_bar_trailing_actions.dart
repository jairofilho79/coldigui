import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/share_position_origin.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/core/widgets/confirm_dialog.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_bar_shell.dart';
import 'package:coldigui/features/leaflet/presentation/providers/leaflet_actions_provider.dart';
import 'package:coldigui/features/playlists/data/providers/playlist_providers.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_tab.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_ui_provider.dart';
import 'package:coldigui/features/playlists/presentation/utils/playlist_share_debug_log.dart';
import 'package:coldigui/features/playlists/presentation/widgets/save_playlist_dialog.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Largura mínima da tela (px) para layout expandido da barra do carousel.
///
/// Em larguras menores, [CarouselBarTrailingActions] colapsa salvar/compartilhar/
/// folheto/limpar em [PopupMenuButton] (`more_vert`). [CarouselNavigatorBar]
/// mantém setas e botão lista sempre visíveis.
const kCarouselBarExpandedBreakpoint = 600.0;

enum _CarouselOverflowAction {
  savePlaylist,
  sharePlaylist,
  generateLeaflet,
  clear
}

/// Ações à direita da barra de carousel: salvar, compartilhar, folheto e limpar.
///
/// Layout responsivo em [kCarouselBarExpandedBreakpoint]:
/// - **Compacto:** menu overflow (`more_vert`) com `iconColor: AppColors.title`.
/// - **Expandido:** quatro [IconButton] com [carouselBarIconButtonStyle].
///
/// **Compartilhar** (UC-07): usa a playlist ativa ([activePlaylistIdProvider])
/// e delega a [PlaylistsNotifier.sharePlaylist] — URL PWA-compatível
/// (`/?sharepdfs=…&sharename=…`) via [share_plus].
///
/// Shell e leitor PDF ([CarouselChips] via [CarouselBarShell]).
class CarouselBarTrailingActions extends ConsumerStatefulWidget {
  const CarouselBarTrailingActions({super.key});

  @override
  ConsumerState<CarouselBarTrailingActions> createState() =>
      _CarouselBarTrailingActionsState();
}

class _CarouselBarTrailingActionsState
    extends ConsumerState<CarouselBarTrailingActions> {
  var _generatingLeaflet = false;

  Future<bool> _canClear() async {
    final activeId = ref.read(activePlaylistIdProvider);
    if (activeId == null) return true;

    final active = await ref.read(playlistRepositoryProvider).getById(activeId);
    return active == null || !active.salva;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isCompact =
        MediaQuery.sizeOf(context).width < kCarouselBarExpandedBreakpoint;

    if (isCompact) {
      return PopupMenuButton<_CarouselOverflowAction>(
        tooltip: l10n.carouselOverflowMenu,
        iconColor: AppColors.title,
        icon: _generatingLeaflet
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.title,
                ),
              )
            : const Icon(Icons.more_vert),
        onSelected: (action) =>
            _handleOverflowAction(context, ref, l10n, action),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: _CarouselOverflowAction.savePlaylist,
            child: Text(l10n.carouselSavePlaylist),
          ),
          PopupMenuItem(
            value: _CarouselOverflowAction.sharePlaylist,
            child: Text(l10n.carouselSharePlaylist),
          ),
          PopupMenuItem(
            value: _CarouselOverflowAction.generateLeaflet,
            enabled: !_generatingLeaflet,
            child: Text(l10n.carouselGenerateLeaflet),
          ),
          PopupMenuItem(
            value: _CarouselOverflowAction.clear,
            child: Text(l10n.carouselClear),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          style: carouselBarIconButtonStyle,
          tooltip: l10n.carouselSavePlaylist,
          icon: const Icon(Icons.save_outlined),
          onPressed: () => _savePlaylist(context, ref, l10n),
        ),
        IconButton(
          style: carouselBarIconButtonStyle,
          tooltip: l10n.carouselSharePlaylist,
          icon: const Icon(Icons.share_outlined),
          onPressed: () => _sharePlaylist(context, ref, l10n),
        ),
        IconButton(
          style: carouselBarIconButtonStyle,
          tooltip: l10n.carouselGenerateLeaflet,
          icon: _generatingLeaflet
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.title,
                  ),
                )
              : const Icon(Icons.description_outlined),
          onPressed:
              _generatingLeaflet ? null : () => _generateLeaflet(context, ref),
        ),
        IconButton(
          style: carouselBarIconButtonStyle,
          tooltip: l10n.carouselClear,
          icon: const Icon(Icons.clear_all),
          onPressed: () => _confirmClear(context, ref, l10n),
        ),
      ],
    );
  }

  void _handleOverflowAction(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    _CarouselOverflowAction action,
  ) {
    switch (action) {
      case _CarouselOverflowAction.savePlaylist:
        _savePlaylist(context, ref, l10n);
      case _CarouselOverflowAction.sharePlaylist:
        _sharePlaylist(context, ref, l10n);
      case _CarouselOverflowAction.generateLeaflet:
        _generateLeaflet(context, ref);
      case _CarouselOverflowAction.clear:
        _confirmClear(context, ref, l10n);
    }
  }

  Future<void> _savePlaylist(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final activeId = ref.read(activePlaylistIdProvider);
    final active = activeId == null
        ? null
        : await ref.read(playlistRepositoryProvider).getById(activeId);

    final initialName = active?.nome;
    if (!context.mounted) return;
    final nome = await showSavePlaylistDialog(
      context,
      initialName: initialName,
    );
    if (nome == null || !context.mounted) return;

    final saved = await ref.read(playlistsProvider.notifier).saveActivePlaylist(
          nome: nome,
        );
    if (!context.mounted) return;

    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.playlistEmptyCarousel)),
      );
      return;
    }

    ref.read(playlistsUiProvider.notifier).selectTab(PlaylistTab.saved);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.playlistSaved),
        action: SnackBarAction(
          label: l10n.playlistViewLists,
          onPressed: () {
            ref.read(playlistsUiProvider.notifier).selectTab(PlaylistTab.saved);
            context.go(RoutePaths.playlists);
          },
        ),
      ),
    );
  }

  Future<void> _sharePlaylist(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    playlistShareDebugLog('CarouselBarTrailingActions._sharePlaylist: início');
    final shareOrigin = sharePositionOriginFromContextOrFallback(context);
    final resolved = await ref
        .read(playlistsProvider.notifier)
        .resolveActivePlaylistFromCarousel();
    if (!context.mounted) return;

    if (resolved == null) {
      playlistShareDebugLog(
        '_sharePlaylist: resolve retornou null — exibindo lista vazia',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.playlistEmptyPdfList)),
      );
      return;
    }

    playlistShareDebugLog(
      '_sharePlaylist: compartilhando id=${resolved.playlistId} '
      'nome="${resolved.nome}"',
    );
    final shared = await ref.read(playlistsProvider.notifier).sharePlaylist(
          playlistId: resolved.playlistId,
          subject: resolved.nome,
          sharePositionOrigin: shareOrigin,
        );
    if (!shared && context.mounted) {
      showPlaylistShareErrorSnackbar(context, l10n);
    }
  }

  Future<void> _generateLeaflet(BuildContext context, WidgetRef ref) async {
    setState(() => _generatingLeaflet = true);
    try {
      await ref.read(leafletActionsProvider.notifier).generateAndShare(context);
    } finally {
      if (mounted) {
        setState(() => _generatingLeaflet = false);
      }
    }
  }

  Future<void> _confirmClear(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    if (!await _canClear()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.playlistClearSavedBlocked)),
        );
      }
      return;
    }

    if (!context.mounted) return;
    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.carouselClearConfirmTitle,
      message: l10n.carouselClearConfirmMessage,
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(playlistsProvider.notifier).clearActiveUnsavedPlaylist();
  }
}

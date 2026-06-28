import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/share_position_origin.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/core/widgets/confirm_dialog.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_louvores_provider.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_bar_shell.dart';
import 'package:coldigui/features/playlists/data/providers/playlist_providers.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_share_option.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_tab.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_share_actions_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_ui_provider.dart';
import 'package:coldigui/features/playlists/presentation/utils/playlist_share_debug_log.dart';
import 'package:coldigui/features/playlists/presentation/widgets/playlist_share_sheet.dart';
import 'package:coldigui/features/playlists/presentation/widgets/save_playlist_dialog.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Largura mínima da tela (px) para layout expandido da barra do carousel.
///
/// Em larguras menores, [CarouselBarTrailingActions] colapsa salvar/compartilhar/
/// limpar em [PopupMenuButton] (`more_vert`). [CarouselNavigatorBar]
/// mantém setas e botão lista sempre visíveis.
const kCarouselBarExpandedBreakpoint = 600.0;

enum _CarouselOverflowAction { savePlaylist, share, clear }

/// Ações à direita da barra de carousel: salvar, compartilhar e limpar.
///
/// **Compartilhar** (UC-07/UC-08): bottom sheet com link, folheto ou ambos.
class CarouselBarTrailingActions extends ConsumerStatefulWidget {
  const CarouselBarTrailingActions({super.key});

  @override
  ConsumerState<CarouselBarTrailingActions> createState() =>
      _CarouselBarTrailingActionsState();
}

class _CarouselBarTrailingActionsState
    extends ConsumerState<CarouselBarTrailingActions> {
  var _sharing = false;

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
        icon: _sharing
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
            value: _CarouselOverflowAction.share,
            child: Text(l10n.carouselSharePlaylist),
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
          icon: _sharing
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.title,
                  ),
                )
              : const Icon(Icons.share_outlined),
          onPressed:
              _sharing ? null : () => _openShareSheet(context, ref, l10n),
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
      case _CarouselOverflowAction.share:
        _openShareSheet(context, ref, l10n);
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

  Future<void> _openShareSheet(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    playlistShareDebugLog('CarouselBarTrailingActions._openShareSheet: início');
    final shareOrigin = sharePositionOriginFromContextOrFallback(context);
    final resolved = await ref
        .read(playlistsProvider.notifier)
        .resolveActivePlaylistFromCarousel();
    if (!context.mounted) return;

    if (resolved == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.playlistEmptyPdfList)),
      );
      return;
    }

    final pdfIds =
        ref.read(carouselLouvoresProvider).map((e) => e.pdfId).toList();
    final option = await showPlaylistShareSheet(context);
    if (option == null || !context.mounted) return;

    setState(() => _sharing = true);
    try {
      final shared =
          await ref.read(playlistShareActionsProvider.notifier).share(
                context,
                PlaylistShareContext(
                  playlistId: resolved.playlistId,
                  nome: resolved.nome,
                  pdfIds: pdfIds,
                  fromCarousel: true,
                ),
                option,
                sharePositionOrigin: shareOrigin,
              );
      if (!shared && context.mounted) {
        showPlaylistShareErrorSnackbar(context, l10n);
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
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

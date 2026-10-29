import 'dart:async';

import 'package:coldigui/core/utils/share_position_origin.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/carousel/presentation/widgets/active_playlist_name_chip.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_bar_action_button.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_clear_choice_dialog.dart';
import 'package:coldigui/features/live/presentation/providers/live_projection_provider.dart';
import 'package:coldigui/features/playlists/data/providers/playlist_providers.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_share_option.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_share_actions_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/features/playlists/presentation/utils/playlist_share_debug_log.dart';
import 'package:coldigui/features/playlists/presentation/widgets/playlist_share_sheet.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ações da lista à direita da barra: compartilhar e limpar (lixeira — o
/// `clear_all` parecia menu).
///
/// «Salvar como lista» não mora mais aqui: tocar em «Rascunho» na chip do
/// nome ([ActivePlaylistNameChip]) já salva com nome; o menu de três pontos
/// virou um botão único de compartilhar com o ícone da plataforma
/// ([Icons.adaptive.share] — `share` no Android/web, `ios_share` no iOS).
///
/// [showLabels] — repassado a [CarouselBarActionButton] (legenda sob o ícone
/// quando a barra é larga o bastante).
class CarouselBarTrailingActions extends ConsumerStatefulWidget {
  const CarouselBarTrailingActions({this.showLabels = true, super.key});

  final bool showLabels;

  @override
  ConsumerState<CarouselBarTrailingActions> createState() =>
      _CarouselBarTrailingActionsState();
}

class _CarouselBarTrailingActionsState
    extends ConsumerState<CarouselBarTrailingActions> {
  var _sharing = false;

  Future<bool> _canDeleteActiveUnsaved() async {
    final activeId = ref.read(activePlaylistIdProvider);
    if (activeId == null) return false;

    final active = await ref.read(playlistRepositoryProvider).getById(activeId);
    return active != null && !active.salva;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final following = ref.watch(liveProjectionProvider) != null;

    // Seguindo um gestor ao vivo: nem compartilhar nem limpar. A lista
    // projetada é a do gestor — não existe no repositório local, então os
    // links de partilha não resolvem (`GeneratePlaylistShareUrl` procura o
    // `playlistId` localmente); e a camada de dados já ignora mutações
    // (Task 9), então a lixeira só confundiria (spec §6.2).
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!following)
          CarouselBarActionButton(
            icon: Icons.adaptive.share,
            label: l10n.carouselSharePlaylist,
            showLabel: widget.showLabels,
            iconOverride: _sharing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.title,
                    ),
                  )
                : null,
            onPressed: _sharing
                ? null
                : () => unawaited(_openShareSheet(context, ref, l10n)),
          ),
        if (!following)
          CarouselBarActionButton(
            icon: Icons.delete_outline,
            label: l10n.carouselClearShort,
            tooltip: l10n.carouselClear,
            showLabel: widget.showLabels,
            onPressed: () => _confirmClear(context, ref),
          ),
      ],
    );
  }

  Future<void> _openShareSheet(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    playlistShareDebugLog('CarouselBarTrailingActions._openShareSheet: início');
    final shareOrigin = sharePositionOriginFromContextOrFallback(context);
    // A lista ativa **é** a seleção (D3): nada a reconciliar com o carousel.
    final active = ref.read(activePlaylistProvider);
    if (active == null || active.entries.isEmpty) {
      playlistShareDebugLog('_openShareSheet: sem lista ativa ou vazia');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.playlistEmptyPdfList)));
      return;
    }

    final entries = ref
        .read(activeEntriesProvider)
        .map((activeEntry) => activeEntry.entry)
        .toList(growable: false);
    final option = await showPlaylistShareSheet(context);
    if (option == null || !context.mounted) return;

    setState(() => _sharing = true);
    try {
      // Falha ou cancelamento: o próprio provider decide se mostra snackbar
      // (ele diferencia cancelamento de erro — ver doc de
      // `PlaylistShareActionsNotifier.share`).
      await ref
          .read(playlistShareActionsProvider.notifier)
          .share(
            context,
            PlaylistShareContext(
              playlistId: active.playlistId,
              nome: active.nome,
              entries: entries,
              fromCarousel: true,
            ),
            option,
            sharePositionOrigin: shareOrigin,
          );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final canDelete = await _canDeleteActiveUnsaved();
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
  }
}

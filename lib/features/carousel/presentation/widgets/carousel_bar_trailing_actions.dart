import 'dart:async';

import 'package:coldigui/core/utils/share_position_origin.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/carousel/presentation/widgets/active_playlist_name_chip.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_bar_shell.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_clear_choice_dialog.dart';
import 'package:coldigui/features/playlists/data/providers/playlist_providers.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_share_option.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_material_icons.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_media_face.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_media_face_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_share_actions_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/features/playlists/presentation/utils/playlist_share_debug_log.dart';
import 'package:coldigui/features/playlists/presentation/widgets/playlist_share_sheet.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ações à direita da barra: toggle de face, compartilhar a lista e limpar.
///
/// «Salvar como lista» não mora mais aqui: tocar em «Rascunho» na chip do
/// nome ([ActivePlaylistNameChip]) já salva com nome; o menu de três pontos
/// virou um botão único de compartilhar com o ícone da plataforma
/// ([Icons.adaptive.share] — `share` no Android/web, `ios_share` no iOS).
class CarouselBarTrailingActions extends ConsumerStatefulWidget {
  const CarouselBarTrailingActions({super.key});

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
    final face = ref.watch(playlistMediaFaceProvider);
    final isAudioFace = face == PlaylistMediaFace.audio;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          style: carouselBarIconButtonStyle,
          tooltip: isAudioFace ? l10n.playlistFacePdf : l10n.playlistFaceAudio,
          icon: Icon(
            isAudioFace
                ? Icons.picture_as_pdf_outlined
                : LouvorMaterialIcons.audio,
          ),
          onPressed: () =>
              ref.read(playlistMediaFaceProvider.notifier).toggle(),
        ),
        IconButton(
          style: carouselBarIconButtonStyle,
          tooltip: l10n.carouselSharePlaylist,
          icon: _sharing
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.title,
                  ),
                )
              : Icon(Icons.adaptive.share),
          onPressed: _sharing
              ? null
              : () => unawaited(_openShareSheet(context, ref, l10n)),
        ),
        IconButton(
          style: carouselBarIconButtonStyle,
          tooltip: l10n.carouselClear,
          icon: const Icon(Icons.clear_all),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.playlistEmptyPdfList)));
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
      final shared = await ref
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
      if (!shared && context.mounted) {
        showPlaylistShareErrorSnackbar(context, l10n);
      }
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

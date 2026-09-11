import 'dart:async';

import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/features/playlists/presentation/widgets/save_playlist_dialog.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Nome da lista ativa, à esquerda das chips do carousel (C11, spec B.3).
///
/// Lê [activePlaylistProvider] (a lista ativa já resolvida por
/// `PlaylistsNotifier`) e mostra `.nome` — rascunho (`salva == false`) mostra
/// [AppLocalizations.playlistDraftLabel] no lugar do nome default gerado por
/// `defaultPlaylistName` (técnico demais para a barra). Toque abre o mesmo
/// diálogo de renomear do menu do tile ([showSavePlaylistDialog] +
/// `PlaylistsNotifier.rename`).
///
/// `null` (sem lista ativa) → [SizedBox.shrink] — quem monta esta chip
/// (`_CarouselChipsBar`) decide a largura mínima (480 px) abaixo da qual ela
/// some, dando prioridade à chip do louvor.
class ActivePlaylistNameChip extends ConsumerWidget {
  const ActivePlaylistNameChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlist = ref.watch(activePlaylistProvider);
    if (playlist == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final nome = playlist.nome.trim();
    final label = playlist.salva && nome.isNotEmpty
        ? nome
        : (l10n?.playlistDraftLabel ?? 'Rascunho');

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: AppColors.title,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.gold, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => unawaited(_rename(context, ref, playlist, l10n)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                label,
                style: AppTypography.headline.copyWith(
                  fontSize: 13,
                  height: 1.1,
                  color: AppColors.textLight,
                  shadows: const [],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    SavedPlaylist playlist,
    AppLocalizations? l10n,
  ) async {
    final nome = await showSavePlaylistDialog(
      context,
      initialName: playlist.nome,
      title: l10n?.playlistRenameTitle,
      confirmLabel: l10n?.playlistRenameConfirm,
    );
    if (nome == null || !context.mounted) return;
    await ref
        .read(playlistsProvider.notifier)
        .rename(playlistId: playlist.playlistId, nome: nome);
  }
}

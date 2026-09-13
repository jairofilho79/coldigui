import 'dart:async';

import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/carousel/presentation/utils/save_active_playlist_from_bar.dart';
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
/// `defaultPlaylistName` (técnico demais para a barra). Toque num rascunho
/// **salva** a lista com o nome digitado ([saveActivePlaylistFromBar] —
/// `PlaylistsNotifier.saveActivePlaylist`, que promove `salva`); numa lista
/// já salva abre o diálogo de renomear ([showSavePlaylistDialog] +
/// `PlaylistsNotifier.rename`). Renomear nunca promove o rascunho — era o
/// bug em que a chip aceitava o nome e continuava «Rascunho».
///
/// `null` (sem lista ativa) → [SizedBox.shrink] — quem monta esta chip
/// (`_CarouselChipsBar`) decide a largura mínima (480 px) abaixo da qual ela
/// some, dando prioridade à chip do louvor, e passa em [maxWidth] a fatia da
/// barra que o nome pode ocupar (o texto além disso vira reticências).
class ActivePlaylistNameChip extends ConsumerWidget {
  const ActivePlaylistNameChip({super.key, this.maxWidth = defaultMaxWidth});

  /// Largura máxima do texto do nome, sem o padding da chip.
  final double maxWidth;

  /// Teto usado quando quem monta a chip não passa [maxWidth].
  static const double defaultMaxWidth = 160;

  /// Largura do nome para uma barra de [barWidth] px: um quinto da barra,
  /// entre [minTextWidth] e [defaultMaxWidth] — um nome longo nunca engole a
  /// chip do louvor, que tem prioridade.
  static double maxWidthForBar(double barWidth) =>
      (barWidth * 0.2).clamp(minTextWidth, defaultMaxWidth);

  static const double minTextWidth = 72;

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
          onTap: () => unawaited(
            playlist.salva
                ? _rename(context, ref, playlist, l10n)
                : saveActivePlaylistFromBar(
                    context,
                    ref,
                    initialName: playlist.nome,
                  ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
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
                  const SizedBox(width: 6),
                  // O lápis diz que dá para nomear/renomear (spec D9).
                  const Icon(Icons.edit, size: 14, color: AppColors.textLight),
                ],
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

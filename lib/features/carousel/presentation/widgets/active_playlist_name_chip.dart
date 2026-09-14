import 'dart:async';

import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/carousel/presentation/utils/save_active_playlist_from_bar.dart';
import 'package:coldigui/features/live/presentation/providers/live_projection_provider.dart';
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
///
/// Seguindo um gestor ao vivo ([liveProjectionProvider] não nulo, spec
/// §6.2): mostra [_LiveNameChip] com o nome da lista **dele** em vez da lista
/// ativa local — sem edição, sem lixeira (Task 19).
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
    final live = ref.watch(liveProjectionProvider);
    if (live != null) return _LiveNameChip(name: live.name, maxWidth: maxWidth);

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

/// Chip do nome enquanto o consumidor segue um gestor ao vivo: mesma
/// aparência de [ActivePlaylistNameChip] (`Material`/cores/forma/padding),
/// mas com [Icons.sensors] no lugar do lápis e sem `onTap` — nada aqui é
/// editável (spec §6.2, Task 19).
class _LiveNameChip extends StatelessWidget {
  const _LiveNameChip({required this.name, required this.maxWidth});

  final String name;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: AppColors.title,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.gold, width: 2),
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
                    name,
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
                // Sensores, não lápis: seguindo ao vivo, nada aqui edita.
                const Icon(Icons.sensors, size: 14, color: AppColors.textLight),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

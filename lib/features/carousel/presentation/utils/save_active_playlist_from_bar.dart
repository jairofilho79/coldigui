import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/routing/shell_navigation.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_tab.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_ui_provider.dart';
import 'package:coldigui/features/playlists/presentation/widgets/save_playlist_dialog.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Salva a lista ativa a partir da barra do carousel: pede o nome em
/// [showSavePlaylistDialog] e chama `PlaylistsNotifier.saveActivePlaylist`,
/// que promove o rascunho a lista salva (ou renomeia se já salva).
///
/// Único ponto de entrada do «salvar» na barra — a chip do nome
/// (`ActivePlaylistNameChip`) chama isto quando a lista é rascunho; o
/// antigo item «Salvar como lista» do menu foi absorvido por ela.
///
/// Devolve `true` quando salvou. Lista vazia avisa em snackbar e devolve
/// `false`; cancelar o diálogo devolve `false` sem aviso.
Future<bool> saveActivePlaylistFromBar(
  BuildContext context,
  WidgetRef ref, {
  String? initialName,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final nome = await showSavePlaylistDialog(context, initialName: initialName);
  if (nome == null || !context.mounted) return false;

  final saved = await ref
      .read(playlistsProvider.notifier)
      .saveActivePlaylist(nome: nome);
  if (!context.mounted) return saved;

  if (!saved) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.playlistEmptyCarousel)));
    return false;
  }

  ref.read(playlistsUiProvider.notifier).selectTab(PlaylistTab.saved);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(l10n.playlistSaved),
      action: SnackBarAction(
        label: l10n.playlistViewLists,
        onPressed: () {
          ref.read(playlistsUiProvider.notifier).selectTab(PlaylistTab.saved);
          goToShellDestination(context, RoutePaths.playlists);
        },
      ),
    ),
  );
  return true;
}

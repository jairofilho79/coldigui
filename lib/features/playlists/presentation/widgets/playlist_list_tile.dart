import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/storage_unavailable_exception.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/playlist_tab.dart';
import '../../domain/entities/saved_playlist.dart';
import '../providers/playlists_provider.dart';
import '../providers/playlists_ui_provider.dart';
import '../utils/playlist_count_label.dart';
import 'playlist_tile_actions.dart';
import 'playlist_tile_detail_chips.dart';
import 'playlist_tile_header.dart';

/// Tile de playlist com favorito, expansão e ações (UC-06).
///
/// **Design system (jun/2026):** card temático PLPCG — fundo [AppColors.card],
/// borda dourada 2px e sombra [AppColors.shadowMd]. Cabeçalho centralizado com
/// [AppTypography.headline] (nome), hora (`SavedPlaylist.createdAt`) e contagem
/// de louvores. Expansão animada ([AnimatedCrossFade]) revela coluna vertical de
/// [CarouselLouvorChip] variante [CarouselLouvorChipVariant.modal] — paridade
/// visual com modal do carousel e [LouvorCard] (pesquisa/biblioteca).
///
/// Fase 4.2: CRUD (renomear, excluir, remover PDF, favorito).
/// Onda 3 (D6): menu **Editar por aqui** (sem modal — snackbar com
/// «Desfazer») e **Abrir no leitor**; toque em chip expandido abre o PDF
/// selecionado no leitor — os dois tornam a lista ativa
/// ([ActivePlaylistEditor.activate]) e navegam via [openPdfInReaderProvider] +
/// `context.push` (rota `/leitor` com [rootNavigatorKey]).
///
/// Metadados dos chips enriquecidos via [catalogMaterialLookupProvider] quando
/// disponível; fallback parse do label `"numero — nome"` em [PlaylistViewItem.pdfLabels].
///
/// Cabeçalho, chips de detalhe e ações do menu (E4) vivem em
/// [PlaylistTileHeader], [PlaylistTileDetailChips] e [PlaylistTileActions].
class PlaylistListTile extends ConsumerStatefulWidget {
  const PlaylistListTile({required this.item, required this.tab, super.key});

  /// Playlist enriquecida com os rótulos do catálogo para exibição e chips.
  final PlaylistViewItem item;

  /// Aba atual — define ícone de ação no cabeçalho.
  final PlaylistTab tab;

  @override
  ConsumerState<PlaylistListTile> createState() => _PlaylistListTileState();
}

class _PlaylistListTileState extends ConsumerState<PlaylistListTile> {
  var _expanded = false;
  var _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncExpandFromUi());
  }

  void _syncExpandFromUi() {
    if (!mounted) return;
    final expandId = ref.read(playlistsUiProvider).expandPlaylistId;
    if (expandId == widget.item.playlist.playlistId && !_expanded) {
      setState(() => _expanded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(playlistsUiProvider, (_, next) {
      if (next.expandPlaylistId == widget.item.playlist.playlistId &&
          !_expanded) {
        setState(() => _expanded = true);
      }
    });

    final l10n = AppLocalizations.of(context)!;
    final playlist = widget.item.playlist;
    final countLabel = playlistCountLabel(
      l10n,
      pdfs: playlist.pdfIds.length,
      audios: playlist.audioIds.length,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gold, width: 2),
          boxShadow: AppColors.shadowMd,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PlaylistTileHeader(
                nome: _displayName(playlist.nome),
                hora: _formatTime(playlist.createdAt),
                countLabel: countLabel,
                isPublished: playlist.isPublished,
                publicBadgeLabel: l10n.playlistPublicBadge,
                categoryLabel: playlist.publicationCategory == null
                    ? null
                    : _categoryLabel(l10n, playlist.publicationCategory!),
                reachLabel: playlist.publicationReach == null
                    ? null
                    : (playlist.publicationReach == PlaylistReach.usual
                          ? l10n.playlistPublishReachUsual
                          : l10n.playlistPublishReachPontual),
                tab: widget.tab,
                saveTooltip: l10n.playlistSaveAction,
                favoriteOffTooltip: l10n.playlistFavoriteOn,
                favoriteOnTooltip: l10n.playlistFavoriteOff,
                expanded: _expanded,
                loading: _loading,
                onPrimaryAction: () =>
                    _handlePrimaryAction(playlist.playlistId),
                onMenuSelected: (action) => _handleAction(context, action),
                menuItems: _actions(context, l10n).menuItems(),
                onTap: () => setState(() => _expanded = !_expanded),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.gold.withValues(alpha: 0.35),
                    ),
                    PlaylistTileDetailChips(
                      item: widget.item,
                      loading: _loading,
                      onPdfTap: (pdfId) =>
                          _actions(context, l10n).openPdfInReader(pdfId),
                      onAudioTap: (track) =>
                          _actions(context, l10n).openAudioTrack(track),
                    ),
                  ],
                ),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 220),
                sizeCurve: Curves.easeOutCubic,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Monta a ação (UC-06) com o que ela precisa do `State`: `ref`, `context`,
  /// `l10n`, a playlist e os callbacks que espelham `setState` em
  /// `_loading`/`_expanded` (E4 — `PlaylistTileActions`).
  PlaylistTileActions _actions(BuildContext context, AppLocalizations l10n) {
    return PlaylistTileActions(
      ref: ref,
      context: context,
      l10n: l10n,
      playlist: widget.item.playlist,
      tab: widget.tab,
      loading: _loading,
      onLoadingChanged: _setLoading,
      onExpandedChanged: _setExpanded,
    );
  }

  void _setLoading(bool value) {
    if (!mounted) return;
    setState(() => _loading = value);
  }

  void _setExpanded(bool value) {
    if (!mounted) return;
    setState(() => _expanded = value);
  }

  static String _categoryLabel(
    AppLocalizations l10n,
    PlaylistCategory category,
  ) {
    return switch (category) {
      PlaylistCategory.evangelizacao => l10n.playlistCategoryEvangelizacao,
      PlaylistCategory.aprendizado => l10n.playlistCategoryAprendizado,
      PlaylistCategory.medleys => l10n.playlistCategoryMedleys,
      PlaylistCategory.cultoEspecial => l10n.playlistCategoryCultoEspecial,
    };
  }

  Future<void> _handlePrimaryAction(String playlistId) async {
    final notifier = ref.read(playlistsProvider.notifier);
    switch (widget.tab) {
      case PlaylistTab.unsaved:
        await notifier.savePlaylist(playlistId);
      case PlaylistTab.saved:
        await notifier.favoritePlaylist(playlistId);
      case PlaylistTab.favorites:
        await notifier.unfavoritePlaylist(playlistId);
    }
  }

  /// Porteira única de storage das ações do menu.
  ///
  /// Carregar, renomear, publicar e excluir acabam todos numa escrita; sem
  /// Isar elas lançam [StorageUnavailableException] de dentro do callback do
  /// menu, onde viraria erro solto e nenhum aviso. Um `catch` só no topo, com
  /// a mesma mensagem que a tela de listas já usa.
  Future<void> _handleAction(BuildContext context, String action) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await _actions(context, l10n).run(action);
    } on StorageUnavailableException catch (e) {
      debugPrint('[playlists] ação "$action" sem storage: $e');
      if (context.mounted) {
        showAppSnackbar(context, l10n.offlineStorageUnavailable);
      }
    }
  }

  static String _displayName(String nome) {
    if (nome.isEmpty) return nome;
    return nome[0].toUpperCase() + nome.substring(1);
  }

  static String _formatTime(DateTime dateTime) {
    final h = dateTime.hour.toString().padLeft(2, '0');
    final m = dateTime.minute.toString().padLeft(2, '0');
    final s = dateTime.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

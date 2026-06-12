import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/share_position_origin.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../carousel/presentation/providers/carousel_louvores_provider.dart';
import '../../../offline/data/providers/offline_providers.dart';
import '../../../offline/domain/exceptions/pdf_resolve_exceptions.dart';
import '../../../pdf_opening/data/providers/pdf_opening_providers.dart';
import '../../../pdf_opening/domain/utils/louvor_pdf_path.dart';
import '../../../pdf_reader/domain/exceptions/invalid_pdf_path_exception.dart';
import '../../../catalog/presentation/providers/louvores_manifest_provider.dart';
import '../../domain/entities/playlist_tab.dart';
import '../providers/playlists_provider.dart';
import '../utils/playlist_open_debug_log.dart';
import '../utils/playlist_share_debug_log.dart';
import 'save_playlist_dialog.dart';

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
/// Fase 4.3: menu **Carregar no carousel** e **Abrir no leitor**; toque em
/// chip expandido abre o PDF selecionado no leitor — ambos confirmam
/// substituição quando [carouselLouvoresProvider] não está vazio, carregam a
/// playlist no carousel e navegam via [openPdfInReaderProvider] +
/// `context.push` (rota `/leitor` com [rootNavigatorKey]).
///
/// Metadados dos chips enriquecidos via [louvoresManifestProvider] quando
/// disponível; fallback parse do label `"numero — nome"` em [PlaylistViewItem.pdfLabels].
class PlaylistListTile extends ConsumerStatefulWidget {
  const PlaylistListTile({
    required this.item,
    required this.tab,
    super.key,
  });

  /// Playlist enriquecida com labels do manifest para exibição e chips.
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final playlist = widget.item.playlist;
    final count = playlist.pdfIds.length;

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
              _PlaylistHeader(
                nome: _displayName(playlist.nome),
                hora: _formatTime(playlist.createdAt),
                countLabel: l10n.playlistPdfCount(count),
                tab: widget.tab,
                saveTooltip: l10n.playlistSaveAction,
                favoriteOffTooltip: l10n.playlistFavoriteOn,
                favoriteOnTooltip: l10n.playlistFavoriteOff,
                expanded: _expanded,
                loading: _loading,
                onPrimaryAction: () =>
                    _handlePrimaryAction(playlist.playlistId),
                onMenuSelected: (action) => _handleAction(context, action),
                menuItems: _menuItems(l10n),
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
                    _PlaylistDetailChips(
                      item: widget.item,
                      loading: _loading,
                      onPdfTap: (pdfId) => _openPdfInReader(pdfId),
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

  List<PopupMenuEntry<String>> _menuItems(AppLocalizations l10n) {
    return [
      PopupMenuItem(value: 'load', child: Text(l10n.playlistLoadIntoCarousel)),
      PopupMenuItem(
        value: 'openReader',
        child: Text(l10n.playlistOpenInReader),
      ),
      PopupMenuItem(value: 'share', child: Text(l10n.playlistShare)),
      PopupMenuItem(value: 'rename', child: Text(l10n.playlistRename)),
      PopupMenuItem(value: 'delete', child: Text(l10n.playlistDelete)),
    ];
  }

  void _showError(String message) {
    if (!mounted) return;
    showAppSnackbar(context, message);
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

  Future<bool> _confirmReplaceIfNeeded(AppLocalizations l10n) async {
    final carouselItems = ref.read(carouselLouvoresProvider);
    if (carouselItems.isEmpty) return true;

    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.playlistLoadConfirmTitle,
      message: l10n.playlistLoadConfirmMessage,
    );
    return confirmed == true;
  }

  Future<void> _openPdfInReader(String pdfId) async {
    if (_loading) return;

    final l10n = AppLocalizations.of(context)!;
    final playlist = widget.item.playlist;
    playlistOpenDebugClearLastFailure();
    playlistOpenDebugLog(
      '_openPdfInReader: início playlistId=${playlist.playlistId} '
      'salva=${playlist.salva} pdfId=$pdfId '
      'pdfIds (${playlist.pdfIds.length}): ${playlist.pdfIds.join(', ')}',
    );

    setState(() => _loading = true);
    try {
      final loaded = await _loadPlaylist(l10n);
      if (!loaded || !mounted) return;

      final louvor =
          ref.read(playlistsProvider.notifier).findLouvorByPdfId(pdfId);
      if (louvor == null) {
        if (mounted) showPlaylistOpenErrorSnackbar(context, l10n);
        return;
      }

      final remotePath = LouvorPdfPath.fromLouvor(louvor);
      playlistOpenDebugLog(
        '_openPdfInReader: resolvePdf pdfId=${louvor.pdfId} '
        'remotePath=$remotePath',
      );
      final source = await ref.read(resolvePdfForReaderProvider)(
        pdfId: louvor.pdfId,
        remotePath: remotePath,
      );
      playlistOpenDebugLog(
        '_openPdfInReader: resolvePdf ok path=${source.absolutePath} '
        'fromCache=${source.fromCache}',
      );
      if (!mounted) return;

      final location = ref.read(openPdfInReaderProvider).call(
            pdfPath: source.absolutePath,
            pdfId: louvor.pdfId,
            titulo: louvor.nome,
          );
      playlistOpenDebugLog('_openPdfInReader: navegando → $location');
      if (!mounted) return;
      await context.push(location);
      playlistOpenDebugLog('_openPdfInReader: concluído');
    } on InvalidPdfPathException catch (error, stackTrace) {
      playlistOpenDebugLogError('caminho PDF inválido', error, stackTrace);
      if (mounted) showPlaylistOpenErrorSnackbar(context, l10n);
    } on PdfOfflineUnavailableException catch (e) {
      playlistOpenDebugLogFailure('PDF offline indisponível', e.message);
      _showError(e.message);
    } on PdfExternallyDeletedException catch (e) {
      playlistOpenDebugLogFailure('PDF removido externamente', e.message);
      _showError(e.message);
    } on PdfFetchFailedException catch (e, stackTrace) {
      playlistOpenDebugLogError('falha ao baixar PDF', e, stackTrace);
      _showError(e.message);
    } on Object catch (error, stackTrace) {
      playlistOpenDebugLogError('_openPdfInReader', error, stackTrace);
      if (mounted) showPlaylistOpenErrorSnackbar(context, l10n);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _loadPlaylist(AppLocalizations l10n) async {
    final playlist = widget.item.playlist;
    playlistOpenDebugLog(
      '_loadPlaylist: playlistId=${playlist.playlistId} '
      'pdfIds (${playlist.pdfIds.length})',
    );
    if (playlist.pdfIds.isEmpty) {
      playlistOpenDebugLogFailure(
        '_loadPlaylist',
        'playlist sem pdfIds',
      );
      _showError(l10n.playlistEmptyPdfList);
      return false;
    }

    if (!await _confirmReplaceIfNeeded(l10n) || !context.mounted) {
      playlistOpenDebugLog('_loadPlaylist: cancelado pelo usuário');
      return false;
    }

    final loaded = await ref
        .read(playlistsProvider.notifier)
        .loadIntoCarousel(playlist.playlistId);
    if (!context.mounted) return false;

    if (!loaded) {
      playlistOpenDebugLogFailure(
        '_loadPlaylist',
        'loadIntoCarousel retornou false',
      );
      showPlaylistOpenErrorSnackbar(context, l10n);
      return false;
    }

    playlistOpenDebugLog('_loadPlaylist: ok');
    return true;
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    final l10n = AppLocalizations.of(context)!;
    final playlist = widget.item.playlist;

    switch (action) {
      case 'load':
        if (_loading) return;
        setState(() => _loading = true);
        try {
          final loaded = await _loadPlaylist(l10n);
          if (loaded && context.mounted) {
            showAppSnackbar(context, l10n.playlistLoaded);
          }
        } finally {
          if (mounted) setState(() => _loading = false);
        }
      case 'openReader':
        await _openPdfInReader(playlist.pdfIds.first);
      case 'share':
        if (playlist.pdfIds.isEmpty) {
          _showError(l10n.playlistEmptyPdfList);
          return;
        }
        if (_loading) return;
        final shareOrigin = sharePositionOriginFromContextOrFallback(context);
        setState(() => _loading = true);
        try {
          playlistShareDebugLog(
            'PlaylistListTile.share: id=${playlist.playlistId} '
            'pdfIds (${playlist.pdfIds.length})',
          );
          final shared =
              await ref.read(playlistsProvider.notifier).sharePlaylist(
                    playlistId: playlist.playlistId,
                    subject: playlist.nome,
                    sharePositionOrigin: shareOrigin,
                  );
          if (!shared && context.mounted) {
            showPlaylistShareErrorSnackbar(context, l10n);
          }
        } finally {
          if (mounted) setState(() => _loading = false);
        }
      case 'rename':
        final nome = await showSavePlaylistDialog(
          context,
          initialName: playlist.nome,
          title: l10n.playlistRenameTitle,
          confirmLabel: l10n.playlistRenameConfirm,
        );
        if (nome == null || !context.mounted) return;
        await ref.read(playlistsProvider.notifier).rename(
              playlistId: playlist.playlistId,
              nome: nome,
            );
      case 'delete':
        final confirmed = await showConfirmDialog(
          context: context,
          title: l10n.playlistDeleteConfirmTitle,
          message: l10n.playlistDeleteConfirmMessage,
        );
        if (confirmed != true || !context.mounted) return;
        await ref.read(playlistsProvider.notifier).delete(playlist.playlistId);
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

class _PlaylistHeader extends StatelessWidget {
  const _PlaylistHeader({
    required this.nome,
    required this.hora,
    required this.countLabel,
    required this.tab,
    required this.saveTooltip,
    required this.favoriteOffTooltip,
    required this.favoriteOnTooltip,
    required this.expanded,
    required this.loading,
    required this.onPrimaryAction,
    required this.onMenuSelected,
    required this.menuItems,
    required this.onTap,
  });

  final String nome;
  final String hora;
  final String countLabel;
  final PlaylistTab tab;
  final String saveTooltip;
  final String favoriteOffTooltip;
  final String favoriteOnTooltip;
  final bool expanded;
  final bool loading;
  final VoidCallback onPrimaryAction;
  final ValueChanged<String> onMenuSelected;
  final List<PopupMenuEntry<String>> menuItems;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    tooltip: switch (tab) {
                      PlaylistTab.unsaved => saveTooltip,
                      PlaylistTab.saved => favoriteOnTooltip,
                      PlaylistTab.favorites => favoriteOffTooltip,
                    },
                    onPressed: loading ? null : onPrimaryAction,
                    icon: Icon(
                      switch (tab) {
                        PlaylistTab.unsaved => Icons.save_outlined,
                        PlaylistTab.saved => Icons.star_outline_rounded,
                        PlaylistTab.favorites => Icons.star_rounded,
                      },
                      color: tab == PlaylistTab.favorites
                          ? AppColors.gold
                          : AppColors.title.withValues(alpha: 0.45),
                      size: 26,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          nome,
                          style: AppTypography.headline.copyWith(
                            fontSize: 17,
                            color: AppColors.title,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hora,
                          style: AppTypography.body.copyWith(
                            fontSize: 13,
                            color: AppColors.title.withValues(alpha: 0.65),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          countLabel,
                          style: AppTypography.label.copyWith(
                            fontSize: 12,
                            color: AppColors.title.withValues(alpha: 0.8),
                            letterSpacing: 0.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: loading
                        ? const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.gold,
                              ),
                            ),
                          )
                        : PopupMenuButton<String>(
                            onSelected: onMenuSelected,
                            icon: Icon(
                              Icons.more_horiz_rounded,
                              color: AppColors.title.withValues(alpha: 0.75),
                            ),
                            color: AppColors.card,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(
                                color: AppColors.gold,
                                width: 1.5,
                              ),
                            ),
                            itemBuilder: (context) => menuItems,
                          ),
                  ),
                ],
              ),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: Icon(
                  Icons.expand_more_rounded,
                  size: 20,
                  color: AppColors.title.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistDetailChips extends ConsumerWidget {
  const _PlaylistDetailChips({
    required this.item,
    required this.loading,
    required this.onPdfTap,
  });

  final PlaylistViewItem item;
  final bool loading;
  final Future<void> Function(String pdfId) onPdfTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < item.playlist.pdfIds.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            CarouselLouvorChip(
              item: _carouselItemFor(
                pdfId: item.playlist.pdfIds[i],
                label: item.pdfLabels[i],
                index: i,
                findLouvor: (pdfId) => _findLouvorFromManifest(ref, pdfId),
              ),
              onTap: loading ? null : () => onPdfTap(item.playlist.pdfIds[i]),
              onRemove: loading
                  ? null
                  : () async {
                      if (item.playlist.pdfIds.length == 1) {
                        final confirmed = await showConfirmDialog(
                          context: context,
                          title: l10n.playlistDeleteLastPdfTitle,
                          message: l10n.playlistDeleteLastPdfMessage,
                        );
                        if (confirmed != true || !context.mounted) return;
                      }

                      await ref.read(playlistsProvider.notifier).removePdf(
                            playlistId: item.playlist.playlistId,
                            pdfId: item.playlist.pdfIds[i],
                          );
                    },
            ),
          ],
        ],
      ),
    );
  }

  static Louvor? _findLouvorFromManifest(WidgetRef ref, String pdfId) {
    try {
      final catalog = ref.read(louvoresManifestProvider).asData?.value;
      if (catalog == null) return null;
      for (final louvor in catalog) {
        if (louvor.pdfId == pdfId) return louvor;
      }
    } on Object {
      return null;
    }
    return null;
  }

  static CarouselItem _carouselItemFor({
    required String pdfId,
    required String label,
    required int index,
    required Louvor? Function(String pdfId) findLouvor,
  }) {
    final louvor = findLouvor(pdfId);
    if (louvor != null) {
      return CarouselItem(
        pdfId: pdfId,
        sortOrder: index,
        numero: louvor.numero,
        nome: louvor.nome,
        categoria: louvor.categoria,
        classificacao: louvor.classificacao,
      );
    }

    final dashIndex = label.indexOf(' — ');
    if (dashIndex > 0) {
      return CarouselItem(
        pdfId: pdfId,
        sortOrder: index,
        numero: label.substring(0, dashIndex).trim(),
        nome: label.substring(dashIndex + 3).trim(),
        categoria: '',
        classificacao: '',
      );
    }

    return CarouselItem(
      pdfId: pdfId,
      sortOrder: index,
      numero: '',
      nome: label,
      categoria: '',
      classificacao: '',
    );
  }
}

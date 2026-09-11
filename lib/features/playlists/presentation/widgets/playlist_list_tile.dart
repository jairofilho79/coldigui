import 'dart:async';

import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/audio_player/presentation/utils/active_list_audio_queue.dart';
import 'package:coldigui/features/audio_player/presentation/utils/open_audio_in_player.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/core/utils/material_id_kind.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/catalog/domain/utils/find_louvor_by_pdf_id.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/storage_unavailable_exception.dart';
import '../../../../core/errors/user_message_for.dart';
import '../../../../core/utils/share_position_origin.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../offline/data/providers/offline_providers.dart';
import '../../../pdf_opening/data/providers/pdf_opening_providers.dart';
import '../../../pdf_opening/domain/utils/louvor_pdf_path.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../auth/presentation/widgets/create_username_dialog.dart';
import '../../../catalog/presentation/providers/louvores_manifest_provider.dart';
import '../../../catalog/domain/usecases/resolve_catalog_material.dart';
import '../../../catalog/presentation/providers/catalog_material_lookup_provider.dart';
import '../../../catalog/presentation/providers/open_material_provider.dart';
import '../../domain/entities/playlist_media_face.dart';
import '../../domain/entities/playlist_tab.dart';
import '../../domain/entities/playlist_share_option.dart';
import '../../domain/entities/saved_playlist.dart';
import '../providers/active_playlist_editor.dart';
import '../providers/playlist_media_face_provider.dart';
import '../providers/playlist_share_actions_provider.dart';
import '../providers/playlists_provider.dart';
import '../providers/playlists_ui_provider.dart';
import '../utils/playlist_open_debug_log.dart';
import '../utils/playlist_share_debug_log.dart';
import 'playlist_audio_face_panel.dart';
import 'playlist_share_sheet.dart';
import 'publish_playlist_dialog.dart';
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
/// Onda 3 (D6): menu **Tornar lista ativa** (sem modal — snackbar com
/// «Desfazer») e **Abrir no leitor**; toque em chip expandido abre o PDF
/// selecionado no leitor — os dois tornam a lista ativa
/// ([ActivePlaylistEditor.activate]) e navegam via [openPdfInReaderProvider] +
/// `context.push` (rota `/leitor` com [rootNavigatorKey]).
///
/// Metadados dos chips enriquecidos via [louvoresManifestProvider] quando
/// disponível; fallback parse do label `"numero — nome"` em [PlaylistViewItem.pdfLabels].
class PlaylistListTile extends ConsumerStatefulWidget {
  const PlaylistListTile({required this.item, required this.tab, super.key});

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
    final face = ref.watch(playlistMediaFaceProvider);
    final countLabel = face == PlaylistMediaFace.audio
        ? l10n.playlistAudioCount(playlist.audioIds.length)
        : l10n.playlistPdfCount(playlist.pdfIds.length);

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
                menuItems: _menuItems(l10n, playlist, face),
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
                    if (face == PlaylistMediaFace.audio)
                      PlaylistAudioFacePanel(playlist: playlist)
                    else
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

  List<PopupMenuEntry<String>> _menuItems(
    AppLocalizations l10n,
    SavedPlaylist playlist,
    PlaylistMediaFace face,
  ) {
    final hasUsername =
        ref.watch(authStateProvider).asData?.value?.hasUsername ?? false;

    return [
      PopupMenuItem(value: 'activate', child: Text(l10n.playlistActivate)),
      PopupMenuItem(
        value: face == PlaylistMediaFace.audio ? 'openAudio' : 'openReader',
        child: Text(
          face == PlaylistMediaFace.audio
              ? l10n.playlistOpenInAudioPlayer
              : l10n.playlistOpenInReader,
        ),
      ),
      PopupMenuItem(value: 'share', child: Text(l10n.playlistShare)),
      if (playlist.salva && !playlist.isPublished)
        PopupMenuItem(
          value: 'publish',
          child: Tooltip(
            message: hasUsername ? '' : l10n.usernameRequiredToPublish,
            child: Opacity(
              opacity: hasUsername ? 1 : 0.45,
              child: Text(l10n.playlistPublish),
            ),
          ),
        ),
      PopupMenuItem(value: 'rename', child: Text(l10n.playlistRename)),
      PopupMenuItem(value: 'delete', child: Text(l10n.playlistDelete)),
    ];
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

  /// «Tornar lista ativa» (D6): sem modal — a lista que era ativa continua
  /// existindo, então não há o que "substituir". O snackbar oferece
  /// «Desfazer», que devolve a ativação à lista anterior quando havia uma.
  Future<void> _activate(BuildContext context, AppLocalizations l10n) async {
    if (_loading) return;
    final playlist = widget.item.playlist;
    setState(() => _loading = true);
    final String? previous;
    try {
      previous = await ref
          .read(activePlaylistEditorProvider.notifier)
          .activate(playlist.playlistId);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    if (!context.mounted) return;

    final previousId = previous;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.playlistActivated(_displayName(playlist.nome))),
        duration: const Duration(seconds: 5),
        action: previousId == null
            ? null
            : SnackBarAction(
                label: l10n.undo,
                onPressed: () => unawaited(_undoActivate(previousId, l10n)),
              ),
      ),
    );
  }

  /// Volta a ativação para [previousId]. Mesma porteira de storage das ações
  /// do menu: o callback do snackbar também não tem quem trate a exceção.
  Future<void> _undoActivate(String previousId, AppLocalizations l10n) async {
    try {
      await ref
          .read(activePlaylistEditorProvider.notifier)
          .activate(previousId);
    } on StorageUnavailableException catch (e) {
      debugPrint('[playlists] desfazer ativação sem storage: $e');
      _showError(l10n.offlineStorageUnavailable);
    }
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

      // Cifra, áudio e PDF dividem o mesmo espaço de ids, então a entrada da
      // lista só se revela ao ser decodificada. O que não é PDF vai pelo ponto
      // único de abertura; sem este desvio a cifra cairia no findLouvorByPdfId
      // (que só conhece PDFs) e viraria erro genérico. O caminho de PDF fica
      // abaixo porque ele tem pré-fetch e skeleton próprios.
      if (materialIdKindOf(pdfId) != MaterialKind.pdf) {
        final material = await resolveCatalogMaterialFromWidget(ref, pdfId);
        if (!mounted) return;
        if (material != null) {
          playlistOpenDebugLog(
            '_openPdfInReader: material ${material.kind.name} → opener',
          );
          await ref.read(openMaterialProvider).open(context, ref, material);
          playlistOpenDebugLog('_openPdfInReader: concluído');
          return;
        }
        if (materialIdKindOf(pdfId) == MaterialKind.chord) {
          // Cache frio: segue para o caminho de erro comum abaixo.
          playlistOpenDebugLogFailure(
            '_openPdfInReader',
            'cifra $pdfId fora do cache',
          );
        }
      }

      final louvor = ref
          .read(playlistsProvider.notifier)
          .findLouvorByPdfId(pdfId);
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

      final location = ref
          .read(openPdfInReaderProvider)
          .call(
            pdfPath: source.absolutePath,
            pdfId: louvor.pdfId,
            titulo: louvor.nome,
          );
      playlistOpenDebugLog('_openPdfInReader: navegando → $location');
      if (!mounted) return;
      await context.push(location);
      playlistOpenDebugLog('_openPdfInReader: concluído');
    } on Object catch (error, stackTrace) {
      // Escada única de exceções de abertura (compartilhada com o carousel);
      // aqui ela ganha o log de diagnóstico UC-06 e a snackbar com resumo.
      final failure = classifyMaterialOpenFailure(
        error,
        genericStage: '_openPdfInReader',
      );
      // A escada reconhece o erro quando ele traz mensagem própria (falha de
      // download) ou quando é um caso esperado, sem stack (offline, apagado,
      // corrompido). O texto vem de [userMessageFor]: essas exceções não
      // carregam mais literal PT, e ler `failure.message` direto aqui faria o
      // "PDF removido do dispositivo" virar o erro genérico da playlist (D.6).
      // Sem reconhecimento — `InvalidPdfPathException`, erro desconhecido —
      // segue valendo a snackbar de playlist, que em debug leva o diagnóstico.
      final explained = failure.message != null || !failure.logWithStack;
      final message = explained ? userMessageFor(l10n, error) : null;
      if (message != null && !failure.logWithStack) {
        playlistOpenDebugLogFailure(failure.stage, message);
      } else {
        playlistOpenDebugLogError(failure.stage, error, stackTrace);
      }
      if (message != null) {
        _showError(message);
      } else if (mounted) {
        showPlaylistOpenErrorSnackbar(context, l10n);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Torna a lista ativa antes de abrir uma entrada dela no leitor (D6).
  ///
  /// Sem confirmação: a lista anterior continua salva. `false` só quando a
  /// lista não tem face de partituras para abrir.
  Future<bool> _loadPlaylist(AppLocalizations l10n) async {
    final playlist = widget.item.playlist;
    playlistOpenDebugLog(
      '_loadPlaylist: playlistId=${playlist.playlistId} '
      'pdfIds (${playlist.pdfIds.length})',
    );
    if (playlist.pdfIds.isEmpty) {
      playlistOpenDebugLogFailure('_loadPlaylist', 'playlist sem pdfIds');
      _showError(l10n.playlistEmptyPdfList);
      return false;
    }

    await ref
        .read(activePlaylistEditorProvider.notifier)
        .activate(playlist.playlistId);
    if (!mounted) return false;

    playlistOpenDebugLog('_loadPlaylist: ok');
    return true;
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
      await _runAction(context, l10n, action);
    } on StorageUnavailableException catch (e) {
      debugPrint('[playlists] ação "$action" sem storage: $e');
      if (context.mounted) {
        showAppSnackbar(context, l10n.offlineStorageUnavailable);
      }
    }
  }

  Future<void> _runAction(
    BuildContext context,
    AppLocalizations l10n,
    String action,
  ) async {
    final playlist = widget.item.playlist;

    switch (action) {
      case 'activate':
        await _activate(context, l10n);
      case 'openReader':
        // Ativa e abre a **primeira entrada da face de partituras** — que é
        // o que `pdfIds` projeta (tudo que não é áudio, na ordem).
        if (playlist.pdfIds.isEmpty) {
          _showError(l10n.playlistEmptyPdfList);
          return;
        }
        await _openPdfInReader(playlist.pdfIds.first);
      case 'openAudio':
        if (playlist.audioIds.isEmpty) {
          _showError(l10n.playlistAudioEmpty);
          return;
        }
        setState(() => _expanded = true);
        final tracks = ref
            .read(catalogMaterialLookupProvider)
            .tracksFor(playlist.audioIds);
        if (tracks.isEmpty) {
          _showError(l10n.playlistAudioEmpty);
          return;
        }
        // D4: se a faixa já está na lista ativa, a fila é a lista ativa.
        await openAudioInPlayer(
          ref: ref,
          context: context,
          track: tracks.first,
          queue: queueForTrack(
            track: tracks.first,
            groupTracks: tracks,
            activeQueue: activeListAudioQueue(ref),
          ),
        );
      case 'share':
        if (playlist.pdfIds.isEmpty && playlist.audioIds.isEmpty) {
          _showError(l10n.playlistEmptyPdfList);
          return;
        }
        if (_loading) return;
        final shareOrigin = sharePositionOriginFromContextOrFallback(context);
        final option = await showPlaylistShareSheet(context);
        if (option == null || !context.mounted) return;

        setState(() => _loading = true);
        try {
          playlistShareDebugLog(
            'PlaylistListTile.share: id=${playlist.playlistId} '
            'option=$option pdfIds (${playlist.pdfIds.length})',
          );
          final shared = await ref
              .read(playlistShareActionsProvider.notifier)
              .share(
                context,
                PlaylistShareContext(
                  playlistId: playlist.playlistId,
                  nome: playlist.nome,
                  pdfIds: playlist.pdfIds,
                ),
                option,
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
        await ref
            .read(playlistsProvider.notifier)
            .rename(playlistId: playlist.playlistId, nome: nome);
      case 'publish':
        if (playlist.isPublished) return;
        final hasUsername =
            ref.read(authStateProvider).asData?.value?.hasUsername ?? false;
        if (!hasUsername) {
          await showCreateUsernameDialog(context);
          return;
        }
        final result = await showPublishPlaylistDialog(context);
        if (result == null || !context.mounted) return;
        await ref
            .read(playlistsProvider.notifier)
            .publishPlaylist(
              playlistId: playlist.playlistId,
              category: result.category,
              reach: result.reach,
            );
        if (context.mounted) {
          showAppSnackbar(context, l10n.playlistPublished);
        }
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
    required this.isPublished,
    required this.publicBadgeLabel,
    required this.categoryLabel,
    required this.reachLabel,
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
  final bool isPublished;
  final String publicBadgeLabel;
  final String? categoryLabel;
  final String? reachLabel;
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
                        if (isPublished) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Chip(
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                avatar: const Icon(
                                  Icons.public,
                                  size: 16,
                                  color: AppColors.gold,
                                ),
                                label: Text(
                                  publicBadgeLabel,
                                  style: AppTypography.label.copyWith(
                                    fontSize: 11,
                                    color: AppColors.title,
                                  ),
                                ),
                                side: const BorderSide(color: AppColors.gold),
                                backgroundColor: AppColors.card,
                              ),
                              if (categoryLabel != null)
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  label: Text(
                                    categoryLabel!,
                                    style: AppTypography.label.copyWith(
                                      fontSize: 11,
                                      color: AppColors.title,
                                    ),
                                  ),
                                  side: BorderSide(
                                    color: AppColors.gold.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                  backgroundColor: AppColors.card,
                                ),
                              if (reachLabel != null)
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  label: Text(
                                    reachLabel!,
                                    style: AppTypography.label.copyWith(
                                      fontSize: 11,
                                      color: AppColors.title,
                                    ),
                                  ),
                                  side: BorderSide(
                                    color: AppColors.gold.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                  backgroundColor: AppColors.card,
                                ),
                            ],
                          ),
                        ],
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

                      await ref
                          .read(playlistsProvider.notifier)
                          .removePdf(
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
      final catalog = ref.read(louvoresManifestProvider).asData?.value.louvores;
      return findLouvorByPdfIdWithColdigom(
        catalog,
        pdfId,
        coldigomCache: ref.read(coldigomLouvoresCacheProvider),
      );
    } on Object {
      return null;
    }
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
        source: louvor.source,
      );
    }

    final inferredSource = louvorDataSourceFromPdfId(pdfId);
    final dashIndex = label.indexOf(' — ');
    if (dashIndex > 0) {
      return CarouselItem(
        pdfId: pdfId,
        sortOrder: index,
        numero: label.substring(0, dashIndex).trim(),
        nome: label.substring(dashIndex + 3).trim(),
        categoria: '',
        classificacao: '',
        source: inferredSource,
      );
    }

    return CarouselItem(
      pdfId: pdfId,
      sortOrder: index,
      numero: '',
      nome: label,
      categoria: '',
      classificacao: '',
      source: inferredSource,
    );
  }
}

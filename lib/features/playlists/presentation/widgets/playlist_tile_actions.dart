import 'dart:async';

import 'package:coldigui/features/audio_player/presentation/utils/active_list_audio_queue.dart';
import 'package:coldigui/features/audio_player/presentation/utils/open_audio_in_player.dart';
import 'package:coldigui/core/utils/material_id_kind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/storage_unavailable_exception.dart';
import '../../../../core/errors/user_message_for.dart';
import '../../../../core/utils/share_position_origin.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../offline/data/providers/offline_providers.dart';
import '../../../pdf_opening/data/providers/pdf_opening_providers.dart';
import '../../../pdf_opening/domain/utils/louvor_pdf_path.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../auth/presentation/widgets/create_username_dialog.dart';
import '../../../catalog/domain/usecases/resolve_catalog_material.dart';
import '../../../catalog/presentation/providers/catalog_material_lookup_provider.dart';
import '../../../catalog/presentation/providers/open_material_provider.dart';
import '../../domain/entities/playlist_media_face.dart';
import '../../domain/entities/playlist_share_option.dart';
import '../../domain/entities/saved_playlist.dart';
import '../providers/active_playlist_editor.dart';
import '../providers/active_playlist_provider.dart';
import '../providers/playlist_share_actions_provider.dart';
import '../providers/playlists_provider.dart';
import '../utils/playlist_open_debug_log.dart';
import '../utils/playlist_share_debug_log.dart';
import 'playlist_share_sheet.dart';
import 'publish_playlist_dialog.dart';
import 'save_playlist_dialog.dart';

/// Ações do menu e do primário-de-conteúdo de [PlaylistListTile]: ativar,
/// abrir no leitor/áudio, compartilhar, renomear, publicar e excluir
/// (UC-06); também monta os itens do [PopupMenuButton].
///
/// Extraído de `playlist_list_tile.dart` (E4) — mesma lógica do antigo
/// `_runAction`/`_menuItems`, só que recebendo por parâmetro do construtor o
/// que antes vinha do `State` (`ref`, `context`, `playlist`) e os callbacks
/// que alteram o estado do tile (`loading`, `expanded`) em vez de mexer
/// direto em campos do `State`.
class PlaylistTileActions {
  PlaylistTileActions({
    required this.ref,
    required this.context,
    required this.l10n,
    required this.playlist,
    required this.loading,
    required this.onLoadingChanged,
    required this.onExpandedChanged,
  });

  final WidgetRef ref;
  final BuildContext context;
  final AppLocalizations l10n;
  final SavedPlaylist playlist;

  /// Valor de `_loading` do tile no instante em que esta ação foi criada.
  final bool loading;

  /// Espelha `setState(() => _loading = value)` no `State` do tile.
  final ValueChanged<bool> onLoadingChanged;

  /// Espelha `setState(() => _expanded = value)` no `State` do tile.
  final ValueChanged<bool> onExpandedChanged;

  List<PopupMenuEntry<String>> menuItems(PlaylistMediaFace face) {
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
      PopupMenuItem(value: 'duplicate', child: Text(l10n.playlistDuplicate)),
      PopupMenuItem(
        value: 'generateLeaflet',
        child: Text(l10n.carouselGenerateLeaflet),
      ),
      PopupMenuItem(value: 'delete', child: Text(l10n.playlistDelete)),
    ];
  }

  void _showError(String message) {
    if (!context.mounted) return;
    showAppSnackbar(context, message);
  }

  /// «Tornar lista ativa» (D6): sem modal — a lista que era ativa continua
  /// existindo, então não há o que "substituir". O snackbar oferece
  /// «Desfazer», que devolve a ativação à lista anterior quando havia uma.
  ///
  /// O snackbar vive 5 s no messenger da raiz, e o tile pode sair da árvore
  /// nesse meio-tempo (troca de aba): o callback **não toca em `ref`** — usa
  /// o notifier e o container capturados antes de mostrar. Snackbars
  /// enfileiram, então o anterior é limpo e o desfazer só age se esta lista
  /// ainda for a ativa (um «Desfazer» antigo não derruba ativação mais nova).
  Future<void> _activate() async {
    if (loading) return;
    final editor = ref.read(activePlaylistEditorProvider.notifier);
    final container = ProviderScope.containerOf(context, listen: false);
    onLoadingChanged(true);
    final String? previous;
    try {
      previous = await editor.activate(playlist.playlistId);
    } finally {
      onLoadingChanged(false);
    }
    if (!context.mounted) return;

    final previousId = previous;
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.playlistActivated(_displayName(playlist.nome))),
        duration: const Duration(seconds: 5),
        // Já era a ativa: não há para onde voltar.
        action: previousId == null || previousId == playlist.playlistId
            ? null
            : SnackBarAction(
                label: l10n.undo,
                onPressed: () => unawaited(
                  _undoActivate(
                    editor: editor,
                    container: container,
                    messenger: messenger,
                    playlistId: playlist.playlistId,
                    previousId: previousId,
                    l10n: l10n,
                  ),
                ),
              ),
      ),
    );
  }

  /// Volta a ativação para [previousId] — só se [playlistId] ainda for a
  /// ativa. Sem `ref` nem `context`: o tile pode já ter sido desmontado.
  /// Mesma porteira de storage das ações do menu: o callback do snackbar
  /// também não tem quem trate a exceção.
  static Future<void> _undoActivate({
    required ActivePlaylistEditor editor,
    required ProviderContainer container,
    required ScaffoldMessengerState messenger,
    required String playlistId,
    required String previousId,
    required AppLocalizations l10n,
  }) async {
    if (container.read(activePlaylistIdProvider) != playlistId) return;
    try {
      await editor.activate(previousId);
    } on StorageUnavailableException catch (e) {
      debugPrint('[playlists] desfazer ativação sem storage: $e');
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.offlineStorageUnavailable)),
        );
      }
    }
  }

  Future<void> openPdfInReader(String pdfId) async {
    if (loading) return;

    playlistOpenDebugClearLastFailure();
    playlistOpenDebugLog(
      '_openPdfInReader: início playlistId=${playlist.playlistId} '
      'salva=${playlist.salva} pdfId=$pdfId '
      'pdfIds (${playlist.pdfIds.length}): ${playlist.pdfIds.join(', ')}',
    );

    onLoadingChanged(true);
    try {
      final loaded = await _loadPlaylist();
      if (!loaded || !context.mounted) return;

      // Cifra, áudio e PDF dividem o mesmo espaço de ids, então a entrada da
      // lista só se revela ao ser decodificada. O que não é PDF vai pelo ponto
      // único de abertura; sem este desvio a cifra cairia no findLouvorByPdfId
      // (que só conhece PDFs) e viraria erro genérico. O caminho de PDF fica
      // abaixo porque ele tem pré-fetch e skeleton próprios.
      if (materialIdKindOf(pdfId) != MaterialKind.pdf) {
        final material = await resolveCatalogMaterialFromWidget(ref, pdfId);
        if (!context.mounted) return;
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
        if (context.mounted) showPlaylistOpenErrorSnackbar(context, l10n);
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
      if (!context.mounted) return;

      final location = ref
          .read(openPdfInReaderProvider)
          .call(
            pdfPath: source.absolutePath,
            pdfId: louvor.pdfId,
            titulo: louvor.nome,
          );
      playlistOpenDebugLog('_openPdfInReader: navegando → $location');
      if (!context.mounted) return;
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
      } else if (context.mounted) {
        showPlaylistOpenErrorSnackbar(context, l10n);
      }
    } finally {
      onLoadingChanged(false);
    }
  }

  /// Torna a lista ativa antes de abrir uma entrada dela no leitor (D6).
  ///
  /// Sem confirmação: a lista anterior continua salva. `false` só quando a
  /// lista não tem face de partituras para abrir.
  Future<bool> _loadPlaylist() async {
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
    if (!context.mounted) return false;

    playlistOpenDebugLog('_loadPlaylist: ok');
    return true;
  }

  /// «Apagar» (C11): sem diálogo — o desfazer substitui a confirmação. O
  /// item some do estado na hora ([PlaylistsNotifier.deleteWithUndo]); o
  /// snackbar oferece «Desfazer» por 5 s, mesmo padrão de [_activate]/
  /// [_undoActivate] (captura o `container`, não `ref`/`context`, porque o
  /// `PendingDelete.undo` pode disparar depois que o tile saiu da árvore).
  void _delete() {
    if (loading) return;
    final container = ProviderScope.containerOf(context, listen: false);
    final pending = container
        .read(playlistsProvider.notifier)
        .deleteWithUndo(playlist.playlistId);
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.playlistDeletedUndo),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () => unawaited(pending.undo()),
        ),
      ),
    );
  }

  /// «Duplicar» (C11): cria cópia salva com as mesmas entradas — o nome
  /// («Nome (cópia)», ARB `playlistCopyName`) é decidido aqui porque o
  /// notifier não conhece l10n.
  Future<void> _duplicate() async {
    if (loading) return;
    final copyName = l10n.playlistCopyName(playlist.nome);
    onLoadingChanged(true);
    try {
      await ref
          .read(playlistsProvider.notifier)
          .duplicate(playlist.playlistId, copyName: copyName);
    } finally {
      onLoadingChanged(false);
    }
  }

  /// «Gerar folheto» (C16, revisão de review): mesmo caminho de
  /// «Compartilhar» ([PlaylistShareActionsNotifier.share]), só que fixado em
  /// [PlaylistShareOption.leaflet] e sem passar pelo sheet de opções — a
  /// entrada é direto o menu do tile. **Nunca troca a lista ativa**: a
  /// primeira versão ativava a lista antes de gerar (para o
  /// `LeafletActionsNotifier.generateAndShare` legado, que só lê a seleção
  /// ativa); o controlador reverteu essa decisão (spec B.3) porque abrir o
  /// menu de uma lista salva não pode mudar qual lista está em uso alhures
  /// no app. `share` já aceita `PlaylistShareContext.entries` de qualquer
  /// playlist, então nada precisa ser ativado.
  Future<void> _generateLeaflet() async {
    if (loading) return;
    final shareOrigin = sharePositionOriginFromContextOrFallback(context);
    onLoadingChanged(true);
    try {
      final shared = await ref
          .read(playlistShareActionsProvider.notifier)
          .share(
            context,
            PlaylistShareContext(
              playlistId: playlist.playlistId,
              nome: playlist.nome,
              entries: playlist.entries,
            ),
            PlaylistShareOption.leaflet,
            sharePositionOrigin: shareOrigin,
          );
      if (!shared && context.mounted) {
        showPlaylistShareErrorSnackbar(context, l10n);
      }
    } finally {
      onLoadingChanged(false);
    }
  }

  Future<void> run(String action) async {
    switch (action) {
      case 'activate':
        await _activate();
      case 'openReader':
        // Ativa e abre a **primeira entrada da face de partituras** — que é
        // o que `pdfIds` projeta (tudo que não é áudio, na ordem).
        if (playlist.pdfIds.isEmpty) {
          _showError(l10n.playlistEmptyPdfList);
          return;
        }
        await openPdfInReader(playlist.pdfIds.first);
      case 'openAudio':
        if (playlist.audioIds.isEmpty) {
          _showError(l10n.playlistAudioEmpty);
          return;
        }
        onExpandedChanged(true);
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
        if (loading) return;
        final shareOrigin = sharePositionOriginFromContextOrFallback(context);
        final option = await showPlaylistShareSheet(context);
        if (option == null || !context.mounted) return;

        onLoadingChanged(true);
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
                  entries: playlist.entries,
                ),
                option,
                sharePositionOrigin: shareOrigin,
              );
          if (!shared && context.mounted) {
            showPlaylistShareErrorSnackbar(context, l10n);
          }
        } finally {
          onLoadingChanged(false);
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
      case 'duplicate':
        await _duplicate();
      case 'generateLeaflet':
        await _generateLeaflet();
      case 'delete':
        _delete();
    }
  }

  static String _displayName(String nome) {
    if (nome.isEmpty) return nome;
    return nome[0].toUpperCase() + nome.substring(1);
  }
}

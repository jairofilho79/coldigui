import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/database/isar_provider.dart';
import '../../../../core/utils/playlist_share_url_builder.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../audio_player/presentation/providers/audio_player_session_provider.dart';
import '../../../carousel/presentation/providers/carousel_focused_index_provider.dart';
import '../../../catalog/domain/entities/louvor.dart';
import '../../../catalog/presentation/providers/catalog_material_lookup_provider.dart';
import '../../../catalog/presentation/providers/louvores_manifest_provider.dart';
import '../../data/providers/playlist_providers.dart';
import '../../domain/entities/playlist_tab.dart';
import '../../domain/entities/saved_playlist.dart';
import '../../domain/exceptions/empty_playlist_share_exception.dart';
import '../../domain/exceptions/invalid_share_playlist_exception.dart';
import '../../domain/exceptions/playlist_not_found_exception.dart';
import '../utils/playlist_open_debug_log.dart';
import '../utils/playlist_share_debug_log.dart';
import 'active_playlist_editor.dart';
import 'active_playlist_provider.dart';
import 'pending_delete.dart';
import 'playlist_session_hydrate.dart';
import 'playlist_sync_provider.dart';
import 'playlists_ui_provider.dart';

/// Playlist enriquecida com labels do manifest para exibição na UI.
class PlaylistViewItem {
  const PlaylistViewItem({required this.playlist, required this.pdfLabels});

  final SavedPlaylist playlist;
  final List<String> pdfLabels;
}

/// Estado reativo das playlists — UC-06 (CRUD, load, abas) e UC-07 (share/import).
///
/// Toda mutação da **seleção** passa pelo [ActivePlaylistEditor] (D3);
/// [addLouvorToActivePlaylist]/[addAudioToActivePlaylist] são a porta de quem
/// abre um material e quer garanti-lo na lista ativa.
class PlaylistsNotifier extends Notifier<List<PlaylistViewItem>> {
  var _sessionHydrated = false;

  /// Exclusão adiada em curso (C11) — só uma por vez, ver [deleteWithUndo].
  PendingDelete? _pendingDelete;

  /// `playlistId` de [_pendingDelete] — usado por [_reload] para não
  /// ressuscitar a lista enquanto a exclusão ainda não comitou (fix round 1,
  /// Important 1).
  String? _pendingDeleteId;

  @override
  List<PlaylistViewItem> build() {
    ref.listen(louvoresManifestProvider, (_, _) {
      unawaited(_reload());
    });
    // O app monta durante a abertura do Isar (A8), então o primeiro `_reload`
    // roda contra o datasource degradado e não lista nada. Quando o banco abre,
    // recarrega — é também o gatilho que finalmente hidrata a sessão.
    ref.listen(isarStatusProvider, (_, next) {
      if (next == IsarStatus.available) unawaited(_reload());
    });
    ref.onDispose(() {
      final pending = _pendingDelete;
      if (pending != null && !pending.isSettled) unawaited(pending.commit());
    });
    Future.microtask(_reload);
    return const [];
  }

  List<String> _labelsForPdfIds(
    List<String> pdfIds,
    CatalogMaterialLookup lookup,
  ) {
    return pdfIds
        .map((id) {
          final louvor = lookup.louvor(id);
          if (louvor == null) return _fallbackLabel(id);
          return '${louvor.numero} — ${louvor.nome}';
        })
        .toList(growable: false);
  }

  static String _fallbackLabel(String pdfId) {
    if (pdfId.length <= 12) return pdfId;
    return '${pdfId.substring(0, 12)}…';
  }

  Future<void> _reload() async {
    final repository = ref.read(playlistRepositoryProvider);
    final lookup = ref.read(catalogMaterialLookupProvider);

    // Fix round 1 — Important 1 / fix round 2 — Minor: o repositório ainda
    // tem a linha enquanto a exclusão está na graça (o commit real só roda
    // depois); um reload disparado nesse meio-tempo (`playlist_sync_provider
    // .dart` chama `reload()` após todo sync com `movedRows`, e qualquer
    // mutação autenticada pode disparar isso dentro dos 5 s) não pode
    // ressuscitar a lista que o usuário acabou de apagar. Resolvido **antes**
    // do `await` abaixo — não depois: um `commit()` concorrente assenta
    // `_pendingDelete!.isSettled` de forma síncrona (antes do próprio
    // `_onCommit` terminar), então checar depois do `await getAll()` corre o
    // risco de ver `isSettled == true` mesmo quando a leitura em voo capturou
    // um snapshot de antes da exclusão de verdade.
    final pendingDelete = _pendingDelete;
    final hiddenId = (pendingDelete != null && !pendingDelete.isSettled)
        ? _pendingDeleteId
        : null;

    final playlists = await repository.getAll();

    state = playlists
        .where((playlist) => playlist.playlistId != hiddenId)
        .map(
          (playlist) => PlaylistViewItem(
            playlist: playlist,
            pdfLabels: _labelsForPdfIds(playlist.pdfIds, lookup),
          ),
        )
        .toList(growable: false);

    if (!_sessionHydrated) {
      // Trava antes de esperar para não disparar duas hidratações concorrentes
      // (`_reload` roda de novo quando o manifest chega e quando o Isar abre).
      _sessionHydrated = true;
      unawaited(_hydrateSession());
    }
  }

  /// Hidrata a sessão e **destrava** se não havia storage.
  ///
  /// Sem Isar a hidratação não aconteceu de fato — deixar travado faria o boot
  /// frio (app montado durante `opening`, A8) perder a restauração para sempre.
  Future<void> _hydrateSession() async {
    if (!await hydratePlaylistSession(ref)) _sessionHydrated = false;
  }

  /// Recarrega listas do Isar (ex.: após sync cloud).
  Future<void> reload() => _reload();

  /// Playlists filtradas e ordenadas para a aba (pilha — mais recente no topo).
  List<PlaylistViewItem> itemsForTab(PlaylistTab tab) {
    return state
        .where((item) {
          final p = item.playlist;
          return switch (tab) {
            PlaylistTab.unsaved => !p.salva,
            PlaylistTab.saved => p.salva && !p.favorita,
            PlaylistTab.favorites => p.favorita,
          };
        })
        .toList(growable: false)
      ..sort(
        (a, b) =>
            _sortKey(b.playlist, tab).compareTo(_sortKey(a.playlist, tab)),
      );
  }

  DateTime _sortKey(SavedPlaylist playlist, PlaylistTab tab) {
    return switch (tab) {
      PlaylistTab.unsaved => playlist.createdAt,
      PlaylistTab.saved => playlist.savedAt ?? playlist.createdAt,
      PlaylistTab.favorites => playlist.favoritedAt ?? playlist.createdAt,
    };
  }

  /// Sync na nuvem se autenticado. A tela recarrega dentro do próprio
  /// [PlaylistSyncNotifier] quando a rodada mexe em alguma linha.
  void _syncCloudIfAuthed() {
    unawaited(ref.read(playlistSyncProvider.notifier).sync());
  }

  /// Adiciona louvor à lista ativa; cria lista não salva se necessário.
  ///
  /// Sem storage (Isar não abriu / degradado) devolve `false` em vez de
  /// propagar: os chamadores disparam isto de futuros não aguardados
  /// (`playAudioInSession`, `openLouvorInReader`), onde a exceção viraria erro
  /// assíncrono não tratado sem nenhum retorno visível ao usuário.
  Future<bool> addLouvorToActivePlaylist(String pdfId) async {
    final outcome = await ref
        .read(activePlaylistEditorProvider.notifier)
        .addToActive(pdfId);
    return outcome == AddToActiveOutcome.added;
  }

  /// Salva a playlist ativa (ou renomeia se já salva).
  Future<bool> saveActivePlaylist({required String nome}) async {
    final activeId = ref.read(activePlaylistIdProvider);
    if (activeId == null) return false;

    final active = await ref.read(playlistRepositoryProvider).getById(activeId);
    if (active == null) return false;
    if (active.entries.isEmpty) return false;

    if (active.salva) {
      await ref.read(updatePlaylistProvider)(playlistId: activeId, nome: nome);
    } else {
      await ref.read(savePlaylistProvider)(playlistId: activeId, nome: nome);
    }
    await _reload();
    ref.read(playlistsUiProvider.notifier).selectTab(PlaylistTab.saved);
    _syncCloudIfAuthed();
    return true;
  }

  Future<void> savePlaylist(String playlistId) async {
    await ref.read(savePlaylistProvider)(playlistId: playlistId);
    await _reload();
    ref
        .read(playlistsUiProvider.notifier)
        .selectTab(PlaylistTab.saved, scrollToPlaylistId: playlistId);
    _syncCloudIfAuthed();
  }

  Future<void> favoritePlaylist(String playlistId) async {
    await ref.read(favoritePlaylistProvider)(playlistId: playlistId);
    await _reload();
    ref
        .read(playlistsUiProvider.notifier)
        .selectTab(PlaylistTab.favorites, scrollToPlaylistId: playlistId);
    _syncCloudIfAuthed();
  }

  Future<void> unfavoritePlaylist(String playlistId) async {
    await ref.read(unfavoritePlaylistProvider)(playlistId: playlistId);
    await _reload();
    ref
        .read(playlistsUiProvider.notifier)
        .selectTab(PlaylistTab.saved, scrollToPlaylistId: playlistId);
    _syncCloudIfAuthed();
  }

  Future<void> publishPlaylist({
    required String playlistId,
    required PlaylistCategory category,
    PlaylistReach reach = PlaylistReach.usual,
  }) async {
    await ref.read(publishPlaylistProvider)(
      playlistId: playlistId,
      category: category,
      reach: reach,
    );
    await _reload();
    _syncCloudIfAuthed();
  }

  Future<void> rename({
    required String playlistId,
    required String nome,
  }) async {
    await ref.read(updatePlaylistProvider)(playlistId: playlistId, nome: nome);
    await _reload();
    _syncCloudIfAuthed();
  }

  /// Remove a entrada na posição [index] de `entries` (ordem única) — **uma**
  /// ocorrência, nunca todas as do mesmo id (B.1).
  ///
  /// A lista ativa passa pelo [ActivePlaylistEditor] (`removeByKey`), que
  /// assenta a reordenação em voo antes de gravar e mantém o override até o
  /// reload; qualquer outra vai direto a [UpdatePlaylist] com `entries:` — um
  /// rascunho que fica vazio é apagado por ele. Posição fora da lista: no-op.
  Future<void> removeEntryAt({
    required String playlistId,
    required int index,
  }) async {
    final current = state
        .where((item) => item.playlist.playlistId == playlistId)
        .map((item) => item.playlist)
        .firstOrNull;
    if (current == null) return;
    if (index < 0 || index >= current.entries.length) return;

    if (ref.read(activePlaylistIdProvider) == playlistId) {
      final key = activeEntriesOf(current.entries)[index].key;
      await ref.read(activePlaylistEditorProvider.notifier).removeByKey(key);
      return;
    }

    final next = [...current.entries]..removeAt(index);
    await ref.read(updatePlaylistProvider)(
      playlistId: playlistId,
      entries: next,
    );
    await _reload();
    if (current.salva) _syncCloudIfAuthed();
  }

  Future<bool> toggleFavorite(String playlistId) async {
    final next = await ref.read(togglePlaylistFavoriteProvider)(
      playlistId: playlistId,
    );
    await _reload();
    _syncCloudIfAuthed();
    return next;
  }

  /// Apaga imediatamente (sem desfazer) — atalho para [deleteWithUndo] com
  /// `grace: Duration.zero` seguido de `commit`.
  Future<void> delete(String playlistId) =>
      deleteWithUndo(playlistId, grace: Duration.zero).commit();

  /// C11 — exclusão adiada: some do estado agora, mas o repositório só é
  /// tocado depois de [grace] (5 s por padrão) — ou antes, se [PendingDelete]
  /// é comitado explicitamente (outro `deleteWithUndo`, o `dispose` do
  /// notifier ou o chamador). [PendingDelete.undo] recoloca o item sem nunca
  /// ter chegado ao repositório.
  ///
  /// Qualquer `deleteWithUndo` anterior ainda pendente é comitado antes
  /// deste começar: o item dele já sumiu do estado, não faz sentido guardar
  /// duas exclusões "em voo" ao mesmo tempo.
  ///
  /// Repositório e "autenticado" são resolvidos **agora** (não dentro do
  /// `commit`): a exclusão de verdade pode rodar depois que o notifier já
  /// foi descartado (`ref.onDispose`), quando `ref.read` não é mais seguro
  /// (mesmo padrão de [ActivePlaylistEditor]).
  PendingDelete deleteWithUndo(
    String playlistId, {
    Duration grace = const Duration(seconds: 5),
  }) {
    final previousPending = _pendingDelete;
    if (previousPending != null && !previousPending.isSettled) {
      unawaited(previousPending.commit());
    }

    final index = state.indexWhere(
      (item) => item.playlist.playlistId == playlistId,
    );
    final removed = index == -1 ? null : state[index];
    if (removed != null) {
      state = [...state]..removeAt(index);
    }

    // Fix round 2 (Minor): a seleção ativa não pode continuar apontando pra
    // uma lista que já sumiu do estado — limpa já aqui (não só no `commit`,
    // que só roda depois da graça ou nem roda se o usuário desfizer); o
    // `undo` restaura.
    final wasActive =
        removed != null && ref.read(activePlaylistIdProvider) == playlistId;
    if (wasActive) {
      ref.read(activePlaylistIdProvider.notifier).clear();
    }

    final repository = ref.read(playlistRepositoryProvider);
    final deletePlaylist = ref.read(deletePlaylistProvider);
    final authed = ref.read(authStateProvider).asData?.value != null;
    // Sem conta: hard delete (sem tombstone órfão) — mesma regra de antes.
    final hardDelete = removed?.playlist.salva == true && !authed;

    final pending = PendingDelete(
      grace: grace,
      onUndo: () async {
        if (removed == null || !ref.mounted) return;
        if (state.any((item) => item.playlist.playlistId == playlistId)) {
          return;
        }
        final next = [...state];
        next.insert(index.clamp(0, next.length), removed);
        state = next;
        if (wasActive) {
          ref.read(activePlaylistIdProvider.notifier).set(playlistId);
        }
      },
      onCommit: () async {
        if (hardDelete) {
          await repository.hardDelete(playlistId);
        } else {
          await deletePlaylist(playlistId: playlistId);
        }
        if (!ref.mounted) return;
        if (ref.read(activePlaylistIdProvider) == playlistId) {
          ref.read(activePlaylistIdProvider.notifier).clear();
        }
        await _reload();
        if (!ref.mounted) return;
        if (authed && (removed?.playlist.salva ?? true)) {
          _syncCloudIfAuthed();
        }
      },
    );
    _pendingDelete = pending;
    _pendingDeleteId = playlistId;
    return pending;
  }

  /// C11 — duplica playlist: cria cópia salva com as mesmas entradas e o
  /// nome [copyName] (já formatado pelo chamador — ARB `playlistCopyName`).
  /// Devolve o `playlistId` da cópia.
  Future<String> duplicate(
    String playlistId, {
    required String copyName,
  }) async {
    final copy = await ref.read(duplicatePlaylistProvider)(
      playlistId: playlistId,
      copyName: copyName,
    );
    await _reload();
    ref
        .read(playlistsUiProvider.notifier)
        .selectTab(PlaylistTab.saved, scrollToPlaylistId: copy.playlistId);
    _syncCloudIfAuthed();
    return copy.playlistId;
  }

  Future<void> deleteAllUnsaved() async {
    final activeId = ref.read(activePlaylistIdProvider);
    final active = activeId == null
        ? null
        : await ref.read(playlistRepositoryProvider).getById(activeId);

    await ref.read(deleteAllUnsavedPlaylistsProvider)();
    if (active != null && !active.salva) {
      ref.read(activePlaylistIdProvider.notifier).clear();
    }
    await _reload();
  }

  /// Para o áudio e esquece o foco — a seleção some inteira.
  Future<void> _releaseMediaSelectionViews() async {
    await ref.read(audioPlayerSessionProvider.notifier).close();
    ref.read(carouselFocusedKeyProvider.notifier).clear();
  }

  /// Desanexa a lista ativa, sem apagar a playlist.
  Future<void> startNewEmptySelection() async {
    await _releaseMediaSelectionViews();
    await ref.read(activePlaylistEditorProvider.notifier).detachActive();
  }

  /// Apaga a lista ativa não salva; lista salva só é desanexada.
  Future<void> deleteActiveUnsavedPlaylist() async {
    await _releaseMediaSelectionViews();
    await ref.read(activePlaylistEditorProvider.notifier).deleteActiveDraft();
  }

  /// Busca louvor no manifest carregado — usado ao abrir PDF de playlist no leitor.
  ///
  /// Lookup O(1) pelo [catalogMaterialLookupProvider] (A4/C.3). Retorna `null`
  /// se o manifest ainda não carregou ou o [pdfId] for órfão. Em debug,
  /// registra estado do manifest e falhas via [playlistOpenDebugLog*].
  Louvor? findLouvorByPdfId(String pdfId) {
    final manifestAsync = ref.read(louvoresManifestProvider);
    final lookup = ref.read(catalogMaterialLookupProvider);
    playlistOpenDebugLog(
      'findLouvorByPdfId: pdfId=$pdfId '
      'manifest=${manifestAsync.isLoading
          ? 'loading'
          : manifestAsync.hasError
          ? 'error'
          : '${lookup.plpcgLouvoresByPdfId.length} itens'} '
      'coldigomCache=${lookup.coldigomLouvoresByPdfId.length}',
    );
    final louvor = lookup.louvor(pdfId);
    if (louvor != null) {
      playlistOpenDebugLog(
        'findLouvorByPdfId: encontrado numero=${louvor.numero} '
        'nome="${louvor.nome}" source=${louvor.source.name}',
      );
      return louvor;
    }
    playlistOpenDebugLogFailure(
      'findLouvorByPdfId',
      'pdfId=$pdfId ausente no manifest e cache coldigom',
    );
    return null;
  }

  /// Compartilha playlist via URL PWA (`/?sharepdfs=…&sharename=…`).
  ///
  /// [sharePositionOrigin] é obrigatório no iOS — capturar do contexto antes
  /// de `await` ([sharePositionOriginFromContextOrFallback]).
  /// Retorna `false` em playlist ausente/vazia ou falha do share sheet.
  Future<bool> sharePlaylist({
    required String playlistId,
    required String subject,
    Rect? sharePositionOrigin,
    ShareFn? share,
  }) async {
    playlistShareDebugClearLastFailure();
    playlistShareDebugLog(
      'sharePlaylist: início playlistId=$playlistId subject="$subject"',
    );
    try {
      final generateUrl = ref.read(generatePlaylistShareUrlProvider);
      playlistShareDebugLog('sharePlaylist: gerando URL…');
      final url = await generateUrl(playlistId: playlistId);
      playlistShareDebugLog('sharePlaylist: URL gerada ($url)');
      final shareFn = share ?? _defaultSharePlaylistUrl;
      playlistShareDebugLog(
        'sharePlaylist: abrindo share sheet nativo '
        '(origin=$sharePositionOrigin)…',
      );
      await shareFn(
        url,
        subject: subject,
        sharePositionOrigin: sharePositionOrigin,
      );
      playlistShareDebugLog('sharePlaylist: concluído com sucesso');
      return true;
    } on PlaylistNotFoundException catch (error, stackTrace) {
      playlistShareDebugLogError('playlist não encontrada', error, stackTrace);
      return false;
    } on EmptyPlaylistShareException catch (error, stackTrace) {
      playlistShareDebugLogError('playlist sem pdfIds', error, stackTrace);
      return false;
    } on Object catch (error, stackTrace) {
      playlistShareDebugLogError('share sheet nativo', error, stackTrace);
      return false;
    }
  }

  Future<void> refreshAfterImport() async {
    await _reload();
  }

  /// Adiciona áudio à lista ativa (cria rascunho se necessário).
  ///
  /// Mesmo contrato de [addLouvorToActivePlaylist]: sem storage devolve
  /// `false` em vez de propagar. O `kind` é **declarado** (A8) — a extensão do
  /// id não decide.
  Future<bool> addAudioToActivePlaylist(String audioId) async {
    final outcome = await ref
        .read(activePlaylistEditorProvider.notifier)
        .addToActive(audioId, kind: MaterialKind.audio);
    return outcome == AddToActiveOutcome.added;
  }

  Future<String?> importSharedFromUrl({
    required String shareName,
    String sharePdfs = '',
    String shareAudios = '',
    String shareItems = '',
  }) async {
    try {
      // Fix round 2 (Minor): a lista pendente de exclusão adiada (C11, ainda
      // sem `deletedAt` no repositório) não pode ser reaproveitada pela
      // dedupe por conteúdo (spec C.2).
      final pendingDelete = _pendingDelete;
      final excludePlaylistId =
          (pendingDelete != null && !pendingDelete.isSettled)
          ? _pendingDeleteId
          : null;
      final result = await ref.read(importSharedPlaylistFromUrlProvider)(
        sharePdfs: sharePdfs,
        shareAudios: shareAudios,
        shareItems: shareItems,
        shareName: shareName,
        excludePlaylistId: excludePlaylistId,
      );
      final playlistId = result.playlist.playlistId;
      // D6: a importada vira a ativa pelo mesmo caminho do «Tornar lista
      // ativa» — a lista que era ativa continua salva, com a ordem pendente
      // dela levada a disco antes da troca. Vale também quando a importada é
      // a existente reaproveitada pela dedupe (spec C.2): ela também vira a
      // ativa.
      await ref
          .read(activePlaylistEditorProvider.notifier)
          .activate(playlistId);
      return playlistId;
    } on InvalidSharePlaylistException {
      return null;
    }
  }

  PlaylistShareParams? parseShareInput(String raw) =>
      extractShareParamsFromUserInput(raw);
}

Future<void> _defaultSharePlaylistUrl(
  String text, {
  String? subject,
  Rect? sharePositionOrigin,
}) {
  return SharePlus.instance.share(
    ShareParams(
      text: text,
      subject: subject,
      sharePositionOrigin: sharePositionOrigin,
    ),
  );
}

/// Callback injetável para testes — espelha [SharePlus.instance.share] do [share_plus].
typedef ShareFn =
    Future<void> Function(
      String text, {
      String? subject,
      Rect? sharePositionOrigin,
    });

final playlistsProvider =
    NotifierProvider<PlaylistsNotifier, List<PlaylistViewItem>>(
      PlaylistsNotifier.new,
    );

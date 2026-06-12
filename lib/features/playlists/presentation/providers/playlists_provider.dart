import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/utils/playlist_share_url_builder.dart';
import '../../../carousel/data/providers/carousel_providers.dart';
import '../../../carousel/presentation/providers/carousel_focused_index_provider.dart';
import '../../../carousel/presentation/providers/carousel_louvores_provider.dart';
import '../../../catalog/domain/entities/louvor.dart';
import '../../../catalog/presentation/providers/louvores_manifest_provider.dart';
import '../../data/providers/playlist_providers.dart';
import '../../domain/entities/playlist_tab.dart';
import '../../domain/entities/saved_playlist.dart';
import '../../domain/exceptions/empty_carousel_exception.dart';
import '../../domain/exceptions/empty_playlist_share_exception.dart';
import '../../domain/exceptions/invalid_share_playlist_exception.dart';
import '../../domain/exceptions/playlist_not_found_exception.dart';
import '../../domain/utils/playlist_defaults.dart';
import '../utils/playlist_open_debug_log.dart';
import '../utils/playlist_share_debug_log.dart';
import 'active_playlist_provider.dart';
import 'active_playlist_sync.dart' as active_sync;
import 'playlists_ui_provider.dart';

/// Playlist ativa alinhada ao carousel — retorno de
/// [PlaylistsNotifier.resolveActivePlaylistFromCarousel].
///
/// Usado por [CarouselBarTrailingActions._sharePlaylist] e
/// [PlaylistsNotifier.sharePlaylist] antes de gerar URL PWA.
class ResolvedActivePlaylist {
  const ResolvedActivePlaylist({
    required this.playlistId,
    required this.nome,
  });

  /// ID estável da playlist ([SavedPlaylist.playlistId]).
  final String playlistId;

  /// Nome exibido no share sheet (`subject` do [Share.share]).
  final String nome;
}

/// Playlist enriquecida com labels do manifest para exibição na UI.
class PlaylistViewItem {
  const PlaylistViewItem({
    required this.playlist,
    required this.pdfLabels,
  });

  final SavedPlaylist playlist;
  final List<String> pdfLabels;
}

/// Estado reativo das playlists — UC-06 (CRUD, load, abas) e UC-07 (share/import).
///
/// Expõe [resolveActivePlaylistFromCarousel] para alinhar carousel Isar com
/// playlist ativa antes de compartilhar; [findLouvorByPdfId] e
/// [loadIntoCarousel] com instrumentação [playlistOpenDebugLog*] em debug.
class PlaylistsNotifier extends Notifier<List<PlaylistViewItem>> {
  @override
  List<PlaylistViewItem> build() {
    ref.listen(louvoresManifestProvider, (_, __) {
      unawaited(_reload());
    });
    Future.microtask(_reload);
    return const [];
  }

  Map<String, String> _buildLabelMap(List<Louvor>? catalog) {
    if (catalog == null) return const {};
    return {
      for (final louvor in catalog)
        louvor.pdfId: '${louvor.numero} — ${louvor.nome}',
    };
  }

  List<String> _labelsForPdfIds(
    List<String> pdfIds,
    Map<String, String> labelMap,
  ) {
    return pdfIds
        .map((id) => labelMap[id] ?? _fallbackLabel(id))
        .toList(growable: false);
  }

  static String _fallbackLabel(String pdfId) {
    if (pdfId.length <= 12) return pdfId;
    return '${pdfId.substring(0, 12)}…';
  }

  Future<void> _reload() async {
    final repository = ref.read(playlistRepositoryProvider);
    final labelMap = _buildLabelMap(ref.read(louvoresManifestProvider).value);
    final playlists = await repository.getAll();

    state = playlists
        .map(
          (playlist) => PlaylistViewItem(
            playlist: playlist,
            pdfLabels: _labelsForPdfIds(playlist.pdfIds, labelMap),
          ),
        )
        .toList(growable: false);
  }

  /// Playlists filtradas e ordenadas para a aba (pilha — mais recente no topo).
  List<PlaylistViewItem> itemsForTab(PlaylistTab tab) {
    return state.where((item) {
      final p = item.playlist;
      return switch (tab) {
        PlaylistTab.unsaved => !p.salva,
        PlaylistTab.saved => p.salva && !p.favorita,
        PlaylistTab.favorites => p.favorita,
      };
    }).toList(growable: false)
      ..sort((a, b) =>
          _sortKey(b.playlist, tab).compareTo(_sortKey(a.playlist, tab)));
  }

  DateTime _sortKey(SavedPlaylist playlist, PlaylistTab tab) {
    return switch (tab) {
      PlaylistTab.unsaved => playlist.createdAt,
      PlaylistTab.saved => playlist.savedAt ?? playlist.createdAt,
      PlaylistTab.favorites => playlist.favoritedAt ?? playlist.createdAt,
    };
  }

  /// Sincroniza [pdfIds] da playlist ativa com o carousel atual.
  Future<void> syncActivePlaylistFromCarousel() async {
    await active_sync.syncActivePlaylistFromCarousel(ref);
    await _reload();
  }

  /// Garante playlist ativa com [pdfId] e retorna o ID.
  Future<String> ensurePlaylistForLouvor(String pdfId) async {
    final result = await ref.read(ensurePlaylistForLouvorProvider)(
      pdfId: pdfId,
      activePlaylistId: ref.read(activePlaylistIdProvider),
    );
    ref.read(activePlaylistIdProvider.notifier).set(result.playlistId);
    await ref.read(carouselLouvoresProvider.notifier).reload();
    ref.read(carouselFocusedIndexProvider.notifier).focusPdfId(pdfId);
    await _reload();
    return result.playlistId;
  }

  /// Adiciona louvor à lista ativa; cria lista não salva se necessário.
  Future<bool> addLouvorToActivePlaylist(String pdfId) async {
    var activeId = ref.read(activePlaylistIdProvider);
    if (activeId == null) {
      activeId = await ensurePlaylistForLouvor(pdfId);
      return true;
    }

    final active = await ref.read(playlistRepositoryProvider).getById(activeId);
    if (active == null) {
      activeId = await ensurePlaylistForLouvor(pdfId);
      return true;
    }

    if (active.pdfIds.contains(pdfId)) return false;

    final added = await ref.read(carouselLouvoresProvider.notifier).add(pdfId);
    if (added) {
      await syncActivePlaylistFromCarousel();
    }
    return added;
  }

  /// Cria playlist a partir do carousel. Retorna [playlistId] ou `null` se vazio.
  Future<String?> createFromCarousel({String? nome}) async {
    try {
      final id = await ref.read(createPlaylistFromCarouselProvider)(nome: nome);
      await _reload();
      return id;
    } on EmptyCarouselException {
      return null;
    }
  }

  /// Salva a playlist ativa (ou renomeia se já salva).
  Future<bool> saveActivePlaylist({required String nome}) async {
    final activeId = ref.read(activePlaylistIdProvider);
    if (activeId == null) return false;

    final active = await ref.read(playlistRepositoryProvider).getById(activeId);
    if (active == null || active.pdfIds.isEmpty) return false;

    await syncActivePlaylistFromCarousel();

    if (active.salva) {
      await ref.read(updatePlaylistProvider)(playlistId: activeId, nome: nome);
    } else {
      await ref.read(savePlaylistProvider)(
        playlistId: activeId,
        nome: nome,
      );
    }
    await _reload();
    ref.read(playlistsUiProvider.notifier).selectTab(PlaylistTab.saved);
    return true;
  }

  Future<void> savePlaylist(String playlistId) async {
    await ref.read(savePlaylistProvider)(playlistId: playlistId);
    await _reload();
    ref.read(playlistsUiProvider.notifier).selectTab(
          PlaylistTab.saved,
          scrollToPlaylistId: playlistId,
        );
  }

  Future<void> favoritePlaylist(String playlistId) async {
    await ref.read(favoritePlaylistProvider)(playlistId: playlistId);
    await _reload();
    ref.read(playlistsUiProvider.notifier).selectTab(
          PlaylistTab.favorites,
          scrollToPlaylistId: playlistId,
        );
  }

  Future<void> unfavoritePlaylist(String playlistId) async {
    await ref.read(unfavoritePlaylistProvider)(playlistId: playlistId);
    await _reload();
    ref.read(playlistsUiProvider.notifier).selectTab(
          PlaylistTab.saved,
          scrollToPlaylistId: playlistId,
        );
  }

  Future<void> rename({
    required String playlistId,
    required String nome,
  }) async {
    await ref.read(updatePlaylistProvider)(
      playlistId: playlistId,
      nome: nome,
    );
    await _reload();
  }

  Future<void> removePdf({
    required String playlistId,
    required String pdfId,
  }) async {
    final current = state
        .firstWhere((item) => item.playlist.playlistId == playlistId)
        .playlist;
    final nextIds =
        current.pdfIds.where((id) => id != pdfId).toList(growable: false);

    await ref.read(updatePlaylistProvider)(
      playlistId: playlistId,
      pdfIds: nextIds,
    );
    if (nextIds.isEmpty && ref.read(activePlaylistIdProvider) == playlistId) {
      ref.read(activePlaylistIdProvider.notifier).clear();
    }
    await _reload();
  }

  Future<bool> toggleFavorite(String playlistId) async {
    final next =
        await ref.read(togglePlaylistFavoriteProvider)(playlistId: playlistId);
    await _reload();
    return next;
  }

  Future<void> delete(String playlistId) async {
    await ref.read(deletePlaylistProvider)(playlistId: playlistId);
    if (ref.read(activePlaylistIdProvider) == playlistId) {
      ref.read(activePlaylistIdProvider.notifier).clear();
    }
    await _reload();
  }

  Future<void> deleteAllUnsaved() async {
    final activeId = ref.read(activePlaylistIdProvider);
    final active = activeId == null
        ? null
        : await ref.read(playlistRepositoryProvider).getById(activeId);

    await ref.read(deleteAllUnsavedPlaylistsProvider)();
    if (active != null && !active.salva) {
      ref.read(activePlaylistIdProvider.notifier).clear();
      await ref.read(carouselLouvoresProvider.notifier).clear();
    }
    await _reload();
  }

  /// Apaga lista ativa não salva e limpa carousel.
  Future<void> clearActiveUnsavedPlaylist() async {
    final activeId = ref.read(activePlaylistIdProvider);
    if (activeId == null) {
      await ref.read(carouselLouvoresProvider.notifier).clear();
      return;
    }

    final active = await ref.read(playlistRepositoryProvider).getById(activeId);
    if (active != null && !active.salva) {
      await ref.read(deletePlaylistProvider)(playlistId: activeId);
      ref.read(activePlaylistIdProvider.notifier).clear();
    }
    await ref.read(carouselLouvoresProvider.notifier).clear();
    await _reload();
  }

  /// Carrega playlist no carousel e define como ativa.
  ///
  /// Delega [LoadPlaylistIntoCarousel], atualiza [activePlaylistIdProvider],
  /// recarrega [carouselLouvoresProvider] e reseta [carouselFocusedIndexProvider].
  /// Retorna `false` se a playlist não existir ou ocorrer erro — instrumentação
  /// via [playlistOpenDebugLog*] em [kDebugMode].
  Future<bool> loadIntoCarousel(String playlistId) async {
    playlistOpenDebugLog('loadIntoCarousel: início playlistId=$playlistId');
    try {
      await ref.read(loadPlaylistIntoCarouselProvider)(
        playlistId: playlistId,
      );
      ref.read(activePlaylistIdProvider.notifier).set(playlistId);
      await ref.read(carouselLouvoresProvider.notifier).reload();
      ref.read(carouselFocusedIndexProvider.notifier).reset();
      final carouselIds =
          await ref.read(carouselRepositoryProvider).getOrderedPdfIds();
      playlistOpenDebugLog(
        'loadIntoCarousel: ok — carousel pdfIds (${carouselIds.length}): '
        '${carouselIds.join(', ')}',
      );
      return true;
    } on PlaylistNotFoundException catch (error, stackTrace) {
      playlistOpenDebugLogError(
        'loadIntoCarousel playlist não encontrada',
        error,
        stackTrace,
      );
      return false;
    } on Object catch (error, stackTrace) {
      playlistOpenDebugLogError('loadIntoCarousel', error, stackTrace);
      return false;
    }
  }

  /// Busca louvor no manifest carregado — usado ao abrir PDF de playlist no leitor.
  ///
  /// Lookup O(n) em [louvoresManifestProvider]. Retorna `null` se o manifest
  /// ainda não carregou ou o [pdfId] for órfão. Em debug, registra estado do
  /// manifest e falhas via [playlistOpenDebugLog*].
  Louvor? findLouvorByPdfId(String pdfId) {
    final manifestAsync = ref.read(louvoresManifestProvider);
    final catalog = manifestAsync.value;
    playlistOpenDebugLog(
      'findLouvorByPdfId: pdfId=$pdfId '
      'manifest=${manifestAsync.isLoading ? 'loading' : manifestAsync.hasError ? 'error' : catalog == null ? 'null' : '${catalog.length} itens'}',
    );
    if (catalog == null) return null;
    for (final louvor in catalog) {
      if (louvor.pdfId == pdfId) {
        playlistOpenDebugLog(
          'findLouvorByPdfId: encontrado numero=${louvor.numero} '
          'nome="${louvor.nome}"',
        );
        return louvor;
      }
    }
    playlistOpenDebugLogFailure(
      'findLouvorByPdfId',
      'pdfId=$pdfId ausente no manifest (${catalog.length} itens)',
    );
    return null;
  }

  /// Garante playlist com os [pdfIds] do carousel para ações como compartilhar.
  ///
  /// Recupera rascunho existente quando [activePlaylistIdProvider] foi perdido
  /// (ex.: restart do app) ou sincroniza a playlist ativa com o carousel Isar.
  /// Retorna `null` se a seleção estiver vazia.
  Future<ResolvedActivePlaylist?> resolveActivePlaylistFromCarousel() async {
    playlistShareDebugLog('resolveActivePlaylistFromCarousel: início');
    final carouselPdfIds =
        await ref.read(carouselRepositoryProvider).getOrderedPdfIds();
    playlistShareDebugLog(
      'resolve: carousel Isar pdfIds (${carouselPdfIds.length}): '
      '${carouselPdfIds.join(', ')}',
    );
    if (carouselPdfIds.isEmpty) {
      playlistShareDebugLog('resolve: carousel vazio — abortando');
      return null;
    }

    final repository = ref.read(playlistRepositoryProvider);
    final activeId = ref.read(activePlaylistIdProvider);
    playlistShareDebugLog('resolve: activePlaylistId em memória=$activeId');

    if (activeId != null) {
      final active = await repository.getById(activeId);
      if (active != null) {
        playlistShareDebugLog(
          'resolve: playlist ativa encontrada nome="${active.nome}" '
          'pdfIds (${active.pdfIds.length})',
        );
        if (!_pdfIdsMatch(active.pdfIds, carouselPdfIds)) {
          playlistShareDebugLog(
            'resolve: pdfIds divergentes — sincronizando carousel → playlist',
          );
          await syncActivePlaylistFromCarousel();
        }
        final updated = await repository.getById(activeId);
        if (updated != null && updated.pdfIds.isNotEmpty) {
          playlistShareDebugLog(
            'resolve: reutilizando playlist ativa id=$activeId',
          );
          return ResolvedActivePlaylist(
            playlistId: activeId,
            nome: updated.nome,
          );
        }
        playlistShareDebugLog(
          'resolve: playlist ativa id=$activeId sem pdfIds após sync',
        );
      } else {
        playlistShareDebugLog(
          'resolve: activePlaylistId=$activeId não existe no Isar',
        );
      }
    }

    final allPlaylists = await repository.getAll();
    playlistShareDebugLog(
      'resolve: buscando match entre ${allPlaylists.length} playlists',
    );
    final matching = _findPlaylistWithPdfIds(allPlaylists, carouselPdfIds);
    if (matching != null) {
      playlistShareDebugLog(
        'resolve: match encontrado id=${matching.playlistId} '
        'salva=${matching.salva}',
      );
      ref.read(activePlaylistIdProvider.notifier).set(matching.playlistId);
      return ResolvedActivePlaylist(
        playlistId: matching.playlistId,
        nome: matching.nome,
      );
    }

    playlistShareDebugLog('resolve: sem match — criando rascunho');
    final nome = defaultPlaylistName();
    final playlistId = await repository.create(
      nome: nome,
      pdfIds: carouselPdfIds,
      salva: false,
    );
    ref.read(activePlaylistIdProvider.notifier).set(playlistId);
    await _reload();
    playlistShareDebugLog(
        'resolve: rascunho criado id=$playlistId nome="$nome"');
    return ResolvedActivePlaylist(playlistId: playlistId, nome: nome);
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
      final shareFn = share ?? Share.share;
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
    await ref.read(carouselLouvoresProvider.notifier).reload();
  }

  Future<String?> importSharedFromUrl({
    required String sharePdfs,
    required String shareName,
  }) async {
    try {
      final playlistId = await ref.read(importSharedPlaylistFromUrlProvider)(
        sharePdfs: sharePdfs,
        shareName: shareName,
      );
      ref.read(activePlaylistIdProvider.notifier).set(playlistId);
      await _reload();
      await ref.read(carouselLouvoresProvider.notifier).reload();
      ref.read(carouselFocusedIndexProvider.notifier).reset();
      return playlistId;
    } on InvalidSharePlaylistException {
      return null;
    }
  }

  PlaylistShareParams? parseShareInput(String raw) =>
      extractShareParamsFromUserInput(raw);

  static SavedPlaylist? _findPlaylistWithPdfIds(
    List<SavedPlaylist> playlists,
    List<String> pdfIds,
  ) {
    SavedPlaylist? unsavedMatch;
    SavedPlaylist? anyMatch;
    for (final playlist in playlists) {
      if (!_pdfIdsMatch(playlist.pdfIds, pdfIds)) continue;
      if (!playlist.salva) {
        unsavedMatch = playlist;
        break;
      }
      anyMatch ??= playlist;
    }
    return unsavedMatch ?? anyMatch;
  }

  static bool _pdfIdsMatch(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Callback injetável para testes — espelha [Share.share] do [share_plus].
typedef ShareFn = Future<void> Function(
  String text, {
  String? subject,
  Rect? sharePositionOrigin,
});

final playlistsProvider =
    NotifierProvider<PlaylistsNotifier, List<PlaylistViewItem>>(
  PlaylistsNotifier.new,
);

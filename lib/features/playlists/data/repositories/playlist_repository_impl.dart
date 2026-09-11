import '../../../../core/database/collections/playlist.dart';
import '../../domain/entities/playlist_tab.dart';
import '../../domain/entities/saved_playlist.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../../domain/utils/playlist_defaults.dart';
import '../datasources/playlist_local_datasource.dart';

/// Orquestra [PlaylistLocalDatasource] (UC-06 + UC-15).
class PlaylistRepositoryImpl implements PlaylistRepository {
  const PlaylistRepositoryImpl(this._local);

  final PlaylistLocalDatasource _local;

  @override
  Future<List<SavedPlaylist>> getAll() async {
    final rows = await _local.findAll();
    return rows.map(_toEntity).toList(growable: false);
  }

  @override
  Future<List<SavedPlaylist>> getByTab(PlaylistTab tab) async {
    final rows = switch (tab) {
      PlaylistTab.unsaved => await _local.findUnsaved(),
      PlaylistTab.saved => await _local.findSaved(),
      PlaylistTab.favorites => await _local.findFavorites(),
    };
    return rows.map(_toEntity).toList(growable: false);
  }

  @override
  Future<SavedPlaylist?> getById(String playlistId) async {
    final row = await _local.findByPlaylistId(playlistId);
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<String> create({
    required String nome,
    List<PlaylistEntry>? entries,
    List<String> pdfIds = const [],
    List<String> audioIds = const [],
    String? playlistId,
    DateTime? createdAt,
    bool salva = true,
    DateTime? savedAt,
    DateTime? updatedAt,
    int version = 1,
    PlaylistSyncStatus syncStatus = PlaylistSyncStatus.synced,
    String? ownerSub,
  }) async {
    final id = playlistId ?? generatePlaylistId();
    final now = createdAt ?? DateTime.now();
    final effectiveUpdatedAt = updatedAt ?? now;
    final row = Playlist()
      ..playlistId = id
      ..nome = nome
      ..createdAt = now
      ..salva = salva
      ..savedAt = savedAt ?? (salva ? now : null)
      ..favorita = false
      ..updatedAt = effectiveUpdatedAt
      ..version = version
      ..syncStatus = salva && syncStatus == PlaylistSyncStatus.synced
          ? PlaylistSyncStatus.pendingPush
          : syncStatus
      ..ownerSub = ownerSub;
    // Também no `create`: as colunas de compat são projeção de `entries`,
    // nunca as listas cruas que o chamador passou.
    _writeEntries(
      row,
      entries ??
          SavedPlaylist.entriesFromLegacyLists(
            pdfIds: pdfIds,
            audioIds: audioIds,
          ),
    );

    await _local.insert(row);
    return id;
  }

  /// [entries] vence tudo: grava a ordem única literal (repetições inclusive).
  /// Sem ele, [pdfIds]/[audioIds] substituem apenas o seu subconjunto da ordem
  /// única — ver [SavedPlaylist.replaceSubset].
  @override
  Future<void> update(
    String playlistId, {
    String? nome,
    List<PlaylistEntry>? entries,
    List<String>? pdfIds,
    List<String>? audioIds,
    bool? salva,
    DateTime? savedAt,
    DateTime? favoritedAt,
    bool? favorita,
    bool clearFavoritedAt = false,
    DateTime? updatedAt,
    int? version,
    PlaylistSyncStatus? syncStatus,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) async {
    final existing = await getById(playlistId);
    final becomesSaved = salva == true || (existing?.salva ?? false);
    final touchSync =
        nome != null ||
        entries != null ||
        pdfIds != null ||
        audioIds != null ||
        salva != null ||
        savedAt != null ||
        favoritedAt != null ||
        favorita != null ||
        clearFavoritedAt ||
        deletedAt != null;

    // Reprojeta a ordem única antes de escrever: as duas listas gravadas em
    // disco continuam sendo projeções coerentes de `items`.
    List<PlaylistEntry>? next;
    if (entries != null) {
      next = List<PlaylistEntry>.unmodifiable(entries);
    } else if ((pdfIds != null || audioIds != null) && existing != null) {
      next = existing.nextEntriesWith(pdfIds: pdfIds, audioIds: audioIds);
    }

    await _local.updateFields(
      playlistId,
      nome: nome,
      items: next == null ? null : <String>[for (final e in next) e.id],
      itemKinds: next == null ? null : _kindsOf(next),
      pdfIds: next == null
          ? pdfIds
          : <String>[
              for (final e in next)
                if (!e.isAudio) e.id,
            ],
      audioIds: next == null
          ? audioIds
          : <String>[
              for (final e in next)
                if (e.isAudio) e.id,
            ],
      salva: salva,
      savedAt: savedAt,
      favoritedAt: favoritedAt,
      favorita: favorita,
      clearFavoritedAt: clearFavoritedAt,
      updatedAt: updatedAt ?? (touchSync ? DateTime.now().toUtc() : null),
      version: version,
      syncStatus:
          syncStatus ??
          (touchSync && becomesSaved ? PlaylistSyncStatus.pendingPush : null),
      deletedAt: deletedAt,
      clearDeletedAt: clearDeletedAt,
    );
  }

  @override
  Future<void> publish(
    String playlistId, {
    required PlaylistCategory category,
    PlaylistReach reach = PlaylistReach.usual,
  }) async {
    final existing = await getById(playlistId);
    if (existing == null) {
      throw StateError('Playlist not found: $playlistId');
    }
    if (!existing.salva) {
      throw StateError('Only saved playlists can be published');
    }
    if (existing.isPublished) {
      throw StateError('Playlist already published: $playlistId');
    }
    final now = DateTime.now().toUtc();
    await _local.updateFields(
      playlistId,
      isPublished: true,
      publicationReachIndex: reach.index,
      publicationCategoryIndex: category.index,
      publishedAt: now,
      updatedAt: now,
      syncStatus: PlaylistSyncStatus.pendingPush,
    );
  }

  @override
  Future<void> delete(String playlistId) async {
    final existing = await getById(playlistId);
    if (existing == null) return;
    if (existing.salva) {
      await _local.softDeleteByPlaylistId(playlistId);
    } else {
      await _local.deleteByPlaylistId(playlistId);
    }
  }

  @override
  Future<void> hardDelete(String playlistId) =>
      _local.deleteByPlaylistId(playlistId);

  @override
  Future<void> deleteAllUnsaved() => _local.deleteAllUnsaved();

  @override
  Future<List<SavedPlaylist>> getPendingPush({String? sub}) async {
    final rows = await _local.findPendingPush(sub: sub);
    return rows.map(_toEntity).toList(growable: false);
  }

  @override
  Future<List<SavedPlaylist>> getTombstones({String? sub}) async {
    final rows = await _local.findTombstones(sub: sub);
    return rows.map(_toEntity).toList(growable: false);
  }

  @override
  Future<void> upsert(SavedPlaylist playlist) async {
    final row = Playlist()
      ..playlistId = playlist.playlistId
      ..nome = playlist.nome
      ..createdAt = playlist.createdAt
      ..salva = playlist.salva
      ..savedAt = playlist.savedAt
      ..favoritedAt = playlist.favoritedAt
      ..favorita = playlist.favorita
      ..updatedAt = playlist.updatedAt
      ..version = playlist.version
      ..syncStatus = playlist.syncStatus
      ..deletedAt = playlist.deletedAt
      ..isPublished = playlist.isPublished
      ..publicationReach = playlist.publicationReach
      ..publicationCategory = playlist.publicationCategory
      ..publishedAt = playlist.publishedAt
      ..ownerSub = playlist.ownerSub;
    _writeEntries(row, playlist.entries);
    await _local.insert(row);
  }

  /// Grava a ordem única tipada e reprojeta as colunas de compatibilidade
  /// (`pdfIds`/`audioIds`, lidas por builds antigos do mesmo dispositivo e pelo
  /// Worker v1) — sempre a partir de [entries], nunca de listas soltas.
  static void _writeEntries(Playlist row, List<PlaylistEntry> entries) {
    row
      ..items = <String>[for (final e in entries) e.id]
      ..itemKinds = _kindsOf(entries)
      ..pdfIds = <String>[
        for (final e in entries)
          if (!e.isAudio) e.id,
      ]
      ..audioIds = <String>[
        for (final e in entries)
          if (e.isAudio) e.id,
      ];
  }

  static List<String> _kindsOf(List<PlaylistEntry> entries) => <String>[
    for (final e in entries) e.kind.name,
  ];

  @override
  Future<void> adoptForSub(String sub) => _local.adoptForSub(sub);

  @override
  Future<int> purgeSyncedOwnedBy(String previousSub) =>
      _local.purgeSyncedOwnedBy(previousSub);

  SavedPlaylist _toEntity(Playlist row) => SavedPlaylist(
    playlistId: row.playlistId,
    entries: _entriesOf(row),
    nome: row.nome,
    createdAt: row.createdAt,
    salva: row.salva,
    savedAt: row.savedAt,
    favoritedAt: row.favoritedAt,
    favorita: row.favorita,
    updatedAt: row.updatedAt.millisecondsSinceEpoch == 0
        ? row.createdAt
        : row.updatedAt,
    version: row.version,
    syncStatus: row.syncStatus,
    deletedAt: row.deletedAt,
    isPublished: row.isPublished,
    publicationReach: row.publicationReach,
    publicationCategory: row.publicationCategory,
    publishedAt: row.publishedAt,
    ownerSub: row.ownerSub,
  );

  /// Ordem única tipada da linha: `items` + `itemKinds`.
  ///
  /// As duas listas já vêm migradas e alinhadas do datasource; o fallback (uma
  /// linha lida fora dele, ou com a invariante quebrada) reclassifica pela
  /// extensão com `row.audioIds` como veredito — sem ele, um áudio com
  /// container fora de `kAudioMaterialExtensions` migraria para a face de
  /// partituras e o próximo sync do carousel o consumiria (A8).
  static List<PlaylistEntry> _entriesOf(Playlist row) {
    final items = row.items.isNotEmpty
        ? row.items
        : <String>[...row.pdfIds, ...row.audioIds];
    if (row.itemKinds.length != items.length) {
      return SavedPlaylist.entriesFromLegacyLists(
        items: items,
        audioIds: row.audioIds,
      );
    }
    return <PlaylistEntry>[
      for (var i = 0; i < items.length; i++)
        PlaylistEntry(
          id: items[i],
          kind: materialKindFromName(row.itemKinds[i]),
        ),
    ];
  }
}

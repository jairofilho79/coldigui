import '../entities/remote_playlist.dart';
import '../entities/saved_playlist.dart';
import '../repositories/playlist_repository.dart';

/// Resultado de [SyncPlaylists].
class PlaylistSyncResult {
  const PlaylistSyncResult({
    this.pulled = 0,
    this.pushed = 0,
    this.deleted = 0,
    this.skipped = false,
  });

  final int pulled;
  final int pushed;
  final int deleted;
  final bool skipped;

  static const skippedAuth = PlaylistSyncResult(skipped: true);
}

/// Sync offline-first: pull → push → tombstones (UC-15).
///
/// Pré-condição: [idToken] não-nulo. Sem token, retorna [PlaylistSyncResult.skippedAuth]
/// sem tocar a rede.
class SyncPlaylists {
  const SyncPlaylists(
    this._repository,
    this._fetch,
    this._upsert,
    this._delete,
  );

  final PlaylistRepository _repository;
  final Future<List<RemotePlaylist>> Function(String idToken) _fetch;
  final Future<RemotePlaylist> Function({
    required String idToken,
    required RemotePlaylist playlist,
  })
  _upsert;
  final Future<void> Function({
    required String idToken,
    required String playlistId,
  })
  _delete;

  Future<PlaylistSyncResult> call({required String? idToken}) async {
    if (idToken == null || idToken.isEmpty) {
      return PlaylistSyncResult.skippedAuth;
    }

    var pulled = 0;
    var pushed = 0;
    var deleted = 0;

    // Fase A — Pull
    final remote = await _fetch(idToken);

    for (final r in remote) {
      if (!r.salva) continue;
      final local = await _repository.getById(r.id);
      if (local == null) {
        await _repository.upsert(_fromRemote(r));
        pulled++;
        continue;
      }
      if (local.deletedAt != null) {
        // Tombstone local pendente — não sobrescrever com pull.
        continue;
      }
      final localPending = local.syncStatus == PlaylistSyncStatus.pendingPush;
      if (localPending && !local.updatedAt.isBefore(r.updatedAt)) {
        continue;
      }
      if (local.updatedAt.isBefore(r.updatedAt) ||
          (local.updatedAt.isAtSameMomentAs(r.updatedAt) &&
              local.version < r.version)) {
        await _repository.upsert(_fromRemote(r));
        pulled++;
      }
    }

    // Fase B — Push
    final pending = await _repository.getPendingPush();
    for (final local in pending) {
      if (!local.salva) continue;
      try {
        final saved = await _upsert(
          idToken: idToken,
          playlist: _toRemote(local),
        );
        await _repository.upsert(
          local.copyWith(
            version: saved.version,
            updatedAt: saved.updatedAt,
            syncStatus: PlaylistSyncStatus.synced,
            clearDeletedAt: true,
          ),
        );
        pushed++;
      } on Object {
        // Mantém pendingPush; próxima sync tenta de novo.
      }
    }

    // Fase C — Deletes
    final tombstones = await _repository.getTombstones();
    for (final tomb in tombstones) {
      try {
        await _delete(idToken: idToken, playlistId: tomb.playlistId);
        await _repository.hardDelete(tomb.playlistId);
        deleted++;
      } on Object {
        // Mantém tombstone.
      }
    }

    return PlaylistSyncResult(pulled: pulled, pushed: pushed, deleted: deleted);
  }

  static SavedPlaylist _fromRemote(RemotePlaylist r) => SavedPlaylist(
    playlistId: r.id,
    nome: r.nome,
    pdfIds: List<String>.from(r.pdfIds),
    createdAt: r.createdAt,
    salva: true,
    savedAt: r.savedAt,
    favoritedAt: r.favoritedAt,
    favorita: r.favorita,
    updatedAt: r.updatedAt,
    version: r.version,
    syncStatus: PlaylistSyncStatus.synced,
    isPublished: r.isPublished,
    publicationReach: r.publicationReach,
    publicationCategory: r.publicationCategory,
    publishedAt: r.publishedAt,
  );

  static RemotePlaylist _toRemote(SavedPlaylist p) => RemotePlaylist(
    id: p.playlistId,
    nome: p.nome,
    pdfIds: p.pdfIds,
    salva: true,
    favorita: p.favorita,
    createdAt: p.createdAt,
    updatedAt: p.updatedAt,
    version: p.version,
    savedAt: p.savedAt,
    favoritedAt: p.favoritedAt,
    isPublished: p.isPublished,
    publicationReach: p.publicationReach,
    publicationCategory: p.publicationCategory,
    publishedAt: p.publishedAt,
  );
}

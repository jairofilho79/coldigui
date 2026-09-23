import '../../../../core/utils/pdf_id_codec.dart';
import '../../../catalog/domain/legacy_ids/legacy_id_store.dart';
import '../../domain/entities/saved_playlist.dart';
import '../../domain/repositories/playlist_repository.dart';

/// `Playlist.items` + `pdfIds` (spec 2026-09-23 §6.2).
///
/// Troca cada id legado resolvido mantendo o `kind` e a ordem, pelo
/// [PlaylistRepository.update] — que reprojeta `pdfIds`/`audioIds` e marca
/// `pendingPush` nas salvas (o push leva a lista normalizada ao D1). Id
/// desconhecido fica: aparece como indisponível e o usuário remove.
///
/// Normalizar não é editar: o `updatedAt` da lista **fica** (o Worker aceita
/// o push com `clientUpdatedAt == updated_at`). Carimbar agora faria o pull
/// descartar uma edição remota mais nova e impediria um tombstone remoto de
/// apagar a lista (`SyncPlaylists._applyRemoteDeletion`).
///
/// Nada serializa as escritas de playlists, então cada lista é relida logo
/// antes da sua escrita e a troca é aplicada a essa cópia — nunca à foto de
/// [PlaylistRepository.getAll], que uma edição do usuário ou um pull podem
/// ter deixado velha.
class PlaylistLegacyIdStore implements LegacyIdStore {
  const PlaylistLegacyIdStore(this._repository);

  final PlaylistRepository _repository;

  @override
  String get name => 'playlists';

  @override
  Future<Set<String>> collectLegacyIds() async => {
    for (final playlist in await _repository.getAll())
      for (final entry in playlist.entries)
        if (isLegacyPdfId(entry.id)) entry.id,
  };

  @override
  Future<int> rewrite(LegacyIdResolution resolution) async {
    var changed = 0;
    for (final candidate in await _repository.getAll()) {
      if (_rewritten(candidate.entries, resolution) == null) continue;

      final fresh = await _repository.getById(candidate.playlistId);
      // Apagada entretanto (tombstone local ou remoto): não ressuscitar.
      if (fresh == null || fresh.deletedAt != null) continue;
      final next = _rewritten(fresh.entries, resolution);
      if (next == null) continue;

      await _repository.update(
        fresh.playlistId,
        entries: next,
        updatedAt: fresh.updatedAt,
        // `update` marcaria `pendingPush` (só nas salvas); um conflito
        // continua conflito — o banner conta-o e o push ignora-o até o
        // usuário decidir.
        syncStatus: fresh.syncStatus == PlaylistSyncStatus.conflict
            ? PlaylistSyncStatus.conflict
            : null,
      );
      changed++;
    }
    return changed;
  }

  /// [entries] com os legados resolvidos trocados, ou `null` se nenhum mudou.
  static List<PlaylistEntry>? _rewritten(
    List<PlaylistEntry> entries,
    LegacyIdResolution resolution,
  ) {
    var touched = false;
    final next = <PlaylistEntry>[];
    for (final entry in entries) {
      final mapped = resolution.resolved[entry.id];
      if (mapped == null) {
        next.add(entry);
      } else {
        next.add(PlaylistEntry(id: mapped, kind: entry.kind));
        touched = true;
      }
    }
    return touched ? next : null;
  }
}

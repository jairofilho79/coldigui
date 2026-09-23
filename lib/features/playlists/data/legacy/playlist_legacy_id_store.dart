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
/// ter deixado velha. Resta a janela curta dentro do próprio `update` (ele lê
/// e depois grava, com `await` no meio): fechá-la pediria uma transação Isar
/// única, que o repositório não expõe.
///
/// Lista de **outra** conta (`ownerSub` diferente de [currentSub]; sem sessão
/// conta como outra) troca os ids mas guarda o `syncStatus`: uma `synced`
/// continua `synced` e sai no `purgeSyncedOwnedBy` da troca de conta — virar
/// `pendingPush` deixá-la-ia à vista da conta seguinte. Sem dono ou da conta
/// corrente seguem a regra de cima.
class PlaylistLegacyIdStore implements LegacyIdStore {
  const PlaylistLegacyIdStore(
    this._repository, {
    required String? Function() currentSub,
  }) : _currentSub = currentSub; // ignore: prefer_initializing_formals

  final PlaylistRepository _repository;

  /// `sub` da sessão atual, ou `null` sem sessão.
  final String? Function() _currentSub;

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

      final owner = fresh.ownerSub;
      final foreign = owner != null && owner != _currentSub();
      await _repository.update(
        fresh.playlistId,
        entries: next,
        updatedAt: fresh.updatedAt,
        // `update` marcaria `pendingPush` (só nas salvas). Um conflito
        // continua conflito — o banner conta-o e o push ignora-o até o
        // usuário decidir —, e a lista de outra conta guarda o seu estado.
        syncStatus: foreign || fresh.syncStatus == PlaylistSyncStatus.conflict
            ? fresh.syncStatus
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

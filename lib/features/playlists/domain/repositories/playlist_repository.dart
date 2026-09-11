import '../entities/playlist_tab.dart';
import '../entities/saved_playlist.dart';

/// Contrato de persistência de playlists (UC-06 + UC-15).
abstract class PlaylistRepository {
  /// Todas as playlists ativas (sem tombstones).
  Future<List<SavedPlaylist>> getAll();

  /// Playlists filtradas e ordenadas por aba (pilha — mais recente no topo).
  Future<List<SavedPlaylist>> getByTab(PlaylistTab tab);

  /// Lookup O(1) por [playlistId] (inclui tombstone se existir).
  Future<SavedPlaylist?> getById(String playlistId);

  /// Persiste nova playlist; retorna [playlistId] gerado.
  ///
  /// [entries] é a ordem única tipada e vence as duas listas legadas quando
  /// informado — é o único jeito de criar uma playlist com partituras e áudios
  /// intercalados (import de share v2, spec A.5). Sem ele, `pdfIds` seguido de
  /// `audioIds` continua sendo a ordem gravada.
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
  });

  /// Atualização parcial — lança [StateError] se playlist ausente.
  ///
  /// [entries] é a ordem única tipada e **vence** [pdfIds]/[audioIds]: é o
  /// único jeito de gravar repetição do mesmo id e de mover uma entrada entre
  /// faces sem passar pelas projeções.
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
  });

  /// Publica lista salva (irreversível). Lança [StateError] se já publicada
  /// ou se não for salva.
  Future<void> publish(
    String playlistId, {
    required PlaylistCategory category,
    PlaylistReach reach = PlaylistReach.usual,
  });

  /// Soft delete se salva; hard delete se rascunho.
  Future<void> delete(String playlistId);

  /// Hard delete imediato (após DELETE remoto ok).
  Future<void> hardDelete(String playlistId);

  /// Remove todas as playlists não salvas.
  Future<void> deleteAllUnsaved();

  /// Pendentes de push (ativas, salvas) que [sub] pode enviar: as dela e as
  /// ainda sem dono (spec A.5).
  Future<List<SavedPlaylist>> getPendingPush({String? sub});

  /// Tombstones locais aguardando DELETE remoto que [sub] pode enviar: os dela
  /// e os ainda sem dono (mesma regra de [getPendingPush]).
  ///
  /// Apagar na nuvem da conta anterior não é assunto desta conta — o tombstone
  /// do dono antigo fica no aparelho até ela voltar (spec A.5).
  Future<List<SavedPlaylist>> getTombstones({String? sub});

  /// Upsert completo a partir do remoto / sync.
  Future<void> upsert(SavedPlaylist playlist);

  /// Pós-login: marca `pendingPush` e grava `ownerSub = sub` nas listas salvas
  /// sem dono ou já de [sub] (spec A.5).
  ///
  /// Rascunhos (`salva == false`) nunca ganham dono; listas de outra conta
  /// ficam intocadas — elas não sobem no push desta.
  Future<void> adoptForSub(String sub);

  /// Troca de conta: hard delete das listas `synced` de [previousSub].
  ///
  /// Só as `synced`: elas estão na nuvem da conta anterior e voltam no próximo
  /// login dela. `pendingPush`/`conflict` ficam no aparelho, com o dono antigo.
  /// Devolve quantas saíram.
  Future<int> purgeSyncedOwnedBy(String previousSub);
}

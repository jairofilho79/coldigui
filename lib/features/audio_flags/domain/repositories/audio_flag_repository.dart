import '../entities/saved_audio_flag.dart';

/// Persistência local de marcadores de áudio.
abstract class AudioFlagRepository {
  Future<List<SavedAudioFlag>> getByAudioId(String audioId);

  Future<SavedAudioFlag?> getById(String flagId);

  Future<String> create({
    required String audioId,
    required int positionMs,
    String label = '',
    String? flagId,
    DateTime? createdAt,
  });

  Future<void> delete(String flagId);

  Future<void> hardDelete(String flagId);

  /// Pendências que [sub] pode enviar: as dela e as ainda sem dono (spec A.5).
  Future<List<SavedAudioFlag>> getPendingPush({String? sub});

  /// Tombstones locais aguardando DELETE remoto que [sub] pode enviar: os dela
  /// e os ainda sem dono (mesma regra de [getPendingPush]).
  ///
  /// Apagar na nuvem da conta anterior não é assunto desta conta — o tombstone
  /// do dono antigo fica no aparelho até ela voltar (spec A.5).
  Future<List<SavedAudioFlag>> getTombstones({String? sub});

  Future<void> upsert(SavedAudioFlag flag);

  /// Pós-login: marca `pendingPush` e grava `ownerSub = sub` nas linhas sem
  /// dono ou já de [sub].
  ///
  /// Sem armazenamento lança `StorageUnavailableException` — nunca finge que
  /// adotou.
  Future<void> adoptForSub(String sub);

  /// Troca de conta: hard delete das linhas `synced` de [previousSub].
  ///
  /// Devolve quantas saíram; sem armazenamento lança
  /// `StorageUnavailableException`.
  Future<int> purgeSyncedOwnedBy(String previousSub);
}

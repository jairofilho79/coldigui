import 'package:isar_plus/isar_plus.dart';

part 'offline_audio_index.g.dart';

/// Índice offline de áudios Coldigom `audioId → storageKey` (spec offline
/// Coldigom §5.1, O7).
///
/// Irmão de [OfflinePdfIndex], sem `isPersistent` nem `lastAccessedAt`: áudio
/// só entra aqui por download explícito e nunca é evictado (não há LRU de
/// áudio, §9) — sai só por «Remover baixados do Coldigom».
@Collection()
class OfflineAudioIndex {
  int id = 0;

  /// `encodePdfId(r2Key)` — o mesmo id de `AudioTrack.audioId`.
  @Index(unique: true)
  late String audioId;

  /// Chave do objeto no R2 (`assets/praises/<praise>/<material>.mp3`).
  late String r2Key;

  /// Path absoluto (nativo, `documents/plpcg_audio/…`) ou chave lógica
  /// (web, `plpcg_audio/…` na Cache API) — o que [AudioStoragePort] devolveu.
  late String storageKey;

  /// Bytes gravados — soma para «Remover» e para as stats, sem scan.
  late int fileSize;

  late DateTime downloadedAt;
}

import 'dart:typed_data';

import '../entities/local_audio_source.dart';
import '../entities/offline_audio_entry.dart';

/// Persistência de áudios Coldigom — índice Isar + [AudioStoragePort] (O7).
///
/// DI via `offlineAudioRepositoryProvider`. Consumido pelo player
/// (`lookup`), pelo download (`lookupBatch`/`upsert`) e pela remoção.
abstract class OfflineAudioRepository {
  /// Índice + ficheiro válidos; `null` caso contrário.
  Future<LocalAudioSource?> lookup(String audioId);

  /// Subconjunto de [audioIds] com índice e ficheiro.
  Future<Set<String>> lookupBatch(Set<String> audioIds);

  Future<OfflineAudioEntry> upsert({
    required String audioId,
    required String r2Key,
    required Uint8List bytes,
  });

  /// Apaga ficheiro e índice (idempotente).
  Future<void> remove(String audioId);

  Future<List<OfflineAudioEntry>> listAll();

  /// Soma de `fileSize` do índice — sem scan.
  Future<int> totalBytes();

  /// «Remover áudios baixados»: store inteiro + índice.
  Future<void> removeAll();
}

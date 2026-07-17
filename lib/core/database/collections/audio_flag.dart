import 'package:isar_plus/isar_plus.dart';

import 'playlist_sync_status.dart';

part 'audio_flag.g.dart';

/// Marcador de áudio do usuário (checkpoint por posição).
///
/// [flagId] é UUID estável; [audioId] é a chave Coldigom da faixa.
@Collection()
class AudioFlag {
  int id = 0;

  @Index(unique: true)
  late String flagId;

  @Index()
  late String audioId;

  late int positionMs;

  /// Rótulo opcional; string vazia = sem nome.
  String label = '';

  late DateTime createdAt;

  DateTime updatedAt = DateTime.fromMillisecondsSinceEpoch(0);

  int version = 1;

  /// Índice de [PlaylistSyncStatus] (0 synced … 3 conflict).
  int syncStatusIndex = 0;

  DateTime? deletedAt;
}

extension AudioFlagSyncStatusX on AudioFlag {
  PlaylistSyncStatus get syncStatus =>
      PlaylistSyncStatus.values[syncStatusIndex.clamp(
        0,
        PlaylistSyncStatus.values.length - 1,
      )];

  set syncStatus(PlaylistSyncStatus value) => syncStatusIndex = value.index;
}

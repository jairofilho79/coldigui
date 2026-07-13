import 'package:isar_plus/isar_plus.dart';

import 'playlist_sync_status.dart';

part 'playlist.g.dart';

/// Playlist do usuário (UC-06/07 + UC-15 sync).
///
/// [playlistId] é UUID estável; [pdfIds] preserva ordem da seleção.
/// [salva] default `true` migra registros existentes como salvas.
@Collection()
class Playlist {
  int id = 0;

  @Index(unique: true)
  late String playlistId;

  late String nome;
  late List<String> pdfIds;
  late DateTime createdAt;

  /// `false` = lista não salva (rascunho automático ao abrir louvor).
  bool salva = true;

  DateTime? savedAt;
  DateTime? favoritedAt;
  bool favorita = false;

  /// Última mutação local/remota — merge last-write-wins.
  DateTime updatedAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Versão otimista do servidor.
  int version = 1;

  /// Índice de [PlaylistSyncStatus] (0 synced … 3 conflict).
  int syncStatusIndex = 0;

  /// Soft delete local (tombstone até push remoto).
  DateTime? deletedAt;
}

extension PlaylistSyncStatusX on Playlist {
  PlaylistSyncStatus get syncStatus =>
      PlaylistSyncStatus.values[syncStatusIndex.clamp(
        0,
        PlaylistSyncStatus.values.length - 1,
      )];

  set syncStatus(PlaylistSyncStatus value) => syncStatusIndex = value.index;
}

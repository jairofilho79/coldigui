import '../../../../core/database/collections/playlist_sync_status.dart';

export '../../../../core/database/collections/playlist_sync_status.dart';

/// Playlist do usuário (UC-06, Fase 4.2+ / UC-15 sync).
///
/// Espelha o modelo persistido sem expor Isar.
class SavedPlaylist {
  SavedPlaylist({
    required this.playlistId,
    required this.nome,
    required this.pdfIds,
    required this.createdAt,
    this.salva = true,
    this.savedAt,
    this.favoritedAt,
    this.favorita = false,
    DateTime? updatedAt,
    this.version = 1,
    this.syncStatus = PlaylistSyncStatus.synced,
    this.deletedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  /// Identificador estável (UUID-like, compatível com PWA).
  final String playlistId;

  /// Nome exibido na lista — default `lista dd/MM/yyyy HH:mm:ss` na criação.
  final String nome;

  /// IDs dos PDFs na ordem da seleção original.
  final List<String> pdfIds;

  final DateTime createdAt;

  /// `false` quando criada automaticamente ao abrir louvor no leitor.
  final bool salva;

  /// Preenchido ao salvar; ordena aba Salvas.
  final DateTime? savedAt;

  /// Preenchido ao favoritar; ordena aba Favoritas.
  final DateTime? favoritedAt;

  final bool favorita;

  final DateTime updatedAt;
  final int version;
  final PlaylistSyncStatus syncStatus;
  final DateTime? deletedAt;

  SavedPlaylist copyWith({
    String? playlistId,
    String? nome,
    List<String>? pdfIds,
    DateTime? createdAt,
    bool? salva,
    DateTime? savedAt,
    DateTime? favoritedAt,
    bool? favorita,
    DateTime? updatedAt,
    int? version,
    PlaylistSyncStatus? syncStatus,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return SavedPlaylist(
      playlistId: playlistId ?? this.playlistId,
      nome: nome ?? this.nome,
      pdfIds: pdfIds ?? this.pdfIds,
      createdAt: createdAt ?? this.createdAt,
      salva: salva ?? this.salva,
      savedAt: savedAt ?? this.savedAt,
      favoritedAt: favoritedAt ?? this.favoritedAt,
      favorita: favorita ?? this.favorita,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      syncStatus: syncStatus ?? this.syncStatus,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}

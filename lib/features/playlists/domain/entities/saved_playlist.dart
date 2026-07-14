import '../../../../core/database/collections/playlist_publication.dart';
import '../../../../core/database/collections/playlist_sync_status.dart';

export '../../../../core/database/collections/playlist_publication.dart';
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
    this.audioIds = const [],
    this.salva = true,
    this.savedAt,
    this.favoritedAt,
    this.favorita = false,
    DateTime? updatedAt,
    this.version = 1,
    this.syncStatus = PlaylistSyncStatus.synced,
    this.deletedAt,
    this.isPublished = false,
    this.publicationReach,
    this.publicationCategory,
    this.publishedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  /// Identificador estável (UUID-like, compatível com PWA).
  final String playlistId;

  /// Nome exibido na lista — default `lista dd/MM/yyyy HH:mm:ss` na criação.
  final String nome;

  /// IDs dos PDFs na ordem da seleção original.
  final List<String> pdfIds;

  /// IDs das faixas de áudio (ordem independente).
  final List<String> audioIds;

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

  /// `true` após publicação — irreversível sem excluir a lista.
  final bool isPublished;

  /// Alcance da publicidade; só preenchido se [isPublished].
  final PlaylistReach? publicationReach;

  /// Categoria; obrigatória na publicação.
  final PlaylistCategory? publicationCategory;

  final DateTime? publishedAt;

  SavedPlaylist copyWith({
    String? playlistId,
    String? nome,
    List<String>? pdfIds,
    List<String>? audioIds,
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
    bool? isPublished,
    PlaylistReach? publicationReach,
    PlaylistCategory? publicationCategory,
    DateTime? publishedAt,
    bool clearPublication = false,
  }) {
    return SavedPlaylist(
      playlistId: playlistId ?? this.playlistId,
      nome: nome ?? this.nome,
      pdfIds: pdfIds ?? this.pdfIds,
      audioIds: audioIds ?? this.audioIds,
      createdAt: createdAt ?? this.createdAt,
      salva: salva ?? this.salva,
      savedAt: savedAt ?? this.savedAt,
      favoritedAt: favoritedAt ?? this.favoritedAt,
      favorita: favorita ?? this.favorita,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      syncStatus: syncStatus ?? this.syncStatus,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      isPublished: clearPublication ? false : (isPublished ?? this.isPublished),
      publicationReach: clearPublication
          ? null
          : (publicationReach ?? this.publicationReach),
      publicationCategory: clearPublication
          ? null
          : (publicationCategory ?? this.publicationCategory),
      publishedAt: clearPublication ? null : (publishedAt ?? this.publishedAt),
    );
  }
}

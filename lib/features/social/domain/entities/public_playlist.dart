import '../../../playlists/domain/entities/saved_playlist.dart';

/// Playlist pública de outro usuário (descoberta social).
class PublicPlaylist {
  const PublicPlaylist({
    required this.id,
    required this.nome,
    required this.pdfIds,
    this.publicationReach,
    this.publicationCategory,
    this.publishedAt,
  });

  final String id;
  final String nome;
  final List<String> pdfIds;
  final PlaylistReach? publicationReach;
  final PlaylistCategory? publicationCategory;
  final DateTime? publishedAt;

  factory PublicPlaylist.fromJson(Map<String, dynamic> json) {
    final pdfRaw = json['pdfIds'];
    return PublicPlaylist(
      id: json['id'] as String? ?? '',
      nome: json['nome'] as String? ?? '',
      pdfIds: pdfRaw is List
          ? pdfRaw.whereType<String>().toList(growable: false)
          : const [],
      publicationReach: PlaylistReachWire.tryParse(
        json['publicationReach'] as String?,
      ),
      publicationCategory: PlaylistCategoryWire.tryParse(
        json['publicationCategory'] as String?,
      ),
      publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? ''),
    );
  }
}

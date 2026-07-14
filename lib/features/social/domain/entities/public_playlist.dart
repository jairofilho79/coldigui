import '../../../playlists/domain/entities/saved_playlist.dart';

/// Playlist pública de outro usuário (descoberta social).
class PublicPlaylist {
  const PublicPlaylist({
    required this.id,
    required this.nome,
    required this.pdfIds,
    this.audioIds = const [],
    this.publicationReach,
    this.publicationCategory,
    this.publishedAt,
  });

  final String id;
  final String nome;
  final List<String> pdfIds;
  final List<String> audioIds;
  final PlaylistReach? publicationReach;
  final PlaylistCategory? publicationCategory;
  final DateTime? publishedAt;

  factory PublicPlaylist.fromJson(Map<String, dynamic> json) {
    final pdfRaw = json['pdfIds'];
    final audioRaw = json['audioIds'];
    return PublicPlaylist(
      id: json['id'] as String? ?? '',
      nome: json['nome'] as String? ?? '',
      pdfIds: pdfRaw is List
          ? pdfRaw.whereType<String>().toList(growable: false)
          : const [],
      audioIds: audioRaw is List
          ? audioRaw.whereType<String>().toList(growable: false)
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

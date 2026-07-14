import '../../../../core/database/collections/playlist_publication.dart';

/// Playlist remota (payload Worker `/api/playlists`).
class RemotePlaylist {
  const RemotePlaylist({
    required this.id,
    required this.nome,
    required this.pdfIds,
    required this.salva,
    required this.favorita,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    this.audioIds = const [],
    this.savedAt,
    this.favoritedAt,
    this.isPublished = false,
    this.publicationReach,
    this.publicationCategory,
    this.publishedAt,
  });

  final String id;
  final String nome;
  final List<String> pdfIds;
  final List<String> audioIds;
  final bool salva;
  final bool favorita;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final DateTime? savedAt;
  final DateTime? favoritedAt;
  final bool isPublished;
  final PlaylistReach? publicationReach;
  final PlaylistCategory? publicationCategory;
  final DateTime? publishedAt;

  factory RemotePlaylist.fromJson(Map<String, dynamic> json) {
    return RemotePlaylist(
      id: json['id'] as String,
      nome: json['nome'] as String,
      pdfIds: (json['pdfIds'] as List<dynamic>? ?? const []).cast<String>(),
      audioIds: (json['audioIds'] as List<dynamic>? ?? const []).cast<String>(),
      salva: json['salva'] as bool? ?? true,
      favorita: json['favorita'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      version: json['version'] as int? ?? 1,
      savedAt: _parseOptionalDate(json['savedAt']),
      favoritedAt: _parseOptionalDate(json['favoritedAt']),
      isPublished: json['isPublished'] as bool? ?? false,
      publicationReach: PlaylistReachWire.tryParse(
        json['publicationReach'] as String?,
      ),
      publicationCategory: PlaylistCategoryWire.tryParse(
        json['publicationCategory'] as String?,
      ),
      publishedAt: _parseOptionalDate(json['publishedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'pdfIds': pdfIds,
    'audioIds': audioIds,
    'salva': salva,
    'favorita': favorita,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'version': version,
    'savedAt': savedAt?.toUtc().toIso8601String(),
    'favoritedAt': favoritedAt?.toUtc().toIso8601String(),
    'isPublished': isPublished,
    'publicationReach': publicationReach?.wireValue,
    'publicationCategory': publicationCategory?.wireValue,
    'publishedAt': publishedAt?.toUtc().toIso8601String(),
  };

  static DateTime? _parseOptionalDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}

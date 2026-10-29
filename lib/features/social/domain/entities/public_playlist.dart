import '../../../playlists/domain/entities/saved_playlist.dart';

/// Playlist pública de outro usuário (descoberta social).
class PublicPlaylist {
  /// [entries] é a ordem única tipada — fonte da verdade do payload.
  const PublicPlaylist({
    required this.id,
    required this.nome,
    required this.entries,
    this.publicationReach,
    this.publicationCategory,
    this.publishedAt,
  });

  /// Compat com as listas do wire v1 (`pdfIds`/`audioIds` separados).
  PublicPlaylist.fromLegacyLists({
    required this.id,
    required this.nome,
    List<String> pdfIds = const [],
    List<String> audioIds = const [],
    this.publicationReach,
    this.publicationCategory,
    this.publishedAt,
  }) : entries = SavedPlaylist.entriesFromLegacyLists(
         pdfIds: pdfIds,
         audioIds: audioIds,
       );

  final String id;
  final String nome;

  /// Ordem única tipada — fonte da verdade a partir da v2.
  final List<PlaylistEntry> entries;

  /// Projeção PDF/cifra derivada de [entries] — compat com quem ainda lê a
  /// lista antiga (`social_user_card.dart`, Tarefa 14).
  List<String> get pdfIds =>
      entries.where((e) => !e.isAudio).map((e) => e.id).toList(growable: false);

  /// Projeção de áudio derivada de [entries].
  List<String> get audioIds =>
      entries.where((e) => e.isAudio).map((e) => e.id).toList(growable: false);

  final PlaylistReach? publicationReach;
  final PlaylistCategory? publicationCategory;
  final DateTime? publishedAt;

  /// Lê um payload v1 ou v2.
  ///
  /// Lança [FormatException] quando `id` está ausente/inválido, e quando
  /// `items` (v2) não tem a forma esperada — a tolerância por registro (pular
  /// uma playlist ruim em vez de perder a página inteira) é responsabilidade
  /// de [SocialRemoteDatasource.fetchUserPlaylists].
  factory PublicPlaylist.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw FormatException(
        'PublicPlaylist: campo "id" obrigatório ausente ou inválido '
        '(veio $id)',
      );
    }
    final pdfIds = _stringList(json, 'pdfIds');
    final audioIds = _stringList(json, 'audioIds');
    final rawItems = json['items'];
    if (rawItems != null && rawItems is! List) {
      throw FormatException(
        'PublicPlaylist: campo "items" deve ser uma lista, veio $rawItems',
      );
    }

    return PublicPlaylist(
      id: id,
      nome: json['nome'] as String? ?? '',
      // `items` (v2) manda; as listas só entram quando ele não veio (v1).
      entries: rawItems == null
          ? SavedPlaylist.entriesFromLegacyLists(
              pdfIds: pdfIds,
              audioIds: audioIds,
            )
          : _entriesFromWireItems(rawItems as List, audioIds),
      publicationReach: PlaylistReachWire.tryParse(
        json['publicationReach'] as String?,
      ),
      publicationCategory: PlaylistCategoryWire.tryParse(
        json['publicationCategory'] as String?,
      ),
      publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? ''),
    );
  }

  /// `items` do wire v2 → [PlaylistEntry], aceitando objeto e string solta.
  static List<PlaylistEntry> _entriesFromWireItems(
    List<Object?> rawItems,
    List<String> declaredAudio,
  ) {
    final declared = declaredAudio.toSet();
    return [
      for (final raw in rawItems)
        if (raw == null)
          throw const FormatException('PublicPlaylist: entrada nula em "items"')
        else
          PlaylistEntry.fromJson(raw, declaredAudio: declared),
    ];
  }

  static List<String> _stringList(Map<String, dynamic> json, String field) {
    final value = json[field];
    return value is List
        ? value.whereType<String>().toList(growable: false)
        : const [];
  }
}

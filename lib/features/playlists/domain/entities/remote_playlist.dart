// `PlaylistReach`/`PlaylistCategory` são usados aqui por direito próprio;
// depender do re-export de `saved_playlist.dart` deixaria este arquivo
// quebrado se aquele export sumisse.
// ignore: unnecessary_import
import '../../../../core/database/collections/playlist_publication.dart';
import 'saved_playlist.dart';

/// Versão do payload de playlist enviada ao Worker.
///
/// - v1: só `pdfIds` + `audioIds` (duas listas independentes).
/// - v2: `items` (ordem única) + `pdfIds`/`audioIds` derivados.
///
/// O cliente sempre envia v2 **com as listas derivadas**, porque o Worker
/// `plpcg-catalog` ainda lê os campos v1. Payload sem `schemaVersion`/`items`
/// é lido como v1 e vira `items = [...pdfIds, ...audioIds]`.
const int kPlaylistSchemaVersion = 2;

/// Playlist remota (payload Worker `/api/playlists`).
class RemotePlaylist {
  /// [items] é a ordem única; omiti-lo mantém a semântica v1
  /// (`[...pdfIds, ...audioIds]`).
  RemotePlaylist({
    required this.id,
    required this.nome,
    required this.salva,
    required this.favorita,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    List<String>? items,
    List<String> pdfIds = const [],
    List<String> audioIds = const [],
    this.schemaVersion = kPlaylistSchemaVersion,
    this.savedAt,
    this.favoritedAt,
    this.isPublished = false,
    this.publicationReach,
    this.publicationCategory,
    this.publishedAt,
  }) : items = List<String>.unmodifiable(
         items ?? <String>[...pdfIds, ...audioIds],
       );

  final String id;
  final String nome;

  /// Versão do schema do payload recebido/enviado.
  final int schemaVersion;

  /// Ordem única de materiais — fonte da verdade a partir da v2.
  final List<String> items;

  /// Projeção PDF/cifra de [items] — enviada para o Worker v1 continuar
  /// funcionando.
  late final List<String> pdfIds = items
      .where(SavedPlaylist.isPdfFaceItem)
      .toList(growable: false);

  /// Projeção de áudio de [items].
  late final List<String> audioIds = items
      .where(SavedPlaylist.isAudioFaceItem)
      .toList(growable: false);

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
    final pdfIds = (json['pdfIds'] as List<dynamic>? ?? const [])
        .cast<String>();
    final audioIds = (json['audioIds'] as List<dynamic>? ?? const [])
        .cast<String>();
    final rawItems = json['items'] as List<dynamic>?;
    final schemaVersion = json['schemaVersion'] as int?;

    return RemotePlaylist(
      id: json['id'] as String,
      nome: json['nome'] as String,
      // Sem `schemaVersion`/`items` o payload é v1: a ordem única é a
      // concatenação das duas listas.
      schemaVersion: schemaVersion ?? (rawItems == null ? 1 : 2),
      items: rawItems == null
          ? <String>[...pdfIds, ...audioIds]
          : rawItems.cast<String>(),
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

  /// Sempre v2: `items` mais as duas listas derivadas (compat com o Worker).
  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'schemaVersion': kPlaylistSchemaVersion,
    'items': items,
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

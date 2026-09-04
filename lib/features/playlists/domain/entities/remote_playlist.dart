// `PlaylistReach`/`PlaylistCategory` são usados aqui por direito próprio;
// depender do re-export de `saved_playlist.dart` deixaria este arquivo
// quebrado se aquele export sumisse.
// ignore: unnecessary_import
import '../../../../core/database/collections/playlist_publication.dart';
import 'saved_playlist.dart';

/// Versão do payload de playlist enviada ao Worker.
///
/// - v1: só `pdfIds` + `audioIds` (duas listas independentes).
/// - v2: `items` como **objetos** `{id, kind}` (ordem única tipada) mais
///   `pdfIds`/`audioIds` derivados.
///
/// O cliente sempre envia v2 **com as listas derivadas**, porque um Worker v1
/// ainda lê só os campos antigos. Na leitura, [RemotePlaylist.fromJson] aceita
/// os três formatos que já circularam:
///
/// | payload | leitura |
/// | --- | --- |
/// | sem `schemaVersion` nem `items` | v1: `pdfIds` classificado pela extensão, `audioIds` como áudio |
/// | `items` de **strings** (rascunho v2 da fatia 1, só existiu em Isar local) | classifica pela extensão, com `audioIds` como veredito |
/// | `items` de **objetos** | `kind` do wire, normalizado por `resolveWireKind` |
///
/// `items`, quando presente, **manda** sobre `pdfIds`/`audioIds` — as listas
/// são projeções derivadas, não uma segunda fonte da verdade.
const int kPlaylistSchemaVersion = 2;

/// Playlist remota (payload Worker `/api/playlists`).
class RemotePlaylist {
  /// [entries] é a ordem única tipada — fonte da verdade do payload.
  RemotePlaylist({
    required this.id,
    required this.nome,
    required this.salva,
    required this.favorita,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required List<PlaylistEntry> entries,
    this.schemaVersion = kPlaylistSchemaVersion,
    this.savedAt,
    this.favoritedAt,
    this.isPublished = false,
    this.publicationReach,
    this.publicationCategory,
    this.publishedAt,
  }) : entries = List<PlaylistEntry>.unmodifiable(entries);

  /// Compat com as listas do wire v1 e com o rascunho v2 (`items` de strings).
  ///
  /// Mesmas regras de [SavedPlaylist.fromLegacyLists]: `audioIds` é o veredito
  /// de áudio do Worker (A8) e vence a extensão do id.
  RemotePlaylist.fromLegacyLists({
    required String id,
    required String nome,
    required bool salva,
    required bool favorita,
    required DateTime createdAt,
    required DateTime updatedAt,
    required int version,
    List<String>? items,
    List<String> pdfIds = const [],
    List<String> audioIds = const [],
    int schemaVersion = kPlaylistSchemaVersion,
    DateTime? savedAt,
    DateTime? favoritedAt,
    bool isPublished = false,
    PlaylistReach? publicationReach,
    PlaylistCategory? publicationCategory,
    DateTime? publishedAt,
  }) : this(
         id: id,
         nome: nome,
         salva: salva,
         favorita: favorita,
         createdAt: createdAt,
         updatedAt: updatedAt,
         version: version,
         entries: SavedPlaylist.entriesFromLegacyLists(
           items: items,
           pdfIds: pdfIds,
           audioIds: audioIds,
         ),
         schemaVersion: schemaVersion,
         savedAt: savedAt,
         favoritedAt: favoritedAt,
         isPublished: isPublished,
         publicationReach: publicationReach,
         publicationCategory: publicationCategory,
         publishedAt: publishedAt,
       );

  final String id;
  final String nome;

  /// Versão do schema do payload recebido/enviado.
  final int schemaVersion;

  /// Ordem única tipada — fonte da verdade a partir da v2.
  final List<PlaylistEntry> entries;

  /// Ids de [entries], na ordem.
  late final List<String> items = entries
      .map((e) => e.id)
      .toList(growable: false);

  /// Projeção PDF/cifra — enviada para o Worker v1 continuar funcionando.
  late final List<String> pdfIds = entries
      .where((e) => !e.isAudio)
      .map((e) => e.id)
      .toList(growable: false);

  /// Projeção de áudio de [entries].
  late final List<String> audioIds = entries
      .where((e) => e.isAudio)
      .map((e) => e.id)
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

  /// Lê um payload v1 ou v2.
  ///
  /// Lança [FormatException] **nomeando o campo** quando um campo obrigatório
  /// (`id`, `nome`, `createdAt`, `updatedAt`) falta ou tem tipo inesperado, e
  /// quando `items`/`pdfIds`/`audioIds` não têm a forma esperada. A tolerância
  /// por item (pular uma entrada ruim em vez de perder a playlist inteira) é
  /// responsabilidade de quem chama, na fase de pull do sync (A.7).
  factory RemotePlaylist.fromJson(Map<String, Object?> json) {
    final pdfIds = _stringList(json, 'pdfIds');
    final audioIds = _stringList(json, 'audioIds');
    final rawItems = json['items'];
    if (rawItems != null && rawItems is! List) {
      throw FormatException(
        'RemotePlaylist: campo "items" deve ser uma lista, veio $rawItems',
      );
    }
    final schemaVersion = _optionalInt(json, 'schemaVersion');

    return RemotePlaylist(
      id: _requiredString(json, 'id'),
      nome: _requiredString(json, 'nome', allowEmpty: true),
      // Sem `schemaVersion`/`items` o payload é v1: a ordem única é a
      // concatenação das duas listas.
      schemaVersion: schemaVersion ?? (rawItems == null ? 1 : 2),
      // `items` manda; as listas só entram quando ele não veio.
      entries: rawItems == null
          ? SavedPlaylist.entriesFromLegacyLists(
              pdfIds: pdfIds,
              audioIds: audioIds,
            )
          : _entriesFromWireItems(rawItems as List, audioIds),
      salva: json['salva'] as bool? ?? true,
      favorita: json['favorita'] as bool? ?? false,
      createdAt: _requiredDate(json, 'createdAt'),
      updatedAt: _requiredDate(json, 'updatedAt'),
      version: _optionalInt(json, 'version') ?? 1,
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

  /// `items` do wire v2 → [PlaylistEntry], aceitando objeto e string solta.
  ///
  /// [declaredAudio] é o `audioIds` do mesmo payload: só serve para a entrada
  /// que chegou **sem** `kind` (string do rascunho v2, ou objeto de um cliente
  /// que só sabia mandar o id).
  static List<PlaylistEntry> _entriesFromWireItems(
    List<Object?> rawItems,
    List<String> declaredAudio,
  ) {
    final declared = declaredAudio.toSet();
    return [
      for (final raw in rawItems)
        if (raw == null)
          throw const FormatException('RemotePlaylist: entrada nula em "items"')
        else
          PlaylistEntry.fromJson(raw, declaredAudio: declared),
    ];
  }

  /// Sempre v2: `items` como objetos `{id, kind}` mais as duas listas
  /// derivadas, para um leitor v1 continuar funcionando.
  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'schemaVersion': kPlaylistSchemaVersion,
    'items': entries.map((e) => e.toJson()).toList(growable: false),
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

  static String _requiredString(
    Map<String, Object?> json,
    String field, {
    bool allowEmpty = false,
  }) {
    final value = json[field];
    if (value is! String || (!allowEmpty && value.isEmpty)) {
      throw FormatException(
        'RemotePlaylist: campo "$field" obrigatório ausente ou inválido '
        '(veio $value)',
      );
    }
    return value;
  }

  static DateTime _requiredDate(Map<String, Object?> json, String field) {
    final value = json[field];
    final parsed = value is String ? DateTime.tryParse(value) : null;
    if (parsed == null) {
      throw FormatException(
        'RemotePlaylist: campo "$field" não é uma data ISO-8601 (veio $value)',
      );
    }
    return parsed;
  }

  static int? _optionalInt(Map<String, Object?> json, String field) {
    final value = json[field];
    if (value == null) return null;
    if (value is! int) {
      throw FormatException(
        'RemotePlaylist: campo "$field" deve ser inteiro (veio $value)',
      );
    }
    return value;
  }

  static List<String> _stringList(Map<String, Object?> json, String field) {
    final value = json[field];
    if (value == null) return const [];
    if (value is! List || value.any((v) => v is! String)) {
      throw FormatException(
        'RemotePlaylist: campo "$field" deve ser uma lista de strings '
        '(veio $value)',
      );
    }
    return value.cast<String>().toList(growable: false);
  }
}

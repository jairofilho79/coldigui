import '../../../../core/database/collections/playlist_publication.dart';
import '../../../../core/database/collections/playlist_sync_status.dart';
import 'playlist_entry.dart';

export '../../../../core/database/collections/playlist_publication.dart';
export '../../../../core/database/collections/playlist_sync_status.dart';
export 'playlist_entry.dart';

/// Playlist do usuário (UC-06, Fase 4.2+ / UC-15 sync).
///
/// Espelha o modelo persistido sem expor Isar.
///
/// [entries] é a **única** fonte de verdade de conteúdo, ordem e tipo (D2 fatia
/// 2). [items], [pdfIds] e [audioIds] são projeções: a UI de "faces" continua
/// vendo duas listas, mas a ordem real (com partitura e áudio intercalados) e o
/// tipo de cada entrada vivem em [entries].
class SavedPlaylist {
  /// Construtor canônico: recebe a ordem única já tipada.
  SavedPlaylist({
    required this.playlistId,
    required this.nome,
    required this.createdAt,
    required List<PlaylistEntry> entries,
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
    this.ownerSub,
  }) : updatedAt = updatedAt ?? createdAt,
       entries = List<PlaylistEntry>.unmodifiable(entries);

  /// Construtor de compatibilidade: monta [entries] a partir das listas
  /// legadas (Isar v1, wire v1, share URL v1).
  ///
  /// - [items] tem precedência: cada id é classificado pela extensão, salvo os
  ///   que [audioIds] declara áudio (veredito de quem gravou, A8).
  /// - Sem [items]: `[...pdfIds, ...audioIds]`, com [pdfIds] classificados pela
  ///   extensão (nunca `audio`) e [audioIds] sempre [MaterialKind.audio].
  SavedPlaylist.fromLegacyLists({
    required String playlistId,
    required String nome,
    required DateTime createdAt,
    List<String>? items,
    List<String> pdfIds = const [],
    List<String> audioIds = const [],
    bool salva = true,
    DateTime? savedAt,
    DateTime? favoritedAt,
    bool favorita = false,
    DateTime? updatedAt,
    int version = 1,
    PlaylistSyncStatus syncStatus = PlaylistSyncStatus.synced,
    DateTime? deletedAt,
    bool isPublished = false,
    PlaylistReach? publicationReach,
    PlaylistCategory? publicationCategory,
    DateTime? publishedAt,
    String? ownerSub,
  }) : this(
         playlistId: playlistId,
         nome: nome,
         createdAt: createdAt,
         entries: entriesFromLegacyLists(
           items: items,
           pdfIds: pdfIds,
           audioIds: audioIds,
         ),
         salva: salva,
         savedAt: savedAt,
         favoritedAt: favoritedAt,
         favorita: favorita,
         updatedAt: updatedAt,
         version: version,
         syncStatus: syncStatus,
         deletedAt: deletedAt,
         isPublished: isPublished,
         publicationReach: publicationReach,
         publicationCategory: publicationCategory,
         publishedAt: publishedAt,
         ownerSub: ownerSub,
       );

  /// Monta a ordem única tipada a partir das listas legadas — ver
  /// [SavedPlaylist.fromLegacyLists].
  static List<PlaylistEntry> entriesFromLegacyLists({
    List<String>? items,
    List<String> pdfIds = const [],
    List<String> audioIds = const [],
  }) {
    if (items == null) {
      return <PlaylistEntry>[
        ...pdfIds.map(PlaylistEntry.classified),
        ...audioIds.map(PlaylistEntry.audio),
      ];
    }
    final declaredAudio = audioIds.toSet();
    return <PlaylistEntry>[
      for (final id in items)
        declaredAudio.contains(id)
            ? PlaylistEntry.audio(id)
            : PlaylistEntry.classified(id),
    ];
  }

  /// Identificador estável (UUID-like, compatível com PWA).
  final String playlistId;

  /// Nome exibido na lista — default `lista dd/MM/yyyy HH:mm:ss` na criação.
  final String nome;

  /// Ordem única tipada de materiais — fonte da verdade.
  final List<PlaylistEntry> entries;

  /// Ids de [entries], na ordem.
  late final List<String> items = entries
      .map((e) => e.id)
      .toList(growable: false);

  /// Projeção da face de partituras: tudo que **não** é áudio.
  ///
  /// Inclui [MaterialKind.gesture] (gesto é material de leitura),
  /// [MaterialKind.youtube] e [MaterialKind.unknown] (ids legados). Assim
  /// nenhuma família some das duas faces (A7).
  late final List<String> pdfIds = entries
      .where((e) => !e.isAudio)
      .map((e) => e.id)
      .toList(growable: false);

  /// Projeção da face de áudio: [MaterialKind.audio].
  late final List<String> audioIds = entries
      .where((e) => e.isAudio)
      .map((e) => e.id)
      .toList(growable: false);

  /// Substitui em [current] o subconjunto que [belongs] seleciona por [next],
  /// **preservando a posição relativa dos demais materiais**.
  ///
  /// Regra (fixada por teste): percorre [current]; cada slot que [belongs]
  /// aceita recebe, em ordem, a próxima entrada de [next]. Slots que sobram
  /// (porque [next] é menor) desaparecem; entradas de [next] que sobram são
  /// inseridas logo depois do último slot preenchido — ou no fim, se [current]
  /// não tinha nenhum slot desse tipo. Materiais fora do subconjunto nunca
  /// mudam de ordem entre si e continuam ancorados aos vizinhos que
  /// sobreviveram.
  static List<PlaylistEntry> replaceSubset(
    List<PlaylistEntry> current,
    List<PlaylistEntry> next,
    bool Function(PlaylistEntry entry) belongs,
  ) {
    final result = <PlaylistEntry>[];
    var cursor = 0;
    var afterLastSlot = -1;
    for (final entry in current) {
      if (belongs(entry)) {
        if (cursor < next.length) {
          result.add(next[cursor++]);
          afterLastSlot = result.length;
        }
        continue;
      }
      result.add(entry);
    }
    if (cursor < next.length) {
      result.insertAll(
        afterLastSlot >= 0 ? afterLastSlot : result.length,
        next.sublist(cursor),
      );
    }
    return result;
  }

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

  /// `sub` Google do dono; `null` = lista criada sem conta (spec A.5).
  ///
  /// A sync só envia listas sem dono ou do dono corrente, e a troca de conta
  /// purga localmente as `synced` da conta anterior.
  final String? ownerSub;

  /// Cópia com campos trocados.
  ///
  /// [entries] tem precedência e substitui tudo. Sem ele, [pdfIds]/[audioIds]
  /// substituem apenas o seu subconjunto de [entries] via [replaceSubset] — é
  /// isso que faz `update(pdfIds: …)` vindo do carousel preservar a posição dos
  /// áudios.
  SavedPlaylist copyWith({
    String? playlistId,
    String? nome,
    List<PlaylistEntry>? entries,
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
    String? ownerSub,
  }) {
    return SavedPlaylist(
      playlistId: playlistId ?? this.playlistId,
      nome: nome ?? this.nome,
      entries: entries ?? nextEntriesWith(pdfIds: pdfIds, audioIds: audioIds),
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
      ownerSub: ownerSub ?? this.ownerSub,
    );
  }

  /// Nova ordem única aplicando as substituições parciais de face.
  ///
  /// `null` em [pdfIds]/[audioIds] significa "não mexe nessa face".
  ///
  /// As duas faces **não** são simétricas, e é de propósito:
  ///
  /// - `audioIds:` **declara** áudio (A8). Um id listado ali vira
  ///   [MaterialKind.audio] mesmo que a extensão diga outra coisa e mesmo que
  ///   já estivesse na lista com outro `kind` — é o veredito de quem gravou.
  ///   A entrada antiga é retipada no lugar ([_retaggedAsAudio]), então o id
  ///   muda de face sem aparecer duas vezes na ordem única.
  /// - `pdfIds:` **não declara nada**. É a lista que o carousel devolve, e o
  ///   carousel não sabe o tipo de nada: reclassificar por ela rebaixaria um
  ///   `youtube`/`chord` declarado para o que a extensão adivinhar, e
  ///   rebaixaria um áudio declarado para a face de partituras. Por isso
  ///   [_pdfFaceReplacement] preserva o `kind` que a entrada já tem, só
  ///   classifica pela extensão os ids que ainda não estão na lista, e
  ///   **ignora** os ids que já são áudio (a entrada de áudio fica onde está,
  ///   fora do subconjunto que [replaceSubset] substitui).
  List<PlaylistEntry> nextEntriesWith({
    List<String>? pdfIds,
    List<String>? audioIds,
  }) {
    var next = entries;
    if (pdfIds != null) {
      next = replaceSubset(
        next,
        _pdfFaceReplacement(next, pdfIds),
        (e) => !e.isAudio,
      );
    }
    if (audioIds != null) {
      next = replaceSubset(
        _retaggedAsAudio(next, audioIds.toSet()),
        audioIds.map(PlaylistEntry.audio).toList(growable: false),
        (e) => e.isAudio,
      );
    }
    return next;
  }

  /// Entradas que vão ocupar os slots da face de partituras.
  ///
  /// Id já presente e não-áudio → a **própria entrada** (preserva o `kind`);
  /// id já presente e áudio → **descartado** (nunca rebaixa uma face de áudio);
  /// id novo → [PlaylistEntry.classified].
  static List<PlaylistEntry> _pdfFaceReplacement(
    List<PlaylistEntry> current,
    List<String> pdfIds,
  ) {
    final byId = <String, PlaylistEntry>{
      for (final entry in current) entry.id: entry,
    };
    final next = <PlaylistEntry>[];
    for (final id in pdfIds) {
      final existing = byId[id];
      if (existing == null) {
        next.add(PlaylistEntry.classified(id));
      } else if (!existing.isAudio) {
        next.add(existing);
      }
    }
    return next;
  }

  static List<PlaylistEntry> _retaggedAsAudio(
    List<PlaylistEntry> current,
    Set<String> declared,
  ) {
    if (declared.isEmpty) return current;
    return <PlaylistEntry>[
      for (final entry in current)
        declared.contains(entry.id) ? PlaylistEntry.audio(entry.id) : entry,
    ];
  }
}

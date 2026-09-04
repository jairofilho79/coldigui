import 'package:flutter/foundation.dart';

import '../../../../core/database/collections/playlist_publication.dart';
import '../../../../core/database/collections/playlist_sync_status.dart';
import '../../../../core/utils/material_id_kind.dart';

export '../../../../core/database/collections/playlist_publication.dart';
export '../../../../core/database/collections/playlist_sync_status.dart';

/// Playlist do usuário (UC-06, Fase 4.2+ / UC-15 sync).
///
/// Espelha o modelo persistido sem expor Isar.
///
/// [items] é a **ordem única** de materiais (D2). [pdfIds] e [audioIds] são
/// projeções derivadas por [materialIdKindOf] — a UI de "faces" continua vendo
/// duas listas, mas a ordem real (com PDF e áudio intercalados) vive em
/// [items].
class SavedPlaylist {
  /// Construtor de compatibilidade: aceita as duas listas antigas e monta
  /// [items] concatenando (`[...pdfIds, ...audioIds]`) quando [items] é
  /// omitido. Passar [items] tem precedência sobre [pdfIds]/[audioIds].
  SavedPlaylist({
    required this.playlistId,
    required this.nome,
    required this.createdAt,
    List<String>? items,
    List<String> pdfIds = const [],
    List<String> audioIds = const [],
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
  }) : updatedAt = updatedAt ?? createdAt,
       items = List<String>.unmodifiable(
         items ?? <String>[...pdfIds, ...warnIfNotAudio(audioIds)],
       );

  /// Identificador estável (UUID-like, compatível com PWA).
  final String playlistId;

  /// Nome exibido na lista — default `lista dd/MM/yyyy HH:mm:ss` na criação.
  final String nome;

  /// Ordem única de materiais (PDF, cifra, áudio…) — fonte da verdade.
  final List<String> items;

  /// Projeção PDF/cifra de [items], na ordem em que aparecem.
  ///
  /// Inclui [MaterialKind.unknown], que é o balde de tudo que não decodifica
  /// como path: ids legados **e ids de YouTube** (que vêm do Worker e não são
  /// path nenhum). Eles ficam na face de partituras em vez de sumir da lista.
  /// A única família invisível às duas faces é [MaterialKind.gesture] — e hoje
  /// nenhum caminho do app coloca id de gesto numa playlist.
  late final List<String> pdfIds = items
      .where((id) => isPdfFaceItem(id))
      .toList(growable: false);

  /// Projeção de áudio de [items], na ordem em que aparecem.
  late final List<String> audioIds = items
      .where((id) => isAudioFaceItem(id))
      .toList(growable: false);

  /// `true` se [id] pertence à face de partituras/cifras.
  static bool isPdfFaceItem(String id) {
    final kind = materialIdKindOf(id);
    return kind == MaterialKind.pdf ||
        kind == MaterialKind.chord ||
        kind == MaterialKind.unknown;
  }

  /// `true` se [id] pertence à face de áudio.
  static bool isAudioFaceItem(String id) =>
      materialIdKindOf(id) == MaterialKind.audio;

  /// Devolve [audioIds] avisando no console sobre ids que **não** classificam
  /// como [MaterialKind.audio].
  ///
  /// A fonte da verdade do tipo é o `type` do Worker, mas a projeção de faces
  /// usa a extensão do `r2_key` ([kAudioMaterialExtensions]). Quando as duas
  /// discordam, a faixa migraria silenciosamente para a face de partituras —
  /// este aviso faz o descompasso aparecer em vez de virar bug de UI.
  static List<String> warnIfNotAudio(List<String> audioIds) {
    for (final id in audioIds) {
      if (isAudioFaceItem(id)) continue;
      debugPrint(
        '[playlists] id de áudio sem extensão reconhecida (vai para a face de '
        'partituras): $id — ver kAudioMaterialExtensions',
      );
    }
    return audioIds;
  }

  /// Substitui em [current] o subconjunto que [belongs] seleciona por [next],
  /// **preservando a posição relativa dos demais materiais**.
  ///
  /// Regra (fixada por teste): percorre [current]; cada slot que [belongs]
  /// aceita recebe, em ordem, o próximo id de [next]. Slots que sobram (porque
  /// [next] é menor) desaparecem; ids de [next] que sobram são inseridos logo
  /// depois do último slot preenchido — ou no fim, se [current] não tinha
  /// nenhum slot desse tipo. Materiais fora do subconjunto nunca mudam de
  /// ordem entre si e continuam ancorados aos vizinhos que sobreviveram.
  static List<String> replaceSubset(
    List<String> current,
    List<String> next,
    bool Function(String id) belongs,
  ) {
    assert(
      next.every(belongs),
      'replaceSubset: `next` só pode conter ids da face que `belongs` aceita; '
      'recebido: ${next.where((id) => !belongs(id)).toList()}',
    );
    final result = <String>[];
    var cursor = 0;
    var afterLastSlot = -1;
    for (final id in current) {
      if (belongs(id)) {
        if (cursor < next.length) {
          result.add(next[cursor++]);
          afterLastSlot = result.length;
        }
        continue;
      }
      result.add(id);
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

  /// Cópia com campos trocados.
  ///
  /// [items] tem precedência. Sem ele, [pdfIds]/[audioIds] substituem apenas o
  /// seu subconjunto de [items] via [replaceSubset] — é isso que faz
  /// `update(pdfIds: …)` vindo do carousel preservar a posição dos áudios.
  SavedPlaylist copyWith({
    String? playlistId,
    String? nome,
    List<String>? items,
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
      items: items ?? nextItemsWith(pdfIds: pdfIds, audioIds: audioIds),
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

  /// Nova ordem única aplicando as substituições parciais de face.
  ///
  /// `null` em [pdfIds]/[audioIds] significa "não mexe nessa face".
  ///
  /// A face de um slot é "o que [materialIdKindOf] diz **ou** o que o chamador
  /// declarou": um id passado em [audioIds] conta como slot de áudio mesmo que
  /// a extensão não o classifique assim. Sem isso, um áudio com container fora
  /// de [kAudioMaterialExtensions] seria descartado por [replaceSubset] em vez
  /// de apenas cair na face errada — perda de dado. [warnIfNotAudio] avisa
  /// quando isso acontece.
  List<String> nextItemsWith({List<String>? pdfIds, List<String>? audioIds}) {
    var next = items;
    if (pdfIds != null) {
      final declared = pdfIds.toSet();
      next = replaceSubset(
        next,
        pdfIds,
        (id) => isPdfFaceItem(id) || declared.contains(id),
      );
    }
    if (audioIds != null) {
      warnIfNotAudio(audioIds);
      final declared = audioIds.toSet();
      next = replaceSubset(
        next,
        audioIds,
        (id) => isAudioFaceItem(id) || declared.contains(id),
      );
    }
    return next;
  }
}

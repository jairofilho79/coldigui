import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/coldigom/domain/entities/coldigom_praise_metadata.dart';

import '../../../chords/domain/entities/chord_material.dart';
import '../../../gestures/domain/entities/gesture_material.dart';
import '../constants/louvor_category_order.dart';
import '../utils/louvor_classification.dart';
import 'catalog_material.dart';
import 'louvor.dart';
import 'youtube_material.dart';

/// Folha da sublista — exatamente um PDF/material.
class LouvorMaterialEntry {
  const LouvorMaterialEntry({
    required this.categoria,
    required this.pdfId,
    required this.louvor,
  });

  final String categoria;
  final String pdfId;
  final Louvor louvor;
}

/// Seção da sublista — materiais de uma [classificacao] do manifest.
class LouvorMaterialSection {
  const LouvorMaterialSection({
    required this.classificacao,
    required this.displayLabel,
    required this.materials,
  });

  final String classificacao;
  final String displayLabel;
  final List<LouvorMaterialEntry> materials;
}

/// Louvor lógico — um card na Home/Biblioteca (vários PDFs/áudios possíveis).
class LouvorGroup {
  /// [extras] é a lista canônica dos materiais que não são PDF de seção.
  ///
  /// Os parâmetros [chordMaterials]/[gestureMaterials]/[audioTracks]/
  /// [youtubeMaterials] continuam aceitos por compatibilidade: quando [extras]
  /// não vem, eles são convertidos em [CatalogMaterial] na ordem canônica
  /// (cifras, gestos, áudios, YouTube) — a mesma que [materials] sempre expôs.
  /// Passar [extras] tem precedência: ele já é o vocabulário único e define a
  /// ordem.
  LouvorGroup({
    required this.groupId,
    required this.numero,
    required this.nome,
    required this.sections,
    List<CatalogMaterial>? extras,
    List<AudioTrack> audioTracks = const [],
    List<YoutubeMaterial> youtubeMaterials = const [],
    List<ChordMaterial> chordMaterials = const [],
    List<GestureMaterial> gestureMaterials = const [],
    LyricsMaterial? lyrics,
    this.coldigomMeta,
  }) : extras =
           extras ??
           [
             for (final chord in chordMaterials) ChordMaterialRef(chord),
             for (final gesture in gestureMaterials)
               GestureMaterialRef(gesture),
             for (final track in audioTracks) AudioMaterial(track),
             for (final item in youtubeMaterials) YoutubeMaterialRef(item),
             // A letra fecha a lista: é o material «sempre presente» e o
             // menos urgente no sheet.
             ?lyrics,
           ],
       numeroSortKey = _parseNumeroSortKey(numero);

  final String groupId;
  final String numero;
  final String nome;
  final List<LouvorMaterialSection> sections;

  /// Materiais do grupo que não são PDF de seção — cifras, áudios e YouTube.
  ///
  /// Guardado como [CatalogMaterial] para que o grupo tenha um vocabulário só;
  /// os getters por tipo abaixo continuam servindo os consumidores antigos.
  final List<CatalogMaterial> extras;

  /// Metadados Coldigom (tom, autor, ritmo…) — null enquanto o grupo não os tem.
  final ColdigomPraiseMetadata? coldigomMeta;

  /// Faixas Coldigom associadas ao mesmo [groupId] — derivado de [extras].
  List<AudioTrack> get audioTracks => [
    for (final material in extras)
      if (material is AudioMaterial) material.track,
  ];

  /// Links YouTube Coldigom associados ao mesmo [groupId] — de [extras].
  List<YoutubeMaterial> get youtubeMaterials => [
    for (final item in extras)
      if (item is YoutubeMaterialRef) item.material,
  ];

  /// Cifras ChordPro Coldigom associadas ao mesmo [groupId] — de [extras].
  List<ChordMaterial> get chordMaterials => [
    for (final material in extras)
      if (material is ChordMaterialRef) material.chord,
  ];

  /// Documentos de gestos Coldigom associados ao mesmo [groupId] — de [extras].
  List<GestureMaterial> get gestureMaterials => [
    for (final material in extras)
      if (material is GestureMaterialRef) material.gesture,
  ];

  /// Letra Coldigom do grupo — de [extras]; `null` sem letra.
  LyricsMaterial? get lyrics {
    for (final material in extras) {
      if (material is LyricsMaterial) return material;
    }
    return null;
  }

  /// Chave numérica para ordenação — parse feito uma vez no construtor.
  final int numeroSortKey;

  /// Cópia com [coldigomMeta] (ex.: attach a partir do cache).
  LouvorGroup withColdigomMeta(ColdigomPraiseMetadata? meta) {
    return LouvorGroup(
      groupId: groupId,
      numero: numero,
      nome: nome,
      sections: sections,
      extras: extras,
      coldigomMeta: meta,
    );
  }

  /// PDFs de todas as seções, ordenados por categoria (sem labels de ritmo).
  List<LouvorMaterialEntry> get flatPdfMaterials {
    final entries = [for (final section in sections) ...section.materials];
    entries.sort(
      (a, b) => LouvorCategoryOrder.compare(a.categoria, b.categoria),
    );
    return entries;
  }

  /// Todos os materiais do grupo num vocabulário único, na ordem de exibição:
  /// PDFs por seção seguidos de [extras] (cifras, áudios, YouTube).
  ///
  /// Os PDFs saem na ordem das [sections] (classificação, depois categoria
  /// dentro da seção) — diferente de [flatPdfMaterials], que reordena todas as
  /// seções juntas por [LouvorCategoryOrder].
  ///
  /// É o insumo do `openMaterialProvider`.
  List<CatalogMaterial> get materials => [
    for (final section in sections)
      for (final entry in section.materials) PdfMaterial(entry.louvor),
    ...extras,
  ];

  /// Total de PDFs no grupo.
  int get totalPdfs =>
      sections.fold(0, (sum, section) => sum + section.materials.length);

  /// Total de entradas (PDFs + áudios + YouTube + cifras) no grupo.
  int get totalMaterials => totalPdfs + extras.length;

  /// Classificações distintas no grupo (uma seção por arranjo PDF).
  int get totalArrangements => sections.length;

  /// Material PDF preferido para atalhos (+ no card): Partitura ou primeiro.
  Louvor? get primaryLouvor {
    for (final section in sections) {
      for (final material in section.materials) {
        if (material.categoria == 'Partitura') return material.louvor;
      }
    }
    for (final section in sections) {
      if (section.materials.isNotEmpty) return section.materials.first.louvor;
    }
    return null;
  }

  /// Agrupa [louvores] e opcionalmente áudios/YouTube pelo mesmo groupId.
  ///
  /// [sortByNumber] `true` (padrão) — browse/biblioteca por número.
  /// `false` — preserva ordem de primeira aparição (busca ranqueada).
  static List<LouvorGroup> fromLouvores(
    List<Louvor> louvores, {
    List<AudioTrack> audioTracks = const [],
    List<YoutubeMaterial> youtubeMaterials = const [],
    List<ChordMaterial> chordMaterials = const [],
    List<GestureMaterial> gestureMaterials = const [],
    Map<String, LyricsMaterial>? lyricsByGroupId,
    Map<String, ColdigomPraiseMetadata>? coldigomMetaByGroupId,
    bool sortByNumber = true,
  }) {
    final byGroup = <String, List<Louvor>>{};
    for (final louvor in louvores) {
      final gid = louvor.effectiveGroupId;
      byGroup.putIfAbsent(gid, () => []).add(louvor);
    }

    final audioByGroup = <String, List<AudioTrack>>{};
    for (final track in audioTracks) {
      final gid = track.groupId.trim();
      if (gid.isEmpty) continue;
      audioByGroup.putIfAbsent(gid, () => []).add(track);
    }

    final youtubeByGroup = <String, List<YoutubeMaterial>>{};
    for (final item in youtubeMaterials) {
      final gid = item.groupId.trim();
      if (gid.isEmpty) continue;
      youtubeByGroup.putIfAbsent(gid, () => []).add(item);
    }

    final chordByGroup = <String, List<ChordMaterial>>{};
    for (final item in chordMaterials) {
      final gid = item.groupId.trim();
      if (gid.isEmpty) continue;
      chordByGroup.putIfAbsent(gid, () => []).add(item);
    }

    final gestureByGroup = <String, List<GestureMaterial>>{};
    for (final item in gestureMaterials) {
      final gid = item.groupId.trim();
      if (gid.isEmpty) continue;
      gestureByGroup.putIfAbsent(gid, () => []).add(item);
    }

    final allGroupIds = <String>{
      ...byGroup.keys,
      ...audioByGroup.keys,
      ...youtubeByGroup.keys,
      ...chordByGroup.keys,
      ...gestureByGroup.keys,
      ...?lyricsByGroupId?.keys,
    };
    final groups = allGroupIds.map((gid) {
      return _buildGroup(
        gid,
        byGroup[gid] ?? const [],
        audioByGroup[gid] ?? const [],
        youtubeByGroup[gid] ?? const [],
        chordByGroup[gid] ?? const [],
        gestureByGroup[gid] ?? const [],
        lyricsByGroupId?[gid],
        coldigomMetaByGroupId?[gid],
      );
    }).toList();

    if (sortByNumber) groups.sort(_compareGroups);
    return groups;
  }

  static LouvorGroup _buildGroup(
    String groupId,
    List<Louvor> items,
    List<AudioTrack> tracks,
    List<YoutubeMaterial> youtube,
    List<ChordMaterial> chords,
    List<GestureMaterial> gestures, [
    LyricsMaterial? lyrics,
    ColdigomPraiseMetadata? coldigomMeta,
  ]) {
    final byClass = <String, List<Louvor>>{};
    for (final item in items) {
      byClass.putIfAbsent(item.classificacao, () => []).add(item);
    }

    final classKeys = byClass.keys.toList()..sort();
    final sections = <LouvorMaterialSection>[];

    for (final classificacao in classKeys) {
      final classItems = List<Louvor>.from(byClass[classificacao]!);
      classItems.sort(
        (a, b) => LouvorCategoryOrder.compare(a.categoria, b.categoria),
      );

      sections.add(
        LouvorMaterialSection(
          classificacao: classificacao,
          displayLabel: LouvorClassification.materialSectionLabel(
            classificacao,
          ),
          materials: [
            for (final louvor in classItems)
              LouvorMaterialEntry(
                categoria: louvor.categoria,
                pdfId: louvor.pdfId,
                louvor: louvor,
              ),
          ],
        ),
      );
    }

    final String nome;
    final String numero;
    if (items.isNotEmpty) {
      nome = _canonicalNome(items);
      numero = _canonicalNumero(items);
    } else if (tracks.isNotEmpty) {
      nome = tracks.first.nome;
      numero = tracks.first.numero.trim();
    } else if (youtube.isNotEmpty) {
      nome = youtube.first.nome;
      numero = youtube.first.numero.trim();
    } else if (chords.isNotEmpty) {
      nome = chords.first.nome;
      numero = chords.first.numero.trim();
    } else if (gestures.isNotEmpty) {
      nome = gestures.first.nome;
      numero = gestures.first.numero.trim();
    } else if (lyrics != null) {
      nome = lyrics.nome;
      numero = lyrics.numero.trim();
    } else {
      nome = '';
      numero = '';
    }

    return LouvorGroup(
      groupId: groupId,
      numero: numero,
      nome: nome,
      sections: sections,
      audioTracks: List<AudioTrack>.from(tracks),
      youtubeMaterials: List<YoutubeMaterial>.from(youtube),
      chordMaterials: List<ChordMaterial>.from(chords),
      gestureMaterials: List<GestureMaterial>.from(gestures),
      lyrics: lyrics,
      coldigomMeta: coldigomMeta,
    );
  }

  static String _canonicalNome(List<Louvor> items) {
    final counts = <String, int>{};
    for (final item in items) {
      counts[item.nome] = (counts[item.nome] ?? 0) + 1;
    }
    var best = items.first.nome;
    var bestCount = 0;
    for (final entry in counts.entries) {
      if (entry.value > bestCount) {
        best = entry.key;
        bestCount = entry.value;
      }
    }
    for (final item in items) {
      if (item.categoria == 'Partitura') return item.nome;
    }
    return best;
  }

  static String _canonicalNumero(List<Louvor> items) {
    for (final item in items) {
      if (item.numero.trim().isNotEmpty) return item.numero.trim();
    }
    return '';
  }

  static int _parseNumeroSortKey(String numero) => int.tryParse(numero) ?? -1;

  static int _compareGroups(LouvorGroup a, LouvorGroup b) {
    final na = a.numeroSortKey;
    final nb = b.numeroSortKey;
    if (na != -1 && nb != -1 && na != nb) return na.compareTo(nb);
    if (na != -1 && nb == -1) return -1;
    if (na == -1 && nb != -1) return 1;
    return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
  }
}

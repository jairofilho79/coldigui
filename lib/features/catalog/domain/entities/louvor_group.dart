import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';

import '../constants/louvor_category_order.dart';
import '../utils/louvor_classification.dart';
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
  LouvorGroup({
    required this.groupId,
    required this.numero,
    required this.nome,
    required this.sections,
    this.audioTracks = const [],
    this.youtubeMaterials = const [],
  }) : numeroSortKey = _parseNumeroSortKey(numero);

  final String groupId;
  final String numero;
  final String nome;
  final List<LouvorMaterialSection> sections;

  /// Faixas Coldigom associadas ao mesmo [groupId].
  final List<AudioTrack> audioTracks;

  /// Links YouTube Coldigom associados ao mesmo [groupId].
  final List<YoutubeMaterial> youtubeMaterials;

  /// Chave numérica para ordenação — parse feito uma vez no construtor.
  final int numeroSortKey;

  /// Total de PDFs no grupo.
  int get totalPdfs =>
      sections.fold(0, (sum, section) => sum + section.materials.length);

  /// Total de entradas (PDFs + áudios + YouTube) no grupo.
  int get totalMaterials =>
      totalPdfs + audioTracks.length + youtubeMaterials.length;

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
  static List<LouvorGroup> fromLouvores(
    List<Louvor> louvores, {
    List<AudioTrack> audioTracks = const [],
    List<YoutubeMaterial> youtubeMaterials = const [],
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

    final allGroupIds = <String>{
      ...byGroup.keys,
      ...audioByGroup.keys,
      ...youtubeByGroup.keys,
    };
    final groups = allGroupIds.map((gid) {
      return _buildGroup(
        gid,
        byGroup[gid] ?? const [],
        audioByGroup[gid] ?? const [],
        youtubeByGroup[gid] ?? const [],
      );
    }).toList();

    groups.sort(_compareGroups);
    return groups;
  }

  static LouvorGroup _buildGroup(
    String groupId,
    List<Louvor> items,
    List<AudioTrack> tracks,
    List<YoutubeMaterial> youtube,
  ) {
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

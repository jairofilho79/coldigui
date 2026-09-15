import '../../../../core/constants/offline_config.dart';
import '../../../../core/database/collections/coldigom_praise_cache.dart';
import '../../../../core/utils/material_id_kind.dart';
import '../../../../core/utils/pdf_id_codec.dart';
import '../../../coldigom/data/mappers/coldigom_praise_cache_mapper.dart';

/// `type` do Worker que o download sabe persistir (O10): PDF, áudio, cifra e
/// gestos. YouTube é link, letra já está no Isar.
bool isColdigomDownloadableType(String rawType) {
  return switch (rawType.toLowerCase()) {
    'pdf' || 'mp3' || 'audio' || 'chord' || 'gestures' => true,
    _ => false,
  };
}

/// Um material Coldigom a baixar — enumerado do catálogo local (§5.2).
class ColdigomDownloadTarget {
  const ColdigomDownloadTarget({
    required this.praiseId,
    required this.praiseNumber,
    required this.praiseName,
    required this.materialId,
    required this.kindId,
    required this.rawType,
    required this.kind,
    required this.r2Key,
    this.size,
  });

  final String praiseId;
  final String praiseNumber;
  final String praiseName;
  final String materialId;
  final String kindId;

  /// `pdf`/`mp3`/`audio`/`chord`/`gestures` como o Worker manda.
  final String rawType;
  final MaterialKind kind;
  final String r2Key;

  /// Bytes reais quando o dump os trouxe (O13).
  final int? size;

  /// Id no espaço do app (`pdfId`/`audioId`/`chordId`/`gestureId`).
  String get localId => encodePdfId(r2Key);

  bool get sizeIsEstimated => size == null;

  /// [size] ou a média por tipo de [OfflineConfig.coldigomEstimatedBytesByType].
  int get estimatedBytes =>
      size ??
      OfflineConfig.coldigomEstimatedBytesByType[rawType.toLowerCase()] ??
      0;

  /// Título de progresso: «001 · Nome».
  String get title =>
      praiseNumber.isEmpty ? praiseName : '$praiseNumber · $praiseName';
}

/// Alvos dos [kindIds] a partir das linhas do catálogo, em ordem de número
/// (o utilizador vê o progresso «em ordem»).
List<ColdigomDownloadTarget> coldigomDownloadTargetsFrom(
  List<ColdigomPraiseCache> rows, {
  required Set<String> kindIds,
}) {
  if (kindIds.isEmpty) return const [];
  final targets = <ColdigomDownloadTarget>[];
  for (final row in rows) {
    for (final m in ColdigomPraiseCacheMapper.decodeMaterials(row)) {
      final kindId = m.kindId;
      final r2Key = m.r2Key;
      if (kindId == null || !kindIds.contains(kindId)) continue;
      if (!isColdigomDownloadableType(m.type)) continue;
      if (r2Key == null || r2Key.isEmpty) continue;
      targets.add(
        ColdigomDownloadTarget(
          praiseId: row.praiseId,
          praiseNumber: row.number,
          praiseName: row.name,
          materialId: m.id,
          kindId: kindId,
          rawType: m.type,
          kind: materialKindOfRawType(m.type),
          r2Key: r2Key,
          size: m.size,
        ),
      );
    }
  }
  targets.sort(_compareTargets);
  return targets;
}

int _compareTargets(ColdigomDownloadTarget a, ColdigomDownloadTarget b) {
  final na = int.tryParse(a.praiseNumber) ?? -1;
  final nb = int.tryParse(b.praiseNumber) ?? -1;
  if (na != -1 && nb != -1 && na != nb) return na.compareTo(nb);
  if (na != -1 && nb == -1) return -1;
  if (na == -1 && nb != -1) return 1;
  final byName = a.praiseName.toLowerCase().compareTo(
    b.praiseName.toLowerCase(),
  );
  if (byName != 0) return byName;
  return a.materialId.compareTo(b.materialId);
}

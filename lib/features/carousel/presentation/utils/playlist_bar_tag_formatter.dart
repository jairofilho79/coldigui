import 'package:coldigui/features/catalog/domain/utils/catalog_tag_hierarchy.dart';

/// Limites de caracteres para a tag na barra de playlist por faixa de largura:
/// - Mobile (< 600px): mín. 3 da tag + 3 da subtag
/// - Tablet Compacto (600px a 749px): 4 da tag + 4 da subtag
/// - Tablet Médio (750px a 899px): 6 da tag + 6 da subtag
/// - Desktop (>= 900px): tag completa sem corte
class PlaylistBarTagLimits {
  const PlaylistBarTagLimits({
    required this.tagChars,
    required this.subtagChars,
    required this.singleTagChars,
  });

  final int? tagChars;
  final int? subtagChars;
  final int? singleTagChars;

  static const mobile = PlaylistBarTagLimits(
    tagChars: 3,
    subtagChars: 3,
    singleTagChars: 3,
  );

  static const tabletCompact = PlaylistBarTagLimits(
    tagChars: 4,
    subtagChars: 4,
    singleTagChars: 10,
  );

  static const tabletMedium = PlaylistBarTagLimits(
    tagChars: 6,
    subtagChars: 6,
    singleTagChars: 12,
  );

  static const full = PlaylistBarTagLimits(
    tagChars: null,
    subtagChars: null,
    singleTagChars: null,
  );

  static PlaylistBarTagLimits forWidth(
    double? barWidth, {
    bool isCompact = false,
  }) {
    if (isCompact || (barWidth != null && barWidth < 600.0)) {
      return mobile;
    }
    if (barWidth == null) {
      return full;
    }
    if (barWidth < 750.0) {
      return tabletCompact;
    }
    if (barWidth < 900.0) {
      return tabletMedium;
    }
    return full;
  }
}

/// Formata a tag para exibição na barra de playlist / carrossel, abreviando
/// a tag principal e a subtag de forma limpa conforme o espaço disponível.
String formatPlaylistBarTag(
  String tag, {
  double? barWidth,
  bool isCompact = false,
}) {
  final trimmed = tag.trim();
  if (trimmed.isEmpty) return '';

  final limits = PlaylistBarTagLimits.forWidth(barWidth, isCompact: isCompact);
  if (limits.tagChars == null && limits.subtagChars == null) {
    return trimmed;
  }

  final parts = trimmed
      .split(catalogTagHierarchySeparator)
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();

  if (parts.isEmpty) return '';

  if (parts.length == 1) {
    final singleLimit = limits.singleTagChars;
    if (singleLimit == null || parts[0].length <= singleLimit) {
      return parts[0];
    }
    return parts[0].substring(0, singleLimit).trim();
  }

  // Com subtag (2 ou mais níveis)
  final tagLimit = limits.tagChars;
  final subtagLimit = limits.subtagChars;

  final formattedParts = <String>[];
  for (var i = 0; i < parts.length; i++) {
    final limit = i == 0 ? tagLimit : subtagLimit;
    final part = parts[i];
    if (limit == null || part.length <= limit) {
      formattedParts.add(part);
    } else {
      formattedParts.add(part.substring(0, limit).trim());
    }
  }

  return formattedParts.join(catalogTagHierarchySeparator);
}

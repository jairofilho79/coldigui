import 'package:flutter/material.dart';

import '../../../../core/utils/material_id_kind.dart';
import '../entities/catalog_material.dart';
import '../entities/louvor_group.dart';

/// Ícone Material por [MaterialKind] de louvor (Partitura, Cifra, Gestos…).
///
/// Mapeamento:
/// - [MaterialKind.chord] → [Icons.music_note]
/// - [MaterialKind.gesture] → [Icons.pan_tool_outlined]
/// - [MaterialKind.audio] → [audio]
/// - [MaterialKind.youtube] → [youtube]
/// - demais → [Icons.piano] (Partitura e fallback)
///
/// O manifest só traz a `categoria` como texto livre, então [kindForCategory]
/// faz a ponte heurística até a próxima onda unificar os materiais.
///
/// Consumidores: [LouvorCard], [CarouselLouvorChip], sheets de material.
abstract final class LouvorMaterialIcons {
  /// Retorna ícone Material para [kind].
  static IconData forKind(MaterialKind kind) {
    return switch (kind) {
      MaterialKind.chord => Icons.music_note,
      MaterialKind.gesture => Icons.pan_tool_outlined,
      MaterialKind.audio => audio,
      MaterialKind.youtube => youtube,
      MaterialKind.pdf || MaterialKind.unknown => Icons.piano,
    };
  }

  /// Classifica [categoria] do manifest (`Louvor.categoria`) em [MaterialKind].
  ///
  /// Heurística via `toLowerCase()` + `contains`, na ordem: áudio, cifra,
  /// gestos; o resto é PDF/partitura.
  static MaterialKind kindForCategory(String categoria) {
    final lower = categoria.toLowerCase();
    if (lower.contains('áudio') ||
        lower.contains('audio') ||
        lower.contains('mp3') ||
        lower.contains('playback')) {
      return MaterialKind.audio;
    }
    if (lower.contains('cifra')) return MaterialKind.chord;
    if (lower.contains('gest')) return MaterialKind.gesture;
    return MaterialKind.pdf;
  }

  /// Retorna ícone Material para [categoria] do manifest.
  @Deprecated('Use MaterialKind; removed next wave')
  static IconData forCategory(String categoria) =>
      forKind(kindForCategory(categoria));

  /// Ícone da entrada PDF de uma seção do sheet.
  ///
  /// PDF é o único material cujo tipo real está na `categoria` (o manifest
  /// mistura Partitura, Cifra e Gestos no mesmo `type: pdf`), por isso a
  /// heurística de [kindForCategory] continua valendo aqui.
  static IconData forEntry(LouvorMaterialEntry entry) =>
      forKind(kindForCategory(entry.categoria));

  /// Ícone de qualquer [CatalogMaterial].
  ///
  /// Cifra, áudio e YouTube já chegam com [CatalogMaterial.kind] confiável — a
  /// categoria deles é texto livre do Worker e não decide mais o ícone.
  static IconData forMaterial(CatalogMaterial material) {
    return switch (material) {
      PdfMaterial(:final louvor) => forKind(kindForCategory(louvor.categoria)),
      ChordMaterialRef() ||
      AudioMaterial() ||
      YoutubeMaterialRef() => forKind(material.kind),
    };
  }

  /// Ícone dedicado a materiais de áudio (cards / sheet).
  static const IconData audio = Icons.library_music;

  /// Ícone dedicado a materiais YouTube (sheet).
  static const IconData youtube = Icons.smart_display;
}

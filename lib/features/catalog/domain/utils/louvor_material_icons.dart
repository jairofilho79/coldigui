import 'package:flutter/material.dart';

import '../../../../core/utils/material_id_kind.dart';

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

  /// Ícone dedicado a materiais de áudio (cards / sheet).
  static const IconData audio = Icons.library_music;

  /// Ícone dedicado a materiais YouTube (sheet).
  static const IconData youtube = Icons.smart_display;
}

import 'package:flutter/material.dart';

/// Ícone Material por material/categoria de louvor (Partitura, Cifra, Gestos).
///
/// Mapeamento heurístico via `toLowerCase()` + `contains`:
/// - `cifra` → [Icons.music_note]
/// - `gest` → [Icons.pan_tool_outlined]
/// - demais → [Icons.piano] (Partitura e fallback)
///
/// Consumidores: [LouvorCard], [CarouselLouvorChip].
abstract final class LouvorMaterialIcons {
  /// Retorna ícone Material para [categoria] do manifest (`Louvor.categoria`).
  static IconData forCategory(String categoria) {
    final lower = categoria.toLowerCase();
    if (lower.contains('áudio') ||
        lower.contains('audio') ||
        lower.contains('mp3') ||
        lower.contains('playback')) {
      return audio;
    }
    if (lower.contains('cifra')) return Icons.music_note;
    if (lower.contains('gest')) return Icons.pan_tool_outlined;
    return Icons.piano;
  }

  /// Ícone dedicado a materiais de áudio (cards / sheet).
  static const IconData audio = Icons.library_music;
}

import 'package:flutter/material.dart';

/// Ícone Material por material/categoria de louvor (Partitura, Cifra, Gestos).
abstract final class LouvorMaterialIcons {
  /// Retorna ícone Material para [categoria] (Partitura, Cifra, Gestos em Gravura).
  static IconData forCategory(String categoria) {
    final lower = categoria.toLowerCase();
    if (lower.contains('cifra')) return Icons.music_note;
    if (lower.contains('gest')) return Icons.pan_tool_outlined;
    return Icons.piano;
  }
}

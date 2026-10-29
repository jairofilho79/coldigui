import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/chordpro_song.dart';
import '../../domain/usecases/transpose_chord.dart';
import '../theme/chord_reader_theme.dart';

/// Título e metadados (subtítulo, tom já transposto, ritmo, artista).
///
/// Componente reutilizável compartilhado entre o leitor final ([ChordReaderScreen])
/// e a pré-visualização de sugestões ([ExtractedChordEditor]), garantindo
/// que o que o usuário vê no preview seja idêntico ao leitor.
class ChordHeader extends StatelessWidget {
  const ChordHeader({
    required this.song,
    required this.semitones,
    required this.palette,
    super.key,
  });

  final ChordProSong song;
  final int semitones;
  final ChordReaderPalette palette;

  /// Cabeçalho com o tom já transposto — o músico lê o tom em que vai tocar,
  /// não o do arquivo.
  String get _meta {
    return [
      if (song.subtitle.isNotEmpty) song.subtitle,
      if (transposeKeyLabel(song.key, semitones).isNotEmpty)
        transposeKeyLabel(song.key, semitones),
      if (song.rhythm.isNotEmpty) song.rhythm,
      if (song.artist.isNotEmpty) song.artist,
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final meta = _meta;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (song.title.isNotEmpty)
          Text(
            song.title,
            style: AppTypography.headline.copyWith(color: palette.chord),
          ),
        if (meta.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Text(
              meta,
              style: AppTypography.label.copyWith(color: palette.comment),
            ),
          ),
      ],
    );
  }
}

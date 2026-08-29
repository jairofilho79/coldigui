import 'package:flutter/material.dart';

import '../../domain/entities/chordpro_song.dart';
import '../theme/chord_reader_theme.dart';

/// Key da barra vermelha da célula [cellIndex] na linha [lineIndex].
ValueKey<String> chordBarKey(int lineIndex, int cellIndex) =>
    ValueKey<String>('chord-bar-$lineIndex-$cellIndex');

/// Renderiza [song] com acorde sobre sílaba e barra vermelha no ponto de troca.
///
/// Cada [ChordCell] vira uma coluna — rótulo em cima, texto embaixo — e a linha
/// é um [Wrap] dessas colunas. A quebra em tela estreita acontece entre células,
/// nunca dentro de uma, então o alinhamento acorde↔sílaba sobrevive.
///
/// A barra só aparece quando [ChordCell.attached]; célula solta fica sem barra e
/// o espaçamento da fonte é preservado porque os espaços são texto de verdade.
class ChordProView extends StatelessWidget {
  const ChordProView({required this.song, required this.palette, super.key});

  final ChordProSong song;
  final ChordReaderPalette palette;

  @override
  Widget build(BuildContext context) {
    final lyricStyle = TextStyle(
      fontSize: 16,
      height: 1.35,
      color: palette.lyric,
    );
    final chordStyle = TextStyle(
      fontSize: 13,
      height: 1.1,
      fontWeight: FontWeight.w700,
      color: palette.chord,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < song.lines.length; i++)
          _buildLine(song.lines[i], i, lyricStyle, chordStyle),
      ],
    );
  }

  Widget _buildLine(
    ChordProLine line,
    int index,
    TextStyle lyricStyle,
    TextStyle chordStyle,
  ) {
    return switch (line) {
      ChordProStanzaBreak() => const SizedBox(height: 18),
      ChordProCommentLine(:final text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: lyricStyle.copyWith(
            fontStyle: FontStyle.italic,
            fontSize: 14,
            color: palette.comment,
          ),
        ),
      ),
      ChordProLyricLine(:final cells) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            for (var j = 0; j < cells.length; j++)
              _ChordCellView(
                cell: cells[j],
                barKey: chordBarKey(index, j),
                barColor: palette.bar,
                lyricStyle: lyricStyle,
                chordStyle: chordStyle,
              ),
          ],
        ),
      ),
    };
  }
}

class _ChordCellView extends StatelessWidget {
  const _ChordCellView({
    required this.cell,
    required this.barKey,
    required this.barColor,
    required this.lyricStyle,
    required this.chordStyle,
  });

  final ChordCell cell;
  final ValueKey<String> barKey;
  final Color barColor;
  final TextStyle lyricStyle;
  final TextStyle chordStyle;

  @override
  Widget build(BuildContext context) {
    final lyric = Text(cell.text, style: lyricStyle, softWrap: false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(cell.chord ?? '', style: chordStyle, softWrap: false),
        if (cell.attached)
          // IntrinsicHeight dá altura finita à Row — sem ela, o
          // CrossAxisAlignment.stretch explode com "infinite height" porque
          // o Wrap/Column ao redor não limita a altura.
          IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Barra na borda esquerda do texto: é ali que o acorde troca.
                // Com texto vazio (Sinai[C#m7]) ela cai logo após a célula anterior.
                SizedBox(
                  width: 2,
                  child: ColoredBox(key: barKey, color: barColor),
                ),
                lyric,
              ],
            ),
          )
        else
          lyric,
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../domain/entities/chordpro_song.dart';
import '../../domain/usecases/transpose_chord.dart';
import '../theme/chord_reader_theme.dart';

/// Key da barra vermelha da célula [cellIndex] na linha [lineIndex].
ValueKey<String> chordBarKey(int lineIndex, int cellIndex) =>
    ValueKey<String>('chord-bar-$lineIndex-$cellIndex');

/// Key da faixa zebrada da [lyricIndex]-ésima linha de letra.
///
/// Indexada só por linhas de letra: estrofes e comentários não entram na
/// contagem, senão a alternância "pularia" a cada quebra.
ValueKey<String> chordStripeKey(int lyricIndex) =>
    ValueKey<String>('chord-stripe-$lyricIndex');

/// Proporção entre o corpo do acorde e o da letra.
///
/// Fixa para que o rótulo não descole da sílaba quando o usuário muda o tamanho.
const _chordToLyricRatio = 13 / 16;

/// Renderiza [song] com acorde sobre sílaba e barra vermelha no ponto de troca.
///
/// Cada [ChordCell] vira uma coluna — rótulo em cima, texto embaixo — e a linha
/// é um [Wrap] dessas colunas. A quebra em tela estreita acontece entre células,
/// nunca dentro de uma, então o alinhamento acorde↔sílaba sobrevive.
///
/// A barra só aparece quando [ChordCell.attached]; célula solta fica sem barra e
/// o espaçamento da fonte é preservado porque os espaços são texto de verdade.
///
/// [semitones] transpõe os rótulos na renderização — o modelo parseado continua
/// com a grafia original, então voltar ao tom é só zerar o deslocamento.
class ChordProView extends StatelessWidget {
  const ChordProView({
    required this.song,
    required this.palette,
    this.fontSize = 16,
    this.semitones = 0,
    super.key,
  });

  final ChordProSong song;
  final ChordReaderPalette palette;

  /// Corpo da letra; o acorde acompanha por [_chordToLyricRatio].
  final double fontSize;

  /// Semitons de transposição aplicados aos rótulos.
  final int semitones;

  @override
  Widget build(BuildContext context) {
    final lyricStyle = TextStyle(
      fontSize: fontSize,
      height: 1.35,
      color: palette.lyric,
    );
    final chordStyle = TextStyle(
      fontSize: fontSize * _chordToLyricRatio,
      height: 1.1,
      fontWeight: FontWeight.w700,
      color: palette.chord,
    );

    // Grafia do resultado vem do tom de destino: Sol subindo um é Láb, não Sol#.
    final preferFlats = preferFlatsForKey(song.key, semitones);

    var lyricIndex = 0;
    final rows = <Widget>[];
    for (var i = 0; i < song.lines.length; i++) {
      final line = song.lines[i];
      rows.add(
        _buildLine(
          line: line,
          index: i,
          lyricIndex: line is ChordProLyricLine ? lyricIndex : -1,
          lyricStyle: lyricStyle,
          chordStyle: chordStyle,
          preferFlats: preferFlats,
        ),
      );
      if (line is ChordProLyricLine) lyricIndex++;
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  Widget _buildLine({
    required ChordProLine line,
    required int index,
    required int lyricIndex,
    required TextStyle lyricStyle,
    required TextStyle chordStyle,
    required bool preferFlats,
  }) {
    return switch (line) {
      ChordProStanzaBreak() => SizedBox(height: fontSize * 1.1),
      ChordProCommentLine(:final text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: lyricStyle.copyWith(
            fontStyle: FontStyle.italic,
            fontSize: fontSize * 0.875,
            color: palette.comment,
          ),
        ),
      ),
      ChordProLyricLine(:final cells) => Container(
        key: lyricIndex.isOdd ? chordStripeKey(lyricIndex) : null,
        width: double.infinity,
        color: lyricIndex.isOdd ? palette.stripe : null,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
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
                semitones: semitones,
                preferFlats: preferFlats,
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
    required this.semitones,
    required this.preferFlats,
  });

  final ChordCell cell;
  final ValueKey<String> barKey;
  final Color barColor;
  final TextStyle lyricStyle;
  final TextStyle chordStyle;
  final int semitones;
  final bool preferFlats;

  @override
  Widget build(BuildContext context) {
    // Célula sem acorde não tem rótulo para alinhar, então pode quebrar: sem
    // isso um trecho longo estoura a largura da viewport e é cortado em
    // silêncio (TextOverflow.clip, sem reticências). Com acorde, o texto tem
    // de ficar em uma linha só para não se descolar do rótulo acima.
    final lyric = Text(
      cell.text,
      style: lyricStyle,
      softWrap: cell.chord == null,
    );

    final chord = cell.chord;
    final label = chord == null
        ? ''
        : transposeChordLabel(chord, semitones, preferFlats: preferFlats);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: chordStyle, softWrap: false),
        if (cell.attached)
          // Barra na borda esquerda do texto: é ali que o acorde troca. Como
          // borda do próprio texto, ela acompanha a altura da letra sem
          // IntrinsicHeight — nada de segunda passada de layout por célula.
          // Com texto vazio (Sinai[C#m7]) ela cai logo após a célula anterior.
          Container(
            key: barKey,
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: barColor, width: 2)),
            ),
            child: lyric,
          )
        else
          lyric,
      ],
    );
  }
}

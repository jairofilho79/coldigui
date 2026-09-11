import 'package:flutter/material.dart';

import '../../domain/entities/chordpro_song.dart';
import '../../domain/usecases/transpose_chord.dart';
import '../theme/chord_reader_theme.dart';
import '../utils/split_lines_for_columns.dart';
import '../utils/transpose_label_memo.dart';

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

/// Espaço entre as duas colunas, quando [ChordProView.columns] é 2.
const _columnGap = 16.0;

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
///
/// A14: a view em si é um sliver (uma linha por item de [SliverList] em vez de
/// um [Column] fixo de `song.lines.length` widgets) para não relayoutar a
/// música inteira a cada transposição/tamanho de fonte — só as linhas visíveis
/// (re)constroem. [memo] memoiza [transposeChordLabel] por célula; sem ele, cai
/// para a chamada direta (é o caso dos testes de widget deste arquivo).
///
/// C9: com [columns] 2, `song.lines` é dividido por [splitLinesForColumns] e
/// as duas metades viram [SliverList]s lado a lado via [SliverCrossAxisGroup].
/// Este widget precisa estar dentro dos `slivers` de um [CustomScrollView]
/// (nunca dentro de um [Column]/[Scaffold.body] direto) — é assim que
/// [ChordReaderScreen] o usa.
class ChordProView extends StatelessWidget {
  const ChordProView({
    required this.song,
    required this.palette,
    this.fontSize = 16,
    this.semitones = 0,
    this.memo,
    this.columns = 1,
    super.key,
  });

  final ChordProSong song;
  final ChordReaderPalette palette;

  /// Corpo da letra; o acorde acompanha por [_chordToLyricRatio].
  final double fontSize;

  /// Semitons de transposição aplicados aos rótulos.
  final int semitones;

  /// Memo opcional de [transposeChordLabel] (A14) — mora na tela, é
  /// compartilhado entre rebuilds desta view.
  final TransposeLabelMemo? memo;

  /// 1 (padrão) ou 2 colunas lado a lado (C9, tela larga).
  final int columns;

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
    final lyricIndexes = _computeLyricIndexes(song.lines);

    Widget buildLineAt(int index) {
      return _buildLine(
        line: song.lines[index],
        index: index,
        lyricIndex: lyricIndexes[index],
        lyricStyle: lyricStyle,
        chordStyle: chordStyle,
        preferFlats: preferFlats,
      );
    }

    if (columns != 2) {
      return SliverList.builder(
        itemCount: song.lines.length,
        itemBuilder: (context, index) => buildLineAt(index),
      );
    }

    final split = splitLinesForColumns(song.lines);
    final leftCount = split.left.length;
    final rightCount = split.right.length;

    return SliverCrossAxisGroup(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.only(right: _columnGap / 2),
          sliver: SliverList.builder(
            itemCount: leftCount,
            itemBuilder: (context, index) => buildLineAt(index),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(left: _columnGap / 2),
          sliver: SliverList.builder(
            itemCount: rightCount,
            itemBuilder: (context, index) => buildLineAt(leftCount + index),
          ),
        ),
      ],
    );
  }

  /// Índice da linha entre só as linhas de letra (zebra), ou -1 fora delas.
  static List<int> _computeLyricIndexes(List<ChordProLine> lines) {
    var lyricIndex = 0;
    return [
      for (final line in lines)
        if (line is ChordProLyricLine) lyricIndex++ else -1,
    ];
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
                memo: memo,
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
    required this.memo,
  });

  final ChordCell cell;
  final ValueKey<String> barKey;
  final Color barColor;
  final TextStyle lyricStyle;
  final TextStyle chordStyle;
  final int semitones;
  final bool preferFlats;
  final TransposeLabelMemo? memo;

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
        : (memo?.label(chord, semitones, preferFlats: preferFlats) ??
              transposeChordLabel(chord, semitones, preferFlats: preferFlats));

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

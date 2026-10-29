/// Célula de renderização — um acorde opcional sobre um trecho de texto.
///
/// [text] preserva o espaço em branco literal da fonte, então
/// `"Deus é Amor [C]"` e `"Deus é Amor   [C]"` produzem células diferentes sem
/// nenhum cálculo especial no renderer.
class ChordCell {
  const ChordCell({this.chord, this.attached = false, required this.text});

  /// Rótulo do acorde (`Cm`, `G/B`), ou `null` no trecho sem acorde.
  final String? chord;

  /// `true` quando o acorde encosta em texto — desenha a barra vermelha na
  /// borda esquerda de [text]. `false` quando o acorde está solto entre espaços.
  final bool attached;

  /// Trecho de letra que vai sob o acorde, com espaços preservados.
  final String text;
}

/// Linha do documento ChordPro já estruturada.
sealed class ChordProLine {
  const ChordProLine();
}

/// Linha de letra — sequência de células.
class ChordProLyricLine extends ChordProLine {
  const ChordProLyricLine(this.cells);

  final List<ChordCell> cells;
}

/// `{comment: ...}` — recado dirigido ao músico, renderizado em itálico.
class ChordProCommentLine extends ChordProLine {
  const ChordProCommentLine(this.text);

  final String text;
}

/// Separador de estrofe (uma ou mais linhas em branco).
class ChordProStanzaBreak extends ChordProLine {
  const ChordProStanzaBreak();
}

/// Documento ChordPro estruturado.
class ChordProSong {
  const ChordProSong({
    this.title = '',
    this.subtitle = '',
    this.key = '',
    this.rhythm = '',
    this.artist = '',
    this.lines = const [],
  });

  final String title;
  final String subtitle;
  final String key;
  final String rhythm;
  final String artist;
  final List<ChordProLine> lines;

  /// `false` quando o arquivo só tem diretivas e comentários — uma lápide de
  /// pipeline. O sheet não lista e o leitor mostra o estado de indisponível,
  /// mesmo o HTTP tendo respondido 200.
  bool get hasLyrics => lines.any((line) => line is ChordProLyricLine);
}

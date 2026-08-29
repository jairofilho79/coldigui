import '../entities/chordpro_song.dart';

final _directiveRe = RegExp(r'^\{([^:}]+):\s*(.*)\}$');

/// Converte o conteúdo de um `.chord` em [ChordProSong].
///
/// Não normaliza acordes, não transpõe e não corrige OCR — só estrutura.
/// Ver §3.3 da spec para as regras.
ChordProSong parseChordPro(String source) {
  var title = '';
  var subtitle = '';
  var key = '';
  var rhythm = '';
  var artist = '';
  final lines = <ChordProLine>[];

  for (final raw in source.split('\n')) {
    final trimmed = raw.trim();

    if (trimmed.isEmpty) {
      // Brancos consecutivos colapsam num separador só.
      if (lines.isNotEmpty && lines.last is! ChordProStanzaBreak) {
        lines.add(const ChordProStanzaBreak());
      }
      continue;
    }

    // Comentário de autoria: recado de pipeline, não é conteúdo do usuário.
    if (trimmed.startsWith(';')) continue;

    final directive = _directiveRe.firstMatch(trimmed);
    if (directive != null) {
      final name = directive.group(1)!.trim().toLowerCase();
      final value = _directiveValue(directive.group(2)!);
      switch (name) {
        case 'title':
          title = value;
        case 'subtitle':
          subtitle = value;
        case 'key':
          key = value;
        case 'rhythm':
          rhythm = value;
        case 'artist':
          artist = value;
        case 'comment':
          if (value.isNotEmpty) lines.add(ChordProCommentLine(value));
        default:
          break; // meta, column e quaisquer outras: ignoradas em silêncio.
      }
      continue;
    }

    lines.add(ChordProLyricLine(parseChordProLine(raw)));
  }

  // Um separador no fim não representa estrofe nenhuma.
  while (lines.isNotEmpty && lines.last is ChordProStanzaBreak) {
    lines.removeLast();
  }

  return ChordProSong(
    title: title,
    subtitle: subtitle,
    key: key,
    rhythm: rhythm,
    artist: artist,
    lines: lines,
  );
}

/// Quebra uma linha de letra em células.
///
/// Público para teste direto; [parseChordPro] é o ponto de entrada normal.
List<ChordCell> parseChordProLine(String line) {
  final cells = <ChordCell>[];
  final buffer = StringBuffer();
  String? pendingChord;
  var pendingAttached = false;

  void flush() {
    cells.add(
      ChordCell(
        chord: pendingChord,
        attached: pendingAttached,
        text: buffer.toString(),
      ),
    );
    buffer.clear();
  }

  var i = 0;
  while (i < line.length) {
    final char = line[i];

    // Colchete escapado: texto literal.
    if (char == r'\' &&
        i + 1 < line.length &&
        (line[i + 1] == '[' || line[i + 1] == ']')) {
      buffer.write(line[i + 1]);
      i += 2;
      continue;
    }

    if (char == '[') {
      final close = line.indexOf(']', i + 1);
      final label = close == -1 ? '' : line.substring(i + 1, close);

      // Sem fechamento ou rótulo vazio: texto literal.
      if (close == -1 || label.isEmpty) {
        buffer.write(char);
        i += 1;
        continue;
      }

      flush();

      // Adjacência lida da linha original, não do buffer já desescapado.
      final before = i > 0 ? line[i - 1] : null;
      final after = close + 1 < line.length ? line[close + 1] : null;
      final attachLeft = before != null && before.trim().isNotEmpty;
      final attachRight = after != null && after.trim().isNotEmpty;

      pendingChord = label;
      pendingAttached = attachLeft || attachRight;
      i = close + 1;
      continue;
    }

    buffer.write(char);
    i += 1;
  }

  flush();

  // Célula vazia antes do primeiro acorde não vira nada renderizável.
  if (cells.length > 1 &&
      cells.first.chord == null &&
      cells.first.text.isEmpty) {
    cells.removeAt(0);
  }

  return cells;
}

/// Valor de diretiva; `''` e `'?'` contam como ausente.
String _directiveValue(String raw) {
  final value = raw.trim();
  return value == '?' ? '' : value;
}

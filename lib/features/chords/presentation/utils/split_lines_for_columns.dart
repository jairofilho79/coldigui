import '../../domain/entities/chordpro_song.dart';

/// Divide [lines] em duas colunas para a cifra em tela larga (C9).
///
/// Com menos de [minLines] devolve tudo em `left` e `right` vazio — poucas
/// linhas não justificam duas colunas. Do contrário, corta no
/// [ChordProStanzaBreak] mais próximo do meio (`length ~/ 2`), para não partir
/// uma estrofe ao meio; sem nenhuma quebra de estrofe no documento, corta
/// exatamente na metade.
({List<ChordProLine> left, List<ChordProLine> right}) splitLinesForColumns(
  List<ChordProLine> lines, {
  int minLines = 24,
}) {
  if (lines.length < minLines) {
    return (left: lines, right: const <ChordProLine>[]);
  }

  final middle = lines.length ~/ 2;
  var cutIndex = middle;
  var bestDistance = lines.length;

  for (var i = 0; i < lines.length; i++) {
    if (lines[i] is! ChordProStanzaBreak) continue;
    final distance = (i - middle).abs();
    if (distance < bestDistance) {
      bestDistance = distance;
      cutIndex = i;
    }
  }

  return (left: lines.sublist(0, cutIndex), right: lines.sublist(cutIndex));
}

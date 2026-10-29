import '../entities/flat_gesture_card.dart';
import '../entities/gesture_document.dart';

/// Lista linear dos cartões de gesto de [document], em ordem de documento.
///
/// Repetições **não** são expandidas (um `repeat 2` com 4 gestos rende 4
/// cartões, não 8): o modo foco mostra o chip `2x` e o regente repete. Isso
/// mantém o índice estável entre a página e o foco.
List<FlatGestureCard> flattenGestureCards(GestureDocument document) {
  final out = <FlatGestureCard>[];
  _walk(document.items, const [], out);
  return out;
}

void _walk(
  List<GestureItem> items,
  List<BlockContext> contexts,
  List<FlatGestureCard> out,
) {
  for (final item in items) {
    switch (item) {
      case GestureCard():
        out.add(
          FlatGestureCard(index: out.length, card: item, contexts: contexts),
        );
      case RepeatBlock(:final count, :final children):
        _walk(children, [...contexts, RepeatContext(count)], out);
      case ChorusBlock(:final children):
        _walk(children, [...contexts, const ChorusContext()], out);
      case LinkBlock(:final children):
        _walk(children, [...contexts, const LinkContext()], out);
      case FinalBlock(:final children):
        _walk(children, [...contexts, const FinalContext()], out);
      case InstructionCard() || TextLine() || SectionLabel():
        break;
    }
  }
}

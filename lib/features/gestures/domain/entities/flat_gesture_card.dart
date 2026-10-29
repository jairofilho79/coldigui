import 'gesture_document.dart';

/// Bloco que envolve um cartão — vira chip de contexto no modo foco.
sealed class BlockContext {
  const BlockContext();
}

final class RepeatContext extends BlockContext {
  const RepeatContext(this.count);

  final int count;
}

final class ChorusContext extends BlockContext {
  const ChorusContext();
}

final class FinalContext extends BlockContext {
  const FinalContext();
}

final class LinkContext extends BlockContext {
  const LinkContext();
}

/// Um cartão de gesto na ordem linear do documento.
///
/// [index] é a posição na lista achatada — o mesmo número que a página usa
/// para rolar até o cartão e que o modo foco usa como página do `PageView`.
/// [contexts] vai do bloco mais externo ao mais interno.
class FlatGestureCard {
  const FlatGestureCard({
    required this.index,
    required this.card,
    required this.contexts,
  });

  final int index;
  final GestureCard card;
  final List<BlockContext> contexts;
}

/// Documento de gestos de um louvor (`coldigom.gestures/1`), já parseado.
///
/// A ordem de [items] é a ordem de execução. Blocos aninham livremente
/// (`repeat` dentro de `coro`, `link` dentro de `repeat`…); profundidade
/// prática ≤ 3.
class GestureDocument {
  const GestureDocument({
    required this.schemaMajor,
    required this.title,
    required this.dictionaryVersion,
    required this.items,
  });

  /// Major do `schema` (`coldigom.gestures/1` → 1). Só serve para o aviso de
  /// "formato mais novo": o parser renderiza o que conseguir mesmo assim.
  final int schemaMajor;

  /// Título como no PDF, ex.: `182 - QUERO VIVER PRA SEMPRE COM JESUS`.
  final String title;

  /// Versão do dicionário usada ao salvar — só diagnóstico.
  final int dictionaryVersion;

  final List<GestureItem> items;

  /// `true` quando o documento veio de um app mais novo que este.
  bool get isNewerSchema => schemaMajor > 1;

  /// `true` quando há pelo menos um cartão de gesto em qualquer profundidade.
  bool get hasGestures => items.any(_containsGesture);

  static bool _containsGesture(GestureItem item) => switch (item) {
    GestureCard() => true,
    RepeatBlock(:final children) ||
    ChorusBlock(:final children) ||
    LinkBlock(:final children) ||
    FinalBlock(:final children) => children.any(_containsGesture),
    InstructionCard() || TextLine() => false,
  };
}

/// Um item do documento.
///
/// `sealed` pela mesma razão de `CatalogMaterial`: um tipo novo quebra a
/// compilação em cada `switch` da renderização em vez de sumir da tela.
sealed class GestureItem {
  const GestureItem();
}

/// Uma linha de letra: o gatilho (vermelho) e a leitura (preto).
class LyricLine {
  const LyricLine({required this.trigger, required this.text});

  /// Palavra(s) em que o gesto começa; vazio em linha de continuação.
  final String trigger;

  /// O que se canta enquanto o gesto dura.
  final String text;
}

/// Cartão de gesto: figura do dicionário + 1 a 3 linhas de letra.
final class GestureCard extends GestureItem {
  const GestureCard({required this.gestureId, required this.lyrics});

  /// Id do dicionário (12 hex). Pode chegar inválido: a tela mostra placeholder.
  final String gestureId;

  final List<LyricLine> lyrics;
}

/// `Nx` — filhos repetidos [count] vezes.
final class RepeatBlock extends GestureItem {
  const RepeatBlock({required this.count, required this.children});

  /// Sempre ≥ 2 (o parser normaliza).
  final int count;

  final List<GestureItem> children;
}

/// `CORO`.
final class ChorusBlock extends GestureItem {
  const ChorusBlock({required this.children});

  final List<GestureItem> children;
}

/// Ligação: 2 ou 3 gestos em sequência contínua.
final class LinkBlock extends GestureItem {
  const LinkBlock({required this.children});

  final List<GestureItem> children;
}

/// `FINAL`: divisor + filhos.
final class FinalBlock extends GestureItem {
  const FinalBlock({required this.children});

  final List<GestureItem> children;
}

/// Instruções de condução — o rótulo é l10n, ver `InstructionCardView`.
enum InstructionKind { instruments, repeatPraise, backToChorus, backToChorusAndFinish }

/// Cartão de instrução de largura total.
final class InstructionCard extends GestureItem {
  const InstructionCard(this.kind);

  final InstructionKind kind;
}

/// Linha livre (cinza, itálico). Também é o destino de itens desconhecidos.
final class TextLine extends GestureItem {
  const TextLine(this.text);

  final String text;
}

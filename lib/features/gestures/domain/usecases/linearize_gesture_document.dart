import '../entities/gesture_document.dart';

/// Leitura linear: expande as marcações de salto do documento para que a
/// regente só precise descer a página.
///
/// - `Nx` → filhos N vezes, com [SectionLabel.pass] antes de cada passagem a
///   partir da 2ª.
/// - `CORO` → [SectionLabel.chorus] + filhos; vira o "último coro visto".
/// - «Voltar ao coro» (e «… e finalizar») → rótulo + cartões do último coro;
///   sem coro anterior, a instrução fica como está.
/// - «Repetir o louvor» → rótulo «2ª vez» + cópia de tudo que a **raiz** já
///   emitiu até ali; sem nada antes, a instrução fica.
/// - `link` e `final` continuam blocos, com os filhos linearizados.
///
/// Puro e idempotente: o documento de saída não tem `RepeatBlock` nem
/// `ChorusBlock`, e linearizá-lo de novo devolve a mesma estrutura.
GestureDocument linearizeGestureDocument(GestureDocument document) {
  final root = <GestureItem>[];
  final state = _LinearizeState(root);
  _linearize(document.items, root, state);
  return GestureDocument(
    schemaMajor: document.schemaMajor,
    title: document.title,
    dictionaryVersion: document.dictionaryVersion,
    items: root,
  );
}

class _LinearizeState {
  _LinearizeState(this.root);

  /// Saída da raiz — «repetir o louvor» copia daqui, em qualquer profundidade.
  final List<GestureItem> root;

  /// Filhos já linearizados do último `CORO` visto, em qualquer profundidade.
  List<GestureItem>? lastChorus;
}

void _linearize(
  List<GestureItem> items,
  List<GestureItem> out,
  _LinearizeState state,
) {
  for (final item in items) {
    switch (item) {
      case GestureCard() || TextLine() || SectionLabel():
        out.add(item);
      case InstructionCard(:final kind):
        _instruction(kind, item, out, state);
      case RepeatBlock(:final count, :final children):
        final pass = <GestureItem>[];
        _linearize(children, pass, state);
        for (var k = 1; k <= count; k++) {
          if (k >= 2) out.add(SectionLabel.pass(k));
          out.addAll(pass);
        }
      case ChorusBlock(:final children):
        final body = <GestureItem>[];
        _linearize(children, body, state);
        state.lastChorus = body;
        out
          ..add(const SectionLabel.chorus())
          ..addAll(body);
      case LinkBlock(:final children):
        final body = <GestureItem>[];
        _linearize(children, body, state);
        out.add(LinkBlock(children: body));
      case FinalBlock(:final children):
        final body = <GestureItem>[];
        _linearize(children, body, state);
        out.add(FinalBlock(children: body));
    }
  }
}

void _instruction(
  InstructionKind kind,
  InstructionCard card,
  List<GestureItem> out,
  _LinearizeState state,
) {
  switch (kind) {
    case InstructionKind.instruments:
      out.add(card);
    case InstructionKind.backToChorus || InstructionKind.backToChorusAndFinish:
      final chorus = state.lastChorus;
      if (chorus == null) {
        out.add(card);
        return;
      }
      out
        ..add(const SectionLabel.chorus())
        ..addAll(chorus);
    case InstructionKind.repeatPraise:
      if (state.root.isEmpty) {
        out.add(card);
        return;
      }
      // Cópia antes de emitir: quando `out` é a própria raiz, `addAll(root)`
      // iteraria a lista enquanto cresce.
      final copy = List<GestureItem>.of(state.root);
      out
        ..add(const SectionLabel.pass(2))
        ..addAll(copy);
  }
}

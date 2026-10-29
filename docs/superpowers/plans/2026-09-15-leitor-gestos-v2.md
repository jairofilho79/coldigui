# Leitor de Gestos v2 — plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dar ao leitor de gestos (`/gestos`) tema claro/escuro, leitura linear (repetições e «voltar ao coro» expandidos), autoscroll que retoma após rolagem manual, e cartões zebrados com conteúdo centralizado — no mesmo padrão visual do leitor de cifras.

**Architecture:** `linearizeGestureDocument` é uma transformação pura `GestureDocument → GestureDocument` aplicada na tela antes da view, do `flatten` e do foco. `GestureReaderPalette` vira instância escolhida por `GestureReaderMode` e é passada por parâmetro a cada widget. O autoscroll é um `Ticker` no `State` da tela, com pausa/retomada dirigida por `ScrollNotification`s.

**Tech Stack:** Flutter 3, Riverpod 3 (`Notifier`/`NotifierProvider`), `shared_preferences`, `flutter gen-l10n` (`pt` template, `en`), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-15-leitor-gestos-v2-design.md`

## Global Constraints

- Contrato de dados (`coldigom.gestures/1`) e o parser **não** mudam. `SectionLabel` só nasce no linearizador.
- `GestureItem` é `sealed`: cada `switch` sobre ele precisa ganhar o caso `SectionLabel()` (o compilador aponta onde).
- Leitura linear **default ligada**; tema default `light`; velocidade default `3`; `running` do autoscroll **não** persiste.
- Preferências do leitor de gestos são independentes das de cifras (`StorageKeys.gestureReaderMode`, `gestureReaderLinear`, `gestureAutoscrollSpeed`).
- Figura sempre em quadro **branco** (`figureBg`), nos dois temas.
- l10n: editar `lib/l10n/app_pt.arb` (template) **e** `app_en.arb`, depois rodar `flutter gen-l10n` — os `app_localizations*.dart` são versionados e entram no commit.
- Comentários e docstrings em português, no tom do código vizinho (explicam o *porquê*, não o *o quê*).
- Cada tarefa termina com `flutter analyze` limpo nos arquivos tocados e os testes da pasta `test/*/features/gestures` verdes.
- Commits: mensagem em português, prefixo convencional (`feat(gestos):`, `refactor(gestos):`, `test(gestos):`), terminando com `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`.
- Trabalhar no worktree `.claude/worktrees/leitor-gestos-v2` (branch `worktree-leitor-gestos-v2`). Não usar `git stash` sem tag.

---

## Mapa de arquivos

| Arquivo | Responsabilidade |
|---|---|
| `lib/features/gestures/domain/entities/gesture_document.dart` | +`SectionLabel` (variante de `GestureItem`) |
| `lib/features/gestures/domain/utils/flatten_gesture_cards.dart` | ignora `SectionLabel` |
| `lib/features/gestures/domain/usecases/linearize_gesture_document.dart` | **novo** — expansão linear pura |
| `lib/features/gestures/domain/entities/gesture_autoscroll_speed.dart` | **novo** — faixa da velocidade (forma de `GestureReaderFontSize`) |
| `lib/features/gestures/presentation/theme/gesture_reader_palette.dart` | paleta vira classe com campos; constantes de layout ficam |
| `lib/features/gestures/presentation/theme/gesture_reader_theme.dart` | **novo** — `GestureReaderMode {light, dark}` → `palette` |
| `lib/core/constants/storage_keys.dart` | +3 chaves |
| `lib/features/gestures/data/datasources/gesture_reader_preferences_datasource.dart` | +mode, linear, autoscrollSpeed |
| `lib/features/gestures/presentation/providers/gesture_reader_mode_provider.dart` | **novo** |
| `lib/features/gestures/presentation/providers/gesture_reader_linear_provider.dart` | **novo** |
| `lib/features/gestures/presentation/providers/gesture_autoscroll_provider.dart` | **novo** |
| `lib/features/gestures/presentation/widgets/*.dart` | recebem `palette`; `gesture_card_tile.dart` ganha zebra + centro; **novo** `section_label_view.dart` |
| `lib/features/gestures/presentation/pages/gesture_reader_screen.dart` | barra nova, linearização, motor de autoscroll |
| `lib/l10n/app_pt.arb`, `app_en.arb` | +8 chaves |

---

### Task 1: `SectionLabel` no domínio

**Files:**
- Modify: `lib/features/gestures/domain/entities/gesture_document.dart`
- Modify: `lib/features/gestures/domain/utils/flatten_gesture_cards.dart`
- Modify: `lib/features/gestures/presentation/widgets/gesture_document_view.dart` (só os `switch`, para compilar)
- Test: `test/unit/features/gestures/flatten_gesture_cards_test.dart`

**Interfaces:**
- Produces: `final class SectionLabel extends GestureItem { const SectionLabel.chorus(); const SectionLabel.pass(int pass); final int? pass; bool get isChorus; }`

- [ ] **Step 1: Teste que falha — `flatten` pula `SectionLabel` e `hasGestures` a ignora**

Acrescentar ao fim de `test/unit/features/gestures/flatten_gesture_cards_test.dart`, dentro de `main()`:

```dart
  test('SectionLabel não vira cartão nem conta como gesto', () {
    const card = GestureCard(gestureId: 'c687580e7682', lyrics: [LyricLine(trigger: 'a', text: 'b')]);
    const doc = GestureDocument(
      schemaMajor: 1,
      title: '',
      dictionaryVersion: 1,
      items: [SectionLabel.chorus(), card, SectionLabel.pass(2), card],
    );

    final flat = flattenGestureCards(doc);

    expect(flat, hasLength(2));
    expect([for (final f in flat) f.index], [0, 1]);
    expect(
      const GestureDocument(schemaMajor: 1, title: '', dictionaryVersion: 1, items: [SectionLabel.pass(3)]).hasGestures,
      isFalse,
    );
    expect(const SectionLabel.chorus().isChorus, isTrue);
    expect(const SectionLabel.pass(2).isChorus, isFalse);
    expect(const SectionLabel.pass(2).pass, 2);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/gestures/flatten_gesture_cards_test.dart`
Expected: erro de compilação — `SectionLabel` não definido.

- [ ] **Step 3: Definir `SectionLabel`**

Em `lib/features/gestures/domain/entities/gesture_document.dart`, acrescentar após `TextLine`:

```dart
/// Rótulo discreto que o linearizador insere entre trechos expandidos
/// («coro», «2ª vez»). O parser nunca o produz; só
/// `linearizeGestureDocument`. Não é cartão (o `flatten` o pula) nem bloco.
final class SectionLabel extends GestureItem {
  const SectionLabel.chorus() : pass = null;

  const SectionLabel.pass(int this.pass) : assert(pass >= 2);

  /// `null` = «coro»; `k` (≥ 2) = «kª vez».
  final int? pass;

  bool get isChorus => pass == null;
}
```

E em `_containsGesture`, trocar a última linha do `switch`:

```dart
    InstructionCard() || TextLine() || SectionLabel() => false,
```

Em `lib/features/gestures/domain/utils/flatten_gesture_cards.dart`, no `switch` de `_walk`:

```dart
      case InstructionCard() || TextLine() || SectionLabel():
        break;
```

Em `lib/features/gestures/presentation/widgets/gesture_document_view.dart`, para compilar até a Task 6 renderizar de verdade:

- em `_isBlock`: `GestureCard() || InstructionCard() || TextLine() || SectionLabel() => false,`
- em `_buildItem`, antes do fechamento do `switch`:

```dart
      case SectionLabel():
        // Renderização real na Task 6 (SectionLabelView).
        return const SizedBox.shrink();
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/unit/features/gestures/flatten_gesture_cards_test.dart && flutter analyze lib/features/gestures`
Expected: todos passam; analyze sem issues.

- [ ] **Step 5: Commit**

```bash
git add lib/features/gestures/domain lib/features/gestures/presentation/widgets/gesture_document_view.dart test/unit/features/gestures/flatten_gesture_cards_test.dart
git commit -m "feat(gestos): SectionLabel — rótulo de seção que só o linearizador produz

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: `linearizeGestureDocument`

**Files:**
- Create: `lib/features/gestures/domain/usecases/linearize_gesture_document.dart`
- Test: `test/unit/features/gestures/linearize_gesture_document_test.dart`

**Interfaces:**
- Consumes: `SectionLabel` (Task 1), `GestureDocument`, `GestureItem` e variantes.
- Produces: `GestureDocument linearizeGestureDocument(GestureDocument document)`.

- [ ] **Step 1: Teste que falha**

Criar `test/unit/features/gestures/linearize_gesture_document_test.dart`:

```dart
import 'dart:io';

import 'package:coldigui/features/gestures/domain/entities/gesture_document.dart';
import 'package:coldigui/features/gestures/domain/usecases/linearize_gesture_document.dart';
import 'package:coldigui/features/gestures/domain/usecases/parse_gesture_document.dart';
import 'package:coldigui/features/gestures/domain/utils/flatten_gesture_cards.dart';
import 'package:flutter_test/flutter_test.dart';

GestureDocument _fixture(String name) => parseGestureDocument(
  File('test/fixtures/gestures/$name').readAsStringSync(),
);

GestureDocument _doc(List<GestureItem> items) =>
    GestureDocument(schemaMajor: 1, title: 't', dictionaryVersion: 1, items: items);

GestureCard _g(String trigger) =>
    GestureCard(gestureId: 'c687580e7682', lyrics: [LyricLine(trigger: trigger, text: '')]);

/// Forma legível da árvore: `g:<trigger>`, `coro`, `2ª`, `!kind`, `link[...]`,
/// `final[...]`, `~texto`. Cartões e blocos não têm `==`, então comparar
/// strings é o jeito estável de comparar estrutura.
String _shape(List<GestureItem> items) => items.map(_shapeOf).join(' ');

String _shapeOf(GestureItem item) => switch (item) {
  GestureCard(:final lyrics) => 'g:${lyrics.first.trigger}',
  SectionLabel(:final pass) => pass == null ? 'coro' : '$passª',
  InstructionCard(:final kind) => '!${kind.name}',
  TextLine(:final text) => '~$text',
  LinkBlock(:final children) => 'link[${_shape(children)}]',
  FinalBlock(:final children) => 'final[${_shape(children)}]',
  RepeatBlock(:final count, :final children) => '${count}x[${_shape(children)}]',
  ChorusBlock(:final children) => 'CORO[${_shape(children)}]',
};

void main() {
  test('cartões, texto e «instrumentos» passam inalterados; título e schema também', () {
    final doc = GestureDocument(
      schemaMajor: 2,
      title: 'X',
      dictionaryVersion: 7,
      items: [_g('a'), const TextLine('livre'), const InstructionCard(InstructionKind.instruments)],
    );
    final out = linearizeGestureDocument(doc);
    expect(_shape(out.items), 'g:a ~livre !instruments');
    expect(out.schemaMajor, 2);
    expect(out.title, 'X');
    expect(out.dictionaryVersion, 7);
  });

  test('Nx repete os filhos N vezes com «kª vez» antes de cada passagem a partir da 2ª', () {
    final out = linearizeGestureDocument(_doc([
      RepeatBlock(count: 3, children: [_g('a'), _g('b')]),
    ]));
    expect(_shape(out.items), 'g:a g:b 2ª g:a g:b 3ª g:a g:b');
  });

  test('CORO vira rótulo + filhos, sem chave', () {
    final out = linearizeGestureDocument(_doc([
      ChorusBlock(children: [_g('a')]),
      _g('b'),
    ]));
    expect(_shape(out.items), 'coro g:a g:b');
  });

  test('«voltar ao coro» repete o último coro visto, com rótulo', () {
    final out = linearizeGestureDocument(_doc([
      ChorusBlock(children: [_g('c1'), _g('c2')]),
      _g('v'),
      const InstructionCard(InstructionKind.backToChorus),
      _g('w'),
      const InstructionCard(InstructionKind.backToChorusAndFinish),
      FinalBlock(children: [_g('f')]),
    ]));
    expect(_shape(out.items), 'coro g:c1 g:c2 g:v coro g:c1 g:c2 g:w coro g:c1 g:c2 final[g:f]');
  });

  test('«voltar ao coro» sem coro mantém a instrução', () {
    final out = linearizeGestureDocument(_doc([
      _g('a'),
      const InstructionCard(InstructionKind.backToChorus),
    ]));
    expect(_shape(out.items), 'g:a !backToChorus');
  });

  test('coro dentro de Nx conta como último coro', () {
    final out = linearizeGestureDocument(_doc([
      RepeatBlock(count: 2, children: [ChorusBlock(children: [_g('c')])]),
      const InstructionCard(InstructionKind.backToChorus),
    ]));
    expect(_shape(out.items), 'coro g:c 2ª coro g:c coro g:c');
  });

  test('«repetir o louvor» duplica tudo que a raiz já emitiu, com «2ª vez»', () {
    final out = linearizeGestureDocument(_doc([
      _g('a'),
      RepeatBlock(count: 2, children: [_g('b')]),
      const InstructionCard(InstructionKind.repeatPraise),
      _g('z'),
    ]));
    expect(_shape(out.items), 'g:a g:b 2ª g:b 2ª g:a g:b 2ª g:b g:z');
  });

  test('«repetir o louvor» sem nada antes mantém a instrução', () {
    final out = linearizeGestureDocument(_doc([
      const InstructionCard(InstructionKind.repeatPraise),
      _g('a'),
    ]));
    expect(_shape(out.items), '!repeatPraise g:a');
  });

  test('«repetir o louvor» dentro de bloco copia só o que a raiz emitiu antes do bloco', () {
    final out = linearizeGestureDocument(_doc([
      _g('a'),
      FinalBlock(children: [_g('f'), const InstructionCard(InstructionKind.repeatPraise)]),
    ]));
    expect(_shape(out.items), 'g:a final[g:f 2ª g:a]');
  });

  test('link e final são mantidos com os filhos linearizados', () {
    final out = linearizeGestureDocument(_doc([
      LinkBlock(children: [_g('a'), RepeatBlock(count: 2, children: [_g('b')])]),
      FinalBlock(children: [RepeatBlock(count: 2, children: [_g('c')])]),
    ]));
    expect(_shape(out.items), 'link[g:a g:b 2ª g:b] final[g:c 2ª g:c]');
  });

  test('181: o 2x da raiz rende 4 + 4 cartões com «2ª vez» no meio', () {
    final out = linearizeGestureDocument(_fixture('181_jerusalem.json'));
    expect(flattenGestureCards(out), hasLength(13));
    expect(_shape(out.items).split(' ').where((s) => s == '2ª').length, 1);
    expect(_shape(out.items), endsWith('g:Jesus 2ª g:Aleluia, g:glória g:Aleluia, g:Jesus'));
  });

  test('182: o coro reaparece nos dois «voltar ao coro»; sem chip de contexto no flatten', () {
    final out = linearizeGestureDocument(_fixture('182_quero_viver.json'));
    // 5 (coro) + 5 + 5 (coro) + 4 + 5 (coro) = 24
    final flat = flattenGestureCards(out);
    expect(flat, hasLength(24));
    expect(flat.every((f) => f.contexts.isEmpty), isTrue);
    expect(_shape(out.items).split(' ').where((s) => s == 'coro').length, 3);
    expect(out.items.whereType<InstructionCard>(), isEmpty);
  });

  test('sintético: 3x com link dentro, coro{2x}, item desconhecido, final', () {
    final out = linearizeGestureDocument(_fixture('sintetico_final_link.json'));
    expect(
      _shape(out.items),
      '!instruments '
      'g:Um link[g:Ligado g:seguinte] 2ª g:Um link[g:Ligado g:seguinte] 3ª g:Um link[g:Ligado g:seguinte] '
      'coro g:Coro 2ª g:Coro '
      '~{"type":"hologram","foo":1} ~linha livre g:Id '
      'final[g:Fim]',
    );
  });

  test('é idempotente: linearizar o já linear não muda nada', () {
    for (final name in ['181_jerusalem.json', '182_quero_viver.json', 'sintetico_final_link.json']) {
      final once = linearizeGestureDocument(_fixture(name));
      final twice = linearizeGestureDocument(once);
      expect(_shape(twice.items), _shape(once.items), reason: name);
    }
  });
}
```

Observação sobre o texto do item desconhecido do sintético: o parser guarda o JSON compactado no `TextLine`; se o `expect` do sintético falhar só nesse trecho, copie o valor real de `out.items` para o teste — o que importa é a estrutura em volta.

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/gestures/linearize_gesture_document_test.dart`
Expected: erro de compilação — `linearize_gesture_document.dart` não existe.

- [ ] **Step 3: Implementar**

Criar `lib/features/gestures/domain/usecases/linearize_gesture_document.dart`:

```dart
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
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/unit/features/gestures/linearize_gesture_document_test.dart && flutter analyze lib/features/gestures/domain`
Expected: todos passam.

- [ ] **Step 5: Commit**

```bash
git add lib/features/gestures/domain/usecases/linearize_gesture_document.dart test/unit/features/gestures/linearize_gesture_document_test.dart
git commit -m "feat(gestos): linearizeGestureDocument — expande Nx, coro e «voltar ao coro»

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Paleta por tema e widgets recebendo `palette`

Refatoração mecânica: `GestureReaderPalette` deixa de ser estática; cada widget do leitor ganha `required this.palette`. Nenhuma mudança de layout nesta tarefa.

**Files:**
- Modify: `lib/features/gestures/presentation/theme/gesture_reader_palette.dart`
- Create: `lib/features/gestures/presentation/theme/gesture_reader_theme.dart`
- Modify: todos em `lib/features/gestures/presentation/widgets/` exceto `newer_schema_banner.dart`
- Modify: `lib/features/gestures/presentation/pages/gesture_reader_screen.dart` (só passar `GestureReaderMode.light.palette` por enquanto)
- Test: `test/unit/features/gestures/gesture_reader_theme_test.dart` (novo); ajustar `test/widget/features/gestures/{block_views,lyric_line_text,gesture_card_tile,gesture_figure,gesture_document_view,gesture_focus_view}_test.dart`

**Interfaces:**
- Produces: `class GestureReaderPalette { const GestureReaderPalette({required Color paper, stripe, trigger, lyric, blue, orange, wine, instructionBg, instructionText, instructionBorder, sectionLabel, placeholderBg, placeholderBorder, figureBg, figureBorder, toolbarIcon, divider}); }`
- Produces: `enum GestureReaderMode { light, dark; GestureReaderPalette get palette; GestureReaderMode toggle(); String toStorageString(); static GestureReaderMode? fromStorageString(String?); }`
- Produces: parâmetro `palette` em `GestureCardTile`, `GestureFigure`, `LyricLineText`, `TextLineView`, `InstructionCardView`, `RepeatBlockView`, `BracedChildren`, `ChorusBlockView`, `LinkBlockView`, `FinalSectionView`, `BracePainter`, `LinkConnectorPainter`, `GestureDocumentView`, `GestureFocusView`, `showGestureFocus`.

- [ ] **Step 1: Teste do tema (falha)**

Criar `test/unit/features/gestures/gesture_reader_theme_test.dart`:

```dart
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/gestures/presentation/theme/gesture_reader_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('claro é creme com texto escuro; escuro é carvão com texto claro', () {
    final light = GestureReaderMode.light.palette;
    final dark = GestureReaderMode.dark.palette;
    expect(light.paper, AppColors.card);
    expect(light.lyric, AppColors.textDark);
    expect(light.toolbarIcon, AppColors.title);
    expect(dark.paper, AppColors.pdfArea);
    expect(dark.lyric, AppColors.textLight);
    expect(dark.toolbarIcon, AppColors.goldLight);
  });

  test('a figura fica em quadro branco nos dois temas', () {
    expect(GestureReaderMode.light.palette.figureBg.toARGB32(), 0xFFFFFFFF);
    expect(GestureReaderMode.dark.palette.figureBg.toARGB32(), 0xFFFFFFFF);
  });

  test('toggle alterna; serialização ida e volta; inválido é null', () {
    expect(GestureReaderMode.light.toggle(), GestureReaderMode.dark);
    expect(GestureReaderMode.dark.toggle(), GestureReaderMode.light);
    for (final mode in GestureReaderMode.values) {
      expect(GestureReaderMode.fromStorageString(mode.toStorageString()), mode);
    }
    expect(GestureReaderMode.fromStorageString('sepia'), isNull);
    expect(GestureReaderMode.fromStorageString(null), isNull);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/gestures/gesture_reader_theme_test.dart`
Expected: erro de compilação — arquivo do tema não existe.

- [ ] **Step 3: Paleta como instância**

Substituir a classe em `lib/features/gestures/presentation/theme/gesture_reader_palette.dart` (as constantes `kGesture*` e `gestureFigureSide` abaixo dela ficam como estão):

```dart
import 'package:flutter/material.dart';

/// Cores de uma variante (clara/escura) do papel de gestos.
///
/// Escolhida por `GestureReaderMode.palette` e passada por parâmetro a cada
/// widget do leitor — nenhum deles lê tema global. A figura fica sempre em
/// quadro branco ([figureBg]): os PNGs do dicionário são coloridos, com borda
/// preta desenhada dentro da imagem, e não admitem inversão.
class GestureReaderPalette {
  const GestureReaderPalette({
    required this.paper,
    required this.stripe,
    required this.trigger,
    required this.lyric,
    required this.blue,
    required this.orange,
    required this.wine,
    required this.instructionBg,
    required this.instructionText,
    required this.instructionBorder,
    required this.sectionLabel,
    required this.placeholderBg,
    required this.placeholderBorder,
    required this.figureBg,
    required this.figureBorder,
    required this.toolbarIcon,
    required this.divider,
  });

  /// Fundo da página.
  final Color paper;

  /// Faixa de fundo dos cartões ímpares (zebra).
  final Color stripe;

  /// Gatilho: palavra em que o gesto começa.
  final Color trigger;

  /// Leitura: o que se canta enquanto o gesto dura. Também o título.
  final Color lyric;

  /// Chave de repetição, `Nx`, rótulo `CORO`, chips do foco.
  final Color blue;

  /// Conector de ligação.
  final Color orange;

  /// Divisor e rótulo `FINAL`.
  final Color wine;

  final Color instructionBg;
  final Color instructionText;
  final Color instructionBorder;

  /// Rótulo de seção da leitura linear e linha livre (`text`).
  final Color sectionLabel;

  final Color placeholderBg;
  final Color placeholderBorder;

  /// Quadro da figura — branco nos dois temas.
  final Color figureBg;
  final Color figureBorder;

  /// Ícones da barra 3.
  final Color toolbarIcon;

  /// Separadores da barra e rodapé do foco.
  final Color divider;
}
```

Criar `lib/features/gestures/presentation/theme/gesture_reader_theme.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/color_extensions.dart';
import 'gesture_reader_palette.dart';

/// Claro/escuro **local ao leitor de gestos**, como `ChordReaderMode` na
/// cifra: o app não tem dark mode global e este toggle não toca em
/// `ThemeData`. Independente do tema da cifra — quem rege gestos não
/// necessariamente abre cifra.
enum GestureReaderMode {
  light,
  dark;

  GestureReaderPalette get palette => switch (this) {
    GestureReaderMode.light => const GestureReaderPalette(
      paper: AppColors.card,
      stripe: Color(0x0A6A2F2F),
      trigger: Color(0xFFC62828),
      lyric: AppColors.textDark,
      blue: Color(0xFF1E63C8),
      orange: Color(0xFFE08A1E),
      wine: AppColors.title,
      instructionBg: Color(0xFFF3EDDC),
      instructionText: Color(0xFF4A4036),
      instructionBorder: Color(0xFFD9CFB8),
      sectionLabel: Color(0xFF8A7F70),
      placeholderBg: Color(0xFFFFF7E6),
      placeholderBorder: Color(0xFFE0B45C),
      figureBg: Color(0xFFFFFFFF),
      figureBorder: Color(0x1A000000),
      // Vinho, não ouro: ouro sobre creme não tem contraste (a cifra faz igual).
      toolbarIcon: AppColors.title,
      divider: Color(0x666A2F2F),
    ),
    GestureReaderMode.dark => const GestureReaderPalette(
      paper: AppColors.pdfArea,
      // Alfa maior no escuro: a mesma faixa que se lê sobre creme some sobre carvão.
      stripe: Color(0x12FFFFFF),
      trigger: Color(0xFFFF5252),
      lyric: AppColors.textLight,
      blue: Color(0xFF7FA9F0),
      orange: Color(0xFFF0B35A),
      wine: AppColors.goldLight,
      instructionBg: Color(0xFF3A3A3A),
      instructionText: Color(0xFFD0D0D0),
      instructionBorder: Color(0xFF555555),
      sectionLabel: Color(0xFF9E9E9E),
      placeholderBg: Color(0xFF3D3420),
      placeholderBorder: Color(0xFFB8933E),
      figureBg: Color(0xFFFFFFFF),
      figureBorder: Color(0x33FFFFFF),
      toolbarIcon: AppColors.goldLight,
      divider: Color(0x66FFFFFF),
    ),
  };

  GestureReaderMode toggle() =>
      this == GestureReaderMode.light ? GestureReaderMode.dark : GestureReaderMode.light;

  /// Serializa para `StorageKeys.gestureReaderMode`.
  String toStorageString() => name;

  /// Restaura; `null` se inválido.
  static GestureReaderMode? fromStorageString(String? value) => switch (value) {
    'light' => GestureReaderMode.light,
    'dark' => GestureReaderMode.dark,
    _ => null,
  };
}
```

- [ ] **Step 4: Rodar o teste do tema**

Run: `flutter test test/unit/features/gestures/gesture_reader_theme_test.dart`
Expected: passa. (`flutter analyze` ainda acusa os widgets — próximo passo.)

- [ ] **Step 5: Passar `palette` pelos widgets**

Regra geral: adicionar `required this.palette` + `final GestureReaderPalette palette;` e trocar cada `GestureReaderPalette.x` por `palette.x`. `freeText` vira `palette.sectionLabel`; `paper` no quadro da figura vira `figureBg`. Detalhes por arquivo:

`brace_painter.dart`:

```dart
class BracePainter extends CustomPainter {
  const BracePainter({required this.dashed, required this.palette, this.label});

  final bool dashed;
  final GestureReaderPalette palette;
  final String? label;
  // ... em paint(): `..color = palette.blue` e no TextStyle `color: palette.blue`
  @override
  bool shouldRepaint(BracePainter old) =>
      old.dashed != dashed || old.label != label || old.palette != palette;
}
```

`link_connector_painter.dart`:

```dart
class LinkConnectorPainter extends CustomPainter {
  const LinkConnectorPainter({required this.palette});

  final GestureReaderPalette palette;
  // paint(): `palette.orange` nas duas ocorrências
  @override
  bool shouldRepaint(LinkConnectorPainter old) => old.palette != palette;
}
```

`repeat_block_view.dart` — `RepeatBlockView({required this.count, required this.palette, required this.children})` repassa para `BracedChildren(dashed: false, label: '${count}x', palette: palette, children: children)`; `BracedChildren` ganha `required this.palette` e monta `BracePainter(dashed: dashed, label: label, palette: palette)`.

`chorus_block_view.dart` — `ChorusBlockView({required this.palette, required this.children})`; `color: palette.blue`; `BracedChildren(dashed: true, palette: palette, children: children)`.

`link_block_view.dart` — `LinkBlockView({required this.palette, required this.children})`; o `Positioned` deixa de ser `const`; `painter: LinkConnectorPainter(palette: palette)`.

`final_section_view.dart` — `FinalSectionView({required this.palette, required this.children})`; `color: palette.wine`; `_DashDotPainter(palette)` com `final GestureReaderPalette palette;` usando `palette.wine`; `shouldRepaint(old) => old.palette != palette`. O `Expanded`/`SizedBox`/`CustomPaint` deixam de ser `const`.

`instruction_card_view.dart` — `InstructionCardView({required this.kind, required this.palette})`; `instructionBg/Text/Border` via `palette`; o `TextStyle` deixa de ser `const`.

`text_line_view.dart` — `TextLineView({required this.text, required this.fontSize, required this.palette})`; `color: palette.sectionLabel`.

`lyric_line_text.dart` — `LyricLineText({required this.line, required this.fontSize, required this.palette})`; os três `color:` via `palette` (`lyric`, `trigger`, `lyric`); os `TextStyle` internos deixam de ser `const`.

`gesture_figure.dart` — `GestureFigure({required this.entry, required this.gestureId, required this.side, required this.palette, this.preferGif = false})`; `ColoredBox(color: palette.figureBg, …)`; `_Placeholder({required this.gestureId, required this.side, required this.palette})` com `placeholderBg/Border` e `sectionLabel` (no lugar de `freeText`) via `palette`. (O quadro arredondado vem na Task 5.)

`gesture_card_tile.dart` — `GestureCardTile({…, required this.palette, …})`; repassa `palette` a `GestureFigure` e a cada `LyricLineText`.

`gesture_document_view.dart` — `GestureDocumentView({…, required this.palette, …})`; `ColoredBox(color: widget.palette.paper, …)`; título `color: widget.palette.lyric`; cada `*View`/`GestureCardTile` recebe `palette: widget.palette`.

`gesture_focus_view.dart` — `showGestureFocus(context, {…, required GestureReaderPalette palette})` repassa a `GestureFocusView({…, required this.palette})`; `Material(color: widget.palette.paper)`; ícone de fechar `color: widget.palette.lyric`; `_FocusPage` recebe `palette` e usa `palette.blue`/`palette.paper` nos chips e repassa a `GestureFigure`/`LyricLineText`; `_NextFooter` recebe `palette`: borda `palette.divider`, textos `palette.sectionLabel`, gatilho `palette.trigger`.

`gesture_reader_screen.dart` — por enquanto, no `build`: `final palette = GestureReaderMode.light.palette;` (import de `../theme/gesture_reader_theme.dart`), passar `palette: palette` para `GestureDocumentView` e `showGestureFocus`. A Task 7 troca pelo provider.

- [ ] **Step 6: Ajustar os testes de widget existentes**

Em cada teste abaixo, importar `package:coldigui/features/gestures/presentation/theme/gesture_reader_theme.dart` e definir `final _palette = GestureReaderMode.light.palette;` no topo; passar `palette: _palette` em cada construtor que agora exige; trocar `GestureReaderPalette.blue` → `_palette.blue`, `.wine` → `_palette.wine`, `.freeText` → `_palette.sectionLabel`, `.trigger`/`.lyric` → `_palette.trigger`/`_palette.lyric`:

- `block_views_test.dart` (`RepeatBlockView`, `ChorusBlockView`, `LinkBlockView`, `FinalSectionView`, `InstructionCardView`, `TextLineView`)
- `lyric_line_text_test.dart`
- `gesture_card_tile_test.dart`
- `gesture_figure_test.dart`
- `gesture_document_view_test.dart`
- `gesture_focus_view_test.dart` (`showGestureFocus(..., palette: _palette)`)

Onde `const` quebrar por causa do `palette` de instância (`const GestureReaderMode.light.palette` não é constante), remover o `const` do construtor no teste.

- [ ] **Step 7: Rodar tudo de gestos**

Run: `flutter analyze lib/features/gestures test/unit/features/gestures test/widget/features/gestures && flutter test test/unit/features/gestures test/widget/features/gestures`
Expected: analyze limpo; 100 + 51 + 3 testes passam.

- [ ] **Step 8: Commit**

```bash
git add lib/features/gestures test/unit/features/gestures test/widget/features/gestures
git commit -m "refactor(gestos): paleta por tema (GestureReaderMode) passada a cada widget

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Preferências e providers (tema, linear, velocidade do autoscroll)

**Files:**
- Create: `lib/features/gestures/domain/entities/gesture_autoscroll_speed.dart`
- Modify: `lib/core/constants/storage_keys.dart`
- Modify: `lib/features/gestures/data/datasources/gesture_reader_preferences_datasource.dart`
- Create: `lib/features/gestures/presentation/providers/gesture_reader_mode_provider.dart`
- Create: `lib/features/gestures/presentation/providers/gesture_reader_linear_provider.dart`
- Create: `lib/features/gestures/presentation/providers/gesture_autoscroll_provider.dart`
- Test: `test/unit/features/gestures/gesture_reader_preferences_test.dart` (novo), `test/unit/features/gestures/gesture_autoscroll_provider_test.dart` (novo)

**Interfaces:**
- Produces: `abstract final class GestureAutoscrollSpeed { static const int min = 1, max = 5, initial = 3; static const double pxPerSecondPerLevel = 10; static int clamp(int); }`
- Produces: `StorageKeys.gestureReaderMode`, `.gestureReaderLinear`, `.gestureAutoscrollSpeed`.
- Produces: no datasource — `GestureReaderMode getMode()`, `Future<void> saveMode(GestureReaderMode)`, `bool getLinear()`, `Future<void> saveLinear(bool)`, `int getAutoscrollSpeed()`, `Future<void> saveAutoscrollSpeed(int)`.
- Produces: `gestureReaderModeProvider` (`NotifierProvider<GestureReaderModeNotifier, GestureReaderMode>`, `toggle()`); `gestureReaderLinearProvider` (`NotifierProvider<GestureReaderLinearNotifier, bool>`, `toggle()`); `gestureAutoscrollProvider` (`NotifierProvider.autoDispose<GestureAutoscrollNotifier, GestureAutoscrollState>`, `toggle()`, `setSpeed(int)`, `stop()`); `class GestureAutoscrollState { bool running; int speed; copyWith }`.

- [ ] **Step 1: Testes que falham**

Criar `test/unit/features/gestures/gesture_reader_preferences_test.dart`:

```dart
import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/gestures/data/datasources/gesture_reader_preferences_datasource.dart';
import 'package:coldigui/features/gestures/presentation/providers/gesture_reader_linear_provider.dart';
import 'package:coldigui/features/gestures/presentation/providers/gesture_reader_mode_provider.dart';
import 'package:coldigui/features/gestures/presentation/theme/gesture_reader_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<(ProviderContainer, SharedPreferences)> _setup({Map<String, Object> initial = const {}}) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
  addTearDown(c.dispose);
  return (c, prefs);
}

void main() {
  group('datasource', () {
    test('defaults: claro, linear ligado, velocidade 3', () async {
      final (_, prefs) = await _setup();
      final ds = GestureReaderPreferencesDatasource(prefs);
      expect(ds.getMode(), GestureReaderMode.light);
      expect(ds.getLinear(), isTrue);
      expect(ds.getAutoscrollSpeed(), 3);
    });

    test('valores inválidos caem no default ou são grampeados', () async {
      final (_, prefs) = await _setup(initial: {
        StorageKeys.gestureReaderMode: 'sepia',
        StorageKeys.gestureAutoscrollSpeed: 42,
      });
      final ds = GestureReaderPreferencesDatasource(prefs);
      expect(ds.getMode(), GestureReaderMode.light);
      expect(ds.getAutoscrollSpeed(), 5);
    });

    test('save/get ida e volta', () async {
      final (_, prefs) = await _setup();
      final ds = GestureReaderPreferencesDatasource(prefs);
      await ds.saveMode(GestureReaderMode.dark);
      await ds.saveLinear(false);
      await ds.saveAutoscrollSpeed(1);
      expect(ds.getMode(), GestureReaderMode.dark);
      expect(ds.getLinear(), isFalse);
      expect(ds.getAutoscrollSpeed(), 1);
      expect(prefs.getString(StorageKeys.gestureReaderMode), 'dark');
      expect(prefs.getBool(StorageKeys.gestureReaderLinear), isFalse);
      expect(prefs.getInt(StorageKeys.gestureAutoscrollSpeed), 1);
    });
  });

  group('gestureReaderModeProvider', () {
    test('começa claro; toggle vai a escuro e persiste', () async {
      final (c, prefs) = await _setup();
      expect(c.read(gestureReaderModeProvider), GestureReaderMode.light);
      c.read(gestureReaderModeProvider.notifier).toggle();
      expect(c.read(gestureReaderModeProvider), GestureReaderMode.dark);
      expect(prefs.getString(StorageKeys.gestureReaderMode), 'dark');
    });

    test('lê o salvo', () async {
      final (c, _) = await _setup(initial: {StorageKeys.gestureReaderMode: 'dark'});
      expect(c.read(gestureReaderModeProvider), GestureReaderMode.dark);
    });
  });

  group('gestureReaderLinearProvider', () {
    test('começa ligado; toggle desliga e persiste', () async {
      final (c, prefs) = await _setup();
      expect(c.read(gestureReaderLinearProvider), isTrue);
      c.read(gestureReaderLinearProvider.notifier).toggle();
      expect(c.read(gestureReaderLinearProvider), isFalse);
      expect(prefs.getBool(StorageKeys.gestureReaderLinear), isFalse);
    });

    test('lê o salvo', () async {
      final (c, _) = await _setup(initial: {StorageKeys.gestureReaderLinear: false});
      expect(c.read(gestureReaderLinearProvider), isFalse);
    });
  });
}
```

Criar `test/unit/features/gestures/gesture_autoscroll_provider_test.dart`:

```dart
import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/gestures/domain/entities/gesture_autoscroll_speed.dart';
import 'package:coldigui/features/gestures/presentation/providers/gesture_autoscroll_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<(ProviderContainer, SharedPreferences)> _setup({Map<String, Object> initial = const {}}) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
  addTearDown(c.dispose);
  return (c, prefs);
}

void main() {
  test('faixa: 1–5, inicial 3, clamp', () {
    expect(GestureAutoscrollSpeed.min, 1);
    expect(GestureAutoscrollSpeed.max, 5);
    expect(GestureAutoscrollSpeed.initial, 3);
    expect(GestureAutoscrollSpeed.clamp(0), 1);
    expect(GestureAutoscrollSpeed.clamp(9), 5);
    expect(GestureAutoscrollSpeed.pxPerSecondPerLevel, 10);
  });

  test('começa parado na velocidade salva (ou 3)', () async {
    final (c, _) = await _setup(initial: {StorageKeys.gestureAutoscrollSpeed: 4});
    final state = c.read(gestureAutoscrollProvider);
    expect(state.running, isFalse);
    expect(state.speed, 4);
  });

  test('toggle liga e desliga; stop é idempotente', () async {
    final (c, _) = await _setup();
    final n = c.read(gestureAutoscrollProvider.notifier);
    // Mantém o autoDispose vivo durante o teste.
    final sub = c.listen(gestureAutoscrollProvider, (_, _) {});
    addTearDown(sub.close);
    n.toggle();
    expect(c.read(gestureAutoscrollProvider).running, isTrue);
    n.toggle();
    expect(c.read(gestureAutoscrollProvider).running, isFalse);
    n.stop();
    expect(c.read(gestureAutoscrollProvider).running, isFalse);
  });

  test('setSpeed grampeia e persiste; não toca em running', () async {
    final (c, prefs) = await _setup();
    final sub = c.listen(gestureAutoscrollProvider, (_, _) {});
    addTearDown(sub.close);
    final n = c.read(gestureAutoscrollProvider.notifier);
    n.toggle();
    n.setSpeed(9);
    expect(c.read(gestureAutoscrollProvider).speed, 5);
    expect(c.read(gestureAutoscrollProvider).running, isTrue);
    expect(prefs.getInt(StorageKeys.gestureAutoscrollSpeed), 5);
    n.setSpeed(-1);
    expect(c.read(gestureAutoscrollProvider).speed, 1);
  });

  test('running não persiste: novo container começa parado', () async {
    final (c, prefs) = await _setup();
    final sub = c.listen(gestureAutoscrollProvider, (_, _) {});
    c.read(gestureAutoscrollProvider.notifier).toggle();
    sub.close();
    final c2 = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(c2.dispose);
    expect(c2.read(gestureAutoscrollProvider).running, isFalse);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/gestures/gesture_reader_preferences_test.dart test/unit/features/gestures/gesture_autoscroll_provider_test.dart`
Expected: erros de compilação (chaves, métodos e providers não existem).

- [ ] **Step 3: Implementar**

Criar `lib/features/gestures/domain/entities/gesture_autoscroll_speed.dart`:

```dart
/// Faixa da velocidade do autoscroll do leitor de gestos.
///
/// Níveis inteiros, como na cifra, mas mais lentos por nível: a linha de
/// gesto (figura de 96 dp) é mais alta que a de cifra, e a regente faz os
/// gestos com as mãos enquanto lê — 10 px/s por nível dá 10–50 px/s.
abstract final class GestureAutoscrollSpeed {
  static const int min = 1;
  static const int max = 5;
  static const int initial = 3;

  /// Pixels por segundo por nível — o motor multiplica pelo nível.
  static const double pxPerSecondPerLevel = 10;

  static int clamp(int speed) => speed.clamp(min, max);
}
```

Em `lib/core/constants/storage_keys.dart`, após `gestureReaderFontSize`:

```dart
  /// Claro/escuro do leitor de gestos (`light` | `dark`).
  static const String gestureReaderMode = 'gestureReaderMode';

  /// Leitura linear do leitor de gestos (`bool`, default `true`).
  static const String gestureReaderLinear = 'gestureReaderLinear';

  /// Velocidade do autoscroll do leitor de gestos (`int` 1–5).
  static const String gestureAutoscrollSpeed = 'gestureAutoscrollSpeed';
```

Substituir `lib/features/gestures/data/datasources/gesture_reader_preferences_datasource.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../domain/entities/gesture_autoscroll_speed.dart';
import '../../domain/entities/gesture_reader_font_size.dart';
import '../../presentation/theme/gesture_reader_theme.dart';

/// Persistência das preferências do leitor de gestos: corpo da letra, tema,
/// leitura linear e velocidade do autoscroll. `running` do autoscroll **não**
/// persiste — cada abertura começa parada.
class GestureReaderPreferencesDatasource {
  const GestureReaderPreferencesDatasource(this._prefs);

  final SharedPreferences _prefs;

  /// Corpo salvo, ou [GestureReaderFontSize.initial]; fora da faixa é
  /// grampeado em vez de descartado.
  double getFontSize() {
    final stored = _prefs.getDouble(StorageKeys.gestureReaderFontSize);
    if (stored == null) return GestureReaderFontSize.initial;
    return GestureReaderFontSize.clamp(stored);
  }

  Future<void> saveFontSize(double size) =>
      _prefs.setDouble(StorageKeys.gestureReaderFontSize, size);

  /// Modo salvo, ou claro por padrão.
  GestureReaderMode getMode() =>
      GestureReaderMode.fromStorageString(
        _prefs.getString(StorageKeys.gestureReaderMode),
      ) ??
      GestureReaderMode.light;

  Future<void> saveMode(GestureReaderMode mode) =>
      _prefs.setString(StorageKeys.gestureReaderMode, mode.toStorageString());

  /// Leitura linear — ligada por padrão.
  bool getLinear() => _prefs.getBool(StorageKeys.gestureReaderLinear) ?? true;

  Future<void> saveLinear(bool linear) =>
      _prefs.setBool(StorageKeys.gestureReaderLinear, linear);

  /// Velocidade salva, ou [GestureAutoscrollSpeed.initial]; grampeada na faixa.
  int getAutoscrollSpeed() {
    final stored = _prefs.getInt(StorageKeys.gestureAutoscrollSpeed);
    if (stored == null) return GestureAutoscrollSpeed.initial;
    return GestureAutoscrollSpeed.clamp(stored);
  }

  Future<void> saveAutoscrollSpeed(int speed) =>
      _prefs.setInt(StorageKeys.gestureAutoscrollSpeed, speed);
}
```

Criar `lib/features/gestures/presentation/providers/gesture_reader_mode_provider.dart`:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../data/datasources/gesture_reader_preferences_datasource.dart';
import '../theme/gesture_reader_theme.dart';

/// Claro/escuro do leitor de gestos, persistido entre sessões.
///
/// Mesmo padrão de `GestureReaderFontSizeNotifier`: `sharedPreferencesProvider`
/// é síncrono e o `main()` já o sobrescreve; testes de widget precisam de
/// `SharedPreferences.setMockInitialValues` **e** do override no `ProviderScope`.
class GestureReaderModeNotifier extends Notifier<GestureReaderMode> {
  @override
  GestureReaderMode build() => _datasource.getMode();

  GestureReaderPreferencesDatasource get _datasource =>
      GestureReaderPreferencesDatasource(ref.read(sharedPreferencesProvider));

  void toggle() {
    final next = state.toggle();
    state = next;
    unawaited(_datasource.saveMode(next));
  }
}

final gestureReaderModeProvider =
    NotifierProvider<GestureReaderModeNotifier, GestureReaderMode>(
      GestureReaderModeNotifier.new,
    );
```

Criar `lib/features/gestures/presentation/providers/gesture_reader_linear_provider.dart`:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../data/datasources/gesture_reader_preferences_datasource.dart';

/// Leitura linear (`true`, default) ou estruturada (`false`), persistida.
///
/// Linear = `linearizeGestureDocument` antes da página, do `flatten` e do
/// foco; estruturada = o documento como veio, com chaves e instruções.
class GestureReaderLinearNotifier extends Notifier<bool> {
  @override
  bool build() => _datasource.getLinear();

  GestureReaderPreferencesDatasource get _datasource =>
      GestureReaderPreferencesDatasource(ref.read(sharedPreferencesProvider));

  void toggle() {
    final next = !state;
    state = next;
    unawaited(_datasource.saveLinear(next));
  }
}

final gestureReaderLinearProvider =
    NotifierProvider<GestureReaderLinearNotifier, bool>(
      GestureReaderLinearNotifier.new,
    );
```

Criar `lib/features/gestures/presentation/providers/gesture_autoscroll_provider.dart`:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../data/datasources/gesture_reader_preferences_datasource.dart';
import '../../domain/entities/gesture_autoscroll_speed.dart';

/// Estado do autoscroll do leitor de gestos.
class GestureAutoscrollState {
  const GestureAutoscrollState({required this.running, required this.speed});

  final bool running;

  /// Entre [GestureAutoscrollSpeed.min] e [GestureAutoscrollSpeed.max].
  final int speed;

  GestureAutoscrollState copyWith({bool? running, int? speed}) =>
      GestureAutoscrollState(
        running: running ?? this.running,
        speed: speed ?? this.speed,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GestureAutoscrollState &&
          other.running == running &&
          other.speed == speed);

  @override
  int get hashCode => Object.hash(running, speed);
}

/// Liga/desliga e regula a velocidade do autoscroll dos gestos.
///
/// Como `ChordAutoscrollNotifier`: o motor (`Ticker`) mora no `State` da
/// tela; aqui fica só a intenção. `autoDispose` para o "ligado" não vazar
/// para a próxima abertura do leitor. A **velocidade**, ao contrário da
/// cifra, persiste: é a preferência da regente, não um ajuste de momento.
class GestureAutoscrollNotifier extends Notifier<GestureAutoscrollState> {
  @override
  GestureAutoscrollState build() => GestureAutoscrollState(
    running: false,
    speed: _datasource.getAutoscrollSpeed(),
  );

  GestureReaderPreferencesDatasource get _datasource =>
      GestureReaderPreferencesDatasource(ref.read(sharedPreferencesProvider));

  void toggle() => state = state.copyWith(running: !state.running);

  void setSpeed(int speed) {
    final clamped = GestureAutoscrollSpeed.clamp(speed);
    if (clamped == state.speed) return;
    state = state.copyWith(speed: clamped);
    unawaited(_datasource.saveAutoscrollSpeed(clamped));
  }

  /// Desliga sem notificar quando já estava parado.
  void stop() {
    if (!state.running) return;
    state = state.copyWith(running: false);
  }
}

final gestureAutoscrollProvider =
    NotifierProvider.autoDispose<GestureAutoscrollNotifier, GestureAutoscrollState>(
      GestureAutoscrollNotifier.new,
    );
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/unit/features/gestures && flutter analyze lib/features/gestures lib/core/constants`
Expected: todos passam, analyze limpo.

- [ ] **Step 5: Commit**

```bash
git add lib/core/constants/storage_keys.dart lib/features/gestures test/unit/features/gestures
git commit -m "feat(gestos): preferências e providers de tema, leitura linear e velocidade do autoscroll

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Cartão zebrado e centralizado; quadro da figura; gaps

**Files:**
- Modify: `lib/features/gestures/presentation/widgets/gesture_card_tile.dart`
- Modify: `lib/features/gestures/presentation/widgets/gesture_figure.dart`
- Modify: `lib/features/gestures/presentation/theme/gesture_reader_palette.dart` (constantes de gap)
- Modify: `lib/features/gestures/presentation/widgets/gesture_document_view.dart` (título com 20 abaixo)
- Test: `test/widget/features/gestures/gesture_card_tile_test.dart`, `test/widget/features/gestures/gesture_figure_test.dart`

**Interfaces:**
- Consumes: `GestureReaderPalette.stripe/figureBg/figureBorder` (Task 3).
- Produces: `Key gestureCardStripeKey(int index)` → `ValueKey('gesture-card-stripe-$index')` no `Material` que pinta a faixa.

- [ ] **Step 1: Testes que falham**

Em `test/widget/features/gestures/gesture_card_tile_test.dart`, **substituir** o teste `'figura à esquerda, uma LyricLineText por linha, alinhados pelo topo'` por:

```dart
  testWidgets('figura à esquerda, uma LyricLineText por linha, centralizados na vertical', (tester) async {
    await _pump(tester);
    expect(find.byType(LyricLineText), findsNWidgets(2));
    final figure = tester.getRect(find.byType(GestureFigure));
    final lyric = tester.getRect(find.byType(LyricLineText).first);
    expect(figure.left, lessThan(lyric.left));
    // Duas linhas de 18 (≈ 47 dp) são mais baixas que a figura (96): a coluna
    // de letra tem que ficar no meio da figura, não colada no topo.
    final column = tester.getRect(
      find.descendant(of: find.byType(GestureCardTile), matching: find.byType(Column)).first,
    );
    expect(column.height, lessThan(figure.height));
    expect(column.center.dy, closeTo(figure.center.dy, 0.5));
  });

  testWidgets('zebra: índice ímpar pinta a faixa, par fica transparente', (tester) async {
    await _pump(tester); // index 3
    final odd = tester.widget<Material>(find.byKey(gestureCardStripeKey(3)));
    expect(odd.color, _palette.stripe);
    expect(tester.getSize(find.byKey(gestureCardStripeKey(3))).width, 400);

    await _pump(tester, index: 2);
    final even = tester.widget<Material>(find.byKey(gestureCardStripeKey(2)));
    expect(even.color, Colors.transparent);
  });
```

E dar ao `_pump` um parâmetro `int index = 3` usado em `GestureCardTile(index: index, …)`.

Em `test/widget/features/gestures/gesture_figure_test.dart`, acrescentar:

```dart
  testWidgets('figura fica num quadro branco arredondado com borda da paleta', (tester) async {
    await _pump(tester, entry: _entry); // use o helper já existente no arquivo com uma entrada válida
    final box = tester.widget<Container>(find.byKey(gestureFigureFrameKey));
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.color, _palette.figureBg);
    expect(decoration.border, Border.all(color: _palette.figureBorder));
    expect(decoration.borderRadius, BorderRadius.circular(8));
    expect(tester.getSize(find.byType(GestureFigure)).width, 96);
  });
```

(Adapte o nome do helper/entrada ao que o arquivo já tem; o que importa é montar um `GestureFigure` com `entry` não nulo e bytes válidos.)

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/widget/features/gestures/gesture_card_tile_test.dart test/widget/features/gestures/gesture_figure_test.dart`
Expected: `gestureCardStripeKey`/`gestureFigureFrameKey` não definidos.

- [ ] **Step 3: Implementar o cartão**

Substituir o corpo de `lib/features/gestures/presentation/widgets/gesture_card_tile.dart`:

```dart
import 'package:flutter/material.dart';

import '../../domain/entities/gesture_dictionary.dart';
import '../../domain/entities/gesture_document.dart';
import '../theme/gesture_reader_palette.dart';
import 'gesture_figure.dart';
import 'lyric_line_text.dart';

/// Chave estável do cartão de índice [index] (o índice do `flatten`).
Key gestureCardKey(int index) => ValueKey('gesture-card-$index');

/// Chave do `Material` que pinta a faixa da zebra do cartão [index].
Key gestureCardStripeKey(int index) => ValueKey('gesture-card-stripe-$index');

/// Cartão de gesto: figura à esquerda, letra à direita, **centralizados na
/// vertical** — com 1 ou 3 linhas, a letra fica no meio da figura.
///
/// Ocupa a largura toda do nível e zebra pelo índice do `flatten`
/// (ímpar = [GestureReaderPalette.stripe]); é a zebra que separa os cartões,
/// por isso o gap entre eles é pequeno. A figura e **toda** a letra ficam no
/// mesmo cartão — a leitura é o que se canta enquanto o gesto dura.
/// [entry] já vem resolvido pelo dicionário; `null` mostra o placeholder.
class GestureCardTile extends StatelessWidget {
  const GestureCardTile({
    required this.index,
    required this.card,
    required this.entry,
    required this.fontSize,
    required this.palette,
    this.onTap,
    super.key,
  });

  final int index;
  final GestureCard card;
  final GestureEntry? entry;
  final double fontSize;
  final GestureReaderPalette palette;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final side = gestureFigureSide(fontSize);
    // `Material` colorido, não `DecoratedBox`: o ink do `InkWell` pinta no
    // `Material` mais próximo — assim o toque aparece sobre a faixa.
    return Material(
      key: gestureCardStripeKey(index),
      color: index.isOdd ? palette.stripe : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        key: gestureCardKey(index),
        onTap: onTap == null ? null : () => onTap!(index),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureFigure(
                entry: entry,
                gestureId: card.gestureId,
                side: side,
                palette: palette,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in card.lyrics)
                      LyricLineText(line: line, fontSize: fontSize, palette: palette),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Quadro da figura**

Em `lib/features/gestures/presentation/widgets/gesture_figure.dart`, acrescentar após `gesturePlaceholderKey`:

```dart
/// Chave do quadro branco que envolve a figura.
const Key gestureFigureFrameKey = ValueKey('gesture-figure-frame');
```

e trocar o `SizedBox(... child: ColoredBox(color: palette.figureBg, child: bytes.when(...)))` por:

```dart
    return SizedBox(
      width: side,
      height: side,
      // Quadro branco arredondado nos dois temas — a imagem tem fundo branco
      // e borda preta próprios; o padding evita a borda colar no arredondamento.
      child: Container(
        key: gestureFigureFrameKey,
        padding: const EdgeInsets.all(4),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: palette.figureBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: palette.figureBorder),
        ),
        child: bytes.when(
          // ... (inalterado)
        ),
      ),
    );
```

- [ ] **Step 5: Gaps e título**

Em `gesture_reader_palette.dart`:

```dart
/// Gap vertical entre cartões e entre blocos. Cartões têm gap pequeno porque a
/// zebra já os separa.
const double kGestureCardGap = 4;
const double kGestureBlockGap = 16;
```

Em `gesture_document_view.dart`, o `Padding` do título passa a `EdgeInsets.only(bottom: 20)`.

- [ ] **Step 6: Rodar e ver passar**

Run: `flutter analyze lib/features/gestures test/widget/features/gestures && flutter test test/widget/features/gestures`
Expected: passam. Se `gesture_document_view_test.dart` pinar o gap antigo (12/20) por posição, atualizar para 4/16.

- [ ] **Step 7: Commit**

```bash
git add lib/features/gestures test/widget/features/gestures
git commit -m "feat(gestos): cartão zebrado com figura e letra centralizadas; quadro branco da figura

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: `SectionLabelView` + l10n

**Files:**
- Create: `lib/features/gestures/presentation/widgets/section_label_view.dart`
- Modify: `lib/features/gestures/presentation/widgets/gesture_document_view.dart`
- Modify: `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb` (+ regenerar `app_localizations*.dart`)
- Test: `test/widget/features/gestures/section_label_view_test.dart` (novo)

**Interfaces:**
- Consumes: `SectionLabel` (Task 1), `palette.sectionLabel` (Task 3).
- Produces: `SectionLabelView({required SectionLabel label, required double fontSize, required GestureReaderPalette palette})`; l10n `gestureSectionChorus`, `gestureSectionPass(int n)`.

- [ ] **Step 1: l10n**

Em `lib/l10n/app_pt.arb`, após `"gestureFocusClose": "Fechar",`:

```json
  "gestureSectionChorus": "coro",
  "gestureSectionPass": "{n}ª vez",
  "@gestureSectionPass": {
    "placeholders": {
      "n": { "type": "int" }
    }
  },
```

Em `lib/l10n/app_en.arb`, após `"gestureFocusClose": "Close",`:

```json
  "gestureSectionChorus": "chorus",
  "gestureSectionPass": "time {n}",
  "@gestureSectionPass": {
    "placeholders": {
      "n": { "type": "int" }
    }
  },
```

Run: `flutter gen-l10n`
Expected: `lib/l10n/app_localizations*.dart` regenerados com `gestureSectionChorus` e `gestureSectionPass(int n)`.

- [ ] **Step 2: Teste que falha**

Criar `test/widget/features/gestures/section_label_view_test.dart`:

```dart
import 'package:coldigui/features/gestures/domain/entities/gesture_document.dart';
import 'package:coldigui/features/gestures/presentation/theme/gesture_reader_theme.dart';
import 'package:coldigui/features/gestures/presentation/widgets/section_label_view.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _palette = GestureReaderMode.light.palette;

Future<void> _pump(WidgetTester tester, SectionLabel label, {Locale locale = const Locale('pt')}) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: Scaffold(
        body: SizedBox(
          width: 360,
          child: SectionLabelView(label: label, fontSize: 20, palette: _palette),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('«coro» em caixa alta, pequeno, na cor da paleta', (tester) async {
    await _pump(tester, const SectionLabel.chorus());
    final text = tester.widget<Text>(find.text('CORO'));
    expect(text.style?.color, _palette.sectionLabel);
    expect(text.style?.fontSize, closeTo(14, 0.01)); // 20 × 0.7
    expect(text.style?.fontWeight, FontWeight.w600);
  });

  testWidgets('«2ª vez» em pt, «TIME 2» em en', (tester) async {
    await _pump(tester, const SectionLabel.pass(2));
    expect(find.text('2ª VEZ'), findsOneWidget);
    await _pump(tester, const SectionLabel.pass(2), locale: const Locale('en'));
    expect(find.text('TIME 2'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `flutter test test/widget/features/gestures/section_label_view_test.dart`
Expected: `section_label_view.dart` não existe.

- [ ] **Step 4: Implementar**

Criar `lib/features/gestures/presentation/widgets/section_label_view.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/gesture_document.dart';
import '../theme/gesture_reader_palette.dart';

/// Rótulo discreto da leitura linear («CORO», «2ª VEZ»): diz onde a regente
/// está na música sem virar marcação de salto — por isso é pequeno, cinza e
/// sem chave.
class SectionLabelView extends StatelessWidget {
  const SectionLabelView({
    required this.label,
    required this.fontSize,
    required this.palette,
    super.key,
  });

  final SectionLabel label;
  final double fontSize;
  final GestureReaderPalette palette;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pass = label.pass;
    final text = pass == null ? l10n.gestureSectionChorus : l10n.gestureSectionPass(pass);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: palette.sectionLabel,
          fontSize: fontSize * 0.7,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
```

Em `gesture_document_view.dart`, importar `section_label_view.dart` e trocar o caso provisório da Task 1:

```dart
      case SectionLabel():
        return SectionLabelView(
          label: item,
          fontSize: widget.fontSize,
          palette: widget.palette,
        );
```

- [ ] **Step 5: Rodar e ver passar**

Run: `flutter analyze lib/features/gestures && flutter test test/widget/features/gestures`
Expected: passam.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n lib/features/gestures test/widget/features/gestures/section_label_view_test.dart
git commit -m "feat(gestos): SectionLabelView — rótulo discreto «coro» / «kª vez» da leitura linear

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Tela — tema, leitura linear e barra nova

**Files:**
- Modify: `lib/features/gestures/presentation/pages/gesture_reader_screen.dart`
- Modify: `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb` (+ regenerar)
- Test: `test/widget/features/gestures/gesture_reader_screen_test.dart`

**Interfaces:**
- Consumes: `gestureReaderModeProvider`, `gestureReaderLinearProvider`, `gestureAutoscrollProvider` (Task 4), `linearizeGestureDocument` (Task 2), `palette` nos widgets (Task 3).
- Produces: barra com tooltips `gesturesReaderToggleTheme`, `gesturesReaderLinear`/`gesturesReaderStructured`, `gesturesAutoscrollPlay`/`Pause`; keys `gestureReaderThemeKey`, `gestureReaderLinearKey`, `gestureReaderAutoscrollKey`, `gestureReaderSpeedKey`. O botão de autoscroll só muda o provider; o motor entra na Task 8.

- [ ] **Step 1: l10n**

`app_pt.arb`, após `gestureSectionPass`:

```json
  "gesturesReaderToggleTheme": "Alternar tema do leitor",
  "gesturesReaderLinear": "Mudar para leitura linear",
  "gesturesReaderStructured": "Mudar para leitura estruturada",
  "gesturesAutoscrollPlay": "Iniciar rolagem automática",
  "gesturesAutoscrollPause": "Pausar rolagem automática",
  "gesturesAutoscrollSpeed": "Velocidade da rolagem: {speed}",
  "@gesturesAutoscrollSpeed": {
    "placeholders": {
      "speed": { "type": "int" }
    }
  },
```

`app_en.arb`:

```json
  "gesturesReaderToggleTheme": "Toggle reader theme",
  "gesturesReaderLinear": "Switch to linear reading",
  "gesturesReaderStructured": "Switch to structured reading",
  "gesturesAutoscrollPlay": "Start autoscroll",
  "gesturesAutoscrollPause": "Pause autoscroll",
  "gesturesAutoscrollSpeed": "Scroll speed: {speed}",
  "@gesturesAutoscrollSpeed": {
    "placeholders": {
      "speed": { "type": "int" }
    }
  },
```

Run: `flutter gen-l10n`.

- [ ] **Step 2: Testes que falham**

Em `test/widget/features/gestures/gesture_reader_screen_test.dart`, acrescentar imports:

```dart
import 'package:coldigui/features/gestures/presentation/providers/gesture_autoscroll_provider.dart';
import 'package:coldigui/features/gestures/presentation/providers/gesture_reader_linear_provider.dart';
import 'package:coldigui/features/gestures/presentation/providers/gesture_reader_mode_provider.dart';
import 'package:coldigui/features/gestures/presentation/theme/gesture_reader_theme.dart';
import 'package:coldigui/features/gestures/presentation/widgets/section_label_view.dart';
import 'package:coldigui/features/gestures/presentation/widgets/instruction_card_view.dart';
```

Dar ao `_pump` um parâmetro `Map<String, Object> prefs = const {}` usado em `SharedPreferences.setMockInitialValues(prefs)`. Acrescentar testes:

```dart
  testWidgets('tema: começa claro; o botão troca o papel e persiste', (tester) async {
    final prefs = await _pump(tester, document: () async => _fixture('182_quero_viver.json'));
    final container = _containerOf(tester);
    Color paper() => tester.widget<ColoredBox>(
      find.descendant(of: find.byType(GestureDocumentView), matching: find.byType(ColoredBox)).first,
    ).color;

    expect(paper(), GestureReaderMode.light.palette.paper);
    await tester.tap(find.byKey(gestureReaderThemeKey));
    await tester.pump();
    expect(container.read(gestureReaderModeProvider), GestureReaderMode.dark);
    expect(paper(), GestureReaderMode.dark.palette.paper);
    expect(prefs.getString(StorageKeys.gestureReaderMode), 'dark');
  });

  testWidgets('linear por padrão: 182 mostra o coro 3 vezes e nenhuma instrução', (tester) async {
    await _pump(tester, document: () async => _fixture('182_quero_viver.json'));
    expect(find.byType(SectionLabelView), findsNWidgets(3));
    expect(find.byType(InstructionCardView), findsNothing);
    expect(find.byType(GestureCardTile), findsNWidgets(24));
  });

  testWidgets('estruturado: botão desliga o linear, some o rótulo e volta a instrução', (tester) async {
    final prefs = await _pump(tester, document: () async => _fixture('182_quero_viver.json'));
    await tester.tap(find.byKey(gestureReaderLinearKey));
    await tester.pumpAndSettle();
    expect(_containerOf(tester).read(gestureReaderLinearProvider), isFalse);
    expect(prefs.getBool(StorageKeys.gestureReaderLinear), isFalse);
    expect(find.byType(SectionLabelView), findsNothing);
    expect(find.byType(InstructionCardView), findsNWidgets(2));
    expect(find.byType(GestureCardTile), findsNWidgets(14));
  });

  testWidgets('foco em linear abre no cartão expandido (índice 20 existe)', (tester) async {
    await _pump(tester, document: () async => _fixture('182_quero_viver.json'));
    await tester.scrollUntilVisible(find.byKey(gestureCardKey(20)), 200);
    await tester.tap(find.byKey(gestureCardKey(20)));
    await tester.pumpAndSettle();
    expect(find.byKey(gestureFocusPageKey(20)), findsOneWidget);
    await tester.tap(find.byKey(gestureFocusCloseKey));
    await tester.pumpAndSettle();
  });

  testWidgets('barra: play alterna o provider; velocidade cicla 3→4→5→1 e persiste', (tester) async {
    final prefs = await _pump(tester, document: () async => _fixture('182_quero_viver.json'));
    final container = _containerOf(tester);
    expect(find.byTooltip('Iniciar rolagem automática'), findsOneWidget);
    await tester.tap(find.byKey(gestureReaderAutoscrollKey));
    await tester.pump();
    expect(container.read(gestureAutoscrollProvider).running, isTrue);
    expect(find.byTooltip('Pausar rolagem automática'), findsOneWidget);
    await tester.tap(find.byKey(gestureReaderAutoscrollKey));
    await tester.pump();
    expect(container.read(gestureAutoscrollProvider).running, isFalse);

    expect(find.text('3x'), findsOneWidget);
    await tester.tap(find.byKey(gestureReaderSpeedKey));
    await tester.pump();
    expect(find.text('4x'), findsOneWidget);
    await tester.tap(find.byKey(gestureReaderSpeedKey));
    await tester.tap(find.byKey(gestureReaderSpeedKey));
    await tester.pump();
    expect(find.text('1x'), findsOneWidget);
    expect(prefs.getInt(StorageKeys.gestureAutoscrollSpeed), 1);
  });
```

(`_fixture` = `parseGestureDocument(_read(name))`; se o arquivo já tem um helper equivalente, use-o.)

- [ ] **Step 3: Rodar e ver falhar**

Run: `flutter test test/widget/features/gestures/gesture_reader_screen_test.dart`
Expected: keys não definidas.

- [ ] **Step 4: Implementar a tela**

Em `lib/features/gestures/presentation/pages/gesture_reader_screen.dart`:

Imports novos:

```dart
import '../../domain/entities/gesture_autoscroll_speed.dart';
import '../../domain/usecases/linearize_gesture_document.dart';
import '../providers/gesture_autoscroll_provider.dart';
import '../providers/gesture_reader_linear_provider.dart';
import '../providers/gesture_reader_mode_provider.dart';
import '../theme/gesture_reader_palette.dart';
import '../theme/gesture_reader_theme.dart';
```

Keys, após `gestureReaderRetryKey`:

```dart
const Key gestureReaderThemeKey = ValueKey('gesture-reader-theme');
const Key gestureReaderLinearKey = ValueKey('gesture-reader-linear');
const Key gestureReaderAutoscrollKey = ValueKey('gesture-reader-autoscroll');
const Key gestureReaderSpeedKey = ValueKey('gesture-reader-speed');

const _toolbarGroupGap = 8.0;
const _speedLabelWidth = 34.0;
```

Atualizar a docstring da classe: barra 3 agora tem `A-`/`A+`, autoscroll, linear/estruturado, tema e tela cheia.

No `build`:

```dart
    final l10n = AppLocalizations.of(context)!;
    final mode = ref.watch(gestureReaderModeProvider);
    final palette = mode.palette;
    final linear = ref.watch(gestureReaderLinearProvider);
    final autoscroll = ref.watch(gestureAutoscrollProvider);
    final fontSize = ref.watch(gestureReaderFontSizeProvider);
    // ...
        child: Material(
          type: MaterialType.transparency,
          child: ColoredBox(
            color: palette.paper,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _GestureReaderToolbar(
                    mode: mode,
                    palette: palette,
                    fontSize: fontSize,
                    linear: linear,
                    autoscroll: autoscroll,
                    l10n: l10n,
                  ),
                  Expanded(
                    child: docAsync.when(
                      loading: () => Center(
                        child: CircularProgressIndicator(color: palette.toolbarIcon),
                      ),
                      error: (_, _) => _Message(
                        message: l10n.gesturesReaderUnavailable,
                        color: palette.sectionLabel,
                        onTap: () { /* inalterado */ },
                        key: gestureReaderRetryKey,
                      ),
                      data: (document) {
                        if (document == null) {
                          return _Message(message: l10n.gesturesReaderEmpty, color: palette.sectionLabel);
                        }
                        if (dictionary.byId.isNotEmpty) {
                          _maybePrefetch(document, dictionary);
                        }
                        // Leitura linear: expande antes da página, do flatten
                        // e do foco, para os três falarem do mesmo índice.
                        final shown = linear ? linearizeGestureDocument(document) : document;
                        final flat = flattenGestureCards(shown);
                        return Column(
                          children: [
                            if (document.isNewerSchema) const NewerSchemaBanner(),
                            Expanded(
                              child: GestureDocumentView(
                                key: _documentViewKey,
                                document: shown,
                                dictionary: dictionary,
                                fontSize: fontSize,
                                palette: palette,
                                onCardTap: flat.isEmpty
                                    ? null
                                    : (index) => _openFocus(flat, dictionary, index, fontSize, palette),
                              ),
                            ),
                          ],
                        );
                      },
```

`_openFocus` ganha o parâmetro `GestureReaderPalette palette` e repassa `palette: palette` a `showGestureFocus`. `_Message` ganha `required this.color` e usa `color:` no lugar de `AppColors.textLight`. Remover o import de `color_extensions.dart` se ficar sem uso.

Substituir `_GestureReaderToolbar` inteira:

```dart
/// Barra 3: corpo da letra, autoscroll, linear/estruturado, tema, tela cheia.
///
/// Espelho de `_ChordReaderToolbar`: ícones na cor da paleta e um traço entre
/// grupos — sem ele os botões se leem como uma fileira de controles iguais.
class _GestureReaderToolbar extends ConsumerWidget {
  const _GestureReaderToolbar({
    required this.mode,
    required this.palette,
    required this.fontSize,
    required this.linear,
    required this.autoscroll,
    required this.l10n,
  });

  final GestureReaderMode mode;
  final GestureReaderPalette palette;
  final double fontSize;
  final bool linear;
  final GestureAutoscrollState autoscroll;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = ref.read(gestureReaderFontSizeProvider.notifier);
    final autoscrollNotifier = ref.read(gestureAutoscrollProvider.notifier);
    final style = _toolbarButtonStyle(palette.toolbarIcon);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _toolbarGroupGap),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            style: style,
            tooltip: l10n.gesturesReaderDecreaseFont,
            icon: const Icon(Icons.text_decrease),
            onPressed: GestureReaderFontSize.canDecrease(fontSize) ? size.decrease : null,
          ),
          IconButton(
            style: style,
            tooltip: l10n.gesturesReaderIncreaseFont,
            icon: const Icon(Icons.text_increase),
            onPressed: GestureReaderFontSize.canIncrease(fontSize) ? size.increase : null,
          ),
          _ToolbarSeparator(color: palette.divider),
          IconButton(
            key: gestureReaderAutoscrollKey,
            style: style,
            tooltip: autoscroll.running ? l10n.gesturesAutoscrollPause : l10n.gesturesAutoscrollPlay,
            icon: Icon(autoscroll.running ? Icons.pause_circle_outline : Icons.play_circle_outline),
            onPressed: autoscrollNotifier.toggle,
          ),
          SizedBox(
            width: _speedLabelWidth,
            // TextButton, não InkWell: traz o próprio Material.
            child: TextButton(
              key: gestureReaderSpeedKey,
              onPressed: () => autoscrollNotifier.setSpeed(
                autoscroll.speed >= GestureAutoscrollSpeed.max
                    ? GestureAutoscrollSpeed.min
                    : autoscroll.speed + 1,
              ),
              style: TextButton.styleFrom(
                foregroundColor: palette.toolbarIcon,
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
                minimumSize: const Size(_speedLabelWidth, 40),
                textStyle: AppTypography.label.copyWith(fontWeight: FontWeight.w700),
              ),
              child: Tooltip(
                message: l10n.gesturesAutoscrollSpeed(autoscroll.speed),
                child: Text('${autoscroll.speed}x'),
              ),
            ),
          ),
          _ToolbarSeparator(color: palette.divider),
          IconButton(
            key: gestureReaderLinearKey,
            style: style,
            // O ícone mostra o estado atual; o tooltip, a ação.
            tooltip: linear ? l10n.gesturesReaderStructured : l10n.gesturesReaderLinear,
            icon: Icon(linear ? Icons.view_agenda_outlined : Icons.account_tree_outlined),
            onPressed: () => ref.read(gestureReaderLinearProvider.notifier).toggle(),
          ),
          _ToolbarSeparator(color: palette.divider),
          IconButton(
            key: gestureReaderThemeKey,
            style: style,
            tooltip: l10n.gesturesReaderToggleTheme,
            icon: Icon(mode == GestureReaderMode.light ? Icons.dark_mode : Icons.light_mode),
            onPressed: () => ref.read(gestureReaderModeProvider.notifier).toggle(),
          ),
          IconButton(
            style: style,
            tooltip: l10n.gesturesReaderFullscreen,
            icon: const Icon(Icons.fullscreen),
            onPressed: () => ref.read(toggleReaderFullscreenProvider).call(),
          ),
        ],
      ),
    );
  }
}

/// Traço entre grupos de controles.
class _ToolbarSeparator extends StatelessWidget {
  const _ToolbarSeparator({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: _toolbarGroupGap / 2),
      color: color,
    );
  }
}
```

- [ ] **Step 5: Rodar e ver passar**

Run: `flutter analyze lib/features/gestures && flutter test test/widget/features/gestures/gesture_reader_screen_test.dart`
Expected: passam, inclusive os testes antigos (o do foco tapa `gestureCardKey(2)`, que existe nos dois modos).

Se `scrollUntilVisible` não achar o cartão 20 por a viewport de teste ser alta o bastante, trocar por `await tester.ensureVisible(find.byKey(gestureCardKey(20)))`.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n lib/features/gestures test/widget/features/gestures/gesture_reader_screen_test.dart
git commit -m "feat(gestos): tema claro/escuro, leitura linear e barra nova no leitor

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Motor do autoscroll com retomada após rolagem manual

**Files:**
- Modify: `lib/features/gestures/presentation/pages/gesture_reader_screen.dart`
- Test: `test/widget/features/gestures/gesture_reader_screen_test.dart`

**Interfaces:**
- Consumes: `gestureAutoscrollProvider` (Task 4), `GestureAutoscrollSpeed.pxPerSecondPerLevel`, `GestureDocumentView.scrollController` (já existe).
- Produces: atalhos `S`, `[`, `]`; `kGestureAutoscrollResumeDelay = Duration(seconds: 1)`.

- [ ] **Step 1: Testes que falham**

Acrescentar ao `gesture_reader_screen_test.dart` um grupo. Documento longo: linear do 182 já dá 24 cartões (~2600 px em fonte 18) — basta a viewport ser baixa.

```dart
  group('autoscroll em execução', () {
    Future<void> pumpShort(WidgetTester tester, {Map<String, String>? queryParams}) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pump(tester, document: () async => _fixture('182_quero_viver.json'), queryParams: queryParams);
    }

    double offset(WidgetTester tester) =>
        tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;

    Future<void> stopAndSettle(WidgetTester tester) async {
      _containerOf(tester).read(gestureAutoscrollProvider.notifier).stop();
      await tester.pump();
    }

    testWidgets('avança com o tempo a 10 px/s por nível', (tester) async {
      await pumpShort(tester);
      final container = _containerOf(tester);
      container.read(gestureAutoscrollProvider.notifier).setSpeed(2);
      container.read(gestureAutoscrollProvider.notifier).toggle();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16)); // 1º tick só marca o relógio
      await tester.pump(const Duration(seconds: 1));
      expect(offset(tester), closeTo(20, 2));
      await stopAndSettle(tester);
    });

    testWidgets('para ao chegar no fim', (tester) async {
      await pumpShort(tester);
      final container = _containerOf(tester);
      container.read(gestureAutoscrollProvider.notifier).setSpeed(5);
      container.read(gestureAutoscrollProvider.notifier).toggle();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(minutes: 5));
      expect(container.read(gestureAutoscrollProvider).running, isFalse);
    });

    testWidgets('rolagem manual pausa; 1 s depois do fim do gesto retoma da posição nova', (tester) async {
      await pumpShort(tester);
      final container = _containerOf(tester);
      container.read(gestureAutoscrollProvider.notifier).toggle();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 500));
      final before = offset(tester);
      expect(before, greaterThan(0));

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
      await tester.pump();
      final afterDrag = offset(tester);
      expect(afterDrag, greaterThan(before + 100));
      // Continua "ligado" — o botão não volta a play.
      expect(container.read(gestureAutoscrollProvider).running, isTrue);

      // Dentro do 1 s: parado onde o dedo deixou.
      await tester.pump(const Duration(milliseconds: 500));
      expect(offset(tester), afterDrag);

      // Passado o 1 s: volta a andar, a partir dali.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 500));
      expect(offset(tester), greaterThan(afterDrag));
      // Um tick de ~600 ms + um de 500 ms a 30 px/s ≈ 33 px: partiu dali,
      // não de onde "estaria" sem a pausa.
      expect(offset(tester), lessThan(afterDrag + 60));
      await stopAndSettle(tester);
    });

    testWidgets('novo gesto antes de 1 s rearma a espera', (tester) async {
      await pumpShort(tester);
      final container = _containerOf(tester);
      container.read(gestureAutoscrollProvider.notifier).toggle();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -100));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -100));
      await tester.pump();
      final afterSecond = offset(tester);
      await tester.pump(const Duration(milliseconds: 700));
      expect(offset(tester), afterSecond); // 700 ms < 1 s desde o 2º gesto
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 300));
      expect(offset(tester), greaterThan(afterSecond));
      await stopAndSettle(tester);
    });

    testWidgets('trocar de louvor para o autoscroll', (tester) async {
      await pumpShort(tester, queryParams: {'pdfId': encodePdfId(_r2Key), 'titulo': 'A'});
      final container = _containerOf(tester);
      container.read(gestureAutoscrollProvider.notifier).toggle();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 200));
      expect(container.read(gestureAutoscrollProvider).running, isTrue);

      await pumpShort(tester, queryParams: {'pdfId': encodePdfId('assets/praises/p1/m2.gestures'), 'titulo': 'B'});
      expect(container.read(gestureAutoscrollProvider).running, isFalse);
    });

    testWidgets('S liga/desliga; [ e ] regulam a velocidade', (tester) async {
      await pumpShort(tester);
      final container = _containerOf(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.pump();
      expect(container.read(gestureAutoscrollProvider).running, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.pump();
      expect(container.read(gestureAutoscrollProvider).running, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
      await tester.pump();
      expect(container.read(gestureAutoscrollProvider).speed, 4);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      await tester.pump();
      expect(container.read(gestureAutoscrollProvider).speed, 2);
    });
  });
```

O teste de troca de louvor reaproveita o padrão já existente no arquivo (o de `prefetch` com `_CountingFigureRepository`): se `_pump` remonta o `ProviderScope` a cada chamada, o `autoDispose` já zera o `running` — então o teste precisa remontar **só** o `GestureReaderScreen` dentro do mesmo `ProviderScope`, como o teste de prefetch faz com `buildApp(...)`. Siga aquele padrão.

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/widget/features/gestures/gesture_reader_screen_test.dart --name autoscroll`
Expected: `offset` não cresce / `S` não faz nada.

- [ ] **Step 3: Implementar o motor**

Em `gesture_reader_screen.dart`:

Imports: `dart:async`, `package:flutter/scheduler.dart` (Ticker), `../../../app_shell/presentation/widgets/app_shortcuts.dart` (já importado; usa `keyboardFocusIsInsideTextField`).

Constante, junto das keys:

```dart
/// Quanto esperar depois que o dedo solta a página antes de voltar a rolar.
const Duration kGestureAutoscrollResumeDelay = Duration(seconds: 1);
```

`State` com `SingleTickerProviderStateMixin` e campos:

```dart
class _GestureReaderScreenState extends ConsumerState<GestureReaderScreen>
    with SingleTickerProviderStateMixin {
  // ... campos existentes
  final ScrollController _scrollController = ScrollController();
  Ticker? _autoscrollTicker;
  Duration? _autoscrollLastTick;

  /// Rolagem manual em curso (ou dentro do 1 s de espera). O `Ticker` continua
  /// vivo, só deixa de mover a página — assim a retomada parte de onde o
  /// dedo deixou, sem guardar alvo nenhum.
  var _pausedByUser = false;
  Timer? _resumeTimer;
```

`didUpdateWidget`: após o bloco existente, `if (_r2Key != _r2KeyOf(oldWidget.queryParams)) { _prefetched = false; _stopAutoscroll(); }` (junte ao `if` já existente).

`dispose`: `_resumeTimer?.cancel(); _autoscrollTicker?.dispose(); _scrollController.dispose();` antes do `_keyboardFocusNode.dispose()`.

Métodos:

```dart
  /// `Ticker`, não `Timer`: sincroniza com o vsync e morre com o `State`.
  void _ensureAutoscrollTicker() {
    _autoscrollTicker ??= createTicker(_onAutoscrollTick);
    if (!_autoscrollTicker!.isActive) {
      _autoscrollLastTick = null;
      _autoscrollTicker!.start();
    }
  }

  void _onAutoscrollTick(Duration elapsed) {
    final lastTick = _autoscrollLastTick;
    _autoscrollLastTick = elapsed;
    if (lastTick == null) return; // primeiro tick só marca o relógio.

    final state = ref.read(gestureAutoscrollProvider);
    if (!state.running) {
      _autoscrollTicker?.stop();
      return;
    }
    if (_pausedByUser || !_scrollController.hasClients) return;

    final dtSeconds = (elapsed - lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    if (dtSeconds <= 0) return;

    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) {
      ref.read(gestureAutoscrollProvider.notifier).stop();
      return;
    }
    final delta = state.speed * GestureAutoscrollSpeed.pxPerSecondPerLevel * dtSeconds;
    final next = (position.pixels + delta).clamp(0.0, position.maxScrollExtent);
    _scrollController.jumpTo(next);
    if (next >= position.maxScrollExtent) {
      ref.read(gestureAutoscrollProvider.notifier).stop();
    }
  }

  /// Troca de louvor: o motor para na hora, o provider no próximo frame
  /// (Riverpod proíbe escrever provider dentro de `didUpdateWidget`).
  void _stopAutoscroll() {
    _autoscrollTicker?.stop();
    _resumeTimer?.cancel();
    _resumeTimer = null;
    _pausedByUser = false;
    if (!ref.read(gestureAutoscrollProvider).running) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(gestureAutoscrollProvider.notifier).stop();
    });
  }

  /// Dedo/roda na página: pausa; 1 s depois do fim do gesto, volta de onde
  /// a página ficou. Só o `UserScrollNotification` com direção diz "é o
  /// usuário" — o `jumpTo` do motor emite `ScrollEnd`, mas nunca direção.
  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is UserScrollNotification &&
        notification.direction != ScrollDirection.idle) {
      _pausedByUser = true;
      _resumeTimer?.cancel();
      _resumeTimer = null;
    } else if (notification is ScrollEndNotification &&
        _pausedByUser &&
        _resumeTimer == null) {
      _resumeTimer = Timer(kGestureAutoscrollResumeDelay, () {
        _resumeTimer = null;
        if (!mounted) return;
        _pausedByUser = false;
      });
    }
    return false;
  }
```

(`ScrollDirection` vem de `package:flutter/rendering.dart`.)

`_onKeyEvent`: depois do bloco com modificador (que retorna `ignored` no fim), acrescentar antes do `return KeyEventResult.ignored;` final — reestruturando para que o bloco com modificador só rode quando há modificador:

```dart
    if (keyboard.isControlPressed || keyboard.isMetaPressed) {
      // ... os quatro `if` existentes ...
      return KeyEventResult.ignored;
    }
    // `S`, `[`, `]` sem modificador — como na cifra, não valem com o foco
    // num campo de texto. As setas sem modificador ficam para o modo foco.
    if (!keyboardFocusIsInsideTextField()) {
      final notifier = ref.read(gestureAutoscrollProvider.notifier);
      if (key == LogicalKeyboardKey.keyS) {
        notifier.toggle();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.bracketRight) {
        notifier.setSpeed(ref.read(gestureAutoscrollProvider).speed + 1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.bracketLeft) {
        notifier.setSpeed(ref.read(gestureAutoscrollProvider).speed - 1);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
```

No `build`, antes do `return Focus(...)`:

```dart
    // Liga/desliga o motor junto da intenção — o provider só guarda o estado.
    ref.listen<GestureAutoscrollState>(gestureAutoscrollProvider, (previous, next) {
      if (next.running) {
        _ensureAutoscrollTicker();
      } else {
        _autoscrollTicker?.stop();
        _resumeTimer?.cancel();
        _resumeTimer = null;
        _pausedByUser = false;
      }
    });
```

E envolver a `GestureDocumentView` (passando `scrollController: _scrollController`):

```dart
                            Expanded(
                              child: NotificationListener<ScrollNotification>(
                                onNotification: _onScrollNotification,
                                child: GestureDocumentView(
                                  key: _documentViewKey,
                                  document: shown,
                                  dictionary: dictionary,
                                  fontSize: fontSize,
                                  palette: palette,
                                  scrollController: _scrollController,
                                  onCardTap: ...,
                                ),
                              ),
                            ),
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter analyze lib/features/gestures && flutter test test/widget/features/gestures/gesture_reader_screen_test.dart`
Expected: todos passam. Se o teste de retomada falhar na asserção `offset == afterDrag` dentro do 1 s, verifique se o `drag` gerou um fling (ballistic) — use `tester.timedDrag(..., const Duration(milliseconds: 300))` para um arrasto sem inércia.

- [ ] **Step 5: Commit**

```bash
git add lib/features/gestures test/widget/features/gestures/gesture_reader_screen_test.dart
git commit -m "feat(gestos): autoscroll que pausa na rolagem manual e retoma 1 s depois

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: Verificação completa e validação em produção

**Files:**
- Modify (se necessário): qualquer arquivo apontado pelo `analyze`/suíte.
- Modify: `docs/features/FEATURE_INDEX.md` (se listar o leitor de gestos, uma linha sobre tema/linear/autoscroll).

- [ ] **Step 1: Analyze e suíte inteira**

Run: `flutter analyze && flutter test`
Expected: sem issues; tudo verde. Testes fora de `gestures` que quebrem por causa da paleta (ex.: `material_sheet_test`, `open_gesture_in_reader_test`) devem ser corrigidos passando `palette`.

- [ ] **Step 2: Build web**

Run: `flutter build web --release 2>&1 | tail -5`
Expected: build ok (a tela é usada em produção web).

- [ ] **Step 3: Validação manual em produção v2 (regra do projeto: validar em `v2.plpcg.com`, aba visível, não em build local)**

Depois do merge e deploy pelo fluxo habitual do repo, no celular:

1. Abrir um louvor com coro + «voltar ao coro» (ex.: 182). Linear ligado por padrão: o coro aparece 3× com «CORO» acima; nenhuma instrução cinza.
2. Botão linear/estruturado: volta às chaves e às instruções; posição de rolagem pode mudar (aceito).
3. Tema escuro: papel carvão, texto claro, figura em quadro branco, zebra visível; barra com ícones dourados. Persistir ao reabrir.
4. Zebra: linhas ímpares com faixa; letra centralizada verticalmente em cartões de 1 e de 3 linhas.
5. Autoscroll: play → desce devagar; `3x` → `4x` mais rápido; arrastar com o dedo pausa; 1 s após soltar, retoma de onde parou; no fim, o botão volta a play.
6. Foco (toque no cartão) em linear: sem chips `2x`/`CORO`; fechar rola até o cartão certo.
7. Teclado (web desktop): `S`, `[`, `]`, `Ctrl+↑/↓`.

- [ ] **Step 4: Registrar**

Anotar em `docs/features/FEATURE_INDEX.md` (se houver entrada do leitor de gestos) a linha: «v2 (2026-09-15): tema claro/escuro local, leitura linear (default), autoscroll com retomada, zebra». Commit:

```bash
git add docs
git commit -m "docs(gestos): FEATURE_INDEX — leitor de gestos v2

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

Depois, seguir `superpowers:finishing-a-development-branch` para integrar `worktree-leitor-gestos-v2` em `web/integration`.

# Leitor de Gestos CIAs — plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tela `/gestos` que renderiza o documento JSON de gestos de um louvor (figura + letra com gatilho vermelho, blocos com chaves) com modo foco, funcionando offline depois do primeiro acesso.

**Architecture:** Feature nova `lib/features/gestures/` em camadas (domain → data → presentation). Documento e dicionário cacheados em Isar (espelho de `ChordContentCache`); figuras PNG em store próprio nativo (filesystem) / web (Cache API). `GestureMaterialRef` entra na `sealed CatalogMaterial`; adapter, caches em memória, sheet, playlist e carousel aprendem o material novo. Blocos desenhados com `Stack` + `Positioned.fill` (sem `IntrinsicHeight`); `gestureId` resolvido na renderização via `GestureDictionary.resolve`.

**Tech Stack:** Flutter 3.44, Riverpod 3 (`Notifier`, `FutureProvider.autoDispose.family` com `retry`), go_router 17, isar_plus 1.3 (`build_runner`), Dio 5, path_provider, `package:web` (Cache API), shared_preferences, flutter_localizations (`flutter gen-l10n`, template `app_pt.arb`).

**Spec:** `docs/superpowers/specs/2026-09-11-leitor-gestos-design.md` — leia a spec inteira antes de qualquer tarefa; as seções 3 (contrato) e 4 (regras de renderização) são fixas.

## Global Constraints

- Todo comando de teste: `flutter test --dart-define-from-file=dart_defines/plpcg.json <caminho>`; ao fim de cada tarefa, `flutter analyze` deve estar limpo.
- Lints: `package:flutter_lints/flutter.yaml` + `prefer_single_quotes` + `avoid_print`. Comentários e docs em português, no estilo dos arquivos vizinhos (explicar o *porquê*, não o *o quê*).
- Não importar pacotes que não estão em `dependencies` do `pubspec.yaml` (ex.: `crypto` é só transitivo — **não usar**).
- Isar: depois de criar/alterar uma `@Collection()`, rodar `dart run build_runner build --delete-conflicting-outputs` e commitar o `.g.dart`.
- l10n: `lib/l10n/app_pt.arb` é o template; toda chave nova entra em `app_pt.arb` **e** `app_en.arb`; depois `flutter gen-l10n`. Os `app_localizations*.dart` gerados são commitados (já estão no repo).
- Cores da spec §4 são literais fixos: gatilho `#D32F2F`, leitura `#1A1A1A`, azul `#1E63C8`, laranja `#E08A1E`, vinho `#6A2F2F`, instrução fundo `#F3F4F6` texto `#374151` borda `#D1D5DB`, placeholder fundo `#FFF7E6` borda `#E0B45C`, texto livre `#6B7280`, papel `#FFFFFF`.
- Fonte do leitor: base 18, faixa 14–28, passo 2. Figura: lado `96 × (fonte / 18)` dp. Largura máxima da página 720 dp, margens 16 dp. Gap entre cartões 12 dp, entre blocos 20 dp. Coluna da chave 28 dp; conector de ligação 20 dp.
- Commits: um por tarefa, mensagem no padrão `feat(gestures): …` / `test(gestures): …`, terminando com as duas linhas de trailer:
  ```
  Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01DuSVKfiGsabi168JixJLB1
  ```
- Nunca `git add -A` cego: adicione os arquivos da tarefa pelo nome (o repo tem `.claude/` e `tmp/` soltos).
- **A branch recebe commits de outra sessão em paralelo.** Antes de cada tarefa, `git log --oneline -5` e releia os arquivos que vai modificar — números de linha e nomes citados aqui são de 2026-09-11 e podem ter andado. Se um arquivo citado não existir mais, procure para onde a responsabilidade foi (`grep -rn`) e siga o padrão novo; anote a divergência no relatório da tarefa.

## Mapa de arquivos

```
lib/features/gestures/
  domain/entities/gesture_document.dart            T1
  domain/usecases/parse_gesture_document.dart      T1
  domain/entities/gesture_dictionary.dart          T2
  domain/usecases/parse_gesture_dictionary.dart    T2
  domain/entities/flat_gesture_card.dart           T3
  domain/utils/flatten_gesture_cards.dart          T3
  domain/entities/gesture_material.dart            T4
  domain/entities/gesture_reader_font_size.dart    T4
  data/datasources/gesture_content_local_datasource.dart      T5
  data/datasources/gesture_dictionary_local_datasource.dart   T5
  data/datasources/gesture_content_datasource.dart            T6
  data/datasources/gesture_dictionary_datasource.dart         T6
  data/constants/gesture_dictionary_config.dart               T6
  data/datasources/gesture_figure_store.dart                  T7
  data/datasources/gesture_figure_store_native.dart           T7
  data/datasources/gesture_figure_store_web.dart              T7
  data/repositories/gesture_figure_repository.dart            T7
  data/datasources/gesture_reader_preferences_datasource.dart T8
  data/providers/gesture_providers.dart                       T8
  presentation/providers/gesture_reader_font_size_provider.dart T8
  presentation/theme/gesture_reader_palette.dart   T9
  presentation/widgets/lyric_line_text.dart        T9
  presentation/widgets/gesture_figure.dart         T9
  presentation/widgets/gesture_card_tile.dart      T9
  presentation/widgets/brace_painter.dart          T10
  presentation/widgets/link_connector_painter.dart T10
  presentation/widgets/repeat_block_view.dart      T10
  presentation/widgets/chorus_block_view.dart      T10
  presentation/widgets/link_block_view.dart        T10
  presentation/widgets/final_section_view.dart     T10
  presentation/widgets/instruction_card_view.dart  T10
  presentation/widgets/text_line_view.dart         T10
  presentation/widgets/gesture_document_view.dart  T11
  presentation/widgets/newer_schema_banner.dart    T11
  presentation/pages/gesture_reader_screen.dart    T12
  presentation/utils/open_gesture_in_reader.dart   T12
  presentation/widgets/gesture_focus_view.dart     T15
lib/core/database/collections/gesture_document_cache.dart    T5
lib/core/database/collections/gesture_dictionary_cache.dart  T5
lib/core/utils/gesture_reader_url_builder.dart               T12
test/fixtures/gestures/{182_quero_viver,181_jerusalem,sintetico_final_link,schema_v2,dictionary}.json  T1/T2
```

Encaixes fora da feature: T4 (`material_id_kind`, `storage_keys`), T5 (`isar_app_schemas`), T12 (`route_paths`, `app_router`, `stage_wakelock`, `shell_scaffold`, `app_shortcuts`, l10n), T13 (`catalog_material`, `louvor_group`, `louvor_material_icons`, `material_sheet_actions`, `carousel_swap_material_button`, adapter, `coldigom_providers`, `coldigom_cache_writer`, `coldigom_search_repository*`, `coldigom_catalog_source`, `coldigom_catalog_source_provider`, `find_louvor_group_by_pdf_id`, `open_material_provider`, `reader_carousel_actions_provider`), T14 (`material_sheet`, l10n), T16 (docs).

---

### Task 1: Entidades do documento + parser tolerante + fixtures

**Files:**
- Create: `lib/features/gestures/domain/entities/gesture_document.dart`
- Create: `lib/features/gestures/domain/usecases/parse_gesture_document.dart`
- Create: `test/fixtures/gestures/182_quero_viver.json`, `test/fixtures/gestures/181_jerusalem.json`, `test/fixtures/gestures/sintetico_final_link.json`, `test/fixtures/gestures/schema_v2.json`
- Test: `test/unit/features/gestures/parse_gesture_document_test.dart`

**Interfaces:**
- Produces: `GestureDocument { int schemaMajor; String title; int dictionaryVersion; List<GestureItem> items; bool isNewerSchema; bool hasGestures }`; `sealed GestureItem` com `GestureCard(gestureId, lyrics)`, `RepeatBlock(count, children)`, `ChorusBlock(children)`, `LinkBlock(children)`, `FinalBlock(children)`, `InstructionCard(kind)`, `TextLine(text)`; `LyricLine(trigger, text)`; `enum InstructionKind { instruments, repeatPraise, backToChorus, backToChorusAndFinish }`; `GestureDocument parseGestureDocument(String json)` (lança `GestureDocumentParseException`); `int parseSchemaMajor(Object? schema)`.

- [ ] **Step 1: Criar os fixtures**

`test/fixtures/gestures/182_quero_viver.json` — copiar **exatamente** o JSON da spec §3.1 ("Exemplo real (182…)"): 12 itens de raiz, 14 cartões. Não altere ids nem letras.

`test/fixtures/gestures/181_jerusalem.json`:

```json
{
  "schema": "coldigom.gestures/1",
  "title": "181 - JERUSALÉM",
  "dictionaryVersion": 1,
  "items": [
    { "type": "gesture", "gestureId": "a1b2c3d4e5f6", "lyrics": [{ "trigger": "Jerusalém,", "text": "cidade santa," }] },
    { "type": "gesture", "gestureId": "b2c3d4e5f6a7", "lyrics": [{ "trigger": "onde", "text": "o Senhor habitará." }] },
    { "type": "gesture", "gestureId": "c3d4e5f6a7b8", "lyrics": [{ "trigger": "Suas", "text": "portas nunca se fecharão," }] },
    { "type": "gesture", "gestureId": "d4e5f6a7b8c9", "lyrics": [{ "trigger": "e", "text": "não haverá noite ali." }] },
    { "type": "gesture", "gestureId": "e5f6a7b8c9d0", "lyrics": [{ "trigger": "Vou", "text": "para lá," }, { "trigger": "", "text": "com Jesus vou morar." }] },
    { "type": "repeat", "count": 2, "children": [
      { "type": "gesture", "gestureId": "f6a7b8c9d0e1", "lyrics": [{ "trigger": "Aleluia,", "text": "aleluia," }] },
      { "type": "gesture", "gestureId": "a7b8c9d0e1f2", "lyrics": [{ "trigger": "glória", "text": "ao Rei!" }] },
      { "type": "gesture", "gestureId": "b8c9d0e1f2a3", "lyrics": [{ "trigger": "Aleluia,", "text": "aleluia," }] },
      { "type": "gesture", "gestureId": "c9d0e1f2a3b4", "lyrics": [{ "trigger": "Jesus", "text": "vem me buscar." }] }
    ]}
  ]
}
```

`test/fixtures/gestures/sintetico_final_link.json`:

```json
{
  "schema": "coldigom.gestures/1",
  "title": "999 - SINTÉTICO",
  "dictionaryVersion": 1,
  "items": [
    { "type": "instruction", "kind": "instruments" },
    { "type": "repeat", "count": 3, "children": [
      { "type": "gesture", "gestureId": "c687580e7682", "lyrics": [{ "trigger": "Um", "text": "gesto solto" }] },
      { "type": "link", "children": [
        { "type": "gesture", "gestureId": "e7b821c9041a", "lyrics": [{ "trigger": "Ligado", "text": "ao" }] },
        { "type": "gesture", "gestureId": "6d88501c6888", "lyrics": [{ "trigger": "seguinte", "text": ", sem parar." }] }
      ]}
    ]},
    { "type": "coro", "children": [
      { "type": "repeat", "count": 2, "children": [
        { "type": "gesture", "gestureId": "dd4ba6562f45", "lyrics": [{ "trigger": "Coro", "text": "repetido" }] }
      ]}
    ]},
    { "type": "hologram", "foo": 1 },
    { "type": "text", "text": "linha livre" },
    { "type": "gesture", "gestureId": "000000000000", "lyrics": [{ "trigger": "Id", "text": "inexistente no dicionário" }] },
    { "type": "final", "children": [
      { "type": "gesture", "gestureId": "121dceda600f", "lyrics": [{ "trigger": "Fim", "text": "do louvor." }] }
    ]}
  ]
}
```

`test/fixtures/gestures/schema_v2.json`:

```json
{
  "schema": "coldigom.gestures/2",
  "title": "SCHEMA NOVO",
  "dictionaryVersion": 9,
  "items": [
    { "type": "gesture", "gestureId": "c687580e7682", "lyrics": [{ "trigger": "Ainda", "text": "renderiza" }] }
  ]
}
```

- [ ] **Step 2: Escrever os testes do parser (falhando)**

`test/unit/features/gestures/parse_gesture_document_test.dart`:

```dart
import 'dart:io';

import 'package:coldigui/features/gestures/domain/entities/gesture_document.dart';
import 'package:coldigui/features/gestures/domain/usecases/parse_gesture_document.dart';
import 'package:flutter_test/flutter_test.dart';

String _fixture(String name) =>
    File('test/fixtures/gestures/$name').readAsStringSync();

void main() {
  group('fixtures reais', () {
    test('182: coro com 5 cartões, gestos soltos e duas instruções', () {
      final doc = parseGestureDocument(_fixture('182_quero_viver.json'));

      expect(doc.schemaMajor, 1);
      expect(doc.isNewerSchema, isFalse);
      expect(doc.title, '182 - QUERO VIVER PRA SEMPRE COM JESUS');
      expect(doc.dictionaryVersion, 1);
      // 12 itens de raiz: coro(5) + 5 gestos + instrução + 4 gestos + instrução.
      expect(doc.items, hasLength(12));
      expect(doc.hasGestures, isTrue);

      final coro = doc.items.first as ChorusBlock;
      expect(coro.children, hasLength(5));
      final first = coro.children.first as GestureCard;
      expect(first.gestureId, 'c687580e7682');
      expect(first.lyrics.single.trigger, 'Quero');
      expect(first.lyrics.single.text, 'viver para sempre');

      expect(
        doc.items[6],
        isA<InstructionCard>().having(
          (i) => i.kind,
          'kind',
          InstructionKind.backToChorus,
        ),
      );
      expect(
        doc.items.last,
        isA<InstructionCard>().having(
          (i) => i.kind,
          'kind',
          InstructionKind.backToChorusAndFinish,
        ),
      );
    });

    test('181: cinco na raiz e repeat 2 com quatro filhos', () {
      final doc = parseGestureDocument(_fixture('181_jerusalem.json'));

      expect(doc.items, hasLength(6));
      final repeat = doc.items.last as RepeatBlock;
      expect(repeat.count, 2);
      expect(repeat.children, hasLength(4));
      final twoLines = doc.items[4] as GestureCard;
      expect(twoLines.lyrics, hasLength(2));
      expect(twoLines.lyrics[1].trigger, '');
    });

    test('sintético: final, link dentro de repeat, instrução e desconhecido', () {
      final doc = parseGestureDocument(_fixture('sintetico_final_link.json'));

      expect(doc.items.first, isA<InstructionCard>());
      final repeat = doc.items[1] as RepeatBlock;
      expect(repeat.count, 3);
      expect(repeat.children[1], isA<LinkBlock>());
      expect((repeat.children[1] as LinkBlock).children, hasLength(2));
      final coro = doc.items[2] as ChorusBlock;
      expect(coro.children.single, isA<RepeatBlock>());
      // Tipo desconhecido vira texto com o JSON compactado.
      expect(
        doc.items[3],
        isA<TextLine>().having(
          (t) => t.text,
          'text',
          '{"type":"hologram","foo":1}',
        ),
      );
      expect(doc.items[4], isA<TextLine>().having((t) => t.text, 'text', 'linha livre'));
      expect(doc.items.last, isA<FinalBlock>());
    });

    test('schema v2 marca isNewerSchema e ainda parseia', () {
      final doc = parseGestureDocument(_fixture('schema_v2.json'));

      expect(doc.schemaMajor, 2);
      expect(doc.isNewerSchema, isTrue);
      expect(doc.items.single, isA<GestureCard>());
    });
  });

  group('falhas conclusivas', () {
    test('JSON inválido lança GestureDocumentParseException', () {
      expect(
        () => parseGestureDocument('{nope'),
        throwsA(isA<GestureDocumentParseException>()),
      );
    });

    test('raiz que não é objeto lança', () {
      expect(
        () => parseGestureDocument('[1, 2]'),
        throwsA(isA<GestureDocumentParseException>()),
      );
    });
  });

  group('tolerância item a item', () {
    test('items ausente vira documento vazio, sem gestos', () {
      final doc = parseGestureDocument('{"schema":"coldigom.gestures/1","title":"X"}');
      expect(doc.items, isEmpty);
      expect(doc.hasGestures, isFalse);
    });

    test('count ausente ou menor que 2 cai para 2', () {
      final doc = parseGestureDocument(
        '{"items":[{"type":"repeat","children":[{"type":"gesture","gestureId":"c687580e7682"}]},'
        '{"type":"repeat","count":1,"children":[{"type":"gesture","gestureId":"c687580e7682"}]},'
        '{"type":"repeat","count":"4","children":[{"type":"gesture","gestureId":"c687580e7682"}]}]}',
      );
      expect((doc.items[0] as RepeatBlock).count, 2);
      expect((doc.items[1] as RepeatBlock).count, 2);
      expect((doc.items[2] as RepeatBlock).count, 4);
    });

    test('bloco sem filhos válidos é descartado', () {
      final doc = parseGestureDocument(
        '{"items":[{"type":"coro","children":[]},{"type":"link"},{"type":"final","children":[42]}]}',
      );
      expect(doc.items, isEmpty);
    });

    test('lyrics ausente vira uma linha vazia; mais de 3 é truncado', () {
      final doc = parseGestureDocument(
        '{"items":[{"type":"gesture","gestureId":"c687580e7682"},'
        '{"type":"gesture","gestureId":"c687580e7682","lyrics":['
        '{"trigger":"a"},{"trigger":"b"},{"trigger":"c"},{"trigger":"d"}]}]}',
      );
      final empty = doc.items[0] as GestureCard;
      expect(empty.lyrics.single.trigger, '');
      expect(empty.lyrics.single.text, '');
      expect((doc.items[1] as GestureCard).lyrics, hasLength(3));
    });

    test('gestureId inválido é mantido cru (placeholder decide na tela)', () {
      final doc = parseGestureDocument(
        '{"items":[{"type":"gesture","gestureId":"XYZ","lyrics":[{"trigger":"a","text":"b"}]}]}',
      );
      expect((doc.items.single as GestureCard).gestureId, 'XYZ');
    });

    test('instruction com kind desconhecido vira texto', () {
      final doc = parseGestureDocument(
        '{"items":[{"type":"instruction","kind":"dance"}]}',
      );
      expect(doc.items.single, isA<TextLine>());
    });

    test('text vazio é descartado; campos desconhecidos são ignorados', () {
      final doc = parseGestureDocument(
        '{"items":[{"type":"text","text":"  "},{"type":"text","text":"ok","extra":true}]}',
      );
      expect(doc.items, hasLength(1));
      expect((doc.items.single as TextLine).text, 'ok');
    });

    test('item que não é objeto é ignorado', () {
      final doc = parseGestureDocument('{"items":[1,"x",null,{"type":"text","text":"a"}]}');
      expect(doc.items, hasLength(1));
    });
  });

  group('parseSchemaMajor', () {
    test('lê o major depois da barra', () {
      expect(parseSchemaMajor('coldigom.gestures/1'), 1);
      expect(parseSchemaMajor('coldigom.gestures/2'), 2);
      expect(parseSchemaMajor('coldigom.gestures/3.1'), 3);
    });

    test('ausente ou inválido assume 1', () {
      expect(parseSchemaMajor(null), 1);
      expect(parseSchemaMajor(7), 1);
      expect(parseSchemaMajor('sem-barra'), 1);
      expect(parseSchemaMajor('x/abc'), 1);
    });
  });
}
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `flutter test --dart-define-from-file=dart_defines/plpcg.json test/unit/features/gestures/parse_gesture_document_test.dart`
Expected: falha de compilação (`gesture_document.dart` não existe).

- [ ] **Step 4: Implementar as entidades**

`lib/features/gestures/domain/entities/gesture_document.dart`:

```dart
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
```

- [ ] **Step 5: Implementar o parser**

`lib/features/gestures/domain/usecases/parse_gesture_document.dart`:

```dart
import 'dart:convert';

import '../entities/gesture_document.dart';

/// Falha **conclusiva** de parse: corpo que não é JSON ou raiz que não é
/// objeto. Só nesses dois casos não há nada para renderizar; tudo o que
/// acontece dentro de `items` é tolerado item a item, porque o leitor não
/// pode cair no meio do culto por causa de um campo torto.
class GestureDocumentParseException implements Exception {
  const GestureDocumentParseException(this.message);

  final String message;

  @override
  String toString() => 'GestureDocumentParseException: $message';
}

/// Máximo de linhas de letra por cartão (contrato §3.1).
const kGestureMaxLyricLines = 3;

/// Parseia o JSON de um documento de gestos.
///
/// Lança [GestureDocumentParseException] só para JSON inválido / raiz não
/// objeto. Regras de tolerância: spec §3.3.
GestureDocument parseGestureDocument(String json) {
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException catch (error) {
    throw GestureDocumentParseException('JSON inválido: ${error.message}');
  }
  if (decoded is! Map<String, Object?>) {
    throw GestureDocumentParseException('raiz não é objeto');
  }

  final rawItems = decoded['items'];
  return GestureDocument(
    schemaMajor: parseSchemaMajor(decoded['schema']),
    title: _asTrimmedString(decoded['title']),
    dictionaryVersion: _asInt(decoded['dictionaryVersion']) ?? 0,
    items: rawItems is List<Object?> ? _parseItems(rawItems) : const [],
  );
}

/// `"coldigom.gestures/1"` → 1. Ausente ou ilegível assume 1: a alternativa
/// (tratar como mais novo) mostraria o aviso de atualização à toa.
int parseSchemaMajor(Object? schema) {
  if (schema is! String) return 1;
  final slash = schema.lastIndexOf('/');
  if (slash == -1) return 1;
  final version = schema.substring(slash + 1);
  final dot = version.indexOf('.');
  final major = int.tryParse(dot == -1 ? version : version.substring(0, dot));
  return major ?? 1;
}

List<GestureItem> _parseItems(List<Object?> raw) {
  return [
    for (final entry in raw)
      if (_parseItem(entry) case final item?) item,
  ];
}

GestureItem? _parseItem(Object? raw) {
  if (raw is! Map<String, Object?>) return null;

  switch (raw['type']) {
    case 'gesture':
      return GestureCard(
        gestureId: _asTrimmedString(raw['gestureId']),
        lyrics: _parseLyrics(raw['lyrics']),
      );
    case 'repeat':
      final children = _parseChildren(raw['children']);
      if (children.isEmpty) return null;
      final count = _asInt(raw['count']);
      return RepeatBlock(
        count: count == null || count < 2 ? 2 : count,
        children: children,
      );
    case 'coro':
      final children = _parseChildren(raw['children']);
      return children.isEmpty ? null : ChorusBlock(children: children);
    case 'link':
      final children = _parseChildren(raw['children']);
      return children.isEmpty ? null : LinkBlock(children: children);
    case 'final':
      final children = _parseChildren(raw['children']);
      return children.isEmpty ? null : FinalBlock(children: children);
    case 'instruction':
      final kind = _instructionKind(raw['kind']);
      return kind == null ? TextLine(jsonEncode(raw)) : InstructionCard(kind);
    case 'text':
      final text = _asTrimmedString(raw['text']);
      return text.isEmpty ? null : TextLine(text);
    default:
      // Tipo desconhecido: se trouxer `text`, é o que se mostra; senão o
      // JSON compactado, para o regente ver que algo ficou de fora.
      final text = _asTrimmedString(raw['text']);
      return TextLine(text.isEmpty ? jsonEncode(raw) : text);
  }
}

List<GestureItem> _parseChildren(Object? raw) {
  if (raw is! List<Object?>) return const [];
  return _parseItems(raw);
}

List<LyricLine> _parseLyrics(Object? raw) {
  const fallback = [LyricLine(trigger: '', text: '')];
  if (raw is! List<Object?>) return fallback;
  final lines = <LyricLine>[];
  for (final entry in raw) {
    if (entry is! Map<String, Object?>) continue;
    lines.add(
      LyricLine(
        trigger: _asTrimmedString(entry['trigger']),
        text: _asTrimmedString(entry['text']),
      ),
    );
    if (lines.length == kGestureMaxLyricLines) break;
  }
  return lines.isEmpty ? fallback : lines;
}

InstructionKind? _instructionKind(Object? raw) => switch (raw) {
  'instruments' => InstructionKind.instruments,
  'repeat_praise' => InstructionKind.repeatPraise,
  'back_to_chorus' => InstructionKind.backToChorus,
  'back_to_chorus_and_finish' => InstructionKind.backToChorusAndFinish,
  _ => null,
};

String _asTrimmedString(Object? value) => value is String ? value.trim() : '';

int? _asInt(Object? value) => switch (value) {
  int() => value,
  num() => value.toInt(),
  String() => int.tryParse(value.trim()),
  _ => null,
};
```

- [ ] **Step 6: Rodar os testes até passar; `flutter analyze`**

Run: `flutter test --dart-define-from-file=dart_defines/plpcg.json test/unit/features/gestures/parse_gesture_document_test.dart && flutter analyze`
Expected: todos PASS; analyze sem issues.

- [ ] **Step 7: Commit**

```bash
git add lib/features/gestures/domain test/fixtures/gestures test/unit/features/gestures/parse_gesture_document_test.dart
git commit -m "feat(gestures): entidades do documento e parser tolerante com fixtures

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01DuSVKfiGsabi168JixJLB1"
```

---

### Task 2: Dicionário — entidade, parser e resolução de alias

**Files:**
- Create: `lib/features/gestures/domain/entities/gesture_dictionary.dart`
- Create: `lib/features/gestures/domain/usecases/parse_gesture_dictionary.dart`
- Create: `test/fixtures/gestures/dictionary.json`
- Test: `test/unit/features/gestures/parse_gesture_dictionary_test.dart`, `test/unit/features/gestures/gesture_dictionary_resolve_test.dart`

**Interfaces:**
- Produces: `GestureDictionary { int version; DateTime? generatedAt; Map<String, GestureEntry> byId; GestureEntry? resolve(String id); static const empty }`; `GestureEntry { id, name, description, exampleTriggers, image, gif, status, replacedBy, updatedAt }`; `enum GestureStatus { active, deprecated }`; `GestureDictionary parseGestureDictionary(String json)` (lança `GestureDictionaryParseException`); `const kGestureAliasMaxHops = 5`.

- [ ] **Step 1: Fixture do dicionário**

`test/fixtures/gestures/dictionary.json` — 12 entradas. Os ids das 10 primeiras são os usados pelo fixture 182 + o sintético; `a1b2c3d4e5f6` está `deprecated` → `c687580e7682`; `x` e `y` formam ciclo. Todas as `image` seguem `assets/cia/gestures/{id}.png`.

```json
{
  "schema": "coldigom.gesture-dictionary/1",
  "version": 3,
  "generatedAt": "2026-09-10T12:00:00Z",
  "gestures": [
    { "id": "c687580e7682", "name": "Mão ao peito", "description": "Mão direita sobre o peito.", "exampleTriggers": ["Quero", "Vou"], "image": "assets/cia/gestures/c687580e7682.png", "gif": null, "status": "active", "replacedBy": null, "updatedAt": "2026-09-01T00:00:00Z" },
    { "id": "e7b821c9041a", "name": "Apontar para cima", "description": "Indicador direito para o alto.", "exampleTriggers": ["com", "Jesus"], "image": "assets/cia/gestures/e7b821c9041a.png", "gif": "assets/cia/gestures/e7b821c9041a.gif", "status": "active", "replacedBy": null, "updatedAt": "2026-09-01T00:00:00Z" },
    { "id": "6d88501c6888", "name": "Beber", "description": "Mão em concha à boca.", "exampleTriggers": ["beber"], "image": "assets/cia/gestures/6d88501c6888.png", "gif": null, "status": "active", "replacedBy": null, "updatedAt": "2026-09-01T00:00:00Z" },
    { "id": "dd4ba6562f45", "name": "Comer", "description": "Mão à boca.", "exampleTriggers": ["comer"], "image": "assets/cia/gestures/dd4ba6562f45.png", "gif": null, "status": "active", "replacedBy": null, "updatedAt": "2026-09-01T00:00:00Z" },
    { "id": "a6a5eb350ad4", "name": "Passear", "description": "Dedos caminhando.", "exampleTriggers": ["Passear"], "image": "assets/cia/gestures/a6a5eb350ad4.png", "gif": null, "status": "active", "replacedBy": null, "updatedAt": "2026-09-01T00:00:00Z" },
    { "id": "fa2878588e54", "name": "Árvore", "description": "Braços abertos como copa.", "exampleTriggers": ["A árvore"], "image": "assets/cia/gestures/fa2878588e54.png", "gif": null, "status": "active", "replacedBy": null, "updatedAt": "2026-09-01T00:00:00Z" },
    { "id": "5ef0073c9723", "name": "Meio", "description": "Mãos ao centro.", "exampleTriggers": ["no meio"], "image": "assets/cia/gestures/5ef0073c9723.png", "gif": null, "status": "active", "replacedBy": null, "updatedAt": "2026-09-01T00:00:00Z" },
    { "id": "121dceda600f", "name": "Certeza", "description": "Punho fechado firme.", "exampleTriggers": ["É certeza"], "image": "assets/cia/gestures/121dceda600f.png", "gif": null, "status": "active", "replacedBy": null, "updatedAt": "2026-09-01T00:00:00Z" },
    { "id": "fff2698cc966", "name": "Para trás", "description": "Mão jogando para trás.", "exampleTriggers": ["Para"], "image": "assets/cia/gestures/fff2698cc966.png", "gif": null, "status": "active", "replacedBy": null, "updatedAt": "2026-09-01T00:00:00Z" },
    { "id": "81338f2f401e", "name": "Domínio", "description": "Mão espalmada para baixo.", "exampleTriggers": ["Seu"], "image": "assets/cia/gestures/81338f2f401e.png", "gif": null, "status": "active", "replacedBy": null, "updatedAt": "2026-09-01T00:00:00Z" },
    { "id": "a1b2c3d4e5f6", "name": "Mão ao peito (antigo)", "description": "Fundido.", "exampleTriggers": [], "image": "assets/cia/gestures/a1b2c3d4e5f6.png", "gif": null, "status": "deprecated", "replacedBy": "c687580e7682", "updatedAt": "2026-09-05T00:00:00Z" },
    { "id": "b2c3d4e5f6a7", "name": "Ciclo X", "description": "", "exampleTriggers": [], "image": "assets/cia/gestures/b2c3d4e5f6a7.png", "gif": null, "status": "deprecated", "replacedBy": "c3d4e5f6a7b8", "updatedAt": "2026-09-05T00:00:00Z" },
    { "id": "c3d4e5f6a7b8", "name": "Ciclo Y", "description": "", "exampleTriggers": [], "image": "assets/cia/gestures/c3d4e5f6a7b8.png", "gif": null, "status": "deprecated", "replacedBy": "b2c3d4e5f6a7", "updatedAt": "2026-09-05T00:00:00Z" }
  ]
}
```

(São 13 linhas; o teste conta 13.)

- [ ] **Step 2: Testes (falhando)**

`test/unit/features/gestures/parse_gesture_dictionary_test.dart`:

```dart
import 'dart:io';

import 'package:coldigui/features/gestures/domain/entities/gesture_dictionary.dart';
import 'package:coldigui/features/gestures/domain/usecases/parse_gesture_dictionary.dart';
import 'package:flutter_test/flutter_test.dart';

String _fixture() =>
    File('test/fixtures/gestures/dictionary.json').readAsStringSync();

void main() {
  test('parseia versão, data e entradas indexadas por id', () {
    final dict = parseGestureDictionary(_fixture());

    expect(dict.version, 3);
    expect(dict.generatedAt, DateTime.utc(2026, 9, 10, 12));
    expect(dict.byId, hasLength(13));
    final entry = dict.byId['e7b821c9041a']!;
    expect(entry.name, 'Apontar para cima');
    expect(entry.image, 'assets/cia/gestures/e7b821c9041a.png');
    expect(entry.gif, 'assets/cia/gestures/e7b821c9041a.gif');
    expect(entry.status, GestureStatus.active);
    expect(entry.exampleTriggers, ['com', 'Jesus']);
    expect(dict.byId['a1b2c3d4e5f6']!.status, GestureStatus.deprecated);
    expect(dict.byId['a1b2c3d4e5f6']!.replacedBy, 'c687580e7682');
  });

  test('entrada sem id ou sem image é descartada; status desconhecido é active', () {
    final dict = parseGestureDictionary(
      '{"version":1,"gestures":[{"id":"","image":"x.png"},{"id":"aaaaaaaaaaaa"},'
      '{"id":"bbbbbbbbbbbb","image":"b.png","status":"weird"}]}',
    );
    expect(dict.byId.keys, ['bbbbbbbbbbbb']);
    expect(dict.byId['bbbbbbbbbbbb']!.status, GestureStatus.active);
    expect(dict.byId['bbbbbbbbbbbb']!.gif, isNull);
    expect(dict.byId['bbbbbbbbbbbb']!.exampleTriggers, isEmpty);
  });

  test('version ausente vira 0; generatedAt ilegível vira null', () {
    final dict = parseGestureDictionary('{"gestures":[],"generatedAt":"ontem"}');
    expect(dict.version, 0);
    expect(dict.generatedAt, isNull);
    expect(dict.byId, isEmpty);
  });

  test('JSON inválido ou raiz não objeto lança', () {
    expect(
      () => parseGestureDictionary('nope'),
      throwsA(isA<GestureDictionaryParseException>()),
    );
    expect(
      () => parseGestureDictionary('[]'),
      throwsA(isA<GestureDictionaryParseException>()),
    );
  });
}
```

`test/unit/features/gestures/gesture_dictionary_resolve_test.dart`:

```dart
import 'dart:io';

import 'package:coldigui/features/gestures/domain/entities/gesture_dictionary.dart';
import 'package:coldigui/features/gestures/domain/usecases/parse_gesture_dictionary.dart';
import 'package:flutter_test/flutter_test.dart';

GestureEntry _entry(String id, {String? replacedBy}) => GestureEntry(
  id: id,
  name: id,
  description: '',
  exampleTriggers: const [],
  image: 'assets/cia/gestures/$id.png',
  gif: null,
  status: replacedBy == null ? GestureStatus.active : GestureStatus.deprecated,
  replacedBy: replacedBy,
  updatedAt: null,
);

void main() {
  late GestureDictionary dict;

  setUp(() {
    dict = parseGestureDictionary(
      File('test/fixtures/gestures/dictionary.json').readAsStringSync(),
    );
  });

  test('id ativo resolve para si mesmo', () {
    expect(dict.resolve('c687580e7682')?.id, 'c687580e7682');
  });

  test('deprecated segue replacedBy até a entrada ativa', () {
    expect(dict.resolve('a1b2c3d4e5f6')?.id, 'c687580e7682');
  });

  test('id ausente devolve null', () {
    expect(dict.resolve('000000000000'), isNull);
    expect(dict.resolve(''), isNull);
  });

  test('ciclo não trava: devolve a última entrada visitada', () {
    final resolved = dict.resolve('b2c3d4e5f6a7');
    expect(resolved, isNotNull);
    expect(['b2c3d4e5f6a7', 'c3d4e5f6a7b8'], contains(resolved!.id));
  });

  test('cadeia maior que kGestureAliasMaxHops para no teto', () {
    // a0 → a1 → … → a7 (ativo): 7 saltos, teto 5 → para em a5.
    final entries = <String, GestureEntry>{};
    for (var i = 0; i <= 7; i++) {
      final id = 'a$i'.padRight(12, '0');
      final next = i == 7 ? null : 'a${i + 1}'.padRight(12, '0');
      entries[id] = _entry(id, replacedBy: next);
    }
    final chain = GestureDictionary(version: 1, generatedAt: null, byId: entries);

    expect(chain.resolve('a0'.padRight(12, '0'))?.id, 'a5'.padRight(12, '0'));
  });

  test('replacedBy apontando para id ausente devolve a própria deprecated', () {
    final dict = GestureDictionary(
      version: 1,
      generatedAt: null,
      byId: {'aaaaaaaaaaaa': _entry('aaaaaaaaaaaa', replacedBy: 'zzzzzzzzzzzz')},
    );
    expect(dict.resolve('aaaaaaaaaaaa')?.id, 'aaaaaaaaaaaa');
  });

  test('empty não tem entradas', () {
    expect(GestureDictionary.empty.byId, isEmpty);
    expect(GestureDictionary.empty.resolve('c687580e7682'), isNull);
  });
}
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `flutter test --dart-define-from-file=dart_defines/plpcg.json test/unit/features/gestures/parse_gesture_dictionary_test.dart test/unit/features/gestures/gesture_dictionary_resolve_test.dart`
Expected: falha de compilação.

- [ ] **Step 4: Implementar entidade**

`lib/features/gestures/domain/entities/gesture_dictionary.dart`:

```dart
/// Teto de saltos ao seguir `replacedBy` (contrato §3.4).
const kGestureAliasMaxHops = 5;

enum GestureStatus { active, deprecated }

/// Uma entrada do dicionário de gestos CIAs.
class GestureEntry {
  const GestureEntry({
    required this.id,
    required this.name,
    required this.description,
    required this.exampleTriggers,
    required this.image,
    required this.gif,
    required this.status,
    required this.replacedBy,
    required this.updatedAt,
  });

  /// 12 hex, estável para sempre.
  final String id;
  final String name;
  final String description;
  final List<String> exampleTriggers;

  /// `r2_key` do PNG (`assets/cia/gestures/{id}.png`).
  final String image;

  /// `r2_key` do GIF animado, quando houver.
  final String? gif;

  final GestureStatus status;

  /// Id que substitui esta entrada quando [status] é `deprecated`.
  final String? replacedBy;

  final DateTime? updatedAt;
}

/// Dicionário global publicado por `GET /api/gestures/dictionary`.
class GestureDictionary {
  const GestureDictionary({
    required this.version,
    required this.generatedAt,
    required this.byId,
  });

  /// Dicionário sem entradas — o que a tela usa antes de o real chegar.
  static const empty = GestureDictionary(version: 0, generatedAt: null, byId: {});

  /// Inteiro monotônico; incrementa a cada alteração no coldigom.
  final int version;

  final DateTime? generatedAt;

  final Map<String, GestureEntry> byId;

  /// Entrada a renderizar para [id], seguindo a cadeia `replacedBy`.
  ///
  /// Para na primeira entrada `active`, em [kGestureAliasMaxHops] saltos, num
  /// `replacedBy` que não existe, ou num ciclo — nos três últimos casos devolve
  /// a última entrada visitada, porque mostrar uma figura velha é melhor que
  /// um placeholder. Só `null` quando [id] não está no dicionário.
  GestureEntry? resolve(String id) {
    var current = byId[id];
    if (current == null) return null;

    final visited = <String>{current.id};
    for (var hop = 0; hop < kGestureAliasMaxHops; hop++) {
      if (current.status == GestureStatus.active) return current;
      final nextId = current.replacedBy;
      if (nextId == null || !visited.add(nextId)) return current;
      final next = byId[nextId];
      if (next == null) return current;
      current = next;
    }
    return current;
  }
}
```

- [ ] **Step 5: Implementar parser**

`lib/features/gestures/domain/usecases/parse_gesture_dictionary.dart`:

```dart
import 'dart:convert';

import '../entities/gesture_dictionary.dart';

/// Falha conclusiva de parse do dicionário (JSON inválido / raiz não objeto).
class GestureDictionaryParseException implements Exception {
  const GestureDictionaryParseException(this.message);

  final String message;

  @override
  String toString() => 'GestureDictionaryParseException: $message';
}

/// Parseia o JSON de `GET /api/gestures/dictionary`.
///
/// Entrada sem `id` ou sem `image` é descartada (não há o que desenhar);
/// `status` desconhecido vira `active`; campos ausentes ganham vazio/null.
GestureDictionary parseGestureDictionary(String json) {
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException catch (error) {
    throw GestureDictionaryParseException('JSON inválido: ${error.message}');
  }
  if (decoded is! Map<String, Object?>) {
    throw GestureDictionaryParseException('raiz não é objeto');
  }

  final byId = <String, GestureEntry>{};
  final rawGestures = decoded['gestures'];
  if (rawGestures is List<Object?>) {
    for (final raw in rawGestures) {
      final entry = _parseEntry(raw);
      if (entry != null) byId[entry.id] = entry;
    }
  }

  final rawVersion = decoded['version'];
  return GestureDictionary(
    version: rawVersion is num ? rawVersion.toInt() : 0,
    generatedAt: _parseDate(decoded['generatedAt']),
    byId: byId,
  );
}

GestureEntry? _parseEntry(Object? raw) {
  if (raw is! Map<String, Object?>) return null;
  final id = _string(raw['id']);
  final image = _string(raw['image']);
  if (id.isEmpty || image.isEmpty) return null;

  final gif = _string(raw['gif']);
  final replacedBy = _string(raw['replacedBy']);
  final rawTriggers = raw['exampleTriggers'];
  return GestureEntry(
    id: id,
    name: _string(raw['name']),
    description: _string(raw['description']),
    exampleTriggers: rawTriggers is List<Object?>
        ? [for (final t in rawTriggers) if (t is String) t]
        : const [],
    image: image,
    gif: gif.isEmpty ? null : gif,
    status: raw['status'] == 'deprecated'
        ? GestureStatus.deprecated
        : GestureStatus.active,
    replacedBy: replacedBy.isEmpty ? null : replacedBy,
    updatedAt: _parseDate(raw['updatedAt']),
  );
}

DateTime? _parseDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

String _string(Object? value) => value is String ? value.trim() : '';
```

- [ ] **Step 6: Rodar até passar; analyze**

Run: `flutter test --dart-define-from-file=dart_defines/plpcg.json test/unit/features/gestures/ && flutter analyze`
Expected: PASS, sem issues.

- [ ] **Step 7: Commit**

```bash
git add lib/features/gestures/domain test/fixtures/gestures/dictionary.json test/unit/features/gestures/parse_gesture_dictionary_test.dart test/unit/features/gestures/gesture_dictionary_resolve_test.dart
git commit -m "feat(gestures): dicionário de gestos com parser tolerante e resolução de alias

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01DuSVKfiGsabi168JixJLB1"
```

---

### Task 3: `flattenGestureCards` — lista linear com contexto de bloco

**Files:**
- Create: `lib/features/gestures/domain/entities/flat_gesture_card.dart`
- Create: `lib/features/gestures/domain/utils/flatten_gesture_cards.dart`
- Test: `test/unit/features/gestures/flatten_gesture_cards_test.dart`

**Interfaces:**
- Consumes: T1 (`GestureDocument`, `GestureItem` e subtipos).
- Produces: `FlatGestureCard { int index; GestureCard card; List<BlockContext> contexts }`; `sealed BlockContext` com `RepeatContext(count)`, `ChorusContext()`, `FinalContext()`, `LinkContext()`; `List<FlatGestureCard> flattenGestureCards(GestureDocument document)`. **`index` é o único esquema de numeração de cartões do app**: a página (T11) e o foco (T15) usam este.

- [ ] **Step 1: Teste (falhando)**

`test/unit/features/gestures/flatten_gesture_cards_test.dart`:

```dart
import 'dart:io';

import 'package:coldigui/features/gestures/domain/entities/flat_gesture_card.dart';
import 'package:coldigui/features/gestures/domain/entities/gesture_document.dart';
import 'package:coldigui/features/gestures/domain/usecases/parse_gesture_document.dart';
import 'package:coldigui/features/gestures/domain/utils/flatten_gesture_cards.dart';
import 'package:flutter_test/flutter_test.dart';

GestureDocument _fixture(String name) => parseGestureDocument(
  File('test/fixtures/gestures/$name').readAsStringSync(),
);

void main() {
  test('182: 14 cartões em ordem de documento; os 5 do coro têm ChorusContext', () {
    final flat = flattenGestureCards(_fixture('182_quero_viver.json'));

    expect(flat, hasLength(14));
    expect([for (final f in flat) f.index], List.generate(14, (i) => i));
    for (final f in flat.take(5)) {
      expect(f.contexts, [isA<ChorusContext>()]);
    }
    expect(flat[5].contexts, isEmpty);
    expect(flat[5].card.lyrics.single.trigger, 'Vou');
    // Instruções não entram na lista.
    expect(flat.last.card.lyrics.single.trigger, 'Viver');
  });

  test('181: os 4 do repeat carregam RepeatContext(2)', () {
    final flat = flattenGestureCards(_fixture('181_jerusalem.json'));

    expect(flat, hasLength(9));
    expect(flat[4].contexts, isEmpty);
    for (final f in flat.skip(5)) {
      expect(f.contexts, [isA<RepeatContext>().having((c) => c.count, 'count', 2)]);
    }
  });

  test('sintético: contextos aninhados do mais externo ao mais interno', () {
    final flat = flattenGestureCards(_fixture('sintetico_final_link.json'));

    // repeat3 > gesto solto
    expect(flat[0].contexts, [isA<RepeatContext>().having((c) => c.count, 'count', 3)]);
    // repeat3 > link > gesto
    expect(flat[1].contexts, [isA<RepeatContext>(), isA<LinkContext>()]);
    expect(flat[2].contexts, [isA<RepeatContext>(), isA<LinkContext>()]);
    // coro > repeat2 > gesto
    expect(flat[3].contexts, [isA<ChorusContext>(), isA<RepeatContext>()]);
    // gesto de id inexistente também entra
    expect(flat[4].card.gestureId, '000000000000');
    expect(flat[4].contexts, isEmpty);
    // final > gesto
    expect(flat[5].contexts, [isA<FinalContext>()]);
    expect(flat, hasLength(6));
  });

  test('documento sem gestos devolve lista vazia', () {
    final doc = parseGestureDocument('{"items":[{"type":"text","text":"x"}]}');
    expect(flattenGestureCards(doc), isEmpty);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test --dart-define-from-file=dart_defines/plpcg.json test/unit/features/gestures/flatten_gesture_cards_test.dart`
Expected: falha de compilação.

- [ ] **Step 3: Implementar**

`lib/features/gestures/domain/entities/flat_gesture_card.dart`:

```dart
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
```

`lib/features/gestures/domain/utils/flatten_gesture_cards.dart`:

```dart
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
      case InstructionCard() || TextLine():
        break;
    }
  }
}
```

- [ ] **Step 4: Rodar até passar; analyze; commit**

Run: `flutter test --dart-define-from-file=dart_defines/plpcg.json test/unit/features/gestures/ && flutter analyze`

```bash
git add lib/features/gestures/domain test/unit/features/gestures/flatten_gesture_cards_test.dart
git commit -m "feat(gestures): flatten dos cartões com contexto de bloco

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01DuSVKfiGsabi168JixJLB1"
```

---

### Task 4: `GestureMaterial`, `GestureReaderFontSize`, `StorageKeys` e `materialIdKindOf`

**Files:**
- Create: `lib/features/gestures/domain/entities/gesture_material.dart`
- Create: `lib/features/gestures/domain/entities/gesture_reader_font_size.dart`
- Modify: `lib/core/constants/storage_keys.dart` (perto de `chordReaderFontSize`, linha ~40)
- Modify: `lib/core/utils/material_id_kind.dart:36-57` e o doc-comment acima
- Test: `test/unit/features/gestures/gesture_reader_font_size_test.dart`, `test/unit/core/material_id_kind_test.dart` (ajustar)

**Interfaces:**
- Produces: `GestureMaterial { gestureId, r2Key, nome, numero, groupId, categoria, classificacao, author, source }` (mesma forma de `ChordMaterial`, `gestureId = encodePdfId(r2Key)`); `GestureReaderFontSize { min 14, max 28, step 2, initial 18, clamp, increase, decrease, canIncrease, canDecrease }`; `StorageKeys.gestureReaderFontSize = 'gestureReaderFontSize'`; `materialIdKindOf` devolve `MaterialKind.gesture` para `.gestures` e `unknown` para `.txt`/`.gest`.

- [ ] **Step 1: Testes (falhando)**

`test/unit/features/gestures/gesture_reader_font_size_test.dart`:

```dart
import 'package:coldigui/features/gestures/domain/entities/gesture_reader_font_size.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('faixa 14–28, passo 2, inicial 18', () {
    expect(GestureReaderFontSize.min, 14);
    expect(GestureReaderFontSize.max, 28);
    expect(GestureReaderFontSize.step, 2);
    expect(GestureReaderFontSize.initial, 18);
  });

  test('increase/decrease andam de 2 e param nos limites', () {
    expect(GestureReaderFontSize.increase(18), 20);
    expect(GestureReaderFontSize.decrease(18), 16);
    expect(GestureReaderFontSize.increase(28), 28);
    expect(GestureReaderFontSize.decrease(14), 14);
    expect(GestureReaderFontSize.canIncrease(28), isFalse);
    expect(GestureReaderFontSize.canDecrease(14), isFalse);
  });

  test('clamp grampeia fora da faixa', () {
    expect(GestureReaderFontSize.clamp(5), 14);
    expect(GestureReaderFontSize.clamp(99), 28);
  });
}
```

Em `test/unit/core/material_id_kind_test.dart`, **substituir** os três testes `reconhece gestos por .txt`, `reconhece gestos por .gest` e `ignora caixa da extensao de gestos` por:

```dart
    test('reconhece gestos por .gestures', () {
      final id = encodePdfId('assets/praises/abc/def.gestures');
      expect(materialIdKindOf(id), MaterialKind.gesture);
    });

    test('ignora caixa da extensao de gestos', () {
      final id = encodePdfId('assets/praises/abc/def.GESTURES');
      expect(materialIdKindOf(id), MaterialKind.gesture);
    });

    test('.txt e .gest nao sao mais gesto (nada as produz)', () {
      expect(
        materialIdKindOf(encodePdfId('assets/praises/abc/def.txt')),
        MaterialKind.unknown,
      );
      expect(
        materialIdKindOf(encodePdfId('assets/praises/abc/def.gest')),
        MaterialKind.unknown,
      );
    });
```

Rode também `grep -rn "\.gest\b\|\.txt" test/unit/features/playlists/` — se algum teste de playlist depender de `.gest`/`.txt` classificar como gesto, troque a extensão do fixture para `.gestures` (o comportamento esperado não muda).

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test --dart-define-from-file=dart_defines/plpcg.json test/unit/features/gestures/gesture_reader_font_size_test.dart test/unit/core/material_id_kind_test.dart`
Expected: o primeiro não compila; no segundo os três testes novos falham.

- [ ] **Step 3: Implementar**

`lib/features/gestures/domain/entities/gesture_material.dart`:

```dart
import '../../../catalog/domain/entities/louvor_data_source.dart';

/// Material "documento de gestos" coldigom — abre em `/gestos`.
///
/// Mesma forma de `ChordMaterial`: [gestureId] vive no espaço do `pdfId`
/// (`encodePdfId(r2Key)`), para que carousel e playlist funcionem sem um
/// segundo espaço de ids. Ver `materialIdKindOf`.
class GestureMaterial {
  const GestureMaterial({
    required this.gestureId,
    required this.r2Key,
    required this.nome,
    required this.numero,
    required this.groupId,
    required this.categoria,
    required this.classificacao,
    this.author = '',
    this.source = LouvorDataSource.coldigom,
  });

  /// `encodePdfId(r2Key)` — mesmo espaço do `pdfId`.
  final String gestureId;

  /// Chave do asset no R2 (`assets/praises/<praise>/<material>.gestures`).
  final String r2Key;

  final String nome;
  final String numero;
  final String groupId;

  /// Label do kind, ex.: `Gestos`.
  final String categoria;

  final String classificacao;
  final String author;
  final LouvorDataSource source;
}
```

`lib/features/gestures/domain/entities/gesture_reader_font_size.dart`:

```dart
/// Faixa e passo do corpo da letra no leitor de gestos (spec §4).
///
/// Base 18 porque a letra é lida a um braço de distância, com o aparelho na
/// mão; abaixo de 14 o gatilho some, acima de 28 a figura (que escala junto)
/// engole a largura do celular.
abstract final class GestureReaderFontSize {
  static const double min = 14;
  static const double max = 28;
  static const double step = 2;
  static const double initial = 18;

  static double clamp(double size) => size.clamp(min, max);

  static double increase(double size) => clamp(size + step);

  static double decrease(double size) => clamp(size - step);

  static bool canIncrease(double size) => size < max;

  static bool canDecrease(double size) => size > min;
}
```

`lib/core/constants/storage_keys.dart` — logo após `chordReaderFontSize`:

```dart
  /// Corpo da letra no leitor de gestos (`double`).
  static const String gestureReaderFontSize = 'gestureReaderFontSize';
```

`lib/core/utils/material_id_kind.dart` — trocar

```dart
  if (lower.endsWith('.txt') || lower.endsWith('.gest')) {
    return MaterialKind.gesture;
  }
```

por

```dart
  if (lower.endsWith('.gestures')) return MaterialKind.gesture;
```

e, no doc-comment da função, trocar a frase "junto com os ids legados e com [MaterialKind.gesture] (gesto abre no leitor)" por "junto com os ids legados e com [MaterialKind.gesture] (documento JSON de gestos, `.gestures`, que abre em `/gestos`)".

- [ ] **Step 4: Rodar a suíte inteira de unit (o `.txt` pode ter dependentes); analyze**

Run: `flutter test --dart-define-from-file=dart_defines/plpcg.json test/unit && flutter analyze`
Expected: PASS. Se algum teste de playlist quebrar por `.gest`, corrija a extensão do fixture para `.gestures`.

- [ ] **Step 5: Commit**

```bash
git add lib/features/gestures/domain lib/core/constants/storage_keys.dart lib/core/utils/material_id_kind.dart test/unit/features/gestures/gesture_reader_font_size_test.dart test/unit/core/material_id_kind_test.dart
git commit -m "feat(gestures): GestureMaterial, faixa de fonte e .gestures como extensão de gesto

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01DuSVKfiGsabi168JixJLB1"
```

---

### Task 5: Coleções Isar e datasources locais (documento + dicionário)

**Files:**
- Create: `lib/core/database/collections/gesture_document_cache.dart` (+ `.g.dart` gerado)
- Create: `lib/core/database/collections/gesture_dictionary_cache.dart` (+ `.g.dart` gerado)
- Modify: `lib/core/database/isar_app_schemas.dart`
- Create: `lib/features/gestures/data/datasources/gesture_content_local_datasource.dart`
- Create: `lib/features/gestures/data/datasources/gesture_dictionary_local_datasource.dart`
- Test: `test/unit/features/gestures/gesture_content_local_datasource_test.dart`, `test/unit/features/gestures/gesture_dictionary_local_datasource_test.dart`

**Interfaces:**
- Produces: `GestureCacheEntry { String content; DateTime fetchedAt; bool isStaleAt(DateTime now) }`, `const kGestureCacheTtl = Duration(hours: 24)`, `GestureContentLocalDatasource(Isar?) { GestureCacheEntry? read(String r2Key); void write(String r2Key, String content) }`; `GestureDictionaryCacheEntry { String content; String? etag; DateTime fetchedAt; bool isStaleAt(DateTime now) }`, `const kGestureDictionaryTtl = Duration(hours: 1)`, `GestureDictionaryLocalDatasource(Isar?) { GestureDictionaryCacheEntry? read(); void write({required String content, required String? etag}); void touch() }`.

- [ ] **Step 1: Coleções**

`lib/core/database/collections/gesture_document_cache.dart`:

```dart
import 'package:isar_plus/isar_plus.dart';

part 'gesture_document_cache.g.dart';

/// Cache persistente do documento `.gestures` de um material coldigom.
///
/// Cópia fiel de `ChordContentCache`: JSON de 2–8 KB, guardar o corpo inteiro
/// é o que faz o louvor abrir offline e impede que uma queda de rede vire
/// "este louvor não tem gestos". [content] vazio é o marcador negativo (404).
@Collection()
class GestureDocumentCache {
  int id = 0;

  /// Chave Coldigom do arquivo, ex.: `assets/praises/p1/m1.gestures`.
  @Index(unique: true)
  late String r2Key;

  /// JSON cru, exatamente como veio do Worker; vazio = não existe.
  late String content;

  /// Quando o corpo foi buscado — base para revalidação em background.
  late DateTime fetchedAt;
}
```

`lib/core/database/collections/gesture_dictionary_cache.dart`:

```dart
import 'package:isar_plus/isar_plus.dart';

part 'gesture_dictionary_cache.g.dart';

/// Cache persistente do dicionário de gestos — **linha única**, `id = 1`.
///
/// Guarda o [etag] porque a revalidação usa `If-None-Match`: um 304 custa um
/// round-trip vazio em vez dos ~40 KB do JSON.
@Collection()
class GestureDictionaryCache {
  /// Sempre [singletonId]; a coleção nunca tem mais de uma linha.
  int id = singletonId;

  static const int singletonId = 1;

  late String content;

  String? etag;

  late DateTime fetchedAt;
}
```

Em `lib/core/database/isar_app_schemas.dart`, adicionar os imports e as duas entradas ao fim de `kAppIsarSchemas`:

```dart
import 'collections/gesture_dictionary_cache.dart';
import 'collections/gesture_document_cache.dart';
…
  ChordContentCacheSchema,
  GestureDocumentCacheSchema,
  GestureDictionaryCacheSchema,
];
```

- [ ] **Step 2: Gerar o código Isar**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: cria `gesture_document_cache.g.dart` e `gesture_dictionary_cache.g.dart`; `flutter analyze` limpo.

- [ ] **Step 3: Testes (falhando)**

`test/unit/features/gestures/gesture_content_local_datasource_test.dart`:

```dart
import 'dart:io';

import 'package:coldigui/core/database/collections/gesture_document_cache.dart';
import 'package:coldigui/features/gestures/data/datasources/gesture_content_local_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

import '../../../helpers/isar_plus_test_init.dart';

void main() {
  const key = 'assets/praises/p1/m1.gestures';
  const content = '{"schema":"coldigom.gestures/1","items":[]}';

  group('com Isar', () {
    late Directory tempDir;
    late Isar isar;
    late GestureContentLocalDatasource datasource;

    setUpAll(ensureIsarPlusTestCore);

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('gesture_cache_test');
      isar = Isar.open(
        schemas: [GestureDocumentCacheSchema],
        directory: tempDir.path,
      );
      datasource = GestureContentLocalDatasource(isar);
    });

    tearDown(() {
      isar.close(deleteFromDisk: true);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('read devolve null antes de qualquer escrita', () {
      expect(datasource.read(key), isNull);
    });

    test('write persiste e read devolve de volta', () {
      datasource.write(key, content);
      expect(datasource.read(key)?.content, content);
    });

    test('write duas vezes na mesma chave nao duplica linha', () {
      datasource.write(key, content);
      datasource.write(key, '{}');
      expect(isar.gestureDocumentCaches.where().count(), 1);
      expect(datasource.read(key)?.content, '{}');
    });

    test('marcador negativo: conteudo vazio e uma entrada valida', () {
      datasource.write(key, '');
      final entry = datasource.read(key);
      expect(entry, isNotNull);
      expect(entry!.content, isEmpty);
    });

    test('chave vazia e ignorada', () {
      datasource.write('', content);
      expect(datasource.read(''), isNull);
      expect(isar.gestureDocumentCaches.where().count(), 0);
    });
  });

  group('sem Isar (degradado)', () {
    test('read devolve null e write nao lanca', () {
      const datasource = GestureContentLocalDatasource(null);
      expect(() => datasource.write(key, content), returnsNormally);
      expect(datasource.read(key), isNull);
    });
  });

  test('isStaleAt respeita kGestureCacheTtl', () {
    final now = DateTime(2026, 9, 11, 12);
    final fresh = GestureCacheEntry(content: 'x', fetchedAt: now.subtract(const Duration(hours: 23)));
    final stale = GestureCacheEntry(content: 'x', fetchedAt: now.subtract(const Duration(hours: 25)));
    expect(fresh.isStaleAt(now), isFalse);
    expect(stale.isStaleAt(now), isTrue);
  });
}
```

`test/unit/features/gestures/gesture_dictionary_local_datasource_test.dart`:

```dart
import 'dart:io';

import 'package:coldigui/core/database/collections/gesture_dictionary_cache.dart';
import 'package:coldigui/features/gestures/data/datasources/gesture_dictionary_local_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

import '../../../helpers/isar_plus_test_init.dart';

void main() {
  const content = '{"version":3,"gestures":[]}';

  group('com Isar', () {
    late Directory tempDir;
    late Isar isar;
    late GestureDictionaryLocalDatasource datasource;

    setUpAll(ensureIsarPlusTestCore);

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('gesture_dict_test');
      isar = Isar.open(
        schemas: [GestureDictionaryCacheSchema],
        directory: tempDir.path,
      );
      datasource = GestureDictionaryLocalDatasource(isar);
    });

    tearDown(() {
      isar.close(deleteFromDisk: true);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('read devolve null antes de qualquer escrita', () {
      expect(datasource.read(), isNull);
    });

    test('write guarda conteudo e etag numa linha so', () {
      datasource.write(content: content, etag: '"abc"');
      datasource.write(content: '{}', etag: null);
      expect(isar.gestureDictionaryCaches.where().count(), 1);
      final entry = datasource.read()!;
      expect(entry.content, '{}');
      expect(entry.etag, isNull);
    });

    test('touch atualiza fetchedAt sem trocar o conteudo', () async {
      datasource.write(content: content, etag: '"abc"');
      final before = datasource.read()!.fetchedAt;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      datasource.touch();
      final after = datasource.read()!;
      expect(after.content, content);
      expect(after.etag, '"abc"');
      expect(after.fetchedAt.isAfter(before), isTrue);
    });

    test('touch sem linha e no-op', () {
      expect(datasource.touch, returnsNormally);
      expect(datasource.read(), isNull);
    });
  });

  test('sem Isar: read null, write/touch nao lancam', () {
    const datasource = GestureDictionaryLocalDatasource(null);
    expect(() => datasource.write(content: content, etag: null), returnsNormally);
    expect(datasource.touch, returnsNormally);
    expect(datasource.read(), isNull);
  });

  test('isStaleAt respeita kGestureDictionaryTtl (1 h)', () {
    final now = DateTime(2026, 9, 11, 12);
    final fresh = GestureDictionaryCacheEntry(content: 'x', etag: null, fetchedAt: now.subtract(const Duration(minutes: 59)));
    final stale = GestureDictionaryCacheEntry(content: 'x', etag: null, fetchedAt: now.subtract(const Duration(minutes: 61)));
    expect(fresh.isStaleAt(now), isFalse);
    expect(stale.isStaleAt(now), isTrue);
  });
}
```

- [ ] **Step 4: Rodar e ver falhar**

Run: `flutter test --dart-define-from-file=dart_defines/plpcg.json test/unit/features/gestures/gesture_content_local_datasource_test.dart test/unit/features/gestures/gesture_dictionary_local_datasource_test.dart`
Expected: falha de compilação.

- [ ] **Step 5: Implementar os datasources**

`lib/features/gestures/data/datasources/gesture_content_local_datasource.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:isar_plus/isar_plus.dart';

import '../../../../core/database/collections/gesture_document_cache.dart';

/// Entrada do cache: o JSON cru e quando ele foi buscado.
///
/// [content] vazio é o **marcador negativo** (404): evita um GET por abertura
/// no caso de material publicado sem objeto no R2.
class GestureCacheEntry {
  const GestureCacheEntry({required this.content, required this.fetchedAt});

  final String content;
  final DateTime fetchedAt;

  bool isStaleAt(DateTime now) => now.difference(fetchedAt) > kGestureCacheTtl;
}

/// Idade a partir da qual uma entrada é revalidada em background.
const kGestureCacheTtl = Duration(hours: 24);

/// Cache Isar do documento `.gestures`, indexado por `r2Key`.
///
/// Best-effort como o de cifras: sem Isar (web degradada) `read` devolve
/// `null` e `write` vira no-op registrado.
class GestureContentLocalDatasource {
  const GestureContentLocalDatasource(this._isar);

  final Isar? _isar;

  GestureCacheEntry? read(String r2Key) {
    final isar = _isar;
    final key = r2Key.trim();
    if (isar == null || key.isEmpty) return null;
    try {
      final row = isar.gestureDocumentCaches
          .where()
          .r2KeyEqualTo(key)
          .findFirst();
      if (row == null) return null;
      return GestureCacheEntry(content: row.content, fetchedAt: row.fetchedAt);
    } on Object catch (error) {
      debugPrint('[gestos] leitura do cache de $key falhou: $error');
      return null;
    }
  }

  void write(String r2Key, String content) {
    final isar = _isar;
    final key = r2Key.trim();
    if (key.isEmpty) return;
    if (isar == null) {
      debugPrint('[gestos] sem Isar — cache de $key não persistido');
      return;
    }
    try {
      isar.write((isar) {
        final coll = isar.gestureDocumentCaches;
        final row =
            coll.where().r2KeyEqualTo(key).findFirst() ??
            (GestureDocumentCache()..id = coll.autoIncrement());
        row
          ..r2Key = key
          ..content = content
          ..fetchedAt = DateTime.now();
        coll.put(row);
      });
    } on Object catch (error) {
      debugPrint('[gestos] escrita do cache de $key falhou: $error');
    }
  }
}
```

`lib/features/gestures/data/datasources/gesture_dictionary_local_datasource.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:isar_plus/isar_plus.dart';

import '../../../../core/database/collections/gesture_dictionary_cache.dart';

/// Entrada única do cache do dicionário.
class GestureDictionaryCacheEntry {
  const GestureDictionaryCacheEntry({
    required this.content,
    required this.etag,
    required this.fetchedAt,
  });

  final String content;
  final String? etag;
  final DateTime fetchedAt;

  bool isStaleAt(DateTime now) =>
      now.difference(fetchedAt) > kGestureDictionaryTtl;
}

/// Idade a partir da qual o dicionário é revalidado (`If-None-Match`).
///
/// Uma hora: o coldigom publica `max-age=300`, mas aqui a revalidação custa
/// um round-trip que na maioria das vezes devolve 304 — não precisa ser a cada
/// abertura de louvor.
const kGestureDictionaryTtl = Duration(hours: 1);

/// Cache Isar do dicionário — linha única `GestureDictionaryCache.singletonId`.
class GestureDictionaryLocalDatasource {
  const GestureDictionaryLocalDatasource(this._isar);

  final Isar? _isar;

  GestureDictionaryCacheEntry? read() {
    final isar = _isar;
    if (isar == null) return null;
    try {
      final row = isar.gestureDictionaryCaches.get(
        GestureDictionaryCache.singletonId,
      );
      if (row == null) return null;
      return GestureDictionaryCacheEntry(
        content: row.content,
        etag: row.etag,
        fetchedAt: row.fetchedAt,
      );
    } on Object catch (error) {
      debugPrint('[gestos] leitura do cache do dicionário falhou: $error');
      return null;
    }
  }

  void write({required String content, required String? etag}) {
    final isar = _isar;
    if (isar == null) {
      debugPrint('[gestos] sem Isar — dicionário não persistido');
      return;
    }
    try {
      isar.write((isar) {
        isar.gestureDictionaryCaches.put(
          GestureDictionaryCache()
            ..content = content
            ..etag = etag
            ..fetchedAt = DateTime.now(),
        );
      });
    } on Object catch (error) {
      debugPrint('[gestos] escrita do cache do dicionário falhou: $error');
    }
  }

  /// Renova [GestureDictionaryCacheEntry.fetchedAt] depois de um 304.
  void touch() {
    final isar = _isar;
    if (isar == null) return;
    try {
      isar.write((isar) {
        final coll = isar.gestureDictionaryCaches;
        final row = coll.get(GestureDictionaryCache.singletonId);
        if (row == null) return;
        coll.put(row..fetchedAt = DateTime.now());
      });
    } on Object catch (error) {
      debugPrint('[gestos] touch do dicionário falhou: $error');
    }
  }
}
```

- [ ] **Step 6: Rodar até passar; analyze; commit**

Run: `flutter test --dart-define-from-file=dart_defines/plpcg.json test/unit/features/gestures/ test/unit/core/database/ && flutter analyze`

```bash
git add lib/core/database lib/features/gestures/data/datasources test/unit/features/gestures/gesture_content_local_datasource_test.dart test/unit/features/gestures/gesture_dictionary_local_datasource_test.dart
git commit -m "feat(gestures): cache Isar do documento e do dicionário (com ETag)

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01DuSVKfiGsabi168JixJLB1"
```

---

### Task 6: Datasources remotos — documento por `r2Key` e dicionário com `If-None-Match`

**Files:**
- Create: `lib/features/gestures/data/constants/gesture_dictionary_config.dart`
- Create: `lib/features/gestures/data/datasources/gesture_content_datasource.dart`
- Create: `lib/features/gestures/data/datasources/gesture_dictionary_datasource.dart`
- Test: `test/unit/features/gestures/gesture_content_datasource_test.dart`, `test/unit/features/gestures/gesture_dictionary_datasource_test.dart`

**Interfaces:**
- Consumes: `ColdigomAssetUrl.fetchUrlForKey(key, apiBase:)` (`lib/core/utils/coldigom_asset_url.dart`).
- Produces: `GestureFetchFailedException(r2Key, cause)`; `GestureContentDatasource(Dio, {required String apiBase}) { Future<String?> fetchContent(String r2Key) }`; `GestureDictionaryConfig.baseUrl` (String) e `GestureDictionaryConfig.path = '/api/gestures/dictionary'`; `sealed GestureDictionaryFetchResult` com `GestureDictionaryFresh(body, etag)`, `GestureDictionaryNotModified()`, `GestureDictionaryNotFound()`; `GestureDictionaryDatasource(Dio, {required String baseUrl}) { Future<GestureDictionaryFetchResult> fetch({String? etag}) }` (lança `GestureFetchFailedException('dictionary', cause)` em rede/5xx).

- [ ] **Step 1: Testes (falhando)**

`test/unit/features/gestures/gesture_content_datasource_test.dart`:

```dart
import 'package:coldigui/features/gestures/data/datasources/gesture_content_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Interceptor que responde da tabela [routes] sem tocar na rede.
class _FakeAdapter extends Interceptor {
  _FakeAdapter(this.routes, {this.offline = false});

  final Map<String, (int status, String body)> routes;
  final bool offline;
  final requestedPaths = <String>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requestedPaths.add(options.path);
    if (offline) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );
      return;
    }
    final route = routes[options.path];
    if (route == null) {
      handler.reject(
        DioException(
          requestOptions: options,
          response: Response<String>(requestOptions: options, statusCode: 404),
          type: DioExceptionType.badResponse,
        ),
      );
      return;
    }
    handler.resolve(
      Response<String>(
        requestOptions: options,
        statusCode: route.$1,
        data: route.$2,
      ),
    );
  }
}

GestureContentDatasource _datasource(_FakeAdapter adapter) {
  final dio = Dio()..interceptors.add(adapter);
  return GestureContentDatasource(dio, apiBase: 'https://plpcg.com');
}

void main() {
  const key = 'assets/praises/p1/m1.gestures';
  const url = 'https://plpcg.com/api/coldigom/$key';
  const body = '{"schema":"coldigom.gestures/1","items":[]}';

  test('200 devolve o corpo cru, buscando pelo proxy', () async {
    final adapter = _FakeAdapter({url: (200, body)});
    final content = await _datasource(adapter).fetchContent(key);
    expect(content, body);
    expect(adapter.requestedPaths.single, url);
  });

  test('404 devolve null', () async {
    expect(await _datasource(_FakeAdapter(const {})).fetchContent(key), isNull);
  });

  test('corpo vazio devolve null (lápide)', () async {
    expect(await _datasource(_FakeAdapter({url: (200, '  ')})).fetchContent(key), isNull);
  });

  test('chave vazia devolve null sem ir à rede', () async {
    final adapter = _FakeAdapter(const {});
    expect(await _datasource(adapter).fetchContent('  '), isNull);
    expect(adapter.requestedPaths, isEmpty);
  });

  test('queda de rede lança GestureFetchFailedException', () async {
    await expectLater(
      _datasource(_FakeAdapter(const {}, offline: true)).fetchContent(key),
      throwsA(isA<GestureFetchFailedException>()),
    );
  });

  test('500 lança GestureFetchFailedException', () async {
    await expectLater(
      _datasource(_FakeAdapter({url: (500, 'boom')})).fetchContent(key),
      throwsA(isA<GestureFetchFailedException>()),
    );
  });
}
```

`test/unit/features/gestures/gesture_dictionary_datasource_test.dart`:

```dart
import 'package:coldigui/features/gestures/data/datasources/gesture_content_datasource.dart';
import 'package:coldigui/features/gestures/data/datasources/gesture_dictionary_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAdapter extends Interceptor {
  _FakeAdapter({
    required this.status,
    this.body = '',
    this.etag,
    this.offline = false,
  });

  final int status;
  final String body;
  final String? etag;
  final bool offline;
  final requests = <RequestOptions>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requests.add(options);
    if (offline) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );
      return;
    }
    final response = Response<String>(
      requestOptions: options,
      statusCode: status,
      data: body,
      headers: Headers.fromMap({
        if (etag != null) 'etag': [etag!],
      }),
    );
    if (status >= 400) {
      handler.reject(
        DioException(
          requestOptions: options,
          response: response,
          type: DioExceptionType.badResponse,
        ),
      );
      return;
    }
    handler.resolve(response);
  }
}

GestureDictionaryDatasource _datasource(_FakeAdapter adapter) {
  final dio = Dio()..interceptors.add(adapter);
  return GestureDictionaryDatasource(dio, baseUrl: 'https://coldigom.test');
}

void main() {
  const body = '{"version":3,"gestures":[]}';

  test('200 devolve Fresh com corpo e etag, na URL certa', () async {
    final adapter = _FakeAdapter(status: 200, body: body, etag: '"v3"');
    final result = await _datasource(adapter).fetch();
    expect(result, isA<GestureDictionaryFresh>());
    final fresh = result as GestureDictionaryFresh;
    expect(fresh.body, body);
    expect(fresh.etag, '"v3"');
    expect(adapter.requests.single.path, 'https://coldigom.test/api/gestures/dictionary');
    expect(adapter.requests.single.headers.containsKey('If-None-Match'), isFalse);
  });

  test('manda If-None-Match quando há etag; 304 devolve NotModified', () async {
    final adapter = _FakeAdapter(status: 304);
    final result = await _datasource(adapter).fetch(etag: '"v3"');
    expect(result, isA<GestureDictionaryNotModified>());
    expect(adapter.requests.single.headers['If-None-Match'], '"v3"');
  });

  test('404 devolve NotFound', () async {
    expect(await _datasource(_FakeAdapter(status: 404)).fetch(), isA<GestureDictionaryNotFound>());
  });

  test('rede e 500 lançam GestureFetchFailedException', () async {
    await expectLater(
      _datasource(_FakeAdapter(status: 200, offline: true)).fetch(),
      throwsA(isA<GestureFetchFailedException>()),
    );
    await expectLater(
      _datasource(_FakeAdapter(status: 500)).fetch(),
      throwsA(isA<GestureFetchFailedException>()),
    );
  });

  test('baseUrl com barra final não duplica a barra', () async {
    final adapter = _FakeAdapter(status: 200, body: body);
    final dio = Dio()..interceptors.add(adapter);
    await GestureDictionaryDatasource(dio, baseUrl: 'https://x.test/').fetch();
    expect(adapter.requests.single.path, 'https://x.test/api/gestures/dictionary');
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test --dart-define-from-file=dart_defines/plpcg.json test/unit/features/gestures/gesture_content_datasource_test.dart test/unit/features/gestures/gesture_dictionary_datasource_test.dart`
Expected: falha de compilação.

- [ ] **Step 3: Implementar**

`lib/features/gestures/data/constants/gesture_dictionary_config.dart`:

```dart
import '../../../coldigom/data/constants/coldigom_api_config.dart';

/// Onde buscar `GET /api/gestures/dictionary`.
///
/// Por padrão é o Worker coldigom ([ColdigomApiConfig.baseUrl]).
/// `--dart-define=GESTURE_DICTIONARY_BASE_URL=http://localhost:8787` aponta
/// para outro servidor enquanto o coldigom não publica o dicionário real.
abstract final class GestureDictionaryConfig {
  static const String _override = String.fromEnvironment(
    'GESTURE_DICTIONARY_BASE_URL',
  );

  static String get baseUrl =>
      _override.isEmpty ? ColdigomApiConfig.baseUrl : _override;

  static const String path = '/api/gestures/dictionary';
}
```

`lib/features/gestures/data/datasources/gesture_content_datasource.dart`:

```dart
import 'package:dio/dio.dart';

import '../../../../core/utils/coldigom_asset_url.dart';

/// Falha ao buscar um recurso de gestos — rede, timeout ou status inesperado.
///
/// Separa "não existe" (404 → `null`) de "não deu para saber agora": sem isso
/// uma queda de rede viraria, para o resto do app, um louvor sem gestos.
class GestureFetchFailedException implements Exception {
  const GestureFetchFailedException(this.resource, this.cause);

  /// `r2Key` do documento, ou `'dictionary'`.
  final String resource;

  final Object cause;

  @override
  String toString() => 'GestureFetchFailedException($resource): $cause';
}

/// Busca o JSON `.gestures` de um material coldigom.
///
/// Mesma escada do `ChordContentDatasource`: um GET pelo proxy de assets
/// resolve "existe?" e "qual é?" de uma vez — o arquivo tem poucos KB.
class GestureContentDatasource {
  // Dart não aceita identificador privado como rótulo de parâmetro nomeado.
  const GestureContentDatasource(this._dio, {required String apiBase})
    // ignore: prefer_initializing_formals
    : _apiBase = apiBase;

  final Dio _dio;
  final String _apiBase;

  /// JSON cru, ou `null` quando o arquivo não existe (chave vazia, 404, corpo
  /// vazio). Qualquer outra falha vira [GestureFetchFailedException].
  Future<String?> fetchContent(String r2Key) async {
    final key = r2Key.trim();
    if (key.isEmpty) return null;

    final url = ColdigomAssetUrl.fetchUrlForKey(key, apiBase: _apiBase);

    final Response<String> response;
    try {
      response = await _dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      throw GestureFetchFailedException(key, error);
    } on Object catch (error) {
      throw GestureFetchFailedException(key, error);
    }

    final status = response.statusCode;
    if (status == 404) return null;
    if (status != 200) {
      throw GestureFetchFailedException(
        key,
        DioException.badResponse(
          statusCode: status ?? 0,
          requestOptions: response.requestOptions,
          response: response,
        ),
      );
    }

    final body = response.data ?? '';
    return body.trim().isEmpty ? null : body;
  }
}
```

`lib/features/gestures/data/datasources/gesture_dictionary_datasource.dart`:

```dart
import 'package:dio/dio.dart';

import '../constants/gesture_dictionary_config.dart';
import 'gesture_content_datasource.dart';

/// Resultado de `GET /api/gestures/dictionary`.
sealed class GestureDictionaryFetchResult {
  const GestureDictionaryFetchResult();
}

/// 200: corpo novo (com o `ETag` que o servidor mandou, se mandou).
final class GestureDictionaryFresh extends GestureDictionaryFetchResult {
  const GestureDictionaryFresh({required this.body, required this.etag});

  final String body;
  final String? etag;
}

/// 304: o cache continua válido.
final class GestureDictionaryNotModified extends GestureDictionaryFetchResult {
  const GestureDictionaryNotModified();
}

/// 404: o coldigom ainda não publica o dicionário.
final class GestureDictionaryNotFound extends GestureDictionaryFetchResult {
  const GestureDictionaryNotFound();
}

/// Busca o dicionário com `If-None-Match`.
///
/// É chamada de API JSON (como `/api/plpcg/praises`), não de asset: vai
/// direto na base, sem o proxy `/api/coldigom/*` (esse só existe para assets
/// sob COEP). A URL é absoluta para o `--dart-define` de override funcionar
/// mesmo com o `baseUrl` do `Dio` apontando para o coldigom.
class GestureDictionaryDatasource {
  const GestureDictionaryDatasource(this._dio, {required String baseUrl})
    // ignore: prefer_initializing_formals
    : _baseUrl = baseUrl;

  final Dio _dio;
  final String _baseUrl;

  String get _url {
    final base = _baseUrl.trim();
    final trimmed = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return '$trimmed${GestureDictionaryConfig.path}';
  }

  Future<GestureDictionaryFetchResult> fetch({String? etag}) async {
    final Response<String> response;
    try {
      response = await _dio.get<String>(
        _url,
        options: Options(
          responseType: ResponseType.plain,
          headers: {if (etag != null && etag.isNotEmpty) 'If-None-Match': etag},
          // 304 não é erro: deixa passar para o `switch` abaixo.
          validateStatus: (status) =>
              status != null && (status < 400 || status == 404),
        ),
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return const GestureDictionaryNotFound();
      }
      throw GestureFetchFailedException('dictionary', error);
    } on Object catch (error) {
      throw GestureFetchFailedException('dictionary', error);
    }

    switch (response.statusCode) {
      case 200:
        return GestureDictionaryFresh(
          body: response.data ?? '',
          etag: response.headers.value('etag'),
        );
      case 304:
        return const GestureDictionaryNotModified();
      case 404:
        return const GestureDictionaryNotFound();
      default:
        throw GestureFetchFailedException(
          'dictionary',
          DioException.badResponse(
            statusCode: response.statusCode ?? 0,
            requestOptions: response.requestOptions,
            response: response,
          ),
        );
    }
  }
}
```

- [ ] **Step 4: Rodar até passar; analyze; commit**

Run: `flutter test --dart-define-from-file=dart_defines/plpcg.json test/unit/features/gestures/ && flutter analyze`

```bash
git add lib/features/gestures/data test/unit/features/gestures/gesture_content_datasource_test.dart test/unit/features/gestures/gesture_dictionary_datasource_test.dart
git commit -m "feat(gestures): datasources remotos do documento e do dicionário (If-None-Match)

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01DuSVKfiGsabi168JixJLB1"
```

---

### Task 7: Store de figuras (nativo + web) e repositório

**Files:**
- Create: `lib/features/gestures/data/datasources/gesture_figure_store.dart`
- Create: `lib/features/gestures/data/datasources/gesture_figure_store_native.dart`
- Create: `lib/features/gestures/data/datasources/gesture_figure_store_web.dart`
- Create: `lib/features/gestures/data/repositories/gesture_figure_repository.dart`
- Test: `test/unit/features/gestures/gesture_figure_store_native_test.dart`, `test/unit/features/gestures/gesture_figure_repository_test.dart`

**Interfaces:**
- Produces: `abstract interface class GestureFigureStorePort { Future<Uint8List?> read(String r2Key); Future<void> write(String r2Key, Uint8List bytes); Future<void> deleteAll() }`; `GestureFigureStorePort createGestureFigureStore()` (import condicional); `String gestureFigureFileName(String r2Key)`; `GestureFigureRepository(GestureFigureStorePort, Dio, {required String apiBase}) { Future<Uint8List?> get(String r2Key); Future<void> prefetch(Iterable<String> r2Keys) }`.

- [ ] **Step 1: Testes (falhando)**

`test/unit/features/gestures/gesture_figure_store_native_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/features/gestures/data/datasources/gesture_figure_store.dart';
import 'package:coldigui/features/gestures/data/datasources/gesture_figure_store_native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late GestureFigureStoreNative store;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('gesture_figures_');
    store = GestureFigureStoreNative(
      getApplicationDocumentsDirectory: () async => tempDir,
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('gestureFigureFileName saneia a chave', () {
    expect(
      gestureFigureFileName('assets/cia/gestures/c687580e7682.png'),
      'assets_cia_gestures_c687580e7682.png',
    );
    expect(gestureFigureFileName('a b/ç.gif'), 'a_b__.gif');
  });

  test('read devolve null antes de escrever', () async {
    expect(await store.read('assets/cia/gestures/x.png'), isNull);
  });

  test('write grava em plpcg_gestures/figures e read devolve os bytes', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    await store.write('assets/cia/gestures/x.png', bytes);

    expect(await store.read('assets/cia/gestures/x.png'), bytes);
    expect(
      File('${tempDir.path}/plpcg_gestures/figures/assets_cia_gestures_x.png').existsSync(),
      isTrue,
    );
    expect(
      Directory('${tempDir.path}/plpcg_gestures/figures').listSync().any((f) => f.path.endsWith('.tmp')),
      isFalse,
    );
  });

  test('deleteAll apaga tudo e read volta a null', () async {
    await store.write('k.png', Uint8List.fromList([9]));
    await store.deleteAll();
    expect(await store.read('k.png'), isNull);
  });
}
```

`test/unit/features/gestures/gesture_figure_repository_test.dart`:

```dart
import 'dart:typed_data';

import 'package:coldigui/features/gestures/data/datasources/gesture_figure_store.dart';
import 'package:coldigui/features/gestures/data/repositories/gesture_figure_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStore implements GestureFigureStorePort {
  final rows = <String, Uint8List>{};
  int writes = 0;

  @override
  Future<Uint8List?> read(String r2Key) async => rows[r2Key];

  @override
  Future<void> write(String r2Key, Uint8List bytes) async {
    writes++;
    rows[r2Key] = bytes;
  }

  @override
  Future<void> deleteAll() async => rows.clear();
}

class _FakeAdapter extends Interceptor {
  _FakeAdapter(this.routes, {this.offline = false});

  final Map<String, List<int>> routes;
  final bool offline;
  final requested = <String>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requested.add(options.path);
    if (offline) {
      handler.reject(DioException(requestOptions: options, type: DioExceptionType.connectionError));
      return;
    }
    final body = routes[options.path];
    if (body == null) {
      handler.reject(
        DioException(
          requestOptions: options,
          response: Response<dynamic>(requestOptions: options, statusCode: 404),
          type: DioExceptionType.badResponse,
        ),
      );
      return;
    }
    handler.resolve(
      Response<List<int>>(requestOptions: options, statusCode: 200, data: body),
    );
  }
}

GestureFigureRepository _repo(_MemoryStore store, _FakeAdapter adapter) {
  final dio = Dio()..interceptors.add(adapter);
  return GestureFigureRepository(store, dio, apiBase: 'https://plpcg.com');
}

void main() {
  const key = 'assets/cia/gestures/c687580e7682.png';
  const url = 'https://plpcg.com/api/coldigom/$key';

  test('hit no store não vai à rede', () async {
    final store = _MemoryStore()..rows[key] = Uint8List.fromList([7]);
    final adapter = _FakeAdapter(const {});
    expect(await _repo(store, adapter).get(key), [7]);
    expect(adapter.requested, isEmpty);
  });

  test('miss baixa pelo proxy, grava e devolve', () async {
    final store = _MemoryStore();
    final adapter = _FakeAdapter({url: [1, 2]});
    expect(await _repo(store, adapter).get(key), [1, 2]);
    expect(adapter.requested.single, url);
    expect(store.rows[key], [1, 2]);
  });

  test('404 e rede devolvem null sem lançar', () async {
    expect(await _repo(_MemoryStore(), _FakeAdapter(const {})).get(key), isNull);
    expect(await _repo(_MemoryStore(), _FakeAdapter(const {}, offline: true)).get(key), isNull);
  });

  test('chave vazia devolve null', () async {
    expect(await _repo(_MemoryStore(), _FakeAdapter(const {})).get(''), isNull);
  });

  test('prefetch baixa só o que falta e ignora falhas', () async {
    final store = _MemoryStore()..rows['a.png'] = Uint8List.fromList([0]);
    final adapter = _FakeAdapter({
      'https://plpcg.com/api/coldigom/b.png': [1],
      // c.png não existe → 404, ignorado.
    });
    await _repo(store, adapter).prefetch(['a.png', 'b.png', 'c.png', 'b.png']);
    expect(store.rows.keys, containsAll(['a.png', 'b.png']));
    expect(store.rows.containsKey('c.png'), isFalse);
    expect(adapter.requested.where((p) => p.endsWith('b.png')).length, 1);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test --dart-define-from-file=dart_defines/plpcg.json test/unit/features/gestures/gesture_figure_store_native_test.dart test/unit/features/gestures/gesture_figure_repository_test.dart`
Expected: falha de compilação.

- [ ] **Step 3: Implementar o port e a factory**

`lib/features/gestures/data/datasources/gesture_figure_store.dart`:

```dart
import 'dart:typed_data';

import 'gesture_figure_store_native.dart'
    if (dart.library.js_interop) 'gesture_figure_store_web.dart';

/// Persistência das figuras PNG/GIF dos gestos, por `r2Key`.
///
/// Espelha `PdfStoragePort` na forma (filesystem no nativo, Cache API na web)
/// mas num store **separado** dos PDFs: as figuras não entram nas
/// estatísticas do UC-10 (`getTotalOfflineBytes`/`listOrphans`), que contam o
/// que o usuário baixou de propósito.
///
/// Best-effort: nenhuma operação lança — figura que não gravou vira download
/// de novo na próxima abertura, nunca erro de tela.
abstract interface class GestureFigureStorePort {
  Future<Uint8List?> read(String r2Key);
  Future<void> write(String r2Key, Uint8List bytes);
  Future<void> deleteAll();
}

/// Subdiretório (nativo) / prefixo lógico (web) do store.
const kGestureFigureStoreSubdir = 'plpcg_gestures/figures';

/// Nome de arquivo estável e seguro para [r2Key].
///
/// `assets/cia/gestures/c687580e7682.png` → `assets_cia_gestures_c687580e7682.png`.
/// Não é hash de propósito: dá para achar a figura no disco pelo id.
String gestureFigureFileName(String r2Key) =>
    r2Key.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

/// Factory por plataforma (import condicional).
GestureFigureStorePort createGestureFigureStore() =>
    createGestureFigureStoreImpl();
```

- [ ] **Step 4: Implementar o store nativo**

`lib/features/gestures/data/datasources/gesture_figure_store_native.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart' as path_provider;

import 'gesture_figure_store.dart';

typedef _GetDirectory = Future<Directory> Function();

GestureFigureStorePort createGestureFigureStoreImpl() =>
    GestureFigureStoreNative();

/// Store nativo: `{ApplicationDocumentsDirectory}/plpcg_gestures/figures/`.
class GestureFigureStoreNative implements GestureFigureStorePort {
  GestureFigureStoreNative({_GetDirectory? getApplicationDocumentsDirectory})
    : _getDocuments =
          getApplicationDocumentsDirectory ??
          path_provider.getApplicationDocumentsDirectory;

  final _GetDirectory _getDocuments;
  Directory? _root;

  Future<Directory> _rootDir() async {
    final cached = _root;
    if (cached != null) return cached;
    final docs = await _getDocuments();
    final root = Directory('${docs.path}/$kGestureFigureStoreSubdir');
    if (!await root.exists()) await root.create(recursive: true);
    return _root = root;
  }

  Future<File> _fileFor(String r2Key) async =>
      File('${(await _rootDir()).path}/${gestureFigureFileName(r2Key)}');

  @override
  Future<Uint8List?> read(String r2Key) async {
    if (r2Key.trim().isEmpty) return null;
    try {
      final file = await _fileFor(r2Key);
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } on Object catch (error) {
      debugPrint('[gestos] leitura da figura $r2Key falhou: $error');
      return null;
    }
  }

  /// `.tmp` + rename: uma queda no meio da escrita não deixa PNG truncado.
  @override
  Future<void> write(String r2Key, Uint8List bytes) async {
    if (r2Key.trim().isEmpty) return;
    File? tmp;
    try {
      final file = await _fileFor(r2Key);
      tmp = File('${file.path}.tmp');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(file.path);
    } on Object catch (error) {
      debugPrint('[gestos] escrita da figura $r2Key falhou: $error');
      try {
        if (tmp != null && await tmp.exists()) await tmp.delete();
      } on Object {
        // Melhor esforço.
      }
    }
  }

  @override
  Future<void> deleteAll() async {
    try {
      final root = await _rootDir();
      if (await root.exists()) await root.delete(recursive: true);
      _root = null;
    } on Object catch (error) {
      debugPrint('[gestos] limpeza das figuras falhou: $error');
    }
  }
}
```

- [ ] **Step 5: Implementar o store web**

`lib/features/gestures/data/datasources/gesture_figure_store_web.dart`:

```dart
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart';

import 'gesture_figure_store.dart';

GestureFigureStorePort createGestureFigureStoreImpl() => GestureFigureStoreWeb();

/// Store web via Cache API, mesma técnica de `PdfStorageWeb` mas em cache
/// próprio (`plpcg-gesture-figures`), para não colidir com os PDFs offline.
class GestureFigureStoreWeb implements GestureFigureStorePort {
  static const _cacheName = 'plpcg-gesture-figures';
  static const _origin = 'https://plpcg-gestures.local';

  Cache? _cache;

  Future<Cache> _openCache() async =>
      _cache ??= await window.caches.open(_cacheName).toDart;

  Request _requestFor(String r2Key) => Request(
    Uri(
      scheme: 'https',
      host: Uri.parse(_origin).host,
      pathSegments: [kGestureFigureStoreSubdir, gestureFigureFileName(r2Key)],
    ).toString().toJS,
  );

  @override
  Future<Uint8List?> read(String r2Key) async {
    if (r2Key.trim().isEmpty) return null;
    try {
      final cache = await _openCache();
      final response = await cache.match(_requestFor(r2Key)).toDart;
      if (response == null) return null;
      final buffer = await response.arrayBuffer().toDart;
      return Uint8List.view(buffer.toDart);
    } on Object catch (error) {
      debugPrint('[gestos] leitura da figura $r2Key falhou: $error');
      return null;
    }
  }

  @override
  Future<void> write(String r2Key, Uint8List bytes) async {
    if (r2Key.trim().isEmpty) return;
    try {
      final cache = await _openCache();
      final type = r2Key.toLowerCase().endsWith('.gif') ? 'image/gif' : 'image/png';
      final blob = Blob([bytes.toJS].toJS, BlobPropertyBag(type: type));
      await cache
          .put(_requestFor(r2Key), Response(blob, ResponseInit(status: 200)))
          .toDart;
    } on Object catch (error) {
      // Quota estourada ou Cache API indisponível: a figura fica só em
      // memória nesta sessão.
      debugPrint('[gestos] escrita da figura $r2Key falhou: $error');
    }
  }

  @override
  Future<void> deleteAll() async {
    try {
      await window.caches.delete(_cacheName).toDart;
      _cache = null;
    } on Object catch (error) {
      debugPrint('[gestos] limpeza das figuras falhou: $error');
    }
  }
}
```

Se `flutter analyze` reclamar de algum nome do `package:web` (`ResponseInit`, `BlobPropertyBag`, `arrayBuffer`), confira como `lib/features/offline/data/datasources/pdf_storage_web.dart` usa o mesmo nome e copie a forma.

- [ ] **Step 6: Implementar o repositório**

`lib/features/gestures/data/repositories/gesture_figure_repository.dart`:

```dart
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/utils/coldigom_asset_url.dart';
import '../datasources/gesture_figure_store.dart';

/// Figuras dos gestos: store local primeiro, rede só no miss.
///
/// Tudo best-effort e sem exceção para fora: figura que não veio é
/// placeholder na tela, e a próxima abertura tenta de novo.
class GestureFigureRepository {
  const GestureFigureRepository(this._store, this._dio, {required String apiBase})
    // ignore: prefer_initializing_formals
    : _apiBase = apiBase;

  final GestureFigureStorePort _store;
  final Dio _dio;
  final String _apiBase;

  /// Quantos downloads em voo o [prefetch] mantém.
  static const int prefetchConcurrency = 4;

  /// Bytes da figura, do store ou da rede; `null` se não deu.
  Future<Uint8List?> get(String r2Key) async {
    final key = r2Key.trim();
    if (key.isEmpty) return null;

    final cached = await _store.read(key);
    if (cached != null) return cached;

    final bytes = await _download(key);
    if (bytes == null) return null;
    await _store.write(key, bytes);
    return bytes;
  }

  /// Aquece o store com [r2Keys] (deduplicadas), ignorando falhas.
  Future<void> prefetch(Iterable<String> r2Keys) async {
    final pending = r2Keys.map((k) => k.trim()).where((k) => k.isNotEmpty).toSet().toList();
    Future<void> worker() async {
      while (pending.isNotEmpty) {
        final key = pending.removeLast();
        await get(key);
      }
    }

    await Future.wait([for (var i = 0; i < prefetchConcurrency; i++) worker()]);
  }

  Future<Uint8List?> _download(String key) async {
    final url = ColdigomAssetUrl.fetchUrlForKey(key, apiBase: _apiBase);
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      if (response.statusCode != 200 || data == null || data.isEmpty) {
        return null;
      }
      return Uint8List.fromList(data);
    } on Object catch (error) {
      debugPrint('[gestos] download da figura $key falhou: $error');
      return null;
    }
  }
}
```

- [ ] **Step 7: Rodar até passar; analyze (inclui a versão web); commit**

Run: `flutter test --dart-define-from-file=dart_defines/plpcg.json test/unit/features/gestures/ && flutter analyze`

```bash
git add lib/features/gestures/data test/unit/features/gestures/gesture_figure_store_native_test.dart test/unit/features/gestures/gesture_figure_repository_test.dart
git commit -m "feat(gestures): store de figuras nativo/web e repositório com prefetch

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01DuSVKfiGsabi168JixJLB1"
```

---

### Task 8: Providers — documento, dicionário, figura, prefetch e fonte

**Files:**
- Create: `lib/features/gestures/data/datasources/gesture_reader_preferences_datasource.dart`
- Create: `lib/features/gestures/data/providers/gesture_providers.dart`
- Create: `lib/features/gestures/presentation/providers/gesture_reader_font_size_provider.dart`
- Test: `test/unit/features/gestures/gesture_document_provider_test.dart`, `test/unit/features/gestures/gesture_dictionary_provider_test.dart`, `test/unit/features/gestures/gesture_reader_font_size_provider_test.dart`

**Interfaces:**
- Consumes: T1–T7; `optionalIsarProvider` (`lib/core/database/isar_provider.dart`), `coldigomDioProvider`, `deviceConnectivityProvider`, `sharedPreferencesProvider` (`lib/core/providers/shared_prefs_provider.dart`), `AppConfig.apiBaseUrl` (`lib/core/constants/app_config.dart`).
- Produces: `gestureContentDatasourceProvider`, `gestureContentLocalDatasourceProvider`, `gestureDictionaryDatasourceProvider`, `gestureDictionaryLocalDatasourceProvider`, `gestureFigureStoreProvider`, `gestureFigureRepositoryProvider`; `gestureDocumentProvider(r2Key)` → `FutureProvider.autoDispose.family<GestureDocument?, String>`; `gestureDictionaryProvider` → `FutureProvider<GestureDictionary?>`; `gestureFigureProvider(r2Key)` → `FutureProvider.family<Uint8List?, String>`; `void prefetchGestureFigures(GestureFigureRepository repository, GestureDocument doc, GestureDictionary dict)`; `gestureReaderFontSizeProvider` → `NotifierProvider<GestureReaderFontSizeNotifier, double>` com `increase()`/`decrease()`.

- [ ] **Step 1: Testes (falhando)**

`test/unit/features/gestures/gesture_document_provider_test.dart`:

```dart
import 'package:coldigui/core/network/device_connectivity.dart';
import 'package:coldigui/core/providers/device_connectivity_provider.dart';
import 'package:coldigui/features/gestures/data/datasources/gesture_content_datasource.dart';
import 'package:coldigui/features/gestures/data/datasources/gesture_content_local_datasource.dart';
import 'package:coldigui/features/gestures/data/providers/gesture_providers.dart';
import 'package:coldigui/features/gestures/domain/entities/gesture_document.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _key = 'assets/praises/p1/m1.gestures';
const _content = '{"schema":"coldigom.gestures/1","title":"A","items":[{"type":"text","text":"x"}]}';
const _outro = '{"schema":"coldigom.gestures/1","title":"B","items":[{"type":"text","text":"y"}]}';

class _FakeRemote implements GestureContentDatasource {
  _FakeRemote({this.body, this.failure});

  String? body;
  Object? failure;
  int calls = 0;

  @override
  Future<String?> fetchContent(String r2Key) async {
    calls++;
    if (failure != null) throw failure!;
    return body;
  }
}

class _FakeLocal implements GestureContentLocalDatasource {
  final rows = <String, GestureCacheEntry>{};
  int writes = 0;

  void seed(String r2Key, String content, {Duration idade = Duration.zero}) {
    rows[r2Key] = GestureCacheEntry(content: content, fetchedAt: DateTime.now().subtract(idade));
  }

  @override
  GestureCacheEntry? read(String r2Key) => rows[r2Key];

  @override
  void write(String r2Key, String content) {
    writes++;
    rows[r2Key] = GestureCacheEntry(content: content, fetchedAt: DateTime.now());
  }
}

class _FakeConnectivity implements DeviceConnectivity {
  _FakeConnectivity(this.online);
  bool online;
  @override
  Future<bool> hasConnection() async => online;
}

ProviderContainer _container({required _FakeRemote remote, required _FakeLocal local, bool online = true}) {
  final container = ProviderContainer(
    overrides: [
      gestureContentDatasourceProvider.overrideWithValue(remote),
      gestureContentLocalDatasourceProvider.overrideWithValue(local),
      deviceConnectivityProvider.overrideWithValue(_FakeConnectivity(online)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Lê segurando uma inscrição (como um widget) e solta no fim; o `pump()`
/// deixa o Riverpod decidir se o elemento sobreviveu (`keepAlive`) ou não.
Future<AsyncValue<GestureDocument?>> _readWhileWatched(ProviderContainer c, String key) async {
  final sub = c.listen(gestureDocumentProvider(key), (_, _) {});
  final AsyncValue<GestureDocument?> result;
  try {
    await c.read(gestureDocumentProvider(key).future).then<void>((_) {}, onError: (Object _) {});
    result = c.read(gestureDocumentProvider(key));
  } finally {
    sub.close();
  }
  await c.pump();
  return result;
}

void main() {
  test('sucesso remoto grava no cache e parseia', () async {
    final remote = _FakeRemote(body: _content);
    final local = _FakeLocal();
    final result = await _readWhileWatched(_container(remote: remote, local: local), _key);

    expect(result.value?.title, 'A');
    expect(local.rows[_key]?.content, _content);
  });

  test('404 grava marcador negativo e devolve null', () async {
    final local = _FakeLocal();
    final result = await _readWhileWatched(_container(remote: _FakeRemote(body: null), local: local), _key);
    expect(result.value, isNull);
    expect(local.rows[_key]?.content, '');
  });

  test('cache fresco responde sem ir à rede', () async {
    final remote = _FakeRemote(body: _outro);
    final local = _FakeLocal()..seed(_key, _content);
    final result = await _readWhileWatched(_container(remote: remote, local: local), _key);
    expect(result.value?.title, 'A');
    expect(remote.calls, 0);
  });

  test('marcador negativo em cache devolve null sem rede', () async {
    final remote = _FakeRemote(body: _content);
    final local = _FakeLocal()..seed(_key, '');
    final result = await _readWhileWatched(_container(remote: remote, local: local), _key);
    expect(result.value, isNull);
    expect(remote.calls, 0);
  });

  test('cache stale + online revalida em background e troca o corpo', () async {
    final remote = _FakeRemote(body: _outro);
    final local = _FakeLocal()..seed(_key, _content, idade: const Duration(hours: 25));
    final c = _container(remote: remote, local: local);

    final sub = c.listen(gestureDocumentProvider(_key), (_, _) {});
    addTearDown(sub.close);
    final first = await c.read(gestureDocumentProvider(_key).future);
    expect(first?.title, 'A');

    await Future<void>.delayed(Duration.zero);
    await c.pump();
    final second = await c.read(gestureDocumentProvider(_key).future);
    expect(second?.title, 'B');
    expect(local.rows[_key]?.content, _outro);
  });

  test('cache stale + offline não revalida', () async {
    final remote = _FakeRemote(body: _outro);
    final local = _FakeLocal()..seed(_key, _content, idade: const Duration(hours: 25));
    await _readWhileWatched(_container(remote: remote, local: local, online: false), _key);
    await Future<void>.delayed(Duration.zero);
    expect(remote.calls, 0);
  });

  test('falha de rede vira AsyncError que não gruda: próxima leitura tenta de novo', () async {
    final remote = _FakeRemote(failure: const GestureFetchFailedException(_key, 'rede'));
    final local = _FakeLocal();
    final c = _container(remote: remote, local: local);

    final first = await _readWhileWatched(c, _key);
    expect(first.hasError, isTrue);
    expect(local.writes, 0);

    remote
      ..failure = null
      ..body = _content;
    final second = await _readWhileWatched(c, _key);
    expect(second.value?.title, 'A');
  });

  test('JSON inválido no cache vira AsyncError (conclusivo)', () async {
    final local = _FakeLocal()..seed(_key, '{nope');
    final result = await _readWhileWatched(_container(remote: _FakeRemote(), local: local), _key);
    expect(result.hasError, isTrue);
  });

  test('chave vazia devolve null sem tocar nada', () async {
    final remote = _FakeRemote(body: _content);
    final result = await _readWhileWatched(_container(remote: remote, local: _FakeLocal()), '');
    expect(result.value, isNull);
    expect(remote.calls, 0);
  });
}
```

`test/unit/features/gestures/gesture_dictionary_provider_test.dart`:

```dart
import 'package:coldigui/core/network/device_connectivity.dart';
import 'package:coldigui/core/providers/device_connectivity_provider.dart';
import 'package:coldigui/features/gestures/data/datasources/gesture_content_datasource.dart';
import 'package:coldigui/features/gestures/data/datasources/gesture_dictionary_datasource.dart';
import 'package:coldigui/features/gestures/data/datasources/gesture_dictionary_local_datasource.dart';
import 'package:coldigui/features/gestures/data/providers/gesture_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _v3 = '{"version":3,"gestures":[{"id":"aaaaaaaaaaaa","image":"a.png"}]}';
const _v4 = '{"version":4,"gestures":[{"id":"aaaaaaaaaaaa","image":"a.png"},{"id":"bbbbbbbbbbbb","image":"b.png"}]}';

class _FakeRemote implements GestureDictionaryDatasource {
  _FakeRemote(this.result, {this.failure});
  GestureDictionaryFetchResult result;
  Object? failure;
  final etagsSent = <String?>[];

  @override
  Future<GestureDictionaryFetchResult> fetch({String? etag}) async {
    etagsSent.add(etag);
    if (failure != null) throw failure!;
    return result;
  }
}

class _FakeLocal implements GestureDictionaryLocalDatasource {
  GestureDictionaryCacheEntry? row;
  int touches = 0;

  void seed(String content, {String? etag, Duration idade = Duration.zero}) {
    row = GestureDictionaryCacheEntry(content: content, etag: etag, fetchedAt: DateTime.now().subtract(idade));
  }

  @override
  GestureDictionaryCacheEntry? read() => row;

  @override
  void write({required String content, required String? etag}) {
    row = GestureDictionaryCacheEntry(content: content, etag: etag, fetchedAt: DateTime.now());
  }

  @override
  void touch() {
    touches++;
    final r = row;
    if (r != null) row = GestureDictionaryCacheEntry(content: r.content, etag: r.etag, fetchedAt: DateTime.now());
  }
}

class _FakeConnectivity implements DeviceConnectivity {
  _FakeConnectivity(this.online);
  final bool online;
  @override
  Future<bool> hasConnection() async => online;
}

ProviderContainer _container(_FakeRemote remote, _FakeLocal local, {bool online = true}) {
  final c = ProviderContainer(
    overrides: [
      gestureDictionaryDatasourceProvider.overrideWithValue(remote),
      gestureDictionaryLocalDatasourceProvider.overrideWithValue(local),
      deviceConnectivityProvider.overrideWithValue(_FakeConnectivity(online)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('sem cache: busca, grava corpo+etag e devolve', () async {
    final remote = _FakeRemote(const GestureDictionaryFresh(body: _v3, etag: '"3"'));
    final local = _FakeLocal();
    final dict = await _container(remote, local).read(gestureDictionaryProvider.future);
    expect(dict?.version, 3);
    expect(local.row?.etag, '"3"');
    expect(remote.etagsSent, [null]);
  });

  test('cache fresco responde sem rede', () async {
    final remote = _FakeRemote(const GestureDictionaryFresh(body: _v4, etag: '"4"'));
    final local = _FakeLocal()..seed(_v3, etag: '"3"');
    final dict = await _container(remote, local).read(gestureDictionaryProvider.future);
    expect(dict?.version, 3);
    expect(remote.etagsSent, isEmpty);
  });

  test('cache stale + online: manda If-None-Match; 304 só toca fetchedAt', () async {
    final remote = _FakeRemote(const GestureDictionaryNotModified());
    final local = _FakeLocal()..seed(_v3, etag: '"3"', idade: const Duration(hours: 2));
    final c = _container(remote, local);
    final dict = await c.read(gestureDictionaryProvider.future);
    expect(dict?.version, 3);
    await Future<void>.delayed(Duration.zero);
    expect(remote.etagsSent, ['"3"']);
    expect(local.touches, 1);
  });

  test('cache stale + online: 200 troca o corpo e invalida', () async {
    final remote = _FakeRemote(const GestureDictionaryFresh(body: _v4, etag: '"4"'));
    final local = _FakeLocal()..seed(_v3, etag: '"3"', idade: const Duration(hours: 2));
    final c = _container(remote, local);
    final sub = c.listen(gestureDictionaryProvider, (_, _) {});
    addTearDown(sub.close);
    expect((await c.read(gestureDictionaryProvider.future))?.version, 3);
    await Future<void>.delayed(Duration.zero);
    await c.pump();
    expect((await c.read(gestureDictionaryProvider.future))?.version, 4);
    expect(local.row?.etag, '"4"');
  });

  test('sem cache e sem rede: devolve null, não erro', () async {
    final remote = _FakeRemote(const GestureDictionaryFresh(body: _v3, etag: null), failure: const GestureFetchFailedException('dictionary', 'rede'));
    final dict = await _container(remote, _FakeLocal()).read(gestureDictionaryProvider.future);
    expect(dict, isNull);
  });

  test('404 devolve null e não grava', () async {
    final local = _FakeLocal();
    final dict = await _container(_FakeRemote(const GestureDictionaryNotFound()), local).read(gestureDictionaryProvider.future);
    expect(dict, isNull);
    expect(local.row, isNull);
  });
}
```

`test/unit/features/gestures/gesture_reader_font_size_provider_test.dart`:

```dart
import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/gestures/presentation/providers/gesture_reader_font_size_provider.dart';
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
  test('começa em 18 sem valor salvo', () async {
    final (c, _) = await _setup();
    expect(c.read(gestureReaderFontSizeProvider), 18);
  });

  test('lê o valor salvo, grampeado na faixa', () async {
    final (c, _) = await _setup(initial: {StorageKeys.gestureReaderFontSize: 99.0});
    expect(c.read(gestureReaderFontSizeProvider), 28);
  });

  test('increase/decrease persistem', () async {
    final (c, prefs) = await _setup();
    c.read(gestureReaderFontSizeProvider.notifier).increase();
    expect(c.read(gestureReaderFontSizeProvider), 20);
    expect(prefs.getDouble(StorageKeys.gestureReaderFontSize), 20);
    c.read(gestureReaderFontSizeProvider.notifier).decrease();
    c.read(gestureReaderFontSizeProvider.notifier).decrease();
    expect(c.read(gestureReaderFontSizeProvider), 16);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test --dart-define-from-file=dart_defines/plpcg.json test/unit/features/gestures/gesture_document_provider_test.dart test/unit/features/gestures/gesture_dictionary_provider_test.dart test/unit/features/gestures/gesture_reader_font_size_provider_test.dart`
Expected: falha de compilação.

- [ ] **Step 3: Preferências e notifier da fonte**

`lib/features/gestures/data/datasources/gesture_reader_preferences_datasource.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../domain/entities/gesture_reader_font_size.dart';

/// Persistência do corpo da letra do leitor de gestos.
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
}
```

`lib/features/gestures/presentation/providers/gesture_reader_font_size_provider.dart`:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../data/datasources/gesture_reader_preferences_datasource.dart';
import '../../domain/entities/gesture_reader_font_size.dart';

/// Corpo da letra no leitor de gestos, persistido entre sessões.
///
/// Mesmo padrão de `ChordReaderFontSizeNotifier`: `sharedPreferencesProvider`
/// é síncrono e o `main()` já o sobrescreve; testes de widget precisam de
/// `SharedPreferences.setMockInitialValues` **e** do override no `ProviderScope`.
class GestureReaderFontSizeNotifier extends Notifier<double> {
  @override
  double build() => _datasource.getFontSize();

  GestureReaderPreferencesDatasource get _datasource =>
      GestureReaderPreferencesDatasource(ref.read(sharedPreferencesProvider));

  void increase() => _set(GestureReaderFontSize.increase(state));

  void decrease() => _set(GestureReaderFontSize.decrease(state));

  void _set(double next) {
    if (next == state) return;
    state = next;
    unawaited(_datasource.saveFontSize(next));
  }
}

final gestureReaderFontSizeProvider =
    NotifierProvider<GestureReaderFontSizeNotifier, double>(
      GestureReaderFontSizeNotifier.new,
    );
```

- [ ] **Step 4: Providers de dados**

`lib/features/gestures/data/providers/gesture_providers.dart`:

```dart
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/database/isar_provider.dart';
import '../../../../core/providers/device_connectivity_provider.dart';
import '../../../coldigom/data/providers/coldigom_dio_provider.dart';
import '../../domain/entities/gesture_dictionary.dart';
import '../../domain/entities/gesture_document.dart';
import '../../domain/usecases/parse_gesture_dictionary.dart';
import '../../domain/usecases/parse_gesture_document.dart';
import '../../domain/utils/flatten_gesture_cards.dart';
import '../constants/gesture_dictionary_config.dart';
import '../datasources/gesture_content_datasource.dart';
import '../datasources/gesture_content_local_datasource.dart';
import '../datasources/gesture_dictionary_datasource.dart';
import '../datasources/gesture_dictionary_local_datasource.dart';
import '../datasources/gesture_figure_store.dart';
import '../repositories/gesture_figure_repository.dart';

final gestureContentDatasourceProvider = Provider<GestureContentDatasource>((ref) {
  return GestureContentDatasource(
    ref.watch(coldigomDioProvider),
    apiBase: AppConfig.apiBaseUrl,
  );
});

/// Cache Isar do documento; `null` de Isar = modo degradado.
final gestureContentLocalDatasourceProvider =
    Provider<GestureContentLocalDatasource>((ref) {
      return GestureContentLocalDatasource(ref.watch(optionalIsarProvider));
    });

final gestureDictionaryDatasourceProvider =
    Provider<GestureDictionaryDatasource>((ref) {
      return GestureDictionaryDatasource(
        ref.watch(coldigomDioProvider),
        baseUrl: GestureDictionaryConfig.baseUrl,
      );
    });

final gestureDictionaryLocalDatasourceProvider =
    Provider<GestureDictionaryLocalDatasource>((ref) {
      return GestureDictionaryLocalDatasource(ref.watch(optionalIsarProvider));
    });

final gestureFigureStoreProvider = Provider<GestureFigureStorePort>(
  (ref) => createGestureFigureStore(),
);

final gestureFigureRepositoryProvider = Provider<GestureFigureRepository>((ref) {
  return GestureFigureRepository(
    ref.watch(gestureFigureStoreProvider),
    ref.watch(coldigomDioProvider),
    apiBase: AppConfig.apiBaseUrl,
  );
});

/// Documento de um `r2Key`: `null` só quando o arquivo não existe.
///
/// Cópia do contrato do `chordSongProvider`: `autoDispose` + `keepAlive()` só
/// no sucesso (um `AsyncError` de rede não fica colado no louvor), cache-first
/// com revalidação em background quando stale e online, 404 grava marcador
/// negativo, `retry: null` desliga o backoff do Riverpod (quem abriu quer ver
/// "tentar de novo" agora). JSON inválido no cache ou na rede é conclusivo e
/// vira `AsyncError`.
final gestureDocumentProvider = FutureProvider.autoDispose
    .family<GestureDocument?, String>(retry: (_, _) => null, (ref, r2Key) async {
      final key = r2Key.trim();
      if (key.isEmpty) return null;

      final local = ref.watch(gestureContentLocalDatasourceProvider);
      final cached = local.read(key);
      if (cached != null) {
        if (cached.content.isEmpty) {
          ref.keepAlive();
          return null;
        }
        final doc = parseGestureDocument(cached.content);
        ref.keepAlive();
        if (cached.isStaleAt(DateTime.now())) {
          unawaited(_revalidateDocument(ref, key, cached.content, local));
        }
        return doc;
      }

      final remote = ref.watch(gestureContentDatasourceProvider);
      final content = await remote.fetchContent(key);
      if (content == null) {
        ref.keepAlive();
        local.write(key, '');
        return null;
      }
      final doc = parseGestureDocument(content);
      ref.keepAlive();
      local.write(key, content);
      return doc;
    });

Future<void> _revalidateDocument(
  Ref ref,
  String key,
  String cached,
  GestureContentLocalDatasource local,
) async {
  try {
    if (!await ref.read(deviceConnectivityProvider).hasConnection()) return;
    final fresh = await ref.read(gestureContentDatasourceProvider).fetchContent(key);
    if (fresh == null || fresh == cached) return;
    local.write(key, fresh);
    ref.invalidateSelf();
  } on Object catch (error) {
    debugPrint('[gestos] revalidação de $key falhou: $error');
  }
}

/// Dicionário global: `null` quando não há cache nem rede (a tela renderiza
/// com placeholders — não é erro).
///
/// Um objeto por sessão (`keepAlive` natural do `FutureProvider`). Cache-first;
/// stale + online → `If-None-Match`; 304 só renova `fetchedAt`.
final gestureDictionaryProvider = FutureProvider<GestureDictionary?>((ref) async {
  final local = ref.watch(gestureDictionaryLocalDatasourceProvider);
  final cached = local.read();
  if (cached != null) {
    final dict = _parseDictionaryOrNull(cached.content);
    if (dict != null) {
      if (cached.isStaleAt(DateTime.now())) {
        unawaited(_revalidateDictionary(ref, cached.etag, local));
      }
      return dict;
    }
  }

  final remote = ref.watch(gestureDictionaryDatasourceProvider);
  try {
    switch (await remote.fetch()) {
      case GestureDictionaryFresh(:final body, :final etag):
        final dict = _parseDictionaryOrNull(body);
        if (dict != null) local.write(content: body, etag: etag);
        return dict;
      case GestureDictionaryNotModified():
        // Sem cache local não há o que "não modificar"; trata como ausente.
        return null;
      case GestureDictionaryNotFound():
        return null;
    }
  } on GestureFetchFailedException catch (error) {
    debugPrint('[gestos] dicionário indisponível: $error');
    return null;
  }
});

GestureDictionary? _parseDictionaryOrNull(String body) {
  try {
    return parseGestureDictionary(body);
  } on GestureDictionaryParseException catch (error) {
    debugPrint('[gestos] dicionário ilegível: $error');
    return null;
  }
}

Future<void> _revalidateDictionary(
  Ref ref,
  String? etag,
  GestureDictionaryLocalDatasource local,
) async {
  try {
    if (!await ref.read(deviceConnectivityProvider).hasConnection()) return;
    switch (await ref.read(gestureDictionaryDatasourceProvider).fetch(etag: etag)) {
      case GestureDictionaryFresh(:final body, :final etag):
        if (_parseDictionaryOrNull(body) == null) return;
        local.write(content: body, etag: etag);
        ref.invalidateSelf();
      case GestureDictionaryNotModified():
        local.touch();
      case GestureDictionaryNotFound():
        break;
    }
  } on Object catch (error) {
    debugPrint('[gestos] revalidação do dicionário falhou: $error');
  }
}

/// Bytes de uma figura por `r2Key`; `null` se não deu. Fica viva na sessão:
/// a mesma figura aparece várias vezes no documento e no foco.
final gestureFigureProvider = FutureProvider.family<Uint8List?, String>((ref, r2Key) {
  return ref.watch(gestureFigureRepositoryProvider).get(r2Key);
});

/// Aquece o store com as figuras (PNG e GIF) dos ids de [document]
/// resolvidos por [dictionary]. Best-effort, dispara e esquece.
///
/// Recebe o repositório (não um `Ref`) para servir tanto a providers quanto
/// a widgets (`WidgetRef` não é `Ref`).
void prefetchGestureFigures(
  GestureFigureRepository repository,
  GestureDocument document,
  GestureDictionary dictionary,
) {
  final keys = <String>{};
  for (final flat in flattenGestureCards(document)) {
    final entry = dictionary.resolve(flat.card.gestureId);
    if (entry == null) continue;
    keys.add(entry.image);
    final gif = entry.gif;
    if (gif != null) keys.add(gif);
  }
  if (keys.isEmpty) return;
  unawaited(repository.prefetch(keys));
}
```

- [ ] **Step 5: Rodar até passar; analyze; commit**

Run: `flutter test --dart-define-from-file=dart_defines/plpcg.json test/unit/features/gestures/ && flutter analyze`

Se o teste de revalidação falhar por timing, substitua o `await Future<void>.delayed(Duration.zero)` por `await Future<void>.delayed(const Duration(milliseconds: 10))` — o `unawaited` roda em microtasks + o `hasConnection` fake é async.

```bash
git add lib/features/gestures test/unit/features/gestures
git commit -m "feat(gestures): providers cache-first do documento, dicionário com ETag, figuras e fonte

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01DuSVKfiGsabi168JixJLB1"
```

---

### Task 9: Paleta, `LyricLineText`, `GestureFigure` e `GestureCardTile`

**Files:**
- Create: `lib/features/gestures/presentation/theme/gesture_reader_palette.dart`
- Create: `lib/features/gestures/presentation/widgets/lyric_line_text.dart`
- Create: `lib/features/gestures/presentation/widgets/gesture_figure.dart`
- Create: `lib/features/gestures/presentation/widgets/gesture_card_tile.dart`
- Test: `test/widget/features/gestures/lyric_line_text_test.dart`, `test/widget/features/gestures/gesture_figure_test.dart`, `test/widget/features/gestures/gesture_card_tile_test.dart`
- Test helper: `test/helpers/gesture_test_png.dart`

**Interfaces:**
- Consumes: T1 (`GestureCard`, `LyricLine`), T2 (`GestureEntry`), T8 (`gestureFigureProvider`).
- Produces: `GestureReaderPalette` (constantes `paper, trigger, lyric, blue, orange, wine, instructionBg, instructionText, instructionBorder, placeholderBg, placeholderBorder, freeText`); `double gestureFigureSide(double fontSize)` (= `96 * fontSize / 18`); `LyricLineText({required LyricLine line, required double fontSize})`; `String nonBreaking(String s)`; `GestureFigure({required GestureEntry? entry, required String gestureId, required double side, bool preferGif = false})`; `GestureCardTile({required int index, required GestureCard card, required GestureEntry? entry, required double fontSize, ValueChanged<int>? onTap})`; `Key gestureCardKey(int index)`; `Key gesturePlaceholderKey(String gestureId)`; `const kGestureTestPngBase64` + `Uint8List gestureTestPng()` (helper de teste).

- [ ] **Step 1: Helper de teste com um PNG 1×1**

`test/helpers/gesture_test_png.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

/// PNG 1×1 transparente — bytes válidos para `Image.memory` nos testes.
const kGestureTestPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

Uint8List gestureTestPng() => base64Decode(kGestureTestPngBase64);
```

- [ ] **Step 2: Testes de widget (falhando)**

`test/widget/features/gestures/lyric_line_text_test.dart`:

```dart
import 'package:coldigui/features/gestures/domain/entities/gesture_document.dart';
import 'package:coldigui/features/gestures/presentation/theme/gesture_reader_palette.dart';
import 'package:coldigui/features/gestures/presentation/widgets/lyric_line_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<RichText> _pump(WidgetTester tester, LyricLine line, {double width = 400}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(width: width, child: LyricLineText(line: line, fontSize: 18)),
      ),
    ),
  );
  return tester.widget<RichText>(find.byType(RichText));
}

/// `Text.rich` envolve o span dado num `TextSpan` raiz (com o estilo do
/// `DefaultTextStyle`); os spans do gatilho/leitura estão um nível abaixo.
List<TextSpan> _spans(RichText rich) {
  final root = rich.text as TextSpan;
  final ours = root.children!.single as TextSpan;
  return ours.children!.cast<TextSpan>();
}

void main() {
  testWidgets('gatilho vermelho negrito + espaço + leitura preta', (tester) async {
    final rich = await _pump(tester, const LyricLine(trigger: 'Quero', text: 'viver'));
    final spans = _spans(rich);
    expect(spans[0].text, 'Quero');
    expect(spans[0].style?.color, GestureReaderPalette.trigger);
    expect(spans[0].style?.fontWeight, FontWeight.bold);
    expect(spans[1].text, ' viver');
    expect(spans[1].style?.color, GestureReaderPalette.lyric);
    expect(spans[1].style?.fontWeight, isNot(FontWeight.bold));
  });

  testWidgets('sem espaço quando a leitura começa com pontuação', (tester) async {
    for (final punct in [',', '.', ';', ':', '!', '?', ')', ']']) {
      final rich = await _pump(tester, LyricLine(trigger: 'a', text: '${punct}b'));
      expect(_spans(rich)[1].text, '${punct}b', reason: punct);
    }
  });

  testWidgets('gatilho vazio → só a leitura, sem espaço na frente', (tester) async {
    final rich = await _pump(tester, const LyricLine(trigger: '', text: 'só leitura'));
    final spans = _spans(rich);
    expect(spans, hasLength(1));
    expect(spans.single.text, 'só leitura');
  });

  testWidgets('leitura vazia → só o gatilho', (tester) async {
    final rich = await _pump(tester, const LyricLine(trigger: 'Amém', text: ''));
    expect(_spans(rich).single.text, 'Amém');
  });

  test('nonBreaking troca espaço por NBSP', () {
    expect(nonBreaking('É certeza'), 'É\u00A0certeza');
  });

  testWidgets('gatilho de duas palavras nunca quebra linha', (tester) async {
    // Largura pequena força quebra; a linha 1 tem que conter o gatilho inteiro.
    final rich = await _pump(
      tester,
      const LyricLine(trigger: 'É certeza', text: 'que Jesus me prometeu'),
      width: 120,
    );
    expect(_spans(rich)[0].text, 'É\u00A0certeza');
  });
}
```

`test/widget/features/gestures/gesture_figure_test.dart`:

```dart
import 'package:coldigui/features/gestures/data/providers/gesture_providers.dart';
import 'package:coldigui/features/gestures/domain/entities/gesture_dictionary.dart';
import 'package:coldigui/features/gestures/presentation/widgets/gesture_figure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/gesture_test_png.dart';

const _entry = GestureEntry(
  id: 'c687580e7682',
  name: 'Mão ao peito',
  description: '',
  exampleTriggers: [],
  image: 'assets/cia/gestures/c687580e7682.png',
  gif: 'assets/cia/gestures/c687580e7682.gif',
  status: GestureStatus.active,
  replacedBy: null,
  updatedAt: null,
);

Future<void> _pump(
  WidgetTester tester, {
  required GestureEntry? entry,
  required Future<List<int>?> Function(String key) figure,
  bool preferGif = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gestureFigureProvider.overrideWith((ref, key) async {
          final bytes = await figure(key);
          return bytes == null ? null : gestureTestPng();
        }),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: GestureFigure(entry: entry, gestureId: 'c687580e7682', side: 96, preferGif: preferGif),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('sem entrada → placeholder com o id', (tester) async {
    await _pump(tester, entry: null, figure: (_) async => null);
    expect(find.byKey(gesturePlaceholderKey('c687580e7682')), findsOneWidget);
    expect(find.text('c687580e7682'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('com bytes → Image.memory num quadrado de 96', (tester) async {
    final asked = <String>[];
    await _pump(tester, entry: _entry, figure: (k) async { asked.add(k); return [1]; });
    expect(find.byType(Image), findsOneWidget);
    expect(asked, [_entry.image]);
    final size = tester.getSize(find.byType(GestureFigure));
    expect(size.width, 96);
    expect(size.height, 96);
  });

  testWidgets('download falhou (null) → placeholder', (tester) async {
    await _pump(tester, entry: _entry, figure: (_) async => null);
    expect(find.byKey(gesturePlaceholderKey('c687580e7682')), findsOneWidget);
  });

  testWidgets('preferGif pede o GIF quando existe', (tester) async {
    final asked = <String>[];
    await _pump(tester, entry: _entry, figure: (k) async { asked.add(k); return [1]; }, preferGif: true);
    expect(asked, [_entry.gif]);
  });
}
```

`test/widget/features/gestures/gesture_card_tile_test.dart`:

```dart
import 'package:coldigui/features/gestures/data/providers/gesture_providers.dart';
import 'package:coldigui/features/gestures/domain/entities/gesture_dictionary.dart';
import 'package:coldigui/features/gestures/domain/entities/gesture_document.dart';
import 'package:coldigui/features/gestures/presentation/widgets/gesture_card_tile.dart';
import 'package:coldigui/features/gestures/presentation/widgets/gesture_figure.dart';
import 'package:coldigui/features/gestures/presentation/widgets/lyric_line_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/gesture_test_png.dart';

const _entry = GestureEntry(
  id: 'c687580e7682', name: 'x', description: '', exampleTriggers: [],
  image: 'assets/cia/gestures/c687580e7682.png', gif: null,
  status: GestureStatus.active, replacedBy: null, updatedAt: null,
);

const _card = GestureCard(
  gestureId: 'c687580e7682',
  lyrics: [
    LyricLine(trigger: 'Vou', text: 'para lá,'),
    LyricLine(trigger: '', text: 'com Jesus vou morar.'),
  ],
);

Future<void> _pump(WidgetTester tester, {double fontSize = 18, ValueChanged<int>? onTap}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gestureFigureProvider.overrideWith((ref, key) async => gestureTestPng()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: GestureCardTile(index: 3, card: _card, entry: _entry, fontSize: fontSize, onTap: onTap),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('figura à esquerda, uma LyricLineText por linha, alinhados pelo topo', (tester) async {
    await _pump(tester);
    expect(find.byType(LyricLineText), findsNWidgets(2));
    final figure = tester.getRect(find.byType(GestureFigure));
    final lyric = tester.getRect(find.byType(LyricLineText).first);
    expect(figure.left, lessThan(lyric.left));
    expect(figure.top, lyric.top);
  });

  testWidgets('lado da figura escala com a fonte: 96 em 18, 149 em 28', (tester) async {
    await _pump(tester);
    expect(tester.getSize(find.byType(GestureFigure)).width, 96);
    await _pump(tester, fontSize: 28);
    expect(tester.getSize(find.byType(GestureFigure)).width, closeTo(149.3, 0.1));
  });

  testWidgets('toque chama onTap com o índice', (tester) async {
    int? tapped;
    await _pump(tester, onTap: (i) => tapped = i);
    await tester.tap(find.byKey(gestureCardKey(3)));
    expect(tapped, 3);
  });
}
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `flutter test --dart-define-from-file=dart_defines/plpcg.json test/widget/features/gestures/`
Expected: falha de compilação.

- [ ] **Step 4: Paleta**

`lib/features/gestures/presentation/theme/gesture_reader_palette.dart`:

```dart
import 'package:flutter/material.dart';

/// Cores do papel de gestos (spec §4) — **isoladas** do `AppColors`.
///
/// O documento é desenhado sempre sobre branco porque as figuras são PNG com
/// fundo branco; o tema vinho/creme do app fica no chrome ao redor. O preview
/// do editor no coldigom usa exatamente estes valores.
abstract final class GestureReaderPalette {
  static const Color paper = Color(0xFFFFFFFF);

  /// Gatilho: palavra em que o gesto começa.
  static const Color trigger = Color(0xFFD32F2F);

  /// Leitura: o que se canta enquanto o gesto dura.
  static const Color lyric = Color(0xFF1A1A1A);

  /// Chave de repetição, `Nx`, rótulo `CORO`, chave tracejada.
  static const Color blue = Color(0xFF1E63C8);

  /// Conector de ligação.
  static const Color orange = Color(0xFFE08A1E);

  /// Divisor e rótulo `FINAL`.
  static const Color wine = Color(0xFF6A2F2F);

  static const Color instructionBg = Color(0xFFF3F4F6);
  static const Color instructionText = Color(0xFF374151);
  static const Color instructionBorder = Color(0xFFD1D5DB);

  static const Color placeholderBg = Color(0xFFFFF7E6);
  static const Color placeholderBorder = Color(0xFFE0B45C);

  /// Linha livre (`text`).
  static const Color freeText = Color(0xFF6B7280);
}

/// Fonte em que a figura tem 96 dp de lado.
const double kGestureBaseFontSize = 18;

/// Lado da caixa da figura para [fontSize]: `96 × (fonte / 18)`.
double gestureFigureSide(double fontSize) => 96 * fontSize / kGestureBaseFontSize;

/// Gap vertical entre cartões e entre blocos (spec §4).
const double kGestureCardGap = 12;
const double kGestureBlockGap = 20;

/// Largura da coluna da chave (`repeat`/`coro`) e do conector (`link`).
const double kGestureBraceWidth = 28;
const double kGestureLinkWidth = 20;

/// Página: largura máxima e margens.
const double kGesturePageMaxWidth = 720;
const double kGesturePageMargin = 16;
```

- [ ] **Step 5: `LyricLineText`**

`lib/features/gestures/presentation/widgets/lyric_line_text.dart`:

```dart
import 'package:flutter/material.dart';

import '../../domain/entities/gesture_document.dart';
import '../theme/gesture_reader_palette.dart';

/// Pontuação que cola no gatilho sem espaço (spec §4).
const _noSpaceBefore = {',', '.', ';', ':', '!', '?', ')', ']'};

/// Troca espaços por NBSP: o gatilho nunca quebra linha.
String nonBreaking(String s) => s.replaceAll(' ', '\u00A0');

/// Uma linha de letra: gatilho vermelho negrito + leitura preta.
///
/// Um `Text.rich` com dois `TextSpan` — o espaço entre eles entra no span da
/// leitura para que a quebra de linha, se vier, caia depois do gatilho inteiro.
class LyricLineText extends StatelessWidget {
  const LyricLineText({required this.line, required this.fontSize, super.key});

  final LyricLine line;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final trigger = line.trigger;
    final text = line.text;
    final glue = text.isEmpty || _noSpaceBefore.contains(text[0]) ? '' : ' ';

    return Text.rich(
      TextSpan(
        style: TextStyle(fontSize: fontSize, height: 1.3, color: GestureReaderPalette.lyric),
        children: [
          if (trigger.isNotEmpty)
            TextSpan(
              text: nonBreaking(trigger),
              style: const TextStyle(
                color: GestureReaderPalette.trigger,
                fontWeight: FontWeight.bold,
              ),
            ),
          if (text.isNotEmpty)
            TextSpan(
              text: trigger.isEmpty ? text : '$glue$text',
              style: const TextStyle(
                color: GestureReaderPalette.lyric,
                fontWeight: FontWeight.normal,
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: `GestureFigure`**

`lib/features/gestures/presentation/widgets/gesture_figure.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/providers/gesture_providers.dart';
import '../../domain/entities/gesture_dictionary.dart';
import '../theme/gesture_reader_palette.dart';

/// Chave do placeholder de gesto ausente — para testes e para achar na tela.
Key gesturePlaceholderKey(String gestureId) => ValueKey('gesture-placeholder-$gestureId');

/// Figura do gesto num quadrado de [side], fundo branco, `BoxFit.contain`.
///
/// [entry] `null` (id fora do dicionário) ou bytes `null` (download falhou)
/// viram o placeholder tracejado com o id em fonte pequena — nunca erro.
/// [preferGif] só no modo foco: mostra o GIF quando a entrada tem um.
class GestureFigure extends ConsumerWidget {
  const GestureFigure({
    required this.entry,
    required this.gestureId,
    required this.side,
    this.preferGif = false,
    super.key,
  });

  final GestureEntry? entry;
  final String gestureId;
  final double side;
  final bool preferGif;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = this.entry;
    if (entry == null) return _Placeholder(gestureId: gestureId, side: side);

    final key = preferGif ? (entry.gif ?? entry.image) : entry.image;
    final bytes = ref.watch(gestureFigureProvider(key));

    return SizedBox(
      width: side,
      height: side,
      child: ColoredBox(
        color: GestureReaderPalette.paper,
        child: bytes.when(
          loading: () => const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (_, _) => _Placeholder(gestureId: gestureId, side: side),
          data: (data) => data == null
              ? _Placeholder(gestureId: gestureId, side: side)
              : Image.memory(
                  data,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.medium,
                ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.gestureId, required this.side});

  final String gestureId;
  final double side;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      key: gesturePlaceholderKey(gestureId),
      width: side,
      height: side,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: GestureReaderPalette.placeholderBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: GestureReaderPalette.placeholderBorder, width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.pan_tool_outlined, size: 20, color: GestureReaderPalette.placeholderBorder),
          const SizedBox(height: 4),
          Text(
            l10n?.gestureNotFound ?? 'gesto não encontrado',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9, color: GestureReaderPalette.freeText),
          ),
          Text(
            gestureId,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, color: GestureReaderPalette.freeText),
          ),
        ],
      ),
    );
  }
}
```

A borda "tracejada" da spec: `Border` do Flutter não tem estilo tracejado; usar a borda sólida de 1.5 na cor `#E0B45C` é aceitável no v1 (documente no commit). Se quiser fidelidade, desenhe com um `CustomPainter` de retângulo tracejado usando `Path.computeMetrics` — opcional.

`gestureNotFound` ainda não existe no l10n: **adicione agora** em `lib/l10n/app_pt.arb` (`"gestureNotFound": "gesto não encontrado"`) e `app_en.arb` (`"gestureNotFound": "gesture not found"`) e rode `flutter gen-l10n`. As demais chaves de gestos entram na Task 10.

- [ ] **Step 7: `GestureCardTile`**

`lib/features/gestures/presentation/widgets/gesture_card_tile.dart`:

```dart
import 'package:flutter/material.dart';

import '../../domain/entities/gesture_dictionary.dart';
import '../../domain/entities/gesture_document.dart';
import '../theme/gesture_reader_palette.dart';
import 'gesture_figure.dart';
import 'lyric_line_text.dart';

/// Chave estável do cartão de índice [index] (o índice do `flatten`).
Key gestureCardKey(int index) => ValueKey('gesture-card-$index');

/// Cartão de gesto: figura à esquerda, letra à direita, alinhados pelo topo.
///
/// A figura e **toda** a letra ficam no mesmo cartão — a leitura preta é o que
/// se canta enquanto o gesto dura. [entry] já vem resolvido pelo dicionário
/// (alias seguido); `null` mostra o placeholder.
class GestureCardTile extends StatelessWidget {
  const GestureCardTile({
    required this.index,
    required this.card,
    required this.entry,
    required this.fontSize,
    this.onTap,
    super.key,
  });

  final int index;
  final GestureCard card;
  final GestureEntry? entry;
  final double fontSize;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final side = gestureFigureSide(fontSize);
    return InkWell(
      key: gestureCardKey(index),
      onTap: onTap == null ? null : () => onTap!(index),
      borderRadius: BorderRadius.circular(6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureFigure(entry: entry, gestureId: card.gestureId, side: side),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in card.lyrics)
                  LyricLineText(line: line, fontSize: fontSize),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 8: Rodar até passar; analyze; commit**

Run: `flutter test --dart-define-from-file=dart_defines/plpcg.json test/widget/features/gestures/ && flutter analyze`

Se um teste travar em `pumpAndSettle` por causa do `Image.memory`, use `tester.pump()` duas vezes em vez de `pumpAndSettle` (a decodificação de imagem não termina em fake-async e isso é esperado).

```bash
git add lib/features/gestures/presentation lib/l10n test/helpers/gesture_test_png.dart test/widget/features/gestures
git commit -m "feat(gestures): paleta do papel, linha de letra, figura com placeholder e cartão de gesto

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01DuSVKfiGsabi168JixJLB1"
```

---

### Task 10: Painters, blocos (`repeat`/`coro`/`link`/`final`), instrução, texto livre e l10n

**Files:**
- Modify: `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb` (todas as chaves de gestos)
- Create: `lib/features/gestures/presentation/widgets/brace_painter.dart`
- Create: `lib/features/gestures/presentation/widgets/link_connector_painter.dart`
- Create: `lib/features/gestures/presentation/widgets/repeat_block_view.dart`
- Create: `lib/features/gestures/presentation/widgets/chorus_block_view.dart`
- Create: `lib/features/gestures/presentation/widgets/link_block_view.dart`
- Create: `lib/features/gestures/presentation/widgets/final_section_view.dart`
- Create: `lib/features/gestures/presentation/widgets/instruction_card_view.dart`
- Create: `lib/features/gestures/presentation/widgets/text_line_view.dart`
- Test: `test/widget/features/gestures/block_views_test.dart`

**Interfaces:**
- Consumes: T9 (paleta e constantes), T1 (`InstructionKind`).
- Produces: `BracePainter({required bool dashed, String? label})`; `LinkConnectorPainter()`; `RepeatBlockView({required int count, required List<Widget> children})`; `ChorusBlockView({required List<Widget> children})`; `LinkBlockView({required List<Widget> children})`; `FinalSectionView({required List<Widget> children})`; `InstructionCardView({required InstructionKind kind})`; `TextLineView({required String text, required double fontSize})`; `String instructionLabel(AppLocalizations l10n, InstructionKind kind)`; `Key gestureBraceKey = ValueKey('gesture-brace')`, `Key gestureLinkConnectorKey = ValueKey('gesture-link-connector')`, `Key gestureFinalDividerKey = ValueKey('gesture-final-divider')`. Chaves l10n: ver Step 1.

- [ ] **Step 1: Todas as chaves l10n de gestos**

Em `lib/l10n/app_pt.arb`, logo após o bloco `chordReader…` (~linha 360), adicionar (o `gestureNotFound` da Task 9 já existe; não duplique):

```json
  "gesturesMaterialLabel": "Gestos",
  "gesturesMaterialSection": "Gestos",
  "gesturesReaderTitle": "Leitor de gestos",
  "gesturesReaderEmpty": "Este louvor ainda não tem gestos",
  "gesturesReaderUnavailable": "Gestos indisponíveis · tentar de novo",
  "gesturesReaderIncreaseFont": "Aumentar letra dos gestos",
  "gesturesReaderDecreaseFont": "Diminuir letra dos gestos",
  "gesturesReaderFullscreen": "Tela cheia",
  "gesturesNewerSchemaWarning": "Documento em formato mais novo; atualize o app.",
  "gestureInstructionInstruments": "Instrumentos",
  "gestureInstructionRepeatPraise": "Repetir o louvor",
  "gestureInstructionBackToChorus": "Voltar ao coro",
  "gestureInstructionBackToChorusAndFinish": "Voltar ao coro e finalizar",
  "gestureContextRepeat": "{count}x",
  "@gestureContextRepeat": {
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "gestureContextChorus": "CORO",
  "gestureContextFinal": "FINAL",
  "gestureContextLink": "ligação",
  "gestureFocusNext": "próximo:",
  "gestureFocusEnd": "fim",
  "gestureFocusClose": "Fechar",
```

Em `lib/l10n/app_en.arb`, no lugar equivalente:

```json
  "gesturesMaterialLabel": "Gestures",
  "gesturesMaterialSection": "Gestures",
  "gesturesReaderTitle": "Gesture reader",
  "gesturesReaderEmpty": "This hymn has no gestures yet",
  "gesturesReaderUnavailable": "Gestures unavailable · try again",
  "gesturesReaderIncreaseFont": "Increase gesture text",
  "gesturesReaderDecreaseFont": "Decrease gesture text",
  "gesturesReaderFullscreen": "Full screen",
  "gesturesNewerSchemaWarning": "Document in a newer format; update the app.",
  "gestureInstructionInstruments": "Instruments",
  "gestureInstructionRepeatPraise": "Repeat the hymn",
  "gestureInstructionBackToChorus": "Back to chorus",
  "gestureInstructionBackToChorusAndFinish": "Back to chorus and finish",
  "gestureContextRepeat": "{count}x",
  "@gestureContextRepeat": {
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "gestureContextChorus": "CHORUS",
  "gestureContextFinal": "END",
  "gestureContextLink": "link",
  "gestureFocusNext": "next:",
  "gestureFocusEnd": "end",
  "gestureFocusClose": "Close",
```

Run: `flutter gen-l10n && flutter analyze` — sem erros.

- [ ] **Step 2: Teste dos blocos (falhando)**

`test/widget/features/gestures/block_views_test.dart`:

```dart
import 'package:coldigui/features/gestures/domain/entities/gesture_document.dart';
import 'package:coldigui/features/gestures/presentation/theme/gesture_reader_palette.dart';
import 'package:coldigui/features/gestures/presentation/widgets/brace_painter.dart';
import 'package:coldigui/features/gestures/presentation/widgets/chorus_block_view.dart';
import 'package:coldigui/features/gestures/presentation/widgets/final_section_view.dart';
import 'package:coldigui/features/gestures/presentation/widgets/instruction_card_view.dart';
import 'package:coldigui/features/gestures/presentation/widgets/link_block_view.dart';
import 'package:coldigui/features/gestures/presentation/widgets/link_connector_painter.dart';
import 'package:coldigui/features/gestures/presentation/widgets/repeat_block_view.dart';
import 'package:coldigui/features/gestures/presentation/widgets/text_line_view.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _child(String label, double height) =>
    SizedBox(key: ValueKey(label), height: height, child: Text(label));

Future<void> _pump(WidgetTester tester, Widget body, {Locale locale = const Locale('pt')}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      // Altura ilimitada, como no corpo rolável do leitor.
      home: Scaffold(
        body: SingleChildScrollView(
          // Align solta a largura: sem ele o scroll view força 800 no SizedBox.
          child: Align(alignment: Alignment.topLeft, child: SizedBox(width: 360, child: body)),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('RepeatBlockView', () {
    testWidgets('chave cobre exatamente a altura dos filhos e mostra Nx', (tester) async {
      await _pump(tester, RepeatBlockView(count: 2, children: [_child('a', 40), _child('b', 60)]));

      final brace = tester.getRect(find.byKey(gestureBraceKey));
      final first = tester.getRect(find.byKey(const ValueKey('a')));
      final last = tester.getRect(find.byKey(const ValueKey('b')));
      expect(brace.top, first.top);
      expect(brace.bottom, last.bottom);
      expect(brace.width, kGestureBraceWidth);
      expect(brace.right, 360);
      final painter = tester.widget<CustomPaint>(find.byKey(gestureBraceKey)).painter as BracePainter;
      expect(painter.label, '2x');
      expect(painter.dashed, isFalse);
    });

    testWidgets('aninhado: a chave externa envolve a interna (recuo por nível)', (tester) async {
      await _pump(
        tester,
        RepeatBlockView(count: 3, children: [
          RepeatBlockView(count: 2, children: [_child('a', 40)]),
        ]),
      );
      final braces = find.byKey(gestureBraceKey);
      expect(braces, findsNWidgets(2));
      // Ordem de árvore: a chave interna (dentro do Padding) vem antes da
      // externa (Positioned irmão); não dependa dela, ordene pela posição.
      final a = tester.getRect(braces.first);
      final b = tester.getRect(braces.last);
      final inner = a.left < b.left ? a : b;
      final outer = a.left < b.left ? b : a;
      expect(inner.right, lessThanOrEqualTo(outer.left));
    });
  });

  group('ChorusBlockView', () {
    testWidgets('rótulo CORO azul acima e chave tracejada cobrindo os filhos', (tester) async {
      await _pump(tester, ChorusBlockView(children: [_child('a', 40), _child('b', 40)]));

      final label = tester.widget<Text>(find.text('CORO'));
      expect(label.style?.color, GestureReaderPalette.blue);
      expect(label.style?.fontWeight, FontWeight.bold);
      final brace = tester.getRect(find.byKey(gestureBraceKey));
      expect(brace.top, tester.getRect(find.byKey(const ValueKey('a'))).top);
      expect(brace.bottom, tester.getRect(find.byKey(const ValueKey('b'))).bottom);
      expect(tester.getRect(find.text('CORO')).bottom, lessThanOrEqualTo(brace.top));
      final painter = tester.widget<CustomPaint>(find.byKey(gestureBraceKey)).painter as BracePainter;
      expect(painter.dashed, isTrue);
      expect(painter.label, isNull);
    });

    testWidgets('em inglês o rótulo é CHORUS', (tester) async {
      await _pump(tester, ChorusBlockView(children: [_child('a', 40)]), locale: const Locale('en'));
      expect(find.text('CHORUS'), findsOneWidget);
    });
  });

  group('LinkBlockView', () {
    testWidgets('conector laranja à esquerda, filhos sem espaço entre si', (tester) async {
      await _pump(tester, LinkBlockView(children: [_child('a', 40), _child('b', 40)]));
      final connector = tester.getRect(find.byKey(gestureLinkConnectorKey));
      expect(connector.left, 0);
      expect(connector.width, kGestureLinkWidth);
      final a = tester.getRect(find.byKey(const ValueKey('a')));
      final b = tester.getRect(find.byKey(const ValueKey('b')));
      expect(b.top, a.bottom);
      expect(connector.top, a.top);
      expect(connector.bottom, b.bottom);
      expect(tester.widget<CustomPaint>(find.byKey(gestureLinkConnectorKey)).painter, isA<LinkConnectorPainter>());
    });
  });

  group('FinalSectionView', () {
    testWidgets('divisor + rótulo FINAL antes dos filhos', (tester) async {
      await _pump(tester, FinalSectionView(children: [_child('a', 40)]));
      expect(find.byKey(gestureFinalDividerKey), findsOneWidget);
      final label = tester.widget<Text>(find.text('FINAL'));
      expect(label.style?.color, GestureReaderPalette.wine);
      expect(tester.getRect(find.text('FINAL')).bottom, lessThanOrEqualTo(tester.getRect(find.byKey(const ValueKey('a'))).top));
    });
  });

  group('InstructionCardView', () {
    testWidgets('quatro rótulos em pt', (tester) async {
      for (final (kind, label) in [
        (InstructionKind.instruments, 'Instrumentos'),
        (InstructionKind.repeatPraise, 'Repetir o louvor'),
        (InstructionKind.backToChorus, 'Voltar ao coro'),
        (InstructionKind.backToChorusAndFinish, 'Voltar ao coro e finalizar'),
      ]) {
        await _pump(tester, InstructionCardView(kind: kind));
        expect(find.text(label), findsOneWidget, reason: kind.name);
      }
    });

    testWidgets('quatro rótulos em en', (tester) async {
      for (final (kind, label) in [
        (InstructionKind.instruments, 'Instruments'),
        (InstructionKind.repeatPraise, 'Repeat the hymn'),
        (InstructionKind.backToChorus, 'Back to chorus'),
        (InstructionKind.backToChorusAndFinish, 'Back to chorus and finish'),
      ]) {
        await _pump(tester, InstructionCardView(kind: kind), locale: const Locale('en'));
        expect(find.text(label), findsOneWidget, reason: kind.name);
      }
    });

    testWidgets('ocupa a largura toda com fundo cinza', (tester) async {
      await _pump(tester, const InstructionCardView(kind: InstructionKind.instruments));
      expect(tester.getSize(find.byType(InstructionCardView)).width, 360);
    });
  });

  testWidgets('TextLineView é cinza e itálico', (tester) async {
    await _pump(tester, const TextLineView(text: 'linha livre', fontSize: 18));
    final text = tester.widget<Text>(find.text('linha livre'));
    expect(text.style?.color, GestureReaderPalette.freeText);
    expect(text.style?.fontStyle, FontStyle.italic);
  });
}
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `flutter test --dart-define-from-file=dart_defines/plpcg.json test/widget/features/gestures/block_views_test.dart`
Expected: falha de compilação.

- [ ] **Step 4: Painters**

`lib/features/gestures/presentation/widgets/brace_painter.dart`:

```dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/gesture_reader_palette.dart';

/// Chave do `CustomPaint` da chave de bloco (repeat/coro) — para testes.
const Key gestureBraceKey = ValueKey('gesture-brace');

/// Chave vertical à direita de um bloco: `}` espelhada, altura = altura dos
/// filhos (o `Positioned.fill` que a hospeda garante isso).
///
/// [label] (`Nx`) é pintado centralizado verticalmente, à esquerda da chave.
/// [dashed] é a variante do `coro`.
class BracePainter extends CustomPainter {
  const BracePainter({required this.dashed, this.label});

  final bool dashed;
  final String? label;

  static const double _stroke = 2;
  static const double _hook = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = GestureReaderPalette.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;

    // Chave nos 12 dp da direita; o resto da coluna é do rótulo.
    final x = size.width - 12;
    final tip = size.width - 2;
    final midY = size.height / 2;
    final path = Path()
      ..moveTo(x - _hook, 1)
      ..quadraticBezierTo(x, 1, x, _hook)
      ..lineTo(x, midY - _hook)
      ..quadraticBezierTo(x, midY, tip, midY)
      ..quadraticBezierTo(x, midY, x, midY + _hook)
      ..lineTo(x, size.height - _hook)
      ..quadraticBezierTo(x, size.height - 1, x - _hook, size.height - 1);

    canvas.drawPath(dashed ? _dash(path) : path, paint);

    final label = this.label;
    if (label == null) return;
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: GestureReaderPalette.blue,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: x - _hook);
    painter.paint(
      canvas,
      Offset((x - _hook - painter.width) / 2, midY - painter.height / 2),
    );
  }

  static Path _dash(Path source) {
    const dash = 5.0;
    const gap = 4.0;
    final out = Path();
    for (final ui.PathMetric metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0, metric.length).toDouble();
        out.addPath(metric.extractPath(distance, end), Offset.zero);
        distance = end + gap;
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(BracePainter old) => old.dashed != dashed || old.label != label;
}
```

`lib/features/gestures/presentation/widgets/link_connector_painter.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/gesture_reader_palette.dart';

const Key gestureLinkConnectorKey = ValueKey('gesture-link-connector');

/// Conector vertical laranja com seta para baixo: os filhos executam sem pausa.
class LinkConnectorPainter extends CustomPainter {
  const LinkConnectorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = GestureReaderPalette.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final x = size.width / 2;
    final bottom = size.height - 4;
    canvas.drawLine(Offset(x, 4), Offset(x, bottom - 6), paint);
    final head = Path()
      ..moveTo(x - 5, bottom - 8)
      ..lineTo(x, bottom)
      ..lineTo(x + 5, bottom - 8)
      ..close();
    canvas.drawPath(head, Paint()..color = GestureReaderPalette.orange);
  }

  @override
  bool shouldRepaint(LinkConnectorPainter old) => false;
}
```

- [ ] **Step 5: Views de bloco**

`lib/features/gestures/presentation/widgets/repeat_block_view.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/gesture_reader_palette.dart';
import 'brace_painter.dart';

/// Bloco `Nx`: filhos empilhados + chave azul à direita com a altura deles.
///
/// `Stack` de propósito, não `Row(stretch)`: em altura ilimitada (corpo
/// rolável) o `RenderFlex` passaria `tightFor(height: ∞)` aos filhos. Aqui a
/// `Column` (com padding da largura da chave) dá o tamanho ao `Stack`, e o
/// `Positioned.fill` herda a altura sem medição intrínseca. Aninhar é só
/// empilhar `Stack`s: cada nível recua os filhos em [kGestureBraceWidth].
class RepeatBlockView extends StatelessWidget {
  const RepeatBlockView({required this.count, required this.children, super.key});

  final int count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return BracedChildren(
      dashed: false,
      label: '${count}x',
      children: children,
    );
  }
}

/// Filhos + chave vertical à direita. Compartilhado por repeat e coro.
class BracedChildren extends StatelessWidget {
  const BracedChildren({
    required this.dashed,
    required this.children,
    this.label,
    super.key,
  });

  final bool dashed;
  final String? label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: kGestureBraceWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: kGestureBraceWidth,
          child: CustomPaint(
            key: gestureBraceKey,
            painter: BracePainter(dashed: dashed, label: label),
          ),
        ),
      ],
    );
  }
}
```

`lib/features/gestures/presentation/widgets/chorus_block_view.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../theme/gesture_reader_palette.dart';
import 'repeat_block_view.dart';

/// `CORO`: rótulo azul negrito acima, chave **tracejada** à direita dos filhos.
class ChorusBlockView extends StatelessWidget {
  const ChorusBlockView({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            l10n?.gestureContextChorus ?? 'CORO',
            style: const TextStyle(
              color: GestureReaderPalette.blue,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 1,
            ),
          ),
        ),
        BracedChildren(dashed: true, children: children),
      ],
    );
  }
}
```

`lib/features/gestures/presentation/widgets/link_block_view.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/gesture_reader_palette.dart';
import 'link_connector_painter.dart';

/// Ligação: filhos sem espaço entre si + conector laranja à esquerda.
class LinkBlockView extends StatelessWidget {
  const LinkBlockView({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: kGestureLinkWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
        const Positioned(
          top: 0,
          bottom: 0,
          left: 0,
          width: kGestureLinkWidth,
          child: CustomPaint(
            key: gestureLinkConnectorKey,
            painter: LinkConnectorPainter(),
          ),
        ),
      ],
    );
  }
}
```

`lib/features/gestures/presentation/widgets/final_section_view.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../theme/gesture_reader_palette.dart';

const Key gestureFinalDividerKey = ValueKey('gesture-final-divider');

/// `FINAL`: divisor traço-ponto + rótulo à esquerda, depois os filhos.
class FinalSectionView extends StatelessWidget {
  const FinalSectionView({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Text(
                l10n?.gestureContextFinal ?? 'FINAL',
                style: const TextStyle(
                  color: GestureReaderPalette.wine,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: SizedBox(
                  height: 2,
                  child: CustomPaint(
                    key: gestureFinalDividerKey,
                    painter: _DashDotPainter(),
                  ),
                ),
              ),
            ],
          ),
        ),
        ...children,
      ],
    );
  }
}

class _DashDotPainter extends CustomPainter {
  const _DashDotPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = GestureReaderPalette.wine
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset((x + 8).clamp(0, size.width), y), paint);
      x += 12;
      if (x < size.width) canvas.drawPoints(PointMode.points, [Offset(x, y)], paint);
      x += 5;
    }
  }

  @override
  bool shouldRepaint(_DashDotPainter old) => false;
}
```

(`PointMode` vem de `dart:ui`; adicione `import 'dart:ui' show PointMode;` se o analyzer pedir.)

`lib/features/gestures/presentation/widgets/instruction_card_view.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/gesture_document.dart';
import '../theme/gesture_reader_palette.dart';

/// Rótulo l10n de uma instrução.
String instructionLabel(AppLocalizations l10n, InstructionKind kind) => switch (kind) {
  InstructionKind.instruments => l10n.gestureInstructionInstruments,
  InstructionKind.repeatPraise => l10n.gestureInstructionRepeatPraise,
  InstructionKind.backToChorus => l10n.gestureInstructionBackToChorus,
  InstructionKind.backToChorusAndFinish => l10n.gestureInstructionBackToChorusAndFinish,
};

/// Cartão de largura total com a instrução (`Instrumentos`, `Voltar ao coro`…).
class InstructionCardView extends StatelessWidget {
  const InstructionCardView({required this.kind, super.key});

  final InstructionKind kind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: GestureReaderPalette.instructionBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: GestureReaderPalette.instructionBorder),
      ),
      child: Text(
        instructionLabel(l10n, kind),
        style: const TextStyle(
          color: GestureReaderPalette.instructionText,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
```

`lib/features/gestures/presentation/widgets/text_line_view.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/gesture_reader_palette.dart';

/// Linha livre (`text`) e destino de itens desconhecidos: cinza, itálico.
class TextLineView extends StatelessWidget {
  const TextLineView({required this.text, required this.fontSize, super.key});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: GestureReaderPalette.freeText,
        fontStyle: FontStyle.italic,
        fontSize: fontSize - 2,
      ),
    );
  }
}
```

- [ ] **Step 6: Rodar até passar; analyze; commit**

Run: `flutter test --dart-define-from-file=dart_defines/plpcg.json test/widget/features/gestures/ && flutter analyze`

```bash
git add lib/l10n lib/features/gestures/presentation test/widget/features/gestures/block_views_test.dart
git commit -m "feat(gestures): blocos repeat/coro/link/final com chaves por Stack, instrução, texto livre e l10n

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01DuSVKfiGsabi168JixJLB1"
```

---

### Task 11: `GestureDocumentView` e banner de schema

**Files:**
- Create: `lib/features/gestures/presentation/widgets/newer_schema_banner.dart`
- Create: `lib/features/gestures/presentation/widgets/gesture_document_view.dart`
- Test: `test/widget/features/gestures/gesture_document_view_test.dart`

**Interfaces:**
- Consumes: T1–T3, T9, T10.
- Produces: `NewerSchemaBanner()`; `GestureDocumentView({required GestureDocument document, required GestureDictionary dictionary, required double fontSize, ValueChanged<int>? onCardTap, ScrollController? scrollController, Key? key})` com `GestureDocumentViewState.scrollToCard(int index)` acessível por `GlobalKey<GestureDocumentViewState>`; `Key gestureDocumentTitleKey = ValueKey('gesture-document-title')`.

- [ ] **Step 1: Teste (falhando)**

`test/widget/features/gestures/gesture_document_view_test.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:coldigui/features/gestures/data/providers/gesture_providers.dart';
import 'package:coldigui/features/gestures/domain/entities/gesture_dictionary.dart';
import 'package:coldigui/features/gestures/domain/usecases/parse_gesture_dictionary.dart';
import 'package:coldigui/features/gestures/domain/usecases/parse_gesture_document.dart';
import 'package:coldigui/features/gestures/presentation/widgets/brace_painter.dart';
import 'package:coldigui/features/gestures/presentation/widgets/gesture_card_tile.dart';
import 'package:coldigui/features/gestures/presentation/widgets/gesture_document_view.dart';
import 'package:coldigui/features/gestures/presentation/widgets/gesture_figure.dart';
import 'package:coldigui/features/gestures/presentation/widgets/instruction_card_view.dart';
import 'package:coldigui/features/gestures/presentation/widgets/link_connector_painter.dart';
import 'package:coldigui/features/gestures/presentation/widgets/newer_schema_banner.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/gesture_test_png.dart';

String _read(String name) => File('test/fixtures/gestures/$name').readAsStringSync();

Future<GlobalKey<GestureDocumentViewState>> _pump(
  WidgetTester tester,
  String fixture, {
  GestureDictionary? dictionary,
  ValueChanged<int>? onCardTap,
  double fontSize = 18,
}) async {
  final key = GlobalKey<GestureDocumentViewState>();
  final dict = dictionary ?? parseGestureDictionary(_read('dictionary.json'));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [gestureFigureProvider.overrideWith((ref, k) async => gestureTestPng())],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Scaffold(
          body: Column(
            children: [
              if (parseGestureDocument(_read(fixture)).isNewerSchema) const NewerSchemaBanner(),
              Expanded(
                child: GestureDocumentView(
                  key: key,
                  document: parseGestureDocument(_read(fixture)),
                  dictionary: dict,
                  fontSize: fontSize,
                  onCardTap: onCardTap,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return key;
}

void main() {
  testWidgets('182: título em caixa alta, CORO tracejado sobre 5 cartões, 14 cartões, 2 instruções', (tester) async {
    await _pump(tester, '182_quero_viver.json');

    expect(find.text('182 - QUERO VIVER PRA SEMPRE COM JESUS'), findsOneWidget);
    expect(find.byType(GestureCardTile, skipOffstage: false), findsNWidgets(14));
    expect(find.byType(InstructionCardView, skipOffstage: false), findsNWidgets(2));
    expect(find.text('Voltar ao coro', skipOffstage: false), findsOneWidget);

    final brace = find.byKey(gestureBraceKey);
    expect(brace, findsOneWidget);
    expect((tester.widget<CustomPaint>(brace).painter as BracePainter).dashed, isTrue);
    final braceRect = tester.getRect(brace);
    expect(braceRect.top, tester.getRect(find.byKey(gestureCardKey(0))).top);
    expect(braceRect.bottom, tester.getRect(find.byKey(gestureCardKey(4))).bottom);
  });

  testWidgets('181: chave 2x cobre os 4 últimos cartões', (tester) async {
    await _pump(tester, '181_jerusalem.json');
    final brace = find.byKey(gestureBraceKey);
    expect((tester.widget<CustomPaint>(brace).painter as BracePainter).label, '2x');
    expect(tester.getRect(brace).top, tester.getRect(find.byKey(gestureCardKey(5))).top);
    expect(tester.getRect(brace).bottom, tester.getRect(find.byKey(gestureCardKey(8))).bottom);
  });

  testWidgets('sintético: FINAL, conector dentro da chave, id inexistente vira placeholder, texto desconhecido não quebra', (tester) async {
    await _pump(tester, 'sintetico_final_link.json');
    expect(find.text('FINAL', skipOffstage: false), findsOneWidget);
    expect(find.byKey(gestureLinkConnectorKey, skipOffstage: false), findsOneWidget);
    expect(find.byKey(gesturePlaceholderKey('000000000000'), skipOffstage: false), findsOneWidget);
    expect(find.textContaining('hologram', skipOffstage: false), findsOneWidget);
    expect(find.text('Instrumentos'), findsOneWidget);
  });

  testWidgets('alias: documento com id deprecated mostra a figura da entrada ativa', (tester) async {
    final asked = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gestureFigureProvider.overrideWith((ref, k) async {
            asked.add(k);
            return gestureTestPng();
          }),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: Scaffold(
            body: GestureDocumentView(
              document: parseGestureDocument(
                '{"items":[{"type":"gesture","gestureId":"a1b2c3d4e5f6","lyrics":[{"trigger":"a","text":"b"}]}]}',
              ),
              dictionary: parseGestureDictionary(_read('dictionary.json')),
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(asked, ['assets/cia/gestures/c687580e7682.png']);
  });

  testWidgets('dicionário vazio: todos os cartões viram placeholder, nada quebra', (tester) async {
    await _pump(tester, '182_quero_viver.json', dictionary: GestureDictionary.empty);
    expect(find.byType(GestureCardTile, skipOffstage: false), findsNWidgets(14));
    expect(find.byKey(gesturePlaceholderKey('c687580e7682'), skipOffstage: false), findsWidgets);
  });

  testWidgets('schema v2 mostra o banner e renderiza', (tester) async {
    await _pump(tester, 'schema_v2.json');
    expect(find.byType(NewerSchemaBanner), findsOneWidget);
    expect(find.text('Documento em formato mais novo; atualize o app.'), findsOneWidget);
    expect(find.byType(GestureCardTile), findsOneWidget);
  });

  testWidgets('toque no cartão chama onCardTap com o índice do flatten', (tester) async {
    int? tapped;
    await _pump(tester, '182_quero_viver.json', onCardTap: (i) => tapped = i);
    await tester.tap(find.byKey(gestureCardKey(3)));
    expect(tapped, 3);
  });

  testWidgets('scrollToCard rola até o cartão', (tester) async {
    // Num Column rolável todo cartão está construído e on-stage (só fora da
    // viewport), então o teste mede posição, não presença.
    final key = await _pump(tester, '182_quero_viver.json', fontSize: 28);
    final viewport = tester.getSize(find.byType(GestureDocumentView));
    expect(tester.getRect(find.byKey(gestureCardKey(13))).top, greaterThan(viewport.height));

    // Não se espera o Future: ensureVisible anima e só resolve com frames,
    // que no teste vêm do pumpAndSettle.
    unawaited(key.currentState!.scrollToCard(13));
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byKey(gestureCardKey(13)));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(viewport.height));
  });

  testWidgets('largura máxima 720 centralizada', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester, '182_quero_viver.json');
    final page = tester.getRect(find.byKey(gestureDocumentPageKey));
    expect(page.width, 720);
    expect(page.left, closeTo((1200 - 720) / 2, 1));
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test --dart-define-from-file=dart_defines/plpcg.json test/widget/features/gestures/gesture_document_view_test.dart`
Expected: falha de compilação.

- [ ] **Step 3: Banner**

`lib/features/gestures/presentation/widgets/newer_schema_banner.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../l10n/app_localizations.dart';

/// Aviso acima do papel quando `schemaMajor > 1`: o app tenta renderizar
/// mesmo assim, mas o regente precisa saber por que algo pode faltar.
class NewerSchemaBanner extends StatelessWidget {
  const NewerSchemaBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return MaterialBanner(
      backgroundColor: AppColors.card,
      leading: const Icon(Icons.system_update_alt, color: AppColors.title),
      content: Text(
        l10n.gesturesNewerSchemaWarning,
        style: AppTypography.label.copyWith(color: AppColors.textDark),
      ),
      actions: const [SizedBox.shrink()],
    );
  }
}
```

- [ ] **Step 4: `GestureDocumentView`**

`lib/features/gestures/presentation/widgets/gesture_document_view.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/gesture_dictionary.dart';
import '../../domain/entities/gesture_document.dart';
import '../theme/gesture_reader_palette.dart';
import 'chorus_block_view.dart';
import 'final_section_view.dart';
import 'gesture_card_tile.dart';
import 'instruction_card_view.dart';
import 'link_block_view.dart';
import 'repeat_block_view.dart';
import 'text_line_view.dart';

const Key gestureDocumentTitleKey = ValueKey('gesture-document-title');
const Key gestureDocumentPageKey = ValueKey('gesture-document-page');

/// O documento inteiro como página rolável sobre papel branco.
///
/// Árvore → widgets por recursão; os cartões são numerados **na mesma ordem
/// do `flattenGestureCards`** (contador incremental em ordem de documento,
/// pulando instruções e texto), para que [scrollToCard] e o modo foco falem
/// do mesmo índice. `Column` inteira, não `ListView`: blocos aninhados não
/// cabem num item lazy, e o documento tem ≤ 40 cartões.
class GestureDocumentView extends StatefulWidget {
  const GestureDocumentView({
    required this.document,
    required this.dictionary,
    required this.fontSize,
    this.onCardTap,
    this.scrollController,
    super.key,
  });

  final GestureDocument document;
  final GestureDictionary dictionary;
  final double fontSize;
  final ValueChanged<int>? onCardTap;
  final ScrollController? scrollController;

  @override
  State<GestureDocumentView> createState() => GestureDocumentViewState();
}

class GestureDocumentViewState extends State<GestureDocumentView> {
  final _cardKeys = <int, GlobalKey>{};
  int _nextIndex = 0;

  GlobalKey _keyFor(int index) => _cardKeys.putIfAbsent(index, GlobalKey.new);

  /// Rola até o cartão [index] (índice do `flatten`). No-op se não existe.
  Future<void> scrollToCard(int index) async {
    final context = _cardKeys[index]?.currentContext;
    if (context == null) return;
    await Scrollable.ensureVisible(
      context,
      alignment: 0.2,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  Widget build(BuildContext context) {
    _nextIndex = 0;
    final items = _buildItems(widget.document.items, gapInsideLink: false);

    return ColoredBox(
      color: GestureReaderPalette.paper,
      child: SingleChildScrollView(
        controller: widget.scrollController,
        padding: const EdgeInsets.symmetric(vertical: kGesturePageMargin),
        child: Center(
          child: ConstrainedBox(
            key: gestureDocumentPageKey,
            constraints: const BoxConstraints(maxWidth: kGesturePageMaxWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: kGesturePageMargin),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.document.title.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        widget.document.title.toUpperCase(),
                        key: gestureDocumentTitleKey,
                        style: AppTypography.headline.copyWith(
                          color: GestureReaderPalette.lyric,
                        ),
                      ),
                    ),
                  ...items,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Filhos de um nível com os gaps entre eles: 12 entre cartões, 20 quando
  /// um dos vizinhos é bloco; dentro de `link`, nenhum.
  List<Widget> _buildItems(List<GestureItem> items, {required bool gapInsideLink}) {
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0 && !gapInsideLink) {
        final gap = _isBlock(items[i - 1]) || _isBlock(items[i])
            ? kGestureBlockGap
            : kGestureCardGap;
        out.add(SizedBox(height: gap));
      }
      out.add(_buildItem(items[i]));
    }
    return out;
  }

  static bool _isBlock(GestureItem item) => switch (item) {
    RepeatBlock() || ChorusBlock() || LinkBlock() || FinalBlock() => true,
    GestureCard() || InstructionCard() || TextLine() => false,
  };

  Widget _buildItem(GestureItem item) {
    switch (item) {
      case GestureCard():
        final index = _nextIndex++;
        return KeyedSubtree(
          key: _keyFor(index),
          child: GestureCardTile(
            index: index,
            card: item,
            entry: widget.dictionary.resolve(item.gestureId),
            fontSize: widget.fontSize,
            onTap: widget.onCardTap,
          ),
        );
      case RepeatBlock(:final count, :final children):
        return RepeatBlockView(
          count: count,
          children: _buildItems(children, gapInsideLink: false),
        );
      case ChorusBlock(:final children):
        return ChorusBlockView(children: _buildItems(children, gapInsideLink: false));
      case LinkBlock(:final children):
        return LinkBlockView(children: _buildItems(children, gapInsideLink: true));
      case FinalBlock(:final children):
        return FinalSectionView(children: _buildItems(children, gapInsideLink: false));
      case InstructionCard(:final kind):
        return InstructionCardView(kind: kind);
      case TextLine(:final text):
        return TextLineView(text: text, fontSize: widget.fontSize);
    }
  }
}
```

- [ ] **Step 5: Rodar até passar; analyze; commit**

Run: `flutter test --dart-define-from-file=dart_defines/plpcg.json test/widget/features/gestures/ && flutter analyze`

```bash
git add lib/features/gestures/presentation test/widget/features/gestures/gesture_document_view_test.dart
git commit -m "feat(gestures): GestureDocumentView com página de 720 dp, índices do flatten e banner de schema

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01DuSVKfiGsabi168JixJLB1"
```

---

### Task 12: Rota `/gestos`, URL builder, `GestureReaderScreen`, wakelock e atalhos

**Files:**
- Modify: `lib/core/routing/route_paths.dart` (após `chords`)
- Modify: `lib/core/routing/app_router.dart` (import + `GoRoute(path: 'gestos')` após o de `cifra`, ~linha 114)
- Create: `lib/core/utils/gesture_reader_url_builder.dart`
- Create: `lib/features/gestures/presentation/pages/gesture_reader_screen.dart`
- Modify: `lib/features/app_shell/presentation/widgets/stage_wakelock.dart:9-13` (`_stageRoutes`)
- Modify: `lib/features/app_shell/presentation/shell_scaffold.dart:35-39` (`_isImmersiveMediaRoute`)
- Modify: `lib/features/app_shell/presentation/widgets/app_shortcuts.dart:161-162` (`_isReaderRoute`) e a tabela de atalhos no doc-comment (`F` / `Esc` valem também no leitor de gestos)
- Test: `test/unit/core/gesture_reader_url_builder_test.dart`, `test/unit/features/app_shell/stage_wakelock_test.dart` (adicionar caso), `test/widget/features/gestures/gesture_reader_screen_test.dart`

**Interfaces:**
- Consumes: T8 (`gestureDocumentProvider`, `gestureDictionaryProvider`, `prefetchGestureFigures`, `gestureReaderFontSizeProvider`), T11 (`GestureDocumentView`, `NewerSchemaBanner`), `readerRouteParamsProvider` (`lib/features/pdf_reader/presentation/providers/reader_route_params_provider.dart`), `toggleReaderFullscreenProvider` (`…/reader_fullscreen_provider.dart`), `navigateReaderCarouselByKeyboard` + `CarouselReaderDirection` (`app_shortcuts.dart`, `carousel_reader_position.dart`), `PdfPathNormalizer.getPdfRelPath`, `UrlSyncParams.pdfId/titulo/subtitulo`, `GestureReaderFontSize`.
- Produces: `RoutePaths.gestos = '/gestos'`; `String buildGestureReaderLocation({required String gestureId, String? titulo, String? subtitulo})`; `GestureReaderScreen({required Map<String, String> queryParams})` com `GlobalKey<GestureDocumentViewState>` interno e `onCardTap` **ainda não ligado** (Task 15 liga o modo foco); chaves de teste `gestureReaderRetryKey = ValueKey('gesture-reader-retry')`.

- [ ] **Step 1: Testes (falhando)**

`test/unit/core/gesture_reader_url_builder_test.dart`:

```dart
import 'package:coldigui/core/utils/gesture_reader_url_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('monta /gestos com pdfId', () {
    expect(buildGestureReaderLocation(gestureId: 'abc123'), '/gestos?pdfId=abc123');
  });

  test('inclui titulo e subtitulo codificados', () {
    final location = buildGestureReaderLocation(
      gestureId: 'abc',
      titulo: 'Quero viver, ó Deus',
      subtitulo: '182',
    );
    expect(location, startsWith('/gestos?pdfId=abc'));
    expect(location, contains('titulo=Quero%20viver%2C%20%C3%B3%20Deus'));
    expect(location, contains('subtitulo=182'));
  });

  test('omite titulo e subtitulo vazios', () {
    expect(buildGestureReaderLocation(gestureId: 'abc', titulo: '', subtitulo: ''), '/gestos?pdfId=abc');
  });
}
```

Em `test/unit/features/app_shell/stage_wakelock_test.dart`, dentro do grupo `shouldHoldWakelock — rotas de palco`, adicionar:

```dart
    test('/gestos segura o wakelock', () {
      expect(
        shouldHoldWakelock(path: RoutePaths.gestos, playing: false),
        isTrue,
      );
    });
```

`test/widget/features/gestures/gesture_reader_screen_test.dart`:

```dart
import 'dart:io';

import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/gestures/data/datasources/gesture_content_datasource.dart';
import 'dart:typed_data';

import 'package:coldigui/features/gestures/data/providers/gesture_providers.dart';
import 'package:coldigui/features/gestures/data/repositories/gesture_figure_repository.dart';
import 'package:coldigui/features/gestures/domain/entities/gesture_document.dart';
import 'package:coldigui/features/gestures/domain/usecases/parse_gesture_dictionary.dart';
import 'package:coldigui/features/gestures/domain/usecases/parse_gesture_document.dart';
import 'package:coldigui/features/gestures/presentation/pages/gesture_reader_screen.dart';
import 'package:coldigui/features/gestures/presentation/providers/gesture_reader_font_size_provider.dart';
import 'package:coldigui/features/gestures/presentation/widgets/gesture_card_tile.dart';
import 'package:coldigui/features/gestures/presentation/widgets/gesture_document_view.dart';
import 'package:coldigui/features/gestures/presentation/widgets/gesture_figure.dart';
import 'package:coldigui/features/gestures/presentation/widgets/newer_schema_banner.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_route_params_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/gesture_test_png.dart';

const _r2Key = 'assets/praises/p1/m1.gestures';

String _read(String name) => File('test/fixtures/gestures/$name').readAsStringSync();

/// O prefetch da tela não pode ir à rede no teste.
class _NoopFigureRepository implements GestureFigureRepository {
  @override
  Future<Uint8List?> get(String r2Key) async => null;

  @override
  Future<void> prefetch(Iterable<String> r2Keys) async {}
}

/// [document] `null` = 404; `Future.error` = falha de rede.
Future<SharedPreferences> _pump(
  WidgetTester tester, {
  required Future<GestureDocument?> Function() document,
  Map<String, String>? queryParams,
}) async {
  SharedPreferences.setMockInitialValues(const {});
  final prefs = await SharedPreferences.getInstance();
  final dict = parseGestureDictionary(_read('dictionary.json'));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        gestureDocumentProvider.overrideWith((ref, key) => document()),
        gestureDictionaryProvider.overrideWith((ref) async => dict),
        gestureFigureProvider.overrideWith((ref, k) async => gestureTestPng()),
        gestureFigureRepositoryProvider.overrideWithValue(_NoopFigureRepository()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: GestureReaderScreen(
          queryParams: queryParams ?? {'pdfId': encodePdfId(_r2Key), 'titulo': 'Quero viver'},
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return prefs;
}

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(GestureReaderScreen)));

Future<void> _sendWithControl(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

void main() {
  testWidgets('renderiza o documento e publica os params da rota', (tester) async {
    await _pump(tester, document: () async => parseGestureDocument(_read('182_quero_viver.json')));

    expect(find.byType(GestureDocumentView), findsOneWidget);
    expect(find.text('182 - QUERO VIVER PRA SEMPRE COM JESUS'), findsOneWidget);
    expect(find.byType(GestureCardTile), findsWidgets);
    expect(_containerOf(tester).read(readerRouteParamsProvider)['pdfId'], encodePdfId(_r2Key));
  });

  testWidgets('404 mostra "ainda não tem gestos"', (tester) async {
    await _pump(tester, document: () async => null);
    expect(find.text('Este louvor ainda não tem gestos'), findsOneWidget);
    expect(find.byType(GestureDocumentView), findsNothing);
  });

  testWidgets('falha de rede mostra indisponível com retry que reinvalida', (tester) async {
    var calls = 0;
    await _pump(tester, document: () {
      calls++;
      return calls == 1
          ? Future.error(const GestureFetchFailedException(_r2Key, 'rede'))
          : Future.value(parseGestureDocument(_read('182_quero_viver.json')));
    });
    expect(find.text('Gestos indisponíveis · tentar de novo'), findsOneWidget);

    await tester.tap(find.byKey(gestureReaderRetryKey));
    await tester.pump();
    await tester.pump();
    expect(find.byType(GestureDocumentView), findsOneWidget);
  });

  testWidgets('schema v2 mostra o banner acima do papel', (tester) async {
    await _pump(tester, document: () async => parseGestureDocument(_read('schema_v2.json')));
    expect(find.byType(NewerSchemaBanner), findsOneWidget);
    expect(find.byType(GestureDocumentView), findsOneWidget);
  });

  testWidgets('A+/A- mudam a fonte e persistem; Ctrl+↑/↓ também', (tester) async {
    final prefs = await _pump(tester, document: () async => parseGestureDocument(_read('182_quero_viver.json')));
    final container = _containerOf(tester);
    expect(container.read(gestureReaderFontSizeProvider), 18);

    await tester.tap(find.byTooltip('Aumentar letra dos gestos'));
    await tester.pump();
    expect(container.read(gestureReaderFontSizeProvider), 20);
    expect(prefs.getDouble(StorageKeys.gestureReaderFontSize), 20);
    expect(tester.getSize(find.byType(GestureFigure).first).width, closeTo(96 * 20 / 18, 0.1));

    await _sendWithControl(tester, LogicalKeyboardKey.arrowDown);
    await _sendWithControl(tester, LogicalKeyboardKey.arrowDown);
    expect(container.read(gestureReaderFontSizeProvider), 16);

    await tester.tap(find.byTooltip('Diminuir letra dos gestos'));
    await tester.pump();
    expect(container.read(gestureReaderFontSizeProvider), 14);
    expect(tester.widget<IconButton>(find.byTooltip('Diminuir letra dos gestos')).onPressed, isNull);
  });

  testWidgets('pdfId inválido não quebra: mostra "ainda não tem gestos"', (tester) async {
    await _pump(tester, document: () async => null, queryParams: {'pdfId': '###'});
    expect(find.text('Este louvor ainda não tem gestos'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test --dart-define-from-file=dart_defines/plpcg.json test/unit/core/gesture_reader_url_builder_test.dart test/widget/features/gestures/gesture_reader_screen_test.dart`
Expected: falha de compilação.

- [ ] **Step 3: Rota, URL builder, wakelock, shell, atalhos**

`lib/core/routing/route_paths.dart`, após `chords`:

```dart
  /// Leitor de gestos CIAs — irmã de [chords], filha da branch Home.
  static const String gestos = '/gestos';
```

`lib/core/utils/gesture_reader_url_builder.dart`:

```dart
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/url_sync_params.dart';

/// Monta o path do leitor de gestos.
///
/// Reusa [UrlSyncParams.pdfId] como o leitor de cifras: gesto, cifra e PDF
/// vivem no mesmo espaço de ids, e é isso que deixa [CarouselChips]
/// sincronizar o chip focado nas três rotas com o mesmo código.
String buildGestureReaderLocation({
  required String gestureId,
  String? titulo,
  String? subtitulo,
}) {
  final params = <String, String>{UrlSyncParams.pdfId: gestureId};
  if (titulo != null && titulo.isNotEmpty) params[UrlSyncParams.titulo] = titulo;
  if (subtitulo != null && subtitulo.isNotEmpty) {
    params[UrlSyncParams.subtitulo] = subtitulo;
  }
  final query = params.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
  return '${RoutePaths.gestos}?$query';
}
```

`lib/core/routing/app_router.dart`: import `'../../features/gestures/presentation/pages/gesture_reader_screen.dart';` e, logo após o `GoRoute(path: 'cifra', …)`:

```dart
                  GoRoute(
                    path: 'gestos',
                    builder: (context, state) => GestureReaderScreen(
                      queryParams: safeQueryParameters(state.uri),
                    ),
                  ),
```

`stage_wakelock.dart`: `RoutePaths.gestos` em `_stageRoutes` (e "partitura, cifra, gestos e reprodutor" no comentário). `shell_scaffold.dart` `_isImmersiveMediaRoute`: `|| path == RoutePaths.gestos`. `app_shortcuts.dart` `_isReaderRoute`: `|| path == RoutePaths.gestos`; na tabela do doc-comment, `F`/`Esc` "no leitor PDF, no de cifras e no de gestos".

- [ ] **Step 4: A tela**

`lib/features/gestures/presentation/pages/gesture_reader_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../core/utils/pdf_path_normalizer.dart';
import '../../../../core/utils/url_sync_params.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_shell/presentation/widgets/app_shortcuts.dart';
import '../../../pdf_reader/domain/entities/carousel_reader_position.dart';
import '../../../pdf_reader/presentation/providers/reader_fullscreen_provider.dart';
import '../../../pdf_reader/presentation/providers/reader_route_params_provider.dart';
import '../../data/providers/gesture_providers.dart';
import '../../domain/entities/gesture_dictionary.dart';
import '../../domain/entities/gesture_document.dart';
import '../../domain/entities/gesture_reader_font_size.dart';
import '../providers/gesture_reader_font_size_provider.dart';
import '../widgets/gesture_document_view.dart';
import '../widgets/newer_schema_banner.dart';

const Key gestureReaderRetryKey = ValueKey('gesture-reader-retry');

/// Leitor de gestos CIAs — rota `/gestos`, filha do [ShellScaffold].
///
/// Espelho de `ChordReaderScreen`: barras 1–2 vêm do shell; aqui ficam a barra
/// 3 (`A-`/`A+`, tela cheia) e o papel. Recebe [UrlSyncParams.pdfId] (id do
/// material, mesmo espaço do PDF), `titulo` e `subtitulo`; publica os params
/// em [readerRouteParamsProvider] para o [CarouselChips] sincronizar o chip.
class GestureReaderScreen extends ConsumerStatefulWidget {
  const GestureReaderScreen({required this.queryParams, super.key});

  final Map<String, String> queryParams;

  @override
  ConsumerState<GestureReaderScreen> createState() => _GestureReaderScreenState();
}

class _GestureReaderScreenState extends ConsumerState<GestureReaderScreen> {
  late final FocusNode _keyboardFocusNode = FocusNode(debugLabel: 'gestureReaderKeys');
  final _documentViewKey = GlobalKey<GestureDocumentViewState>();
  var _louvorNavigationInProgress = false;
  var _prefetched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(readerRouteParamsProvider.notifier).update(widget.queryParams);
    });
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  /// `r2Key` decodificado do id da rota; vazio se o id faltar ou for inválido.
  String get _r2Key {
    final id = widget.queryParams[UrlSyncParams.pdfId] ?? '';
    if (id.isEmpty) return '';
    try {
      return PdfPathNormalizer.getPdfRelPath(id);
    } on Object {
      return '';
    }
  }

  Future<void> _navigateLouvor(CarouselReaderDirection direction) async {
    if (_louvorNavigationInProgress) return;
    _louvorNavigationInProgress = true;
    try {
      await navigateReaderCarouselByKeyboard(
        ref: ref,
        context: context,
        currentPdfId: widget.queryParams[UrlSyncParams.pdfId],
        direction: direction,
      );
    } finally {
      _louvorNavigationInProgress = false;
    }
  }

  /// `Ctrl+↑/↓` corpo da letra, `Ctrl+←/→` troca de louvor. `F`/`Esc` sobem
  /// para [AppShortcuts]. As setas sem modificador ficam para o modo foco.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    if (!(keyboard.isControlPressed || keyboard.isMetaPressed)) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      ref.read(gestureReaderFontSizeProvider.notifier).increase();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      ref.read(gestureReaderFontSizeProvider.notifier).decrease();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _navigateLouvor(CarouselReaderDirection.next);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _navigateLouvor(CarouselReaderDirection.previous);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Aquece as figuras uma vez por documento+dicionário carregados.
  void _maybePrefetch(GestureDocument document, GestureDictionary dictionary) {
    if (_prefetched) return;
    _prefetched = true;
    prefetchGestureFigures(
      ref.read(gestureFigureRepositoryProvider),
      document,
      dictionary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fontSize = ref.watch(gestureReaderFontSizeProvider);
    final docAsync = ref.watch(gestureDocumentProvider(_r2Key));
    final dictionary =
        ref.watch(gestureDictionaryProvider).asData?.value ?? GestureDictionary.empty;

    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: Listener(
        onPointerDown: (_) => _keyboardFocusNode.requestFocus(),
        child: ColoredBox(
          color: AppColors.background,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _GestureReaderToolbar(fontSize: fontSize, l10n: l10n),
                Expanded(
                  child: docAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, _) => _Message(
                      message: l10n.gesturesReaderUnavailable,
                      onTap: () => ref.invalidate(gestureDocumentProvider(_r2Key)),
                      key: gestureReaderRetryKey,
                    ),
                    data: (document) {
                      if (document == null) {
                        return _Message(message: l10n.gesturesReaderEmpty);
                      }
                      if (dictionary.byId.isNotEmpty) {
                        _maybePrefetch(document, dictionary);
                      }
                      return Column(
                        children: [
                          if (document.isNewerSchema) const NewerSchemaBanner(),
                          Expanded(
                            child: GestureDocumentView(
                              key: _documentViewKey,
                              document: document,
                              dictionary: dictionary,
                              fontSize: fontSize,
                              // Task 15 liga o modo foco aqui.
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.message, this.onTap, super.key});

  final String message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: AppColors.textLight),
          ),
        ),
      ),
    );
  }
}

ButtonStyle _toolbarButtonStyle(Color color) => IconButton.styleFrom(
  foregroundColor: color,
  disabledForegroundColor: color.withValues(alpha: 0.38),
  visualDensity: VisualDensity.compact,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  minimumSize: const Size(44, 44),
);

/// Barra 3: corpo da letra e tela cheia.
class _GestureReaderToolbar extends ConsumerWidget {
  const _GestureReaderToolbar({required this.fontSize, required this.l10n});

  final double fontSize;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = ref.read(gestureReaderFontSizeProvider.notifier);
    final style = _toolbarButtonStyle(AppColors.gold);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
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
```

Se `AppColors.gold`/`AppColors.textLight` não existirem com esses nomes, use os que existem em `lib/core/theme/color_extensions.dart` (`gold`, `textLight`, `background` estão lá em 2026-09-11).

- [ ] **Step 5: Rodar até passar; analyze; commit**

Run: `flutter test --dart-define-from-file=dart_defines/plpcg.json test/unit/core/gesture_reader_url_builder_test.dart test/unit/features/app_shell/ test/widget/features/gestures/ && flutter analyze`

```bash
git add lib/core/routing lib/core/utils/gesture_reader_url_builder.dart lib/features/gestures/presentation/pages lib/features/app_shell test/unit/core/gesture_reader_url_builder_test.dart test/unit/features/app_shell/stage_wakelock_test.dart test/widget/features/gestures/gesture_reader_screen_test.dart
git commit -m "feat(gestures): rota /gestos, GestureReaderScreen com barra de fonte, wakelock e atalhos

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01DuSVKfiGsabi168JixJLB1"
```

---

### Task 13: Encaixes no catálogo — `GestureMaterialRef`, adapter, caches, `OpenMaterial`, carousel

**Files:**
- Modify: `lib/features/catalog/domain/entities/catalog_material.dart` (nova variante; doc "quatro casos" → "cinco")
- Modify: `lib/features/catalog/domain/entities/louvor_group.dart` (`gestureMaterials` no construtor, getter, `isColdigom`, `fromLouvores`, `_buildGroup`)
- Modify: `lib/features/catalog/domain/utils/louvor_material_icons.dart:62-66` (`forMaterial`)
- Modify: `lib/features/catalog/presentation/widgets/material_sheet_actions.dart:91`
- Modify: `lib/features/carousel/presentation/widgets/carousel_swap_material_button.dart:101`
- Modify: `lib/features/coldigom/data/adapters/coldigom_louvor_adapter.dart` (`toGestureMaterials`, `_kindOfType`)
- Modify: `lib/features/coldigom/data/providers/coldigom_providers.dart` (novo notifier após o de cifras)
- Modify: `lib/features/coldigom/data/coldigom_cache_writer.dart` (`_merge` + `mergeSearchResult`/`mergeBrowseResult`/`mergePraiseDetail` + novo `mergeGestures`) — é o **ponto único** de escrita nos caches; o warmup e a busca passam por ele, não os edite diretamente
- Modify: `lib/features/coldigom/domain/repositories/coldigom_search_repository.dart` (`gestureMaterials` em `ColdigomSearchResult` e `ColdigomBrowseResult`, ao lado de `chordMaterials`)
- Modify: `lib/features/coldigom/data/repositories/coldigom_search_repository_impl.dart` (`_mapDetails` + chamadas `fromLouvores` + construtores de resultado — siga cada ocorrência de `chordMaterials`)
- Modify: `lib/features/coldigom/data/sources/coldigom_catalog_source.dart` (mapa `gestures`, `findGroupById`, `findMaterialById`)
- Modify: `lib/features/coldigom/data/providers/coldigom_catalog_source_provider.dart` (`gestures:`)
- Modify: `lib/features/catalog/domain/utils/find_louvor_group_by_pdf_id.dart` (`gestureCache` opcional em `findSwapMaterialGroup`; passa ao `ColdigomCatalogSource` e ao `_groupIfMultiple`)
- Modify: `lib/features/catalog/presentation/providers/open_material_provider.dart` (typedef + caso)
- Create: `lib/features/gestures/presentation/utils/open_gesture_in_reader.dart`
- Modify: `lib/features/pdf_reader/presentation/providers/reader_carousel_actions_provider.dart:49-53` (desvio de gesto por rota)
- Test: `test/unit/features/gestures/gesture_material_adapter_test.dart`, `test/unit/features/gestures/coldigom_catalog_source_gesture_test.dart`, `test/unit/features/catalog/louvor_group_gestures_test.dart`, `test/widget/features/gestures/open_gesture_in_reader_test.dart`, `test/unit/features/catalog/open_material_gesture_test.dart`

**Interfaces:**
- Consumes: T4 (`GestureMaterial`), T12 (`buildGestureReaderLocation`), `MaterialKind.gesture`, `encodePdfId`, `coldigomCacheWriterProvider` (`lib/features/coldigom/data/providers/coldigom_providers.dart`).
- Produces: `GestureMaterialRef(GestureMaterial gesture)` em `CatalogMaterial`; `LouvorGroup.gestureMaterials`; `ColdigomLouvorAdapter.toGestureMaterials(PraiseDetailDto)`; `coldigomGestureMaterialsCacheProvider` (`Notifier<Map<String, GestureMaterial>>` com `mergeGestures`, `findByGestureId`); `ColdigomCacheWriter.mergeGestures(Iterable<GestureMaterial>)`; `ColdigomCatalogSource({gestures})`; `GestureMaterialOpener` typedef + `OpenMaterial.openGesture`; `openGestureInReader({ref, context, gesture})`; `GestureRoute gestureRouteFor(String materialId, Map<String, GestureMaterial> cache)`.

> O repo mudou em 2026-09-11 (commits `73f7392`, `40fceac`, `2f19870`): os merges nos caches passam por `ColdigomCacheWriter`, a fonte Coldigom vem de `coldigomCatalogSourceProvider`, e `ColdigomCatalogSource` tem também `youtube` e `searchRepository` (opcionais). Antes de editar, leia `coldigom_cache_writer.dart` inteiro e `grep -rn chordMaterials lib` — **toda** ocorrência de `chordMaterials` ganha um irmão `gestureMaterials`.

- [ ] **Step 1: Testes (falhando)**

`test/unit/features/gestures/gesture_material_adapter_test.dart`:

```dart
import 'package:coldigui/core/utils/material_id_kind.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/coldigom/data/adapters/coldigom_louvor_adapter.dart';
import 'package:coldigui/features/coldigom/data/models/praise_dto.dart';
import 'package:flutter_test/flutter_test.dart';

PraiseDetailDto _praise(List<Map<String, Object?>> materials) => PraiseDetailDto.fromJson({
  'id': 'p1',
  'name': 'Quero viver',
  'number': '182',
  'rhythm': 'Marcha',
  'tonality': 'C',
  'category': 'CIA',
  'author': 'Autor',
  'tag_names': <String>[],
  'materials': materials,
});

void main() {
  test('type gestures com r2_key vira GestureMaterial no espaço do pdfId', () {
    final praise = _praise([
      {'id': 'm1', 'praise_id': 'p1', 'type': 'gestures', 'r2_key': 'assets/praises/p1/m1.gestures', 'material_kind_name': 'Gestos'},
      {'id': 'm2', 'praise_id': 'p1', 'type': 'pdf', 'r2_key': 'assets/praises/p1/m2.pdf'},
    ]);
    final items = ColdigomLouvorAdapter.toGestureMaterials(praise);
    expect(items, hasLength(1));
    final g = items.single;
    expect(g.gestureId, encodePdfId('assets/praises/p1/m1.gestures'));
    expect(materialIdKindOf(g.gestureId), MaterialKind.gesture);
    expect(g.r2Key, 'assets/praises/p1/m1.gestures');
    expect(g.nome, 'Quero viver');
    expect(g.numero, '182');
    expect(g.groupId, 'p1');
    expect(g.categoria, 'Gestos');
    expect(g.classificacao, 'Marcha');
    expect(g.author, 'Autor');
  });

  test('sem r2_key é ignorado; categoria cai para "Gestos"', () {
    final praise = _praise([
      {'id': 'm1', 'praise_id': 'p1', 'type': 'gestures'},
      {'id': 'm3', 'praise_id': 'p1', 'type': 'GESTURES', 'r2_key': 'assets/praises/p1/m3.gestures'},
    ]);
    final items = ColdigomLouvorAdapter.toGestureMaterials(praise);
    expect(items.single.categoria, 'Gestos');
  });

  test('PDF de gestos continua sendo Louvor (toLouvores), não GestureMaterial', () {
    final praise = _praise([
      {'id': 'm2', 'praise_id': 'p1', 'type': 'pdf', 'r2_key': 'assets/praises/p1/gestos.pdf', 'material_kind_name': 'Gestos em Gravura'},
    ]);
    expect(ColdigomLouvorAdapter.toGestureMaterials(praise), isEmpty);
    expect(ColdigomLouvorAdapter.toLouvores(praise), hasLength(1));
  });
}
```

Confira em `lib/features/coldigom/data/models/praise_dto.dart` os nomes exatos das chaves JSON (`r2_key`, `material_kind_name`, `tag_names`) e ajuste o helper `_praise` se divergirem.

`test/unit/features/gestures/coldigom_catalog_source_gesture_test.dart`:

```dart
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/coldigom/data/sources/coldigom_catalog_source.dart';
import 'package:coldigui/features/gestures/domain/entities/gesture_material.dart';
import 'package:flutter_test/flutter_test.dart';

final _id = encodePdfId('assets/praises/p1/m1.gestures');
final _gesture = GestureMaterial(
  gestureId: _id, r2Key: 'assets/praises/p1/m1.gestures', nome: 'Quero viver',
  numero: '182', groupId: 'p1', categoria: 'Gestos', classificacao: 'Marcha',
);

void main() {
  test('findMaterialById resolve gesto do cache', () {
    final source = ColdigomCatalogSource(gestures: {_id: _gesture});
    final material = source.findMaterialById(_id);
    expect(material, isA<GestureMaterialRef>());
    expect(material!.id, _id);
  });

  test('gesto fora do cache devolve null', () {
    expect(const ColdigomCatalogSource().findMaterialById(_id), isNull);
  });

  test('findGroupById inclui o gesto nos extras do grupo', () {
    final source = ColdigomCatalogSource(gestures: {_id: _gesture});
    final group = source.findGroupById('p1');
    expect(group, isNotNull);
    expect(group!.gestureMaterials.single.gestureId, _id);
    expect(group.extras.whereType<GestureMaterialRef>(), hasLength(1));
  });
}
```

`test/unit/features/catalog/louvor_group_gestures_test.dart`:

```dart
import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:coldigui/features/gestures/domain/entities/gesture_material.dart';
import 'package:flutter_test/flutter_test.dart';

const _chord = ChordMaterial(chordId: 'c', r2Key: 'k.chord', nome: 'N', numero: '1', groupId: 'g', categoria: 'Cifra', classificacao: 'x');
const _gesture = GestureMaterial(gestureId: 'g1', r2Key: 'k.gestures', nome: 'N', numero: '1', groupId: 'g', categoria: 'Gestos', classificacao: 'x');

void main() {
  test('gestureMaterials entra em extras depois das cifras e antes do áudio', () {
    final group = LouvorGroup(
      groupId: 'g', numero: '1', nome: 'N', sections: const [],
      chordMaterials: const [_chord], gestureMaterials: const [_gesture],
    );
    expect(group.extras.map((m) => m.runtimeType), [ChordMaterialRef, GestureMaterialRef]);
    expect(group.gestureMaterials.single.gestureId, 'g1');
    expect(group.isColdigom, isTrue);
  });

  test('fromLouvores agrupa gestos pelo groupId', () {
    final groups = LouvorGroup.fromLouvores(const [], gestureMaterials: const [_gesture]);
    expect(groups.single.groupId, 'g');
    expect(groups.single.gestureMaterials, hasLength(1));
    expect(groups.single.nome, 'N');
  });
}
```

`test/unit/features/catalog/open_material_gesture_test.dart`:

```dart
import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/presentation/providers/open_material_provider.dart';
import 'package:coldigui/features/gestures/domain/entities/gesture_material.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _gesture = GestureMaterial(gestureId: 'g1', r2Key: 'k.gestures', nome: 'N', numero: '1', groupId: 'g', categoria: 'Gestos', classificacao: 'x');

void main() {
  testWidgets('GestureMaterialRef vai para openGesture', (tester) async {
    GestureMaterial? opened;
    final open = OpenMaterial(
      openGesture: ({required ref, required context, required gesture}) async => opened = gesture,
    );
    late WidgetRef capturedRef;
    late BuildContext capturedContext;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(builder: (context, ref, _) {
            capturedRef = ref;
            capturedContext = context;
            return const SizedBox();
          }),
        ),
      ),
    );
    await open.open(capturedContext, capturedRef, const GestureMaterialRef(_gesture));
    expect(opened, same(_gesture));
  });
}
```

`test/widget/features/gestures/open_gesture_in_reader_test.dart`: **copie** `test/widget/features/chords/open_chord_in_reader_test.dart` inteiro e aplique estas substituições, mantendo o resto igual (o teste pina que abrir entra na lista ativa e navega):

- import `chords/domain/entities/chord_material.dart` → `gestures/domain/entities/gesture_material.dart`; `chords/presentation/utils/open_chord_in_reader.dart` → `gestures/presentation/utils/open_gesture_in_reader.dart`;
- `ChordMaterial(chordId: …)` → `GestureMaterial(gestureId: …)`; `.chord` → `.gestures` nas chaves; `Cifra` → `Gestos`;
- `openChordInReader(… chord: _chord)` → `openGestureInReader(… gesture: _gesture)`;
- `RoutePaths.chords` → `RoutePaths.gestos`; `coldigomChordMaterialsCacheProvider` → `coldigomGestureMaterialsCacheProvider`; `mergeChords`/`findByChordId` → `mergeGestures`/`findByGestureId` (o `openChordInReader` atual funde pelo `coldigomCacheWriterProvider`; o de gestos faz o mesmo);
- nomes de variáveis `_chord`/`_chordId` → `_gesture`/`_gestureId`.

Playlist: `PlaylistListTile` já manda tudo que não é PDF para `resolveCatalogMaterialFromWidget` + `openMaterialProvider`, então não há código novo. Se `test/widget/features/playlists/playlist_list_tile_test.dart` tiver um caso "entrada de cifra abre pelo opener", duplique-o para uma entrada `.gestures` (mesma montagem, `GestureMaterial` no cache `coldigomGestureMaterialsCacheProvider`, esperar `GestureMaterialRef` no opener). Se não tiver, pule — o caminho é idêntico.

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test --dart-define-from-file=dart_defines/plpcg.json test/unit/features/gestures/gesture_material_adapter_test.dart`
Expected: falha de compilação.

- [ ] **Step 3: `CatalogMaterial` e os `switch` exaustivos**

Em `catalog_material.dart`, import `'../../../gestures/domain/entities/gesture_material.dart';` e, após `ChordMaterialRef`:

```dart
/// Documento de gestos CIAs — abre em `/gestos`.
final class GestureMaterialRef extends CatalogMaterial {
  const GestureMaterialRef(this.gesture);

  final GestureMaterial gesture;

  @override
  String get id => gesture.gestureId;

  @override
  MaterialKind get kind => MaterialKind.gesture;

  @override
  String get groupId => gesture.groupId;

  @override
  String get categoria => gesture.categoria;
}
```

Atualize o doc da classe (`cobrir os quatro casos` → `cinco`; "PDF, cifra, áudio ou YouTube" → "PDF, cifra, gestos, áudio ou YouTube").

Rode `flutter analyze` — ele lista cada `switch` não exaustivo. Corrija:

- `louvor_group.dart` `isColdigom`: `case ChordMaterialRef() || GestureMaterialRef(): return true;`
- `louvor_material_icons.dart` `forMaterial`: `ChordMaterialRef() || GestureMaterialRef() || AudioMaterial() || YoutubeMaterialRef() => forKind(material.kind),`
- `material_sheet_actions.dart`: `ChordMaterialRef() || GestureMaterialRef() || YoutubeMaterialRef() => null,`
- `carousel_swap_material_button.dart`: `case ChordMaterialRef() || GestureMaterialRef() || YoutubeMaterialRef():` (abre pelo `openMaterialProvider`).
- `open_material_provider.dart` — ver Step 6.

- [ ] **Step 4: `LouvorGroup`**

Em `louvor_group.dart`: import `GestureMaterial`; no construtor adicionar `List<GestureMaterial> gestureMaterials = const [],` e na lista de compatibilidade inserir **depois das cifras e antes dos áudios**:

```dart
             for (final chord in chordMaterials) ChordMaterialRef(chord),
             for (final gesture in gestureMaterials) GestureMaterialRef(gesture),
             for (final track in audioTracks) AudioMaterial(track),
```

Getter, após `chordMaterials`:

```dart
  /// Documentos de gestos Coldigom associados ao mesmo [groupId] — de [extras].
  List<GestureMaterial> get gestureMaterials => [
    for (final material in extras)
      if (material is GestureMaterialRef) material.gesture,
  ];
```

`fromLouvores`: parâmetro `List<GestureMaterial> gestureMaterials = const [],`; agrupar como as cifras (`gestureByGroup`), incluir em `allGroupIds`, passar a `_buildGroup` (novo parâmetro `List<GestureMaterial> gestures` após `chords`); em `_buildGroup`, o `else if (chords.isNotEmpty)` de nome/número ganha um irmão `else if (gestures.isNotEmpty)` com `gestures.first.nome`/`numero`, e o construtor recebe `gestureMaterials: List<GestureMaterial>.from(gestures)`. Atualize o doc do construtor ("cifras, gestos, áudios, YouTube").

- [ ] **Step 5: Adapter, cache em memória, warmup, busca, catálogo**

`coldigom_louvor_adapter.dart`: import `gesture_material.dart`; `'gestures' => MaterialKind.gesture,` em `_kindOfType`; novo método após `toChordMaterials`:

```dart
  /// Um [GestureMaterial] por `type: gestures` com `r2_key` válido.
  static List<GestureMaterial> toGestureMaterials(PraiseDetailDto praise) {
    final items = <GestureMaterial>[];
    for (final material in praise.materials) {
      if (_kindOfType(material.type) != MaterialKind.gesture) continue;
      final r2Key = material.r2Key;
      if (r2Key == null || r2Key.isEmpty) continue;
      items.add(
        GestureMaterial(
          gestureId: encodePdfId(r2Key),
          r2Key: r2Key,
          nome: praise.name,
          numero: praise.number,
          groupId: praise.id,
          categoria: material.materialKindName ?? 'Gestos',
          classificacao: praise.rhythm,
          author: praise.author,
          source: LouvorDataSource.coldigom,
        ),
      );
    }
    return items;
  }
```

`coldigom_providers.dart`, após `coldigomChordMaterialsCacheProvider`:

```dart
/// Cache em memória de documentos de gestos coldigom indexados por `gestureId`.
class ColdigomGestureMaterialsCacheNotifier
    extends Notifier<Map<String, GestureMaterial>> {
  @override
  Map<String, GestureMaterial> build() => const {};

  void mergeGestures(Iterable<GestureMaterial> gestures) {
    if (gestures.isEmpty) return;
    final next = Map<String, GestureMaterial>.from(state);
    for (final gesture in gestures) {
      next[gesture.gestureId] = gesture;
    }
    state = next;
  }

  GestureMaterial? findByGestureId(String gestureId) => state[gestureId];
}

final coldigomGestureMaterialsCacheProvider =
    NotifierProvider<
      ColdigomGestureMaterialsCacheNotifier,
      Map<String, GestureMaterial>
    >(ColdigomGestureMaterialsCacheNotifier.new);
```

`coldigom_cache_writer.dart`: import `gesture_material.dart`; `_merge` ganha `required List<GestureMaterial> gestureMaterials` e chama `_ref.read(coldigomGestureMaterialsCacheProvider.notifier).mergeGestures(gestureMaterials)`; `mergeSearchResult`/`mergeBrowseResult` passam `gestureMaterials: result.gestureMaterials`; `mergePraiseDetail` passa `gestureMaterials: ColdigomLouvorAdapter.toGestureMaterials(detail)`; e um método novo ao lado de `mergeChords`:

```dart
  /// Funde só gestos — o sheet e o desvio de `/gestos` já têm o objeto pronto.
  void mergeGestures(Iterable<GestureMaterial> gestures) {
    _ref
        .read(coldigomGestureMaterialsCacheProvider.notifier)
        .mergeGestures(gestures);
  }
```

`coldigom_search_repository.dart`: `this.gestureMaterials = const [],` + `final List<GestureMaterial> gestureMaterials;` em `ColdigomSearchResult` e `ColdigomBrowseResult` (ao lado de `chordMaterials`). `coldigom_search_repository_impl.dart`: `_mapDetails` ganha `gestureMaterials` no record (preenchido com `toGestureMaterials`); toda chamada `LouvorGroup.fromLouvores(...)` que passa `chordMaterials:` passa também `gestureMaterials: fetched.gestureMaterials,`; todo construtor de resultado que passa `chordMaterials:` passa também `gestureMaterials:` (nos de lista vazia/erro, deixe o default).

`coldigom_catalog_source.dart`: campo `final Map<String, GestureMaterial> gestures;` (`this.gestures = const {}`), `findGroupById` filtra `groupGestures` por `groupId`, inclui na condição de vazio e passa `gestureMaterials: groupGestures` ao `fromLouvores`; `findMaterialById`:

```dart
      case MaterialKind.gesture:
        final gesture = gestures[materialId];
        return gesture == null ? null : GestureMaterialRef(gesture);
      // YouTube não vive no espaço de ids do app (o id vem do Worker).
      case MaterialKind.youtube:
      case MaterialKind.unknown:
        return null;
```

`coldigom_catalog_source_provider.dart`: `gestures: ref.watch(coldigomGestureMaterialsCacheProvider),`. `find_louvor_group_by_pdf_id.dart`: `Map<String, GestureMaterial>? gestureCache,` em `findSwapMaterialGroup`, passado ao `ColdigomCatalogSource(gestures: gestureCache ?? const {})`; `_groupIfMultiple` ganha `List<GestureMaterial> gestures` filtrado por `groupId` e passa `gestureMaterials:` ao `fromLouvores` (quem chama `findSwapMaterialGroup` hoje pode continuar sem passar o cache — o parâmetro é opcional).

- [ ] **Step 6: `openGestureInReader` e `OpenMaterial`**

`lib/features/gestures/presentation/utils/open_gesture_in_reader.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/gesture_reader_url_builder.dart';
import '../../../../core/utils/material_id_kind.dart';
import '../../../coldigom/data/providers/coldigom_providers.dart';
import '../../../playlists/presentation/providers/playlists_provider.dart';
import '../../domain/entities/gesture_material.dart';

/// Resultado de decodificar um id de material como documento de gestos.
///
/// [isGesture] falso = siga pelo caminho de PDF; verdadeiro com [location]
/// nula = é gesto, mas o cache está frio (não há para onde navegar).
class GestureRoute {
  const GestureRoute({required this.isGesture, this.location});

  final bool isGesture;
  final String? location;
}

/// Classifica [materialId] como gesto e resolve a rota `/gestos` pelo cache.
GestureRoute gestureRouteFor(
  String materialId,
  Map<String, GestureMaterial> gestureCache,
) {
  if (materialIdKindOf(materialId) != MaterialKind.gesture) {
    return const GestureRoute(isGesture: false);
  }
  final gesture = gestureCache[materialId];
  if (gesture == null) return const GestureRoute(isGesture: true);
  return GestureRoute(
    isGesture: true,
    location: buildGestureReaderLocation(
      gestureId: gesture.gestureId,
      titulo: gesture.nome,
      subtitulo: gesture.numero,
    ),
  );
}

/// Abre [gesture] em `/gestos`, entrando na lista ativa como o PDF faz.
///
/// Espelha `openChordInReader`: o documento é buscado pelo
/// `gestureDocumentProvider` na própria tela.
Future<void> openGestureInReader({
  required WidgetRef ref,
  required BuildContext context,
  required GestureMaterial gesture,
}) async {
  ref.read(coldigomCacheWriterProvider).mergeGestures([gesture]);

  await ref
      .read(playlistsProvider.notifier)
      .addLouvorToActivePlaylist(gesture.gestureId);

  if (!context.mounted) return;

  unawaited(
    context.push(
      buildGestureReaderLocation(
        gestureId: gesture.gestureId,
        titulo: gesture.nome,
        subtitulo: gesture.numero,
      ),
    ),
  );
}
```

`open_material_provider.dart`: imports de `gesture_material.dart` e `open_gesture_in_reader.dart`; typedef

```dart
/// Abre um documento de gestos em `/gestos` (`openGestureInReader` em produção).
typedef GestureMaterialOpener =
    Future<void> Function({
      required WidgetRef ref,
      required BuildContext context,
      required GestureMaterial gesture,
    });
```

campo `this.openGesture = openGestureInReader,` / `final GestureMaterialOpener openGesture;` e o caso no `switch`:

```dart
        case GestureMaterialRef(:final gesture):
          await openGesture(ref: ref, context: context, gesture: gesture);
```

`reader_carousel_actions_provider.dart`, logo após o bloco `chordRoute`:

```dart
    final gestureRoute = gestureRouteFor(
      targetPdfId,
      ref.read(coldigomGestureMaterialsCacheProvider),
    );
    if (gestureRoute.isGesture) return gestureRoute.location;
```

- [ ] **Step 7: Rodar a suíte inteira; analyze; commit**

Run: `flutter test --dart-define-from-file=dart_defines/plpcg.json && flutter analyze`
Expected: tudo verde (a suíte inteira, porque `CatalogMaterial` é usado em muitos testes).

```bash
git add lib test/unit/features/gestures test/unit/features/catalog/louvor_group_gestures_test.dart test/unit/features/catalog/open_material_gesture_test.dart test/widget/features/gestures/open_gesture_in_reader_test.dart
git commit -m "feat(gestures): GestureMaterialRef no catálogo, adapter, cache coldigom, OpenMaterial e desvio por rota

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01DuSVKfiGsabi168JixJLB1"
```

---

### Task 14: Seção "Gestos" no `MaterialSheet`

**Files:**
- Modify: `lib/features/catalog/presentation/widgets/material_sheet.dart` (`initState` merge + seção)
- Test: `test/widget/features/catalog/material_sheet_test.dart` (adicionar casos)

**Interfaces:**
- Consumes: T13 (`GestureMaterialRef`, `LouvorGroup.gestureMaterials`, `coldigomGestureMaterialsCacheProvider`), l10n `gesturesMaterialSection`.

- [ ] **Step 1: Testes (falhando)** — abra `test/widget/features/catalog/material_sheet_test.dart`, veja como os casos existentes montam um `LouvorGroup` com cifra e abrem o sheet, e adicione um `group('gestos')` com dois testes no mesmo estilo:

```dart
    testWidgets('lista o documento de gestos com ícone pan_tool e rótulo Gestos', (tester) async {
      // monte o group como nos testes de cifra, com
      // gestureMaterials: [GestureMaterial(gestureId: encodePdfId('assets/praises/p1/m1.gestures'), r2Key: 'assets/praises/p1/m1.gestures', nome: 'N', numero: '1', groupId: 'p1', categoria: 'Gestos', classificacao: 'x')]
      // e abra o sheet como os testes vizinhos fazem.
      expect(find.text('Gestos'), findsWidgets); // rótulo da seção + categoria
      expect(find.byIcon(Icons.pan_tool_outlined), findsOneWidget);
    });

    testWidgets('toque no gesto chama onMaterialSelected com GestureMaterialRef', (tester) async {
      // capture o material passado ao onMaterialSelected (o teste de cifra já faz isso)
      // tap em find.byIcon(Icons.pan_tool_outlined); pumpAndSettle
      expect(selected, isA<GestureMaterialRef>());
    });

    testWidgets('abrir o sheet aquece coldigomGestureMaterialsCacheProvider', (tester) async {
      // após pump + pumpAndSettle:
      expect(container.read(coldigomGestureMaterialsCacheProvider), containsPair(gestureId, isA<GestureMaterial>()));
    });
```

(Os comentários acima dizem *o que* cada teste precisa; o código de montagem é o mesmo dos testes de cifra no arquivo — copie-o.)

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test --dart-define-from-file=dart_defines/plpcg.json test/widget/features/catalog/material_sheet_test.dart`
Expected: os três novos falham.

- [ ] **Step 3: Implementar**

Em `material_sheet.dart`:

`initState` — depois do bloco das cifras (ou dentro do mesmo post-frame), aquecer o cache de gestos:

```dart
    final gestures = widget.group.gestureMaterials;
    if (gestures.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(coldigomCacheWriterProvider).mergeGestures(gestures);
      });
    }
```

(O bloco de cifras hoje usa `ref.read(coldigomCacheWriterProvider).mergeChords(chords)` com um `return` precoce quando não há cifra — ajuste para não pular o de gestos.)

No `build`, `final gestureMaterials = group.gestureMaterials;` e, no `ListView`, **entre** a seção de cifras e a de áudio:

```dart
                  if (gestureMaterials.isNotEmpty) ...[
                    _sectionLabel(l10n.gesturesMaterialSection),
                    for (final gesture in gestureMaterials)
                      _materialTile(
                        material: GestureMaterialRef(gesture),
                        iconColor: AppColors.title,
                        carouselPdfIds: carouselPdfIds,
                      ),
                  ],
```

Sem verificação de existência (as cifras têm `availableChordsProvider` porque há lápides; o documento de gestos 404 é tratado na própria tela com "ainda não tem gestos").

- [ ] **Step 4: Rodar até passar; analyze; commit**

Run: `flutter test --dart-define-from-file=dart_defines/plpcg.json test/widget/features/catalog/ && flutter analyze`

```bash
git add lib/features/catalog/presentation/widgets/material_sheet.dart test/widget/features/catalog/material_sheet_test.dart
git commit -m "feat(gestures): seção Gestos no sheet de materiais

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01DuSVKfiGsabi168JixJLB1"
```

---

### Task 15: Modo foco

**Files:**
- Create: `lib/features/gestures/presentation/widgets/gesture_focus_view.dart`
- Modify: `lib/features/gestures/presentation/pages/gesture_reader_screen.dart` (ligar `onCardTap`, abrir o foco, rolar ao voltar)
- Test: `test/widget/features/gestures/gesture_focus_view_test.dart`, `test/widget/features/gestures/gesture_reader_screen_test.dart` (adicionar caso)

**Interfaces:**
- Consumes: T3 (`FlatGestureCard`, `BlockContext`), T9 (`GestureFigure`, `LyricLineText`), T11 (`GestureDocumentViewState.scrollToCard`), `readerFullscreenProvider`/`toggleReaderFullscreenProvider`, l10n `gestureFocusNext/End/Close`, `gestureContext*`.
- Produces: `Future<int?> showGestureFocus(BuildContext context, {required List<FlatGestureCard> cards, required GestureDictionary dictionary, required int initialIndex, required double fontSize})`; `GestureFocusView({required cards, required dictionary, required initialIndex, required fontSize})`; chaves `gestureFocusPageKey(int index)`, `gestureFocusNextKey = ValueKey('gesture-focus-next')`, `gestureFocusCloseKey = ValueKey('gesture-focus-close')`; `String blockContextLabel(AppLocalizations l10n, BlockContext context)`.

- [ ] **Step 1: Testes (falhando)**

`test/widget/features/gestures/gesture_focus_view_test.dart`:

```dart
import 'dart:io';

import 'package:coldigui/features/gestures/data/providers/gesture_providers.dart';
import 'package:coldigui/features/gestures/domain/usecases/parse_gesture_dictionary.dart';
import 'package:coldigui/features/gestures/domain/usecases/parse_gesture_document.dart';
import 'package:coldigui/features/gestures/domain/utils/flatten_gesture_cards.dart';
import 'package:coldigui/features/gestures/presentation/widgets/gesture_figure.dart';
import 'package:coldigui/features/gestures/presentation/widgets/gesture_focus_view.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_fullscreen_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/gesture_test_png.dart';

String _read(String name) => File('test/fixtures/gestures/$name').readAsStringSync();

Future<Future<int?>> _open(WidgetTester tester, String fixture, int initialIndex) async {
  final cards = flattenGestureCards(parseGestureDocument(_read(fixture)));
  final dict = parseGestureDictionary(_read('dictionary.json'));
  late Future<int?> result;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [gestureFigureProvider.overrideWith((ref, k) async => gestureTestPng())],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  result = showGestureFocus(context, cards: cards, dictionary: dict, initialIndex: initialIndex, fontSize: 18);
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('abre no cartão tocado, com figura grande e próximo gatilho no rodapé', (tester) async {
    await _open(tester, '182_quero_viver.json', 3);

    expect(find.byKey(gestureFocusPageKey(3)), findsOneWidget);
    expect(find.textContaining('comer da árvore da vida.'), findsOneWidget);
    // Próximo cartão (índice 4) começa em "Com".
    expect(find.byKey(gestureFocusNextKey), findsOneWidget);
    expect(find.descendant(of: find.byKey(gestureFocusNextKey), matching: find.text('Com')), findsOneWidget);
    final figure = tester.getSize(find.byType(GestureFigure));
    final screen = tester.getSize(find.byType(GestureFocusView));
    expect(figure.width, greaterThanOrEqualTo(screen.width * 0.6));
    // Dentro do coro: chip CORO.
    expect(find.text('CORO'), findsOneWidget);
  });

  testWidgets('→ avança, ← volta; último mostra "fim"', (tester) async {
    await _open(tester, '182_quero_viver.json', 12);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.byKey(gestureFocusPageKey(13)), findsOneWidget);
    expect(find.text('fim'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.byKey(gestureFocusPageKey(12)), findsOneWidget);
  });

  testWidgets('toque na metade direita avança', (tester) async {
    await _open(tester, '182_quero_viver.json', 0);
    final size = tester.getSize(find.byType(GestureFocusView));
    await tester.tapAt(Offset(size.width * 0.9, size.height * 0.5));
    await tester.pumpAndSettle();
    expect(find.byKey(gestureFocusPageKey(1)), findsOneWidget);
  });

  testWidgets('Esc fecha devolvendo o índice atual', (tester) async {
    final result = await _open(tester, '182_quero_viver.json', 5);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(await result, 6);
    expect(find.byType(GestureFocusView), findsNothing);
  });

  testWidgets('F alterna a tela cheia', (tester) async {
    await _open(tester, '182_quero_viver.json', 0);
    final container = ProviderScope.containerOf(tester.element(find.byType(GestureFocusView)));
    expect(container.read(readerFullscreenProvider), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();
    expect(container.read(readerFullscreenProvider), isTrue);
  });

  testWidgets('chips de contexto aninhados: 3x e ligação', (tester) async {
    await _open(tester, 'sintetico_final_link.json', 1);
    expect(find.text('3x'), findsOneWidget);
    expect(find.text('ligação'), findsOneWidget);
  });
}
```

Em `gesture_reader_screen_test.dart`, adicionar:

```dart
  testWidgets('toque num cartão abre o foco; fechar rola a página até o cartão', (tester) async {
    await _pump(tester, document: () async => parseGestureDocument(_read('182_quero_viver.json')));
    await tester.tap(find.byKey(gestureCardKey(2)));
    await tester.pumpAndSettle();
    expect(find.byType(GestureFocusView), findsOneWidget);
    expect(find.byKey(gestureFocusPageKey(2)), findsOneWidget);

    for (var i = 0; i < 10; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(GestureFocusView), findsNothing);
    expect(find.byKey(gestureCardKey(12)), findsOneWidget);
  });
```

(importe `gesture_focus_view.dart` e `flutter/services.dart` no teste da tela.)

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test --dart-define-from-file=dart_defines/plpcg.json test/widget/features/gestures/gesture_focus_view_test.dart`
Expected: falha de compilação.

- [ ] **Step 3: Implementar o foco**

`lib/features/gestures/presentation/widgets/gesture_focus_view.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../pdf_reader/presentation/providers/reader_fullscreen_provider.dart';
import '../../domain/entities/flat_gesture_card.dart';
import '../../domain/entities/gesture_dictionary.dart';
import '../theme/gesture_reader_palette.dart';
import 'gesture_figure.dart';
import 'lyric_line_text.dart';

Key gestureFocusPageKey(int index) => ValueKey('gesture-focus-page-$index');
const Key gestureFocusNextKey = ValueKey('gesture-focus-next');
const Key gestureFocusCloseKey = ValueKey('gesture-focus-close');

/// Rótulo do chip de contexto de um bloco.
String blockContextLabel(AppLocalizations l10n, BlockContext context) => switch (context) {
  RepeatContext(:final count) => l10n.gestureContextRepeat(count),
  ChorusContext() => l10n.gestureContextChorus,
  FinalContext() => l10n.gestureContextFinal,
  LinkContext() => l10n.gestureContextLink,
};

/// Abre o modo foco sobre a rota atual e devolve o índice do cartão em que o
/// regente estava ao fechar (`null` se fechou sem índice).
///
/// Overlay (`showGeneralDialog`), não rota: o shell, o wakelock e o carousel
/// continuam sendo os de `/gestos`.
Future<int?> showGestureFocus(
  BuildContext context, {
  required List<FlatGestureCard> cards,
  required GestureDictionary dictionary,
  required int initialIndex,
  required double fontSize,
}) {
  return showGeneralDialog<int>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black,
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (_, _, _) => GestureFocusView(
      cards: cards,
      dictionary: dictionary,
      initialIndex: initialIndex,
      fontSize: fontSize,
    ),
  );
}

/// `PageView` sobre os cartões achatados, um por página.
class GestureFocusView extends ConsumerStatefulWidget {
  const GestureFocusView({
    required this.cards,
    required this.dictionary,
    required this.initialIndex,
    required this.fontSize,
    super.key,
  });

  final List<FlatGestureCard> cards;
  final GestureDictionary dictionary;
  final int initialIndex;
  final double fontSize;

  @override
  ConsumerState<GestureFocusView> createState() => _GestureFocusViewState();
}

class _GestureFocusViewState extends ConsumerState<GestureFocusView> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex.clamp(0, widget.cards.length - 1),
  );
  late int _index = _controller.initialPage;
  final _focusNode = FocusNode(debugLabel: 'gestureFocusKeys');

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final next = (_index + delta).clamp(0, widget.cards.length - 1);
    if (next == _index) return;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  void _close() => Navigator.of(context).pop(_index);

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight) {
      _go(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _go(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyF) {
      ref.read(toggleReaderFullscreenProvider).call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cards = widget.cards;
    final next = _index + 1 < cards.length ? cards[_index + 1] : null;
    final nextTrigger = next?.card.lyrics.first.trigger ?? '';

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Material(
        color: GestureReaderPalette.paper,
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  key: gestureFocusCloseKey,
                  tooltip: l10n.gestureFocusClose,
                  icon: const Icon(Icons.close, color: GestureReaderPalette.lyric),
                  onPressed: _close,
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) =>
                          _go(details.localPosition.dx > constraints.maxWidth / 2 ? 1 : -1),
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: cards.length,
                        onPageChanged: (i) => setState(() => _index = i),
                        itemBuilder: (context, i) => _FocusPage(
                          key: gestureFocusPageKey(i),
                          flat: cards[i],
                          dictionary: widget.dictionary,
                          fontSize: widget.fontSize + 6,
                          maxWidth: constraints.maxWidth,
                        ),
                      ),
                    );
                  },
                ),
              ),
              _NextFooter(l10n: l10n, nextTrigger: next == null ? null : nextTrigger),
            ],
          ),
        ),
      ),
    );
  }
}

class _FocusPage extends StatelessWidget {
  const _FocusPage({
    required this.flat,
    required this.dictionary,
    required this.fontSize,
    required this.maxWidth,
    super.key,
  });

  final FlatGestureCard flat;
  final GestureDictionary dictionary;
  final double fontSize;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final side = (maxWidth * 0.6).clamp(120.0, 480.0);
    final entry = dictionary.resolve(flat.card.gestureId);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (flat.contexts.isNotEmpty)
            Wrap(
              spacing: 6,
              children: [
                for (final ctx in flat.contexts)
                  Chip(
                    label: Text(blockContextLabel(l10n, ctx)),
                    labelStyle: const TextStyle(
                      color: GestureReaderPalette.blue,
                      fontWeight: FontWeight.bold,
                    ),
                    side: const BorderSide(color: GestureReaderPalette.blue),
                    backgroundColor: GestureReaderPalette.paper,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          const SizedBox(height: 8),
          GestureFigure(
            entry: entry,
            gestureId: flat.card.gestureId,
            side: side,
            preferGif: true,
          ),
          const SizedBox(height: 16),
          for (final line in flat.card.lyrics)
            Align(
              alignment: Alignment.centerLeft,
              child: LyricLineText(line: line, fontSize: fontSize),
            ),
        ],
      ),
    );
  }
}

/// Rodapé fixo: `próximo:` + gatilho seguinte em vermelho, ou `fim`.
class _NextFooter extends StatelessWidget {
  const _NextFooter({required this.l10n, required this.nextTrigger});

  final AppLocalizations l10n;

  /// `null` no último cartão.
  final String? nextTrigger;

  @override
  Widget build(BuildContext context) {
    final trigger = nextTrigger;
    return Container(
      key: gestureFocusNextKey,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: GestureReaderPalette.instructionBorder)),
      ),
      child: trigger == null
          ? Text(
              l10n.gestureFocusEnd,
              style: const TextStyle(color: GestureReaderPalette.freeText, fontSize: 16),
            )
          : Row(
              children: [
                Text(
                  '${l10n.gestureFocusNext} ',
                  style: const TextStyle(color: GestureReaderPalette.freeText, fontSize: 16),
                ),
                Expanded(
                  child: Text(
                    trigger,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: GestureReaderPalette.trigger,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
```

- [ ] **Step 4: Ligar na tela**

Em `gesture_reader_screen.dart`: importar `flatten_gesture_cards.dart` e `gesture_focus_view.dart`; no `data:` do `when`, calcular `final flat = flattenGestureCards(document);` e passar ao `GestureDocumentView`:

```dart
                              onCardTap: flat.isEmpty
                                  ? null
                                  : (index) => _openFocus(flat, dictionary, index, fontSize),
```

e o método no `State`:

```dart
  Future<void> _openFocus(
    List<FlatGestureCard> cards,
    GestureDictionary dictionary,
    int index,
    double fontSize,
  ) async {
    final result = await showGestureFocus(
      context,
      cards: cards,
      dictionary: dictionary,
      initialIndex: index,
      fontSize: fontSize,
    );
    if (!mounted || result == null) return;
    await _documentViewKey.currentState?.scrollToCard(result);
    _keyboardFocusNode.requestFocus();
  }
```

(import `flat_gesture_card.dart` para o tipo.) Remova o comentário "Task 15 liga o modo foco aqui".

- [ ] **Step 5: Rodar até passar; analyze; commit**

Run: `flutter test --dart-define-from-file=dart_defines/plpcg.json test/widget/features/gestures/ && flutter analyze`

```bash
git add lib/features/gestures/presentation test/widget/features/gestures
git commit -m "feat(gestures): modo foco com PageView, chips de contexto, próximo gatilho e retorno ao cartão

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01DuSVKfiGsabi168JixJLB1"
```

---

### Task 16: Documentação

**Files:**
- Modify: `docs/features/FEATURE_INDEX.md` (linha nova na tabela "Status por feature", após `chords`)
- Create: `docs/use-cases/UC-17-leitor-gestos.md`
- Modify: `TODO.md` (item 3 "Gestos em Gravura: ferramenta visual de leitura" → marcado como feito, com link para o UC)

- [ ] **Step 1: `FEATURE_INDEX.md`** — após a linha de `chords`:

```markdown
| `gestures` | UC-17 | Média | **Concluído** (leitor de gestos set/2026) | Rota `/gestos` ([GestureReaderScreen]); documento JSON `coldigom.gestures/1` ([parseGestureDocument]) + dicionário com ETag ([gestureDictionaryProvider]); cache Isar ([GestureDocumentCache], [GestureDictionaryCache]) + figuras em store próprio ([GestureFigureStorePort]); blocos por `Stack` ([BracedChildren]); modo foco ([GestureFocusView]); [GestureMaterialRef] no catálogo; spec [leitor de gestos](../superpowers/specs/2026-09-11-leitor-gestos-design.md) |
```

- [ ] **Step 2: `UC-17-leitor-gestos.md`**

```markdown
# UC-17 — Leitor de Gestos CIAs

**Criado em:** 2026-09-11
**Status:** Implementado (set/2026)
**Complementa:** UC-11 (leitor PDF), leitor de cifras, [FEATURE_INDEX.md](../features/FEATURE_INDEX.md)
**Spec:** [2026-09-11-leitor-gestos-design.md](../superpowers/specs/2026-09-11-leitor-gestos-design.md)

## Objetivo

O regente ou instrutor de CIA abre, no celular ou tablet, o documento de gestos de um louvor: figura do gesto à esquerda, letra à direita com o **gatilho em vermelho** e a **leitura em preto**; blocos de repetição, coro, ligação e final desenhados com chaves como no PDF. Um toque num cartão abre o **modo foco** (um gesto por tela, próximo gatilho no rodapé).

## Fluxo principal

1. No sheet de materiais de um louvor Coldigom aparece a seção **Gestos** quando o Worker publica um material `type: gestures`.
2. Toque → `/gestos?pdfId=…` (mesmo espaço de ids do PDF; entra na lista ativa e no carousel).
3. A tela busca o documento (`assets/praises/{pid}/{mid}.gestures`) e o dicionário (`GET /api/gestures/dictionary`, `If-None-Match`), ambos cache-first no Isar; as figuras dos gestos do louvor são pré-buscadas para o store local.
4. `A-`/`A+` (ou `Ctrl+↑/↓`) mudam o corpo da letra (14–28, persistido); `F` tela cheia; `Ctrl+←/→` trocam de louvor pelo carousel.
5. Toque num cartão → modo foco: `←`/`→`, swipe ou toque nas metades; `Esc` fecha e a página rola até o cartão.

## Fluxos alternativos

- Documento 404 → "Este louvor ainda não tem gestos" (marcador negativo no cache).
- Falha de rede sem cache → "indisponível · tentar de novo".
- `gestureId` fora do dicionário → placeholder com o id; item de tipo desconhecido → linha de texto; `schema` com major > 1 → banner e renderiza.
- Modo avião após um primeiro acesso online → documento, dicionário e figuras vêm do cache.

## Fora de escopo (v1)

Duas colunas em tablet paisagem; gestos nos pacotes ZIP offline; GIF fora do foco; edição; busca por gesto.
```

- [ ] **Step 3: `TODO.md`** — localize o item 3 ("Gestos em Gravura: ferramenta visual de leitura") e marque como concluído com `→ UC-17 (set/2026)`.

- [ ] **Step 4: Verificação final e commit**

Run: `flutter analyze && flutter test --dart-define-from-file=dart_defines/plpcg.json`
Expected: analyze limpo, suíte inteira verde. Cole o resumo (`All tests passed!` + contagem) no relatório.

```bash
git add docs/features/FEATURE_INDEX.md docs/use-cases/UC-17-leitor-gestos.md TODO.md
git commit -m "docs(gestures): FEATURE_INDEX, UC-17 e TODO

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01DuSVKfiGsabi168JixJLB1"
```

---

## Ordem e dependências

```
T1 → T2 → T3 → T4 → T5 → T6 → T7 → T8 → T9 → T10 → T11 → T12 → T13 → T14 → T15 → T16
```

Tudo sequencial: cada tarefa consome nomes da anterior. T2 e T3 só dependem de T1 e poderiam rodar em paralelo; T5/T6/T7 só dependem de T1–T4 e também. O resto é linear.

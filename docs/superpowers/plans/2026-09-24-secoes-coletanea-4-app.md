# Seções da Coletânea — Plano 4: app coldigui

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** o app deixa de oferecer, gravar e mostrar a «Categoria» do praise. A seção da Coletânea passa a ser só a subtag `Coletânea · <seção>`, que já aparece na seção Tags, na ficha e na busca sem mudar código (spec §4.3). Links (`?category=`) e filtros gravados (`categories`, pref v2) antigos **não se perdem**: cada valor vira a subtag correspondente e é somado às tags.

**Architecture:** uma função pura, `legacyCategoryToTags`, guarda a tabela fixa do spec §4.2 (em `lib/features/catalog/domain/utils/legacy_category_tags.dart`). `CatalogFilterState` perde `categories`. Ela usa a função em dois pontos de leitura:
- `fromUrl(category:)`: o param continua a ser lido, e o router e as telas continuam a repassá-lo;
- `fromPersistedJson`: aceita as versões 2 e 3 e converte a chave `categories`.

A gravação passa a ser a v3, sem `categories`. Os construtores de URL deixam de escrever `category`. As telas forçam a regravação da URL quando ela ainda traz o param legado. Na ficha do material sai a linha «Categoria», e `hasAnyField` deixa de contar a categoria. Nas contribuições, `MetadataField.category` sai do enum. Por fim saem as três chaves l10n.

**Tech Stack:** Flutter 3 (Dart ≥ 3.13), Riverpod 3 (`Notifier`), go_router, `shared_preferences`, `flutter_test`, `flutter gen-l10n`.

**Spec:** `docs/superpowers/specs/2026-09-24-secoes-coletanea-subtags-design.md`. Este plano cobre só o §4 (app) e a parte coldigui do §8. A fase 3 (§6.5) **não entra**: `category` continua nos DTOs, em `ColdigomPraiseMetadata`, no cache Isar e em `ColdigomPraisesQuery`.

**Worktree/branch:** coldigui `.claude/worktrees/secoes-coletanea`, `feat/secoes-coletanea-subtags`. A branch sai de `web/integration` @ `b81deb19`. Todos os paths abaixo são relativos à raiz do worktree.

## Global Constraints

- **Ordem de deploy (spec §6):** este app só vai para produção depois que o script de dados do coldigom tiver rodado com `--execute` (passo 3). Sem as subtags no catálogo, um link antigo convertido em `Coletânea · Clamor` filtraria para zero resultados. Nada aqui depende de rede: todos os testes usam fixtures.
- **Fica até a fase 3 (não tocar):**
  - `category` em `ColdigomCatalogPraiseDto`, `PraiseDetailDto` e `PraiseSummaryDto`;
  - `ColdigomPraiseMetadata.category` (o campo fica; só sai de `hasAnyField`, Task 4);
  - `ColdigomPraiseCache.category` (Isar, sem `build_runner`);
  - o mapper e o adapter;
  - `ColdigomPraisesQuery.categories`;
  - o parâmetro `category` de `catalogGroup` em `test/helpers/coldigom_catalog_test_helpers.dart`;
  - os `..category = ''` das fixtures.
- **O param `category` continua a ser lido:** ficam `UrlSyncParams.category`, `app_router.dart` (`initialCategory: params[UrlSyncParams.category]`, linhas 139 e 200), `HomeScreen.initialCategory`, `LibraryScreen.initialCategory` e `CatalogFiltersNotifier.hydrateFromUrl(category:)`. Só a **escrita** sai (Task 3).
- **Tag:** o separador é a constante existente `catalogTagHierarchySeparator` (`' · '`, U+00B7 entre espaços), definida em `lib/features/catalog/domain/utils/catalog_tag_hierarchy.dart`. Nos testes, a string literal `'Coletânea · Clamor'` usa esse mesmo caractere, como os testes existentes de `'PES · 9.2026'`.
- **WIP não commitado no checkout principal (`web/integration`).** O diretório `/Volumes/SSD 2TB SD/dev/coldigui` tem mudanças locais, fora desta branch, com «subtags sob demanda»:
  - `catalogTagParent` e `catalogTagsRefined`;
  - a seção «Subtags», com a chave `coldigomFilterSubtags`;
  - `toggleTag`, que desmarca também as filhas.

  Elas mexem em `catalog_filter_sections.dart`, `catalog_filters_provider.dart`, `matches_catalog_filters.dart`, `catalog_tag_hierarchy.dart`, nos testes desses arquivos e nos arb e gerados. **Não copiar esse WIP para cá.** Quem fizer o merge em `web/integration` vai ter conflitos nesses arquivos, e em todos a resolução é manter as duas mudanças. O teste de «pref v2 aparece como subtag marcada» (Task 2) vale com e sem o WIP: subtag marcada sem o pai continua visível.
- **l10n:** editar `lib/l10n/app_pt.arb` e `app_en.arb`, rodar `flutter gen-l10n` e commitar os gerados (`lib/l10n/app_localizations*.dart`).
- **Testes de widget:** para caber conteúdo, usar `tester.view.physicalSize` e `tester.ensureVisible`, com `addTearDown(tester.view.resetPhysicalSize)`. Nunca encolher a UI (densidade ou fonte) para o teste passar.
- **Formato:** cada implementador roda `dart format` nos arquivos que tocou. Revisores conferem com `dart format --output=none --set-exit-if-changed <arquivos>`.
- **Git:** comandos simples dentro do worktree (`git add …`, `git commit …`). O guard recusa `cd <path> && git …` e `git -C …`. É um commit por tarefa, em português, terminando com o trailer exato:
  `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`
- Nada de push, merge ou deploy sem pedido do dono.
- **Nunca afirmar que testes passam sem os ter rodado** e visto a saída. Se um passo «espera FAIL» e o teste passa, pare e investigue antes de seguir.
- Se `.dart_tool/` não existir no worktree, rode `flutter pub get` antes do primeiro `flutter test`.

## Review Focus

1. **Pref v2 migrada, não descartada.** Hoje `fromPersistedJson` rejeita qualquer `v` diferente de `persistedVersion` (`json['v'] != persistedVersion` → `null`). O provider então **apaga** a pref (`catalog_filters_provider.dart:40-46`). Subir para 3 sem mais nada apagaria o filtro salvo de todos os usuários. A leitura aceita `{2, 3}`. Testes: `catalog_filter_state_test` e `catalog_filters_provider_test` (Task 2).
2. **Vírgula do CSV.** Na URL, «Morte, Ressureição e Salvação» chega partido em «Morte» e «Ressureição e Salvação». Os dois pedaços, e «Morte» sozinho, levam à tag de Morte. Na pref, o valor chega inteiro. Testes: `legacy_category_tags_test` (Task 1) e `fromUrl` (Task 2).
3. **`?category=` preso na URL.** O normalizador `build*LocationFromUri` passa a ignorar `category`. Sem outra proteção, desmarcar tudo daria um alvo igual à URL normalizada (`/`). O `?category=Clamor` ficaria na barra, e recarregar reaplicaria o filtro. As telas forçam a regravação quando o param legado está presente. Teste: `filters_url_sync_across_tabs_test` (Task 3).
4. **Bloco de metadados vazio.** `hasAnyField` conta `category`. Sem a linha na ficha, um praise que só tem categoria desenharia uma caixa dourada vazia. `category` sai de `hasAnyField` (Task 4, `coldigom_praise_metadata_test`).
5. **Contribuição antiga com `field: category`.** O detalhe procura o campo por nome em `MetadataField.values`; nome desconhecido dá `null`, e a linha não aparece. O detalhe tem de abrir sem exceção. Teste novo: `contribution_detail_screen_test` (Task 5).

### Decisões tomadas ao planejar

- **D1. Nada de regravar a pref v2 na leitura.** O estado lido de uma v2 fica em memória, e o próximo toggle grava a v3. Isso evita escrever em prefs dentro do `build()` do notifier. Uma v2 que só tinha `categories: ['Avulsos']` vira estado vazio, que é inofensivo.
- **D2. Link só com categoria descartada (`?category=Avulsos`).** A conversão resulta vazia, e `hydrateFromUrl` já trata «URL sem filtro» como no-op (mantém o gravado). O comportamento é o mesmo de um link sem params. O spec (§7) só exige «descarta em silêncio», e este é o comportamento mais simples. O teste fica em `catalog_filters_provider_test`.
- **D3. A URL não é regravada ao abrir.** A Task 3 só garante que o **próximo** sync tire o `?category=`. Regravar na montagem obrigaria a ler `homeSearchUrlSyncQueryProvider` antes de o debounce de 500 ms propagar `pesquisa`, o que apagaria `?pesquisa=` por um instante. Isso não vale o risco. Na homologação (§6.4), o link `?category=Clamor` abre filtrado; a URL muda na primeira interação.
- **D4. `persistedVersion` vai para 3, e a leitura de 2 e 3 converte `categories`.** É o texto do spec. Uma v3 com `categories` (não emitida por nenhuma versão) também converte, sem custo.

## Mapa de arquivos

| Tarefa | Cria | Modifica |
|---|---|---|
| 1 Conversão legada | `lib/features/catalog/domain/utils/legacy_category_tags.dart`, `test/unit/features/catalog/legacy_category_tags_test.dart` | — |
| 2 Estado sem categoria | — | `catalog_filter_state.dart`, `catalog_filter_options.dart`, `matches_catalog_filters.dart`, `catalog_filters_provider.dart`, `catalog_filter_sections.dart`, `home_screen.dart` (1 linha + doc), `library_screen.dart` (1 linha), `storage_keys.dart` (doc), testes de state/provider/options/matches/sections |
| 3 URL | — | `home_url_builder.dart`, `library_url_builder.dart`, `url_sync_params.dart` (doc), `home_screen.dart`, `library_screen.dart`, `home_url_builder_test.dart`, `library_url_builder_test.dart`, `filters_url_sync_across_tabs_test.dart` |
| 4 Ficha | `test/unit/features/coldigom/coldigom_praise_metadata_test.dart` | `material_sheet.dart`, `coldigom_praise_metadata.dart`, `material_sheet_test.dart` |
| 5 Contribuições | `test/widget/features/contributions/contribution_detail_screen_test.dart` | `contribution_kind.dart`, `contribution_labels.dart`, `contribution_context_fields.dart`, `contribution_draft_test.dart`, `contribute_screen_test.dart` |
| 6 l10n + varredura | — | `app_pt.arb`, `app_en.arb`, `app_localizations*.dart` (gerados), `louvor_classification.dart` (doc) |

---

### Task 1: conversão das categorias antigas em subtags (`legacyCategoryToTags`)

**Files:**
- Create: `lib/features/catalog/domain/utils/legacy_category_tags.dart`
- Create: `test/unit/features/catalog/legacy_category_tags_test.dart`

**Interfaces:**
```dart
/// Tag raiz das seções da Coletânea no coldigom.
const String coletaneaRootTag = 'Coletânea';

/// Valores antigos de `praise.category` (inteiros ou pedaços do CSV da URL)
/// → subtags `Coletânea · <seção>`; o resto é descartado.
Set<String> legacyCategoryToTags(Iterable<String> values);
```

- [ ] **Step 1: escrever o teste que falha**

`test/unit/features/catalog/legacy_category_tags_test.dart`:

```dart
import 'package:coldigui/features/catalog/domain/utils/catalog_tag_hierarchy.dart';
import 'package:coldigui/features/catalog/domain/utils/legacy_category_tags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String section(String name) => 'Coletânea · $name';
  final morte = section('Morte Ressurreição e Salvação');
  final santificacao = section(
    'Santificação e Derramamento do Espírito Santo',
  );

  test('as 11 seções de nome igual viram Coletânea · <nome>', () {
    const sameName = [
      'Clamor',
      'Consolo e Encorajamento',
      'Contra-Capa',
      'Corinhos',
      'Crianças e Adolescentes',
      'Dedicação',
      'Grupo de Louvor',
      'Invocação e Comunhão',
      'Louvor',
      'Salmos de Louvor',
      'Volta de Jesus e Eternidade',
    ];
    for (final name in sameName) {
      expect(legacyCategoryToTags([name]), {section(name)}, reason: name);
    }
  });

  test('o rótulo usa a raiz e o separador da hierarquia de tags', () {
    expect(coletaneaRootTag, 'Coletânea');
    expect(
      legacyCategoryToTags(['Clamor']).single,
      '$coletaneaRootTag${catalogTagHierarchySeparator}Clamor',
    );
  });

  test('Morte: as duas grafias inteiras (pref gravada)', () {
    expect(legacyCategoryToTags(['Morte, Ressureição e Salvação']), {morte});
    expect(legacyCategoryToTags(['Morte, Ressurreição e Salvação']), {morte});
  });

  test('Morte: pedaços partidos pela vírgula do CSV da URL', () {
    expect(legacyCategoryToTags(['Morte', 'Ressureição e Salvação']), {
      morte,
    });
    expect(legacyCategoryToTags(['Morte', 'Ressurreição e Salvação']), {
      morte,
    });
    expect(legacyCategoryToTags(['Ressureição e Salvação']), {morte});
    expect(legacyCategoryToTags(['Morte']), {morte});
  });

  test('Santificação: as duas grafias', () {
    expect(legacyCategoryToTags(['Santificação e Derramamento']), {
      santificacao,
    });
    expect(
      legacyCategoryToTags(['Santificação e Derramamento do Espírito Santo']),
      {santificacao},
    );
  });

  test('coleções e valores desconhecidos são descartados', () {
    expect(
      legacyCategoryToTags([
        'Avulso',
        'Avulsos',
        'Avulso Cias',
        'Avulsos das Senhoras',
        'Adoração',
        '',
        '   ',
      ]),
      isEmpty,
    );
  });

  test('apara espaços, junta repetidos e mantém só as seções', () {
    expect(
      legacyCategoryToTags([' Clamor ', 'Avulsos', 'Clamor', 'Louvor']),
      {section('Clamor'), section('Louvor')},
    );
  });

  test('sem valores → vazio', () {
    expect(legacyCategoryToTags(const []), isEmpty);
  });
}
```

- [ ] **Step 2: rodar e ver falhar**

Run: `flutter test test/unit/features/catalog/legacy_category_tags_test.dart`
Expected: FAIL na compilação (`legacy_category_tags.dart` não existe).

- [ ] **Step 3: implementar**

`lib/features/catalog/domain/utils/legacy_category_tags.dart`:

```dart
import 'catalog_tag_hierarchy.dart';

/// Tag raiz das seções da Coletânea no coldigom (spec seções-coletânea §2.1).
const coletaneaRootTag = 'Coletânea';

const _morte = 'Morte Ressurreição e Salvação';
const _santificacao = 'Santificação e Derramamento do Espírito Santo';

/// `praise.category` antigo → nome da subtag de [coletaneaRootTag] (spec
/// seções-coletânea §4.2). A tabela só existe para ler links e filtros
/// gravados antes do fim da categoria; **não** acompanha mudanças futuras de
/// tags.
///
/// «Morte, Ressu… e Salvação» tem vírgula: na URL chega partido pelo CSV
/// (`CatalogFilterState.parseCsv`) em «Morte» e «Ressu… e Salvação», e cada
/// pedaço também leva à seção.
const _legacySections = <String, String>{
  'Clamor': 'Clamor',
  'Consolo e Encorajamento': 'Consolo e Encorajamento',
  'Contra-Capa': 'Contra-Capa',
  'Corinhos': 'Corinhos',
  'Crianças e Adolescentes': 'Crianças e Adolescentes',
  'Dedicação': 'Dedicação',
  'Grupo de Louvor': 'Grupo de Louvor',
  'Invocação e Comunhão': 'Invocação e Comunhão',
  'Louvor': 'Louvor',
  'Salmos de Louvor': 'Salmos de Louvor',
  'Volta de Jesus e Eternidade': 'Volta de Jesus e Eternidade',
  'Morte, Ressureição e Salvação': _morte,
  'Morte, Ressurreição e Salvação': _morte,
  'Morte': _morte,
  'Ressureição e Salvação': _morte,
  'Ressurreição e Salvação': _morte,
  'Santificação e Derramamento': _santificacao,
  'Santificação e Derramamento do Espírito Santo': _santificacao,
};

/// Converte valores antigos de categoria (inteiros, da pref, ou pedaços do
/// CSV da URL) nas subtags `Coletânea · <seção>`.
///
/// Coleções (Avulso, Avulsos, Avulso Cias, Avulsos das Senhoras) e qualquer
/// valor desconhecido são descartados em silêncio (spec §7).
Set<String> legacyCategoryToTags(Iterable<String> values) {
  final tags = <String>{};
  for (final raw in values) {
    final section = _legacySections[raw.trim()];
    if (section != null) {
      tags.add('$coletaneaRootTag$catalogTagHierarchySeparator$section');
    }
  }
  return tags;
}
```

- [ ] **Step 4: rodar e ver passar**

Run: `flutter test test/unit/features/catalog/legacy_category_tags_test.dart`
Expected: PASS (8 testes).

- [ ] **Step 5: formatar e analisar**

```bash
dart format lib/features/catalog/domain/utils/legacy_category_tags.dart test/unit/features/catalog/legacy_category_tags_test.dart
flutter analyze lib/features/catalog/domain/utils/legacy_category_tags.dart test/unit/features/catalog/legacy_category_tags_test.dart
```
Expected: `No issues found!`

- [ ] **Step 6: commit**

```bash
git add lib/features/catalog/domain/utils/legacy_category_tags.dart test/unit/features/catalog/legacy_category_tags_test.dart
git commit -m "feat(catalogo): conversão das categorias antigas em subtags da Coletânea" -m "Tabela fixa do spec seções-coletânea §4.2, só para ler links e filtros gravados antigos. Reconhece os pedaços de «Morte, Ressu… e Salvação» partidos pelo CSV da URL." -m "Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: filtros sem categoria; links e prefs antigos viram subtags (v3)

**Files:**
- Modify: `lib/features/catalog/domain/entities/catalog_filter_state.dart` (arquivo inteiro, 1-160)
- Modify: `lib/features/catalog/domain/entities/catalog_filter_options.dart:29-44,49,58,91`
- Modify: `lib/features/catalog/domain/usecases/matches_catalog_filters.dart:8-15,27-30`
- Modify: `lib/features/catalog/presentation/providers/catalog_filters_provider.dart:22-23,80-81`
- Modify: `lib/features/catalog/presentation/widgets/catalog_filter_sections.dart:11-12,42-47`
- Modify: `lib/features/catalog/presentation/pages/home_screen.dart:26-27,51-52,194` (a linha `category: filters.categoryUrlValue,` e os docs)
- Modify: `lib/features/library/presentation/pages/library_screen.dart:172` (a linha `category: filters.categoryUrlValue,`)
- Modify: `lib/core/constants/storage_keys.dart:30-31` (doc)
- Test: `test/unit/features/catalog/catalog_filter_state_test.dart`, `catalog_filters_provider_test.dart`, `catalog_filter_options_test.dart`, `matches_catalog_filters_test.dart`, `test/widget/features/catalog/catalog_filter_sections_test.dart`

**Interfaces (depois da tarefa):**
```dart
class CatalogFilterState {
  const CatalogFilterState({
    Set<String> tonalities = const {},
    Set<String> rhythms = const {},
    Set<String> tags = const {},
    Set<String> materialKindIds = const {},
  });
  factory CatalogFilterState.fromUrl({
    String? tonality,
    String? rhythm,
    String? category, // legado: convertido em tags
    String? tags,
    String? materialKinds,
  });
  static const persistedVersion = 3;
  Map<String, Object> toPersistedJson(); // sem 'categories'
  static CatalogFilterState? fromPersistedJson(Object? json); // aceita v 2 e 3
  CatalogFilterState copyWith({
    Set<String>? tonalities,
    Set<String>? rhythms,
    Set<String>? tags,
    Set<String>? materialKindIds,
  });
  // Saem: categories, categoryUrlValue, copyWith(categories:).
}
// CatalogFilterOptions: sai `categories`.
// CatalogFiltersNotifier: sai `toggleCategory`; `hydrateFromUrl(category:)` fica.
```

**Por que home/library entram aqui:** remover `categoryUrlValue` quebra a compilação das duas telas (`category: filters.categoryUrlValue,`). Nesta tarefa só essa linha sai. Os construtores ainda aceitam `category`, e o parâmetro sai na Task 3.

- [ ] **Step 1: atualizar os testes (falham)**

**1a.** `test/unit/features/catalog/catalog_filter_state_test.dart`: substituir o arquivo inteiro por:

```dart
import 'dart:convert';

import 'package:coldigui/features/catalog/domain/entities/catalog_filter_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty não filtra; qualquer conjunto não vazio filtra', () {
    expect(CatalogFilterState.empty.isEmpty, isTrue);
    expect(const CatalogFilterState(tags: {'PES'}).isEmpty, isFalse);
    expect(const CatalogFilterState(materialKindIds: {'k1'}).isEmpty, isFalse);
  });

  test('igualdade por conteúdo dos quatro conjuntos', () {
    expect(
      const CatalogFilterState(tonalities: {'Dm', 'G'}),
      const CatalogFilterState(tonalities: {'G', 'Dm'}),
    );
    expect(
      const CatalogFilterState(tonalities: {'Dm'}),
      isNot(const CatalogFilterState(rhythms: {'Dm'})),
    );
  });

  test('getters de URL: CSV ordenado; null quando vazio', () {
    const state = CatalogFilterState(
      tonalities: {'G', 'Dm'},
      tags: {'PES · 9.2026', 'Avulsos'},
      materialKindIds: {'k2', 'k1'},
    );

    expect(state.tonalityUrlValue, 'Dm,G');
    expect(state.tagsUrlValue, 'Avulsos,PES · 9.2026');
    expect(state.materialKindsUrlValue, 'k1,k2');
    expect(state.rhythmUrlValue, isNull);
  });

  test('fromUrl/parseCsv aparam espaços e ignoram vazios', () {
    final state = CatalogFilterState.fromUrl(
      tonality: ' Dm , ,G',
      tags: '',
      materialKinds: 'k1',
    );

    expect(state.tonalities, {'Dm', 'G'});
    expect(state.tags, isEmpty);
    expect(state.materialKindIds, {'k1'});
  });

  test('fromUrl: category legado vira subtag de Coletânea somada às tags', () {
    // «Morte, Ressureição e Salvação» chega partido pela vírgula do CSV.
    final state = CatalogFilterState.fromUrl(
      category: 'Clamor,Morte, Ressureição e Salvação,Avulsos',
      tags: 'PES',
    );

    expect(state.tags, {
      'PES',
      'Coletânea · Clamor',
      'Coletânea · Morte Ressurreição e Salvação',
    });
    expect(state.tonalities, isEmpty);
  });

  test('fromUrl: só categorias sem seção → estado vazio', () {
    expect(
      CatalogFilterState.fromUrl(category: 'Avulsos,Avulso Cias').isEmpty,
      isTrue,
    );
  });

  test('formato gravado v3: ida e volta, sem categories; antigo e lixo → null', () {
    const state = CatalogFilterState(
      tonalities: {'Dm'},
      rhythms: {'Fox'},
      tags: {'PES'},
      materialKindIds: {'k1'},
    );

    final json =
        jsonDecode(jsonEncode(state.toPersistedJson())) as Map<String, dynamic>;
    expect(CatalogFilterState.persistedVersion, 3);
    expect(json['v'], 3);
    expect(json, isNot(contains('categories')));
    expect(CatalogFilterState.fromPersistedJson(json), state);
    expect(
      CatalogFilterState.fromPersistedJson({
        'materials': ['Partitura'],
        'arranjos': <String>[],
      }),
      isNull,
    );
    expect(
      CatalogFilterState.fromPersistedJson({
        'v': 1,
        'tags': ['PES'],
      }),
      isNull,
    );
    expect(CatalogFilterState.fromPersistedJson('x'), isNull);
    expect(CatalogFilterState.fromPersistedJson(null), isNull);
  });

  test('v2 gravado: categories converte para tags e nada mais se perde', () {
    final state = CatalogFilterState.fromPersistedJson(
      jsonDecode(
        jsonEncode({
          'v': 2,
          'tonalities': ['Dm'],
          'rhythms': <String>[],
          'categories': [
            'Clamor',
            'Morte, Ressurreição e Salvação',
            'Avulsos',
          ],
          'tags': ['PES'],
          'materialKinds': ['k1'],
        }),
      ),
    );

    expect(
      state,
      const CatalogFilterState(
        tonalities: {'Dm'},
        tags: {
          'PES',
          'Coletânea · Clamor',
          'Coletânea · Morte Ressurreição e Salvação',
        },
        materialKindIds: {'k1'},
      ),
    );
  });

  test('v3 com categories também converte', () {
    expect(
      CatalogFilterState.fromPersistedJson({
        'v': 3,
        'categories': ['Louvor'],
      }),
      const CatalogFilterState(tags: {'Coletânea · Louvor'}),
    );
  });

  test('activeCount soma os valores escolhidos de todos os filtros', () {
    expect(CatalogFilterState.empty.activeCount, 0);
    expect(
      const CatalogFilterState(
        tonalities: {'Dm', 'G'},
        tags: {'PES'},
        materialKindIds: {'k1'},
      ).activeCount,
      4,
    );
  });
}
```

**1b.** `test/unit/features/catalog/catalog_filters_provider_test.dart`:

Trocar o teste `'toggles gravam o formato v2 e um container novo relê'` (linhas 35-60) por:

```dart
  test('toggles gravam o formato v3 e um container novo relê', () async {
    await setUpPrefs();
    final first = createContainer();
    first.read(catalogFiltersProvider.notifier)
      ..toggleTonality('Dm')
      ..toggleRhythm('Fox')
      ..toggleTag('PES')
      ..toggleMaterialKind('k1');

    final raw = jsonDecode(
      prefs.getString(StorageKeys.catalogFilters)!,
    ) as Map<String, dynamic>;
    expect(raw['v'], 3);
    expect(raw, isNot(contains('categories')));
    expect(raw['tags'], ['PES']);
    expect(
      createContainer().read(catalogFiltersProvider),
      const CatalogFilterState(
        tonalities: {'Dm'},
        rhythms: {'Fox'},
        tags: {'PES'},
        materialKindIds: {'k1'},
      ),
    );
  });

  test(
    'pref v2 com categories é migrada para tags, não descartada nem apagada',
    () async {
      await setUpPrefs({
        StorageKeys.catalogFilters: jsonEncode({
          'v': 2,
          'tonalities': ['Dm'],
          'rhythms': <String>[],
          'categories': ['Clamor', 'Avulsos'],
          'tags': ['PES'],
          'materialKinds': <String>[],
        }),
      });

      final container = createContainer();

      expect(
        container.read(catalogFiltersProvider),
        const CatalogFilterState(
          tonalities: {'Dm'},
          tags: {'PES', 'Coletânea · Clamor'},
        ),
      );
      await pumpEventQueue();
      expect(prefs.getString(StorageKeys.catalogFilters), isNotNull);

      // O próximo toggle grava a v3, já sem categories.
      container.read(catalogFiltersProvider.notifier).toggleRhythm('Fox');
      final raw = jsonDecode(
        prefs.getString(StorageKeys.catalogFilters)!,
      ) as Map<String, dynamic>;
      expect(raw['v'], 3);
      expect(raw, isNot(contains('categories')));
      expect(raw['tags'], ['Coletânea · Clamor', 'PES']);
    },
  );
```

No fim de `main()`, antes do `}` final, acrescentar:

```dart
  test('hydrateFromUrl converte category legado em subtag', () async {
    await setUpPrefs();
    final container = createContainer();

    container
        .read(catalogFiltersProvider.notifier)
        .hydrateFromUrl(category: 'Clamor', tonality: 'Dm');

    expect(
      container.read(catalogFiltersProvider),
      const CatalogFilterState(
        tonalities: {'Dm'},
        tags: {'Coletânea · Clamor'},
      ),
    );
  });

  test(
    'link só com categoria descartada (Avulsos) mantém o gravado (D2)',
    () async {
      await setUpPrefs();
      final container = createContainer();
      final notifier = container.read(catalogFiltersProvider.notifier)
        ..toggleTag('PES');

      notifier.hydrateFromUrl(category: 'Avulsos');

      expect(
        container.read(catalogFiltersProvider),
        const CatalogFilterState(tags: {'PES'}),
      );
    },
  );
```

**1c.** `test/unit/features/catalog/catalog_filter_options_test.dart`, linhas 63-70: trocar

```dart
    test(
      'tom, ritmo e categoria: valores com praise, aparados, sem vazios',
      () {
        expect(options.tonalities, ['Dm', 'G']);
        expect(options.rhythms, ['Fox']);
        expect(options.categories, ['Adoração', 'Clamor']);
      },
    );
```

por

```dart
    test('tom e ritmo: valores com praise, aparados, sem vazios', () {
      expect(options.tonalities, ['Dm', 'G']);
      expect(options.rhythms, ['Fox']);
    });

    test('a categoria do praise não vira opção em lugar nenhum', () {
      expect(options.tags, isNot(contains('Clamor')));
      expect(options.tags, isNot(contains('Adoração')));
    });
```

Os `category:` das fixtures (linhas 38 e 46) **ficam**: provam que a categoria é ignorada.

**1d.** `test/unit/features/catalog/matches_catalog_filters_test.dart`, linhas 49-60: trocar o teste `'ritmo e categoria'` por:

```dart
  test('ritmo', () {
    expect(matches(hino, const CatalogFilterState(rhythms: {'Fox'})), isTrue);
    expect(matches(coro, const CatalogFilterState(rhythms: {'Fox'})), isFalse);
  });

  test('a categoria do praise não filtra; link antigo acha a seção pela subtag', () {
    final secao = catalogGroup(
      praiseId: 'p4',
      name: 'Seção',
      category: 'Clamor',
      tags: const ['Coletânea · Clamor'],
    );
    final soCategoria = catalogGroup(
      praiseId: 'p5',
      name: 'Só categoria',
      category: 'Clamor',
    );
    final fromLink = CatalogFilterState.fromUrl(category: 'Clamor');

    expect(matches(secao, fromLink), isTrue);
    expect(matches(soCategoria, fromLink), isFalse);
    expect(
      matches(secao, const CatalogFilterState(tags: {'Coletânea'})),
      isTrue,
    );
  });
```

**1e.** `test/widget/features/catalog/catalog_filter_sections_test.dart`: trocar o primeiro `testWidgets` (linhas 81-104) por:

```dart
  testWidgets('secções e chips saem do índice local, com o pai das tags', (
    tester,
  ) async {
    await pump(tester);

    for (final label in [
      'Tom',
      'Ritmo',
      'Tags',
      'Materiais',
      'Dm',
      'G',
      'Fox',
      'PES',
      'PES · 9.2026',
      'CIAs',
      'Grade',
      'Cifra I',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    // p1 tem category «Clamor»: não há mais secção nem chip de categoria.
    for (final gone in ['Categoria', 'Clamor']) {
      expect(find.text(gone), findsNothing, reason: gone);
    }
  });
```

No fim de `main()`, acrescentar:

```dart
  testWidgets(
    'filtro gravado antes (v2, categories) aparece como subtag marcada',
    (tester) async {
      final container = await pump(
        tester,
        prefsValues: {
          StorageKeys.catalogFilters: jsonEncode({
            'v': 2,
            'categories': ['Clamor'],
          }),
        },
      );

      expect(find.text('Categoria'), findsNothing);
      expect(isSelected(tester, 'Coletânea · Clamor'), isTrue);

      await tapChip(tester, 'Coletânea · Clamor');
      expect(container.read(catalogFiltersProvider).tags, isEmpty);
    },
  );
```

- [ ] **Step 2: rodar e ver falhar**

Run:
```bash
flutter test test/unit/features/catalog/catalog_filter_state_test.dart test/unit/features/catalog/catalog_filters_provider_test.dart test/unit/features/catalog/catalog_filter_options_test.dart test/unit/features/catalog/matches_catalog_filters_test.dart test/widget/features/catalog/catalog_filter_sections_test.dart
```
Expected: FAIL. `catalog_filter_state_test`, `catalog_filters_provider_test` e `catalog_filter_sections_test` falham por asserção (v2 rejeitada, `category` ignorado na URL, secção «Categoria» presente). `matches_catalog_filters_test` falha em `fromLink` (a categoria ainda é filtro próprio, e `secao` passa, mas `soCategoria` também passa). `catalog_filter_options_test` pode já passar: é só limpeza.

- [ ] **Step 3: `CatalogFilterState` sem categorias**

Substituir `lib/features/catalog/domain/entities/catalog_filter_state.dart` inteiro por:

```dart
import '../utils/legacy_category_tags.dart';

/// Filtros do catálogo — um conjunto só para a página inicial e a
/// /biblioteca (spec fim-fonte §2.2, C5).
///
/// OU dentro de cada conjunto, E entre conjuntos; conjunto vazio não
/// restringe (`matchesCatalogFilters`). [tags] guarda **nomes** de tag;
/// [materialKindIds], ids de `material_kind`. Os getters `*UrlValue` dão o
/// CSV ordenado de cada conjunto (`null` quando vazio) para a URL (§2.5).
///
/// Não há filtro de categoria: a seção da Coletânea é a subtag
/// `Coletânea · <seção>` (spec seções-coletânea §4). Links e prefs antigos
/// com categoria são convertidos em tags na leitura ([legacyCategoryToTags]).
class CatalogFilterState {
  const CatalogFilterState({
    this.tonalities = const {},
    this.rhythms = const {},
    this.tags = const {},
    this.materialKindIds = const {},
  });

  /// Sem filtro nenhum.
  static const empty = CatalogFilterState();

  /// Estado a partir dos params da URL (CSV de cada filtro).
  ///
  /// [category] é o param legado `?category=`: cada valor vira a subtag de
  /// `Coletânea` e soma-se a [tags]; valores sem seção (Avulsos…) são
  /// descartados (spec seções-coletânea §4.2).
  factory CatalogFilterState.fromUrl({
    String? tonality,
    String? rhythm,
    String? category,
    String? tags,
    String? materialKinds,
  }) {
    return CatalogFilterState(
      tonalities: parseCsv(tonality),
      rhythms: parseCsv(rhythm),
      tags: {...parseCsv(tags), ...legacyCategoryToTags(parseCsv(category))},
      materialKindIds: parseCsv(materialKinds),
    );
  }

  final Set<String> tonalities;
  final Set<String> rhythms;

  /// Nomes de tag; `PES` também apanha `PES · 9.2026`.
  final Set<String> tags;

  /// Ids de `material_kind`.
  final Set<String> materialKindIds;

  bool get isEmpty =>
      tonalities.isEmpty &&
      rhythms.isEmpty &&
      tags.isEmpty &&
      materialKindIds.isEmpty;

  /// Quantos valores estão escolhidos, somando todos os filtros — a
  /// contagem do cabeçalho do painel (`filtersActiveCount`).
  int get activeCount =>
      tonalities.length + rhythms.length + tags.length + materialKindIds.length;

  CatalogFilterState copyWith({
    Set<String>? tonalities,
    Set<String>? rhythms,
    Set<String>? tags,
    Set<String>? materialKindIds,
  }) {
    return CatalogFilterState(
      tonalities: tonalities ?? this.tonalities,
      rhythms: rhythms ?? this.rhythms,
      tags: tags ?? this.tags,
      materialKindIds: materialKindIds ?? this.materialKindIds,
    );
  }

  String? get tonalityUrlValue => _csvOrNull(tonalities);
  String? get rhythmUrlValue => _csvOrNull(rhythms);
  String? get tagsUrlValue => _csvOrNull(tags);
  String? get materialKindsUrlValue => _csvOrNull(materialKindIds);

  /// Versão do JSON gravado em `StorageKeys.catalogFilters`. A v3 não tem
  /// `categories`; a v2 (com `categories`) continua a ser lida
  /// ([_readableVersions]) e convertida em tags.
  static const persistedVersion = 3;

  static const _readableVersions = {2, persistedVersion};

  Map<String, Object> toPersistedJson() => {
    'v': persistedVersion,
    'tonalities': _sorted(tonalities),
    'rhythms': _sorted(rhythms),
    'tags': _sorted(tags),
    'materialKinds': _sorted(materialKindIds),
  };

  /// `null` quando [json] não é uma versão legível — inclusive o antigo
  /// `{materials, arranjos}`, que é descartado (spec fim-fonte §2.2). A chave
  /// `categories` (v2) vira subtags de `Coletânea` somadas a [tags] (spec
  /// seções-coletânea §4.2).
  static CatalogFilterState? fromPersistedJson(Object? json) {
    if (json is! Map || !_readableVersions.contains(json['v'])) return null;
    Set<String> read(String key) {
      final raw = json[key];
      if (raw is! List) return <String>{};
      return {
        for (final value in raw)
          if (value is String && value.trim().isNotEmpty) value.trim(),
      };
    }

    return CatalogFilterState(
      tonalities: read('tonalities'),
      rhythms: read('rhythms'),
      tags: {...read('tags'), ...legacyCategoryToTags(read('categories'))},
      materialKindIds: read('materialKinds'),
    );
  }

  /// CSV da URL → conjunto (trim, sem vazios).
  static Set<String> parseCsv(String? raw) {
    if (raw == null || raw.trim().isEmpty) return {};
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  static String? _csvOrNull(Set<String> values) =>
      values.isEmpty ? null : _sorted(values).join(',');

  static List<String> _sorted(Set<String> values) => values.toList()..sort();

  static bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogFilterState &&
          _sameSet(tonalities, other.tonalities) &&
          _sameSet(rhythms, other.rhythms) &&
          _sameSet(tags, other.tags) &&
          _sameSet(materialKindIds, other.materialKindIds);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(tonalities),
    Object.hashAllUnordered(rhythms),
    Object.hashAllUnordered(tags),
    Object.hashAllUnordered(materialKindIds),
  );

  @override
  String toString() =>
      'CatalogFilterState(tom: $tonalities, ritmo: $rhythms, '
      'tags: $tags, tipos: $materialKindIds)';
}
```

- [ ] **Step 4: `CatalogFilterOptions` sem categorias**

Em `lib/features/catalog/domain/entities/catalog_filter_options.dart`:
- no construtor (linhas 29-35), remover `this.categories = const [],`;
- nos campos (linha 42), remover `final List<String> categories;`;
- em `fromGroups`, remover `final categories = <String>{};` (linha 49), `_addValue(categories, meta.category);` (linha 58) e `categories: _sorted(categories),` (linha 91).

- [ ] **Step 5: predicado sem categoria**

Em `lib/features/catalog/domain/usecases/matches_catalog_filters.dart`, trocar o doc das linhas 8-15:

```dart
/// - Tom, ritmo, categoria: o valor do praise (`coldigomMeta`, aparado) está
///   no conjunto (OU).
```
por
```dart
/// - Tom, ritmo: o valor do praise (`coldigomMeta`, aparado) está no
///   conjunto (OU). A seção da Coletânea é tag (`Coletânea · <seção>`), não
///   categoria (spec seções-coletânea §4.1).
```
e, na mesma docstring,
```dart
///   `coldigomMeta` só passa sem filtros de tom/ritmo/categoria/tags.
```
por
```dart
///   `coldigomMeta` só passa sem filtros de tom/ritmo/tags.
```
Remover o bloco das linhas 27-30:
```dart
  if (filters.categories.isNotEmpty &&
      (meta == null || !filters.categories.contains(meta.category.trim()))) {
    return false;
  }
```

- [ ] **Step 6: provider sem `toggleCategory`**

Em `lib/features/catalog/presentation/providers/catalog_filters_provider.dart`:
- linhas 22-23: trocar
```dart
/// Seleção, persistência (C13: pref `catalogFilters`, formato v2) e
/// hidratação da URL.
```
por
```dart
/// Seleção, persistência (C13: pref `catalogFilters`, formato v3; a v2 é
/// lida e convertida) e hidratação da URL.
```
- remover as linhas 80-81:
```dart
  void toggleCategory(String value) =>
      _apply(state.copyWith(categories: _toggle(state.categories, value)));
```
`hydrateFromUrl` **não muda**: continua a receber `category` e a repassá-lo a `fromUrl`.

- [ ] **Step 7: secção «Categoria» sai do painel**

Em `lib/features/catalog/presentation/widgets/catalog_filter_sections.dart`:
- linhas 11-12: trocar
```dart
/// Secções de chips dos filtros do catálogo (tom, ritmo, categoria, tags,
/// tipo de material) — as mesmas na página inicial e na /biblioteca.
```
por
```dart
/// Secções de chips dos filtros do catálogo (tom, ritmo, tags, tipo de
/// material) — as mesmas na página inicial e na /biblioteca.
```
- remover o bloco das linhas 42-47:
```dart
      _ChipSection(
        title: l10n.coldigomFilterCategory,
        items: _withSelected(_named(options.categories), selected.categories),
        selectedIds: selected.categories,
        onToggle: notifier.toggleCategory,
      ),
```

- [ ] **Step 8: telas compilam sem `categoryUrlValue`**

- `lib/features/catalog/presentation/pages/home_screen.dart` linha 194: remover `      category: filters.categoryUrlValue,`.
- Na docstring da classe (linha 27), trocar
```dart
/// (tom, ritmo, categoria, tags, tipo de material — os mesmos da
```
por
```dart
/// (tom, ritmo, tags, tipo de material — os mesmos da
```
- Doc dos campos (linhas 51-52): trocar
```dart
  /// CSVs iniciais dos filtros do catálogo (`?tonality=`, `?rhythm=`,
  /// `?category=`, `?tags=` por nome, `?materialKinds=` por id de kind).
```
por
```dart
  /// CSVs iniciais dos filtros do catálogo (`?tonality=`, `?rhythm=`,
  /// `?tags=` por nome, `?materialKinds=` por id de kind). `?category=` é
  /// legado: vira subtag de `Coletânea` na hidratação.
```
- `lib/features/library/presentation/pages/library_screen.dart` linha 172: remover `      category: filters.categoryUrlValue,`.

- [ ] **Step 9: doc da pref**

`lib/core/constants/storage_keys.dart` linhas 30-31: trocar
```dart
  /// Filtros do catálogo (JSON v2: tom, ritmo, categoria, tags, tipos de
  /// material) — C13, spec fim-fonte §2.2.
```
por
```dart
  /// Filtros do catálogo (JSON v3: tom, ritmo, tags, tipos de material; a v2
  /// com `categories` ainda é lida e convertida em tags) — C13, spec
  /// fim-fonte §2.2 e seções-coletânea §4.2.
```

- [ ] **Step 10: rodar e ver passar**

Run: o mesmo comando do Step 2 mais `test/unit/features/catalog/legacy_category_tags_test.dart`.
Expected: PASS em todos.

Rodar também os testes que montam as telas e o painel, para garantir que nada mais usava categoria:
```bash
flutter test test/widget/features/library/library_screen_test.dart test/widget/features/catalog/filters_url_sync_across_tabs_test.dart test/widget/features/catalog/home_search_test.dart
```
Expected: PASS.

- [ ] **Step 11: formatar e analisar**

```bash
dart format lib/features/catalog/domain/entities/catalog_filter_state.dart lib/features/catalog/domain/entities/catalog_filter_options.dart lib/features/catalog/domain/usecases/matches_catalog_filters.dart lib/features/catalog/presentation/providers/catalog_filters_provider.dart lib/features/catalog/presentation/widgets/catalog_filter_sections.dart lib/features/catalog/presentation/pages/home_screen.dart lib/features/library/presentation/pages/library_screen.dart lib/core/constants/storage_keys.dart test/unit/features/catalog/catalog_filter_state_test.dart test/unit/features/catalog/catalog_filters_provider_test.dart test/unit/features/catalog/catalog_filter_options_test.dart test/unit/features/catalog/matches_catalog_filters_test.dart test/widget/features/catalog/catalog_filter_sections_test.dart
flutter analyze
```
Expected: `No issues found!`. O `coldigomFilterCategory` fica sem uso, mas não é aviso do analyzer; a chave sai na Task 6.

- [ ] **Step 12: commit**

```bash
git add lib/features/catalog/domain/entities/catalog_filter_state.dart lib/features/catalog/domain/entities/catalog_filter_options.dart lib/features/catalog/domain/usecases/matches_catalog_filters.dart lib/features/catalog/presentation/providers/catalog_filters_provider.dart lib/features/catalog/presentation/widgets/catalog_filter_sections.dart lib/features/catalog/presentation/pages/home_screen.dart lib/features/library/presentation/pages/library_screen.dart lib/core/constants/storage_keys.dart test/unit/features/catalog/catalog_filter_state_test.dart test/unit/features/catalog/catalog_filters_provider_test.dart test/unit/features/catalog/catalog_filter_options_test.dart test/unit/features/catalog/matches_catalog_filters_test.dart test/widget/features/catalog/catalog_filter_sections_test.dart
git commit -m "feat(catalogo): filtros sem categoria; links e prefs antigos viram subtags (v3)" -m "Sai a secção Categoria, CatalogFilterState.categories, toggleCategory e o critério do predicado. ?category= e a chave categories da pref v2 são convertidos em Coletânea · <seção> e somados às tags; persistedVersion vai para 3 e a leitura aceita 2 e 3 (antes, versão diferente descartava e apagava a pref)." -m "Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: a URL deixa de gravar `category`; o link antigo sai no próximo sync

**Files:**
- Modify: `lib/core/utils/home_url_builder.dart:4-50`
- Modify: `lib/core/utils/library_url_builder.dart:4-69`
- Modify: `lib/core/utils/url_sync_params.dart:8-12` (doc)
- Modify: `lib/features/catalog/presentation/pages/home_screen.dart` (`_applyUrlSyncFromState`, ~176-198)
- Modify: `lib/features/library/presentation/pages/library_screen.dart` (`_applyUrlSyncFromState`, ~155-178)
- **Não muda:** `lib/core/routing/app_router.dart` (continua a passar `params[UrlSyncParams.category]` para `initialCategory`).
- Test: `test/unit/core/utils/home_url_builder_test.dart`, `test/unit/core/utils/library_url_builder_test.dart`, `test/widget/features/catalog/filters_url_sync_across_tabs_test.dart`

**Interfaces (depois da tarefa):**
```dart
String buildHomeLocation({
  String pesquisa = '',
  String? tonality,
  String? rhythm,
  String? tags,
  String? materialKinds,
});
String buildHomeLocationFromUri(Uri uri); // ignora `category`
String buildLibraryLocation({
  String? tonality,
  String? rhythm,
  String? tags,
  String? materialKinds,
  String ordenar = UrlSyncParams.defaultOrdenar,
  String itensPorPagina = UrlSyncParams.defaultItensPorPagina,
  String pagina = UrlSyncParams.defaultPagina,
});
String buildLibraryLocationFromUri(Uri uri); // ignora `category`
```

- [ ] **Step 1: testes (os dos builders falham)**

**1a.** `test/unit/core/utils/home_url_builder_test.dart`:
- no teste `'buildHomeLocation combina pesquisa e os filtros do catálogo'` (linhas 10-26), remover o argumento `category: 'Clamor',` e a linha `expect(location, contains('category=Clamor'));`;
- no fim de `main()`, acrescentar:

```dart
  test('category (legado) não é escrito e a normalização o ignora', () {
    final uri = Uri.parse('/?category=Clamor&tags=PES');

    final location = buildHomeLocationFromUri(uri);

    expect(location, buildHomeLocation(tags: 'PES'));
    expect(location, isNot(contains('category')));
  });
```

**1b.** `test/unit/core/utils/library_url_builder_test.dart`:
- no teste `'buildLibraryLocation combina filtros do catálogo e vista'` (linhas 10-30), remover `category: 'Clamor',` e `expect(location, contains('category=Clamor'));`;
- no fim de `main()`, acrescentar:

```dart
  test('category (legado) não é escrito e a normalização o ignora', () {
    final uri = Uri.parse('/biblioteca?category=Clamor&tonality=Dm');

    final location = buildLibraryLocationFromUri(uri);

    expect(location, buildLibraryLocation(tonality: 'Dm'));
    expect(location, isNot(contains('category')));
  });
```

**1c.** `test/widget/features/catalog/filters_url_sync_across_tabs_test.dart`: no fim de `main()`, acrescentar. `CatalogFilterState` já vem pelo export de `catalog_filters_provider.dart`, que o arquivo importa.

```dart
  testWidgets(
    'link antigo ?category= na página inicial filtra pela subtag e o param '
    'sai no próximo sync, mesmo quando o alvo fica vazio',
    (tester) async {
      final router = await pumpShell(
        tester,
        initialLocation: '${RoutePaths.home}?${UrlSyncParams.category}=Clamor',
      );
      final container = containerOf(tester);
      expect(
        container.read(catalogFiltersProvider),
        const CatalogFilterState(tags: {'Coletânea · Clamor'}),
      );

      // Desmarcar tudo: o alvo é `/`; o `?category=` não pode ficar na URL
      // (recarregar reaplicaria o filtro).
      container
          .read(catalogFiltersProvider.notifier)
          .toggleTag('Coletânea · Clamor');
      await tester.pumpAndSettle();

      expect(container.read(catalogFiltersProvider).isEmpty, isTrue);
      expect(currentUri(router).path, RoutePaths.home);
      expect(
        currentUri(router).queryParameters,
        isNot(contains(UrlSyncParams.category)),
      );
    },
  );

  testWidgets(
    'link antigo ?category= na /biblioteca filtra pela subtag e o param sai '
    'no próximo sync',
    (tester) async {
      final router = await pumpShell(
        tester,
        initialLocation:
            '${RoutePaths.library}?${UrlSyncParams.category}=Clamor',
      );
      final container = containerOf(tester);
      expect(
        container.read(catalogFiltersProvider),
        const CatalogFilterState(tags: {'Coletânea · Clamor'}),
      );

      container
          .read(catalogFiltersProvider.notifier)
          .toggleTag('Coletânea · Clamor');
      await tester.pumpAndSettle();

      expect(currentUri(router).path, RoutePaths.library);
      expect(
        currentUri(router).queryParameters,
        isNot(contains(UrlSyncParams.category)),
      );
    },
  );
```

- [ ] **Step 2: rodar e ver falhar**

Run:
```bash
flutter test test/unit/core/utils/home_url_builder_test.dart test/unit/core/utils/library_url_builder_test.dart test/widget/features/catalog/filters_url_sync_across_tabs_test.dart
```
Expected: FAIL nos dois testes «category (legado)…» dos builders (a normalização ainda escreve `category`). Os dois testes novos de `filters_url_sync_across_tabs_test` **passam** por enquanto: `build*LocationFromUri` ainda inclui `category`, então a URL normalizada difere do alvo e é regravada. É o esperado neste passo.

- [ ] **Step 3: builders sem `category`**

`lib/core/utils/home_url_builder.dart`:
- remover o parâmetro `String? category,` (linha 15) e a linha `put(UrlSyncParams.category, category);` (linha 28);
- em `buildHomeLocationFromUri`, remover `category: uri.queryParameters[UrlSyncParams.category],` (linha 47);
- trocar a docstring de `buildHomeLocationFromUri` (linhas 40-42) por:
```dart
/// Normaliza [uri] da página inicial para comparação com [buildHomeLocation].
///
/// `materiais`/`arranjo` de links antigos são ignorados (spec fim-fonte
/// §2.5), e `category` também: a hidratação já o converteu em tags (spec
/// seções-coletânea §4.2). Quem compara precisa forçar a regravação quando
/// o param legado está presente (ver `HomeScreen._applyUrlSyncFromState`).
```

`lib/core/utils/library_url_builder.dart`:
- na docstring, trocar a linha 8
```dart
/// [rhythm], [category], [tags] (nomes) e [materialKinds] (ids de kind);
```
por
```dart
/// [rhythm], [tags] (nomes) e [materialKinds] (ids de kind);
```
- remover `String? category,` (linha 14), `put(UrlSyncParams.category, category);` (linha 29) e `category: uri.queryParameters[UrlSyncParams.category],` (linha 58);
- trocar a docstring de `buildLibraryLocationFromUri` (linhas 50-54) por:
```dart
/// Normaliza [uri] da /biblioteca para comparação com [buildLibraryLocation].
///
/// Params que não existem mais (`fonte`, `materiais`, `arranjo`,
/// `arranjoEspecial`, `category`) são ignorados — um link antigo abre sem
/// erro e o sync de URL os tira. `category` já virou tags na hidratação
/// (spec seções-coletânea §4.2); quem compara força a regravação quando ele
/// está presente (ver `LibraryScreen._applyUrlSyncFromState`).
```

`lib/core/utils/url_sync_params.dart` linhas 8-12: trocar
```dart
  /// Filtros do catálogo (CSV), nas rotas `/` e `/biblioteca` (spec fim-fonte
  /// §2.5). [tags] leva **nomes** de tag; [materialKinds], ids de kind.
  static const String tonality = 'tonality';
  static const String rhythm = 'rhythm';
  static const String category = 'category';
```
por
```dart
  /// Filtros do catálogo (CSV), nas rotas `/` e `/biblioteca` (spec fim-fonte
  /// §2.5). [tags] leva **nomes** de tag; [materialKinds], ids de kind.
  static const String tonality = 'tonality';
  static const String rhythm = 'rhythm';

  /// Legado — categoria do praise. Só lido: vira subtag `Coletânea · <seção>`
  /// (spec seções-coletânea §4.2); a URL não o grava mais.
  static const String category = 'category';
```

- [ ] **Step 4: rodar e ver o teste de sync da página inicial falhar**

Run: `flutter test test/unit/core/utils/home_url_builder_test.dart test/unit/core/utils/library_url_builder_test.dart test/widget/features/catalog/filters_url_sync_across_tabs_test.dart`
Expected:
- os testes dos builders passam;
- o teste «link antigo ?category= na página inicial…» **FAIL**: a URL normalizada (`/`) é igual ao alvo (`/`), nada é regravado, e o `category` fica. Esse é o bug do Review Focus 3.
- O da /biblioteca pode falhar ou passar, conforme `itensPorPagina` entre ou não no alvo. Siga para o Step 5 de qualquer forma.

- [ ] **Step 5: forçar a regravação com o param legado**

`lib/features/catalog/presentation/pages/home_screen.dart`, em `_applyUrlSyncFromState`: acrescentar o import `import 'package:coldigui/core/utils/url_sync_params.dart';` (em ordem alfabética, depois de `home_url_builder.dart`) e trocar

```dart
    if (buildHomeLocationFromUri(uri) == target) return;
```
por
```dart
    // `?category=` (link antigo) já virou tags na hidratação e o normalizador
    // o ignora; sem esta checagem, um alvo igual ao resto da URL (ex.: tudo
    // desmarcado → `/`) deixaria o param lá e recarregar reaplicaria o filtro.
    final hasLegacyCategory = uri.queryParameters.containsKey(
      UrlSyncParams.category,
    );
    if (!hasLegacyCategory && buildHomeLocationFromUri(uri) == target) return;
```

`lib/features/library/presentation/pages/library_screen.dart`, em `_applyUrlSyncFromState`: acrescentar o import `import 'package:coldigui/core/utils/url_sync_params.dart';` (depois de `library_url_builder.dart`) e trocar

```dart
    if (buildLibraryLocationFromUri(uri) == target) return;
```
por
```dart
    // `?category=` (link antigo) já virou tags na hidratação e o normalizador
    // o ignora; sem esta checagem, um alvo igual ao resto da URL deixaria o
    // param lá e recarregar reaplicaria o filtro.
    final hasLegacyCategory = uri.queryParameters.containsKey(
      UrlSyncParams.category,
    );
    if (!hasLegacyCategory && buildLibraryLocationFromUri(uri) == target) {
      return;
    }
```

Se `url_sync_params.dart` já estiver importado em alguma das telas, não duplique o import: o analyzer acusa `duplicate_import`.

- [ ] **Step 6: rodar e ver passar**

Run:
```bash
flutter test test/unit/core/utils/home_url_builder_test.dart test/unit/core/utils/library_url_builder_test.dart test/widget/features/catalog/filters_url_sync_across_tabs_test.dart test/widget/features/library/library_screen_test.dart test/widget/features/catalog/home_search_test.dart
```
Expected: PASS em todos. `library_screen_test` e `home_search_test` provam que o sync normal não entrou em loop.

- [ ] **Step 7: formatar e analisar**

```bash
dart format lib/core/utils/home_url_builder.dart lib/core/utils/library_url_builder.dart lib/core/utils/url_sync_params.dart lib/features/catalog/presentation/pages/home_screen.dart lib/features/library/presentation/pages/library_screen.dart test/unit/core/utils/home_url_builder_test.dart test/unit/core/utils/library_url_builder_test.dart test/widget/features/catalog/filters_url_sync_across_tabs_test.dart
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 8: commit**

```bash
git add lib/core/utils/home_url_builder.dart lib/core/utils/library_url_builder.dart lib/core/utils/url_sync_params.dart lib/features/catalog/presentation/pages/home_screen.dart lib/features/library/presentation/pages/library_screen.dart test/unit/core/utils/home_url_builder_test.dart test/unit/core/utils/library_url_builder_test.dart test/widget/features/catalog/filters_url_sync_across_tabs_test.dart
git commit -m "feat(catalogo): URL deixa de gravar category; link antigo sai no próximo sync" -m "Os builders e a normalização ignoram category; o router e as telas continuam a lê-lo para a hidratação (vira Coletânea · <seção>). Com o param legado presente as telas regravam a URL mesmo quando o alvo coincide com o resto dela — senão, tudo desmarcado deixaria ?category= e recarregar reaplicaria o filtro." -m "Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: a ficha do material fica sem a linha «Categoria»

**Files:**
- Modify: `lib/features/catalog/presentation/widgets/material_sheet.dart:716-766` (`_ColdigomMetaBlock`)
- Modify: `lib/features/coldigom/domain/entities/coldigom_praise_metadata.dart:31-36` (`hasAnyField`)
- Create: `test/unit/features/coldigom/coldigom_praise_metadata_test.dart`
- Modify: `test/widget/features/catalog/material_sheet_test.dart:400-401`

**Interfaces:** `ColdigomPraiseMetadata.category` **fica** (fase 3). `bool get hasAnyField` passa a ignorar `category`. Ele só é usado em `material_sheet.dart:352` (`if (meta != null && meta.hasAnyField)`) e em `coldigom_louvor_adapter_test.dart:246`, que continua `true` por tom e ritmo.

- [ ] **Step 1: testes que falham**

`test/unit/features/coldigom/coldigom_praise_metadata_test.dart`:

```dart
import 'package:coldigui/features/coldigom/domain/entities/coldigom_praise_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'hasAnyField ignora category: a seção da Coletânea vem nas tags',
    () {
      expect(
        const ColdigomPraiseMetadata(name: 'x', category: 'Clamor').hasAnyField,
        isFalse,
      );
      expect(
        const ColdigomPraiseMetadata(
          name: 'x',
          category: 'Clamor',
          tagNames: ['Coletânea · Clamor'],
        ).hasAnyField,
        isTrue,
      );
    },
  );

  test('hasAnyField: tom, autor, ritmo ou tags bastam', () {
    expect(const ColdigomPraiseMetadata(name: 'x').hasAnyField, isFalse);
    expect(
      const ColdigomPraiseMetadata(name: 'x', tonality: 'Dm').hasAnyField,
      isTrue,
    );
    expect(
      const ColdigomPraiseMetadata(name: 'x', author: 'A').hasAnyField,
      isTrue,
    );
    expect(
      const ColdigomPraiseMetadata(name: 'x', rhythm: 'Fox').hasAnyField,
      isTrue,
    );
    expect(
      const ColdigomPraiseMetadata(name: 'x', tagNames: ['PES']).hasAnyField,
      isTrue,
    );
  });
}
```

Em `test/widget/features/catalog/material_sheet_test.dart`, no teste `'meta, número separado do nome e abas por tipo'`, trocar as linhas 400-401

```dart
      expect(find.text('Categoria'), findsOneWidget);
      expect(find.text('Clamor'), findsOneWidget);
```
por
```dart
      // A meta ainda traz category (fase 3), mas a ficha não a mostra: a
      // seção da Coletânea aparece nas tags (spec seções-coletânea §4.1).
      expect(find.text('Categoria'), findsNothing);
      expect(find.text('Clamor'), findsNothing);
```

- [ ] **Step 2: rodar e ver falhar**

Run: `flutter test test/unit/features/coldigom/coldigom_praise_metadata_test.dart test/widget/features/catalog/material_sheet_test.dart`
Expected: FAIL. `hasAnyField` retorna `true` para «só categoria», e a ficha mostra «Categoria» e «Clamor».

- [ ] **Step 3: implementar**

`lib/features/coldigom/domain/entities/coldigom_praise_metadata.dart`, trocar as linhas 31-36:

```dart
  bool get hasAnyField =>
      tonality.trim().isNotEmpty ||
      author.trim().isNotEmpty ||
      rhythm.trim().isNotEmpty ||
      category.trim().isNotEmpty ||
      tagNames.isNotEmpty;
```
por
```dart
  /// Há algo a mostrar no bloco de metadados da ficha. [category] não conta:
  /// a ficha não a mostra mais — a seção da Coletânea vem em [tagNames] (spec
  /// seções-coletânea §4.1). O campo em si sai na fase 3.
  bool get hasAnyField =>
      tonality.trim().isNotEmpty ||
      author.trim().isNotEmpty ||
      rhythm.trim().isNotEmpty ||
      tagNames.isNotEmpty;
```

`lib/features/catalog/presentation/widgets/material_sheet.dart`, em `_ColdigomMetaBlock`:
- linha 716: trocar `/// Bloco de metadados do praise Coldigom (tom, ritmo, autor, categoria, tags).` por `/// Bloco de metadados do praise Coldigom (tom, ritmo, autor, tags).`;
- remover a linha 728: `    final category = meta.category.trim();`;
- remover o bloco das linhas 762-765:
```dart
            if (category.isNotEmpty) ...[
              if (hasPair || author.isNotEmpty) const SizedBox(height: 10),
              _metaField(l10n.coldigomMetaCategory, category),
            ],
```
O espaçamento das tags (`const SizedBox(height: 12)`, logo abaixo) não depende da categoria e não muda.

- [ ] **Step 4: rodar e ver passar**

Run:
```bash
flutter test test/unit/features/coldigom/coldigom_praise_metadata_test.dart test/widget/features/catalog/material_sheet_test.dart test/unit/features/coldigom/coldigom_louvor_adapter_test.dart
```
Expected: PASS.

- [ ] **Step 5: formatar e analisar**

```bash
dart format lib/features/catalog/presentation/widgets/material_sheet.dart lib/features/coldigom/domain/entities/coldigom_praise_metadata.dart test/unit/features/coldigom/coldigom_praise_metadata_test.dart test/widget/features/catalog/material_sheet_test.dart
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 6: commit**

```bash
git add lib/features/catalog/presentation/widgets/material_sheet.dart lib/features/coldigom/domain/entities/coldigom_praise_metadata.dart test/unit/features/coldigom/coldigom_praise_metadata_test.dart test/widget/features/catalog/material_sheet_test.dart
git commit -m "feat(catalogo): ficha do material sem a linha Categoria" -m "A seção da Coletânea já aparece nas tags. hasAnyField deixa de contar category, senão um praise só com categoria desenharia o bloco de metadados vazio. O campo fica até a fase 3." -m "Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: o campo de metadado das contribuições fica sem «Categoria»

**Files:**
- Modify: `lib/features/contributions/domain/entities/contribution_kind.dart:46-48`
- Modify: `lib/features/contributions/presentation/utils/contribution_labels.dart:24`
- Modify: `lib/features/contributions/presentation/widgets/contribution_context_fields.dart:158-160`
- **Não muda:** `lib/features/contributions/presentation/pages/contribution_detail_screen.dart`. Hoje `_metadataLine` (linhas 161-172) procura o nome em `MetadataField.values` e, quando não acha, devolve `null` sem mostrar a linha. O teste novo fixa esse comportamento.
- Create: `test/widget/features/contributions/contribution_detail_screen_test.dart`
- Modify: `test/unit/features/contributions/contribution_draft_test.dart`, `test/widget/features/contributions/contribute_screen_test.dart`

**Usos de `MetadataField` levantados.** O `switch` exaustivo em `contribution_labels.dart:17-26` e o de `contribution_context_fields.dart:153-161` quebram a compilação se ficarem com `.category`. O dropdown (`for (final f in MetadataField.values)`, `:101`) e o detalhe, que busca por `name`, se adaptam sozinhos. O rascunho envia `'field': metadataField!.name` (`contribution_draft.dart:73`) e não é persistido localmente. O servidor mantém `'category'` em `METADATA_FIELDS` (spec §3.4), então apps antigos continuam a enviar.

- [ ] **Step 1: testes que falham**

**1a.** `test/unit/features/contributions/contribution_draft_test.dart`: acrescentar no fim de `main()`:

```dart
  test('MetadataField: wireNames sem category (a seção virou tag)', () {
    expect([for (final f in MetadataField.values) f.name], [
      'title',
      'number',
      'author',
      'tonality',
      'rhythm',
      'tags',
    ]);
  });
```

**1b.** `test/widget/features/contributions/contribute_screen_test.dart`: acrescentar no fim de `main()`. `_logged`, `_FakePraiseMetaNotifier` e os imports já existem no arquivo.

```dart
  testWidgets('metadata: o campo não oferece «Categoria»', (tester) async {
    await pumpApp(
      tester,
      const ContributeScreen(
        target: ContributionTarget(
          source: ContributionSource.coldigom,
          praiseId: 'p1',
        ),
      ),
      overrides: [
        ..._logged(),
        coldigomPraiseMetaCacheProvider.overrideWith(
          () => _FakePraiseMetaNotifier({
            'p1': const ColdigomPraiseMetadata(name: 'Nome', category: 'Clamor'),
          }),
        ),
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Título, número, tom…'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('contribute-metadata-field')));
    await tester.pumpAndSettle();

    for (final label in ['Título', 'Número', 'Autor', 'Tom', 'Ritmo', 'Tags']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    expect(find.text('Categoria'), findsNothing);
  });
```

**1c.** Criar `test/widget/features/contributions/contribution_detail_screen_test.dart`:

```dart
import 'package:coldigui/features/contributions/domain/entities/contribution_kind.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_summary.dart';
import 'package:coldigui/features/contributions/presentation/pages/contribution_detail_screen.dart';
import 'package:coldigui/features/contributions/presentation/providers/my_contributions_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/pump_app.dart';

ContributionSummary _metadata(Map<String, dynamic> fields) =>
    ContributionSummary(
      id: 'c1',
      kind: ContributionKind.wrongInfo,
      subkind: 'metadata',
      title: 'Metadado errado',
      body: 'Corpo da contribuição',
      status: ContributionStatus.pendente,
      decisionNote: null,
      createdAt: DateTime.utc(2026, 9, 10),
      updatedAt: DateTime.utc(2026, 9, 10),
      links: const [],
      files: const [],
      fields: fields,
    );

Future<void> _pump(WidgetTester tester, ContributionSummary item) async {
  await pumpApp(
    tester,
    ContributionDetailScreen(id: item.id),
    overrides: [
      contributionDetailProvider(item.id).overrideWith((ref) async => item),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('campo conhecido mostra «campo: atual → proposto»', (
    tester,
  ) async {
    await _pump(
      tester,
      _metadata({'field': 'tonality', 'current': 'Dm', 'proposed': 'Em'}),
    );

    expect(find.text('Tom: Dm → Em'), findsOneWidget);
  });

  testWidgets(
    'contribuição antiga com field «category» abre sem a linha de metadado',
    (tester) async {
      await _pump(
        tester,
        _metadata({
          'field': 'category',
          'current': 'Clamor',
          'proposed': 'Louvor',
        }),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Metadado errado'), findsOneWidget);
      expect(find.text('Corpo da contribuição'), findsOneWidget);
      expect(find.textContaining('Clamor'), findsNothing);
      expect(find.textContaining('→'), findsNothing);
    },
  );
}
```

- [ ] **Step 2: rodar e ver falhar**

Run:
```bash
flutter test test/unit/features/contributions/contribution_draft_test.dart test/widget/features/contributions/contribute_screen_test.dart test/widget/features/contributions/contribution_detail_screen_test.dart
```
Expected:
- FAIL no teste do enum (tem `category`);
- FAIL no dropdown (acha «Categoria»);
- FAIL no detalhe, no caso `field: category`: hoje o enum reconhece o nome e a linha «Categoria: Clamor → Louvor» aparece.

O teste «campo conhecido» passa já agora.

- [ ] **Step 3: implementar**

`lib/features/contributions/domain/entities/contribution_kind.dart`, linhas 46-48: trocar

```dart
/// Campo de metadado alvo de um `wrong_info/metadata` — o nome do enum já é
/// o `wireName` esperado pelo servidor.
enum MetadataField { title, number, author, tonality, rhythm, category, tags }
```
por
```dart
/// Campo de metadado alvo de um `wrong_info/metadata` — o nome do enum já é
/// o `wireName` esperado pelo servidor.
///
/// Sem `category`: a seção da Coletânea virou tag (spec seções-coletânea
/// §4.1). Contribuições antigas com `field: category` não casam com nenhum
/// valor e o detalhe omite a linha, como com qualquer campo desconhecido.
enum MetadataField { title, number, author, tonality, rhythm, tags }
```

`lib/features/contributions/presentation/utils/contribution_labels.dart`: remover a linha 24, `      MetadataField.category => l10n.contributeMetadataCategory,`.

`lib/features/contributions/presentation/widgets/contribution_context_fields.dart`, linhas 158-160: trocar

```dart
      MetadataField.number ||
      MetadataField.category ||
      MetadataField.tags => null,
```
por
```dart
      MetadataField.number || MetadataField.tags => null,
```

- [ ] **Step 4: rodar e ver passar**

Run: o mesmo do Step 2, mais `flutter test test/widget/features/contributions/ test/unit/features/contributions/`.
Expected: PASS em todos.

- [ ] **Step 5: formatar e analisar**

```bash
dart format lib/features/contributions/domain/entities/contribution_kind.dart lib/features/contributions/presentation/utils/contribution_labels.dart lib/features/contributions/presentation/widgets/contribution_context_fields.dart test/unit/features/contributions/contribution_draft_test.dart test/widget/features/contributions/contribute_screen_test.dart test/widget/features/contributions/contribution_detail_screen_test.dart
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 6: commit**

```bash
git add lib/features/contributions/domain/entities/contribution_kind.dart lib/features/contributions/presentation/utils/contribution_labels.dart lib/features/contributions/presentation/widgets/contribution_context_fields.dart test/unit/features/contributions/contribution_draft_test.dart test/widget/features/contributions/contribute_screen_test.dart test/widget/features/contributions/contribution_detail_screen_test.dart
git commit -m "feat(contribuicoes): campo de metadado sem Categoria" -m "MetadataField.category sai do enum (a seção virou tag). Contribuições antigas com field category abrem no detalhe sem a linha de metadado, como qualquer campo desconhecido; o servidor continua a aceitar category (spec §3.4)." -m "Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: remover as chaves l10n de «Categoria» e varredura final

**Files:**
- Modify: `lib/l10n/app_pt.arb` (linhas 124, 370 e 1041)
- Modify: `lib/l10n/app_en.arb` (linhas 124, 361 e 887)
- Regenerate: `lib/l10n/app_localizations.dart`, `lib/l10n/app_localizations_pt.dart`, `lib/l10n/app_localizations_en.dart`
- Modify: `lib/features/catalog/domain/utils/louvor_classification.dart:5` (doc)

- [ ] **Step 1: conferir que as chaves não têm mais uso**

```bash
grep -rn "coldigomFilterCategory\|coldigomMetaCategory\|contributeMetadataCategory" lib test --include='*.dart' | grep -v "^lib/l10n/"
```
Expected: nenhuma linha. Se aparecer alguma, a tarefa correspondente (2, 4 ou 5) ficou incompleta: corrija lá antes de seguir.

- [ ] **Step 2: remover das arb**

Em `lib/l10n/app_pt.arb`, remover as três linhas:
```
  "coldigomFilterCategory": "Categoria",
  "coldigomMetaCategory": "Categoria",
  "contributeMetadataCategory": "Categoria",
```
Em `lib/l10n/app_en.arb`, remover:
```
  "coldigomFilterCategory": "Category",
  "coldigomMetaCategory": "Category",
  "contributeMetadataCategory": "Category",
```
Nenhuma das três tem bloco `@…` de metadados; confira com `grep -n "@coldigomFilterCategory\|@coldigomMetaCategory\|@contributeMetadataCategory" lib/l10n/*.arb` (esperado: nada). **Não** remover `playlistPublishCategoryLabel` («Categoria» de publicação de lista, outro assunto). Confira que as linhas vizinhas continuam com vírgula no fim e que o JSON segue válido.

- [ ] **Step 3: regenerar**

```bash
flutter gen-l10n
grep -n "coldigomFilterCategory\|coldigomMetaCategory\|contributeMetadataCategory" lib/l10n/app_localizations*.dart
```
Expected: `gen-l10n` sem erro; o grep não acha nada.

- [ ] **Step 4: doc residual**

`lib/features/catalog/domain/utils/louvor_classification.dart` linhas 4-6: trocar

```dart
/// e o chip do carrossel. Os filtros do catálogo já não usam classificação
/// nem arranjo: são tom, ritmo, categoria, tags e tipo de material, do índice
/// Coldigom (spec fim-fonte §2.2).
```
por
```dart
/// e o chip do carrossel. Os filtros do catálogo já não usam classificação
/// nem arranjo: são tom, ritmo, tags e tipo de material, do índice Coldigom
/// (spec fim-fonte §2.2).
```

Varredura, para conferir que só sobrou o que o spec manda manter:
```bash
grep -rn "categories\|toggleCategory\|categoryUrlValue\|MetadataField.category" lib --include='*.dart' | grep -v "^lib/l10n/"
```
Expected: só `lib/features/coldigom/data/datasources/coldigom_remote_datasource.dart` (`ColdigomPraisesQuery.categories`, fase 3).

```bash
grep -rn "UrlSyncParams.category" lib --include='*.dart'
```
Expected: `app_router.dart` (duas leituras), `home_screen.dart` e `library_screen.dart` (o `containsKey` da Task 3). Nenhum `put(UrlSyncParams.category`.

- [ ] **Step 5: suíte inteira e analyzer**

```bash
flutter analyze
flutter test
```
Expected: `No issues found!` e `All tests passed!`. Cole na mensagem de hand-off a última linha real de cada comando (contagem de testes). Se falhar algum teste fora das áreas tocadas, **não** conclua que não tem relação sem prova. Rode-o isolado, leia a falha e procure `category`, `categories` ou «Categoria» no teste e no código que ele exercita. Se a falha não tiver relação com este plano, relate ao controlador com a saída; não a «conserte» por conta própria.

- [ ] **Step 6: formato dos arquivos tocados no plano todo**

```bash
dart format --output=none --set-exit-if-changed lib/features/catalog/domain/utils/legacy_category_tags.dart lib/features/catalog/domain/entities/catalog_filter_state.dart lib/features/catalog/domain/entities/catalog_filter_options.dart lib/features/catalog/domain/usecases/matches_catalog_filters.dart lib/features/catalog/presentation/providers/catalog_filters_provider.dart lib/features/catalog/presentation/widgets/catalog_filter_sections.dart lib/features/catalog/presentation/pages/home_screen.dart lib/features/library/presentation/pages/library_screen.dart lib/core/constants/storage_keys.dart lib/core/utils/home_url_builder.dart lib/core/utils/library_url_builder.dart lib/core/utils/url_sync_params.dart lib/features/catalog/presentation/widgets/material_sheet.dart lib/features/coldigom/domain/entities/coldigom_praise_metadata.dart lib/features/contributions/domain/entities/contribution_kind.dart lib/features/contributions/presentation/utils/contribution_labels.dart lib/features/contributions/presentation/widgets/contribution_context_fields.dart lib/features/catalog/domain/utils/louvor_classification.dart
```
Expected: exit 0.

- [ ] **Step 7: commit**

```bash
git add lib/l10n/app_pt.arb lib/l10n/app_en.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_pt.dart lib/l10n/app_localizations_en.dart lib/features/catalog/domain/utils/louvor_classification.dart
git commit -m "chore(l10n): remove as chaves de Categoria (filtro, ficha, contribuição)" -m "coldigomFilterCategory, coldigomMetaCategory e contributeMetadataCategory ficaram sem uso com o fim da categoria no app (spec seções-coletânea §4.1). Gerados regenerados com flutter gen-l10n." -m "Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

## Homologação (depois do deploy, spec §6.4; fora deste plano)

- A seção Categoria sumiu dos filtros, da ficha e do campo de contribuição.
- Tags mostra só `Coletânea`; marcá-la revela as 13 seções na seção Subtags (rótulo do último nível, ex.: `Clamor`) e traz as 1123.
- `/?category=Clamor` e `/biblioteca?category=Clamor` abrem filtrados por `Coletânea · Clamor`. Ao mexer num filtro, o `category` some da URL.
- Um usuário com filtro de categoria salvo antes do deploy reabre o app com a subtag marcada.
- A busca «Clamor» encontra louvores da seção.

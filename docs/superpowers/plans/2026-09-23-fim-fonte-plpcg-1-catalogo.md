# Fim da fonte PLPCG — plano 1: catálogo único (filtros, /biblioteca, página inicial)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** a página inicial e a /biblioteca passam a viver só do índice local do catálogo coldigom (`ColdigomSearchIndex`), com um conjunto único de filtros (tom, ritmo, categoria, tags, tipo de material), um caminho em memória para quem não tem Isar, e o `shortId` de praise a atravessar DTO → Isar → metadados → índice (para o plano 2 gerar e ler o link `?p=`).

**Architecture:** o dump `/api/plpcg/catalog` continua a ser a fonte; com Isar vai para o banco e é hidratado como hoje, sem Isar o `SyncColdigomCatalog` devolve as linhas em memória (`ColdigomCatalogSyncInMemory`) e a hidratação lê-as de `coldigomInMemoryCatalogProvider`. Um único `CatalogFilterState` (domínio) + o predicado puro `matchesCatalogFilters` servem a /biblioteca (pipeline síncrono índice → filtro → ordenar → paginar), a busca local da página inicial (`ColdigomSearchIndex.search` + filtro) e os «novos» da busca remota. As opções dos chips saem do próprio índice (`catalogFilterOptionsProvider`). `catalogIndexStatusProvider` diz à UI se o índice está a carregar, pronto ou falhado (erro + «tentar de novo» → `coldigomCatalogSyncProvider.sync()`).

**Tech Stack:** Flutter 3 + Riverpod 3 (`Notifier`/`Provider`/`FutureProvider`), `isar_plus` (schema gerado por `build_runner`), Dio, `flutter_test`, `flutter gen-l10n`.

**Spec:** `docs/superpowers/specs/2026-09-23-fim-fonte-plpcg-design.md` — §2 inteiro e as camadas do `shortId` de §4.2 («Praise → `shortId`, que atravessa estas camadas»). Quem executa lê o spec e este plano. Modelo de dados atual: spec `2026-09-18-catalogo-coldigom-modo-unico-design.md` §11–§12.

**Ordem dos planos:** 0 (coldigom: `praises.short_id` no dump, crosswalk) → **1 (este)** → 2 (share por praise, ao vivo, cor) → 3 (normalizador, fim do manifesto, /offline). O plano 0 é pré-requisito de produção, mas **nada aqui depende de rede**: todos os testes usam fixtures.

## Global Constraints

- `flutter analyze` limpo + `flutter test` verde; a CI roda **sem** dart-defines — nenhum teste pode depender de `COLDIGOM_API_BASE_URL`/`PLPCG_API_BASE_URL`.
- l10n: editar `lib/l10n/app_pt.arb` + `app_en.arb`, rodar `flutter gen-l10n`; gerados commitados.
- Isar: mudanças de schema são aditivas e anuláveis; regenerar com `dart run build_runner build --delete-conflicting-outputs`; `.g.dart` commitados.
- Commits em português, um por tarefa, com o trailer exato:
  `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`
- Nada de push, merge ou deploy sem pedido do dono.
- Não renomear código `Plpcg*`, a env `PLPCG_API_BASE_URL` nem o Worker `plpcg-catalog`; marca «PLPCG» fica (spec §0). Código **morto** por este trabalho é apagado.
- Execução prevista: subagentes em worktree, tarefa a tarefa (subagent-driven-development). Implementadores rodam git como comando plano (`git add …`, `git commit …`, sem `cd … &&` nem `git -C`); UI de teste com `ensureVisible`/`tester.view.physicalSize` em vez de encolher densidade.
- **Não apagar** (C7): a pilha do manifesto (`louvoresManifestProvider`, `PlpcgCatalogSource`, `PlpcgSearchIndex`, `ManifestMaterialAliases`…), o `CompositeCatalogSource` (e o `mergeLocalSearchResults` que ele usa), o `catalogSourceProvider` (continua a devolver o composite até o plano 3) e o `LouvorDataSource`. Não mexer em share, ao vivo, cor nem /offline (planos 2 e 3).
- Valores sujos do coldigom (M5: «Avulso»/«Avulsos», «fox»/«Fox»…) aparecem como estão nos filtros — limpar é tarefa do coldigom.

## Contratos partilhados produzidos aqui (nomes fixos)

- **C3 (Task 1):** `ColdigomPraiseMetadata.shortId` (`String?`, default `null`); `ColdigomCatalogPraiseDto.shortId` (JSON `shortId`), `PraiseDetailDto.shortId` e `PraiseSummaryDto.shortId` (JSON `short_id`), todos `String?`; `ColdigomPraiseCache.shortId` (Isar `String?`); mapper e adapter propagam. Normalização única: `String? normalizePraiseShortId(Object? raw)` em `lib/features/coldigom/domain/utils/praise_short_id.dart` (trim + minúsculas, `[0-9a-f]{3,8}`, senão `null`) — o plano 2 usa-a para os tokens de `?p=`.
- **C4 (Task 2):** `ColdigomSearchIndex.groups` (`List<LouvorGroup>`, ordem das entries), `LouvorGroup? groupByShortId(String shortId)` (normaliza a entrada) e `LouvorGroup? groupForMaterialId(String entryId)` (qualquer id de `LouvorGroup.materials`: pdfId, audioId, chordId, gestureId, `lyrics:<praiseId>`, id do material YouTube), ambos O(1) por mapas montados no `build`.
- **C5 (Tasks 5 e 7):** `CatalogFilterState` em `lib/features/catalog/domain/entities/catalog_filter_state.dart` (`Set<String> tonalities, rhythms, categories, tags, materialKindIds`, `isEmpty`, `empty`, getters `tonalityUrlValue`/`rhythmUrlValue`/`categoryUrlValue`/`tagsUrlValue`/`materialKindsUrlValue`, `parseCsv`, `fromUrl`, `toPersistedJson`/`fromPersistedJson`); `catalogFiltersProvider` (`CatalogFiltersNotifier`: `toggleTonality`/`toggleRhythm`/`toggleCategory`/`toggleTag`/`toggleMaterialKind`, `clear`, `hydrateFromUrl({tonality, rhythm, category, tags, materialKinds})`; toggles e `clear` voltam a /biblioteca à página 1); `bool matchesCatalogFilters(LouvorGroup group, CatalogFilterState filters)` em `lib/features/catalog/domain/usecases/matches_catalog_filters.dart`; `CatalogFilterOptions` + `catalogFilterOptionsProvider` (opções derivadas do índice); `catalogTagMatches`/`catalogTagWithAncestors` em `lib/features/catalog/domain/utils/catalog_tag_hierarchy.dart`.
- **C6 (Tasks 3 e 4):** `ColdigomCatalogSyncInMemory(List<ColdigomPraiseCache> rows)` (+ `count`), desfecho do `SyncColdigomCatalog.run()` quando o datasource local está indisponível (nada é gravado, nem ETag); `coldigomInMemoryCatalogProvider` (`NotifierProvider<ColdigomInMemoryCatalogNotifier, List<ColdigomPraiseCache>>`, método `replace(rows)`); `coldigomCatalogHydrationProvider` lê o Isar quando `IsarStatus.available`, senão essas linhas; `enum CatalogIndexStatus { loading, ready, failed }` + `catalogIndexStatusProvider`; `coldigomCatalogRowProvider` (`Provider.family<ColdigomPraiseCache?, String>`, Isar ou memória). O retry da UI é `coldigomCatalogSyncProvider.notifier.sync()`.
- **C7:** a página inicial e a /biblioteca deixam de ler manifesto/PLPCG (Task 8 verifica com grep); a pilha do manifesto e o composite ficam para o plano 3.

## Review Focus

1. **Filtro ativo sem chip** — um valor selecionado (pref gravada ou link) que o catálogo já não tem (tag renomeada no coldigom, kind apagado) deixaria a lista vazia sem chip para desmarcar; a secção mostra o valor selecionado e marcado para o usuário o tirar (Task 7, `catalog_filter_sections_test`).
2. **Arranque a frio sem Isar e sem rede** — a página inicial e a /biblioteca não podem ficar no skeleton para sempre: sem catálogo e sem rede o `requestSyncIfStale` marca `ColdigomCatalogSyncFailed('sem rede')` e a UI mostra `catalogLoadError` + «Tentar novamente»; a volta da rede tenta sozinha (Tasks 4, 6 e 8).
3. **Pref antiga `{materials, arranjos}` e link antigo com `fonte`/`materiais`/`arranjo`/`arranjoEspecial`** — são ignorados sem erro nem filtro fantasma; a pref velha é apagada e a URL reescrita sem esses params (Tasks 6 e 7).
4. **Tag pai vs prefixo** — selecionar `PES` apanha `PES · 9.2026` mas não `PESCA`, e selecionar o filho não apanha o pai (Tasks 5 e 7).
5. **Web sem Isar abre a letra** — sem Isar o material «Letra» continua no card (vem do dump) e o leitor `/letra` tem de mostrar o texto das linhas em memória, não «sem letra» (Task 4).

### Desvios do spec (decididos ao planear; justificativa na tarefa)

1. **§2.3 — pipeline da /biblioteca síncrono, sem `compute`.** São ~2063 grupos já montados na hidratação; filtrar + ordenar (`SortLouvorGroups`, O(n log n) sobre `int`/`String`) + paginar custa poucos milissegundos. Na web o `compute` corre na mesma thread (não ganha nada) e no nativo copiar 2063 `LouvorGroup` para o isolate custa mais do que o trabalho. A ordenação fica num provider separado da paginação (trocar de página não reordena). A Task 6 mede num teste (2063 grupos sintéticos, teto folgado de 250 ms, tempo impresso) e o implementador regista o número no commit. Saem `LibraryGroupPipelineDriver`, `libraryGroupPipelineExecutorProvider`, `libraryGroupSortedResultsDataProvider`, `library_group_worker.dart`.
2. **§2.5 — «valem nas duas rotas».** Os cinco params de filtro (`tonality`, `rhythm`, `category`, `tags`, `materialKinds`) valem em `/` e em `/biblioteca` (o estado é um só). `ordenar`/`itensPorPagina`/`pagina` continuam só na /biblioteca (a página inicial não pagina) e `pesquisa` só na página inicial (a /biblioteca não tem busca textual). Ler o texto à letra criaria params sem efeito.
3. **§2.2 — opções de tag incluem os ancestrais.** Com a regra «o pai inclui os filhos», `PES` apanha ≥1 praise mesmo que nenhum tenha a tag exata `PES`; por isso a lista de tags mostra cada tag e os seus prefixos (`A · B · C` → `A`, `A · B`, `A · B · C`). Sem isto a regra do pai só serviria a quem escreve o link à mão.
4. **§2.4 — `mergeLocalSearchResults` sai da página inicial, mas a função fica.** Ela é do `CompositeCatalogSource.searchLocal`, que o C7 manda manter até o plano 3.
5. **§2.1 — `catalogSourceProvider` continua a devolver o composite.** A troca para o `ColdigomCatalogSource` é do plano 3 (C9). Aqui a página inicial passa a usar `coldigomCatalogSourceProvider` (busca remota) e o índice (busca local) diretamente.
6. **§2.1 — 1.º arranque com Isar vazio não usa o caminho em memória.** Com Isar disponível o dump é gravado e o índice relê o Isar (como hoje): um caminho só para quem tem banco, e ler 2063 linhas do Isar Plus é síncrono e barato. O caminho em memória fica só para `IsarStatus.unavailable`.
7. **§10.1 — `louvor_classification_special_test` é aparado, não apagado.** `displayLabel`, `materialSectionLabel` e `specialArrangement` continuam com chamador (`LouvorGroup._buildGroup`, `CarouselLouvorChip`); saem só os testes de `parseSpecialArrangementsFromUrl`/`serializeSpecialArrangementsForUrl`.
8. **Código morto além da lista do spec**, apagado porque este trabalho o deixa sem chamador: `ColdigomSearchRepository.browse` + `ColdigomBrowseQuery`/`ColdigomBrowseResult` + `ColdigomCacheWriter.mergeBrowseResult`; `ColdigomRemoteDatasource.fetchFilterOptions` + `ColdigomFilterOptionsDto`/`ColdigomTagFacetDto` + `ColdigomEndpoints.filterOptions`; `CatalogQuery.filters`/`defaultFilters`; `CatalogMaterials.expandMaterial(s)`/`isDefaultSelection`/`parseFromUrl`/`serializeForUrl`; `LouvorClassification.parse*/serialize*`; `browseLibraryProvider`; a string `catalogStaleBanner` (só a página inicial a usava). **Ficam** (pilha do manifesto, plano 3): `LouvoresManifest.availableArranjos`, `LouvorClassification.collectAvailableArranjos`, `CatalogMaterials.uiMaterials`/`defaultSelected` (secção PLPCG do /offline). `ColdigomPraisesQuery` mantém os campos de filtro (é o contrato do cliente HTTP de `/api/plpcg/praises`).
9. **§2.2 — persistência.** A chave `catalogFilters` fica; o formato novo é versionado (`{"v": 2, "tonalities": […], "rhythms": […], "categories": […], "tags": […], "materialKinds": […]}`). Qualquer outro conteúdo (o velho `{materials, arranjos}`, JSON ilegível) é descartado e a pref apagada na leitura.
10. **§2.1 — /letra sem Isar.** O spec não fala do leitor de letra; sem Isar o material «Letra» continua no card (a letra vem no dump), e o leitor passa a ler a linha via `coldigomCatalogRowProvider` (Isar ou memória).
11. **Estados transitórios entre tarefas** (a branch só sai inteira, spec §11): entre a Task 6 e a 7 a /biblioteca não tem painel de filtros; entre a Task 7 e a 8 a busca local da página inicial ainda junta manifesto + índice (já filtrada pelo predicado novo).

## Mapa de ficheiros

| Tarefa | Cria | Modifica | Apaga |
|---|---|---|---|
| 1 `shortId` (C3) | `lib/features/coldigom/domain/utils/praise_short_id.dart`, `test/unit/features/coldigom/praise_short_id_test.dart` | `coldigom_catalog_dto.dart`, `praise_dto.dart`, `coldigom_praise_cache.dart` (+ `.g.dart`), `coldigom_praise_cache_mapper.dart`, `coldigom_praise_metadata.dart`, `coldigom_louvor_adapter.dart`, `test/fixtures/coldigom_catalog_sample.json` | — |
| 2 Mapas do índice (C4) | `test/helpers/coldigom_catalog_test_helpers.dart` | `coldigom_search_index.dart`, `coldigom_search_index_test.dart`, `coldigom_catalog_hydration_test.dart` | — |
| 3 Catálogo em memória (C6) | — | `sync_coldigom_catalog.dart`, `coldigom_catalog_providers.dart`, `sync_coldigom_catalog_test.dart`, `coldigom_catalog_hydration_test.dart` | — |
| 4 Estado do índice + /letra | `test/unit/features/coldigom/catalog_index_status_provider_test.dart` | `coldigom_catalog_providers.dart`, `lyrics_reader_screen.dart`, helper de teste, `coldigom_catalog_hydration_test.dart`, `lyrics_reader_screen_test.dart` | — |
| 5 Opções de filtro | `catalog_tag_hierarchy.dart`, `catalog_filter_options.dart`, `catalog_filter_options_provider.dart`, `test/unit/features/catalog/catalog_filter_options_test.dart` | — | — |
| 6 /biblioteca local | `test/unit/features/library/library_group_results_provider_test.dart` | `library_group_results_provider.dart`, `library_screen.dart`, `library_providers.dart`, `library_url_builder.dart`, `url_sync_params.dart`, `app_router.dart`, repositório/remote/cache writer/DTO/endpoints Coldigom, `louvor_classification.dart`, arb + gerados, testes | modo Coldigom da biblioteca, browse remoto, lastGood, facets, arranjo especial, worker, `BrowseLibrary`, `FilterBySpecialArrangement` (lista na tarefa) |
| 7 Filtros únicos | `matches_catalog_filters.dart`, `catalog_filter_sections.dart`, testes novos | `catalog_filter_state.dart`, `catalog_filters_provider.dart`, `filters_panel.dart`, `catalog_query.dart`, `plpcg_search_index.dart`, `catalog_materials.dart`, `louvor_classification.dart`, `home_search_provider.dart`, `home_screen.dart`, `home_empty_state.dart`, `home_url_builder.dart`, `url_sync_params.dart`, `app_router.dart`, `library_group_results_provider.dart`, `library_screen.dart`, testes | `category_filters.dart`, `classification_filters.dart`, `filter_by_material_and_arranjo.dart`, testes deles |
| 8 Página inicial só do índice | — | `home_search_provider.dart`, `home_remote_search_provider.dart`, `known_praise_ids_provider.dart`, `home_search_state.dart`, `home_screen.dart`, `shell_scaffold.dart` (comentário), arb + gerados, testes | — |
| 9 Varredura | — | só o que a varredura achar | — |

Todos os paths são relativos à raiz do repo. Comandos de teste: `flutter test <path>`; ao fim de cada tarefa, `flutter analyze` também.

---
## Unidade 1 — `shortId` e índice

### Task 1: `shortId` de praise atravessa DTO → Isar → detalhe → metadados (C3)

**Files:**
- Create: `lib/features/coldigom/domain/utils/praise_short_id.dart`
- Modify: `lib/features/coldigom/data/models/coldigom_catalog_dto.dart` (`ColdigomCatalogPraiseDto`)
- Modify: `lib/features/coldigom/data/models/praise_dto.dart` (`PraiseSummaryDto`, `PraiseDetailDto`)
- Modify: `lib/core/database/collections/coldigom_praise_cache.dart` (+ regenerar `coldigom_praise_cache.g.dart`)
- Modify: `lib/features/coldigom/data/mappers/coldigom_praise_cache_mapper.dart`
- Modify: `lib/features/coldigom/domain/entities/coldigom_praise_metadata.dart`
- Modify: `lib/features/coldigom/data/adapters/coldigom_louvor_adapter.dart` (`toMetadata`)
- Modify: `test/fixtures/coldigom_catalog_sample.json`
- Test: `test/unit/features/coldigom/praise_short_id_test.dart` (novo)

**Interfaces:**
- Consumes: contrato C1 do plano 0 — `"shortId": "<hex>"` em cada praise do dump (omitido se nulo); `"short_id"` em `GET /api/praises/:id` e nos itens de `GET /api/plpcg/praises`.
- Produces: `String? normalizePraiseShortId(Object? raw)`; `ColdigomCatalogPraiseDto.shortId`, `PraiseDetailDto.shortId`, `PraiseSummaryDto.shortId`, `ColdigomPraiseCache.shortId`, `ColdigomPraiseMetadata.shortId` — todos `String?`, já normalizados (minúsculas), construtores com `this.shortId` **opcional** (nenhum chamador existente muda).

- [ ] **Step 1: Fixture com `shortId`**

Em `test/fixtures/coldigom_catalog_sample.json`, acrescentar `"shortId"` a dois praises (o terceiro fica sem, para cobrir o nulo):
- no objeto de `"id": "p-001"`, logo depois de `"id": "p-001",`, a linha `"shortId": "000",`;
- no objeto de `"id": "p-002"`, logo depois de `"id": "p-002",`, a linha `"shortId": "0a1",`.

- [ ] **Step 2: Escrever o teste que falha**

```dart
// test/unit/features/coldigom/praise_short_id_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:coldigui/core/database/collections/coldigom_praise_cache.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/coldigom/data/adapters/coldigom_louvor_adapter.dart';
import 'package:coldigui/features/coldigom/data/mappers/coldigom_praise_cache_mapper.dart';
import 'package:coldigui/features/coldigom/data/models/coldigom_catalog_dto.dart';
import 'package:coldigui/features/coldigom/data/models/praise_dto.dart';
import 'package:coldigui/features/coldigom/domain/utils/praise_short_id.dart';
import 'package:flutter_test/flutter_test.dart';

ColdigomCatalogDto _catalog() => ColdigomCatalogDto.fromJson(
  jsonDecode(
    File('test/fixtures/coldigom_catalog_sample.json').readAsStringSync(),
  ) as Map<String, dynamic>,
);

void main() {
  group('normalizePraiseShortId', () {
    test('aceita [0-9a-f]{3,8}; normaliza maiúsculas e espaços', () {
      expect(normalizePraiseShortId('1a2'), '1a2');
      expect(normalizePraiseShortId(' 0A1 '), '0a1');
      expect(normalizePraiseShortId('1000'), '1000');
      expect(normalizePraiseShortId('abcdef01'), 'abcdef01');
    });

    test('fora do padrão, vazio ou não-string → null (nunca lança)', () {
      for (final raw in <Object?>[
        null,
        '',
        '12',
        '123456789',
        'xyz',
        '1g2',
        7,
      ]) {
        expect(normalizePraiseShortId(raw), isNull, reason: '$raw');
      }
    });
  });

  group('shortId atravessa as camadas', () {
    test('dump: um shortId por praise; ausente fica null', () {
      final praises = _catalog().praises;

      expect(praises[0].shortId, '000');
      expect(praises[1].shortId, '0a1');
      expect(praises[2].shortId, isNull);
    });

    test('dump com shortId inválido vira null sem derrubar o praise', () {
      final dto = ColdigomCatalogPraiseDto.fromJson({
        'id': 'p',
        'shortId': 'ZZ',
        'materials': <Object>[],
      });

      expect(dto.id, 'p');
      expect(dto.shortId, isNull);
    });

    test('API: short_id no detalhe e no resumo', () {
      final detail = PraiseDetailDto.fromJson({
        'id': 'p1',
        'name': 'Hino',
        'short_id': '00F',
      });
      final summary = PraiseSummaryDto.fromJson({
        'id': 'p1',
        'name': 'Hino',
        'short_id': '00f',
      });

      expect(detail.shortId, '00f');
      expect(summary.shortId, '00f');
      expect(PraiseDetailDto.fromJson({'id': 'p2', 'name': 'x'}).shortId, isNull);
    });

    test('linha Isar → detalhe → metadados preservam o shortId', () {
      final catalog = _catalog();
      final row = ColdigomPraiseCacheMapper.fromCatalogPraise(
        catalog.praises.first,
        kindNames: catalog.kindNames,
      );

      expect(row.shortId, '000');
      final detail = ColdigomPraiseCacheMapper.toPraiseDetail(row);
      expect(detail.shortId, '000');
      expect(ColdigomLouvorAdapter.toMetadata(detail).shortId, '000');
      expect(ColdigomPraiseCache().shortId, isNull);
    });

    test('página remota e adoção de «novos» levam o shortId à linha', () {
      final detail = PraiseDetailDto.fromJson({
        'id': 'p9',
        'name': 'Novo',
        'number': '9',
        'short_id': 'a0b',
        'materials': [
          {
            'id': 'm1',
            'type': 'pdf',
            'r2_key': 'assets/praises/p9/m1.pdf',
            'material_kind': 'k1',
          },
        ],
      });

      expect(
        ColdigomPraiseCacheMapper.fromPraiseDetail(
          detail,
          kindNames: const {},
        ).shortId,
        'a0b',
      );

      final group = LouvorGroup.fromLouvores(
        ColdigomLouvorAdapter.toLouvores(detail),
        coldigomMetaByGroupId: {'p9': ColdigomLouvorAdapter.toMetadata(detail)},
      ).single;
      expect(ColdigomPraiseCacheMapper.fromLouvorGroup(group).shortId, 'a0b');
    });
  });
}
```

- [ ] **Step 3: Correr e ver falhar**

Run: `flutter test test/unit/features/coldigom/praise_short_id_test.dart`
Expected: FAIL — `praise_short_id.dart` não existe / `shortId` não é membro.

- [ ] **Step 4: Normalizador**

```dart
// lib/features/coldigom/domain/utils/praise_short_id.dart

/// `shortId` de praise no coldigom (spec fim-fonte §7.1): hex minúsculo de 3
/// a 8 dígitos, **sempre string** — nunca `int.parse` (`00f` ≠ `f`).
final _praiseShortIdPattern = RegExp(r'^[0-9a-f]{3,8}$');

/// [raw] normalizado (trim + minúsculas) quando é um `shortId` válido; senão
/// `null`. Tolerante como os DTOs (C.8): tipo errado não lança.
///
/// Usado pelos DTOs (dump e API), pelo índice (`groupByShortId`) e pelo
/// leitor do link `?p=` (plano 2).
String? normalizePraiseShortId(Object? raw) {
  if (raw is! String) return null;
  final value = raw.trim().toLowerCase();
  return _praiseShortIdPattern.hasMatch(value) ? value : null;
}
```

- [ ] **Step 5: DTOs**

Em `lib/features/coldigom/data/models/coldigom_catalog_dto.dart`:
1. Acrescentar o import `import '../../domain/utils/praise_short_id.dart';`.
2. No construtor de `ColdigomCatalogPraiseDto`, depois de `required this.materials,`, acrescentar `this.shortId,`.
3. Depois do campo `materials`, acrescentar:

```dart
  /// `shortId` do praise ([normalizePraiseShortId]); `null` quando o dump
  /// não o traz (praise sem `short_id` no coldigom) ou é inválido.
  final String? shortId;
```

4. Em `ColdigomCatalogPraiseDto.fromJson`, dentro do `return ColdigomCatalogPraiseDto(`, depois de `id: id,`, acrescentar `shortId: normalizePraiseShortId(json['shortId']),`.

Em `lib/features/coldigom/data/models/praise_dto.dart`:
1. Acrescentar o import `import '../../domain/utils/praise_short_id.dart';`.
2. `PraiseSummaryDto`: no construtor, depois de `this.tagNames = const [],`, acrescentar `this.shortId,`; depois do campo `tagNames`, o campo

```dart
  /// `short_id` do praise ([normalizePraiseShortId]); `null` se ausente.
  final String? shortId;
```

e em `fromJson`, depois de `tagNames: splitColdigomCsv(json['tag_names']),`, `shortId: normalizePraiseShortId(json['short_id']),`.
3. `PraiseDetailDto`: no construtor, depois de `this.lyricsExcerpt,`, acrescentar `this.shortId,`; depois do campo `lyricsExcerpt`, o mesmo campo `shortId` (mesmo doc); em `fromJson`, depois de `lyricsExcerpt: json['lyrics_excerpt'] as String?,`, `shortId: normalizePraiseShortId(json['short_id']),`.

- [ ] **Step 6: Isar (aditivo, anulável)**

Em `lib/core/database/collections/coldigom_praise_cache.dart`, depois de `late String searchTokens;`:

```dart

  /// `shortId` do praise (hex `[0-9a-f]{3,8}`) — chave do link de lista por
  /// louvor (spec fim-fonte §4). Nulo em linhas gravadas antes de o dump o
  /// trazer: o ETag muda com o campo novo e o próximo sync regrava tudo.
  /// Propriedade aditiva, sem migração (precedente: `LouvorCache.shortId`).
  String? shortId;
```

Regenerar: `dart run build_runner build --delete-conflicting-outputs` (deve mudar só `lib/core/database/collections/coldigom_praise_cache.g.dart`; conferir com `git status --short`).

- [ ] **Step 7: Mapper**

Em `lib/features/coldigom/data/mappers/coldigom_praise_cache_mapper.dart`:
1. Em `_row`, acrescentar o parâmetro `String? shortId,` (depois de `required List<ColdigomCatalogMaterialEntry> materials,`) e, na cascata, `..shortId = shortId` depois de `..materialsJson = …`.
2. `fromCatalogPraise`: passar `shortId: praise.shortId,` ao `_row`.
3. `fromPraiseDetail`: passar `shortId: praise.shortId,`.
4. `fromLouvorGroup`: passar `shortId: meta?.shortId,`.
5. `toPraiseDetail`: no `return PraiseDetailDto(`, acrescentar `shortId: row.shortId,`.

- [ ] **Step 8: Metadados e adapter**

Em `lib/features/coldigom/domain/entities/coldigom_praise_metadata.dart`: construtor ganha `this.shortId,` (depois de `this.lyricsExcerpt,`) e o campo

```dart
  /// `shortId` do praise — chave do link por louvor (`?p=`, plano 2) e do
  /// mapa `ColdigomSearchIndex.groupByShortId`. `null` quando o coldigom
  /// ainda não o expõe para este praise.
  final String? shortId;
```

`hasAnyField` não muda (o `shortId` não é mostrado no sheet).

Em `lib/features/coldigom/data/adapters/coldigom_louvor_adapter.dart`, em `toMetadata`, acrescentar `shortId: praise.shortId,` ao construtor.

- [ ] **Step 9: Correr e ver passar**

Run: `flutter test test/unit/features/coldigom/`
Expected: PASS — o teste novo e os existentes (`coldigom_catalog_dto_test`, `coldigom_praise_cache_mapper_test`, `coldigom_catalog_hydration_test`, `sync_coldigom_catalog_test`) continuam verdes com a fixture nova.
Run: `flutter analyze`
Expected: sem issues.

- [ ] **Step 10: Commit**

```bash
git add lib/features/coldigom/domain/utils/praise_short_id.dart lib/features/coldigom/data/models/coldigom_catalog_dto.dart lib/features/coldigom/data/models/praise_dto.dart lib/core/database/collections/coldigom_praise_cache.dart lib/core/database/collections/coldigom_praise_cache.g.dart lib/features/coldigom/data/mappers/coldigom_praise_cache_mapper.dart lib/features/coldigom/domain/entities/coldigom_praise_metadata.dart lib/features/coldigom/data/adapters/coldigom_louvor_adapter.dart test/fixtures/coldigom_catalog_sample.json test/unit/features/coldigom/praise_short_id_test.dart
git commit -m "feat(coldigom): shortId de praise do dump até aos metadados do grupo

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: `ColdigomSearchIndex` com `groups`, `groupByShortId` e `groupForMaterialId` (C4)

**Files:**
- Modify: `lib/features/coldigom/domain/search/coldigom_search_index.dart` (classe `ColdigomSearchIndex`; `ColdigomIndexedPraise` não muda)
- Create: `test/helpers/coldigom_catalog_test_helpers.dart`
- Test: `test/unit/features/coldigom/coldigom_search_index_test.dart` (acrescentar grupo), `test/unit/features/coldigom/coldigom_catalog_hydration_test.dart` (asserções no 1.º teste)

**Interfaces:**
- Consumes: `ColdigomPraiseMetadata.shortId`, `normalizePraiseShortId` (Task 1).
- Produces:
  - `List<LouvorGroup> ColdigomSearchIndex.groups` — os grupos das entries, na ordem das entries (é o que a /biblioteca ordena e as opções de filtro varrem).
  - `LouvorGroup? ColdigomSearchIndex.groupByShortId(String shortId)` — normaliza a entrada com `normalizePraiseShortId`.
  - `LouvorGroup? ColdigomSearchIndex.groupForMaterialId(String entryId)` — qualquer `CatalogMaterial.id` do grupo.
  - Helpers de teste (usados pelas Tasks 4–8): `LouvorGroup catalogGroup({required String praiseId, required String name, String number = '', String tonality = '', String rhythm = '', String category = '', List<String> tags = const [], Map<String, String> pdfKinds = const {'k-partitura': 'Partitura'}, Map<String, String> audioKinds = const {}, String? shortId})` e `ColdigomSearchIndex catalogIndexOf(List<LouvorGroup> groups)`.

- [ ] **Step 1: Helper de teste**

```dart
// test/helpers/coldigom_catalog_test_helpers.dart
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/coldigom/data/adapters/coldigom_louvor_adapter.dart';
import 'package:coldigui/features/coldigom/data/mappers/coldigom_praise_cache_mapper.dart';
import 'package:coldigui/features/coldigom/data/models/praise_dto.dart';
import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';

/// Um praise do catálogo montado como a hidratação o monta (adapter +
/// `coldigomMeta`) — para testes de filtros, /biblioteca e página inicial
/// sem Isar nem rede.
///
/// [pdfKinds]/[audioKinds]: `kindId → nome do kind`; cada entrada vira um
/// material (`pdf`/`mp3`) com `materialKindId`. Precisa de pelo menos um
/// material, senão não há grupo.
LouvorGroup catalogGroup({
  required String praiseId,
  required String name,
  String number = '',
  String tonality = '',
  String rhythm = '',
  String category = '',
  List<String> tags = const [],
  Map<String, String> pdfKinds = const {'k-partitura': 'Partitura'},
  Map<String, String> audioKinds = const {},
  String? shortId,
}) {
  final materials = <MaterialDto>[
    for (final kind in pdfKinds.entries)
      MaterialDto(
        id: 'pdf-${kind.key}',
        type: 'pdf',
        r2Key: 'assets/praises/$praiseId/pdf-${kind.key}.pdf',
        materialKindId: kind.key,
        materialKindName: kind.value,
      ),
    for (final kind in audioKinds.entries)
      MaterialDto(
        id: 'mp3-${kind.key}',
        type: 'mp3',
        r2Key: 'assets/praises/$praiseId/mp3-${kind.key}.mp3',
        materialKindId: kind.key,
        materialKindName: kind.value,
      ),
  ];
  final detail = PraiseDetailDto(
    id: praiseId,
    name: name,
    number: number,
    rhythm: rhythm,
    tonality: tonality,
    category: category,
    tagNames: tags,
    shortId: shortId,
    materials: materials,
  );
  return LouvorGroup.fromLouvores(
    ColdigomLouvorAdapter.toLouvores(detail),
    audioTracks: ColdigomLouvorAdapter.toAudioTracks(detail),
    coldigomMetaByGroupId: {praiseId: ColdigomLouvorAdapter.toMetadata(detail)},
  ).single;
}

/// Índice com [groups], tokens de busca calculados como no sync.
ColdigomSearchIndex catalogIndexOf(List<LouvorGroup> groups) {
  return ColdigomSearchIndex.build([
    for (final group in groups)
      ColdigomIndexedPraise.build(
        praiseId: group.groupId,
        numero: group.numero,
        nome: group.nome,
        searchTokens: ColdigomPraiseCacheMapper.buildSearchTokens(
          name: group.nome,
          number: group.numero,
          author: group.coldigomMeta?.author ?? '',
          tags: group.coldigomMeta?.tagNames ?? const [],
        ),
        group: group,
      ),
  ]);
}
```

- [ ] **Step 2: Testes que falham**

Em `test/unit/features/coldigom/coldigom_search_index_test.dart`, acrescentar o import `import '../../../helpers/coldigom_catalog_test_helpers.dart';` e, no fim de `main()`, o grupo:

```dart
  group('mapas O(1) (C4)', () {
    final aleluia = catalogGroup(
      praiseId: 'p1',
      number: '001',
      name: 'Aleluia',
      shortId: '000',
      pdfKinds: const {'k-grade': 'Grade'},
      audioKinds: const {'k-play': 'Playback'},
    );
    final semShortId = catalogGroup(
      praiseId: 'p2',
      number: '002',
      name: 'Sem shortId',
    );
    final mapped = catalogIndexOf([aleluia, semShortId]);

    test('groups segue a ordem das entries; vazio no índice vazio', () {
      expect(mapped.groups.map((g) => g.groupId), ['p1', 'p2']);
      expect(ColdigomSearchIndex.empty.groups, isEmpty);
    });

    test('groupByShortId acha o praise, normaliza a entrada e ignora inválidos', () {
      expect(mapped.groupByShortId('000')?.groupId, 'p1');
      expect(mapped.groupByShortId(' 000 ')?.groupId, 'p1');
      expect(mapped.groupByShortId('fff'), isNull);
      expect(mapped.groupByShortId('zz'), isNull);
      expect(ColdigomSearchIndex.empty.groupByShortId('000'), isNull);
    });

    test('groupForMaterialId cobre todo material do grupo', () {
      expect(aleluia.materials, hasLength(2));
      for (final material in aleluia.materials) {
        expect(
          mapped.groupForMaterialId(material.id)?.groupId,
          'p1',
          reason: material.id,
        );
      }
      expect(mapped.groupForMaterialId('desconhecido'), isNull);
    });
  });
```

Em `test/unit/features/coldigom/coldigom_catalog_hydration_test.dart`, acrescentar o import `import 'package:coldigui/core/utils/pdf_id_codec.dart';` e, no teste `'hidrata caches e índice a partir do Isar, sem tocar na rede'`, logo antes de `expect(remote.calls, 0);`:

```dart
    // C4: shortId e ids de material de qualquer tipo apontam para o grupo.
    expect(index.groupByShortId('000')?.groupId, 'p-001');
    expect(index.groupByShortId('0A1')?.groupId, 'p-002');
    for (final id in [
      encodePdfId('assets/praises/p-001/m-pdf.pdf'),
      encodePdfId('assets/praises/p-001/m-chord.chord'),
      encodePdfId('assets/praises/p-001/m-gest.gestures'),
      encodePdfId('assets/praises/p-001/m-mp3.mp3'),
      'lyrics:p-001',
      'yt-1',
    ]) {
      expect(index.groupForMaterialId(id)?.groupId, 'p-001', reason: id);
    }
    expect(
      index.groupForMaterialId(encodePdfId('assets/praises/p-002/m-odd.m4a'))
          ?.groupId,
      'p-002',
    );
```

- [ ] **Step 3: Correr e ver falhar**

Run: `flutter test test/unit/features/coldigom/coldigom_search_index_test.dart test/unit/features/coldigom/coldigom_catalog_hydration_test.dart`
Expected: FAIL — `groups`/`groupByShortId`/`groupForMaterialId` não existem.

- [ ] **Step 4: Implementação**

Em `lib/features/coldigom/domain/search/coldigom_search_index.dart`, acrescentar os imports `import '../utils/praise_short_id.dart';` e substituir a classe `ColdigomSearchIndex` inteira (até antes de `List<LouvorGroup> search(String query)`, que fica igual) por:

```dart
/// Índice de busca do acervo Coldigom — espelho de `PlpcgSearchIndex`.
///
/// Mesmo ranking de `SearchLouvorByNumberOrText.callIndexed` (número exato →
/// título exato → parcial), sobre praises em vez de `Louvor`: no Coldigom a
/// unidade da Home é o grupo, e ele já sai montado daqui.
///
/// Também é **o** catálogo do app (spec fim-fonte §2.1): [groups] alimenta a
/// /biblioteca e as opções de filtro, e os mapas de [groupByShortId] (link
/// por louvor) e [groupForMaterialId] (entrada de playlist → louvor) são
/// montados uma vez por hidratação.
final class ColdigomSearchIndex {
  const ColdigomSearchIndex._(
    this.entries,
    this.groups,
    this.praiseIds,
    this.catalogIds,
    this._groupByShortId,
    this._groupByMaterialId,
  );

  /// Índice vazio — antes da hidratação e em modo degradado.
  static const empty = ColdigomSearchIndex._(
    <ColdigomIndexedPraise>[],
    <LouvorGroup>[],
    <String>{},
    <String>{},
    <String, LouvorGroup>{},
    <String, LouvorGroup>{},
  );

  /// [catalogIds] é o Isar inteiro (inclui praises sem material endereçável,
  /// ex. só YouTube, que ficam fora de [entries]/[praiseIds]) — quando
  /// omitido cai para os ids das [entries]. Ver [catalogIds].
  factory ColdigomSearchIndex.build(
    List<ColdigomIndexedPraise> entries, {
    Set<String>? catalogIds,
  }) {
    if (entries.isEmpty && (catalogIds == null || catalogIds.isEmpty)) {
      return empty;
    }
    final praiseIds = Set<String>.unmodifiable({
      for (final e in entries) e.praiseId,
    });
    final byShortId = <String, LouvorGroup>{};
    final byMaterialId = <String, LouvorGroup>{};
    for (final entry in entries) {
      final shortId = entry.group.coldigomMeta?.shortId;
      if (shortId != null) byShortId.putIfAbsent(shortId, () => entry.group);
      for (final material in entry.group.materials) {
        byMaterialId.putIfAbsent(material.id, () => entry.group);
      }
    }
    return ColdigomSearchIndex._(
      List<ColdigomIndexedPraise>.unmodifiable(entries),
      List<LouvorGroup>.unmodifiable([for (final e in entries) e.group]),
      praiseIds,
      catalogIds == null ? praiseIds : Set<String>.unmodifiable(catalogIds),
      Map<String, LouvorGroup>.unmodifiable(byShortId),
      Map<String, LouvorGroup>.unmodifiable(byMaterialId),
    );
  }

  final List<ColdigomIndexedPraise> entries;

  /// Um grupo por entry, na ordem das [entries] — o catálogo inteiro que a
  /// /biblioteca filtra e ordena.
  final List<LouvorGroup> groups;

  /// Ids no índice de busca (com material endereçável) — é contra isto que
  /// a busca textual local decide match; ver [ColdigomIndexedPraise.build].
  final Set<String> praiseIds;

  /// Todo o Isar, [praiseIds] incluído — é contra isto que a pesquisa remota
  /// (plano 3, §6.2) decide o que é «novo» (`HomeSearchState.knownIds`): um
  /// praise já adotado no Isar (mesmo sem entrar no índice de busca, ex.
  /// só-YouTube) não deve continuar a levar o chip «novo» pra sempre.
  final Set<String> catalogIds;

  final Map<String, LouvorGroup> _groupByShortId;
  final Map<String, LouvorGroup> _groupByMaterialId;

  bool get isEmpty => entries.isEmpty;

  /// Grupo do praise com [shortId] (link `?p=`, spec §4.3); a entrada é
  /// normalizada (`0A1` → `0a1`). `null` para inválido ou desconhecido.
  LouvorGroup? groupByShortId(String shortId) {
    final normalized = normalizePraiseShortId(shortId);
    return normalized == null ? null : _groupByShortId[normalized];
  }

  /// Grupo ao qual pertence a entrada de playlist [entryId] — qualquer id de
  /// `LouvorGroup.materials` (pdfId, audioId, chordId, gestureId,
  /// `lyrics:<praiseId>`, id do material YouTube). Usa o material do
  /// catálogo, não o path do id: 64 materiais movidos têm o path na pasta
  /// de outro praise (desvio 2 do spec de 18/09).
  LouvorGroup? groupForMaterialId(String entryId) =>
      _groupByMaterialId[entryId];
```

(O método `search` continua depois disto, sem mudanças.)

- [ ] **Step 5: Correr e ver passar**

Run: `flutter test test/unit/features/coldigom/`
Expected: PASS.
Run: `flutter analyze`
Expected: sem issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/coldigom/domain/search/coldigom_search_index.dart test/helpers/coldigom_catalog_test_helpers.dart test/unit/features/coldigom/coldigom_search_index_test.dart test/unit/features/coldigom/coldigom_catalog_hydration_test.dart
git commit -m "feat(coldigom): índice expõe os grupos e mapas por shortId e por material

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---
## Unidade 2 — Caminho em memória (C6)

### Task 3: sem Isar, o dump vai para a memória e o índice hidrata dele

**Files:**
- Modify: `lib/features/coldigom/domain/usecases/sync_coldigom_catalog.dart`
- Modify: `lib/features/coldigom/presentation/providers/coldigom_catalog_providers.dart` (hidratação, provider em memória, `requestSyncIfStale`, `_run`, `export`)
- Test: `test/unit/features/coldigom/sync_coldigom_catalog_test.dart`, `test/unit/features/coldigom/coldigom_catalog_hydration_test.dart`

**Interfaces:**
- Consumes: `ColdigomPraiseCache.shortId` (Task 1), `ColdigomSearchIndex.groupByShortId` (Task 2).
- Produces:
  - `final class ColdigomCatalogSyncInMemory extends ColdigomCatalogSyncResult { const ColdigomCatalogSyncInMemory(this.rows); final List<ColdigomPraiseCache> rows; int get count; }` — exportada por `coldigom_catalog_providers.dart`.
  - `coldigomInMemoryCatalogProvider` — `NotifierProvider<ColdigomInMemoryCatalogNotifier, List<ColdigomPraiseCache>>`; `void replace(List<ColdigomPraiseCache> rows)`.
  - `coldigomCatalogHydrationProvider` passa a hidratar das linhas em memória quando `awaitIsarSettled` ≠ `available`.
  - `ColdigomCatalogSyncNotifier.requestSyncIfStale()`: espera o Isar assentar; sem Isar não usa o `syncedAt` das prefs; sem catálogo e sem rede grava `lastResult = ColdigomCatalogSyncFailed('sem rede')` (lido pela Task 4).

**Porquê assim:** hoje sem Isar o `_run` devolve `ColdigomCatalogSyncFailed('Isar indisponível')` e o índice fica vazio — a página inicial e a /biblioteca só funcionavam sem Isar porque o manifesto ia para a memória (M7). O mesmo contrato passa a valer para o dump. Com Isar, nada muda (Desvio 6).

- [ ] **Step 1: Testes do use case que falham**

Em `test/unit/features/coldigom/sync_coldigom_catalog_test.dart`, **substituir** o último teste (`'sem Isar → failed com StorageUnavailableException, sem gravar etag'`) por estes dois:

```dart
  test(
    'sem Isar → dump em memória: nada gravado, pedido sem If-None-Match',
    () async {
      await metadata.markReplaced(
        etag: '"v0"',
        count: 3,
        at: DateTime.utc(2026, 1, 1),
      );
      final remote = _ScriptedRemote(
        (_) async => ColdigomCatalogFresh(catalog: _catalog(), etag: '"v1"'),
      );
      final degraded = SyncColdigomCatalog(
        remote: remote,
        local: const ColdigomCatalogLocalDatasource.unavailable(),
        metadata: metadata,
        now: () => fixedNow,
      );

      final result = await degraded.run();

      expect(result, isA<ColdigomCatalogSyncInMemory>());
      final inMemory = result as ColdigomCatalogSyncInMemory;
      expect(inMemory.count, 3);
      expect(inMemory.rows.map((r) => r.praiseId), ['p-001', 'p-002', 'p-003']);
      expect(inMemory.rows.first.shortId, '000');
      // O ETag guardado é de um Isar que não está aqui: pede o corpo inteiro.
      expect(remote.ifNoneMatches, [null]);
      // Nada de metadados: o próximo arranque sem Isar baixa de novo.
      expect(metadata.readEtag(), '"v0"');
      expect(metadata.readSyncedAt(), DateTime.utc(2026, 1, 1));
    },
  );

  test('sem Isar e dump vazio → failed (nunca um catálogo vazio)', () async {
    final remote = _ScriptedRemote(
      (_) async => const ColdigomCatalogFresh(
        catalog: ColdigomCatalogDto(generatedAt: '', kindNames: {}, praises: []),
        etag: '"v2"',
      ),
    );
    final degraded = SyncColdigomCatalog(
      remote: remote,
      local: const ColdigomCatalogLocalDatasource.unavailable(),
      metadata: metadata,
      now: () => fixedNow,
    );

    final result = await degraded.run();

    expect(result, isA<ColdigomCatalogSyncFailed>());
    expect((result as ColdigomCatalogSyncFailed).cause, 'dump vazio');
  });
```

- [ ] **Step 2: Testes da hidratação que falham**

Em `test/unit/features/coldigom/coldigom_catalog_hydration_test.dart`, **substituir** o teste `'sem Isar: índice vazio e sync falha sem gravar'` por:

```dart
  test('sem Isar: o sync baixa o dump para a memória e o índice hidrata dele', () async {
    final remote = _ScriptedRemote(
      () async => ColdigomCatalogFresh(catalog: _catalog(), etag: '"v1"'),
    );
    // Offline: o `requestSyncIfStale` do boot não corre em paralelo com o
    // `sync()` explícito deste teste.
    final c = container(remote: remote, isarAvailable: false, online: false);

    expect(
      (await c.read(coldigomCatalogHydrationProvider.future)).isEmpty,
      isTrue,
    );
    final result = await c.read(coldigomCatalogSyncProvider.notifier).sync();

    expect(result, isA<ColdigomCatalogSyncInMemory>());
    final index = await c.read(coldigomCatalogHydrationProvider.future);
    expect(index.praiseIds, {'p-001', 'p-002'});
    expect(index.catalogIds, {'p-001', 'p-002', 'p-003'});
    expect(index.groupByShortId('000')?.groupId, 'p-001');
    expect(c.read(coldigomLouvoresCacheProvider), hasLength(1));
    expect(c.read(coldigomInMemoryCatalogProvider), hasLength(3));
    final state = c.read(coldigomCatalogSyncProvider);
    expect(state.lastResult, isA<ColdigomCatalogSyncInMemory>());
    expect(state.isSyncing, isFalse);
    expect(state.count, 3);
    expect(state.lastSyncedAt, isNotNull);
    expect(ColdigomCatalogSyncMetadataStore(prefs).readEtag(), isNull);
    expect(remote.calls, 1);
  });

  test('sem Isar: requestSyncIfStale ignora o syncedAt das prefs e baixa o dump', () async {
    // Prefs de uma sessão anterior com Isar: «sincronizado agora mesmo».
    await ColdigomCatalogSyncMetadataStore(
      prefs,
    ).markReplaced(etag: '"v1"', count: 3, at: DateTime.now().toUtc());
    final remote = _ScriptedRemote(
      () async => ColdigomCatalogFresh(catalog: _catalog(), etag: '"v1"'),
    );
    final c = container(remote: remote, isarAvailable: false);

    // Montar o notifier agenda o `requestSyncIfStale` do boot (um só
    // caminho, sem corrida com uma chamada explícita).
    c.read(coldigomCatalogSyncProvider);
    await pumpEventQueue();

    expect(remote.calls, 1);
    expect(remote.lastIfNoneMatch, isNull);
    expect(c.read(coldigomInMemoryCatalogProvider), hasLength(3));

    // O catálogo em memória acabou de chegar: pedir de novo não rebaixa.
    await c.read(coldigomCatalogSyncProvider.notifier).requestSyncIfStale();
    expect(remote.calls, 1);
  });

  test('Isar vazio com prefs dizendo que há catálogo: sincroniza mesmo assim', () async {
    // Ex.: a web apagou o IndexedDB mas manteve o localStorage.
    await ColdigomCatalogSyncMetadataStore(
      prefs,
    ).markReplaced(etag: '"v1"', count: 3, at: DateTime.now().toUtc());
    final remote = _ScriptedRemote(
      () async => ColdigomCatalogFresh(catalog: _catalog(), etag: '"v2"'),
    );
    final c = container(remote: remote);

    c.read(coldigomCatalogSyncProvider);
    await pumpEventQueue();

    expect(remote.calls, 1);
    // Sem linhas no Isar o ETag guardado não vale (regra do use case).
    expect(remote.lastIfNoneMatch, isNull);
    expect(ColdigomCatalogLocalDatasource(isar).count(), 3);
  });
```

- [ ] **Step 3: Correr e ver falhar**

Run: `flutter test test/unit/features/coldigom/sync_coldigom_catalog_test.dart test/unit/features/coldigom/coldigom_catalog_hydration_test.dart`
Expected: FAIL — `ColdigomCatalogSyncInMemory` e `coldigomInMemoryCatalogProvider` não existem.

- [ ] **Step 4: Desfecho em memória no use case**

Em `lib/features/coldigom/domain/usecases/sync_coldigom_catalog.dart`:
1. Acrescentar o import `import '../../../../core/database/collections/coldigom_praise_cache.dart';`.
2. Depois de `ColdigomCatalogSyncFailed`, acrescentar:

```dart
/// Sem Isar (C6, spec fim-fonte §2.1): o dump foi baixado e convertido, mas
/// **não** gravado — nem linhas nem ETag. Quem hidrata lê estas [rows].
final class ColdigomCatalogSyncInMemory extends ColdigomCatalogSyncResult {
  const ColdigomCatalogSyncInMemory(this.rows);

  final List<ColdigomPraiseCache> rows;

  int get count => rows.length;
}
```

3. Trocar o doc da classe `SyncColdigomCatalog` (o parágrafo «Sem Isar a escrita lança…») por:

```dart
/// Best-effort por contrato: nunca lança. `ColdigomCatalogSyncFailed.cause`
/// existe para a tela `/offline` explicar «não foi possível atualizar»; para
/// o boot e o foreground a falha é só um `debugPrint`.
///
/// Sem Isar ([ColdigomCatalogLocalDatasource.isAvailable] `false`) o dump
/// vem sempre inteiro (sem `If-None-Match`) e volta como
/// [ColdigomCatalogSyncInMemory], sem gravar ETag — senão o próximo pedido
/// com Isar receberia `304` para um banco vazio.
```

4. Substituir o método `run()` por:

```dart
  Future<ColdigomCatalogSyncResult> run() async {
    try {
      final persist = _local.isAvailable;
      // Sem catálogo gravado (ou sem banco) o ETag guardado não vale: pedir
      // sem `If-None-Match` garante o corpo inteiro.
      final etag = !persist || _local.count() == 0 ? null : _metadata.readEtag();
      final result = await _remote.fetchCatalog(ifNoneMatch: etag);
      switch (result) {
        case ColdigomCatalogNotModified():
          // Defensivo: sem ETag o servidor não tem como responder 304.
          if (!persist) {
            return const ColdigomCatalogSyncFailed('304 sem catálogo local');
          }
          await _metadata.markValidated(_now());
          return const ColdigomCatalogSyncNoop();
        case ColdigomCatalogFresh(:final catalog, etag: final freshEtag):
          final rows = [
            for (final praise in catalog.praises)
              ColdigomPraiseCacheMapper.fromCatalogPraise(
                praise,
                kindNames: catalog.kindNames,
              ),
          ];
          // Um `200` com corpo vazio é sinal de dump quebrado no servidor,
          // não «catálogo ficou vazio» — nunca apaga um catálogo bom local.
          if (rows.isEmpty) {
            return const ColdigomCatalogSyncFailed('dump vazio');
          }
          if (!persist) return ColdigomCatalogSyncInMemory(rows);
          await _local.replaceAll(rows);
          await _metadata.markReplaced(
            etag: freshEtag,
            count: rows.length,
            at: _now(),
          );
          return ColdigomCatalogSyncReplaced(rows.length);
      }
    } on Object catch (error) {
      debugPrint('[coldigom] sync do catálogo falhou: $error');
      return ColdigomCatalogSyncFailed(error);
    }
  }
```

Remover o import de `storage_unavailable_exception.dart` se ficar sem uso (o doc deixou de o citar).

- [ ] **Step 5: Linhas em memória e hidratação**

Em `lib/features/coldigom/presentation/providers/coldigom_catalog_providers.dart`:
1. Acrescentar o import `import '../../../../core/database/collections/coldigom_praise_cache.dart';`.
2. No `export … show`, acrescentar `ColdigomCatalogSyncInMemory,`.
3. Antes de `coldigomCatalogHydrationProvider`, acrescentar:

```dart
/// Catálogo baixado **sem Isar** (C6, spec fim-fonte §2.1): as linhas do
/// dump, só em memória — o contrato que o manifesto tinha. Vazio enquanto o
/// Isar existe (aí o catálogo vive no banco) e até o primeiro sync em
/// memória terminar.
final coldigomInMemoryCatalogProvider =
    NotifierProvider<
      ColdigomInMemoryCatalogNotifier,
      List<ColdigomPraiseCache>
    >(ColdigomInMemoryCatalogNotifier.new);

class ColdigomInMemoryCatalogNotifier
    extends Notifier<List<ColdigomPraiseCache>> {
  @override
  List<ColdigomPraiseCache> build() => const [];

  /// Troca o catálogo inteiro — desfecho [ColdigomCatalogSyncInMemory].
  void replace(List<ColdigomPraiseCache> rows) {
    state = List<ColdigomPraiseCache>.unmodifiable(rows);
  }
}
```

4. Em `coldigomCatalogHydrationProvider`, trocar o início do corpo

```dart
  if (await awaitIsarSettled(ref) != IsarStatus.available) {
    return ColdigomSearchIndex.empty;
  }
  final rows = ref.read(coldigomCatalogLocalDatasourceProvider).findAllSync();
  if (rows.isEmpty) return ColdigomSearchIndex.empty;
```

por

```dart
  // Observado antes de qualquer `await`: sem Isar as linhas vêm do sync em
  // memória, e trocá-las re-hidrata sozinho.
  final memoryRows = ref.watch(coldigomInMemoryCatalogProvider);
  final List<ColdigomPraiseCache> rows;
  if (await awaitIsarSettled(ref) == IsarStatus.available) {
    rows = ref.read(coldigomCatalogLocalDatasourceProvider).findAllSync();
  } else {
    rows = memoryRows;
  }
  if (rows.isEmpty) return ColdigomSearchIndex.empty;
```

e trocar, no doc do provider, os parágrafos «Corre depois de o Isar abrir e fora do caminho crítico: a Home não espera por isto (o PLPCG aparece primeiro, como hoje)…» e «Sem Isar (modo degradado) devolve [ColdigomSearchIndex.empty]…» por:

```dart
/// Corre depois de o Isar assentar e fora do caminho crítico: a página
/// inicial e a /biblioteca mostram carregamento até o índice ter praises
/// (`catalogIndexStatusProvider`). A conversão é fatiada em
/// [OfflineConfig.coldigomHydrationChunkSize] praises com `await
/// Future.delayed(Duration.zero)` entre fatias — na web tudo corre na thread
/// de UI, e 2063 praises de uma vez atrasariam o primeiro frame.
///
/// Com Isar, lê o banco. Sem Isar (modo degradado), lê as linhas que o sync
/// baixou para [coldigomInMemoryCatalogProvider] (C6). Um sync que
/// substituiu o catálogo no Isar invalida este provider
/// ([ColdigomCatalogSyncNotifier]); o sync em memória troca as linhas
/// observadas.
```

- [ ] **Step 6: Notifier — `requestSyncIfStale` e `_run`**

No mesmo ficheiro, substituir `requestSyncIfStale` e `_run` de `ColdigomCatalogSyncNotifier` por:

```dart
  /// Sync só quando o último foi há ≥ [OfflineConfig.coldigomCatalogSyncMinInterval]
  /// (ou nunca, ou não há catálogo) **e** há rede.
  ///
  /// Espera o Isar assentar: é ele que decide entre o catálogo gravado (ETag
  /// e `syncedAt` nas prefs) e o catálogo só em memória (C6), que não
  /// sobrevive ao reinício e por isso ignora o `syncedAt` das prefs. Sem
  /// catálogo e sem rede grava a falha: é o que faz a página inicial e a
  /// /biblioteca trocarem o carregamento por erro + «tentar de novo».
  Future<void> requestSyncIfStale() async {
    final status = await awaitIsarSettled(ref);
    // Este pedido pode nascer como microtask de `build()`: se o container já
    // foi descartado nesse meio-tempo (fim de um teste, navegação que
    // desmonta o shell), `ref` não serve mais.
    if (!ref.mounted) return;
    final inMemory = status != IsarStatus.available;
    if (_hasFreshCatalog(inMemory: inMemory)) return;
    final hasConnection = await ref
        .read(deviceConnectivityProvider)
        .hasConnection();
    if (!ref.mounted) return;
    if (!hasConnection) {
      // Um sync concorrente pode ter enchido o catálogo durante os awaits.
      if (_inFlight == null && !_hasCatalog(inMemory: inMemory)) {
        state = state.copyWith(
          lastResult: const ColdigomCatalogSyncFailed('sem rede'),
        );
      }
      return;
    }
    await sync();
  }

  /// Há catálogo local? Com Isar conta as linhas (já assentado: a leitura
  /// síncrona é segura); uma leitura que falhe conta como «não há».
  bool _hasCatalog({required bool inMemory}) {
    if (inMemory) return ref.read(coldigomInMemoryCatalogProvider).isNotEmpty;
    try {
      return ref.read(coldigomCatalogLocalDatasourceProvider).count() > 0;
    } on Object {
      return false;
    }
  }

  bool _hasFreshCatalog({required bool inMemory}) {
    if (!_hasCatalog(inMemory: inMemory)) return false;
    final syncedAt = inMemory
        ? state.lastSyncedAt
        : ref.read(coldigomCatalogSyncMetadataStoreProvider).readSyncedAt();
    return syncedAt != null &&
        DateTime.now().toUtc().difference(syncedAt) <
            OfflineConfig.coldigomCatalogSyncMinInterval;
  }

  Future<ColdigomCatalogSyncResult> _run() async {
    // O shell monta (e o boot agenda `requestSyncIfStale`) enquanto o Isar
    // ainda pode estar abrindo. Sincronizar antes disso faria o use case ver
    // o datasource `.unavailable()` e tratar um catálogo bom, só ainda não
    // aberto, como ausente. Espera o Isar assentar; sem ele, o dump vai para
    // a memória (C6).
    await awaitIsarSettled(ref);
    if (!ref.mounted) return const ColdigomCatalogSyncFailed('descartado');
    state = state.copyWith(isSyncing: true);
    final result = await ref.read(syncColdigomCatalogProvider).run();
    if (!ref.mounted) return result;
    if (result is ColdigomCatalogSyncInMemory) {
      // Nada gravado: o índice re-hidrata porque observa estas linhas.
      ref.read(coldigomInMemoryCatalogProvider.notifier).replace(result.rows);
      state = state.copyWith(
        isSyncing: false,
        lastResult: result,
        lastSyncedAt: DateTime.now().toUtc(),
        count: result.count,
      );
      return result;
    }
    final metadata = ref.read(coldigomCatalogSyncMetadataStoreProvider);
    state = state.copyWith(
      isSyncing: false,
      lastResult: result,
      lastSyncedAt: metadata.readSyncedAt(),
      count: metadata.readCount(),
    );
    if (result is ColdigomCatalogSyncReplaced) {
      // O Isar mudou por baixo dos caches: re-hidrata (o índice novo troca
      // a lista local sem tocar em quem já leu `groupById`).
      ref.invalidate(coldigomCatalogHydrationProvider);
    }
    return result;
  }
```

No `build()` do notifier, trocar o comentário «Boot: em paralelo ao PLPCG, sem bloquear ninguém…» por «Boot: sem bloquear ninguém — e sem repetir o pedido se o último sync foi há pouco (o app pode reabrir muitas vezes).».

- [ ] **Step 7: Correr e ver passar**

Run: `flutter test test/unit/features/coldigom/`
Expected: PASS — inclusive `'requestSyncIfStale respeita os 30 min e a rede'` (semeia o Isar, então `_hasCatalog` é `true`) e `'sync espera o Isar abrir antes de tocar na rede/local'`.
Run: `flutter test test/widget/features/app_shell/ test/widget/features/offline/`
Expected: PASS (o shell e o /offline montam este notifier de verdade).
Run: `flutter analyze`
Expected: sem issues.

- [ ] **Step 8: Commit**

```bash
git add lib/features/coldigom/domain/usecases/sync_coldigom_catalog.dart lib/features/coldigom/presentation/providers/coldigom_catalog_providers.dart test/unit/features/coldigom/sync_coldigom_catalog_test.dart test/unit/features/coldigom/coldigom_catalog_hydration_test.dart
git commit -m "feat(coldigom): sem Isar o catálogo vai para a memória e o índice hidrata dele

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: `catalogIndexStatusProvider` e o leitor de letra sem Isar

**Files:**
- Modify: `lib/features/coldigom/presentation/providers/coldigom_catalog_providers.dart` (enum + status + linha por praise)
- Modify: `lib/features/lyrics/presentation/pages/lyrics_reader_screen.dart`
- Modify: `test/helpers/coldigom_catalog_test_helpers.dart` (fake do sync + overrides)
- Test: `test/unit/features/coldigom/catalog_index_status_provider_test.dart` (novo), `test/unit/features/coldigom/coldigom_catalog_hydration_test.dart`, `test/widget/features/lyrics/lyrics_reader_screen_test.dart`

**Interfaces:**
- Consumes: `coldigomInMemoryCatalogProvider`, `ColdigomCatalogSyncFailed('sem rede')` do `requestSyncIfStale` (Task 3).
- Produces:
  - `enum CatalogIndexStatus { loading, ready, failed }` e `final catalogIndexStatusProvider = Provider<CatalogIndexStatus>` — a UI mostra skeleton em `loading`, `catalogLoadError` + «Tentar novamente» em `failed`.
  - `final coldigomCatalogRowProvider = Provider.family<ColdigomPraiseCache?, String>` — linha do praise (Isar ou memória).
  - Helpers de teste: `class FakeColdigomCatalogSyncNotifier extends ColdigomCatalogSyncNotifier` (`syncCalls`, estado inicial injetável, sem rede) e `List<Override> catalogIndexOverrides(ColdigomSearchIndex index, {FakeColdigomCatalogSyncNotifier? sync})`.

Regra do estado (spec §2.1 «Enquanto o índice está vazio…»):
- índice com praises → `ready`;
- hidratação em curso → `loading`;
- índice vazio + sync em voo → `loading`;
- índice vazio + último sync `ColdigomCatalogSyncFailed` → `failed`;
- índice vazio sem tentativa ainda (`lastResult == null`) → `loading`;
- índice vazio depois de um sync bem-sucedido (catálogo vazio de verdade) → `ready` (lista vazia, sem skeleton eterno).

- [ ] **Step 1: Helpers de teste**

Em `test/helpers/coldigom_catalog_test_helpers.dart`, acrescentar os imports

```dart
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:flutter_riverpod/misc.dart';
```

e, no fim do ficheiro:

```dart
/// Sync do catálogo sem rede nem Isar: estado fixo e `sync()` contado.
class FakeColdigomCatalogSyncNotifier extends ColdigomCatalogSyncNotifier {
  FakeColdigomCatalogSyncNotifier([
    this.initial = const ColdigomCatalogSyncState(
      lastResult: ColdigomCatalogSyncNoop(),
    ),
  ]);

  final ColdigomCatalogSyncState initial;
  var syncCalls = 0;

  @override
  ColdigomCatalogSyncState build() => initial;

  @override
  Future<ColdigomCatalogSyncResult> sync() async {
    syncCalls++;
    return const ColdigomCatalogSyncNoop();
  }

  @override
  Future<void> requestSyncIfStale() async {}
}

/// Índice já hidratado com [index] e um sync falso — o que uma tela que lê
/// o catálogo precisa para não tocar em Isar nem rede.
List<Override> catalogIndexOverrides(
  ColdigomSearchIndex index, {
  FakeColdigomCatalogSyncNotifier? sync,
}) {
  return [
    coldigomCatalogHydrationProvider.overrideWith((ref) async => index),
    coldigomCatalogSyncProvider.overrideWith(
      () => sync ?? FakeColdigomCatalogSyncNotifier(),
    ),
  ];
}
```

- [ ] **Step 2: Testes do estado que falham**

```dart
// test/unit/features/coldigom/catalog_index_status_provider_test.dart
import 'dart:async';

import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';

void main() {
  final ready = catalogIndexOf([catalogGroup(praiseId: 'p1', name: 'Aleluia')]);

  ProviderContainer container({
    required Future<ColdigomSearchIndex> Function() hydration,
    ColdigomCatalogSyncState sync = const ColdigomCatalogSyncState(),
  }) {
    final c = ProviderContainer(
      overrides: [
        coldigomCatalogHydrationProvider.overrideWith((ref) => hydration()),
        coldigomCatalogSyncProvider.overrideWith(
          () => FakeColdigomCatalogSyncNotifier(sync),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<CatalogIndexStatus> settled(ProviderContainer c) async {
    await c.read(coldigomCatalogHydrationProvider.future);
    return c.read(catalogIndexStatusProvider);
  }

  test('índice com praises → ready, mesmo com um sync falhado', () async {
    final c = container(
      hydration: () async => ready,
      sync: const ColdigomCatalogSyncState(
        lastResult: ColdigomCatalogSyncFailed('x'),
      ),
    );
    expect(await settled(c), CatalogIndexStatus.ready);
  });

  test('hidratação em curso → loading', () {
    final pending = Completer<ColdigomSearchIndex>();
    final c = container(hydration: () => pending.future);
    expect(c.read(catalogIndexStatusProvider), CatalogIndexStatus.loading);
  });

  test('índice vazio + sync em voo → loading', () async {
    final c = container(
      hydration: () async => ColdigomSearchIndex.empty,
      sync: const ColdigomCatalogSyncState(isSyncing: true),
    );
    expect(await settled(c), CatalogIndexStatus.loading);
  });

  test('índice vazio + sync falhado → failed', () async {
    final c = container(
      hydration: () async => ColdigomSearchIndex.empty,
      sync: const ColdigomCatalogSyncState(
        lastResult: ColdigomCatalogSyncFailed('sem rede'),
      ),
    );
    expect(await settled(c), CatalogIndexStatus.failed);
  });

  test('índice vazio sem tentativa de sync ainda → loading', () async {
    final c = container(hydration: () async => ColdigomSearchIndex.empty);
    expect(await settled(c), CatalogIndexStatus.loading);
  });

  test('índice vazio depois de um sync bem-sucedido → ready', () async {
    final c = container(
      hydration: () async => ColdigomSearchIndex.empty,
      sync: const ColdigomCatalogSyncState(
        lastResult: ColdigomCatalogSyncNoop(),
      ),
    );
    expect(await settled(c), CatalogIndexStatus.ready);
  });
}
```

Em `test/unit/features/coldigom/coldigom_catalog_hydration_test.dart`, acrescentar:

```dart
  test('sem catálogo e sem rede: requestSyncIfStale deixa a UI em erro', () async {
    final remote = _ScriptedRemote(
      () async => const ColdigomCatalogNotModified(),
    );
    final c = container(remote: remote, isarAvailable: false, online: false);

    await c.read(coldigomCatalogSyncProvider.notifier).requestSyncIfStale();
    await c.read(coldigomCatalogHydrationProvider.future);

    expect(
      c.read(coldigomCatalogSyncProvider).lastResult,
      isA<ColdigomCatalogSyncFailed>(),
    );
    expect(c.read(catalogIndexStatusProvider), CatalogIndexStatus.failed);
    expect(remote.calls, 0);
  });
```

- [ ] **Step 3: Teste do leitor de letra que falha**

Em `test/widget/features/lyrics/lyrics_reader_screen_test.dart`, acrescentar o import `import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';`, a classe

```dart
/// Catálogo em memória já semeado (C6: sem Isar).
class _SeededMemoryCatalog extends ColdigomInMemoryCatalogNotifier {
  _SeededMemoryCatalog(this._rows);

  final List<ColdigomPraiseCache> _rows;

  @override
  List<ColdigomPraiseCache> build() => _rows;
}
```

e o teste:

```dart
  testWidgets('sem Isar lê a letra das linhas em memória', (tester) async {
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    await pumpApp(
      tester,
      const LyricsReaderScreen(queryParams: {'praiseId': 'p1'}),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        coldigomCatalogLocalDatasourceProvider.overrideWithValue(
          const ColdigomCatalogLocalDatasource.unavailable(),
        ),
        coldigomInMemoryCatalogProvider.overrideWith(
          () => _SeededMemoryCatalog([_row('Letra só em memória')]),
        ),
      ],
    );
    await tester.pump();

    expect(find.textContaining('Letra só em memória'), findsOneWidget);
    expect(find.text('Ainda há tempo'), findsOneWidget);
  });
```

- [ ] **Step 4: Correr e ver falhar**

Run: `flutter test test/unit/features/coldigom/catalog_index_status_provider_test.dart test/unit/features/coldigom/coldigom_catalog_hydration_test.dart test/widget/features/lyrics/lyrics_reader_screen_test.dart`
Expected: FAIL — `catalogIndexStatusProvider`/`CatalogIndexStatus` não existem; o leitor mostra «sem letra» sem Isar.

- [ ] **Step 5: Estado do índice e linha por praise**

No fim de `lib/features/coldigom/presentation/providers/coldigom_catalog_providers.dart`:

```dart
/// Onde está o índice do catálogo, para a página inicial e a /biblioteca
/// (spec fim-fonte §2.1).
enum CatalogIndexStatus {
  /// Hidratando, ou índice vazio à espera de um sync (skeleton).
  loading,

  /// Índice pronto — com praises, ou vazio depois de um sync bem-sucedido.
  ready,

  /// Índice vazio e o último sync falhou (sem rede, servidor fora):
  /// `catalogLoadError` + «Tentar novamente» → `coldigomCatalogSyncProvider.sync()`.
  failed,
}

/// [CatalogIndexStatus] derivado da hidratação e do sync.
final catalogIndexStatusProvider = Provider<CatalogIndexStatus>((ref) {
  final hydration = ref.watch(coldigomCatalogHydrationProvider);
  final index = hydration.value;
  if (index != null && !index.isEmpty) return CatalogIndexStatus.ready;
  if (hydration.isLoading) return CatalogIndexStatus.loading;
  final sync = ref.watch(coldigomCatalogSyncProvider);
  if (sync.isSyncing) return CatalogIndexStatus.loading;
  return switch (sync.lastResult) {
    null => CatalogIndexStatus.loading,
    ColdigomCatalogSyncFailed() => CatalogIndexStatus.failed,
    _ => CatalogIndexStatus.ready,
  };
});

/// Linha do catálogo do praise [praiseId] — do Isar ou, sem Isar, das linhas
/// em memória (C6). O leitor `/letra` lê a letra daqui.
final coldigomCatalogRowProvider =
    Provider.family<ColdigomPraiseCache?, String>((ref, praiseId) {
      final fromIsar = ref
          .watch(coldigomCatalogLocalDatasourceProvider)
          .findByPraiseIdSync(praiseId);
      if (fromIsar != null || praiseId.isEmpty) return fromIsar;
      for (final row in ref.watch(coldigomInMemoryCatalogProvider)) {
        if (row.praiseId == praiseId) return row;
      }
      return null;
    });
```

- [ ] **Step 6: Leitor de letra**

Em `lib/features/lyrics/presentation/pages/lyrics_reader_screen.dart`:
1. Trocar o import `import '../../../coldigom/data/providers/coldigom_catalog_data_providers.dart';` por `import '../../../coldigom/presentation/providers/coldigom_catalog_providers.dart';`.
2. No `build`, trocar

```dart
    final row = ref
        .watch(coldigomCatalogLocalDatasourceProvider)
        .findByPraiseIdSync(_praiseId);
```

por

```dart
    final row = ref.watch(coldigomCatalogRowProvider(_praiseId));
```

3. No doc da classe, trocar «Lê o texto do Isar ([coldigomCatalogLocalDatasourceProvider]), nunca da rede» por «Lê o texto da linha do catálogo ([coldigomCatalogRowProvider]: Isar, ou as linhas em memória sem Isar), nunca da rede».

- [ ] **Step 7: Correr e ver passar**

Run: `flutter test test/unit/features/coldigom/ test/widget/features/lyrics/`
Expected: PASS.
Run: `flutter analyze`
Expected: sem issues.

- [ ] **Step 8: Commit**

```bash
git add lib/features/coldigom/presentation/providers/coldigom_catalog_providers.dart lib/features/lyrics/presentation/pages/lyrics_reader_screen.dart test/helpers/coldigom_catalog_test_helpers.dart test/unit/features/coldigom/catalog_index_status_provider_test.dart test/unit/features/coldigom/coldigom_catalog_hydration_test.dart test/widget/features/lyrics/lyrics_reader_screen_test.dart
git commit -m "feat(coldigom): estado do índice para a UI e letra sem Isar

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---
## Unidade 3 — Filtros e /biblioteca

### Task 5: opções de filtro derivadas do índice local

**Files:**
- Create: `lib/features/catalog/domain/utils/catalog_tag_hierarchy.dart`
- Create: `lib/features/catalog/domain/entities/catalog_filter_options.dart`
- Create: `lib/features/catalog/presentation/providers/catalog_filter_options_provider.dart`
- Test: `test/unit/features/catalog/catalog_filter_options_test.dart` (novo)

**Interfaces:**
- Consumes: `ColdigomSearchIndex.groups` (Task 2), `coldigomSearchIndexProvider`.
- Produces:
  - `const catalogTagHierarchySeparator = ' · '`; `bool catalogTagMatches(String tag, String selected)`; `Iterable<String> catalogTagWithAncestors(String tag)`.
  - `class CatalogKindOption { const CatalogKindOption({required String id, required String name}); }` (com `==`).
  - `class CatalogFilterOptions { List<String> tonalities, rhythms, categories, tags; List<CatalogKindOption> materialKinds; static const empty; factory CatalogFilterOptions.fromGroups(Iterable<LouvorGroup> groups); }`.
  - `final catalogFilterOptionsProvider = Provider<CatalogFilterOptions>`.

Regras (spec §2.2 «Opções de cada filtro»): só valores com ≥1 praise; valores com espaços nas pontas são aparados, vazios ignorados, o resto como está (M5); tags com os ancestrais (Desvio 3); tipos por `materialKindId` dos materiais do grupo, rotulados pelo nome do kind que o dump trouxe (`categoria` do material, que vem de `kinds[].name`); tudo ordenado sem acento/caixa (`LouvorSearchTokens.normalize`), desempate pelo texto cru.

- [ ] **Step 1: Teste que falha**

```dart
// test/unit/features/catalog/catalog_filter_options_test.dart
import 'package:coldigui/features/catalog/domain/entities/catalog_filter_options.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/utils/catalog_tag_hierarchy.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_filter_options_provider.dart';
import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';

void main() {
  group('hierarquia de tags', () {
    test('o pai casa consigo e com os filhos; prefixo solto não conta', () {
      expect(catalogTagMatches('PES', 'PES'), isTrue);
      expect(catalogTagMatches('PES · 9.2026', 'PES'), isTrue);
      expect(catalogTagMatches('PES · 9.2026 · Coro', 'PES · 9.2026'), isTrue);
      expect(catalogTagMatches('PESCA', 'PES'), isFalse);
      expect(catalogTagMatches('PES', 'PES · 9.2026'), isFalse);
    });

    test('ancestrais em ordem, do mais geral à própria tag', () {
      expect(catalogTagWithAncestors('A · B · C').toList(), [
        'A',
        'A · B',
        'A · B · C',
      ]);
      expect(catalogTagWithAncestors('Avulsos').toList(), ['Avulsos']);
    });
  });

  group('CatalogFilterOptions.fromGroups', () {
    final groups = [
      catalogGroup(
        praiseId: 'p1',
        name: 'Hino',
        tonality: 'Dm',
        rhythm: 'Fox',
        category: 'Clamor',
        tags: const ['PES · 9.2026', 'Avulsos'],
        pdfKinds: const {'k-cifra1': 'Cifra I'},
      ),
      catalogGroup(
        praiseId: 'p2',
        name: 'Coro',
        tonality: ' G ',
        category: 'Adoração',
        tags: const ['avulsos'],
        pdfKinds: const {'k-grade': 'Grade'},
        audioKinds: const {'k-play': 'Playback'},
      ),
      catalogGroup(
        praiseId: 'p3',
        name: 'Outro',
        tonality: 'Dm',
        pdfKinds: const {'k-grade': 'Grade'},
      ),
      // Grupo sem meta (ex.: montado fora do catálogo): não contribui nem
      // derruba nada.
      LouvorGroup(groupId: 'x', numero: '', nome: 'x', sections: const []),
    ];
    final options = CatalogFilterOptions.fromGroups(groups);

    test('tom, ritmo e categoria: valores com praise, aparados, sem vazios', () {
      expect(options.tonalities, ['Dm', 'G']);
      expect(options.rhythms, ['Fox']);
      expect(options.categories, ['Adoração', 'Clamor']);
    });

    test('tags como estão (M5), com os ancestrais, sem acento/caixa na ordem', () {
      expect(options.tags, ['Avulsos', 'avulsos', 'PES', 'PES · 9.2026']);
    });

    test('tipos de material por id, com o nome do kind, ordenados pelo nome', () {
      expect(options.materialKinds, const [
        CatalogKindOption(id: 'k-cifra1', name: 'Cifra I'),
        CatalogKindOption(id: 'k-grade', name: 'Grade'),
        CatalogKindOption(id: 'k-play', name: 'Playback'),
      ]);
    });

    test('sem grupos → vazio', () {
      final empty = CatalogFilterOptions.fromGroups(const []);
      expect(empty.tonalities, isEmpty);
      expect(empty.tags, isEmpty);
      expect(empty.materialKinds, isEmpty);
    });
  });

  test('catalogFilterOptionsProvider lê o índice local', () {
    final container = ProviderContainer(
      overrides: [
        coldigomSearchIndexProvider.overrideWithValue(
          catalogIndexOf([
            catalogGroup(praiseId: 'p1', name: 'Hino', tonality: 'Dm'),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(catalogFilterOptionsProvider).tonalities, ['Dm']);
  });

  test('índice vazio → CatalogFilterOptions.empty', () {
    final container = ProviderContainer(
      overrides: [
        coldigomSearchIndexProvider.overrideWithValue(ColdigomSearchIndex.empty),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(catalogFilterOptionsProvider),
      same(CatalogFilterOptions.empty),
    );
  });
}
```

- [ ] **Step 2: Correr e ver falhar**

Run: `flutter test test/unit/features/catalog/catalog_filter_options_test.dart`
Expected: FAIL — ficheiros não existem.

- [ ] **Step 3: Hierarquia de tags**

```dart
// lib/features/catalog/domain/utils/catalog_tag_hierarchy.dart

/// Separador de hierarquia nas tags do coldigom (`PES · 9.2026`).
const catalogTagHierarchySeparator = ' · ';

/// `true` quando [tag] é [selected] ou um descendente dele — «o pai inclui
/// os filhos» (spec fim-fonte §2.2). `PESCA` não é filho de `PES`: o prefixo
/// tem de acabar no separador.
bool catalogTagMatches(String tag, String selected) =>
    tag == selected ||
    tag.startsWith('$selected$catalogTagHierarchySeparator');

/// [tag] e cada ancestral, do mais geral à própria tag:
/// `A · B · C` → `A`, `A · B`, `A · B · C`.
Iterable<String> catalogTagWithAncestors(String tag) sync* {
  final parts = tag.split(catalogTagHierarchySeparator);
  for (var i = 1; i <= parts.length; i++) {
    yield parts.sublist(0, i).join(catalogTagHierarchySeparator);
  }
}
```

- [ ] **Step 4: Opções**

```dart
// lib/features/catalog/domain/entities/catalog_filter_options.dart
import '../../../../core/utils/louvor_search_tokens.dart';
import '../utils/catalog_tag_hierarchy.dart';
import 'louvor_group.dart';

/// Um tipo de material (`material_kind` do coldigom) oferecido como filtro.
class CatalogKindOption {
  const CatalogKindOption({required this.id, required this.name});

  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is CatalogKindOption && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'CatalogKindOption($id, $name)';
}

/// Os chips de cada filtro do catálogo — derivados do índice local, nunca
/// de `/api/praises/filters` nem `/api/materials/kinds` (spec fim-fonte §2.2).
///
/// Só aparecem valores com ≥1 praise. Tags incluem os ancestrais (`PES`
/// para `PES · 9.2026`), porque selecionar o pai apanha os filhos.
class CatalogFilterOptions {
  const CatalogFilterOptions({
    this.tonalities = const [],
    this.rhythms = const [],
    this.categories = const [],
    this.tags = const [],
    this.materialKinds = const [],
  });

  /// Nada a oferecer — índice ainda vazio.
  static const empty = CatalogFilterOptions();

  final List<String> tonalities;
  final List<String> rhythms;
  final List<String> categories;
  final List<String> tags;
  final List<CatalogKindOption> materialKinds;

  factory CatalogFilterOptions.fromGroups(Iterable<LouvorGroup> groups) {
    final tonalities = <String>{};
    final rhythms = <String>{};
    final categories = <String>{};
    final tags = <String>{};
    final kindNames = <String, String>{};

    for (final group in groups) {
      final meta = group.coldigomMeta;
      if (meta != null) {
        _addValue(tonalities, meta.tonality);
        _addValue(rhythms, meta.rhythm);
        _addValue(categories, meta.category);
        for (final raw in meta.tagNames) {
          final tag = raw.trim();
          if (tag.isEmpty) continue;
          tags.addAll(catalogTagWithAncestors(tag));
        }
      }
      for (final section in group.sections) {
        for (final entry in section.materials) {
          _addKind(
            kindNames,
            entry.louvor.materialKindId,
            entry.louvor.categoria,
          );
        }
      }
      for (final material in group.extras) {
        _addKind(kindNames, material.materialKindId, material.categoria);
      }
    }

    final kinds = [
      for (final entry in kindNames.entries)
        CatalogKindOption(id: entry.key, name: entry.value),
    ]..sort((a, b) {
        final byName = _compareLabels(a.name, b.name);
        return byName != 0 ? byName : a.id.compareTo(b.id);
      });

    return CatalogFilterOptions(
      tonalities: _sorted(tonalities),
      rhythms: _sorted(rhythms),
      categories: _sorted(categories),
      tags: _sorted(tags),
      materialKinds: List<CatalogKindOption>.unmodifiable(kinds),
    );
  }

  static void _addValue(Set<String> into, String raw) {
    final value = raw.trim();
    if (value.isNotEmpty) into.add(value);
  }

  static void _addKind(Map<String, String> into, String? id, String name) {
    if (id == null || id.isEmpty) return;
    final label = name.trim();
    into.putIfAbsent(id, () => label.isEmpty ? id : label);
  }

  static List<String> _sorted(Set<String> values) =>
      List<String>.unmodifiable(values.toList()..sort(_compareLabels));

  /// Sem acento nem caixa primeiro; desempate pelo texto cru (estável).
  static int _compareLabels(String a, String b) {
    final byNormalized = LouvorSearchTokens.normalize(
      a,
    ).compareTo(LouvorSearchTokens.normalize(b));
    return byNormalized != 0 ? byNormalized : a.compareTo(b);
  }
}
```

- [ ] **Step 5: Provider**

```dart
// lib/features/catalog/presentation/providers/catalog_filter_options_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../coldigom/presentation/providers/coldigom_catalog_providers.dart';
import '../../domain/entities/catalog_filter_options.dart';

export '../../domain/entities/catalog_filter_options.dart';

/// Opções dos chips de filtro (página inicial e /biblioteca), derivadas do
/// índice local — recalculadas só quando o índice muda (hidratação/sync).
final catalogFilterOptionsProvider = Provider<CatalogFilterOptions>((ref) {
  final index = ref.watch(coldigomSearchIndexProvider);
  if (index.isEmpty) return CatalogFilterOptions.empty;
  return CatalogFilterOptions.fromGroups(index.groups);
});
```

- [ ] **Step 6: Correr e ver passar**

Run: `flutter test test/unit/features/catalog/catalog_filter_options_test.dart`
Expected: PASS.
Run: `flutter analyze`
Expected: sem issues.

- [ ] **Step 7: Commit**

```bash
git add lib/features/catalog/domain/utils/catalog_tag_hierarchy.dart lib/features/catalog/domain/entities/catalog_filter_options.dart lib/features/catalog/presentation/providers/catalog_filter_options_provider.dart test/unit/features/catalog/catalog_filter_options_test.dart
git commit -m "feat(catalog): opções de filtro derivadas do índice local

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: /biblioteca com pipeline local único (sai o modo Coldigom remoto)

**Files:**
- Modify: `lib/features/library/presentation/providers/library_group_results_provider.dart` (reescrito)
- Modify: `lib/features/library/presentation/pages/library_screen.dart` (reescrito)
- Modify: `lib/features/library/data/providers/library_providers.dart` (sai `browseLibraryProvider`)
- Modify: `lib/core/utils/library_url_builder.dart`, `lib/core/utils/url_sync_params.dart`, `lib/core/routing/app_router.dart` (rota `/biblioteca`)
- Modify: `lib/features/coldigom/domain/repositories/coldigom_search_repository.dart`, `lib/features/coldigom/data/repositories/coldigom_search_repository_impl.dart`, `lib/features/coldigom/data/coldigom_cache_writer.dart`, `lib/features/coldigom/data/datasources/coldigom_remote_datasource.dart`, `lib/features/coldigom/data/models/praise_dto.dart`, `lib/features/coldigom/data/constants/coldigom_endpoints.dart`
- Modify: `lib/features/catalog/domain/utils/louvor_classification.dart`
- Modify: `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb` (+ gerados)
- Delete:
  - `lib/features/library/domain/entities/library_catalog_mode.dart`
  - `lib/features/library/presentation/providers/library_catalog_mode_provider.dart`
  - `lib/features/library/presentation/widgets/library_catalog_mode_toggle.dart`
  - `lib/features/library/presentation/providers/library_coldigom_browse_provider.dart`
  - `lib/features/library/presentation/providers/library_last_good_results_provider.dart`
  - `lib/features/library/presentation/providers/coldigom_library_facets_provider.dart`
  - `lib/features/library/presentation/providers/coldigom_library_filters_provider.dart`
  - `lib/features/library/presentation/widgets/coldigom_library_filters.dart`
  - `lib/features/library/presentation/providers/library_special_arrangement_provider.dart`
  - `lib/features/library/presentation/widgets/special_arrangement_filters.dart`
  - `lib/features/library/presentation/providers/library_group_worker.dart`
  - `lib/features/library/domain/usecases/browse_library.dart`
  - `lib/features/catalog/domain/usecases/filter_by_special_arrangement.dart`
  - Testes: `test/unit/features/library/browse_library_test.dart`, `test/unit/features/library/library_catalog_mode_provider_test.dart`, `test/widget/features/library/library_catalog_mode_toggle_test.dart`, `test/unit/features/catalog/filter_by_special_arrangement_test.dart`
- Test: `test/unit/features/library/library_group_results_provider_test.dart` (novo); reescritos `test/widget/features/library/library_screen_test.dart`, `test/widget/features/library/library_screen_error_test.dart`; ajustados `test/unit/core/utils/library_url_builder_test.dart`, `test/unit/features/coldigom/coldigom_search_repository_test.dart`, `test/unit/features/coldigom/coldigom_remote_datasource_test.dart`, `test/unit/features/catalog/catalog_source_test.dart`, `test/widget/features/catalog/home_search_test.dart`, `test/widget/features/catalog/home_search_keyboard_test.dart`, `test/unit/features/catalog/louvor_classification_special_test.dart`

**Interfaces:**
- Consumes: `coldigomSearchIndexProvider` + `ColdigomSearchIndex.groups` (Task 2); `catalogIndexStatusProvider`, `coldigomCatalogSyncProvider`, helpers `catalogIndexOverrides`/`FakeColdigomCatalogSyncNotifier` (Task 4).
- Produces:
  - `final libraryFilteredGroupsProvider = Provider<List<LouvorGroup>>` — índice → (filtro, Task 7) → ordenado por `libraryViewSettingsProvider.sortBy`.
  - `final libraryGroupResultsProvider = Provider<PaginatedLouvorGroups>` — mesmo nome de hoje (os widgets `LibraryResultsSummary`/`LibraryPaginationControls` não mudam), agora síncrono e sempre local.
  - `LibraryScreen({initialTonality, initialRhythm, initialCategory, initialTags, initialMaterialKinds, initialOrdenar, initialItensPorPagina, initialPagina})` — saem `initialFonte`, `initialMateriais`, `initialArranjo`, `initialArranjoEspecial`. Os cinco `initial*` de filtro continuam declarados (o router já os passa) e passam a ser usados na Task 7.
  - `buildLibraryLocation({tonality, rhythm, category, tags, materialKinds, ordenar, itensPorPagina, pagina})`.

**Estado transitório (Desvio 11):** esta tarefa tira o painel de filtros da /biblioteca (os chips de material/arranjo não se aplicam a grupos do índice); a Task 7 põe o painel novo.

- [ ] **Step 1: Teste do pipeline que falha**

```dart
// test/unit/features/library/library_group_results_provider_test.dart
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/features/library/presentation/providers/library_group_results_provider.dart';
import 'package:coldigui/features/library/presentation/providers/library_view_settings_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer containerWith(List<LouvorGroup> groups) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        coldigomSearchIndexProvider.overrideWithValue(catalogIndexOf(groups)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// [count] grupos em ordem **inversa** de número — prova que ordena.
  List<LouvorGroup> numbered(int count) => [
    for (var i = count; i >= 1; i--)
      catalogGroup(
        praiseId: 'p$i',
        number: '$i'.padLeft(3, '0'),
        name: 'Louvor $i',
      ),
  ];

  List<String> ids(ProviderContainer c) => [
    for (final g in c.read(libraryGroupResultsProvider).items) g.groupId,
  ];

  test('ordena por número e pagina', () {
    final c = containerWith(numbered(25));
    c.read(libraryViewSettingsProvider.notifier).setPage(2);

    final page = c.read(libraryGroupResultsProvider);

    expect(page.totalItems, 25);
    expect(page.totalPages, 3);
    expect(page.page, 2);
    expect(page.items, hasLength(10));
    expect(page.items.first.numero, '011');
  });

  test('ordena por nome sem distinguir caixa', () {
    final c = containerWith([
      catalogGroup(praiseId: 'b', number: '001', name: 'Bendito'),
      catalogGroup(praiseId: 'a', number: '002', name: 'aleluia'),
    ]);
    c.read(libraryViewSettingsProvider.notifier).setSortBy('nome');

    expect(ids(c), ['a', 'b']);
  });

  test('página além do fim cai na última', () {
    final c = containerWith(numbered(12));
    c.read(libraryViewSettingsProvider.notifier).setPage(9);

    final page = c.read(libraryGroupResultsProvider);

    expect(page.page, 2);
    expect(page.items, hasLength(2));
  });

  test('índice vazio → página vazia', () {
    final c = containerWith(const []);
    expect(c.read(libraryGroupResultsProvider).totalItems, 0);
  });

  test('2063 grupos: pipeline síncrono folgado (medição do Desvio 1)', () {
    final c = containerWith(numbered(2063));
    final stopwatch = Stopwatch()..start();
    c.read(libraryGroupResultsProvider);
    stopwatch.stop();
    debugPrint('biblioteca: 2063 grupos em ${stopwatch.elapsedMilliseconds} ms');
    expect(stopwatch.elapsedMilliseconds, lessThan(250));
  });
}
```

- [ ] **Step 2: Correr e ver falhar**

Run: `flutter test test/unit/features/library/library_group_results_provider_test.dart`
Expected: FAIL — a /biblioteca ainda lê o manifesto (índice ignorado, `totalItems` 0).

- [ ] **Step 3: Pipeline local**

Substituir `lib/features/library/presentation/providers/library_group_results_provider.dart` por:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../catalog/domain/entities/louvor_group.dart';
import '../../../coldigom/presentation/providers/coldigom_catalog_providers.dart';
import '../../data/providers/library_providers.dart';
import '../../domain/entities/paginated_louvor_groups.dart';
import 'library_view_settings_provider.dart';

/// Grupos da /biblioteca já ordenados: índice local do catálogo → ordenar
/// (`numero`/`nome`, a regra de [SortLouvorGroups]) — spec fim-fonte §2.3.
///
/// Síncrono, sem `compute`: são ~2063 grupos já montados na hidratação e
/// ordená-los custa poucos milissegundos; na web o `compute` corre na mesma
/// thread e, no nativo, copiar os grupos para o isolate custaria mais do que
/// o trabalho (plano, Desvio 1). Separado da paginação: trocar de página não
/// reordena.
final libraryFilteredGroupsProvider = Provider<List<LouvorGroup>>((ref) {
  final groups = ref.watch(coldigomSearchIndexProvider).groups;
  final sortBy = ref.watch(
    libraryViewSettingsProvider.select((view) => view.sortBy),
  );
  return ref.watch(sortLouvorGroupsProvider)(groups, sortBy: sortBy);
});

/// Página corrente da /biblioteca — [libraryFilteredGroupsProvider] paginado.
final libraryGroupResultsProvider = Provider<PaginatedLouvorGroups>((ref) {
  final groups = ref.watch(libraryFilteredGroupsProvider);
  final view = ref.watch(libraryViewSettingsProvider);
  return ref.watch(paginateLouvorGroupsProvider)(
    groups,
    page: view.page,
    itemsPerPage: view.itemsPerPage,
  );
});
```

Em `lib/features/library/data/providers/library_providers.dart`, apagar `browseLibraryProvider` e o import de `browse_library.dart`.

- [ ] **Step 4: Apagar o modo Coldigom, o browse remoto e o arranjo especial**

```bash
git rm lib/features/library/domain/entities/library_catalog_mode.dart lib/features/library/presentation/providers/library_catalog_mode_provider.dart lib/features/library/presentation/widgets/library_catalog_mode_toggle.dart lib/features/library/presentation/providers/library_coldigom_browse_provider.dart lib/features/library/presentation/providers/library_last_good_results_provider.dart lib/features/library/presentation/providers/coldigom_library_facets_provider.dart lib/features/library/presentation/providers/coldigom_library_filters_provider.dart lib/features/library/presentation/widgets/coldigom_library_filters.dart lib/features/library/presentation/providers/library_special_arrangement_provider.dart lib/features/library/presentation/widgets/special_arrangement_filters.dart lib/features/library/presentation/providers/library_group_worker.dart lib/features/library/domain/usecases/browse_library.dart lib/features/catalog/domain/usecases/filter_by_special_arrangement.dart test/unit/features/library/browse_library_test.dart test/unit/features/library/library_catalog_mode_provider_test.dart test/widget/features/library/library_catalog_mode_toggle_test.dart test/unit/features/catalog/filter_by_special_arrangement_test.dart
```

(`FilterByMaterialAndArranjo` ainda serve o pipeline de busca do manifesto; sai na Task 7.)

Browse remoto sem chamador — apagar:
1. `lib/features/coldigom/domain/repositories/coldigom_search_repository.dart`: o método `browse`, as classes `ColdigomBrowseQuery` e `ColdigomBrowseResult`; doc da interface: «Porta de busca coldigom.».
2. `lib/features/coldigom/data/repositories/coldigom_search_repository_impl.dart`: o método `browse`; doc da classe: «Orquestra a busca coldigom via endpoint PLPCG (1 request com materials).» (o resto do doc fica).
3. `lib/features/coldigom/data/coldigom_cache_writer.dart`: o método `mergeBrowseResult`.
4. `lib/features/coldigom/data/datasources/coldigom_remote_datasource.dart`: o método `fetchFilterOptions` (`fetchMaterialKinds` fica — o ecrã de tipos favoritos usa).
5. `lib/features/coldigom/data/models/praise_dto.dart`: as classes `ColdigomTagFacetDto` e `ColdigomFilterOptionsDto`.
6. `lib/features/coldigom/data/constants/coldigom_endpoints.dart`: a constante `filterOptions`.

`lib/features/catalog/domain/utils/louvor_classification.dart`: apagar `parseSpecialArrangementsFromUrl` e `serializeSpecialArrangementsForUrl`; no doc da classe, trocar as três linhas «Contrato URL: param [UrlSyncParams.arranjo] … omitido quando nenhum filtro está selecionado.» por «Rótulos de classificação/arranjo do manifesto nas secções de material e no chip do carrossel.» (`parseArranjosFromUrl`/`serializeArranjosForUrl` saem na Task 7).

- [ ] **Step 5: URL e rota**

Substituir `lib/core/utils/library_url_builder.dart` por:

```dart
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/url_sync_params.dart';

/// Monta path da /biblioteca com query params sincronizados (spec fim-fonte
/// §2.5).
///
/// Filtros do catálogo (os mesmos da página inicial): CSV de [tonality],
/// [rhythm], [category], [tags] (nomes) e [materialKinds] (ids de kind);
/// omitidos quando vazios. Vista: [ordenar] `numero`, [itensPorPagina] `10` e
/// [pagina] `1` são omitidos. Valores codificados via [Uri.encodeComponent].
String buildLibraryLocation({
  String? tonality,
  String? rhythm,
  String? category,
  String? tags,
  String? materialKinds,
  String ordenar = UrlSyncParams.defaultOrdenar,
  String itensPorPagina = UrlSyncParams.defaultItensPorPagina,
  String pagina = UrlSyncParams.defaultPagina,
}) {
  final params = <String, String>{};

  void put(String key, String? value) {
    if (value != null && value.isNotEmpty) params[key] = value;
  }

  put(UrlSyncParams.tonality, tonality);
  put(UrlSyncParams.rhythm, rhythm);
  put(UrlSyncParams.category, category);
  put(UrlSyncParams.tags, tags);
  put(UrlSyncParams.materialKinds, materialKinds);
  if (ordenar != UrlSyncParams.defaultOrdenar) {
    params[UrlSyncParams.ordenar] = ordenar;
  }
  if (itensPorPagina != UrlSyncParams.defaultItensPorPagina) {
    params[UrlSyncParams.itensPorPagina] = itensPorPagina;
  }
  if (pagina != UrlSyncParams.defaultPagina) {
    params[UrlSyncParams.pagina] = pagina;
  }

  if (params.isEmpty) return RoutePaths.library;

  final query = params.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
  return '${RoutePaths.library}?$query';
}

/// Normaliza [uri] da /biblioteca para comparação com [buildLibraryLocation].
///
/// Params que não existem mais (`fonte`, `materiais`, `arranjo`,
/// `arranjoEspecial`) são ignorados — um link antigo abre sem erro e o sync
/// de URL os tira.
String buildLibraryLocationFromUri(Uri uri) => buildLibraryLocation(
  tonality: uri.queryParameters[UrlSyncParams.tonality],
  rhythm: uri.queryParameters[UrlSyncParams.rhythm],
  category: uri.queryParameters[UrlSyncParams.category],
  tags: uri.queryParameters[UrlSyncParams.tags],
  materialKinds: uri.queryParameters[UrlSyncParams.materialKinds],
  ordenar:
      uri.queryParameters[UrlSyncParams.ordenar] ??
      UrlSyncParams.defaultOrdenar,
  itensPorPagina:
      uri.queryParameters[UrlSyncParams.itensPorPagina] ??
      UrlSyncParams.defaultItensPorPagina,
  pagina:
      uri.queryParameters[UrlSyncParams.pagina] ?? UrlSyncParams.defaultPagina,
);
```

Em `lib/core/utils/url_sync_params.dart`: apagar `arranjoEspecial` e `fonte` (com o doc «Biblioteca: `plpcg` (omitido) | `coldigom`.»); trocar o doc «Filtros Coldigom (CSV) — espelham query params da API.» por «Filtros do catálogo (CSV), nas rotas `/` e `/biblioteca` (spec fim-fonte §2.5). [tags] leva **nomes** de tag; [materialKinds], ids de kind.».

Em `lib/core/routing/app_router.dart`, na rota `RoutePaths.library`, apagar as linhas `initialFonte: …`, `initialMateriais: …`, `initialArranjo: …` e `initialArranjoEspecial: …` (as de `initialTonality`…`initialPagina` ficam).

- [ ] **Step 6: `LibraryScreen`**

Substituir `lib/features/library/presentation/pages/library_screen.dart` por:

```dart
import 'dart:async';

import 'package:coldigui/core/network/connectivity_stream_provider.dart';
import 'package:coldigui/core/routing/url_sync_navigation.dart';
import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/core/utils/library_url_builder.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_group_card.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_group_card_skeleton.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/features/library/presentation/providers/library_group_results_provider.dart';
import 'package:coldigui/features/library/presentation/providers/library_view_settings_provider.dart';
import 'package:coldigui/features/library/presentation/widgets/library_view_controls.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// UC-03 — /biblioteca: o catálogo local inteiro, ordenado e paginado
/// (spec fim-fonte §2.3). Um caminho só: sem seletor de fonte, sem browse
/// remoto. Enquanto o índice está vazio mostra carregamento; índice vazio
/// com o sync falhado mostra `catalogLoadError` + «Tentar novamente».
/// Sync URL via [buildLibraryLocation].
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({
    super.key,
    this.initialTonality,
    this.initialRhythm,
    this.initialCategory,
    this.initialTags,
    this.initialMaterialKinds,
    this.initialOrdenar,
    this.initialItensPorPagina,
    this.initialPagina,
  });

  final String? initialTonality;
  final String? initialRhythm;
  final String? initialCategory;
  final String? initialTags;
  final String? initialMaterialKinds;
  final String? initialOrdenar;
  final String? initialItensPorPagina;
  final String? initialPagina;

  static const double _maxContentWidth = 896;

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  var _initialized = false;
  var _urlSyncEnabled = false;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrateFromUrl());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollResultsToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(0);
  }

  void _hydrateFromUrl() {
    if (_initialized) return;
    _initialized = true;
    _hydrateView();
    // C13: default de itens/página pela largura — só quando não há valor
    // gravado nem `itensPorPagina` na URL (no-op nos demais casos).
    ref
        .read(libraryViewSettingsProvider.notifier)
        .setDefaultForWidth(MediaQuery.sizeOf(context).width);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _urlSyncEnabled = true;
    });
  }

  void _hydrateView() {
    ref
        .read(libraryViewSettingsProvider.notifier)
        .hydrateFromUrl(
          ordenar: widget.initialOrdenar,
          itensPorPagina: widget.initialItensPorPagina,
          pagina: widget.initialPagina,
        );
  }

  @override
  void didUpdateWidget(LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final viewChanged =
        oldWidget.initialOrdenar != widget.initialOrdenar ||
        oldWidget.initialItensPorPagina != widget.initialItensPorPagina ||
        oldWidget.initialPagina != widget.initialPagina;
    if (!viewChanged) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _hydrateView();
    });
  }

  void _syncUrlFromState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyUrlSyncFromState();
    });
  }

  void _applyUrlSyncFromState() {
    final goRouter = GoRouter.maybeOf(context);
    if (goRouter == null) return;

    final uri = goRouter.routerDelegate.currentConfiguration.uri;
    final view = ref.read(libraryViewSettingsProvider);
    final target = buildLibraryLocation(
      ordenar: view.ordenarUrlValue ?? view.sortBy,
      itensPorPagina: view.itensPorPaginaUrlValue ?? '${view.itemsPerPage}',
      pagina: view.paginaUrlValue ?? '${view.page}',
    );

    if (buildLibraryLocationFromUri(uri) == target) return;
    // Ordenação e página espelham estado — replaceState (P4).
    goReplacingUrl(context, goRouter, target);
  }

  void _retryCatalog() {
    unawaited(ref.read(coldigomCatalogSyncProvider.notifier).sync());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final status = ref.watch(catalogIndexStatusProvider);
    final results = ref.watch(libraryGroupResultsProvider);

    ref.listen<LibraryViewSettings>(libraryViewSettingsProvider, (
      previous,
      next,
    ) {
      if (previous?.page != next.page ||
          previous?.sortBy != next.sortBy ||
          previous?.itemsPerPage != next.itemsPerPage) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollResultsToTop();
        });
      }
      if (!_urlSyncEnabled) return;
      _syncUrlFromState();
    });

    // Reconexão (C.8): volta a rede com o catálogo vazio → tenta de novo
    // sozinho (spec §2.1).
    ref.listen<AsyncValue<bool>>(connectivityStreamProvider, (_, next) {
      if (next.value != true) return;
      if (ref.read(coldigomSearchIndexProvider).isEmpty) _retryCatalog();
    });

    final horizontalPadding = MediaQuery.sizeOf(context).width > 600
        ? 24.0
        : 16.0;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: LibraryScreen._maxContentWidth,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 16,
            ),
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const LibraryViewControls(),
                      if (status == CatalogIndexStatus.failed) ...[
                        const SizedBox(height: 16),
                        Text(
                          l10n.catalogLoadError,
                          style: AppTypography.body.copyWith(
                            color: AppColors.textLight,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: FilledButton(
                            onPressed: _retryCatalog,
                            child: Text(l10n.retry),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                if (status == CatalogIndexStatus.loading)
                  const CatalogLoadingSliver()
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: EdgeInsets.only(
                          bottom: index < results.items.length - 1 ? 8 : 0,
                        ),
                        child: LouvorGroupCard(group: results.items[index]),
                      ),
                      childCount: results.items.length,
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
```

- [ ] **Step 7: Strings que morrem**

Em `lib/l10n/app_pt.arb` e `lib/l10n/app_en.arb`, apagar as chaves `specialArrangementPadrao`, `filtersSpecialArrangementTitle`, `libraryCatalogModeLabel`, `libraryCatalogModePlpcg`, `libraryCatalogModeColdigom` e `coldigomLoadError` (spec §9.1; nenhuma tem bloco `@`). Confirmar zero chamadores antes: `grep -rn "specialArrangementPadrao\|filtersSpecialArrangementTitle\|libraryCatalogMode\|coldigomLoadError" lib test --include='*.dart' | grep -v "lib/l10n/app_localizations"` deve dar só `LouvorClassification.specialArrangementPadrao` (a constante Dart, que fica). Depois: `flutter gen-l10n`.

- [ ] **Step 8: Testes de widget da /biblioteca**

Substituir `test/widget/features/library/library_screen_test.dart` por:

```dart
import 'dart:async';

import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/widgets/golden_tagged_container.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_group_card_skeleton.dart';
import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/features/library/presentation/pages/library_screen.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';

List<LouvorGroup> _groups(int count) => [
  for (var i = 1; i <= count; i++)
    catalogGroup(
      praiseId: 'p$i',
      number: '$i'.padLeft(3, '0'),
      name: 'Louvor $i',
    ),
];

Widget _libraryTestApp({
  required SharedPreferences prefs,
  required List<Override> catalogOverrides,
}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      ...catalogOverrides,
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('pt'),
      home: const Scaffold(body: LibraryScreen()),
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpLibrary(WidgetTester tester, List<LouvorGroup> groups) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      _libraryTestApp(
        prefs: prefs,
        catalogOverrides: catalogIndexOverrides(catalogIndexOf(groups)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lista os louvores do índice local, sem seletor de fonte', (
    tester,
  ) async {
    await pumpLibrary(tester, _groups(15));

    expect(find.text('#001 — Louvor 1'), findsOneWidget);
    // O seletor «Fonte: PLPCG | Coldigom» não existe mais.
    expect(find.text('Fonte'), findsNothing);
  });

  testWidgets('resumo dentro do card Visualização', (tester) async {
    await pumpLibrary(tester, _groups(15));

    final summary = find.textContaining('Mostrando 1');
    expect(summary, findsOneWidget);
    expect(find.text('10 por página'), findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(
          of: summary,
          matching: find.byType(GoldenTaggedContainer),
        ),
        matching: find.text('Visualização'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('troca página e ordenação', (tester) async {
    await pumpLibrary(tester, _groups(15));

    expect(find.text('#001 — Louvor 1'), findsOneWidget);
    expect(find.text('#011 — Louvor 11'), findsNothing);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text('#011 — Louvor 11'), findsOneWidget);
    expect(find.text('#001 — Louvor 1'), findsNothing);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text('#001 — Louvor 1'), findsOneWidget);

    await tester.tap(find.text('Nome'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('#001 — Louvor 1')).dy,
      lessThan(tester.getTopLeft(find.text('#010 — Louvor 10')).dy),
    );
  });

  testWidgets('skeleton enquanto o índice hidrata', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prefs = await SharedPreferences.getInstance();
    final pending = Completer<ColdigomSearchIndex>();

    await tester.pumpWidget(
      _libraryTestApp(
        prefs: prefs,
        catalogOverrides: [
          coldigomCatalogHydrationProvider.overrideWith((ref) => pending.future),
          coldigomCatalogSyncProvider.overrideWith(
            FakeColdigomCatalogSyncNotifier.new,
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.byType(LouvorGroupCardSkeleton), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pump(const Duration(milliseconds: 600));
  });
}
```

Substituir `test/widget/features/library/library_screen_error_test.dart` por:

```dart
import 'dart:async';

import 'package:coldigui/core/network/connectivity_stream_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_group_card_skeleton.dart';
import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/features/library/presentation/pages/library_screen.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';

Widget _app(SharedPreferences prefs, List<Override> overrides) {
  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs), ...overrides],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('pt'),
      home: const Scaffold(body: LibraryScreen()),
    ),
  );
}

/// `pumpAndSettle` trava com o shimmer do skeleton (animação em loop).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

const _failed = ColdigomCatalogSyncState(
  lastResult: ColdigomCatalogSyncFailed('sem rede'),
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'índice vazio e sync falhado: catalogLoadError e «Tentar novamente» chama sync()',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final sync = FakeColdigomCatalogSyncNotifier(_failed);

      await tester.pumpWidget(
        _app(prefs, [
          ...catalogIndexOverrides(ColdigomSearchIndex.empty, sync: sync),
          connectivityStreamProvider.overrideWith(
            (ref) => const Stream<bool>.empty(),
          ),
        ]),
      );
      await _settle(tester);

      expect(find.text('Não foi possível carregar o catálogo'), findsOneWidget);
      expect(find.byType(LouvorGroupCardSkeleton), findsNothing);

      final retry = find.widgetWithText(FilledButton, 'Tentar novamente');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await _settle(tester);

      expect(sync.syncCalls, 1);
    },
  );

  testWidgets('a rede volta com o índice vazio: sync() sozinho', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final sync = FakeColdigomCatalogSyncNotifier(_failed);
    final connectivity = StreamController<bool>();
    addTearDown(connectivity.close);

    await tester.pumpWidget(
      _app(prefs, [
        ...catalogIndexOverrides(ColdigomSearchIndex.empty, sync: sync),
        connectivityStreamProvider.overrideWith((ref) => connectivity.stream),
      ]),
    );
    await _settle(tester);
    expect(sync.syncCalls, 0);

    connectivity.add(true);
    await _settle(tester);

    expect(sync.syncCalls, 1);
  });

  testWidgets('índice pronto: sem erro, e a volta da rede não sincroniza', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final sync = FakeColdigomCatalogSyncNotifier(_failed);
    final connectivity = StreamController<bool>();
    addTearDown(connectivity.close);

    await tester.pumpWidget(
      _app(prefs, [
        ...catalogIndexOverrides(
          catalogIndexOf([
            catalogGroup(praiseId: 'p1', number: '001', name: 'Aleluia'),
          ]),
          sync: sync,
        ),
        connectivityStreamProvider.overrideWith((ref) => connectivity.stream),
      ]),
    );
    await _settle(tester);

    connectivity.add(true);
    await _settle(tester);

    expect(find.text('Não foi possível carregar o catálogo'), findsNothing);
    expect(find.text('#001 — Aleluia'), findsOneWidget);
    expect(sync.syncCalls, 0);
  });
}
```

Se algum destes testes pendurar em timers ou tentar abrir o Isar por causa de um consumidor do manifesto que ainda existe (o lookup de materiais que o card usa), acrescentar `louvoresManifestOverride(LouvoresManifest.fromLouvores(const []))` (de `test/helpers/louvores_manifest_test_helpers.dart`) aos overrides — o plano 3 tira-o junto com o manifesto.

- [ ] **Step 9: Ajustar os testes que tocavam no que saiu**

1. `test/unit/core/utils/library_url_builder_test.dart` — substituir o corpo de `main()` por:

```dart
  test('buildLibraryLocation sem params retorna path base', () {
    expect(buildLibraryLocation(), RoutePaths.library);
  });

  test('buildLibraryLocation combina filtros do catálogo e vista', () {
    final location = buildLibraryLocation(
      tonality: 'Dm,G',
      rhythm: 'Fox',
      category: 'Clamor',
      tags: 'PES',
      materialKinds: 'k1',
      ordenar: 'nome',
      itensPorPagina: '25',
      pagina: '2',
    );

    expect(location, contains('tonality=${Uri.encodeComponent('Dm,G')}'));
    expect(location, contains('rhythm=Fox'));
    expect(location, contains('category=Clamor'));
    expect(location, contains('tags=PES'));
    expect(location, contains('materialKinds=k1'));
    expect(location, contains('ordenar=nome'));
    expect(location, contains('itensPorPagina=25'));
    expect(location, contains('pagina=2'));
  });

  test('buildLibraryLocation omite defaults', () {
    final location = buildLibraryLocation(
      ordenar: 'numero',
      itensPorPagina: '10',
      pagina: '1',
    );

    expect(location, RoutePaths.library);
  });

  test('buildLibraryLocation codifica valores especiais', () {
    final location = buildLibraryLocation(tags: 'PES · 9.2026');
    expect(location, contains(Uri.encodeComponent('PES · 9.2026')));
  });

  test('link antigo: fonte/materiais/arranjo/arranjoEspecial são ignorados', () {
    final uri = Uri.parse(
      '/biblioteca?fonte=coldigom&materiais=Partitura&arranjo=ColAdultos'
      '&arranjoEspecial=Especial&tonality=Dm&pagina=3',
    );

    final location = buildLibraryLocationFromUri(uri);

    expect(location, buildLibraryLocation(tonality: 'Dm', pagina: '3'));
    expect(location, isNot(contains('fonte')));
    expect(location, isNot(contains('materiais')));
    expect(location, isNot(contains('arranjo')));
  });
```

2. `test/unit/features/coldigom/coldigom_search_repository_test.dart` — apagar os testes `'browse com q vazio usa total da API'` e `'browse grava os mesmos caches'`; na mensagem do `StateError` (`'fetchDetail não deve ser chamado no search/browse'`) trocar `search/browse` por `search`.
3. `test/unit/features/coldigom/coldigom_remote_datasource_test.dart` — apagar o teste `'ColdigomFilterOptionsDto parseia facets'`.
4. `test/unit/features/catalog/catalog_source_test.dart`, `test/widget/features/catalog/home_search_test.dart` (duas classes) e `test/widget/features/catalog/home_search_keyboard_test.dart` — apagar o override `Future<ColdigomBrowseResult> browse(ColdigomBrowseQuery query)` dos fakes de `ColdigomSearchRepository`.
5. `test/unit/features/catalog/louvor_classification_special_test.dart` — apagar os quatro testes `parseSpecialArrangementsFromUrl …`/`serializeSpecialArrangementsForUrl …` (Desvio 7; os de `displayLabel` e `specialArrangement` ficam).

- [ ] **Step 10: Correr e ver passar**

Run: `flutter test test/unit/features/library/ test/widget/features/library/ test/unit/core/utils/library_url_builder_test.dart test/unit/features/coldigom/ test/unit/features/catalog/ test/widget/features/catalog/`
Expected: PASS. Registar no commit o tempo impresso pelo teste dos 2063 grupos.
Run: `flutter analyze`
Expected: sem issues (atenção a imports órfãos nos ficheiros ajustados).

- [ ] **Step 11: Commit**

```bash
git add -A lib/features/library lib/features/coldigom lib/features/catalog/domain/utils/louvor_classification.dart lib/core/utils/library_url_builder.dart lib/core/utils/url_sync_params.dart lib/core/routing/app_router.dart lib/l10n test/unit/features/library test/widget/features/library test/unit/core/utils/library_url_builder_test.dart test/unit/features/coldigom test/unit/features/catalog test/widget/features/catalog
git commit -m "feat(library): /biblioteca só do índice local; sai o modo Coldigom remoto

Pipeline síncrono índice → ordenar → paginar (2063 grupos em N ms no VM).
Saem o seletor de fonte, o browse remoto, lastGood, facets, o arranjo
especial e o worker com compute.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

(Trocar `N` pelo tempo medido. Os `git rm` do Step 4 já deixaram as remoções no índice.)

---
### Task 7: filtros únicos — estado, predicado, painel e URL nas duas rotas

**Files:**
- Modify (reescrito): `lib/features/catalog/domain/entities/catalog_filter_state.dart`
- Create: `lib/features/catalog/domain/usecases/matches_catalog_filters.dart`
- Modify (reescrito): `lib/features/catalog/presentation/providers/catalog_filters_provider.dart`
- Create: `lib/features/catalog/presentation/widgets/catalog_filter_sections.dart`
- Modify (reescrito): `lib/features/catalog/presentation/widgets/filters_panel.dart`
- Modify: `lib/features/catalog/domain/entities/catalog_query.dart`, `lib/features/catalog/domain/search/plpcg_search_index.dart`, `lib/features/catalog/domain/constants/catalog_materials.dart`, `lib/features/catalog/domain/utils/louvor_classification.dart`, `lib/core/constants/storage_keys.dart` (doc)
- Modify: `lib/features/catalog/presentation/providers/home_search_provider.dart`, `lib/features/catalog/presentation/pages/home_screen.dart`, `lib/features/catalog/presentation/widgets/home_empty_state.dart`
- Modify (reescrito): `lib/core/utils/home_url_builder.dart`; Modify: `lib/core/utils/url_sync_params.dart`, `lib/core/routing/app_router.dart` (rota `/`)
- Modify: `lib/features/library/presentation/providers/library_group_results_provider.dart`, `lib/features/library/presentation/pages/library_screen.dart` (versão final)
- Delete: `lib/features/catalog/presentation/widgets/category_filters.dart`, `lib/features/catalog/presentation/widgets/classification_filters.dart`, `lib/features/catalog/domain/usecases/filter_by_material_and_arranjo.dart`, `test/widget/features/catalog/category_filters_test.dart`, `test/unit/features/catalog/filter_by_material_and_arranjo_test.dart`
- Test (novos): `test/unit/features/catalog/catalog_filter_state_test.dart`, `test/unit/features/catalog/matches_catalog_filters_test.dart`, `test/widget/features/catalog/catalog_filter_sections_test.dart`
- Test (reescrito): `test/unit/features/catalog/catalog_filters_provider_test.dart`, `test/unit/core/utils/home_url_builder_test.dart`
- Test (ajustados): `test/unit/features/library/library_group_results_provider_test.dart`, `test/widget/features/library/library_screen_test.dart`, `test/unit/features/catalog/home_search_provider_test.dart`, `test/widget/features/catalog/home_empty_state_test.dart`, `test/unit/features/catalog/plpcg_search_index_test.dart`, `test/unit/features/catalog/catalog_source_test.dart`, `test/unit/features/catalog/catalog_materials_test.dart`

**Interfaces:**
- Consumes: `catalogTagMatches` e `catalogFilterOptionsProvider`/`CatalogFilterOptions` (Task 5); `libraryViewSettingsProvider.setPage`; `libraryFilteredGroupsProvider` (Task 6); `catalogIndexStatusProvider` (Task 4).
- Produces (C5, nomes fixos):
  - `class CatalogFilterState` — `const CatalogFilterState({Set<String> tonalities, rhythms, categories, tags, materialKindIds})` (todos `const {}` por omissão), `static const empty`, `bool isEmpty`, `copyWith`, `factory CatalogFilterState.fromUrl({String? tonality, String? rhythm, String? category, String? tags, String? materialKinds})`, getters `tonalityUrlValue`/`rhythmUrlValue`/`categoryUrlValue`/`tagsUrlValue`/`materialKindsUrlValue` (CSV ordenado ou `null`), `static Set<String> parseCsv(String?)`, `Map<String, Object> toPersistedJson()`, `static CatalogFilterState? fromPersistedJson(Object?)`, `==`/`hashCode`.
  - `bool matchesCatalogFilters(LouvorGroup group, CatalogFilterState filters)`.
  - `catalogFiltersProvider` / `CatalogFiltersNotifier`: `toggleTonality(String)`, `toggleRhythm(String)`, `toggleCategory(String)`, `toggleTag(String)`, `toggleMaterialKind(String)`, `clear()`, `hydrateFromUrl({String? tonality, String? rhythm, String? category, String? tags, String? materialKinds})`.
  - `CatalogFilterSections` (widget, sem parâmetros); `FiltersPanel({bool initiallyExpanded = false})` (saem `showPlpcgSections` e `additionalExpandedSections`).
  - `buildHomeLocation({String pesquisa = '', String? tonality, String? rhythm, String? category, String? tags, String? materialKinds})`; `HomeScreen({initialSearchQuery, initialTonality, initialRhythm, initialCategory, initialTags, initialMaterialKinds})`.
  - `CatalogQuery` perde `filters`/`defaultFilters` (os filtros deixam de viajar pela porta `CatalogSource`; quem filtra é o predicado).

**Estado transitório (Desvio 11):** a busca local da página inicial ainda junta manifesto + índice (a troca é da Task 8), mas já passa pelo predicado novo — um grupo do manifesto (sem `coldigomMeta`) só aparece sem filtros de meta ativos.

- [ ] **Step 1: Testes do estado e do predicado (falham)**

```dart
// test/unit/features/catalog/catalog_filter_state_test.dart
import 'dart:convert';

import 'package:coldigui/features/catalog/domain/entities/catalog_filter_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty não filtra; qualquer conjunto não vazio filtra', () {
    expect(CatalogFilterState.empty.isEmpty, isTrue);
    expect(const CatalogFilterState(tags: {'PES'}).isEmpty, isFalse);
    expect(
      const CatalogFilterState(materialKindIds: {'k1'}).isEmpty,
      isFalse,
    );
  });

  test('igualdade por conteúdo dos cinco conjuntos', () {
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
    expect(state.categoryUrlValue, isNull);
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

  test('formato gravado v2: ida e volta; formato antigo e lixo → null', () {
    const state = CatalogFilterState(
      tonalities: {'Dm'},
      rhythms: {'Fox'},
      categories: {'Clamor'},
      tags: {'PES'},
      materialKindIds: {'k1'},
    );

    final json = jsonDecode(jsonEncode(state.toPersistedJson()));
    expect(CatalogFilterState.fromPersistedJson(json), state);
    expect(
      CatalogFilterState.fromPersistedJson({
        'materials': ['Partitura'],
        'arranjos': <String>[],
      }),
      isNull,
    );
    expect(CatalogFilterState.fromPersistedJson('x'), isNull);
    expect(CatalogFilterState.fromPersistedJson(null), isNull);
  });
}
```

```dart
// test/unit/features/catalog/matches_catalog_filters_test.dart
import 'package:coldigui/features/catalog/domain/entities/catalog_filter_state.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/usecases/matches_catalog_filters.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';

void main() {
  final hino = catalogGroup(
    praiseId: 'p1',
    name: 'Hino',
    tonality: 'Dm',
    rhythm: 'Fox',
    category: 'Clamor',
    tags: const ['PES · 9.2026', 'Avulsos'],
    pdfKinds: const {'k-grade': 'Grade'},
    audioKinds: const {'k-play': 'Playback'},
  );
  final coro = catalogGroup(
    praiseId: 'p2',
    name: 'Coro',
    tonality: 'G',
    rhythm: 'Valsa',
    category: 'Adoração',
    tags: const ['CIAs'],
    pdfKinds: const {'k-cifra1': 'Cifra I'},
  );
  final semMeta = LouvorGroup(
    groupId: 'x',
    numero: '',
    nome: 'Sem meta',
    sections: const [],
  );

  bool matches(LouvorGroup group, CatalogFilterState filters) =>
      matchesCatalogFilters(group, filters);

  test('sem filtros passa tudo, inclusive grupo sem meta', () {
    expect(matches(hino, CatalogFilterState.empty), isTrue);
    expect(matches(semMeta, CatalogFilterState.empty), isTrue);
  });

  test('tom: OU entre os selecionados', () {
    const filters = CatalogFilterState(tonalities: {'Dm', 'A'});
    expect(matches(hino, filters), isTrue);
    expect(matches(coro, filters), isFalse);
  });

  test('ritmo e categoria', () {
    expect(matches(hino, const CatalogFilterState(rhythms: {'Fox'})), isTrue);
    expect(matches(coro, const CatalogFilterState(rhythms: {'Fox'})), isFalse);
    expect(
      matches(coro, const CatalogFilterState(categories: {'Adoração'})),
      isTrue,
    );
    expect(
      matches(hino, const CatalogFilterState(categories: {'Adoração'})),
      isFalse,
    );
  });

  test('tags: o pai inclui os filhos; o filho não inclui o pai; prefixo solto não conta', () {
    expect(matches(hino, const CatalogFilterState(tags: {'PES'})), isTrue);
    expect(
      matches(hino, const CatalogFilterState(tags: {'PES · 9.2026'})),
      isTrue,
    );
    expect(
      matches(hino, const CatalogFilterState(tags: {'PES · 9.2026 · Coro'})),
      isFalse,
    );
    expect(matches(hino, const CatalogFilterState(tags: {'PE'})), isFalse);
    expect(
      matches(coro, const CatalogFilterState(tags: {'PES', 'CIAs'})),
      isTrue,
    );
  });

  test('tipo de material: algum PDF ou extra com o materialKindId', () {
    expect(
      matches(hino, const CatalogFilterState(materialKindIds: {'k-play'})),
      isTrue,
    );
    expect(
      matches(hino, const CatalogFilterState(materialKindIds: {'k-grade'})),
      isTrue,
    );
    expect(
      matches(
        coro,
        const CatalogFilterState(materialKindIds: {'k-grade', 'k-play'}),
      ),
      isFalse,
    );
  });

  test('E entre filtros diferentes', () {
    const filters = CatalogFilterState(tonalities: {'Dm', 'G'}, tags: {'CIAs'});
    expect(matches(hino, filters), isFalse);
    expect(matches(coro, filters), isTrue);
  });

  test('grupo sem meta falha filtros de meta; sem materiais falha o tipo', () {
    expect(
      matches(semMeta, const CatalogFilterState(tonalities: {'Dm'})),
      isFalse,
    );
    expect(matches(semMeta, const CatalogFilterState(tags: {'PES'})), isFalse);
    expect(
      matches(semMeta, const CatalogFilterState(materialKindIds: {'k-grade'})),
      isFalse,
    );
  });

  test('valor do praise com espaços nas pontas casa com o chip aparado', () {
    final sujo = catalogGroup(praiseId: 'p3', name: 'S', tonality: ' Dm ');
    expect(matches(sujo, const CatalogFilterState(tonalities: {'Dm'})), isTrue);
  });
}
```

- [ ] **Step 2: Correr e ver falhar**

Run: `flutter test test/unit/features/catalog/catalog_filter_state_test.dart test/unit/features/catalog/matches_catalog_filters_test.dart`
Expected: FAIL — `CatalogFilterState` ainda é o de material/arranjo; `matches_catalog_filters.dart` não existe.

- [ ] **Step 3: Estado novo**

Substituir `lib/features/catalog/domain/entities/catalog_filter_state.dart` por:

```dart
/// Filtros do catálogo — um conjunto só para a página inicial e a
/// /biblioteca (spec fim-fonte §2.2, C5).
///
/// OU dentro de cada conjunto, E entre conjuntos; conjunto vazio não
/// restringe (`matchesCatalogFilters`). [tags] guarda **nomes** de tag;
/// [materialKindIds], ids de `material_kind`. Os getters `*UrlValue` dão o
/// CSV ordenado de cada conjunto (`null` quando vazio) para a URL (§2.5).
class CatalogFilterState {
  const CatalogFilterState({
    this.tonalities = const {},
    this.rhythms = const {},
    this.categories = const {},
    this.tags = const {},
    this.materialKindIds = const {},
  });

  /// Sem filtro nenhum.
  static const empty = CatalogFilterState();

  /// Estado a partir dos params da URL (CSV de cada filtro).
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
      categories: parseCsv(category),
      tags: parseCsv(tags),
      materialKindIds: parseCsv(materialKinds),
    );
  }

  final Set<String> tonalities;
  final Set<String> rhythms;
  final Set<String> categories;

  /// Nomes de tag; `PES` também apanha `PES · 9.2026`.
  final Set<String> tags;

  /// Ids de `material_kind`.
  final Set<String> materialKindIds;

  bool get isEmpty =>
      tonalities.isEmpty &&
      rhythms.isEmpty &&
      categories.isEmpty &&
      tags.isEmpty &&
      materialKindIds.isEmpty;

  CatalogFilterState copyWith({
    Set<String>? tonalities,
    Set<String>? rhythms,
    Set<String>? categories,
    Set<String>? tags,
    Set<String>? materialKindIds,
  }) {
    return CatalogFilterState(
      tonalities: tonalities ?? this.tonalities,
      rhythms: rhythms ?? this.rhythms,
      categories: categories ?? this.categories,
      tags: tags ?? this.tags,
      materialKindIds: materialKindIds ?? this.materialKindIds,
    );
  }

  String? get tonalityUrlValue => _csvOrNull(tonalities);
  String? get rhythmUrlValue => _csvOrNull(rhythms);
  String? get categoryUrlValue => _csvOrNull(categories);
  String? get tagsUrlValue => _csvOrNull(tags);
  String? get materialKindsUrlValue => _csvOrNull(materialKindIds);

  /// Versão do JSON gravado em `StorageKeys.catalogFilters`.
  static const persistedVersion = 2;

  Map<String, Object> toPersistedJson() => {
    'v': persistedVersion,
    'tonalities': _sorted(tonalities),
    'rhythms': _sorted(rhythms),
    'categories': _sorted(categories),
    'tags': _sorted(tags),
    'materialKinds': _sorted(materialKindIds),
  };

  /// `null` quando [json] não é o formato [persistedVersion] — inclusive o
  /// antigo `{materials, arranjos}`, que é descartado (spec §2.2).
  static CatalogFilterState? fromPersistedJson(Object? json) {
    if (json is! Map || json['v'] != persistedVersion) return null;
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
      categories: read('categories'),
      tags: read('tags'),
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
          _sameSet(categories, other.categories) &&
          _sameSet(tags, other.tags) &&
          _sameSet(materialKindIds, other.materialKindIds);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(tonalities),
    Object.hashAllUnordered(rhythms),
    Object.hashAllUnordered(categories),
    Object.hashAllUnordered(tags),
    Object.hashAllUnordered(materialKindIds),
  );

  @override
  String toString() =>
      'CatalogFilterState(tom: $tonalities, ritmo: $rhythms, '
      'categoria: $categories, tags: $tags, tipos: $materialKindIds)';
}
```

- [ ] **Step 4: Predicado**

```dart
// lib/features/catalog/domain/usecases/matches_catalog_filters.dart
import '../entities/catalog_filter_state.dart';
import '../entities/louvor_group.dart';
import '../utils/catalog_tag_hierarchy.dart';

/// Predicado único dos filtros do catálogo (spec fim-fonte §2.2) — usado
/// pela /biblioteca, pela busca local e pelos «novos» da busca remota.
///
/// - Tom, ritmo, categoria: o valor do praise (`coldigomMeta`, aparado) está
///   no conjunto (OU).
/// - Tags: alguma tag do praise é uma selecionada ou filha dela
///   ([catalogTagMatches]: `PES` apanha `PES · 9.2026`).
/// - Tipo de material: algum material do grupo (PDF de secção ou extra) tem
///   o `materialKindId` no conjunto.
/// - Entre filtros, E; filtro vazio não restringe. Um grupo sem
///   `coldigomMeta` só passa sem filtros de tom/ritmo/categoria/tags.
bool matchesCatalogFilters(LouvorGroup group, CatalogFilterState filters) {
  if (filters.isEmpty) return true;
  final meta = group.coldigomMeta;
  if (filters.tonalities.isNotEmpty &&
      (meta == null || !filters.tonalities.contains(meta.tonality.trim()))) {
    return false;
  }
  if (filters.rhythms.isNotEmpty &&
      (meta == null || !filters.rhythms.contains(meta.rhythm.trim()))) {
    return false;
  }
  if (filters.categories.isNotEmpty &&
      (meta == null || !filters.categories.contains(meta.category.trim()))) {
    return false;
  }
  if (filters.tags.isNotEmpty &&
      (meta == null || !_hasSelectedTag(meta.tagNames, filters.tags))) {
    return false;
  }
  if (filters.materialKindIds.isNotEmpty &&
      !_hasSelectedKind(group, filters.materialKindIds)) {
    return false;
  }
  return true;
}

bool _hasSelectedTag(List<String> tagNames, Set<String> selected) {
  for (final raw in tagNames) {
    final tag = raw.trim();
    for (final wanted in selected) {
      if (catalogTagMatches(tag, wanted)) return true;
    }
  }
  return false;
}

/// Sem montar `group.materials` (lista nova a cada chamada): 2063 grupos por
/// tecla/filtro.
bool _hasSelectedKind(LouvorGroup group, Set<String> kinds) {
  for (final section in group.sections) {
    for (final entry in section.materials) {
      final kind = entry.louvor.materialKindId;
      if (kind != null && kinds.contains(kind)) return true;
    }
  }
  for (final material in group.extras) {
    final kind = material.materialKindId;
    if (kind != null && kinds.contains(kind)) return true;
  }
  return false;
}
```

- [ ] **Step 5: Tirar os filtros velhos da porta e do pipeline do manifesto**

1. `lib/features/catalog/domain/entities/catalog_query.dart`: apagar os imports de `catalog_materials.dart` e `catalog_filter_state.dart`, o parâmetro `this.filters = defaultFilters,`, a constante `defaultFilters` e o campo `filters`; o doc da classe passa a «Uma pergunta ao catálogo: texto + página. A busca local usa [text]; a remota usa [text], [page] e [pageSize]. Os filtros do catálogo não viajam por aqui: quem filtra é `matchesCatalogFilters`.».
2. `lib/features/catalog/domain/search/plpcg_search_index.dart`: apagar o import de `filter_by_material_and_arranjo.dart`, a linha `const filter = FilterByMaterialAndArranjo();` e o passo de filtro — o fim de `runPlpcgSearchPipeline` fica

```dart
  final searched = search.callIndexed(index, query.text);
  return group(searched, sortByNumber: false);
```

e o doc da função «Pipeline local da Home — UC-01 → UC-02 → agrupamento» passa a «Pipeline de busca do manifesto — UC-01 → agrupamento (sai no plano 3).».
3. `git rm lib/features/catalog/domain/usecases/filter_by_material_and_arranjo.dart test/unit/features/catalog/filter_by_material_and_arranjo_test.dart`.
4. `lib/features/catalog/domain/constants/catalog_materials.dart`: apagar `expandMaterial`, `expandMaterials`, `isDefaultSelection`, `parseFromUrl` e `serializeForUrl` (sem chamador depois disto; `uiMaterials`/`defaultSelected`/constantes ficam para a secção PLPCG do /offline, que o plano 3 apaga). Doc da classe: «Materiais da secção PLPCG do /offline (categorias do manifesto) — sai com ela no plano 3.».
5. `lib/features/catalog/domain/utils/louvor_classification.dart`: apagar `parseArranjosFromUrl` e `serializeArranjosForUrl`.
6. `lib/core/constants/storage_keys.dart`: doc de `catalogFilters` → «Filtros do catálogo (JSON v2: tom, ritmo, categoria, tags, tipos de material) — C13, spec fim-fonte §2.2.».

- [ ] **Step 6: Provider (teste reescrito, falha)**

Substituir `test/unit/features/catalog/catalog_filters_provider_test.dart` por:

```dart
import 'dart:convert';

import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_filters_provider.dart';
import 'package:coldigui/features/library/presentation/providers/library_view_settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  Future<void> setUpPrefs([Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    prefs = await SharedPreferences.getInstance();
  }

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('sem pref: nenhum filtro', () async {
    await setUpPrefs();
    expect(
      createContainer().read(catalogFiltersProvider),
      CatalogFilterState.empty,
    );
  });

  test('toggles gravam o formato v2 e um container novo relê', () async {
    await setUpPrefs();
    final first = createContainer();
    first.read(catalogFiltersProvider.notifier)
      ..toggleTonality('Dm')
      ..toggleRhythm('Fox')
      ..toggleCategory('Clamor')
      ..toggleTag('PES')
      ..toggleMaterialKind('k1');

    final raw =
        jsonDecode(prefs.getString(StorageKeys.catalogFilters)!)
            as Map<String, dynamic>;
    expect(raw['v'], 2);
    expect(raw['tags'], ['PES']);
    expect(
      createContainer().read(catalogFiltersProvider),
      const CatalogFilterState(
        tonalities: {'Dm'},
        rhythms: {'Fox'},
        categories: {'Clamor'},
        tags: {'PES'},
        materialKindIds: {'k1'},
      ),
    );
  });

  test('tocar duas vezes desmarca', () async {
    await setUpPrefs();
    final container = createContainer();
    container.read(catalogFiltersProvider.notifier)
      ..toggleTag('PES')
      ..toggleTag('PES');

    expect(container.read(catalogFiltersProvider).isEmpty, isTrue);
  });

  test('pref no formato antigo {materials, arranjos} é descartada e apagada', () async {
    await setUpPrefs({
      StorageKeys.catalogFilters: jsonEncode({
        'materials': ['Partitura'],
        'arranjos': ['ColAdultos'],
      }),
    });

    final container = createContainer();

    expect(container.read(catalogFiltersProvider), CatalogFilterState.empty);
    await pumpEventQueue();
    expect(prefs.getString(StorageKeys.catalogFilters), isNull);
  });

  test('pref ilegível também é descartada', () async {
    await setUpPrefs({StorageKeys.catalogFilters: 'não é json'});

    expect(
      createContainer().read(catalogFiltersProvider),
      CatalogFilterState.empty,
    );
  });

  test('hydrateFromUrl com params substitui os cinco; sem params mantém o gravado', () async {
    await setUpPrefs();
    final container = createContainer();
    final notifier = container.read(catalogFiltersProvider.notifier)
      ..toggleTonality('Dm');

    notifier.hydrateFromUrl();
    expect(container.read(catalogFiltersProvider).tonalities, {'Dm'});

    notifier.hydrateFromUrl(tags: 'PES,CIAs', materialKinds: 'k1');
    expect(
      container.read(catalogFiltersProvider),
      const CatalogFilterState(tags: {'PES', 'CIAs'}, materialKindIds: {'k1'}),
    );
  });

  test('mexer num filtro volta a /biblioteca à página 1; hidratar da URL não', () async {
    await setUpPrefs();
    final container = createContainer();
    container.read(libraryViewSettingsProvider.notifier).setPage(3);

    container.read(catalogFiltersProvider.notifier).hydrateFromUrl(tags: 'PES');
    expect(container.read(libraryViewSettingsProvider).page, 3);

    container.read(catalogFiltersProvider.notifier).toggleTag('CIAs');
    expect(container.read(libraryViewSettingsProvider).page, 1);
  });

  test('clear esvazia, apaga a pref e volta à página 1', () async {
    await setUpPrefs();
    final container = createContainer();
    container.read(catalogFiltersProvider.notifier).toggleTag('PES');
    container.read(libraryViewSettingsProvider.notifier).setPage(2);

    container.read(catalogFiltersProvider.notifier).clear();

    expect(container.read(catalogFiltersProvider).isEmpty, isTrue);
    expect(container.read(libraryViewSettingsProvider).page, 1);
    await pumpEventQueue();
    expect(prefs.getString(StorageKeys.catalogFilters), isNull);
  });
}
```

- [ ] **Step 7: Provider novo**

Substituir `lib/features/catalog/presentation/providers/catalog_filters_provider.dart` por:

```dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../library/presentation/providers/library_view_settings_provider.dart';
import '../../domain/entities/catalog_filter_state.dart';

// O objeto de valor mora no domínio; quem importava daqui continua a vê-lo.
export '../../domain/entities/catalog_filter_state.dart';

/// Filtros do catálogo — um estado só para a página inicial e a /biblioteca
/// (spec fim-fonte §2.2, C5).
final catalogFiltersProvider =
    NotifierProvider<CatalogFiltersNotifier, CatalogFilterState>(
      CatalogFiltersNotifier.new,
    );

/// Seleção, persistência (C13: pref `catalogFilters`, formato v2) e
/// hidratação da URL.
///
/// Mexer num filtro (toggle ou [clear]) volta a /biblioteca à página 1 — o
/// conjunto de resultados mudou. Hidratar da URL não: a URL traz a página.
class CatalogFiltersNotifier extends Notifier<CatalogFilterState> {
  @override
  CatalogFilterState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(StorageKeys.catalogFilters);
    if (raw == null || raw.isEmpty) return CatalogFilterState.empty;

    CatalogFilterState? stored;
    try {
      stored = CatalogFilterState.fromPersistedJson(jsonDecode(raw));
    } on FormatException {
      stored = null;
    }
    if (stored == null) {
      // Formato antigo `{materials, arranjos}` (filtros que já não existem)
      // ou pref ilegível: descarta e apaga (spec §2.2).
      AppLogger.of(
        'catalog',
      ).warn('Filtros gravados em formato antigo ou inválido; descartados');
      unawaited(prefs.remove(StorageKeys.catalogFilters));
      return CatalogFilterState.empty;
    }
    return stored;
  }

  /// Hidrata os filtros dos params da rota (página inicial ou /biblioteca).
  ///
  /// Chamado no primeiro build das telas mesmo sem params: sem nenhum dos
  /// cinco, mantém o estado atual (gravado) em vez de limpar. Com algum,
  /// a URL manda nos cinco (os ausentes ficam vazios). Não grava.
  void hydrateFromUrl({
    String? tonality,
    String? rhythm,
    String? category,
    String? tags,
    String? materialKinds,
  }) {
    final fromUrl = CatalogFilterState.fromUrl(
      tonality: tonality,
      rhythm: rhythm,
      category: category,
      tags: tags,
      materialKinds: materialKinds,
    );
    if (fromUrl.isEmpty) return;
    state = fromUrl;
  }

  void toggleTonality(String value) =>
      _apply(state.copyWith(tonalities: _toggle(state.tonalities, value)));

  void toggleRhythm(String value) =>
      _apply(state.copyWith(rhythms: _toggle(state.rhythms, value)));

  void toggleCategory(String value) =>
      _apply(state.copyWith(categories: _toggle(state.categories, value)));

  void toggleTag(String name) =>
      _apply(state.copyWith(tags: _toggle(state.tags, name)));

  void toggleMaterialKind(String kindId) => _apply(
    state.copyWith(materialKindIds: _toggle(state.materialKindIds, kindId)),
  );

  /// Tira todos os filtros e apaga a pref.
  void clear() {
    state = CatalogFilterState.empty;
    unawaited(
      ref.read(sharedPreferencesProvider).remove(StorageKeys.catalogFilters),
    );
    ref.read(libraryViewSettingsProvider.notifier).setPage(1);
  }

  void _apply(CatalogFilterState next) {
    state = next;
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .setString(
            StorageKeys.catalogFilters,
            jsonEncode(next.toPersistedJson()),
          ),
    );
    ref.read(libraryViewSettingsProvider.notifier).setPage(1);
  }

  static Set<String> _toggle(Set<String> current, String value) {
    final next = Set<String>.from(current);
    if (!next.remove(value)) next.add(value);
    return next;
  }
}
```

- [ ] **Step 8: Secções do painel (teste que falha)**

```dart
// test/widget/features/catalog/catalog_filter_sections_test.dart
import 'dart:convert';

import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_filters_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/catalog_filter_sections.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';

void main() {
  final index = catalogIndexOf([
    catalogGroup(
      praiseId: 'p1',
      name: 'Hino',
      tonality: 'Dm',
      rhythm: 'Fox',
      category: 'Clamor',
      tags: const ['PES · 9.2026'],
      pdfKinds: const {'k-grade': 'Grade'},
    ),
    catalogGroup(
      praiseId: 'p2',
      name: 'Coro',
      tonality: 'G',
      tags: const ['CIAs'],
      pdfKinds: const {'k-cifra1': 'Cifra I'},
    ),
  ]);

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    Map<String, Object> prefsValues = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefsValues);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        coldigomSearchIndexProvider.overrideWithValue(index),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: const Scaffold(
            body: SingleChildScrollView(child: CatalogFilterSections()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> tapChip(WidgetTester tester, String label) async {
    final chip = find.widgetWithText(FilterChip, label);
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  bool isSelected(WidgetTester tester, String label) =>
      tester.widget<FilterChip>(find.widgetWithText(FilterChip, label)).selected;

  testWidgets('secções e chips saem do índice local, com o pai das tags', (
    tester,
  ) async {
    await pump(tester);

    for (final label in [
      'Tom',
      'Ritmo',
      'Categoria',
      'Tags',
      'Materiais',
      'Dm',
      'G',
      'Fox',
      'Clamor',
      'PES',
      'PES · 9.2026',
      'CIAs',
      'Grade',
      'Cifra I',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('tocar num chip alterna o filtro', (tester) async {
    final container = await pump(tester);

    await tapChip(tester, 'Dm');
    expect(container.read(catalogFiltersProvider).tonalities, {'Dm'});
    expect(isSelected(tester, 'Dm'), isTrue);

    await tapChip(tester, 'Cifra I');
    expect(container.read(catalogFiltersProvider).materialKindIds, {
      'k-cifra1',
    });

    await tapChip(tester, 'Dm');
    expect(container.read(catalogFiltersProvider).tonalities, isEmpty);
  });

  testWidgets(
    'seleção que o catálogo não tem aparece marcada para poder desmarcar',
    (tester) async {
      final container = await pump(
        tester,
        prefsValues: {
          StorageKeys.catalogFilters: jsonEncode(
            const CatalogFilterState(
              tags: {'Sumida'},
              materialKindIds: {'k-velho'},
            ).toPersistedJson(),
          ),
        },
      );

      expect(isSelected(tester, 'Sumida'), isTrue);
      expect(isSelected(tester, 'k-velho'), isTrue);

      await tapChip(tester, 'Sumida');
      expect(container.read(catalogFiltersProvider).tags, isEmpty);
    },
  );
}
```

Apagar `test/widget/features/catalog/category_filters_test.dart` (`git rm`).

- [ ] **Step 9: Widget das secções e painel**

```dart
// lib/features/catalog/presentation/widgets/catalog_filter_sections.dart
import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_filter_options_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_filters_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef _ChipItem = ({String id, String name});

/// Secções de chips dos filtros do catálogo (tom, ritmo, categoria, tags,
/// tipo de material) — as mesmas na página inicial e na /biblioteca.
///
/// As opções vêm do índice local ([catalogFilterOptionsProvider]); a seleção
/// é [catalogFiltersProvider]. Secção sem opções não aparece. Um valor
/// selecionado que o catálogo não tem (pref ou link antigo, valor que sumiu
/// do coldigom) continua visível e marcado — senão o filtro ficaria ativo sem
/// chip para o desmarcar.
class CatalogFilterSections extends ConsumerWidget {
  const CatalogFilterSections({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final options = ref.watch(catalogFilterOptionsProvider);
    final selected = ref.watch(catalogFiltersProvider);
    final notifier = ref.read(catalogFiltersProvider.notifier);

    final sections = [
      _ChipSection(
        title: l10n.coldigomFilterTonality,
        items: _withSelected(_named(options.tonalities), selected.tonalities),
        selectedIds: selected.tonalities,
        onToggle: notifier.toggleTonality,
      ),
      _ChipSection(
        title: l10n.coldigomFilterRhythm,
        items: _withSelected(_named(options.rhythms), selected.rhythms),
        selectedIds: selected.rhythms,
        onToggle: notifier.toggleRhythm,
      ),
      _ChipSection(
        title: l10n.coldigomFilterCategory,
        items: _withSelected(_named(options.categories), selected.categories),
        selectedIds: selected.categories,
        onToggle: notifier.toggleCategory,
      ),
      _ChipSection(
        title: l10n.coldigomFilterTags,
        items: _withSelected(_named(options.tags), selected.tags),
        selectedIds: selected.tags,
        onToggle: notifier.toggleTag,
      ),
      _ChipSection(
        title: l10n.coldigomFilterMaterials,
        items: _withSelected([
          for (final kind in options.materialKinds)
            (id: kind.id, name: kind.name),
        ], selected.materialKindIds),
        selectedIds: selected.materialKindIds,
        onToggle: notifier.toggleMaterialKind,
      ),
    ].where((section) => section.items.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          sections[i],
        ],
      ],
    );
  }

  static List<_ChipItem> _named(List<String> values) => [
    for (final value in values) (id: value, name: value),
  ];

  static List<_ChipItem> _withSelected(
    List<_ChipItem> items,
    Set<String> selected,
  ) {
    final known = {for (final item in items) item.id};
    final missing = [
      for (final id in selected)
        if (!known.contains(id)) id,
    ]..sort();
    return [...items, for (final id in missing) (id: id, name: id)];
  }
}

class _ChipSection extends StatelessWidget {
  const _ChipSection({
    required this.title,
    required this.items,
    required this.selectedIds,
    required this.onToggle,
  });

  final String title;
  final List<_ChipItem> items;
  final Set<String> selectedIds;
  final void Function(String) onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final item in items)
              FilterChip(
                label: Text(item.name),
                selected: selectedIds.contains(item.id),
                showCheckmark: false,
                selectedColor: AppColors.gold.withValues(alpha: 0.3),
                backgroundColor: AppColors.card,
                side: BorderSide(
                  color: selectedIds.contains(item.id)
                      ? AppColors.gold
                      : AppColors.title,
                  width: selectedIds.contains(item.id) ? 2 : 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                onSelected: (_) => onToggle(item.id),
              ),
          ],
        ),
      ],
    );
  }
}
```

Substituir `lib/features/catalog/presentation/widgets/filters_panel.dart` por:

```dart
import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/core/widgets/golden_tagged_container.dart';
import 'package:coldigui/features/catalog/presentation/widgets/catalog_filter_sections.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Painel de filtros colapsável com container dourado (§5.2).
///
/// Usado na página inicial e na /biblioteca, com o mesmo conteúdo
/// ([CatalogFilterSections]). Colapsado mostra
/// [AppLocalizations.filtersTapToExpand].
///
/// Cabeçalho compacto: [GoldenTaggedContainer.compactContentPaddingFor] e
/// altura intrínseca alinham texto e chevron.
class FiltersPanel extends StatefulWidget {
  const FiltersPanel({super.key, this.initiallyExpanded = false});

  /// Expande ao montar quando a URL traz algum filtro.
  final bool initiallyExpanded;

  @override
  State<FiltersPanel> createState() => _FiltersPanelState();
}

class _FiltersPanelState extends State<FiltersPanel> {
  late var _expanded = widget.initiallyExpanded;

  @override
  void didUpdateWidget(FiltersPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.initiallyExpanded && widget.initiallyExpanded) {
      _expanded = true;
    }
  }

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Semantics(
      expanded: _expanded,
      child: GoldenTaggedContainer(
        label: l10n.filtersTitle,
        onTap: _expanded ? null : _toggle,
        contentPadding: _expanded
            ? GoldenTaggedContainer.expandedSectionPaddingFor(context)
            : GoldenTaggedContainer.compactContentPaddingFor(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: _toggle,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      _expanded ? l10n.filtersTitle : l10n.filtersTapToExpand,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w500,
                        height: 1.1,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.title,
                    size: 20,
                  ),
                ],
              ),
            ),
            if (_expanded) ...[
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: CatalogFilterSections(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

`git rm lib/features/catalog/presentation/widgets/category_filters.dart lib/features/catalog/presentation/widgets/classification_filters.dart`.

- [ ] **Step 10: URL da página inicial (teste reescrito, falha)**

Substituir o corpo de `main()` de `test/unit/core/utils/home_url_builder_test.dart` por:

```dart
  test('buildHomeLocation sem params retorna path base', () {
    expect(buildHomeLocation(), RoutePaths.home);
  });

  test('buildHomeLocation combina pesquisa e os filtros do catálogo', () {
    final location = buildHomeLocation(
      pesquisa: 'aleluia',
      tonality: 'Dm',
      rhythm: 'Fox',
      category: 'Clamor',
      tags: 'PES',
      materialKinds: 'k1',
    );

    expect(location, contains('pesquisa=aleluia'));
    expect(location, contains('tonality=Dm'));
    expect(location, contains('rhythm=Fox'));
    expect(location, contains('category=Clamor'));
    expect(location, contains('tags=PES'));
    expect(location, contains('materialKinds=k1'));
  });

  test('buildHomeLocation codifica valores especiais', () {
    final location = buildHomeLocation(
      pesquisa: 'são joão',
      tags: 'PES · 9.2026',
    );
    expect(location, contains(Uri.encodeComponent('são joão')));
    expect(location, contains(Uri.encodeComponent('PES · 9.2026')));
  });

  test('link antigo: materiais/arranjo são ignorados', () {
    final uri = Uri.parse(
      '/?pesquisa=x&materiais=Partitura&arranjo=ColAdultos&tags=PES',
    );

    final location = buildHomeLocationFromUri(uri);

    expect(location, buildHomeLocation(pesquisa: 'x', tags: 'PES'));
    expect(location, isNot(contains('materiais')));
    expect(location, isNot(contains('arranjo')));
  });
```

Substituir `lib/core/utils/home_url_builder.dart` por:

```dart
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/url_sync_params.dart';

/// Monta path da página inicial com query params sincronizados (spec
/// fim-fonte §2.5).
///
/// [pesquisa] vazia é omitida; os filtros do catálogo (os mesmos da
/// /biblioteca) vão em CSV — [tags] por nome, [materialKinds] por id de kind
/// — e são omitidos quando vazios. Valores codificados via
/// [Uri.encodeComponent].
String buildHomeLocation({
  String pesquisa = '',
  String? tonality,
  String? rhythm,
  String? category,
  String? tags,
  String? materialKinds,
}) {
  final params = <String, String>{};

  void put(String key, String? value) {
    if (value != null && value.isNotEmpty) params[key] = value;
  }

  put(UrlSyncParams.pesquisa, pesquisa);
  put(UrlSyncParams.tonality, tonality);
  put(UrlSyncParams.rhythm, rhythm);
  put(UrlSyncParams.category, category);
  put(UrlSyncParams.tags, tags);
  put(UrlSyncParams.materialKinds, materialKinds);

  if (params.isEmpty) return RoutePaths.home;

  final query = params.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
  return '${RoutePaths.home}?$query';
}

/// Normaliza [uri] da página inicial para comparação com [buildHomeLocation].
///
/// `materiais`/`arranjo` de links antigos são ignorados (spec §2.5).
String buildHomeLocationFromUri(Uri uri) => buildHomeLocation(
  pesquisa: uri.queryParameters[UrlSyncParams.pesquisa] ?? '',
  tonality: uri.queryParameters[UrlSyncParams.tonality],
  rhythm: uri.queryParameters[UrlSyncParams.rhythm],
  category: uri.queryParameters[UrlSyncParams.category],
  tags: uri.queryParameters[UrlSyncParams.tags],
  materialKinds: uri.queryParameters[UrlSyncParams.materialKinds],
);
```

Em `lib/core/utils/url_sync_params.dart`, apagar `materiais` e `arranjo`. Em `lib/core/routing/app_router.dart`, na rota `RoutePaths.home`, trocar

```dart
              initialMateriais: params[UrlSyncParams.materiais],
              initialArranjo: params[UrlSyncParams.arranjo],
```

por

```dart
              initialTonality: params[UrlSyncParams.tonality],
              initialRhythm: params[UrlSyncParams.rhythm],
              initialCategory: params[UrlSyncParams.category],
              initialTags: params[UrlSyncParams.tags],
              initialMaterialKinds: params[UrlSyncParams.materialKinds],
```

- [ ] **Step 11: Página inicial — filtros novos**

`lib/features/catalog/presentation/pages/home_screen.dart`:
1. No doc da classe, trocar «Busca com debounce 300ms, filtros material/arranjo em tempo real, resultados como [LouvorGroupCard] (chips agrupados) e sync URL (`pesquisa=`, `materiais=`, `arranjo=`).» por «Busca com debounce 300ms, filtros do catálogo (tom, ritmo, categoria, tags, tipo de material — os mesmos da /biblioteca), resultados como [LouvorGroupCard] e sync URL (`pesquisa=` + params de filtro, spec fim-fonte §2.5).».
2. Trocar o construtor e os campos `initialMateriais`/`initialArranjo` por:

```dart
  const HomeScreen({
    super.key,
    this.initialSearchQuery = '',
    this.initialTonality,
    this.initialRhythm,
    this.initialCategory,
    this.initialTags,
    this.initialMaterialKinds,
  });

  /// Query inicial vinda de `?pesquisa=` na URL.
  final String initialSearchQuery;

  /// CSVs iniciais dos filtros do catálogo (`?tonality=`, `?rhythm=`,
  /// `?category=`, `?tags=` por nome, `?materialKinds=` por id de kind).
  final String? initialTonality;
  final String? initialRhythm;
  final String? initialCategory;
  final String? initialTags;
  final String? initialMaterialKinds;

  bool get _hasInitialFilters =>
      initialTonality != null ||
      initialRhythm != null ||
      initialCategory != null ||
      initialTags != null ||
      initialMaterialKinds != null;
```

3. No estado, acrescentar o método

```dart
  void _hydrateFilters() {
    ref
        .read(catalogFiltersProvider.notifier)
        .hydrateFromUrl(
          tonality: widget.initialTonality,
          rhythm: widget.initialRhythm,
          category: widget.initialCategory,
          tags: widget.initialTags,
          materialKinds: widget.initialMaterialKinds,
        );
  }
```

e trocar as duas chamadas `ref.read(catalogFiltersProvider.notifier).hydrateFromUrl(materiais: widget.initialMateriais, arranjo: widget.initialArranjo)` (em `_hydrateFromUrl` e em `didUpdateWidget`) por `_hydrateFilters();`.
4. Em `didUpdateWidget`, o `filtersChanged` passa a

```dart
    final filtersChanged =
        oldWidget.initialTonality != widget.initialTonality ||
        oldWidget.initialRhythm != widget.initialRhythm ||
        oldWidget.initialCategory != widget.initialCategory ||
        oldWidget.initialTags != widget.initialTags ||
        oldWidget.initialMaterialKinds != widget.initialMaterialKinds;
```

5. Em `_applyUrlSyncFromState`, o `target` passa a

```dart
    final target = buildHomeLocation(
      pesquisa: pesquisa,
      tonality: filters.tonalityUrlValue,
      rhythm: filters.rhythmUrlValue,
      category: filters.categoryUrlValue,
      tags: filters.tagsUrlValue,
      materialKinds: filters.materialKindsUrlValue,
    );
```

6. No `build`, `FiltersPanel(initiallyExpanded: widget.initialMateriais != null || widget.initialArranjo != null)` passa a `FiltersPanel(initiallyExpanded: widget._hasInitialFilters)`.

`lib/features/catalog/presentation/widgets/home_empty_state.dart`, em `_NoResultsContent.build`:

```dart
    final hasActiveFilter = !ref.watch(catalogFiltersProvider).isEmpty;
```

(no lugar das duas linhas `final filters = …` / `final hasActiveFilter = filters.materiaisUrlValue != null || …`) e o botão passa a `onPressed: () => ref.read(catalogFiltersProvider.notifier).clear(),`. No doc da classe, «limpar filtros (se houver filtro fora do padrão)» → «limpar filtros (se houver algum ativo)».

`lib/features/catalog/presentation/providers/home_search_provider.dart`:
1. Acrescentar o import `import '../../domain/usecases/matches_catalog_filters.dart';`.
2. `homeLocalSearchProvider` passa a (transitório até a Task 8):

```dart
final homeLocalSearchProvider = Provider<List<LouvorGroup>>((ref) {
  final query = ref.watch(homeSearchDebouncedQueryProvider);
  final filters = ref.watch(catalogFiltersProvider);
  final plpcg = ref.watch(plpcgCatalogSourceProvider);
  final coldigom = ref.watch(coldigomCatalogSourceProvider);
  final catalogQuery = CatalogQuery(text: query);
  final merged = mergeLocalSearchResults(
    plpcg: plpcg.searchLocal(catalogQuery),
    coldigom: coldigom.searchLocal(catalogQuery),
    manifestPraiseIds: ref.watch(manifestMaterialAliasesProvider).praiseIds,
  );
  if (filters.isEmpty) return merged;
  return [
    for (final group in merged)
      if (matchesCatalogFilters(group, filters)) group,
  ];
});
```

e o doc dele termina com «Os filtros do catálogo valem para toda a lista (`matchesCatalogFilters`).» em vez de «Os filtros UC-02 valem só para o PLPCG.».
3. Em `homeSearchStateProvider`, depois de `final localGroups = ref.watch(homeLocalSearchProvider);`, acrescentar `final filters = ref.watch(catalogFiltersProvider);` e o `newGroups` passa a

```dart
  // Os «novos» passam pelo mesmo predicado da lista local (spec §2.4), no
  // cliente — os nomes de tag não viram ids do servidor.
  final newGroups = [
    for (final g in remote.value?.groups ?? const <LouvorGroup>[])
      if (!localIds.contains(g.groupId) && matchesCatalogFilters(g, filters))
        g,
  ];
```

- [ ] **Step 12: /biblioteca — filtros no pipeline e na tela**

`lib/features/library/presentation/providers/library_group_results_provider.dart`: acrescentar os imports

```dart
import '../../../catalog/domain/usecases/matches_catalog_filters.dart';
import '../../../catalog/presentation/providers/catalog_filters_provider.dart';
```

e o `libraryFilteredGroupsProvider` passa a

```dart
final libraryFilteredGroupsProvider = Provider<List<LouvorGroup>>((ref) {
  final groups = ref.watch(coldigomSearchIndexProvider).groups;
  final filters = ref.watch(catalogFiltersProvider);
  final sortBy = ref.watch(
    libraryViewSettingsProvider.select((view) => view.sortBy),
  );
  final filtered = filters.isEmpty
      ? groups
      : [
          for (final group in groups)
            if (matchesCatalogFilters(group, filters)) group,
        ];
  return ref.watch(sortLouvorGroupsProvider)(filtered, sortBy: sortBy);
});
```

(doc: «índice local do catálogo → `matchesCatalogFilters` → ordenar …»).

`lib/features/library/presentation/pages/library_screen.dart` — versão final. Sobre a da Task 6:
1. Imports novos: `package:coldigui/features/catalog/presentation/providers/catalog_filters_provider.dart` e `package:coldigui/features/catalog/presentation/widgets/filters_panel.dart`.
2. Doc da classe: «… o catálogo local inteiro, filtrado (os mesmos filtros da página inicial, [catalogFiltersProvider]), ordenado e paginado …».
3. No widget, depois dos campos:

```dart
  bool get _hasInitialFilters =>
      initialTonality != null ||
      initialRhythm != null ||
      initialCategory != null ||
      initialTags != null ||
      initialMaterialKinds != null;
```

4. No estado, o método

```dart
  void _hydrateFilters() {
    ref
        .read(catalogFiltersProvider.notifier)
        .hydrateFromUrl(
          tonality: widget.initialTonality,
          rhythm: widget.initialRhythm,
          category: widget.initialCategory,
          tags: widget.initialTags,
          materialKinds: widget.initialMaterialKinds,
        );
  }
```

e `_hydrateFromUrl` chama `_hydrateFilters();` **antes** de `_hydrateView();` (os toggles voltam à página 1, a hidratação não; a vista vem depois e manda na página).
5. `didUpdateWidget` passa a:

```dart
  @override
  void didUpdateWidget(LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final filtersChanged =
        oldWidget.initialTonality != widget.initialTonality ||
        oldWidget.initialRhythm != widget.initialRhythm ||
        oldWidget.initialCategory != widget.initialCategory ||
        oldWidget.initialTags != widget.initialTags ||
        oldWidget.initialMaterialKinds != widget.initialMaterialKinds;
    final viewChanged =
        oldWidget.initialOrdenar != widget.initialOrdenar ||
        oldWidget.initialItensPorPagina != widget.initialItensPorPagina ||
        oldWidget.initialPagina != widget.initialPagina;
    if (!filtersChanged && !viewChanged) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (filtersChanged) _hydrateFilters();
      if (viewChanged) _hydrateView();
    });
  }
```

6. Em `_applyUrlSyncFromState`:

```dart
    final filters = ref.read(catalogFiltersProvider);
    final view = ref.read(libraryViewSettingsProvider);
    final target = buildLibraryLocation(
      tonality: filters.tonalityUrlValue,
      rhythm: filters.rhythmUrlValue,
      category: filters.categoryUrlValue,
      tags: filters.tagsUrlValue,
      materialKinds: filters.materialKindsUrlValue,
      ordenar: view.ordenarUrlValue ?? view.sortBy,
      itensPorPagina: view.itensPorPaginaUrlValue ?? '${view.itemsPerPage}',
      pagina: view.paginaUrlValue ?? '${view.page}',
    );
```

(comentário: «Filtros, ordenação e página espelham estado — replaceState (P4).»).
7. No `build`, antes do listener de `libraryViewSettingsProvider`:

```dart
    ref.listen<CatalogFilterState>(catalogFiltersProvider, (_, _) {
      if (!_urlSyncEnabled) return;
      _syncUrlFromState();
    });
```

8. Na coluna do topo, antes de `const LibraryViewControls(),`:

```dart
                      FiltersPanel(
                        initiallyExpanded: widget._hasInitialFilters,
                      ),
                      const SizedBox(height: 12),
```

- [ ] **Step 13: Ajustar testes existentes**

1. `test/unit/features/library/library_group_results_provider_test.dart` — acrescentar o import `import 'package:coldigui/features/catalog/presentation/providers/catalog_filters_provider.dart';` e os testes:

```dart
  test('filtros do catálogo: E entre filtros, OU dentro', () {
    final c = containerWith([
      catalogGroup(praiseId: 'p1', number: '001', name: 'A', tonality: 'Dm', tags: const ['CIAs']),
      catalogGroup(praiseId: 'p2', number: '002', name: 'B', tonality: 'G', tags: const ['CIAs']),
      catalogGroup(praiseId: 'p3', number: '003', name: 'C', tonality: 'Dm', tags: const ['PES']),
    ]);
    final filters = c.read(catalogFiltersProvider.notifier)..toggleTag('CIAs');
    expect(ids(c), ['p1', 'p2']);

    filters.toggleTonality('Dm');
    expect(ids(c), ['p1']);

    filters.toggleTonality('G');
    expect(ids(c), ['p1', 'p2']);
  });

  test('mexer num filtro volta à página 1', () {
    final c = containerWith(numbered(25));
    c.read(libraryViewSettingsProvider.notifier).setPage(3);

    c.read(catalogFiltersProvider.notifier).toggleMaterialKind('k-partitura');

    expect(c.read(libraryGroupResultsProvider).page, 1);
    expect(c.read(libraryGroupResultsProvider).totalItems, 25);
  });
```

2. `test/widget/features/library/library_screen_test.dart` — acrescentar:

```dart
  testWidgets('o painel de filtros usa o índice e filtra a lista', (
    tester,
  ) async {
    await pumpLibrary(tester, [
      catalogGroup(praiseId: 'p1', number: '001', name: 'Louvor 1', tonality: 'Dm'),
      catalogGroup(praiseId: 'p2', number: '002', name: 'Louvor 2', tonality: 'G'),
    ]);

    await tester.tap(find.text('Filtros'));
    await tester.pumpAndSettle();
    final dm = find.widgetWithText(FilterChip, 'Dm');
    await tester.ensureVisible(dm);
    await tester.tap(dm);
    await tester.pumpAndSettle();

    expect(find.text('#001 — Louvor 1'), findsOneWidget);
    expect(find.text('#002 — Louvor 2'), findsNothing);
  });
```

3. `test/unit/features/catalog/home_search_provider_test.dart` — nos dois testes que chamam `toggleMaterial('Partitura')` (`'mudar o filtro re-deriva só a busca local'` e `'mudar o filtro não re-busca a remota'`), trocar por `toggleTonality('Sem tom')` (nenhum grupo local tem esse tom → a lista local esvazia, a remota não é refeita). Acrescentar o teste:

```dart
  test('os «novos» do remoto passam pelo mesmo filtro da lista local', () async {
    final emDm = LouvorGroup(
      groupId: 'cold-dm',
      numero: '901',
      nome: 'Em Dm',
      sections: const [],
      coldigomMeta: const ColdigomPraiseMetadata(name: 'Em Dm', tonality: 'Dm'),
    );
    final source = _RecordingCatalogSource(
      (query) async => CatalogSearchPage(
        groups: [_coldigomGroup('cold-2'), emDm],
        page: query.page,
      ),
    );
    final container = createContainer(source);
    keepStateAlive(container);
    await pumpEventQueue();

    container.read(catalogFiltersProvider.notifier).toggleTonality('Dm');
    container
        .read(homeSearchDebouncedQueryProvider.notifier)
        .setImmediate('aleluia');
    await pumpEventQueue();

    final state = container.read(homeSearchStateProvider);
    expect(state.newGroups.map((g) => g.groupId), ['cold-dm']);
  });
```

4. `test/widget/features/catalog/home_empty_state_test.dart`:
   - `_DefaultFiltersNotifier.build()` passa a devolver `CatalogFilterState.empty`;
   - nos dois testes que fazem `.toggleArranjo('ColAdultos')`, trocar por `.toggleTag('PES')`;
   - no teste `'filtro fora do padrão mostra "Limpar filtros" e chama reset'` (renomear para `'filtro ativo mostra "Limpar filtros" e limpa'`), as duas asserções finais passam a `expect(container.read(catalogFiltersProvider).isEmpty, isTrue);`.
5. `test/unit/features/catalog/plpcg_search_index_test.dart` — `_query` passa a `CatalogQuery _query(String text) => CatalogQuery(text: text);` (sem `materiais`/`arranjos`); apagar o teste `'aplica o filtro de material da query'` e os imports de `catalog_materials.dart` e `catalog_filter_state.dart`.
6. `test/unit/features/catalog/catalog_source_test.dart` — `_query` passa a `CatalogQuery _query(String text, {int page = 1}) => CatalogQuery(text: text, page: page);`; apagar o teste `'PlpcgCatalogSource.searchLocal filtra por materiais'` e os imports que ficarem sem uso (`catalog_materials.dart`, `catalog_filter_state.dart`/`catalog_filters_provider.dart`).
7. `test/unit/features/catalog/catalog_materials_test.dart` — apagar o grupo `'CatalogMaterials'` inteiro e o teste `'parseArranjosFromUrl vazio retorna conjunto vazio'`; fica só `'baseClassification remove parênteses'` (e o import de `catalog_materials.dart` sai).

- [ ] **Step 14: Correr e ver passar**

Run: `flutter test test/unit/features/catalog/ test/widget/features/catalog/ test/unit/features/library/ test/widget/features/library/ test/unit/core/utils/`
Expected: PASS.
Run: `grep -rn "selectedMaterials\|selectedArranjos\|materiaisUrlValue\|arranjoUrlValue\|toggleMaterial(\|toggleArranjo\|CategoryFilters\|ClassificationFilters\|showPlpcgSections\|additionalExpandedSections\|initialMateriais\|initialArranjo\|UrlSyncParams.materiais\|UrlSyncParams.arranjo\|FilterByMaterialAndArranjo\|defaultFilters" lib test`
Expected: nenhum resultado.
Run: `flutter analyze`
Expected: sem issues.

- [ ] **Step 15: Commit**

```bash
git add -A lib/features/catalog lib/features/library lib/core test/unit/features/catalog test/widget/features/catalog test/unit/features/library test/widget/features/library test/unit/core/utils
git commit -m "feat(catalog): um conjunto de filtros (tom, ritmo, categoria, tags, tipo) na página inicial e na /biblioteca

Predicado único matchesCatalogFilters (OU dentro, E entre, tag pai
inclui filhos, tipo por materialKindId); opções do índice local; URL
com os mesmos params nas duas rotas; pref antiga descartada.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---
## Unidade 4 — Página inicial

### Task 8: página inicial só do índice (sem manifesto)

**Files:**
- Modify: `lib/features/catalog/presentation/providers/home_search_provider.dart`
- Modify: `lib/features/catalog/presentation/providers/home_remote_search_provider.dart`
- Modify (reescrito): `lib/features/catalog/presentation/providers/known_praise_ids_provider.dart`
- Modify: `lib/features/catalog/presentation/providers/home_search_state.dart` (só docs)
- Modify (reescrito): `lib/features/catalog/presentation/pages/home_screen.dart`
- Modify: `lib/features/catalog/presentation/widgets/home_empty_state.dart` (só doc), `lib/features/app_shell/presentation/shell_scaffold.dart` (só comentário)
- Modify: `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb` (+ gerados)
- Test (reescritos): `test/unit/features/catalog/known_praise_ids_provider_test.dart`, `test/widget/features/catalog/home_screen_error_test.dart`, `test/integration/uc01_search_home_test.dart`
- Test (ajustados): `test/unit/features/catalog/home_search_provider_test.dart`, `test/unit/features/catalog/home_remote_search_provider_test.dart`, `test/widget/features/catalog/home_screen_l10n_test.dart`, `test/widget/features/catalog/home_search_test.dart`, `test/widget/features/catalog/home_search_keyboard_test.dart`, `test/widget/features/catalog/home_empty_state_test.dart`

**Interfaces:**
- Consumes: `coldigomSearchIndexProvider`, `catalogIndexStatusProvider`, `coldigomCatalogSyncProvider`, helpers `catalogIndexOverrides`/`FakeColdigomCatalogSyncNotifier`/`catalogGroup`/`catalogIndexOf` (Tasks 2 e 4); `matchesCatalogFilters`, `catalogFiltersProvider` (Task 7).
- Produces:
  - `homeLocalSearchProvider` = `ColdigomSearchIndex.search(query)` filtrado por `matchesCatalogFilters` (spec §2.4).
  - `homeRemoteSearchProvider` lê `coldigomCatalogSourceProvider` (não o composite).
  - `knownPraiseIdsProvider` = `coldigomSearchIndexProvider.catalogIds`.
  - `HomeScreen` mostra skeleton em `CatalogIndexStatus.loading`, `catalogLoadError` + «Tentar novamente» (→ `sync()`) em `failed`; reconexão com índice vazio chama `sync()`.
  - Nenhum ficheiro da página inicial nem da /biblioteca importa manifesto, `plpcgCatalogSourceProvider`, `manifestMaterialAliasesProvider` ou `catalogSourceProvider` (C7).

- [ ] **Step 1: Testes que falham**

Substituir `test/unit/features/catalog/known_praise_ids_provider_test.dart` por:

```dart
import 'package:coldigui/features/catalog/presentation/providers/known_praise_ids_provider.dart';
import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('são os catalogIds do índice, inclusive praises fora da busca', () {
    final container = ProviderContainer(
      overrides: [
        coldigomSearchIndexProvider.overrideWithValue(
          ColdigomSearchIndex.build(const [], catalogIds: {'p-index', 'p-yt'}),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(knownPraiseIdsProvider), {'p-index', 'p-yt'});
  });
}
```

Substituir `test/widget/features/catalog/home_screen_error_test.dart` por:

```dart
import 'dart:async';

import 'package:coldigui/core/network/connectivity_stream_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/catalog/presentation/pages/home_screen.dart';
import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart' hide SearchBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';
import '../../../helpers/louvores_manifest_test_helpers.dart';

Widget _homeErrorTestApp({
  required SharedPreferences prefs,
  required List<Override> extraOverrides,
}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      // O estado vazio ainda resolve os «recentes» pelo lookup de materiais,
      // que lê o manifesto até o plano 3 o reapontar — sem isto ele abriria
      // o Isar e a rede de verdade.
      louvoresManifestOverride(LouvoresManifest.fromLouvores(const [])),
      ...extraOverrides,
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('pt'),
      home: const HomeScreen(),
    ),
  );
}

/// `pumpAndSettle` trava com o shimmer do skeleton (animação em loop).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

const _failed = ColdigomCatalogSyncState(
  lastResult: ColdigomCatalogSyncFailed('sem rede'),
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'catálogo vazio com sync falhado: erro e «Tentar novamente» chama sync()',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final sync = FakeColdigomCatalogSyncNotifier(_failed);

      await tester.pumpWidget(
        _homeErrorTestApp(
          prefs: prefs,
          extraOverrides: [
            ...catalogIndexOverrides(ColdigomSearchIndex.empty, sync: sync),
            connectivityStreamProvider.overrideWith(
              (ref) => const Stream<bool>.empty(),
            ),
          ],
        ),
      );
      await _settle(tester);

      expect(find.text('Não foi possível carregar o catálogo'), findsOneWidget);
      final retry = find.widgetWithText(FilledButton, 'Tentar novamente');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await _settle(tester);

      expect(sync.syncCalls, 1);
    },
  );

  testWidgets('a rede volta com o catálogo vazio: sync() sozinho', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final sync = FakeColdigomCatalogSyncNotifier(_failed);
    final connectivity = StreamController<bool>();
    addTearDown(connectivity.close);

    await tester.pumpWidget(
      _homeErrorTestApp(
        prefs: prefs,
        extraOverrides: [
          ...catalogIndexOverrides(ColdigomSearchIndex.empty, sync: sync),
          connectivityStreamProvider.overrideWith((ref) => connectivity.stream),
        ],
      ),
    );
    await _settle(tester);
    expect(sync.syncCalls, 0);

    connectivity.add(true);
    await _settle(tester);

    expect(sync.syncCalls, 1);
  });

  testWidgets('catálogo pronto: sem erro, e a volta da rede não sincroniza', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final sync = FakeColdigomCatalogSyncNotifier(_failed);
    final connectivity = StreamController<bool>();
    addTearDown(connectivity.close);

    await tester.pumpWidget(
      _homeErrorTestApp(
        prefs: prefs,
        extraOverrides: [
          ...catalogIndexOverrides(
            catalogIndexOf([catalogGroup(praiseId: 'p1', name: 'Aleluia')]),
            sync: sync,
          ),
          connectivityStreamProvider.overrideWith((ref) => connectivity.stream),
        ],
      ),
    );
    await _settle(tester);

    connectivity.add(true);
    await _settle(tester);

    expect(find.text('Não foi possível carregar o catálogo'), findsNothing);
    expect(sync.syncCalls, 0);
  });
}
```

Substituir `test/integration/uc01_search_home_test.dart` por:

```dart
import 'package:flutter_test/flutter_test.dart';

import '../helpers/coldigom_catalog_test_helpers.dart';

void main() {
  test('UC-01 integração — busca por número no índice do catálogo', () {
    final index = catalogIndexOf([
      catalogGroup(praiseId: 'p-100', number: '100', name: 'Louvor de teste'),
      catalogGroup(praiseId: 'p-101', number: '101', name: 'Outro louvor'),
    ]);

    final results = index.search('100');

    expect(results, hasLength(1));
    expect(results.first.groupId, 'p-100');
  });
}
```

Em `test/unit/features/catalog/home_search_provider_test.dart` (a página inicial deixa de ler manifesto e composite):
1. Imports: apagar `catalog_source_provider.dart`, `domain/entities/catalog_material.dart`, `domain/entities/louvor.dart`, `domain/entities/louvores_manifest.dart`, `domain/ports/catalog_source.dart` e `louvores_manifest_provider.dart`; acrescentar `package:coldigui/features/coldigom/data/providers/coldigom_catalog_source_provider.dart`, `package:coldigui/features/coldigom/data/sources/coldigom_catalog_source.dart` e `'../../../helpers/coldigom_catalog_test_helpers.dart'`.
2. Apagar `_louvor`, `_MutableManifestNotifier` e, em `main()`, a lista `catalog`.
3. Trocar `_RecordingCatalogSource` por:

```dart
/// Fonte Coldigom que conta as buscas remotas e responde pelo roteiro.
class _RecordingCatalogSource extends ColdigomCatalogSource {
  _RecordingCatalogSource(this._respond);

  factory _RecordingCatalogSource.ok() {
    return _RecordingCatalogSource(
      (query) async => CatalogSearchPage(groups: const [], page: query.page),
    );
  }

  final Future<CatalogSearchPage> Function(CatalogQuery query) _respond;

  final queries = <CatalogQuery>[];

  int get searchCalls => queries.length;

  @override
  Future<CatalogSearchPage> search(
    CatalogQuery query, {
    SearchCancellation? cancellation,
  }) {
    queries.add(query);
    return _respond(query);
  }
}
```

4. Acrescentar, antes de `_MutableColdigomIndexNotifier`:

```dart
/// Catálogo local dos testes: «Aleluia» (001) e «São João» (002).
final _defaultIndex = catalogIndexOf([
  catalogGroup(praiseId: 'p-001', number: '001', name: 'Aleluia'),
  catalogGroup(praiseId: 'p-002', number: '002', name: 'São João'),
]);
```

e `_MutableColdigomIndexNotifier.build()` passa a devolver `_defaultIndex`.
5. `createContainer` passa a:

```dart
  ProviderContainer createContainer(
    ColdigomCatalogSource source, {
    bool online = true,
    ColdigomSearchIndex? index,
    // Por padrão a hidratação já "terminou" com o mesmo `index` — os testes
    // do gate antes da hidratação e da invalidação por `syncAfterAdoption`
    // passam o próprio override (Riverpod rejeita sobrescrever o mesmo
    // provider duas vezes).
    Override? hydrationOverride,
    Override? searchIndexOverride,
    List<Override> extra = const [],
  }) {
    final effectiveIndex = index ?? _defaultIndex;
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        coldigomCatalogSourceProvider.overrideWithValue(source),
        connectivityStreamProvider.overrideWith((ref) => Stream.value(online)),
        adoptColdigomSearchNoveltiesProvider.overrideWithValue(adopter),
        coldigomCatalogSyncProvider.overrideWith(() => syncNotifier),
        hydrationOverride ??
            coldigomCatalogHydrationProvider.overrideWith(
              (ref) async => effectiveIndex,
            ),
        searchIndexOverride ??
            coldigomSearchIndexProvider.overrideWithValue(effectiveIndex),
        ...extra,
      ],
    );
    addTearDown(container.dispose);
    return container;
  }
```

6. Testes:
   - `'grupos concatenam local (PLPCG) e remoto (Coldigom) nessa ordem'` → renomear para `'grupos concatenam local e remoto nessa ordem'` (corpo igual).
   - `'grupo remoto com o mesmo groupId de um local não duplica'`: o grupo remoto passa a ter `groupId: 'p-001'` (o `Aleluia` do índice) e a última asserção filtra por `'p-001'`; o comentário do topo passa a «Um grupo remoto com o id de um praise que o índice já devolveu não duplica: `newGroups` filtra ids já locais.».
   - `'erro remoto marca remoteFailed; …'`: comentário «Os resultados PLPCG continuam visíveis» → «Os resultados locais continuam visíveis».
   - `'novo manifest re-deriva só a busca local'` → substituir por:

```dart
  test('novo índice re-deriva só a busca local', () async {
    final source = _RecordingCatalogSource.ok();
    final container = createContainer(
      source,
      searchIndexOverride: coldigomSearchIndexProvider.overrideWith(
        (ref) => ref.watch(_mutableColdigomIndexProvider),
      ),
    );
    keepStateAlive(container);
    await pumpEventQueue();

    container
        .read(homeSearchDebouncedQueryProvider.notifier)
        .setImmediate('aleluia');
    await pumpEventQueue();

    expect(source.searchCalls, 1);
    final before = container.read(homeSearchStateProvider).localGroups;
    expect(before, isNotEmpty);

    container
        .read(_mutableColdigomIndexProvider.notifier)
        .update(
          catalogIndexOf([
            catalogGroup(praiseId: 'p-001', number: '001', name: 'Aleluia'),
            catalogGroup(praiseId: 'p-003', number: '003', name: 'Aleluia nova'),
          ]),
        );
    await pumpEventQueue();

    final after = container.read(homeSearchStateProvider).localGroups;
    expect(after.length, greaterThan(before.length));
    expect(source.searchCalls, 1);
  });
```

   - `'remoto com extra → updatedWithNew, …'`: `expect(adopter.knownSeen, isEmpty);` → `expect(adopter.knownSeen, {'p-001', 'p-002'});` (o índice por omissão já conhece esses dois). Qualquer outra asserção de `knownSeen` vazio que dependa do índice por omissão muda igual.
   - Apagar o teste `'praise do manifest devolvido pelo remoto não é «novo» nem candidato a adoção'` (não há mais manifesto na página inicial).

Em `test/unit/features/catalog/home_remote_search_provider_test.dart`:
1. Imports: apagar `catalog_source_provider.dart`, `catalog_material.dart`, `louvores_manifest.dart`, `ports/catalog_source.dart` e `'../../../helpers/louvores_manifest_test_helpers.dart'`; acrescentar `coldigom_catalog_source_provider.dart`, `coldigom/data/sources/coldigom_catalog_source.dart`, `coldigom/domain/search/coldigom_search_index.dart`, `coldigom/presentation/providers/coldigom_catalog_providers.dart` e `'../../../helpers/coldigom_catalog_test_helpers.dart'`.
2. `_RecordingCatalogSource` passa a `extends ColdigomCatalogSource` e fica só com `queries`, `cancellations`, `searchCalls`, o construtor/`ok()` e o override de `search` (apagar `searchLocal`, `groupById`, `materialById`, `groupForMaterial`).
3. `_createContainer(ColdigomCatalogSource source)`:

```dart
ProviderContainer _createContainer(ColdigomCatalogSource source) {
  final container = ProviderContainer(
    overrides: [
      coldigomCatalogSourceProvider.overrideWithValue(source),
      // `homeRemoteSearchProvider` lê `knownPraiseIdsProvider` (índice) e o
      // notifier do sync: sem estes overrides um container nu tentaria
      // abrir o Isar e bater na rede.
      coldigomSearchIndexProvider.overrideWithValue(ColdigomSearchIndex.empty),
      coldigomCatalogSyncProvider.overrideWith(
        FakeColdigomCatalogSyncNotifier.new,
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}
```

Nos testes de widget da página inicial, o override de manifesto vazio **fica** onde existe: o estado vazio (`HomeEmptyState`) ainda resolve os «recentes» por `catalogMaterialLookupProvider`, que lê o manifesto até o plano 3 o reapontar. O que muda é que o catálogo passa a vir do índice.

Em `test/widget/features/catalog/home_screen_l10n_test.dart`:
1. Imports: acrescentar `dart:async`, `coldigom/domain/search/coldigom_search_index.dart`, `coldigom/presentation/providers/coldigom_catalog_providers.dart` e `'../../../helpers/coldigom_catalog_test_helpers.dart'`.
2. `'HomeScreen exibe hint de busca localizado em pt'`: depois de `louvoresManifestOverride(LouvoresManifest.fromLouvores(const [])),`, acrescentar `...catalogIndexOverrides(catalogIndexOf([catalogGroup(praiseId: 'p1', name: 'Aleluia')])),`.
3. Apagar `'HomeScreen exibe banner quando catálogo está obsoleto'` (o banner saiu com o manifesto).
4. `'HomeScreen exibe skeleton enquanto manifest carrega'` → renomear para `'HomeScreen exibe skeleton enquanto o índice hidrata'` e trocar `louvoresManifestLoadingOverride(),` por

```dart
          louvoresManifestOverride(LouvoresManifest.fromLouvores(const [])),
          coldigomCatalogHydrationProvider.overrideWith(
            (ref) => Completer<ColdigomSearchIndex>().future,
          ),
          coldigomCatalogSyncProvider.overrideWith(
            FakeColdigomCatalogSyncNotifier.new,
          ),
```

Em `test/widget/features/catalog/home_search_test.dart`, em `_homeSearchTestOverrides`, trocar a linha `louvoresManifestOverride(LouvoresManifest.fromLouvores(catalog)),` e o comentário seguinte («Acervo vazio: estes testes medem debounce/eco de URL sobre a busca PLPCG…») por:

```dart
    // Manifesto vazio só para o lookup dos «recentes» do estado vazio (até
    // o plano 3); o catálogo destes testes vem do índice, e a busca remota
    // fica vazia por omissão (a validação remota tem cobertura própria).
    louvoresManifestOverride(LouvoresManifest.fromLouvores(const [])),
    ...catalogIndexOverrides(
      catalogIndexOf([
        for (final louvor in catalog)
          catalogGroup(
            praiseId: 'p-${louvor.numero}',
            number: louvor.numero,
            name: louvor.nome,
          ),
      ]),
    ),
```

e acrescentar o import `'../../../helpers/coldigom_catalog_test_helpers.dart'`.

Em `test/widget/features/catalog/home_search_keyboard_test.dart`, em `_pumpHome`, depois de `louvoresManifestOverride(LouvoresManifest.fromLouvores(const [])),`, acrescentar `catalogIndexStatusProvider.overrideWithValue(CatalogIndexStatus.ready),` e o import `coldigom/presentation/providers/coldigom_catalog_providers.dart`.

Em `test/widget/features/catalog/home_empty_state_test.dart`, trocar todas as ocorrências do texto `'Sem conexão — o acervo Coldigom pode estar incompleto nesta busca.'` por `'Sem conexão — o catálogo pode estar incompleto nesta busca.'` e, nos nomes dos testes, «aviso Coldigom» por «aviso de catálogo incompleto» e «catálogo Coldigom local» por «catálogo local».

- [ ] **Step 2: Correr e ver falhar**

Run: `flutter test test/unit/features/catalog/known_praise_ids_provider_test.dart test/widget/features/catalog/home_screen_error_test.dart test/unit/features/catalog/home_search_provider_test.dart test/widget/features/catalog/home_empty_state_test.dart`
Expected: FAIL — `knownPraiseIdsProvider` ainda une o manifesto; a página inicial ainda observa `louvoresManifestProvider`; o texto do aviso é o antigo.

- [ ] **Step 3: Busca local, remota e ids conhecidos**

Em `lib/features/catalog/presentation/providers/home_search_provider.dart`:
1. Imports: apagar `coldigom_catalog_source_provider.dart`, `plpcg_catalog_source_provider.dart`, `composite_catalog_source.dart` e `manifest_material_aliases_provider.dart`.
2. No doc do topo, o diagrama passa a

```dart
/// ```
/// homeSearchQueryProvider (texto cru)
///   → homeSearchDebouncedQueryProvider (300 ms)
///       ├→ homeLocalSearchProvider   (índice do catálogo + filtros)
///       └→ homeRemoteSearchProvider((query, 1))  (valida e traz «novos»; só com rede)
///             → homeSearchStateProvider → HomeSearchResultsSliver
/// ```
```

3. `homeLocalSearchProvider` passa a:

```dart
/// Resultados locais da query + filtros correntes — **síncronos**, do índice
/// do catálogo (`ColdigomSearchIndex.search`: número exato → título exato →
/// parcial) filtrados por `matchesCatalogFilters` (spec fim-fonte §2.4).
///
/// Observa o índice hidratado, a query e os filtros: um sync do catálogo ou
/// um chip re-derivam só esta lista, sem tocar a rede.
final homeLocalSearchProvider = Provider<List<LouvorGroup>>((ref) {
  final query = ref.watch(homeSearchDebouncedQueryProvider);
  final filters = ref.watch(catalogFiltersProvider);
  final results = ref.watch(coldigomSearchIndexProvider).search(query);
  if (filters.isEmpty) return results;
  return [
    for (final group in results)
      if (matchesCatalogFilters(group, filters)) group,
  ];
});
```

4. No doc de `homeSearchStateProvider`, «A lista é a local (PLPCG + Coldigom do índice)» → «A lista é a local (índice do catálogo)».

Em `lib/features/catalog/presentation/providers/home_remote_search_provider.dart`:
1. Trocar o import `'../../data/providers/catalog_source_provider.dart'` por `'../../../coldigom/data/providers/coldigom_catalog_source_provider.dart'`.
2. `final source = ref.read(catalogSourceProvider);` → `final source = ref.read(coldigomCatalogSourceProvider);` (o comentário do `read` fica).
3. Comentário «Índice Coldigom ∪ praises do manifest — um praise do manifest nunca é adotado para o Isar Coldigom.» → «Praises que o catálogo local já conhece (`catalogIds`).».
4. No doc de `HomeRemoteSearchKey`, o parágrafo dos filtros passa a «Os filtros do catálogo ficam de fora de propósito: são aplicados no cliente (`matchesCatalogFilters`), inclusive aos «novos». É por isso que mexer num chip não re-busca nada na rede.».

Substituir `lib/features/catalog/presentation/providers/known_praise_ids_provider.dart` por:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../coldigom/presentation/providers/coldigom_catalog_providers.dart';

/// Praises que o app já conhece localmente: o catálogo hidratado inteiro
/// ([ColdigomSearchIndex.catalogIds], inclui os que não entram na busca,
/// ex. só-YouTube).
///
/// É contra isto que a página inicial decide o chip «novo» e a adoção dos
/// «novos» da pesquisa remota (spec fim-fonte §2.4).
final knownPraiseIdsProvider = Provider<Set<String>>((ref) {
  return ref.watch(coldigomSearchIndexProvider).catalogIds;
});
```

Em `lib/features/catalog/presentation/providers/home_search_state.dart` (só docs, os campos ficam):
- doc da classe: «da busca local síncrona (PLPCG + Coldigom, O16)» → «da busca local síncrona no índice do catálogo»;
- `localGroups`: «Resultados locais: PLPCG (com filtros UC-02) e depois Coldigom.» → «Resultados locais: índice do catálogo, já filtrado (`matchesCatalogFilters`).»;
- `remote`: «Página 1 remota (Coldigom): …» → «Página 1 remota (`/api/plpcg/praises`): …»;
- `knownIds`: «Ids que o índice Coldigom já conhece (`coldigomSearchIndexProvider`)» → «Ids que o catálogo local já conhece (`knownPraiseIdsProvider`)».

- [ ] **Step 4: `HomeScreen`**

Substituir `lib/features/catalog/presentation/pages/home_screen.dart` por:

```dart
import 'dart:async';

import 'package:coldigui/core/network/connectivity_stream_provider.dart';
import 'package:coldigui/core/platform/platform_capabilities_provider.dart';
import 'package:coldigui/core/routing/url_sync_navigation.dart';
import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/core/utils/home_url_builder.dart';
import 'package:coldigui/features/app_shell/presentation/widgets/app_shortcuts.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_filters_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/recently_opened_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/filters_panel.dart';
import 'package:coldigui/features/catalog/presentation/widgets/home_search_results_sliver.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_group_card_skeleton.dart';
import 'package:coldigui/features/catalog/presentation/widgets/search_bar.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart' hide SearchBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// UC-01, UC-02 — página inicial / Pesquisador.
///
/// Busca com debounce 300ms no índice local do catálogo, filtros do catálogo
/// (tom, ritmo, categoria, tags, tipo de material — os mesmos da
/// /biblioteca), resultados como [LouvorGroupCard] e sync URL (`pesquisa=` +
/// params de filtro, spec fim-fonte §2.5). Enquanto o índice está vazio
/// mostra carregamento; vazio com o sync falhado mostra `catalogLoadError` +
/// «Tentar novamente».
///
/// **Ciclo de vida Riverpod:** hidratação de URL e `goRouter.go` são adiados com
/// `addPostFrameCallback` em [didUpdateWidget] e [_syncUrlFromState]
/// — evita `Tried to modify a provider while the widget tree was building`
/// quando o índice (~2063 grupos) conclui e a árvore reconstrói.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    super.key,
    this.initialSearchQuery = '',
    this.initialTonality,
    this.initialRhythm,
    this.initialCategory,
    this.initialTags,
    this.initialMaterialKinds,
  });

  /// Query inicial vinda de `?pesquisa=` na URL.
  final String initialSearchQuery;

  /// CSVs iniciais dos filtros do catálogo (`?tonality=`, `?rhythm=`,
  /// `?category=`, `?tags=` por nome, `?materialKinds=` por id de kind).
  final String? initialTonality;
  final String? initialRhythm;
  final String? initialCategory;
  final String? initialTags;
  final String? initialMaterialKinds;

  bool get _hasInitialFilters =>
      initialTonality != null ||
      initialRhythm != null ||
      initialCategory != null ||
      initialTags != null ||
      initialMaterialKinds != null;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  var _initialized = false;
  var _urlSyncEnabled = false;

  /// Evita hidratar busca quando [goRouter.go] foi disparado por este widget
  /// (eco de URL) — o usuário pode ter digitado além do valor já sincronizado.
  var _suppressSearchHydrationFromOwnUrlSync = false;

  /// Recria [SearchBar] só em hidratação externa (deep link, voltar no histórico).
  var _searchHydrationEpoch = 0;

  /// Valor inicial da [SearchBar] — não segue `?pesquisa=` a cada sync de URL.
  late String _searchBarInitialValue;

  /// Vive na tela, não na [SearchBar]: o `Ctrl+K` precisa de um nó estável
  /// mesmo quando a barra é recriada pela hidratação de URL.
  final _searchFocusNode = FocusNode(debugLabel: 'homeSearch');

  static const double _maxContentWidth = 896;

  @override
  void initState() {
    super.initState();
    _searchBarInitialValue = widget.initialSearchQuery;
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrateFromUrl());
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _focusSearchField() {
    _searchFocusNode.requestFocus();
  }

  void _hydrateFromUrl() {
    if (_initialized) return;
    _initialized = true;
    ref
        .read(homeSearchDebouncedQueryProvider.notifier)
        .setImmediate(widget.initialSearchQuery);
    _hydrateFilters();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _urlSyncEnabled = true;
    });
  }

  void _hydrateFilters() {
    ref
        .read(catalogFiltersProvider.notifier)
        .hydrateFromUrl(
          tonality: widget.initialTonality,
          rhythm: widget.initialRhythm,
          category: widget.initialCategory,
          tags: widget.initialTags,
          materialKinds: widget.initialMaterialKinds,
        );
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final searchChanged =
        oldWidget.initialSearchQuery != widget.initialSearchQuery;
    final filtersChanged =
        oldWidget.initialTonality != widget.initialTonality ||
        oldWidget.initialRhythm != widget.initialRhythm ||
        oldWidget.initialCategory != widget.initialCategory ||
        oldWidget.initialTags != widget.initialTags ||
        oldWidget.initialMaterialKinds != widget.initialMaterialKinds;
    if (!searchChanged && !filtersChanged) return;

    // Riverpod proíbe modificar providers durante o ciclo de build/update.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ownUrlSyncEcho = _suppressSearchHydrationFromOwnUrlSync;
      if (ownUrlSyncEcho) {
        _suppressSearchHydrationFromOwnUrlSync = false;
      }
      if (searchChanged && !ownUrlSyncEcho) {
        ref
            .read(homeSearchDebouncedQueryProvider.notifier)
            .setImmediate(widget.initialSearchQuery);
        setState(() {
          _searchBarInitialValue = widget.initialSearchQuery;
          _searchHydrationEpoch++;
        });
      }
      if (filtersChanged) _hydrateFilters();
    });
  }

  void _syncUrlFromState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyUrlSyncFromState();
    });
  }

  void _applyUrlSyncFromState() {
    final goRouter = GoRouter.maybeOf(context);
    if (goRouter == null) return;

    final uri = goRouter.routerDelegate.currentConfiguration.uri;
    final pesquisa = ref.read(homeSearchUrlSyncQueryProvider);
    final filters = ref.read(catalogFiltersProvider);

    final target = buildHomeLocation(
      pesquisa: pesquisa,
      tonality: filters.tonalityUrlValue,
      rhythm: filters.rhythmUrlValue,
      category: filters.categoryUrlValue,
      tags: filters.tagsUrlValue,
      materialKinds: filters.materialKindsUrlValue,
    );

    if (buildHomeLocationFromUri(uri) == target) return;
    _suppressSearchHydrationFromOwnUrlSync = true;
    // replaceState, não pushState: digitar não pode poluir o voltar (P4).
    goReplacingUrl(context, goRouter, target);
  }

  void _retryCatalog() {
    unawaited(ref.read(coldigomCatalogSyncProvider.notifier).sync());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final status = ref.watch(catalogIndexStatusProvider);
    // Mantém o `recentlyOpenedProvider` com um observador vivo enquanto a
    // Home existe — sem isto os `ref.listen` internos dele (leitor/cifra,
    // sessão de áudio) não disparam (Riverpod 3.3, ver docstring do provider).
    ref.watch(recentlyOpenedProvider);

    ref.listen<String>(homeSearchUrlSyncQueryProvider, (_, _) {
      if (!_urlSyncEnabled) return;
      _syncUrlFromState();
    });

    ref.listen<CatalogFilterState>(catalogFiltersProvider, (_, _) {
      if (!_urlSyncEnabled) return;
      _syncUrlFromState();
    });

    ref.listen<int>(searchFocusRequestProvider, (_, _) => _focusSearchField());

    // Reconexão (C.8): volta a rede com o catálogo vazio ou a página remota
    // em erro → tenta de novo sozinho, sem esperar o usuário tocar em
    // «Tentar novamente» (spec §2.1).
    ref.listen<AsyncValue<bool>>(connectivityStreamProvider, (_, next) {
      if (next.value != true) return;
      if (ref.read(coldigomSearchIndexProvider).isEmpty) _retryCatalog();
      if (ref.read(homeSearchStateProvider).remoteFailed) {
        retryRemoteSearch(ref);
      }
    });

    final horizontalPadding = MediaQuery.sizeOf(context).width > 600
        ? 24.0
        : 16.0;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 16,
            ),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: FiltersPanel(
                    initiallyExpanded: widget._hasInitialFilters,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverToBoxAdapter(
                  child: SearchBar(
                    key: ValueKey(_searchHydrationEpoch),
                    hintText: l10n.searchHint,
                    initialValue: _searchBarInitialValue,
                    focusNode: _searchFocusNode,
                    capabilities: ref.read(platformCapabilitiesProvider),
                    onQueryChanged: (value) {
                      ref
                          .read(homeSearchQueryProvider.notifier)
                          .setQuery(value);
                    },
                  ),
                ),
                if (status == CatalogIndexStatus.loading) ...[
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  const CatalogLoadingSliver(),
                ],
                if (status == CatalogIndexStatus.failed) ...[
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.catalogLoadError,
                          style: AppTypography.body.copyWith(
                            color: AppColors.textLight,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: _retryCatalog,
                          child: Text(l10n.retry),
                        ),
                      ],
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                const HomeSearchResultsSliver(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Strings e comentários**

1. `lib/l10n/app_pt.arb`: apagar `catalogStaleBanner` (só a página inicial o usava — confirmar com `grep -rn catalogStaleBanner lib test --include='*.dart' | grep -v lib/l10n/app_localizations`); `homeColdigomOffline` passa a `"Sem conexão — o catálogo pode estar incompleto nesta busca."` e a `description` do `@homeColdigomOffline` a `"Aviso da página inicial sem resultado quando a busca remota não foi chamada por falta de rede e o catálogo local está vazio (spec fim-fonte §9.2)"`.
2. `lib/l10n/app_en.arb`: apagar `catalogStaleBanner`; `homeColdigomOffline` → `"No connection — the catalog may be incomplete for this search."`.
3. `flutter gen-l10n`.
4. `lib/features/catalog/presentation/widgets/home_empty_state.dart`, doc da classe: «+ aviso Coldigom (se a busca remota falhou e o dispositivo está offline)» → «+ aviso de catálogo incompleto (sem rede e sem catálogo local)».
5. `lib/features/app_shell/presentation/shell_scaffold.dart`, comentário antes de `ref.listen(coldigomCatalogHydrationProvider, …)`: «Catálogo Coldigom local (O4/O5): hidrata do Isar e sincroniza no boot sem bloquear o shell — a Home mostra o PLPCG primeiro, como hoje.» → «Catálogo local (O4/O5, C6): hidrata (Isar ou memória) e sincroniza no boot sem bloquear o shell — a página inicial e a /biblioteca mostram carregamento até o índice chegar.».

- [ ] **Step 6: Correr e ver passar**

Run: `flutter test test/unit/features/catalog/ test/widget/features/catalog/ test/integration/uc01_search_home_test.dart test/widget/features/app_shell/`
Expected: PASS.
Run (C7): `grep -rln "louvoresManifestProvider\|plpcgCatalogSourceProvider\|manifestMaterialAliasesProvider\|catalogSourceProvider\|mergeLocalSearchResults\|louvores_manifest" lib/features/catalog/presentation/pages/home_screen.dart lib/features/catalog/presentation/providers/home_search_provider.dart lib/features/catalog/presentation/providers/home_remote_search_provider.dart lib/features/catalog/presentation/providers/known_praise_ids_provider.dart lib/features/catalog/presentation/providers/catalog_filters_provider.dart lib/features/catalog/presentation/widgets/filters_panel.dart lib/features/catalog/presentation/widgets/catalog_filter_sections.dart lib/features/library`
Expected: nenhum ficheiro.
Run: `flutter analyze`
Expected: sem issues.

- [ ] **Step 7: Commit**

```bash
git add -A lib/features/catalog lib/features/app_shell/presentation/shell_scaffold.dart lib/l10n test/unit/features/catalog test/widget/features/catalog test/integration/uc01_search_home_test.dart
git commit -m "feat(home): página inicial só do índice do catálogo; sem manifesto

Busca local = índice + filtros; «novos» pelo mesmo predicado; ids
conhecidos = catalogIds; carregamento/erro/retry pelo estado do índice.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: varredura final

**Files:**
- Modify: só o que a varredura achar (resíduos de nome, imports órfãos, comentários que falem da dicotomia na página inicial/biblioteca).

**Interfaces:**
- Consumes: tudo o que as Tasks 1–8 produziram.
- Produces: nada novo — a branch fica com `flutter analyze` limpo e `flutter test` verde.

- [ ] **Step 1: Resíduos do que saiu**

Run:

```bash
grep -rn "LibraryCatalogMode\|libraryCatalogMode\|coldigomLibraryFilters\|ColdigomLibraryFilter\|coldigomLibraryFacets\|libraryColdigomBrowse\|libraryLastGood\|librarySpecialArrangement\|SpecialArrangementFilters\|CategoryFilters\|ClassificationFilters\|BrowseLibrary\|browseLibraryProvider\|FilterByMaterialAndArranjo\|FilterBySpecialArrangement\|LibraryGroupPipeline\|runLibraryGroupPipeline\|selectedMaterials\|selectedArranjos\|initialFonte\|initialMateriais\|initialArranjo\|coldigomLoadError\|catalogStaleBanner\|filtersSpecialArrangementTitle\|ColdigomBrowse\|mergeBrowseResult\|fetchFilterOptions\|ColdigomFilterOptionsDto\|ColdigomTagFacetDto\|showPlpcgSections\|UrlSyncParams.fonte\|UrlSyncParams.materiais\|UrlSyncParams.arranjo" lib test
```

Expected: nenhum resultado. Se aparecer algo, apagar/ajustar e correr de novo.

- [ ] **Step 2: A pilha do manifesto continua de pé (C7)**

Run: `ls lib/features/catalog/data/sources/composite_catalog_source.dart lib/features/catalog/data/sources/plpcg_catalog_source.dart lib/features/catalog/presentation/providers/louvores_manifest_provider.dart lib/features/catalog/domain/entities/louvor_data_source.dart`
Expected: os quatro existem (quem os apaga é o plano 3).

- [ ] **Step 3: Suite inteira**

Run: `flutter analyze`
Expected: `No issues found!`
Run: `flutter test`
Expected: tudo verde (sem dart-defines).

- [ ] **Step 4: Commit (só se a varredura mudou algo)**

```bash
git add -A lib test
git commit -m "chore(catalog): varredura do catálogo único (resíduos e imports)

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Auto-revisão (redator)

**Cobertura do spec (escopo do plano 1):**
- §2.1 fonte = índice; caminho normal Isar → hidratação (Task 3, inalterado); caminho em memória sem Isar (Task 3); `SyncColdigomCatalog` com desfecho em memória (Task 3); hidratação aceita as linhas do DTO (Task 3); carregamento enquanto vazio, erro + retry com `sync()`, reconexão refaz o sync (Tasks 4, 6, 8); arranque a frio continua fatiado (Task 3, sem mudar `coldigomHydrationChunkSize`). A troca do `catalogSourceProvider` fica para o plano 3 (Desvio 5).
- §2.2 estado único (Task 7), cinco filtros com a semântica da tabela (Task 7, `matches_catalog_filters_test`), opções do índice (Task 5), predicado único usado pela /biblioteca, busca local e «novos» (Tasks 6–8), `FiltersPanel` sem `showPlpcgSections`, `CategoryFilters`/`ClassificationFilters`/`SpecialArrangementFilters` fora, conteúdo vindo do antigo `ColdigomLibraryFilters` (Tasks 6–7), pref antiga descartada (Task 7). Facets remotas deixam de ser chamadas (Task 6).
- §2.3 pipeline único local, `compute` decidido e medido (Task 6, Desvio 1); tudo o que «Sai» (Tasks 6–7); `LouvorClassification.materialSectionLabel`/`displayLabel` ficam por terem chamador (Desvio 7).
- §2.4 busca local = índice + predicado (Task 8), sai o merge da página inicial (Desvio 4), «novos» filtrados no cliente (Task 7), `knownPraiseIdsProvider` = `catalogIds` (Task 8), docs do `home_search_state` (Task 8).
- §2.5 params novos nas duas rotas, velhos ignorados sem erro (Tasks 6–7, Desvio 2).
- §4.2 camadas do `shortId` (Task 1) e mapa `shortId → praise`/material → praise no índice (Task 2).
- §9: `libraryCatalogMode*`, `coldigomLoadError` (Task 6), `filtersSpecialArrangementTitle`, `specialArrangementPadrao` (Task 6), `homeColdigomOffline` neutro (Task 8), `coldigomFilter*` ficam (Task 7 usa).
- §10.1/§10.2/§10.3 no escopo: `browse_library_test`, `library_catalog_mode_provider_test`, `library_catalog_mode_toggle_test`, `filter_by_special_arrangement_test` (Task 6), `category_filters_test`, `filter_by_material_and_arranjo_test` (Task 7) apagados; `louvor_classification_special_test` aparado (Desvio 7); `home_search_provider_test`, `home_remote_search_provider_test`, `known_praise_ids_provider_test`, `uc01_search_home_test` (Task 8), `coldigom_catalog_hydration_test` + memória + mapa `shortId` (Tasks 2–4), `sync_coldigom_catalog_test` + desfecho em memória (Task 3), `library_screen_error_test` (Task 6), `home_empty_state_test` (Tasks 7–8); novos: `matchesCatalogFilters` (Task 7), opções (Task 5), pipeline da /biblioteca (Task 6), hidratação em memória e mapa `shortId` (Tasks 2–3).

**Review Focus → testes:** 1 → `catalog_filter_sections_test` («seleção que o catálogo não tem…», Task 7); 2 → `catalog_index_status_provider_test` + `'sem catálogo e sem rede…'` (Task 4), `library_screen_error_test` e `home_screen_error_test` (Tasks 6 e 8); 3 → `catalog_filters_provider_test` («formato antigo…») e os testes «link antigo» dos dois URL builders (Tasks 6–7); 4 → `catalog_filter_options_test` e `matches_catalog_filters_test` (Tasks 5 e 7); 5 → `lyrics_reader_screen_test` («sem Isar lê a letra…», Task 4).

**Tipos e nomes cruzados conferidos:** `catalogGroup`/`catalogIndexOf` (Task 2) e `FakeColdigomCatalogSyncNotifier`/`catalogIndexOverrides` (Task 4) usados com a mesma assinatura nas Tasks 5–8; `CatalogFilterState` (C5) com `materialKindIds` no campo e `materialKinds` na URL/JSON em todas as tarefas; `libraryFilteredGroupsProvider`/`libraryGroupResultsProvider` (Task 6) estendidos na Task 7; `catalogIndexStatusProvider`/`CatalogIndexStatus` (Task 4) nas Tasks 6 e 8; `coldigomInMemoryCatalogProvider` (Task 3) nas Tasks 4 e hidratação.

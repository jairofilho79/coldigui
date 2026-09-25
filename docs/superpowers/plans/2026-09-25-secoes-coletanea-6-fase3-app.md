# Fase 3 das seções da Coletânea — app (category sai dos DTOs e do Isar) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** tirar `praise.category` do app: DTOs, `ColdigomPraiseMetadata`, `ColdigomPraisesQuery` e o cache Isar `ColdigomPraiseCache`, sem quebrar quem já tem o cache gravado com a coluna.

**Architecture:** o campo é passagem pura (DTO → mapper → Isar → metadata) e ninguém o lê para exibir, filtrar ou buscar. Remove-se de ponta a ponta; o JSON da API continua trazendo `"category"` e os `fromJson` simplesmente não o leem. O schema Isar perde uma propriedade: um teste nativo grava com o schema antigo e abre com o novo. O conversor de links e preferências antigos (`legacy_category_tags.dart`, `?category=`, `categories` no JSON v2) **fica**: lê strings guardadas pelo usuário, não a API.

**Tech Stack:** Flutter/Dart, Riverpod, isar_plus 1.3.7 + build_runner.

**Spec:** `docs/superpowers/specs/2026-09-24-secoes-coletanea-subtags-design.md` §6 item 5 e §4.

## Global Constraints

- Worktree `/Volumes/SSD 2TB SD/dev/coldigui/.claude/worktrees/categoria-fase3`, branch `feat/secoes-coletanea-fase3`, a partir de `web/integration`.
- **Não tocar** no conceito de categoria de MATERIAL, que tem o mesmo nome: `Louvor.categoria`, `LouvorCategoryOrder`, `CarouselItem.categoria`, `ChipMetadataRow.categoria`, `AudioTrack/ChordMaterial/GestureMaterial/YoutubeMaterial.categoria`, `LouvorCache.categoria`, `OfflinePdfIndex.category`/`OfflinePdfEntry.category` (ex.: `ColAdultos`), `PlaylistCategory`. Testes com `category: 'ColAdultos'` ou `OfflinePdfEntry(category: …)` ficam como estão.
- **Não tocar** em `lib/features/catalog/domain/utils/legacy_category_tags.dart`, `CatalogFilterState.fromUrl(category:)`, `fromPersistedJson` (chave `categories`), `UrlSyncParams.category`, `hydrateFromUrl(category:)` e nos testes deles.
- Regerar o Isar com `dart run build_runner build --delete-conflicting-outputs`; commitar o `.g.dart` gerado.
- `flutter analyze` limpo e `flutter test` inteiro verde antes de cada commit final (o benchmark `reconcile_offline_index_benchmark_test.dart` é instável sob carga: se só ele falhar, rodar sozinho).
- Git: nunca `git stash` puro; rodar git como comando plano no worktree (sem `cd X && git`, sem `git -C`); trailer `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.
- Revisores usam `dart format --output=none --set-exit-if-changed`, nunca `git checkout --`.

## Review Focus

1. Um navegador com o cache Isar gravado **com** a coluna `category` abre o app novo sem erro de schema e lê as linhas (teste de migração nativo, Task 1).
2. JSON da API que ainda traz `"category": "Clamor"` (catálogo, lista, detalhe) continua sendo lido sem erro.
3. Link antigo `?category=Clamor` e preferências v2 com `categories` continuam virando `Coletânea` + `Coletânea · Clamor`.
4. Nenhum uso de categoria de material mudou (diff não toca os arquivos listados nas constraints).
5. `ColdigomPraisesQuery.toQueryParameters()` não emite mais a chave `category`.

---

### Task 1: category sai de DTOs, metadata, query e Isar

**Files:**
- Modify: `lib/features/coldigom/data/models/praise_dto.dart` (`PraiseSummaryDto`, `PraiseDetailDto`)
- Modify: `lib/features/coldigom/data/models/coldigom_catalog_dto.dart` (`ColdigomCatalogPraiseDto`)
- Modify: `lib/features/coldigom/domain/entities/coldigom_praise_metadata.dart`
- Modify: `lib/features/coldigom/data/adapters/coldigom_louvor_adapter.dart` (linha que copia `category`)
- Modify: `lib/features/coldigom/data/mappers/coldigom_praise_cache_mapper.dart` (todas as ocorrências)
- Modify: `lib/features/coldigom/data/datasources/coldigom_remote_datasource.dart` (`ColdigomPraisesQuery.categories` e `_putCsv(params, 'category', …)`)
- Modify: `lib/core/database/collections/coldigom_praise_cache.dart` + regenerar `coldigom_praise_cache.g.dart`
- Create: `test/unit/core/database/coldigom_praise_cache_schema_migration_test.dart` (+ `test/helpers/legacy_isar/coldigom_praise_cache_v1.dart` com o schema antigo)
- Modify (testes): `test/helpers/coldigom_catalog_test_helpers.dart` (tirar o parâmetro `category` de `catalogGroup`), `test/fixtures/coldigom_catalog_sample.json` (**manter** as chaves `"category"`: provam que o JSON antigo é tolerado), `test/unit/features/coldigom/coldigom_praise_metadata_test.dart`, `coldigom_praise_cache_mapper_test.dart`, `coldigom_louvor_adapter_test.dart`, `coldigom_remote_datasource_test.dart`, `sync_coldigom_catalog_test.dart`, `coldigom_catalog_local_datasource_test.dart`, `adopt_coldigom_search_novelties_test.dart`, `test/unit/features/catalog/catalog_filter_options_test.dart`, `matches_catalog_filters_test.dart` (só as chamadas `catalogGroup(category: …)`; os casos `CatalogFilterState.fromUrl(category: …)` ficam), `test/widget/features/catalog/catalog_filter_sections_test.dart`, `material_sheet_test.dart`, `test/widget/features/contributions/contribute_screen_test.dart`.

**Interfaces:**
- Produces: construtores sem `category`: `PraiseSummaryDto`, `PraiseDetailDto`, `ColdigomCatalogPraiseDto`, `ColdigomPraiseMetadata`, `ColdigomPraisesQuery` (sem `categories`); `ColdigomPraiseCache` sem a propriedade `category`.

- [ ] **Step 1: teste de migração do schema (antes de mexer no Isar)**

Com o código ainda intacto, criar `test/helpers/legacy_isar/coldigom_praise_cache_v1.dart` copiando `lib/core/database/collections/coldigom_praise_cache.dart` **e** o conteúdo de `coldigom_praise_cache.g.dart` num único arquivo sem `part`/`part of`, renomeando só os identificadores Dart (`ColdigomPraiseCache` → `ColdigomPraiseCacheV1`, `ColdigomPraiseCacheSchema` → `ColdigomPraiseCacheV1Schema`, extensões/métodos gerados idem) e **mantendo o nome da coleção no schema** (`name: 'ColdigomPraiseCache'`), para que seja a mesma coleção no disco. Cabeçalho do arquivo:

```dart
// Cópia congelada do schema de ColdigomPraiseCache ANTES da fase 3 (com
// `category`), para o teste de migração. Não editar: é o que está gravado
// nos navegadores até o próximo sync.
// ignore_for_file: type=lint, invalid_use_of_protected_member, deprecated_member_use
```

Criar `test/unit/core/database/coldigom_praise_cache_schema_migration_test.dart`:

```dart
import 'dart:io';

import 'package:coldigui/core/database/collections/coldigom_praise_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

import '../../../helpers/legacy_isar/coldigom_praise_cache_v1.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('isar_praise_cache_mig_');
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  test('cache gravado com category (fase 2) abre com o schema atual', () {
    final antigo = Isar.open(schemas: [ColdigomPraiseCacheV1Schema], directory: dir.path);
    antigo.write((isar) {
      final row = ColdigomPraiseCacheV1()
        ..praiseId = 'p1'
        ..number = '001'
        ..name = 'Ainda há tempo'
        ..author = ''
        ..rhythm = ''
        ..tonality = 'Dm'
        ..category = 'Clamor'
        ..tags = ['Coletânea · Clamor']
        ..lyrics = ''
        ..materialsJson = '[]'
        ..searchTokens = 'ainda ha tempo'
        ..shortId = '2cf';
      row.id = isar.coldigomPraiseCacheV1s.autoIncrement();
      isar.coldigomPraiseCacheV1s.put(row);
    });
    antigo.close();

    final atual = Isar.open(schemas: [ColdigomPraiseCacheSchema], directory: dir.path);
    addTearDown(() => atual.close(deleteFromDisk: true));
    final lido = atual.coldigomPraiseCaches.where().praiseIdEqualTo('p1').findFirst();
    expect(lido, isNotNull);
    expect(lido!.name, 'Ainda há tempo');
    expect(lido.tags, ['Coletânea · Clamor']);
    expect(lido.shortId, '2cf');
  });
}
```

Os nomes exatos dos acessores gerados (`coldigomPraiseCacheV1s`, `praiseIdEqualTo`) seguem o que o `.g.dart` copiado define; ajustar o teste a eles. Os campos do `..` acima seguem a classe atual: conferir e completar com todos os `late` obrigatórios.

- [ ] **Step 2: rodar — passa com o schema atual (ainda igual ao V1)**

Run: `flutter test test/unit/core/database/coldigom_praise_cache_schema_migration_test.dart`
Expected: PASS. É uma guarda: o passo que importa é o Step 5.

- [ ] **Step 3: remover o campo de ponta a ponta**

- `praise_dto.dart`: tirar o parâmetro, o campo `category` e a leitura `json['category']` de `PraiseSummaryDto` e `PraiseDetailDto`.
- `coldigom_catalog_dto.dart`: idem em `ColdigomCatalogPraiseDto` (e de `toJson`, se houver).
- `coldigom_praise_metadata.dart`: tirar `category`; o comentário de `hasAnyField` que fala da fase 3 perde a menção ao campo.
- `coldigom_louvor_adapter.dart`: tirar `category: praise.category,`.
- `coldigom_praise_cache_mapper.dart`: tirar todas as passagens de `category` (parâmetros nomeados, `..category = category`, `meta?.category ?? ''`).
- `coldigom_remote_datasource.dart`: tirar `categories` de `ColdigomPraisesQuery` e `_putCsv(params, 'category', categories);`.
- `coldigom_praise_cache.dart`: tirar `late String category;`.
- Rodar `dart run build_runner build --delete-conflicting-outputs`.

Conferir que sobrou só o que deve: `git grep -n "\bcategory\b" -- lib/features/coldigom lib/core/database/collections/coldigom_praise_cache.dart` → nenhum resultado.

- [ ] **Step 4: ajustar os testes**

- `catalogGroup` perde `String category = ''` e a passagem ao DTO; tirar `category: …` de todas as chamadas.
- `coldigom_praise_metadata_test.dart`: apagar os casos que existem só para `category`.
- `material_sheet_test.dart:389-407`: apagar a asserção de que `meta` ainda carrega `category`.
- `contribute_screen_test.dart:405`, `adopt_coldigom_search_novelties_test.dart:71`, `coldigom_praise_cache_mapper_test.dart:167`: tirar o argumento.
- `sync_coldigom_catalog_test.dart`, `coldigom_catalog_local_datasource_test.dart`: tirar `..category = ''`.
- `coldigom_remote_datasource_test.dart`: um teste que monta `ColdigomPraisesQuery(tonalities: {'Dm'})` e verifica `toQueryParameters().containsKey('category')` é `false`; o JSON de resposta com `'category': 'Clamor'` continua no fixture e o parse passa.
- `coldigom_louvor_adapter_test.dart`: manter `'category': 'Clamor'` no JSON de entrada (tolerância).
- Testes de `CatalogFilterState.fromUrl(category: …)`, `hydrateFromUrl(category: …)`, `legacy_category_tags_test.dart`, URL builders e `filters_url_sync_across_tabs_test.dart`: **sem mudança**.

- [ ] **Step 5: rodar o teste de migração com o schema novo**

Run: `flutter test test/unit/core/database/coldigom_praise_cache_schema_migration_test.dart`
Expected: PASS — o Isar abre o arquivo gravado com `category` usando o schema sem ela. **Se falhar** (erro de schema/versão ao abrir), parar e reportar BLOCKED com a mensagem exata: a remoção da propriedade Isar exige outra estratégia (não contornar trocando o nome da coleção).

- [ ] **Step 6: suíte inteira e analyze**

Run: `flutter analyze && flutter test`
Expected: analyze sem issues; todos os testes passam.

- [ ] **Step 7: commit**

```bash
git add -A lib test
git commit -m "feat(coldigom): praise.category sai dos DTOs, dos metadados e do cache Isar (fase 3)

O JSON da API ainda traz category e é ignorado. O conversor de links e
preferências antigos (legacy_category_tags) fica. Teste nativo abre com o
schema novo um cache gravado com a coluna.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

## Entrega (fora das tasks; quem faz é o controlador com o dono)

A fase 3 não tem ordem obrigatória entre as partes: a API continua emitindo `category` (`''` depois do script) e o app novo não lê. Sequência escolhida:
1. coldigom: PR `develop → main` com o ZIP/ingest (plano 5) → deploy da API.
2. Snapshot + ensaio do `core.secoes_coletanea_categoria` → `--execute` pelo dono.
3. App: merge em `web/integration` → `./scripts/web_deploy.sh`.
4. Conferência em produção: `/api/plpcg/catalog` sem nenhum `category` não vazio; app abre com o cache antigo (Configurações offline mostra o catálogo com a contagem, sem cair para o modo em memória) e os filtros por seção seguem funcionando.

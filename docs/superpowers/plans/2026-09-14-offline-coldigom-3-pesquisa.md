# Offline Coldigom — Parte 3: Pesquisa híbrida — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A pesquisa da Home passa a ser uma lista única 100 % local (PLPCG + Coldigom do índice hidratado) com uma linha de estado «Em cache · a verificar…» → «Atualizado». A página 1 remota do Coldigom deixa de ser «a lista» e passa a **validar**: o que o local não tinha entra no fim com o chip «novo», é gravado no Isar e dispara um sync do catálogo. A paginação Coldigom da Home é removida.

**Architecture:** `HomeSearchState` ganha `newGroups`/`offline` e deriva `SearchFreshness` (nunca é mutado na mão — continua um valor derivado). `homeSearchStateProvider` não observa o remoto sem rede (`connectivityStreamProvider == false` → `offline`) e pede sempre `page: 1`. O efeito colateral (adotar os «novos») vive em `homeRemoteSearchProvider`, depois de a página chegar: `AdoptColdigomSearchNovelties` (domínio Coldigom) grava as linhas `ColdigomPraiseCache` construídas a partir dos `LouvorGroup` remotos (`ColdigomPraiseCacheMapper.fromLouvorGroup`) e, se adotou algo, `coldigomCatalogSyncProvider.sync()` traz o dump inteiro (o ETag mudou). UI: `SearchFreshnessLine` no topo do sliver; chip «novo» no card; `HomeColdigomPaginationControls` e `homeSearchPageProvider` removidos.

**Tech Stack:** Flutter 3 + Riverpod 3 (`Provider` derivado, `FutureProvider.autoDispose.family` com `keepAlive`), `flutter gen-l10n`.

**Spec:** `docs/superpowers/specs/2026-09-14-offline-coldigom-design.md` (secção §6 completa: 6.1 estado, 6.2 pipeline, 6.3 UI; decisões O15/O16)

**Depende de:** `2026-09-14-offline-coldigom-1-catalogo.md` (obrigatório) e `2026-09-14-offline-coldigom-2-download.md` (só o chip «novo» partilha estilo com o badge; nada de código). Consome do plano 1: `coldigomSearchIndexProvider` (`ColdigomSearchIndex.praiseIds`), `coldigomCatalogSyncProvider` (`sync()`), `coldigomCatalogLocalDatasourceProvider` (`findByPraiseIdSync`, `upsertMany`), `ColdigomPraiseCacheMapper` (`buildSearchTokens`, `decodeMaterials`), `ColdigomCatalogMaterialEntry`, `homeLocalSearchProvider` (já concatenado PLPCG + Coldigom), `LyricsMaterial`.

## Global Constraints

- Todos os comandos rodam a partir da raiz da worktree `/Volumes/SSD 2TB SD/dev/coldigui/.claude/worktrees/offline-coldigom`.
- Nunca migrar/alterar `OfflinePdfIndex`, `LouvorCache`, `ChordContentCache`, `GestureDocumentCache` (decisões O7/O8) — só collections novas (`ColdigomPraiseCache`, `OfflineAudioIndex`); aqui só se escreve em `ColdigomPraiseCache` via `upsertMany`.
- `r2Key` é derivado: `assets/praises/<praiseId>/<materialId>.<ext>` (O2) — nos grupos remotos ele já está codificado no id (`PdfPathNormalizer.getPdfRelPath(id)`); YouTube usa `url`.
- Letra: `MaterialKind.lyrics`, id `lyrics:<praiseId>`, sem download, sem favoritos (O6) — a página remota não traz texto de letra; os «novos» entram sem letra até o sync do dump.
- Download só logado (O9); seleção local em prefs `offlineColdigomKindIds` (O11); idempotente sem checkpoint (O12); usa `offlineMaintenanceLockProvider` e `wakelock_plus` — plano 2, nada aqui toca.
- Pesquisa: lista única, PLPCG primeiro e Coldigom depois; remoto só valida a página 1; novos entram no fim (O15/O16). Remoto que devolve **menos** que o local não remove nada (só o sync substitui).
- Filtros UC-02 continuam a aplicar-se só ao PLPCG (O16).
- Sem rede (`connectivityStreamProvider.value == false`) o remoto **não é chamado** — `freshness = offline`. `AsyncLoading` inicial da conectividade conta como online (`?? true`), como hoje na Home.
- `homeRemoteSearchProvider` mantém a assinatura `HomeRemoteSearchKey(query, page)`; a Home passa sempre `page: 1`.
- Comentários de código e strings em português, no tom do código vizinho (explicam o porquê).
- Antes de cada commit: `dart format` nos ficheiros tocados, `flutter analyze` sem erros novos, testes da task verdes (`flutter gen-l10n` antes do `analyze` quando a task mexe nos `.arb`).
- Commits terminam com:
  ```
  Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01GfpG6w2yp8DjxrmfC6XtiP
  ```
- Baseline conhecido: `pdfrx_viewer_adapter_test` e `reconcile_offline_index_benchmark_test` falham por timeout sob carga — pré-existente, não corrigir.

---

## File map

- Modify `lib/features/catalog/presentation/providers/home_search_state.dart` — `SearchFreshness`, `HomeSearchState` novo.
- Modify `lib/features/coldigom/data/mappers/coldigom_praise_cache_mapper.dart` — `fromLouvorGroup`.
- Create `lib/features/coldigom/domain/usecases/adopt_coldigom_search_novelties.dart` — `AdoptColdigomSearchNovelties`.
- Modify `lib/features/coldigom/data/providers/coldigom_catalog_data_providers.dart` — `adoptColdigomSearchNoveltiesProvider`.
- Modify `lib/features/catalog/presentation/providers/home_remote_search_provider.dart` — adoção após a página; sync.
- Modify `lib/features/catalog/presentation/providers/home_search_provider.dart` — sem `homeSearchPageProvider`/`HomeSearchPage`; gate offline; `newGroups`.
- Create `lib/features/catalog/presentation/widgets/search_freshness_line.dart`.
- Modify `lib/features/catalog/presentation/widgets/home_search_results_sliver.dart` — linha no topo; sem pager; sem spinner de rodapé.
- Delete `lib/features/catalog/presentation/widgets/home_coldigom_pagination_controls.dart`.
- Modify `lib/features/catalog/presentation/widgets/louvor_group_card.dart` — chip «novo».
- Modify `lib/features/carousel/presentation/widgets/carousel_louvor_chip.dart` — parâmetro `isNew` e chip.
- Modify `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb` — `searchFreshness*`, `searchResultNew`.
- Modify tests: `test/unit/features/catalog/home_search_provider_test.dart`, `test/widget/features/catalog/home_search_results_sliver_test.dart`, `home_search_keyboard_test.dart`, `home_empty_state_test.dart`, `home_search_test.dart`.
- Create tests: `test/unit/features/coldigom/adopt_coldigom_search_novelties_test.dart`, `test/unit/features/catalog/home_search_state_test.dart`, `test/widget/features/catalog/home_search_freshness_test.dart`.
- Modify docs: `docs/use-cases/UC-01-search-louvor-home.md`, `docs/features/FEATURE_INDEX.md`.

---

### Task 1: `SearchFreshness` e o novo `HomeSearchState`

**Files:**
- Modify: `lib/features/catalog/presentation/providers/home_search_state.dart` (ficheiro inteiro)
- Modify: `test/widget/features/catalog/home_search_results_sliver_test.dart` (helper `_state`, linhas 18–29), `test/widget/features/catalog/home_search_keyboard_test.dart` (linhas 88–95), `test/widget/features/catalog/home_empty_state_test.dart` (linhas 62–71)
- Test: `test/unit/features/catalog/home_search_state_test.dart`

**Interfaces:**
- Produces:
  - `enum SearchFreshness { checking, updated, updatedWithNew, offline, failed }`
  - `final class HomeSearchState { const HomeSearchState({required String query, required List<LouvorGroup> localGroups, required AsyncValue<CatalogSearchPage> remote, List<LouvorGroup> newGroups = const [], bool offline = false}); bool get isEmptyQuery; List<LouvorGroup> get groups; Set<String> get newGroupIds; int get newCount; bool get remoteLoading; bool get remoteFailed; SearchFreshness get freshness; }` — sem `page`, sem `remoteGroups`, sem `hasNextPage`.

- [ ] **Step 1: Teste que falha**

`test/unit/features/catalog/home_search_state_test.dart`:

```dart
import 'package:coldigui/features/catalog/domain/entities/catalog_query.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

LouvorGroup _g(String id) =>
    LouvorGroup(groupId: id, numero: '001', nome: id, sections: const []);

void main() {
  final local = [_g('plpcg-1'), _g('cold-1')];

  test('a verificar: local na hora, sem novos', () {
    final state = HomeSearchState(
      query: 'x',
      localGroups: local,
      remote: const AsyncLoading(),
    );

    expect(state.freshness, SearchFreshness.checking);
    expect(state.groups.map((g) => g.groupId), ['plpcg-1', 'cold-1']);
    expect(state.newGroupIds, isEmpty);
    expect(state.remoteLoading, isTrue);
    expect(state.remoteFailed, isFalse);
  });

  test('remoto igual → atualizado; remoto com extra → atualizado com N novos no fim', () {
    final same = HomeSearchState(
      query: 'x',
      localGroups: local,
      remote: AsyncData(CatalogSearchPage(groups: [_g('cold-1')], page: 1)),
    );
    expect(same.freshness, SearchFreshness.updated);
    expect(same.newCount, 0);

    final withNew = HomeSearchState(
      query: 'x',
      localGroups: local,
      remote: AsyncData(CatalogSearchPage(groups: [_g('cold-1'), _g('cold-9')], page: 1)),
      newGroups: [_g('cold-9')],
    );
    expect(withNew.freshness, SearchFreshness.updatedWithNew);
    expect(withNew.newCount, 1);
    expect(withNew.newGroupIds, {'cold-9'});
    expect(withNew.groups.last.groupId, 'cold-9');
  });

  test('erro → failed com a lista local intacta; offline → offline sem olhar o remoto', () {
    final failed = HomeSearchState(
      query: 'x',
      localGroups: local,
      remote: AsyncError(Exception('boom'), StackTrace.empty),
    );
    expect(failed.freshness, SearchFreshness.failed);
    expect(failed.remoteFailed, isTrue);
    expect(failed.groups, hasLength(2));

    final offline = HomeSearchState(
      query: 'x',
      localGroups: local,
      remote: const AsyncLoading(),
      offline: true,
    );
    expect(offline.freshness, SearchFreshness.offline);
    expect(offline.remoteLoading, isFalse);
    expect(offline.remoteFailed, isFalse);
  });

  test('query vazia', () {
    const state = HomeSearchState(
      query: '  ',
      localGroups: [],
      remote: AsyncData(CatalogSearchPage.empty),
    );
    expect(state.isEmptyQuery, isTrue);
    expect(state.freshness, SearchFreshness.updated);
  });
}
```

Correr: `flutter test test/unit/features/catalog/home_search_state_test.dart` → falha (`newGroups`, `freshness` não existem).

- [ ] **Step 2: Estado**

`lib/features/catalog/presentation/providers/home_search_state.dart` inteiro:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/catalog_query.dart';
import '../../domain/entities/louvor_group.dart';

/// O que a linha de estado da Home diz sobre a lista (spec offline
/// Coldigom §6.1).
enum SearchFreshness {
  /// Página remota em voo — «Em cache · a verificar…».
  checking,

  /// Remoto confirmou a lista local — «Atualizado».
  updated,

  /// Remoto trouxe louvores que o local não tinha — «Atualizado · N novos».
  updatedWithNew,

  /// Sem rede: o remoto nem foi chamado — «Em cache · sem ligação».
  offline,

  /// Remoto falhou; a lista local fica — «Em cache · não foi possível verificar».
  failed,
}

/// Tudo o que a Home precisa saber sobre a busca corrente, num valor só (C.2).
///
/// Valor **derivado** por `homeSearchStateProvider` — da `query` debounced,
/// da busca local síncrona (PLPCG + Coldigom, O16), da página remota
/// `AsyncValue` e da conectividade —, nunca mutado na mão: não há geração a
/// comparar nem escrita cruzada entre providers. A lista é 100 % local; o
/// remoto só **valida** (O15): o que ele traz a mais entra em [newGroups],
/// no fim, com o chip «novo».
final class HomeSearchState {
  const HomeSearchState({
    required this.query,
    required this.localGroups,
    required this.remote,
    this.newGroups = const [],
    this.offline = false,
  });

  /// Query já debounced (300 ms) — o texto cru vive em `homeSearchQueryProvider`.
  final String query;

  /// Resultados locais: PLPCG (com filtros UC-02) e depois Coldigom.
  final List<LouvorGroup> localGroups;

  /// Página 1 remota (Coldigom): `loading` | `data` | `error`. Ignorada
  /// quando [offline].
  final AsyncValue<CatalogSearchPage> remote;

  /// Grupos que só o remoto tinha, na ordem remota — anexados no fim.
  final List<LouvorGroup> newGroups;

  /// `true` quando o remoto não foi chamado por falta de rede.
  final bool offline;

  /// `true` quando não há o que buscar — nenhuma fonte toca a rede.
  bool get isEmptyQuery => query.trim().isEmpty;

  /// Lista exibida: local primeiro, novos no fim (sem reordenar).
  List<LouvorGroup> get groups => [...localGroups, ...newGroups];

  /// Ids dos cards que levam o chip «novo».
  Set<String> get newGroupIds => {for (final g in newGroups) g.groupId};

  int get newCount => newGroups.length;

  /// `true` enquanto a página remota está em voo (e há rede).
  bool get remoteLoading => !offline && remote.isLoading;

  /// `true` só quando a busca remota **terminou** em erro.
  ///
  /// Um refresh depois de uma falha mantém o erro anterior dentro do
  /// `AsyncLoading`; enquanto ele estiver em voo a linha volta a «a
  /// verificar…» — que é o que o usuário acabou de pedir ao tocar em
  /// «tentar de novo».
  bool get remoteFailed => !offline && !remote.isLoading && remote.hasError;

  SearchFreshness get freshness {
    if (offline) return SearchFreshness.offline;
    if (remote.isLoading) return SearchFreshness.checking;
    if (remote.hasError) return SearchFreshness.failed;
    return newGroups.isEmpty
        ? SearchFreshness.updated
        : SearchFreshness.updatedWithNew;
  }
}
```

- [ ] **Step 3: Testes de widget que constroem o estado**

`home_search_results_sliver_test.dart` linhas 18–29 → remover o parâmetro `page` do helper `_state` e da chamada:

```dart
HomeSearchState _state({
  String query = 'agua',
  List<LouvorGroup> localGroups = const [],
  List<LouvorGroup> newGroups = const [],
  bool offline = false,
  required AsyncValue<CatalogSearchPage> remote,
}) {
  return HomeSearchState(
    query: query,
    localGroups: localGroups,
    remote: remote,
    newGroups: newGroups,
    offline: offline,
  );
}
```

`home_search_keyboard_test.dart` linhas 88–95 e `home_empty_state_test.dart` linhas 62–71: apagar a linha `page: 1,`. Os testes deste ficheiro que dependem do pager (`home_search_results_sliver_test.dart`: procure `pager`, `Página`, `chevron_right`) ficam **a falhar até à Task 4** — não os apague agora; a Task 4 reescreve-os.

Correr: `flutter test test/unit/features/catalog/home_search_state_test.dart` → 4 verdes. `flutter analyze` mostra erros em `home_search_provider.dart`/`home_search_results_sliver.dart`/`home_coldigom_pagination_controls.dart` (usam `page`/`remoteGroups`/`hasNextPage`) — são as Tasks 3 e 4; **não** faça commit ainda com `analyze` vermelho: siga para a Task 2 (independente) e feche o commit desta task junto com a Task 3.

---

### Task 2: `ColdigomPraiseCacheMapper.fromLouvorGroup` + `AdoptColdigomSearchNovelties`

**Files:**
- Modify: `lib/features/coldigom/data/mappers/coldigom_praise_cache_mapper.dart` (método novo depois de `fromPraiseDetail`)
- Create: `lib/features/coldigom/domain/usecases/adopt_coldigom_search_novelties.dart`
- Modify: `lib/features/coldigom/data/providers/coldigom_catalog_data_providers.dart` (provider novo no fim)
- Test: `test/unit/features/coldigom/adopt_coldigom_search_novelties_test.dart`

**Interfaces:**
- Consumes: `LouvorGroup` (`groupId`, `numero`, `nome`, `coldigomMeta`, `materials`), `PdfPathNormalizer.getPdfRelPath`, `ColdigomCatalogLocalDatasource.findByPraiseIdSync/upsertMany`, `StorageUnavailableException`.
- Produces:
  - `static ColdigomPraiseCache ColdigomPraiseCacheMapper.fromLouvorGroup(LouvorGroup group)` — `praiseId = groupId`; metadados de `coldigomMeta` (vazios se `null`); materiais: PDF/cifra/gestos/áudio com `r2Key` decodificado do id e `type` `pdf`/`chord`/`gestures`/`mp3`, `kindName = categoria`, `kindId = materialKindId`; YouTube com `url`; letra ignorada; `lyrics = ''`.
  - `class AdoptColdigomSearchNovelties { const (ColdigomCatalogLocalDatasource local); Future<Set<String>> call(Iterable<LouvorGroup> remoteGroups, {required Set<String> knownPraiseIds}); }` — grava só os grupos Coldigom cujo `groupId` não está em `knownPraiseIds` **nem** no Isar; devolve os ids adotados; nunca lança (sem Isar → `{}`).
  - `adoptColdigomSearchNoveltiesProvider` (`Provider<AdoptColdigomSearchNovelties>`).

- [ ] **Step 1: Teste que falha**

`test/unit/features/coldigom/adopt_coldigom_search_novelties_test.dart`:

```dart
import 'dart:io';

import 'package:coldigui/core/database/collections/coldigom_praise_cache.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/entities/youtube_material.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:coldigui/features/coldigom/data/datasources/coldigom_catalog_local_datasource.dart';
import 'package:coldigui/features/coldigom/data/mappers/coldigom_praise_cache_mapper.dart';
import 'package:coldigui/features/coldigom/domain/entities/coldigom_praise_metadata.dart';
import 'package:coldigui/features/coldigom/domain/usecases/adopt_coldigom_search_novelties.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

LouvorGroup _remoteGroup(String praiseId) {
  final pdf = Louvor.fromManifest(
    nome: 'Ainda há tempo',
    numero: '001',
    categoria: 'Grade',
    classificacao: 'Básico',
    pdf: 'm-pdf.pdf',
    pdfId: encodePdfId('assets/praises/$praiseId/m-pdf.pdf'),
    groupId: praiseId,
    source: LouvorDataSource.coldigom,
    materialKindId: 'k-grade',
  );
  return LouvorGroup.fromLouvores(
    [pdf],
    audioTracks: [
      AudioTrack(
        audioId: encodePdfId('assets/praises/$praiseId/m-mp3.mp3'),
        r2Key: 'assets/praises/$praiseId/m-mp3.mp3',
        nome: 'Ainda há tempo',
        numero: '001',
        groupId: praiseId,
        categoria: 'Playback',
        classificacao: 'Básico',
        materialKindId: 'k-play',
      ),
    ],
    chordMaterials: [
      ChordMaterial(
        chordId: encodePdfId('assets/praises/$praiseId/m-chord.chord'),
        r2Key: 'assets/praises/$praiseId/m-chord.chord',
        nome: 'Ainda há tempo',
        numero: '001',
        groupId: praiseId,
        categoria: 'Cifra',
        classificacao: 'Básico',
        materialKindId: 'k-cifra',
      ),
    ],
    youtubeMaterials: [
      YoutubeMaterial(
        id: 'yt-1',
        url: 'https://www.youtube.com/watch?v=1Pks43ceAac',
        nome: 'Ainda há tempo',
        numero: '001',
        groupId: praiseId,
        categoria: 'Vídeo',
        classificacao: 'Básico',
      ),
    ],
    coldigomMetaByGroupId: {
      praiseId: const ColdigomPraiseMetadata(
        name: 'Ainda há tempo',
        tonality: 'Dm',
        author: 'Autor',
        rhythm: 'Básico',
        category: 'Dm',
        tagNames: ['PES'],
      ),
    },
  ).single;
}

void main() {
  test('fromLouvorGroup reconstrói a linha a partir do grupo remoto', () {
    final row = ColdigomPraiseCacheMapper.fromLouvorGroup(_remoteGroup('p-9'));

    expect(row.praiseId, 'p-9');
    expect(row.number, '001');
    expect(row.name, 'Ainda há tempo');
    expect(row.author, 'Autor');
    expect(row.tonality, 'Dm');
    expect(row.tags, ['PES']);
    expect(row.lyrics, '');
    expect(row.searchTokens.split(' '), containsAll(['ainda', 'tempo', '001', 'pes', 'autor']));
    final materials = {for (final m in ColdigomPraiseCacheMapper.decodeMaterials(row)) m.id: m};
    expect(materials['m-pdf']!.type, 'pdf');
    expect(materials['m-pdf']!.r2Key, 'assets/praises/p-9/m-pdf.pdf');
    expect(materials['m-pdf']!.kindId, 'k-grade');
    expect(materials['m-pdf']!.kindName, 'Grade');
    expect(materials['m-mp3']!.type, 'mp3');
    expect(materials['m-chord']!.type, 'chord');
    expect(materials['yt-1']!.type, 'youtube');
    expect(materials['yt-1']!.url, isNotNull);
    expect(materials['yt-1']!.r2Key, isNull);
  });

  group('AdoptColdigomSearchNovelties', () {
    late Directory tempDir;
    late Isar isar;
    late ColdigomCatalogLocalDatasource local;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('adopt_');
      isar = Isar.open(
        schemas: [ColdigomPraiseCacheSchema],
        directory: tempDir.path,
        name: 'adopt_${DateTime.now().microsecondsSinceEpoch}',
      );
      local = ColdigomCatalogLocalDatasource(isar);
    });

    tearDown(() async {
      isar.close(deleteFromDisk: true);
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('grava só os desconhecidos (nem no índice nem no Isar) e devolve os ids', () async {
      await local.upsertMany([ColdigomPraiseCacheMapper.fromLouvorGroup(_remoteGroup('p-isar'))]);
      final usecase = AdoptColdigomSearchNovelties(local);

      final adopted = await usecase(
        [_remoteGroup('p-known'), _remoteGroup('p-isar'), _remoteGroup('p-new')],
        knownPraiseIds: {'p-known'},
      );

      expect(adopted, {'p-new'});
      expect(local.count(), 2);
      expect(local.findByPraiseIdSync('p-new')!.name, 'Ainda há tempo');
      expect(local.findByPraiseIdSync('p-known'), isNull);
    });

    test('grupos PLPCG são ignorados; sem Isar devolve vazio sem lançar', () async {
      final plpcg = LouvorGroup.fromLouvores([
        Louvor.fromManifest(
          nome: 'Aleluia',
          numero: '001',
          categoria: 'Partitura',
          classificacao: 'ColAdultos',
          pdf: '001.pdf',
          pdfId: encodePdfId('ColAdultos/001.pdf'),
        ),
      ]).single;

      expect(await AdoptColdigomSearchNovelties(local)([plpcg], knownPraiseIds: const {}), isEmpty);
      expect(local.count(), 0);
      expect(
        await const AdoptColdigomSearchNovelties(ColdigomCatalogLocalDatasource.unavailable())(
          [_remoteGroup('p-new')],
          knownPraiseIds: const {},
        ),
        isEmpty,
      );
    });
  });
}
```

Correr: `flutter test test/unit/features/coldigom/adopt_coldigom_search_novelties_test.dart` → falha.

- [ ] **Step 2: Mapper**

Em `coldigom_praise_cache_mapper.dart`, imports adicionais `../../../../core/utils/pdf_path_normalizer.dart`, `../../../catalog/domain/entities/catalog_material.dart`, `../../../catalog/domain/entities/louvor_group.dart`; método depois de `fromPraiseDetail`:

```dart
  /// Linha Isar a partir de um grupo da página remota (`/api/plpcg/praises`)
  /// — os «novos» da pesquisa (§6.2). O `r2Key` está codificado no id de
  /// cada material; o `type` sai do `kind`; a letra não vem na página
  /// (fica `''` até o sync do dump).
  static ColdigomPraiseCache fromLouvorGroup(LouvorGroup group) {
    final meta = group.coldigomMeta;
    final materials = <ColdigomCatalogMaterialEntry>[];
    for (final material in group.materials) {
      final entry = switch (material) {
        PdfMaterial() => _entryFromId(material, 'pdf'),
        ChordMaterialRef() => _entryFromId(material, 'chord'),
        GestureMaterialRef() => _entryFromId(material, 'gestures'),
        AudioMaterial(:final track) => ColdigomCatalogMaterialEntry(
          id: _basenameWithoutExt(track.r2Key),
          kindId: material.materialKindId,
          kindName: material.categoria,
          type: 'mp3',
          r2Key: track.r2Key,
        ),
        YoutubeMaterialRef(material: final youtube) => ColdigomCatalogMaterialEntry(
          id: youtube.id,
          kindId: material.materialKindId,
          kindName: material.categoria,
          type: 'youtube',
          r2Key: null,
          url: youtube.url,
        ),
        LyricsMaterial() => null,
      };
      if (entry != null) materials.add(entry);
    }
    return _row(
      praiseId: group.groupId,
      number: group.numero,
      name: group.nome,
      author: meta?.author ?? '',
      rhythm: meta?.rhythm ?? '',
      tonality: meta?.tonality ?? '',
      category: meta?.category ?? '',
      tags: meta?.tagNames ?? const [],
      lyrics: '',
      materials: materials,
    );
  }

  /// Materiais cujo id é `encodePdfId(r2Key)`: o `materialId` do Worker é o
  /// nome do ficheiro sem extensão (`assets/praises/<praise>/<material>.<ext>`).
  static ColdigomCatalogMaterialEntry? _entryFromId(CatalogMaterial material, String type) {
    final String r2Key;
    try {
      r2Key = PdfPathNormalizer.getPdfRelPath(material.id);
    } on Object {
      return null;
    }
    return ColdigomCatalogMaterialEntry(
      id: _basenameWithoutExt(r2Key),
      kindId: material.materialKindId,
      kindName: material.categoria,
      type: type,
      r2Key: r2Key,
    );
  }

  static String _basenameWithoutExt(String path) {
    final slash = path.lastIndexOf('/');
    final base = slash == -1 ? path : path.substring(slash + 1);
    final dot = base.lastIndexOf('.');
    return dot <= 0 ? base : base.substring(0, dot);
  }
```

- [ ] **Step 3: Use case e provider**

`lib/features/coldigom/domain/usecases/adopt_coldigom_search_novelties.dart`:

```dart
import 'package:flutter/foundation.dart';

import '../../../catalog/domain/entities/louvor_group.dart';
import '../../data/datasources/coldigom_catalog_local_datasource.dart';
import '../../data/mappers/coldigom_praise_cache_mapper.dart';

/// Adota no catálogo local os louvores que a página remota trouxe e o
/// Isar não conhecia (§6.2, O15).
///
/// Só grupos Coldigom ([LouvorGroup.isColdigom]) fora de [knownPraiseIds]
/// (os ids do índice hidratado) e fora do Isar. É o segundo escritor de
/// `ColdigomPraiseCache` — o `replaceAll` do sync vence sempre (é o estado
/// do servidor) e quem chama dispara esse sync quando isto adota algo.
/// Best-effort: sem Isar devolve vazio.
class AdoptColdigomSearchNovelties {
  const AdoptColdigomSearchNovelties(this._local);

  final ColdigomCatalogLocalDatasource _local;

  Future<Set<String>> call(
    Iterable<LouvorGroup> remoteGroups, {
    required Set<String> knownPraiseIds,
  }) async {
    if (!_local.isAvailable) return const {};
    final rows = [
      for (final group in remoteGroups)
        if (group.isColdigom &&
            !knownPraiseIds.contains(group.groupId) &&
            _local.findByPraiseIdSync(group.groupId) == null)
          ColdigomPraiseCacheMapper.fromLouvorGroup(group),
    ];
    if (rows.isEmpty) return const {};
    try {
      await _local.upsertMany(rows);
    } on Object catch (error) {
      debugPrint('[coldigom] adoção de novos da pesquisa falhou: $error');
      return const {};
    }
    return {for (final row in rows) row.praiseId};
  }
}
```

Em `coldigom_catalog_data_providers.dart`, no fim:

```dart
/// DI — [AdoptColdigomSearchNovelties].
final adoptColdigomSearchNoveltiesProvider = Provider<AdoptColdigomSearchNovelties>((ref) {
  return AdoptColdigomSearchNovelties(ref.watch(coldigomCatalogLocalDatasourceProvider));
});
```

(import `../../domain/usecases/adopt_coldigom_search_novelties.dart`.)

Correr: `flutter test test/unit/features/coldigom/adopt_coldigom_search_novelties_test.dart test/unit/features/coldigom/coldigom_praise_cache_mapper_test.dart` → verdes.

- [ ] **Step 4: Commit (só os ficheiros desta task — a Task 1 fecha na Task 3)**

```bash
dart format lib/features/coldigom test/unit/features/coldigom/adopt_coldigom_search_novelties_test.dart
flutter analyze lib/features/coldigom
git add lib/features/coldigom test/unit/features/coldigom/adopt_coldigom_search_novelties_test.dart
git commit -m "feat(coldigom): AdoptColdigomSearchNovelties — grava no Isar os louvores que só a página remota tinha

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GfpG6w2yp8DjxrmfC6XtiP"
```

---

### Task 3: Pipeline local-first com validação remota (sem paginação)

**Files:**
- Modify: `lib/features/catalog/presentation/providers/home_remote_search_provider.dart` (corpo do provider, linhas 55–90)
- Modify: `lib/features/catalog/presentation/providers/home_search_provider.dart` (doc linhas 12–24; `homeSearchPageProvider` linhas 34–37; `homeSearchStateProvider` linhas 51–78; `retryRemoteSearch` linhas 80–91; classe `HomeSearchPage` linhas 131–159)
- Modify: `test/unit/features/catalog/home_search_provider_test.dart`

**Interfaces:**
- Consumes: `HomeSearchState` (Task 1), `adoptColdigomSearchNoveltiesProvider` (Task 2), `coldigomSearchIndexProvider`, `coldigomCatalogSyncProvider` (plano 1), `connectivityStreamProvider`, `homeLocalSearchProvider` (já PLPCG + Coldigom).
- Produces:
  - `homeRemoteSearchProvider((query, page))` — inalterado na assinatura; depois de a página chegar, adota os «novos» (`AdoptColdigomSearchNovelties` com `knownPraiseIds = coldigomSearchIndexProvider.praiseIds`) e, se adotou, `coldigomCatalogSyncProvider.sync()`.
  - `homeSearchStateProvider` — `groups = local + newGroups`; `offline` quando `connectivityStreamProvider.value == false` (remoto nem instanciado); `page` fixo em 1.
  - `retryRemoteSearch(WidgetRef)` — invalida `(query, 1)`.
  - Removidos: `homeSearchPageProvider`, `HomeSearchPage`.

- [ ] **Step 1: Reescrever os testes do pipeline (falham)**

Em `test/unit/features/catalog/home_search_provider_test.dart`:

1. Imports novos:

```dart
import 'package:coldigui/core/network/connectivity_stream_provider.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_catalog_data_providers.dart';
import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';
import 'package:coldigui/features/coldigom/domain/usecases/adopt_coldigom_search_novelties.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/features/coldigom/data/datasources/coldigom_catalog_local_datasource.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_state.dart';
```

2. Fakes novos (antes de `main`):

```dart
/// Regista o que a Home pediu para adotar; devolve os ids como adotados.
class _RecordingAdopter extends AdoptColdigomSearchNovelties {
  _RecordingAdopter() : super(const ColdigomCatalogLocalDatasource.unavailable());

  final calls = <List<String>>[];
  Set<String> knownSeen = const {};

  @override
  Future<Set<String>> call(
    Iterable<LouvorGroup> remoteGroups, {
    required Set<String> knownPraiseIds,
  }) async {
    knownSeen = knownPraiseIds;
    final ids = [for (final g in remoteGroups) g.groupId];
    calls.add(ids);
    return ids.toSet();
  }
}

/// Conta os `sync()` disparados pela pesquisa; não toca na rede.
class _CountingSync extends ColdigomCatalogSyncNotifier {
  var calls = 0;

  @override
  ColdigomCatalogSyncState build() => const ColdigomCatalogSyncState();

  @override
  Future<ColdigomCatalogSyncResult> sync() async {
    calls++;
    return const ColdigomCatalogSyncNoop();
  }
}

LouvorGroup _coldigomGroup(String id) => LouvorGroup(
  groupId: id,
  numero: '900',
  nome: 'Coldigom $id',
  sections: const [],
  coldigomMeta: const ColdigomPraiseMetadata(name: 'Coldigom'),
);
```

(import `package:coldigui/features/coldigom/domain/entities/coldigom_praise_metadata.dart`.)

3. `createContainer` ganha `bool online = true` e `ColdigomSearchIndex index = ColdigomSearchIndex.empty` (um provider não pode ser sobrescrito duas vezes no mesmo container — por isso o índice entra por parâmetro, não por `extra`) e os overrides:

```dart
        connectivityStreamProvider.overrideWith((ref) => Stream.value(online)),
        adoptColdigomSearchNoveltiesProvider.overrideWithValue(adopter),
        coldigomCatalogSyncProvider.overrideWith(() => syncNotifier),
        coldigomSearchIndexProvider.overrideWithValue(index),
```

com `late _RecordingAdopter adopter; late _CountingSync syncNotifier;` inicializados no `setUp`.

4. Apague os testes «página 2 usa outra chave; voltar à 1 reusa o memo», «trocar a query volta a página para 1» e «mudar o filtro volta a página para 1 sem re-buscar a remota», e troque `expect(state.hasNextPage, isFalse);` (teste «query vazia») por `expect(state.freshness, SearchFreshness.updated);`. Acrescente:

```dart
  test('remoto igual ao local → updated, sem novos, sem adoção nem sync', () async {
    final coldigom = _coldigomGroup('cold-1');
    // Índice local conhece cold-1: a busca local devolve-o e o remoto só confirma.
    final source = _RecordingCatalogSource(
      (query) async => CatalogSearchPage(groups: [coldigom], page: query.page),
    );
    final container = createContainer(
      source,
      index: ColdigomSearchIndex.build([
        ColdigomIndexedPraise.build(
          praiseId: 'cold-1',
          numero: '900',
          nome: 'Coldigom cold-1',
          searchTokens: 'coldigom cold-1 900',
          group: coldigom,
        ),
      ]),
    );
    keepStateAlive(container);
    await pumpEventQueue();

    container.read(homeSearchDebouncedQueryProvider.notifier).setImmediate('coldigom');
    await pumpEventQueue();

    final state = container.read(homeSearchStateProvider);
    expect(state.freshness, SearchFreshness.updated);
    expect(state.newGroupIds, isEmpty);
    expect(state.groups.map((g) => g.groupId), contains('cold-1'));
    expect(adopter.calls, [<String>[]]);
    expect(syncNotifier.calls, 0);
  });

  test('remoto com extra → updatedWithNew, extra no fim, adoção e sync disparados', () async {
    final source = _RecordingCatalogSource(
      (query) async => CatalogSearchPage(
        groups: [_coldigomGroup('cold-2'), _coldigomGroup('cold-1')],
        page: query.page,
      ),
    );
    final container = createContainer(source);
    keepStateAlive(container);
    await pumpEventQueue();

    container.read(homeSearchDebouncedQueryProvider.notifier).setImmediate('aleluia');
    await pumpEventQueue();

    final state = container.read(homeSearchStateProvider);
    expect(state.freshness, SearchFreshness.updatedWithNew);
    expect(state.newCount, 2);
    expect(state.groups.map((g) => g.groupId).toList().sublist(state.localGroups.length), ['cold-2', 'cold-1']);
    expect(state.localGroups.first.groupId, isNot('cold-2'));
    expect(adopter.calls.single, ['cold-2', 'cold-1']);
    expect(adopter.knownSeen, isEmpty);
    expect(syncNotifier.calls, 1);
    expect(source.queries.single.page, 1);
  });

  test('remoto falha → failed com a lista local intacta', () async {
    final source = _RecordingCatalogSource((_) async => throw Exception('boom'));
    final container = createContainer(source);
    keepStateAlive(container);
    await pumpEventQueue();

    container.read(homeSearchDebouncedQueryProvider.notifier).setImmediate('aleluia');
    await pumpEventQueue();

    final state = container.read(homeSearchStateProvider);
    expect(state.freshness, SearchFreshness.failed);
    expect(state.localGroups, isNotEmpty);
    expect(state.groups.length, state.localGroups.length);
    expect(adopter.calls, isEmpty);
  });

  test('sem rede → offline sem chamar o remoto', () async {
    final source = _RecordingCatalogSource.ok();
    final container = createContainer(source, online: false);
    keepStateAlive(container);
    await pumpEventQueue();

    container.read(homeSearchDebouncedQueryProvider.notifier).setImmediate('aleluia');
    await pumpEventQueue();

    final state = container.read(homeSearchStateProvider);
    expect(state.freshness, SearchFreshness.offline);
    expect(state.localGroups, isNotEmpty);
    expect(state.remoteLoading, isFalse);
    expect(source.searchCalls, 0);
  });

  test('mudar o filtro não re-busca a remota', () async {
    final source = _RecordingCatalogSource.ok();
    final container = createContainer(source);
    keepStateAlive(container);
    await pumpEventQueue();

    container.read(homeSearchDebouncedQueryProvider.notifier).setImmediate('aleluia');
    await pumpEventQueue();
    expect(source.searchCalls, 1);

    container.read(catalogFiltersProvider.notifier).toggleMaterial('Partitura');
    await pumpEventQueue();

    expect(source.searchCalls, 1);
  });
```

O teste existente «página remota chega depois da local…» (linhas 156–183, o que espera `state.groups.last.groupId == 'coldigom-1'`) continua válido: o grupo remoto não está no local, logo é «novo» e vai para o fim.

Correr: `flutter test test/unit/features/catalog/home_search_provider_test.dart` → falha de compilação.

- [ ] **Step 2: Remoto adota os novos**

Em `home_remote_search_provider.dart`, imports `../../../coldigom/data/providers/coldigom_catalog_data_providers.dart` e `../../../coldigom/presentation/providers/coldigom_catalog_providers.dart`; substitua o trecho depois de `if (!ref.mounted) return page;` por:

```dart
      if (!ref.mounted) return page;

      // §6.2: o que o índice local não conhece vai para o Isar já, e o
      // ETag mudou — o dump inteiro vem a seguir pelo sync. Lê os providers
      // **antes** de qualquer await: este provider é autoDispose e um `ref`
      // descartado não pode ser lido.
      final adopt = ref.read(adoptColdigomSearchNoveltiesProvider);
      final known = ref.read(coldigomSearchIndexProvider).praiseIds;
      final syncNotifier = ref.read(coldigomCatalogSyncProvider.notifier);
      unawaited(
        adopt(page.groups, knownPraiseIds: known).then((adopted) {
          if (adopted.isNotEmpty) unawaited(syncNotifier.sync());
        }),
      );

      final link = ref.keepAlive();
      final timer = Timer(homeRemoteSearchMemoDuration, link.close);
      ref.onDispose(timer.cancel);

      return page;
```

Atualize o doc-comment do provider: «Página 1 da busca remota — **validação** da lista local (O15), cancelável e memoizada por `(query, página)`; a página é sempre 1 desde a pesquisa híbrida, a chave mantém o campo por compatibilidade.»

- [ ] **Step 3: Estado sem paginação**

Em `home_search_provider.dart`:

1. Doc-comment (linhas 12–24):

```dart
/// Estado da busca e filtros na Home (UC-01 + UC-02 + pesquisa híbrida §6).
///
/// Pipeline declarativo (C.2):
/// ```
/// homeSearchQueryProvider (texto cru)
///   → homeSearchDebouncedQueryProvider (300 ms)
///       ├→ homeLocalSearchProvider   (PLPCG + filtros, depois Coldigom local)
///       └→ homeRemoteSearchProvider((query, 1))  (Coldigom, valida; só com rede)
///             → homeSearchStateProvider → HomeSearchResultsSliver
/// ```
/// Sync URL: [homeSearchUrlSyncQueryProvider] + [catalogFiltersProvider]
/// consumidos por `HomeScreen` → `buildHomeLocation`.
```

2. Apague `homeSearchPageProvider` (linhas 34–37) e a classe `HomeSearchPage` (linhas 131–159).

3. `homeSearchStateProvider`:

```dart
/// Estado único da busca da Home — o que os widgets observam.
///
/// A lista é a local (PLPCG + Coldigom do índice); o remoto só valida (O15):
/// sem rede nem é instanciado (`offline`), com rede o que ele trouxer a mais
/// entra em `newGroups`, no fim, na ordem remota.
final homeSearchStateProvider = Provider<HomeSearchState>((ref) {
  final query = ref.watch(homeSearchDebouncedQueryProvider);
  final localGroups = ref.watch(homeLocalSearchProvider);

  if (query.trim().isEmpty) {
    // Sem query não há página remota: nada de `loading` e nada de rede — a
    // família nem chega a ser instanciada.
    return HomeSearchState(
      query: query,
      localGroups: localGroups,
      remote: const AsyncData(CatalogSearchPage.empty),
    );
  }

  // `AsyncLoading` inicial da conectividade conta como online, como no
  // resto da Home; só um `false` explícito segura o remoto.
  final online = ref.watch(connectivityStreamProvider).value ?? true;
  if (!online) {
    return HomeSearchState(
      query: query,
      localGroups: localGroups,
      remote: const AsyncLoading(),
      offline: true,
    );
  }

  final remote = ref.watch(
    homeRemoteSearchProvider(HomeRemoteSearchKey(query: query, page: 1)),
  );
  final localIds = {for (final g in localGroups) g.groupId};
  final newGroups = [
    for (final g in remote.value?.groups ?? const <LouvorGroup>[])
      if (!localIds.contains(g.groupId)) g,
  ];

  return HomeSearchState(
    query: query,
    localGroups: localGroups,
    remote: remote,
    newGroups: newGroups,
  );
});
```

(import `../../../../core/network/connectivity_stream_provider.dart`.)

4. `retryRemoteSearch`:

```dart
/// Re-dispara a validação remota da query corrente (linha de estado e
/// reconexão). Invalida só a chave `(query, 1)` que está na tela.
void retryRemoteSearch(WidgetRef ref) {
  final query = ref.read(homeSearchDebouncedQueryProvider);
  if (query.trim().isEmpty) return;
  ref.invalidate(
    homeRemoteSearchProvider(HomeRemoteSearchKey(query: query, page: 1)),
  );
}
```

`flutter analyze` ainda acusa `home_search_results_sliver.dart` e `home_coldigom_pagination_controls.dart` (Task 4). Para fechar o commit desta task com `analyze` limpo, faça já a parte mínima da Task 4 neste commit: apague `home_coldigom_pagination_controls.dart` e, em `home_search_results_sliver.dart`, remova o `import` dele, o valor `pager` do enum, o ramo `pager` de `homeSearchTrailingSlot` e do `switch` (a linha final passa a ser só `loading`/`error`); os testes do sliver que citam o pager são reescritos na Task 4.

Correr: `flutter test test/unit/features/catalog/home_search_provider_test.dart test/unit/features/catalog/home_search_state_test.dart` → verdes; `flutter analyze` limpo.

- [ ] **Step 4: Commit (fecha Task 1 + Task 3)**

```bash
dart format lib test
flutter analyze
git add -A lib test
git commit -m "feat(catalog): pesquisa híbrida — lista local única, remoto só valida a página 1, novos no fim e adotados no Isar (O15/O16)

Remove a paginação Coldigom da Home (homeSearchPageProvider, HomeColdigomPaginationControls).

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GfpG6w2yp8DjxrmfC6XtiP"
```

---

### Task 4: `SearchFreshnessLine`, chip «novo» e sliver sem paginação

**Files:**
- Modify: `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb`
- Create: `lib/features/catalog/presentation/widgets/search_freshness_line.dart`
- Modify: `lib/features/catalog/presentation/widgets/home_search_results_sliver.dart` (ficheiro inteiro)
- Modify: `lib/features/carousel/presentation/widgets/carousel_louvor_chip.dart` (parâmetro `isNew`; render ao lado do badge offline, ~linha 268)
- Modify: `lib/features/catalog/presentation/widgets/louvor_group_card.dart` (`build`, passar `isNew`)
- Modify: `test/widget/features/catalog/home_search_results_sliver_test.dart`, `test/widget/features/catalog/home_search_test.dart`
- Test: `test/widget/features/catalog/home_search_freshness_test.dart`

**Interfaces:**
- Consumes: `HomeSearchState.freshness/newCount/newGroupIds` (Task 1), `retryRemoteSearch` (Task 3), `homeSearchStateProvider`.
- Produces:
  - l10n: `searchFreshnessChecking` («Em cache · a verificar…»), `searchFreshnessUpdated` («Atualizado»), `searchFreshnessUpdatedNew(count)` («Atualizado · {count} novos»), `searchFreshnessOffline` («Em cache · sem ligação»), `searchFreshnessFailed` («Em cache · não foi possível verificar»), `searchResultNew` («novo»).
  - `class SearchFreshnessLine extends StatelessWidget { const SearchFreshnessLine({required SearchFreshness freshness, required int newCount, VoidCallback? onRetry}); }` — ícone `○`/`✓` + texto `bodySmall`/`onSurfaceVariant`; em `failed` o texto é um `TextButton` que chama `onRetry`.
  - `CarouselLouvorChip({…, bool isNew = false})` — chip «novo» (mesmo estilo do badge offline: fundo `AppColors.gold` 25 %, borda `AppColors.gold`, texto 10 px) ao lado da badge.
  - Sliver: linha no topo quando a query não é vazia; sem `pager`; sem spinner de rodapé (a linha «a verificar…» substitui-o); a linha «Coldigom indisponível · tentar de novo» sai — o retry vive na própria linha de estado (`failed`).

- [ ] **Step 1: l10n**

`app_pt.arb`:

```json
  "searchFreshnessChecking": "Em cache · a verificar…",
  "searchFreshnessUpdated": "Atualizado",
  "searchFreshnessUpdatedNew": "{count, plural, one{Atualizado · 1 novo} other{Atualizado · {count} novos}}",
  "@searchFreshnessUpdatedNew": { "placeholders": { "count": { "type": "int" } } },
  "searchFreshnessOffline": "Em cache · sem ligação",
  "searchFreshnessFailed": "Em cache · não foi possível verificar",
  "searchResultNew": "novo"
```

`app_en.arb`:

```json
  "searchFreshnessChecking": "Cached · checking…",
  "searchFreshnessUpdated": "Up to date",
  "searchFreshnessUpdatedNew": "{count, plural, one{Up to date · 1 new} other{Up to date · {count} new}}",
  "searchFreshnessOffline": "Cached · offline",
  "searchFreshnessFailed": "Cached · could not verify",
  "searchResultNew": "new"
```

`flutter gen-l10n`.

- [ ] **Step 2: Teste que falha**

`test/widget/features/catalog/home_search_freshness_test.dart`:

```dart
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_query.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_state.dart';
import 'package:coldigui/features/catalog/presentation/widgets/home_search_results_sliver.dart';
import 'package:coldigui/features/catalog/presentation/widgets/search_freshness_line.dart';
import 'package:coldigui/features/coldigom/domain/entities/coldigom_praise_metadata.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

LouvorGroup _group(String id) => LouvorGroup(
  groupId: id,
  numero: '001',
  nome: id,
  sections: const [],
  coldigomMeta: const ColdigomPraiseMetadata(name: 'x'),
);

late SharedPreferences _prefs;

Future<void> _pump(WidgetTester tester, HomeSearchState state) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(_prefs),
        homeSearchStateProvider.overrideWithValue(state),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: const Scaffold(
          body: CustomScrollView(slivers: [HomeSearchResultsSliver()]),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });

  final local = [_group('a'), _group('b')];

  testWidgets('checking / updated / offline / failed', (tester) async {
    await _pump(tester, HomeSearchState(query: 'x', localGroups: local, remote: const AsyncLoading()));
    expect(find.text('Em cache · a verificar…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await _pump(tester, HomeSearchState(query: 'x', localGroups: local, remote: const AsyncData(CatalogSearchPage.empty)));
    expect(find.text('Atualizado'), findsOneWidget);

    await _pump(tester, HomeSearchState(query: 'x', localGroups: local, remote: const AsyncLoading(), offline: true));
    expect(find.text('Em cache · sem ligação'), findsOneWidget);

    await _pump(tester, HomeSearchState(query: 'x', localGroups: local, remote: AsyncError(Exception('boom'), StackTrace.empty)));
    expect(find.text('Em cache · não foi possível verificar'), findsOneWidget);
    expect(find.text('Coldigom indisponível · tentar de novo'), findsNothing);
  });

  testWidgets('updatedWithNew: «N novos» na linha e chip «novo» só nos cards novos', (tester) async {
    await _pump(
      tester,
      HomeSearchState(
        query: 'x',
        localGroups: local,
        remote: AsyncData(CatalogSearchPage(groups: [_group('c')], page: 1)),
        newGroups: [_group('c')],
      ),
    );

    expect(find.text('Atualizado · 1 novo'), findsOneWidget);
    expect(find.text('novo'), findsOneWidget);
    // O chip vive no card do grupo novo, o último da lista.
    final chip = find.text('novo');
    expect(find.ancestor(of: chip, matching: find.byWidgetPredicate((w) => w.key == const ValueKey('card-c'))), findsOneWidget);
  });

  testWidgets('sem query não há linha; query com resultado vazio a verificar mostra só a linha', (tester) async {
    await _pump(tester, const HomeSearchState(query: '', localGroups: [], remote: AsyncData(CatalogSearchPage.empty)));
    expect(find.byType(SearchFreshnessLine), findsNothing);

    await _pump(tester, const HomeSearchState(query: 'zzz', localGroups: [], remote: AsyncLoading()));
    expect(find.byType(SearchFreshnessLine), findsOneWidget);
    expect(find.text('Nenhum louvor para «zzz»'), findsNothing);

    await _pump(tester, const HomeSearchState(query: 'zzz', localGroups: [], remote: AsyncData(CatalogSearchPage.empty)));
    expect(find.text('Nenhum louvor para «zzz»'), findsOneWidget);
  });
}
```

Correr → falha.

- [ ] **Step 3: Linha de estado**

`lib/features/catalog/presentation/widgets/search_freshness_line.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/color_extensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/home_search_state.dart';

/// Linha «Em cache · a verificar…» → «Atualizado» no topo dos resultados
/// (spec §6.3). Em `failed` o texto é o retry: a lista local já está na
/// tela, não há mais nada a fazer além de tentar de novo.
class SearchFreshnessLine extends StatelessWidget {
  const SearchFreshnessLine({
    required this.freshness,
    required this.newCount,
    this.onRetry,
    super.key,
  });

  final SearchFreshness freshness;
  final int newCount;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = AppColors.textLight.withValues(alpha: 0.7);
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: color);
    final (icon, text) = switch (freshness) {
      SearchFreshness.checking => (Icons.radio_button_unchecked, l10n.searchFreshnessChecking),
      SearchFreshness.updated => (Icons.check, l10n.searchFreshnessUpdated),
      SearchFreshness.updatedWithNew => (Icons.check, l10n.searchFreshnessUpdatedNew(newCount)),
      SearchFreshness.offline => (Icons.radio_button_unchecked, l10n.searchFreshnessOffline),
      SearchFreshness.failed => (Icons.radio_button_unchecked, l10n.searchFreshnessFailed),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          if (freshness == SearchFreshness.failed && onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: color,
              ),
              child: Text(text, style: style),
            )
          else
            Text(text, style: style),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Sliver**

`home_search_results_sliver.dart` inteiro:

```dart
import 'package:coldigui/features/catalog/presentation/providers/home_search_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/home_empty_state.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_group_card.dart';
import 'package:coldigui/features/catalog/presentation/widgets/search_freshness_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lista de resultados da Home — isolada da [SearchBar] para evitar rebuilds
/// do campo de busca quando a validação remota conclui.
///
/// Desde a pesquisa híbrida (§6) a lista é a local; o remoto só acrescenta
/// «novos» no fim e alimenta a [SearchFreshnessLine] no topo. Não há mais
/// spinner de rodapé, pager nem linha «Coldigom indisponível»: os três
/// viraram estados da linha.
class HomeSearchResultsSliver extends ConsumerWidget {
  const HomeSearchResultsSliver({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeSearchStateProvider);
    final results = state.groups;
    final newIds = state.newGroupIds;

    if (state.isEmptyQuery) {
      return SliverToBoxAdapter(child: HomeEmptyState(state: state));
    }

    final line = SearchFreshnessLine(
      freshness: state.freshness,
      newCount: state.newCount,
      onRetry: () => retryRemoteSearch(ref),
    );

    if (results.isEmpty) {
      // Enquanto o remoto valida, «Nenhum louvor» seria mentira: ele ainda
      // pode trazer algo. A linha sozinha diz o que está a acontecer.
      return SliverToBoxAdapter(
        child: Column(
          children: [
            line,
            if (!state.remoteLoading) HomeEmptyState(state: state),
          ],
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index == 0) return line;
        final group = results[index - 1];
        return LouvorGroupCard(
          key: ValueKey('card-${group.groupId}'),
          group: group,
          isNew: newIds.contains(group.groupId),
        );
      }, childCount: results.length + 1),
    );
  }
}
```

Apague `home_coldigom_pagination_controls.dart` (se ainda existir) e a chave l10n `coldigomUnavailableRetry` fica sem uso (não apague: `home_screen_error_test.dart` pode citá-la — verifique com `grep -rn coldigomUnavailableRetry test lib`; se só o `.arb` a tiver, apague-a dos dois ARBs).

- [ ] **Step 5: Chip «novo» no card**

`louvor_group_card.dart`: `const LouvorGroupCard({required this.group, this.isNew = false, super.key});` + `final bool isNew;` (doc: «Card vindo só da validação remota — chip «novo» (§6.3).»); em `build` passar `isNew: widget.isNew` ao `CarouselLouvorChip`.

`carousel_louvor_chip.dart`: parâmetro `this.isNew = false` + `final bool isNew;`; onde o `OfflineAvailabilityBadge` é renderizado (~linha 268), acrescentar ao lado (na mesma `Row`, depois do badge):

```dart
                      if (isNew) ...[
                        const SizedBox(width: 4),
                        _NewChip(label: AppLocalizations.of(context)!.searchResultNew),
                      ],
```

e no fim do ficheiro:

```dart
/// Chip «novo» — mesmo estilo do badge offline: pequeno, dourado, sem
/// competir com o título.
class _NewChip extends StatelessWidget {
  const _NewChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gold, width: 1),
      ),
      child: Text(
        label,
        style: AppTypography.label.copyWith(
          fontSize: 10,
          color: Colors.white.withValues(alpha: 0.95),
        ),
      ),
    );
  }
}
```

(Se o chip já importa `AppLocalizations`/`AppTypography`, reutilize; senão acrescente os imports.)

- [ ] **Step 6: Testes existentes do sliver e da Home**

`home_search_results_sliver_test.dart`: apague os casos que citam `pager`/`chevron`/`Página` e o caso «remoto falho … "Coldigom indisponível"» (a linha de retry mudou de sítio — o novo comportamento está em `home_search_freshness_test.dart`); mantenha «sem consulta…» e «consulta sem resultado e remoto concluído…». `home_search_test.dart`: procure `chevron_right`/`pageNext`/`Página 2`; remova esses asserts (a paginação não existe) e mantenha o resto.

Correr: `flutter test test/widget/features/catalog test/unit/features/catalog` → verdes.

- [ ] **Step 7: Commit**

```bash
flutter gen-l10n
dart format lib test
flutter analyze
git add -A lib test
git commit -m "feat(catalog): SearchFreshnessLine (em cache → atualizado) e chip «novo» nos resultados vindos só do remoto

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GfpG6w2yp8DjxrmfC6XtiP"
```

---

### Task 5: Docs (UC-01, FEATURE_INDEX)

**Files:**
- Modify: `docs/use-cases/UC-01-search-louvor-home.md`
- Modify: `docs/features/FEATURE_INDEX.md`

- [ ] **Step 1: UC-01**

«Fluxo principal», passo 5: `5. Resultados como LouvorGroupCard — lista única local (PLPCG com filtros, depois Coldigom do índice), linha «Em cache · a verificar…» no topo. 6. A página 1 remota do Coldigom valida: igual → «Atualizado»; louvores que o local não tinha → anexados no fim com o chip «novo», gravados no Isar (AdoptColdigomSearchNovelties) e sync do catálogo disparado.`

«Fluxos alternativos»: acrescentar `Sem rede → «Em cache · sem ligação» (remoto não é chamado). Remoto falha → «Em cache · não foi possível verificar» (toque = tentar de novo); lista local intacta. Remoto com menos itens que o local → nada é removido (só o sync substitui).`

«Regras de negócio»: acrescentar `Sem paginação Coldigom na Home (O15); ordem PLPCG → Coldigom → novos (O16).`

«Componentes Flutter alvo»: acrescentar `SearchFreshnessLine, homeSearchStateProvider (SearchFreshness), AdoptColdigomSearchNovelties`.

- [ ] **Step 2: FEATURE_INDEX**

Linha `catalog`: acrescentar `; **pesquisa híbrida set/2026** — lista local única + validação remota ([SearchFreshness], [SearchFreshnessLine], chip «novo», [AdoptColdigomSearchNovelties]); paginação Coldigom da Home removida (O15/O16)`.

- [ ] **Step 3: Commit**

```bash
git add docs
git commit -m "docs(catalog): UC-01 e FEATURE_INDEX — pesquisa híbrida (local-first, validação remota, novos)

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GfpG6w2yp8DjxrmfC6XtiP"
```

---

## Checklist manual (§8 da spec — Parte 3)

**Pré-requisito:** Parte 1 no ar (catálogo hidratado); Parte 2 opcional.

**Web dev (`flutter run -d chrome --dart-define-from-file=dart_defines/dev.json`):**
- [ ] Pesquisar `tempo`: cards PLPCG e Coldigom aparecem **de imediato** com a linha «○ Em cache · a verificar…» no topo; sem spinner de rodapé; sem setas de página no fim da lista.
- [ ] Segundos depois a linha vira «✓ Atualizado» (Network: um único `GET /api/plpcg/praises?q=tempo&page=1`); mudar um chip de filtro não dispara request nova.
- [ ] Simular «novo»: no DevTools apagar uma linha de `ColdigomPraiseCache` (ou pesquisar uma palavra que só a letra tem — o servidor faz FTS na letra, o índice local não): o card entra no fim com o chip «novo» e a linha diz «✓ Atualizado · 1 novo»; Network mostra `GET /api/plpcg/catalog` a seguir (sync); após a re-hidratação, repetir a pesquisa mostra o louvor na parte local sem chip.
- [ ] Network → Offline (com shell offline) ou desligar o Wi-Fi no nativo: linha «○ Em cache · sem ligação», nenhuma request; a lista local continua.
- [ ] Apontar `COLDIGOM_API_BASE_URL` para um host inválido: linha «○ Em cache · não foi possível verificar»; tocar nela re-dispara (Network mostra nova tentativa); lista local intacta.
- [ ] Limpar a query: a linha some e o estado vazio da Home (recentes) volta.

**iPhone real (build homolog):**
- [ ] Modo de avião: pesquisar por número e por texto — resultados PLPCG + Coldigom com «Em cache · sem ligação».
- [ ] Voltar online sem fechar o app: a próxima pesquisa mostra «a verificar…» → «Atualizado».
- [ ] Pesquisar uma palavra só presente na letra (ex.: um verso): o louvor chega como «novo» no fim; depois do sync, entra na lista local.

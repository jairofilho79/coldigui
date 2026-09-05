# Onda 3 — web: sync de ponta a ponta, lista ativa como única seleção, busca da Home pela porta

**Criado em:** 2026-09-04 · **Branch:** `web/integration` @ `861e56a` (onda 2 integrada, Worker publicado com a migration `0008`)
**Origem:** seção I.4 de `docs/WEB_REFACTOR_OPPORTUNITIES_2026-09.md` (próxima onda recomendada), aprovada pelo dono do produto ("onda 3").
**Autoridade:** `PRODUCT.md` (princípios 1–4), `docs/USER_AUTH_PLAYLIST_SYNC_SPEC.md` (§6, §7, §10).
**Levantamento:** `.superpowers/sdd/2026-09-04-onda3-web/w3-explore-{sync,carousel,search,leftovers}.md` (copiados pelo controlador; `arquivo:linha` de `861e56a`).

Quatro subprojetos com contratos próprios. As decisões foram tomadas pelo executor e estão marcadas **[decisão]**; as marcadas **[decisão — revisar]** mudam semântica visível ao usuário ou formato que sai do dispositivo e merecem o olhar do dono do produto.

---

## Subprojeto A — Sync de ponta a ponta

### A.0 Problema

A onda 2 deixou o sync de listas tolerante e com ordem única, mas: a rota social ainda responde v1 (perde a ordem intercalada); o sync de marcadores de áudio (`audio_flag_sync_provider.dart`) está no formato antigo (sem `sub` persistido, pull que derruba push, 409 engolido, sem erro visível, sem `ref.mounted`); o 409 descarta as edições locais; uma lista apagada em outro aparelho nunca some deste (`GET /api/playlists` filtra `deleted_at`, e o cliente só visita o que o servidor devolve); trocar de conta Google no mesmo aparelho sobe a biblioteca inteira da conta anterior para a nova (nada no Isar tem dono); um `syncAfterLogin` que falha só é retentado no próximo boot; o CI do Worker nunca roda `tsc` e a lista de testes é explícita (um arquivo novo é pulado em silêncio).

### A.1 Rota social v2

**[decisão]** `listPublicPlaylistsByUsername` passa a selecionar `items` e a responder `schemaVersion: 2` + `items: [{id, kind}]` **ao lado** de `pdfIds`/`audioIds` (mesma projeção de `rowToJson`: `parseItemsColumn` com fallback `itemsFromLegacy`). `SCHEMA_VERSION`, `parseIdList` e o `json()` local viram exports de um módulo compartilhado (`src/playlists/wire.ts`), sem duplicatas em `social/handlers.ts`.

- Cliente: `PublicPlaylist` ganha `entries: List<PlaylistEntry>` lido como `RemotePlaylist.fromJson` (v1 → classificado por extensão + `audioIds` declarados; v2 → `resolveWireKind`); `pdfIds`/`audioIds` viram getters derivados. `SocialRemoteDatasource.fetchUserPlaylists` fica tolerante por item (um registro malformado é descartado com log, não derruba a lista).
- Import da lista pública (`social_user_card.dart`) adiciona **todas** as entradas, na ordem e com o `kind`, à lista ativa (via `addEntriesToActive` do subprojeto B); a contagem exibida é `entries.length`.
- Teste do Worker `src/social/handlers.test.ts` com `fake_d1.ts` estendido para a consulta de `users` por `username` e o `SELECT … WHERE user_id = ? AND is_published = 1 AND deleted_at IS NULL`.

### A.2 Exclusão remota por tombstones (B9)

**[decisão — revisar]** O servidor passa a **expor** os tombstones que já guarda; o cliente nunca deduz exclusão por ausência (uma lista pulada por estar malformada, ou um pull parcial, apagaria dados válidos).

- Worker: `GET /api/playlists?includeDeleted=1` devolve também as linhas com `deleted_at IS NOT NULL`, cada uma com `deletedAt` (ISO) no JSON; sem o parâmetro, comportamento atual. Mesmo para `GET /api/audio-flags?includeDeleted=1`. `PlaylistJson`/`AudioFlagJson` ganham `deletedAt: string | null` (sempre presente; `null` nas vivas).
- Cliente (`SyncPlaylists._pull`, sempre com `includeDeleted=1`): para cada remota com `deletedAt != null`: se não existe local → ignora; se a local está `synced` ou `pendingPull`, ou `pendingPush` com `updatedAt <= deletedAt` → **hard delete local** (contado em `PlaylistSyncResult.deletedRemotely`); se a local está `pendingPush` com `updatedAt > deletedAt` → mantém e o push a ressuscita (ramo `existing.deleted_at !== null` do Worker, já existente). Se a lista apagada era a ativa, `activePlaylistIdProvider` é limpo pelo `reload()` da tela (regra já existente em `hydratePlaylistSession`: id sem lista → limpa).
- Mesma regra em `SyncAudioFlags`.
- Banner: quando `deletedRemotely > 0`, snackbar informativo «N lista(s) removida(s) em outro aparelho» (não é erro).

### A.3 Conflito 409 com cópia local

**[decisão — revisar]** Quando o remoto é mais novo e a local tinha edições pendentes (`syncStatus == pendingPush`), a versão local **não é descartada**: antes do `upsert(remoto)`, ela é gravada como uma lista nova (`playlistId` novo, `nome: '<nome> (cópia local)'`, `salva: true`, `syncStatus: PlaylistSyncStatus.conflict`, `entries`/`updatedAt` da local, `version: 1`), e a original recebe o remoto (`synced`). A cópia com status `conflict` **não é enviada** enquanto o usuário não a editar (qualquer `update` a marca `pendingPush` e ela sobe como lista nova). `PlaylistSyncResult.conflicts` conta essas cópias; o banner existente passa a dizer «Edições locais de «X» guardadas em «X (cópia local)»» (chave `playlistConflictCopySaved`). A cópia só é criada quando `entries`/`nome` da local diferem do remoto (edição idêntica não gera lixo).

O ramo de re-push (cliente mais novo) fica como está.

### A.4 Marcadores de áudio no mesmo formato

**[decisão]** `SyncAudioFlags`/`AudioFlagSyncNotifier` espelham o par de listas, sem abstração genérica nova (duas cópias alinhadas custam menos do que um `SyncRunner<T>` agora):
- pull isolado (falha do pull não impede push nem tombstones), tolerante por item (já é);
- `AudioFlagRemoteDatasource.upsert` converte 409 em `AudioFlagConflictException(remote)`; resolução LWW por `updatedAt` (remoto mais novo → `upsert(remoto)`; senão re-push único com `version` do remoto; falha → `conflict`). Sem cópia local (um marcador é um par posição/rótulo — o remoto vence);
- tombstones com `maxTombstoneAttemptsPerBoot = 3`;
- `AudioFlagSyncResult` ganha `conflicts`, `deletedRemotely`, `pullError`, `pushError`, `error`; `AudioFlagSyncState` ganha `lastErrorCause`, `hasProblem`;
- `sub` persistido em `audio_flag_sync.last_synced_sub` com a mesma regra do de listas (só remarca tudo quando o `sub` muda; falha em `markAllPendingPush` não persiste o `sub`);
- `ref.mounted` após todo `await`; `retryAndReload()`;
- erro visível: linha «Marcadores não sincronizados · Tentar novamente» (`audioFlagsSyncFailed`) no `AudioPlayerScreen`, acima da lista de marcadores.

### A.5 Uma conta por vez no mesmo aparelho (B18)

**[decisão — revisar]** `Playlist` e `AudioFlag` ganham `String? ownerSub` (declarado **por último**; `null` = ainda sem dono). Regras:
- `adoptForSub(sub)` substitui `markAllSavedPendingPush()`: marca `pendingPush` **só** as salvas com `ownerSub == null || ownerSub == sub` e grava `ownerSub = sub` nelas. Rascunhos (`salva == false`) nunca ganham dono.
- Toda linha escrita pelo pull/push recebe `ownerSub = sub` corrente.
- Na troca de conta (`sub` persistido ≠ `sub` que entrou, e o persistido não é `null`): antes do `adoptForSub`, `purgeSyncedOwnedBy(previousSub)` faz **hard delete** das linhas com `ownerSub == previousSub` e `syncStatus == synced` (estão na nuvem da conta anterior; voltam no próximo login dela). Linhas da conta anterior com `pendingPush`/`conflict` ficam no aparelho, com o dono antigo, e **não** entram no push da conta nova. Se a lista ativa foi apagada, o id ativo é limpo.
- Logout continua sem tocar nos dados (re-login na mesma conta é barato).
- Mesma regra para `AudioFlag`.

Custo se estiver errado: uma pessoa que usa duas contas no mesmo aparelho perde a visão local das listas da conta que saiu até voltar a ela (nada é perdido na nuvem).

### A.6 Retentativa do pós-login e reconexão

- `PlaylistSyncNotifier.retryAndReload()` reexecuta `syncAfterLogin` quando o `sub` corrente ainda não foi persistido (adoção pendente); senão `sync()`.
- Os dois notifiers escutam `connectivityStreamProvider`: ao voltar a rede com usuário logado, disparam `sync()` (debounce de 2 s; um só em voo).

### A.7 Worker: CI e testes

- `package.json`: `"typecheck": "tsc --noEmit"`; `"test": "node --experimental-strip-types --test \"src/**/*.test.ts\""` (glob nativo do Node 22). Erros de tipo encontrados pelo `tsc` são corrigidos na mesma tarefa.
- `.github/workflows/web.yml` job `worker`: passo `npm run typecheck` antes de `npm test`.

---

## Subprojeto B — D3: a lista ativa é a única seleção

### B.0 Problema

O carousel é uma segunda persistência (`CarouselEntry{pdfId @unique, sortOrder}` no Isar) reconciliada à mão com a playlist ativa em sete pontos, em dois sentidos (`syncActivePlaylistFromCarousel`, `LoadPlaylistIntoCarousel`, `resolveActivePlaylistFromCarousel` com 80 linhas que chegam a criar rascunho); o índice único torna um louvor repetido impossível (princípio 4 do `PRODUCT.md`: a lista é de louvores, e uma reunião pode repetir um); `clear()` não sincroniza; `removePdf` na tela de listas não toca o carousel; `LoadPlaylistIntoCarousel` descarta os áudios; e a face de áudio é uma troca de widget com três fontes de dados, não um filtro.

### B.1 Modelo

**[decisão]** `SavedPlaylist.entries` da lista ativa é a **única** fonte de verdade da seleção. Não existe mais escrita em `CarouselEntry`.

- **Identidade de entrada = posição.** `PlaylistEntry` continua `{id, kind}` (o wire e o Isar não mudam). A view deriva uma chave estável por ocorrência: `key = id` para a primeira ocorrência e `'$id#$n'` para a n-ésima (n ≥ 1). Chaves servem a `ValueKey`, ao foco persistido e às mutações por chave; duas ocorrências do mesmo id só se distinguem pela posição, e isso basta.
- **Repetição permitida.** `entries` pode ter o mesmo id mais de uma vez. A adição rápida (botão «+» do card, do sheet e do áudio) continua **idempotente** por padrão (`allowDuplicate: false` → devolve `alreadyPresent`); o sheet de materiais mostra «Adicionar de novo» quando o material já está na lista, e o import de share/social respeita repetições da origem. **[decisão — revisar]**
- **Face = filtro puro.** `PlaylistMediaFace.pdf` ⇒ `entries.where((e) => !e.isAudio)`; `audio` ⇒ `entries.where((e) => e.isAudio)`. A face continua um toggle global persistido.

### B.2 Providers da view (feature `carousel`, presentation)

- `activePlaylistProvider: Provider<SavedPlaylist?>` — lista ativa (id de `activePlaylistIdProvider` resolvido em `playlistsProvider`).
- `ActiveEntry { int index; PlaylistEntry entry; String key; }` e `activeEntriesProvider: Provider<List<ActiveEntry>>` — `entries` com chaves, com **override otimista** de reordenação (ver B.3).
- `CarouselItem` passa a `{ String materialId; MaterialKind kind; int index; String key; numero; nome; categoria; classificacao; source }` (`pdfId`/`sortOrder` saem; `label` fica). Enriquecimento sem mapa O(catálogo) por mutação (A4): `louvoresByPdfIdProvider: Provider<Map<String, Louvor>>` é construído **uma vez por manifest**; Coldigom e cifras já são mapas por id (`coldigomLouvoresCacheProvider`, `coldigomChordMaterialsCacheProvider`) e são consultados por id. Sem metadado → fallback `nome` truncado (regra atual).
- `carouselItemsProvider: Provider<List<CarouselItem>>` — **face de partituras** (substitui `carouselLouvoresProvider`/`carouselLouvoresDisplayProvider`; o debounce de reordenação passa a ser o override otimista).
- `audioFaceItemsProvider: Provider<List<CarouselItem>>` — face de áudio.
- `activeMaterialIdsProvider: Provider<Set<String>>` — ids presentes (substitui `carouselPdfIdsProvider`; o badge do card usa `select`).
- `carouselFocusedIndexProvider` continua: índice na face de partituras, persistido por **chave** na mesma pref `carousel_focused_pdf_id` (valores antigos são chaves válidas da primeira ocorrência). `focusKey(String key)` substitui `focusPdfId`.

### B.3 Mutações (feature `playlists`, `ActivePlaylistEditor` — Notifier no mesmo arquivo do override)

Todas passam por `PlaylistRepository.update(playlistId, entries: …)` (parâmetro novo em `update` e em `UpdatePlaylist`; `entries` vence `pdfIds`/`audioIds`) e terminam em `playlistsProvider.reload()`; lista salva → `playlistSyncProvider.sync()` (regra de `syncActivePlaylistFromCarousel`, que sai).

- `addToActive(String materialId, {MaterialKind? kind, bool allowDuplicate = false}) → Future<AddToActiveOutcome>` (`added | alreadyPresent | storageUnavailable`): garante rascunho (`EnsurePlaylistForLouvor`), classifica por `kind ?? materialIdKindOf(id)`. Substitui `addLouvorToActivePlaylist`, `addAudioToActivePlaylist` e `CarouselLouvoresNotifier.add`.
- `addEntriesToActive(List<PlaylistEntry>) → Future<int>` (import social/share: repete o que a origem repete).
- `removeByKey(String key)`, `replaceByKey(String key, PlaylistEntry replacement)` (troca de material na mesma posição — leitor e sheet de troca), `reorderFace(PlaylistMediaFace face, List<String> orderedKeys)` (permuta só a face, preservando as posições da outra via `replaceSubset`; aplica override otimista imediato e persiste com debounce de 100 ms), `detachActive()` (limpa o id ativo sem tocar na lista) e `deleteActiveDraft()` (rascunho: apaga e limpa). `CarouselClearChoiceDialog` mantém a semântica atual sobre estes dois.
- `activate(String playlistId) → String? previousActiveId` (D6).
- Uma lista que fica sem entradas continua sendo apagada se for rascunho (regra de `UpdatePlaylist`); salva vazia fica.
- **Migração única** (`MigrateCarouselStore`, chamada em `hydratePlaylistSession`): se `CarouselEntry` tem linhas — sem lista ativa: cria rascunho com os ids classificados por extensão e o torna ativo; com lista ativa: a lista **vence** (o sync era carousel → lista a cada mutação, então já espelham); depois esvazia a coleção. `CarouselEntry` fica no schema (só leitura para a migração; remoção do schema numa onda futura).
- Saem: `CarouselRepository`/`CarouselLocalDatasource` (exceto `getOrderedPdfIds`/`clear` para a migração), os quatro use cases do carousel, `active_playlist_sync.dart`, `load_playlist_into_carousel.dart`, `create_playlist_from_carousel.dart` (a partir da ativa: `saveActivePlaylist` já existe), `resolveActivePlaylistFromCarousel`, `_findPlaylistWithPdfIds`, `_pdfIdsMatch`, `navigate_carousel_in_reader.dart` (morto). `RemapPdfIdsAfterCatalogUpdate` só remapeia listas. `GenerateLeafletFromSelection` lê a face de partituras da ativa.

### B.4 Nomes

`pdfId` → `materialId` nos contratos do carousel e do leitor (`CarouselItem`, `CarouselReaderPosition.previousMaterialId/nextMaterialId`, `PrefetchAdjacentCarouselPdfs`, `openCarouselPdfInReader`, `focusKey`). Ficam como estão: `UrlSyncParams.pdfId` (URL pública), `SavedPlaylist.pdfIds`/`Playlist.pdfIds` (wire/disco), `Louvor.pdfId` (manifest).

### B.5 Leitor sobre a view

- `readerCarouselPositionProvider` deriva de `carouselItemsProvider`: item corrente = o focado quando `items[focused].materialId == pdfId` da URL, senão a primeira ocorrência do id; `previous/next` pelos vizinhos na face. Navegação (setas, teclado `N`/`P`, chips) foca por chave e faz `context.replace` com o `pdfId`.
- Prefetch adjacente e `reader_carousel_actions_provider` idem. Nada lê Isar do carousel.

### B.6 D4 — fila do player é a reunião

`audioQueueForActiveList(ref)` (utilitário em `audio_player`) devolve as faixas das entradas de áudio da ativa, na ordem, resolvidas pelo `catalogMaterialLookupProvider` (C.3). Os três pontos que hoje tocam com `group.audioTracks` (`louvor_group_card.dart`, `carousel_swap_material_button.dart`, `open_material_provider.dart` via `audioQueue`) e o `_playGroupAudio` dos chips passam a: faixa está na ativa → fila = ativa; senão → fila = materiais do grupo (regra híbrida que os chips já têm). `playlist_audio_face_panel.dart` calcula `hasPrevious`/`hasNext` da sessão.

### B.7 D6 — «Tornar ativa» sem modal

**[decisão — revisar]** «Carregar no carousel» vira «Tornar lista ativa» (`playlistActivate`): `activate(id)`, sem confirmação (nada é destruído: a lista que era ativa continua existindo como rascunho ou salva), snackbar «Lista «X» ativa» com «Desfazer» (`activate(previousActiveId)`; 5 s). O modal «Substituir seleção?» e as chaves `playlistLoadConfirmTitle/Message` saem, inclusive do import por URL na tela de listas (paridade com o deep link, que já não pergunta). «Abrir no leitor» de uma lista salva ativa-a e abre a primeira entrada da face de partituras.

### B.8 A5 — badge offline sem query por card

`offlineAvailabilityMapProvider: Provider<Map<String, PdfOfflineAvailability>>` derivado do índice offline (uma leitura por mudança do índice, invalidada por `upsert`/`remove`/`clearAll` do `OfflinePdfLocalDatasource` via um `offlineIndexRevisionProvider` incrementado nas escritas); `LouvorGroupCard` usa `select((m) => m[id] ?? notAvailable)`. O `FutureProvider.autoDispose.family` privado sai.

---

## Subprojeto C — E3 fatia 2: busca da Home pela porta

### C.0 Problema

A busca da Home é um `Notifier<int>` que muta seis `StateProvider` imperativamente, refaz a busca a cada emissão do manifest, não cancela a requisição Coldigom (só descarta a resposta), não memoiza `(query, página)`, re-busca no Coldigom quando um filtro local muda (os filtros nem são enviados), roda a varredura PLPCG normalizando o número de cada um dos ~4600 louvores por tecla (A10; `compute` é no-op na web) e grava nos quatro caches Coldigom a partir da presentation. O warmup de boot faz N chamadas seriais de até 5 s (A12). Vinte arquivos de presentation leem os caches Coldigom diretamente.

### C.1 Porta de busca

**[decisão]** `CatalogSource` ganha:

```dart
final class CatalogQuery { final String text; final CatalogFilterState filters; final int page; final int pageSize; }
final class CatalogSearchPage { final List<LouvorGroup> groups; final bool hasNextPage; final int page; static const empty; }
/// Cancelamento sem Dio no domínio.
final class SearchCancellation { void cancel(); bool get isCancelled; Future<void> get whenCancelled; }

abstract class CatalogSource {
  … (os três métodos atuais)
  /// Resultados locais, síncronos, do índice em memória. Fontes remotas devolvem `[]`.
  List<LouvorGroup> searchLocal(CatalogQuery query);
  /// Uma página remota. Fontes locais devolvem [CatalogSearchPage.empty] sem tocar a rede.
  Future<CatalogSearchPage> search(CatalogQuery query, {SearchCancellation? cancellation});
}
```

- `PlpcgCatalogSource` recebe um `PlpcgSearchIndex` construído **uma vez por manifest** (`numeroNorm` pré-computado por louvor + os campos `search*` que já existem) e roda o pipeline atual (`SearchLouvorByNumberOrText` → `FilterByMaterialAndArranjo` → `GroupLouvoresByMaterial`) de forma síncrona sobre o índice (A10 na medida do que a web permite: sem normalização por item por tecla, sem `List.of` do catálogo). `compute` sai da Home (Biblioteca fica como está).
- `ColdigomCatalogSource.search` → `ColdigomSearchRepository.search(query, page:, cancellation:)` → `listPlpcgPraises(..., cancelToken:)` (`SearchCancellation` vira `CancelToken` no data). Ao concluir, o **repositório** funde louvores/faixas/meta/YouTube nos caches (as escritas saem da presentation). Filtros locais não são enviados (a API não os aceita).
- `CompositeCatalogSource.searchLocal` = PLPCG; `search` = Coldigom.
- Providers: `plpcgCatalogSourceProvider` (observa só o manifest), `coldigomCatalogSourceProvider` (observa os caches), `catalogSourceProvider` compõe os dois — o índice PLPCG não é descartado a cada página Coldigom.

### C.2 `HomeSearchState` imutável

```dart
final class HomeSearchState {
  final String query; final int page;
  final List<LouvorGroup> localGroups;
  final AsyncValue<CatalogSearchPage> remote;   // loading | data | error
  List<LouvorGroup> get groups; bool get remoteLoading; bool get remoteFailed; bool get hasNextPage; bool get isEmptyQuery;
}
```

- `homeSearchQueryProvider` (texto cru) e `homeSearchDebouncedQueryProvider` (300 ms) ficam; `homeSearchPageProvider: Notifier<int>` volta a 1 quando a query debounced ou os filtros mudam.
- `homeLocalSearchProvider: Provider<List<LouvorGroup>>` = `plpcgCatalogSourceProvider.searchLocal(query)` — reage a manifest, query e filtros por `watch` (o manifest de fundo re-deriva; **não** re-busca no Coldigom).
- `homeRemoteSearchProvider: FutureProvider.autoDispose.family<CatalogSearchPage, HomeRemoteSearchKey(query, page)>` — cria uma `SearchCancellation`, cancela em `ref.onDispose`, `retry: (_, _) => null`, `ref.keepAlive()` só no sucesso com timer de 10 min (memo `(query, página)` sem LRU manual); query vazia → `empty` sem rede.
- `homeSearchStateProvider: Provider<HomeSearchState>` compõe os três. `retry()` = `ref.invalidate(homeRemoteSearchProvider(key))`; a Home, ao voltar a rede, invalida a página remota corrente (hoje só o manifest).
- `HomeSearchPipelineDriver`, os seis `StateProvider`, `homeSearchPipelineExecutorProvider` e `home_search_worker.dart` saem; `HomeSearchResultsSliver` e `HomeColdigomPaginationControls` leem o estado único (a aritmética de slots finais vira um `switch`).

### C.3 Caches Coldigom fora da presentation

- `catalogMaterialLookupProvider: Provider<CatalogMaterialLookup>` (feature `catalog`): facade **síncrona** — `Louvor? louvor(String materialId)`, `AudioTrack? audioTrack(String id)`, `ChordMaterial? chord(String id)`, `ColdigomPraiseMetadata? praiseMeta(String groupId)`, `List<YoutubeMaterialRef> youtube(String groupId)`, `List<AudioTrack> tracksFor(Iterable<String> ids)`. Implementada sobre `louvoresByPdfIdProvider` + os caches.
- Os 20 arquivos de presentation que leem `coldigom*CacheProvider` passam a ler o lookup; as 4 escritas (`home_search_provider`, `material_sheet`, `library_coldigom_browse_provider`, `open_chord_in_reader`) passam para os repositórios/datasources correspondentes. `group_with_coldigom_meta.dart` sai (`CatalogSource.groupById` já entrega a meta). Fora de `features/coldigom`, só `data/` importa `coldigom_providers.dart`.
- YouTube (sobra 6a): `coldigomYoutubeCacheProvider: Map<groupId, List<YoutubeMaterialRef>>` alimentado no mesmo ponto das outras fusões; `ColdigomCatalogSource` o recebe e `findGroupById` passa `youtubeMaterials`.

### C.4 Warmup (A12)

`warmupColdigomPraiseIds` roda com **concorrência 3** (pool simples sobre `Future.wait`), timeout de 5 s por id, sem serializar; `ensureColdigomPraiseMaterialsCachedProvider` reutiliza a mesma função com um id.

---

## Subprojeto D — Sobras da onda 2 e boot web

### D.1 A7 — posição do player em provider próprio

`audioPlayerPositionProvider: NotifierProvider<AudioPlayerPositionNotifier, AudioPlayerPosition{position, duration}>` alimentado por `positionStream`/`durationStream`; `AudioPlayerSessionState` perde `position`/`duration`. `CarouselChips` observa só `select((s) => s.queue.isNotEmpty)`; `CarouselAudioFaceBar` e o player observam campos com `select` e a posição pelo provider novo; `updatePosition` da media session a 1 Hz.

### D.2 A8 + A11 — boot web

- `isarStatusProvider: Provider<IsarStatus>` (`opening | available | unavailable`); `isarAvailableProvider` continua `bool` (`available`).
- `BootstrapApp` monta `ColdiguiApp` **já em `opening`**; `StorageRequiredGate` mostra «Preparando armazenamento…» enquanto `opening` (em vez de «indisponível»); `LouvoresManifestNotifier.build()` em `opening` aguarda o `isarInitializerProvider` (já com timeout de 15 s) antes de decidir cache-first — mas dispara o `GET /checksum` **imediatamente**, em paralelo, e o reaproveita.
- `PdfrxIdlePreloader` só agenda o preload do `pdfium.wasm` depois de `louvoresManifestProvider` ter valor ou erro **e** 3 s de folga; na web, respeita `navigator.connection.saveData` quando existir (`dart:js_interop`, best-effort).

### D.3 Offline

- Reconcile completo pulado também quando `entries.length < filesOnDisk.length / 2` (`ReconcileSkipReason.indexTooSmall`), reaproveitando o `listOrphans` já feito.
- `deleteOnError: false` nos dois `_dio.download` de `zip_package_downloader_native.dart` (o `.tmp` sobrevive ao stall e a retomada por Range funciona).

### D.4 Auth

Falha **transitória** do refresh silencioso (o refresher lançou) não marca a sessão como expirada: o token corrente segue em uso e o próximo request tenta de novo. Só resultado **conclusivo** (`null`, vazio, ou token idêntico sem exceção) marca `sessionExpired`. O refresh preventivo que falha transitoriamente deixa o request seguir com o token atual (o 401, se vier, tenta uma vez).

### D.5 Cifra

`_revalidate`: `fresh == null` (conclusivo, 404) → `local.write(key, '')` (marcador negativo) + `invalidateSelf()`; `fetchedAt` renovado.

### D.6 Catálogo, material, share

- `PdfExternallyDeletedException`/`PdfLocalCorruptedException` perdem a `message` em PT; `userMessageFor` e `classifyMaterialOpenFailure` mapeiam as duas para `pdfExternallyDeleted`/`pdfLocalCorrupted` (l10n).
- `MaterialSheet`: rótulos de seção aparecem quando há mais de um bloco (seções de PDF + cifra + áudio), não só quando `sections.length > 1`.
- Biblioteca (Coldigom, página ≥ 2 em erro): o paginador continua visível com a última página boa (`libraryLastGoodResultsProvider`), o banner de erro fica.
- `parsePlaylistShareParams` distingue «não é share» (`null`) de «share sem materiais» (`PlaylistShareParams` com `entries` vazio) → `ImportSharedPlaylistFromUrl` lança `InvalidSharePlaylistException` → snackbar `playlistImportInvalidUrl` (deep link e colar URL).

### D.7 Código morto e ciclos

- Saem: `force_refresh_catalog.dart` + `forceRefreshCatalogProvider` + teste; chaves ARB `catalogRefresh*` (5) e `pdfMaterialSection`; `resolveCatalogMaterial(Ref)` (fica a variante `WidgetRef`).
- Ciclos: `classifyMaterialOpenFailure` vai para `lib/features/catalog/presentation/providers/material_open_failure.dart` (importado por `user_message_for.dart` e `open_material_provider.dart`); o opener padrão de PDF sai de `open_material_provider.dart` para `open_material_defaults.dart` (importado por quem monta o provider), quebrando `open_louvor_in_reader ↔ open_material_provider`.
- Comentário de `dio_provider.dart` descreve também o refresh preventivo.

---

## Ordem de execução e paralelismo

- **Fase 1 (paralela, arquivos disjuntos):** T1 Worker (A.1 servidor, A.2 servidor, A.7); T2 cliente social DTO/datasource (A.1); T3 `SyncPlaylists` tombstones + cópia de conflito (A.2, A.3); T4 `ownerSub` + provider de listas (A.5, A.6); T5 marcadores de áudio (A.4 + A.2/A.5 deles); T6 D3 núcleo (B.1–B.3, B.8 não); T7 porta de busca + fontes + lookup + warmup (C.1, C.3 facade, C.4); T8 sobras offline/auth/cifra/PT/share (D.3–D.6 parte); T9 A7; T10 boot (D.2); T11 código morto e ciclos + seção/paginador (D.6 parte, D.7).
- **Fase 2 (após T6 e T7):** T12 widgets do carousel + rename (B.2 consumidores, B.4); T13 leitor (B.5); T14 D4 + D6 + import social/share por entradas (B.6, B.7, A.1 cliente); T15 Home (C.2).
- **Fase 3:** T16 leituras restantes pelo lookup (C.3) + badge offline (B.8); revisão final da branch; onda única de correções; doc + artifact.

## Fora de escopo (próxima onda)

D5 mini-player persistente e independente da face; D7 encurtador de link; C4–C16 (UX de culto); A6, A9, A13–A16; E4–E8, E10–E13; remoção de `CarouselEntry` do schema; `SyncRunner` genérico; UI de escolha na troca de conta.

## Riscos aceitos

- **Troca de conta apaga localmente as listas sincronizadas da conta anterior** (A.5) — recuperáveis pelo login dela. Mitigação: só `synced`; pendentes ficam.
- **Tombstones sem poda** (A.2): o `includeDeleted=1` cresce com o histórico; volume por usuário é pequeno (dezenas). Poda por idade fica para depois.
- **Chave por ocorrência** (B.1): duas ocorrências iguais trocadas de lugar são indistinguíveis — por construção não faz diferença.
- **Migração única do carousel** (B.3): se o Isar abrir degradado no boot da migração, ela roda no próximo boot com storage (a coleção continua lá).
- **`keepAlive` de 10 min por página remota** (C.2): memória limitada a poucas páginas de 20 grupos.

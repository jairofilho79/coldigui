# Offline Coldigom — catálogo local, download por tipos favoritos e pesquisa híbrida

**Data:** 2026-09-14
**Estado:** aprovado em brainstorm (abordagem C1 + endpoint novo no coldigom-api + letra com leitor simples + deslogado convida a entrar + lista única com linha de estado); spec para revisão
**Escopo:** três entregas em sequência num único branch:
- **B. Catálogo Coldigom local** — o catálogo inteiro (1690 louvores, metadados, letra e lista de materiais) fica em Isar, sincronizado por ETag. Metadados e lista de materiais aparecem **sempre**, online ou offline.
- **C. Download de materiais Coldigom** — no `/offline`, secção para baixar PDFs, áudios, cifras e gestos filtrados pelos `material_kinds` favoritos (com outros tipos sugeridos discretamente). Offline, o que não foi baixado aparece **desabilitado** no sheet.
- **D. Pesquisa híbrida** — resultados locais na hora (PLPCG + Coldigom), validação online em segundo plano com linha «Em cache» → «Atualizado».

**Pré-requisito de produto (não de código):** `2026-09-14-pwa-shell-offline-design.md` — sem shell offline, na web nada disto é alcançável sem rede. No nativo não há dependência.
**Repos:** `coldigui` (Flutter) + patch para o Worker `coldigom-api` (fora do repo; guardado em `patches/`).

## 1. Estado atual (factual)

- Offline existente = **só PDFs do PLPCG**: `OfflinePdfIndex` (Isar) + `PdfStoragePort` (ficheiros no nativo, Cache API na web), bulk por categoria, LRU 500 MB, `isPersistent`, "baixar faltantes", `offlineMaintenanceLockProvider`.
- PDFs Coldigom abertos on-demand **já** caem em `OfflinePdfIndex` via `ResolvePdfForReader` (`pdfId = encodePdfId(r2Key)`), só que como LRU (`isPersistent = false`).
- Cifras (`ChordContentCache`) e gestos (`GestureDocumentCache` + `GestureFigureStore`) já persistem em Isar/Cache API sem eviction; só são preenchidos quando o utilizador abre.
- Áudio: nada persistido (web: 2 blob URLs em memória; nativo: streaming).
- Coldigom: metadados só em memória, página a página (`GET /api/plpcg/praises?q=&page=&limit=20`); `ColdigomCatalogSource.searchLocal` devolve `[]`; a Home mostra "Coldigom offline" no empty state.
- `type: 'lyrics'` chega como material sintético e é ignorado (`MaterialKind.unknown`).
- Favoritos: `MaterialKindPrefs { kindIds (≤5), preferredTypeByKind }` só logado.

## 2. Decisões

| # | Decisão |
|---|---|
| O1 | **Endpoint novo `GET /api/plpcg/catalog` no coldigom-api** — dump compacto do catálogo com `ETag` + `If-None-Match → 304`. Patch em `patches/coldigom-api-plpcg-catalog.patch`; deploy é passo do dono. |
| O2 | **`r2Key` derivado, não transmitido**: os materiais seguem `assets/praises/<praiseId>/<materialId>.<ext>` (verificado em produção). O dump manda `{id, kind, type}` e o app reconstrói o `r2Key`. YouTube manda `url`. |
| O3 | Catálogo Coldigom em Isar: collection `ColdigomPraiseCache` (uma linha por louvor, materiais serializados em JSON na própria linha). Substituição total por sync (uma transação), como `LouvorCache`. |
| O4 | Os caches em memória atuais (`coldigomLouvoresCacheProvider` etc.) passam a ser **hidratados do Isar no boot**; `ColdigomCacheWriter` continua a ser o único escritor, agora também alimentado pelo sync. Nada muda para quem lê (`groupById`, `materialById`, sheet, playlists). |
| O5 | **Sync:** no boot com rede (paralelo ao do PLPCG, não bloqueia nada), no foreground se passaram ≥ 30 min (`OfflineConfig.catalogChecksumMinInterval` já existe), e após a pesquisa detetar louvor desconhecido (§6). Sem rede → fica o que está. |
| O6 | **Letra** = material `MaterialKind.lyrics` sintético (`id = 'lyrics:<praiseId>'`), texto no dump, sempre offline, sem download. Abre em `/letra?praiseId=`. Não tem `material_kind`, logo não entra nos favoritos nem nas contagens de download. |
| O7 | **Storage por tipo (C1):** PDF → `OfflinePdfIndex` + `PdfStoragePort` com `isPersistent = true`; áudio → **novo** `OfflineAudioIndex` + `AudioStoragePort` (mesmos dois gémeos nativo/web); cifra → `ChordContentCache`; gestos → `GestureDocumentCache` + `GestureFigureStore`. Sem índice unificado, sem migração dos índices existentes. |
| O8 | Cifra e gestos **não ganham `isPersistent`**: já não são evictados e pesam 0,6–8 KB. «Remover baixados do Coldigom» apaga áudio e PDFs Coldigom persistentes; cifras/gestos ficam (documentado na UI como "textos ficam sempre"). |
| O9 | **Download só para logado.** Deslogado vê na secção Coldigom um card «Entre com Google para baixar os seus tipos favoritos» + `GoogleSignInButton` (igual à tela de favoritos, D10). |
| O10 | **Sugestão:** os kinds favoritos (`kindIds`, na ordem) aparecem **pré-marcados** no topo; abaixo, um expansor fechado «Outros tipos» com os restantes kinds (ordem alfabética), desmarcados. Só kinds com pelo menos um material baixável (`pdf|mp3|audio|chord|gestures`) aparecem; YouTube nunca. |
| O11 | A seleção do download é **local** (`offlineColdigomKindIds` em prefs), independente dos favoritos: mudar favoritos não altera o que já foi marcado/baixado; a pré-marcação só se aplica a kinds nunca decididos. |
| O12 | Download **idempotente e retomável por construção**: o use case enumera do catálogo local, salta o que já está no índice/cache, e pode ser parado e retomado sem checkpoint próprio. Progresso = `feitos/total` por kind. Usa o `offlineMaintenanceLockProvider` e `wakelock_plus` como o bulk PLPCG. |
| O13 | Estimativa de tamanho: o dump inclui `size` (bytes) por material quando o coldigom o conhece; sem `size`, o app usa médias por tipo (`pdf` 350 KB, `mp3` 4 MB, `chord` 1 KB, `gestures` 60 KB com figuras) e mostra `~`. Antes de iniciar, compara com `StorageQuotaEstimator` e avisa (sem bloquear) se o estimado ultrapassa o livre. |
| O14 | **Desabilitado no sheet:** com `connectivityStreamProvider == false`, tile de material não disponível localmente fica `enabled: false` com subtítulo «Não baixado · sem ligação»; YouTube «Precisa de ligação»; letra nunca desabilita. `+`/`×` de playlist continuam ativos (só ids). Online, nada muda. |
| O15 | **Pesquisa:** lista única, 100 % local (PLPCG + Coldigom). O remoto (`homeRemoteSearchProvider`, página 1) passa a **validar**: mesma lista → «Atualizado»; louvores que o local não tinha → anexados no fim com marca «novo», gravados no Isar e dispara sync. A paginação Coldigom da Home é removida. |
| O16 | Ordem na lista: PLPCG primeiro, Coldigom depois (como hoje: local + remoto); dentro de cada fonte, o ranking existente (número exato → título exato → parcial). Filtros UC-02 continuam a aplicar-se só ao PLPCG. |

## 3. Backend — coldigom-api (patch)

`GET /api/plpcg/catalog` (público, CORS igual a `/api/plpcg/praises`):

```json
{
  "generatedAt": "2026-09-14T12:00:00Z",
  "kinds": [{ "id": "a19e…", "name": "Grade" }],
  "praises": [
    {
      "id": "2cfe…", "number": "001", "name": "Ainda há tempo",
      "author": "", "rhythm": "Básico", "tonality": "Dm", "category": "Dm",
      "tags": ["Avulsos", "PES"],
      "lyrics": "…texto…",                         // omitido se vazio
      "materials": [
        { "id": "0866…", "kind": "a19e…", "type": "pdf", "size": 312345 },
        { "id": "390c…", "kind": "8860…", "type": "mp3" },
        { "id": "yt1…",  "kind": null,    "type": "youtube", "url": "https://…" }
      ]
    }
  ]
}
```

- `ETag` = SHA-256 (hex curto) do corpo; `If-None-Match` igual → `304` sem corpo. `Cache-Control: public, max-age=300`.
- `size` opcional: preenchido se a tabela de materiais tiver o tamanho; senão omitido (o app estima, O13). Não fazer `HEAD` ao R2 por material na geração.
- Ordenação estável por `number` e depois `name` (facilita diff e ETag estável).
- Testes (`vitest`, como no patch anterior): corpo mínimo, `304` com ETag, `lyrics` omitida quando vazia, YouTube com `url`, materiais sem `r2_key`.
- Tamanho esperado: ~1,5 MB sem letra, ~2,5 MB com letra; gzip pela Cloudflare → ~400–600 KB.

Cliente: `ColdigomEndpoints.plpcgCatalog = '/api/plpcg/catalog'`; `ColdigomRemoteDatasource.fetchCatalog({String? ifNoneMatch})` → `ColdigomCatalogDto?` (`null` em 304) + `etag`. Dio do `coldigomDioProvider` (retry já existe), `receiveTimeout` 60 s para este pedido.

## 4. App — B. Catálogo Coldigom local

### 4.1 Isar

```dart
@Collection()
class ColdigomPraiseCache {
  int id = 0;
  @Index(unique: true) late String praiseId;
  late String number;        // '001'
  late String name;
  late String author;
  late String rhythm;
  late String tonality;
  late String category;
  late List<String> tags;
  late String lyrics;        // '' quando não há
  late String materialsJson; // JSON array de {id,kind,type,size?,url?}
  late String searchTokens;  // tokens normalizados (nome + número + tags + autor), separados por espaço
}
```

`kAppIsarSchemas` += `ColdigomPraiseCacheSchema`. Metadados do sync em SharedPreferences: `coldigomCatalogEtag`, `coldigomCatalogSyncedAt`, `coldigomCatalogCount` (`StorageKeys`).

### 4.2 Camadas (`lib/features/coldigom/`)

- `data/datasources/coldigom_catalog_local_datasource.dart` — `replaceAll(List<ColdigomPraiseCache>)` numa transação; `findAllSync()`; `upsertMany(...)` (para os «novos» da pesquisa, §6); `count()`. `null` de Isar → `StorageUnavailableException` como os outros datasources.
- `data/models/coldigom_catalog_dto.dart` — parse tolerante; `materials[].r2Key` derivado: `assets/praises/$praiseId/$materialId.$ext` com `ext` por `type` (`pdf→pdf`, `mp3|audio→mp3`, `chord→chord`, `gestures→gestures`); `youtube` usa `url`.
- `domain/usecases/sync_coldigom_catalog.dart` — `run()`: lê etag local → `fetchCatalog(ifNoneMatch)` → `304` → `noop`; `200` → converte e `replaceAll` → grava etag/`syncedAt` → `ColdigomCatalogSyncResult { replaced, noop, failed(cause) }`. Nunca lança para o chamador (best-effort), mas expõe `cause` para a UI do `/offline`.
- `presentation/providers/coldigom_catalog_providers.dart` — `coldigomCatalogSyncProvider` (Notifier: `sync()` deduplicado in-flight; gatilhos O5) e `coldigomCatalogHydrationProvider` (FutureProvider `keepAlive`: lê o Isar uma vez no boot, converte com `ColdigomLouvorAdapter` e entrega ao `ColdigomCacheWriter`; após um sync que substituiu, `ref.invalidate` e re-hidrata). A hidratação corre depois do Isar abrir; a Home não espera por ela (aparece o PLPCG primeiro, como hoje).
- `ColdigomCatalogSource.searchLocal(query)` — usa `ColdigomSearchIndex` (novo, `domain/search/`), construído uma vez por hidratação a partir dos `searchTokens`/`number` (espelho de `PlpcgSearchIndex`, mesmo ranking via `SearchLouvorByNumberOrText.callIndexed`). Devolve `List<LouvorGroup>` (um por praise, com todos os materiais, letra incluída).
- `CompositeCatalogSource.searchLocal` — concatena PLPCG + Coldigom (O16).
- **Custo em memória:** ~1690 praises × ~12 materiais ≈ 20 k entidades pequenas; o PLPCG já mantém 4633 `Louvor`. Medir no boot web (`web_perf_baseline.json`) e no plano fixar um limite (< 150 ms de hidratação no iPhone).

### 4.3 Letra

- `MaterialKind.lyrics` em `material_id_kind.dart`; `materialKindOfRawType('lyrics') → lyrics`; `materialIdKindOf` reconhece o prefixo `lyrics:`.
- `LyricsMaterial extends CatalogMaterial { praiseId, groupId, title, text }` em `catalog_material.dart`; adapter `toLyricsMaterial(praise)` quando `lyrics` não é vazia; entra em `LouvorGroup.extras`.
- `OpenMaterial.open`: `LyricsMaterial → context.push('/letra?praiseId=…')`. Rota `RoutePaths.lyrics = '/letra'` no branch do catálogo, sem `DeferredRouteLoader`.
- `LyricsReaderScreen` (`lib/features/lyrics/presentation/pages/`): `AppBar` com título do louvor, corpo `SelectableText` em `SingleChildScrollView`, tamanho da fonte com os mesmos controles/preferência do leitor de cifras se forem reutilizáveis sem alterar o leitor de cifras; senão, dois botões A−/A+ com preferência `lyricsFontScale` em prefs. Texto lido de `ColdigomPraiseCache` (nunca da rede).
- Sheet: aba «Letra» (`MaterialKind.lyrics`) quando existe; tile único; não adicionável a playlist nesta entrega.

## 5. App — C. Download de materiais Coldigom

### 5.1 Áudio persistente (novo)

- `OfflineAudioIndex` (Isar): `audioId` (unique, = `encodePdfId(r2Key)` como `AudioTrack.audioId`), `r2Key`, `storageKey`, `fileSize`, `downloadedAt`. Sempre persistente (não há LRU de áudio).
- `AudioStoragePort` (`lib/features/offline/domain/ports/`): `writeAtomic(bytes, relPath) → storageKey`, `exists`, `readBytes`, `delete`, `deleteTree`, `getTotalBytes`. Implementações: `audio_storage_native.dart` (documents dir `plpcg_audio/`, escrita `.tmp` + rename) e `audio_storage_web.dart` (Cache API bucket `plpcg-audio-store-v1`, origem lógica `https://plpcg-offline.local/plpcg_audio/`), copiando o padrão de `pdf_storage_*` incluindo a classificação de quota → `InsufficientDiskSpaceException`.
- `OfflineAudioRepository` (`lookup(audioId) → LocalAudioSource?`, `upsert`, `remove`, `listAll`, `totalBytes`, `removeAll`).
- **Reprodução:** `AudioPlayerSession._playbackUriForTrack` consulta o repositório primeiro: nativo → `Uri.file(path)`; web → bytes da Cache API → blob URL pelo `WebAudioSourceResolver` já existente (ganha `resolveFromBytes(key, bytes)`; o limite `maxBlobBytes` 20 MB mantém-se). Miss → fluxo atual (rede). Sem rede e sem local → o erro atual do player com mensagem «Este áudio não foi baixado» (l10n) em vez de erro de rede genérico.
- Fetch de bytes: `AudioBytesDatasource` (Dio do `dioProvider` na web via proxy `ColdigomAssetUrl.fetchUrlForKey`; direto no nativo), `receiveTimeout` 120 s (`OfflineConfig.pdfDownloadReceiveTimeout`), retry pelo `download_retry.dart`, `RetryInterceptor.disableKey` como o PDF.

### 5.2 Use case `DownloadColdigomMaterials`

Entrada: `Set<String> kindIds`, `CancelToken`, `onProgress(ColdigomDownloadProgress)`.

1. Lê `ColdigomPraiseCache` (`findAllSync`) → lista de alvos `(praiseId, materialId, kind, type, r2Key, size?)` com `kind ∈ kindIds` e `type` baixável. Ordena por `number` (o utilizador vê progresso "em ordem").
2. Consulta presença em lote: `OfflinePdfRepository.lookupBatch` (só conta `isPersistent`; LRU existente é promovido a persistente sem novo download — `markPersistent(pdfIds)`), `OfflineAudioRepository.lookupBatch`, chaves de `ChordContentLocalDatasource`/`GestureContentLocalDatasource`. Alvos presentes → `skipped`.
3. Fila com concorrência `OfflineConfig.coldigomDownloadConcurrency` (3 nativo, 6 web), por tipo:
   - `pdf` → `FetchAndStorePdf(pdfId, remotePath: '/$r2Key', persistentDownload: true)` (mesmo caminho do on-demand Coldigom).
   - `mp3` → `AudioBytesDatasource.fetch(r2Key)` → `AudioStoragePort.writeAtomic` → `OfflineAudioRepository.upsert`.
   - `chord` → `ChordContentDatasource.fetchContent` → `ChordContentLocalDatasource.write` (404 → marcador negativo, conta como feito).
   - `gestures` → `GestureContentDatasource` → `GestureContentLocalDatasource.write` → parse (`parseGestureDocument`) → `GestureFigureRepository.prefetch(figureKeys)`.
4. Falha individual → regista em `failures` e segue (como `DownloadMissingPdfs`); `InsufficientDiskSpaceException` ou cancelamento → para tudo e devolve o parcial.
5. Resultado `ColdigomDownloadResult { done, skipped, failed: List<(materialId, cause)>, bytes }`. Progresso a cada item: `{kindId, doneInKind, totalInKind, doneTotal, total, currentTitle}`.

Provider `offlineColdigomDownloadProvider` (Notifier com `start(kindIds)`, `stop()`, estado `idle|running(progress)|done(result)|failed(cause)`), adquire `offlineMaintenanceLockProvider` (o bulk PLPCG e este são mutuamente exclusivos), `WakelockPlus.enable()` durante a execução, pausa ao ir para background como o bulk (`offline_lifecycle_listener.dart`).

`RemoveColdigomDownloads`: apaga `OfflineAudioIndex` + store de áudio; PDFs Coldigom (`isColdigomPdfId`) com `isPersistent = true` → `remove`. Cifras/gestos ficam (O8).

### 5.3 Estatísticas e disponibilidade

- `offlineColdigomStatsProvider` — por kind: `{total, downloaded, bytesKnown, bytesEstimated}` calculado a partir do catálogo + índices (sync, com `offlineIndexRevisionProvider` + revisão nova do índice de áudio + revisões dos caches de cifra/gestos). Computação em chunks com `await Future.delayed(Duration.zero)` a cada 300 praises em todas as plataformas, nativo incluído (evitar jank — o mesmo padrão do `library_group_worker`; sem `compute` porque linhas Isar não atravessam isolates sem re-marshalling).
- `materialAvailabilityMapProvider` — `Map<String materialId, PdfOfflineAvailability>` unindo: `offlineAvailabilityMapProvider` (PDF), índice de áudio (`persistentOffline`), chaves de cifra/gestos com conteúdo não vazio (`persistentOffline`). Letra e YouTube não entram (regras fixas no sheet, O14).

### 5.4 Ecrã `/offline`

`OfflineSettingsScreen` passa a ter duas secções com cabeçalho:

1. **Acervo PLPCG (PDFs)** — tudo o que existe hoje, inalterado.
2. **Coldigom por tipo de material**
   - Linha de estado do catálogo: «Catálogo: 1690 louvores · atualizado há 2 h» + botão «Atualizar» (`coldigomCatalogSyncProvider.sync()`); sem catálogo local ainda → «Ligue-se à internet para baixar o catálogo».
   - Deslogado → card + `GoogleSignInButton` (O9). Logado:
   - **Seus tipos favoritos** — `CheckboxListTile` por kind favorito, na ordem do rank: nome, «N materiais · ~X MB», barra fina `downloaded/total`. Pré-marcados (O11).
   - **Outros tipos** — `ExpansionTile` fechada; mesma linha por kind, desmarcados.
   - Rodapé fixo: «Baixar selecionados (~X MB)» / «Parar» durante a execução; progresso «Tipo · 120/1690 · Nome do louvor»; resultado com falhas → «N não baixados · Tentar de novo» (re-executa; idempotente). Aviso de espaço (O13) em `SnackBar` antes de iniciar.
   - Link discreto «Remover áudios e PDFs baixados do Coldigom» (confirmação em diálogo; nota «cifras, gestos e letras ficam»).
   - Todos os botões respeitam o `offlineMaintenanceLockProvider` (desabilitados durante bulk/reconcile/limpeza).

### 5.5 Sheet de materiais (`MaterialSheet`)

- `final online = ref.watch(connectivityStreamProvider).value ?? true;` e `final availability = ref.watch(materialAvailabilityMapProvider);`.
- `_materialTile` ganha `enabled` + `subtitle` opcional; regras O14. `+`/`×` mantêm-se ativos.
- Cabeçalho do sheet, quando offline: linha «Sem ligação · só o que está no aparelho abre» (uma vez, em cima das abas).
- Cards do catálogo (`louvor_group_card.dart`): o badge de disponibilidade existente passa a considerar o grupo «disponível» se **algum** material do grupo está em `materialAvailabilityMapProvider` (hoje só PDF).
- Home: o aviso «Coldigom offline» do empty state passa a aparecer só quando **não há catálogo Coldigom local** e não há rede.

## 6. App — D. Pesquisa híbrida

### 6.1 Estado

```dart
enum SearchFreshness { checking, updated, updatedWithNew, offline, failed }

class HomeSearchState {
  final List<LouvorGroup> groups;      // local (PLPCG + Coldigom) + novos no fim
  final Set<String> newGroupIds;       // vindos só do remoto nesta consulta
  final SearchFreshness freshness;
  final int newCount;
}
```

### 6.2 Pipeline (`home_search_provider.dart`)

1. `homeLocalSearchProvider` — `CompositeCatalogSource.searchLocal` (PLPCG + Coldigom), síncrono, imediato. Query vazia → estado atual (carrossel/vazio).
2. `homeRemoteSearchProvider((query, page: 1))` — mantém debounce 300 ms, cancelamento e memo; sem rede (`connectivityStreamProvider == false`) nem tenta → `freshness = offline`.
3. `homeSearchStateProvider` combina: `groups = local`; `freshness = checking` enquanto o remoto carrega. Remoto resolvido: `remoteIds = page.groups.map(id)`; `missing = remoteIds − localIds` → se vazio → `updated`; senão → `updatedWithNew(newCount)`, `groups = local + missing (ordem remota)`, `newGroupIds = missing`, e efeito colateral: `ColdigomCatalogLocalDatasource.upsertMany(missing)` + `ColdigomCacheWriter` + `coldigomCatalogSyncProvider.sync()` (o ETag mudou, o dump inteiro vem a seguir). Erro → `failed` (lista local intacta).
4. Remoto que devolve **menos** do que o local (louvor apagado no servidor) não remove nada na hora: o sync O5 substituirá o catálogo.
5. `home_coldigom_pagination_controls.dart` e o `page` variável na Home são removidos; `homeRemoteSearchProvider` fica com `page` fixo em 1 (a família mantém a assinatura para não tocar em testes que a usam).

### 6.3 UI

- `SearchFreshnessLine` (novo widget, `home_search_results_sliver.dart` insere no topo quando a query não é vazia): ícone + texto pequeno em `bodySmall`/`onSurfaceVariant`:
  - `checking` → `○ Em cache · a verificar…`
  - `updated` → `✓ Atualizado`
  - `updatedWithNew` → `✓ Atualizado · N novos`
  - `offline` → `○ Em cache · sem ligação`
  - `failed` → `○ Em cache · não foi possível verificar`
- Cards em `newGroupIds` mostram um chip «novo» no canto (mesmo estilo do badge offline). Sem animação de reordenação: novos entram só no fim.
- A linha some quando a query é limpa.

## 7. l10n (pt / en)

`offlineColdigomSection`, `offlineColdigomCatalogStatus(count, ago)`, `offlineColdigomCatalogMissing`, `offlineColdigomSignInPrompt`, `offlineColdigomFavoriteKinds`, `offlineColdigomOtherKinds`, `offlineColdigomKindSummary(count, size)`, `offlineColdigomDownloadSelected(size)`, `offlineColdigomStop`, `offlineColdigomProgress(kind, done, total)`, `offlineColdigomFailures(count)`, `offlineColdigomRetry`, `offlineColdigomRemove`, `offlineColdigomRemoveNote`, `offlineColdigomSpaceWarning(size, free)`, `materialNotDownloadedOffline`, `materialNeedsConnection`, `materialSheetOfflineBanner`, `lyricsTitle`, `lyricsTab`, `audioNotDownloaded`, `searchFreshnessChecking`, `searchFreshnessUpdated`, `searchFreshnessUpdatedNew(count)`, `searchFreshnessOffline`, `searchFreshnessFailed`, `searchResultNew`.

## 8. Testes

**Worker (patch):** ver §3.

**Unit** (`test/unit/features/coldigom/`, `.../offline/`, `.../catalog/`):
- `coldigom_catalog_dto_test.dart` — parse; `r2Key` derivado por tipo; YouTube com `url`; `lyrics` ausente → `''`; `size` opcional.
- `sync_coldigom_catalog_test.dart` — 304 → noop; 200 → `replaceAll` + etag; falha de rede → `failed` sem tocar no Isar.
- `coldigom_search_index_test.dart` — número exato, título exato, parcial sem acento; tags; ordenação estável.
- `composite_catalog_source_test.dart` (existente) — `searchLocal` concatena PLPCG + Coldigom.
- `lyrics_material_test.dart` — adapter só cria letra quando há texto; `materialIdKindOf('lyrics:…') == lyrics`.
- `offline_audio_repository_test.dart` — upsert/lookup/remove; `totalBytes`.
- `audio_storage_web_test.dart` / `_native_test.dart` — escrita atómica, quota → `InsufficientDiskSpaceException` (fakes como os de `pdf_storage_*`).
- `download_coldigom_materials_test.dart` — filtra por kind e tipo baixável; salta presentes; promove LRU a persistente sem download; cifra 404 conta como feito; gestos prefetch figuras; falha individual não para; quota para tudo; cancelamento devolve parcial; concorrência limitada.
- `remove_coldigom_downloads_test.dart` — remove áudio e PDFs Coldigom persistentes; não toca em PLPCG nem em cifras.
- `offline_coldigom_stats_test.dart` — contagens e estimativas com/sem `size`.
- `material_availability_map_provider_test.dart` — união das quatro fontes.
- `home_search_state_test.dart` — local imediato; remoto igual → `updated`; remoto com extra → `updatedWithNew`, extra no fim, upsert chamado, sync disparado; erro → `failed`; sem rede → `offline` sem chamar o remoto.
- `audio_player_session_test.dart` (existente) — faixa com áudio local usa `Uri.file`/blob local; miss usa rede.

**Widget:**
- `offline_settings_screen_coldigom_test.dart` — deslogado mostra convite; logado mostra favoritos pré-marcados e «Outros tipos» fechado; botão desabilitado com lock; progresso; remover pede confirmação.
- `material_sheet_offline_test.dart` — offline: tile sem download desabilitado com subtítulo; YouTube desabilitado; letra ativa; `+` ativo; online: tudo ativo.
- `lyrics_reader_screen_test.dart` — mostra texto; A−/A+.
- `home_search_freshness_test.dart` — os cinco estados da linha; chip «novo».

**Manual:** web dev com Worker local (`patches/` aplicado no coldigom local ou apontando a `COLDIGOM_API_BASE_URL` de preview); iPhone real: baixar 2 kinds, modo de avião, abrir PDF/áudio/cifra/gestos/letra, pesquisar, ver linha «Em cache · sem ligação»; voltar online e ver «Atualizado».

## 9. Fora do escopo

- Download de materiais do acervo PLPCG por kind (continua por categoria).
- Favoritos para PLPCG.
- Sincronizar a seleção de download entre aparelhos.
- Background download (iOS suspende; o utilizador mantém o app aberto, como no bulk).
- LRU/quota para áudio (só remoção manual).
- Adicionar letra a playlists; pesquisar dentro da letra (os `searchTokens` não incluem a letra nesta entrega).
- Remover da Home os louvores apagados no servidor em tempo real (só no sync).

## 10. Riscos

| Risco | Mitigação |
|---|---|
| Catálogo de 1690 praises pesa no boot web | Hidratação fora do caminho crítico; índice construído uma vez; medir e fixar limite no plano. |
| Áudio: 1 kind «Playback» ≈ 1690 × 4 MB ≈ 6–7 GB | Estimativa visível antes de iniciar + aviso de espaço; Safari pode negar — `InsufficientDiskSpaceException` para o download limpo com o parcial guardado. |
| `r2Key` derivado deixa de valer | Teste de contrato no patch do Worker (`r2_key` gerado == padrão); se um dia falhar, o dump passa a mandar `r2` explícito (campo opcional já previsto no parser). |
| Sheet «desabilitado» com deteção de rede errada (`connectivity_plus` diz online mas não há internet) | Tile fica ativo e o erro de abertura já existente aparece; o desabilitado é só conforto, nunca bloqueio de segurança. |
| Dois escritores no Isar (sync total vs upsert da pesquisa) | Ambos passam por `ColdigomCatalogLocalDatasource`; `replaceAll` é uma transação e vence sempre (é o estado do servidor). |
| Coldigom offline em produção (Worker fora do ar) | O catálogo local continua a servir; `SearchFreshness.failed`. |

## 11. Entrega

- Branch `feat/offline-coldigom`, worktree `.claude/worktrees/offline-coldigom`, a partir de `web/integration`. Ordem no plano: **B → C → D**, cada uma mergeável sozinha (B já traz valor: metadados offline + pesquisa local).
- Passos do dono: aplicar `patches/coldigom-api-plpcg-catalog.patch` no repo do coldigom e fazer deploy **antes** de publicar a web com B; deploy Pages depois.
- Docs a atualizar no final: `docs/use-cases/UC-01` (busca), `UC-09`/`UC-10` (offline), `docs/features/FEATURE_INDEX.md`, `workers/plpcg-catalog/README.md` (nada muda, mas referenciar o endpoint do coldigom).

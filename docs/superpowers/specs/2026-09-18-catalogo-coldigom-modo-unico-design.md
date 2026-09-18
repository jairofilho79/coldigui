# Catálogo PLPCG servido pelo coldigom — fim do modo dual

**Data:** 2026-09-18
**Estado:** desenho aprovado; implementação por fazer.
**Escopo:** o app `coldigui` deixa de depender do site `plpcg.com` para catálogo, PDFs e pacotes offline. O manifest e o checksum passam a vir do Worker `coldigom-api`; o PDF é aberto pela URL absoluta que o manifest traz; PLPCG e Coldigom deixam de ser dois acervos separados e passam a ser **um louvor por praise**, com os ids legados (`pdfId`, `shortId`) preservados. A primeira configuração offline deixa de usar ZIPs.
**Fora do escopo (follow-ups em §11):** gates «Lista ao Vivo só Coldigom» e «share só PLPCG puro»; áudio/cifra/gestos pelo proxy; qualquer mudança no coldigom ou no Worker `plpcg-catalog`.

**Repos:** `coldigui` (Flutter + Worker `plpcg-catalog`). O coldigom (`https://coldigom-api.jairofilho79.workers.dev`) **não muda**.

## 1. Contexto e factos medidos (2026-09-18)

| # | Facto | Consequência |
|---|---|---|
| F1 | `GET /api/plpcg/manifest` no coldigom devolve 4429 entradas no shape do manifest (`nome, classificacao, numero, categoria, pdf, pdfId, groupId, shortId`) + `praiseId`, `materialId`. `pdfId`/`groupId`/`shortId` são os originais do PLPCG; `pdf` é URL **absoluta** no coldigom. `ETag: "<sha256>"`, `Cache-Control: public, max-age=300`, `access-control-expose-headers: ETag`. `/api/plpcg/manifest/checksum` devolve o mesmo hex; `If-None-Match` → 204. | Mesmo contrato do `/api/catalog/*` do Worker `plpcg-catalog`: o poll UC-12 e o repositório só trocam de URL. |
| F2 | O coldigom tem 2063 praises, 12 044 PDFs, 6653 áudios, 2271 cifras, 1396 letras, 410 YouTube, 254 gestos (paginação completa de `/api/plpcg/praises`). O manifest cobre 4427 `materialId` distintos de **1847 praises**; 216 praises são só-coldigom; **1639 praises têm materiais além do manifest**; só 424 são 100 % cobertos. | Dedupe por material não basta — a duplicação que o utilizador vê é por **louvor**. A fusão tem de ser por praise. |
| F3 | `groupId ↔ praiseId` não é 1:1: 82 grupos fuzzy do script Python juntam 2 praises; 64 praises estão em 2 grupos. | Ao chavear por `praiseId`, 82 cards dividem-se e 64 fundem-se. Aceite: passa a valer a identidade do coldigom, que áudio/cifra/letra já usam. |
| F4 | Nenhum `pdfId` do manifest decodifica para `assets/praises/…`; 36 começam por `assets/` (ex.: `assets/PES/…`). Dois `materialId` aparecem em duas entradas (dois `pdfId` legados para o mesmo ficheiro). | `isColdigomPdfId`/`louvorDataSourceFromPdfId` continuam corretos. O alias `materialId → Louvor` fica com a primeira ocorrência; as duas continuam a abrir. |
| F5 | Prod (`v2.plpcg.com`) serve COOP `same-origin` + COEP `require-corp` (commit 1239434d). O coldigom responde aos PDFs com `access-control-allow-origin: https://v2.plpcg.com`, `cross-origin-resource-policy: cross-origin` e `content-type: application/pdf`. Os PDFs Coldigom já vão direto hoje (`AssetBaseUrlResolver` → `ColdigomApiConfig.baseUrl`). | Ir direto ao coldigom é seguro no web. O proxy `/api/coldigom/*` não é necessário para PDFs (§3.4). |
| F6 | `GET /api/plpcg/catalog` devolve 404 em prod (o patch `patches/coldigom-api-plpcg-catalog.patch` nunca foi aplicado). | O índice local Coldigom está vazio em prod; só cresce por adoção dos «novos» da busca remota. A fusão não pode depender desse endpoint. |
| F7 | `Louvor.pdf` é persistido no Isar (`LouvorCache.pdf`) mas nunca usado para URL. `OfflinePdfIndex` é chaveado por `pdfId`. | O campo já existe para receber a URL absoluta; o cache de PDFs baixados sobrevive sem migração. |
| F8 | `/offline-manifest.json` + `/packages/*.zip` são estáticos do Pages `plpcg.com` (gerados em 2026-07-25) e só servem a **primeira** configuração offline (UC-09). O UC-10 «baixar faltantes» já baixa PDF a PDF. | Com o site desligado, o ZIP morre. Decisão: trocar já para PDF a PDF e apagar o pipeline (§6). |
| F9 | `scripts/test_all.sh` injeta `dart_defines/plpcjf.json` (que já tem `COLDIGOM_API_BASE_URL`). | O `defaultValue` hard-coded de `ColdigomApiConfig.baseUrl` pode sair. |

## 2. Decisões

| # | Decisão |
|---|---|
| D1 | **Fonte do catálogo:** `COLDIGOM_API_BASE_URL` + `/api/plpcg/manifest` e `/api/plpcg/manifest/checksum`. O `/api/catalog/*` do Worker `plpcg-catalog` deixa de ter chamador no app. |
| D2 | **URL do PDF direto ao coldigom** via campo `pdf` do manifest (F5). Sem proxy, sem `/resolve?redirect=1`. |
| D3 | **Um louvor por praise.** `Louvor.effectiveGroupId` = `praiseId` quando presente. A fusão manifest + extras Coldigom acontece no `CompositeCatalogSource` (abordagem A em §2.1). |
| D4 | **Uma entrada por material.** O lado Coldigom não emite PDFs cujo `materialId` o manifest cobre; o id Coldigom desses materiais resolve por alias para o `Louvor` do manifest, então playlists recentes com ids Coldigom continuam a abrir. |
| D5 | **Busca e ranking intactos.** `PlpcgSearchIndex`/`runPlpcgSearchPipeline` não mudam; `searchLocal` não funde (custo), só filtra duplicados Coldigom; a página remota valida em vez de duplicar. |
| D6 | **Offline sem ZIP.** UC-09 usa `DownloadMissingPdfs` (PDF a PDF, concorrência 3, do coldigom). Pipeline ZIP, checkpoint e `offline-manifest.json` são apagados. |
| D7 | **Dois dart-defines, nada hard-coded:** `PLPCG_API_BASE_URL` (Worker `plpcg-catalog`) e `COLDIGOM_API_BASE_URL` (coldigom). Guard de arranque cobre os dois. |
| D8 | **Gates Live/share fora** desta entrega (§11). |

### 2.1 Abordagens consideradas

- **A. Fusão na porta (`CompositeCatalogSource`) — escolhida.** As duas fontes continuam a responder do seu cache; muda a chave (`praiseId`) e o composite funde em vez de despachar por prefixo. Busca/ranking não se apercebem.
- **B. Fonte única (manifest nos caches Coldigom, apagar `PlpcgCatalogSource`).** Rejeitada: o ranking UC-01 e os filtros UC-02 vivem sobre a lista do manifest; portar para `ColdigomSearchIndex` é reescrever a busca.
- **C. Fusão na camada de dados (manifest gravado em `ColdigomPraiseCache`).** Rejeitada: duplica o manifest em duas coleções Isar, dobra o sync e não elimina a fusão em memória.

## 3. Configuração, endpoints e transporte

### 3.1 dart-defines e guard

- `ColdigomApiConfig.baseUrl` perde o `defaultValue`. `AppConfig` ganha `isColdigomBaseUrlMissing`; `app.dart` mostra `_MissingApiBaseUrlScreen` quando **qualquer** dos dois falta, dizendo qual.
- Os quatro `dart_defines/*.json` já têm os dois defines; `ios/Flutter/PlpcgDartDefines.xcconfig` é conferido para incluir `COLDIGOM_API_BASE_URL`.

### 3.2 Endpoints

- `ColdigomEndpoints` += `plpcgManifest = '/api/plpcg/manifest'`, `plpcgManifestChecksum = '/api/plpcg/manifest/checksum'`.
- `ApiEndpoints` −= `louvoresManifest`, `louvoresManifestChecksum`, `offlineManifest`, `packagesZip`, `assetsPdf`, e `uploadLouvor` se não tiver chamador. Sobram só rotas do Worker `plpcg-catalog`.

### 3.3 `CatalogRemoteDatasource`

- Recebe `coldigomDioProvider` (base `COLDIGOM_API_BASE_URL`, só `RetryInterceptor`) em vez de `dioProvider`; usa os dois paths novos. Lógica de `fetchManifestConditional`/`fetchChecksumConditional` inalterada (F1). Sai o `StateError` «PLPCG_API_BASE_URL não definido».
- `CatalogRepositoryImpl.syncManifest`, `PollManifestChecksum`, `ManifestChecksumStore`, `CatalogSyncMetadataStore` não mudam.

### 3.4 URL do PDF

- `LouvorPdfPath.fromLouvor(louvor)` devolve `louvor.pdf` quando começa por `http://`/`https://`; caso contrário mantém a derivação legada por `pdfId` (fixtures; cache Isar antes do primeiro sync).
- `PdfSourceResolver` já trata URL absoluta como `remoteUrl`; o Dio ignora `baseUrl` para URL absoluta. Leitor, prefetch do carrossel, «baixar de novo» e UC-10 passam a ir ao coldigom sem mais mudanças.
- Trade-off do proxy: `/api/coldigom/*` existe para recursos sem CORS/CORP próprios; os PDFs do coldigom já os têm (F5). O proxy só acrescentaria um salto pelo Worker `plpcg-catalog` (latência, requests, dependência). Áudio/cifra/gestos continuam pelo proxy como hoje (fora do escopo).
- `AssetBaseUrlResolver` mantém a regra por prefixo para ids Coldigom nativos; a base PLPCG dele fica só para `pdf` não absoluto.

### 3.5 Cache

- `OfflinePdfIndex` por `pdfId`: nada a migrar. O primeiro sync pós-deploy regrava as 4429 linhas de `LouvorCache` (mudou `pdf` e entram `praiseId`/`materialId`) uma vez; `RemapPdfIdsAfterCatalogUpdate` não remapeia nada porque os `pdfId` são iguais.

## 4. Modelo

### 4.1 Campos novos

- `Louvor`, `LouvorDto`, `LouvorCache`: `String? praiseId`, `String? materialId`. Isar `isar_plus` aceita propriedade nula nova sem migração manual (precedente: `shortId`, 0f0ec0dc).
- `LouvorCacheMapper` e `_isSameManifest` cobrem os dois campos. O DTO só aceita `String` não vazia; o resto vira `null`. O parser continua a ignorar só entradas sem `pdfId`.

### 4.2 Identidade do grupo

- `Louvor.effectiveGroupId` = `praiseId` → senão `groupId` do manifest → senão `LouvorGroupId.compute(numero, nome)`.
- É a única mudança semântica: `PlpcgSearchIndex`, `LouvorGroup.fromLouvores`, `louvoresOfGroup`, sheet de materiais e troca de material já agrupam por `effectiveGroupId`. Consequência F3 aceite. Fixtures antigas e cache pré-sync caem no `groupId`.

### 4.3 `LouvorDataSource`

- Enum fica; doc reescrita: `plpcg` = id legado (`<classificacao>/<arquivo>.pdf`), `coldigom` = id nativo (`assets/praises/<praise>/<material>.<ext>`). Ambos servidos pelo coldigom; o valor só diz o espaço de ids.

### 4.4 `LouvorGroup.isColdigom` — ponto de verificação

- Passa a ser `true` para grupo do manifest com extras em cache. Na implementação, levantar cada chamador; se algum depender de «PLPCG puro», trocar por `primaryLouvor?.source == LouvorDataSource.plpcg`. (`showColdigomShareDialog` decide por entradas da lista, não por `isColdigom`.)

### 4.5 Alias de ids

- Utilitário puro no domínio do catálogo: `coldigomPdfIdFor(praiseId, materialId) = encodePdfId('assets/praises/$praiseId/$materialId.pdf')` — igual ao `pdfId` que `ColdigomLouvorAdapter` produz.
- `manifestMaterialAliasesProvider` (observa só `louvoresManifestProvider`, construído uma vez por manifest, padrão de `pdfIdsByShortIdProvider`) expõe: `praiseIds: Set<String>`, `byMaterialId: Map<String, Louvor>`, `legacyPdfIdByColdigomPdfId: Map<String, String>`. Vazio enquanto o manifest não tem `praiseId`.

## 5. Fontes e fusão

### 5.1 Regra

Um grupo é «do manifest» quando `praiseId ∈ aliases.praiseIds`. O composite monta-o com `LouvorGroup.fromLouvores(pdfsDoManifest + pdfsColdigomNãoCobertos, audioTracks, chordMaterials, gestureMaterials, lyricsByGroupId, youtubeMaterials, coldigomMetaByGroupId)`, tudo chaveado pelo mesmo `praiseId` → um grupo, com `coldigomMeta`. `ColdigomCatalogSource` expõe `partsOfGroup(praiseId)` (PDFs, faixas, cifras, gestos, letra, YouTube, meta) para o composite não conhecer os caches.

### 5.2 `CompositeCatalogSource`

| Método | Comportamento |
|---|---|
| `groupById(id)` | `id ∈ praiseIds` → fundido; senão `coldigom.groupById`; senão (pré-sync) `plpcg.groupById`. |
| `groupForMaterial(id)` | Id legado → louvor do manifest → fundido. Id Coldigom com alias → idem. Senão `coldigom.groupForMaterial`; se o praise está no manifest → fundido. |
| `materialById(id)` | Legado → `plpcg`. Coldigom com alias → `PdfMaterial(louvor do manifest)`. Senão `coldigom`. |
| `searchLocal(q)` | `plpcg.searchLocal(q)` **sem fundir** + `coldigom.searchLocal(q)` filtrando `groupId ∈ praiseIds`. Ordem O16 e ranking intactos. |
| `search(q)` | Página Coldigom; cada grupo com praise no manifest é substituído pelo fundido. |

Também ganha as versões síncronas `findGroupById`/`findGroupForMaterial` (os caches e o manifest já estão em memória) para o carrossel (§5.6).

`catalogSourceProvider` observa também `manifestMaterialAliasesProvider`; `plpcgCatalogSourceProvider` continua estável.

### 5.3 Lado Coldigom pula o coberto

- `ColdigomCacheWriter._merge` (ponto único de escrita — busca, browse, detalhe/warmup, hidratação): PDFs cujo `pdfId ∈ legacyPdfIdByColdigomPdfId` não entram em `coldigomLouvoresCache`. Áudio, cifra, gestos, letra, YouTube e meta entram sempre.
- `ColdigomSearchIndex` não muda; quem filtra é o composite (§5.2).

### 5.4 Conhecidos e adoção

- `knownPraiseIdsProvider` = `coldigomSearchIndexProvider.catalogIds ∪ aliases.praiseIds`.
- `homeSearchProvider` usa-o em `knownIds` (sem chip «novo» para praise do manifest); `homeRemoteSearchProvider` usa-o para filtrar candidatos à adoção — praises do manifest nunca entram no Isar Coldigom.
- Efeito na Home: como `newGroups` exclui `groupId`s já presentes no local e os grupos do manifest têm `groupId = praiseId`, a página remota passa a **validar** («Atualizado») em vez de anexar cópias; só os 216 praises fora do manifest (e futuros) entram como extra.

### 5.5 Warmup

- `warmupColdigomInBackground`/`ensureColdigomPraiseMaterialsCached`: `praiseId = louvor.praiseId ?? coldigomPraiseIdFromPdfId(louvor.pdfId)`. Abrir um PDF do manifest aquece o praise; o sheet mostra áudio/cifra/letra.
- Curto-circuito «já tem PDF e áudio» → «já tem `praiseMeta[praiseId]`» (com PDFs cobertos fora do cache o critério antigo nunca fecharia).

### 5.6 `findSwapMaterialGroup`

- Passa a receber o `CompositeCatalogSource` e a usar `findGroupForMaterial`/`findGroupById` síncronos dele, mantendo a precedência «faixa tocando manda se o `pdfId` for de outro louvor» e o corte `totalMaterials > 1`.
- Chamadores (`carousel_chips`, `carousel_swap_material_button`) passam `ref.watch(catalogSourceProvider)` em vez dos cinco caches.
- `findLouvorGroupByPdfId` (só PLPCG) fica.

## 6. Offline — primeira configuração sem ZIP

### 6.1 Sai

`OfflineManifestRemoteDatasource` (+ `OfflineManifest`/DTO, chaves `offline_manifest_json`/`offline_manifest_cache_time`), `ZipPackageDownloader` (nativo/web), `ZipPdfExtractor`/`ZipExtractionRunner` (nativo/web/shared), `ExtractAndStorePdfs`, `DownloadOfflinePackages`, `OfflineBulkCheckpointStore` + `OfflineBulkCheckpoint`, estado `unmatchedZipEntries`, `CheckpointBanner`, e os testes de cada um. `StorageQuotaEstimator`/`InsufficientDiskSpaceException` só ficam com outro chamador. `ReconcileOfflineIndex` fica (`offline_reconcile_provider`). `archive` sai do `pubspec` se só o extractor a usar.

### 6.2 Entra

- `OfflineBulkDownloadNotifier.start(categories)` → `DownloadMissingPdfs(materialCategories, cancelToken, onProgress)`. O use case ganha `CancelToken` (repassado a `FetchAndStorePdf`); `(done, total)` alimenta a `ProgressSection`. `persistentDownload: true`.
- `_completeBulkDownload` continua a gravar `OFFLINE_AVAILABLE=TRUE` e as categorias. O gate UC-09/UC-10 da tela não muda.
- Cancelar interrompe; «retomar» = `start` com as categorias da última execução (`DownloadMissingPdfs` pré-filtra o que já existe). Wakelock e lock de manutenção ficam.

### 6.3 Custo aceite

«Tudo» = 4429 requests (concorrência 3) em vez de ~12 ZIPs. Em troca: sem dependência do plpcg.com, um caminho só.

## 7. Erros

- Rede falha no manifest → cache Isar (como hoje). Sem cache e sem rede → erro atual.
- `pdf` não absoluto (defensivo) → derivação legada contra `PLPCG_API_BASE_URL`.
- Id Coldigom de material coberto sem cache Coldigom → alias sem rede.
- Antes do primeiro sync pós-deploy: sem `praiseId`, comportamento idêntico ao atual.

## 8. Testes

- Unit: DTO/mapper com e sem `praiseId`/`materialId`; `effectiveGroupId` (praiseId > groupId > computado); `coldigomPdfIdFor` = `encodePdfId` do r2Key do adapter; `LouvorPdfPath.fromLouvor` absoluto vs relativo; `CatalogRemoteDatasource` nos paths novos e no Dio Coldigom.
- `CompositeCatalogSource`: fusão em `groupById`/`groupForMaterial`; `materialById` por alias; `searchLocal` filtra e mantém ordem; `search` substitui pelo fundido; fallback pré-sync.
- `ColdigomCacheWriter` pula cobertos; `knownPraiseIdsProvider` união; warmup por `praiseId` e curto-circuito por meta.
- `findSwapMaterialGroup` sobre o composite com os casos de precedência atuais.
- Offline: notifier sobre `DownloadMissingPdfs` (start, progresso, cancel, retomar); `DownloadMissingPdfs` com `CancelToken`; testes do ZIP apagados.
- Fixture `test/fixtures/manifest_coldigom_sample.json` com o shape real (F4: dois `materialId` duplicados; F3: um praise em dois grupos legados).
- Guard de arranque para cada define ausente.

## 9. Validação manual (prod v2, pós-deploy)

1. Abrir PDF de playlist antiga (id legado) e de link `?s=`.
2. Abrir playlist recente com id Coldigom de material coberto.
3. Sheet de materiais de louvor do manifest mostra áudio/cifra após warmup.
4. Busca «a ti senhor»: um card, remoto em «Atualizado».
5. Primeira configuração offline de «Gestos em Gravura» (253) até o fim; contadores da tela offline iguais antes/depois do primeiro sync para o que já estava baixado.
6. `window.__plpcgPerf` / rede: PDFs saem de `coldigom-api…/assets/praises/…`, sem chamadas a `plpcg.com/assets`.

## 10. Docs e entrega

- `docs/features/FEATURE_INDEX.md` (`catalog`, `offline`; a nota do gate de share aponta para §11), `docs/features/LOUVOR_GROUPING.md` (identidade por `praiseId`), `README`/`dart_defines` (dois defines obrigatórios), `MAPEAMENTO_PLPCG_FLUTTER.md` §2.3/§11.1 (catálogo e assets migraram para o coldigom).
- Branch a partir de `web/integration`; commits por unidade (config → modelo → fusão → offline → docs); PR para `web/integration`.

## 11. Follow-ups (fora desta entrega)

- **Lista ao Vivo:** traduzir entrada legada → id Coldigom (`praiseId`/`materialId` do manifest) e deixar listas antigas subir ao vivo.
- **Share:** rever o gate «só PLPCG puro» à luz da fusão (entradas Coldigom continuam sem `shortId`).
- **`/api/plpcg/catalog`:** se o patch entrar no coldigom, a hidratação existente cobre e o filtro do composite continua correto.
- **Worker `plpcg-catalog`:** congelar/remover `/api/catalog/*` quando não houver builds antigas em uso.
- **Áudio/cifra/gestos direto** (sem proxy) — mesma verificação de CORS/CORP de F5.

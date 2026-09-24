# Fim da fonte PLPCG — o app vive só do coldigom

**Data:** 2026-09-23
**Estado:** implementado (planos 0–3, branch `feat/fim-fonte-plpcg` @ `0e6c6b08`); ver §13 «Estado implementado e desvios».
**Branch:** `feat/fim-fonte-plpcg` (worktree `.claude/worktrees/fim-fonte-plpcg`), a partir de `web/integration` @ `59e38160`.
**Repos:** `coldigui` (app Flutter + Worker `plpcg-catalog`) e `coldigom` (`api/`, só as duas peças de §7).
**Substitui:** a dicotomia PLPCG × Coldigom que sobrou do spec `2026-09-18-catalogo-coldigom-modo-unico-design.md`. Fecha os follow-ups §11 «Lista ao Vivo» e «Share» desse spec e o débito «gate Coldigom» de `docs/features/FEATURE_INDEX.md`.

## 0. Objetivo e limites

O app **deixa de consumir o `louvores-manifest.json` em qualquer forma**, incluindo o `/api/plpcg/manifest` que o coldigom serve. Catálogo, busca, /biblioteca, /offline, agrupamento, compartilhar e ao vivo passam a usar só dados do coldigom:
- o dump `/api/plpcg/catalog`, que já é sincronizado no Isar por ETag;
- a API de praises (busca remota e detalhe);
- o crosswalk legado do coldigom, uma única vez por id legado (§6).

Deixa de existir no app qualquer escolha ou distinção visual de fonte de dados.

**Não entra (decidido):**
- **A marca.** Continuam `appTitle` «PLPCG», os títulos de aba «{louvor} · PLPCG», «Folheto PLPCG», «Ajude a melhorar o PLPCG», «abra v2.plpcg.com no Safari» e o domínio v2.plpcg.com. Rebranding é outro plano.
- **Renomear código.** Ficam as classes e ficheiros `Plpcg*` de UI (`PlpcgAppBarTitle`, `PlpcgPrimaryAppBar`, `PlpcgBottomNavBar`, `PlpcgNavigationRail`), a env `PLPCG_API_BASE_URL` e o Worker `plpcg-catalog`, que continua a servir auth, playlists, flags, favoritos, social e ao vivo.
  - Código **morto** por causa deste trabalho é apagado, não renomeado. Exemplos: `PlpcgCatalogSource`, `PlpcgSearchIndex`.
- **O plpcjf (plpcg.com).** Vai ser desligado; não há paridade a manter e ele não é tocado.

## 1. Factos medidos (2026-09-23, coldigom de produção)

| # | Facto | Consequência |
|---|---|---|
| M1 | O `classificacao` do manifesto é exatamente a lista de tags do praise: 0 divergências em 4429 entradas (ex.: `"CIAs, Coletânea"`, `"Avulsos, PES · 9.2026"`). | O filtro «classificação» já era um filtro de tags. Hoje os chips mostram **combinações** («CIAs, Coletânea» num chip só). |
| M2 | Nenhum `classificacao` tem parênteses. | O filtro «arranjo especial» está morto: tudo é «Padrão». |
| M3 | `categoria` → tipos coldigom: Partitura → {Partitura 1019, Coro 556, Coro e piano 4}; Cifra → Cifra; Cifra nível I → Cifra I; Cifra nível II → Cifra II; Gestos em Gravura → Gestos CIAs. | Os 3 chips curados são uma vista do tipo de material; o app passa a usar os tipos reais. |
| M4 | `GET /api/plpcg/catalog` responde 200 (a 18/09 respondia 404, facto F6 do spec anterior). São 2063 praises com `tags`, `rhythm`, `tonality`, `category`, `lyrics` e `materials[{id, kind, type}]`, e 103 kinds. Tamanho: 3,7 MB, ~950 KB comprimidos. O app já sincroniza por ETag (`SyncColdigomCatalog`) e hidrata o `ColdigomSearchIndex`. | O acervo inteiro, com todos os atributos dos dois modos de hoje, já está no aparelho. |
| M5 | Preenchimento dos praises: rhythm 1149, tonality 1158, category 1171, number 1215 (de 2063); tags em todos. Valores sujos no coldigom: «Avulso»/«Avulsos», «Ressureição»/«Ressurreição», «Basico»/«Básico», «fox»/«Fox». | Os filtros mostram os valores como estão. Limpar é tarefa do coldigom (fora do escopo). |
| M6 | O coldigom tem a tabela `plpcg_crosswalk` (migration 019): `pdf_id` legado → `praise_id`, `praise_material_id`, com evidência e confiança. `GET /api/plpcg/resolve/:shortId` responde 200 com `{pdf_id, praise_id, material_id, url}`. | O mapeamento legado → coldigom vive no coldigom, independente do manifesto (§6). |
| M7 | A página inicial e a /biblioteca funcionam hoje **sem Isar** (o manifesto vai para a memória). Só `/listas` e `/offline` estão atrás do `StorageRequiredGate`. | O catálogo único tem de manter um caminho em memória (§2.1). |
| M8 | A secção Coldigom do /offline só lista tipos com login. Sem login, o offline hoje vem só da secção PLPCG. | Apagar a secção PLPCG sem mais nada tiraria o offline a quem não tem login (§3.1). |
| M9 | Ids legados persistidos (levantamento de 2026-09-23):<br>• Isar: `Playlist.items`/`pdfIds`, `OfflinePdfIndex.pdfId`, `CarouselEntry.pdfId` (residual);<br>• prefs: `recentlyOpened`, `pdfLastPages`, `carousel_focused_pdf_id` (formato `id#n`);<br>• D1: `user_playlists.items`/`pdf_ids`, `short_links.query`.<br>Nada mais guarda material ids: favoritos guardam kinds, e o áudio é só coldigom. | Inventário da migração (§6). |
| M10 | Sync de playlists: pull → push → tombstones; LWW por `updatedAt` com `version` como desempate. O servidor ignora a `version` do cliente e devolve 409 em push velho. Reescrever pelo `PlaylistRepository.update` dá push; um `version+1` no D1 sem mexer em `updated_at` é puxado por quem não tem push pendente. | Regras da migração no servidor (§6.3). |

## 2. /biblioteca, filtros e página inicial

### 2.1 Fonte: o índice do catálogo coldigom

- `ColdigomSearchIndex` (um `LouvorGroup` por praise) passa a ser **o** catálogo. O `catalogSourceProvider` passa a devolver o `ColdigomCatalogSource`, e a porta `CatalogSource` fica.
- **Caminho normal:** Isar → `coldigomCatalogHydrationProvider` (como hoje).
- **Caminho novo, em memória:** quando o Isar está `unavailable`, o sync baixa o dump e monta o índice direto, sem gravar. É o mesmo contrato que o `louvoresManifestProvider` tem hoje.
  - O `SyncColdigomCatalog` ganha o desfecho «dump em memória».
  - A hidratação passa a aceitar as linhas vindas do DTO.
- **Enquanto o índice está vazio:** a página inicial e a /biblioteca mostram carregamento.
  - Índice vazio, sync falhado e sem rede → `catalogLoadError` + «tentar de novo», que chama `coldigomCatalogSyncProvider.sync()`.
  - A reconexão refaz o sync se o índice estiver vazio.
- **Arranque a frio:** passa a baixar o dump (~950 KB comprimidos) em vez do manifesto. A hidratação continua fatiada (`coldigomHydrationChunkSize`). Medir o 1.º frame em prod é item da validação (§11).

### 2.2 Filtros — um conjunto só

O `CatalogFilterState` novo substitui o de material/arranjo (`catalogFiltersProvider`) e o `ColdigomLibraryFilterState`.

| Filtro | Origem (catálogo local) | Semântica |
|---|---|---|
| Tom | `tonality` do praise | OU entre os selecionados |
| Ritmo | `rhythm` | OU |
| Categoria | `category` | OU |
| Tags | `tags` (nomes) | OU. Selecionar `X` também apanha `X · Y` (o pai inclui os filhos). |
| Tipo de material | `kind` de cada material do praise | O praise tem ≥1 material de algum tipo selecionado |

- Entre filtros diferentes, a regra é E. Sem seleção num filtro, esse filtro não restringe.
- **Opções de cada filtro:** saem do índice local. Só aparecem valores com ≥1 praise; os tipos por nome, a partir do `kinds` do dump. `coldigomLibraryFacetsProvider`, `/api/praises/filters` e `/api/materials/kinds` deixam de ser chamados pela /biblioteca e pela página inicial.
- **Predicado único:** a função pura `matchesCatalogFilters(LouvorGroup, CatalogFilterState)` lê o `coldigomMeta` (tom, ritmo, categoria, tags) e os `materialKindId` dos materiais do grupo. É usada pela /biblioteca, pela busca local e pelos «novos» da busca remota.
- **UI:**
  - O `FiltersPanel` perde o `showPlpcgSections`.
  - Somem `CategoryFilters`, `ClassificationFilters` e `SpecialArrangementFilters`.
  - O conteúdo das secções vem do `ColdigomLibraryFilters` de hoje, que passa a ler as opções locais em vez das facets remotas.
- **Persistência:** a pref `catalogFilters` (`{materials, arranjos}`) é descartada na leitura quando tem o formato velho. O formato novo guarda os cinco conjuntos.

### 2.3 /biblioteca

- Pipeline único e local: índice → `matchesCatalogFilters` → ordenar (`numero`/`nome`, a mesma regra de hoje) → paginar (`PaginateLouvorGroups`).
- O driver assíncrono (`LibraryGroupPipelineDriver` + `compute`) fica **se** a medição mostrar que vale para 2063 grupos. Senão, o pipeline passa a síncrono num `Provider`, como a busca da página inicial.
- **Saem:**
  - `LibraryCatalogMode`, `libraryCatalogModeProvider`, `LibraryCatalogModeToggle`;
  - `libraryColdigomBrowseProvider`, `libraryLastGoodResultsProvider`, `libraryPlpcgGroupResultsProvider`;
  - `librarySpecialArrangementProvider`, `BrowseLibrary`, `FilterByMaterialAndArranjo`, `FilterBySpecialArrangement`;
  - `LouvorClassification`, na parte de filtros.
  
  O `library_screen.dart` perde todos os ramos `isColdigom`: loading, erro, retry, reconexão e `ValueKey(mode)`.
- **Mantém-se:** `LouvorClassification.materialSectionLabel`/`displayLabel`, **se** tiverem outro chamador (verificar no plano). Senão saem também.

### 2.4 Página inicial

- A busca local (`homeLocalSearchProvider`) passa a ser `ColdigomSearchIndex.search(query)` filtrado por `matchesCatalogFilters`. O ranking é o de hoje (número exato → título exato → parcial), que o índice já espelha.
- Sai o `mergeLocalSearchResults` («PLPCG primeiro, Coldigom depois») e o filtro por `manifestPraiseIds`.
- A página remota continua a validar e a trazer «novos». Os «novos» passam pelo mesmo `matchesCatalogFilters` no cliente, sem traduzir nomes de tag para ids do servidor. A adoção e o chip «novo» ficam.
- `knownPraiseIdsProvider` passa a ser só `coldigomSearchIndexProvider.catalogIds`.
- `home_search_state.dart`: os campos e docs deixam de falar em PLPCG/Coldigom.

### 2.5 URL

- **Saem** `fonte`, `materiais`, `arranjo` e `arranjoEspecial`. Um link antigo com eles é ignorado sem erro.
- **Valem nas duas rotas (`/` e `/biblioteca`):** `tonality`, `rhythm`, `category`, `tags` (**por nome**, CSV ordenado), `materialKinds` (ids de kind), `ordenar`, `itensPorPagina`, `pagina`, `pesquisa`.
- `library_url_builder.dart`, `buildHomeLocation`, `app_router.dart` (sai o `initialFonte` e os `initialMateriais`/`initialArranjo`/`initialArranjoEspecial`) e `url_sync_params.dart` acompanham.

### 2.6 O que se perde (aceite)

- O filtro «arranjo especial» (M2).
- Os 3 chips curados Partitura / Cifra / Gestos (M3), trocados pela lista real de tipos.
- Os chips de «classificação» combinada, trocados por tags individuais.

## 3. /offline e cor

### 3.1 /offline — uma secção

- **Uma secção só**, com o rótulo «Baixar para usar offline» (chave nova), construída a partir da `ColdigomOfflineSection`.
- **Mantém-se:**
  - a linha de estado do catálogo;
  - a escolha por tipo, «Baixar selecionados», «Parar» e o progresso;
  - o uso de disco (`offlineStatsDiskUsage`/`UsedOnly`), «Atualizar» (reconcile) e o banner «N removidos», só com «dispensar».
- **Sem login:** aparece a lista «Tipos» completa, sem o bloco «Seus tipos favoritos» (M8).
  - O download por tipo não depende de conta; só os favoritos dependem.
  - O `_SignInCard` passa a ser uma linha opcional («Entre para ver os seus tipos favoritos primeiro»), não um bloqueio.
- **Remover tudo:** «Remover áudios e PDFs baixados do Coldigom» passa a «Remover todos os baixados», e o título do diálogo de confirmação acompanha. O `RemoveColdigomDownloads` perde o filtro `isColdigomPdfId` e remove todos os PDFs e áudios indexados.
- **Saem:**
  - `_OfflineContent` (chips de categoria, estatísticas por categoria, long-press «em falta», limpar por categoria);
  - `OfflineBulkDownloadNotifier` e `DownloadMissingPdfs` sobre o `LouvorCache`;
  - `offlineCategorySelectionProvider`, `GetOfflineStatsByCategory` e `loadPdfIdToCategoria`;
  - `OfflineAvailableStore`, com a flag `OFFLINE_AVAILABLE` e o gate UC-09/UC-10;
  - as prefs `offlineSelectedCategories` e `offlineBulkCategories`;
  - `ProgressSection` e `KeepAppOpenBanner`, **se** a secção por tipo não os reaproveitar (verificar no plano).
- **Um estado de ocupado:** `_plpcgMaintenanceBusy` e `_maintenanceBusy` fundem-se. Decide o `offlineMaintenanceLockProvider`, que já sabe quem é o dono; a secção desabilita tudo menos o «Parar» do próprio dono.
- O `MigrateOfflineStorage` ganha o passo 5: apaga as prefs mortas desta secção e do manifesto (§6.4).

### 3.2 Cor

- Morrem `AppColors.chipColdigom` e `CarouselItem.source` (o único consumidor era a cor do chip). Tudo passa a `AppColors.title`.
- Tocados: `carousel_louvor_chip.dart:227-229`, `carousel_items_provider.dart`, `carousel_chips.dart:211-218`, `home_empty_state.dart` (:64-66, :72-96, :102), `louvor_group_card.dart` (:74, :318), `playlist_tile_detail_chips.dart`.
- O fallback `artist: 'Coldigom'` da notificação de áudio (`audio_player_session_provider.dart:655`) passa a `'PLPCG'` (marca, como `audio_media_session_web.dart:51`).

## 4. Compartilhar — link por praise

### 4.1 Contrato

```
https://v2.plpcg.com/?p=1a2-0c3-fff&n=Culto%20de%20domingo
```

| Item | Regra |
|---|---|
| `p` | `shortId`s de **praise** (§7.1) separados por `-`, na ordem da lista; repetidos permitidos. |
| token | `[0-9a-f]{3,8}`, sempre string (nada de `int.parse`). Maiúsculas normalizam para minúsculas; fora do padrão é ignorado. |
| `n` | Nome da lista, obrigatório. |
| Origem | `https://v2.plpcg.com`, constante nova `ShareConfig.appOrigin`. Deixa de ser `AppConfig.apiBaseUrl`. |
| Limpeza | `p` e `n` entram na lista de params removidos após o import. |

É param novo (`p`, não `s`): os shortIds de material dos links antigos (`1a2f`) colidiriam com shortIds de praise depois de 4096 praises, e um link antigo abriria louvores errados.

### 4.2 Gerar

- Cada entrada → praise pelo **catálogo local** (mapa material → praise do índice), não pelo path do id: 64 materiais movidos têm o path noutra pasta (desvio 2 do spec de 18/09).
- Praise → `shortId`, que atravessa estas camadas:
  - `ColdigomCatalogPraiseDto`, `PraiseDetailDto` e `PraiseSummaryDto` (campo `short_id`/`shortId` opcional);
  - `ColdigomPraiseCache` (propriedade Isar nova, nula; aditiva, sem migração, como precedente `LouvorCache.shortId`);
  - `ColdigomPraiseMetadata.shortId`.
- Todas as entradas servem, incluindo áudio, cifra, gesto e YouTube.
- Entrada cujo praise não tem `shortId`, ou material fora do índice: o share falha com o snackbar de erro de hoje e dispara-se `coldigomCatalogSyncProvider.sync()`.
- `GeneratePlaylistShareUrl` devolve só a URL: sai o `PlaylistShareLink.isShort` e o param `short`.

### 4.3 Importar

- `p` → praises pelo índice (mapa `shortId → praiseId`, montado na hidratação). Com o índice vazio, o import espera o sync (um `Future` com timeout; falha = mensagem de hoje).
- Token desconhecido: ignorado com log. Nenhum resolvido: link inválido, com a mensagem de hoje.
- Cada praise → `preferredMaterialForGroup(group, rank: favoriteMaterialKindRank)`:
  - com login, o material do favorito mais bem colocado;
  - sem favorito presente ou sem login, PDF principal → único áudio → primeiro adicionável.
  - Praise sem nada adicionável é saltado.
- O material escolhido por quem enviou não viaja; é aceite, porque o link é por louvor.

### 4.4 Links antigos

- `s`, `sharepdfs`, `shareitems`, `shareaudios` e `sharename` são reconhecidos, limpos da URL e mostram a mensagem nova `playlistShareLegacyLinkUnsupported`: «Este link é de uma versão antiga e já não abre. Peça um link novo à pessoa.».
- Os parsers do formato curto por material e do formato longo saem.

### 4.5 O que sai

- `showColdigomShareDialog`, `coldigom_share_dialog.dart` e as strings `playlistShareColdigomTitle`/`BodyLeaflet`/`BodyLink`/`Cancel`/`LeafletOnly`/`Dismiss`.
- O cliente do encurtador `/l/` (`share_link_shortener_remote.dart`, provider e teste).
- `pdfIdsByShortIdProvider`, `ShortIdResolver` (porta) e `isShortId`/`isShortFormat` do formato por material.
- O débito anotado em `playlist_share_actions_provider.dart:229-236` fica pago.
- **Folheto:** sai sempre com QR. As opções «Folheto» e «Só o link» ficam.

## 5. Ao vivo — o gate morre

- **Saem:**
  - `lib/features/live/domain/live_coldigom_only.dart`;
  - `showLiveColdigomOnlyDialog` (`live_coldigom_only_dialog.dart`);
  - `AddToActiveOutcome.liveColdigomOnly`;
  - as verificações em `active_playlist_editor.dart` (:97-115 add; :279 replace/swap), `playlist_tile_actions.dart:577-579` (`_goLive`) e `live_session_banner.dart:38-45` («Retomar»);
  - as strings `liveColdigomOnlyTitle`/`Body`/`Add`.
- **Porquê é seguro:**
  - Depois da normalização (§6.2) toda a entrada guardada tem id coldigom.
  - Uma órfã que sobreviva (crosswalk não a conhece) não bloqueia nada: `livePraiseKeysOf` já cai na chave por material, e o consumidor vê-a como material indisponível, como qualquer id desconhecido.

## 6. Ids legados — migração

### 6.1 Decisão

- Os ids legados **deixam de ser um espaço de ids suportado**.
- Tudo o que estiver guardado é normalizado **uma vez** para id coldigom, pelo crosswalk do coldigom (M6).
- Links `?s=` e longos antigos não abrem (§4.4).
- Não há tabela congelada no app, e o app deixa de ler o manifesto.
- `isColdigomPdfId` fica: é o detetor de id legado. Id legado = entrada PDF com `!isColdigomPdfId`, o que inclui os 36 `assets/PES/…`.

### 6.2 No aparelho — `NormalizeLegacyMaterialIds`

- **Mapa:** `ColdigomRemoteDatasource.resolveLegacyPdfIds(ids)` → `POST /api/plpcg/crosswalk` (§7.2), em lotes de 500. Id coldigom = `encodePdfId(<path do url depois da base>)`, a mesma regra de `coldigomPdfIdFromManifestPdf`, que passa a ler o `url` do crosswalk.
- **Stores (M9):**

| Store | Reescrita | Id desconhecido |
|---|---|---|
| `Playlist.items` + `pdfIds` | `PlaylistRepository.update(entries:)`: mantém o `kind` e a ordem, preserva `syncStatus == conflict`, faz push nas guardadas. | Fica. Aparece como indisponível e o usuário remove. |
| `OfflinePdfIndex` | `remapPdfId` (o ficheiro fica em `storagePath`). | A linha sai; o ficheiro órfão é limpo pelo reconcile (`listOrphans`). |
| pref `recentlyOpened` | Troca o id, sem repetidos. | Descartado. |
| pref `pdfLastPages` | Troca o `id`; em colisão fica a entrada mais recente. | Descartada. |
| pref `carousel_focused_pdf_id` | Troca a parte do id e mantém o sufixo `#n`. | Pref apagada (o foco cai no início). |
| `CarouselEntry` | Corre depois do `MigrateCarouselStore`, que já esvazia a coleção. Nada a fazer se estiver vazia. | — |

- **Quando corre:** depois de o Isar assentar, no hydrate da sessão (`hydratePlaylistSession`) e depois de cada pull de playlists (`SyncPlaylists`).
  - Varre as stores e junta os ids legados. **Sem ids legados não há rede nem escrita.**
  - Com ids legados e sem rede, fica pendente e tenta no próximo gatilho.
  - Não há flag de «feito»: é idempotente, e por isso também apanha ids legados que um cliente antigo volte a empurrar pelo servidor.
- **Concorrência:** o índice offline é reescrito sob o `offlineMaintenanceLockProvider`. As playlists passam pelo repositório, que já serializa as escritas.
- **Sem Isar:** não há playlists nem índice para migrar; só as prefs são normalizadas.
- **Remoção futura:** quando deixar de haver ids legados, `NormalizeLegacyMaterialIds` e `resolveLegacyPdfIds` saem (follow-up, §12).
- **Item parkeado L/X do offline (spec de 18/09):** resolvido. Todo o índice passa a X.

### 6.3 No servidor — script único no D1

- `workers/plpcg-catalog/scripts/migrate-legacy-playlist-ids.ts` (Node, via `wrangler d1 execute --remote`):
  1. Lê `user_playlists` onde `items` ou `pdf_ids` têm id legado. As linhas anteriores à 0008 têm `items='[]'` e derivam de `pdf_ids`, e por isso as duas colunas são reescritas.
  2. Resolve pelo mesmo `POST /api/plpcg/crosswalk`.
  3. Grava `items` e `pdf_ids` reescritos com `version = version + 1` e **`updated_at` intacto**, para não gerar 409 nem cópias de conflito (M10).
  4. Modo `--dry-run` imprime o diff e a contagem; o modo real grava um relatório (linhas, ids resolvidos, desconhecidos).
- **Corre depois do deploy do app novo**, para que um cliente antigo não reponha ids legados logo a seguir. O normalizador do aparelho cobre o que escapar.
- `short_links` não é migrado: o `/l/` fica sem emissor e os links antigos são legados (§4.4).
- As listas publicadas (`/api/social`, que lê `user_playlists`) ficam normalizadas por consequência.

### 6.4 O que sai do app

- **Pilha do manifesto:**
  - `CatalogRemoteDatasource` (manifesto/checksum), `CatalogRepository` + `CatalogRepositoryImpl`, `CatalogLocalDatasource`;
  - `CatalogSyncMetadataStore`, `ManifestChecksumStore`, `PollManifestChecksum`, `catalog_checksum_poll_provider.dart`, `catalog_manifest_sync_providers.dart`, `OfflineCatalogManifestSyncListener`, `RemapPdfIdsAfterCatalogUpdate`;
  - `louvoresManifestProvider` + `LouvoresManifest`, `louvoresByPdfIdProvider`, `PlpcgCatalogSource` + `plpcgCatalogSourceProvider`, `PlpcgSearchIndex` + `runPlpcgSearchPipeline`, `SearchLouvorByNumberOrText`;
  - `CompositeCatalogSource`, `ManifestMaterialAliases` + `manifestMaterialAliasesProvider`, `pdfIdsByShortIdProvider`, `findLouvorGroupByPdfId`/`findLouvorByPdfId`/`resolveLouvorDataSource`;
  - `LouvorDto`, `LouvorCacheMapper`, `LouvorPdfPath` (derivação legada), `ColdigomEndpoints.plpcgManifest`/`plpcgManifestChecksum`.
  
  Cada um só sai quando não tem chamador; o plano lista o destino de cada consumidor.
- **Consumidores do manifesto a reapontar para o catálogo coldigom:**
  - `app.dart`, `audio_follow_reader_provider.dart`, `home_screen.dart`, `pdfrx_bootstrap.dart`;
  - `playlist_providers.dart`, `playlists_provider.dart`, `playlist_list_tile.dart`;
  - `catalog_material_lookup_provider.dart`, `open_material_provider.dart`.
- **Isar:** a coleção `LouvorCache` sai de `isar_app_schemas.dart`, e os dados são apagados no passo 5 do `MigrateOfflineStorage`, antes de a coleção sair do schema, ou pelo mecanismo que o `isar_plus` exija (verificar no plano).
- **Prefs:** saem `manifestChecksum`, `catalogLastSyncAt`, `lastChecksumPollAt`, `offlineSelectedCategories`, `offlineBulkCategories` e `OFFLINE_AVAILABLE` (passo 5).
- **`LouvorDataSource`:** o enum e os campos `source` de `Louvor`, `AudioTrack`, `ChordMaterial`, `GestureMaterial` e `YoutubeMaterial` são **apagados** (42 referências em 21 ficheiros de `lib`, 73 nos testes).
  - `louvorDataSourceFromPdfId` sai.
  - `LouvorGroup.isColdigom` sai; os 3 chamadores passam a assumir coldigom.
  - `ContributionSource` fica (contrato com o servidor), e `contributionSourceOf` passa a devolver sempre `coldigom`.
  - A doc de `isColdigomPdfId` passa a dizer «detetor de id legado para a normalização».

## 7. Mudanças no coldigom (`../coldigom/api`)

Estas são as **únicas** mudanças no coldigom. As duas são pequenas e têm de estar em produção antes do deploy do app.

### 7.1 `praises.short_id`

- **Migration nova:**
  - `ALTER TABLE praises ADD COLUMN short_id TEXT` + `CREATE UNIQUE INDEX idx_praises_short_id ON praises(short_id)`.
  - Backfill determinístico: `ROW_NUMBER() OVER (ORDER BY created_at, id)` → `printf('%03x', rn - 1)`.
  - Contador numa tabela de meta (a existente, ou `app_meta(key, value)` se não houver): `short_id_next = COUNT(*)`.
- **Atribuição:** no INSERT de praise, no mesmo `db.batch`, lê e avança o contador. O cliente nunca escolhe o valor.
- **Invariantes:** imutável em UPDATE, merge e move; nunca reutilizado (praise apagado ou fundido queima o id).
- **Largura dinâmica:** `printf('%03x', n)` dá `000`–`fff` (4096; hoje há 2063) e depois `1000`… sozinho. Os leitores aceitam `[0-9a-f]{3,8}`, sempre como string.
- **Exposição:** `shortId` em cada praise de `/api/plpcg/catalog` (o ETag muda, e os clientes rebaixam uma vez), em `GET /api/praises/:id` e em `GET /api/plpcg/praises`.
- **Testes (vitest):** backfill único e contíguo; insert gasta um id; falha no insert não avança o contador; merge e delete não reutilizam; o dump traz `shortId`.

### 7.2 `POST /api/plpcg/crosswalk`

- **Corpo:** `{ "pdfIds": ["…", …] }`, até 500 (acima disso: 400).
- **Resposta:** `{ "items": { "<pdfId>": { "praiseId": "…", "materialId": "…", "url": "…" } } }`. Os desconhecidos são omitidos.
- Lê `plpcg_crosswalk` + o `r2_key` atual do material. O `url` tem de ser o real, como o de `/api/plpcg/resolve/:shortId`, para acertar os materiais movidos.
- Público, com o CORS do `/resolve` (origem `https://v2.plpcg.com`) e `Cache-Control: no-store`.
- Testes: lote misto (conhecidos e desconhecidos), limite de 500, `url` de material movido.

**Porque não se evita:**
- (7.1) O link por praise precisa de um id curto que seja do coldigom.
- (7.2) A alternativa, o `LouvorCache` do aparelho, falha em aparelhos que nunca sincronizaram o manifesto do coldigom (`pdf` não absoluto) e não serve o script do D1.

## 8. Erros

- Catálogo vazio + sem rede → `catalogLoadError` + retry (§2.1).
- Crosswalk fora do ar → a normalização fica pendente e as entradas legadas aparecem indisponíveis.
- Link `?p=` com o índice vazio → espera o sync; timeout → mensagem de link inválido de hoje.
- Share com praise sem `shortId` → snackbar de erro + sync (§4.2).
- Link antigo → `playlistShareLegacyLinkUnsupported` (§4.4).

## 9. Strings (l10n: `lib/l10n/app_pt.arb` + `app_en.arb`, depois `flutter gen-l10n`; os gerados são commitados)

### 9.1 Saem
- `libraryCatalogModeLabel`, `libraryCatalogModePlpcg`, `libraryCatalogModeColdigom`.
- `coldigomLoadError`: os dois chamadores passam a `catalogLoadError`.
- `playlistShareColdigomTitle`, `…BodyLeaflet`, `…BodyLink`, `…Cancel`, `…LeafletOnly`, `…Dismiss`.
- `liveColdigomOnlyTitle`, `liveColdigomOnlyBody`, `liveColdigomOnlyAdd`.
- `offlineColdigomPlpcgSection`, `offlineColdigomSection`.
- **Chaves só da secção PLPCG do /offline:**
  - `offlineClearCache`, `…Cancel`, `…Confirm`, `…ConfirmBody`, `…ConfirmBodyAll`, `…ConfirmTitle`, `…Success`, `…SuccessPartial`;
  - `offlineDownloadCompleted`, `…WithFailures`;
  - `offlineStatsCategory`, `…CategoryUnreliableMissing`, `…CategoryWithMissing`, `…MissingUnreliable`, `…Total`, `…TotalMissing`;
  - `offlineStopDownload`, `offlineStoppingDownload`, `offlinePhaseFetching`, `offlineProgressDetail`, `offlineKeepAppOpenDuringDownload`.
  
  **Cada uma só sai se não tiver outro chamador** (o plano confere com grep). Saem também as chaves mortas já hoje: `offlineStatsTitle`, `offlineSelectCategories`.
- `filtersSpecialArrangementTitle`, `specialArrangementPadrao`.

### 9.2 Mudam de valor
- `homeColdigomOffline` → «Sem conexão — o catálogo pode estar incompleto nesta busca.» (en: «No connection — the catalog may be incomplete for this search.»). A chave pode ficar.
- `offlineColdigomRemove` → «Remover todos os baixados»; `offlineColdigomRemoveConfirmTitle` → «Remover todos os baixados?».
- `offlineColdigomSignInPrompt` → «Entre com Google para ver os seus tipos favoritos primeiro».

### 9.3 Entram
- `offlineSectionTitle`: «Baixar para usar offline» / «Download for offline use».
- `offlineKindsAll`: «Tipos» / «Types» (lista sem login).
- `playlistShareLegacyLinkUnsupported` (§4.4).

### 9.4 Ficam (valores neutros, chave com «coldigom» no nome; não se renomeiam)
- `coldigomFilterTonality`/`Rhythm`/`Category`/`Tags`/`Materials`: passam a rotular os filtros únicos.
- `coldigomMeta*`.
- Os outros `offlineColdigom*`.
- `searchResultNew`, `searchFreshness*`.
- **Marca:** `appTitle`, `browserTitle*`, `leafletShareSubject`, `leafletShareQrCaption`, `playlistShareOptionLinkSubtitle`, `authSignInOpenInBrowserHint`, `contributeTitle`.

## 10. Testes

Piso: `flutter analyze` + `flutter test` verdes, sem depender de dart-defines (a CI corre sem `COLDIGOM_API_BASE_URL`/`PLPCG_API_BASE_URL`). Hoje: 2912 testes em 424 ficheiros; 80 ficheiros tocam em símbolos deste trabalho.

### 10.1 Apagar (testam uma unidade que sai)

- **Manifesto e catálogo:**
  - `test/helpers/louvores_manifest_test_helpers.dart`;
  - `test/unit/features/catalog/`: `catalog_checksum_poll_provider_test`, `catalog_local_datasource_test`, `catalog_remote_datasource_test`, `catalog_repository_impl_test`, `filter_by_material_and_arranjo_test`, `filter_by_special_arrangement_test`, `find_louvor_by_pdf_id_test`, `louvor_classification_special_test`, `louvor_short_id_test`, `louvores_by_pdf_id_provider_test`, `louvores_manifest_notifier_test`, `manifest_material_aliases_test`, `pdf_ids_by_short_id_provider_test`, `plpcg_search_index_test`, `poll_manifest_checksum_test`, `search_louvor_by_number_or_text_test`;
  - `test/fixtures/louvores_manifest_sample.json` e `manifest_coldigom_sample.json`, se ficarem sem uso.
- **Biblioteca:** `test/unit/features/library/browse_library_test`, `library_catalog_mode_provider_test`; `test/widget/features/library/library_catalog_mode_toggle_test`; `test/widget/features/catalog/category_filters_test`.
- **Offline:** `test/unit/features/offline/download_missing_pdfs_test`, `get_offline_stats_by_category_test`, `offline_available_store_test`, `offline_bulk_download_provider_test`, `remap_pdf_ids_after_catalog_update_test`, `clear_offline_cache_test` (se `ClearOfflineCache` por categoria sair).
- **Ao vivo e compartilhar:** `test/unit/features/live/live_coldigom_only_test`; `test/unit/features/playlists/share_link_shortener_remote_test`.

### 10.2 Adaptar

- **Id-space e fixtures:**
  - `catalog_source_test` passa a testar só o `ColdigomCatalogSource`;
  - `catalog_material_lookup_test`, `resolve_catalog_material_test`, `louvor_group_audio_test`, `louvor_group_materials_test`, `louvor_praise_id_test`;
  - `home_search_provider_test`, `home_remote_search_provider_test`, `known_praise_ids_provider_test`;
  - `test/integration/uc01_search_home_test`, `test/unit/core/database/isar_smoke_test` (sai o `LouvorCache`).
- **Outras features:**
  - áudio: `audio_follow_reader_provider_test`, `find_material_for_group_test`, `swap_material_group_test`;
  - carrossel: `carousel_items_provider_test` (sem `source`);
  - cifras: `chord_carousel_navigation_test`, `chord_material_adapter_test`;
  - coldigom: `adopt_coldigom_search_novelties_test`, `coldigom_catalog_hydration_test` (+ caminho em memória, + mapa `shortId`), `coldigom_louvor_adapter_test`, `coldigom_praise_cache_warmup_test`, `sync_coldigom_catalog_test` (+ desfecho em memória);
  - ao vivo: `live_material_choice_test`.
- **Offline:** `fetch_and_store_pdf_test`, `migrate_offline_storage_test` (+ passo 5), `offline_pdf_repository_test`, `offline_reconcile_provider_test`, `offline_test_helpers`, `resolve_pdf_for_reader_test`.
- **Leitor:** `pdfrx_idle_preloader_test`, `reader_carousel_actions_provider_test`.
- **Playlists:**
  - `active_playlist_editor_test`: sai o caso «transmitindo ao vivo, só entra material Coldigom»;
  - `generate_playlist_share_url_test`: reescrito para `?p=`;
  - `playlist_share_actions_test`: saem os casos do diálogo Coldigom e entra «lista com áudio/cifra partilha link com QR».
- **Widget:**
  - `carousel_louvor_chip_test`: assere `AppColors.title` no lugar do preto (:295-328);
  - `carousel_chips_test`, `carousel_swap_material_sheet_test`;
  - `home_empty_state_test`: texto neutro do aviso offline e título do teste;
  - `louvor_group_card_*_test` (4), `material_sheet_*_test` (5), `open_material_provider_test`;
  - `play_audio_in_session_storage_test`, `play_entry_points_active_queue_test`;
  - `library_screen_error_test`: um só caminho de erro, com `catalogLoadError`, e sai o `lastGood`;
  - `offline_settings_screen_test`: uma secção, um «Atualizar»;
  - `offline_settings_screen_coldigom_test`: textos de «Remover todos», e sem login vê «Tipos»;
  - `live_session_banner_test`: sai o caso «Retomar com material PLPCG».
- **Contribuições:** `contribution_draft_test`, `contribute_screen_test`.

### 10.3 Novos

- `matchesCatalogFilters`:
  - cada filtro;
  - OU dentro de um filtro e E entre filtros;
  - tag pai inclui filhos;
  - tipo de material por `materialKindId`;
  - grupo sem meta.
- Opções de filtro derivadas do índice: só valores com ≥1 praise; tipos por nome.
- Pipeline da /biblioteca: filtros → ordenar (número/nome) → paginar; índice vazio → loading; sync falhado → erro + retry.
- Hidratação em memória sem Isar; mapa `shortId → praiseId`.
- Share `?p=`:
  - geração por praise (material movido usa o praise do catálogo, não o do path);
  - erro em praise sem `shortId`;
  - parse (token `[0-9a-f]{3,8}`, maiúsculas, desconhecidos);
  - import com e sem favoritos;
  - link antigo → mensagem nova.
- `NormalizeLegacyMaterialIds`:
  - cada store da tabela §6.2;
  - desconhecidos;
  - sem ids legados = sem rede;
  - sem rede = pendente;
  - preserva `conflict`;
  - colisão no índice offline e no `pdfLastPages`;
  - sufixo `#n`.
- `ColdigomRemoteDatasource.resolveLegacyPdfIds`: lotes de 500, id derivado do `url`.
- Script D1: teste do transformador puro (linha → linha nova + relatório) com `items` e com `pdf_ids` antigos.
- `MigrateOfflineStorage` passo 5.

## 11. Entrega, ordem e validação

**Unidades, uma ou mais tarefas de plano cada, com execução por subagentes em worktree:**
1. **coldigom:** §7.1 + §7.2, com PR e deploy no coldigom. **Pré-requisito** de 3 e 4.
2. **Filtros, /biblioteca e página inicial (§2).**
3. **Normalizador + fim do manifesto + /offline (§3.1, §6.2, §6.4).** O normalizador precisa do endpoint de 7.2.
4. **Compartilhar + ao vivo + cor (§3.2, §4, §5).** Precisa do `shortId` de 7.1.
5. **Script D1 (§6.3)**, escrito junto com 3 e **corrido só depois do deploy do app**.
6. **Docs:**
   - `docs/features/FEATURE_INDEX.md`: `catalog`, `library` (sem toggle), `offline` (uma secção), `playlists`/`carousel` (link por praise, sem gate), `live` (sem regra «só Coldigom»), «Débitos técnicos» (gate pago) e a linha `CarouselBarTrailingActions`;
   - `docs/features/LOUVOR_GROUPING.md`: sem manifesto;
   - `docs/use-cases/UC-09-configure-offline.md`;
   - os specs de 18/09, 13/09 (share) e 12/09 (ao vivo) ganham a nota «substituído por este spec» nas secções afetadas.

As unidades 2–4 saem **juntas** numa versão do app: não há estado intermédio publicável sem manifesto e com o gate de share vivo. Commits por unidade; nada é pushado, mergeado ou deployado sem pedido.

**Validação manual em prod v2 (pós-deploy):**
1. /biblioteca sem seletor de fonte: filtrar por tag «CIAs» + tipo «Cifra I»; ordenar por nome; paginar. Também offline (modo avião) depois do 1.º sync.
2. Página inicial: buscar «a ti senhor» com e sem filtro; «novos» respeitam o filtro.
3. Arranque a frio numa janela privada (sem Isar): a página inicial e a /biblioteca carregam pelo caminho em memória; medir o tempo até ao 1.º card.
4. /offline sem login: lista «Tipos»; baixar «Gestos CIAs» até o fim; «Remover todos os baixados».
5. Playlist antiga com ids legados (conta com listas de antes de 20/09): as entradas abrem depois do arranque; o índice offline mostra os PDFs já baixados sem os baixar de novo.
6. Share de lista com PDF + áudio + cifra: link `https://v2.plpcg.com/?p=…&n=…`, folheto com QR; importar noutro aparelho com e sem login (favoritos aplicados).
7. Link antigo `?s=…`: mensagem de link antigo.
8. Ao vivo: pôr no ar uma lista que antes era recusada; o chip do carrossel é vinho em todo o lado.
9. Rede: nenhuma chamada a `/api/plpcg/manifest*`, `/api/praises/filters` ou `/api/materials/kinds` na página inicial ou na /biblioteca.

## 12. Follow-ups (fora desta entrega)

- **Worker `plpcg-catalog`:** remover `/api/catalog/*`, `/l/*`, `/api/links*` e a tabela `louvores`/`short_id` quando o plpcjf for desligado. O `ORIGIN = https://plpcg.com` dos redirects `/l/` e `/ao-vivo/` aponta para o plpcjf; rever para `v2.plpcg.com` nessa altura.
- **Universal Links nativos para `v2.plpcg.com`:** hoje o entitlement só tem `applinks:plpcg.com`, portanto no app nativo o link novo abre no browser.
- **Remover `NormalizeLegacyMaterialIds` e `resolveLegacyPdfIds`** quando deixar de haver ids legados (o log do normalizador conta os casos).
- **Qualidade de dados no coldigom (M5):** unificar valores duplicados de categoria e ritmo.
- **coldigom:** congelar `/api/plpcg/manifest*` quando não houver builds antigas em uso.
- **Remover `LouvorCacheSchema` do schema Isar** depois de medir a limpeza do passo 5 na web (SQLite) — ver §13, Plano 3, desvio 3.

## 13. Estado implementado e desvios

Os quatro planos (0 coldigom, 1 catálogo, 2 share/ao vivo/cor, 3 ids legados/manifesto/offline/D1/docs) estão implementados na branch `feat/fim-fonte-plpcg` (HEAD `0e6c6b08`). Esta secção regista as decisões tomadas durante a execução que mudam o que os §§1–12 descrevem — não os ajustes por tarefa (nits), que ficam só nos `progress.md` de cada plano.

### Plano 0 — coldigom (`praises.short_id` + crosswalk)

- **§7.2 — `praiseId` do crosswalk é o dono *atual* do material** (`praise_materials.praise_id`), não o `plpcg_crosswalk.praise_id` que o `/resolve` devolve: merge e move trocam o dono, e o crosswalk desatualizado apontaria para o praise errado. Mesmo motivo por que a `url` também vem do `r2_key` real, não do crosswalk. Sem isto, um material movido depois do crosswalk resolvia para o praise antigo.

### Plano 1 — catálogo, filtros, /biblioteca, página inicial

- **`shortId` autocurativo via reset de ETag:** `SyncColdigomCatalog` não envia `If-None-Match` quando o índice tem linhas mas nenhuma tem `shortId` — sem flag de controlo. Achado Critical da revisão final: sem isto, uma instalação que sincronizou antes do deploy do `short_id` no coldigom (plano 0) nunca o recebia, porque o `304` do ETag nunca deixava o dump completo passar de novo.
- **Reconexão dispara sync sempre que o catálogo está `failed`**, substituindo a regra original «só na transição offline→online» — a web não emite um valor inicial de conectividade, então a transição nunca disparava lá. Achado Important da revisão final; custo aceito: um sync extra deduplicado em alguns casos.

### Plano 2 — compartilhar, ao vivo, cor

- **O share salta entradas órfãs em vez de falhar a lista inteira** (desvio do spec §4.2): uma entrada cujo id **não** é id coldigom (legado que o crosswalk não conhece) é saltada; entradas coldigom sem praise/`shortId` continuam a falhar o share + disparar sync, como o spec pedia. Motivo: depois do plano 3 uma órfã nunca abre em lado nenhum, e falhar a lista inteira por causa dela bloquearia o share para sempre.
- **Os dois lados do link por praise avisam quando algo fica de fora:** quem envia vê aviso quando órfãs saem do link; quem importa vê «N louvores ficaram de fora» pelos saltados (praise sem nada adicionável). Achado da revisão final (Important: descarte silencioso de praises sem PDF/áudio).
- **Import cai para cifra/gestos quando não há PDF nem áudio:** `preferredEntryForPraise` ganhou um terceiro nível de fallback (PDF → áudio → cifra/gestos) para praises que só têm esses materiais.

### Plano 3 — ids legados, fim do manifesto, `/offline`, script D1

Os sete desvios decididos ao planear (topo do plano, `docs/superpowers/plans/2026-09-23-fim-fonte-plpcg-3-manifesto-offline-migracao.md`):

1. `LouvorPdfPath` fica, simplificado — ainda monta `/assets/praises/<praise>/<material>.pdf` a partir do `pdfId` para todo PDF coldigom; só o ramo do `pdf` absoluto do manifesto sai.
2. `contributionSourceOf` é apagado — com um valor só (`ContributionSource.coldigom`), os três chamadores passam a constante direto; `ContributionSource` fica.
3. **`LouvorCache` sem passo de limpeza no `MigrateOfflineStorage`, como planeado ao início — mas revertido na Task 11:** a sonda em VM (`isar_plus` 1.3.7 nativo, 2026-09-23) mediu que abrir a instância com um schema sem a coleção **apaga os dados dela** sozinho, mas isso não foi medido na web (SQLite) — arriscaria o Isar não abrir lá. Por isso o `LouvorCacheSchema` **fica** no schema Isar, marcado obsoleto e sem consumidores de leitura, e os dados são limpos explicitamente no passo 5 do `MigrateOfflineStorage`; tirar a coleção do schema vira follow-up depois de medir na web (item 10 da validação manual, Tarefa 15, e follow-up acima).
4. Um só «Atualizar» no `/offline` — o botão da linha de estado faz `coldigomCatalogSyncProvider.sync()` **e** `offlineCacheStatusProvider.refreshAll()` (reconcile) numa ação só, em vez de dois controlos separados.
5. `ResolvePdfForReader` perde `isFullOfflineMode` e `hasNetworkConnection` — só existiam para a flag `OFFLINE_AVAILABLE`; sem ela, o caminho passa a ser sempre o fetch on-demand com LRU.
6. Saem chaves l10n mortas não listadas no spec (`offlineDownloadSelected`, `offlineMaintenanceBusy`, `offlineMissingLouvoresEmpty`, `offlineMissingLouvoresLoadError`, `offlineMissingLouvoresSheetTitle`), conferidas por grep antes de apagar.
7. **«Sem gatilho extra ao voltar a rede», como planeado — revertido na Task 6 (ruling 6.4):** o normalizador (`NormalizeLegacyMaterialIds`) passou a correr também na transição offline→online (deduplicado), além do hydrate da sessão e de cada pull de playlists. Motivo: com o crosswalk fora do ar, sem este terceiro gatilho os ids legados só normalizavam no próximo hydrate/pull, que podia demorar. Reruns concorrentes coalescem: uma rodada em voo marca um novo pedido e corre **uma** rodada extra ao terminar, em vez de perder ids trazidos por um pull no meio do caminho.

Outras decisões de design do plano 3, fora da lista acima:

- **Listas de conta estranha (`ownerSub` ≠ sessão atual, incluindo deslogado) são normalizadas mantendo o `syncStatus`** — uma lista `synced` continua `synced`, preservando a purga na troca de conta; a normalização do lado do servidor para essas listas fica a cargo do script D1 (§6.3) ou espera a conta dona voltar.
- **Segurança do script D1** (`migrate-legacy-playlist-ids.ts`): exige `--local`/`--remote` explícito (rejeita flags desconhecidas, nunca corre "às cegas"); relata as linhas saltadas pela guarda de versão (re-`SELECT` pós-escrita, contra escrita concorrente); o runbook pede um bookmark de time-travel do D1 antes de rodar e documenta o comando de restauro.

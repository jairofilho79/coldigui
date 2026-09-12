# Oportunidades de melhoria — Web (PLPCG / coldigui)

**Criado em:** 2026-09-02  
**Branch:** `web/integration` @ `6f5a181` (auditoria) · **Onda 1 executada em 2026-09-03** (seção **H**) · **Onda 2 executada em 2026-09-04** (seção **I**) · **Onda 3 executada em 2026-09-11** (seção **J**) · **Onda 4 executada em 2026-09-12** (seção **K**); itens implementados estão marcados ✅/🟡 no próprio bloco.  
**Objetivo:** primeira leva de refatorações para dar sustentação às features grandes que vêm (viewer de gestos, sync de listas, Social, Eventos, plugins, favoritos de material), priorizando a versão web.  
**Método:** leitura direta do código em cinco frentes (performance web, estabilidade, UX/produtividade, fluxo playlist + áudio + PDF, arquitetura), `flutter analyze` e `flutter test`, e verificação item a item dos backlogs anteriores em `docs/`. Cada achado traz `arquivo:linha`. Onde a consequência não foi reproduzida, está marcado **[inferência]**.

Legenda: **Esforço** S (horas) / M (1–3 dias) / L (semana+). **Conf.** = confiança de que o achado é real.

---

## 0. Sinais objetivos da árvore limpa

| Sinal | Na auditoria (`6f5a181`) | Após a onda 1 (2026-09-03) | Após a onda 2 (2026-09-04, `ba3801b`) | Após a onda 3 (2026-09-11, `442eb66`) | Após a onda 4 (2026-09-12, `89f96e4`) |
|---|---|---|---|---|---|
| `flutter analyze` | 1 info (lint em teste) | 1 info (o mesmo) | 1 info (o mesmo) | **0** | **0** |
| `flutter test` | **4 falhas** em 798 testes | **0 falhas** em 1076 testes | **0 falhas** em 1503 testes (+ 76 no Worker) | **0 falhas** em 1832 testes (+ 84 no Worker, `tsc` no CI) | **0 falhas** em 2146 testes (+ 96 no Worker) |
| `flutter test --platform chrome test/web` | não medido | verde após `@TestOn('vm')` em `web_index_perf_test.dart` | verde (7) | não re-executado nesta onda | não re-executado nesta onda |
| Cobertura | 171 arquivos de teste; 0 goldens; 0 testes de boot/Isar degradado/auth | +1 teste Chrome de provider (`test/web/pdf_reader_offline_preserved_web_test.dart`); ainda 0 goldens e 0 testes de boot/Isar degradado | testes de modo degradado (Isar indisponível) em playlists, offline, deep link e áudio; Worker com D1 fake (76); ainda 0 goldens | testes de boot com Isar abrindo (hidratação, manifest), troca de conta com Isar real, editor da lista ativa com Isar real, Worker social/audio-flags com D1 fake (84); ainda 0 goldens | `test/support` (fakes compartilhadas, `pumpApp`, overrides padrão), testes de layout largo (rail, split view, colunas), fullscreen web com porta fake, Worker links (96); ainda 0 goldens |

As 4 falhas têm a mesma causa: `PdfSourceResolver` aceita `apiBaseUrl` no construtor mas o ignora, porque `_joinApiUrl` passou a chamar `AssetBaseUrlResolver.joinAssetUrl` (global) no commit `c85c567`. Ver item **B0**.

---

## 1. Top 12 — maior retorno por esforço

| # | Item | Eixo | Esforço | Status (2026-09-03) |
|---|---|---|---|---|
| A1 | Manifest inteiro (1,45 MB) rebaixado e regravado no Isar em **todo boot**, na UI thread | Perf | S–M | ✅ `7a283dc` |
| A2 | Fontes: `--no-tree-shake-icons` + fontes variáveis inteiras ≈ 3 MB antes do 1º frame | Perf | S | ✅ `3e4af1a` |
| A3 | Abrir louvor = cadeia serial (playlist → warmup Coldigom → resolve PDF) antes de navegar | Perf | S–M | ✅ `0753efe` |
| B1 | Boot offline ou 5xx **apaga a sessão** do usuário | Estab. | S | ✅ `8699fc7` (+ B0 `011f8a9`) |
| B2 | Falha de init do pdfrx/GIS fica memoizada; "Tentar novamente" nunca funciona | Estab. | S | ✅ `1a17f05` |
| B3 | Qualquer erro ao abrir PDF local **deleta o PDF offline** | Estab. | M | ✅ `3a7c0e7`, `2d4a824` |
| B4 | Web: `QuotaExceededError` engolido → bulk "concluído" com 0 PDFs | Estab. | M | ✅ `2527ea0`, `6c5cc19` |
| C1 | Zero atalhos de teclado fora das setas do leitor; busca sem autofocus/Enter | UX | M | ✅ `4547891`…`c595a57` |
| C2 | Sem wakelock no leitor/cifra/player (tela apaga no meio do louvor) | UX | S | ✅ `4547891` |
| D1 | Não existe ponte áudio ↔ partitura do mesmo louvor (o cerne do "ouvir enquanto lê") | Playlist | M | ✅ `fa97e7c`…`f63d52d` |
| D2 | Modelo de lista ainda é duas filas (`pdfIds` × `audioIds`), contra o PRODUCT.md | Playlist/Arq | L | 🟡 fatia 1 (modelo + wire v2) — ver D2 |
| E1 | Não há abstração `Material`; tudo é `pdfId` com ramos por tipo (bloqueia gestos e favoritos) | Arq | L | 🟡 fatia 1 (`MaterialKind` + `CatalogMaterial` + opener) — ver E1/E2 |

---

## A. Performance web

Fatos de plataforma que sustentam vários itens: `compute()` na web roda **na thread principal**; Isar Plus na web não tem `writeAsync`/`readAsync` (toda leitura/escrita é síncrona na UI thread).

### A1. Refresh completo do catálogo em todo boot
- **Evidência:** `lib/features/catalog/presentation/providers/louvores_manifest_provider.dart:29-36` — com cache, `unawaited(_refreshFromRemote())` sempre. `catalog_local_datasource.dart:24-33` faz `clear()` + ~4600 `put` numa `isar.write` síncrona. O Worker não emite `ETag` em `/louvores` (`workers/plpcg-catalog/src/index.ts:167-178`); existe `/checksum` mas só é usado no foreground.
- **Efeito:** 1,45 MB por abertura em rede ruim; decode + regravação bloqueiam a UI justo quando o usuário começa a digitar; `state = AsyncData` reexecuta busca, biblioteca, carousel e playlists mesmo sem mudança.
- **Fix:** no boot, consultar `/checksum` (com `If-None-Match`) e só baixar se mudou; `ETag`/304 na rota; não emitir novo estado se o conteúdo for igual.
- **Esforço:** S–M · **Conf.:** alta
- ✅ **Implementado (2026-09-03)** — `7a283dc`: `CatalogRepository.syncManifest({cached, knownChecksum})` → `ManifestSyncOutcome`; `/checksum` condicional no boot, `ETag`/304 em `/api/catalog/louvores` (Worker `fetchLouvores`), `_isSameManifest` evita reemitir estado igual.

### A2. ~3 MB de fontes no caminho crítico
- **Evidência:** `scripts/web_build.sh:38` — `--no-tree-shake-icons`; `MaterialIcons` 1,6 MB + EBGaramond 851 KB + OpenSans 533 KB em `FontManifest.json`. A justificativa do comentário (cache stale) já foi resolvida pelo hash no nome (`scripts/cache_bust_web_entrypoints.sh:1257-1263`).
- **Fix:** reativar tree-shake; subsetar as fontes para Latin e remover eixo `wdth` do OpenSans; `<link rel=preload as=font>`.
- **Esforço:** S · **Conf.:** alta
- ✅ **Implementado (2026-09-03)** — `3e4af1a`: `scripts/subset_fonts.sh` (EBGaramond 851 KB → 192 KB, OpenSans 533 KB → 98 KB, originais em `assets/fonts/source/`), tree-shake de ícones reativado, `<link rel=preload as=font>` no `index.html`.

### A3. Abrir louvor bloqueia até rede do Coldigom responder
- **Evidência:** `lib/features/catalog/presentation/utils/open_louvor_in_reader.dart:26-46` — `await addLouvorToActivePlaylist` → `await ensureColdigomPraiseMaterialsCached` (pode ir à rede, sem try) → `await resolveLouvorPdf` → só então `push`. Mesmo padrão em `reader_carousel_actions_provider.dart:61`.
- **Efeito:** o gesto mais frequente do culto fica "morto" mesmo com PDF em cache. Coldigom fora do ar impede abrir PDF Coldigom já baixado.
- **Fix:** navegar primeiro (leitor já tem skeleton) e rodar playlist/warmup em paralelo com `unawaited` e timeout curto; warmup best-effort.
- **Esforço:** S–M · **Conf.:** alta
- ✅ **Implementado (2026-09-03)** — `0753efe`: `open_louvor_in_reader.dart` resolve o PDF e adiciona à playlist em paralelo (`Future.wait`), warm-up Coldigom `unawaited` com `coldigomWarmupDefaultTimeout`; Coldigom fora do ar não impede abrir PDF já em cache.

### A4. Mapas O(catálogo) reconstruídos a cada mutação de carousel/playlist
- **Evidência:** `lib/features/carousel/presentation/utils/build_carousel_metadata_map.dart:13-23`, `carousel_louvores_provider.dart:43-48`, `playlists_provider.dart:75-81,449` ("Lookup O(n)").
- **Fix:** `Provider<Map<String, Louvor>>` por `pdfId` derivado do manifest (1× por manifest).
- **Esforço:** S · **Conf.:** alta
- ✅ **Implementado (2026-09-11, onda 3)** — `19e49e8`, `4175b9c`: `louvoresByPdfIdProvider` (mapa `pdfId → Louvor` construído uma vez por manifest); `buildCarouselMetadataMap` e `_buildLabelMap` apagados; `findLouvorByPdfId` O(1).

### A5. Cada card visível dispara uma query Isar síncrona para o badge offline
- **Evidência:** `lib/features/catalog/presentation/widgets/louvor_group_card.dart:291-293` — `FutureProvider.autoDispose.family` por `pdfId` → `findFirst()` síncrono.
- **Fix:** provider único `Map<String,bool>` atualizado por `upsert/remove/clearAll`; cards usam `select`.
- **Esforço:** S–M · **Conf.:** alta
- ✅ **Implementado (2026-09-11, onda 3)** — `4fbd4a7`: `offlineAvailabilityMapProvider` (mapa único lido de forma síncrona do índice) invalidado por `offlineIndexRevisionProvider` (bump a cada escrita do datasource); o card usa `select`; o `FutureProvider.family` por card saiu.

### A6. Cálculo de quota na web itera toda a Cache Storage, até 3× por PDF baixado
- **Evidência:** `lib/features/offline/domain/usecases/fetch_and_store_pdf.dart:57-84` chama `totalCachedBytes()` 3×; na web `pdf_storage_web.dart:78-90` materializa cada blob. `sumFileSizes()` via índice Isar já existe (`offline_pdf_local_datasource.dart:97-100`) e não é usado.
- **Efeito:** com centenas de PDFs offline, abrir um PDF novo custa segundos extras.
- **Esforço:** S · **Conf.:** alta
- ✅ **Implementado (2026-09-12, onda 4)** — `8d51dfb`: `totalCachedBytes()` lê `sumFileSizes()` do índice Isar (O(1) por índice); o scan do Cache Storage fica só para a estatística por categoria e o reconcile; com Isar indisponível a quota não desaloja nada (direção segura).

### A7. Estado do player substituído a ~5 Hz e observado inteiro pelo shell
- **Evidência:** `lib/features/audio_player/presentation/providers/audio_player_session_provider.dart:105-111` — `positionStream.listen((p) => state = state.copyWith(position: p))`; `carousel_chips.dart:48`, `audio_player_screen.dart:28` fazem `watch` total.
- **Fix:** posição em provider próprio; `select` nos consumidores; throttle do `setPositionState` a 1 Hz.
- **Esforço:** S · **Conf.:** alta
- ✅ **Implementado (2026-09-11, onda 3)** — `a0f841b`: `audioPlayerPositionProvider` separado da sessão; `CarouselChips`/`CarouselAudioFaceBar`/player observam com `select`; media session a 1 Hz (`MediaSessionPositionThrottle`).

### A8. Boot serializado: Isar (WASM + OPFS) gate-a o app antes do manifest começar a baixar
- **Evidência:** `lib/bootstrap_app.dart:17-31`; `louvores_manifest_provider.dart:26-27` espera `isarAvailableProvider`.
- **Fix:** iniciar fetch do `/checksum`/manifest em `main()` guardando o `Future`; montar `ColdiguiApp` já no `loading` do Isar (o `StorageRequiredGate` já cobre as áreas que exigem storage).
- **Esforço:** M · **Conf.:** média-alta
- ✅ **Implementado (2026-09-11, onda 3)** — `a165b10`, `7d0edaa`, `98f8139`: `IsarStatus {opening, available, unavailable}`; `ColdiguiApp` monta durante a abertura do Isar; `StorageRequiredGate` mostra «Preparando armazenamento…»; o `/checksum` sai em paralelo à abertura e o checksum do boot só é gravado quando o manifest realmente entrou; a hidratação da sessão espera o Isar (`awaitIsarSettled`) e nunca apaga a lista ativa sem storage.

### A9. PWA sem cache de shell: entrypoints `no-cache` e SW do Flutter 3.35 se desregistra
- **Evidência:** `web/_headers:8-27`; `build/web/flutter_service_worker.js` (stub que faz `unregister`). A Fase C da doc está marcada como "immutable", mas foi revertida (`e99558b`).
- **Efeito:** ≥8 revalidações condicionais por abertura; sem rede, o PWA instalado não abre mesmo com catálogo e PDFs locais.
- **Fix:** hash de conteúdo no nome do arquivo + `immutable`; SW próprio (precache dos entrypoints + `stale-while-revalidate` do `index.html`); no mínimo `stale-if-error`.
- **Esforço:** M–L · **Conf.:** média (decisão anterior foi deliberada; validar na CDN)

### A10. Busca/biblioteca rodam na UI thread sem índice
- **Evidência:** `home_search_provider.dart:71` (`compute` = no-op na web); `search_louvor_by_number_or_text.dart:17-19,60-65` normaliza o `numero` de 4600 louvores por query.
- **Fix:** `numeroNorm` pré-computado; índice em memória 1× por manifest; chunks com yield ou Web Worker se a medição justificar.
- **Esforço:** M · **Conf.:** média (falta medição)
- 🟡 **Fatia 1 (2026-09-11, onda 3)** — `2f19870`: `PlpcgSearchIndex` construído uma vez por manifest (`numeroNorm` pré-computado); a busca da Home roda síncrona sobre o índice, sem `compute` (no-op na web) nem cópia do catálogo por tecla. A Biblioteca continua no pipeline antigo.
- ✅ **Fechado (2026-09-12, onda 4)** — `d38adce`: a Biblioteca não tem busca textual (só filtros), então a «fatia 2» não tinha alvo; apagados `searchLouvorByNumberOrTextProvider` e o `call()` não indexado sem chamador.

### A11. `pdfium.wasm` (5,2 MB) prefetchado logo após o 1º frame, competindo com o manifest
- **Evidência:** `lib/features/pdf_reader/data/pdfrx_bootstrap.dart:24-28`; `connectivity_results.dart:16-24` trata web como não-medida.
- **Fix:** agendar só depois do manifest em `data` + N s ocioso; respeitar `saveData`/`effectiveType`; ou disparar no primeiro hover num card.
- **Esforço:** S · **Conf.:** média
- ✅ **Implementado (2026-09-11, onda 3)** — `98dbc45`: `PdfrxIdlePreloader` só agenda o `pdfium.wasm` depois de o manifest ter valor ou erro **e** 3 s de folga (`Timer` cancelado no dispose); respeita `saveData` na web quando existir.

### A12. Busca Coldigom sem cancelamento/memoização; warmup N+1 serial no boot
- **Evidência:** `home_search_provider.dart:187-190`; `coldigom_praise_cache_warmup.dart:21-49` (`for … await fetchDetail`), chamado em `playlist_session_hydrate.dart:70-73`.
- **Fix:** `CancelToken` por geração; LRU `(query,page)`; `Future.wait` com concorrência 3–4 e timeout.
- **Esforço:** S–M · **Conf.:** média-alta
- ✅ **Implementado (2026-09-11, onda 3)** — `2f19870`, `f886ccb`, `702e1a3`, `d7060cf`: `CatalogSource.search` com `SearchCancellation` → `CancelToken`; `homeRemoteSearchProvider` (`FutureProvider.autoDispose.family` por `(query, página)`, `retry: null`, `keepAlive` de 10 min no sucesso); warmup do boot com concorrência 3.

### A13. Leitor sem teto de raster/memória na web × LRU de 3 sessões
- **Evidência:** `pdf_reader_pdf_view.dart:364-385` (`PdfViewerParams` sem `getPageRenderingScale`/`maxImageBytesCachedOnMemory`); `pdf_session_cache.dart:7`.
- **Fix:** escala ≤ `2×dpr`, ~32 MB em `kIsWeb`, `maxSize` 2 na web.
- **Esforço:** S · **Conf.:** média
- ✅ **Implementado (2026-09-12, onda 4)** — `aca420f`: `getPageRenderingScale` ≤ 2 × dpr e `maxImageBytesCachedOnMemory` = 32 MiB na web (por `PlatformCapabilities`); `PdfSessionCache` com `maxSize` 2 na web e 3 no nativo.

### A14. Cifra re-layouta a música inteira a cada transposição/tamanho de fonte
- **Evidência:** `chordpro_view.dart:69-86,110-130,167-169` — `Column` de `Wrap`, `transposeChordLabel` por célula por build.
- **Fix:** `SliverList` por linha + memoização por `(chord, semitones, preferFlats)`.
- **Esforço:** S–M · **Conf.:** média
- ✅ **Implementado (2026-09-12, onda 4)** — `9500380`: corpo da cifra em `CustomScrollView` + `SliverList.builder` por linha; `TransposeLabelMemo` (`(acorde, semitons, bemóis)` → rótulo, teto 512).

### A15. Bottom nav: `TextPainter.layout()` no `build` durante animação (regressão do V2-A5)
- **Evidência:** `plpcg_bottom_nav_bar.dart:323-329,342` (revertido em `e24aa3f`).
- **Esforço:** S · **Conf.:** alta
- ✅ **Implementado (2026-09-12, onda 4)** — `e4783f2`: largura do rótulo calculada em `initState`/`didUpdateWidget` (só quando o rótulo muda), nunca no `build`.

### A16. Bundle publica `assets/fixtures/sample.pdf` (1,95 MB) e `NOTICES` (1,45 MB)
- **Evidência:** `pubspec.yaml:69`; único uso em `lib/` é comentário.
- **Esforço:** S · **Conf.:** alta

---

## B. Estabilidade e tratamento de erros

### B0. 4 testes falhando: `PdfSourceResolver.apiBaseUrl` é ignorado
- **Evidência:** `lib/features/pdf_reader/data/utils/pdf_source_resolver.dart:78-81` — `_joinApiUrl` chama `AssetBaseUrlResolver.joinAssetUrl` (lê `AppConfig` global), ignorando o campo `apiBaseUrl` injetado. Regressão de `c85c567`.
- **Fix:** passar `apiBaseUrl` ao resolver de asset (ou remover o parâmetro e ajustar os testes). CI deveria estar vermelho; conferir por que `.github/workflows/web.yml` não bloqueou.
- **Esforço:** S · **Conf.:** alta
- ✅ **Implementado (2026-09-03)** — `011f8a9`: `AssetBaseUrlResolver.joinAssetUrl(path, baseUrl:)`; os 4 testes de `PdfSourceResolver` voltaram a passar.

### B1. Boot offline (ou Worker 5xx) apaga a sessão
- **Evidência:** `lib/features/auth/presentation/providers/auth_state_provider.dart:43-51` — `on Object { store.clear(); return null; }`; `auth_remote_datasource.dart:27` trata 5xx como exceção.
- **Efeito:** abrir a PWA no culto sem rede desloga; ao voltar a rede, `syncAfterLogin` remarca tudo como pendente.
- **Fix:** limpar só em 401/403; em rede/5xx manter sessão "não verificada" e revalidar depois.
- **Esforço:** S · **Conf.:** alta
- ✅ **Implementado (2026-09-03)** — `8699fc7`: `AuthUnauthorizedException` no datasource; a sessão só é limpa em 401/403, rede/5xx mantém a sessão armazenada.

### B2. Falhas memoizadas em `static Future?` (pdfrx e GoogleSignIn) + `retry: null`
- **Evidência:** `pdfrx_bootstrap.dart:15-17` (`??=`), `auth_state_provider.dart:59-61`, `main.dart:17`; `deferred_route_loader.dart:33-48` re-aguarda o mesmo future no "Tentar novamente".
- **Efeito:** primeiro `/leitor` com rede ruim → erro permanente até recarregar a aba. GIS bloqueado → perfil/Social mortos.
- **Fix:** `catchError` que zera o cache; init de auth falhando = "deslogado + indisponível", não erro do provider.
- **Esforço:** S · **Conf.:** alta
- ✅ **Implementado (2026-09-03)** — `1a17f05`: `lib/core/utils/retryable_init.dart` (Future rejeitado não fica memoizado) aplicado a pdfrx, Google Sign-In e `deferred_route_loader`; "Tentar novamente" funciona.

### B3. `catch` amplo apaga o PDF offline e chama de "corrompido" para qualquer erro
- **Evidência:** `pdf_reader_document_provider.dart:65-75` — `on Object catch (_)` → `_removeCorruptedLocalPdf`; na web `readBytes` devolve `null` para qualquer exceção da Cache API (`pdf_storage_web.dart:106-117`).
- **Efeito:** erro transitório de storage no Safari = louvor perdido sem rede.
- **Fix:** só remover com evidência real (magic bytes via `pdf_integrity_validator.dart`, ou erro de formato do pdfium); senão "não foi possível ler" + retry.
- **Esforço:** M · **Conf.:** média
- ✅ **Implementado (2026-09-03)** — `3a7c0e7` + `2d4a824`: `classifyPdfOpenFailure` (corrompido só com magic bytes inválidos nos bytes já lidos pelo adapter, ou erro de formato do pdfium); senão `PdfLocalReadFailedException` com retry, sem apagar; `retry: null` no `pdfReaderSessionProvider`; teste Chrome em `test/web/pdf_reader_offline_preserved_web_test.dart`.

### B4. Web: `QuotaExceededError` engolido; bulk "conclui" e marca configurado
- **Evidência:** `pdf_storage_web.dart:125-132` (`cache.put` sem try); `zip_extraction_runner_web.dart:57-68` (`failedPdfIds.add` sem abortar); `offline_bulk_download_provider.dart:265-284` chama `markConfigured()` mesmo com falhas; `failedPdfIds` nem entra no estado.
- **Fix:** mapear `QuotaExceededError` → `InsufficientDiskSpaceException`; abortar workers; não marcar configurado se tudo falhou; expor `failedCount` com l10n própria.
- **Esforço:** M · **Conf.:** alta
- ✅ **Implementado (2026-09-03)** — `2527ea0` + `6c5cc19`: `QuotaExceededError` → `InsufficientDiskSpaceException` (classificador em `domain/exceptions/quota_exceeded_classifier.dart`), abort cooperativo dos workers, não marca configurado se nada foi gravado, `failedCount` com l10n e mensagem honesta.

### B5. Isar indisponível: offline grava sem índice e o reconcile apaga tudo; deep link cria playlist fantasma
- **Evidência:** `offline_pdf_local_datasource.dart:58-64,128-138` (`put*` viram no-op silencioso); `reconcile_offline_index.dart:79-84` (índice vazio → todos os arquivos "órfãos" → apagados); `playlist_local_datasource.dart:99-105` (`insert` no-op) → `create()` devolve id inexistente → `PlaylistNotFoundException` não capturada em `sync_deep_link_state.dart:61-70`. `optionalIsarProvider` também é `null` **enquanto** o Isar ainda abre.
- **Fix:** datasources `unavailable()` lançam `StorageUnavailableException` em escrita; reconcile/bulk abortam sem Isar; deep link captura e avisa.
- **Esforço:** M · **Conf.:** alta
- ✅ **Implementado (2026-09-04, onda 2)** — `22c7c08`, `19a1e7a`, `26d4fac`: escritas sem Isar lançam `StorageUnavailableException` (offline e playlists); reconcile completo com índice indisponível ou vazio-com-arquivos é **pulado** (`ReconcileSkipped`), nunca apaga; PDF abre em modo degradado (gravado sem índice); deep link e tela de listas mostram `offlineStorageUnavailable`.

### B6. Race no `pdfReaderSessionProvider`: dispose durante `await` vaza documento e sobrescreve o handle ativo
- **Evidência:** `pdf_reader_document_provider.dart:57,78-83` — `bindHandle` e `ref.onDispose` após o `await` sem checar `ref.mounted` (Riverpod 3 lança `UnmountedRefException`).
- **Efeito:** "próximo" duas vezes rápido → setas/teclado atuam num documento invisível; handle nunca liberado (heap WASM cresce; reload da aba no iOS).
- **Fix:** `if (!ref.mounted) { handle.dispose(); return; }` após o `await`.
- **Esforço:** S · **Conf.:** alta
- ✅ **Implementado (2026-09-04, onda 2)** — `2a4ad0c`: `ref.mounted` após o `await` de `openDocument`; sessão descartada libera o handle e não religa.

### B7. Deep link/import: `Uri.queryParameters` lança em `%` malformado; `_handleUri` sem catch
- **Evidência (reproduzido em Dart):** `Uri.parse('/?sharename=%E0%A4%A&sharepdfs=a').queryParameters` → `FormatException`. Chamadores sem try: `playlist_share_url_builder.dart:84-86,119-146`, `deep_link_initial_uri.dart:9-10`, `app_router.dart:59-95`; `deep_link_listener.dart:81-101` só tem `finally`.
- **Efeito:** link truncado do WhatsApp → dialog de import não responde; no boot web, o stream de links nunca é assinado.
- **Fix:** `safeQueryParameters(uri)`; `on Object` com snackbar em `_handleUri`; dedupe por tempo em vez de fingerprint.
- **Esforço:** S · **Conf.:** alta
- ✅ **Implementado (2026-09-04, onda 2)** — `552849c`: `safeQueryParameters` (nunca lança em `%` malformado) no router, no `deep_link_initial_uri` e no builder de share; `_handleUri` com snackbar traduzido; dedupe por query com janela de 3 s.

### B8. Sync de playlists: um registro remoto malformado derruba o sync inteiro, em silêncio, para sempre
- **Evidência:** `remote_playlist.dart:39-49` (casts rígidos); `sync_playlists.dart:57` faz pull antes do push; `playlist_sync_provider.dart:99-101` — `on Object { isSyncing: false }` sem `lastError`. Mesmo padrão em `remote_audio_flag.dart:23-28`.
- **Fix:** parse tolerante por item; `lastError` no estado com banner; não bloquear push se o pull falhar por parsing.
- **Esforço:** S · **Conf.:** alta
- ✅ **Implementado (2026-09-04, onda 2)** — `1b555c3`, `38094ec`: pull tolerante por item (playlists e audio flags), falha no pull não bloqueia push/tombstones, `lastError` com banner e «Tentar novamente» na tela de listas.

### B9. `syncAfterLogin` remarca todas as listas como `pendingPush` a cada boot; exclusões remotas nunca propagam
- **Evidência:** `playlist_sync_provider.dart:58-67,104-110` (`fireImmediately`, `_lastSyncedSub` começa `null`); `sync_playlists.dart:56-104` só faz upsert. `PlaylistSyncStatus.conflict` nunca é usado (grep vazio).
- **Efeito [inferência]:** lista apagada no celular ressuscita pelo tablet; N PUTs por boot.
- **Fix:** persistir `lastSyncedSub`; tratar ausência remota como exclusão (ou tombstones do servidor); estratégia para 409.
- **Esforço:** M · **Conf.:** média (semântica do `GET /api/playlists` não verificada)
- ✅ **Implementado (2026-09-04, onda 2)** — `1b555c3`, `262da03`: `_lastSyncedSub` persistido (só remarca tudo quando o `sub` muda), 409 → `PlaylistConflictException` com LWW por `updatedAt` e re-push único, status `conflict` visível no banner, tombstones com no máximo 3 tentativas por boot. Exclusão remota (ausência = apagar) continua fora: depende de decisão (B9/B18).
- ✅ **Fechado (2026-09-11, onda 3)** — `a81bc1e`, `134e00b`, `efa863b`, `a81eec4`: o Worker expõe tombstones (`GET …?includeDeleted=1`, `deletedAt` em toda linha); o cliente apaga localmente a lista removida em outro aparelho (a menos que tenha edição pendente mais nova, que a ressuscita); 409 com remoto mais novo guarda as edições locais numa «(cópia local)» com status `conflict`; `syncAfterLogin` retentado por «Tentar novamente» e sync ao voltar a rede; boot espera o Isar.

### B10. `id_token` Google (1h) sem refresh e sem tratamento de 401 em lugar nenhum
- **Evidência:** `auth_user.dart:23`; Bearer cru em `playlist_remote_datasource.dart:12-13`, `audio_flag_remote_datasource.dart:12-13`, `social_remote_datasource.dart:13-14`; zero interceptors no projeto.
- **Efeito:** PWA aberta o culto inteiro → sync e Social falham em silêncio.
- **Fix:** interceptor 401 → `attemptLightweightAuthentication()` e refazer; senão estado "expirado" com banner.
- **Esforço:** M · **Conf.:** alta
- ✅ **Implementado (2026-09-04, onda 2)** — `fa50ddd`, `2d1bd21`: `AuthUser.expiresAt` (claim `exp`), `refreshIdToken()` via `attemptLightweightAuthentication`, `AuthRefreshInterceptor` (401 → 1 refresh + 1 replay; token igual conta como falha), `sessionExpiredProvider` + banner no perfil.

### B11. Áudio: `_applyQueue` sem generation guard; nenhum listener de `errorStream`
- **Evidência:** `audio_player_session_provider.dart:194-259` (dois `await` longos sem checar se outra chamada começou); `grep errorStream lib` vazio; `playPause/seek/skip` (`:263-296`) sem try e chamados sem `await`.
- **Efeito:** tocar duas faixas rápido → fila/índice errados (o bug do iPad volta); 404 no proxy → exceção não tratada, sem retry.
- **Fix:** `_generation++` e checagem após cada `await`; assinar `errorStream`; botão retry.
- **Esforço:** S · **Conf.:** alta
- ✅ **Implementado (2026-09-04, onda 2)** — `a5e25c3`, `ec28651`, `2cd2b1b`: `_applyQueue` com geração (só a chamada mais nova escreve estado), contador de `setAudioSources` em voo (não de geração), `errorStream` assinado, erro visível com «Tentar novamente» na face de áudio e no player, transporte com try/catch.

### B12. Cifra: falha de rede vira `null` cacheado (`keepAlive`) e a cifra some do sheet; sem cache persistente
- **Evidência:** `chord_content_datasource.dart:40-42` (`on Object { return null; }`); `chord_providers.dart:25-26` (`keepAlive` antes do fetch); `available_chords_provider.dart:28-31` reutiliza; sempre `_dio.get`, sem Isar.
- **Efeito:** rede oscila ao abrir → "indisponível" até fechar o app; domingo sem rede, cifra ensaiada na quarta não abre.
- **Fix:** `null` só para 404; `keepAlive` só no sucesso; persistir `.chord` (~600 B) no Isar por `r2Key`.
- **Esforço:** S (retry) / M (cache) · **Conf.:** alta / média
- ✅ **Implementado (2026-09-04, onda 2)** — `c189fc4`, `1e213c5`, `efde830`: `fetchSong` só devolve `null` em 404; `chordSongProvider` `autoDispose` com `keepAlive` só no sucesso (erro não gruda na sessão); cache persistente `ChordContentCache` no Isar com TTL de 24 h e marcador negativo para 404.

### B13. Offline bulk: cancel nativo vira `failed`; `.tmp` apagado no boot anula resume; ZIP corrompido reutilizado para sempre; sem watchdog de stall
- **Evidência:** `zip_package_downloader_native.dart:66-71` (tipo `cancel` não mapeado), `:248-261` + `offline_bulk_providers.dart:12-19` (`cleanOrphanedTempFiles` unawaited na criação), `:35-44` (cache hit só por tamanho, sem magic bytes/ETag); `offline_config.dart:39` (`receiveTimeout = Duration.zero`) sem watchdog por `onReceiveProgress`.
- **Fix:** mapear `cancel`; limpar `.tmp` só fora do checkpoint; `on FormatException` → apagar ZIP; `If-Range`; watchdog de stall (timer reiniciado a cada progresso).
- **Esforço:** S+S+S+M · **Conf.:** alta
- ✅ **Implementado (2026-09-04, onda 2)** — `10eceeb`, `d309b7b`: cancel do usuário vira `cancelled` (não `failed`); `.tmp` do checkpoint ativo preservado; ZIP em cache validado por assinatura `PK`; extração corrompida apaga o ZIP e baixa de novo uma vez; watchdog de stall (90 s) reiniciado a cada chunk. Pendente: `dio.download` com `deleteOnError` impede retomar por Range após um stall.

### B14. Reconcile global concorrente ao bulk apaga PDFs recém-extraídos; sem exclusão mútua entre bulk / faltantes / limpar
- **Evidência:** `offline_reconcile_provider.dart:63-71` não consulta o bulk; gatilhos em `offline_lifecycle_listener.dart:47-48` e `offline_settings_screen.dart:35-38`; `offline_bulk_download_provider.dart:154-155,197-201` guardam por `isRunning`, não `isActive`.
- **Fix:** lock de manutenção compartilhado.
- **Esforço:** S · **Conf.:** alta
- ✅ **Implementado (2026-09-04, onda 2)** — `9e26784`, `19a1e7a`: `offlineMaintenanceLockProvider` entre bulk, faltantes, limpar e reconcile; reconcile pedido durante um bulk é recusado; bulk faz reconcile **escopado** por pacote ao terminar.

### B15. Catálogo: erro sem retry, `CatalogRefreshBanner` é código morto, nada recarrega ao voltar online; DTOs Coldigom com casts rígidos derrubam a página inteira
- **Evidência:** `home_screen.dart:203-212` e `library_screen.dart:348-357` (só `Text`); `CatalogRefreshBanner(` nunca instanciado; `praise_dto.dart:23,57-58,107-108,161,182,197,245` (`as String`/`as Map` sem try por item, ao contrário de `catalog_remote_datasource.dart:44-48`); `home_search_provider.dart:208-213` (Coldigom falha → `[]` sem sinal).
- **Fix:** botão "Tentar novamente" + `onConnectivityChanged`; parser tolerante; provider de erro Coldigom com linha "indisponível · tentar de novo".
- **Esforço:** S · **Conf.:** alta
- ✅ **Implementado (2026-09-04, onda 2)** — `930e7a9`: Home e Biblioteca com «Tentar novamente» e recarga automática ao voltar a rede (`connectivityStreamProvider`); `CatalogRefreshBanner` apagado; DTOs Coldigom tolerantes (`type` ausente → `unknown`, material inválido descartado); busca Coldigom em erro mostra «Coldigom indisponível · tentar de novo».

### B16. Rede: nenhum interceptor de retry nos dois `Dio`; mensagens técnicas cruas na UI
- **Evidência:** `dio_provider.dart:11-17`, `coldigom_dio_provider.dart:8-14`; `catalog_refresh_provider.dart:45`, `google_sign_in_button_web.dart:31`, `profile_screen.dart` (`'Erro de autenticação: $e'`).
- **Fix:** `RetryInterceptor` (GET idempotente, backoff); `userMessageFor(Object)` central com l10n.
- **Esforço:** M · **Conf.:** alta
- ✅ **Implementado (2026-09-04, onda 2)** — `253d506`, `1b66ccf`: `RetryInterceptor` (GET idempotente, 2 retentativas com backoff) nos dois `Dio` com opt-out para os laços próprios do offline; `userMessageFor(l10n, erro)` central (Dio, storage, auth, família PDF) substitui os `$e` crus.

### B17. Isar sem timeout na abertura → spinner infinito **[inferência]**
- **Evidência:** `isar_provider.dart:9-13`; `bootstrap_app.dart:19-31`. Modo degradado só entra em erro, não em hang (ex.: segunda aba disputando OPFS).
- **Fix:** `.timeout(15s)`; detectar outra aba via `navigator.locks`/`BroadcastChannel`.
- **Esforço:** S · **Conf.:** média
- ✅ **Implementado (2026-09-04, onda 2)** — `b2d556e`, `ae6f352`: `openAppIsar().timeout(15 s)` com `Timer` cancelável → modo degradado; instância que abre depois do timeout é fechada.

### B18. Troca de conta em tablet compartilhado mistura dados entre usuários
- **Evidência:** `signOut` só limpa sessão (`auth_state_provider.dart:113-115`); nenhum registro Isar tem `ownerSub`; `markAllSavedPendingPush()` sobe tudo para a conta seguinte.
- **Esforço:** M · **Conf.:** média
- ✅ **Implementado (2026-09-11, onda 3)** — `b37435b`, `a6b6982`, `44cec66`: `Playlist.ownerSub`/`AudioFlag.ownerSub`; `adoptForSub` (só sem dono ou do mesmo dono) substitui `markAllSavedPendingPush`; na troca de conta `purgeSyncedOwnedBy(anterior)` apaga localmente o que já está na nuvem da conta anterior (pendentes ficam e não entram no push da nova); `getPendingPush`/`getTombstones` filtrados por dono.

---

## C. UX e produtividade (web/desktop/tablet)

### C1. Teclado: zero atalhos fora das setas do leitor; busca sem autofocus, Enter ou navegação
- **Evidência:** grep de `Shortcuts(`/`CallbackShortcuts`/`HardwareKeyboard` em `lib/` → apenas `pdf_page_keyboard_policy.dart:12-22` (setas); `search_bar.dart:54,98-117` sem `autofocus`/`onSubmitted`; foco do leitor se perde ao clicar na toolbar (`pdf_reader_page_key_handler.dart:70-73`).
- **Proposta:** `/` ou `Ctrl+K` foca a busca de qualquer tela; Enter abre o primeiro resultado; ↑/↓ entre cards; no leitor: PageDown/Espaço/→ próxima, PageUp/←, Home/End, `Ctrl+←/→` ou `N/P` louvor anterior/próximo, `F` fullscreen, Espaço play/pause, `+/-` transpõe. Pedaleiras Bluetooth mandam PageUp/Down.
- **Esforço:** M · **Conf.:** alta
- ✅ **Implementado (2026-09-03)** — `4547891`, `3009075`, `69a7695`, `82ff910`, `c595a57`: `AppShortcuts` no shell (`Ctrl/Cmd+K`, `/`, `Espaço`, `F`, `Esc`), `PdfKeyAction` (PageUp/Down, Home/End, pedaleira na última página → próximo louvor), atalhos da cifra (`+/=/-`, `Ctrl+↑↓`, `Ctrl+←→`), busca com autofocus/Enter/Esc; foco do leitor restaurado ao clicar na toolbar.

### C2. Sem wakelock no leitor, cifra e player
- **Evidência:** `grep wakelock lib` → só `offline_bulk_download_provider.dart`. `wakelock_plus` já está no pubspec e suporta web.
- **Proposta:** `WakelockPlus.enable()` enquanto rota ∈ {`/leitor`,`/cifra`,`/audio`} ou `session.playing`.
- **Esforço:** S · **Conf.:** alta
- ✅ **Implementado (2026-09-03)** — `4547891`: `StageWakelockListener` no shell (`shouldHoldWakelock` puro: rota de leitor/cifra/player ou áudio tocando), falha da plataforma só registra `debugPrint`.

### C3. Busca indexa só título + número; a "letra/texto" prometida no PRODUCT.md não existe
- **Evidência:** `lib/features/catalog/domain/entities/louvor.dart:78-96` (`searchContentTokens` = `nome` + `numero`); hint "Buscar por número ou título" (`app_pt.arb:4`).
- **Proposta:** campo `letra`/primeiros versos tokenizado no manifest (depende de backend); até lá, copy honesta no hint e no estado vazio; indexar primeira linha do chordpro para Coldigom.
- **Esforço:** L (dado) / S (copy) · **Conf.:** alta

### C4. Home sem estado vazio nem "sem resultados"
- **Evidência:** `home_search_results_sliver.dart:27-29` — `results.isEmpty → SizedBox.shrink()`; nenhuma chave l10n de "nenhum resultado" para a Home.
- **Proposta:** mensagem + sugestões; Home sem query com "últimos abertos" e "lista ativa"; aviso "Coldigom indisponível offline".
- **Esforço:** S / M · **Conf.:** alta
- ✅ **Implementado (2026-09-12, onda 4)** — `b3491b4`, `87c0366`: `HomeEmptyState` — sem consulta mostra a lista ativa («Abrir no leitor») e «Abertos recentemente» (`recentlyOpenedProvider`, 8 ids em prefs, gravados pelos params do leitor e pela faixa do player); consulta sem resultado mostra «Nenhum louvor para …», dicas, «Limpar filtros» quando há filtro e aviso Coldigom offline.

### C5. Card não mostra quais materiais existem; termos casados sem destaque; "+" só aparece com PDF único
- **Evidência:** `louvor_group_card.dart:279-288` (resumo textual), `:301-308` (`onAdd` nulo se multi-material). Sem `TextSpan` de highlight.
- **Efeito:** montar 8 louvores na lista do culto ≈ 30 toques.
- **Proposta:** linha de ícones (PDF · cifra · gestos · áudio · YouTube) clicáveis; "+" sempre visível adicionando o material preferido com snackbar "Trocar material".
- **Esforço:** M · **Conf.:** alta
- ✅ **Implementado (2026-09-12, onda 4)** — `485fad4`, `abeb28f`, `a47b05b`, `1055011`: `MaterialKindsRow` (ícones por tipo com contagem, toque abre o sheet) no card; «+» sempre que há material adicionável (`preferredMaterialForGroup`: PDF principal > áudio único > extra adicionável) com snackbar «Adicionado à lista · Trocar material» (troca por `replaceByKey`); `HighlightedText` destaca o termo no título com a normalização do índice.

### C6. Shell de 5 abas em desktop, com aba placeholder em posição nobre; Listas/Offline a 2 cliques
- **Evidência:** `shell_scaffold.dart:96-102`; `app_router.dart:47-51` → `PlaceholderTabScreen('Eventos')` → "Em breve"; único breakpoint muda padding (`home_screen.dart:165`); `plpcg_bottom_nav_bar.dart:56` índices fixos.
- **Proposta:** `LayoutBuilder` ≥ 840 px → `NavigationRail`; esconder Eventos enquanto placeholder (via feature flag, ver E7); Listas no 1º nível.
- **Esforço:** M · **Conf.:** alta
- ✅ **Implementado (2026-09-12, onda 4)** — `9ded0c6`: rail a partir de 840 px (`kRailBreakpoint`) com as mesmas destinations derivadas das flags; bottom bar escondida nessa largura. Listas continuam no 2º nível.
- 🔁 **Refeito (onda 4.1, `e1a5b3e`)** — o `NavigationRail` do Material perdeu os ícones/tipografia/brilho da barra inferior na validação; o rail agora empilha os mesmos `PlpcgNavItem` (item extraído da barra, com `axis`) sobre o vinho com a linha dourada.

### C7. Sem split view em telas largas (PDF/cifra + lista da reunião + player)
- **Evidência:** `pdf_reader_screen.dart:333-405` e `chord_reader_screen.dart:63-137` são `Column` sem breakpoint; lista só em `AlertDialog` (`carousel_selection_sheet.dart:104`) que cobre a partitura.
- **Proposta:** ≥ 900 px: painel lateral com a lista (item atual destacado, drag para reordenar), player compacto, "seguir áudio".
- **Esforço:** M–L · **Conf.:** alta
- ↩️ **Implementado e removido** — onda 4 (`4ab554a`, `cac2713`, `8772a75`) trouxe `ActiveListPanel` num painel de 320 px a partir de 900 px; na validação o botão da toolbar foi julgado redundante com o «olho» da barra («a ideia é a mesma, mas só funciona de desktop em diante») e o painel saiu inteiro na onda 4.1 (`4815aa4`). Fica o `ActiveListPanel` como corpo do diálogo de seleção. Não retomar sem pedido.

### C8. Leitor PDF: toggle fit-mode existe e nenhum botão o chama; fullscreen web é no-op; sem 2 páginas lado a lado; sem lembrar última página
- **Evidência:** `pdf_reader_view_settings_provider.dart:31` (`toggleFitMode`, 0 chamadas); `reader_fullscreen_provider.dart:41-47` (só `SystemChrome`, sem Fullscreen API); `pdf_reader_pdf_view.dart:364-368` (sem spread); `reader_preferences_datasource.dart:26` (só `fitMode`).
- **Proposta:** botão fit + tecla; `requestFullscreen()` via `package:web`; spread quando `width/height > 1.3`; `{pdfId: page}` LRU 50.
- **Esforço:** S+S+M+S · **Conf.:** alta
- ✅ **Implementado (2026-09-12, onda 4)** — `a3954e0`, `97366ad`, `2ab3e71`, `4d35b76`, `8e199ca`, `75f4972`, `c607f36`: botão e tecla `Z` de ajuste; fullscreen web pela Fullscreen API (`ReaderFullscreenPlatform`, escuta `fullscreenchange`); última página por PDF (LRU 50 em prefs) restaurada quando o viewer fica pronto e a rota não traz `page`; «ir para página» pelo indicador e tecla `G`; duas páginas lado a lado em viewport largo (`spreadPageLayout`), desligado enquanto o ajuste efetivo é à largura (fullscreen/`Z`). Onda 4.1 (`ff8c100`): a preferência «Duas páginas em tela larga» saiu do menu — o spread é só automático.

### C9. Leitor de cifras: sem autoscroll, capo, colunas em tela larga
- **Evidência:** `chord_reader_screen.dart:90-130` (`SingleChildScrollView` + `Column`); grep `autoscroll|capo` vazio; `chordpro_view.dart:86` coluna única.
- **Esforço:** M · **Conf.:** alta
- ✅ **Implementado (2026-09-12, onda 4)** — `dddae1b`, `78d0ce9`, `322a6de`, `d0715cd`, `f5bc42b`: autoscroll por `Ticker` (velocidade 1–5, teclas `S`, `[`, `]`; para no fim, no toque e ao trocar de louvor); duas colunas pela largura disponível (≥ 900 px e ≥ 24 linhas, corte na seção mais próxima do meio). Capo fica fora.

### C10. Transposição vaza para o próximo louvor da lista (contradiz o docstring)
- **Evidência:** `chord_reader_mode_provider.dart:59-87` — `NotifierProvider` global, doc diz "cada abertura começa no tom original", mas ninguém chama `reset()` ao trocar de `pdfId` (só o botão, `chord_reader_screen.dart:220`); troca de louvor é `context.replace` (`carousel_chips.dart:315`).
- **Proposta:** curto prazo `family` por `chordId`/reset em `didUpdateWidget`; médio prazo "tom escolhido" como atributo da entrada da lista (vai no share e no folheto).
- **Esforço:** S / M · **Conf.:** alta
- ✅ **Implementado (2026-09-12, onda 4)** — `ac76885`: `chordReaderTransposeProvider` virou família por `chordId` — cada louvor tem seu tom na sessão; abrir outro não herda.

### C11. Listas: nome da lista ativa invisível na barra; reordenar só no diálogo; exclusão sem "desfazer"; sem duplicar
- **Evidência:** `carousel_chips.dart`/`carousel_navigator_bar.dart` não exibem `nome`; `carousel_selection_sheet.dart:108-116`; `playlist_list_tile.dart:500-507` (confirm → delete, sem undo); menu `:194-217` sem "Duplicar".
- **Proposta:** nome editável inline à esquerda dos chips; drag & drop na própria barra com mouse; snackbar "Removida · Desfazer" (soft-delete); "Duplicar".
- **Esforço:** M + S · **Conf.:** alta
- ✅ **Implementado (2026-09-12, onda 4)** — `539d7a7`, `a3760cb`, `d777450`, `b3887f9`, `dfb970d`: nome da lista ativa na barra (toque renomeia; some < 480 px; onda 4.2 `3e265cf`: tocar em «Rascunho» **salva** com nome — antes só renomeava e o rascunho ficava rascunho — e o nome ocupa no máximo 1/5 da barra, 72–160 px; o menu «⋮» da barra virou um botão único de compartilhar com `Icons.adaptive.share`); apagar sem confirmação, com «Desfazer» por 5 s (exclusão adiada `PendingDelete`; `_reload` e o import ignoram a lista pendente; ativa é solta na hora e restaurada no undo); «Duplicar» (`DuplicatePlaylist`, «Nome (cópia)», sem publicação). Reordenar na barra fica fora (o painel lateral cobre).

### C12. Player sem velocidade, ±10 s, loop A–B, Espaço; marcador só com áudio pausado; posição não persiste
- **Evidência:** `audio_transport_controls.dart` (só prev/play/next); sem `setSpeed`/loop no provider; `audio_player_screen.dart:43` — `canAddFlag = track != null && !session.playing`.
- **Esforço:** M · **Conf.:** alta
- ✅ **Implementado (2026-09-12, onda 4)** — `7979eb6`, `971c863`, `86ff3a2`, `3cdb710`, `cb9ca89`, `89faa2f`, `885bf6e`, `87e3bb2`: ±10 s nos controles e teclas `J`/`L` (sem modificador, guarda de campo de texto); velocidade 0,75×–1,5× (reaplicada na troca de fila; zerada no `close`); marcador com o áudio tocando; posição gravada a cada 5 s e no pause/stop com a duração observada, retomada só no boot (não retoma a menos de 5 s do fim). Loop A–B fica fora.

### C13. Filtros nunca persistem entre sessões; Biblioteca com 10 itens por página em desktop
- **Evidência:** `catalog_filters_provider.dart` sem `SharedPreferences`; `library_view_settings_provider.dart:25`.
- **Esforço:** S · **Conf.:** alta
- ✅ **Implementado (2026-09-12, onda 4)** — `c7b50f0`, `8622cac`: filtros de material/arranjo e itens por página persistem em prefs (URL vence quando presente; `hydrateFromUrl` sem params não apaga); Biblioteca abre com 25 por página em tela larga quando nada foi escolhido.

### C14. Título da aba do navegador fixo em "PLPCG"
- **Evidência:** `lib/app.dart:44`; nenhum `Title(`/`onGenerateTitle`.
- **Proposta:** `Title('$numero — $nome · PLPCG')` nos leitores e player.
- **Esforço:** S · **Conf.:** alta
- ✅ **Implementado (2026-09-12, onda 4)** — `dd2c452`: `Title` no shell — «123 — Nome · PLPCG» no leitor/cifra, faixa no player, «Aba · PLPCG» nas demais.

### C15. Strings hardcoded em PT fora do l10n; alvos de toque pequenos; sem `semanticLabel`
- **Evidência:** `shell_scaffold.dart:48-57` (nomes das abas), `pdf_reader_screen.dart:200,211,266,370,391,413`, `plpcg_primary_app_bar.dart:35,47`, `confirm_dialog.dart:17,21`, `profile_screen.dart:62-74,157`, `deferred_route_loader.dart:71`; 27 fallbacks `?? '…'`. 8 `Semantics(`, 0 `semanticLabel`; botão limpar 24×24 (`search_bar.dart:138-141`); 10 usos de `MaterialTapTargetSize.shrinkWrap`.
- **Efeito:** usuário em inglês vê a barra de navegação inteira em português.
- **Esforço:** S–M · **Conf.:** alta

### C16. Folheto só via Share; gesto escondido (long-press no indicador de página); sem "ir para página"
- **Evidência:** `playlist_share_sheet.dart:54`; `pdf_reader_page_indicator.dart:40-48`.
- **Esforço:** S · **Conf.:** alta
- ✅ **Implementado (2026-09-12, onda 4)** — `4d35b76`, `fc74aac`, `f30cc59`: «ir para página» pelo indicador e tecla `G`; «Gerar folheto» direto no menu da lista salva (sem passar pelo sheet de share e sem trocar a lista ativa).

---

## D. Fluxo playlist + áudio + PDF ("ouvir enquanto lê", culto e estudo)

**Como funciona hoje (verificado):** abrir/+ chama `addLouvorToActivePlaylist(pdfId)` e navega; a lista ativa é `activePlaylistIdProvider` (prefs) e o carousel é uma **segunda cópia** em Isar (`CarouselEntry{pdfId}`), sincronizada à mão nos dois sentidos. `SavedPlaylist` tem `pdfIds[]` **e** `audioIds[]` independentes; uma pref global `playlistMediaFaceProvider` (PDF|Áudio) decide qual "face" a barra mostra. A sessão de áudio é global e continua tocando ao navegar. "Próximo" no leitor percorre só `getOrderedPdfIds()`; "próximo" no player percorre a fila do `just_audio`. Nada liga a faixa tocando ao PDF exibido.

### D1. Não existe ponte áudio ↔ partitura do mesmo louvor
- **Evidência:** `audio_player_session_provider.dart:121-131` (listener de `currentIndexStream` só atualiza media session); `audio_player_screen.dart` sem ação "ver partitura"; `carousel_audio_face_bar.dart:156-159` + `find_louvor_group_by_pdf_id.dart:81-95` — na face áudio o botão "layers" mostra os materiais do **PDF focado**, não do áudio tocando. A chave já existe no domínio: `AudioTrack.groupId` e `Louvor.effectiveGroupId`.
- **Proposta:** (a) no leitor, "▶ áudio deste louvor"; (b) no player/face áudio, "partitura/cifra deste louvor"; (c) toggle "seguir o áudio": ao mudar `currentTrack.groupId`, `navigateToPdfId` do material desse louvor na lista.
- **Esforço:** M · **Conf.:** alta
- ✅ **Implementado (2026-09-03)** — `fa97e7c`, `d468ef9`, `3a0b8bf`, `f63d52d`: `findMaterialForGroup`, "partitura deste louvor" no player e na face áudio, botão morto do carousel virou "tocar áudio deste louvor", toggle "seguir o áudio" (`audioFollowReaderProvider`, não dispara na restauração da sessão nem troca o material escolhido do mesmo louvor).

### D2. Modelo "duas filas" (`pdfIds` × `audioIds`) — contradiz o princípio 4 do PRODUCT.md e congela o formato de sync
- **Evidência:** `saved_playlist.dart:37-41`; `core/database/collections/playlist.dart:21-23`; `playlist_media_face.dart:2`; `remote_playlist.dart:66-67` (wire format já serializa as duas); funções gêmeas `removePdf/removeAudio`, `addLouvorToActivePlaylist/addAudioToActivePlaylist`. Cifra já entrou "disfarçada" em `pdfIds`.
- **Efeito:** reunião com 384 (cifra), 412 (áudio), 128 (YouTube): na face PDF o 412 some; na face áudio somem 384 e 128. Cada tipo novo (gestos) = coluna nova + migration + merge no D1.
- **Proposta:** `PlaylistEntry{groupId, materialId, kind}` em ordem única; `pdfIds/audioIds` viram projeções; `RemotePlaylist.schemaVersion: 2` com `items: [{id, kind}]`; Worker aceita v1 e v2; `PlaylistMediaFace` some (vira filtro). **Fazer antes de ligar o sync em produção.**
- **Esforço:** L · **Conf.:** alta
- 🟡 **Fatia 1 implementada (2026-09-03)** — `f66c6ce`, `ec3ae57`, `7cc31cd`, `09a6767`: `Playlist.items` (Isar, migração lazy na leitura), `SavedPlaylist.items` como fonte de verdade com `pdfIds`/`audioIds` derivados por `materialIdKindOf` (pdf/cifra/desconhecido → face PDF; áudio → face áudio), toda mutação sobre `items`, `updatePlaylist(pdfIds:)` preserva a posição relativa dos áudios (regra de slots documentada), dedupe por `items`; `RemotePlaylist` envia `schemaVersion: 2` + `items` + listas derivadas e lê v1/v2. **O Worker ainda não guarda `items`** (todo pull achata a ordem) — próxima onda: coluna `items` no D1 + `kind` junto do id + `PlaylistMediaFace` como filtro.
- 🟡 **Fatia 2 (2026-09-04, onda 2)** — `2523836`, `f413bee`, `12d296b`, `a5a71a5`, `b31d1ae`, `303e99a`, `6cd3e4e`: `PlaylistEntry{id, kind}` é a fonte de verdade (`itemKinds` no Isar com migração lazy), wire v2 com `items` como objetos, **Worker persiste `items`** (migration `0008`, kinds preservados em PUT v1), URL de compartilhamento com `shareitems` (ordem e tipo), testes do Worker com D1 fake e job de CI. Falta (D3): carousel como view da lista e a face como filtro puro; `social/handlers.ts` ainda v1; encurtador de link (D7).
- ✅ **Fechado (2026-09-11, onda 3)** — `ec5f50e`, `2cc5472`, `d1fcbe7`: rota social responde v2 (`items`) e o import de lista pública leva ordem, tipo e áudios (`PublicPlaylist.entries`); com D3, a lista ativa é a única persistência. Falta só o encurtador (D7).

### D3. Carousel (Isar) e playlist ativa são duas persistências reconciliadas à mão; louvor repetido é impossível
- **Evidência:** `carousel_entry.dart:12-13` (`@Index(unique: true) pdfId`); `playlists_provider.dart:491-572` (`resolveActivePlaylistFromCarousel`, 80 linhas, chega a criar rascunho novo); `active_playlist_sync.dart`, `ensure_playlist_for_louvor.dart`, `load_playlist_into_carousel.dart` (cópias nos dois sentidos); `removePdf` na tela de listas não toca o carousel.
- **Proposta:** carousel = view derivada de `activePlaylist.entries`; `CarouselEntry` some; `carouselFocusedIndex` vira `currentIndex` da lista ativa (o mesmo campo que UC-16 quer sincronizar).
- **Esforço:** L (destrava D2, D5, D6) · **Conf.:** alta
- ✅ **Implementado (2026-09-11, onda 3)** — `4175b9c`, `9e764d3`, `c68b113`, `914407e`, `a4b326e`, `793779e`: `SavedPlaylist.entries` da lista ativa é a única seleção; `ActivePlaylistEditor` (add/remove/replace/reorder por chave de ocorrência `id`/`id#n`, `activate`, `detach`); `carouselItemsProvider`/`audioFaceItemsProvider` como views filtradas por face; foco por chave; leitor navega por chave; louvor repetido permitido («Adicionar de novo»); `CarouselEntry` só na migração única do boot; adaptadores e `CarouselRepository` apagados.

### D4. Fila do player disparada pela busca é "materiais do mesmo louvor", não a reunião
- **Evidência:** `louvor_material_sheet.dart:295-299`, `coldigom_material_sheet.dart:358-362`, `louvor_group_card.dart:85-90` — `queue: group.audioTracks`; só `playlist_list_tile.dart:420-434` monta com `playlist.audioIds`; `playlist_audio_face_panel.dart:110` — `hasPrevious: true` hard-coded.
- **Efeito:** "próximo" na barra pula para "Playback"/"MIDI" do mesmo louvor, não para o 412.
- **Proposta:** fila = entradas de áudio da lista ativa; materiais alternativos ficam no swap.
- **Esforço:** M · **Conf.:** alta
- ✅ **Implementado (2026-09-11, onda 3)** — `5689cb7`: `activeListAudioQueue`/`queueForTrack`: se a faixa está na lista ativa, a fila é a lista; senão, os materiais do grupo; `hasPrevious`/`hasNext` vêm da sessão.

### D5. No leitor, a face áudio tira as setas de louvor, a face PDF esconde o player, e fullscreen esconde os dois
- **Evidência:** `carousel_chips.dart:53-62` (face áudio substitui a barra com setas); `carousel_audio_face_bar.dart:110-155` (sem anterior/próximo louvor); `shell_scaffold.dart:78-84` (`hideChrome` remove a barra inteira).
- **Efeito:** pausar durante o louvor em tela cheia exige duas ações.
- **Proposta:** mini-player fino e persistente, independente da face, visível em fullscreen (mesmo padrão do FAB de sair, `pdf_reader_screen.dart:384-400`).
- **Esforço:** M · **Conf.:** alta
- ✅ **Implementado (2026-09-12, onda 4)** — `ab1eb34`, `ca0e3c7`, `1913a34`, `0fab43e`, `dc1d4f9`: `MiniPlayerBar` (44 px) no shell quando há faixa e a face de áudio não está visível, e como overlay translúcido em fullscreen sobre o leitor e a cifra (toque em área vazia passa; FAB de sair e última linha da cifra sobem); face de áudio com setas de louvor relativas à faixa tocando.

### D6. Modal "Substituir seleção?" e "Carregar no carousel" divergem de "abrir entra na lista ativa, sem modal"
- **Evidência:** `playlist_list_tile.dart:250-260,363-376`; `app_pt.arb:370-371`. Import por deep link faz o oposto: substitui sem perguntar (`sync_deep_link_state.dart:43-44`).
- **Proposta:** toque na lista salva = vira ativa, snackbar "Lista X ativa · Desfazer"; import com prévia "[Abrir agora] [Só salvar] [Adicionar à ativa]".
- **Esforço:** S–M · **Conf.:** alta
- ✅ **Implementado (2026-09-11, onda 3)** — `8a9c7f7`, `119a0eb`: «Tornar lista ativa» sem modal, snackbar com «Desfazer» (só quando havia outra ativa; nunca derruba uma ativação mais nova; não toca em `ref` depois do unmount); import por URL sem confirmação (paridade com o deep link); chaves `playlistLoadConfirm*` apagadas.

### D7. Share/import: só ids, sem material/índice/tom; importar cria lista salva duplicada a cada clique
- **Evidência:** `playlist_share_url_builder.dart:40-49`; `pdf_id_codec.dart:8-9` (base64 do path, ~60–90 chars por id); `import_shared_playlist_from_url.dart:31-41` (`create(salva: true)` sempre); dedupe só por fingerprint na sessão (`deep_link_listener.dart:76-78`).
- **Proposta:** dedupe por hash de conteúdo; formato v2 `id:kind` (+ índice atual, tom); short link pelo Worker (`/l/ABC123`), que também é o degrau para UC-16.
- **Esforço:** M · **Conf.:** alta
- ✅ **Implementado (2026-09-12, onda 4)** — `3a3710b`, `6c314a9`, `3d4ac39`, `984457b`: Worker `POST /api/links` (autenticado, reuso por `(dono, query)`, teto 100/24 h, código de 7 chars, charset validado) e `GET /l/:code` (público, 302 para `plpcg.com/?…`, `max-age` 1 h) com migration `0009_create_short_links`; o share usa o link curto quando logado e cai na URL longa em qualquer erro; importar o mesmo conteúdo não duplica a lista salva (`contentFingerprint` por `kind:id`; «Lista já estava salva»).

### D8. Folheto e "compartilhar da barra" ignoram entradas de áudio
- **Evidência:** `playlist_share_actions_provider.dart:246-251`, `playlist_list_tile.dart:455-459`, `carousel_bar_trailing_actions.dart:183-186` — só `pdfIds`; `generate_leaflet_from_selection.dart:26-28` lança "seleção vazia" numa lista só de áudios.
- **Proposta:** folheto consome a fila única (D2); enquanto não existir, `pdfIds ∪ audioIds` resolvidos para (numero, nome) e deduplicados por `groupId`.
- **Esforço:** S após D2 · **Conf.:** alta
- ✅ **Implementado (2026-09-12, onda 4)** — `7656c6c`, `42f3273`: `GenerateLeafletFromEntries` (um só use case) resolve PDF, cifra e áudio pelo `CatalogMaterialLookup`, deduplica por `groupId`; `PlaylistShareContext.entries`; `EmptyLeafletException` no próprio feature.

### D9. Cache do leitor descartado ao sair do `/leitor`; LRU de 3 não cobre ida e volta entre 5 louvores
- **Evidência:** `pdf_session_cache.dart:7,55-59`; `reader_adjacent_pdf_prefetch_provider.dart:37` (`autoDispose`); prefetch sem `CancelToken` nem dedupe com o download do usuário (`prefetch_adjacent_carousel_pdfs.dart:39-48`).
- **Proposta:** manter cache enquanto a lista ativa existir, tamanho `min(lista, 6)`; pré-aquecer o material do louvor tocando no áudio; dedupe `pdfId → Future` em `ResolvePdfForReader`.
- **Esforço:** M · **Conf.:** média

### D10. Botão "Abrir no leitor" morto no modo leitor
- **Evidência:** `carousel_chips.dart:431,453` — `onOpenPlayer: () {}`; `carousel_navigator_bar.dart:86-92` renderiza o botão.
- **Proposta:** `null` no modo leitor, ou reaproveitar o slot como "▶ áudio deste louvor" (D1).
- **Esforço:** S · **Conf.:** alta
- ✅ **Implementado (2026-09-03, onda 1)** — `3a0b8bf`: o botão do modo leitor vira «tocar áudio deste louvor» (`queueForTrack`); constatado no levantamento da onda 4.

### D11. Tela `/audio` é beco sem saída e duplica a barra
- **Evidência:** `audio_player_screen.dart:45-208` (sem lista, sem link para partitura); `shell_scaffold.dart:33-38` marca `/audio` imersiva enquanto a `CarouselAudioFaceBar` repete os mesmos controles.
- **Proposta:** transformar em tela de **estudo**: fila da lista, loop A–B entre flags, velocidade, "partitura/cifra".
- **Esforço:** M · **Conf.:** alta (proposta é opinião de produto)

---

## E. Arquitetura e sustentação das próximas features

Fatos medidos: 16 features; 180 providers (0 codegen); `pdfId` aparece 198× em offline, 142× em playlists, 138× em carousel; `lib/deferred/` vazio e zero `deferred as`; 48 fakes ad-hoc em testes (`_FakeCarouselNotifier` copiado em 14 arquivos); sem `FlutterError.onError`/`runZonedGuarded`; lints = `flutter_lints` + 2 regras.

### E1. Não existe abstração `Material`; o modelo é `pdfId`-cêntrico com listas paralelas por tipo e discriminador por extensão
- **Evidência:** `louvor_group.dart:56-62` (`audioTracks`, `youtubeMaterials`, `chordMaterials` + PDFs em `sections`); `core/utils/material_id_kind.dart:8` (`enum { pdf, chord, unknown }` por extensão do base64; áudio/YouTube nem entram); `find_louvor_group_by_pdf_id.dart:70-76` (um cache por tipo passado por parâmetro, 202 linhas); `carousel_repository.dart:17,23` (`add(String pdfId)`); adapter Coldigom mapeia por string (`coldigom_louvor_adapter.dart:40,111,135`); ícone por `contains('cifra')` (`louvor_material_icons.dart:21-22`).
- **Custo:** Gestos `.txt` exige hoje ~9 pontos de extensão; favoritos de material não têm `kind` estável para persistir.
- **Refactor:** `sealed class CatalogMaterial { id, kind: MaterialKind{pdf,chord,audio,youtube,gesture}, groupId, categoria, source }` com subclasses; `LouvorGroup.materials: List<CatalogMaterial>` + getters derivados; `switch` exaustivo. Passo 0 barato: renomear `pdfId` → `materialId` nos contratos de carousel/playlist/share (mantendo o codec).
- **Esforço:** L (dividível) · **Risco:** médio · **Conf.:** alta
- 🟡 **Fatia 1 implementada (2026-09-03)** — `55bd941`, `fc90988`, `1e47bf9`: `MaterialKind {pdf, chord, audio, youtube, gesture, unknown}` substitui `MaterialIdKind` (`.txt`/`.gest` → `gesture`); `sealed class CatalogMaterial` (`PdfMaterial`, `ChordMaterialRef`, `AudioMaterial`, `YoutubeMaterialRef`) e `LouvorGroup.materials` derivado (PDFs por seção, cifras, áudios, YouTube); adapter Coldigom mapeia `type` num único switch; `LouvorMaterialIcons.forKind` (API por string `@Deprecated`). Falta (próxima onda): migrar `LouvorGroup`/carousel/share para a lista unificada e renomear `pdfId` → `materialId` nos contratos.
- 🟡 **Fatia 2 (2026-09-04, onda 2)** — `44c0948`, `f272c4f`, `c50acf9`: `LouvorGroup` guarda `sections` + `extras: List<CatalogMaterial>` (getters tipados derivados); porta `CatalogSource` (`PlpcgCatalogSource`, `ColdigomCatalogSource`, `CompositeCatalogSource`) e `resolveCatalogMaterial`; desvios de cifra/áudio do tile e do leitor passam pelo `openMaterialProvider`. Falta: renomear `pdfId` → `materialId` no carousel (junto de D3).
- ✅ **Fechado (2026-09-11, onda 3)** — `c68b113`, `793779e`: `pdfId → materialId` nos contratos do carousel e do leitor; `CarouselItem{materialId, kind, index, key}`; `CarouselReaderPosition` com chaves.

### E2. "Abrir material" duplicado em 3 lugares + 3 openers distintos
- **Evidência:** `playlist_list_tile.dart:282-292` e `reader_carousel_actions_provider.dart:44-51` (bloco idêntico de cifra); `open_louvor_in_reader.dart`, `open_chord_in_reader.dart`, `open_youtube_material.dart`; escada de 4 `on XException` copiada em `open_carousel_pdf_in_reader.dart:38-55` e `playlist_list_tile.dart:337-352`; 95 linhas de orquestração dentro de um `State` (`playlist_list_tile.dart:262-356`).
- **Refactor:** `openMaterialProvider` único (`locationFor(CatalogMaterial)` com switch exaustivo) + `MaterialOpenErrorPresenter`.
- **Esforço:** M · **Conf.:** alta
- 🟡 **Implementado em parte (2026-09-03)** — `ed82aee`, `1e47bf9`: `openMaterialProvider` (`OpenMaterial.open` com switch exaustivo) + `classifyMaterialOpenFailure`/`presentMaterialOpenError` numa única escada; `chordReaderLocationFor` remove o bloco duplicado de cifra em `playlist_list_tile` e `reader_carousel_actions_provider`; `louvorPdfErrorMessage` delega à escada. `open()` ainda sem chamador em produção (os pontos de entrada partem de `pdfId` cru, não de `CatalogMaterial`) — a próxima onda liga sheet/cards ao provider.

### E3. Coldigom vaza na presentation: 4 caches por tipo, heurística `isColdigom`, dois sheets, Home com 4 `StateProvider` mutados imperativamente
- **Evidência:** `coldigom_providers.dart:13,35,58,82`; `louvor_group.dart:71-83` (`if (chordMaterials.isNotEmpty) return true;` — "tem cifra ⇒ é Coldigom"); `louvor_group_card.dart:123-137` e `carousel_swap_material_button.dart:74-90` (`if (group.isColdigom) showColdigomMaterialSheet else showLouvorMaterialSheet`); `coldigom_material_sheet.dart` (722 l.) duplica `_MaterialAddTrailing`, `_handleAddPdf/_handleAddAudio` de `louvor_material_sheet.dart` e define um segundo enum de kind privado (`:56`); 40 arquivos fora de `features/coldigom` referenciam "coldigom"; `home_search_provider.dart:33-49,146-215`.
- **Refactor:** porta `CatalogSource {search, browse, getGroup, getMaterial}` com duas implementações; `LouvorGroup.source` explícito; `MaterialCacheRepository` único keyed por `materialId`; um `MaterialSheet(group)` com bloco de metadados opcional; `HomeSearchState` imutável num `AsyncNotifier`.
- **Esforço:** L (dividível em M + M) · **Conf.:** alta
- 🟡 **Fatia 1 (2026-09-04, onda 2)** — `f272c4f`, `16c829d`, `5b3f1cd`, `2433919`, `a453778`: porta `CatalogSource` (PLPCG + Coldigom + composta) para leitura por id; `MaterialSheet` único para os dois acervos (cabeçalho Coldigom quando há meta; sem abas por tipo; cifra em erro mostra «indisponível · tentar de novo»); card e botão de troca de material sem ramos `isColdigom`; `LouvorMaterialIcons.forCategory` removido. Falta (fatia 2): `HomeSearchState` imutável em `AsyncNotifier` com cancelamento/memo, `CatalogSource.search`, e tirar os 4 caches por tipo da presentation.
- ✅ **Fechado (2026-09-11, onda 3)** — `d7060cf`, `40fceac`, `a4bc52f`, `73f7392`: `HomeSearchState` imutável (`homeSearchStateProvider` = local síncrono + remoto memoizado); `CatalogSource.searchLocal/search`; caches Coldigom gravados no data (`ColdigomCacheWriter`) e lidos na presentation só pelo `CatalogMaterialLookup`; `group_with_coldigom_meta` apagado; `flutter_riverpod/legacy` fora de `features/catalog`.

### E4. God files
| Arquivo | Linhas | Split |
|---|---|---|
| `playlists_provider.dart` | 742 | CRUD/abas · ponte carousel · share (já existe `playlist_share_actions_provider.dart`) · lookup → use case |
| `playlist_list_tile.dart` | 861 | tile puro · `PlaylistActionsController` · abertura → E2 |
| `coldigom_material_sheet.dart` | 722 | → E3 |
| `offline_settings_screen.dart` | 677 | controller + 5 widgets |
| `carousel_louvor_chip.dart` | 589 | chip + `chip_parts/` |
- **Esforço:** M por arquivo · **Risco:** baixo (widget tests existentes) · **Conf.:** alta
- ✅ **Implementado (2026-09-12, onda 4)** — `967a0d5`, `ed3ba4a`, `4f1cc86`: `playlist_list_tile.dart` → tile + `playlist_tile_{header,detail_chips,actions}.dart`; `offline_settings_screen.dart` → 4 widgets em `offline_settings_widgets/` (fica com 531 linhas — `_OfflineContent` ainda dentro); `carousel_louvor_chip.dart` → `chip_parts/`. Sem mudança de comportamento.

### E5. Código morto e docs desalinhadas
- **Evidência (computado):** nunca importados: `core/constants/feature_flags.dart`, `core/constants/deep_link_config.dart`, `pdf_opening/domain/usecases/open_pdf_external.dart`, `catalog/presentation/widgets/catalog_refresh_banner.dart`, `admin/**` (`@Deprecated`), `offline/presentation/providers/offline_missing_download_provider.dart`; 19 chaves ARB sem uso; `FEATURE_INDEX.md` aponta 4 arquivos inexistentes (inclui `library_results_provider.dart` como "legado implementado"); `lib/deferred/` vazio; 3 imports `flutter_riverpod/legacy`. `WEB_PERFORMANCE_AND_LOADING.md` (Fases C e F) e `OFFLINE_PERFORMANCE_BACKLOG.md` descrevem estado que o código já não tem.
- **Refactor:** apagar; `scripts/check_unused_dart.sh` + `check_doc_paths.sh` no CI; atualizar docs.
- **Esforço:** S · **Conf.:** alta

### E6. Sem feature flags: Social/Eventos/Admin gateados por "não registrar" ou constante morta
- **Evidência:** `feature_flags.dart:4` (não importado); `app_router.dart:47-49,126-128` sempre registra; `plpcg_bottom_nav_bar.dart:56` índices fixos; `dart_defines/*.json` só tem URLs.
- **Refactor:** `FeatureFlags.fromEnvironment()` (`bool.fromEnvironment('FF_SOCIAL')`) → `featureFlagsProvider`; router e nav bar montam abas a partir dele; fase 2: overrides remotos via Worker `/api/config` por canal beta (TODO #2).
- **Esforço:** S / M · **Conf.:** alta
- ✅ **Implementado (2026-09-12, onda 4)** — `dcb2997`, `0767526`: `FeatureFlags.fromEnvironment()` (`FF_EVENTS` default false, `FF_SOCIAL` true, `FF_ADMIN_UPLOAD` false) → `featureFlagsProvider`; `appTabsFor(flags)` alimenta router e shell (índices sempre derivados); `dart_defines/*.json` com as três chaves; rota desconhecida/escondida redireciona à Home.

### E7. "Deferred loading" não existe de fato
- **Evidência:** `app_router.dart:100-103` — único `DeferredRouteLoader` só chama `ensurePdfrxInitialized` (init de runtime); `grep 'deferred as'` = 0; Fase F foi revertida (WebKit não registra `.part.js`, `app_router.dart:34-35`).
- **Refactor:** padrão `<feature>_entry.dart` + `deferred as` no router; piloto com `chords` e `social`; é o padrão que TODO #11 (plugins) precisa. Medir com `--dump-info`.
- **Esforço:** M · **Risco:** médio (providers ficam na lib base) · **Conf.:** alta nos fatos, média no ganho

### E8. Sem `Failure`/`Result`: 14 `*Result` ad-hoc, 14 exceções com mensagem em PT no domínio, 55 catches silenciosos
- **Evidência:** `open_carousel_pdf_in_reader.dart:38-55`; exceções com `.message` fora do l10n; 55 `catch (_)`/`on Object {}` sem log (18 em presentation).
- **Refactor:** `sealed class AppFailure {Network, Offline, NotFound, Storage, Auth, Conflict, Unknown}`; `failureMessage(l10n, f)` central; migrar primeiro `pdf_opening`/`offline`.
- **Esforço:** M · **Conf.:** média-alta
- ✅ **Implementado (2026-09-12, onda 4)** — `5a07709`, `59d8561`, `e6cf45c`, `34c8913`, `a2ae708`, `2837196`: `sealed class AppFailure` (network/offline/notFound/storage/auth/conflict/unknown) com `AppFailure.from` e `failureMessage(l10n)`; catches da presentation de pdf_reader e offline migrados (sem silenciosos); `PdfExternallyDeleted` mantém texto e atalho «Baixar»; falta de espaço mantém a mensagem própria; exceções de caminho/leitura sem PT no domínio. Outros features ficam para depois.

### E9. Observabilidade zero: sem error boundary, logs por feature, `retry: null` não documentado
- **Evidência:** `main.dart` sem `FlutterError.onError`/`PlatformDispatcher.onError`/`runZonedGuarded`; 3 utilitários de debug log locais; `main.dart:17`.
- **Refactor:** `AppLogger.of('feature')`, `installErrorHandlers(reporter)` com `ErrorReporter` port (no-op agora, Sentry web depois).
- **Esforço:** S · **Conf.:** alta
- 🟡 **Fatia 1 (2026-09-04, onda 2)** — `b2d556e`: `AppLogger.of('feature')`, porta `ErrorReporter` (no-op) e `installErrorHandlers` em `main.dart` (`FlutterError.onError`, `PlatformDispatcher.onError`, `runZonedGuarded`). Falta: migrar os `debugPrint('[x]')` existentes e ligar um reporter real.
- 🟡 **Fatia 2 (2026-09-11, onda 3)** — os arquivos novos da onda usam `AppLogger.of('feature')`; continuam `debugPrint` legados e nenhum reporter real.

### E10. Infra de teste: sem fakes compartilhados, sem `pumpApp`, sem goldens, smoke web trivial
- **Evidência:** 48 fakes duplicados; `test/helpers/` só com 2 arquivos; cada widget test monta `MaterialApp` à mão; `test/web/chrome_smoke_test.dart` só checa `kIsWeb`; `flutter test -j 1` por causa do binário Isar.
- **Refactor:** `test/support/` com `pumpApp`, `InMemory*Repository`, `FakeColdigomSource`, `TestProviderOverrides.standard()`; goldens para card, chip e tile.
- **Esforço:** M · **Conf.:** alta
- ✅ **Implementado (2026-09-12, onda 4)** — `1ba6549`, `9e792fa`: `test/support/` com `pumpApp`, `standardTestOverrides` (prefs, Isar indisponível, opener, carousel datasource, `PlatformCapabilities`) e as 5 fakes mais duplicadas (35 arquivos migrados); 5 testes que abriam o Isar real agora pinam os overrides. Sem goldens.

### E11. Lints permissivos
- **Evidência:** `analysis_options.yaml` = `flutter_lints` + `prefer_single_quotes` + `avoid_print`. Sem `strict-casts/inference/raw-types`, `unawaited_futures`, `cancel_subscriptions`, `always_use_package_imports` (imports mistos no mesmo arquivo, ex. `louvor_group.dart:1-9`).
- **Esforço:** S (config) + M (fix-ups) · **Conf.:** alta

### E12. Prontidão para sync: entidade boa, mas domínio importa a pasta do banco e o wire format herda D2
- **Evidência:** `saved_playlist.dart:1-5` importa/re-exporta enums de `core/database/collections/`; `RemotePlaylist` sem `schemaVersion`; publicação (`isPublished`, `publicationReach`) na mesma collection da playlist (Social vai precisar de metadados públicos separados).
- **Refactor:** mover enums para o domínio; `schemaVersion`; `PlaylistPublication` própria ligada por `playlistId`.
- **Esforço:** S–M · **Conf.:** alta

### E13. `kIsWeb` vaza na presentation; sufixos de plataforma inconsistentes
- **Evidência:** `audio_player_session_provider.dart:138,157,213,246`, `playlist_sync_lifecycle.dart:61`, `deep_link_listener.dart:52`; sufixos `_stub`/`_native`/`_io` misturados.
- **Refactor:** `PlatformCapabilities {supportsBackgroundAudio, needsUserGestureForAudio, supportsFileSave, …}` via conditional import + provider overridável (plugins metrônomo/afinador vão depender disso).
- **Esforço:** S · **Conf.:** alta
- ✅ **Implementado (2026-09-12, onda 4)** — `bb7717d`, `76810ee`: `PlatformCapabilities {isWeb, supportsBackgroundAudio, needsUserGestureForAudio, supportsFileSave, supportsFullscreenApi}` por conditional import + `platformCapabilitiesProvider`; zero `kIsWeb` na presentation. Sufixos de arquivo não renomeados.

### E14. Convenções: pt/en misturado na mesma classe; `pdfId` para ids que não são PDF; estrutura por feature desigual
- **Evidência:** `SavedPlaylist { nome, salva, favorita, updatedAt, syncStatus }`; `auth`, `audio_player`, `social`, `coldigom` sem use cases; `ports/` vs `repositories/` para o mesmo conceito.
- **Esforço:** S (contínuo, junto com E1/D2) · **Conf.:** alta

---

## F. Ordem de execução sugerida

**Onda 0 — sinal vermelho (horas):** B0 (testes falhando), E5 (código morto + docs), E9 (error boundary + logger).

**Onda 1 — quick wins de culto (S, independentes):** B1, B2, B7, B11, B12 (retry), B13 (cancel/`.tmp`/ZIP), B14, B15, C2, C10, C14, D10, A2, A4, A6, A7, A15, A16, E6 (flags por env), E11.

**Onda 2 — web em rede ruim e "ouvir enquanto lê" (M):** A1, A3, A5, A8, A12, B3, B4, B5, B10, B16, C1, C4, C5, C8, C11, D1, D4, D5, D6, E2, E10, E13.

**Onda 3 — estruturais (L, um por vez, antes de ligar sync em produção):** E1 (`CatalogMaterial` + `MaterialKind.gesture`), D2 (fila única + wire v2), D3 (carousel como view), E3 (`CatalogSource` + sheet único), E7 (deferred piloto), E4 (splits intercalados), D7, D8, C7, D9, A9, B9, E8, E12.

**Dependem de decisão de produto/backend:** C3 (letra no manifest), B9/B18 (semântica de exclusão, conflito e conta em dispositivo compartilhado), D11 (tela de estudo), A9 (política de cache na CDN).

---

## G. Status dos backlogs anteriores (verificado no código)

| Documento | Ainda aberto |
|---|---|
| `PERFORMANCE_BACKLOG.md` (v1) | nenhum |
| `PERFORMANCE_BACKLOG_V2.md` | A5 regrediu (→ A15) |
| `LEITOR_PERFORMANCE_BACKLOG.md` | #3 (→ A3), #12 (→ B15/C8 erro do viewer) |
| `WEB_PERFORMANCE_AND_LOADING.md` | Fase C divergente (`no-cache`), Fase F revertida — doc desatualizada (→ A9, E7) |
| `WEB_PERFORMANCE_RELIABILITY_AUDIT.md` | C3 parcial; A1/A3/B1/C1 implementados |
| `OFFLINE_PERFORMANCE_BACKLOG.md` | #8 e #14 parciais |
| `OFFLINE_DOWNLOAD_RELIABILITY_BACKLOG.md` | #6, #7, #8, #9 parciais (→ B4, B13) |

**O que já está bem e deve ser preservado:** isolamento do pdfrx em `pdf_reader/data/adapters`; conditional imports concentrados na data layer; use cases puros em `offline`/`playlists`/`pdf_reader`; `SyncPlaylists` injetável; cache-first do catálogo com skeleton; `SavedPlaylist` com `playlistId` UUID, `updatedAt`, `version`, `syncStatus`, `deletedAt`; ADRs e `FEATURE_INDEX.md` como contexto (só precisam de check de paths no CI).

---

## H. Onda 1 executada (2026-09-03)

**Escopo:** o Top 12 da seção 1, dividido em 10 tarefas (`docs/superpowers/plans/2026-09-02-top12-web.md`), executado por subagentes em worktrees paralelos (tarefas 1–8, arquivos disjuntos) e depois em sequência (9 e 10), cada tarefa com revisão de especificação + qualidade e rodada de correção antes de entrar em `web/integration` por cherry-pick (histórico linear, 30 commits de `13c375a` a `09a6767`, mais 8 commits da onda final de correções, `97dfcb4` a `b57a273`).

| Sinal | Antes (`6f5a181`) | Depois (`b57a273`) |
|---|---|---|
| `flutter analyze` | 1 info | 1 info (o mesmo, em teste) |
| `flutter test` | 4 falhas / 798 | **0 falhas / 1076** (+278 testes) |
| `flutter test --platform chrome test/web` | não medido | verde (o `web_index_perf_test.dart` ganhou `@TestOn('vm')`) |
| Fontes no caminho crítico | ≈ 3 MB | ≈ 290 KB de fontes subsetadas + ícones tree-shaked |
| Manifest por boot | 1,45 MB sempre | `/checksum` condicional + 304; regrava só se mudou |

### H.1 O que entrou, por item

| Item | Commits | Resultado |
|---|---|---|
| B0 | `011f8a9` | `apiBaseUrl` respeitado; suíte verde |
| B1 | `8699fc7` | sessão só limpa em 401/403 |
| B2 | `1a17f05` | `retryable_init.dart`; "Tentar novamente" funciona para pdfrx, GIS e loader |
| A1 | `7a283dc` | `syncManifest` + `ETag`/304 no Worker |
| A2 | `3e4af1a` | `scripts/subset_fonts.sh`, preload, tree-shake |
| A3 | `0753efe` | abrir louvor não espera Coldigom; playlist/resolve em paralelo |
| B3 | `3a7c0e7`, `2d4a824` | apagar PDF offline só com evidência (bytes lidos ou erro de formato do pdfium) |
| B4 | `2527ea0`, `6c5cc19` | quota web → `InsufficientDiskSpaceException`, conclusão honesta |
| C1 | `4547891`, `3009075`, `69a7695`, `82ff910`, `c595a57` | atalhos globais, pedaleira no PDF, cifra, busca |
| C2 | `4547891` | wakelock de palco |
| D1 | `fa97e7c`, `d468ef9`, `3a0b8bf`, `f63d52d` | ponte áudio ↔ partitura + "seguir o áudio" |
| E1/E2 (fatia 1) | `55bd941`, `fc90988`, `ed82aee`, `1e47bf9` | `MaterialKind`, `CatalogMaterial`, opener + escada única |
| D2 (fatia 1) | `f66c6ce`, `ec3ae57`, `7cc31cd`, `09a6767` | `items` no modelo/Isar/wire v2; projeções mantêm as faces |

### H.2 Decisões tomadas durante a execução (para revisar)

- **A3:** a navegação espera `Future.wait([resolve, addToPlaylist])`, não só o resolve — manter o carousel consistente valeu mais que os ms de uma escrita Isar local.
- **B3:** `retry: null` no `pdfReaderSessionProvider` vale para **todos** os erros (inclusive rede): erro imediato com "Tentar novamente" manual em vez de ~38 s de spinner de retry automático do Riverpod.
- **D1:** "seguir o áudio" ignora a restauração da sessão e compara por **grupo** (louvor), não por id de material — a cifra escolhida não é trocada pela partitura irmã.
- **C1:** `Espaço` só vira play/pause quando nenhum controle ativável/scrollável tem foco (senão o botão/scroll padrão do Flutter fica mudo com uma faixa carregada).
- **E1:** `ChordMaterialRef` (wrapper) em vez de adaptar a entidade de cifra — `sealed` só admite subtipos na mesma biblioteca.
- **E2:** `openMaterialProvider.open` ainda **sem chamador em produção**: os pontos de entrada partem de `pdfId` cru; a duplicação foi removida por `chordReaderLocationFor` e pela escada única.
- **D2:** ids `youtube`/desconhecidos ficam na face PDF (round-trip do legado); só `gesture` é invisível às duas faces; dedupe passou a ser por `items`; áudio ainda é classificado por extensão (fonte de verdade é o `type` do Worker — guardar `kind` junto do id é fatia 2).

### H.3 Pendências conhecidas (revisão final da branch + revisões por tarefa)

**H.3.a — Corrigidas na onda final (revisão da branch inteira, 7 Important + lista curta):**
- `97dfcb4` A1: o checksum persistido é o ETag do corpo baixado (`fetched.etag ?? freshChecksum`), não o de `/checksum` — os dois têm caches de navegador independentes; `debugPrint` quando a resposta vem sem ETag.
- `3f9a68d` A1: `_refreshFromRemote` inteiro dentro do `try` com `ref.mounted` após cada `await`; boot frio passa por `syncManifest` e já persiste o checksum (gate arma no 2º boot, não no 3º).
- `a872a9c` B1/B2: falha de init do Google SDK não devolve `null` antes de ler a sessão armazenada (defeito do plano, que contradizia B1); `googleSignInUnavailableProvider` alimenta o botão; `debugPrint` para `GOOGLE_CLIENT_ID_WEB` ausente; testes de 401/403 → `AuthUnauthorizedException`.
- `129a9dc` D1: "seguir o áudio" passa a valer para a **primeira** faixa da sessão — `restoredWithoutPlayback` explícito na sessão de áudio, limpo por qualquer intenção de reprodução do usuário, em vez de `previousGroupId == null`.
- `dfef4f4` D2: `gesture` entra na face de partituras (era invisível às duas faces → linha fantasma).
- `ce11678` D2: `audioIds` declarados pela linha/Worker viram evidência por instância (`declaredAudioIds`) — um áudio com extensão fora da lista não migra para a face de partituras nem é consumido pelo sync do carousel.
- `422273b` D2: teste de evolução de schema do Isar (engine sqlite, schema legado sem `items` → reabre com o schema novo → migração lazy). Cobre o engine, não o OPFS do navegador.
- `b57a273` lista curta: toggle "seguir o áudio" sempre visível; `setEnabled` com `catchError`; `_removeCorruptedLocalPdf` lê o repositório uma vez; `warmupColdigomInBackground` único; teste da pedaleira no handler; plural ICU em "N arquivos com falha"; `@TestOn('vm')` no `web_index_perf_test`; literal "Carregando leitor…" removido; doc de fontes e `fontTools` pinado; `Esc` não rouba o fechamento de um sheet modal.

**Deixadas de propósito para a próxima onda (não bloqueiam):**
- **Playlist/áudio:** memoizar `resolveMaterialForGroup` na face de áudio (`Provider.family`); overflow da barra da face em 360 px; `isReaderRoute` duplicado; `currentReaderMaterialPdfId` ignora o fallback de `readerRouteParamsProvider`; `findTombstones` migra linhas prestes a ser apagadas; `create()` grava as colunas de compatibilidade sem reprojetar; `assert` de `replaceSubset` vazio nos dois chamadores; `AudioPlayerSessionNotifier.close()` sem uso.
- **Offline:** entradas órfãs na Cache API após abort por quota (reconcile pulado no caminho de exceção); `nothingWasStored` como proxy em `resumeFromCheckpoint`; `PdfStorageWriteException` no lugar errado; sem teste de widget do snackbar; chave `offlineInsufficientDiskSpace` morta.
- **Teclado/leitor:** `_activeKeyboardFocusNode` global de módulo; wakelock com `dispose()` durante `enable()` em voo; `app_shortcuts.dart` faz quatro coisas; `_navigateLouvor` duplicado nos dois leitores; tooltip de `Espaço`/`Ctrl+Espaço`; `Espaço` não rola a cifra (o `Focus` da tela captura o foco); `N`/`P` sem guarda de Shift; `activateFirstHomeSearchResult` caminha a árvore por `GlobalKey`.
- **Leitor/PDF:** `classifyPdfOpenFailure` ainda casa substrings do pdfrx quando `hasValidMagicBytes == null`; arquivo de 0–3 bytes classifica corrompido; `PdfIntegrityValidator` importado entre features; mensagem padrão só em PT na família de exceções.
- **Catálogo/material:** desvio de cifra decodifica base64 duas vezes (`chordReaderLocationFor` devolve `null` para "não é cifra" e "cache frio"); ciclo de import `open_louvor_in_reader` ↔ `open_material_provider` (inerte); `LouvorMaterialIcons.forCategory` deprecado sem substituto ergonômico; `_kindLabel` lança e `_buildKindList` devolve vazio para os mesmos ramos.
- **Worker:** `matchesEtag` só aceita um valor (lista ou `*` → 200); sem teste do 304; `items` ainda não é persistido (todo pull achata a ordem).
- **Verificação manual recomendada antes de publicar:** abrir um banco Isar criado pelo build anterior (OPFS, web) com o build novo e confirmar que as listas sobrevivem com a ordem.

### H.4 Próxima onda recomendada (rascunho — confirmar com o dono do produto)

Ordem sugerida, mantendo o critério "primeiro o que sustenta as features grandes, depois o que o culto sente":

1. **D2 fatia 2 — fechar a ordem única de ponta a ponta.** Coluna `items` (com `kind`) no D1 do Worker + handlers v2; `PlaylistEntry{id, kind}` no cliente para parar de classificar áudio por extensão; `PlaylistMediaFace` vira filtro sobre `items`; URL de compartilhamento v2 preservando a ordem. Pré-requisito para ligar o sync em produção (B9/B18 dependem disso).
2. **E1 fatia 2 + E3 — `LouvorGroup` sobre `CatalogMaterial`.** Ligar sheet/cards/carousel ao `openMaterialProvider`, renomear `pdfId` → `materialId` nos contratos, `CatalogSource` para tirar o Coldigom da presentation (4 caches por tipo, dois sheets, 4 `StateProvider` da Home). Destrava gestos (`.txt`/`.gest`) e favoritos de material.
3. **Estabilidade que sobrou da lista (S/M):** B5 (Isar indisponível), B6 (race no `pdfReaderSessionProvider`), B7 (deep link com `%` malformado), B8/B9 (sync: registro malformado, `pendingPush` em todo boot), B10 (refresh do `id_token`), B11 (`errorStream` do áudio), B12 (cifra com `null` cacheado), B13/B14 (bulk: cancel, `.tmp`, exclusão mútua), B16 (retry nos `Dio`), E9 (error boundary + logger).
4. **Performance web ainda aberta:** A4/A5 (mapas por mutação e query por card), A7 (player a 5 Hz observado inteiro pelo shell), A8/A11 (boot serializado, `pdfium.wasm` competindo com o manifest), A9 (política de cache dos entrypoints — precisa de decisão de CDN), A12 (busca Coldigom sem cancelamento), A13 (teto de raster no leitor), A14 (cifra re-layouta inteira).
5. **UX de culto (S):** C4/C5/C8/C10/C11/C14 e D4–D6 (retomar de onde parou, "próximo louvor" visível, transposição por louvor, feedback de erro do viewer).

Fora da onda até haver decisão de produto/backend: C3 (letra no manifest), B9/B18 (semântica de exclusão/conflito e conta em dispositivo compartilhado), D11 (tela de estudo), A9 (cache na CDN), E7 (deferred loading piloto).

---

## I. Onda 2 executada (2026-09-03 → 2026-09-04)

**Escopo:** a "próxima onda recomendada" da seção H.4, aprovada pelo dono do produto: D2 fatia 2, E1 fatia 2 + E3 fatia 1, e a estabilidade restante (B5–B17, E9). Spec em `docs/superpowers/specs/2026-09-03-onda2-web-design.md`; plano em `docs/superpowers/plans/2026-09-03-onda2-web.md` (16 tarefas). Mesmo método da onda 1: fase 1 com 10 tarefas em worktrees paralelos (arquivos disjuntos), depois T2/T3 (wire e URL) e T14 (sync), depois T15/T16 (catálogo) em sequência; cada tarefa com revisão de especificação + qualidade e rodadas de correção antes do cherry-pick em `web/integration`.

### I.1 O que entrou, por item

| Item | Commits | Resultado |
|---|---|---|
| D2 fatia 2 | `2523836`, `f413bee`, `26d4fac`, `12d296b`, `a5a71a5`, `b31d1ae`, `d1dffed`, `303e99a`, `6cd3e4e`, `978e629` | `PlaylistEntry{id, kind}` como fonte de verdade; `itemKinds` no Isar com migração lazy; wire v2 com `items` como objetos; Worker persiste `items` (migration `0008`, kinds preservados em PUT v1, ETag multi-valor, testes com D1 fake, job de CI); URL de compartilhamento com `shareitems` |
| B8/B9 (sync) | `1b555c3`, `38094ec`, `262da03` | pull tolerante por item, `lastError` com banner e retry, `sub` persistido, 409 com LWW e `conflict`, tombstones com limite |
| E1 fatia 2 + E3 fatia 1 | `44c0948`, `f272c4f`, `c50acf9`, `88774be` | `LouvorGroup.extras` como `CatalogMaterial`; porta `CatalogSource` + `resolveCatalogMaterial`; desvios de cifra/áudio pelo `openMaterialProvider` |
| B5 + B14 | `22c7c08`, `9e26784`, `19a1e7a` | `StorageUnavailableException`; reconcile nunca apaga com índice vazio/indisponível; lock de manutenção offline |
| B13 | `10eceeb`, `e61a2bf`, `d309b7b` | cancel honesto, `.tmp` do checkpoint preservado, ZIP corrompido, watchdog de stall |
| B6 | `2a4ad0c` | race do `pdfReaderSessionProvider` |
| B7 | `552849c` | deep link seguro (`safeQueryParameters`, snackbars, dedupe) |
| B10 + B16 | `fa50ddd`, `253d506`, `2d1bd21`, `1b66ccf` | expiração/refresh do token, `AuthRefreshInterceptor`, `RetryInterceptor`, `userMessageFor` |
| B11 | `a5e25c3`, `ec28651`, `2cd2b1b` | áudio sem corrida, erro visível, retry |
| B12 | `c189fc4`, `1e213c5`, `efde830` | cifra: 404 vs falha, `autoDispose`, cache Isar com TTL |
| B15 | `930e7a9` | catálogo com retry, reconexão, DTOs tolerantes |
| B17 + E9 fatia 1 | `b2d556e`, `ae6f352` | timeout do Isar, `AppLogger`, handlers globais |

### I.2 Decisões tomadas durante a execução (para revisar)

- **Wire v2 fechado com `items` como objetos** `{id, kind}` (nenhum Worker jamais persistiu a v2 em strings); o cliente lê v1, v2-strings e v2-objetos; o Worker tolera strings no PUT e preserva `kind` em PUT v1 quando o id continua na mesma face.
- **`shareitems` na URL** com prefixos `p/c/a/y/g/u`, emitido junto dos parâmetros legados (URL maior até o encurtador, D7).
- **Face de partituras** = tudo que não é áudio (inclui YouTube e desconhecidos); `pdfIds:` vindo do carousel nunca reclassifica um id que já existe na lista.
- **Reconcile completo com índice vazio e arquivos no disco é pulado**, nunca executado (o índice vazio é sinal de Isar indisponível, não de "não há PDFs").
- **PDF abre em modo degradado** (gravado sem índice) — a exceção de storage vale só para quem precisa do índice (bulk, faltantes, limpar).
- **Refresh que devolve o mesmo token conta como falha** e a sessão vai para "expirada" — senão os providers que observam o usuário reconstroem e realimentam o laço de 401.
- **Retry de rede com opt-out** nos dois laços próprios do offline (senão 9 tentativas por PDF).
- **Marca de troca de fontes do áudio é um contador do player**, não da geração da fila.
- **`chordSongProvider` `autoDispose`** com `keepAlive` só no sucesso; 404 vira marcador negativo no cache.
- **Migration `0008` precisa ser aplicada antes de publicar o Worker** (o `SELECT` já pede a coluna `items`).

### I.3 Pendências conhecidas (revisão final da branch)

**I.3.a — Corrigidas na onda final de correções (revisão da branch inteira: 0 Critical, 5 Important + lista curta):**
- `72f13bb` adicionar à lista ativa sem storage (a partir do sheet/áudio) não estoura mais: os dois `add*ToActivePlaylist` devolvem `false` em `StorageUnavailableException` e `playAudioInSession` só grava com Isar disponível.
- `7bca396` `presentMaterialOpenError` usa `userMessageFor` (sem conexão, storage, auth) em vez do genérico.
- `6c9376e` `userMessageFor`: a causa genérica (404/desconhecido) não atropela a mensagem específica do wrapper de PDF.
- `f25b780` contrato pinado: `availableChordsProvider` nunca emite `AsyncError` (a linha "cifra indisponível" do sheet é defensiva e está anotada).
- `0460b14` `AuthUserExpiry` ligado: refresh preventivo em `onRequest` quando o `exp` está a menos de 2 min (um só refresh para requests concorrentes; falha → 401 trata sem segundo refresh).
- `166e358` `catalog_refresh_provider.dart` (morto) apagado; helpers de retry de download movidos para `core/network` (sem `core → features`).
- `ba3801b` ícone do sheet por `forMaterial`; deep link que falha entra no dedupe; ações do tile sem storage mostram o aviso.

Residuais da onda final (não bloqueiam): falha do refresh preventivo marca a sessão como expirada antes de qualquer 401 (janela de 2 min); comentário desatualizado em `dio_provider.dart`; ciclo de import `user_message_for` ↔ `open_material_provider`; `forceRefreshCatalog` + chaves `catalogRefresh*` sem uso.

**Deixadas para a próxima onda (não bloqueiam):**
- **Sync/Worker:** rota pública `social/handlers.ts` (`listPublicPlaylistsByUsername`) ainda responde v1 (perde a ordem intercalada e achata `youtube`); `audio_flag_sync_provider.dart` continua no formato antigo (sem `sub` persistido, sem isolamento do pull); falha em `syncAfterLogin` não é retentada na sessão; o ramo de re-push do 409 é inalcançável contra o Worker atual (409 só quando o cliente é mais antigo); LWW descarta edições locais pendentes quando o remoto é mais novo — vale guardar o perdedor como cópia em `conflict`; falta `tsc --noEmit` no job de CI do Worker.
- **Offline:** guarda do reconcile completo é "índice vazio" — um índice com 1 linha sobre 4000 arquivos ainda apaga 3999 (usar razão arquivos/índice); `isarAvailableProvider` é falso durante o carregamento (bulk no boot frio web reporta storage indisponível); `deleteOnError` do `dio.download` impede retomar por Range após um stall; `activeCheckpointName` calculado uma vez; `offlineMissingDownloadProvider` sem consumidor; `hasAnyFile()` ausente na porta.
- **Auth/rede:** falha transitória do refresh silencioso trava `sessionExpired` até novo login; `PdfExternallyDeletedException`/`PdfLocalCorruptedException` ainda com literais PT.
- **Áudio/cifra:** seam `audioSessionPlayerFactoryProvider` só para testes; sem teste de widget do retry do player; overflow da face de áudio em 360 px (pré-existente); revalidação de cifra nunca limpa uma cifra apagada no servidor (marcador negativo fica além do TTL).
- **Catálogo/material:** `LouvorGroup.extras` só é consumido pelos getters tipados (um `PdfMaterial` em `extras` não renderiza); grupos Coldigom construídos pela porta não carregam YouTube; `resolveCatalogMaterial(Ref)` sem chamador; rótulo de seção some em grupos PLPCG de uma seção; chave `pdfMaterialSection` sem uso; linha de erro Coldigom esconde o paginador a partir da página 2.
- **Playlist:** `create.pdfIds` deixou de ser obrigatório; URL só com nome é pulada em silêncio; outros chamadores do `OpenMaterial` não passam fila.
- **Teste:** `zip_package_downloader_test` custa ~18 s (watchdogs reais de 3 s); um smoke test de widget em modo degradado (Isar indisponível) pegaria o item A1 da onda final.
- **Sobras da onda 1** (inalteradas): memoizar `resolveMaterialForGroup`; entradas órfãs na Cache API após abort por quota; `_activeKeyboardFocusNode` global; wakelock com `dispose()` em voo; `app_shortcuts.dart` faz quatro coisas; `_navigateLouvor` duplicado; tooltip de `Espaço`; `Espaço` não rola a cifra; `N`/`P` sem Shift; `PdfIntegrityValidator` importado entre features; ciclo `open_louvor_in_reader` ↔ `open_material_provider`.
- **Deploy (feito em 2026-09-04):** migration D1 `0008` aplicada no D1 remoto e Worker publicado (versão `22c480e5`). Verificação manual feita: banco Isar (OPFS) criado por um build da base `13c375a` (antes das migrações `items`/`itemKinds` e da coleção `ChordContentCache`), com uma lista salva de 3 entradas (partitura, partitura, cifra), abriu no build de `ba3801b` na mesma origem com a lista intacta e na mesma ordem.

### I.4 Próxima onda recomendada

1. **Fechar o sync de ponta a ponta:** rota social v2, `audio_flag_sync_provider` no mesmo formato do de playlists, cópia em `conflict` no LWW, `tsc --noEmit` no CI; decidir a semântica de exclusão remota (B9/B18) com o dono do produto.
2. **D3 — carousel como view da lista ativa:** `CarouselEntry` some, `PlaylistMediaFace` vira filtro puro, `pdfId` → `materialId` nos contratos; permite louvor repetido e fecha o D2.
3. **E3 fatia 2:** `HomeSearchState` imutável em `AsyncNotifier` com cancelamento e memo; `CatalogSource.search`; tirar os 4 caches por tipo da presentation.
4. **Performance web (A4–A14):** mapas por mutação e query por card, player a 5 Hz, boot serializado e `pdfium.wasm` competindo com o manifest, teto de raster, cifra re-layoutando; A9 depende de decisão de CDN.
5. **UX de culto (C4–C16, D4–D6):** estado vazio da Home, ícones de material no card, split view em tela larga, fit/fullscreen/duas páginas no leitor, autoscroll da cifra, fila do player = lista ativa, mini-player persistente.

---

## J. Onda 3 executada (2026-09-04 → 2026-09-11)

**Escopo:** a "próxima onda recomendada" da seção I.4, aprovada pelo dono do produto ("onda 3"): fechar o sync de ponta a ponta, D3 (carousel como view da lista ativa), E3 fatia 2 (busca da Home pela porta) e as sobras da onda 2 mais o boot web (A7, A8, A11). Spec em `docs/superpowers/specs/2026-09-04-onda3-web-design.md`; plano em `docs/superpowers/plans/2026-09-04-onda3-web.md` (17 tarefas). Mesmo método das ondas anteriores: fase 1 com 10 tarefas em worktrees paralelos, fase 2 com 4 (widgets do carousel, leitor, Home, código morto), T14 e T16 em sequência; cada tarefa com revisão de especificação + qualidade e rodadas de correção antes do cherry-pick; revisão da branch inteira ao final e uma onda única de correções. A sessão caiu duas vezes no meio (limite de uso); os worktrees preservaram o trabalho e os agentes foram retomados.

### J.1 O que entrou, por item

| Item | Commits | Resultado |
|---|---|---|
| Sync: tombstones, cópia de conflito, dono por conta (B9, B18) | `a81bc1e`, `134e00b`, `efa863b`, `b37435b`, `a81eec4`, `a6b6982`, `391fbdf` | Worker expõe tombstones (`includeDeleted=1`, `deletedAt`); lista apagada em outro aparelho some daqui; 409 com remoto mais novo guarda «(cópia local)»; `ownerSub` em `Playlist`/`AudioFlag`; troca de conta purga o que já está na nuvem da conta anterior e adota só o sem dono; `getPendingPush`/`getTombstones` por dono; retentativa do pós-login, sync ao voltar a rede e ao abrir o Isar; **sync recarrega a tela quando move linhas** |
| Marcadores de áudio no mesmo formato | `44cec66`, `955fd90`, `7f1a5ee`, `0a6c1bc` | pull isolado, 409 LWW, tombstones com cap, `sub` persistido, erro visível no player, dono, espera do Isar |
| Rota social v2 + import por entradas | `ec5f50e`, `2cc5472`, `d1fcbe7` | `items` na rota pública; `PublicPlaylist.entries`; import leva ordem, tipo e áudios |
| Worker CI | `cde7d4b` | `tsc --noEmit` e testes por glob (84) |
| D3 — lista ativa única | `4175b9c`, `9e764d3`, `c68b113`, `914407e`, `a4b326e`, `793779e`, `df4acb8`, `899990c` | `ActivePlaylistEditor`; views por face; chave por ocorrência; louvor repetido; migração única do carousel Isar; leitor/chips/seleção por chave; adaptadores apagados |
| D4 + D6 | `5689cb7`, `8a9c7f7`, `119a0eb` | fila = lista ativa quando a faixa está nela; «Tornar lista ativa» sem modal com desfazer |
| E3 fatia 2 + A12 + A10 fatia 1 | `2f19870`, `73f7392`, `f886ccb`, `40fceac`, `702e1a3`, `d7060cf`, `a4bc52f`, `cf69925`, `4c5e2c2` | `CatalogSource.searchLocal/search`; índice PLPCG por manifest; cancelamento e memo Coldigom; `HomeSearchState` imutável; caches gravados no data e lidos pelo `CatalogMaterialLookup`; DI de rede separado dos caches |
| A4, A5, A7 | `19e49e8`, `4fbd4a7`, `a0f841b` | mapa por manifest; badge offline por mapa único; posição do player em provider próprio |
| A8 + A11 | `a165b10`, `98dbc45`, `7d0edaa`, `98f8139`, `6c9c449`, `442eb66` | app monta durante a abertura do Isar; manifest começa antes; `pdfium.wasm` depois do manifest; hidratação e adição à lista esperam o Isar |
| Sobras da onda 2 | `88b5967`, `09815ae`, `d0cdef0`, `59d3326`, `5c496c7`, `cf23728`, `089dd85`, `4289528`, `9f34f7f`, `5fb02c9`, `dc7640e`, `32178dd`, `114e9bf` | reconcile pulado com índice muito menor que o disco; `.tmp` sobrevive ao stall e só é emendado se o pacote é o mesmo; refresh transitório não expira a sessão; cifra apagada vira marcador negativo; mensagens de PDF pelo l10n; share só com nome avisa; código morto e ciclos; paginador da Biblioteca; `CatalogFilterState` no domínio; leaflet |

### J.2 Decisões tomadas durante a execução (para revisar)

- **Exclusão remota só por tombstone explícito** (`includeDeleted=1`), nunca por ausência; a local com edição pendente mais nova que o `deletedAt` ressuscita a lista.
- **409 com remoto mais novo não descarta a edição local:** vira lista nova «X (cópia local)» com status `conflict`, que só sobe se o usuário a editar. `conflicts` não conta as cópias (o banner mostra a linha própria).
- **Troca de conta apaga localmente as listas/marcadores `synced` da conta anterior** (estão na nuvem dela); pendentes e rascunhos ficam e não entram no push da conta nova. Listas criadas sem login continuam sem dono até o primeiro push.
- **Identidade de entrada = posição**; chave por ocorrência (`id`, `id#1`, …) para foco, chips e mutações. Adição rápida continua idempotente; «Adicionar de novo» repete.
- **Lista salva esvaziada fica vazia** (não vira tombstone); rascunho esvaziado é apagado.
- **«Tornar lista ativa» sem confirmação** (nada é destruído); «Desfazer» só quando havia outra ativa e nunca derruba uma ativação mais nova.
- **Boot:** o app monta com o Isar abrindo; quem precisa do banco espera (`awaitIsarSettled`) em vez de concluir «indisponível»; o checksum do boot só é gravado quando o manifest realmente entrou.
- **Busca remota da Home com `ref.read` da fonte** (o repositório Coldigom grava os caches que recompõem a fonte — `watch` faria laço).
- **Retomada de ZIP** exige o mesmo `content-length`/`ETag` no HEAD e assinatura `PK` no `.tmp` montado.

### J.3 Pendências conhecidas (não bloqueiam)

- **Sync:** `includeDeleted=1` cresce sem poda; marcadores em `conflict` não têm caminho de recuperação (o remoto vence); listas ainda ownerless até o primeiro push; teste de troca de modo (PLPCG ↔ Coldigom) no `libraryLastGoodResultsProvider`.
- **Lista ativa:** rótulos Coldigom das listas salvas só aparecem num `_reload` posterior ao warmup; `_carouselItemFor` do tile duplica o enriquecimento; `EmptyCarouselException` mora em `playlists/domain` mas só o leaflet lança; `_noLabel` duplicado nos dois use cases do leaflet; seguir o áudio foca a primeira ocorrência.
- **Busca:** `CatalogQuery.pageSize` não é enviado; `PlpcgCatalogSource` guarda `catalog` e `index.louvores`; memo sem teto; `CatalogFilterState` sem `==`.
- **Offline:** badge por índice (sem validar disco) até o primeiro abrir; ETag da retomada só dentro da mesma chamada de `download()`; `content-length` confiado.
- **Boot:** testes que constroem `playlistsProvider` sem override do Isar chamam o opener real (pinar `isarOpenerProvider`); `_reload` sem guarda de geração; um toque em «+» dentro da janela de abertura do Isar com id ativo obsoleto pode disputar com a hidratação (o rascunho criado fica sem ser o ativo) — `addToActive` deveria esperar a hidratação; `addAudioToActivePlaylist` sem chamador em `lib/`.
- **Sobras menores:** 18 chaves ARB órfãs pré-existentes; `tsconfig` do Worker não cobre os testes; `readerCarouselPositionProvider` não é autoDispose.
- **Deploy:** nenhuma migration nova; o Worker publicado (`22c480e5`) já responde v1 da rota social — publicar o Worker novo antes do web app para que o import social leve os áudios.

### J.4 Próxima onda recomendada

1. **UX de culto (C4–C16, D5):** mini-player persistente e independente da face (D5), split view em tela larga (C7), fit/fullscreen/duas páginas no leitor (C8), autoscroll da cifra (C9), estado vazio da Home (C4), ícones de material no card (C5).
2. **D7/D8:** encurtador de link e folheto com entradas de áudio.
3. **Performance restante:** A6 (quota web), A9 (PWA shell cache — depende de decisão de CDN), A13 (teto de raster), A14 (cifra), A10 fatia 2 (Biblioteca sobre o índice).
4. **Arquitetura:** E4 (god files), E6 (feature flags), E8 (`Failure`/`Result`), E10 (fakes compartilhados, goldens), E12/E13.

## K. Onda 4 executada (2026-09-11 → 2026-09-12)

**Branch:** `web/integration` @ `89f96e4` (77 commits sobre `01f2c1b`). **Spec:** `docs/superpowers/specs/2026-09-11-onda4-web-design.md` · **Plano:** `docs/superpowers/plans/2026-09-11-onda4-web.md` (17 tarefas em três fases, subagents em worktrees, revisão por tarefa, revisão final da branch e uma onda de correções).

### K.1 O que entrou, por item

| Item | Commits | Resultado |
|---|---|---|
| D5 + C14 (mini-player, título) | `ab1eb34`, `ca0e3c7`, `1913a34`, `dd2c452`, `0fab43e`, `dc1d4f9` | mini-player persistente no shell e overlay em fullscreen; setas de louvor na face de áudio; `<title>` por rota |
| C8 + C16 (leitor) | `a3954e0`, `97366ad`, `2ab3e71`, `4d35b76`, `8e199ca`, `75f4972`, `c607f36`, `9427f8b` | ajuste (`Z`), fullscreen web, última página, ir para página (`G`), spread em viewport largo |
| C9 + C10 + A14 (cifra) | `ac76885`, `9500380`, `dddae1b`, `78d0ce9`, `322a6de`, `d0715cd`, `f5bc42b` | tom por louvor, sliver + memo, autoscroll, duas colunas pela largura disponível |
| C7 (split view) | `4ab554a`, `cac2713`, `8772a75` | `ActiveListPanel` no leitor e na cifra a partir de 900 px |
| C4 (Home) | `b3491b4`, `87c0366`, `a6c6084` | estados vazios com recentes, «sem resultados», Coldigom offline (o cartão da lista ativa saiu na 4.2) |
| C5 (card) | `485fad4`, `abeb28f`, `a47b05b`, `1055011` | ícones de material, «+» sempre com troca, destaque do termo |
| C11 + C16 (listas) | `539d7a7`, `a3760cb`, `d777450`, `b3887f9`, `fc74aac`, `f30cc59`, `dfb970d` | nome na barra, apagar com desfazer, duplicar, folheto direto |
| C12 (player) | `7979eb6`, `971c863`, `86ff3a2`, `3cdb710`, `cb9ca89`, `89faa2f`, `885bf6e`, `87e3bb2` | ±10 s (`J`/`L`), velocidade, marcador tocando, posição retomada |
| C13 + A6 + A15 + A10 | `c7b50f0`, `8622cac`, `8d51dfb`, `e4783f2`, `d38adce` | filtros e página persistidos; quota pelo índice; nav memoizada; busca morta apagada |
| D7 (link curto, dedupe) | `3a3710b`, `6c314a9`, `3d4ac39`, `984457b` | Worker `short_links` (migration `0009`), share com link curto, import sem duplicar |
| D8 (folheto) | `7656c6c`, `42f3273` | folheto por entradas, com áudio |
| E6 + C6 (flags, rail) | `dcb2997`, `9ded0c6`, `0767526` | flags por `dart-define`, abas derivadas, `NavigationRail` ≥ 840 px, redirect de rota escondida |
| E8 (`AppFailure`) | `5a07709`, `59d8561`, `e6cf45c`, `34c8913`, `a2ae708`, `dcacdbc`, `2837196` | falhas tipadas e mensagem central em pdf_reader e offline |
| E13 (`PlatformCapabilities`) | `bb7717d`, `76810ee` | zero `kIsWeb` na presentation |
| E4 (splits) | `967a0d5`, `ed3ba4a`, `4f1cc86` | tile, tela offline e chip em partes |
| A13 (raster) | `aca420f` | teto de raster e cache 2 na web |
| E10 (`test/support`) | `1ba6549`, `9e792fa` | fakes compartilhadas, `pumpApp`, overrides padrão, testes pinados ao Isar fake |

### K.2 Decisões tomadas durante a execução (para revisar)

- **Última página lembrada** (C8): quem volta a um louvor cai na página em que parou; o indicador mostra «n/N» e o long-press volta à primeira.
- **Spread desligado no ajuste à largura** (C8): pdfrx 2.4.4 não ajusta a uma região; em fullscreen e com `Z` o leitor volta a uma página por linha.
- **Apagar lista sem confirmação, com «Desfazer» por 5 s** (C11): exclusão adiada; fechar a aba nos 5 s cancela a exclusão (nada se perde).
- **Link curto**: criação só autenticada com teto de 100/24 h por conta; `GET /l/:code` público e cacheável, sem rate limit; a URL longa continua com os três parâmetros.
- **Dedupe do import** por conteúdo (`kind:id` na ordem), ignorando o nome.
- **`FF_EVENTS=false`** esconde a aba «Eventos» (placeholder «Em breve») até a feature existir — não é o «Modo Culto» descartado; rotas escondidas redirecionam à Home.
- **Face de áudio**: a posição corrente é a faixa tocando (não o foco da face de partituras); as setas navegam relativas a ela.
- **«Gerar folheto» do menu da lista** não troca a lista ativa.
- **Marcador com o áudio tocando**: posição do toque, sem exigir pausa.
- **Tom por louvor na sessão** (C10): voltar ao mesmo louvor mantém o tom; sem persistência.
- **Trailer dos commits dos agentes**: `Co-Authored-By: Claude Sonnet 5` (modelo que os escreveu), mantido.
- Fora desta onda por decisão: capo, loop A–B, reordenar na barra, mover Listas ao 1º nível, goldens, renomear sufixos `_stub`/`_io`, A9 (SW próprio — decisão de CDN), A16, E12 (separar publicação), C15.

### K.3 Pendências conhecidas (não bloqueiam)

- **Leitor:** `applyInitialFit` continua sendo re-aplicado a cada troca de página (comportamento antigo); navegação por página com spread avança uma página por vez; `_HoverFade` do overlay sem teste de hit-test; `readerCarouselPositionProvider` não é autoDispose.
- **Cifra:** `stop()` adiado do autoscroll pode cancelar um reinício no mesmo frame (token de geração); `chord_reader_screen.dart` com 616 linhas.
- **Listas:** chip do nome observa a entidade inteira; `duplicate` recebe `copyName` do tile. (Renomear rascunho sem sair de «Rascunho» era o bug corrigido em `3e265cf`.)
- **Player:** `audioPlayerPositionProvider.duration` não é zerado numa troca dentro da fila (UI pode mostrar a duração anterior por um tick); `setSpeed` grava o estado antes do player; `MediaSessionPositionThrottle` reutilizado para o store com o nome antigo.
- **Home/card:** `record()` de recentes grava mesmo sem mudança; com remoto falho aparecem a linha «Coldigom indisponível · tentar de novo» e o aviso do estado vazio (checar com produto); ordem de ícones testada sem gestos/YouTube.
- **Worker:** sem rate limit no `GET /l/:code`; `tsconfig` não cobre testes.
- **Arquitetura:** `generate_leaflet_from_entries.dart` (domínio) importa o tipo do lookup da presentation; `offline_settings_screen.dart` (531) e `playlist_tile_actions.dart` (425) ainda grandes; ciclo de import entre `metadata_row.dart` e `carousel_louvor_chip.dart` por duas constantes; `offlineMissingDownloadProvider` e `LeafletDocument.fromPdfIds` mortos; `InvalidPdfPathException` cai na mensagem genérica do leitor; `_tabLabel` do shell com literais PT (convenção antiga da nav); `Title` re-enviado a cada rebuild do shell; `.gitignore` `test/**/failures/` esconderia um futuro `test/unit/core/failures/`.
- **Testes:** `standardTestOverrides` omite prefs quando `null`; `pumpApp` criado mas não adotado; `playlist_add_dedupe_test` e `reconcile_offline_index_benchmark_test` sensíveis à carga (o primeiro agora pinado ao Isar fake).
- **Deploy:** migration `0009_create_short_links.sql` **precisa ser aplicada** e o Worker publicado antes do web app (`wrangler.jsonc` ganhou as rotas `plpcg.com/l/*` e `plpcg.com/api/links*`); `dart_defines/*.json` ganharam `FF_EVENTS`/`FF_SOCIAL`/`FF_ADMIN_UPLOAD` (o build de produção esconde «Eventos»).

### K.3b Ondas 4.1 e 4.2 — correções da validação manual (2026-09-12)

| Commit | O quê |
|---|---|
| `e1a5b3e` | rail com os mesmos `PlpcgNavItem` da barra inferior (ícones SVG, Garamond, brilho) — C6 |
| `d41fa55` | texto branco no estado vazio da Home (era vinho sobre vinho) — C4 |
| `4815aa4` | painel lateral e botão da toolbar removidos; o olho da barra abre a lista — C7 |
| `ff8c100` | «Duas páginas em tela larga» fora do menu; spread só automático — C8 |
| `3e265cf` | «Rascunho» na chip salva a lista com nome (`saveActivePlaylist`); «Salvar como lista» e o menu «⋮» saem, fica só compartilhar (`Icons.adaptive.share`); nome limitado a 1/5 da barra — C11 |

| `06d1c04` | cartão «Lista ativa: … · Abrir no leitor» removido do estado vazio da Home — redundante com a barra do carousel (lista, louvor em foco e abrir); ficam «Abertos recentemente» e a dica — C4 |

Pendência do mesmo padrão: o banner antigo de «catálogo desatualizado» em `home_screen.dart` também pinta vinho sobre vinho (anterior à onda; não mexido).

### K.4 Próxima onda recomendada

1. **Validação em culto:** uma passada manual no navegador do que só o olho pega — fullscreen com mini-player e FAB, spread em projetor, última página, autoscroll da cifra, link curto de ponta a ponta (migration `0009` e Worker já publicados em 2026-09-12; web app ainda não). Em curso — ver K.3b.
2. **Sobras de UX:** C15 (varredura l10n/toque/semântica), capo e loop A–B se houver demanda, reordenar no painel com mouse, `pumpApp` nos testes existentes.
3. **Arquitetura:** E8 nos demais features (catalog, playlists, audio), E12 (separar publicação), E5 (mortos listados em K.3), remoção do `applyInitialFit` por página.
4. **Performance:** A9 (SW próprio) depois da decisão de CDN; A16 se o artefato de deploy importar.

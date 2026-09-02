# Oportunidades de melhoria — Web (PLPCG / coldigui)

**Criado em:** 2026-09-02  
**Branch:** `web/integration` @ `6f5a181`  
**Objetivo:** primeira leva de refatorações para dar sustentação às features grandes que vêm (viewer de gestos, sync de listas, Social, Eventos, plugins, favoritos de material), priorizando a versão web.  
**Método:** leitura direta do código em cinco frentes (performance web, estabilidade, UX/produtividade, fluxo playlist + áudio + PDF, arquitetura), `flutter analyze` e `flutter test`, e verificação item a item dos backlogs anteriores em `docs/`. Cada achado traz `arquivo:linha`. Onde a consequência não foi reproduzida, está marcado **[inferência]**.

Legenda: **Esforço** S (horas) / M (1–3 dias) / L (semana+). **Conf.** = confiança de que o achado é real.

---

## 0. Sinais objetivos da árvore limpa

| Sinal | Resultado |
|---|---|
| `flutter analyze` | 1 info (lint em teste) |
| `flutter test` | **4 falhas** em 798 testes |
| Cobertura | 171 arquivos de teste; 0 goldens; 0 testes de boot/Isar degradado/auth |

As 4 falhas têm a mesma causa: `PdfSourceResolver` aceita `apiBaseUrl` no construtor mas o ignora, porque `_joinApiUrl` passou a chamar `AssetBaseUrlResolver.joinAssetUrl` (global) no commit `c85c567`. Ver item **B0**.

---

## 1. Top 12 — maior retorno por esforço

| # | Item | Eixo | Esforço |
|---|---|---|---|
| A1 | Manifest inteiro (1,45 MB) rebaixado e regravado no Isar em **todo boot**, na UI thread | Perf | S–M |
| A2 | Fontes: `--no-tree-shake-icons` + fontes variáveis inteiras ≈ 3 MB antes do 1º frame | Perf | S |
| A3 | Abrir louvor = cadeia serial (playlist → warmup Coldigom → resolve PDF) antes de navegar | Perf | S–M |
| B1 | Boot offline ou 5xx **apaga a sessão** do usuário | Estab. | S |
| B2 | Falha de init do pdfrx/GIS fica memoizada; "Tentar novamente" nunca funciona | Estab. | S |
| B3 | Qualquer erro ao abrir PDF local **deleta o PDF offline** | Estab. | M |
| B4 | Web: `QuotaExceededError` engolido → bulk "concluído" com 0 PDFs | Estab. | M |
| C1 | Zero atalhos de teclado fora das setas do leitor; busca sem autofocus/Enter | UX | M |
| C2 | Sem wakelock no leitor/cifra/player (tela apaga no meio do louvor) | UX | S |
| D1 | Não existe ponte áudio ↔ partitura do mesmo louvor (o cerne do "ouvir enquanto lê") | Playlist | M |
| D2 | Modelo de lista ainda é duas filas (`pdfIds` × `audioIds`), contra o PRODUCT.md | Playlist/Arq | L |
| E1 | Não há abstração `Material`; tudo é `pdfId` com ramos por tipo (bloqueia gestos e favoritos) | Arq | L |

---

## A. Performance web

Fatos de plataforma que sustentam vários itens: `compute()` na web roda **na thread principal**; Isar Plus na web não tem `writeAsync`/`readAsync` (toda leitura/escrita é síncrona na UI thread).

### A1. Refresh completo do catálogo em todo boot
- **Evidência:** `lib/features/catalog/presentation/providers/louvores_manifest_provider.dart:29-36` — com cache, `unawaited(_refreshFromRemote())` sempre. `catalog_local_datasource.dart:24-33` faz `clear()` + ~4600 `put` numa `isar.write` síncrona. O Worker não emite `ETag` em `/louvores` (`workers/plpcg-catalog/src/index.ts:167-178`); existe `/checksum` mas só é usado no foreground.
- **Efeito:** 1,45 MB por abertura em rede ruim; decode + regravação bloqueiam a UI justo quando o usuário começa a digitar; `state = AsyncData` reexecuta busca, biblioteca, carousel e playlists mesmo sem mudança.
- **Fix:** no boot, consultar `/checksum` (com `If-None-Match`) e só baixar se mudou; `ETag`/304 na rota; não emitir novo estado se o conteúdo for igual.
- **Esforço:** S–M · **Conf.:** alta

### A2. ~3 MB de fontes no caminho crítico
- **Evidência:** `scripts/web_build.sh:38` — `--no-tree-shake-icons`; `MaterialIcons` 1,6 MB + EBGaramond 851 KB + OpenSans 533 KB em `FontManifest.json`. A justificativa do comentário (cache stale) já foi resolvida pelo hash no nome (`scripts/cache_bust_web_entrypoints.sh:1257-1263`).
- **Fix:** reativar tree-shake; subsetar as fontes para Latin e remover eixo `wdth` do OpenSans; `<link rel=preload as=font>`.
- **Esforço:** S · **Conf.:** alta

### A3. Abrir louvor bloqueia até rede do Coldigom responder
- **Evidência:** `lib/features/catalog/presentation/utils/open_louvor_in_reader.dart:26-46` — `await addLouvorToActivePlaylist` → `await ensureColdigomPraiseMaterialsCached` (pode ir à rede, sem try) → `await resolveLouvorPdf` → só então `push`. Mesmo padrão em `reader_carousel_actions_provider.dart:61`.
- **Efeito:** o gesto mais frequente do culto fica "morto" mesmo com PDF em cache. Coldigom fora do ar impede abrir PDF Coldigom já baixado.
- **Fix:** navegar primeiro (leitor já tem skeleton) e rodar playlist/warmup em paralelo com `unawaited` e timeout curto; warmup best-effort.
- **Esforço:** S–M · **Conf.:** alta

### A4. Mapas O(catálogo) reconstruídos a cada mutação de carousel/playlist
- **Evidência:** `lib/features/carousel/presentation/utils/build_carousel_metadata_map.dart:13-23`, `carousel_louvores_provider.dart:43-48`, `playlists_provider.dart:75-81,449` ("Lookup O(n)").
- **Fix:** `Provider<Map<String, Louvor>>` por `pdfId` derivado do manifest (1× por manifest).
- **Esforço:** S · **Conf.:** alta

### A5. Cada card visível dispara uma query Isar síncrona para o badge offline
- **Evidência:** `lib/features/catalog/presentation/widgets/louvor_group_card.dart:291-293` — `FutureProvider.autoDispose.family` por `pdfId` → `findFirst()` síncrono.
- **Fix:** provider único `Map<String,bool>` atualizado por `upsert/remove/clearAll`; cards usam `select`.
- **Esforço:** S–M · **Conf.:** alta

### A6. Cálculo de quota na web itera toda a Cache Storage, até 3× por PDF baixado
- **Evidência:** `lib/features/offline/domain/usecases/fetch_and_store_pdf.dart:57-84` chama `totalCachedBytes()` 3×; na web `pdf_storage_web.dart:78-90` materializa cada blob. `sumFileSizes()` via índice Isar já existe (`offline_pdf_local_datasource.dart:97-100`) e não é usado.
- **Efeito:** com centenas de PDFs offline, abrir um PDF novo custa segundos extras.
- **Esforço:** S · **Conf.:** alta

### A7. Estado do player substituído a ~5 Hz e observado inteiro pelo shell
- **Evidência:** `lib/features/audio_player/presentation/providers/audio_player_session_provider.dart:105-111` — `positionStream.listen((p) => state = state.copyWith(position: p))`; `carousel_chips.dart:48`, `audio_player_screen.dart:28` fazem `watch` total.
- **Fix:** posição em provider próprio; `select` nos consumidores; throttle do `setPositionState` a 1 Hz.
- **Esforço:** S · **Conf.:** alta

### A8. Boot serializado: Isar (WASM + OPFS) gate-a o app antes do manifest começar a baixar
- **Evidência:** `lib/bootstrap_app.dart:17-31`; `louvores_manifest_provider.dart:26-27` espera `isarAvailableProvider`.
- **Fix:** iniciar fetch do `/checksum`/manifest em `main()` guardando o `Future`; montar `ColdiguiApp` já no `loading` do Isar (o `StorageRequiredGate` já cobre as áreas que exigem storage).
- **Esforço:** M · **Conf.:** média-alta

### A9. PWA sem cache de shell: entrypoints `no-cache` e SW do Flutter 3.35 se desregistra
- **Evidência:** `web/_headers:8-27`; `build/web/flutter_service_worker.js` (stub que faz `unregister`). A Fase C da doc está marcada como "immutable", mas foi revertida (`e99558b`).
- **Efeito:** ≥8 revalidações condicionais por abertura; sem rede, o PWA instalado não abre mesmo com catálogo e PDFs locais.
- **Fix:** hash de conteúdo no nome do arquivo + `immutable`; SW próprio (precache dos entrypoints + `stale-while-revalidate` do `index.html`); no mínimo `stale-if-error`.
- **Esforço:** M–L · **Conf.:** média (decisão anterior foi deliberada; validar na CDN)

### A10. Busca/biblioteca rodam na UI thread sem índice
- **Evidência:** `home_search_provider.dart:71` (`compute` = no-op na web); `search_louvor_by_number_or_text.dart:17-19,60-65` normaliza o `numero` de 4600 louvores por query.
- **Fix:** `numeroNorm` pré-computado; índice em memória 1× por manifest; chunks com yield ou Web Worker se a medição justificar.
- **Esforço:** M · **Conf.:** média (falta medição)

### A11. `pdfium.wasm` (5,2 MB) prefetchado logo após o 1º frame, competindo com o manifest
- **Evidência:** `lib/features/pdf_reader/data/pdfrx_bootstrap.dart:24-28`; `connectivity_results.dart:16-24` trata web como não-medida.
- **Fix:** agendar só depois do manifest em `data` + N s ocioso; respeitar `saveData`/`effectiveType`; ou disparar no primeiro hover num card.
- **Esforço:** S · **Conf.:** média

### A12. Busca Coldigom sem cancelamento/memoização; warmup N+1 serial no boot
- **Evidência:** `home_search_provider.dart:187-190`; `coldigom_praise_cache_warmup.dart:21-49` (`for … await fetchDetail`), chamado em `playlist_session_hydrate.dart:70-73`.
- **Fix:** `CancelToken` por geração; LRU `(query,page)`; `Future.wait` com concorrência 3–4 e timeout.
- **Esforço:** S–M · **Conf.:** média-alta

### A13. Leitor sem teto de raster/memória na web × LRU de 3 sessões
- **Evidência:** `pdf_reader_pdf_view.dart:364-385` (`PdfViewerParams` sem `getPageRenderingScale`/`maxImageBytesCachedOnMemory`); `pdf_session_cache.dart:7`.
- **Fix:** escala ≤ `2×dpr`, ~32 MB em `kIsWeb`, `maxSize` 2 na web.
- **Esforço:** S · **Conf.:** média

### A14. Cifra re-layouta a música inteira a cada transposição/tamanho de fonte
- **Evidência:** `chordpro_view.dart:69-86,110-130,167-169` — `Column` de `Wrap`, `transposeChordLabel` por célula por build.
- **Fix:** `SliverList` por linha + memoização por `(chord, semitones, preferFlats)`.
- **Esforço:** S–M · **Conf.:** média

### A15. Bottom nav: `TextPainter.layout()` no `build` durante animação (regressão do V2-A5)
- **Evidência:** `plpcg_bottom_nav_bar.dart:323-329,342` (revertido em `e24aa3f`).
- **Esforço:** S · **Conf.:** alta

### A16. Bundle publica `assets/fixtures/sample.pdf` (1,95 MB) e `NOTICES` (1,45 MB)
- **Evidência:** `pubspec.yaml:69`; único uso em `lib/` é comentário.
- **Esforço:** S · **Conf.:** alta

---

## B. Estabilidade e tratamento de erros

### B0. 4 testes falhando: `PdfSourceResolver.apiBaseUrl` é ignorado
- **Evidência:** `lib/features/pdf_reader/data/utils/pdf_source_resolver.dart:78-81` — `_joinApiUrl` chama `AssetBaseUrlResolver.joinAssetUrl` (lê `AppConfig` global), ignorando o campo `apiBaseUrl` injetado. Regressão de `c85c567`.
- **Fix:** passar `apiBaseUrl` ao resolver de asset (ou remover o parâmetro e ajustar os testes). CI deveria estar vermelho; conferir por que `.github/workflows/web.yml` não bloqueou.
- **Esforço:** S · **Conf.:** alta

### B1. Boot offline (ou Worker 5xx) apaga a sessão
- **Evidência:** `lib/features/auth/presentation/providers/auth_state_provider.dart:43-51` — `on Object { store.clear(); return null; }`; `auth_remote_datasource.dart:27` trata 5xx como exceção.
- **Efeito:** abrir a PWA no culto sem rede desloga; ao voltar a rede, `syncAfterLogin` remarca tudo como pendente.
- **Fix:** limpar só em 401/403; em rede/5xx manter sessão "não verificada" e revalidar depois.
- **Esforço:** S · **Conf.:** alta

### B2. Falhas memoizadas em `static Future?` (pdfrx e GoogleSignIn) + `retry: null`
- **Evidência:** `pdfrx_bootstrap.dart:15-17` (`??=`), `auth_state_provider.dart:59-61`, `main.dart:17`; `deferred_route_loader.dart:33-48` re-aguarda o mesmo future no "Tentar novamente".
- **Efeito:** primeiro `/leitor` com rede ruim → erro permanente até recarregar a aba. GIS bloqueado → perfil/Social mortos.
- **Fix:** `catchError` que zera o cache; init de auth falhando = "deslogado + indisponível", não erro do provider.
- **Esforço:** S · **Conf.:** alta

### B3. `catch` amplo apaga o PDF offline e chama de "corrompido" para qualquer erro
- **Evidência:** `pdf_reader_document_provider.dart:65-75` — `on Object catch (_)` → `_removeCorruptedLocalPdf`; na web `readBytes` devolve `null` para qualquer exceção da Cache API (`pdf_storage_web.dart:106-117`).
- **Efeito:** erro transitório de storage no Safari = louvor perdido sem rede.
- **Fix:** só remover com evidência real (magic bytes via `pdf_integrity_validator.dart`, ou erro de formato do pdfium); senão "não foi possível ler" + retry.
- **Esforço:** M · **Conf.:** média

### B4. Web: `QuotaExceededError` engolido; bulk "conclui" e marca configurado
- **Evidência:** `pdf_storage_web.dart:125-132` (`cache.put` sem try); `zip_extraction_runner_web.dart:57-68` (`failedPdfIds.add` sem abortar); `offline_bulk_download_provider.dart:265-284` chama `markConfigured()` mesmo com falhas; `failedPdfIds` nem entra no estado.
- **Fix:** mapear `QuotaExceededError` → `InsufficientDiskSpaceException`; abortar workers; não marcar configurado se tudo falhou; expor `failedCount` com l10n própria.
- **Esforço:** M · **Conf.:** alta

### B5. Isar indisponível: offline grava sem índice e o reconcile apaga tudo; deep link cria playlist fantasma
- **Evidência:** `offline_pdf_local_datasource.dart:58-64,128-138` (`put*` viram no-op silencioso); `reconcile_offline_index.dart:79-84` (índice vazio → todos os arquivos "órfãos" → apagados); `playlist_local_datasource.dart:99-105` (`insert` no-op) → `create()` devolve id inexistente → `PlaylistNotFoundException` não capturada em `sync_deep_link_state.dart:61-70`. `optionalIsarProvider` também é `null` **enquanto** o Isar ainda abre.
- **Fix:** datasources `unavailable()` lançam `StorageUnavailableException` em escrita; reconcile/bulk abortam sem Isar; deep link captura e avisa.
- **Esforço:** M · **Conf.:** alta

### B6. Race no `pdfReaderSessionProvider`: dispose durante `await` vaza documento e sobrescreve o handle ativo
- **Evidência:** `pdf_reader_document_provider.dart:57,78-83` — `bindHandle` e `ref.onDispose` após o `await` sem checar `ref.mounted` (Riverpod 3 lança `UnmountedRefException`).
- **Efeito:** "próximo" duas vezes rápido → setas/teclado atuam num documento invisível; handle nunca liberado (heap WASM cresce; reload da aba no iOS).
- **Fix:** `if (!ref.mounted) { handle.dispose(); return; }` após o `await`.
- **Esforço:** S · **Conf.:** alta

### B7. Deep link/import: `Uri.queryParameters` lança em `%` malformado; `_handleUri` sem catch
- **Evidência (reproduzido em Dart):** `Uri.parse('/?sharename=%E0%A4%A&sharepdfs=a').queryParameters` → `FormatException`. Chamadores sem try: `playlist_share_url_builder.dart:84-86,119-146`, `deep_link_initial_uri.dart:9-10`, `app_router.dart:59-95`; `deep_link_listener.dart:81-101` só tem `finally`.
- **Efeito:** link truncado do WhatsApp → dialog de import não responde; no boot web, o stream de links nunca é assinado.
- **Fix:** `safeQueryParameters(uri)`; `on Object` com snackbar em `_handleUri`; dedupe por tempo em vez de fingerprint.
- **Esforço:** S · **Conf.:** alta

### B8. Sync de playlists: um registro remoto malformado derruba o sync inteiro, em silêncio, para sempre
- **Evidência:** `remote_playlist.dart:39-49` (casts rígidos); `sync_playlists.dart:57` faz pull antes do push; `playlist_sync_provider.dart:99-101` — `on Object { isSyncing: false }` sem `lastError`. Mesmo padrão em `remote_audio_flag.dart:23-28`.
- **Fix:** parse tolerante por item; `lastError` no estado com banner; não bloquear push se o pull falhar por parsing.
- **Esforço:** S · **Conf.:** alta

### B9. `syncAfterLogin` remarca todas as listas como `pendingPush` a cada boot; exclusões remotas nunca propagam
- **Evidência:** `playlist_sync_provider.dart:58-67,104-110` (`fireImmediately`, `_lastSyncedSub` começa `null`); `sync_playlists.dart:56-104` só faz upsert. `PlaylistSyncStatus.conflict` nunca é usado (grep vazio).
- **Efeito [inferência]:** lista apagada no celular ressuscita pelo tablet; N PUTs por boot.
- **Fix:** persistir `lastSyncedSub`; tratar ausência remota como exclusão (ou tombstones do servidor); estratégia para 409.
- **Esforço:** M · **Conf.:** média (semântica do `GET /api/playlists` não verificada)

### B10. `id_token` Google (1h) sem refresh e sem tratamento de 401 em lugar nenhum
- **Evidência:** `auth_user.dart:23`; Bearer cru em `playlist_remote_datasource.dart:12-13`, `audio_flag_remote_datasource.dart:12-13`, `social_remote_datasource.dart:13-14`; zero interceptors no projeto.
- **Efeito:** PWA aberta o culto inteiro → sync e Social falham em silêncio.
- **Fix:** interceptor 401 → `attemptLightweightAuthentication()` e refazer; senão estado "expirado" com banner.
- **Esforço:** M · **Conf.:** alta

### B11. Áudio: `_applyQueue` sem generation guard; nenhum listener de `errorStream`
- **Evidência:** `audio_player_session_provider.dart:194-259` (dois `await` longos sem checar se outra chamada começou); `grep errorStream lib` vazio; `playPause/seek/skip` (`:263-296`) sem try e chamados sem `await`.
- **Efeito:** tocar duas faixas rápido → fila/índice errados (o bug do iPad volta); 404 no proxy → exceção não tratada, sem retry.
- **Fix:** `_generation++` e checagem após cada `await`; assinar `errorStream`; botão retry.
- **Esforço:** S · **Conf.:** alta

### B12. Cifra: falha de rede vira `null` cacheado (`keepAlive`) e a cifra some do sheet; sem cache persistente
- **Evidência:** `chord_content_datasource.dart:40-42` (`on Object { return null; }`); `chord_providers.dart:25-26` (`keepAlive` antes do fetch); `available_chords_provider.dart:28-31` reutiliza; sempre `_dio.get`, sem Isar.
- **Efeito:** rede oscila ao abrir → "indisponível" até fechar o app; domingo sem rede, cifra ensaiada na quarta não abre.
- **Fix:** `null` só para 404; `keepAlive` só no sucesso; persistir `.chord` (~600 B) no Isar por `r2Key`.
- **Esforço:** S (retry) / M (cache) · **Conf.:** alta / média

### B13. Offline bulk: cancel nativo vira `failed`; `.tmp` apagado no boot anula resume; ZIP corrompido reutilizado para sempre; sem watchdog de stall
- **Evidência:** `zip_package_downloader_native.dart:66-71` (tipo `cancel` não mapeado), `:248-261` + `offline_bulk_providers.dart:12-19` (`cleanOrphanedTempFiles` unawaited na criação), `:35-44` (cache hit só por tamanho, sem magic bytes/ETag); `offline_config.dart:39` (`receiveTimeout = Duration.zero`) sem watchdog por `onReceiveProgress`.
- **Fix:** mapear `cancel`; limpar `.tmp` só fora do checkpoint; `on FormatException` → apagar ZIP; `If-Range`; watchdog de stall (timer reiniciado a cada progresso).
- **Esforço:** S+S+S+M · **Conf.:** alta

### B14. Reconcile global concorrente ao bulk apaga PDFs recém-extraídos; sem exclusão mútua entre bulk / faltantes / limpar
- **Evidência:** `offline_reconcile_provider.dart:63-71` não consulta o bulk; gatilhos em `offline_lifecycle_listener.dart:47-48` e `offline_settings_screen.dart:35-38`; `offline_bulk_download_provider.dart:154-155,197-201` guardam por `isRunning`, não `isActive`.
- **Fix:** lock de manutenção compartilhado.
- **Esforço:** S · **Conf.:** alta

### B15. Catálogo: erro sem retry, `CatalogRefreshBanner` é código morto, nada recarrega ao voltar online; DTOs Coldigom com casts rígidos derrubam a página inteira
- **Evidência:** `home_screen.dart:203-212` e `library_screen.dart:348-357` (só `Text`); `CatalogRefreshBanner(` nunca instanciado; `praise_dto.dart:23,57-58,107-108,161,182,197,245` (`as String`/`as Map` sem try por item, ao contrário de `catalog_remote_datasource.dart:44-48`); `home_search_provider.dart:208-213` (Coldigom falha → `[]` sem sinal).
- **Fix:** botão "Tentar novamente" + `onConnectivityChanged`; parser tolerante; provider de erro Coldigom com linha "indisponível · tentar de novo".
- **Esforço:** S · **Conf.:** alta

### B16. Rede: nenhum interceptor de retry nos dois `Dio`; mensagens técnicas cruas na UI
- **Evidência:** `dio_provider.dart:11-17`, `coldigom_dio_provider.dart:8-14`; `catalog_refresh_provider.dart:45`, `google_sign_in_button_web.dart:31`, `profile_screen.dart` (`'Erro de autenticação: $e'`).
- **Fix:** `RetryInterceptor` (GET idempotente, backoff); `userMessageFor(Object)` central com l10n.
- **Esforço:** M · **Conf.:** alta

### B17. Isar sem timeout na abertura → spinner infinito **[inferência]**
- **Evidência:** `isar_provider.dart:9-13`; `bootstrap_app.dart:19-31`. Modo degradado só entra em erro, não em hang (ex.: segunda aba disputando OPFS).
- **Fix:** `.timeout(15s)`; detectar outra aba via `navigator.locks`/`BroadcastChannel`.
- **Esforço:** S · **Conf.:** média

### B18. Troca de conta em tablet compartilhado mistura dados entre usuários
- **Evidência:** `signOut` só limpa sessão (`auth_state_provider.dart:113-115`); nenhum registro Isar tem `ownerSub`; `markAllSavedPendingPush()` sobe tudo para a conta seguinte.
- **Esforço:** M · **Conf.:** média

---

## C. UX e produtividade (web/desktop/tablet)

### C1. Teclado: zero atalhos fora das setas do leitor; busca sem autofocus, Enter ou navegação
- **Evidência:** grep de `Shortcuts(`/`CallbackShortcuts`/`HardwareKeyboard` em `lib/` → apenas `pdf_page_keyboard_policy.dart:12-22` (setas); `search_bar.dart:54,98-117` sem `autofocus`/`onSubmitted`; foco do leitor se perde ao clicar na toolbar (`pdf_reader_page_key_handler.dart:70-73`).
- **Proposta:** `/` ou `Ctrl+K` foca a busca de qualquer tela; Enter abre o primeiro resultado; ↑/↓ entre cards; no leitor: PageDown/Espaço/→ próxima, PageUp/←, Home/End, `Ctrl+←/→` ou `N/P` louvor anterior/próximo, `F` fullscreen, Espaço play/pause, `+/-` transpõe. Pedaleiras Bluetooth mandam PageUp/Down.
- **Esforço:** M · **Conf.:** alta

### C2. Sem wakelock no leitor, cifra e player
- **Evidência:** `grep wakelock lib` → só `offline_bulk_download_provider.dart`. `wakelock_plus` já está no pubspec e suporta web.
- **Proposta:** `WakelockPlus.enable()` enquanto rota ∈ {`/leitor`,`/cifra`,`/audio`} ou `session.playing`.
- **Esforço:** S · **Conf.:** alta

### C3. Busca indexa só título + número; a "letra/texto" prometida no PRODUCT.md não existe
- **Evidência:** `lib/features/catalog/domain/entities/louvor.dart:78-96` (`searchContentTokens` = `nome` + `numero`); hint "Buscar por número ou título" (`app_pt.arb:4`).
- **Proposta:** campo `letra`/primeiros versos tokenizado no manifest (depende de backend); até lá, copy honesta no hint e no estado vazio; indexar primeira linha do chordpro para Coldigom.
- **Esforço:** L (dado) / S (copy) · **Conf.:** alta

### C4. Home sem estado vazio nem "sem resultados"
- **Evidência:** `home_search_results_sliver.dart:27-29` — `results.isEmpty → SizedBox.shrink()`; nenhuma chave l10n de "nenhum resultado" para a Home.
- **Proposta:** mensagem + sugestões; Home sem query com "últimos abertos" e "lista ativa"; aviso "Coldigom indisponível offline".
- **Esforço:** S / M · **Conf.:** alta

### C5. Card não mostra quais materiais existem; termos casados sem destaque; "+" só aparece com PDF único
- **Evidência:** `louvor_group_card.dart:279-288` (resumo textual), `:301-308` (`onAdd` nulo se multi-material). Sem `TextSpan` de highlight.
- **Efeito:** montar 8 louvores na lista do culto ≈ 30 toques.
- **Proposta:** linha de ícones (PDF · cifra · gestos · áudio · YouTube) clicáveis; "+" sempre visível adicionando o material preferido com snackbar "Trocar material".
- **Esforço:** M · **Conf.:** alta

### C6. Shell de 5 abas em desktop, com aba placeholder em posição nobre; Listas/Offline a 2 cliques
- **Evidência:** `shell_scaffold.dart:96-102`; `app_router.dart:47-51` → `PlaceholderTabScreen('Eventos')` → "Em breve"; único breakpoint muda padding (`home_screen.dart:165`); `plpcg_bottom_nav_bar.dart:56` índices fixos.
- **Proposta:** `LayoutBuilder` ≥ 840 px → `NavigationRail`; esconder Eventos enquanto placeholder (via feature flag, ver E7); Listas no 1º nível.
- **Esforço:** M · **Conf.:** alta

### C7. Sem split view em telas largas (PDF/cifra + lista da reunião + player)
- **Evidência:** `pdf_reader_screen.dart:333-405` e `chord_reader_screen.dart:63-137` são `Column` sem breakpoint; lista só em `AlertDialog` (`carousel_selection_sheet.dart:104`) que cobre a partitura.
- **Proposta:** ≥ 900 px: painel lateral com a lista (item atual destacado, drag para reordenar), player compacto, "seguir áudio".
- **Esforço:** M–L · **Conf.:** alta

### C8. Leitor PDF: toggle fit-mode existe e nenhum botão o chama; fullscreen web é no-op; sem 2 páginas lado a lado; sem lembrar última página
- **Evidência:** `pdf_reader_view_settings_provider.dart:31` (`toggleFitMode`, 0 chamadas); `reader_fullscreen_provider.dart:41-47` (só `SystemChrome`, sem Fullscreen API); `pdf_reader_pdf_view.dart:364-368` (sem spread); `reader_preferences_datasource.dart:26` (só `fitMode`).
- **Proposta:** botão fit + tecla; `requestFullscreen()` via `package:web`; spread quando `width/height > 1.3`; `{pdfId: page}` LRU 50.
- **Esforço:** S+S+M+S · **Conf.:** alta

### C9. Leitor de cifras: sem autoscroll, capo, colunas em tela larga
- **Evidência:** `chord_reader_screen.dart:90-130` (`SingleChildScrollView` + `Column`); grep `autoscroll|capo` vazio; `chordpro_view.dart:86` coluna única.
- **Esforço:** M · **Conf.:** alta

### C10. Transposição vaza para o próximo louvor da lista (contradiz o docstring)
- **Evidência:** `chord_reader_mode_provider.dart:59-87` — `NotifierProvider` global, doc diz "cada abertura começa no tom original", mas ninguém chama `reset()` ao trocar de `pdfId` (só o botão, `chord_reader_screen.dart:220`); troca de louvor é `context.replace` (`carousel_chips.dart:315`).
- **Proposta:** curto prazo `family` por `chordId`/reset em `didUpdateWidget`; médio prazo "tom escolhido" como atributo da entrada da lista (vai no share e no folheto).
- **Esforço:** S / M · **Conf.:** alta

### C11. Listas: nome da lista ativa invisível na barra; reordenar só no diálogo; exclusão sem "desfazer"; sem duplicar
- **Evidência:** `carousel_chips.dart`/`carousel_navigator_bar.dart` não exibem `nome`; `carousel_selection_sheet.dart:108-116`; `playlist_list_tile.dart:500-507` (confirm → delete, sem undo); menu `:194-217` sem "Duplicar".
- **Proposta:** nome editável inline à esquerda dos chips; drag & drop na própria barra com mouse; snackbar "Removida · Desfazer" (soft-delete); "Duplicar".
- **Esforço:** M + S · **Conf.:** alta

### C12. Player sem velocidade, ±10 s, loop A–B, Espaço; marcador só com áudio pausado; posição não persiste
- **Evidência:** `audio_transport_controls.dart` (só prev/play/next); sem `setSpeed`/loop no provider; `audio_player_screen.dart:43` — `canAddFlag = track != null && !session.playing`.
- **Esforço:** M · **Conf.:** alta

### C13. Filtros nunca persistem entre sessões; Biblioteca com 10 itens por página em desktop
- **Evidência:** `catalog_filters_provider.dart` sem `SharedPreferences`; `library_view_settings_provider.dart:25`.
- **Esforço:** S · **Conf.:** alta

### C14. Título da aba do navegador fixo em "PLPCG"
- **Evidência:** `lib/app.dart:44`; nenhum `Title(`/`onGenerateTitle`.
- **Proposta:** `Title('$numero — $nome · PLPCG')` nos leitores e player.
- **Esforço:** S · **Conf.:** alta

### C15. Strings hardcoded em PT fora do l10n; alvos de toque pequenos; sem `semanticLabel`
- **Evidência:** `shell_scaffold.dart:48-57` (nomes das abas), `pdf_reader_screen.dart:200,211,266,370,391,413`, `plpcg_primary_app_bar.dart:35,47`, `confirm_dialog.dart:17,21`, `profile_screen.dart:62-74,157`, `deferred_route_loader.dart:71`; 27 fallbacks `?? '…'`. 8 `Semantics(`, 0 `semanticLabel`; botão limpar 24×24 (`search_bar.dart:138-141`); 10 usos de `MaterialTapTargetSize.shrinkWrap`.
- **Efeito:** usuário em inglês vê a barra de navegação inteira em português.
- **Esforço:** S–M · **Conf.:** alta

### C16. Folheto só via Share; gesto escondido (long-press no indicador de página); sem "ir para página"
- **Evidência:** `playlist_share_sheet.dart:54`; `pdf_reader_page_indicator.dart:40-48`.
- **Esforço:** S · **Conf.:** alta

---

## D. Fluxo playlist + áudio + PDF ("ouvir enquanto lê", culto e estudo)

**Como funciona hoje (verificado):** abrir/+ chama `addLouvorToActivePlaylist(pdfId)` e navega; a lista ativa é `activePlaylistIdProvider` (prefs) e o carousel é uma **segunda cópia** em Isar (`CarouselEntry{pdfId}`), sincronizada à mão nos dois sentidos. `SavedPlaylist` tem `pdfIds[]` **e** `audioIds[]` independentes; uma pref global `playlistMediaFaceProvider` (PDF|Áudio) decide qual "face" a barra mostra. A sessão de áudio é global e continua tocando ao navegar. "Próximo" no leitor percorre só `getOrderedPdfIds()`; "próximo" no player percorre a fila do `just_audio`. Nada liga a faixa tocando ao PDF exibido.

### D1. Não existe ponte áudio ↔ partitura do mesmo louvor
- **Evidência:** `audio_player_session_provider.dart:121-131` (listener de `currentIndexStream` só atualiza media session); `audio_player_screen.dart` sem ação "ver partitura"; `carousel_audio_face_bar.dart:156-159` + `find_louvor_group_by_pdf_id.dart:81-95` — na face áudio o botão "layers" mostra os materiais do **PDF focado**, não do áudio tocando. A chave já existe no domínio: `AudioTrack.groupId` e `Louvor.effectiveGroupId`.
- **Proposta:** (a) no leitor, "▶ áudio deste louvor"; (b) no player/face áudio, "partitura/cifra deste louvor"; (c) toggle "seguir o áudio": ao mudar `currentTrack.groupId`, `navigateToPdfId` do material desse louvor na lista.
- **Esforço:** M · **Conf.:** alta

### D2. Modelo "duas filas" (`pdfIds` × `audioIds`) — contradiz o princípio 4 do PRODUCT.md e congela o formato de sync
- **Evidência:** `saved_playlist.dart:37-41`; `core/database/collections/playlist.dart:21-23`; `playlist_media_face.dart:2`; `remote_playlist.dart:66-67` (wire format já serializa as duas); funções gêmeas `removePdf/removeAudio`, `addLouvorToActivePlaylist/addAudioToActivePlaylist`. Cifra já entrou "disfarçada" em `pdfIds`.
- **Efeito:** reunião com 384 (cifra), 412 (áudio), 128 (YouTube): na face PDF o 412 some; na face áudio somem 384 e 128. Cada tipo novo (gestos) = coluna nova + migration + merge no D1.
- **Proposta:** `PlaylistEntry{groupId, materialId, kind}` em ordem única; `pdfIds/audioIds` viram projeções; `RemotePlaylist.schemaVersion: 2` com `items: [{id, kind}]`; Worker aceita v1 e v2; `PlaylistMediaFace` some (vira filtro). **Fazer antes de ligar o sync em produção.**
- **Esforço:** L · **Conf.:** alta

### D3. Carousel (Isar) e playlist ativa são duas persistências reconciliadas à mão; louvor repetido é impossível
- **Evidência:** `carousel_entry.dart:12-13` (`@Index(unique: true) pdfId`); `playlists_provider.dart:491-572` (`resolveActivePlaylistFromCarousel`, 80 linhas, chega a criar rascunho novo); `active_playlist_sync.dart`, `ensure_playlist_for_louvor.dart`, `load_playlist_into_carousel.dart` (cópias nos dois sentidos); `removePdf` na tela de listas não toca o carousel.
- **Proposta:** carousel = view derivada de `activePlaylist.entries`; `CarouselEntry` some; `carouselFocusedIndex` vira `currentIndex` da lista ativa (o mesmo campo que UC-16 quer sincronizar).
- **Esforço:** L (destrava D2, D5, D6) · **Conf.:** alta

### D4. Fila do player disparada pela busca é "materiais do mesmo louvor", não a reunião
- **Evidência:** `louvor_material_sheet.dart:295-299`, `coldigom_material_sheet.dart:358-362`, `louvor_group_card.dart:85-90` — `queue: group.audioTracks`; só `playlist_list_tile.dart:420-434` monta com `playlist.audioIds`; `playlist_audio_face_panel.dart:110` — `hasPrevious: true` hard-coded.
- **Efeito:** "próximo" na barra pula para "Playback"/"MIDI" do mesmo louvor, não para o 412.
- **Proposta:** fila = entradas de áudio da lista ativa; materiais alternativos ficam no swap.
- **Esforço:** M · **Conf.:** alta

### D5. No leitor, a face áudio tira as setas de louvor, a face PDF esconde o player, e fullscreen esconde os dois
- **Evidência:** `carousel_chips.dart:53-62` (face áudio substitui a barra com setas); `carousel_audio_face_bar.dart:110-155` (sem anterior/próximo louvor); `shell_scaffold.dart:78-84` (`hideChrome` remove a barra inteira).
- **Efeito:** pausar durante o louvor em tela cheia exige duas ações.
- **Proposta:** mini-player fino e persistente, independente da face, visível em fullscreen (mesmo padrão do FAB de sair, `pdf_reader_screen.dart:384-400`).
- **Esforço:** M · **Conf.:** alta

### D6. Modal "Substituir seleção?" e "Carregar no carousel" divergem de "abrir entra na lista ativa, sem modal"
- **Evidência:** `playlist_list_tile.dart:250-260,363-376`; `app_pt.arb:370-371`. Import por deep link faz o oposto: substitui sem perguntar (`sync_deep_link_state.dart:43-44`).
- **Proposta:** toque na lista salva = vira ativa, snackbar "Lista X ativa · Desfazer"; import com prévia "[Abrir agora] [Só salvar] [Adicionar à ativa]".
- **Esforço:** S–M · **Conf.:** alta

### D7. Share/import: só ids, sem material/índice/tom; importar cria lista salva duplicada a cada clique
- **Evidência:** `playlist_share_url_builder.dart:40-49`; `pdf_id_codec.dart:8-9` (base64 do path, ~60–90 chars por id); `import_shared_playlist_from_url.dart:31-41` (`create(salva: true)` sempre); dedupe só por fingerprint na sessão (`deep_link_listener.dart:76-78`).
- **Proposta:** dedupe por hash de conteúdo; formato v2 `id:kind` (+ índice atual, tom); short link pelo Worker (`/l/ABC123`), que também é o degrau para UC-16.
- **Esforço:** M · **Conf.:** alta

### D8. Folheto e "compartilhar da barra" ignoram entradas de áudio
- **Evidência:** `playlist_share_actions_provider.dart:246-251`, `playlist_list_tile.dart:455-459`, `carousel_bar_trailing_actions.dart:183-186` — só `pdfIds`; `generate_leaflet_from_selection.dart:26-28` lança "seleção vazia" numa lista só de áudios.
- **Proposta:** folheto consome a fila única (D2); enquanto não existir, `pdfIds ∪ audioIds` resolvidos para (numero, nome) e deduplicados por `groupId`.
- **Esforço:** S após D2 · **Conf.:** alta

### D9. Cache do leitor descartado ao sair do `/leitor`; LRU de 3 não cobre ida e volta entre 5 louvores
- **Evidência:** `pdf_session_cache.dart:7,55-59`; `reader_adjacent_pdf_prefetch_provider.dart:37` (`autoDispose`); prefetch sem `CancelToken` nem dedupe com o download do usuário (`prefetch_adjacent_carousel_pdfs.dart:39-48`).
- **Proposta:** manter cache enquanto a lista ativa existir, tamanho `min(lista, 6)`; pré-aquecer o material do louvor tocando no áudio; dedupe `pdfId → Future` em `ResolvePdfForReader`.
- **Esforço:** M · **Conf.:** média

### D10. Botão "Abrir no leitor" morto no modo leitor
- **Evidência:** `carousel_chips.dart:431,453` — `onOpenPlayer: () {}`; `carousel_navigator_bar.dart:86-92` renderiza o botão.
- **Proposta:** `null` no modo leitor, ou reaproveitar o slot como "▶ áudio deste louvor" (D1).
- **Esforço:** S · **Conf.:** alta

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

### E2. "Abrir material" duplicado em 3 lugares + 3 openers distintos
- **Evidência:** `playlist_list_tile.dart:282-292` e `reader_carousel_actions_provider.dart:44-51` (bloco idêntico de cifra); `open_louvor_in_reader.dart`, `open_chord_in_reader.dart`, `open_youtube_material.dart`; escada de 4 `on XException` copiada em `open_carousel_pdf_in_reader.dart:38-55` e `playlist_list_tile.dart:337-352`; 95 linhas de orquestração dentro de um `State` (`playlist_list_tile.dart:262-356`).
- **Refactor:** `openMaterialProvider` único (`locationFor(CatalogMaterial)` com switch exaustivo) + `MaterialOpenErrorPresenter`.
- **Esforço:** M · **Conf.:** alta

### E3. Coldigom vaza na presentation: 4 caches por tipo, heurística `isColdigom`, dois sheets, Home com 4 `StateProvider` mutados imperativamente
- **Evidência:** `coldigom_providers.dart:13,35,58,82`; `louvor_group.dart:71-83` (`if (chordMaterials.isNotEmpty) return true;` — "tem cifra ⇒ é Coldigom"); `louvor_group_card.dart:123-137` e `carousel_swap_material_button.dart:74-90` (`if (group.isColdigom) showColdigomMaterialSheet else showLouvorMaterialSheet`); `coldigom_material_sheet.dart` (722 l.) duplica `_MaterialAddTrailing`, `_handleAddPdf/_handleAddAudio` de `louvor_material_sheet.dart` e define um segundo enum de kind privado (`:56`); 40 arquivos fora de `features/coldigom` referenciam "coldigom"; `home_search_provider.dart:33-49,146-215`.
- **Refactor:** porta `CatalogSource {search, browse, getGroup, getMaterial}` com duas implementações; `LouvorGroup.source` explícito; `MaterialCacheRepository` único keyed por `materialId`; um `MaterialSheet(group)` com bloco de metadados opcional; `HomeSearchState` imutável num `AsyncNotifier`.
- **Esforço:** L (dividível em M + M) · **Conf.:** alta

### E4. God files
| Arquivo | Linhas | Split |
|---|---|---|
| `playlists_provider.dart` | 742 | CRUD/abas · ponte carousel · share (já existe `playlist_share_actions_provider.dart`) · lookup → use case |
| `playlist_list_tile.dart` | 861 | tile puro · `PlaylistActionsController` · abertura → E2 |
| `coldigom_material_sheet.dart` | 722 | → E3 |
| `offline_settings_screen.dart` | 677 | controller + 5 widgets |
| `carousel_louvor_chip.dart` | 589 | chip + `chip_parts/` |
- **Esforço:** M por arquivo · **Risco:** baixo (widget tests existentes) · **Conf.:** alta

### E5. Código morto e docs desalinhadas
- **Evidência (computado):** nunca importados: `core/constants/feature_flags.dart`, `core/constants/deep_link_config.dart`, `pdf_opening/domain/usecases/open_pdf_external.dart`, `catalog/presentation/widgets/catalog_refresh_banner.dart`, `admin/**` (`@Deprecated`), `offline/presentation/providers/offline_missing_download_provider.dart`; 19 chaves ARB sem uso; `FEATURE_INDEX.md` aponta 4 arquivos inexistentes (inclui `library_results_provider.dart` como "legado implementado"); `lib/deferred/` vazio; 3 imports `flutter_riverpod/legacy`. `WEB_PERFORMANCE_AND_LOADING.md` (Fases C e F) e `OFFLINE_PERFORMANCE_BACKLOG.md` descrevem estado que o código já não tem.
- **Refactor:** apagar; `scripts/check_unused_dart.sh` + `check_doc_paths.sh` no CI; atualizar docs.
- **Esforço:** S · **Conf.:** alta

### E6. Sem feature flags: Social/Eventos/Admin gateados por "não registrar" ou constante morta
- **Evidência:** `feature_flags.dart:4` (não importado); `app_router.dart:47-49,126-128` sempre registra; `plpcg_bottom_nav_bar.dart:56` índices fixos; `dart_defines/*.json` só tem URLs.
- **Refactor:** `FeatureFlags.fromEnvironment()` (`bool.fromEnvironment('FF_SOCIAL')`) → `featureFlagsProvider`; router e nav bar montam abas a partir dele; fase 2: overrides remotos via Worker `/api/config` por canal beta (TODO #2).
- **Esforço:** S / M · **Conf.:** alta

### E7. "Deferred loading" não existe de fato
- **Evidência:** `app_router.dart:100-103` — único `DeferredRouteLoader` só chama `ensurePdfrxInitialized` (init de runtime); `grep 'deferred as'` = 0; Fase F foi revertida (WebKit não registra `.part.js`, `app_router.dart:34-35`).
- **Refactor:** padrão `<feature>_entry.dart` + `deferred as` no router; piloto com `chords` e `social`; é o padrão que TODO #11 (plugins) precisa. Medir com `--dump-info`.
- **Esforço:** M · **Risco:** médio (providers ficam na lib base) · **Conf.:** alta nos fatos, média no ganho

### E8. Sem `Failure`/`Result`: 14 `*Result` ad-hoc, 14 exceções com mensagem em PT no domínio, 55 catches silenciosos
- **Evidência:** `open_carousel_pdf_in_reader.dart:38-55`; exceções com `.message` fora do l10n; 55 `catch (_)`/`on Object {}` sem log (18 em presentation).
- **Refactor:** `sealed class AppFailure {Network, Offline, NotFound, Storage, Auth, Conflict, Unknown}`; `failureMessage(l10n, f)` central; migrar primeiro `pdf_opening`/`offline`.
- **Esforço:** M · **Conf.:** média-alta

### E9. Observabilidade zero: sem error boundary, logs por feature, `retry: null` não documentado
- **Evidência:** `main.dart` sem `FlutterError.onError`/`PlatformDispatcher.onError`/`runZonedGuarded`; 3 utilitários de debug log locais; `main.dart:17`.
- **Refactor:** `AppLogger.of('feature')`, `installErrorHandlers(reporter)` com `ErrorReporter` port (no-op agora, Sentry web depois).
- **Esforço:** S · **Conf.:** alta

### E10. Infra de teste: sem fakes compartilhados, sem `pumpApp`, sem goldens, smoke web trivial
- **Evidência:** 48 fakes duplicados; `test/helpers/` só com 2 arquivos; cada widget test monta `MaterialApp` à mão; `test/web/chrome_smoke_test.dart` só checa `kIsWeb`; `flutter test -j 1` por causa do binário Isar.
- **Refactor:** `test/support/` com `pumpApp`, `InMemory*Repository`, `FakeColdigomSource`, `TestProviderOverrides.standard()`; goldens para card, chip e tile.
- **Esforço:** M · **Conf.:** alta

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

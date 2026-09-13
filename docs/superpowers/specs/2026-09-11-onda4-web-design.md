# Onda 4 — web: UX de culto, folheto e link curto, performance restante, arquitetura

**Criado em:** 2026-09-11 · **Branch:** `web/integration` @ `d979b1b` (onda 3 integrada; Worker publicado ainda em v1 da rota social)
**Origem:** seção J.4 de `docs/WEB_REFACTOR_OPPORTUNITIES_2026-09.md` (próxima onda recomendada), aprovada pelo dono do produto ("Continue").
**Autoridade:** `PRODUCT.md` (princípios 1–4 e 6; «Interação (foco vigente)»; «Descartado (2026-08-18)»), `docs/USER_AUTH_PLAYLIST_SYNC_SPEC.md`.
**Levantamento:** `.superpowers/sdd/2026-09-11-onda4-web/w4-explore-{reader,home,share,perf-arch}.md` (`arquivo:linha` de `d979b1b`).

Cinco subprojetos com contratos próprios. As decisões foram tomadas pelo executor e estão marcadas **[decisão]**; as marcadas **[decisão — revisar]** mudam semântica visível ao usuário, formato que sai do dispositivo ou custo de infra e merecem o olhar do dono do produto.

**Recorte corrigido pelo levantamento:** D10 já estava resolvido (`3a0b8bf`); do D7 só falta o dedupe do import e o link curto (o formato v2 `shareitems` já existe); do E12 só falta separar publicação (fica fora — pede decisão de produto e migration de dados); Espaço já dá play/pause (C12 fica com ±10 s, velocidade, marcador tocando e posição); a Biblioteca não tem busca textual, então «A10 fatia 2» vira só remoção de código morto; `sample.pdf`/`NOTICES` (A16) só pesam no artefato de deploy, não no boot — fora; A9 fica fora (ver Riscos).

---

## Subprojeto A — UX de culto no leitor

### A.0 Problema
Pausar durante o louvor em tela cheia exige duas ações (D5); em tela larga a lista cobre a partitura (C7); o ajuste de página existe e nada o chama, o fullscreen web é no-op e a última página não é lembrada (C8); a cifra não rola sozinha nem usa a largura (C9); a transposição vaza para o próximo louvor (C10) e a cifra inteira é re-layoutada a cada mudança (A14); a aba do navegador é sempre «PLPCG» (C14); não há «ir para página» (C16).

### A.1 D5 — mini-player persistente
- Novo widget `MiniPlayerBar` (`lib/features/audio_player/presentation/widgets/mini_player_bar.dart`), 44 px: título «numero — nome» da faixa atual (`select` de `currentTrack`), botões faixa anterior / play-pause / próxima (`AudioPlayerSessionNotifier.skipToPrevious/playPause/skipToNext`), erro da sessão como ícone com tooltip (`errorMessage`), e uma linha de progresso fina de 2 px lida de `audioPlayerPositionProvider`. Nenhum campo novo no estado do player.
- Onde aparece **[decisão]:** no `ShellScaffold`, entre a barra de chips e o corpo, sempre que `currentTrack != null` **e** a face de áudio não está visível (a face de áudio já tem esses controles; duplicar seria ruído). Em fullscreen (`hideChrome`), aparece como overlay `Positioned(bottom: 0)` sobre o `navigationShell`, com `Opacity` 0.35 que sobe a 1 em hover/toque (mesmo padrão do FAB de sair do leitor, `pdf_reader_screen.dart:412-433`), para o leitor de PDF e o de cifra.
- Face de áudio ganha setas de louvor anterior/próximo (`CarouselAudioFaceBar`), que movem o foco ao longo de `audioFaceItemsProvider` (por chave de ocorrência, `carouselFocusedIndexProvider.focusKey`) e tocam a faixa da entrada focada via `queueForTrack(..., activeQueue: activeListAudioQueue(ref))`. Setas desabilitadas nas pontas.
- Testes: widget do `MiniPlayerBar` (sem faixa → nada; com faixa → título e play/pause chamam o notifier); `shell_scaffold` (visível com faixa na face PDF; oculto com face de áudio; overlay presente em fullscreen); face de áudio (setas focam e tocam; pontas desabilitadas).

### A.2 C14 — título da aba do navegador
- `ShellScaffold` envolve o corpo num `Title(color: …, title: browserTitle)` onde `browserTitle(l10n, readerRouteParams, currentTrack, tabLabel)` é função pura: no leitor/cifra com `numero`/`titulo` nos params → «123 — Nome · PLPCG» (`l10n.browserTitleLouvor(numero, nome)`; sem número → «Nome · PLPCG»); no `/audio` → faixa atual; fora deles → «Aba · PLPCG» (`l10n.browserTitleTab(label)`). `Title` é o mecanismo do Flutter web para `<title>`; no nativo é inofensivo.
- Teste unitário da função pura com os quatro casos.

### A.3 C8 — ajuste, fullscreen web, última página, ir para página
- Botão «Ajustar à largura / à página» na toolbar do leitor (`Icons.fit_screen`/`Icons.fit_screen_outlined`), chamando o já existente `toggleFitMode()`; tecla `Z` no `PdfKeyAction` (`pdf_page_keyboard_policy.dart`), respeitando a guarda de campo de texto.
- Fullscreen web: nova porta `ReaderFullscreenPlatform { Future<void> enter(); Future<void> exit(); Stream<bool> get changes; }` com conditional import `reader_fullscreen_platform_{native,web}.dart` (web: `web.document.documentElement!.requestFullscreen()`/`web.document.exitFullscreen()` e evento `fullscreenchange`; nativo: `SystemChrome`, sem stream). `ReaderFullscreenNotifier` chama a porta e escuta `changes` para desligar o estado quando o navegador sai sozinho (Esc do browser). Provider `readerFullscreenPlatformProvider` sobreescrevível nos testes. Falha do `requestFullscreen` (gesto ausente) só registra em `AppLogger.of('pdf_reader')` e mantém o modo imersivo do app.
- Última página **[decisão — revisar]:** `ReaderPreferencesDatasource.lastPageFor(pdfId)` / `saveLastPage(pdfId, page)` — LRU de 50 em JSON numa única chave `StorageKeys.pdfLastPages`. Salva no `onPageChanged` (debounce 500 ms); restaura ao abrir quando a rota **não** traz `page`, o documento tem > 1 página e a página lembrada é > 1. Em culto, quem volta a um louvor cai na página em que parou; o indicador mostra «3/5» e o long-press já volta à primeira.
- «Ir para página» (C16): toque no indicador de página abre um diálogo numérico (`l10n.readerGoToPageTitle`, validação 1..N) e chama `handle.animateToPage(pageNumber:)`; o long-press continua indo à primeira. Tecla `G` abre o mesmo diálogo.
- Testes: unit de `lastPageFor/saveLastPage` (LRU, ordem, JSON corrompido → vazio); notifier de fullscreen com porta fake (enter/exit chamados; `changes=false` desliga o estado); widget da toolbar (botão chama `toggleFitMode`); indicador (tap abre diálogo, número inválido desabilita OK, válido chama `animateToPage`); policy de teclado (`Z`, `G`).

### A.4 C8 — duas páginas lado a lado (spread) e A13 — teto de raster
- `spreadPageLayout(List<PdfPage> pages, PdfViewerParams params, {required double viewportAspect})` (função pura em `lib/features/pdf_reader/presentation/utils/pdf_spread_layout.dart`) devolve `PdfPageLayout` com pares lado a lado (página 1 sozinha à esquerda quando o total é ímpar? **[decisão]** não: 1–2, 3–4, … como partitura encadernada não se aplica a folhas soltas) quando `viewportAspect > 1.3` e `pages.length > 1`; senão delega ao layout padrão do pdfrx. Ligado em `PdfViewerParams.layoutPages`; `PdfReaderViewSettings.spreadEnabled` (default `true`, persistido junto de `fitMode`) com item no menu do leitor «Duas páginas em tela larga».
- A13: `PdfViewerParams.getPageRenderingScale` limitado a `min(escalaPedida, 2 × devicePixelRatio)` e `maxImageBytesCachedOnMemory = 32 MiB` quando `platformCapabilities.isWeb` (E.5); `kPdfSessionCacheMaxSize` vira parâmetro do `PdfSessionCache` — 2 na web, 3 no nativo, decidido no provider a partir de `PlatformCapabilities`.
- Testes: unit do layout (aspecto estreito → 1 coluna; largo com 5 páginas → 3 linhas; larguras somadas); teste do provider de cache (web → 2).

### A.5 C9 + C10 + A14 — leitor de cifras
- **C10 [decisão]:** `chordReaderTransposeProvider` vira `NotifierProvider.family<ChordReaderTransposeNotifier, int, String>` por `chordId`; a tela lê a família com o id da rota. Cada louvor tem seu tom na sessão; abrir outro louvor não herda; voltar ao mesmo louvor na mesma sessão mantém o tom escolhido (melhor que o docstring prometia). Sem persistência.
- **A14:** o corpo da tela vira `CustomScrollView` com `SliverList.builder` por linha da música (título/metadados num `SliverToBoxAdapter`); `transposeChordLabel` memoizado num `TransposeLabelMemo` (`Map<(String, int, bool), String>`, teto 512 entradas, limpa ao estourar) mantido no estado da tela e passado ao `ChordProView`.
- **C9 autoscroll:** `chordAutoscrollProvider` (`NotifierProvider.autoDispose<ChordAutoscrollNotifier, ChordAutoscrollState{running, speed 1..5}>`), motor por `Ticker` no estado da tela: a cada frame `controller.jumpTo(offset + speed × 12 px/s × dt)`, parando no fim (`maxScrollExtent`) e ao toque/rolagem manual do usuário. Controles na toolbar: play/pause do autoscroll e velocidade (`l10n.chordAutoscrollSpeed(n)`); teclas `S` (liga/desliga) e `[`/`]` (velocidade). Desliga no dispose e ao trocar de louvor.
- **C9 colunas:** com largura ≥ `kWideLayoutBreakpoint` (900) e ≥ 24 linhas, `ChordProView` divide `song.lines` em duas colunas no limite de seção mais próximo do meio (função pura `splitLinesForColumns(lines) → (left, right)`); abaixo disso, uma coluna. Capo fica fora **[decisão]** (não há demanda registrada; transposição cobre o uso).
- Testes: família (dois ids independentes); memo (mesma chave não recalcula — contar chamadas via função injetada); `splitLinesForColumns` (corte em seção; lista curta não divide); autoscroll (avança com o tempo, para no fim, para ao trocar de louvor); teclas.

### A.6 C7 — split view em tela larga
- `kWideLayoutBreakpoint = 900` e `kRailBreakpoint = 840` em `lib/core/layout/breakpoints.dart` (constantes puras; `isWideLayout(BuildContext)`).
- `ActiveListPanel` (`lib/features/carousel/presentation/widgets/active_list_panel.dart`): o corpo do diálogo de seleção (`ReorderableListView.builder` de `_CarouselSelectionDialog`) extraído para um widget reutilizável; o diálogo passa a usá-lo. O painel mostra a face corrente (PDF no leitor de PDF; PDF também na cifra — a cifra é material de partitura), item focado destacado, drag para reordenar (`reorderFace`), toque foca e navega (mesma ação das chips), `×` remove por chave.
- `ReaderSplitLayout(child, panel)` (`lib/core/presentation/widgets/reader_split_layout.dart`): `Row` com painel de 320 px à direita quando `isWideLayout` **e** `readerSidePanelOpenProvider` (Notifier persistido em SharedPreferences, default `true`); abaixo do breakpoint, só o `child`. Botão `Icons.view_sidebar` nas toolbars do leitor de PDF e da cifra alterna o painel. Em fullscreen o painel some.
- O mini-player (A.1) já fica no shell; o painel não repete player.
- Testes: `ReaderSplitLayout` (largo+aberto → painel; largo+fechado → sem painel; estreito → sem painel); `ActiveListPanel` (foco destacado; reorder chama `reorderFace`); diálogo continua passando nos testes existentes.

---

## Subprojeto B — Home, listas e player

### B.0 Problema
Home vazia é um `SizedBox.shrink()` (C4); o card não mostra materiais e o «+» some com mais de um material (C5); a lista ativa não tem nome visível, apagar é definitivo e não há duplicar (C11); o player não tem ±10 s, velocidade, marcador tocando nem posição persistida (C12); filtros e tamanho de página não persistem (C13).

### B.1 C4 — estados da Home
- `HomeEmptyState` (`lib/features/catalog/presentation/widgets/home_empty_state.dart`) renderizado por `HomeSearchResultsSliver` no lugar do `SizedBox.shrink()`:
  - **Sem consulta:** cartão da lista ativa («Lista ativa: Nome · N louvores» + botão «Abrir no leitor», só quando há entradas; lê `activePlaylistProvider`) e «Abertos recentemente» (até 8 chips a partir de `recentlyOpenedProvider`, cada uma abre o material com o opener já existente), mais o hint `l10n.homeEmptyHint` («Busque por título ou número»).
  - **Consulta sem resultado** (`query.isNotEmpty && groups.isEmpty && !remoteLoading`): `l10n.homeNoResults(query)` + dicas (`l10n.homeNoResultsTips`) + botão «Limpar filtros» quando `catalogFiltersProvider` não está no default + aviso `l10n.homeColdigomOffline` quando `remoteFailed` e `connectivity` está offline.
- `recentlyOpenedProvider` (`NotifierProvider<RecentlyOpenedNotifier, List<String>>`, `lib/features/catalog/presentation/providers/recently_opened_provider.dart`): ids de material, mais recente primeiro, teto 8, persistido em SharedPreferences (`StorageKeys.recentlyOpened`, JSON). Grava a partir de `ref.listen` no próprio `build`: `readerRouteParamsProvider` (pdfId/chordId ao entrar no leitor/cifra) e `audioPlayerSessionProvider.select((s) => s.currentTrack?.id)`. A Home observa o provider (mantém o listener vivo enquanto a aba existe). Sem `Isar`.
- Testes: sliver nos dois estados vazios (chaves l10n presentes; «Limpar filtros» só com filtro ativo; aviso Coldigom só offline+falha); notifier (ordem, dedupe, teto 8, persistência, JSON inválido → vazio).

### B.2 C5 — card com materiais, «+» sempre, destaque do termo
- `MaterialKindsRow` (`lib/features/carousel/presentation/widgets/chip_parts/material_kinds_row.dart`): ícones por tipo presente no grupo (`LouvorMaterialIcons.forKind`, ordem PDF · cifra · gestos · áudio · YouTube), com contagem quando > 1 do mesmo tipo; toque no ícone abre o `MaterialSheet` do grupo. Entra no `CarouselLouvorChip` na variante de card da Home/Biblioteca, no lugar do resumo textual `louvorGroupMetadataSummary` (a chave fica para o sheet).
- «+» sempre visível no card: adiciona o **material preferido** — `preferredMaterialForGroup(group)`: PDF principal (`primaryLouvor`) se existir, senão o único áudio, senão o primeiro extra adicionável (`canAddMaterialToPlaylist`) — e mostra snackbar «Adicionado à lista · Trocar material», cuja ação abre o `MaterialSheet` no fluxo de troca (`replaceByKey` da entrada recém-criada). Grupos sem material adicionável (só YouTube) mantêm «+» desabilitado.
- Destaque: `HighlightedText(text, query, style, highlightStyle)` (`lib/core/presentation/widgets/highlighted_text.dart`) com `TextSpan` sobre as ocorrências normalizadas (mesma normalização do índice de busca — reaproveitar a função de `plpcg_search_index.dart`/`search_louvor_by_number_or_text.dart`); usado no título do card com `homeSearchDebouncedQueryProvider`. Cor de destaque = ouro do tema (sem cor nova).
- Testes: `preferredMaterialForGroup` (PDF > áudio > extra > null); `HighlightedText` (acentos, múltiplas ocorrências, query vazia); card (ícones por tipo; «+» com multi-material adiciona e mostra snackbar; ação abre o sheet).

### B.3 C11 — nome da lista, apagar com desfazer, duplicar, folheto direto
- Nome na barra: `ActivePlaylistNameChip` à esquerda das chips (`_CarouselChipsBar`), lendo `activePlaylistProvider.select((p) => p?.nome)`; rascunho sem nome mostra `l10n.playlistDraftLabel`; toque abre o diálogo de renomear já existente (`PlaylistsNotifier.rename`). Some quando a largura da barra < 480 px (a chip do louvor tem prioridade).
- Apagar com desfazer **[decisão — revisar]:** exclusão **adiada**: `PlaylistsNotifier.deleteWithUndo(playlistId)` remove a lista do estado imediatamente, agenda o `delete` real em 5 s e devolve `PendingDelete{undo(), commit()}`; o tile mostra snackbar «Lista removida · Desfazer» (padrão de `_activate/_undoActivate`: captura `container`, não `ref`); `undo()` cancela o timer e recoloca a lista; `commit()` roda o delete de verdade (também chamado no `dispose` do notifier e antes de um novo `deleteWithUndo`). O diálogo de confirmação some (o desfazer substitui) e `playlistDeleteConfirm*` é apagado. Custo se estiver errado: fechar a aba dentro dos 5 s cancela a exclusão.
- Duplicar: `DuplicatePlaylist` (use case, `lib/features/playlists/domain/usecases/duplicate_playlist.dart`): cria lista salva com as mesmas `entries` e nome `l10n.playlistCopyName(nome)` («Nome (cópia)»), `syncStatus: pendingPush`, sem publicação; item «Duplicar» no menu do tile.
- Folheto direto (C16): item «Gerar folheto» no menu do tile, chamando `LeafletActionsNotifier.generateAndShare` sem passar pelo sheet de share.
- Reordenar arrastando na própria barra fica fora **[decisão]**: a barra mostra uma chip por vez desde a onda 2; o painel lateral (A.6) cobre o caso em tela larga.
- Testes: chip do nome (nome; rascunho; toque abre renomear); `deleteWithUndo` (some da lista; undo recoloca; commit apaga; dispose comita); `DuplicatePlaylist` (entradas iguais, id novo, nome «(cópia)»); menu do tile (Duplicar e Gerar folheto presentes e chamando os notifiers).

### B.4 C12 — player: ±10 s, velocidade, marcador tocando, posição
- `AudioPlayerSessionNotifier.seekBy(Duration)` (clamp em `[0, duration]`) e `setSpeed(double)` (`just_audio.setSpeed`; valores `0.75, 1.0, 1.25, 1.5`); `AudioPlayerSessionState.speed` (default 1.0; aplicado de novo em `_applyQueue`).
- UI: `AudioTransportControls` ganha «−10 s» / «+10 s» ao redor do play (`Icons.replay_10`/`forward_10`); menu de velocidade na tela `/audio` (`PopupMenuButton`, rótulo «1,25×»). Teclas globais `J` (−10 s) e `L` (+10 s) em `AppShortcuts`, com a mesma guarda de campo de texto/controle do Espaço.
- Marcador tocando **[decisão]:** `canAddFlag = track != null` (cai a exigência de pausar; a posição do marcador é a posição no momento do toque — precisão suficiente; `audioFlagPauseToAdd` apagado).
- Posição persistida: `audioPlayerPositionProvider` continua em memória; `AudioPlaybackPositionStore` (SharedPreferences, `StorageKeys.audioLastPosition`, JSON `{trackId, positionMs}`) gravado a cada 5 s enquanto toca (mesmo throttle do `MediaSessionPositionThrottle`) e no pause/stop; `restoreQueue` (só no boot) faz `seek` para a posição gravada quando o `trackId` coincide e a posição é < duração − 5 s. Tocar uma faixa a partir da lista/busca começa do zero.
- Loop A–B fica fora **[decisão]** (fatia 2 — sem demanda registrada além da doc).
- Testes: `seekBy` (clamp), `setSpeed` (estado + player fake), store (grava/lê, JSON inválido), `restoreQueue` restaura posição só com id igual; widget dos controles; atalhos `J`/`L`.

### B.5 C13 — persistência de filtros e tamanho de página
- `CatalogFiltersNotifier`: lê `StorageKeys.catalogFilters` (JSON `{materials: [...], arranjos: [...]}`) no `build` quando a URL não traz filtro; grava em toda mutação; `reset` apaga a chave. `hydrateFromUrl` continua vencendo.
- `LibraryViewSettingsNotifier`: persiste `itemsPerPage` (`StorageKeys.libraryItemsPerPage`); quando não há valor gravado nem `page_size` na URL, `LibraryScreen` chama `setDefaultForWidth(width)` uma vez: ≥ `kWideLayoutBreakpoint` → 25, senão 10.
- Testes: novos arquivos de teste para os dois providers (defaults, persistência, URL vence, reset limpa; default por largura só sem valor gravado).

---

## Subprojeto C — Folheto e link

### C.0 Problema
O folheto e o «compartilhar da barra» ignoram entradas de áudio (D8); importar o mesmo link cria lista duplicada e a URL longa carrega três parâmetros (D7).

### C.1 D8 — folheto com entradas de áudio
- `PlaylistShareContext` ganha `entries: List<PlaylistEntry>` (substitui `pdfIds`; `fromCarousel` fica) preenchido pelo tile (`playlist.entries`) e pela barra (`activeEntriesProvider`).
- `GenerateLeafletFromEntries` (substitui `GenerateLeafletFromPdfIds` e `GenerateLeafletFromSelection` — um só use case em `lib/features/leaflet/domain/usecases/`): resolve cada entrada a `(numero, nome)` pelo `CatalogMaterialLookup` (`louvor`/`chord`/`audioTrack`), deduplica por `groupId` preservando a primeira ocorrência, e monta o `LeafletDocument`. `EmptyLeafletException` nasce em `leaflet/domain/exceptions/` e `EmptyCarouselException` de `playlists/domain` é apagada com o `_noLabel` duplicado.
- `leafletLabelOf` ganha o ramo `audioTrack`.
- Testes: lista só de áudio gera folheto com número e nome; PDF + áudio do mesmo louvor vira uma linha; entrada sem lookup mostra id como nome (comportamento atual); vazia lança `EmptyLeafletException`.

### C.2 D7 — dedupe do import e link curto
- **Dedupe [decisão]:** `ImportSharedPlaylistFromUrl` calcula `contentFingerprint(entries)` (string `kind:id` na ordem, separada por `,` — comparação de string, sem hash; não é persistida) e procura entre as listas salvas (`getAll()` filtrando `salva && deletedAt == null`) uma com o mesmo fingerprint; se existir, não cria: devolve `ImportResult(playlist, alreadyExisted: true)`. `SyncDeepLinkResult.success` carrega `alreadyExisted` e a UI mostra «Lista já estava salva: Nome». O nome do link não entra no fingerprint.
- **Link curto [decisão — revisar]:** Worker `POST /api/links` (autenticado; corpo `{query}` = a query string do share, máx. 4 KB, validada com `parsePlaylistShareParams`-equivalente no servidor: precisa ter `shareitems`) → `{code, url}`; `GET /l/:code` (público, sem auth, `Cache-Control: public, max-age=3600`) → `302 Location: https://plpcg.com/?<query>`; 404 quando não existe. Tabela `short_links(code TEXT PRIMARY KEY, query TEXT NOT NULL, created_by TEXT NOT NULL, created_at INTEGER NOT NULL, hits INTEGER NOT NULL DEFAULT 0)` — migration `0009_create_short_links.sql`. Código: 7 caracteres de `[a-z0-9]` via `crypto.getRandomValues`, retry em colisão. Reuso: mesma `query` do mesmo usuário devolve o código existente (índice `(created_by, query)`). Guarda de abuso: no máximo 100 links por usuário por 24 h (COUNT) → 429; sem rate limit no GET (só leitura, cacheável). `wrangler.jsonc` ganha a rota `plpcg.com/l/*`. `corsModeForPath` ganha `links` (GET/POST/OPTIONS).
- Cliente: `ShortenShareUrl` (porta `ShareLinkShortener` em `playlists/domain`, impl Dio em `playlists/data` usando o `Dio` autenticado existente, timeout 3 s). `GeneratePlaylistShareUrl.call({playlistId, short})`: com `short: true` e usuário autenticado, tenta o curto e cai na URL longa em qualquer erro (logado em `AppLogger.of('playlists')`). O sheet de share usa `short: true` quando `authStateProvider` tem usuário; anônimo continua com a URL longa. A URL longa continua com os três parâmetros (compat com apps antigos).
- Testes Worker: POST cria e reusa; GET redireciona/404; 429 no teto; sem auth → 401; query sem `shareitems` → 400. Cliente: `contentFingerprint` (ordem importa; kinds importam); import dedupa; `GeneratePlaylistShareUrl` cai na longa em erro/timeout; anônimo não chama o encurtador.

---

## Subprojeto D — Performance restante e sobras

### D.1 A6 — quota pelo índice
- `OfflinePdfRepositoryImpl.totalCachedBytes()` passa a ler `OfflinePdfLocalDatasource.sumFileSizes()` (índice Isar); `PdfStoragePort.getTotalOfflineBytes()` fica só para `get_offline_stats_by_category` e para o reconcile. Com Isar indisponível, `sumFileSizes` devolve 0 → a quota não desaloja nada (direção segura; documentar no docstring).
- Teste: `FetchAndStorePdf` com store fake conta 0 chamadas a `getTotalOfflineBytes` e usa a soma do índice.

### D.2 A15 — largura do rótulo da nav memoizada
- `_NavLabelState` calcula `beamWidth` em `initState`/`didUpdateWidget` (quando `label`/estilo mudam), nunca em `build`.
- Teste: widget existente continua; unit com contador de `TextPainter` não é viável — cobrir com teste de que trocar o label recalcula (largura muda).

### D.3 A10 fatia 2 — só código morto
- Apagar `searchLouvorByNumberOrTextProvider` e, se ficar sem chamador em `lib/`, o `SearchLouvorByNumberOrText.call()` não indexado (manter `callIndexed`). O `compute()` do pipeline da Biblioteca fica (não é O(catálogo) por tecla).

---

## Subprojeto E — Arquitetura

### E.1 E6 + C6 — feature flags e shell em tela larga
- `FeatureFlags{events, social, adminUpload}` com `FeatureFlags.fromEnvironment()` (`bool.fromEnvironment('FF_EVENTS', defaultValue: false)`, `FF_SOCIAL` default `true`, `FF_ADMIN_UPLOAD` default `false`) e `featureFlagsProvider` (`Provider<FeatureFlags>`, sobreescrevível). `dart_defines/*.json` ganham as três chaves explícitas.
- `AppTab{events, library, home, social, profile}` + `appTabsFor(FeatureFlags) → List<AppTab>`; o router monta as `StatefulShellBranch` a partir dessa lista (mesma ordem), e `ShellScaffold._destinations`/`PlpcgBottomNavBar` usam a mesma lista — índices sempre derivados, nunca fixos. **[decisão — revisar]** `FF_EVENTS=false` esconde a aba placeholder «Eventos» («Em breve») até a feature existir; isso não é o «Modo Culto» descartado (busca, Social e sheet continuam).
- C6: em largura ≥ `kRailBreakpoint` (840) o shell usa `NavigationRail` à esquerda (mesmas destinations, mesmo `selectedIndex`/`goBranch`) e esconde a bottom bar; abaixo, como hoje. Listas continuam onde estão **[decisão]** (mover para o 1º nível muda o mapa de rotas e deep links; fica para quando a aba Eventos existir).
- Testes: `appTabsFor` (flags → lista); router com `FF_EVENTS=false` não registra a rota; shell em 1200 px mostra rail e não bottom bar; testes existentes que contam 5 abas passam a usar a lista.

### E.2 E8 — `AppFailure`
- `sealed class AppFailure` em `lib/core/failures/app_failure.dart`: `NetworkFailure`, `OfflineFailure`, `NotFoundFailure`, `StorageFailure`, `AuthFailure`, `ConflictFailure`, `UnknownFailure(Object cause)`; `AppFailure.from(Object error)` mapeia as exceções existentes de `pdf_reader/domain/exceptions` e `offline/domain/exceptions` (e `DioException`, `StorageUnavailableException`) — as exceções continuam existindo no domínio, mas **sem mensagem em PT** (campo `message` removido onde só a UI o lia). `failureMessage(AppLocalizations l10n, AppFailure f)` em `lib/core/l10n/failure_message.dart` centraliza o texto.
- Migração desta onda: os `catch` da presentation de `pdf_reader` e `offline` (snackbars de abrir PDF, download, reconcile) passam por `AppFailure.from` + `failureMessage`; os `catch (_) {}` silenciosos desses dois features passam a registrar em `AppLogger`. Outros features ficam para depois.
- Testes: `AppFailure.from` (cada exceção → tipo); `failureMessage` (cada tipo → chave); os testes de widget existentes dos snackbars continuam verdes com o texto vindo do l10n.

### E.3 E13 — `PlatformCapabilities`
- `PlatformCapabilities{isWeb, supportsBackgroundAudio, needsUserGestureForAudio, supportsFileSave, supportsFullscreenApi}` (`lib/core/platform/platform_capabilities.dart`) com conditional import `platform_capabilities_{native,web}.dart` e `platformCapabilitiesProvider` (`Provider`, sobreescrevível). Os nove `kIsWeb` da presentation (`audio_player_session_provider`, `audio_player_screen`, `playlist_sync_lifecycle`, `deep_link_listener`, `open_youtube_material`, `search_bar`) passam a ler o provider. `kIsWeb` continua permitido em `data`/`core`.
- Sufixos: convenção documentada (`_native`/`_web`; `_stub` só quando não há implementação nativa); sem renomear arquivos nesta onda **[decisão]**.
- Testes: cada capability por plataforma; os testes existentes dos seis arquivos ganham override do provider onde precisavam de `kIsWeb`.

### E.4 E4 — god files
- `playlist_list_tile.dart` (945) → `playlist_list_tile.dart` (tile + estado), `playlist_tile_header.dart` (`_PlaylistHeader` → `PlaylistTileHeader`), `playlist_tile_detail_chips.dart`, `playlist_tile_actions.dart` (`_runAction`/menu → `PlaylistTileActions` com as mesmas assinaturas). `offline_settings_screen.dart` (728) → tela + `offline_settings_widgets/{category_filter_chip, keep_app_open_banner, checkpoint_banner, progress_section}.dart`. `carousel_louvor_chip.dart` (591) → chip + `chip_parts/{metadata_row, chip_body, chip_buttons, share_overflow_button}.dart`. Sem mudança de comportamento; testes existentes intocados salvo imports.
- `playlists_provider.dart` (469) e `material_sheet.dart` (499) já encolheram — fora.

### E.5 E10 — infra de teste compartilhada
- `test/support/`: `pump_app.dart` (`pumpApp(tester, child, {overrides, locale})` com `MaterialApp` + l10n + `ProviderScope`), `fakes/fake_playlists_notifier.dart`, `fakes/fake_isar.dart`, `fakes/fake_active_editor.dart`, `fakes/fake_catalog_repository.dart`, `fakes/fake_auth_remote_datasource.dart`, `test_overrides.dart` (`standardTestOverrides({SharedPreferences? prefs})`: `sharedPreferencesProvider`, `isarStatusProvider`, `isarOpenerProvider`, `carouselLocalDatasourceProvider`, `platformCapabilitiesProvider`). Migrar os arquivos com as cinco fakes mais duplicadas (15 + 8 + 5 + 4 + 4) para importar de `test/support/`.
- Goldens ficam fora **[decisão]** (variam por plataforma de CI; sem infra de baseline).
- Teste: `flutter test` inteiro verde; nenhum `_FakePlaylistsNotifier`/`_FakeIsar` local sobrando (`grep`).

---

## Ordem de execução e paralelismo

- **Fase 1 (paralela, arquivos disjuntos):** T1 E.4 splits; T2 E.3 `PlatformCapabilities`; T3 A.1 + A.2 (mini-player, face de áudio, shell, título); T4 A.3 (ajuste, fullscreen web, última página, ir para página); T5 A.5 (cifra); T6 B.1 (Home vazia + recentes); T7 B.5 + D.1 + D.2 + D.3 (persistência, quota, nav, morto); T8 C.2 (Worker + cliente do link curto + dedupe); T9 C.1 (folheto por entradas — domínio/leaflet; os dois call sites do `PlaylistShareContext` são editados por T9 só nas linhas do contexto; T1 não toca essas linhas do tile porque as move inteiras — ver ruling no ledger).
- **Fase 2 (após a fase 1 integrada):** T10 E.1 (flags + rail; shell após T3); T11 A.6 (split view; após T3, T4, T5); T12 B.2 (card; após T1); T13 B.3 (nome/undo/duplicar/folheto direto; após T1, T3, T9); T14 B.4 (player; após T2, T3); T15 A.4 (spread + A13; após T2, T4).
- **Fase 3:** T16 E.2 (`AppFailure`; após T4, T15, T7); T17 E.5 (`test/support`; por último); revisão final da branch; onda única de correções; doc + artifact.

## Fora de escopo (próxima onda)

A9 (SW próprio/cache de shell — decisão de CDN; a reversão anterior foi deliberada), A16, E12 (separar publicação — migration de dados + decisão de produto), C3 (letra no manifest), C15 (varredura l10n/toque/semântica — item de varredura contínua), D9, D11, loop A–B, capo, reordenar na barra, mover Listas ao 1º nível, renomear sufixos `_stub`/`_io`, goldens, overrides remotos de flags.

## Riscos aceitos

- **Exclusão adiada de lista (B.3):** fechar a aba dentro dos 5 s cancela a exclusão; nada é perdido, só não apagado.
- **Última página lembrada (A.3):** em culto pode surpreender quem espera a página 1; o indicador e o long-press mitigam.
- **Link curto público (C.2):** `GET /l/:code` sem rate limit — só leitura, cacheável na borda; criação exige login e tem teto diário.
- **Aba Eventos escondida por flag (E.1):** o índice das abas muda; deep links para `/eventos` caem no redirect padrão do router.
- **Fullscreen web (A.3):** `requestFullscreen` exige gesto do usuário; via tecla `F` funciona (keydown é gesto), via código não — falha só registra.
- **Marcador tocando (B.4):** posição menos precisa que pausado; o usuário pode editar a posição depois (já existe).

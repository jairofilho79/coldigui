# Feature Index — PLPCG Flutter

**Última atualização:** junho de 2026 (**agrupamento `groupId` jun/2026** — [LouvorGroup] / [LouvorGroupCard] / [showLouvorMaterialSheet]; [GroupLouvoresByMaterial]; [LouvorGroupId]; [homeSearchGroupResultsProvider] / [libraryGroupResultsProvider]; script `assign_louvor_group_ids.py`; [openLouvorInReader]; teste `group_louvores_by_material_test`; spec [LOUVOR_GROUPING.md](./LOUVOR_GROUPING.md); **UC-01 busca flexível jun/2026** — [LouvorSearchTokens.compact], [LouvorSearchTokens.hasWordSeparators], [LouvorSearchTokens.matchesText]; tokenização por `[^a-z0-9]+` (hífens/pontuação); campo [Louvor.searchCompactContent]; exemplos `buscarmeeis` / `buscar me eis` / `buscar-me-eis` → `Buscar-me-eis`; testes `louvor_search_tokens_test` + `search_louvor_by_number_or_text_test`; **LOUVOR_GROUPING.md jun/2026** — spec agente `groupId` (hierarquia louvor → classificação → categoria, regras `f(numero, nomeNorm)`, entidades planejadas, pipeline script, anti-padrões); índice em [Especificações de design](#especificações-de-design-agentes); **docs sync UC-14 + catálogo jun/2026** — subseções API [RoutePaths], [LouvorMaterialIcons], [findLouvorByPdfId], [ResolvedActivePlaylist]; doc comments em `route_paths.dart`; **backlog `groupId`** — hierarquia louvor → classificação → categoria documentada; **docs sync pós-initial commit** — tabela transversal [resolveActivePlaylistFromCarousel]; correções [loadIntoCarousel]/`carouselLouvoresDisplayDebounce`; subseção [playlistShareDebugLog*]; **UC-06 debug abrir lista jun/2026**: [playlistOpenDebugLog*] + [showPlaylistOpenErrorSnackbar] — instrumentação [PlaylistListTile]._openPdfInReader / [PlaylistsNotifier.loadIntoCarousel] / [PlaylistsNotifier.findLouvorByPdfId]; console `[UC-06 playlist-open]`; snackbar [pdfActionError] + resumo técnico em debug (8s); **UC-05 fix flicker reorder jun/2026**: [carouselLouvoresDisplayProvider] + [carouselLouvoresDisplayDebounce] (`100ms`) — barra [CarouselChips] coalesce renders só em reordenação; [carouselReorderPersistDebounce] — [CarouselLouvoresNotifier.reorder] otimista sem `_reload` + persist Isar/sync playlist debounced; `_reloadGeneration` ignora corridas; [carouselFocusedIndexProvider] remove `ref.listen` duplicado; teste `carousel_louvores_display_provider_test`; **UC-05 fix drag modal seleção jun/2026**: [carouselSelectionReorderProxyDecorator] — proxy transparente no [ReorderableListView] de [showCarouselSelectionSheet]; remove borda/sombra retangular do `Material` padrão durante reorder de chips pill [CarouselLouvorChipVariant.modal]; **UC-04 share PDF nos cards jun/2026**: [LouvorCard] menu ⋮ à direita do trailing +/✓ → item [sharePdf] **Compartilhar**; [CarouselLouvorChip.onShare] / `shareLoading`; [LouvorCard._handleShare] → [resolvePdfForReaderProvider] + [sharePdfProvider] com [sharePositionOriginFromContextOrFallback] (fix iOS); paridade toolbar [PdfReaderScreen]; testes `louvor_card_share_save_test` + `carousel_louvor_chip_test`; **UC-14 AboutScreen jun/2026**: [AboutScreen] + [AboutInfoCard] — cards "Quem somos" e "Objetivo"; layout scroll `maxWidth: 896`; título Garamond 18px + divisor gold + corpo Open Sans; textos fixos PT; **UC-07 fix share lista + debug**: [resolveActivePlaylistFromCarousel] + [ResolvedActivePlaylist] — alinha carousel Isar com playlist antes do share (recupera rascunho quando [activePlaylistIdProvider] se perde no restart); [sharePositionOriginFromContextOrFallback] obrigatório no iOS para [Share.share]; [playlistShareDebugLog*] + [showPlaylistShareErrorSnackbar]; testes `resolve_active_playlist_from_carousel_test.dart`; **UC-07 share lista na barra carousel**: [CarouselBarTrailingActions] item [carouselSharePlaylist] — menu overflow smartphone + `share_outlined` expandido; delega [PlaylistsNotifier.sharePlaylist] na playlist ativa; paridade PWA `/?sharepdfs=…&sharename=…`; **UI polish app shell jun/2026**: removido [OfflineIndicator] do header; [PlpcgPrimaryAppBar] só título + divisor gold; [ColdiguiApp] `debugShowCheckedModeBanner: false`; **UC-06 polish [PlaylistsScreen]**: FAB stack — `FloatingActionButton.small` branco apagar todas (só aba Não Salvas) acima do extended importar; estado vazio com [AppColors.textLight] nas 3 abas; **UC-05 polish barra carousel ícones**: [carouselBarIconButtonStyle] — setas/lista/ações com [AppColors.title] (vinho PLPCG), inclusive desabilitado; menu overflow `iconColor` alinhado; **UC-08 fix renderização folheto**: [LeafletContent] raiz `Material(transparency)` + `TextDecoration.none` — remove sublinhação amarela debug sem ancestral Material no [OverlayEntry]; **UC-08 redesign folheto PWA+**: identidade PLPCG — moldura dourada, tabela NÚMERO/NOME, rodapé litúrgico; [LeafletContentLabels] + [leafletWeekdayName] + [formatLeafletHeaderDate]; **UC-08 debug**: [leafletDebugLog]; **UC-08 fix captura**: [waitForRepaintBoundary]; **UC-11 navegação 2.3+**: [pdfReaderDisplayedPageProvider] — indicador `page/total` estável durante `animateToPage`; swipe via [PdfxPdfView.navigateToPage]; RTL/LTR + long-press → página 1)
**Fase atual:** Fase 4 — **4.1 ✅ carousel**, **4.2 ✅ playlists CRUD**, **4.3 ✅ load playlist**, **4.4 ✅ share URL**, **4.5 ✅ deep links**, **4.6 ✅ folheto**, **4.7 ✅ carousel no leitor**, **4.8 ✅ listas sempre ativas + abas**; **polish UI Home** ✅ (+ botão limpar busca); **polish UI Biblioteca** ✅; **polish UI Playlists** ✅ (tile + [PlaylistsScreen] FAB/empty); **polish UI Offline** ✅; **polish chip lista UC-01/03** ✅; **polish UC-14 bottom bar** ✅; **polish barra carousel ícones UC-05** ✅; **polish header app shell** ✅ (sem badge offline; sem selo DEBUG); **polish UC-14 Sobre** ✅ ([AboutScreen] + [AboutInfoCard])

**Próxima fase:** Fase 5 (`PollManifestChecksum`) ou backlog Fase 2 (2.6/2.7)

## Status por feature

| Feature | UCs | Prioridade | Status | Use cases |
|---------|-----|------------|--------|-----------|
| `core` | transversal | Alta | **Concluído** (Fase 0 + share anchor jun/2026) | `PdfPathNormalizer`, `LouvorSearchTokens`, `sharePositionOriginFromContext*`, schemas Isar + codegen, `isarProvider`, `AppConfig` |
| `catalog` | UC-01, UC-02, UC-12 | Alta | **Concluído** (Fase 1.5 + polish chip + busca flexível + share ⋮ + **agrupamento `groupId` jun/2026**) | [LouvorGroupCard] + sublista materiais; [GroupLouvoresByMaterial]; `groupId` client-side ([LouvorGroupId]); manifest remoto ainda sem campo (opcional); script `assign_louvor_group_ids.py`; ver [LOUVOR_GROUPING.md](./LOUVOR_GROUPING.md) |
| `library` | UC-03 | Alta | **Concluído** (Fase 1.4 + 1.5 + refatoração Visualização + **lista agrupada jun/2026**) | [libraryGroupResultsProvider] — Browse → Group → Sort → Paginate grupos; [LouvorGroupCard]; layout `maxWidth: 896`; [LibraryViewControls]; sync URL |
| `pdf_opening` | UC-04 | Alta | **Concluído** (Fase 2.1 ✅ + 2.5 ✅ + 3.4 ✅ + 4.7 ✅ + **share card ⋮ jun/2026**) | `OpenPdfInReader` com `pdfId` na rota; `SharePdf`, `SavePdf` (fast path local), `ValidatePdfAvailability`, `isLocalPdfPath`, `LouvorPdfPath`; consumido por [LouvorGroupCard] / [LouvorCard], [openLouvorInReader], [PdfReaderScreen], [openCarouselPdfInReader] e [PlaylistListTile] |
| `pdf_reader` | UC-11 | Alta | **Em progresso** (Fase 2.3 ✅ + **2.4 ✅ fullscreen** + 3.4 ✅ + 4.7 ✅ + lifecycle ✅ + UI 3 barras ✅ + carousel nav fix v3 ✅ + **long-press indicador página ✅** + **swipe horizontal ✅** + **indicador estável animateToPage ✅**) | [_ReaderScaffold]: barra 3 + [PdfReaderPageIndicator]; swipe → [PdfReaderDisplayedPageNotifier]; scroll vertical fixo; sessão `autoDispose`; [readerFullscreenProvider] |
| `offline` | UC-09, UC-10 | Alta | **Concluído** (Fase 3.7 + manutenção jun/2026) | 3.1–3.7 ✅ local-first + bulk + manutenção + UI; gate `OFFLINE_AVAILABLE` na tela offline (UC-09 vs UC-10); refresh stats; chips por material; download faltantes pré-filtrado |
| `carousel` | UC-05, UC-07 | Média | **Concluído** (Fase 4.1 + 4.7 ✅ + polish chip + abrir leitor + barra compartilhada + nav leitor fix v3 ✅ + overflow smartphone ✅ + **share lista barra ✅** + metadados chip modo médio ✅ + trailing add/lista + **share card ⋮ UC-04 ✅** + **ícones barra vinho ✅** + **fix drag modal seleção ✅** + **fix flicker reorder ✅**) | [carouselBarIconButtonStyle]; [CarouselBarTrailingActions]; [CarouselNavigatorBar]; [carouselLouvoresDisplayProvider] na barra; reorder otimista + debounce persist; [carouselSelectionReorderProxyDecorator] no modal |
| `playlists` | UC-06, UC-07 | Média | **Concluído** (Fase 4.2–4.5 ✅ + 4.8 ✅ + polish UI tile + screen ✅ + **fix share jun/2026** + **debug abrir lista jun/2026**) | UC-06 ✅: CRUD + rascunhos; abas [PlaylistsScreen]; lista ativa [activePlaylistIdProvider]; [resolveActivePlaylistFromCarousel]; debug abrir [playlistOpenDebugLog*]; UC-07 ✅: share/import + deep link + debug [playlistShareDebugLog*]; share em [CarouselBarTrailingActions] e [PlaylistListTile] com `sharePositionOrigin` |
| `leaflet` | UC-08 | Média | **Concluído** (Fase 4.6 + redesign PWA jun/2026 + fix render jun/2026) | [LeafletContent] PLPCG (`Material` off-screen); `LeafletEntry` `{numero,nome}`; [LeafletContentLabels]; captura PNG + share |
| `app_shell` | UC-14 | Transversal | **Concluído** (Fase 4.7 + UI polish + header compartilhado + bottom bar jun/2026 + fullscreen 2.4 + header sem badge jun/2026 + **Sobre jun/2026**) | [ShellScaffold] + [PlpcgPrimaryAppBar] + [CarouselChips] + [PlpcgBottomNavBar] + [AboutScreen]; header sem [OfflineIndicator] (removido); oculta barras 1–2 em fullscreen via [readerFullscreenProvider]; **4.5 ✅** deep links; Sobre via [AboutInfoCard] |
| `l10n` | transversal | Alta | **Em progresso** | `AppLocalizations` wired; UC-04, UC-03, UC-12, UC-09/10 offline, **UC-05 (4.1 + overflow barra)**, **UC-06/07 (4.2–4.8 abas listas + [carouselSharePlaylist])**, **UC-08 (4.6)**, **UC-11 carousel leitor (4.7)**, **design system Home + Biblioteca** |
| `admin` | UC-13 | Fora do MVP | Stub desabilitado | `UploadLouvorAdmin` (`FeatureFlags.enableAdminUpload=false`) |

### Legenda de status

| Status | Significado |
|--------|-------------|
| **Concluído** | Entrega da fase completa com testes |
| **Em progresso** | API pública parcialmente implementada com testes ou UI base funcional |
| **Esqueleto** | Pastas, use cases e widgets base criados; `UnimplementedError` ou placeholder UI |
| **Stub desabilitado** | Código presente mas feature flag desligada |

## Mapa de fases MVP

Alinhado ao [MVP Roadmap](../MVP%20Roadmap.md) — ordem de implementação (não confundir com grafo de UCs):

| Fase | Escopo | UCs | Status |
|------|--------|-----|--------|
| 0 | Core transversal | — | ✅ Concluída |
| 1 | Catálogo + biblioteca | UC-01, UC-02, UC-03, UC-12 (manual) | 1.1–1.5 ✅; `PollManifestChecksum` Fase 5 |
| 2 | Abrir e ler PDF | UC-04, UC-11 | **2.1 ✅** card → leitor; **2.3 ✅** zoom/navegação; **2.4 ✅** fullscreen; **2.5 ✅** share/save; 2.6/2.7 despriorizados |
| 3 | Offline local-first | UC-09, UC-10 | **3.1–3.7 ✅** storage → resolver → leitor → bulk → manutenção → UI ([OfflineSettingsScreen]; badge header removido jun/2026) |
| 4 | Seleção, playlists, folheto | UC-05–UC-08, UC-14 | **4.1 ✅** carousel; **4.2 ✅** playlists CRUD; **4.3 ✅** load playlist; **4.4 ✅** share URL; **4.5 ✅** deep links; **4.6 ✅** folheto; **4.7 ✅** carousel no leitor; **4.8 ✅** listas sempre ativas + abas |
| 5 | Polimento | UC-12 (poll), testes integração | Pendente |

Ordem de features:

```text
core → catalog → library → pdf_opening → pdf_reader → offline → carousel/playlists → leaflet
```

**Nota:** offline **não** bloqueia o leitor PDF online. Fase 3.4 integra `ResolvePdfForReader` no fluxo card → leitor (local-first + fetch on miss). Bulk UC-09 (3.5) é complementar, não gate de abertura.

## APIs públicas — Core

| API | Arquivo | Estado | Descrição |
|-----|---------|--------|-----------|
| `PdfPathNormalizer` | `lib/core/utils/pdf_path_normalizer.dart` | **Implementado + testes** | `getPdfRelPath` (§10.3 UTF-8 Base64) + `normalizePdfUrl` |
| `LouvorSearchTokens` | `lib/core/utils/louvor_search_tokens.dart` | **Implementado + testes + busca flexível jun/2026** | Stop words PT; `normalize`, `compact`, `hasWordSeparators`, `tokenize`, `matchesText` — base da busca UC-01 |
| `UrlSyncParams` | `lib/core/utils/url_sync_params.dart` | **Implementado 4.7** | Query params sincronizados: Home, Biblioteca, leitor (`file`, `pdfId`, `titulo`, `subtitulo`), share playlist (`sharepdfs`, `sharename`) |
| `buildHomeLocation` | `lib/core/utils/home_url_builder.dart` | **Implementado + testes** | Monta `/` com `pesquisa`, `materiais`, `arranjo`; omite defaults |
| `buildHomeLocationFromUri` | `lib/core/utils/home_url_builder.dart` | **Implementado + testes** | Normaliza `Uri` da Home para comparação no sync GoRouter |
| `PlaylistShareParams` | `lib/core/utils/playlist_share_url_builder.dart` | **Implementado 4.4** | Par `{sharePdfs, shareName}` extraído de URL |
| `buildPlaylistShareLocation` | `lib/core/utils/playlist_share_url_builder.dart` | **Implementado 4.4 + testes** | `/?sharepdfs=...&sharename=...` — compatível PWA |
| `buildPlaylistShareUrl` | `lib/core/utils/playlist_share_url_builder.dart` | **Implementado 4.4 + testes** | URL absoluta com [AppConfig.apiBaseUrl] |
| `parsePlaylistShareParams` | `lib/core/utils/playlist_share_url_builder.dart` | **Implementado 4.4 + testes** | Extrai params de [Uri] |
| `parsePdfIdsFromSharePdfs` | `lib/core/utils/playlist_share_url_builder.dart` | **Implementado 4.4 + testes** | CSV → lista ordenada dedupe |
| `extractShareParamsFromUserInput` | `lib/core/utils/playlist_share_url_builder.dart` | **Implementado 4.4 + testes** | URL completa ou query colada |
| `stripPlaylistShareParams` | `lib/core/utils/playlist_share_url_builder.dart` | **Implementado 4.5 + testes** | Remove `sharepdfs`/`sharename` de [Uri] após import deep link |
| `sharePositionOriginFromContext` | `lib/core/utils/share_position_origin.dart` | **Implementado 3.4 + fix jun/2026** | `RenderBox` global → `Rect?`; rejeita largura/altura ≤ 0 |
| `sharePositionOriginFromContextOrFallback` | `lib/core/utils/share_position_origin.dart` | **Implementado jun/2026** | Igual ao anterior; fallback 48×48 centro-inferior — iOS exige retângulo não nulo em [Share.share] e [Share.shareXFiles] |
| `DeepLinkConfig` | `lib/core/constants/deep_link_config.dart` | **Implementado 4.5** | `customScheme`, `universalLinkHost`, `associatedDomain` derivados de [AppConfig.apiBaseUrl] |
| `buildLibraryLocation` | `lib/core/utils/library_url_builder.dart` | **Implementado + testes** | Monta `/biblioteca` com `materiais`, `arranjo`, `arranjoEspecial`, `ordenar`, `itensPorPagina`, `pagina`; omite defaults (UC-03 Fase 1.4) |
| `buildLibraryLocationFromUri` | `lib/core/utils/library_url_builder.dart` | **Implementado + testes** | Normaliza `Uri` da Biblioteca para comparação no sync GoRouter |
| `buildReaderLocation` | `lib/core/utils/reader_url_builder.dart` | **Implementado 4.7 + testes** | Monta `/leitor` com `file`, `pdfId?`, `titulo?`, `subtitulo?`; encode via `Uri.encodeComponent` (UC-04 / UC-11) |
| `ApiEndpoints` | `lib/core/constants/api_endpoints.dart` | Constantes | Endpoints HTTP Cloudflare |
| `AppConfig` | `lib/core/constants/app_config.dart` | **Implementado** | `apiBaseUrl` compile-time; `isApiBaseUrlMissing`; ver [dart_defines/plpcg.json] + [PlpcgDartDefines.xcconfig] |
| `StorageKeys` | `lib/core/constants/storage_keys.dart` | Constantes | Chaves SharedPreferences; inclui `pdfViewerMode` (UC-04 Fase 2.5) |
| `OfflineConfig` | `lib/core/constants/offline_config.dart` | Constantes | `maxRetryAttempts`, `retryBackoffBase`, batch e TTLs; **Fase 3** — revisar constantes legadas PWA (`sw*`, `pdfCacheName`) |
| `FeatureFlags` | `lib/core/constants/feature_flags.dart` | Constantes | Flags de feature (UC-13 off) |
| `AppColors` | `lib/core/theme/color_extensions.dart` | **Implementado + polish** | Tokens de cor Coletânea Digital; inclui `shadowMd`, `shadowLg`, `goldGlow` (§6.2) |
| `AppTypography` | `lib/core/theme/app_typography.dart` | **Implementado** | EB Garamond + Open Sans bundled; `displayPlcpg`, `headline`, `body`, `label`, `tagLabel`, `hint()`, `textTheme()` (§6.3) |
| `AppTheme` | `lib/core/theme/app_theme.dart` | **Implementado + polish** | Material 3: `textTheme`, `inputDecorationTheme`, `chipTheme`, `cardTheme` dourado, `dividerTheme` gold |
| `GoldenTaggedContainer` | `lib/core/widgets/golden_tagged_container.dart` | **Implementado + polish** | Container "tag + caixa dourada" (§5.2); `contentPadding` customizável; `compactContentPadding` + `compactRowHeight` (24px) para campos Home; seções completas em [OfflineSettingsScreen]; `glowEnabled` → `goldenHeatWave`; reduce-motion e widget tests |
| `PlpcgAppBarTitle` | `lib/core/widgets/plpcg_app_bar_title.dart` | **Implementado** | Título PLPCG com [LightBeam] dourado (170×16); usado em [PlpcgPrimaryAppBar] e barra 1 do leitor |
| `LightBeam` | `lib/core/widgets/light_beam.dart` | **Implementado jun/2026** | Widget feixe dourado dimensionável (`width`, `height`); header + aba ativa bottom bar |
| `LightBeamPainter` | `lib/core/widgets/light_beam.dart` | **Implementado jun/2026** | [CustomPainter] elipse radial + halo (light-beam §6.2); usado por [LightBeam] |

### `GoldenTaggedContainer` — API de layout compacto (Home)

| Membro | Tipo | Default | Consumidores |
|--------|------|---------|--------------|
| `contentPadding` | `EdgeInsetsGeometry` (parâmetro) | `EdgeInsets.fromLTRB(12, 20, 12, 12)` | Seções completas: [OfflineSettingsScreen] (stats + download); [FiltersPanel] expandido usa `12/14/12/12`; [LibraryViewControls]; [CatalogRefreshBanner] |
| `compactContentPadding` | `static const EdgeInsets` | `EdgeInsets.fromLTRB(12, 14, 12, 8)` | [SearchBar], [FiltersPanel] colapsado, [PdfViewerSelector] |
| `compactRowHeight` | `static const double` | `24` | Altura da linha ícone+texto/chevron/dropdown na Home |
| `glowEnabled` | `bool` (parâmetro) | `false` | `true` apenas em [SearchBar] (`goldenHeatWave`) |
| `onTap` | `VoidCallback?` | `null` | [FiltersPanel] colapsado — toque na caixa expande |

**Padrão de implementação:** `Row` + `crossAxisAlignment: center` + `SizedBox(height: compactRowHeight)`; evitar `prefixIcon`/`suffixIcon` em [TextField] e usar `isDense: true` em [DropdownButton] para não herdar tap target de 48px.

### `LouvorSearchTokens` — API pública (UC-01)

| Membro | Tipo | Descrição |
|--------|------|-----------|
| `stopWords` | `static const Set<String>` | ~40 stop words PT removidas na tokenização |
| `normalize(text)` | `static String` | Minúsculas + remoção de acentos (`São João` → `sao joao`) |
| `compact(text)` | `static String` | Remove separadores/pontuação após `normalize` (`Buscar-me-eis` → `buscarmeeis`) |
| `hasWordSeparators(text)` | `static bool` | `true` se há espaço, hífen ou pontuação na query normalizada |
| `tokenize(title)` | `static List<String>` | Split `[^a-z0-9]+` + filtro stop words (`Buscar-me-eis` → `['buscar','me','eis']`) |
| `matchesText({...})` | `static bool` | Match UC-01: todos os tokens **ou** substring compacta (query sem separadores, ≥3 chars) |

**Exemplos de match textual** (título manifest `Buscar-me-eis`):

| Query digitada | Estratégia |
|----------------|------------|
| `buscar me eis` | tokens — cada token em `searchContentTokens` |
| `buscar-me-eis` | tokens — hífens tratados como separadores |
| `buscarmeeis` | compacto — `compact(query)` ⊆ `searchCompactContent` |

**Consumidores:** [SearchLouvorByNumberOrText]; [Louvor.fromManifest] pré-computa `searchContentTokens` e `searchCompactContent`.

### `LightBeam` — API pública (design system §6.2)

| Membro | Tipo | Default | Consumidores |
|--------|------|---------|--------------|
| `width` | `double` (parâmetro) | — | Largura do feixe; header PLPCG `170`; aba ativa bottom bar `TextPainter × 1.35` clamp 36–96 |
| `height` | `double` (parâmetro) | `16` | Altura achatada em elipse; bottom bar usa `9` |
| `LightBeamPainter` | [CustomPainter] | const | Halo + disco radial + brilho residual; `shouldRepaint` → `false` |

### `PlpcgBottomNavBar` — API pública (UC-14)

| Membro | Tipo | Default | Descrição |
|--------|------|---------|-----------|
| `selectedIndex` | `int` (parâmetro) | — | 0 Sobre, 1 Biblioteca, 2 Pesquisar (home), 3 Offline, 4 Listas |
| `onDestinationSelected` | `ValueChanged<int>` | — | [ShellScaffold] → `context.go(RoutePaths.*)` |
| `destinations` | `List<PlpcgBottomNavDestination>` | — | Tipicamente 5 itens const no scaffold |
| `animationDuration` | `static const Duration` | `380ms` | Scale, feixe, ícone e texto; `Curves.easeInOut` |
| Aba ativa | interno | scale `1.14` | Ícone 26px [AppColors.placeholder]; rótulo Garamond 11px + [LightBeam] |
| Aba inativa | interno | scale `0.86` | Ícone 20px branco 52%; rótulo Open Sans 10px |
| Reduce-motion | interno | — | `MediaQuery.disableAnimationsOf` → duração zero |

| `PlpcgBottomNavDestination.icon` | `IconData` | — | Ícone Material acima do rótulo |
| `PlpcgBottomNavDestination.label` | `String` | — | Rótulo curto; ellipsis se overflow |

**Destinos UC-14 em [ShellScaffold]:** Sobre (`info_outline`), Biblioteca (`library_books`), **Pesquisar** (`search`, rota `/`), Offline (`cloud_download`), Listas (`playlist_play`). O título **PLPCG** fica exclusivamente no header ([PlpcgAppBarTitle]), não na bottom bar.

### `PlpcgPrimaryAppBar` — API pública (UC-14)

| Membro | Tipo | Default | Descrição |
|--------|------|---------|-----------|
| `preferredSize` | `Size` | `kToolbarHeight + 4` | Altura toolbar + divisor gold 4px |
| `title` | [PlpcgAppBarTitle] | const | Título central PLPCG + [LightBeam] |
| `automaticallyImplyLeading` | interno | `false` | Sem botão voltar no shell |
| `actions` | — | vazio | Badge offline removido jun/2026 (ex-[OfflineIndicator]) |
| `bottom` | `PreferredSize` | divisor 4px | [AppColors.gold] — linha sob o header |

**Consumidores:** [ShellScaffold.appBar]; barra 1 do leitor via [CarouselBarShell] + `SizedBox` em [_ReaderScaffold].

### `AboutScreen` — API pública (UC-14)

| Membro | Tipo | Default | Descrição |
|--------|------|---------|-----------|
| `_maxContentWidth` | `static const double` | `896` | Paridade [LibraryScreen] / [HomeScreen] |
| Layout | `ListView` | padding `16/12/16/24` | Dois [AboutInfoCard]: "Quem somos" (1 parágrafo) + "Objetivo" (2 parágrafos); gap 16px |
| Rota | [RoutePaths.about] | `/sobre` | Destino índice 0 em [PlpcgBottomNavBar] / [ShellScaffold] |
| l10n | — | fixo PT | Conteúdo institucional hardcoded (sem [AppLocalizations] nesta entrega) |

**Consumidores:** [appRouterProvider] → [ShellScaffold.child] quando aba Sobre ativa.

### `AboutInfoCard` — API pública (UC-14)

| Membro | Tipo | Default | Descrição |
|--------|------|---------|-----------|
| `title` | `String` (parâmetro) | — | Título serif EB Garamond 18px [AppColors.title] |
| `paragraphs` | `List<String>` (parâmetro) | — | Corpo sans Open Sans 14px height 1.5 [AppColors.textDark]; múltiplos parágrafos com gap 14px |
| Container | interno | — | [AppColors.card] fundo creme; borda [AppColors.background] 1.5px; `borderRadius` 12; [AppColors.shadowMd] |
| Divisor | `Divider` | gold 1.5px | Entre título e corpo |

**Consumidores:** [AboutScreen] (seções "Quem somos" e "Objetivo").

### `RoutePaths` — API pública (UC-14 / routing)

| Membro | Valor | Tela | Bottom bar |
|--------|-------|------|------------|
| `about` | `/sobre` | [AboutScreen] | índice 0 |
| `library` | `/biblioteca` | [LibraryScreen] | índice 1 |
| `home` | `/` | [HomeScreen] | índice 2 (Pesquisar) |
| `offline` | `/offline` | [OfflineSettingsScreen] | índice 3 |
| `playlists` | `/listas` | [PlaylistsScreen] | índice 4 |
| `reader` | `/leitor` | [PdfReaderScreen] | oculta bottom bar |

**Consumidores:** [appRouterProvider], [ShellScaffold._onTap], deep links UC-07.

### `SearchBar` — API pública (UC-01)

| Membro | Tipo | Default | Descrição |
|--------|------|---------|-----------|
| `hintText` | `String` (parâmetro) | — | Placeholder — tipicamente [AppLocalizations.searchHint] |
| `initialValue` | `String` (parâmetro) | `''` | Query inicial (ex.: `pesquisa=` da URL); sincronizado em `didUpdateWidget` |
| Botão limpar | `IconButton` (interno) | oculto se vazio | `Icons.close` 18px; tooltip [AppLocalizations.searchClear]; limpa controller + [homeSearchRawQueryProvider]; [FocusNode.requestFocus] |
| `FocusNode` | interno | — | Mantém foco no [TextField] após limpar |
| Provider | [homeSearchRawQueryProvider] | — | `onChanged` e limpar escrevem texto imediato; debounce 300ms em [homeSearchDebouncedQueryProvider] |

| `PlpcgPrimaryAppBar` | `lib/core/widgets/plpcg_primary_app_bar.dart` | **Implementado UI 3 barras + polish jun/2026** | `PreferredSizeWidget` — [PlpcgAppBarTitle] + divisor gold 4px; sem `actions`; [ShellScaffold.appBar] e leitor (barra 1 em `SizedBox` no [_ReaderScaffold]) |
| `RoutePaths` | `lib/core/routing/route_paths.dart` | **Implementado + doc jun/2026** | 6 paths shell + leitor; ver subseção [RoutePaths](#routepaths--api-pública-uc-14--routing) |
| `appRouterProvider` | `lib/core/routing/app_router.dart` | **Implementado** | GoRouter + [rootNavigatorKey]; `ShellRoute` (5 destinos) + `/leitor` com `parentNavigatorKey` (fullscreen fora do shell); Home lê `pesquisa=`, `materiais=`, `arranjo=`; Biblioteca lê `materiais=`, `arranjo=`, `arranjoEspecial=`, `ordenar=`, `itensPorPagina=`, `pagina=` |
| `dioProvider` | `lib/core/providers/dio_provider.dart` | **Implementado** | Cliente HTTP Dio com `baseUrl` de [AppConfig] |
| `sharedPreferencesProvider` | `lib/core/providers/shared_prefs_provider.dart` | **Implementado** | Override em `main()` via `SharedPreferences.getInstance()` |
| `isarProvider` | `lib/core/database/isar_provider.dart` | **Implementado** | `Provider<Isar>`; override em `main()` após `Isar.open` |

### `FiltersPanel` — API pública (UC-02 / UC-03)

| Membro | Tipo | Default | Descrição |
|--------|------|---------|-----------|
| `initiallyExpanded` | `bool` (parâmetro) | `false` | Expande ao montar quando a URL traz filtros (`materiais=`, `arranjo=` ou `arranjoEspecial=` na biblioteca) |
| `additionalExpandedSections` | `List<Widget>` (parâmetro) | `const []` | Widgets renderizados após [ClassificationFilters] quando expandido; biblioteca passa [SpecialArrangementFilters] |

**Consumidores:** [HomeScreen] (apenas material + arranjo); [LibraryScreen] (`additionalExpandedSections: [SpecialArrangementFilters]`).

### Configuração de build — `PLPCG_API_BASE_URL`

| Artefato | Caminho | Descrição |
|----------|---------|-----------|
| `dart_defines/plpcg.json` | raiz | Fonte única da URL pública `https://plpcg.com` (não é secret) |
| `PlpcgDartDefines.xcconfig` | `ios/Flutter/` | Injeta `DART_DEFINES` em builds iOS Debug/Release sem flags no terminal |
| `AppConfig.apiBaseUrl` | `app_config.dart` | `String.fromEnvironment('PLPCG_API_BASE_URL')` |
| `AppConfig.isApiBaseUrlMissing` | `app_config.dart` | Gate em [ColdiguiApp] antes do router |

### Fontes bundled — design system (§6.3)

| Artefato | Caminho | Descrição |
|----------|---------|-----------|
| `EBGaramond[wght].ttf` | `assets/fonts/` | Variable font — títulos, PLPCG, cards (pesos 400–700) |
| `OpenSans[wdth,wght].ttf` | `assets/fonts/` | Variable font — corpo, chips, tags |
| `OFL.txt` | `assets/fonts/` | Licença SIL Open Font License |
| `pubspec.yaml` → `flutter.fonts` | raiz | Famílias `EBGaramond` e `OpenSans` (sem `google_fonts`) |

**CLI recomendado:**

```bash
flutter run --dart-define-from-file=dart_defines/plpcg.json
flutter build ios --dart-define-from-file=dart_defines/plpcg.json
flutter test --dart-define-from-file=dart_defines/plpcg.json
```

**Testes unit/widget:** use `https://example.com` em vez de produção.

## APIs públicas — Persistência (Isar)

Schemas anotados com `@Collection()`; codegen via `dart run build_runner build`.

| API | Arquivo | Estado | Descrição |
|-----|---------|--------|-----------|
| `LouvorCache` | `lib/core/database/collections/louvor_cache.dart` | **Implementado** | Cache local do catálogo; `@Index(unique: true)` em `pdfId` |
| `CarouselEntry` | `lib/core/database/collections/carousel_entry.dart` | **Implementado 4.1** | `@Index(unique: true)` em `pdfId`; `@Index()` em `sortOrder` |
| `Playlist` | `lib/core/database/collections/playlist.dart` | **Implementado 4.2 + 4.8** | UC-06; `@Index(unique: true)` em `playlistId`; `nome`, `pdfIds`, `createdAt`, `salva` (default `true` — migra existentes), `savedAt`, `favoritedAt`, `favorita` |
| `OfflinePdfIndex` | `lib/core/database/collections/offline_pdf_index.dart` | **Implementado 3.1** | Índice O(1) `pdfId` → `storagePath` (absoluto), `category`, `fileSize`, `downloadedAt`; `@Index(unique: true)` em `pdfId` |

## APIs públicas — Domínio

| API | Arquivo | Estado | Descrição |
|-----|---------|--------|-----------|
| `Louvor` | `lib/features/catalog/domain/entities/louvor.dart` | **Implementado + groupId jun/2026** | Entidade + `fromManifest()`; `groupId` opcional; `effectiveGroupId`; tokens de busca UC-01 |
| `LouvorGroup` | `lib/features/catalog/domain/entities/louvor_group.dart` | **Implementado jun/2026 + testes** | Louvor lógico — `groupId`, `numero`, `nome`, `sections`; `fromLouvores()`; `totalMaterials`, `primaryLouvor` |
| `LouvorMaterialSection` | idem | **Implementado jun/2026** | Sublista por `classificacao` + `displayLabel` + `materials` |
| `LouvorMaterialEntry` | idem | **Implementado jun/2026** | Folha: `categoria`, `pdfId`, `Louvor` |
| `LouvorGroupId` | `lib/features/catalog/domain/utils/louvor_group_id.dart` | **Implementado jun/2026 + testes** | `compute()`, `effective()` — espelha `assign_louvor_group_ids.py` |
| `LouvorCategoryOrder` | `lib/features/catalog/domain/constants/louvor_category_order.dart` | **Implementado jun/2026** | Ordem Partitura → Cifra I/II → Cifra → Gestos; `compare()` |
| `GroupLouvoresByMaterial` | `lib/features/catalog/domain/usecases/group_louvores_by_material.dart` | **Implementado jun/2026 + testes** | `List<Louvor>` → `List<LouvorGroup>` via [LouvorGroup.fromLouvores] |
| `groupLouvoresByMaterialProvider` | `lib/features/catalog/data/providers/catalog_providers.dart` | **Implementado jun/2026** | DI [GroupLouvoresByMaterial] |
| `CatalogRepository` | `lib/features/catalog/domain/repositories/catalog_repository.dart` | Contrato | `loadManifest`, `forceRefreshManifest`, `cacheManifest`, `fetchManifestChecksum` |
| `LoadLouvoresManifest` | `lib/features/catalog/domain/usecases/load_louvores_manifest.dart` | **Implementado + testes** | UC-12 boot — `call()` → `List<Louvor>` via rede ou cache Isar |
| `SearchLouvorByNumberOrText` | `lib/features/catalog/domain/usecases/search_louvor_by_number_or_text.dart` | **Implementado + testes + busca flexível jun/2026** | UC-01 — `call(catalog, query)` síncrono; número exato prioritário; texto via [LouvorSearchTokens.matchesText] |
| `FilterByMaterialAndArranjo` | `lib/features/catalog/domain/usecases/filter_by_material_and_arranjo.dart` | **Implementado + testes** | UC-02 — `call(louvores, selectedMaterials, selectedArranjos)`; Cifra expande I/II |
| `FilterBySpecialArrangement` | `lib/features/catalog/domain/usecases/filter_by_special_arrangement.dart` | **Implementado + testes** | UC-03 — `call(louvores, selectedSpecialArrangements)`; vazio → sem filtro; match via `LouvorClassification.specialArrangement` |
| `CatalogMaterials` | `lib/features/catalog/domain/constants/catalog_materials.dart` | **Implementado + testes** | Materiais UI, expansão Cifra, parse/serialize URL |
| `LouvorClassification` | `lib/features/catalog/domain/utils/louvor_classification.dart` | **Implementado + testes + groupId jun/2026** | `baseClassification()`, `displayLabel()`, `materialSectionLabel()`, `specialArrangement()`; parse/serialize URL |
| `LouvorMaterialIcons` | `lib/features/catalog/domain/utils/louvor_material_icons.dart` | **Implementado + polish chip** | `forCategory(categoria)` → `IconData` (Partitura/Cifra/Gestos) — [LouvorCard], [CarouselLouvorChip] |
| `findLouvorByPdfId` | `lib/features/catalog/domain/utils/find_louvor_by_pdf_id.dart` | **Implementado 4.7** | `findLouvorByPdfId(catalog, pdfId)` → `Louvor?`; lookup O(n) no manifest — usado por [ReaderCarouselActionsNotifier] e [PlaylistsNotifier] |
| `ForceRefreshCatalog` | `lib/features/catalog/domain/usecases/force_refresh_catalog.dart` | **Implementado + testes** | UC-12 — `call()` → `forceRefreshManifest()`; fetch remoto obrigatório, sem fallback |
| `PollManifestChecksum` | `lib/features/catalog/domain/usecases/poll_manifest_checksum.dart` | Esqueleto | UC-12 — Fase 5 (poll automático SHA-256) |
| `LouvorDto` | `lib/features/catalog/data/models/louvor_dto.dart` | **Implementado + groupId jun/2026** | `fromJson` + `toEntity`; campo opcional `groupId` |
| `OpenPdfDocument` | `lib/features/pdf_reader/domain/usecases/open_pdf_document.dart` | **Implementado + testes** | UC-11 — `validateFilePath()`; sanitiza `file` antes do adapter |
| `InvalidPdfPathException` | `lib/features/pdf_reader/domain/exceptions/invalid_pdf_path_exception.dart` | **Implementado** | Erro de validação UC-11 antes da abertura PDFx |
| `SavedPlaylist` | `lib/features/playlists/domain/entities/saved_playlist.dart` | **Implementado 4.2 + 4.8** | Entidade UC-06 — ver seção [playlists (Fase 4.2–4.8)](#apis-públicas--playlists-fase-42–48-uc-0607) |
| `PlaylistTab` | `lib/features/playlists/domain/entities/playlist_tab.dart` | **Implementado 4.8** | `unsaved` / `saved` / `favorites` — abas da [PlaylistsScreen] |
| `EnsurePlaylistResult` | `lib/features/playlists/domain/usecases/ensure_playlist_for_louvor.dart` | **Implementado 4.8 + testes** | `{playlistId, createdNew}` — retorno de [EnsurePlaylistForLouvor] |
| `EnsurePlaylistForLouvor` | `lib/features/playlists/domain/usecases/ensure_playlist_for_louvor.dart` | **Implementado 4.8 + testes** | Reutiliza lista ativa se `pdfId` presente; senão cria rascunho (`salva: false`) + [LoadPlaylistIntoCarousel] |
| `SavePlaylist` | `lib/features/playlists/domain/usecases/save_playlist.dart` | **Implementado 4.8** | `salva = true`, `savedAt = now`; opcional `nome` |
| `FavoritePlaylist` | `lib/features/playlists/domain/usecases/favorite_playlist.dart` | **Implementado 4.8** | `favorita = true`, `favoritedAt = now` — exige `salva` |
| `UnfavoritePlaylist` | `lib/features/playlists/domain/usecases/unfavorite_playlist.dart` | **Implementado 4.8** | `favorita = false`, limpa `favoritedAt` |
| `DeleteAllUnsavedPlaylists` | `lib/features/playlists/domain/usecases/delete_all_unsaved_playlists.dart` | **Implementado 4.8 + testes** | Remove todas com `salva == false` |
| `PlaylistNotFoundException` | `lib/features/playlists/domain/exceptions/playlist_not_found_exception.dart` | **Implementado 4.3** | Playlist ausente em [LoadPlaylistIntoCarousel] |
| `PlaylistRepository` | `lib/features/playlists/domain/repositories/playlist_repository.dart` | **Implementado 4.2 + 4.8** | CRUD + `getByTab(PlaylistTab)` + `deleteAllUnsaved`; campos `salva`/`savedAt`/`favoritedAt` |
| `CreatePlaylistFromCarousel` | `lib/features/playlists/domain/usecases/create_playlist_from_carousel.dart` | **Implementado 4.2 + testes** | UC-06 — snapshot do carousel → Isar |
| `UpdatePlaylist` | `lib/features/playlists/domain/usecases/update_playlist.dart` | **Implementado 4.2** | UC-06 — renomear e/ou alterar `pdfIds` |
| `DeletePlaylist` | `lib/features/playlists/domain/usecases/delete_playlist.dart` | **Implementado 4.2** | UC-06 — exclusão idempotente |
| `TogglePlaylistFavorite` | `lib/features/playlists/domain/usecases/toggle_playlist_favorite.dart` | **Implementado 4.2** | UC-06 — alterna `favorita`; retorna novo estado |
| `LoadPlaylistIntoCarousel` | `lib/features/playlists/domain/usecases/load_playlist_into_carousel.dart` | **Implementado 4.3 + testes** | UC-06 — `getById` → `CarouselRepository.replaceAll` |
| `GeneratePlaylistShareUrl` | `lib/features/playlists/domain/usecases/generate_playlist_share_url.dart` | **Implementado 4.4 + testes** | UC-07 — `call({playlistId})` → URL absoluta |
| `ImportSharedPlaylistFromUrl` | `lib/features/playlists/domain/usecases/import_shared_playlist_from_url.dart` | **Implementado 4.4 + testes** | UC-07 — create + `LoadPlaylistIntoCarousel`; retorna `playlistId` |
| `EmptyPlaylistShareException` | `lib/features/playlists/domain/exceptions/empty_playlist_share_exception.dart` | **Implementado 4.4** | Playlist vazia ao compartilhar |
| `InvalidSharePlaylistException` | `lib/features/playlists/domain/exceptions/invalid_share_playlist_exception.dart` | **Implementado 4.4** | Params de import inválidos |
| `ResolvedActivePlaylist` | `lib/features/playlists/presentation/providers/playlists_provider.dart` | **Implementado jun/2026** | `{playlistId, nome}` — resultado de [resolveActivePlaylistFromCarousel] |
| `PlaylistsNotifier.resolveActivePlaylistFromCarousel()` | `lib/features/playlists/presentation/providers/playlists_provider.dart` | **Implementado jun/2026 + testes** | Carousel Isar → sync/reutiliza/cria rascunho; restaura [activePlaylistIdProvider]; `null` se vazio |
| `playlistShareDebugLog` / `playlistShareDebugLogError` / `playlistShareDebugErrorSummary` | `lib/features/playlists/presentation/utils/playlist_share_debug_log.dart` | **Implementado jun/2026** | Diagnóstico UC-07 em [kDebugMode] — console `[UC-07 playlist-share]` + resumo na snackbar |
| `showPlaylistShareErrorSnackbar` | `lib/features/playlists/presentation/utils/playlist_share_debug_log.dart` | **Implementado jun/2026** | Snackbar [playlistShareError] + detalhe técnico em debug (8s) |
| `playlistOpenLastStage` / `playlistOpenLastError` | `lib/features/playlists/presentation/utils/playlist_open_debug_log.dart` | **Implementado jun/2026** | Estado de diagnóstico da última falha UC-06 — preenchido em [kDebugMode] |
| `playlistOpenDebugClearLastFailure` | idem | **Implementado jun/2026** | Limpa `playlistOpenLast*` antes de `_openPdfInReader` |
| `playlistOpenDebugLog` / `playlistOpenDebugLogError` / `playlistOpenDebugLogFailure` / `playlistOpenDebugErrorSummary` | idem | **Implementado jun/2026** | Diagnóstico UC-06 abrir lista no leitor em [kDebugMode] — console `[UC-06 playlist-open]` + resumo na snackbar |
| `showPlaylistOpenErrorSnackbar` | idem | **Implementado jun/2026** | Snackbar [pdfActionError] + detalhe técnico em debug (8s) |
| `PlaylistsNotifier.findLouvorByPdfId(pdfId)` | `lib/features/playlists/presentation/providers/playlists_provider.dart` | **Implementado jun/2026** | Lookup manifest + instrumentação [playlistOpenDebugLog*]; `null` se órfão |
| `PlaylistsNotifier.loadIntoCarousel(playlistId)` | idem | **Implementado 4.3 + debug jun/2026** | [LoadPlaylistIntoCarousel] → [activePlaylistIdProvider].set → reload carousel → reset foco; `false` em erro; [playlistOpenDebugLog*] |
| `LeafletEntry` | `lib/features/leaflet/domain/entities/leaflet_entry.dart` | **Implementado 4.6 + redesign** | `{index, numero, nome}` — linha da tabela UC-08 |
| `LeafletDocument` | `lib/features/leaflet/domain/entities/leaflet_document.dart` | **Implementado 4.6 + redesign + testes** | `{entries, generatedAt}`; factory `fromCarouselItems` |
| `GenerateLeafletFromSelection` | `lib/features/leaflet/domain/usecases/generate_leaflet_from_selection.dart` | **Implementado 4.6 + redesign + testes** | UC-08 — carousel ordenado → `LeafletDocument`; [EmptyCarouselException] |
| `LeafletContentLabels` | `lib/features/leaflet/presentation/widgets/leaflet_content_labels.dart` | **Implementado redesign jun/2026** | Textos l10n resolvidos antes da captura off-screen |
| `formatLeafletHeaderDate` | `lib/features/leaflet/presentation/utils/leaflet_header_date.dart` | **Implementado redesign jun/2026** | `QUINTA-FEIRA 11/06/2026` via `leafletWeekday*` + data |
| `waitForRepaintBoundary` | `lib/features/leaflet/presentation/utils/leaflet_image_capture.dart` | **Implementado 4.6 + fix jun/2026** | Aguarda [RenderRepaintBoundary] pintável (até 10 frames); usado por [captureWidgetToPng] |
| `LeafletContent` | `lib/features/leaflet/presentation/widgets/leaflet_content.dart` | **Implementado 4.6 + redesign + fix render jun/2026** | Layout folheto; raiz `Material(transparency)` para captura off-screen sem sublinhação debug |
| `leafletActionsProvider` | `lib/features/leaflet/presentation/providers/leaflet_actions_provider.dart` | **Implementado 4.6 + redesign** | `generateAndShare` — [LeafletContentLabels] + overlay + PNG + [share_plus] |
| `leafletDebugLog` / `leafletDebugLogError` / `leafletDebugErrorSummary` | `lib/features/leaflet/presentation/utils/leaflet_debug_log.dart` | **Implementado jun/2026** | Diagnóstico UC-08 em [kDebugMode] — console + resumo na snackbar |

### `LouvorMaterialIcons` — API pública (UC-01/02 polish)

| Membro | Tipo | Descrição |
|--------|------|-----------|
| `forCategory(categoria)` | `static IconData` | Heurística `toLowerCase()` + `contains`: `cifra` → `Icons.music_note`; `gest` → `Icons.pan_tool_outlined`; demais → `Icons.piano` |

**Consumidores:** [LouvorCard], [CarouselLouvorChip] (ícone de material no chip modal/topBar).

### `findLouvorByPdfId` — API pública (UC-04/05/06/07)

| Assinatura | Retorno | Descrição |
|------------|---------|-----------|
| `findLouvorByPdfId(catalog, pdfId)` | `Louvor?` | Lookup O(n) no manifest; `null` se [catalog] nulo ou id órfão |

**Consumidores:** [ReaderCarouselActionsNotifier.navigateToPdfId] (4.7), [PlaylistsNotifier.findLouvorByPdfId] (wrapper com debug UC-06).

**Nota:** [PlaylistsNotifier.findLouvorByPdfId] é método de instância distinto — delega lookup + [playlistOpenDebugLog*].

## Agrupamento manifest (`groupId`) — implementado (jun/2026)

**Status:** **implementado no app** (agrupamento client-side); manifest remoto ainda pode omitir `groupId` (calculado via [LouvorGroupId]).  
**Especificação:** [LOUVOR_GROUPING.md](./LOUVOR_GROUPING.md)

**Problema resolvido:** cada PDF era um card; louvores com Partitura + Cifra + Gestos apareciam duplicados.

**Hierarquia UI:**

```text
[Nível 0 — card]  LouvorGroupCard (groupId)
[Nível 1 — bottom sheet]  seção por classificacao
[Nível 2 — folha]  categoria → pdfId → leitor
```

**Regra `groupId`:** `f(numero, nomeNormalizado)` — ver [LouvorGroupId.compute]. Carousel/playlists/offline continuam com `pdfId`.

**Script manifest:** `scripts/assign_louvor_group_ids.py` (`--dry-run`, `grouping-report.json`, `grouping-revisao.csv`).

### APIs implementadas — agrupamento (`groupId`)

| API | Arquivo | Estado | Descrição |
|-----|---------|--------|-----------|
| `LouvorGroup` | `catalog/domain/entities/louvor_group.dart` | **Implementado + testes** | Ver tabela domínio |
| `GroupLouvoresByMaterial` | `catalog/domain/usecases/group_louvores_by_material.dart` | **Implementado + testes** | `call(louvores)` → grupos ordenados |
| `LouvorGroupId` | `catalog/domain/utils/louvor_group_id.dart` | **Implementado + testes** | `compute`, `effective` |
| `LouvorGroupCard` | `catalog/presentation/widgets/louvor_group_card.dart` | **Implementado jun/2026** | Card Home/Biblioteca; tap → sheet ou leitor |
| `showLouvorMaterialSheet` | `catalog/presentation/widgets/louvor_material_sheet.dart` | **Implementado jun/2026** | Bottom sheet classificação → categoria |
| `openLouvorInReader` | `catalog/presentation/utils/open_louvor_in_reader.dart` | **Implementado jun/2026** | Resolve + `/leitor`; `resolveLouvorPdf`, `louvorPdfErrorMessage` |
| `homeSearchGroupResultsProvider` | `catalog/presentation/providers/home_search_provider.dart` | **Implementado jun/2026** | UC-01+02 → `List<LouvorGroup>` |
| `libraryGroupResultsProvider` | `library/presentation/providers/library_group_results_provider.dart` | **Implementado jun/2026** | UC-03 → [PaginatedLouvorGroups] |
| `SortLouvorGroups` | `library/domain/usecases/sort_louvor_groups.dart` | **Implementado jun/2026** | Ordena grupos por `numero` ou `nome` |
| `PaginateLouvorGroups` | `library/domain/usecases/paginate_louvor_groups.dart` | **Implementado jun/2026** | Paginação 10/25/50/100 de grupos |
| `PaginatedLouvorGroups` | `library/domain/entities/paginated_louvor_groups.dart` | **Implementado jun/2026** | DTO paginado de grupos |
| `assign_louvor_group_ids.py` | `scripts/` | **Implementado jun/2026** | Atribui `groupId` no JSON do manifest |
| `Louvor.groupId` / `effectiveGroupId` | `catalog/domain/entities/louvor.dart` | **Implementado jun/2026** | Campo manifest opcional + fallback calculado |

**Pendente:** publicar manifest remoto com `groupId`; persistir `groupId` em [LouvorCache] (Isar).

### `LouvorGroup` — API pública (agrupamento jun/2026)

| Membro | Tipo | Descrição |
|--------|------|-----------|
| `groupId` | `String` | Chave estável do louvor lógico |
| `numero` | `String` | Número canônico (pode ser `""`) |
| `nome` | `String` | Título canônico (prefere Partitura) |
| `sections` | `List<LouvorMaterialSection>` | Subdivisões por classificação |
| `totalMaterials` | getter `int` | Contagem de PDFs no grupo |
| `primaryLouvor` | getter `Louvor?` | Partitura ou primeiro material — atalho `+` no card |
| `fromLouvores(louvores)` | static | Agrupa, ordena seções/categorias, ordena grupos |

**Consumidores:** [GroupLouvoresByMaterial], [LouvorGroupCard], [showLouvorMaterialSheet].

### `LouvorGroupCard` — API pública (UC-01/03/04/05)

| Comportamento | Descrição |
|---------------|-----------|
| Tap | `totalMaterials == 1` → [openLouvorInReader]; senão [showLouvorMaterialSheet] |
| Trailing `+` | [PlaylistsNotifier.addLouvorToActivePlaylist] com [LouvorGroup.primaryLouvor] |
| Menu ⋮ share | Só quando grupo tem 1 material (paridade [LouvorCard]) |
| Visual | Delega a [CarouselLouvorChip] modal |

**Consumidores:** [HomeScreen], [LibraryScreen]. [LouvorCard] delega a [LouvorGroupCard] (wrapper 1 material).

### `showLouvorMaterialSheet` — API pública

| Parâmetro | Descrição |
|-----------|-----------|
| `group` | [LouvorGroup] com seções pré-montadas |
| `onMaterialSelected` | Callback com [Louvor] da categoria escolhida |

**Layout:** título `numero — nome`; seções com [LouvorClassification.materialSectionLabel]; [ListTile] por categoria com [LouvorMaterialIcons].

### `LouvorGroupId` — API pública

| Método | Descrição |
|--------|-----------|
| `compute({numero, nome})` | `numero:slug` ou `avulso:slug` |
| `effective({groupId, numero, nome})` | Manifest se preenchido; senão [compute] |

**Espelho:** `scripts/assign_louvor_group_ids.py`.

## APIs públicas — Domínio (library, Fase 1.4)

| API | Arquivo | Estado | Descrição |
|-----|---------|--------|-----------|
| `BrowseLibrary` | `lib/features/library/domain/usecases/browse_library.dart` | **Implementado + testes** | UC-03 — `call(catalog, selectedMaterials, selectedArranjos, selectedSpecialArrangements)`; compõe UC-02 + arranjo especial; sem `pesquisa` |
| `SortLouvores` | `lib/features/library/domain/usecases/sort_louvores.dart` | **Implementado + testes** | UC-03 — `call(louvores, sortBy)`; `numero` (padrão, numérico + desempate `pdfId`) ou `nome` (case-insensitive) |
| `PaginateLouvores` | `lib/features/library/domain/usecases/paginate_louvores.dart` | **Implementado + testes** | UC-03 — `call(louvores, page, itemsPerPage)`; `allowedItemsPerPage` = {10, 25, 50, 100}; inválido → 10 |
| `PaginatedLouvores` | `lib/features/library/domain/entities/paginated_louvores.dart` | **Implementado** | DTO `{items, page, itemsPerPage, totalItems, totalPages}`; página 1-based clamped |

### Contrato implementado — library domínio (UC-03, Fase 1.4)

| Assinatura | Comportamento |
|------------|---------------|
| `BrowseLibrary.call(catalog, {selectedMaterials, selectedArranjos, selectedSpecialArrangements})` | Delega [FilterByMaterialAndArranjo] + [FilterBySpecialArrangement]; `selectedMaterials` vazio → `[]` |
| `FilterBySpecialArrangement.call(louvores, selectedSpecialArrangements)` | Vazio → todos; senão match `LouvorClassification.specialArrangement(classificacao)` |
| `LouvorClassification.specialArrangement(classificacao)` | Texto entre `(` e `)`; sem parênteses → `specialArrangementPadrao` (`'Padrão'`) |
| `LouvorClassification.displayLabel(classificacao)` | Classificação base amigável — ex.: `ColCIAs` → `Coletânea CIAs`; ignora texto entre parênteses |
| `LouvorClassification.parseSpecialArrangementsFromUrl(csv)` | CSV `arranjoEspecial=` → `Set<String>`; vazio → `{}` |
| `LouvorClassification.serializeSpecialArrangementsForUrl(selected)` | Vazio → `null` (omitir param) |
| `SortLouvores.call(louvores, sortBy: 'numero' \| 'nome')` | Cópia ordenada in-memory; `sortBy` desconhecido → `numero` |
| `PaginateLouvores.call(louvores, page, itemsPerPage)` | Retorna [PaginatedLouvores]; lista vazia → página 1, `totalPages` 1 |
| `buildLibraryLocation({materiais?, arranjo?, arranjoEspecial?, ordenar, itensPorPagina, pagina})` | Omite defaults: `ordenar=numero`, `itensPorPagina=10`, `pagina=1`; encode via `Uri.encodeComponent` |
| `buildLibraryLocationFromUri(uri)` | Reconstrói location canônico para diff no sync |

**Contrato URL (Biblioteca):**

| Param | Chave | Padrão (omitido) | Exemplo |
|-------|-------|------------------|---------|
| Materiais | `materiais` | todos selecionados | `/?materiais=Partitura` |
| Arranjo base | `arranjo` | vazio (sem filtro) | `/?arranjo=ColAdultos` |
| Arranjo especial | `arranjoEspecial` | vazio (sem filtro) | `/?arranjoEspecial=Padrão,Especial` |
| Ordenação | `ordenar` | `numero` | `/?ordenar=nome` |
| Itens/página | `itensPorPagina` | `10` | `/?itensPorPagina=25` |
| Página | `pagina` | `1` | `/?pagina=2` |

### Contrato implementado — biblioteca apresentação (UC-03, Fase 1.4)

**Widgets**

| Widget | Provider observado | Comportamento |
|--------|-------------------|---------------|
| `SpecialArrangementFilters` | `libraryAvailableSpecialArrangementsProvider` + `librarySpecialArrangementProvider` | FilterChips dinâmicos; label `Padrão` via l10n `specialArrangementPadrao`; título com [AppTypography.label] |
| `LibraryViewControls` | — (filhos observam providers) | [GoldenTaggedContainer] tag `libraryViewTitle`; agrupa [LibrarySortSelector] + divisor gold + [LibraryPaginationControls] |
| `LibrarySortSelector` | `libraryViewSettingsProvider.sortBy` | `SegmentedButton` número/nome; estilo gold/title (§6) |
| `LibraryPaginationControls` | `libraryGroupResultsProvider` + `libraryViewSettingsProvider.itemsPerPage` | [LibraryResultsSummary] no topo; chip dropdown `itemsPerPageValue` (borda gold); indicador `pageIndicator`; navegação `pagePrevious`/`pageNext`; layout responsivo (breakpoint 480px) |
| `LibraryResultsSummary` | `libraryGroupResultsProvider` | Subcomponente de [LibraryPaginationControls]; texto `libraryResultsSummary(from, to, total)` ou `libraryResultsEmpty`; [AppTypography.body] centralizado |
| `LibraryScreen` | `libraryGroupResultsProvider`, `catalogFiltersProvider`, … | `ConsumerStatefulWidget`; layout `maxWidth: 896` centralizado; ordem: [CatalogRefreshBanner] → [PdfViewerSelector] → [FiltersPanel] (+ [SpecialArrangementFilters]) → [LibraryViewControls] → `SliverToBoxAdapter(SizedBox 16)` → `SliverList<LouvorGroupCard>` (gap 8px entre chips); sync URL post-frame |
| `CatalogRefreshBanner` | `catalogRefreshProvider` | [GoldenTaggedContainer] tag `catalogRefreshLabel`; mensagem + botão tonal `btnBackground`; loading inline; erro inline; `Key('catalogRefreshBanner')` no container |

**Ciclo de vida Riverpod ([LibraryScreen])**

| Método / evento | Comportamento |
|-----------------|---------------|
| `initState` → `addPostFrameCallback` | `_hydrateFromUrl()` — hidrata `catalogFiltersProvider`, `librarySpecialArrangementProvider`, `libraryViewSettingsProvider` |
| `didUpdateWidget` | Re-hidrata só se query params mudaram; post-frame |
| `_urlSyncEnabled` | Habilitado após hidratação inicial (evita `go` prematuro) |
| `ref.listen` (filtros, especial, view) | Post-frame → `buildLibraryLocation` → `goRouter.go` se diff |
| `ref.listen` (`catalogRefreshProvider`) | Transição loading→idle → `showAppSnackbar` sucesso |
| `build` | `Scaffold` → `Center` → `ConstrainedBox(maxWidth: 896)` → `CustomScrollView`; seções com gap 12px; `SliverToBoxAdapter(SizedBox 16)` entre header e lista; loading spinner gold; erro manifest via l10n `catalogLoadError` |

### Fluxo Fase 1.4 — biblioteca paginada (UC-03) + agrupamento jun/2026

```text
louvoresManifestProvider (catálogo)
  → libraryGroupResultsProvider
      → BrowseLibrary(catalog, materiais, arranjos, arranjosEspeciais)
      → GroupLouvoresByMaterial(louvores)
      → SortLouvorGroups(groups, sortBy)
      → PaginateLouvorGroups(groups, page, itemsPerPage)
  → PaginatedLouvorGroups.items → SliverList<LouvorGroupCard> (chips verticais)
      → tap 1 material → openLouvorInReader
      → tap 2+ materiais → showLouvorMaterialSheet → categoria → leitor

catalogFiltersProvider + librarySpecialArrangementProvider + libraryViewSettingsProvider
  → LibraryScreen ref.listen → buildLibraryLocation → GoRouter /biblioteca?…

appRouter /biblioteca?…
  → LibraryScreen(initialMateriais, initialArranjo, initialArranjoEspecial, …)
  → hydrateFromUrl (post-frame) + sync URL quando _urlSyncEnabled
```

**Legado:** [libraryResultsProvider] (PDFs individuais) permanece para testes; UI usa [libraryGroupResultsProvider].

**Pendente (Fase 5):** `PollManifestChecksum` (poll automático SHA-256); integração/Gherkin UC-03.

### Contrato implementado — refresh manual (UC-12, Fase 1.5)

| Assinatura | Comportamento |
|------------|---------------|
| `CatalogRepository.forceRefreshManifest()` | Fetch remoto obrigatório; `cacheManifest` em sucesso; remoto vazio → `StateError`; falha remota **sem** fallback ao cache |
| `ForceRefreshCatalog(repository)` | `call()` → `repository.forceRefreshManifest()` → `Future<List<Louvor>>` |
| `forceRefreshCatalogProvider` | `Provider<ForceRefreshCatalog>` — DI via [catalogRepositoryProvider] |
| `CatalogRefreshNotifier.refresh()` | `state = loading` → use case → `ref.invalidate(louvoresManifestProvider)` → `state = idle`; erro → `CatalogRefreshState.error` |
| `catalogRefreshProvider` | `NotifierProvider<CatalogRefreshNotifier, CatalogRefreshState>` |
| `manifestAsync.when(..., skipLoadingOnReload: true)` | Em [libraryGroupResultsProvider], [libraryResultsProvider] e [homeSearchGroupResultsProvider] / [homeSearchResultsProvider] — preserva lista durante reload |
| `CatalogRefreshBanner` | `ConsumerWidget`; [GoldenTaggedContainer] tag `catalogRefreshLabel`; `Key('catalogRefreshBanner')` no container; botão desabilitado + spinner em `isLoading` |
| `LibraryScreen` `ref.listen(catalogRefreshProvider)` | `previous?.isLoading && next.isIdle` → `showAppSnackbar(catalogRefreshSuccess)` |

### Fluxo Fase 1.5 — refresh manual catálogo (UC-12)

```text
CatalogRefreshBanner → catalogRefreshProvider.refresh()
  → ForceRefreshCatalog → CatalogRepositoryImpl.forceRefreshManifest()
      → fetch remoto obrigatório → saveLouvores (Isar)
  → ref.invalidate(louvoresManifestProvider)
  → libraryGroupResultsProvider / homeSearchGroupResultsProvider (skipLoadingOnReload: true)
  → snackbar catalogRefreshSuccess (ref.listen na LibraryScreen)
```

## APIs públicas — Domínio (pdf_opening / pdf_reader, Fase 2)

| API | Arquivo | Estado | Descrição |
|-----|---------|--------|-----------|
| `OpenPdfInReader` | `lib/features/pdf_opening/domain/usecases/open_pdf_in_reader.dart` | **Implementado + testes** | UC-04 — valida path via [OpenPdfDocument]; retorna rota `/leitor?file=&titulo=` (Fase 2.1) |
| `OpenPdfExternal` | `lib/features/pdf_opening/domain/usecases/open_pdf_external.dart` | Esqueleto | UC-04 — modos `newtab`, `online` (Fase 2.6) |
| `SharePdf` | `lib/features/pdf_opening/domain/usecases/share_pdf.dart` | **Implementado + testes** | UC-04 — remoto: bytes + temp; local ([isLocalPdfPath]): `XFile(localPath)` sem reler bytes |
| `SavePdf` | `lib/features/pdf_opening/domain/usecases/save_pdf.dart` | **Implementado + testes** | UC-04 — remoto: bytes → `saved_pdfs/`; local: `File.copy` do cache |
| `LouvorPdfPath` | `lib/features/pdf_opening/domain/utils/louvor_pdf_path.dart` | **Implementado + testes** | `fromLouvor(Louvor)` → `/assets/...`; prefixa `assets/` quando pdfId do manifest omite (produção) |
| `isLocalPdfPath` | `lib/features/pdf_opening/domain/utils/is_local_pdf_path.dart` | **Implementado + testes** | Distingue path local de remoto/asset — usado por [SharePdf] e [SavePdf] |
| `PdfFileNameSanitizer` | `lib/features/pdf_opening/domain/utils/pdf_file_name_sanitizer.dart` | **Implementado** | `sanitize(rawName)` — basename, strip chars perigosos, sufixo `.pdf` |
| `ValidatePdfAvailability` | `lib/features/pdf_opening/domain/usecases/validate_pdf_availability.dart` | **Implementado + testes** | UC-04 — `repository.lookup(pdfId) != null` sem fetch; DI via [validatePdfAvailabilityProvider] |
| `PdfFitMode` | `lib/features/pdf_reader/domain/entities/pdf_reader_preferences.dart` | **Implementado + testes** | `pageFit` / `pageWidth`; `toStorageString` / `fromStorageString`; `toggle()` |
| `PdfReaderViewSettings` | `lib/features/pdf_reader/domain/entities/pdf_reader_preferences.dart` | **Implementado** | `{fitMode}`; `defaults` = page-fit; scroll vertical fixo em [PdfxPdfView] |
| `PdfReaderControllerPort` | `lib/features/pdf_reader/domain/ports/pdf_reader_controller_port.dart` | **Implementado** | Porta domínio — navegação/zoom sem import `pdfx`; implementada por [PdfxViewerAdapter] |
| `InvalidPdfPageException` | `lib/features/pdf_reader/domain/exceptions/invalid_pdf_page_exception.dart` | **Implementado** | Página fora do intervalo em [NavigatePdfPages] |
| `NavigatePdfPages` | `lib/features/pdf_reader/domain/usecases/navigate_pdf_pages.dart` | **Implementado + testes** | UC-11 — `call(targetPage, pagesCount)`, `nextPage`, `previousPage` via [PdfReaderControllerPort] |
| `SetZoomAndFitMode` | `lib/features/pdf_reader/domain/usecases/set_zoom_and_fit_mode.dart` | **Implementado + testes** | UC-11 — `call(PdfFitMode)`; delega `applyFitMode` à porta |
| `ToggleReaderFullscreen` | `lib/features/pdf_reader/domain/usecases/toggle_reader_fullscreen.dart` | **Implementado 2.4** | UC-11 — `call()` alterna fullscreen; delega [ReaderFullscreenNotifier.toggle] |
| `ReaderFullscreenNotifier` | `lib/features/pdf_reader/presentation/providers/reader_fullscreen_provider.dart` | **Implementado 2.4** | `toggle()` / `exit()`; `SystemUiMode.immersiveSticky` ↔ `manual` |
| `readerFullscreenProvider` | idem | **Implementado 2.4** | `NotifierProvider<bool>` — estado global das barras 1–3 no leitor |
| `toggleReaderFullscreenProvider` | idem | **Implementado 2.4** | DI [ToggleReaderFullscreen] via closure do notifier |
| `CarouselReaderPosition` | `lib/features/pdf_reader/domain/entities/carousel_reader_position.dart` | **Implementado 4.7** | Posição 1-based; `previousPdfId`/`nextPdfId` `null` nas extremidades (sem wrap) |
| `NavigateCarouselInReader` | `lib/features/pdf_reader/domain/usecases/navigate_carousel_in_reader.dart` | **Implementado 4.7 + testes** | UC-11 — `getPosition`, `resolveTarget` via [CarouselRepository] (persistência Isar) |
| `readerCarouselActionsProvider` | `lib/features/pdf_reader/presentation/providers/reader_carousel_actions_provider.dart` | **Implementado 4.7** | `navigateToPdfId` → resolve + `OpenPdfInReader`; `navigateAdjacent` para lookup via repositório |
| `ReaderRouteParamsNotifier` | `lib/features/pdf_reader/presentation/providers/reader_route_params_provider.dart` | **Implementado 4.7 fix v2** | `update(queryParams)` / `clear()` — espelha visita a `/leitor` para o shell (post-frame) |
| `readerRouteParamsProvider` | idem | **Implementado 4.7 fix v3** | `NotifierProvider<Map<String, String>>` — fallback de `pdfId`/`titulo` quando URL vazia; [CarouselChips] prioriza query params do GoRouter |
| `PdfReaderScreen` | `lib/features/pdf_reader/presentation/pages/pdf_reader_screen.dart` | **Implementado 4.7 + 2.3 + 2.4** | Publica [readerRouteParamsProvider]; [PdfReaderPageIndicator] + [PdfxPdfView.navigateToPage]; `_scheduleApplyInitialFit`; botão fullscreen |
| `_ReaderScaffold` | idem | **Implementado UI 3 barras + 2.4 + indicador estável** | Barra 3 condicional; [PdfReaderPageIndicator(filePath)]; FAB `fullscreen_exit` em `Opacity(0.25)` |
| `pdfReaderDisplayedPageProvider` | `lib/features/pdf_reader/presentation/providers/pdf_reader_displayed_page_provider.dart` | **Implementado 2.3** | `NotifierProvider.autoDispose.family<int, String>` — página exibida no indicador; sync com scroll manual |
| `PdfReaderDisplayedPageNotifier` | idem | **Implementado 2.3** | `animateToPage(pageNumber)` congela indicador (`_suppressLiveUpdates`, `_animating`); escuta `pageListenable` + `loadingState`; getters `loadingState`, `pagesCount` |
| `PdfReaderPageIndicator` | `lib/features/pdf_reader/presentation/widgets/pdf_reader_page_indicator.dart` | **Implementado 2.3** | `ConsumerWidget(filePath)` — `ValueListenableBuilder` em `controller.loadingState`; texto `page/total` após `success`; long-press → `animateToPage(1)` |
| `PdfReaderNavigateToPage` | `lib/features/pdf_reader/presentation/widgets/pdfx_pdf_view.dart` | **Implementado 2.3** | `Future<void> Function(int pageNumber)` — callback injetado em [PdfxPdfView] |
| `PdfPageSwipePolicy` | `lib/features/pdf_reader/presentation/utils/pdf_page_swipe_policy.dart` | **Implementado 2.3 + testes** | UC-11 — regras de swipe horizontal sem conflitar pan/pinch do [PdfViewPinch] |
| `PdfPageSwipePolicy.canGoToNextPage(controller)` | idem | **Implementado** | Swipe RTL (próxima): permitido sem pan horizontal ou com viewport na borda direita |
| `PdfPageSwipePolicy.canGoToPreviousPage(controller)` | idem | **Implementado** | Swipe LTR (anterior): permitido sem pan horizontal ou com viewport na borda esquerda |
| `PdfPageSwipePolicy.isHorizontalSwipe(totalDelta)` | idem | **Implementado** | `true` se ≥ [kPdfPageSwipeMinDistance] e horizontal domina vertical ([kPdfPageSwipeHorizontalDominanceFactor]) |
| `kPdfPageSwipeMinDistance` | idem | **Implementado** | `48.0` — distância horizontal mínima para reconhecer swipe |
| `kPdfPageSwipeHorizontalDominanceFactor` | idem | **Implementado** | `1.2` — \|dx\| deve superar \|dy\| × fator |
| `kPdfPageSwipeEdgeTolerance` | idem | **Implementado** | `12.0` — tolerância (px) para considerar viewport encostado na borda da página |
| `readerCarouselPositionProvider` | `lib/features/pdf_reader/presentation/providers/reader_carousel_position_provider.dart` | **Implementado 4.7 + fix nav** | `Provider.family` síncrono — deriva de [carouselLouvoresProvider]; fallback [carouselFocusedIndexProvider] |

### Contrato implementado — leitor (UC-11, Fase 2.2)

| Assinatura | Comportamento |
|------------|---------------|
| `OpenPdfDocument.validateFilePath(filePath)` | Rejeita vazio, `..`, esquemas `file:`/`javascript:`/`data:`; lança [InvalidPdfPathException] |
| `PdfSourceResolver.resolve(filePath)` | `https://…` → URL; `/assets/…` → `${AppConfig.apiBaseUrl}` + path; `asset:fixtures/…` → asset Flutter; outro path absoluto → local |
| `PdfxViewerAdapter.openDocument(filePath)` | Cria [PdfControllerPinch] novo; lifecycle na sessão (sem dispose interno do anterior) |
| `PdfxViewerAdapter.bindController` / `unbindController` | Liga/desliga controller da sessão ativa para use cases de fit/navegação |
| `PdfxViewerAdapter.dispose()` | Safety net no shutdown — libera referência residual |
| `pdfReaderSessionProvider(filePath)` | `FutureProvider.autoDispose.family` — valida + abre sessão; `ref.onDispose` → `unbind` + `controller.dispose()` |
| `PdfReaderScreen(queryParams)` | Lê `file`/`pdfId`/`titulo`; publica [readerRouteParamsProvider]; [_ReaderScaffold] + [PdfxPdfView]; carousel na barra 2 via [ShellScaffold] |

**Rota:** [RoutePaths.reader] (`/leitor`) — filha do [ShellRoute]; barras 1–2 compartilhadas.

**Teste manual:** `/leitor?file=asset:fixtures/sample.pdf&titulo=Fixture`

### Referência — APIs Fase 2.2 (UC-11)

**Validação (domínio)**

| Assinatura | Comportamento |
|------------|---------------|
| `OpenPdfDocument.validateFilePath(filePath)` | Rejeita vazio, `..`, esquemas `file:`/`javascript:`/`data:` → [InvalidPdfPathException] |

**Resolução e abertura (data)**

| API | Métodos principais |
|-----|-------------------|
| `PdfSourceResolver` | `resolve(filePath)`, `assetPrefix` (`asset:`) |
| `ResolvedPdfSource` | `kind` ([PdfSourceKind]), `value` (URL, asset path ou filesystem) |
| `PdfxViewerAdapter` | `openDocument(filePath)` → [PdfControllerPinch] novo; `bindController`/`unbindController`; getter `controller`; `dispose()` residual |

**Providers e UI (presentation)**

| API | Tipo | Responsabilidade |
|-----|------|------------------|
| `pdfxViewerAdapterProvider` | `Provider` | DI factory [PdfxViewerAdapter]; dispose residual no shutdown |
| `openPdfDocumentProvider` | `Provider` | DI [OpenPdfDocument] |
| `pdfReaderSessionProvider` | `FutureProvider.autoDispose.family` | Valida + abre sessão por `filePath`; dispose do controller ao sair do leitor |
| `PdfReaderSession` | classe | `controller` + `filePath` |
| `pdfReaderErrorMessage(error)` | função | Mensagem amigável na UI; exceções offline (3.4) + [InvalidPdfPathException] |
| `PdfxPdfView` | widget | Encapsula `PdfViewPinch`; swipe via [Listener] + [PdfPageSwipePolicy]; exige [PdfReaderNavigateToPage]; `scrollDirection: Axis.vertical` fixo; `ValueKey(controller)` |

### Contrato implementado — leitor (UC-11, Fase 2.3)

| Assinatura | Comportamento |
|------------|---------------|
| `NavigatePdfPages.call(targetPage, pagesCount)` | Valida `[1, pagesCount]`; lança [InvalidPdfPageException]; delega `goToPage` |
| `NavigatePdfPages.nextPage(pagesCount)` / `previousPage()` | No-op nos limites; delega à porta |
| `SetZoomAndFitMode.call(PdfFitMode mode)` | `page-width` → `calculatePageFitMatrix`; `page-fit` → matrix por altura |
| `ReaderPreferencesDatasource.loadSettings()` | Retorna [PdfReaderViewSettings] com defaults PWA (`fitMode` only) |
| `ReaderPreferencesDatasource.saveFitMode` | Persiste [StorageKeys.pdfPreferredFitMode] via SharedPreferences |
| `PdfxViewerAdapter` (implements [PdfReaderControllerPort]) | `goToPage`, `nextPage`, `previousPage`, `applyFitMode`, `currentPage`, `pagesCount` |
| `PdfReaderViewSettingsNotifier.applyInitialFit()` | Reaplica fit salvo no adapter ativo (`SetZoomAndFitMode`) |
| `PdfReaderViewSettingsNotifier.toggleFitMode()` | Persiste + reaplica fit no adapter ativo |
| `PdfxPdfView(controller, navigateToPage)` | Swipe chama `navigateToPage(target)` — tipicamente [PdfReaderDisplayedPageNotifier.animateToPage] |
| `PdfxPdfView` — swipe horizontal | Direita→esquerda: próxima; esquerda→direita: anterior; reconhecido **somente** em `onPointerUp`; alvo = `pageAtPointerDown ± 1`; `_pageTurnInProgress` bloqueia gestos durante animação; pinch (2+ pointers) cancela rastreamento |
| `PdfReaderDisplayedPageNotifier.animateToPage` | `_suppressLiveUpdates` + `_animating` durante `PdfControllerPinch.animateToPage` (500ms default); `state` = destino só no `finally`; scroll manual fora de animação atualiza via `pageListenable`; sync inicial via listener em `loadingState` |
| `PdfReaderPageIndicator(filePath)` | `ValueListenableBuilder` em `session.controller.loadingState` → texto após `success`; `ref.watch(pdfReaderDisplayedPageProvider)`; long-press → `animateToPage(1)`; oculto enquanto sessão/ PDF carregam |
| `PdfPageSwipePolicy.canGoToNextPage` | Swipe RTL permitido se documento carregado e (sem pan horizontal OU borda direita da página) |
| `PdfPageSwipePolicy.canGoToPreviousPage` | Swipe LTR permitido se documento carregado e (sem pan horizontal OU borda esquerda da página) |
| `PdfReaderScreen` (ConsumerStatefulWidget) | Barra 3: share/save/fullscreen; [PdfReaderPageIndicator]; [PdfxPdfView] com `navigateToPage`; `_scheduleApplyInitialFit` pós-frame; carousel na barra 2 via shell |
| `_ReaderScaffold` — indicador de página | [PdfReaderPageIndicator] substitui [PdfPageNumber] do PDFx — evita flicker de páginas intermediárias na animação |

**Gatilhos UI navegação:** swipe horizontal no PDF (RTL próxima / LTR anterior, ao soltar dedo); long-press no texto `page/total` → primeira página via [PdfReaderDisplayedPageNotifier]; indicador **não** pisca durante animação.

**Prefs:** [StorageKeys.pdfPreferredFitMode] — restaurada ao abrir `/leitor` (fit aplicado em `_scheduleApplyInitialFit`; toggle fit removido da barra 3 em 2.4). Chave legada `pdfNavigationMode` ignorada.

**Teste manual:** ao abrir leitor, indicador `1/N` aparece após PDF carregar (não fica vazio com slot reservado); swipe RTL `1/3` → indicador permanece `1/3` durante animação → `2/3` ao final; swipe LTR volta; long-press `3/3` → `1/3` sem flicker; scroll manual atualiza indicador em tempo real; pinch; zoomado — pan horizontal nas bordes.

### Contrato implementado — lifecycle leitor (UC-11)

| Assinatura | Comportamento |
|------------|---------------|
| `pdfReaderSessionProvider(filePath)` | `autoDispose.family` — nova sessão a cada `watch`; sem cache de controller entre visitas |
| `PdfxViewerAdapter.openDocument(filePath)` | Retorna [PdfControllerPinch] novo; **não** dispose do controller anterior |
| `PdfxViewerAdapter.bindController(controller)` | Registra controller ativo para use cases de fit/navegação |
| `PdfxViewerAdapter.unbindController(controller)` | Limpa referência se `identical`; idempotente |
| `PdfxPdfView(controller)` | `ValueKey(controller)` — `initState` limpo no PDFx por sessão |
| `PdfReaderScreen._scheduleApplyInitialFit` | Pós-frame: `mounted` + sessão ativa (`identical` controller) + `loadingState == success` → `applyInitialFit()` |
| `PdfReaderScreen` `ref.listen(readerFullscreenProvider)` | Ao alternar fullscreen → `_scheduleApplyInitialFit` (viewport mudou de tamanho) |
| `_ReaderScaffold` layout PDF | PDF **sempre** em `Column → Expanded → Stack → Positioned.fill` — nunca `Stack` solto no root |

**Motivação:** PDFx `_attach` não recarrega documento quando `_document != null` — reutilizar controller causa canvas vazio. Mudança de constraints (fullscreen) exige `Expanded` estável + reaplicar fit pós-frame.

**Teste manual:** abrir PDF → voltar → reabrir o mesmo PDF 3–5×; sem erro "used after dispose". Fullscreen: PDF permanece visível ao entrar/sair.

### Contrato implementado — share/save (UC-04, Fase 2.5 + 3.4)

| Assinatura | Comportamento |
|------------|---------------|
| `isLocalPdfPath(filePath)` | `true` = filesystem local (`plpcg_pdfs/`); `false` = `http(s)`, `asset:`, `/assets/…` |
| `PdfBytesDatasource.fetchBytes(filePath)` | Resolve via [PdfSourceResolver]; remoto → Dio bytes; asset → rootBundle; local → `readAsBytes` |
| `SharePdf.call({required filePath, displayName?})` | Valida path; **local** → `Share.shareXFiles([XFile(localPath)])` sem fetch; **remoto** → bytes + temp + share |
| `SavePdf.call({required filePath, fileName?})` | Valida path; **local** → `File.copy` → `saved_pdfs/`; **remoto** → fetch bytes + `writeAsBytes` |
| `LouvorPdfPath.fromLouvor(louvor)` | `getPdfRelPath(pdfId)`; prefixa `assets/` se ausente; retorna `/$relPath` para [ResolvePdfForReader] |
| `PdfFileNameSanitizer.sanitize(rawName)` | Basename, remove chars perigosos; garante `.pdf` |
| `PdfViewerMode` / `pdfViewerModeProvider` | Enum `leitor`/`newtab`/`online`/`share`/`save`; persiste [StorageKeys.pdfViewerMode] |
| `LouvorCard` (tap) | [CarouselLouvorChip] `onTap` → [resolvePdfForReaderProvider] → leitor; [loading] no trailing; erros tipados |
| `LouvorCard` (menu ⋮) | [CarouselLouvorChip] `onShare` → [PopupMenuButton] item [sharePdf]; [LouvorCard._handleShare] → [sharePdfProvider] com `sharePositionOrigin`; [shareLoading] no ícone ⋮ |
| `PdfReaderScreen` toolbar (barra 3) | `AppBar(primary: false)` — share/save com path local; ícones brancos via `appBarTheme`; fast path 3.4 quando cacheado |

**Dependências:** `share_plus`, `path_provider` (pubspec).

**Teste manual:** 1º tap baixa; 2º tap instantâneo; share/save sem re-download; modo avião só PDFs cacheados.

### Contrato implementado — abrir leitor (UC-04, Fase 2.1 + 3.4)

| Assinatura | Comportamento |
|------------|---------------|
| `buildReaderLocation({required file, pdfId?, titulo?, subtitulo?})` | Retorna `/leitor?file=…&pdfId=…&titulo=…`; encode via `Uri.encodeComponent` |
| `OpenPdfInReader.call({required pdfPath, pdfId?, titulo?, subtitulo?})` | Valida path; monta rota — **3.4:** `pdfPath` = path absoluto local pós-resolve; **4.7:** `pdfId` habilita navegação carousel |
| `openPdfInReaderProvider` | DI [OpenPdfInReader] + [OpenPdfDocument] |
| `LouvorCard` (modo `leitor`) | [ResolvePdfForReader] → `openPdfInReaderProvider.call(absolutePath, pdfId)` → `context.push` |
| `pdfReaderSessionProvider(filePath)` | [PdfxViewerAdapter.openDocument] → `PdfDocument.openFile` quando path local |
| `PdfViewerMode.leitor` | Modo padrão; persiste [StorageKeys.pdfViewerMode] |

**Teste manual:** tap card → loading → `/leitor?file=/…/plpcg_pdfs/…` → PDFx `openFile` (sem Dio no adapter).

### Contrato implementado — fullscreen leitor (UC-11, Fase 2.4)

| Assinatura | Comportamento |
|------------|---------------|
| `ToggleReaderFullscreen.call()` | Alterna modo fullscreen via [ReaderFullscreenNotifier.toggle] |
| `ReaderFullscreenNotifier.toggle()` | Inverte `state`; entra → `SystemUiMode.immersiveSticky`; sai → `SystemUiMode.manual` + `SystemUiOverlay.values` |
| `ReaderFullscreenNotifier.exit()` | Idempotente se já `false`; restaura overlays do sistema |
| `readerFullscreenProvider` | `NotifierProvider<bool>` — `false` fora do fullscreen |
| `toggleReaderFullscreenProvider` | DI [ToggleReaderFullscreen] — injeta closure do notifier |
| `ShellScaffold` | `hideChrome = isReader && isFullscreen` — oculta [PlpcgPrimaryAppBar] e [CarouselChips]; `Expanded(child)` preservado; `exit()` post-frame ao sair de `/leitor` |
| `_ReaderScaffold` | Barra 3: `Icons.fullscreen` → entra; FAB `Icons.fullscreen_exit` em `Opacity(0.25)` → sai; PDF em `Positioned.fill` dentro de `Expanded` |
| `PdfReaderScreen` | `ref.listen(readerFullscreenProvider)` → `_scheduleApplyInitialFit` após toggle |

**Gatilho UI:** botão `fullscreen` na barra 3 (substitui toggle fit `Icons.fit_screen` da barra 3). Long-press centro permanece não implementado.

**Teste manual:** entrar fullscreen → barras 1–3 somem, PDF ocupa tela, FAB semitransparente (`Opacity(0.25)`); sair → barras e PDF normais sem canvas vazio.

## APIs públicas — offline (Fase 3 — local-first)

Arquitetura replanejada no [MVP Roadmap § Fase 3](../MVP%20Roadmap.md): store nativo no filesystem + índice Isar; leitor resolve **local-first** e faz cache on-demand. A flag PWA [StorageKeys.offlineAvailable] (`TRUE`/`FALSE`) **só** gateia a UI de [OfflineSettingsScreen] (UC-09 bulk vs UC-10 manutenção) — **não** bloqueia abertura de PDF ([offlineCacheStatusProvider] / [ResolvePdfForReader] local-first).

### Data layer (3.1 ✅)

| API | Arquivo | Estado | Descrição |
|-----|---------|--------|-----------|
| `GetApplicationDocumentsDirectoryFn` | `lib/features/offline/data/datasources/pdf_local_store.dart` | **Implementado 3.1** | Typedef injetável para testes — simula `ApplicationDocumentsDirectory` |
| `OfflineAvailableStore` | `lib/features/offline/data/datasources/offline_available_store.dart` | **Implementado jun/2026 + testes** | UC-09/10 — persiste [StorageKeys.offlineAvailable]: `TRUE` (bulk concluído), `FALSE` (cache limpo); `isConfigured`, `isExplicitlyDisabled` |
| `PdfLocalStore` | `lib/features/offline/data/datasources/pdf_local_store.dart` | **Implementado 3.1 + testes** | Root `documents/plpcg_pdfs/`; `writeAtomic`, `exists`, `delete`, `deleteTree`, `listOrphans` |
| `OfflinePdfLocalDatasource` | `lib/features/offline/data/datasources/offline_pdf_local_datasource.dart` | **Implementado 3.1** | `findByPdfId`, `put`, `deleteByPdfId`, `countByCategory`, `findAll` — txn Isar |
| `OfflinePdfRepository` | `lib/features/offline/domain/repositories/offline_pdf_repository.dart` | **Implementado 3.1** | Contrato domínio — ver § contrato 3.1 |
| `OfflinePdfRepositoryImpl` | `lib/features/offline/data/repositories/offline_pdf_repository_impl.dart` | **Implementado 3.1 + testes** | Orquestra store + Isar; `relPath` via `getPdfRelPath` sem prefixo `assets/` |

### Domínio — entidades e resolver (3.1 ✅ / 3.2 ✅ / 3.3 ✅ / 3.4 ✅)

| API | Arquivo | Estado | Descrição |
|-----|---------|--------|-----------|
| `OfflinePdfEntry` | `lib/features/offline/domain/entities/offline_pdf_entry.dart` | **Implementado 3.1** | `{pdfId, absolutePath, category, fileSize, downloadedAt}` — registro válido no índice |
| `LocalPdfSource` | `lib/features/offline/domain/entities/local_pdf_source.dart` | **Implementado 3.2** | `{pdfId, absolutePath, fromCache}` — resultado do resolver |
| `PdfExternallyDeletedException` | `lib/features/offline/domain/exceptions/pdf_resolve_exceptions.dart` | **Implementado 3.2** | Índice órfão + fetch offline; `canRetryWhenOnline` para CTA 3.4 |
| `PdfOfflineUnavailableException` | `lib/features/offline/domain/exceptions/pdf_resolve_exceptions.dart` | **Implementado 3.2** | Nunca cacheado + fetch offline |
| `PdfFetchFailedException` | `lib/features/offline/domain/exceptions/pdf_resolve_exceptions.dart` | **Implementado 3.2** | Fetch falhou (HTTP/erro não-rede) |
| `ResolvePdfForReader` | `lib/features/offline/domain/usecases/resolve_pdf_for_reader.dart` | **Implementado 3.2 + testes** | Hit: path absoluto + stat; miss → [FetchAndStorePdf]; falha rede → exceção tipada (órfão vs ausente) |
| `FetchAndStorePdf` | `lib/features/offline/domain/usecases/fetch_and_store_pdf.dart` | **Implementado 3.3 + testes** | HTTP via [PdfBytesDatasource] → [OfflinePdfRepository.upsert]; retry [OfflineConfig.maxRetryAttempts]; `category` derivável de `getPdfRelPath` |
| `ValidatePdfAvailability` | `lib/features/pdf_opening/domain/usecases/validate_pdf_availability.dart` | **Implementado 3.4 + testes** | UC-04 — `call(pdfId)` → `repository.lookup` (sem fetch) |

### Domínio — bulk e manutenção (3.5 ✅ / 3.6 ✅)

| API | Arquivo | Estado | Descrição |
|-----|---------|--------|-----------|
| `DownloadOfflinePackages` | `lib/features/offline/domain/usecases/download_offline_packages.dart` | **Implementado 3.5 + testes** | UC-09 — fila por categoria; `disk_space_plus`; checkpoint SharedPreferences; cancel Dio |
| `ExtractAndStorePdfs` | `lib/features/offline/domain/usecases/extract_and_store_pdfs.dart` | **Implementado 3.5 + testes** | UC-09 — `compute(extractZipPdfs)`; chunks 75 Isar; skip cache hit; remove ZIP após extração |
| `ReconcileOfflineIndex` | `lib/features/offline/domain/usecases/reconcile_offline_index.dart` | **Implementado 3.6 + testes + benchmark** | Global isolate/chunked `< 20s/5000`; escopo pós-bulk preservado |
| `OfflineMaterialResolver` | `lib/features/offline/domain/utils/offline_material_resolver.dart` | **Implementado jun/2026** | UC-10 — `toUiMaterial(categoria)` → chip UI (`Partitura`, `Cifra`, `Gestos em Gravura`); expande Cifra nível I/II |
| `GetOfflineStatsByCategory` | `lib/features/offline/domain/usecases/get_offline_stats_by_category.dart` | **Implementado 3.6 + jun/2026** | UC-10 — baixados por material (índice + [CatalogLocalDatasource]); faltantes via manifest remoto → [OfflineStats] |
| `DownloadMissingPdfs` | `lib/features/offline/domain/usecases/download_missing_pdfs.dart` | **Implementado 3.6 + jun/2026** | UC-10 — pré-filtra faltantes (índice + arquivo válido); fetch **somente** misses; progresso `done/total` = faltantes |
| `ClearOfflineCache` | `lib/features/offline/domain/usecases/clear_offline_cache.dart` | **Implementado 3.6 + jun/2026 + testes** | UC-10 — clear Isar + deleteTree + checkpoint + `OFFLINE_AVAILABLE=FALSE` |
| `MigrateOfflineStorage` | `lib/features/offline/domain/usecases/migrate_offline_storage.dart` | **Implementado 3.6 + testes** | UC-10 — v1 no-op; versão em [StorageKeys.offlineStorageVersion] |
| `OfflineStats` | `lib/features/offline/domain/entities/offline_stats.dart` | **Implementado 3.6 + jun/2026** | `{byCategory, missingByCategory}` + `totalCount` / `totalMissing` — chaves = material UI |
| `ReconcileResult` | `lib/features/offline/domain/entities/reconcile_result.dart` | **Implementado 3.5 + 3.6** | `{removedFromIndex, orphanFiles}` — retorno de [ReconcileOfflineIndex] |
| `DownloadMissingResult` | `lib/features/offline/domain/usecases/download_missing_pdfs.dart` | **Implementado 3.6** | `{downloadedCount, skippedCount, failedCount}` — retorno de [DownloadMissingPdfs] |
| `ReconcilePathEntry` | `lib/features/offline/data/utils/reconcile_path_validator.dart` | **Implementado 3.6** | Entrada serializável para validação de paths em isolate |
| `validatePdfPathsChunk` | `lib/features/offline/data/utils/reconcile_path_validator.dart` | **Implementado 3.6** | Top-level para [compute] — `existsSync` + `lengthSync > 0` por chunk |
| `ReconcilePathValidationResult` | `lib/features/offline/data/utils/reconcile_path_validator.dart` | **Implementado 3.6** | `{invalidPdfIds, validAbsolutePaths}` — retorno do isolate |

### Providers (3.1 ✅ / 3.2 ✅ / 3.3 ✅ / 3.4 ✅ / 3.5 ✅ / 3.6 ✅)

| API | Arquivo | Estado | Descrição |
|-----|---------|--------|-----------|
| `pdfLocalStoreProvider` | `lib/features/offline/data/providers/offline_providers.dart` | **Implementado 3.1** | DI [PdfLocalStore] via `path_provider` |
| `offlinePdfLocalDatasourceProvider` | `lib/features/offline/data/providers/offline_providers.dart` | **Implementado 3.1** | DI [OfflinePdfLocalDatasource] via [isarProvider] |
| `offlinePdfRepositoryProvider` | `lib/features/offline/data/providers/offline_providers.dart` | **Implementado 3.1** | DI [OfflinePdfRepositoryImpl] |
| `resolvePdfForReaderProvider` | `lib/features/offline/data/providers/offline_providers.dart` | **Implementado 3.2 + 3.3 + 3.4** | DI [ResolvePdfForReader] — consumido por [LouvorCard] |
| `fetchAndStorePdfProvider` | `lib/features/offline/data/providers/offline_providers.dart` | **Implementado 3.3** | DI [FetchAndStorePdf] + [PdfBytesDatasource] + [offlinePdfRepositoryProvider] |
| `validatePdfAvailabilityProvider` | `lib/features/offline/data/providers/offline_providers.dart` | **Implementado 3.4** | DI [ValidatePdfAvailability] — provider em offline para evitar ciclo DI |
| `offlineCacheStatusProvider` | `lib/features/offline/presentation/providers/offline_cache_status_provider.dart` | **Implementado 3.7 + jun/2026** | [OfflineCacheStatus]; `refresh` / `refreshAll`; stats por material + faltantes |
| `offlineMissingDownloadProvider` | `lib/features/offline/presentation/providers/offline_missing_download_provider.dart` | **Implementado 3.7 + jun/2026** | Notifier [DownloadMissingPdfs]; progresso sobre faltantes |
| `offlineManifestRemoteDatasourceProvider` | `lib/features/offline/data/providers/offline_providers.dart` | **Implementado 3.5** | DI manifest `/offline-manifest.json` |
| `diskSpaceCheckerProvider` | `lib/features/offline/data/providers/offline_providers.dart` | **Implementado 3.5** | DI `disk_space_plus` |
| `zipPackageDownloaderProvider` | `lib/features/offline/data/providers/offline_providers.dart` | **Implementado 3.5** | DI ZIP transitório `_bulk_zips/` |
| `offlineBulkCheckpointStoreProvider` | `lib/features/offline/data/providers/offline_providers.dart` | **Implementado 3.5** | DI checkpoint JSON [StorageKeys.offlineBulkCheckpoint] |
| `offlineAvailableStoreProvider` | `lib/features/offline/data/providers/offline_providers.dart` | **Implementado jun/2026** | DI [OfflineAvailableStore] via [sharedPreferencesProvider] |
| `extractAndStorePdfsProvider` | `lib/features/offline/data/providers/offline_providers.dart` | **Implementado 3.5** | DI [ExtractAndStorePdfs] |
| `reconcileOfflineIndexProvider` | `lib/features/offline/data/providers/offline_providers.dart` | **Implementado 3.5 + 3.6** | DI [ReconcileOfflineIndex] — escopo pós-bulk ou global (isolate/chunked) |
| `downloadOfflinePackagesProvider` | `lib/features/offline/data/providers/offline_providers.dart` | **Implementado 3.5** | DI orquestrador bulk UC-09 |
| `offlineBulkDownloadProvider` | `lib/features/offline/presentation/providers/offline_bulk_download_provider.dart` | **Implementado 3.5 + 3.7 + jun/2026** | Notifier progresso/cancel/resume; ao concluir → [offlineModeProvider.markConfigured] + refresh [offlineCacheStatusProvider] |
| `offlineModeProvider` | `lib/features/offline/presentation/providers/offline_mode_provider.dart` | **Implementado jun/2026** | `bool` — gate UI UC-09 vs UC-10; migração automática se `validCount ≥ 200` e flag ausente; bloqueia re-inferência quando `FALSE` |
| `offlineReconcileProvider` | `lib/features/offline/presentation/providers/offline_reconcile_provider.dart` | **Implementado 3.6** | [MigrateOfflineStorage] → [ReconcileOfflineIndex]; debounce foreground; [OfflineSettingsScreen] init |
| `getOfflineStatsByCategoryProvider` | `lib/features/offline/data/providers/offline_providers.dart` | **Implementado 3.6 + jun/2026** | DI [GetOfflineStatsByCategory] + [catalogLocalDatasourceProvider] + manifest |
| `downloadMissingPdfsProvider` | `lib/features/offline/data/providers/offline_providers.dart` | **Implementado 3.6** | DI [DownloadMissingPdfs] |
| `clearOfflineCacheProvider` | `lib/features/offline/data/providers/offline_providers.dart` | **Implementado 3.6** | DI [ClearOfflineCache] |
| `migrateOfflineStorageProvider` | `lib/features/offline/data/providers/offline_providers.dart` | **Implementado 3.6** | DI [MigrateOfflineStorage] |

### Apresentação (3.5 UI mínima → 3.7 completa ✅)

| API | Arquivo | UC | Estado | Descrição |
|-----|---------|-----|--------|-----------|
| `OfflineCacheStatus` | `offline/presentation/providers/offline_cache_status_provider.dart` | UC-10 | **Implementado 3.7 + jun/2026** | `{stats, removedCount, isRefreshing}`; `isReady`, `showRemovedWarning`; stats por material + faltantes |
| `OfflineMissingDownloadState` | `offline/presentation/providers/offline_missing_download_provider.dart` | UC-10 | **Implementado 3.7 + jun/2026** | `{status, done, total, lastResult}` — `total` = **faltantes** (não manifest completo) |
| `OfflineSettingsScreen` | `offline/presentation/pages/offline_settings_screen.dart` | UC-09/10 | **Completa 3.7 + jun/2026** | **Um card por vez** via [offlineModeProvider]: UC-09 (categorias + bulk) ou UC-10 (stats + faltantes + limpar cache); bulk em execução força card UC-09 |
| `OfflineLifecycleListener` | `offline/presentation/widgets/offline_lifecycle_listener.dart` | UC-10 | **Implementado 3.6** | Wrapper no shell; reconcile debounced ao foreground |
| `OfflineReconcileState` | `offline/presentation/providers/offline_reconcile_provider.dart` | UC-10 | **Implementado 3.6** | `{lastResult, lastRunAt, isRunning}` |

### Contrato implementado — Fase 3.1 (storage)

| Assinatura | Comportamento |
|------------|---------------|
| `PdfLocalStore({getApplicationDocumentsDirectory?})` | DI opcional para testes; produção usa `path_provider.getApplicationDocumentsDirectory` |
| `PdfLocalStore.rootDirectory` → `Future<Directory>` | `{docs}/plpcg_pdfs/` — cria se ausente; **proibido** cache/temp |
| `PdfLocalStore.writeAtomic(bytes, relPath)` → `Future<String>` | Grava `{root}/{relPath}.tmp` → `rename`; retorna path absoluto; limpa `.tmp` em falha |
| `PdfLocalStore.exists(absolutePath)` → `Future<bool>` | `File.exists` |
| `PdfLocalStore.delete(absolutePath)` → `Future<void>` | Idempotente |
| `PdfLocalStore.listOrphans(indexedAbsolutePaths)` → `Future<List<String>>` | Walk recursivo; PDFs no disco fora do set indexado |
| `OfflinePdfLocalDatasource.findByPdfId(pdfId)` | `filter().pdfIdEqualTo` — O(1) |
| `OfflinePdfLocalDatasource.put(index)` | `putByPdfId` em txn |
| `OfflinePdfRepository.lookup(pdfId)` → `Future<OfflinePdfEntry?>` | Isar hit + `File.exists` + `length > 0`; miss ou inválido → `null` (índice órfão permanece até reconcile 3.6) |
| `OfflinePdfRepository.findIndexEntry(pdfId)` → `Future<OfflinePdfEntry?>` | Isar hit **sem** validar disco — detecta órfãos para [ResolvePdfForReader] (3.2) |
| `OfflinePdfRepository.upsert({pdfId, bytes, category})` → `Future<OfflinePdfEntry>` | `writeAtomic` + upsert Isar com `fileSize` e `downloadedAt` |
| `OfflinePdfRepository.remove(pdfId)` → `Future<void>` | Delete disco + índice |
| `OfflinePdfRepository.countByCategory()` → `Future<Map<String,int>>` | Agregação Isar — sem scan disco |
| `OfflinePdfRepository.listAll()` → `Future<List<OfflinePdfEntry>>` | Todos os registros do índice (sem validar disco) |
| `offlinePdfRepositoryProvider` | Ponto de entrada DI para use cases 3.2+ |

**Layout de path:** disco `{docs}/plpcg_pdfs/{relPath}` onde `relPath = getPdfRelPath(pdfId)` sem `assets/`; Isar `storagePath` = path absoluto.

### Fluxo implementado Fase 3.1–3.3 — persistência on-demand

```text
FetchAndStorePdf (3.3) ✅ / bulk (3.5)
  → PdfBytesDatasource.fetchBytes(remotePath) [retry maxRetryAttempts]
  → OfflinePdfRepository.upsert(pdfId, bytes, category)
      → relPath = PdfPathNormalizer.getPdfRelPath(pdfId) [strip assets/]
      → PdfLocalStore.writeAtomic(bytes, relPath)
      → OfflinePdfLocalDatasource.put(OfflinePdfIndex)
  → LocalPdfSource(fromCache: false)

ResolvePdfForReader (3.2) ✅
  → OfflinePdfRepository.lookup(pdfId)
      → hit: LocalPdfSource(fromCache: true)
      → miss: findIndexEntry → FetchAndStorePdf ou exceção tipada
```

### Contrato implementado — Fase 3.2 (resolver)

| Assinatura | Comportamento |
|------------|---------------|
| `ResolvePdfForReader.call({required pdfId, required remotePath})` | Hit → [LocalPdfSource] `fromCache: true`; miss → delega [FetchAndStorePdf]; `DioException` rede + órfão → [PdfExternallyDeletedException]; rede + sem índice → [PdfOfflineUnavailableException]; HTTP/outros → [PdfFetchFailedException] |
| `LocalPdfSource` | `{pdfId, absolutePath, fromCache}` — resultado para leitor (3.4) |
| `OfflinePdfRepository.findIndexEntry(pdfId)` | Índice Isar sem stat disco — distingue órfão de nunca cacheado |
| `resolvePdfForReaderProvider` | Injeta repositório + [fetchAndStorePdfProvider] |

### Contrato implementado — Fase 3.3 (fetch on-demand)

| Assinatura | Comportamento |
|------------|---------------|
| `FetchAndStorePdf({PdfBytesDatasource, OfflinePdfRepository})` | Construtor injetável — DI via [fetchAndStorePdfProvider] |
| `FetchAndStorePdf.call({required pdfId, required remotePath, category?})` | `fetchBytes` com retry → `upsert` → [LocalPdfSource] `fromCache: false` |
| `_resolveCategory(pdfId)` | Primeiro segmento de `getPdfRelPath` (strip `assets/`); fallback = path inteiro |
| Retry | Até [OfflineConfig.maxRetryAttempts]; backoff linear [OfflineConfig.retryBackoffBase] × attempt; retentável: erros de rede + HTTP ≥ 500; 4xx falha imediata |
| `fetchAndStorePdfProvider` | [PdfBytesDatasource] + [offlinePdfRepositoryProvider] |

### Contrato implementado — integração leitor (Fase 3.4)

| API | Arquivo | Assinatura / comportamento |
|-----|---------|---------------------------|
| `isLocalPdfPath` | `pdf_opening/domain/utils/is_local_pdf_path.dart` | `bool isLocalPdfPath(String filePath)` — classifica path local vs remoto/asset |
| `ValidatePdfAvailability` | `pdf_opening/domain/usecases/validate_pdf_availability.dart` | `Future<bool> call({required pdfId})` → `repository.lookup != null`; sem fetch |
| `validatePdfAvailabilityProvider` | `offline/data/providers/offline_providers.dart` | DI — provider em offline (evita ciclo com `pdf_opening_providers`) |
| `LouvorCard._resolvePdf()` | `catalog/presentation/widgets/louvor_card.dart` | `ResolvePdfForReader(pdfId, LouvorPdfPath.fromLouvor)` antes de leitor ou share |
| `LouvorCard._handleShare(sharePositionOrigin)` | idem | Resolve PDF → [sharePdfProvider](`absolutePath`, `displayName: nome`, `sharePositionOrigin`); snackbar [pdfShareSuccess] \| erros tipados; desabilitado durante `_loading` |
| `OpenPdfInReader.call` | `pdf_opening/domain/usecases/open_pdf_in_reader.dart` | `pdfPath` = path absoluto local pós-resolve → `/leitor?file=` |
| `SharePdf.call` | `pdf_opening/domain/usecases/share_pdf.dart` | Path local → `XFile` direto; remoto → fluxo 2.5 |
| `SavePdf.call` | `pdf_opening/domain/usecases/save_pdf.dart` | Path local → `File.copy`; remoto → fluxo 2.5 |
| `pdfReaderErrorMessage` | `pdf_reader/presentation/providers/pdf_reader_document_provider.dart` | Exceções offline + [InvalidPdfPathException] → mensagem UI |

### Contrato implementado — Fase 3.5 (bulk UC-09)

| Assinatura | Comportamento |
|------------|---------------|
| `DownloadOfflinePackages.call({categories, onProgress, cancelToken})` | Check [DiskSpaceChecker]; fila por categoria; checkpoint [StorageKeys.offlineBulkCheckpoint]; cancel via Dio |
| `ExtractAndStorePdfs.call({zipPath, materialCategory, resumeCheckpoint?, onProgress})` | `compute(extractZipPdfs)`; chunks [OfflineConfig.bulkIsarChunkSize] Isar; skip cache hit; remove ZIP após extração |
| `ReconcileOfflineIndex.call({materialPackage?, materialCategory?})` | Escopo pós-categoria quando params presentes; global quando omitidos |
| `offlineBulkDownloadProvider` | Notifier: start/cancel/resume; progresso [OfflineDownloadProgress]; ao concluir → [offlineModeProvider.markConfigured] (`OFFLINE_AVAILABLE=TRUE`); snackbars via [OfflineSettingsScreen] |

### Contrato implementado — Fase 3.6 (manutenção UC-10)

| Assinatura | Comportamento |
|------------|---------------|
| `ReconcileOfflineIndex.call()` (global) | Idempotente; validação disco em isolate via [compute]; chunks [OfflineConfig.bulkIsarChunkSize]; **< 20s / 5000 entradas**; remove órfãos índice + opcional orphan files |
| `GetOfflineStatsByCategory.call({includeMissing = true})` | Índice Isar + [CatalogLocalDatasource.loadPdfIdToCategoriaMap] → [OfflineMaterialResolver.toUiMaterial] → `byCategory`; manifest remoto → `missingByCategory`; falha rede em faltantes → mapa vazio |
| `OfflineMaterialResolver.toUiMaterial(categoria)` | `Partitura` / `Gestos em Gravura` direto; `Cifra` + níveis I/II → chip `Cifra`; classificação (`ColAdultos`) → `null` |
| `DownloadMissingPdfs.call({materialCategories?, onProgress})` | Uma passagem no índice → set de PDFs válidos (arquivo existe, `length > 0`); loop **somente** faltantes; `onProgress(done, total)` com `total = missing`; `skippedCount = manifest − missing` |
| `ClearOfflineCache.call()` | [OfflinePdfRepository.clearAll] + [PdfLocalStore.deleteTree] + checkpoint clear + [OfflineAvailableStore.clear] (`OFFLINE_AVAILABLE=FALSE`) |
| `MigrateOfflineStorage.call()` | v1 no-op; persiste [StorageKeys.offlineStorageVersion] |
| `offlineReconcileProvider.requestReconcile()` | [MigrateOfflineStorage] → [ReconcileOfflineIndex] global; deduplica se `isRunning` |
| `offlineReconcileProvider.requestReconcileDebounced()` | Debounce [OfflineConfig.reconcileForegroundDebounce] — [OfflineLifecycleListener] |
| Triggers reconcile | Foreground debounced, init [OfflineSettingsScreen], pós-categoria bulk — **proibido** `main()` / cold start |

### Contrato implementado — Fase 3.7 (UI offline)

| Assinatura | Comportamento |
|------------|---------------|
| `OfflineCacheStatus` | `validCount` = soma material UI; `stats.totalMissing` via manifest; `showRemovedWarning` quando `removedCount > 0` |
| `offlineCacheStatusProvider.refresh({removedCount?})` | Recarrega [GetOfflineStatsByCategory]; listener em [offlineReconcileProvider] propaga `removedFromIndex` |
| `offlineCacheStatusProvider.refreshAll()` | [offlineReconcileProvider.requestReconcile] → [GetOfflineStatsByCategory]; CTA **Atualizar** na [OfflineSettingsScreen] |
| `offlineCacheStatusProvider.dismissRemovedWarning()` | Zera `removedCount` (banner dismissível) |
| `offlineMissingDownloadProvider.start({materialCategories?})` | [DownloadMissingPdfs] com progresso sobre faltantes; refresh + dismiss aviso ao concluir |
| `offlineModeProvider` | `true` quando `OFFLINE_AVAILABLE=TRUE` ou migração (`validCount ≥ offlineModeMigrationMinPdfCount`); `false` quando ausente ou `FALSE` |
| `OfflineModeNotifier.markConfigured()` | Persiste `TRUE` + `state = true` — pós-bulk UC-09 |
| `OfflineModeNotifier.syncDisabled()` | `state = false` após [ClearOfflineCache] (flag já `FALSE` em prefs) |
| `OfflineAvailableStore.markConfigured()` / `clear()` | `TRUE` / `FALSE` em [StorageKeys.offlineAvailable] |
| `OfflineSettingsScreen` | **Mutuamente exclusivo:** UC-10 (stats + faltantes + limpar) **ou** UC-09 (categorias + bulk); bulk `isRunning` força UC-09 |

**Removido jun/2026:** [OfflineIndicator] (`lib/core/widgets/offline_indicator.dart`) — badge `cloud_done`/`cloud_off` no header; status offline permanece em [OfflineSettingsScreen] via [offlineCacheStatusProvider].

**Deprecações PWA (não replicar como gate de abertura PDF):**

| Legado | Substituição Flutter |
|--------|---------------------|
| `OFFLINE_AVAILABLE` como gate de leitor | [ResolvePdfForReader] local-first; contagem Isar via [offlineCacheStatusProvider] (UI só em `/offline`) |
| `OFFLINE_AVAILABLE` na tela `/offline` | [offlineModeProvider] — `TRUE` → UC-10; `FALSE`/ausente → UC-09 |
| Cache Storage `plpc-pdfs` | [PdfLocalStore] em `plpcg_pdfs/` |
| Stats lazy dessincronizados | Índice Isar + [ReconcileOfflineIndex] em background |

### Restrições transversais (Fase 3)

| Restrição | Regra |
|-----------|--------|
| Cold start | Zero I/O de PDF no boot — só manifest + prefs |
| Persistência | Documents/`plpcg_pdfs/` — perene até desinstalar ou limpar dados |
| UI thread | Bulk, ZIP, reconcile completo → isolate/background |
| Indicador shell | Contagem Isar O(1) — não percorre disco |
| Reconcile completo | Foreground (debounced), [OfflineSettingsScreen], pós-bulk — **proibido boot** |
| Verificação por PDF | 1× `stat` no [ResolvePdfForReader] — sob demanda |

### Fluxo implementado Fase 3.4 — card → leitor + share/save local

```text
LouvorCard (modo leitor)
  → LouvorPdfPath.fromLouvor → remotePath (/assets/…)
  → ResolvePdfForReader(pdfId, remotePath)
      → OfflinePdfRepository.lookup(pdfId)     [hit]
          → PdfLocalStore path válido
      → FetchAndStorePdf(remotePath)           [miss + rede]
          → PdfBytesDatasource.fetchBytes
          → PdfLocalStore.writeAtomic
          → OfflinePdfRepository.upsert
  → OpenPdfInReader(pdfPath: localAbsolutePath, titulo)
  → PdfReaderScreen → pdfReaderSessionProvider(localPath)
      → PdfxViewerAdapter.openDocument → PdfDocument.openFile

Share/Save (cache hit):
  → SharePdf → Share.shareXFiles([XFile(localPath)])
  → SavePdf → File.copy → documents/saved_pdfs/
```

**Checkpoint mínimo (3.4):** 1º tap baixa e persiste; 2º tap `openFile`; share WhatsApp sem reler bytes; cold start sem scan PDF.

### Fluxo implementado Fase 3.5 — prefetch bulk (UC-09)

```text
OfflineSettingsScreen → DownloadOfflinePackages(categories)
  → checkFreeDiskSpace() — aborta com aviso se insuficiente
  → offline-manifest.json → ZIP por categoria (fila background / isolate)
  → ExtractAndStorePdfs(zipPath, resumeCheckpoint?)
      → descompacta → PdfLocalStore.writeAtomic (chunks 50–100)
      → OfflinePdfRepository.upsert (txn Isar por chunk)
  → ReconcileOfflineIndex() — fim de cada categoria
  → offlineBulkDownloadProvider completed
      → offlineModeProvider.markConfigured() — OFFLINE_AVAILABLE=TRUE
      → offlineCacheStatusProvider.refresh()
  → UI progresso; on-demand 3.3 continua paralelo
```

### Fluxo implementado jun/2026 — gate UI `OFFLINE_AVAILABLE` (UC-09 vs UC-10)

```text
Primeira visita / cache limpo (OFFLINE_AVAILABLE ausente ou FALSE)
  → OfflineSettingsScreen: card "Selecione as categorias" + "Baixar selecionados"
  → Baixar faltantes OCULTO (evita fetch individual antes do bulk)

Bulk concluído OU migração (validCount ≥ 200 sem flag FALSE)
  → offlineModeProvider = true
  → OfflineSettingsScreen: card "PDFs armazenados" + stats + "Baixar faltantes"

Limpar cache offline
  → ClearOfflineCache → OFFLINE_AVAILABLE=FALSE
  → offlineModeProvider.syncDisabled()
  → volta ao card UC-09 (migração bloqueada por isExplicitlyDisabled)

Bulk em execução
  → força card UC-09 mesmo com offlineModeProvider = true
```

### Fluxo implementado Fase 3.6 — reconcile global (UC-10)

```text
Trigger (debounced foreground | OfflineSettingsScreen.init | pós-bulk por categoria)
  → offlineReconcileProvider.requestReconcile()
      → MigrateOfflineStorage()
      → ReconcileOfflineIndex() — isolate, chunked, < 20s/5000
          → remove entradas índice sem arquivo válido
          → remove orphan files no disco (global)
  → OfflineReconcileState.lastResult.removedFromIndex
  → (3.7) offlineCacheStatusProvider → banner + DownloadMissingPdfs
```

### Fluxo implementado Fase 3.7 — aviso removidos + stats

```text
offlineReconcileProvider conclui
  → offlineCacheStatusProvider.refresh(removedCount: lastResult.removedFromIndex)
  → OfflineSettingsScreen: MaterialBanner se removedCount > 0
      → CTA offlineMissingDownloadProvider.start()
  → offlineBulkDownloadProvider completed → refresh cache status
```

### Fluxo implementado jun/2026 — refresh stats + download faltantes (UC-10)

```text
OfflineSettingsScreen — botão/AppBar "Atualizar"
  → offlineCacheStatusProvider.refreshAll()
      → offlineReconcileProvider.requestReconcile()
      → GetOfflineStatsByCategory(includeMissing: true)
          → listAll() + stat disco → PDFs válidos
          → CatalogLocalDatasource.loadPdfIdToCategoriaMap()
          → OfflineMaterialResolver.toUiMaterial → byCategory (material UI)
          → offline-manifest.json → missingByCategory
  → chips: "Partitura: N (M faltantes)"; subtítulo totalMissing

OfflineSettingsScreen — "Baixar faltantes"
  → offlineMissingDownloadProvider.start()
      → DownloadMissingPdfs
          → _collectValidPdfIds() — uma passagem no índice
          → missingPdfIds = manifest − válidos
          → FetchAndStorePdf **somente** para missingPdfIds
          → onProgress(done, missingPdfIds.length)
  → refresh cache status + dismiss banner removidos
```

### Subfases MVP — critérios de aceite (referência)

| Subfase | Entrega | Critério chave | Status |
|---------|---------|----------------|--------|
| 3.1 | `PdfLocalStore`, `OfflinePdfRepository` | `plpcg_pdfs/` em documents; proibido cache/temp | **Implementado** |
| 3.2 | `ResolvePdfForReader` | O(1) + stat; erro + re-fetch se apagado | **Implementado** |
| 3.3 | `FetchAndStorePdf` | On-demand; escrita atômica; retry | **Implementado** |
| 3.4 | Leitor + share/save local | `openFile`; `XFile` / `File.copy` | **Implementado** |
| 3.5 | Bulk UC-09 | Chunks, resume, espaço livre, reconcile/categoria | **Implementado** |
| 3.6 | Manutenção UC-10 | Reconcile isolate `< 20s/5000`; proibido boot | **Implementado** |
| 3.7 | UI + indicador | Reconcile ao abrir tela; aviso removidos; stats; limpar cache | **Implementado** |

## APIs públicas — carousel (Fase 4.1, UC-05)

Seleção temporária de louvores persistida em Isar ([CarouselEntry]). Substitui `localStorage.carouselLouvores` da PWA. Barra [CarouselChips] no [ShellScaffold] (inclusive `/leitor`) via [CarouselBarShell] + [CarouselNavigatorBar] + [CarouselBarTrailingActions]. **Integração 4.2 ✅:** salvar playlist. **Integração 4.3 ✅:** [LoadPlaylistIntoCarousel]. **Integração 4.4 ✅:** share URL. **Integração 4.6 ✅:** folheto. **Integração 4.7 ✅:** modo leitor em [CarouselChips] — [readerCarouselPositionProvider] + `context.replace` via [ReaderCarouselActionsNotifier.navigateToPdfId].

### Domínio (4.1 ✅)

| API | Arquivo | Estado | Descrição |
|-----|---------|--------|-----------|
| `CarouselItem` | `lib/features/carousel/domain/entities/carousel_item.dart` | **Implementado 4.1 + polish chip** | `{pdfId, sortOrder, numero, nome, categoria, classificacao}`; getter `label` → `numero — nome` (folheto UC-08) |
| `CarouselItemMetadata` | `lib/features/carousel/domain/entities/carousel_item.dart` | **Implementado polish chip** | Snapshot manifest para `getOrderedItems` sem acoplar domínio carousel ao catálogo |
| `CarouselRepository` | `lib/features/carousel/domain/repositories/carousel_repository.dart` | **Implementado 4.1** | Contrato CRUD + `replaceAll` (4.3 ✅) |
| `AddLouvorToCarousel` | `lib/features/carousel/domain/usecases/add_louvor_to_carousel.dart` | **Implementado 4.1 + testes** | `Future<bool> call({required pdfId})` — `true` se inseriu; `false` se duplicata |
| `RemoveLouvorFromCarousel` | `lib/features/carousel/domain/usecases/remove_louvor_from_carousel.dart` | **Implementado 4.1** | `call({required pdfId})` — remove + compacta `sortOrder` |
| `ReorderCarousel` | `lib/features/carousel/domain/usecases/reorder_carousel.dart` | **Implementado 4.1** | `call({required orderedPdfIds})` — reescreve ordem 0..n-1 |
| `ClearCarousel` | `lib/features/carousel/domain/usecases/clear_carousel.dart` | **Implementado 4.1** | `call()` — idempotente |

### Data layer (4.1 ✅)

| API | Arquivo | Estado | Descrição |
|-----|---------|--------|-----------|
| `CarouselLocalDatasource` | `lib/features/carousel/data/datasources/carousel_local_datasource.dart` | **Implementado 4.1 + testes** | `findAllOrdered`, `findByPdfId`, `add`, `remove`, `reorder`, `replaceAll`, `clear` — txn Isar |
| `CarouselRepositoryImpl` | `lib/features/carousel/data/repositories/carousel_repository_impl.dart` | **Implementado 4.1 + testes + polish chip** | Orquestra datasource; `getOrderedItems(pdfIdToMetadata)`; fallback `nome` truncado do `pdfId` |

### Providers (4.1 ✅)

| API | Arquivo | Estado | Descrição |
|-----|---------|--------|-----------|
| `carouselLocalDatasourceProvider` | `lib/features/carousel/data/providers/carousel_providers.dart` | **Implementado 4.1** | DI [CarouselLocalDatasource] via [isarProvider] |
| `carouselRepositoryProvider` | `lib/features/carousel/data/providers/carousel_providers.dart` | **Implementado 4.1** | DI [CarouselRepositoryImpl] |
| `addLouvorToCarouselProvider` | `lib/features/carousel/data/providers/carousel_providers.dart` | **Implementado 4.1** | DI [AddLouvorToCarousel] |
| `removeLouvorFromCarouselProvider` | `lib/features/carousel/data/providers/carousel_providers.dart` | **Implementado 4.1** | DI [RemoveLouvorFromCarousel] |
| `reorderCarouselProvider` | `lib/features/carousel/data/providers/carousel_providers.dart` | **Implementado 4.1** | DI [ReorderCarousel] |
| `clearCarouselProvider` | `lib/features/carousel/data/providers/carousel_providers.dart` | **Implementado 4.1** | DI [ClearCarousel] |
| `carouselReorderPersistDebounce` | `lib/features/carousel/presentation/providers/carousel_louvores_provider.dart` | UC-05 | **Implementado fix flicker reorder jun/2026** | `Duration(milliseconds: 100)` — agrupa persist Isar + [syncActivePlaylistFromCarousel] após `reorder` |
| `CarouselLouvoresNotifier` | `lib/features/carousel/presentation/providers/carousel_louvores_provider.dart` | **Implementado 4.1 + 4.3 + polish chip + fix reorder** | `add`, `remove`, `reorder` (otimista), `clear`, `reload`; `_reloadGeneration` anti-corrida |
| `carouselLouvoresProvider` | `lib/features/carousel/presentation/providers/carousel_louvores_provider.dart` | **Implementado 4.1 + fix reorder** | Fonte de verdade `List<CarouselItem>` — modal, catálogo, navegação |
| `carouselLouvoresDisplayDebounce` | `lib/features/carousel/presentation/providers/carousel_louvores_display_provider.dart` | UC-05 | **Implementado fix flicker reorder jun/2026** | `Duration(milliseconds: 100)` — debounce de render na barra |
| `CarouselLouvoresDisplayNotifier` | idem | UC-05 | **Implementado fix flicker reorder jun/2026** | Deriva de [carouselLouvoresProvider]; add/remove/clear imediato; reorder-only debounced |
| `carouselLouvoresDisplayProvider` | idem | UC-05 | **Implementado fix flicker reorder jun/2026** | Lista para [CarouselChips] — evita flicker na barra durante reorder |
| `CarouselFocusedIndexNotifier` | `lib/features/carousel/presentation/providers/carousel_focused_index_provider.dart` | **Implementado polish chip + abrir leitor + fix reorder** | Índice por `pdfId` focado; `goPrevious` / `goNext` / `focusPdfId` / `reset`; sync via `ref.watch` único |
| `carouselFocusedIndexProvider` | idem | **Implementado polish chip + abrir leitor + fix reorder** | `NotifierProvider<int>` — reativo a [carouselLouvoresProvider]; barra resolve chip por `pdfId` na lista display |

### Apresentação (4.1 ✅ + polish chip + abrir leitor)

| API | Arquivo | UC | Estado | Descrição |
|-----|---------|-----|--------|-----------|
| `CarouselLouvorChipVariant` | `lib/features/carousel/presentation/widgets/carousel_louvor_chip.dart` | UC-05 | **Implementado polish chip** | `modal` (pill, `#num — nome` no título) \| `topBar` (retangular 8px, número na linha de metadados) |
| `CarouselLouvorChip` | idem | UC-05/01/03/04/06 | **Implementado polish chip + abrir leitor + metadados médios + trailing catálogo + share ⋮** | Chip temático PLPCG; metadados responsivos; `onTap`; `onRemove` (playlists/modal); `onAdd`/`isAdded`/`loading`/`onShare`/`shareLoading` ([LouvorCard]); menu ⋮ UC-04; drag opcional |
| `carouselChipBarHeight` / `carouselChipTopBarHeight` | idem | UC-05 | **Implementado polish chip** | `58` (modal/leitor) \| `52` (barra shell) — altura na [CarouselNavigatorBar] |
| `carouselChipMaxWidth` | idem | UC-05 | **Implementado polish chip** | `168` — referência de largura compacta na barra |
| `carouselChipMetadataCompactWidth` | idem | UC-05 | **Implementado metadados médios** | `180` — abaixo: metadados só ícones + [Tooltip] |
| `carouselChipMetadataMediumWidth` | idem | UC-05 | **Implementado metadados médios** | `280` — entre compact e medium: ícone + texto truncável para classificação **e** categoria; acima: classificação só texto, categoria ícone + texto |
| `CarouselBarShell` | `lib/features/carousel/presentation/widgets/carousel_bar_shell.dart` | UC-05/11 | **Implementado UI 3 barras + polish ícones** | Container creme + elevação; `applySafeArea` default `true` (shell e leitor); exporta [carouselBarIconButtonStyle] |
| `carouselBarShellHeight` | idem | UC-05/11 | **Implementado UI 3 barras** | `60.0` — altura aproximada de referência (padding + chip) |
| `carouselBarIconButtonStyle` | idem | UC-05/11 | **Implementado polish ícones barra** | `ButtonStyle` compartilhado — `foregroundColor: AppColors.title`; `disabledForegroundColor` com opacidade 0.38 (setas durante `loading` permanecem vinho, não preto/cinza) |
| `kCarouselBarExpandedBreakpoint` | `lib/features/carousel/presentation/widgets/carousel_bar_trailing_actions.dart` | UC-05 | **Implementado overflow smartphone** | `600.0` — `MediaQuery.sizeOf.width` ≥ valor → ícones individuais; < valor → menu ⋮ |
| `CarouselBarTrailingActions` | `lib/features/carousel/presentation/widgets/carousel_bar_trailing_actions.dart` | UC-05/06/07/08 | **Implementado UI 3 barras + overflow smartphone + share lista + polish ícones** | Salvar, compartilhar (UC-07), folheto, limpar — shell e leitor; compacto: [PopupMenuButton] `iconColor: AppColors.title`; expandido: quatro [IconButton] com [carouselBarIconButtonStyle] |
| `CarouselNavigatorBar` | `lib/features/carousel/presentation/widgets/carousel_navigator_bar.dart` | UC-05/11 | **Implementado 4.7 + fix v2 + polish ícones** | Chip + setas + lista + `trailingActions`; ícones via [carouselBarIconButtonStyle]; `loading` desabilita setas/chip; botão lista **sempre** habilitado |
| `carouselSelectionReorderProxyDecorator` | `lib/features/carousel/presentation/widgets/carousel_selection_sheet.dart` | UC-05 | **Implementado fix drag modal jun/2026** | `ReorderableListView.proxyDecorator` transparente — evita `Material` com elevação retangular atrás de chips pill durante reorder |
| `showCarouselSelectionSheet` | `lib/features/carousel/presentation/widgets/carousel_selection_sheet.dart` | UC-05 | **Implementado polish chip + abrir leitor + fix drag modal** | Modal reordenável; `onItemTap` fecha dialog e abre louvor no leitor; reorder com [carouselSelectionReorderProxyDecorator] |
| `openCarouselPdfInReader` | `lib/features/carousel/presentation/utils/open_carousel_pdf_in_reader.dart` | UC-04/05 | **Implementado + testes widget + fix v3** | `navigateToPdfId` → [ResolvePdfForReader] → rota `/leitor`; `navigate` injetável — **não** aguardar `pop` do `push` |
| `CarouselChips` | `lib/features/carousel/presentation/widgets/carousel_chips.dart` | UC-05/06/08/11 | **Implementado 4.1 + 4.2 + 4.6 + 4.7 fix v3 + fix flicker reorder** | `watch` [carouselLouvoresDisplayProvider] na barra; navegação/setas usam [carouselLouvoresProvider] + `pdfId` focado; `_replaceReaderWithCarouselItem`; `focusPdfId` pós-nav |
| `ShellScaffold` | `lib/features/app_shell/presentation/shell_scaffold.dart` | UC-05/14 | **Implementado 4.1 + header + bottom bar jun/2026 + 2.4** | [PlpcgPrimaryAppBar] + [CarouselChips] + [PlpcgBottomNavBar] (5 destinos); oculta bottom bar em `/leitor`; oculta barras 1–2 quando [readerFullscreenProvider] |
| `LouvorCard` | `lib/features/catalog/presentation/widgets/louvor_card.dart` | UC-01/03/04/05 | **Implementado 4.1 + polish chip lista + share ⋮ jun/2026** | Wrapper de [CarouselLouvorChip] modal; `Louvor` → [CarouselItem]; `onTap` PDF; `onAdd`/`isAdded` via [carouselLouvoresProvider]; menu ⋮ → [sharePdfProvider]; usado em [HomeScreen] e [LibraryScreen] |

### Contrato implementado — Fase 4.1 (UC-05)

| Assinatura | Comportamento |
|------------|---------------|
| `CarouselRepository.add(pdfId)` | Append com `sortOrder = max + 1`; no-op se `pdfId` já existe (`@Index(unique: true)`) |
| `CarouselRepository.remove(pdfId)` | Delete por `pdfId`; reindexa `sortOrder` 0..n-1; idempotente se ausente |
| `CarouselRepository.reorder(orderedPdfIds)` | Valida conjunto idêntico ao atual; lança `ArgumentError` se divergir; reescreve ordem |
| `CarouselRepository.replaceAll(orderedPdfIds)` | `clear` + insert sequencial — usado por [LoadPlaylistIntoCarousel] (4.3 ✅) |
| `carouselLouvoresProvider.notifier.reload()` | Refresh UI após load externo da playlist; `_reloadGeneration` descarta resultados obsoletos |
| `carouselReorderPersistDebounce` | `100ms` — timer entre chamadas consecutivas de `reorder` antes de persistir no Isar |
| `carouselLouvoresProvider.notifier.reorder(orderedPdfIds)` | Atualização otimista em memória (sem `_reload`); persist + [syncActivePlaylistFromCarousel] debounced |
| `carouselLouvoresDisplayDebounce` | `100ms` — debounce de render na barra quando só a ordem muda (mesmo conjunto de `pdfId`) |
| `carouselLouvoresDisplayProvider` | Lista derivada para [CarouselChips]; add/remove/clear imediato; reorder debounced |
| `CarouselRepository.getOrderedItems({pdfIdToMetadata})` | Ordena por `sortOrder`; enriquece `numero`/`nome`/`categoria`/`classificacao` do mapa manifest |
| `CarouselItem.label` | Getter derivado `numero — nome` — usado por [LeafletDocument.fromCarouselItems] |
| `LouvorClassification.displayLabel(classificacao)` | `Col*` → `Coletânea *` na linha de metadados do chip |
| `CarouselLouvorChip(item, {variant, showDragHandle, onTap?, onRemove?, onAdd?, onShare?, isAdded?, loading?, shareLoading?})` | `onTap` no corpo (InkWell); trailing por prioridade: `loading` → spinner; `onRemove` → X; `isAdded` → check; `onAdd` → +; depois menu ⋮ se `onShare` |
| `CarouselLouvorChip.onAdd` / `isAdded` / `loading` | Trailing do catálogo ([LouvorCard]): adicionar à seleção, indicador de duplicata, spinner durante resolve PDF |
| `CarouselLouvorChip.onShare` / `shareLoading` | Menu ⋮ à direita do trailing; item único [sharePdf]; callback recebe `Rect sharePositionOrigin` via [sharePositionOriginFromContextOrFallback]; spinner no ⋮ durante share |
| `CarouselLouvorChip` metadados (largura chip) | &lt; 180: ícones only; 180–280: ícone+texto classificação **e** categoria; ≥ 280: classificação texto, categoria ícone+texto |
| `carouselChipMetadataCompactWidth` / `carouselChipMetadataMediumWidth` | Breakpoints da linha de metadados — `180.0` e `280.0` |
| `CarouselNavigatorBar({item, onChipTap?, loading, ...})` | `loading` desabilita setas/chip; ícones via [carouselBarIconButtonStyle]; `onOpenList` sempre ativo; shell: `onChipTap` → `push`; leitor: sem `onChipTap` |
| `CarouselBarShell({child, applySafeArea})` | `applySafeArea: true` (default) — `SafeArea(bottom: false)`; exporta [carouselBarIconButtonStyle]; barra 1 do leitor usa [PlpcgPrimaryAppBar] (`AppBar` primary) para o notch |
| `_ReaderScaffold` | Barra 3: `AppBar(primary: false)` condicional; [PdfReaderPageIndicator(filePath)] + long-press → página 1; `Expanded → Stack(Positioned.fill)` → PDF; FAB saída `Opacity(0.25)` quando ativo — barras 1–2 via [ShellScaffold] |
| `carouselBarIconButtonStyle` | `ButtonStyle` — `AppColors.title` habilitado; opacidade 0.38 desabilitado; usado em [CarouselNavigatorBar] e [CarouselBarTrailingActions] expandido |
| `CarouselBarTrailingActions` | Salvar / compartilhar / folheto / limpar — extraídos de [CarouselChips]; smartphone: `PopupMenuButton` (`iconColor: AppColors.title`, `carouselOverflowMenu`); tablet+: quatro ícones com [carouselBarIconButtonStyle] |
| `CarouselBarTrailingActions._sharePlaylist` | `sharePositionOrigin` capturado antes de `await` → [resolveActivePlaylistFromCarousel]; vazio? [playlistEmptyPdfList]; senão [PlaylistsNotifier.sharePlaylist] com `sharePositionOrigin`; falha → [showPlaylistShareErrorSnackbar] |
| `kCarouselBarExpandedBreakpoint` | `600.0` — breakpoint compartilhado com layout Home; controla modo compacto vs expandido de [CarouselBarTrailingActions] |
| `carouselSelectionReorderProxyDecorator(child, index, animation)` | Proxy de drag transparente (`elevation: 0`) — usado no [ReorderableListView] do modal; corrige artefato visual com chips pill |
| `showCarouselSelectionSheet(context, {onItemRemoved?, onItemTap?})` | `onItemTap` fecha modal e delega abertura; reorder via handle + [carouselSelectionReorderProxyDecorator]; remove inalterado |
| `openCarouselPdfInReader({ref, context, pdfId, navigate})` | [ReaderCarouselActionsNotifier.navigateToPdfId] + erros offline tipados; `navigate` dispara rota sem aguardar `pop` |
| `CarouselChips._replaceReaderWithCarouselItem({selectedPdfId, currentPdfId?})` | Compara com `pdfId` ativo (URL → provider); guarda `_carouselNavLoading` antes de efeitos; `focusPdfId` após `replace` |
| `CarouselFocusedIndexNotifier.focusPdfId(pdfId)` | Sincroniza índice da barra **após** navegação bem-sucedida (chip/modal/setas) |
| `AddLouvorToCarousel.call({pdfId})` | Delega `add`; retorna `false` se já existia |
| `carouselLouvoresProvider.notifier.add(pdfId)` | Use case + `_reload()`; retorna `bool` para snackbar |
| `CarouselChips` | Um chip visível por vez; lista display debounced; índice/navegação via [carouselFocusedIndexProvider] + `pdfId` na fonte; ações salvar/folheto/limpar na barra |
| `LouvorCard._handleAddToCarousel()` | Trailing `onAdd` do chip; não interfere com `onTap` (abrir PDF); snackbar `carouselAdded` \| `carouselAlreadyAdded` |
| `LouvorCard._handleShare(sharePositionOrigin)` | Menu ⋮ → [sharePdfProvider]; paridade [PdfReaderScreen._sharePdf]; snackbar [pdfShareSuccess]; erros offline tipados |

### Regras de negócio (UC-05)

| Regra | Comportamento |
|-------|---------------|
| Duplicata | Ignorada silenciosamente no `add`; UI opcional via `carouselAlreadyAdded` |
| Ordem | `sortOrder` contíguo 0..n-1 após remove/reorder |
| Persistência | [CarouselEntry] em Isar — sobrevive restart; **sem** cold-start scan especial |
| Louvor órfão | Chip exibe fallback se `pdfId` ausente do manifest |
| Limpar tudo | [showConfirmDialog] antes de [ClearCarousel] |
| UI global | Seleção visível em todas as abas do shell quando não vazia |
| Abrir no leitor | Toque no chip da barra ou no item do modal → [openCarouselPdfInReader] → `/leitor?file=…&pdfId=…` |

### Fluxo implementado Fase 4.1 — adicionar e exibir seleção

```text
LouvorCard trailing (+)
  → carouselLouvoresProvider.notifier.add(pdfId)
      → AddLouvorToCarousel → CarouselRepository.add
      → CarouselLocalDatasource (Isar writeTxn, putByPdfId)
      → _reload() → getOrderedItems + metadados de louvoresManifestProvider
  → snackbar carouselAdded | carouselAlreadyAdded

ShellScaffold
  → CarouselChips.watch(carouselLouvoresDisplayProvider + carouselFocusedIndexProvider)
      → CarouselNavigatorBar(chipVariant: topBar, onChipTap)
          → tap chip → openCarouselPdfInReader → context.push(/leitor?…)
      → ◀/▶ navegam carouselFocusedIndexProvider
      → IconButton view_list → showCarouselSelectionSheet(onItemTap)
          → tap chip no modal → pop dialog → openCarouselPdfInReader → push → focusPdfId
      → IconButton clear_all → showConfirmDialog → clear
```

**Fix drag modal seleção (jun/2026):** [showCarouselSelectionSheet] usa [carouselSelectionReorderProxyDecorator] no `proxyDecorator` do [ReorderableListView] — substitui o `Material` padrão (elevação + sombra retangular) por proxy transparente, eliminando borda visível ao arrastar chips pill no modal "Seleção temporária".

**Fix flicker reorder (jun/2026):** Reordenação no modal disparava múltiplos `_reload()` concorrentes e rebuild duplo do índice focado — dados "piscavam" na barra e no modal. Correções: (1) [CarouselLouvoresNotifier.reorder] — update otimista em memória, persist Isar + sync playlist após [carouselReorderPersistDebounce] (`100ms`), sem `_reload` intermediário; `_reloadGeneration` em `_reload()` ignora corridas; (2) [carouselLouvoresDisplayProvider] — barra [CarouselChips] observa lista debounced ([carouselLouvoresDisplayDebounce]); add/remove/clear imediatos; só reorder coalesce render; modal continua em [carouselLouvoresProvider] para resposta instantânea ao soltar item; (3) [carouselFocusedIndexProvider] — removido `ref.listen` redundante (um rebuild por mudança). Teste: `carousel_louvores_display_provider_test.dart`.

### `CarouselLouvoresDisplayNotifier` — API pública (UC-05 fix flicker jun/2026)

| Membro | Tipo | Default | Descrição |
|--------|------|---------|-----------|
| `carouselLouvoresDisplayDebounce` | `const Duration` (top-level) | `100ms` | Em `carousel_louvores_display_provider.dart`; debounce **somente** quando o conjunto de `pdfId` é idêntico e só a ordem mudou (reorder no modal) |
| `CarouselLouvoresDisplayNotifier` | `Notifier<List<CarouselItem>>` | — | `ref.listen(carouselLouvoresProvider)`; cancela timer em `onDispose` |
| `carouselLouvoresDisplayProvider` | `NotifierProvider` | — | Lista para renderização em [CarouselChips]; fonte de navegação permanece [carouselLouvoresProvider] |
| Add/remove/clear | interno | imediato | `state = next` sem debounce quando o conjunto de `pdfId` muda |
| Reorder-only | interno | debounced | `_samePdfIdSet` && `!_samePdfIdOrder` → `Timer(carouselLouvoresDisplayDebounce)` antes de atualizar `state` |

**Consumidores:** [CarouselChips] (`watch` display); modal [showCarouselSelectionSheet] (`watch` [carouselLouvoresProvider] para feedback instantâneo ao soltar item).

**Polish chip PLPCG (jun/2026):** [CarouselLouvorChip] unifica barra, modal, playlists e **lista de catálogo** — fundo vinho, borda dourada, metadados do manifest (`numero`, `categoria`, `classificacao` amigável). Barra shell usa variante `topBar` (retangular, número na linha inferior) para maximizar espaço do título; modal/leitor/playlists/biblioteca/pesquisa mantêm pill `modal`. [LouvorCard] observa [carouselLouvoresProvider] para `isAdded` e delega visual ao chip.

**Metadados responsivos chip (jun/2026):** Linha inferior adapta conteúdo à largura (`LayoutBuilder`): &lt; [carouselChipMetadataCompactWidth] (180px) — só ícones com [Tooltip]; 180–[carouselChipMetadataMediumWidth] (280px) — ícone + texto truncável para classificação **e** categoria (corrige ausência de rótulo "Partitura"/"Cifra" no modo médio); ≥ 280px — classificação só texto; categoria ícone + texto. Teste: `modo médio exibe classificação e categoria com texto truncável` em `carousel_louvor_chip_test.dart`.

**Trailing catálogo (jun/2026):** Novos parâmetros públicos de [CarouselLouvorChip] para [LouvorCard]:

| Parâmetro | Tipo | Default | Comportamento |
|-----------|------|---------|---------------|
| `onRemove` | `VoidCallback?` | `null` | Botão `X` no trailing — modal de seleção e [PlaylistListTile] expandido |
| `onAdd` | `VoidCallback?` | `null` | Botão circular `+` no trailing; dispara [carouselLouvoresProvider.notifier.add] |
| `isAdded` | `bool` | `false` | Exibe check no trailing quando louvor já está na seleção |
| `loading` | `bool` | `false` | Spinner dourado no trailing; desabilita `onTap`, `onAdd` e `onShare` em [LouvorCard] |
| `onShare` | `void Function(Rect sharePositionOrigin)?` | `null` | Menu ⋮ com item [sharePdf]; à direita do trailing +/✓/X; [PopupMenuButton] temático (`AppColors.card` + borda gold) |
| `shareLoading` | `bool` | `false` | Spinner dourado no ícone ⋮; desabilita item do menu durante share |

Prioridade do trailing: `loading` → `onRemove` → `isAdded` → `onAdd`; depois menu ⋮ se `onShare != null`. Testes: `exibe botão adicionar e indicador de já adicionado`; `exibe menu compartilhar quando onShare está definido` em `carousel_louvor_chip_test.dart`.

**Share PDF nos cards (jun/2026 — UC-04):** [LouvorCard] expõe compartilhamento sem abrir o leitor — paridade com o botão share da toolbar [PdfReaderScreen]. Fluxo: tap ⋮ → **Compartilhar** → [resolvePdfForReaderProvider] → [sharePdfProvider](`absolutePath`, `displayName: louvor.nome`, `sharePositionOrigin`) → sheet nativo [share_plus]. Âncora iOS via [sharePositionOriginFromContextOrFallback] no `onSelected` do menu. Estados: `_shareLoading` independente de `_loading` (abrir leitor). Teste: `LouvorCard menu Compartilhar dispara SharePdf` em `louvor_card_share_save_test.dart`.

**Abrir leitor do carousel (jun/2026):** [openCarouselPdfInReader] centraliza resolve + navegação; reutiliza [ReaderCarouselActionsNotifier.navigateToPdfId]. No leitor, [CarouselChips] usa `context.replace` (setas, modal) — não empilha rotas.

**Navegação carousel no leitor (jun/2026 — fix v2):** [PdfReaderScreen] publica query params em [readerRouteParamsProvider] (post-frame) para [CarouselChips] no shell ler o mesmo `pdfId`. [readerCarouselPositionProvider] é síncrono. Setas → `navigateToPdfId` → `replace`. Botão lista permanece habilitado durante `_carouselNavLoading`. Fallback de `pdfId`: URL → provider → índice focado.

**Modal carousel — fix v3 (jun/2026):** Corrige bug em que o 2º toque no chip do modal só atualizava a barra sem abrir/trocar o PDF. Causas: (1) `_openingReader` permanecia `true` enquanto `context.push` aguardava `pop`; (2) `focusPdfId` antes da navegação mascarava falhas; (3) `currentPdfId` capturado ao abrir o modal ficava defasado vs URL após `replace`. Correções: priorizar query params do GoRouter sobre [readerRouteParamsProvider]; resolver `pdfId` ativo no toque; `focusPdfId` só após `openCarouselPdfInReader` com sucesso; `_carouselNavLoading` verificado antes de qualquer efeito. Testes: `segundo toque no chip do modal no leitor/shell` em `carousel_chips_test.dart`.

**Overflow barra smartphone (jun/2026):** Em largura < [kCarouselBarExpandedBreakpoint] (600px), [CarouselBarTrailingActions] colapsa salvar/compartilhar/folheto/limpar em menu `more_vert` com itens somente texto ([carouselSavePlaylist], [carouselSharePlaylist], [carouselGenerateLeaflet], [carouselClear]). [CarouselNavigatorBar] mantém setas de troca de PDF e botão lista (`view_list`) sempre visíveis — mais espaço horizontal para o chip. Tablet e maiores preservam os quatro ícones (`save_outlined`, `share_outlined`, `description_outlined`, `clear_all`). Testes: `em smartphone usa menu overflow`, `menu overflow em smartphone dispara compartilhar lista` e `menu overflow em smartphone dispara gerar folheto` em `carousel_chips_test.dart`.

**Share lista na barra carousel (jun/2026 — UC-07):** Entrada [carouselSharePlaylist] no menu overflow e botão `share_outlined` no layout expandido. Compartilha a seleção do carousel sem exigir visita a `/listas` — paridade PWA `/?sharepdfs=…&sharename=…`. Fluxo: [resolveActivePlaylistFromCarousel] (sincroniza/recupera playlist; corrige falso “lista vazia” após restart) → [GeneratePlaylistShareUrl] → `Share.share` com [sharePositionOriginFromContextOrFallback] (fix iOS). Diagnóstico: [playlistShareDebugLog*]; falha → [showPlaylistShareErrorSnackbar]. Testes: `carousel_chips_test.dart`, `resolve_active_playlist_from_carousel_test.dart`.

**Fix share iOS (jun/2026 — UC-07):** `PlatformException: sharePositionOrigin: argument must be set` ao chamar [Share.share] sem âncora. Correção: capturar `sharePositionOrigin` do contexto do botão/menu **antes** de awaits; repassar em [PlaylistsNotifier.sharePlaylist]. Fallback [sharePositionOriginFromContextOrFallback] quando [RenderBox] ainda sem layout (menu overflow).

### `playlistShareDebugLog*` — API pública (UC-07 debug jun/2026)

| API | Arquivo | Descrição |
|-----|---------|-----------|
| `playlistShareLastStage` / `playlistShareLastError` | `playlist_share_debug_log.dart` | Estado da última falha de share — preenchido em [kDebugMode] |
| `playlistShareDebugClearLastFailure()` | idem | Limpa estado antes de nova tentativa em [CarouselBarTrailingActions._sharePlaylist] |
| `playlistShareDebugLog(message)` | idem | `debugPrint('[UC-07 playlist-share] …')` só em debug |
| `playlistShareDebugLogError(stage, error, stack)` | idem | Exceção + stack; preenche `playlistShareLast*` |
| `playlistShareDebugErrorSummary()` | idem | Resumo `estágio — Tipo: mensagem` para snackbar |
| `showPlaylistShareErrorSnackbar(context, l10n)` | idem | [playlistShareError] + resumo em debug (8s) |

**Instrumentação em:** [PlaylistsNotifier.resolveActivePlaylistFromCarousel], [PlaylistsNotifier.sharePlaylist], [CarouselBarTrailingActions._sharePlaylist].

**Polish ícones barra carousel (jun/2026):** Setas (`chevron_left`/`chevron_right`), lista (`view_list`) e menu overflow (`more_vert`) passam a usar [AppColors.title] (vinho PLPCG) em vez do preto/cinza padrão do Material — especialmente visível quando setas ficam desabilitadas durante `loading`. API compartilhada: [carouselBarIconButtonStyle] em [CarouselBarShell]; [CarouselBarTrailingActions] define `iconColor: AppColors.title` no [PopupMenuButton] compacto e reutiliza o mesmo estilo no layout expandido. Sem alteração de contrato funcional (UC-05).

**Checkpoint 4.1:** + na Home/Biblioteca; chips no shell; reorder no modal persiste; toque chip/modal abre leitor (repetível); duplicata ignorada; restart mantém seleção.

### Subfase MVP — critério 4.1

| Subfase | Entrega | Critério chave | Status |
|---------|---------|----------------|--------|
| 4.1 | Carousel CRUD | Add/remove/reorder/clear; Isar; barra shell; botão + no card | **Implementado** |

## APIs públicas — playlists (Fase 4.2–4.8, UC-06/07)

Playlists em Isar ([Playlist]). Substitui `localStorage.savedPlaylists` da PWA. **4.8 ✅:** toda abertura de louvor no leitor garante lista ativa ([EnsurePlaylistForLouvor]); rascunhos (`salva: false`) auto-criados; carousel espelha playlist ativa via [syncActivePlaylistFromCarousel]. Gestão em [PlaylistsScreen] com 3 abas ([PlaylistTab]). **4.3 ✅:** carregar + abrir no leitor. **4.4 ✅:** share/import. **4.5 ✅:** deep link via [SyncDeepLinkState] + [DeepLinkListener].

### Domínio (4.2–4.8 ✅)

| API | Arquivo | Estado | Descrição |
|-----|---------|--------|-----------|
| `SavedPlaylist` | `lib/features/playlists/domain/entities/saved_playlist.dart` | **Implementado 4.2 + 4.8** | `{playlistId, nome, pdfIds, createdAt, salva, savedAt?, favoritedAt?, favorita}` |
| `PlaylistTab` | `lib/features/playlists/domain/entities/playlist_tab.dart` | **Implementado 4.8** | `unsaved` / `saved` / `favorites` |
| `EnsurePlaylistResult` | `lib/features/playlists/domain/usecases/ensure_playlist_for_louvor.dart` | **Implementado 4.8 + testes** | `{playlistId, createdNew}` |
| `EnsurePlaylistForLouvor` | `lib/features/playlists/domain/usecases/ensure_playlist_for_louvor.dart` | **Implementado 4.8 + testes** | `call({pdfId, activePlaylistId?})` — reutiliza ou cria rascunho |
| `SavePlaylist` | `lib/features/playlists/domain/usecases/save_playlist.dart` | **Implementado 4.8** | Marca `salva` + `savedAt` |
| `FavoritePlaylist` | `lib/features/playlists/domain/usecases/favorite_playlist.dart` | **Implementado 4.8** | `favorita` + `favoritedAt` |
| `UnfavoritePlaylist` | `lib/features/playlists/domain/usecases/unfavorite_playlist.dart` | **Implementado 4.8** | Remove favorito |
| `DeleteAllUnsavedPlaylists` | `lib/features/playlists/domain/usecases/delete_all_unsaved_playlists.dart` | **Implementado 4.8 + testes** | Apaga rascunhos |
| `PlaylistViewItem` | `lib/features/playlists/presentation/providers/playlists_provider.dart` | **Implementado 4.2** | `{playlist: SavedPlaylist, pdfLabels}` — enriquecido para UI via manifest |
| `PlaylistRepository` | `lib/features/playlists/domain/repositories/playlist_repository.dart` | **Implementado 4.2 + 4.8** | CRUD + `getByTab` + `deleteAllUnsaved`; timestamps por aba |
| `generatePlaylistId` / `defaultPlaylistName` | `lib/features/playlists/domain/utils/playlist_defaults.dart` | **Implementado 4.2** | ID PWA-compatible (base36+random); nome `lista dd/MM/yyyy HH:mm:ss` |
| `EmptyCarouselException` | `lib/features/playlists/domain/exceptions/empty_carousel_exception.dart` | **Implementado 4.2** | Carousel vazio ao salvar |
| `PlaylistNotFoundException` | `lib/features/playlists/domain/exceptions/playlist_not_found_exception.dart` | **Implementado 4.3** | Playlist ausente ao carregar |
| `CreatePlaylistFromCarousel` | `lib/features/playlists/domain/usecases/create_playlist_from_carousel.dart` | **Implementado 4.2 + testes** | `Future<String> call({String? nome})` — snapshot do carousel |
| `LoadPlaylistIntoCarousel` | `lib/features/playlists/domain/usecases/load_playlist_into_carousel.dart` | **Implementado 4.3 + testes** | `call({playlistId})` — `replaceAll(playlist.pdfIds)` |
| `UpdatePlaylist` | `lib/features/playlists/domain/usecases/update_playlist.dart` | **Implementado 4.2** | `call({playlistId, nome?, pdfIds?})` — auto-delete se `pdfIds` vazio |
| `DeletePlaylist` | `lib/features/playlists/domain/usecases/delete_playlist.dart` | **Implementado 4.2** | `call({playlistId})` — idempotente |
| `TogglePlaylistFavorite` | `lib/features/playlists/domain/usecases/toggle_playlist_favorite.dart` | **Implementado 4.2** (legado) | Preferir [FavoritePlaylist] / [UnfavoritePlaylist] (4.8) |
| `GeneratePlaylistShareUrl` | `lib/features/playlists/domain/usecases/generate_playlist_share_url.dart` | **Implementado 4.4 + testes** | `call({playlistId})` → URL com [AppConfig.apiBaseUrl] |
| `ImportSharedPlaylistFromUrl` | `lib/features/playlists/domain/usecases/import_shared_playlist_from_url.dart` | **Implementado 4.4 + testes** | `call({sharePdfs, shareName})` → `playlistId` |
| `EmptyPlaylistShareException` | `lib/features/playlists/domain/exceptions/empty_playlist_share_exception.dart` | **Implementado 4.4** | Share com lista vazia |
| `InvalidSharePlaylistException` | `lib/features/playlists/domain/exceptions/invalid_share_playlist_exception.dart` | **Implementado 4.4** | Import com params inválidos |

### Data layer (4.2 ✅)

| API | Arquivo | Estado | Descrição |
|-----|---------|--------|-----------|
| `PlaylistLocalDatasource` | `lib/features/playlists/data/datasources/playlist_local_datasource.dart` | **Implementado 4.2 + 4.8 + testes** | `findUnsaved`/`findSaved`/`findFavorites`, `deleteAllUnsaved`, `updateFields` com timestamps |
| `PlaylistRepositoryImpl` | `lib/features/playlists/data/repositories/playlist_repository_impl.dart` | **Implementado 4.2 + 4.8 + testes** | Mapeia `Playlist` ↔ `SavedPlaylist`; `create(salva:, savedAt:)`; `getByTab` |

### Providers (4.2–4.8 ✅)

| API | Arquivo | Estado | Descrição |
|-----|---------|--------|-----------|
| `playlistLocalDatasourceProvider` | `lib/features/playlists/data/providers/playlist_providers.dart` | **Implementado 4.2** | DI [PlaylistLocalDatasource] via [isarProvider] |
| `playlistRepositoryProvider` | `lib/features/playlists/data/providers/playlist_providers.dart` | **Implementado 4.2** | DI [PlaylistRepositoryImpl] |
| `createPlaylistFromCarouselProvider` | `lib/features/playlists/data/providers/playlist_providers.dart` | **Implementado 4.2** | DI [CreatePlaylistFromCarousel] + [carouselRepositoryProvider] |
| `updatePlaylistProvider` | `lib/features/playlists/data/providers/playlist_providers.dart` | **Implementado 4.2** | DI [UpdatePlaylist] |
| `deletePlaylistProvider` | `lib/features/playlists/data/providers/playlist_providers.dart` | **Implementado 4.2** | DI [DeletePlaylist] |
| `togglePlaylistFavoriteProvider` | `lib/features/playlists/data/providers/playlist_providers.dart` | **Implementado 4.2** | DI [TogglePlaylistFavorite] (legado) |
| `savePlaylistProvider` | `lib/features/playlists/data/providers/playlist_providers.dart` | **Implementado 4.8** | DI [SavePlaylist] |
| `favoritePlaylistProvider` | `lib/features/playlists/data/providers/playlist_providers.dart` | **Implementado 4.8** | DI [FavoritePlaylist] |
| `unfavoritePlaylistProvider` | `lib/features/playlists/data/providers/playlist_providers.dart` | **Implementado 4.8** | DI [UnfavoritePlaylist] |
| `deleteAllUnsavedPlaylistsProvider` | `lib/features/playlists/data/providers/playlist_providers.dart` | **Implementado 4.8** | DI [DeleteAllUnsavedPlaylists] |
| `ensurePlaylistForLouvorProvider` | `lib/features/playlists/data/providers/playlist_providers.dart` | **Implementado 4.8** | DI [EnsurePlaylistForLouvor] |
| `loadPlaylistIntoCarouselProvider` | `lib/features/playlists/data/providers/playlist_providers.dart` | **Implementado 4.3** | DI [LoadPlaylistIntoCarousel] + [carouselRepositoryProvider] |
| `generatePlaylistShareUrlProvider` | `lib/features/playlists/data/providers/playlist_providers.dart` | **Implementado 4.4** | DI [GeneratePlaylistShareUrl] |
| `importSharedPlaylistFromUrlProvider` | `lib/features/playlists/data/providers/playlist_providers.dart` | **Implementado 4.4** | DI [ImportSharedPlaylistFromUrl] |
| `ActivePlaylistNotifier` | `lib/features/playlists/presentation/providers/active_playlist_provider.dart` | **Implementado 4.8** | `set` / `clear` — `playlistId` em memória |
| `activePlaylistIdProvider` | `lib/features/playlists/presentation/providers/active_playlist_provider.dart` | **Implementado 4.8** | `NotifierProvider<String?>` — lista em uso no leitor |
| `syncActivePlaylistFromCarousel` | `lib/features/playlists/presentation/providers/active_playlist_sync.dart` | **Implementado 4.8** | Copia `pdfIds` do carousel Isar → playlist ativa |
| `PlaylistsUiState` | `lib/features/playlists/presentation/providers/playlists_ui_provider.dart` | **Implementado 4.8** | `{tab, scrollToPlaylistId?}` — navegação entre abas |
| `playlistsUiProvider` | `lib/features/playlists/presentation/providers/playlists_ui_provider.dart` | **Implementado 4.8** | `selectTab` + scroll pós salvar/favoritar |
| `ResolvedActivePlaylist` | `lib/features/playlists/presentation/providers/playlists_provider.dart` | **Implementado jun/2026** | `{playlistId, nome}` — playlist alinhada ao carousel para share/save |
| `PlaylistsNotifier.resolveActivePlaylistFromCarousel()` | `lib/features/playlists/presentation/providers/playlists_provider.dart` | **Implementado jun/2026 + testes** | Lê carousel Isar → sync/reutiliza/cria rascunho; restaura [activePlaylistIdProvider]; `null` se vazio |
| `PlaylistsNotifier` | `lib/features/playlists/presentation/providers/playlists_provider.dart` | **Implementado 4.2–4.8 + fix share jun/2026** | CRUD + `ensurePlaylistForLouvor` + `resolveActivePlaylistFromCarousel` + `sharePlaylist` + sync carousel |
| `playlistsProvider` | `lib/features/playlists/presentation/providers/playlists_provider.dart` | **Implementado 4.2–4.8** | `NotifierProvider<List<PlaylistViewItem>>` |

### Apresentação (4.2–4.8 ✅)

| API | Arquivo | UC | Estado | Descrição |
|-----|---------|-----|--------|-----------|
| `PlaylistsScreen` | `lib/features/playlists/presentation/pages/playlists_screen.dart` | UC-06/07 | **Implementado 4.2 + 4.4 + 4.8 + polish screen jun/2026** | `TabBar` Não Salvas/Salvas/Favoritas; FAB stack (apagar `small` branco só `unsaved` + importar `extended`); empty state [AppColors.textLight] |
| `PlaylistListTile` | `lib/features/playlists/presentation/widgets/playlist_list_tile.dart` | UC-06/07 | **Implementado 4.2–4.8 + polish UI + debug abrir jun/2026** | Ícone contextual por aba (salvar/estrela); `tab: PlaylistTab`; card + chips modal; falha abrir → [showPlaylistOpenErrorSnackbar] |
| `showSavePlaylistDialog` | `lib/features/playlists/presentation/widgets/save_playlist_dialog.dart` | UC-06 | **Implementado 4.2** | Salvar/renomear com nome editável |
| `showImportPlaylistDialog` | `lib/features/playlists/presentation/widgets/import_playlist_dialog.dart` | UC-07 | **Implementado 4.4 + widget tests** | Colar URL; validação; retorna [ImportPlaylistDialogResult] |
| `ImportPlaylistDialogResult` | `lib/features/playlists/presentation/widgets/import_playlist_dialog.dart` | UC-07 | **Implementado 4.4** | `{sharePdfs, shareName}` — params parseados do diálogo |
| `ShareFn` | `lib/features/playlists/presentation/providers/playlists_provider.dart` | UC-07 | **Implementado 4.4 + fix iOS jun/2026** | Typedef injetável — espelha `Share.share` com `sharePositionOrigin` ([share_plus]) |
| `playlistShareDebugLog` | `lib/features/playlists/presentation/utils/playlist_share_debug_log.dart` | UC-07 | **Implementado jun/2026** | `playlistShareDebugLog(msg)` — log `[UC-07 playlist-share]` só em debug |
| `playlistShareDebugLogError` | idem | UC-07 | **Implementado jun/2026** | `playlistShareDebugLogError(stage, error, stack)` — erro + stack; preenche `playlistShareLastStage`/`playlistShareLastError` |
| `playlistShareDebugErrorSummary` | idem | UC-07 | **Implementado jun/2026** | Resumo `estágio — Tipo: mensagem` para snackbar em debug |
| `showPlaylistShareErrorSnackbar` | idem | UC-07 | **Implementado jun/2026** | [playlistShareError] + resumo em [kDebugMode] (8s) |
| `playlistOpenDebugLog` | `lib/features/playlists/presentation/utils/playlist_open_debug_log.dart` | UC-06 | **Implementado jun/2026** | `playlistOpenDebugLog(msg)` — log `[UC-06 playlist-open]` só em debug |
| `playlistOpenDebugClearLastFailure` | idem | UC-06 | **Implementado jun/2026** | Limpa `playlistOpenLastStage`/`playlistOpenLastError` antes de `_openPdfInReader` |
| `playlistOpenDebugLogError` | idem | UC-06 | **Implementado jun/2026** | `playlistOpenDebugLogError(stage, error, stack)` — exceção + stack; preenche estado de diagnóstico |
| `playlistOpenDebugLogFailure` | idem | UC-06 | **Implementado jun/2026** | `playlistOpenDebugLogFailure(stage, detail)` — falha lógica (ex.: `pdfId` órfão no manifest) |
| `playlistOpenDebugErrorSummary` | idem | UC-06 | **Implementado jun/2026** | Resumo `estágio — Tipo: mensagem` para snackbar em debug |
| `showPlaylistOpenErrorSnackbar` | idem | UC-06 | **Implementado jun/2026** | [pdfActionError] + resumo em [kDebugMode] (8s) |
| `CarouselBarTrailingActions` | `lib/features/carousel/presentation/widgets/carousel_bar_trailing_actions.dart` | UC-05/06/07 | **Implementado 4.2 + 4.4 + 4.8 + fix share jun/2026** | Salvar lista ativa; compartilhar via [resolveActivePlaylistFromCarousel] + `sharePositionOrigin`; limpar rascunho |
| `LouvorCard` | `lib/features/catalog/presentation/widgets/louvor_card.dart` | UC-01/04/05/06 | **Implementado 4.8 + share ⋮ jun/2026** | Toque leitor → `ensurePlaylistForLouvor`; `+` → `addLouvorToActivePlaylist`; menu ⋮ → [sharePdfProvider] |

### Contrato implementado — Fase 4.8 (UC-06) — listas sempre ativas

| Assinatura | Comportamento |
|------------|---------------|
| `EnsurePlaylistForLouvor.call({pdfId, activePlaylistId?})` | Se ativa contém `pdfId` → reload carousel; senão `create(salva: false, [pdfId])` + load |
| `activePlaylistIdProvider` | Memória — definido em `ensurePlaylistForLouvor`, `loadIntoCarousel`, import |
| `syncActivePlaylistFromCarousel(ref)` | Após add/remove/reorder no carousel → `update(pdfIds)` na ativa |
| `PlaylistsNotifier.saveActivePlaylist({nome})` | Salva ativa ou renomeia se já salva; muda aba → Salvas |
| `PlaylistsNotifier.savePlaylist` / `favoritePlaylist` / `unfavoritePlaylist` | Timestamps + troca aba + `scrollToPlaylistId` via [playlistsUiProvider] |
| `PlaylistsNotifier.deleteAllUnsaved` | [DeleteAllUnsavedPlaylists]; limpa ativa/carousel se rascunho |
| `PlaylistsNotifier.clearActiveUnsavedPlaylist` | Delete rascunho ativo + `clear` carousel |
| `PlaylistRepository.getByTab(PlaylistTab)` | Não Salvas: `createdAt` desc; Salvas: `savedAt` desc; Favoritas: `favoritedAt` desc |
| `ImportSharedPlaylistFromUrl` | `create(salva: true, savedAt: now)` |
| `CarouselBarTrailingActions._savePlaylist` | Salva lista ativa (não duplica); CTA `/listas` aba Salvas |
| `PlaylistsNotifier.resolveActivePlaylistFromCarousel()` | Carousel Isar → playlist: reutiliza ativa (sync se divergir), match por `pdfIds`, ou cria rascunho; define [activePlaylistIdProvider] |
| `CarouselBarTrailingActions._sharePlaylist` | `sharePositionOrigin` → [resolveActivePlaylistFromCarousel] → [sharePlaylist]; vazio → [playlistEmptyPdfList]; falha → [showPlaylistShareErrorSnackbar] |
| `CarouselBarTrailingActions._confirmClear` | Só se `!salva`; senão snackbar [playlistClearSavedBlocked] |

### Contrato implementado — Fase 4.2 (UC-06) — CRUD

| Assinatura | Comportamento |
|------------|---------------|
| `PlaylistRepository.create({nome, pdfIds, salva?, savedAt?})` | Gera `playlistId`; `salva` default `true`; `savedAt` se salva |
| `PlaylistRepository.getAll()` | Sem ordenação de aba — UI filtra via `itemsForTab` |
| `UpdatePlaylist.call({pdfIds: []})` | Delega `delete` — playlist removida |
| `CreatePlaylistFromCarousel.call({nome?})` | Lê `CarouselRepository.getOrderedPdfIds()`; lança [EmptyCarouselException] se vazio |
| `PlaylistsNotifier.removePdf` | Confirma se último PDF; `UpdatePlaylist` com lista filtrada; limpa ativa se vazio |

### Contrato implementado — Fase 4.3 (UC-06) — carregar playlist

| Assinatura | Comportamento |
|------------|---------------|
| `LoadPlaylistIntoCarousel.call({required playlistId})` | `PlaylistRepository.getById` → `CarouselRepository.replaceAll(pdfIds)`; lança [PlaylistNotFoundException] se ausente; **não** valida manifest |
| `loadPlaylistIntoCarouselProvider` | DI — injeta [PlaylistRepository] + [CarouselRepository] |
| `PlaylistsNotifier.loadIntoCarousel(playlistId)` | Delega [LoadPlaylistIntoCarousel]; `activePlaylistIdProvider.set(playlistId)`; `carouselLouvoresProvider.notifier.reload()`; `carouselFocusedIndexProvider.reset()`; retorna `false` se playlist ausente ou erro; [playlistOpenDebugLog*] |
| `PlaylistsNotifier.findLouvorByPdfId(pdfId)` | Método do notifier (≠ `findLouvorByPdfId(catalog, pdfId)` do domínio catálogo); lookup O(n) no manifest; `null` se órfão; [playlistOpenDebugLog*] em debug |
| `CarouselLouvoresNotifier.reload()` | Re-fetch Isar + re-enriquece labels — chamado após load externo |
| `PlaylistListTile` menu **Carregar no carousel** | Se `carouselLouvoresProvider` não vazio → [showConfirmDialog] → `loadIntoCarousel` → snackbar [playlistLoaded] |
| `PlaylistListTile` menu **Abrir no leitor** | Delega `_openPdfInReader(pdfIds.first)` — load carousel + resolve + `context.push` |
| `PlaylistListTile` chip expandido **toque** | [CarouselLouvorChip] `onTap` → `_openPdfInReader(pdfId)` — abre o PDF selecionado (não só o 1º); desabilita chip/remove durante loading |
| `PlaylistListTile` chip expandido **remover** | [CarouselLouvorChip] `onRemove` → confirma se último PDF → [PlaylistsNotifier.removePdf] |
| `PlaylistListTile._openPdfInReader(pdfId)` | Privado — confirma substituição carousel → [LoadPlaylistIntoCarousel] → [findLouvorByPdfId] → [ResolvePdfForReader] → [OpenPdfInReader] com `pdfId` → `context.push`; falha genérica → [showPlaylistOpenErrorSnackbar] |
| `PlaylistListTile` lista vazia | Snackbar [playlistEmptyPdfList] antes de chamar use case |
| `playlistOpenDebugLog*` | Instrumentação load/findLouvor/resolve/navegação; snackbar com resumo em debug |

### Regras de negócio (UC-06)

| Regra | Comportamento |
|-------|---------------|
| Nome default | `lista dd/MM/yyyy HH:mm:ss` na criação |
| ID | `timestamp.toRadixString(36)` + sufixo aleatório — compatível PWA |
| Ordenação lista | Por aba (pilha): Não Salvas `createdAt`↓; Salvas `savedAt`↓; Favoritas `favoritedAt`↓ |
| Rascunho auto | Abrir louvor fora da lista ativa → nova playlist `salva: false` |
| Lista ativa | Carousel espelha `pdfIds` da playlist ativa; sync em add/remove/reorder |
| Invariante | `favorita` implica `salva == true` |
| Carousel vazio | Snackbar [playlistEmptyCarousel]; não persiste |
| Último PDF removido | Confirmação → auto-delete da playlist |
| Persistência | [Playlist] em Isar — sobrevive restart |
| PDF órfão | Chip exibe fallback truncado do `pdfId` |
| Substituir carousel | Confirmação se seleção não vazia antes de [LoadPlaylistIntoCarousel] |
| Abrir no leitor | Menu abre 1º PDF; chip expandido abre PDF tocado — ambos carregam playlist no carousel antes → `ResolvePdfForReader` → `/leitor?file=…&pdfId=…`; navegação carousel in-reader se ≥ 2 itens (4.7) |

**Polish UI playlist tile (jun/2026):** [PlaylistListTile] abandona `Card`/`ListTile`/`InputChip` Material genéricos em favor do design system PLPCG (§5.2 / §6). Card: fundo [AppColors.card], borda [AppColors.gold] 2px, [AppColors.shadowMd], `borderRadius` 12. Cabeçalho (`_PlaylistHeader`): estrela dourada quando favorita; título [AppTypography.headline] centralizado; hora derivada de `SavedPlaylist.createdAt` (`HH:mm:ss`); contagem via [playlistPdfCount]; menu `more_horiz` temático; chevron animado (`AnimatedRotation`) indica expansão. Expansão: [AnimatedCrossFade] + divisor dourado; lista vertical de [CarouselLouvorChip] variante `modal` (paridade com modal do carousel e [LouvorCard]). Metadados do chip: lookup seguro no manifest via `louvoresManifestProvider.asData?.value` (fallback parse do `pdfLabel` `"numero — nome"`). Testes: `playlist_list_tile_test.dart` (chip tap via `find.textContaining`).

**Polish UI [PlaylistsScreen] (jun/2026):** remove `TextButton` "Apagar todas" abaixo do [TabBar]. **FAB stack** (`Column` `mainAxisSize: min`): [FloatingActionButton.extended] importar (`heroTag: playlist-import`, `Icons.download`, [playlistImport]) — sempre visível; na aba `PlaylistTab.unsaved`, [FloatingActionButton.small] branco (`backgroundColor: AppColors.textLight`, `foregroundColor: AppColors.title`, `heroTag: playlist-delete-all-unsaved`, `Icons.delete_sweep_outlined`, tooltip [playlistDeleteAllUnsaved]) com `padding: EdgeInsets.only(bottom: 12)` acima do importar. **Estado vazio:** mensagem por aba via `_emptyMessage` ([playlistEmptyUnsaved] / [playlistEmptySaved] / [playlistEmptyFavorites]) com `bodyLarge` + `color: AppColors.textLight` — contraste sobre [AppColors.background] (regra §6: texto interativo em creme; empty state é exceção legível no scaffold marrom).

### Regras de negócio (UC-07)

| Regra | Comportamento |
|-------|---------------|
| Formato URL | `https://plpcg.com/?sharepdfs=id1,id2&sharename=Nome` — chaves [UrlSyncParams.sharePdfs] / [UrlSyncParams.shareName] |
| Origin share | [AppConfig.apiBaseUrl] — compatível com PWA |
| CSV pdfIds | Vírgula; trim; dedupe preservando ordem; [pdfId] Base64 URL-safe sem vírgulas |
| Share lista vazia | Snackbar [playlistEmptyPdfList]; não gera URL |
| Import | Sempre **nova** playlist (não merge por nome); carousel substituído via [LoadPlaylistIntoCarousel] |
| PDF órfão no import | Permitido — labels fallback na UI (mesma regra 4.3) |
| Substituir carousel no import | Confirmação se seleção não vazia (reutiliza strings 4.3) |
| Deep link automático | **Implementado 4.5** — [SyncDeepLinkState] + [DeepLinkListener]; sem confirmação de carousel (paridade PWA) |

### Fluxo implementado Fase 4.2 — salvar e gerenciar

```text
CarouselChips IconButton(save)
  → showSavePlaylistDialog (nome default editável)
  → playlistsProvider.notifier.createFromCarousel(nome)
      → CreatePlaylistFromCarousel → CarouselRepository.getOrderedPdfIds
      → PlaylistRepository.create → PlaylistLocalDatasource (Isar writeTxn)
  → snackbar playlistSaved + action → /listas

PlaylistsScreen (CRUD)
  → playlistsProvider.watch → PlaylistListTile
      → estrela → TogglePlaylistFavorite
      → menu renomear → showSavePlaylistDialog → UpdatePlaylist
      → menu excluir → showConfirmDialog → DeletePlaylist
      → expandir → CarouselLouvorChip.onTap → _openPdfInReader(pdfId) → /leitor
      → expandir → CarouselLouvorChip.onRemove → removePdf → UpdatePlaylist (ou delete se vazio)
```

### Fluxo implementado Fase 4.3 — carregar playlist

```text
PlaylistListTile PopupMenu → Carregar no carousel
  → carouselLouvoresProvider.read — vazio? skip : showConfirmDialog(playlistLoadConfirm*)
  → playlistsProvider.notifier.loadIntoCarousel(playlistId)
      → LoadPlaylistIntoCarousel → PlaylistRepository.getById
      → CarouselRepository.replaceAll(pdfIds) → CarouselLocalDatasource (Isar writeTxn)
      → carouselLouvoresProvider.notifier.reload()
  → snackbar playlistLoaded

PlaylistListTile PopupMenu → Abrir no leitor
  → _openPdfInReader(pdfIds[0])

PlaylistListTile expandir → CarouselLouvorChip.onTap
  → _openPdfInReader(pdfId do chip)

_openPdfInReader(pdfId)
  → playlistOpenDebugClearLastFailure + playlistOpenDebugLog (playlistId, pdfIds)
  → (mesmo load carousel acima)
  → findLouvorByPdfId(pdfId) — null? → showPlaylistOpenErrorSnackbar
  → ResolvePdfForReader → OpenPdfInReader(pdfId) → context.push(/leitor?file=…&pdfId=…)
     (rota /leitor via parentNavigatorKey — fullscreen fora do ShellRoute)
  → falha: playlistOpenDebugLogError / playlistOpenDebugLogFailure → showPlaylistOpenErrorSnackbar
     (em debug: pdfActionError + resumo estágio — detalhe; console [UC-06 playlist-open])
```

**Debug abrir lista (jun/2026 — UC-06):** Paridade com [playlistShareDebugLog*] (UC-07). Estágios instrumentados: `_loadPlaylist`, `loadIntoCarousel`, `findLouvorByPdfId`, `ResolvePdfForReader`, navegação `/leitor`. Falhas de rede/offline continuam com mensagens tipadas ([PdfOfflineUnavailableException], etc.); erros genéricos e `pdfId` órfão usam [showPlaylistOpenErrorSnackbar].

### `playlistOpenDebugLog*` — API pública (UC-06 debug jun/2026)

| API | Arquivo | Descrição |
|-----|---------|-----------|
| `playlistOpenLastStage` | `playlist_open_debug_log.dart` | Estágio da última falha — preenchido em [kDebugMode] |
| `playlistOpenLastError` | idem | Exceção ou detalhe lógico da última falha |
| `playlistOpenDebugClearLastFailure()` | idem | Limpa estado antes de nova tentativa em [PlaylistListTile._openPdfInReader] |
| `playlistOpenDebugLog(message)` | idem | `debugPrint('[UC-06 playlist-open] …')` só em debug |
| `playlistOpenDebugLogError(stage, error, stack)` | idem | Exceção + stack; preenche `playlistOpenLast*` |
| `playlistOpenDebugLogFailure(stage, detail)` | idem | Falha lógica sem exceção (ex.: `pdfId` órfão, `loadIntoCarousel` → `false`) |
| `playlistOpenDebugErrorSummary()` | idem | Resumo `estágio — Tipo: mensagem` para snackbar |
| `showPlaylistOpenErrorSnackbar(context, l10n)` | idem | [pdfActionError] + resumo em debug (8s) |

**Instrumentação em:** [PlaylistsNotifier.loadIntoCarousel], [PlaylistsNotifier.findLouvorByPdfId], [PlaylistListTile._openPdfInReader].

### `ResolvedActivePlaylist` — API pública (UC-07 jun/2026)

| Membro | Tipo | Descrição |
|--------|------|-----------|
| `playlistId` | `String` | ID estável ([SavedPlaylist.playlistId]) |
| `nome` | `String` | Nome exibido no share sheet (`subject` do [Share.share]) |

| Método | Retorno | Descrição |
|--------|---------|-----------|
| `PlaylistsNotifier.resolveActivePlaylistFromCarousel()` | `Future<ResolvedActivePlaylist?>` | Carousel Isar → reutiliza playlist ativa (sync se `pdfIds` divergirem), match por `pdfIds`, ou cria rascunho; restaura [activePlaylistIdProvider]; `null` se carousel vazio |

**Consumidores:** [CarouselBarTrailingActions._sharePlaylist], [PlaylistsNotifier.sharePlaylist]. Testes: `resolve_active_playlist_from_carousel_test.dart`.

**Checkpoint 4.3:** carregar playlist substitui chips globais; confirma se seleção existente; abrir louvor no leitor (menu 1º ou chip específico); restart mantém playlist.

### Subfase MVP — critério 4.2–4.7

| Subfase | Entrega | Critério chave | Status |
|---------|---------|----------------|--------|
| 4.2 | Playlists CRUD | Create/Update/Delete/ToggleFavorite; Isar; PlaylistsScreen; salvar no carousel | **Implementado** |
| 4.3 | Load playlist | LoadPlaylistIntoCarousel; confirma substituição; abrir no leitor (menu ou chip) | **Implementado** |
| 4.4 | Share URL | GeneratePlaylistShareUrl; ImportSharedPlaylistFromUrl; menu Share; FAB import | **Implementado** |
| 4.5 | Deep links | SyncDeepLinkState; DeepLinkListener; import automático; dedupe; snackbar | **Implementado** |
| 4.6 | Folheto | GenerateLeafletFromSelection; captura PNG; share | **Implementado** |
| 4.7 | Carousel no leitor | [readerCarouselPositionProvider] síncrono; prev/next sem wrap; `pdfId` na URL; `context.replace` | **Implementado** |
| 4.8 | Listas sempre ativas | Rascunhos auto; abas; lista ativa; sync carousel; salvar/favoritar com scroll | **Implementado** |

### Fluxo implementado Fase 4.8 — lista sempre ativa

```text
LouvorCard tap (modo leitor)
  → playlistsProvider.notifier.ensurePlaylistForLouvor(pdfId)
      → EnsurePlaylistForLouvor (reutiliza ou create salva:false)
      → activePlaylistIdProvider.set(playlistId)
      → carouselLouvoresProvider.reload()
  → context.push(/leitor?file=…&pdfId=…)
  → CarouselChips visível (barra shell)

CarouselLouvoresNotifier.add/remove
  → _reload() → syncActivePlaylistFromCarousel(ref) → UpdatePlaylist(pdfIds)

CarouselLouvoresNotifier.reorder
  → state otimista (memória) → após carouselReorderPersistDebounce
      → ReorderCarousel (Isar) → syncActivePlaylistFromCarousel → UpdatePlaylist(pdfIds)
  → barra: carouselLouvoresDisplayProvider debounce render (carouselLouvoresDisplayDebounce)
  → modal: carouselLouvoresProvider imediato

PlaylistsScreen TabBar
  → itemsForTab(PlaylistTab) — filtro + sort por timestamp da aba
  → vazio? Center + Text(AppColors.textLight) por aba
  → PlaylistListTile(tab) — ícone salvar/estrela conforme aba
  → save/favorite/unfavorite → playlistsUiProvider.selectTab + scroll

PlaylistsScreen FAB stack (aba Não Salvas)
  → FloatingActionButton.small delete (branco) → showConfirmDialog → deleteAllUnsaved
  → FloatingActionButton.extended import (sempre)

CarouselBarTrailingActions
  → Salvar: saveActivePlaylist(nome) — lista ativa, não cópia
  → Compartilhar: sharePositionOrigin → resolveActivePlaylistFromCarousel → sharePlaylist(…, sharePositionOrigin) — URL PWA
  → Limpar: clearActiveUnsavedPlaylist — só rascunhos
```

### Contrato implementado — Fase 4.4 (UC-07) — share URL

| Assinatura | Comportamento |
|------------|---------------|
| `GeneratePlaylistShareUrl.call({playlistId})` | `getById` → `buildPlaylistShareUrl(origin: AppConfig.apiBaseUrl)`; lança [PlaylistNotFoundException] / [EmptyPlaylistShareException] |
| `ImportSharedPlaylistFromUrl.call({sharePdfs, shareName})` | `parsePdfIdsFromSharePdfs` → `create` → `LoadPlaylistIntoCarousel`; retorna `playlistId`; lança [InvalidSharePlaylistException] |
| `PlaylistsNotifier.sharePlaylist({playlistId, subject, sharePositionOrigin?, share?})` | [GeneratePlaylistShareUrl] → `Share.share(url, subject:, sharePositionOrigin:)`; instrumentação [playlistShareDebugLog*]; retorna `bool` |
| `PlaylistsNotifier.importSharedFromUrl` | Delega import → `_reload()` + `carouselLouvoresProvider.reload()` |
| `PlaylistListTile` menu **Compartilhar** | Bloqueia se `pdfIds` vazio; `sharePositionOrigin` antes de `await`; falha → [showPlaylistShareErrorSnackbar] |
| `CarouselBarTrailingActions` menu **Compartilhar lista** | [resolveActivePlaylistFromCarousel]; vazio → [playlistEmptyPdfList]; `sharePositionOrigin` + share; falha → [showPlaylistShareErrorSnackbar] |
| `playlistShareDebugLog*` | Instrumentação resolve/share; snackbar com resumo em debug |
| `PlaylistsScreen` FAB **Apagar todas** | Aba `unsaved` only; `FloatingActionButton.small` branco; [showConfirmDialog] ([playlistDeleteAllUnsavedTitle]) → [PlaylistsNotifier.deleteAllUnsaved] → snackbar [playlistDeleteAllUnsavedDone] |
| `PlaylistsScreen` FAB **Importar lista** | [showImportPlaylistDialog] → confirma substituição carousel → import → snackbar [playlistImported] |

### Fluxo implementado Fase 4.4 — compartilhar e importar

```text
PlaylistListTile PopupMenu → Compartilhar
  → sharePositionOriginFromContextOrFallback(context)
  → playlistsProvider.notifier.sharePlaylist(playlistId, subject: nome, sharePositionOrigin:)
      → GeneratePlaylistShareUrl → buildPlaylistShareUrl
      → Share.share(url, subject:, sharePositionOrigin:)

CarouselBarTrailingActions → Compartilhar lista
  → sharePositionOriginFromContextOrFallback(context)  // antes de awaits
  → resolveActivePlaylistFromCarousel()
  → null? snackbar playlistEmptyPdfList
  → sharePlaylist(playlistId, subject: nome, sharePositionOrigin:)
      → GeneratePlaylistShareUrl → buildPlaylistShareUrl
      → Share.share(url, subject:, sharePositionOrigin:)

PlaylistsScreen FAB → Importar lista
  → showImportPlaylistDialog (colar URL / clipboard)
  → extractShareParamsFromUserInput
  → carousel não vazio? showConfirmDialog(playlistLoadConfirm*)
  → playlistsProvider.notifier.importSharedFromUrl(sharePdfs, shareName)
      → ImportSharedPlaylistFromUrl → create → LoadPlaylistIntoCarousel
  → snackbar playlistImported
```

**Checkpoint 4.4:** Share gera URL PWA-compatível; import manual persiste playlist + carrega carousel; restart mantém playlist importada.

### Contrato implementado — Fase 4.5 (UC-14 / UC-07 deep link)

| Assinatura | Comportamento |
|------------|---------------|
| `SyncDeepLinkState.call({uri?, queryParams?})` | `parsePlaylistShareParams` → null? `skipped`; delega [ImportSharedPlaylistFromUrl]; retorna [SyncDeepLinkResult] |
| `SyncDeepLinkResult` / `SyncDeepLinkOutcome` | `skipped` / `success(playlistId)` / `invalid` |
| `DeepLinkListener` | `app_links` initial + stream; dedupe fingerprint; pós-import `refreshAfterImport` + `go(/)` + snackbar |
| `PlaylistsNotifier.refreshAfterImport` | `_reload()` + `carouselLouvoresProvider.reload()` após import externo |
| `stripPlaylistShareParams(uri)` | Remove params de share preservando `pesquisa`/filtros |

### Fluxo implementado Fase 4.5 — deep link automático

```text
OS / app_links → DeepLinkListener
  → dedupe fingerprint sharepdfs|sharename
  → SyncDeepLinkState(uri)
      → parsePlaylistShareParams → null? skipped (no-op)
      → ImportSharedPlaylistFromUrl → playlistId
  → playlistsProvider.refreshAfterImport + carousel reload
  → go(buildHomeLocationFromUri(stripPlaylistShareParams(uri)))
  → snackbar playlistImported | playlistImportInvalidUrl
```

**Checkpoint 4.5:** link `https://plpcg.com/?sharepdfs=...&sharename=...` importa sem diálogo; restart persiste; import manual 4.4 inalterado. Ver [deep-links-setup.md](../deep-links-setup.md) para AASA/assetlinks.

## APIs públicas — Domínio (`app_shell`, Fase 4.5)

| API | Arquivo | Estado | Descrição |
|-----|---------|--------|-----------|
| `SyncDeepLinkState` | `lib/features/app_shell/domain/usecases/sync_deep_link_state.dart` | **Implementado 4.5 + testes** | Parse URI → [ImportSharedPlaylistFromUrl]; retorna [SyncDeepLinkResult] |
| `SyncDeepLinkResult` / `SyncDeepLinkOutcome` | idem | **Implementado 4.5** | Resultado tipado do sync deep link |

## APIs públicas — Data layer (`app_shell`, Fase 4.5)

| API | Arquivo | Estado | Descrição |
|-----|---------|--------|-----------|
| `appLinksProvider` | `lib/features/app_shell/data/providers/app_shell_providers.dart` | **Implementado 4.5** | DI [AppLinks] |
| `syncDeepLinkStateProvider` | `lib/features/app_shell/data/providers/app_shell_providers.dart` | **Implementado 4.5** | DI [SyncDeepLinkState] via [importSharedPlaylistFromUrlProvider] |

## APIs públicas — leaflet (Fase 4.6, UC-08)

Folheto da seleção do carousel. Substitui `folhetoUtils.js` + html2canvas da PWA. Captura nativa via `RepaintBoundary.toImage()` (sem pacote `screenshot`). Integração em [CarouselChips] — botão entre salvar e limpar.

**Redesign jun/2026:** paridade visual com folheto PWA (moldura dourada, cabeçalho LOUVORES + data, tabela NÚMERO/NOME, rodapé litúrgico) usando [AppColors] + EB Garamond; melhorias: cantos arredondados, linhas zebradas creme/branco.

**Fix captura jun/2026:** overlay invisível `Opacity(0.01)` + `IgnorePointer` em `(0,0)`; [waitForRepaintBoundary] antes de `toImage()`; `sharePositionOrigin` no iPad.

**Fix renderização jun/2026:** [LeafletContent] envolve o layout em `Material(type: MaterialType.transparency, color: AppColors.background)` e define `TextDecoration.none` nos estilos — evita sublinhação dupla amarela (indicador debug de ancestral `Material` ausente) na captura via [OverlayEntry] fora de [Scaffold].

### Domínio (4.6 ✅)

| API | Arquivo | Estado | Descrição |
|-----|---------|--------|-----------|
| `LeafletEntry` | `lib/features/leaflet/domain/entities/leaflet_entry.dart` | **Implementado 4.6 + redesign** | `{index, numero, nome}` — colunas da tabela |
| `LeafletDocument` | `lib/features/leaflet/domain/entities/leaflet_document.dart` | **Implementado 4.6 + redesign + testes** | `{entries, generatedAt}`; factory `fromCarouselItems` |
| `GenerateLeafletFromSelection` | `lib/features/leaflet/domain/usecases/generate_leaflet_from_selection.dart` | **Implementado 4.6 + redesign + testes** | `call({pdfIdToMetadata?, generatedAt?})` → `LeafletDocument`; lança [EmptyCarouselException] |

### Data layer (4.6 ✅)

| API | Arquivo | Estado | Descrição |
|-----|---------|--------|-----------|
| `generateLeafletFromSelectionProvider` | `lib/features/leaflet/data/providers/leaflet_providers.dart` | **Implementado 4.6** | DI via [carouselRepositoryProvider] |

### Presentation (4.6 ✅)

| API | Arquivo | Estado | Descrição |
|-----|---------|--------|-----------|
| `waitForRepaintBoundary` | `lib/features/leaflet/presentation/utils/leaflet_image_capture.dart` | **Implementado 4.6 + fix jun/2026** | `waitForRepaintBoundary(boundaryKey, {maxFrames})` → [RenderRepaintBoundary]; `StateError` se ausente após retries |
| `captureWidgetToPng` | idem | **Implementado 4.6 + fix jun/2026** | Delega a [waitForRepaintBoundary] → `toImage` → PNG bytes; `pixelRatio` default 3.0 |
| `kLeafletContentWidth` | `lib/features/leaflet/presentation/widgets/leaflet_content.dart` | **Implementado 4.6** | 595px — largura fixa ~A4 portrait |
| `LeafletActionsNotifier` | `lib/features/leaflet/presentation/providers/leaflet_actions_provider.dart` | **Implementado 4.6 + redesign** | `generateAndShare(context)` — [LeafletContentLabels] + overlay + temp PNG + [share_plus] |
| `leafletActionsProvider` | idem | **Implementado 4.6 + redesign** | `NotifierProvider` — orquestra UC-08 na UI |
| `leafletDebugLog` | `lib/features/leaflet/presentation/utils/leaflet_debug_log.dart` | **Implementado jun/2026** | `leafletDebugLog(msg)` — log `[UC-08 leaflet]` só em debug |
| `leafletDebugLogError` | idem | **Implementado jun/2026** | `leafletDebugLogError(stage, error, stack)` — erro + stack no console |
| `leafletDebugErrorSummary` | idem | **Implementado jun/2026** | Resumo `Tipo: mensagem` para snackbar em debug |
| `ShareXFilesFn` / `CaptureWidgetToPngFn` / `GetTemporaryDirectoryFn` | idem | **Implementado 4.6 + fix jun/2026** | Typedefs injetáveis para testes; `ShareXFilesFn` inclui `Rect? sharePositionOrigin` |
| `leafletWeekdayName` / `formatLeafletHeaderDate` | `lib/features/leaflet/presentation/utils/leaflet_header_date.dart` | **Implementado redesign jun/2026** | Cabeçalho com dia da semana + `dd/MM/yyyy` |
| `LeafletContentLabels` | `lib/features/leaflet/presentation/widgets/leaflet_content_labels.dart` | **Implementado redesign jun/2026** | `fromL10n(l10n, generatedAt)` — strings para captura |

### Apresentação (4.6 ✅)

| API | Arquivo | UC | Estado | Descrição |
|-----|---------|-----|--------|-----------|
| `LeafletContent` | `lib/features/leaflet/presentation/widgets/leaflet_content.dart` | UC-08 | **Implementado redesign jun/2026 + fix render jun/2026 + widget tests** | Moldura dourada, tabela número/nome, rodapé; raiz `Material(transparency)`; requer `document` + `labels` |

### Fluxo implementado Fase 4.6 — gerar folheto

```text
CarouselChips IconButton(description_outlined)
  → leafletActionsProvider.notifier.generateAndShare(context)
      → sharePositionOrigin = RenderBox do contexto (antes de awaits)
      → GenerateLeafletFromSelection (carousel ordenado + numero/nome)
      → LeafletContentLabels.fromL10n(l10n, document.generatedAt)
      → OverlayEntry invisível (0,0) + Opacity(0.01) + LeafletContent(document, labels) [Material raiz] + RepaintBoundary
      → waitForRepaintBoundary → captureWidgetToPng → temp PNG
      → Share.shareXFiles([XFile png], sharePositionOrigin: …)
```

**l10n:** ver [Chaves UC-08](#chaves-uc-08-fase-46--folheto) abaixo.

### Contrato implementado — Fase 4.6 (UC-08)

| Assinatura | Comportamento |
|------------|---------------|
| `GenerateLeafletFromSelection.call({pdfIdToMetadata?, generatedAt?})` | `getOrderedItems` → `LeafletDocument.fromCarouselItems`; lança [EmptyCarouselException] se vazio |
| `LeafletDocument.fromCarouselItems(items, {generatedAt?})` | Ordena por `sortOrder`; `LeafletEntry` com `numero`/`nome`; `generatedAt` default `DateTime.now()` |
| `LeafletContentLabels.fromL10n(l10n, generatedAt)` | Resolve cabeçalho, colunas, rodapé e data formatada |
| `LeafletContent(document, labels)` | Layout PLPCG para captura PNG — EB Garamond + [AppColors]; raiz `Material(transparency)` obrigatória para overlay off-screen |
| `leafletWeekdayName(l10n, date)` | `DateTime.weekday` → chave `leafletWeekday*` localizada |
| `formatLeafletHeaderDate(l10n, date)` | `{weekday} dd/MM/yyyy` — cabeçalho direito do folheto |
| `leafletDebugLog*` | Instrumentação por estágio da captura/share; snackbar com resumo em debug |
| `waitForRepaintBoundary(boundaryKey, {maxFrames})` | Até 10 `endOfFrame`; retorna boundary quando `!debugNeedsPaint`; `StateError` se ausente |
| `captureWidgetToPng(boundaryKey, {pixelRatio})` | [waitForRepaintBoundary] → `toImage` → PNG; `StateError` se boundary ausente ou encode falhar |
| `LeafletActionsNotifier.generateAndShare(context, {shareXFiles?, getTemporaryDirectory?, capture?})` | Use case → overlay invisível → temp `folheto-plpcg.png` → `Share.shareXFiles` com `sharePositionOrigin`; retorna `bool` |
| `CarouselChips` botão folheto | `Icons.description_outlined`; loading inline; desabilitado durante geração |

### Regras de negócio (UC-08)

| Regra | Comportamento |
|-------|---------------|
| Pré-condição | Louvores no carousel (UC-05) — botão só visível com seleção não vazia |
| Ordem | Reflete `sortOrder` do carousel após drag-and-drop |
| Layout | Moldura dourada; cabeçalho LOUVORES + data; tabela NÚMERO/NOME (nome em CAIXA ALTA); rodapé litúrgico |
| Captura | Overlay invisível `(0,0)` + `Opacity(0.01)` + `IgnorePointer`; [LeafletContent] com `Material` raiz; [waitForRepaintBoundary] antes de `toImage()` |
| Saída | PNG via share sheet nativo (`image/png`); `sharePositionOrigin` no iPad |
| Seleção vazia | [EmptyCarouselException] → snackbar `playlistEmptyCarousel` |
| Falha captura/share | Snackbar `leafletGenerateFailed`; em debug: resumo do erro via [leafletDebugErrorSummary] |
| Tipografia/cores | EB Garamond ([AppTypography.garamondFamily]); tokens [AppColors] — paridade PWA+ |

## APIs públicas — carousel no leitor (Fase 4.7, UC-11)

Navegação entre louvores da seleção do carousel **sem sair** do leitor. UI em [CarouselChips] (barra 2 do [ShellScaffold], inclusive rota `/leitor`); [PdfReaderScreen] renderiza só a barra 3 + PDF e publica params em [readerRouteParamsProvider]. Equivalente ao `CarouselNavigator.svelte` da PWA. Requer UC-05 (carousel) e UC-04/3.4 (abertura local-first). [UrlSyncParams.pdfId] identifica o louvor atual — lido pelo carousel via provider (preferencial) ou URL.

### Domínio (4.7 ✅)

| API | Arquivo | Estado | Descrição |
|-----|---------|--------|-----------|
| `CarouselReaderPosition` | `lib/features/pdf_reader/domain/entities/carousel_reader_position.dart` | **Implementado 4.7** | `{currentIndex, total, previousPdfId, nextPdfId}` — índice 1-based; `canGoPrevious`/`canGoNext` derivados; **sem wrap** nas extremidades |
| `CarouselReaderDirection` | idem | **Implementado 4.7** | `previous` \| `next` |
| `NavigateCarouselInReader` | `lib/features/pdf_reader/domain/usecases/navigate_carousel_in_reader.dart` | **Implementado 4.7 + testes** | `getPosition({currentPdfId})` → posição ou `null` (Isar); `resolveTarget` — usado por `navigateAdjacent` |

### Data layer (4.7 ✅)

| API | Arquivo | Estado | Descrição |
|-----|---------|--------|-----------|
| `navigateCarouselInReaderProvider` | `lib/features/pdf_reader/data/providers/pdf_reader_providers.dart` | **Implementado 4.7** | DI via [carouselRepositoryProvider] |

### Presentation (4.7 ✅ + fix nav jun/2026)

| API | Arquivo | Estado | Descrição |
|-----|---------|--------|-----------|
| `ReaderRouteParamsNotifier` | `lib/features/pdf_reader/presentation/providers/reader_route_params_provider.dart` | **Implementado 4.7 fix v2** | `update(queryParams)` publica mapa imutável; `clear()` ao sair de `/leitor` |
| `readerRouteParamsProvider` | idem | **Implementado 4.7 fix v2** | Ponte shell ↔ leitor — [CarouselChips] lê `pdfId`/`titulo` sem depender só de `GoRouterState` no ancestral |
| `readerCarouselPositionProvider` | `lib/features/pdf_reader/presentation/providers/reader_carousel_position_provider.dart` | **Implementado 4.7 + fix nav** | `Provider.family<CarouselReaderPosition?, String>` — deriva de [carouselLouvoresProvider] (síncrono); `null` só se seleção vazia; fallback [carouselFocusedIndexProvider] se `pdfId` ∉ seleção |
| `ReaderCarouselActionsNotifier` | `lib/features/pdf_reader/presentation/providers/reader_carousel_actions_provider.dart` | **Implementado 4.7 + carousel abrir** | `navigateToPdfId({targetPdfId})` → rota `/leitor` ou `null`; `navigateAdjacent` via [NavigateCarouselInReader] |
| `readerCarouselActionsProvider` | idem | **Implementado 4.7** | `NotifierProvider` — orquestra resolve + rota para troca in-reader |
| `PdfReaderScreen` | `lib/features/pdf_reader/presentation/pages/pdf_reader_screen.dart` | **Implementado 4.7 + 2.3 + 2.4** | `_schedulePublishRouteParams` + `_scheduleApplyInitialFit`; `ref.listen(readerFullscreenProvider)`; [_ReaderScaffold] barra 3 + PDF; botão fullscreen |
| `CarouselChips` (modo leitor) | `lib/features/carousel/presentation/widgets/carousel_chips.dart` | **Implementado 4.7 fix v2** | `_buildReaderMode`; `_onReaderRouteChanged` sincroniza foco e reseta loading; modal sempre abre |
| `CarouselNavigatorBar` | `lib/features/carousel/presentation/widgets/carousel_navigator_bar.dart` | **Implementado 4.7 fix v2 + polish ícones** | `onOpenList` ignora `loading`; ícones via [carouselBarIconButtonStyle]; `Row` largura total (sem overflow de botões) |
| `_ReaderScaffold` | `lib/features/pdf_reader/presentation/pages/pdf_reader_screen.dart` | **Implementado UI 3 barras + 2.4 + indicador estável** | Barra 3 condicional; [PdfReaderPageIndicator]; PDF em `Expanded`; FAB `fullscreen_exit` em `Opacity(0.25)`; oculta título quando carousel tem itens |
| `ReaderFullscreenNotifier` | `lib/features/pdf_reader/presentation/providers/reader_fullscreen_provider.dart` | **Implementado 2.4** | `toggle()` / `exit()`; controla `SystemChrome` + estado das barras |
| `readerFullscreenProvider` | idem | **Implementado 2.4** | `NotifierProvider<bool>` consumido por [ShellScaffold] e [PdfReaderScreen] |
| `toggleReaderFullscreenProvider` | idem | **Implementado 2.4** | DI [ToggleReaderFullscreen] |

### Fluxo implementado Fase 4.7 — navegar carousel no leitor

```text
LouvorCard tap / PlaylistListTile / CarouselChips chip ou modal
  → ResolvePdfForReader → OpenPdfInReader(pdfPath, pdfId, titulo)
  → context.push(`/leitor?file=…&pdfId=…&titulo=…`)
  (carousel: via openCarouselPdfInReader → navigateToPdfId)

PdfReaderScreen (post-frame)
  → readerRouteParamsProvider.notifier.update(queryParams)

ShellScaffold em /leitor
  → CarouselChips: pdfId ← readerRouteParamsProvider | URL | índice focado
  → _buildReaderMode(pdfId)
      → readerCarouselPositionProvider(pdfId)  // síncrono
      → CarouselNavigatorBar (setas + modal + trailing)

Tap ◀ ou ▶ (leitor)
  → position.previousPdfId | nextPdfId
  → focusPdfId(target)
  → readerCarouselActionsProvider.notifier.navigateToPdfId(targetPdfId)
      → findLouvorByPdfId → ResolvePdfForReader → OpenPdfInReader
  → context.replace(location)

Modal — tap outro louvor (leitor)
  → openCarouselPdfInReader → context.replace(location)
```

**l10n:** ver [Chaves UC-11 (4.7)](#chaves-uc-11-fase-47--carousel-no-leitor) abaixo.

### Contrato implementado — Fase 4.7 (UC-11)

| Assinatura | Comportamento |
|------------|---------------|
| `NavigateCarouselInReader.getPosition({currentPdfId})` | `CarouselRepository.getOrderedPdfIds()`; `null` se vazio ou id ausente; prev/next `null` nas extremidades (sem wrap) |
| `NavigateCarouselInReader.resolveTarget({currentPdfId, direction})` | Delega `getPosition`; retorna `previousPdfId` ou `nextPdfId` |
| `ReaderRouteParamsNotifier.update(queryParams)` | Mapa imutável; publicado post-frame por [PdfReaderScreen]; limpo por [CarouselChips] ao sair de `/leitor` |
| `readerRouteParamsProvider` | `Map<String, String>` reativo — chaves [UrlSyncParams] (`file`, `pdfId`, `titulo`, …) |
| `readerCarouselPositionProvider(currentPdfId)` | `watch(carouselLouvoresProvider)`; índice por `pdfId` ou fallback [carouselFocusedIndexProvider]; `null` se seleção vazia |
| `ReaderCarouselActionsNotifier.navigateToPdfId({targetPdfId})` | [findLouvorByPdfId] → [ResolvePdfForReader] → [OpenPdfInReader]; base de [openCarouselPdfInReader] e setas no leitor |
| `ReaderCarouselActionsNotifier.navigateAdjacent(...)` | `resolveTarget` → delega [navigateToPdfId]; legado — UI do leitor usa `navigateToPdfId` direto com ids da posição |
| `CarouselChips._navigateCarouselInReader({direction, position})` | Lê `previousPdfId`/`nextPdfId` da posição; `focusPdfId`; `navigateToPdfId` → `context.replace`; snackbar erros offline |
| `CarouselChips._replaceReaderWithCarouselItem` | Modal no leitor — `openCarouselPdfInReader` + `replace` |
| `CarouselChips._onReaderRouteChanged` | Post-frame: `focusPdfId`; reseta `_carouselNavLoading`/`_openingReader` ao mudar `pdfId`; `clear()` do provider ao sair |
| `buildReaderLocation({file, pdfId?, ...})` | Inclui `pdfId` na query quando informado |
| `PdfReaderScreen._schedulePublishRouteParams` | Post-frame → [readerRouteParamsProvider]; evita mutar provider em `initState` |
| `PdfReaderScreen` | `showTitle: !carouselHasItems` na barra 3; carousel na barra 2 via shell |
| `CarouselNavigatorBar` (leitor) | Variante `topBar`; sem `onChipTap`; `loading` desabilita setas; lista sempre habilitada |

### Regras de negócio (UC-11 — carousel no leitor)

| Regra | Comportamento |
|-------|---------------|
| Pré-condição | Carousel não vazio; em `/leitor`, [CarouselChips] entra em modo leitor via [readerRouteParamsProvider], URL ou índice focado |
| Setas | Visíveis quando `canGoPrevious`/`canGoNext`; ocultas na extremidade (sem wrap) |
| `pdfId` fora da seleção | Posição calculada pelo índice focado — setas ainda navegam itens do carousel |
| Troca de documento | `context.replace` — histórico não acumula PDFs intermediários |
| Offline | Cada troca passa por [ResolvePdfForReader]; erro → snackbar; permanece no PDF atual |
| Carousel alterado | [readerCarouselPositionProvider] reage via [carouselLouvoresProvider]; remove item atual → navega para vizinho ou `pop` |
| Um item na seleção | Barra visível; setas ocultas (`canGoPrevious` e `canGoNext` falsos) |

## APIs públicas — Data layer (catalog)

| API | Arquivo | Estado | Descrição |
|-----|---------|--------|-----------|
| `CatalogRemoteDatasource` | `lib/features/catalog/data/datasources/catalog_remote_datasource.dart` | **Implementado** | `fetchManifest()` — valida JSON; `fetchChecksum()` — 200/204 |
| `CatalogLocalDatasource` | `lib/features/catalog/data/datasources/catalog_local_datasource.dart` | **Implementado + testes** | `saveLouvores` / `loadLouvores`; `loadPdfIdToCategoriaMap` — UC-10 stats offline |
| `LouvorToCache` / `LouvorCacheToEntity` | `lib/features/catalog/data/mappers/louvor_cache_mapper.dart` | **Implementado** | Mapper `Louvor` ↔ `LouvorCache`; recompute tokens via `fromManifest` |
| `CatalogRepositoryImpl` | `lib/features/catalog/data/repositories/catalog_repository_impl.dart` | **Implementado + testes** | `loadManifest` remoto → Isar com fallback; `forceRefreshManifest` remoto obrigatório sem fallback |

## APIs públicas — Data layer (pdf_opening, Fase 2.5)

| API | Arquivo | Estado | Descrição |
|-----|---------|--------|-----------|
| `PdfBytesDatasource` | `lib/features/pdf_opening/data/datasources/pdf_bytes_datasource.dart` | **Implementado + testes** | `fetchBytes(filePath)` — remoto/asset/local via [PdfSourceResolver]; compartilhado com [FetchAndStorePdf] (3.3) e [PdfxViewerAdapter] |

## APIs públicas — Data layer (pdf_reader, Fase 2.2–2.5)

| API | Arquivo | Estado | Descrição |
|-----|---------|--------|-----------|
| `PdfSourceKind` | `lib/features/pdf_reader/data/utils/pdf_source_resolver.dart` | **Implementado** | Enum: `remoteUrl`, `asset`, `localFile` |
| `ResolvedPdfSource` | `lib/features/pdf_reader/data/utils/pdf_source_resolver.dart` | **Implementado** | Par `{kind, value}` resolvido a partir do query `file` |
| `PdfSourceResolver` | `lib/features/pdf_reader/data/utils/pdf_source_resolver.dart` | **Implementado + testes** | Resolve `file` → URL remota, asset Flutter (`asset:`) ou path local |
| `PdfxViewerAdapter` | `lib/features/pdf_reader/data/adapters/pdfx_viewer_adapter.dart` | **Implementado + testes** | Adaptador PDFx (ADR-002); `openDocument` factory; navegação/fit via [PdfReaderControllerPort] |
| `PdfxViewerAdapter.bindController` | `lib/features/pdf_reader/data/adapters/pdfx_viewer_adapter.dart` | **Implementado + testes** | Liga controller da sessão ativa para [SetZoomAndFitMode] / [NavigatePdfPages] |
| `PdfxViewerAdapter.unbindController` | `lib/features/pdf_reader/data/adapters/pdfx_viewer_adapter.dart` | **Implementado + testes** | Desliga se `identical`; chamado no `ref.onDispose` de [pdfReaderSessionProvider] |
| `ReaderPreferencesDatasource` | `lib/features/pdf_reader/data/datasources/reader_preferences_datasource.dart` | **Implementado + testes** | Lê/grava fit e nav via [sharedPreferencesProvider]; defaults PWA |

**Asset de teste:** `assets/fixtures/sample.pdf` — registrado em `pubspec.yaml`; URL manual `asset:fixtures/sample.pdf`.

## APIs públicas — Data layer (offline, Fase 3.1–3.7)

| API | Arquivo | Estado | Descrição |
|-----|---------|--------|-----------|
| `GetApplicationDocumentsDirectoryFn` | `offline/data/datasources/pdf_local_store.dart` | **Implementado 3.1** | Typedef para injeção de diretório em testes |
| `PdfLocalStore` | `offline/data/datasources/pdf_local_store.dart` | **Implementado + testes** | `rootDirectory`, `writeAtomic`, `exists`, `delete`, `deleteTree`, `listOrphans` |
| `OfflinePdfLocalDatasource` | `offline/data/datasources/offline_pdf_local_datasource.dart` | **Implementado 3.1** | `findByPdfId`, `put`, `deleteByPdfId`, `countByCategory`, `findAll` |
| `OfflinePdfRepositoryImpl` | `offline/data/repositories/offline_pdf_repository_impl.dart` | **Implementado + testes** | Implementação de [OfflinePdfRepository]; `clearAll`, `removeIndexEntries`, `listAll` |
| `FetchAndStorePdf` | `offline/domain/usecases/fetch_and_store_pdf.dart` | **Implementado 3.3 + testes** | `call({pdfId, remotePath, category?})` — fetch + upsert; retry [OfflineConfig.maxRetryAttempts] |
| `DownloadOfflinePackages` | `offline/domain/usecases/download_offline_packages.dart` | **Implementado 3.5 + testes** | Orquestrador bulk UC-09 |
| `ReconcileOfflineIndex` | `offline/domain/usecases/reconcile_offline_index.dart` | **Implementado 3.5 + 3.6 + benchmark** | Reconcile escopado ou global |
| `GetOfflineStatsByCategory` | `offline/domain/usecases/get_offline_stats_by_category.dart` | **Implementado 3.6 + jun/2026** | Stats material UI + faltantes manifest |
| `DownloadMissingPdfs` | `offline/domain/usecases/download_missing_pdfs.dart` | **Implementado 3.6 + jun/2026** | Pré-filtra faltantes; fetch só misses |
| `OfflineMaterialResolver` | `offline/domain/utils/offline_material_resolver.dart` | **Implementado jun/2026** | `toUiMaterial(categoria)` |
| `OfflineAvailableStore` | `offline/data/datasources/offline_available_store.dart` | **Implementado jun/2026 + testes** | `TRUE`/`FALSE` em [StorageKeys.offlineAvailable] |
| `ClearOfflineCache` | `offline/domain/usecases/clear_offline_cache.dart` | **Implementado 3.6 + jun/2026 + testes** | Reset índice + tree + checkpoint + `OFFLINE_AVAILABLE=FALSE` |
| `MigrateOfflineStorage` | `offline/domain/usecases/migrate_offline_storage.dart` | **Implementado 3.6 + testes** | Migração versão prefs |
| `ReconcilePathEntry` | `offline/data/utils/reconcile_path_validator.dart` | **Implementado 3.6** | Payload isolate |
| `validatePdfPathsChunk` | `offline/data/utils/reconcile_path_validator.dart` | **Implementado 3.6** | Validação disco em isolate |
| `pdfLocalStoreProvider` | `offline/data/providers/offline_providers.dart` | **Implementado 3.1** | `Provider<PdfLocalStore>` |
| `offlinePdfLocalDatasourceProvider` | `offline/data/providers/offline_providers.dart` | **Implementado 3.1** | `Provider<OfflinePdfLocalDatasource>` via [isarProvider] |
| `offlinePdfRepositoryProvider` | `offline/data/providers/offline_providers.dart` | **Implementado 3.1** | `Provider<OfflinePdfRepository>` — entrada para 3.2+ |
| `fetchAndStorePdfProvider` | `offline/data/providers/offline_providers.dart` | **Implementado 3.3** | `Provider<FetchAndStorePdf>` — [PdfBytesDatasource] + [OfflinePdfRepository] |
| `resolvePdfForReaderProvider` | `offline/data/providers/offline_providers.dart` | **Implementado 3.2 + 3.4** | `Provider<ResolvePdfForReader>` — consumido por [LouvorCard] |
| `validatePdfAvailabilityProvider` | `offline/data/providers/offline_providers.dart` | **Implementado 3.4** | `Provider<ValidatePdfAvailability>` — DI em offline (evita ciclo com pdf_opening) |
| `reconcileOfflineIndexProvider` | `offline/data/providers/offline_providers.dart` | **Implementado 3.5 + 3.6** | DI [ReconcileOfflineIndex] |
| `downloadOfflinePackagesProvider` | `offline/data/providers/offline_providers.dart` | **Implementado 3.5** | DI bulk UC-09 |
| `getOfflineStatsByCategoryProvider` | `offline/data/providers/offline_providers.dart` | **Implementado 3.6 + jun/2026** | DI + catalog + manifest |
| `downloadMissingPdfsProvider` | `offline/data/providers/offline_providers.dart` | **Implementado 3.6** | DI [DownloadMissingPdfs] |
| `offlineAvailableStoreProvider` | `offline/data/providers/offline_providers.dart` | **Implementado jun/2026** | DI [OfflineAvailableStore] |
| `clearOfflineCacheProvider` | `offline/data/providers/offline_providers.dart` | **Implementado 3.6** | DI [ClearOfflineCache] |
| `migrateOfflineStorageProvider` | `offline/data/providers/offline_providers.dart` | **Implementado 3.6** | DI [MigrateOfflineStorage] |
| `offlineReconcileProvider` | `offline/presentation/providers/offline_reconcile_provider.dart` | **Implementado 3.6** | Notifier reconcile global UC-10 |
| `offlineBulkDownloadProvider` | `offline/presentation/providers/offline_bulk_download_provider.dart` | **Implementado 3.5 + 3.7 + jun/2026** | Notifier bulk UC-09; `markConfigured` ao concluir |
| `offlineModeProvider` | `offline/presentation/providers/offline_mode_provider.dart` | **Implementado jun/2026** | Gate UI UC-09 vs UC-10 |
| `offlineCacheStatusProvider` | `offline/presentation/providers/offline_cache_status_provider.dart` | **Implementado 3.7 + jun/2026** | `refresh` / `refreshAll`; stats material + faltantes |
| `offlineMissingDownloadProvider` | `offline/presentation/providers/offline_missing_download_provider.dart` | **Implementado 3.7 + jun/2026** | Progresso sobre faltantes |

**Diretório de produção:** `{ApplicationDocumentsDirectory}/plpcg_pdfs/` ([OfflineConfig.pdfStorageSubdir]).

**Retry on-demand:** [OfflineConfig.maxRetryAttempts] = 3; backoff [OfflineConfig.retryBackoffBase] × attempt.

### Fluxo Fase 1.1 (LoadLouvoresManifest)

```text
ColdiguiApp.listen(louvoresManifestProvider)  // boot; sem rebuild do router
  → LoadLouvoresManifest.call()
  → CatalogRepositoryImpl.loadManifest()
      → CatalogRemoteDatasource.fetchManifest()  [sucesso → cacheManifest]
      → CatalogLocalDatasource.loadLouvores()    [fallback offline]
```

### Fluxo Fase 1.2 (SearchLouvorByNumberOrText / UC-01)

```text
SearchBar.onChanged → homeSearchRawQueryProvider
  → HomeSearchDebouncer (300ms) → homeSearchDebouncedQueryProvider
  → SearchLouvorByNumberOrText(catalog, query) → homeSearchResultsProvider
  → homeSearchGroupResultsProvider → GroupLouvoresByMaterial
  → HomeScreen SliverList<LouvorGroupCard> (chips agrupados — paridade /listas)

SearchLouvorByNumberOrText (texto, após número exato)
  → LouvorSearchTokens.tokenize(query)
  → LouvorSearchTokens.matchesText(
       contentTokens: louvor.searchContentTokens,
       compactContent: louvor.searchCompactContent,
       query, queryTokens)
     • tokens: todos os tokens da query em searchContentTokens
       (hífens/pontuação como separadores — ex. buscar-me-eis)
     • compacto: query sem separadores, len≥3, substring de searchCompactContent
       (ex. buscarmeeis → Buscar-me-eis)

SearchBar botão limpar (Icons.close)
  → controller.clear() + homeSearchRawQueryProvider = ''
  → FocusNode.requestFocus() (teclado permanece aberto)
  → mesmo pipeline debounce acima

homeSearchDebouncedQueryProvider
  → HomeSearchUrlDebouncer (500ms) → homeSearchUrlSyncQueryProvider
  → HomeScreen ref.listen → GoRouter ?pesquisa=
```

### Contrato implementado — boot e lifecycle (homologação iOS)

| Método / evento | Comportamento |
|-----------------|---------------|
| `ColdiguiApp.build` → `ref.listen(louvoresManifestProvider)` | Dispara fetch no boot **sem** `ref.watch` — evita rebuild de `MaterialApp.router` quando manifest (~4600 itens) conclui |
| `ColdiguiApp.build` → `AppConfig.isApiBaseUrlMissing` | Tela diagnóstico `_MissingApiBaseUrlScreen` (sem router) |
| `MaterialApp` / `MaterialApp.router` | `debugShowCheckedModeBanner: false` — oculta selo DEBUG no canto superior direito (debug e release) |
| `HomeScreen.initState` → `addPostFrameCallback` | `_hydrateFromUrl()` uma vez — busca + filtros da URL |
| `HomeScreen.didUpdateWidget` | Só re-hidrata se `initialSearchQuery` / materiais / arranjo mudaram; **post-frame** antes de `setImmediate` / `hydrateFromUrl` |
| `HomeScreen._syncUrlFromState` | `ref.listen` na Home → post-frame → `_applyUrlSyncFromState` → `goRouter.go` |
| Manifest async completa | Rebuild seguro; sem modificar provider durante `build`/`didUpdateWidget` |

**Bugs corrigidos:** (1) manifest ~4627 itens → `ref.watch` no root → rebuild router / tela branca; (2) `didUpdateWidget` síncrono → `Tried to modify a provider while the widget tree was building`.

### Fluxo Fase 1.3 (FilterByMaterialAndArranjo / UC-02)

```text
CategoryFilters / ClassificationFilters → catalogFiltersProvider
  → FilterByMaterialAndArranjo(searched, materiais, arranjos)
  → homeSearchResultsProvider (após UC-01)
  → homeSearchGroupResultsProvider → LouvorGroupCard

catalogFiltersProvider + homeSearchUrlSyncQueryProvider
  → HomeScreen ref.listen → buildHomeLocation → GoRouter ?materiais=&arranjo=
```

### Referência — APIs Fase 1.3 (UC-02)

**Use case**

| Assinatura | Comportamento |
|------------|---------------|
| `FilterByMaterialAndArranjo.call(louvores, {selectedMaterials, selectedArranjos})` | Filtro síncrono in-memory; `selectedMaterials` vazio → `[]`; `selectedArranjos` vazio → todos os arranjos |

**Constantes e utilitários**

| API | Métodos principais |
|-----|-------------------|
| `CatalogMaterials` | `uiMaterials`, `defaultSelected`, `expandMaterial()`, `expandMaterials()`, `parseFromUrl()`, `serializeForUrl()`, `isDefaultSelection()` |
| `LouvorClassification` | `baseClassification()`, `displayLabel()`, `specialArrangement()`, `parseArranjosFromUrl()`, `serializeArranjosForUrl()`, `parseSpecialArrangementsFromUrl()`, `serializeSpecialArrangementsForUrl()`, `specialArrangementPadrao` |
| `LouvorMaterialIcons` | `forCategory(categoria)` |
| `buildHomeLocation({pesquisa, materiais, arranjo})` | Retorna `/` ou `/?…`; omite params padrão |
| `buildHomeLocationFromUri(uri)` | Normaliza URI atual para comparação no sync |

**Contrato URL (Home)**

| Param | Chave | Padrão (omitido) | Exemplo |
|-------|-------|------------------|---------|
| Busca | `pesquisa` | vazio | `/?pesquisa=aleluia` |
| Materiais | `materiais` | todos selecionados | `/?materiais=Partitura,Cifra` |
| Arranjo | `arranjo` | vazio (sem filtro) | `/?arranjo=ColAdultos` |

Regra Cifra: chip UI `"Cifra"` expande para categorias `"Cifra"`, `"Cifra nível I"`, `"Cifra nível II"` em `Louvor.categoria`.

**Providers e estado**

| API | Tipo | Responsabilidade |
|-----|------|------------------|
| `filterByMaterialAndArranjoProvider` | `Provider` | DI do use case UC-02 |
| `catalogFiltersProvider` | `NotifierProvider<CatalogFiltersNotifier, CatalogFilterState>` | Seleção material/arranjo |
| `catalogAvailableArranjosProvider` | `Provider<Set<String>>` | Classificações base do manifest |
| `CatalogFilterState` | classe | `defaults()`, `materiaisUrlValue`, `arranjoUrlValue` |
| `CatalogFiltersNotifier` | `Notifier` | `hydrateFromUrl()`, `toggleMaterial()`, `toggleArranjo()` |

**Widgets**

| Widget | Provider observado |
|--------|-------------------|
| `CategoryFilters` | `catalogFiltersProvider.selectedMaterials` |
| `ClassificationFilters` | `catalogAvailableArranjosProvider` + `selectedArranjos` |

## APIs públicas — Providers (catalog)

| API | Arquivo | Estado | Descrição |
|-----|---------|--------|-----------|
| `catalogRemoteDatasourceProvider` | `lib/features/catalog/data/providers/catalog_providers.dart` | **Implementado** | Injeta [Dio] remoto |
| `catalogLocalDatasourceProvider` | `lib/features/catalog/data/providers/catalog_providers.dart` | **Implementado** | Injeta [Isar] local |
| `catalogRepositoryProvider` | `lib/features/catalog/data/providers/catalog_providers.dart` | **Implementado** | [CatalogRepositoryImpl] |
| `loadLouvoresManifestProvider` | `lib/features/catalog/data/providers/catalog_providers.dart` | **Implementado** | DI use case UC-12 boot |
| `forceRefreshCatalogProvider` | `lib/features/catalog/data/providers/catalog_providers.dart` | **Implementado** | DI [ForceRefreshCatalog] UC-12 manual |
| `searchLouvorByNumberOrTextProvider` | `lib/features/catalog/data/providers/catalog_providers.dart` | **Implementado** | DI use case UC-01 |
| `filterByMaterialAndArranjoProvider` | `lib/features/catalog/data/providers/catalog_providers.dart` | **Implementado** | DI use case UC-02 |
| `CatalogFilterState` | `lib/features/catalog/presentation/providers/catalog_filters_provider.dart` | **Implementado** | Estado imutável; `defaults()`, getters URL |
| `CatalogFiltersNotifier` | `lib/features/catalog/presentation/providers/catalog_filters_provider.dart` | **Implementado** | `hydrateFromUrl()`, `toggleMaterial()`, `toggleArranjo()` |
| `catalogFiltersProvider` | `lib/features/catalog/presentation/providers/catalog_filters_provider.dart` | **Implementado** | `NotifierProvider` UC-02 |
| `catalogAvailableArranjosProvider` | `lib/features/catalog/presentation/providers/catalog_filters_provider.dart` | **Implementado** | Classificações base do manifest (chips dinâmicos) |
| `louvoresManifestProvider` | `lib/features/catalog/presentation/providers/louvores_manifest_provider.dart` | **Implementado** | `FutureProvider<List<Louvor>>`; boot via `ref.listen` em [ColdiguiApp]; invalidado após refresh manual |
| `CatalogRefreshStatus` | `lib/features/catalog/presentation/providers/catalog_refresh_provider.dart` | **Implementado** | Enum: `idle`, `loading`, `error` |
| `CatalogRefreshState` | `lib/features/catalog/presentation/providers/catalog_refresh_provider.dart` | **Implementado** | `idle()` / `loading()` / `error(message)`; getters `isLoading`, `isIdle`, `hasError` |
| `CatalogRefreshNotifier` | `lib/features/catalog/presentation/providers/catalog_refresh_provider.dart` | **Implementado** | `refresh()` → [ForceRefreshCatalog] + `invalidate(louvoresManifestProvider)` |
| `catalogRefreshProvider` | `lib/features/catalog/presentation/providers/catalog_refresh_provider.dart` | **Implementado** | `NotifierProvider` UC-12 refresh manual |
| `homeSearchRawQueryProvider` | `lib/features/catalog/presentation/providers/home_search_provider.dart` | **Implementado** | Texto imediato da [SearchBar] (`onChanged` e botão limpar) |
| `homeSearchDebouncedQueryProvider` | `lib/features/catalog/presentation/providers/home_search_provider.dart` | **Implementado** | Debounce 300ms; `setImmediate()` para URL |
| `homeSearchResultsProvider` | `lib/features/catalog/presentation/providers/home_search_provider.dart` | **Implementado** | UC-01 + UC-02 → `List<Louvor>` filtrado; legado — preferir [homeSearchGroupResultsProvider] |
| `homeSearchGroupResultsProvider` | `lib/features/catalog/presentation/providers/home_search_provider.dart` | **Implementado jun/2026** | UC-01 + UC-02 → `List<LouvorGroup>` via [GroupLouvoresByMaterial]; `skipLoadingOnReload: true` |
| `groupLouvoresByMaterialProvider` | `lib/features/catalog/data/providers/catalog_providers.dart` | **Implementado jun/2026** | DI [GroupLouvoresByMaterial] — agrupamento por `groupId` |
| `homeSearchUrlSyncQueryProvider` | `lib/features/catalog/presentation/providers/home_search_provider.dart` | **Implementado** | Debounce 500ms para sync URL `pesquisa=` |
| `HomeSearchDebouncer` | `lib/features/catalog/presentation/providers/home_search_provider.dart` | **Implementado** | `Notifier` 300ms; `setImmediate()` hidrata da URL |
| `HomeSearchUrlDebouncer` | `lib/features/catalog/presentation/providers/home_search_provider.dart` | **Implementado** | `Notifier` 500ms; alimenta sync GoRouter na Home |

## APIs públicas — Providers (library, Fase 1.4)

| API | Arquivo | Estado | Descrição |
|-----|---------|--------|-----------|
| `browseLibraryProvider` | `lib/features/library/data/providers/library_providers.dart` | **Implementado** | DI [BrowseLibrary] UC-03 |
| `sortLouvoresProvider` | `lib/features/library/data/providers/library_providers.dart` | **Implementado** | DI [SortLouvores] |
| `paginateLouvoresProvider` | `lib/features/library/data/providers/library_providers.dart` | **Implementado** | DI [PaginateLouvores] |
| `filterBySpecialArrangementProvider` | `lib/features/catalog/data/providers/catalog_providers.dart` | **Implementado** | DI [FilterBySpecialArrangement] UC-03 |
| `LibraryViewSettings` | `lib/features/library/presentation/providers/library_view_settings_provider.dart` | **Implementado** | `sortBy`, `itemsPerPage`, `page`; getters URL |
| `LibraryViewSettingsNotifier` | `lib/features/library/presentation/providers/library_view_settings_provider.dart` | **Implementado** | `hydrateFromUrl()`, `setSortBy()`, `setItemsPerPage()` (reseta page), `setPage()`, `goToNextPage()`, `goToPreviousPage()` |
| `libraryViewSettingsProvider` | `lib/features/library/presentation/providers/library_view_settings_provider.dart` | **Implementado** | `NotifierProvider` ordenação/paginação exclusiva biblioteca |
| `LibrarySpecialArrangementState` | `lib/features/library/presentation/providers/library_special_arrangement_provider.dart` | **Implementado** | `selectedSpecialArrangements`; `arranjoEspecialUrlValue` |
| `LibrarySpecialArrangementNotifier` | `lib/features/library/presentation/providers/library_special_arrangement_provider.dart` | **Implementado** | `hydrateFromUrl()`, `toggleSpecialArrangement()` |
| `librarySpecialArrangementProvider` | `lib/features/library/presentation/providers/library_special_arrangement_provider.dart` | **Implementado** | Filtro arranjo especial UC-03 |
| `libraryAvailableSpecialArrangementsProvider` | `lib/features/library/presentation/providers/library_special_arrangement_provider.dart` | **Implementado** | Chips únicos do manifest (inclui `specialArrangementPadrao`) |
| `libraryResultsProvider` | `lib/features/library/presentation/providers/library_results_provider.dart` | **Implementado** | Pipeline manifest → Browse → Sort → Paginate → [PaginatedLouvores]; legado — preferir [libraryGroupResultsProvider] |
| `sortLouvorGroupsProvider` | `lib/features/library/data/providers/library_providers.dart` | **Implementado jun/2026** | DI [SortLouvorGroups] |
| `paginateLouvorGroupsProvider` | `lib/features/library/data/providers/library_providers.dart` | **Implementado jun/2026** | DI [PaginateLouvorGroups] |
| `libraryGroupResultsProvider` | `lib/features/library/presentation/providers/library_group_results_provider.dart` | **Implementado jun/2026** | Pipeline manifest → Browse → Group → Sort → Paginate → [PaginatedLouvorGroups]; `skipLoadingOnReload: true` |

## APIs públicas — Providers (pdf_opening, Fase 2.1–2.5)

| API | Arquivo | Estado | Descrição |
|-----|---------|--------|-----------|
| `openPdfInReaderProvider` | `lib/features/pdf_opening/data/providers/pdf_opening_providers.dart` | **Implementado** | DI [OpenPdfInReader] (Fase 2.1); consumido por [LouvorCard] modo leitor |
| `pdfBytesDatasourceProvider` | `lib/features/pdf_opening/data/providers/pdf_opening_providers.dart` | **Implementado** | DI [PdfBytesDatasource] + [Dio]; compartilhado com [pdfxViewerAdapterProvider] |
| `sharePdfProvider` | `lib/features/pdf_opening/data/providers/pdf_opening_providers.dart` | **Implementado** | DI [SharePdf] (bytes + [OpenPdfDocument]) |
| `savePdfProvider` | `lib/features/pdf_opening/data/providers/pdf_opening_providers.dart` | **Implementado** | DI [SavePdf] (bytes + [OpenPdfDocument]) |
| `PdfViewerMode` | `lib/features/pdf_opening/presentation/providers/pdf_viewer_mode_provider.dart` | **Implementado** | Enum UC-04; `fromStorage`, `storageValue` |
| `PdfViewerModeNotifier` | `lib/features/pdf_opening/presentation/providers/pdf_viewer_mode_provider.dart` | **Implementado** | `setMode(mode)` — persiste prefs |
| `pdfViewerModeProvider` | `lib/features/pdf_opening/presentation/providers/pdf_viewer_mode_provider.dart` | **Implementado** | `NotifierProvider<PdfViewerMode>`; boot de [StorageKeys.pdfViewerMode] |

## APIs públicas — Providers (pdf_reader, Fase 2.2–2.5)

| API | Arquivo | Estado | Descrição |
|-----|---------|--------|-----------|
| `pdfxViewerAdapterProvider` | `lib/features/pdf_reader/data/providers/pdf_reader_providers.dart` | **Implementado** | DI factory [PdfxViewerAdapter]; `ref.onDispose` → dispose residual (shutdown) |
| `openPdfDocumentProvider` | `lib/features/pdf_reader/data/providers/pdf_reader_providers.dart` | **Implementado** | DI use case UC-11 |
| `readerPreferencesDatasourceProvider` | `lib/features/pdf_reader/data/providers/pdf_reader_providers.dart` | **Implementado** | DI [ReaderPreferencesDatasource] via SharedPreferences |
| `navigatePdfPagesProvider` | `lib/features/pdf_reader/data/providers/pdf_reader_providers.dart` | **Implementado** | DI use case UC-11 navegação |
| `setZoomAndFitModeProvider` | `lib/features/pdf_reader/data/providers/pdf_reader_providers.dart` | **Implementado** | DI use case UC-11 zoom/fit |
| `navigateCarouselInReaderProvider` | `lib/features/pdf_reader/data/providers/pdf_reader_providers.dart` | **Implementado 4.7** | DI [NavigateCarouselInReader] via [carouselRepositoryProvider] |
| `PdfReaderSession` | `lib/features/pdf_reader/presentation/providers/pdf_reader_document_provider.dart` | **Implementado** | Par imutável `{controller, filePath}` — uma instância por visita ao leitor |
| `pdfReaderSessionProvider` | `lib/features/pdf_reader/presentation/providers/pdf_reader_document_provider.dart` | **Implementado + testes** | `FutureProvider.autoDispose.family` por filePath; `bind` + `ref.onDispose` → `unbind` + `controller.dispose()` |
| `pdfReaderDisplayedPageProvider` | `lib/features/pdf_reader/presentation/providers/pdf_reader_displayed_page_provider.dart` | **Implementado 2.3** | `NotifierProvider.autoDispose.family<int, String>` — [PdfReaderDisplayedPageNotifier]; autoDispose com sessão |
| `PdfReaderDisplayedPageNotifier.animateToPage` | idem | **Implementado 2.3** | Navegação animada; congela indicador; escuta `pageListenable` + `loadingState` |
| `pdfReaderErrorMessage` | `lib/features/pdf_reader/presentation/providers/pdf_reader_document_provider.dart` | **Implementado 3.4** | [InvalidPdfPathException] + exceções offline; fallback genérico |
| `PdfReaderViewSettingsNotifier` | `lib/features/pdf_reader/presentation/providers/pdf_reader_view_settings_provider.dart` | **Implementado** | `applyInitialFit()`, `toggleFitMode()` (persiste + reaplica) |
| `pdfReaderViewSettingsProvider` | `lib/features/pdf_reader/presentation/providers/pdf_reader_view_settings_provider.dart` | **Implementado** | `NotifierProvider<PdfReaderViewSettings>`; boot via `loadSettings()` |
| `ReaderFullscreenNotifier` | `lib/features/pdf_reader/presentation/providers/reader_fullscreen_provider.dart` | **Implementado 2.4** | `toggle()` / `exit()`; `SystemUiMode` immersive ↔ manual |
| `readerFullscreenProvider` | idem | **Implementado 2.4** | `NotifierProvider<bool>` — fullscreen do leitor |
| `toggleReaderFullscreenProvider` | idem | **Implementado 2.4** | DI [ToggleReaderFullscreen] |

### Fluxo Fase 2.2 (OpenPdfDocument / UC-11)

```text
/leitor?file=…&titulo=…
  → PdfReaderScreen.watch(pdfReaderSessionProvider(file))  [autoDispose]
      → OpenPdfDocument.validateFilePath(file)
      → PdfxViewerAdapter.openDocument(file) → novo PdfControllerPinch
      → adapter.bindController(controller)
      → PdfxPdfView(ValueKey(controller))
  → pop (sair do leitor)
      → pdfReaderSessionProvider.onDispose
          → adapter.unbindController(controller)
          → controller.dispose()
  → reabrir → nova sessão, controller novo (sem cache PDFx)
```

### Fluxo Fase 2.3 (NavigatePdfPages / SetZoomAndFitMode / UC-11)

```text
/leitor?file=…
  → pdfReaderSessionProvider (2.2) — controller ativo
  → pdfReaderViewSettingsProvider (boot)
      → ReaderPreferencesDatasource.loadSettings() → default page-fit
      → PdfReaderScreen._scheduleApplyInitialFit → SetZoomAndFitMode no adapter
  → pdfReaderDisplayedPageProvider(filePath) — escuta sessão + loadingState; sync scroll manual
  → PdfReaderPageIndicator — ValueListenableBuilder(loadingState); congelado durante animateToPage
  → PdfxPdfView(scrollDirection: Axis.vertical, Key(controller), navigateToPage)
      → Listener: acumula delta no drag; onPointerUp → PdfPageSwipePolicy
          → navigateToPage(pageAtPointerDown ± 1) → PdfReaderDisplayedPageNotifier.animateToPage
  → fit persistido aplicado em `_scheduleApplyInitialFit` (toggle fit removido da barra 3 em 2.4)
  → scroll vertical nativo PdfViewPinch; [NavigatePdfPages] para navegação via adapter (use cases)
```

### Fluxo Fase 2.4 (ToggleReaderFullscreen / UC-11)

```text
/leitor — PDF carregado
  → barra 3: IconButton(Icons.fullscreen)
      → toggleReaderFullscreenProvider.call()
          → ReaderFullscreenNotifier.toggle()
              → readerFullscreenProvider = true
              → SystemChrome.setEnabledSystemUIMode(immersiveSticky)
  → ShellScaffold: hideChrome → oculta PlpcgPrimaryAppBar + CarouselChips
  → _ReaderScaffold: oculta AppBar; PDF em Expanded → Stack → Positioned.fill
  → ref.listen(readerFullscreenProvider) → _scheduleApplyInitialFit (viewport maior)
  → FAB Icons.fullscreen_exit em Opacity(0.25) → toggle() inverte fluxo
  → sair de /leitor (ShellScaffold) → ReaderFullscreenNotifier.exit() post-frame
```

### Fluxo Fase 3.4 — card → leitor + share/save local (UC-04/11)

```text
HomeScreen | LibraryScreen
  → PdfViewerSelector → pdfViewerModeProvider
  → LouvorGroupCard tap (1 material) | showLouvorMaterialSheet (2+)
      → openLouvorInReader / resolveLouvorPdf
      → LouvorPdfPath.fromLouvor → remotePath (/assets/…)
      → resolvePdfForReaderProvider(pdfId, remotePath)
          → OfflinePdfRepository.lookup [hit] | FetchAndStorePdf [miss + rede]
          → LocalPdfSource.absolutePath
      → openPdfInReaderProvider.call(pdfPath: absolutePath, titulo)
      → GoRouter.push → /leitor?file=/…/plpcg_pdfs/…
      → erros: PdfOfflineUnavailableException | PdfExternallyDeletedException
                | PdfFetchFailedException → snackbar com e.message

LouvorGroupCard menu ⋮ → Compartilhar (shareLoading — só 1 material)
  → sharePositionOriginFromContextOrFallback(context)
  → resolvePdfForReaderProvider → LocalPdfSource.absolutePath
  → sharePdfProvider(absolutePath, displayName: nome, sharePositionOrigin)
      → isLocalPdfPath → Share.shareXFiles direto | remoto → bytes + temp
  → snackbar pdfShareSuccess | pdfActionError
  → PdfReaderScreen → pdfReaderSessionProvider(localPath)
      → PdfSourceResolver → localFile → PdfDocument.openFile
```

### Fluxo Fase 3.4 — share/save do leitor (UC-04)

```text
/leitor?file=/…/plpcg_pdfs/…&titulo=…
  → pdfReaderSessionProvider — sessão carregada
  → AppBar share | save
      → SharePdf | SavePdf(filePath local)
          → isLocalPdfPath → fast path (sem fetchBytes)
      → snackbar pdfShareSuccess | pdfSaveSuccess | pdfActionError
```

## APIs públicas — Apresentação (transversal)

| API | Arquivo | Estado | Descrição |
|-----|---------|--------|-----------|
| `ColdiguiApp` | `lib/app.dart` | **Implementado 4.5 + polish jun/2026** | Gate [AppConfig.isApiBaseUrlMissing]; `MaterialApp.router` + [DeepLinkListener] + `ref.listen` manifest; `debugShowCheckedModeBanner: false` |
| `ShellScaffold` | `lib/features/app_shell/presentation/shell_scaffold.dart` | **Implementado + polish + bottom bar jun/2026** | [PlpcgBottomNavBar] 5 destinos; [PlpcgPrimaryAppBar]; [CarouselChips] acima do `child`; [OfflineLifecycleListener]; bottom bar oculta em `/leitor` |
| `PlpcgBottomNavBar` | `lib/features/app_shell/presentation/widgets/plpcg_bottom_nav_bar.dart` | **Implementado jun/2026** | Fundo [AppColors.background]; divisor gold 4px; aba ativa scale 1.14 + [LightBeam] + Garamond dourado; inativa scale 0.86; `animationDuration` 380ms ease; reduce-motion; centro **Pesquisar** (≠ PLPCG do header) |
| `PlpcgBottomNavDestination` | `lib/features/app_shell/presentation/widgets/plpcg_bottom_nav_bar.dart` | **Implementado jun/2026** | Par `icon` + `label` para [PlpcgBottomNavBar.destinations] |
| `PlpcgPrimaryAppBar` | `lib/core/widgets/plpcg_primary_app_bar.dart` | **Implementado UI 3 barras + polish jun/2026** | Ver tabela Core — header PLPCG reutilizado no leitor; sem badge offline |
| `AboutScreen` | `lib/features/app_shell/presentation/pages/about_screen.dart` | **Implementado jun/2026** | UC-14 destino Sobre; [AboutInfoCard] ×2; scroll; `maxWidth: 896`; textos PT fixos |
| `AboutInfoCard` | `lib/features/app_shell/presentation/widgets/about_info_card.dart` | **Implementado jun/2026** | Card creme + borda marrom + divisor gold; título Garamond + corpo Open Sans |
| `DeepLinkListener` | `lib/features/app_shell/presentation/widgets/deep_link_listener.dart` | **Implementado 4.5 + widget tests** | Subscription `app_links`; dedupe; snackbar; `go(/)` pós-import |
| `rootNavigatorKey` | `lib/core/routing/app_router.dart` | **Implementado 4.5 + routing leitor** | `GlobalKey<NavigatorState>` do GoRouter; snackbars [DeepLinkListener]; `parentNavigatorKey` da rota `/leitor` para push fullscreen fora do [ShellScaffold] |
| `showAppSnackbar` | `lib/core/widgets/app_snackbar.dart` | Implementado | Toast via SnackBar |
| `showConfirmDialog` | `lib/core/widgets/confirm_dialog.dart` | Implementado | Diálogo de confirmação |
| `GoldenTaggedContainer` | `lib/core/widgets/golden_tagged_container.dart` | **Implementado + polish** | `contentPadding`; `compactContentPadding`; `compactRowHeight`; ver tabela Core |
| `PlpcgAppBarTitle` | `lib/core/widgets/plpcg_app_bar_title.dart` | **Implementado** | Ver tabela Core — título AppBar com [LightBeam] |

### `ColdiguiApp` — API pública (boot)

| Membro | Tipo | Descrição |
|--------|------|-----------|
| `build` | `Widget` | Gate [AppConfig.isApiBaseUrlMissing] → `_MissingApiBaseUrlScreen` ou `MaterialApp.router` |
| `ref.listen(louvoresManifestProvider)` | side effect | Boot fetch manifest sem rebuild do router |
| `debugShowCheckedModeBanner` | `bool` | `false` em ambos `MaterialApp` — sem selo DEBUG no canto superior direito |
| `DeepLinkListener` | wrapper | Import playlist via deep link (Fase 4.5) |

## APIs públicas — Apresentação por feature

| API | Arquivo | UC | Estado | Descrição |
|-----|---------|-----|--------|-----------|
| `HomeScreen` | `catalog/presentation/pages/home_screen.dart` | UC-01/02/04 | **Implementado + agrupamento jun/2026** | Layout `maxWidth: 896`; ordem Filtros → Leitor → Buscar → `SliverList<LouvorGroupCard>`; [FiltersPanel] + [SearchBar] + [PdfViewerSelector]; sync URL; hidratação/`go` pós-frame |
| `FiltersPanel` | `catalog/presentation/widgets/filters_panel.dart` | UC-02/03 | **Implementado + polish + biblioteca jun/2026** | [GoldenTaggedContainer] compacto colapsado; cabeçalho 24px texto+chevron alinhados; `initiallyExpanded`; `additionalExpandedSections` (ex.: [SpecialArrangementFilters] na biblioteca); [CategoryFilters] + [ClassificationFilters] |
| `SearchBar` | `catalog/presentation/widgets/search_bar.dart` | UC-01 | **Implementado + polish + limpar jun/2026** | [GoldenTaggedContainer] compacto + glow; `Row` lupa + [TextField] + `Icons.close` (visível se não vazio); refoco após limpar; debounce 300ms via provider |
| `LouvorGroupCard` | `catalog/presentation/widgets/louvor_group_card.dart` | UC-01/03/04/05 | **Implementado jun/2026** | Card agrupado Home/Biblioteca; tap → [showLouvorMaterialSheet] ou [openLouvorInReader]; trailing + carousel; menu ⋮ share (1 material) |
| `showLouvorMaterialSheet` | `catalog/presentation/widgets/louvor_material_sheet.dart` | UC-01/03/04 | **Implementado jun/2026** | Bottom sheet classificação → categoria → callback material |
| `openLouvorInReader` | `catalog/presentation/utils/open_louvor_in_reader.dart` | UC-04 | **Implementado jun/2026** | Resolve PDF + playlist + `/leitor`; `resolveLouvorPdf`, `louvorPdfErrorMessage` |
| `LouvorCard` | `catalog/presentation/widgets/louvor_card.dart` | UC-01/03/04/05 | **Implementado + wrapper agrupamento jun/2026** | Delega a [LouvorGroupCard] para 1 material; mantido para testes legados |
| `CategoryFilters` | `catalog/presentation/widgets/category_filters.dart` | UC-02 | **Implementado + polish** | FilterChips pill gold/title; toggle Riverpod |
| `ClassificationFilters` | `catalog/presentation/widgets/classification_filters.dart` | UC-02 | **Implementado + polish** | FilterChips arranjo dinâmicos; estilo chip temático |
| `CatalogRefreshBanner` | `catalog/presentation/widgets/catalog_refresh_banner.dart` | UC-12 | **Implementado + polish biblioteca jun/2026** | [GoldenTaggedContainer] tag `catalogRefreshLabel`; refresh manual via [catalogRefreshProvider]; botão tonal; `Key('catalogRefreshBanner')` |
| `LibraryScreen` | `library/presentation/pages/library_screen.dart` | UC-03/12 | **Implementado + lista agrupada jun/2026** | Layout `maxWidth: 896`; ordem Catálogo → Leitor → Filtros → Visualização → gap 16px → `SliverList<LouvorGroupCard>`; resumo em [LibraryPaginationControls]; sync URL post-frame |
| `SpecialArrangementFilters` | `library/presentation/widgets/special_arrangement_filters.dart` | UC-03 | **Implementado + polish jun/2026** | FilterChips arranjo especial; chips dinâmicos do manifest; título [AppTypography.label] |
| `LibraryViewControls` | `library/presentation/widgets/library_view_controls.dart` | UC-03 | **Implementado jun/2026** | [GoldenTaggedContainer] tag `libraryViewTitle`; ordenação + [LibraryPaginationControls] (resumo + chip page size + nav) |
| `LibraryResultsSummary` | `library/presentation/widgets/library_results_summary.dart` | UC-03 | **Implementado jun/2026** | Subcomponente de [LibraryPaginationControls]; `libraryResultsSummary` / `libraryResultsEmpty`; [AppTypography.body] |
| `LibrarySortSelector` | `library/presentation/widgets/library_sort_selector.dart` | UC-03 | **Implementado + polish jun/2026** | `SegmentedButton` número/nome estilizado gold/title via [libraryViewSettingsProvider] |
| `LibraryPaginationControls` | `library/presentation/widgets/library_pagination_controls.dart` | UC-03 | **Implementado + refatoração jun/2026** | Resumo + chip dropdown `itemsPerPageValue`; nav anterior/próxima; layout responsivo |
| `PdfViewerSelector` | `pdf_opening/presentation/widgets/pdf_viewer_selector.dart` | UC-04 | **Implementado + polish** | [GoldenTaggedContainer] compacto; Dropdown `isDense` 24px; label `pdfViewerSelectorLabel`; persiste via [pdfViewerModeProvider]; modos 2.6 → snackbar |
| `PdfReaderScreen` | `pdf_reader/presentation/pages/pdf_reader_screen.dart` | UC-11/04 | **Implementado** (Fase 2.3 + 2.4 + 2.5 + 3.4 + lifecycle + UI 3 barras) | [_ReaderScaffold]: [PdfReaderPageIndicator] + PDF; `navigateToPage` no [PdfxPdfView]; fullscreen 2.4; sessão `autoDispose` |
| `PdfReaderPageIndicator` | `pdf_reader/presentation/widgets/pdf_reader_page_indicator.dart` | UC-11 | **Implementado 2.3** | Indicador `page/total`; `ValueListenableBuilder(loadingState)`; long-press → página 1 |
| `PdfxPdfView` | `pdf_reader/presentation/widgets/pdfx_pdf_view.dart` | UC-11 | **Implementado** (Fase 2.3 + lifecycle + swipe + indicador) | `PdfViewPinch`; swipe via [PdfPageSwipePolicy]; [PdfReaderNavigateToPage] obrigatório; pinch nativo |
| `OfflineSettingsScreen` | `offline/presentation/pages/offline_settings_screen.dart` | UC-09/10 | **Completa 3.7 + jun/2026** | Stats + refresh; chips material/faltantes; manutenção; bulk UC-09 |
| `PlaylistsScreen` | `playlists/presentation/pages/playlists_screen.dart` | UC-06/07 | **Implementado 4.2 + 4.4 + 4.8 + polish screen jun/2026** | Abas; FAB stack apagar (unsaved) + importar; empty state branco |
| `PlaylistListTile` | `playlists/presentation/widgets/playlist_list_tile.dart` | UC-06/07 | **Implementado 4.2–4.4 + polish UI + debug abrir jun/2026** | Card temático; [CarouselLouvorChip] modal (`onTap`/`onRemove`); menu share/load/open/renomear/excluir; falha abrir → [showPlaylistOpenErrorSnackbar] |
| `showImportPlaylistDialog` | `playlists/presentation/widgets/import_playlist_dialog.dart` | UC-07 | **Implementado 4.4** | Import manual URL/clipboard |
| `CarouselLouvorChip` | `carousel/presentation/widgets/carousel_louvor_chip.dart` | UC-05/01/03/04/06 | **Implementado polish chip + abrir leitor + trailing catálogo + share ⋮** | `onTap` / `onRemove` / `onAdd` / `onShare` / `isAdded` / `loading` / `shareLoading`; variantes `topBar` / `modal` |
| `CarouselNavigatorBar` | `carousel/presentation/widgets/carousel_navigator_bar.dart` | UC-05/11 | **Implementado 4.7 + abrir leitor + polish ícones** | `onChipTap`; chip + setas + lista; [carouselBarIconButtonStyle] |
| `openCarouselPdfInReader` | `carousel/presentation/utils/open_carousel_pdf_in_reader.dart` | UC-04/05 | **Implementado** | Abertura carousel → leitor com `navigate` injetável |
| `carouselSelectionReorderProxyDecorator` | `carousel/presentation/widgets/carousel_selection_sheet.dart` | UC-05 | **Implementado fix drag modal jun/2026** | Proxy transparente para reorder de chips pill no modal |
| `showCarouselSelectionSheet` | `carousel/presentation/widgets/carousel_selection_sheet.dart` | UC-05 | **Implementado + abrir leitor + fix drag modal** | Modal reordenável; `onItemTap` opcional; reorder com proxy transparente |
| `CarouselBarShell` | `carousel/presentation/widgets/carousel_bar_shell.dart` | UC-05/11 | **Implementado UI 3 barras + polish ícones** | Container visual compartilhado; exporta [carouselBarIconButtonStyle] |
| `carouselBarIconButtonStyle` | idem | UC-05/11 | **Implementado polish ícones barra** | `ButtonStyle` vinho PLPCG para ícones da barra |
| `CarouselBarTrailingActions` | `carousel/presentation/widgets/carousel_bar_trailing_actions.dart` | UC-05/06/07/08 | **Implementado UI 3 barras + share lista + polish ícones** | Ações salvar/compartilhar/folheto/limpar — shell e leitor; `iconColor` vinho no overflow |
| `carouselLouvoresDisplayProvider` | `carousel/presentation/providers/carousel_louvores_display_provider.dart` | UC-05 | **Implementado fix flicker reorder jun/2026** | Lista debounced para barra; reorder-only coalesce |
| `carouselReorderPersistDebounce` | `carousel/presentation/providers/carousel_louvores_provider.dart` | UC-05 | **Implementado fix flicker reorder jun/2026** | `100ms` — persist Isar após `reorder` |
| `CarouselChips` | `carousel/presentation/widgets/carousel_chips.dart` | UC-05/06/08 | **Implementado 4.1 + 4.2 + 4.6 + fix flicker reorder** | [CarouselBarShell] + chip `topBar`; `watch` display provider; oculta quando vazio |
| `AboutScreen` | `app_shell/presentation/pages/about_screen.dart` | UC-14 | **Implementado jun/2026** | Ver tabela Apresentação — Sobre Quem somos + Objetivo; [AboutInfoCard] ×2 |
| `AboutInfoCard` | `app_shell/presentation/widgets/about_info_card.dart` | UC-14 | **Implementado jun/2026** | Card informativo reutilizável; ver API pública UC-14 |
| `PlpcgBottomNavBar` | `app_shell/presentation/widgets/plpcg_bottom_nav_bar.dart` | UC-14 | **Implementado jun/2026** | Ver tabela Apresentação transversal — bottom bar animada |

## APIs públicas — Localização (l10n)

| API | Arquivo | Estado | Descrição |
|-----|---------|--------|-----------|
| `AppLocalizations` | `lib/l10n/app_localizations.dart` | **Em progresso** | Wired em `ColdiguiApp`; UC-04, UC-03, UC-12, UC-09 bulk, UC-10 offline, **UC-01 `searchClear`**, **UC-05 carousel (4.1)**, **UC-06/07 playlists (4.2–4.8)**, **UC-08 leaflet (4.6 + redesign jun/2026)**, **design system Home + Biblioteca** |
| `AppLocalizations.searchClear` | `lib/l10n/app_localizations.dart` | **Implementado jun/2026** | Tooltip do botão limpar em [SearchBar] — PT "Limpar busca" / EN "Clear search" |
| `app_pt.arb` / `app_en.arb` | `lib/l10n/` | **Em progresso** | UC-04, UC-03, UC-12, UC-09 bulk, UC-10 offline, **UC-01 `searchClear`**, **UC-05 carousel**, **UC-06/07 playlists (abas, apagar todas, estados vazios 4.8)**, **UC-08 leaflet (redesign: header/colunas/rodapé/weekdays)**, **tags containers dourados (Home + Biblioteca)** |
| `l10n.yaml` | raiz do projeto | Config | `template-arb-file: app_pt.arb` |

**Layout compacto Home (polish UI — §5.2 / §6):**

| Widget | Arquivo | Detalhe |
|--------|---------|---------|
| [SearchBar] | `catalog/presentation/widgets/search_bar.dart` | `Row` lupa + [TextField] + botão `Icons.close` (tooltip `searchClear`); [GoldenTaggedContainer.compactContentPadding]; `glowEnabled: true` |
| [FiltersPanel] | `catalog/presentation/widgets/filters_panel.dart` | Cabeçalho 24px; `compactContentPadding` colapsado; padding inferior maior expandido; `additionalExpandedSections` para extensões (biblioteca) |
| [PdfViewerSelector] | `pdf_opening/presentation/widgets/pdf_viewer_selector.dart` | [DropdownButton] `isDense` em `SizedBox(compactRowHeight)` |

**Layout Biblioteca (polish UI — §5.2 / §6):**

| Seção | Tag [GoldenTaggedContainer] | Conteúdo | Detalhe |
|-------|----------------------------|----------|---------|
| Catálogo | `catalogRefreshLabel` | Mensagem + botão refresh | [CatalogRefreshBanner]; botão tonal `btnBackground`; spinner branco em loading |
| Como abrir | `pdfViewerSelectorLabel` | Dropdown modo PDF | [PdfViewerSelector] (compartilhado com Home) |
| Filtros | `filtersTitle` | Material + arranjo + arranjo especial | [FiltersPanel] com `additionalExpandedSections: [SpecialArrangementFilters]` |
| Visualização | `libraryViewTitle` | Ordenar + resumo + paginar | [LibraryViewControls]: [LibrarySortSelector]; [LibraryPaginationControls] com [LibraryResultsSummary] + chip `itemsPerPageValue` + nav |
| Lista | — | Louvores | `SliverToBoxAdapter(SizedBox 16)` após card Visualização; `SliverList<LouvorGroupCard>` gap 8px entre chips; `maxWidth: 896`; padding horizontal 16/24px |

**Layout Offline (polish UI — §5.2 / §6):**

| Seção | Tag [GoldenTaggedContainer] | Conteúdo | Detalhe |
|-------|----------------------------|----------|---------|
| Armazenamento | `offlineStatsTitle` | Total + chips + manutenção | [AppTypography.headline] 18px; `_StatChip` (fundo `gold` 12%, borda 55%); [OutlinedButton] + [TextButton] empilhados; progresso missing com `LinearProgressIndicator` dourado |
| Download | `offlineSelectCategories` | Chips + bulk | [FilterChip] paridade [CategoryFilters]; `_CheckpointBanner` inline (fundo `gold` 10%); [FilledButton] full-width; progresso bulk via `_ProgressSection` |

**Layout Sobre (polish UI — jun/2026):**

| Card | Título | Parágrafos | Detalhe |
|------|--------|------------|---------|
| Quem somos | "Quem somos" | 1 | ICM Triângulo Mineiro; Maanaim Uberlândia-MG; app não oficial ICM; 100% gratuita |
| Objetivo | "Objetivo" | 2 | PLPCG — materiais básicos, offline/ESFs; pedido de oração pelos envolvidos no projeto |

**Regra de contraste:** texto e controles interativos ficam **dentro** das caixas creme — nunca diretamente sobre [AppColors.background] (marrom escuro).

**Chaves design system Home (polish UI — §5.2 / §6):**

| Chave | PT | EN | Uso |
|-------|----|----|-----|
| `searchLabel` | Buscar | Search | Tag de [GoldenTaggedContainer] em [SearchBar] |
| `filtersTapToExpand` | Toque para ver mais | Tap to see more | [FiltersPanel] colapsado |
| `pdfViewerSelectorLabel` | Como abrir | How to open | Tag de [PdfViewerSelector] |
| `filtersTitle` | Filtros | Filters | Tag de [FiltersPanel] (já existente) |
| `searchHint` | Buscar por número ou título | Search by number or title | Placeholder [SearchBar] (já existente) |
| `searchClear` | Limpar busca | Clear search | Tooltip botão X em [SearchBar] (UC-01) |

**Chaves UC-04 (Fase 2.5):**

| Chave | PT | EN | Uso |
|-------|----|----|-----|
| `sharePdf` | Compartilhar | Share | Tooltip AppBar leitor |
| `savePdf` | Baixar | Download | Tooltip AppBar leitor |
| `pdfShareSuccess` | PDF pronto para compartilhar | PDF ready to share | Snackbar pós-share |
| `pdfSaveSuccess` | PDF salvo com sucesso | PDF saved successfully | Snackbar pós-save |
| `pdfActionError` | Não foi possível concluir a ação | Could not complete the action | Snackbar erro genérico; em debug [showPlaylistOpenErrorSnackbar] acrescenta resumo de [playlistOpenDebugErrorSummary] |
| `pdfModeComingSoon` | Em breve | Coming soon | Modos newtab/online |
| `pdfViewerModeLeitor` | Leitor | Reader | [PdfViewerSelector] |
| `pdfViewerModeNewTab` | Nova aba | New tab | [PdfViewerSelector] |
| `pdfViewerModeOnline` | Leitor online | Online reader | [PdfViewerSelector] |
| `pdfViewerModeShare` | Compartilhar | Share | [PdfViewerSelector] |
| `pdfViewerModeSave` | Baixar | Download | [PdfViewerSelector] |

**Chaves UC-09 (Fase 3.5 — bulk offline):**

| Chave | PT | Uso |
|-------|----|-----|
| `offlineTitle` | Offline | AppBar [OfflineSettingsScreen] |
| `offlineStatsTitle` | PDFs armazenados | Tag [GoldenTaggedContainer] — seção stats |
| `offlineSelectCategories` | Selecione as categorias | Tag [GoldenTaggedContainer] — seção download |
| `offlineDownloadSelected` | Baixar selecionados | Botão bulk |
| `offlineCancelDownload` | Cancelar | Cancelar bulk em execução |
| `offlineResumeBanner` | Há um download offline interrompido. | Banner checkpoint |
| `offlineResumeDownload` | Retomar | Retomar bulk |
| `offlineDismissCheckpoint` | Descartar | Descartar checkpoint |
| `offlineDownloadCompleted` | Download offline concluído | Snackbar sucesso |
| `offlineDownloadError` | Não foi possível concluir o download offline | Snackbar erro genérico |
| `offlineInsufficientDiskSpace` | Espaço em disco insuficiente para o download | Snackbar espaço |
| `offlinePhaseFetching` / `extracting` / `storing` / `syncing` | Fases do progresso | [OfflineDownloadProgress] |
| `offlineProgressDetail` | `{category} — parte {part}/{totalParts} — {done}/{total} PDFs ({phase})` | Barra de progresso bulk |

**Chaves UC-10 (Fase 3.7 — manutenção offline):**

| Chave | PT | Uso |
|-------|----|-----|
| `offlineStatsTitle` | PDFs armazenados | Seção stats |
| `offlineStatsTotal` | plural `{count}` | Total indexado |
| `offlineStatsCategory` | `{category}: {count}` | Chips por material (baixados) |
| `offlineStatsCategoryWithMissing` | `{category}: {downloaded} ({missing} faltantes)` | Chip quando `missing > 0` |
| `offlineStatsTotalMissing` | plural `{count}` | Subtítulo vermelho abaixo do total |
| `offlineRefreshStats` | Atualizar | AppBar + botão na seção stats |
| `offlineRefreshSuccess` / `offlineRefreshError` | Snackbars pós-refresh | [OfflineSettingsScreen] |
| `offlineRemovedBanner` | plural `{count}` | Banner pós-reconcile |
| `offlineDownloadMissing` | Baixar faltantes | CTA banner + botão |
| `offlineDismissRemoved` | Dispensar | Fechar banner |
| `offlineClearCache*` | Limpar cache + confirmação | Ação destrutiva |
| `offlineMissingProgress` | `Baixando faltantes: {done}/{total}` | Progresso — **total = faltantes** |
| `offlineMissingCompleted` | `{downloaded}, {failed}` | Snackbar conclusão |
| `offlineMissingError` | Erro genérico | Snackbar falha |

**Chaves UC-03 (Fase 1.4 — Biblioteca):**

| Chave | PT | EN | Uso |
|-------|----|----|-----|
| `libraryTitle` | Biblioteca | Library | AppBar [LibraryScreen] |
| `libraryViewTitle` | Visualização | View | Tag de [LibraryViewControls] |
| `sortByLabel` | Ordenar por | Sort by | Label acima do [LibrarySortSelector] |
| `sortByNumber` | Número | Number | [LibrarySortSelector] |
| `sortByName` | Nome | Name | [LibrarySortSelector] |
| `itemsPerPage` | Itens por página | Items per page | Tooltip/semantics do chip [LibraryPaginationControls] |
| `itemsPerPageValue` | {count} por página | {count} per page | Label do chip dropdown [LibraryPaginationControls] |
| `pagePrevious` | Anterior | Previous | Tooltip botão anterior [LibraryPaginationControls] |
| `pageNext` | Próxima | Next | Tooltip botão próxima [LibraryPaginationControls] |
| `pageIndicator` | Página {current} de {total} | Page {current} of {total} | [LibraryPaginationControls] |
| `libraryResultsSummary` | Mostrando {from}–{to} de {total} louvores | Showing {from}–{to} of {total} hymns | [LibraryResultsSummary] em [LibraryPaginationControls] |
| `libraryResultsEmpty` | Nenhum louvor encontrado com os filtros atuais | No hymns match the current filters | [LibraryResultsSummary] estado vazio |
| `filtersSpecialArrangementTitle` | Arranjo especial | Special arrangement | [SpecialArrangementFilters] |
| `specialArrangementPadrao` | Padrão | Default | Chip arranjo padrão (valor interno `LouvorClassification.specialArrangementPadrao`) |

**Chaves UC-12 (Fase 1.5 — refresh catálogo):**

| Chave | PT | EN | Uso |
|-------|----|----|-----|
| `catalogRefreshAction` | Atualizar lista | Update list | [CatalogRefreshBanner] botão |
| `catalogRefreshLabel` | Catálogo | Catalog | Tag de [GoldenTaggedContainer] em [CatalogRefreshBanner] |
| `catalogRefreshMessage` | Baixar a versão mais recente do catálogo | Download the latest catalog | [CatalogRefreshBanner] texto |
| `catalogRefreshSuccess` | Catálogo atualizado | Catalog updated | Snackbar pós-refresh ([LibraryScreen]) |
| `catalogRefreshError` | Não foi possível atualizar o catálogo | Could not update the catalog | Erro inline no banner |
| `catalogLoadError` | Não foi possível carregar o catálogo | Could not load the catalog | Erro de boot do manifest ([LibraryScreen]) |

**Chaves UC-05 (Fase 4.1 — carousel):**

| Chave | PT | EN | Uso |
|-------|----|----|-----|
| `carouselAddTooltip` | Adicionar à seleção | Add to selection | Tooltip botão + em [LouvorCard] |
| `carouselAdded` | Adicionado à seleção | Added to selection | Snackbar pós-add |
| `carouselAlreadyAdded` | Já está na seleção | Already in selection | Snackbar duplicata |
| `carouselClear` | Limpar seleção | Clear selection | Tooltip botão limpar / item menu overflow em [CarouselBarTrailingActions] |
| `carouselClearConfirmTitle` | Limpar seleção? | Clear selection? | [showConfirmDialog] título |
| `carouselClearConfirmMessage` | Todos os louvores serão removidos da seleção. | All songs will be removed from the selection. | [showConfirmDialog] corpo |
| `carouselRemoveTooltip` | Remover | Remove | Reservada — chip delete (Material InputChip) |
| `carouselSavePlaylist` | Salvar como lista | Save as playlist | Tooltip botão salvar / item menu overflow em [CarouselBarTrailingActions] |
| `carouselSharePlaylist` | Compartilhar lista | Share playlist | Tooltip botão compartilhar / item menu overflow em [CarouselBarTrailingActions] (UC-07) |
| `carouselGenerateLeaflet` | Gerar folheto | Generate leaflet | Tooltip botão folheto / item menu overflow em [CarouselBarTrailingActions] |
| `carouselOverflowMenu` | Mais ações | More actions | Tooltip do [PopupMenuButton] compacto em [CarouselBarTrailingActions] (smartphone) |

**Chaves UC-08 (Fase 4.6 + redesign jun/2026 — folheto):**

| Chave | PT | EN | Uso |
|-------|----|----|-----|
| `leafletGenerating` | Gerando folheto… | Generating leaflet… | Reservada — loading durante captura |
| `leafletShareSubject` | Folheto PLPCG | PLPCG leaflet | Subject do share sheet |
| `leafletGenerateFailed` | Não foi possível gerar o folheto | Could not generate leaflet | Snackbar erro captura/share |
| `leafletHeaderTitle` | LOUVORES | HYMNS | Cabeçalho esquerdo do folheto |
| `leafletColumnNumber` | NÚMERO | NUMBER | Coluna da tabela |
| `leafletColumnName` | NOME DO HINO | HYMN NAME | Coluna da tabela |
| `leafletFooterPeace` | A PAZ DO SENHOR JESUS CRISTO | THE PEACE OF THE LORD JESUS CHRIST | Rodapé principal |
| `leafletFooterGreeting` | Bom culto! | Have a blessed service! | Rodapé secundário |
| `leafletWeekdayMonday`…`Sunday` | SEGUNDA-FEIRA…DOMINGO | MONDAY…SUNDAY | [formatLeafletHeaderDate] |
| `playlistEmptyCarousel` | A seleção está vazia | Selection is empty | Reutilizada quando carousel vazio (UC-08) |

**Chaves UC-11 (Fase 4.7 — carousel no leitor):**

| Chave | PT | EN | Uso |
|-------|----|----|-----|
| `readerCarouselPrevious` | Louvor anterior | Previous hymn | Tooltip botão ◀ em [CarouselNavigatorBar] (shell e leitor) |
| `readerCarouselNext` | Próximo louvor | Next hymn | Tooltip botão ▶ |
| `readerCarouselPosition` | `{current} de {total}` | `{current} of {total}` | Indicador posição na AppBar do leitor |

**Chaves UC-06 (Fase 4.2 — CRUD):**

| Chave | PT | EN | Uso |
|-------|----|----|-----|
| `playlistSaveTitle` | Salvar lista | Save playlist | [showSavePlaylistDialog] título |
| `playlistSaveNameLabel` | Nome da lista | Playlist name | Campo nome |
| `playlistSaveCancel` | Cancelar | Cancel | Botão cancelar diálogo |
| `playlistSaveConfirm` | Salvar | Save | Botão confirmar |
| `playlistSaved` | Lista salva | Playlist saved | Snackbar pós-salvar |
| `playlistViewLists` | Ver listas | View playlists | Snackbar action → `/listas` |
| `playlistEmptyCarousel` | A seleção está vazia | Selection is empty | Snackbar carousel vazio |
| `playlistEmptyList` | Nenhuma lista salva… | No saved playlists… | Legado — preferir chaves 4.8 por aba |
| `playlistRename` / `playlistRenameTitle` | Renomear / Renomear lista | Rename / Rename playlist | Menu e diálogo |
| `playlistDelete` / `playlistDeleteConfirmTitle` | Excluir / Excluir lista? | Delete / Delete playlist? | Menu e confirmação |
| `playlistFavoriteOn` / `playlistFavoriteOff` | Marcar favorita / Remover favorito | Mark favorite / Remove favorite | Estrela em [PlaylistListTile] |
| `playlistPdfCount` | `{count} louvor(es)` | `{count} song(s)` | Subtítulo contagem |
| `playlistDeleteLastPdfTitle` | Remover último louvor? | Remove last song? | Confirmação ao remover último PDF |

**Chaves UC-06 (Fase 4.3 — load playlist):**

| Chave | PT | EN | Uso |
|-------|----|----|-----|
| `playlistLoadIntoCarousel` | Carregar no carousel | Load into carousel | Menu [PlaylistListTile] |
| `playlistOpenInReader` | Abrir no leitor | Open in reader | Menu [PlaylistListTile] |
| `playlistLoadConfirmTitle` | Substituir seleção? | Replace selection? | [showConfirmDialog] antes de carregar/importar |
| `playlistLoadConfirmMessage` | A seleção atual será substituída… | The current selection will be replaced… | Corpo do diálogo |
| `playlistLoaded` | Lista carregada no carousel | Playlist loaded into carousel | Snackbar pós-carregar |
| `playlistEmptyPdfList` | Esta lista não tem louvores. | This playlist has no songs. | Lista sem pdfIds |

**Chaves UC-07 (Fase 4.4 — share URL):**

| Chave | PT | EN | Uso |
|-------|----|----|-----|
| `playlistShare` | Compartilhar | Share | Menu [PlaylistListTile] |
| `playlistImport` | Importar lista | Import playlist | FAB [PlaylistsScreen] |
| `playlistImportTitle` | Importar lista compartilhada | Import shared playlist | [showImportPlaylistDialog] título |
| `playlistImportUrlLabel` | URL ou link compartilhado | Shared URL or link | Campo multiline |
| `playlistImportPaste` | Colar | Paste | Botão clipboard |
| `playlistImportConfirm` | Importar | Import | Botão confirmar diálogo |
| `playlistImported` | Lista importada | Playlist imported | Snackbar pós-import |
| `playlistImportInvalidUrl` | Link inválido… | Invalid link… | Erro validação diálogo |
| `playlistShareError` | Não foi possível compartilhar a lista. | Could not share the playlist. | Snackbar falha share; em debug [showPlaylistShareErrorSnackbar] acrescenta resumo de [playlistShareDebugErrorSummary] |

**Chaves UC-06 (Fase 4.8 — abas + apagar todas + estados vazios):**

| Chave | PT | EN | Uso |
|-------|----|----|-----|
| `playlistTabUnsaved` | Não Salvas | Unsaved | [TabBar] aba 1 |
| `playlistTabSaved` | Salvas | Saved | [TabBar] aba 2 |
| `playlistTabFavorites` | Favoritas | Favorites | [TabBar] aba 3 |
| `playlistEmptyUnsaved` | Nenhuma lista não salva… | No unsaved playlists… | [PlaylistsScreen] empty state aba `unsaved` — [AppColors.textLight] |
| `playlistEmptySaved` | Nenhuma lista salva. | No saved playlists. | [PlaylistsScreen] empty state aba `saved` — [AppColors.textLight] |
| `playlistEmptyFavorites` | Nenhuma lista favorita. | No favorite playlists. | [PlaylistsScreen] empty state aba `favorites` — [AppColors.textLight] |
| `playlistDeleteAllUnsaved` | Apagar todas | Delete all | Tooltip FAB `small` lixeira (só aba Não Salvas) |
| `playlistDeleteAllUnsavedTitle` | Apagar todas as listas não salvas? | Delete all unsaved playlists? | [showConfirmDialog] título |
| `playlistDeleteAllUnsavedMessage` | Todas as listas da aba Não Salvas… | All playlists in the Unsaved tab… | [showConfirmDialog] corpo |
| `playlistDeleteAllUnsavedDone` | Listas não salvas apagadas | Unsaved playlists deleted | Snackbar pós [deleteAllUnsaved] |
| `playlistSaveAction` | Salvar lista | Save playlist | CTA salvar em [PlaylistListTile] (aba não salvas) |
| `playlistClearSavedBlocked` | Listas salvas não podem ser limpas… | Saved playlists cannot be cleared… | Snackbar [CarouselBarTrailingActions] |

## Testes — catalog (Fases 1.1–1.3)

| Arquivo | Cobertura |
|---------|-----------|
| `test/unit/features/catalog/group_louvores_by_material_test.dart` | Agrupamento `groupId`: seções por classificação, ordem categorias, `primaryLouvor`, avulsos |
| `test/unit/features/catalog/load_louvores_manifest_test.dart` | Delegação ao repository |
| `test/unit/features/catalog/catalog_repository_impl_test.dart` | Sucesso remoto, fallback, remoto vazio, erro sem cache; `forceRefreshManifest` sem fallback |
| `test/unit/features/catalog/force_refresh_catalog_test.dart` | Delegação ao `forceRefreshManifest` |
| `test/unit/features/catalog/catalog_local_datasource_test.dart` | save/load Isar |
| `test/unit/core/utils/louvor_search_tokens_test.dart` | UC-01: `normalize`, `tokenize` (hífens), `compact`, `matchesText` |
| `test/unit/features/catalog/search_louvor_by_number_or_text_test.dart` | UC-01: vazio, número exato, texto, prioridade, busca flexível (`buscarmeeis` / `buscar me eis` / `buscar-me-eis`) |
| `test/unit/features/catalog/filter_by_material_and_arranjo_test.dart` | UC-02: material, Cifra I/II, arranjo base |
| `test/unit/features/catalog/catalog_materials_test.dart` | Expansão Cifra, parse/serialize URL |
| `test/unit/core/utils/home_url_builder_test.dart` | `buildHomeLocation` combina params |
| `test/unit/core/playlist_share_url_builder_test.dart` | encode/decode share URL; parse CSV; round-trip | **Implementado 4.4** |
| `test/widget/features/catalog/home_screen_l10n_test.dart` | Hint PT; labels Filtros + `filtersTapToExpand` |
| `test/widget/features/catalog/home_search_test.dart` | Debounce + LouvorGroupCard (via LouvorCard wrapper) |
| `test/widget/features/catalog/category_filters_test.dart` | Toggle material filtra resultados |
| `test/integration/uc01_search_home_test.dart` | Busca in-memory UC-01 |
| `integration_test/gherkin/uc01_search_home.feature` | Cenários Gherkin UC-01 |
| `integration_test/gherkin/uc02_filter_material_arranjo.feature` | Cenários Gherkin UC-02 |
| `test/unit/features/catalog/filter_by_special_arrangement_test.dart` | UC-03: arranjo especial vazio, Padrão, parênteses, múltiplos |
| `test/unit/features/catalog/louvor_classification_special_test.dart` | `specialArrangement`, parse/serialize `arranjoEspecial` URL |

## Testes — library (Fase 1.4 / UC-03)

| Arquivo | Cobertura |
|---------|-----------|
| `test/unit/features/library/browse_library_test.dart` | UC-03: material vazio, catálogo inteiro, material+arranjo, arranjo especial |
| `test/unit/features/library/sort_louvores_test.dart` | Ordenação `numero` (numérico, lexicográfico, desempate `pdfId`), `nome`, fallback |
| `test/unit/features/library/paginate_louvores_test.dart` | Páginas 10/25/50/100, clamp página, lista vazia, segunda página |
| `test/unit/core/utils/library_url_builder_test.dart` | `buildLibraryLocation` combina/omite params; `buildLibraryLocationFromUri` |
| `test/widget/features/library/library_screen_test.dart` | LouvorGroupCards + chips arranjo especial; resumo dentro do card Visualização; paginação; ordenação; banner refresh + loading |

**Pendente:** integração/Gherkin UC-03.

## Testes — pdf_reader (Fase 2.2)

| Arquivo | Cobertura |
|---------|-----------|
| `test/unit/features/pdf_reader/pdf_source_resolver_test.dart` | Resolução URL/asset/local |
| `test/unit/features/pdf_reader/open_pdf_document_test.dart` | Validação path UC-11 |
| `test/unit/features/pdf_reader/pdfx_viewer_adapter_test.dart` | Mock Dio + controller; fit modes e navegação (2.3); `bind`/`unbind`; `openDocument` sem dispose anterior |
| `test/unit/features/pdf_reader/pdf_reader_session_provider_test.dart` | `ref.onDispose` → `controller.dispose()`; reabertura cria controller novo |
| `test/widget/features/pdf_reader/pdf_reader_screen_test.dart` | Erro file ausente/inválido; botão fullscreen + FAB saída (2.4); share/save AppBar (2.5); `pdfReaderErrorMessage` offline (3.4); ciclo sair/reabrir |
| `test/integration/uc11_pdf_reader_test.dart` | Pipeline validação + resolução |
| `integration_test/gherkin/uc11_pdf_reader.feature` | Cenários Gherkin UC-11 (abertura) |

## Testes — pdf_reader (Fase 2.3)

| Arquivo | Cobertura |
|---------|-----------|
| `test/unit/features/pdf_reader/navigate_pdf_pages_test.dart` | Bounds, `goToPage`, next/prev |
| `test/unit/features/pdf_reader/pdf_page_swipe_policy_test.dart` | Pan horizontal, bordas, `isHorizontalSwipe` |
| `test/unit/features/pdf_reader/set_zoom_and_fit_mode_test.dart` | Delegação `applyFitMode` |
| `test/unit/features/pdf_reader/reader_preferences_datasource_test.dart` | Read/write/defaults SharedPreferences |
| `test/widget/features/pdf_reader/pdf_reader_screen_test.dart` | Fullscreen toggle (2.4); share/save (2.5); `pdfReaderErrorMessage` offline (3.4) |
| `integration_test/gherkin/uc11_pdf_navigation_zoom.feature` | Gherkin: swipe, scroll, fit, pinch |

## Testes — pdf_reader (Fase 2.4)

| Arquivo | Cobertura |
|---------|-----------|
| `test/widget/features/pdf_reader/pdf_reader_screen_test.dart` | Botão `Icons.fullscreen`; FAB `fullscreen_exit`; toolbar oculta em fullscreen; share oculto em fullscreen |

## Testes — pdf_opening (Fase 2.1 / 2.5 / 3.4 — UC-04)

| Arquivo | Cobertura |
|---------|-----------|
| `test/unit/features/pdf_opening/open_pdf_in_reader_test.dart` | Rota `/leitor`; path inválido; path absoluto local (3.4) |
| `test/unit/features/pdf_opening/is_local_pdf_path_test.dart` | **3.4** — http/asset/assets vs path local |
| `test/unit/features/pdf_opening/validate_pdf_availability_test.dart` | **3.4** — lookup hit/miss sem fetch |
| `test/unit/features/pdf_opening/pdf_bytes_datasource_test.dart` | Remoto/asset/local; resposta vazia |
| `test/unit/features/pdf_opening/share_pdf_test.dart` | Remoto: temp + shareXFiles; **3.4:** local sem fetchBytes |
| `test/unit/features/pdf_opening/save_pdf_test.dart` | Remoto: `saved_pdfs/`; **3.4:** `File.copy` sem fetchBytes |
| `test/unit/features/pdf_opening/louvor_pdf_path_test.dart` | `fromLouvor` + acentos pdfId; prefixo `assets/` |
| `test/widget/features/catalog/louvor_card_share_save_test.dart` | Mock [resolvePdfForReaderProvider]; tap → `/leitor`; menu ⋮ Compartilhar → [sharePdfProvider] mock |
| `test/integration/uc04_share_save_test.dart` | Pipeline LouvorPdfPath + bytes asset (sem rede) |
| `integration_test/gherkin/uc04_share_save_pdf.feature` | Cenários Gherkin UC-04 share/save |

**Nota:** `pdfx_viewer_adapter_test` injeta [PdfBytesDatasource] (refactor 2.5).

## Testes — offline (Fase 3)

| Arquivo | Cobertura | Status |
|---------|-----------|--------|
| `test/unit/features/offline/pdf_local_store_test.dart` | Path `plpcg_pdfs/`; escrita atômica; exists/delete; listOrphans | **Implementado 3.1** |
| `test/unit/features/offline/offline_pdf_repository_test.dart` | Lookup hit/miss; upsert; remove; countByCategory; paths sem `assets/`; `findIndexEntry` órfão | **Implementado 3.1 + 3.2** |
| `test/unit/features/offline/resolve_pdf_for_reader_test.dart` | Hit; miss fetch; miss com [FetchAndStorePdf] real; apagado externamente → erro; offline; re-fetch; HTTP error | **Implementado 3.2 + 3.3** |
| `test/unit/features/offline/fetch_and_store_pdf_test.dart` | Download + upsert; category derivada/explícita; retry rede (sucesso 2ª tentativa); retry esgotado; HTTP 404 sem retry; resposta vazia | **Implementado 3.3** |
| `test/unit/features/pdf_opening/is_local_pdf_path_test.dart` | Classificação path local vs remoto | **Implementado 3.4** |
| `test/unit/features/pdf_opening/validate_pdf_availability_test.dart` | Alias lookup sem side-effect | **Implementado 3.4** |
| `test/unit/features/pdf_opening/share_pdf_test.dart` | Fast path local (cobertura em share_pdf_test) | **Implementado 3.4** |
| `test/unit/features/pdf_opening/save_pdf_test.dart` | Fast path `File.copy` (cobertura em save_pdf_test) | **Implementado 3.4** |
| `test/widget/features/catalog/louvor_card_share_save_test.dart` | Integração card + resolver mock; share via menu ⋮ | **Implementado 3.4 + share ⋮ jun/2026** |
| `test/unit/features/offline/reconcile_offline_index_test.dart` | Órfão removido; global orphan files; idempotência | **Implementado 3.6** |
| `test/unit/features/offline/reconcile_offline_index_benchmark_test.dart` | 5000 entradas `< 20s` | **Implementado 3.6** (`tags: ['benchmark']`; excluir com `--exclude-tags=benchmark`) |
| `test/unit/features/offline/get_offline_stats_by_category_test.dart` | totalCount + byCategory | **Implementado 3.6** |
| `test/unit/features/offline/download_missing_pdfs_test.dart` | Skip cached; fetch missing | **Implementado 3.6** |
| `test/unit/features/offline/clear_offline_cache_test.dart` | Índice + tree + checkpoint | **Implementado 3.6** |
| `test/unit/features/offline/migrate_offline_storage_test.dart` | v0→v1 | **Implementado 3.6** |
| `test/unit/features/offline/extract_and_store_pdfs_test.dart` | ZIP fixture; skip cache hit | **Implementado 3.5** |
| `test/unit/features/offline/download_offline_packages_test.dart` | Espaço insuficiente; sucesso; resume; cancel | **Implementado 3.5** |
| `test/unit/features/offline/offline_bulk_checkpoint_store_test.dart` | Round-trip JSON checkpoint | **Implementado 3.5** |
| `test/unit/features/offline/download_missing_pdfs_test.dart` | Skip hit; progresso total=faltantes; sem refetch | **Implementado 3.6 + jun/2026** |
| `test/unit/features/offline/get_offline_stats_by_category_test.dart` | Agregação material UI + missing manifest | **Implementado jun/2026** |
| `test/unit/features/offline/offline_material_resolver_test.dart` | toUiMaterial cifra/partitura | **Implementado jun/2026** |
| `test/unit/features/offline/offline_cache_status_provider_test.dart` | isReady; removedCount; dismiss; listener reconcile | **Implementado 3.7** |
| `test/widget/features/offline/offline_settings_screen_test.dart` | Stats; banner removidos; limpar cache | **Implementado 3.7** |
| `test/integration/uc09_offline_download_test.dart` | Bulk + on-demand + reconcile pós-categoria |
| `integration_test/gherkin/uc09_offline.feature` | Prefetch, resume, abertura offline |
| `integration_test/gherkin/uc10_offline_maintenance.feature` | Reconcile, aviso removidos, re-download |

## Testes — carousel (Fase 4.1 / UC-05)

| Arquivo | Cobertura | Status |
|---------|-----------|--------|
| `test/unit/features/carousel/carousel_repository_test.dart` | add/duplicata; remove+compact; reorder; replaceAll; clear; metadata; [AddLouvorToCarousel] | **Implementado 4.1 + polish chip** |
| `test/unit/features/carousel/carousel_louvores_display_provider_test.dart` | Add imediato no display; reorder debounced `100ms` | **Implementado fix flicker reorder jun/2026** |
| `test/unit/features/catalog/louvor_classification_special_test.dart` | `displayLabel`; arranjo especial; parse/serialize URL | **Implementado + polish chip** |
| `test/widget/features/carousel/carousel_louvor_chip_test.dart` | Variantes `modal`/`topBar`; tiers responsivos (compacto ícones; médio classificação+categoria texto); `onTap`; drag/remove; menu ⋮ quando `onShare` | **Implementado polish chip + abrir leitor + metadados médios + share ⋮** |
| `test/widget/features/carousel/carousel_navigator_bar_test.dart` | Chip + setas condicionais + botão lista; loading desabilita setas mas mantém lista | **Implementado 4.7 fix v2** |
| `test/widget/features/carousel/carousel_selection_sheet_test.dart` | Remove; reorder; metadados; `onItemTap` fecha modal; modal usa [carouselSelectionReorderProxyDecorator] | **Implementado polish chip + abrir leitor + fix drag modal** |
| `test/widget/features/carousel/carousel_chips_test.dart` | Barra vazia; navegação índice; chip/modal → `/leitor`; modo leitor com setas; salvar; **compartilhar lista**; folheto; limpar; overflow smartphone; override [playlistsProvider] em `buildSubject` | **Implementado 4.1 + 4.2 + 4.4 + 4.6 + 4.7 + fix share + fix flicker reorder jun/2026** |

**Pendente:** integração/Gherkin UC-05; widget test [LouvorCard] botão + (share ⋮ coberto em `louvor_card_share_save_test.dart`).

## Testes — carousel no leitor (Fase 4.7 / UC-11)

| Arquivo | Cobertura | Status |
|---------|-----------|--------|
| `test/unit/features/pdf_reader/navigate_carousel_in_reader_test.dart` | vazio; pdfId fora; posição central; sem wrap nas extremidades; item único; `resolveTarget` | **Implementado 4.7** |
| `test/unit/core/reader_url_builder_test.dart` | `buildReaderLocation` com/sem `pdfId` | **Implementado 4.7** |
| `test/widget/features/pdf_reader/reader_carousel_navigator_test.dart` | Indicador `N/M`; tooltips; disabled em loading | **Implementado 4.7** |
| `test/widget/features/pdf_reader/pdf_reader_screen_test.dart` | Navigator visível com `pdfId` + posição mock; oculto sem `pdfId` | **Implementado 4.7** |

**Pendente:** integração/Gherkin UC-11 carousel in-reader; widget test E2E tap ◀/▶ com `context.replace`.

## Testes — leaflet (Fase 4.6 / UC-08)

| Arquivo | Cobertura | Status |
|---------|-----------|--------|
| `test/unit/features/leaflet/leaflet_document_test.dart` | `fromCarouselItems` ordem, `numero`/`nome`, `generatedAt` | **Implementado 4.6 + redesign** |
| `test/unit/features/leaflet/generate_leaflet_from_selection_test.dart` | Documento ordenado; EmptyCarouselException | **Implementado 4.6 + redesign** |
| `test/unit/features/leaflet/leaflet_header_date_test.dart` | `formatLeafletHeaderDate` PT | **Implementado redesign jun/2026** |
| `test/widget/features/leaflet/leaflet_content_test.dart` | Cabeçalho, colunas, linhas CAIXA ALTA, rodapé | **Implementado redesign jun/2026** |

**Pendente:** integração/Gherkin UC-08; widget test captura PNG end-to-end (`toImage` não suportado no binding de teste — validar em dispositivo/simulador).

**Fix jun/2026 (captura):** overlay em `left: -10000` quebrava `toImage()` no iOS — corrigido em [leaflet_actions_provider] + [waitForRepaintBoundary].

**Fix jun/2026 (renderização):** textos do folheto exibiam sublinhação dupla amarela no PNG — [LeafletContent] passou a usar `Material(transparency)` na raiz + `TextDecoration.none` nos estilos.

## Testes — playlists (Fase 4.2–4.4 / UC-06–07)

| Arquivo | Cobertura | Status |
|---------|-----------|--------|
| `test/unit/features/playlists/playlist_repository_test.dart` | create; ordenação favorita; update; delete idempotente | **Implementado 4.2** |
| `test/unit/features/playlists/create_playlist_from_carousel_test.dart` | snapshot carousel; nome default; EmptyCarouselException | **Implementado 4.2** |
| `test/unit/features/playlists/load_playlist_into_carousel_test.dart` | replaceAll; ordem; PlaylistNotFoundException; playlist vazia | **Implementado 4.3** |
| `test/unit/features/playlists/generate_playlist_share_url_test.dart` | URL; not found; EmptyPlaylistShareException | **Implementado 4.4** |
| `test/unit/features/playlists/resolve_active_playlist_from_carousel_test.dart` | Recupera rascunho quando `activePlaylistId` perdido; carousel vazio → `null` | **Implementado jun/2026** |
| `test/unit/features/playlists/import_shared_playlist_from_url_test.dart` | create + carousel; ordem; InvalidSharePlaylistException | **Implementado 4.4** |
| `test/unit/core/playlist_share_url_builder_test.dart` | encode/decode; parse; round-trip | **Implementado 4.4** |
| `test/widget/features/playlists/playlists_screen_test.dart` | Estado vazio; render tile; FAB import | **Implementado 4.2 + 4.4** |
| `test/widget/features/playlists/playlist_list_tile_test.dart` | Menu load/open/share; confirma substituição; [CarouselLouvorChip] → `/leitor` com `pdfId`; logs `[UC-06 playlist-open]` em debug | **Implementado 4.3 + 4.4 + polish UI + debug jun/2026** |
| `test/widget/features/playlists/import_playlist_dialog_test.dart` | URL válida; erro inválido | **Implementado 4.4** |

**Pendente:** integração/Gherkin UC-06; widget test fluxo salvar completo em [CarouselChips].

## Ordem MVP

Ver guia detalhado: **[MVP Roadmap.md](../MVP%20Roadmap.md)** (fases 0–5, dependências e checkpoints).

| # | Fase | Feature(s) | Status |
|---|------|------------|--------|
| 0 | Fundação | `core`, `app_shell`, `l10n` | ✅ Concluída |
| 1 | Catálogo + biblioteca | `catalog`, `library` | 1.1–1.5 ✅ |
| 2 | PDF online + offline no leitor | `pdf_opening`, `pdf_reader` | **2.1 ✅** card → leitor; **2.3 ✅** zoom/navegação; **2.4 ✅** fullscreen; **2.5 ✅** share/save; **3.4 ✅** resolve local-first no card |
| 3 | Offline local-first | `offline` | **3.1–3.7 ✅** |
| 4 | Seleção / playlists | `carousel`, `playlists`, `leaflet`, `pdf_reader` | **4.1–4.7 ✅** — Fase 4 concluída (carousel no leitor UC-11) |
| 5 | Polimento | UC-12 poll, testes integração | Pendente |

## Plataformas e homologação (iOS)

| Item | Valor |
|------|-------|
| Target iOS | `ios/` (Flutter 3.38+, Xcode 26) |
| Bundle ID | `com.example.coldigui` |
| Display name | Coldigui |
| Backend homologação | `https://plpcg.com` via [dart_defines/plpcg.json] |

### Scripts de homologação e tooling

| Script | Uso | Modo |
|--------|-----|------|
| `scripts/apply_pdfx_patch.sh` | Patch legado pdfx 2.9.2 (bug swipe horizontal) | **Opcional** — app usa só scroll vertical; ver [ADR-002](../adr/ADR-002-pdfx-reader.md) |
| `scripts/ios_dev_run.sh` | iPhone físico USB — hot reload | `flutter build ios --debug` + `flutter run` |
| `scripts/ios_homolog_install.sh` | iPhone físico — teste como usuário final | `flutter build ios --profile` + `flutter install` (~7 dias) |

Ambos scripts iOS usam `dart_defines/plpcg.json`, desinstalam versão anterior (`com.example.coldigui`) e resolvem dispositivo via `FLUTTER_DEVICE_ID` ou primeiro iPhone físico conectado.

```bash
# Patch pdfx legado (opcional — só se reativar swipe horizontal)
# ./scripts/apply_pdfx_patch.sh

# iPhone físico — desenvolvimento (hot reload)
./scripts/ios_dev_run.sh

# iPhone físico — homologação standalone (sem cabo após instalar)
./scripts/ios_homolog_install.sh

# Simulador — desenvolvimento
open -a Simulator
flutter build ios --simulator --debug --dart-define-from-file=dart_defines/plpcg.json
flutter run -d "iPhone 17 Pro" --dart-define-from-file=dart_defines/plpcg.json
```

**Nota simulador:** `flutter run` direto pode falhar se `build/ios/iphonesimulator/Runner.app` não existir — rode `flutter build ios --simulator` antes.

**Checklist homologação (Fases 1–3.4):** boot → manifest → busca UC-01 → filtros UC-02 → biblioteca UC-03 → banner UC-12 → **1º tap card** (loading + download `plpcg_pdfs/`) → leitor `openFile` → **2º tap** instantâneo → share/save sem re-download → modo avião (cacheado abre; não cacheado mensagem clara).

## Verificação

```bash
flutter analyze   # No issues found
flutter test --dart-define=PLPCG_API_BASE_URL=https://example.com   # 173 testes
# ou:
flutter test --dart-define-from-file=dart_defines/plpcg.json
```

## Especificações de design (agentes)

Documentos de decisão de produto/arquitetura **antes da implementação**. Agentes de dev devem ler o spec correspondente antes de codar.

| Documento | Feature / UC | Status | Conteúdo |
|-----------|--------------|--------|----------|
| [LOUVOR_GROUPING.md](./LOUVOR_GROUPING.md) | `catalog` — agrupamento manifest | **Implementado parcial** (jun/2026) | App + script ✅; manifest remoto + Isar pendentes; hierarquia UI 3 níveis; regras `f(numero, nomeNormalizado)` |

## ADRs

- [ADR-001 — Isar](../adr/ADR-001-isar-storage.md)
- [ADR-002 — PDFx](../adr/ADR-002-pdfx-reader.md)

## Specs de use cases

Ver [`docs/use-cases/`](../use-cases/) — 14 UCs documentados.

## Pipeline de agentes

Ver [`docs/AGENT_PIPELINE.md`](../AGENT_PIPELINE.md).

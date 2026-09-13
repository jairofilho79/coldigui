# Auditoria de polimento — performance, estabilidade e confiabilidade

**Data:** 2026-09-12 · **Branch:** `web/integration` @ `3f0aaba` · **Alvo medido:** produção `https://v2.plpcg.com` (build `af118514f63e`) + build local release (`--wasm`) servido com COOP/COEP.
**Método:** `flutter analyze` + `flutter test` na árvore limpa; leitura do código de roteamento, leitor PDF (pdfrx 2.4.4), shell e providers; medição no Chrome (Performance API, `history`, console, screenshots quadro a quadro) com a aba **visível** — medições com a aba em segundo plano foram descartadas (o Chrome congela `requestAnimationFrame` e o PDF parecia levar 6–7 s para renderizar; com a aba visível são < 1 s).
**Escopo:** o que sobrou depois das ondas 1–4 de `WEB_REFACTOR_OPPORTUNITIES_2026-09.md`. Não repete o que já está fechado lá. Cada item traz `arquivo:linha` e como foi verificado. **[inferência]** marca o que veio só da leitura do código.

---

## 0. Sinais da árvore limpa

| Sinal | Resultado |
|---|---|
| `flutter analyze` | 0 issues |
| `flutter test` | **2309 passando, 0 falhas, 7 skipped** (1m30s, concurrency 6) |
| Boot web quente (produção, cache do navegador) | `firstFrameMs` **399 ms**; TTFB 228 ms |
| Troca de aba Home → Biblioteca | **< 240 ms** até a lista aparecer |
| Troca de louvor no carousel dentro do leitor (vizinho pré-baixado) | **~213 ms** até a partitura nova |
| Abrir PDF pela busca (cache quente) | **< 1 s** até o raster |
| Scroll no PDF (Mac, 120 Hz) | p50 8 ms · p90 9 ms · p99 41 ms · 5/399 frames > 32 ms |
| Cliques rápidos repetidos no `<`/`>` do carousel | sem erro, sem estado inconsistente (guards funcionam) |
| Erros de console em Home/Biblioteca/Perfil/Listas/leitor/cifra | nenhum |

A app está rápida onde foi medida. Os problemas encontrados são de **navegação/URL**, de **um bug reproduzível no leitor** e de uma **regressão silenciosa de infraestrutura web**.

---

## 1. Top 8 — o que atacar primeiro

| # | Item | Eixo | Esforço | Evidência | Status |
|---|---|---|---|---|---|
| P1 | Produção **não** está cross-origin isolated → skwasm roda **single-thread** e nenhum preload de renderer acontece | Perf/infra | S (decisão) + S–M | medido em prod | ⏳ decisão pendente (medir em tablet; login redirect/FedCM × single-thread) |
| P2 | `push` para `/leitor`, `/cifra`, `/audio`, `/gestos` **não reflete na URL** → F5, aba descartada ou link copiado voltam à Home | Estab./nav | M | medido em prod | ✅ 92e5c9c — optionURLReflectsImperativeAPIs (go nos openers fica para depois de feat/barra-lista-ativa) |
| P3 | Virar para a última página do PDF deixa a viewport no **fim da página**, não no topo | Leitor (o "canvas") | S–M | reproduzido 2× em prod | ✅ 279dd68 |
| P4 | Sync de URL da busca/filtros usa `go` → **uma entrada de histórico por termo digitado** | Nav (push × replace) | S | medido | ✅ 645ada8 |
| P5 | `/listas`, `/offline`, `/sobre` são **becos sem saída**: sem voltar, e tocar "Perfil" de novo não sai deles | Nav/UX | S | medido em prod | 🟡 em execução no plano 2026-09-12-nav-listas-perfil.md |
| P6 | Fit reaplicado a cada virada de página (`refreshViewportAfterNavigation`) → **dois saltos** por virada e provável causa de P3 | Leitor | S | código + frames | ✅ 279dd68 (mesma correção de P3) |
| P7 | Transição de página padrão da plataforma (slide Cupertino no Mac/iPad) anima o shell inteiro a cada push/pop | Perf percebida | S | screenshot mid-transition | ✅ 567afd1 |
| P8 | Snackbars da Home sobrevivem à navegação e cobrem o rodapé do PDF/cifra; em tela larga ficam 100 % da largura | UX | S | screenshot | ✅ 53cbd1b |

---

## A. Infraestrutura web

### P1. Cross-origin isolation desligada em produção (regressão silenciosa)

- **Medido em `https://v2.plpcg.com`:** `window.crossOriginIsolated === false`, `typeof SharedArrayBuffer === 'undefined'`, `__plpcgPerf.rendererPreload === 'fallback'`.
- **Causa:** `web/_headers:2` — `Cross-Origin-Opener-Policy: same-origin-allow-popups`. O commit `1047c9c` (Google Sign-In) trocou `same-origin` por `same-origin-allow-popups` para o popup do GIS funcionar. Só `same-origin` + `COEP: require-corp` habilita isolation.
- **Consequências verificadas no `flutter.js` do build:** `skwasmSingleThreaded: … || !n.crossOriginIsolated || …` → o renderer roda **sem worker de rasterização** (raster na thread principal). O `<link rel=preload>` de `skwasm.wasm` em `web/index.html:38-58` nunca dispara (`supportsSkwasmPreload()` exige `crossOriginIsolated === true`). Toda a documentação de performance (`WEB_PERFORMANCE_AND_LOADING.md`, `web_phase_d_coop_coep_validation.md`) foi medida **antes** dessa troca e assume isolation ligada.
- **O que ainda funciona:** Isar web (OPFS via `createSyncAccessHandle`, não depende de SAB — listas persistem em prod), pdfrx (worker próprio, `pdfium_client.js`).
- **Impacto real:** no Mac o scroll ficou em p99 41 ms — aceitável. O custo aparece em **tablet/celular** (classe real de usuário, PRODUCT.md) onde raster single-thread compete com o layout Flutter. Não medi em dispositivo; é o próximo passo antes de decidir.
- **Opções:**
  1. Voltar a `COOP: same-origin` e mover o login Google para **redirect** (`ux_mode: 'redirect'`) ou FedCM — nenhum dos dois precisa de `window.opener`.
  2. Manter `allow-popups` e **assumir** single-thread: então remover o preload morto do `index.html` e o `supportsSkwasmPreload`, e atualizar os docs de perf para não prometerem multi-thread.
  3. Servir o **leitor** num path com `same-origin` e o login noutro — complexo demais para o ganho.
- **Recomendação:** medir P1 num Android/iPad de referência (scroll + virada de página) antes de escolher; se a diferença for perceptível, opção 1.

---

## B. Navegação e URL (push × replace × go)

### P2. Rotas imersivas por `push` não aparecem na URL

- **Medido:** abrir PDF pela busca → título da aba muda para "Ainda há tempo · PLPCG", mas a URL fica `#/?pesquisa=001`. `location.reload()` → volta para a **Home com a busca**; o PDF aberto some. Mesmo comportamento para `/cifra` (medido) e, pelo mesmo código, `/audio` e `/gestos`.
- **Causa:** go_router só reflete rotas empilhadas por `push`/`replace` quando `GoRouter.optionURLReflectsImperativeAPIs = true` (`go_router-17.3.0/lib/src/parser.dart:257-282`, flag default `false`, marcada como legado). O app usa `context.push`/`context.replace` em `open_louvor_in_reader.dart:64`, `open_chord_in_reader.dart:72`, `open_gesture_in_reader.dart:61`, `open_audio_in_player.dart:33`, `carousel_chips.dart:248/284/317/357`, `carousel_swap_material_button.dart:188-190`, `audio_follow_reader_provider.dart:174-176`, `app_shortcuts.dart:124`, `pdf_reader_screen.dart:236`.
- **Por que importa no culto:** Safari/Chrome em tablet descartam abas em segundo plano e recarregam ao voltar; quem trocou para o WhatsApp e voltou perde a partitura. Link copiado da barra não leva ao louvor.
- **Verificado que a alternativa funciona:** `https://v2.plpcg.com/#/leitor?file=…&pdfId=…&titulo=…` abre direto no leitor (deep link OK); `/leitor` já é filha de `/` na branch Home (`app_router.dart:105-135`), então `context.go('/leitor?…')` monta a pilha `[Home, Leitor]` declarativamente, com voltar funcionando e URL correta.
- **Proposta:** trocar `push`/`replace` por `go` nos openers e no carousel (é uma função `navigate` injetada em `openCarouselPdfInReader` — um ponto). Cuidado observado: ao **voltar** de um `/leitor` alcançado por `go`, o go_router deixa a Home com `#/?file=…&pdfId=…&titulo=…` (query herdada — medido). Trocar o `context.pop()` de `plpcg_primary_app_bar.dart:40` por `context.go(RoutePaths.home)` (ou `go` para a location de origem guardada) resolve. Alternativa mínima: ligar `optionURLReflectsImperativeAPIs = true` — funciona, mas é API legada e não resolve o histórico (P4).
- **Bônus:** `/audio` empilhado sobre `/leitor` e "ver partitura" empilhando `/leitor` sobre `/audio` (`audio_follow_reader_provider.dart:169-177` só faz `replace` **em** rota de leitor) cresce a pilha sem limite a cada ida e volta, mantendo `PdfReaderScreen`s montados por baixo **[inferência]**. Com `go` o problema desaparece porque a pilha vira declarativa.

### P4. Sync de URL da busca/filtros cria histórico

- **Medido (build local, mesmo código de prod):** digitar "sangue de jesus" → URL passa por `?pesquisa=sangue`, `?pesquisa=sangue+de`, `?pesquisa=sangue+de+jesus`; **voltar** do navegador percorre os termos intermediários em vez de sair da Home. Na Biblioteca, cada `pagina=`/`ordenar=` também vira entrada (medido `pagina=3 → 2` no voltar).
- **Causa:** `home_screen.dart:165` e `library_screen.dart:247` chamam `goRouter.go(target)`; go_router reporta `go` como `RouteInformationReportingType.none` e, fora do primeiro frame, isso vira `replace: false` (`information_provider.dart:130-150`) → `pushState`.
- **Proposta:** envolver o sync em `Router.neglect(context, () => goRouter.go(target))` (vira `replaceState`). Manter push só onde faz sentido voltar (talvez paginação da Biblioteca — decisão de produto).

### P5. Sub-rotas do Perfil sem saída

- **Medido em prod:** Perfil → Listas: sem botão voltar; tocar "Perfil" no rail/bottom bar **continua em `/listas`**; ir para Pesquisar e voltar a Perfil também cai em `/listas`. Única saída: título PLPCG (→ Home) ou voltar do navegador.
- **Causa:** `/sobre`, `/listas`, `/offline` são rotas **irmãs** de `/perfil` na branch (`app_router.dart:147-166`), abertas por `go` (`profile_screen.dart:70-82`) — o `go` substitui a pilha da branch, e `goBranch(index)` do `StatefulShellRoute` restaura a **última** location da branch.
- **Proposta:** aninhar as três como filhas de `/perfil` (`routes: [...]` dentro do `GoRoute` do perfil) — `go('/perfil/listas')` monta `[Perfil, Listas]`, o `AppBar` pode mostrar voltar; e em `onDestinationSelected` chamar `navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex)` para que re-tocar a aba volte ao hub.

### P7. Transição de página da plataforma

- **Observado:** ao abrir o leitor, screenshot no meio da animação mostra a Home deslizando para a esquerda (Cupertino slide + parallax, ~400 ms) — `AppTheme.light` não define `pageTransitionsTheme` (`app_theme.dart`), então a web usa a transição do `defaultTargetPlatform` (macOS/iOS no iPad).
- **Proposta:** `pageTransitionsTheme` com `FadeForwardsPageTransitionsBuilder` ou `NoTransition` para web/desktop, e `NoTransitionPage`/`CustomTransitionPage` nas trocas de material dentro do leitor (hoje o `replace` reanima a tela inteira a cada `<`/`>`).

---

## C. Leitor de PDF (o relato do "canvas")

### P3. Virar para a última página termina no rodapé da página

- **Reproduzido 2× em prod** com `ColAdultos/001.pdf` (2 páginas, fit `page-width` persistido em `flutter.pdfPreferredFitMode`): `→` na página 1 → quadro ~1 s mostra o **topo** da página 2 (compasso 4) → quadro ~2,5 s mostra os compassos 38–43 ("D.S. al Fine", **fim** da página). `←` volta corretamente para o topo da página 1. Ou seja: a navegação chega no lugar certo e algo depois **rola para o fim**.
- **Suspeito principal:** `pdf_reader_pdf_view.dart:412-418` `_navigateToPageWithLock` → `_scheduleViewportRefresh` → `refreshViewportAfterNavigation` → `applyInitialFit()` (`pdf_reader_screen.dart:392-394`) → `PdfrxViewerAdapter.applyFitMode` → `calcMatrixFitWidthForPage` + `goTo(matrix)`. O `goTo` é clampado pelo pdfrx contra a borda do documento (`_calcMatrixForClampedToNearestBoundary`) — na **última** página o clamp puxa para o fim; na primeira, para o topo, o que bate com a assimetria observada. É também o item K.3 "applyInitialFit continua sendo re-aplicado a cada troca de página".
- **Proposta:** não reaplicar fit após virada (o zoom já é o mesmo; só a posição muda). Se for para manter, usar `goToPage(pageNumber, anchor: PdfPageAnchor.top)` e nunca `goTo(matrix)` após o `animateToPage`. Adicionar teste de widget com `PdfReaderControllerPort` fake assegurando que **uma** virada gera **uma** chamada de navegação e zero de fit.

### P6. Dois saltos por virada / por troca de louvor

- **Observado:** ao trocar de louvor no carousel, o quadro de 213 ms mostra a página numa posição e o de 363 ms noutra (recentrada) — o `applyInitialFit` pós-`onViewerReady` (`pdf_reader_screen.dart:120-133`) anima de novo (200 ms) o que o viewer já posicionou. Cosmético, mas visível a cada troca.
- Mesma correção de P3.

### Outros pontos do leitor (menores, do código)

- `PdfReattachGuard` está definido **duas vezes** (`pdf_reader_pdf_view.dart:497` e `pdf_reader_viewport_policy.dart:17`); só a do view é usada.
- `PdfViewer` é reconstruído (params + closures novas) a cada mudança de `pageListenable`/`loadingState` porque `_buildPdfContent()` fica dentro dos dois `ValueListenableBuilder` (`pdf_reader_pdf_view.dart:461-482`). O pdfrx compara `PdfViewerParams` campo a campo e ignora closures, então não reprocessa — mas o rebuild é desnecessário; mover o `PdfViewer` para fora dos builders (só `PdfReaderPageKeyHandler` precisa de `currentPage`).
- `readerCarouselPositionProvider` é `Provider.family` sem `autoDispose` (`reader_carousel_position_provider.dart:18`) — cresce uma instância por `materialId` visitado na sessão (já listado em K.3).
- Cache LRU web = 2 (`pdf_session_cache.dart:12`) com prefetch de 2 vizinhos em bytes (não em handle) — coerente; sem problema.
- `DeferredRouteLoader` (`app_router.dart:107`) faz `Scaffold` de loading com `AppColors.background` **por fora** do shell — no primeiro `/leitor` do boot aparece um flash de tela inteira vinho sem barras antes do leitor **[inferência]**; a espera é só de `ensurePdfrxInitialized`. Poderia renderizar o `PdfPageSkeleton` dentro do layout do leitor.

---

## D. UX que afeta confiabilidade percebida

### P8. Snackbars

- **Observado em prod (1568 px):** "Adicionado à lista … Trocar material" ocupa 100 % da largura, texto e ação nos cantos opostos; persiste ao entrar no leitor/cifra e cobre o rodapé do documento. `showAppSnackbar` (`app_snackbar.dart:5`) e `louvor_group_card.dart:179-190` usam `SnackBar` padrão.
- **Proposta:** `SnackBarBehavior.floating` + `width` máx (~480 px) no `ThemeData.snackBarTheme`; `ScaffoldMessenger.of(context).clearSnackBars()` ao entrar nas rotas imersivas (ou um `ScaffoldMessenger` próprio do leitor).
- Nota: na minha sessão os snackbars **não** auto-dismissavam — muito provavelmente porque a extensão de automação ativa a árvore de acessibilidade do Chrome (Flutter desliga o timer com `accessibleNavigation`). Vale confirmar com VoiceOver/TalkBack real, já que acessibilidade está "aberta" no PRODUCT.md.

### "Abertos recentemente" com rótulos repetidos

- **Observado:** 4 chips "047 Shekinah" idênticos (materiais diferentes do mesmo louvor). `recentlyOpenedProvider` deduplica por material, o chip mostra só número + nome. Mostrar o tipo (ícone) ou deduplicar por louvor.

### Chip do carousel em deep link direto

- **Observado:** abrindo `/leitor?…` por URL, a chip mostra só o título ("O Sangue", sem `#001 · Coletânea`), porque o louvor não está na lista ativa e a chip sintética (`carousel_chips.dart:227-235`) não consulta o catálogo. Menor, mas fica visível se P2 for resolvido com `go` (a URL passa a ser compartilhável).

---

## E. Cobertura de testes — o que os 2309 testes não pegam

Os bugs P2–P5 estão em comportamento **de plataforma web** (URL, `history`, `pushState`) que `flutter_test` não exercita, e P3 depende do pdfrx real. Sugestões proporcionais:

1. **Contrato de navegação** (unit, rápido): teste do `appRouterProvider` que, para cada opener, chama `router.go/push` num `GoRouter` real com `MockRouterInformationProvider`… é pesado; mais barato: testar a **decisão** — que os openers chamam `go` (após P2) via `navigate` injetado (já existe em `openCarouselPdfInReader`), e que o sync de URL passa por `Router.neglect` (checar `RouteInformationReportingType.neglect` num `RouteInformationProvider` fake).
2. **Smoke em Chrome** (`test/web/`, já existe infra): um teste que monta o app com `MaterialApp.router`, faz `go('/leitor?…')` e afirma `Uri.base.fragment` contém `/leitor`; outro que digita na busca e afirma `html.window.history.length` não cresce. Roda com `flutter test --platform chrome test/web` (hoje "não re-executado" nas últimas duas ondas — voltar a rodar no CI).
3. **Leitor:** teste de widget de `PdfReaderPdfView` com `PdfReaderViewerHandle` fake contando chamadas a `navigateToPage` e `refreshViewportAfterNavigation` por virada (deve ser 1 e 0 após P3/P6).
4. **Golden** do shell em 3 larguras (phone/tablet/desktop) — continua em 0 goldens desde a primeira auditoria; é a única rede para regressões como o snackbar full-width.

---

## F. Ordem sugerida

1. **P3 + P6** (leitor, S–M): é o relato de usuário; corrigir e escrever o teste do item E.3.
2. **P2 + P4 + P5** (navegação, M): mesma família — `go` nos openers, `Router.neglect` no sync, aninhar sub-rotas do Perfil, `goBranch(initialLocation:)`. Depois, item E.2.
3. **P7 + P8** (S): tema — `pageTransitionsTheme`, `snackBarTheme`, `clearSnackBars` nas rotas imersivas.
4. **P1** (decisão): medir num tablet real com e sem `same-origin`; decidir login redirect/FedCM × single-thread; alinhar `index.html` e docs ao que for escolhido.
5. Menores: `PdfReattachGuard` duplicado, `PdfViewer` fora dos builders, `readerCarouselPositionProvider` autoDispose, recentes deduplicados, chip sintética com catálogo.

---

## G. O que foi verificado e está bem

- Boot: `BootstrapApp` não serializa mais no Isar; primeiro frame quente em ~400 ms; manifest cache-first; `PdfrxIdlePreloader` espera o manifest e 3 s de folga.
- Busca: índice pré-computado (`PlpcgSearchIndex`), varredura linear de ~4600 itens síncrona — imperceptível; debounce 300 ms (busca) + 500 ms (URL).
- Carousel: guards contra cliques repetidos; navegação por chave; prefetch de vizinhos em bytes; troca em ~200 ms.
- Sessão PDF: `autoDispose.family` com guarda `ref.mounted` (B6), LRU por plataforma, classificação de falha antes de apagar PDF local (B3).
- Deep link `/leitor?…` funciona — base pronta para P2.
- Sem erros de console em nenhuma tela percorrida; `flutter analyze` e a suíte inteira verdes.

## H. Ambiente e limitações da medição

- Medições em macOS/Chrome, tela 120 Hz, rede boa, cache quente. **Não** medi em Android/iPad nem em rede ruim — P1 depende disso.
- API Coldigom falha por CORS quando a app roda em `127.0.0.1` (`[rede] retentativa 1/2 em GET /api/plpcg/praises: connectionError`) — só local; em prod responde.
- Durante a sessão outra instância rodou `flutter run -d web-server --web-port 8080` e apagou `build/web`; o build release desta auditoria ficou fora da árvore (scratchpad) para não interferir.

---

## I. Execução — 2026-09-12 (`feat/polimento-leitor-nav`)

Plano: `docs/superpowers/plans/2026-09-12-polimento-leitor-nav.md`. Fechados P2, P3, P4, P6, P7, P8 (commits acima). Decisões:

- **P2 pela opção global do go_router**, não por `go` nos openers: os arquivos do carousel/áudio estão em edição em `feat/barra-lista-ativa`. Revisitar quando aquela branch entrar — `go` também resolveria o crescimento da pilha `/leitor` ↔ `/audio` (item B, «Bônus»).
- **Fit só na abertura e no fullscreen.** Se o usuário fizer pinch-zoom e virar a página, o zoom agora é preservado (antes era resetado pelo fit) — comportamento novo, alinhado ao que um leitor de partitura espera.
- **Fora do plano:** P1 (decisão + medição em dispositivo), P5 (outro plano), `readerCarouselPositionProvider` autoDispose (arquivo do plano `barra-lista-ativa`), `PdfViewer` fora dos `ValueListenableBuilder` (sem ganho medido), recentes deduplicados e chip sintética com catálogo (UX, decidir com produto).
- **Skips = dívida técnica documentada (2026-09-13).** A suíte VM fica verde com **10 skips**, todos com comentário `DÍVIDA TÉCNICA` no arquivo: 3 em `test/unit/features/pdf_reader/pdfrx_viewer_adapter_test.dart` (pdfium nativo não carrega no VM — `pdfium_dart` 0.2.5 exige `.dart_tool/native_assets.yaml`; sanar apontando `pdfiumModulePath` num helper de teste, como o Isar), 3 em `test/web/chrome_smoke_test.dart` e 4 em `test/web/pdf_reader_offline_preserved_web_test.dart` (só rodam em `--platform chrome`, hoje apenas no CI; sanar trazendo o alvo Chrome para a verificação local ou tag `@Tags(['web'])`). Ficam para polimentos futuros.

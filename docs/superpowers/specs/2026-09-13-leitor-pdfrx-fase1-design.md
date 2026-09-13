# Leitor PDF — pdfrx 2.6.1 com uso otimizado (Fase 1) — design

Data: 2026-09-13
Origem: diagnóstico «Leitor PDF do PLPCG — pdfrx sob a lupa»
(https://claude.ai/code/artifact/59b3b7b4-8b74-40a1-ba2d-01f29f39d98b), seção 5,
«Fase 1 — mesma lib, uso otimizado». Fases 2 (cross-origin isolation ×
login Google) e 3 (viewer próprio) ficam fora: a 2 vai para outra sessão e a
3 foi descartada pelo dono.

## 1. Contexto

### Sintomas relatados

- «Engasgada» ao abrir/virar página (mais forte na web).
- Partes do canvas (ou a página inteira) em branco até «dar uma mexidinha».

### Causas confirmadas (diagnóstico, 2026-09-13)

1. **Branco até mexer** — no pipeline de imagens do `pdfrx` 2.4.x um preview
   cancelado (scroll rápido, virada animada) ou evictado do cache nunca era
   pedido de novo até o próximo paint com mudança de viewport. Corrigido
   upstream: 2.4.8 (decode pendurado #699, vazamento #698), 2.5.0 («pages
   whose bitmaps were evicted … can be rendered again»), 2.6.0 («canceled
   page previews can be rendered again», escala parcial com `layoutPages`
   custom #702). Reproduzido em v2.plpcg.com: página 2 inteira branca por
   segundos após `→`.
2. **Trabalho inútil para partitura escaneada** — defaults do `PdfViewerParams`
   pensados para PDFs de texto: seleção de texto ligada (carrega texto
   estruturado de toda página no `cacheExtent`, no mesmo worker que
   renderiza), sombra com blur por página por frame, anotações/forms
   (`FPDF_FFLDraw`), `limitRenderingCache: true` (PDFium descarta o JPEG
   decodificado entre renders), preview a 200/72 ≈ 2,78× e tiles «real size»
   sem teto no nativo.
3. **Web sem cross-origin isolation** desde 2026-07-13 (COOP
   `same-origin-allow-popups`) → skwasm single-thread. **Fora deste design**
   (Fase 2).

### O que o repo já tem (verificado em 2026-09-13)

- Flutter **3.44.4** (Homebrew, canal stable, `flutter upgrade` in-place);
  stable atual **3.47.4 / Dart 3.13.3** (2026-09-11). CI
  (`.github/workflows/web.yml`) usa `subosito/flutter-action` com
  `channel: stable` sem pin → já roda 3.47.4.
- `pdfrx ^2.4.4` (lock 2.4.4; `pdfrx_engine` 0.4.3, `pdfium_flutter` 0.2.2,
  `pdfium_dart` 0.2.5). `pdfrx` 2.6.1 (2026-09-04) exige Dart ≥ 3.13 e
  Flutter ≥ 3.47; puxa `pdfrx_engine` ^0.6.0, `pdfium_flutter` ^0.3.0,
  `pdfium_dart` 0.3.0, `material_ui` ^1.0.0.
- Único import `pdfrx` na presentation: `pdf_reader_pdf_view.dart` (+
  `pdf_spread_layout.dart` pelos tipos) — ADR-002.
- Testes com PDFium real já reativados (commit 3ad7104,
  `test/helpers/pdfium_test_init.dart` aponta `Pdfrx.pdfiumModulePath` para
  `build/native_assets/<os>/`). O loader do `pdfium_dart` 0.3.0 não mudou
  (continua só olhando `.dart_tool/native_assets.yaml`), então o helper segue
  necessário e válido.
- Toda API `pdfrx` usada pelo app existe em 2.6.1 sem mudança de assinatura
  (`openData`/`openAsset`, `PdfDocumentRefDirect(autoDispose:)`,
  `calcMatrixFitWidthForPage`/`HeightForPage`, `goTo`, `goToPage`,
  `invalidate`, `layout.pageLayouts`, `viewSize`, `currentZoom`,
  `pdfrxFlutterInitialize`, `Pdfrx.pdfiumModulePath`).

## 2. Decisões

### 2.1 Upgrade: Flutter 3.47.4 + pdfrx 2.6.1

- `flutter upgrade` (global na máquina — autorizado pelo dono nesta sessão;
  afeta todos os worktrees).
- `pubspec.yaml`: `environment.sdk: ">=3.13.0 <4.0.0"`, `pdfrx: ^2.6.1`.
- Gate: `flutter analyze` (fatal em infos — 0 issues), `flutter test`,
  `flutter test --platform chrome test/web/`, `flutter build web --wasm`.
- Se `flutter pub get` não resolver por outra dependência, o plano para
  (BLOCKED) com a saída — não se relaxa constraint de outro pacote às cegas.

### 2.2 Parâmetros do viewer (uma função pura, testável)

`buildPdfReaderViewerParams(...)` em `pdf_reader_pdf_view.dart`
(`@visibleForTesting`; mantém o único import `pdfrx` da presentation):

| Parâmetro | Valor | Por quê |
|---|---|---|
| `textSelectionParams` | `PdfTextSelectionParams(enabled: false)` | scans não têm texto; evita carregar texto estruturado por página e o long-press. Com seleção desligada o menu de contexto padrão fica vazio (retorna `null`) — sem override extra. |
| `annotationRenderingMode` | `PdfAnnotationRenderingMode.none` | sem `FPDF_FFLDraw` |
| `pageDropShadow` | `null` | sem blur por página por frame |
| `limitRenderingCache` | `false` | PDFium mantém o JPEG decodificado |
| `sizeDelegateProvider` | `const PdfViewerSizeDelegateProviderLegacy(onePassRenderingScaleThreshold: 3.0)` | preview a 3× em todas as plataformas (antes 2,78×). `const` porque `doChangesRequireReload` compara por `==`. Demais campos (maxScale 8, minScale 0.1, `useAlternativeFitScaleAsMinScale` true) iguais ao default que o app já usava. |
| `getPageRenderingScale` | `PdfRenderScalePolicy.resolve(estimatedScale, dpr)` = `min(estimada, 2×DPR, 3.0)` — **todas** as plataformas (antes só web, sem o teto 3.0) | scans ~210 dpi ⇒ nada acima de ~3× rende detalhe |
| `maxImageBytesCachedOnMemory` (web) | 64 MiB (era 32 MiB) | spread = 2 páginas A5 a 3× ≈ 8,9 MB cada + tiles; 32 MiB evictava o par visível |
| `scrollPhysics` | `PdfViewerParams.getScrollPhysics(context)` | bounce iOS / overscroll fixo Android (#677 corrigido em 2.4.8) |
| `interactionDelegateProvider` | `const PdfViewerScrollInteractionDelegateProviderPhysics()` | roda/trackpad com inércia em vez de saltos de 20% por tick |

Inalterados: `backgroundColor`, `onViewerReady`, `onPageChanged`,
`layoutPages` (spread), `loadingBannerBuilder`, `errorBannerBuilder`.

### 2.3 `PdfRenderScalePolicy` (sem import `pdfrx`)

`lib/features/pdf_reader/presentation/utils/pdf_render_scale_policy.dart`:
`ceiling = 3.0`, `dprMultiplier = 2`,
`resolve({estimatedScale, devicePixelRatio}) = min(estimatedScale, min(2×dpr, 3.0))`.
Substitui `kPdfWebRenderScaleDprMultiplier` (era só web).

## 3. Fora do escopo (e por quê)

- **1.5 Skeleton até o primeiro preview** — o `pdfrx` 2.6.1 não expõe sinal
  de «primeiro preview pintado»: `pagePaintCallbacks`/`pageBackgroundPaintCallbacks`
  rodam em todo paint, com ou sem imagem, e o retângulo branco é pintado
  entre eles. Implementar exigiria heurística por tempo. Com o retry
  corrigido (2.6.0) e o engine a 5–19 ms/página, o branco inicial é de
  1–2 frames. Reavaliar só se continuar visível na medição pós-deploy.
- **1.6 Testes com PDFium real** — já feito (commit 3ad7104).
- **1.7 Toque-na-borda × double-tap** — em 2.6.1 o double-tap do `PdfViewer`
  não faz nada por padrão (`_handleGeneralTap` → `default:` vazio; só
  overlays/`onGeneralTap` reagem). Não há zoom por double-tap para
  conflitar; dois toques rápidos na faixa = duas viradas, comportamento da
  política de borda, não bug.
- **Fase 0.2 (fixture real no lugar de `sample.pdf`)** — colocaria uma
  partitura do catálogo no repo; decisão do dono, não deste plano.
- **Fase 0.1 (medição com aba visível)** — manual, do dono, antes e depois
  do deploy (ver §5).

## 4. Riscos

- Upgrade de Flutter pode trazer lints novos (analyze é fatal em infos) —
  corrigir minimamente nos arquivos apontados, sem refatorar.
- `pdfium_flutter` 0.3.0 no iOS (SPM): validar build iOS simulador sem aviso
  (manual, pós-plano; CI é só web).
- `scrollPhysics` não-nulo desabilita `normalizeMatrix` (não usado) e muda o
  clamp nas bordas do documento — `applyFitMode` via `goTo` precisa continuar
  encaixando a página (teste manual §5).
- O hook do `pdfium_dart` 0.3.0 baixa binário novo em
  `build/native_assets/<os>/` no primeiro `flutter test` do worktree; se
  `ensurePdfiumTestModule` acusar «ausente», apagar `build/native_assets/` e
  rodar de novo.

## 5. Verificação manual (dono, após merge + deploy em v2.plpcg.com)

Com a aba **visível** (memória `test-on-production-v2`), DevTools →
Performance:

1. Abrir partitura de 3+ páginas; virar com `→`, swipe e toque na borda —
   nenhuma página fica branca após a animação terminar.
2. Pinch forte (> 3×) — tiles nítidos aparecem após ~100 ms; soltar volta ao
   preview sem flash branco.
3. Roda do mouse / trackpad — scroll com inércia, sem saltos de 20%.
4. iOS: bounce nas bordas; Android: overscroll fixo. Fit width/page continua
   encaixando após virar página e após fullscreen.
5. Long-press na página não abre menu de contexto.
6. Comparar long tasks e intervalo até a página 2 pintar com a medição
   anterior (diagnóstico §2).

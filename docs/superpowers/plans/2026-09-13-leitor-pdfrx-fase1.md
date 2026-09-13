# Leitor PDF — pdfrx 2.6.1 com uso otimizado (Fase 1) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminar a página em branco «até mexer» e reduzir o engasgo do leitor de partituras sem trocar de biblioteca: subir para Flutter 3.47.4 + pdfrx 2.6.1 (que trazem os fixes de preview cancelado/evictado) e configurar o `PdfViewer` para partitura escaneada (sem texto/anotação/sombra, escala calibrada em 3×, física de scroll da plataforma).

**Architecture:** Nenhuma mudança de modelo, rotas ou adapter. A construção dos `PdfViewerParams` sai do `build` do `PdfReaderPdfView` para uma função pura `buildPdfReaderViewerParams(...)` no mesmo arquivo (mantendo o único import `pdfrx` da presentation — ADR-002), testável sem montar o viewer. A política de escala vira `PdfRenderScalePolicy` (utils, sem import `pdfrx`) e passa a valer em todas as plataformas. O upgrade de SDK/pacote é a primeira task e o gate é a suíte inteira + build web WASM.

**Tech Stack:** Flutter 3.47.4 / Dart 3.13.3 (alvo; hoje 3.44.4), pdfrx 2.6.1 (pdfrx_engine 0.6.0, pdfium_flutter 0.3.0, pdfium_dart 0.3.0), Riverpod 3, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-13-leitor-pdfrx-fase1-design.md` (argumenta a partir do diagnóstico https://claude.ai/code/artifact/59b3b7b4-8b74-40a1-ba2d-01f29f39d98b, seção 5 «Fase 1»). Itens 1.5, 1.6 e 1.7 do diagnóstico ficam **fora** — motivos na spec §3.

## Global Constraints

- **Worktree próprio:** branch `feat/leitor-pdfrx-fase1` criada a partir de `web/integration` (HEAD `5d3a0b0`… em 2026-09-13) em `.claude/worktrees/leitor-pdfrx-fase1` (skill `superpowers:using-git-worktrees`; usar a ferramenta nativa `EnterWorktree`). Nunca commitar direto em `web/integration`.
- **`flutter upgrade` é global na máquina** (instalação Homebrew, canal stable, atualizada in-place). Autorizado pelo dono nesta sessão (2026-09-13); afeta todos os worktrees. Só a Task 1 roda esse comando.
- **Versões exatas:** Flutter `3.47.4`, Dart `3.13.3`, `pdfrx: ^2.6.1` (lock 2.6.1), `pdfrx_engine` 0.6.0, `pdfium_flutter` 0.3.0, `pdfium_dart` 0.3.0, `environment.sdk: ">=3.13.0 <4.0.0"`. Nenhuma outra dependência é adicionada ou bumpada de propósito (o que o resolver mover sozinho no lock é aceito; se o `pub get` falhar por constraint de outro pacote, reportar `BLOCKED` com a saída em vez de relaxar constraint).
- **Valores da spec §2.2 (verbatim):** `PdfTextSelectionParams(enabled: false)`; `PdfAnnotationRenderingMode.none`; `pageDropShadow: null`; `limitRenderingCache: false`; `sizeDelegateProvider: const PdfViewerSizeDelegateProviderLegacy(onePassRenderingScaleThreshold: 3.0)`; `getPageRenderingScale = min(estimada, 2×DPR, 3.0)` em **todas** as plataformas; web `maxImageBytesCachedOnMemory = 64 << 20` (nativo continua no default do pacote, 100 MB); `scrollPhysics: PdfViewerParams.getScrollPhysics(context)`; `interactionDelegateProvider: const PdfViewerScrollInteractionDelegateProviderPhysics()`.
- **ADR-002:** import `package:pdfrx/pdfrx.dart` na presentation só em `pdf_reader_pdf_view.dart` e `pdf_spread_layout.dart`. `PdfRenderScalePolicy` **não** importa `pdfrx`.
- `flutter analyze` é fatal em infos: **0 issues** antes de cada commit. Lints novos do SDK são corrigidos minimamente nos arquivos apontados, sem refatorar nem reformatar arquivos inteiros (`dart format` só nos arquivos tocados).
- Comentários e docs em português, `///` explicando o *porquê*, com referência ao item do diagnóstico quando fizer sentido (ex.: «Fase 1.2»).
- Commits com prefixo `chore|feat|refactor|test|docs(escopo):` em português, imperativo, uma linha de assunto. Todo commit termina com:
  ```
  Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01X2ZyEPGitn4bV7FhAk7u4j
  ```
- Testes VM: `flutter test <arquivo>` na task; ao final de cada task que toca o leitor, `flutter test test/unit/features/pdf_reader test/widget/features/pdf_reader test/helpers`. O primeiro `flutter test` num worktree novo baixa o PDFium (hook do `pdfium_dart`) para `build/native_assets/macos/` — demora mais; se `ensurePdfiumTestModule` acusar «pdfium nativo ausente», `rm -rf build/native_assets` e rodar de novo.
- Fixture existente `assets/fixtures/sample.pdf` não muda (spec §3).

---

## Mapa de arquivos

**Criar**
- `lib/features/pdf_reader/presentation/utils/pdf_render_scale_policy.dart` — `PdfRenderScalePolicy` (`ceiling`, `dprMultiplier`, `resolve`). Sem import `pdfrx`.
- `test/unit/features/pdf_reader/pdf_render_scale_policy_test.dart`.
- `test/unit/features/pdf_reader/pdf_reader_viewer_params_test.dart` — asserts sobre `buildPdfReaderViewerParams(...)`.
- `test/widget/features/pdf_reader/pdf_reader_pdf_view_test.dart` — o `PdfViewer` montado recebe os params do leitor com a física da plataforma.

**Modificar**
- `pubspec.yaml` (`environment.sdk`, `pdfrx`), `pubspec.lock` (gerado).
- `lib/features/pdf_reader/presentation/widgets/pdf_reader_pdf_view.dart` — remove `kPdfWebRenderScaleDprMultiplier` e o import `dart:math`; `kPdfWebMaxImageBytesCachedOnMemory` vira 64 MiB; novo `kPdfReaderSizeDelegateProvider` e `buildPdfReaderViewerParams(...)`; `_buildPdfContent` passa a chamá-la.
- `docs/adr/ADR-002-pdfx-reader.md` — versão, parâmetros, histórico.
- `docs/DEP_UPGRADE_BACKLOG.md` — linha do inventário do `pdfrx` e baseline Flutter.

**Não tocar**
- `pdfrx_viewer_adapter.dart`, `pdf_reader_viewer_handle.dart`, `pdfrx_bootstrap.dart`, `pdf_spread_layout.dart`, políticas de swipe/borda/teclado, `pdf_reader_screen.dart`, `test/helpers/pdfium_test_init.dart`, `web/_headers`, scripts.

---

### Task 1: Flutter 3.47.4 + pdfrx 2.6.1

**Files:**
- Modify: `pubspec.yaml:7` (`sdk`), `pubspec.yaml:30` (`pdfrx`)
- Modify: `pubspec.lock` (gerado por `flutter pub get`)
- Modify: `docs/DEP_UPGRADE_BACKLOG.md:39` (linha do `pdfrx`)
- Modify: `docs/adr/ADR-002-pdfx-reader.md:12` (versão)
- Modify (só se o analyzer novo apontar): arquivos com lints novos, correção mínima.

**Interfaces:**
- Consumes: nada.
- Produces: SDK e pacote nas versões da Global Constraints; a suíte inteira verde; `build/web` gerado com o WASM do pdfrx 2.6.1. As Tasks 2–3 dependem das APIs `PdfViewerSizeDelegateProviderLegacy`, `PdfViewerScrollInteractionDelegateProviderPhysics`, `PdfTextSelectionParams`, `PdfViewerParams.getScrollPhysics` (todas exportadas por `package:pdfrx/pdfrx.dart` em 2.6.1).

- [ ] **Step 1: Confirmar o SDK atual e subir para o stable**

Run: `flutter --version`
Expected: `Flutter 3.44.4 • channel stable` (ou já 3.47.x — então pular o upgrade).

Run: `flutter upgrade`
Expected: termina com `Flutter 3.47.4 • channel stable` e `Dart 3.13.3`. Confirmar com `flutter --version`. Se o canal não for `stable`, **não** trocar de canal: reportar `BLOCKED`.

- [ ] **Step 2: Bump no `pubspec.yaml`**

Trocar exatamente estas duas linhas:

```yaml
environment:
  sdk: ">=3.13.0 <4.0.0"
```

```yaml
  pdfrx: ^2.6.1
```

- [ ] **Step 3: Resolver dependências e conferir o lock**

Run: `flutter pub get`
Expected: `Got dependencies!` sem erro de resolução. Se falhar citando outro pacote, colar a saída no report e parar (`BLOCKED`).

Run: `grep -A2 -E '^  (pdfrx|pdfrx_engine|pdfium_flutter|pdfium_dart|material_ui):' pubspec.lock | grep version`
Expected (nesta ordem): `version: "2.6.1"`, `version: "0.6.0"`, `version: "0.3.0"`, `version: "0.3.0"`, `version: "1.x.y"` (qualquer 1.x para `material_ui`).

- [ ] **Step 4: Analyzer limpo**

Run: `flutter analyze`
Expected: `No issues found!`. Se aparecerem lints/deprecations novos do SDK 3.47, corrigir **só** o apontado, no mínimo necessário, e anotar cada arquivo tocado no report. Não usar `// ignore:` para deprecations do próprio app; para deprecations vindas de pacote de terceiros que o app não controla, `// ignore: deprecated_member_use` com comentário do porquê é aceitável.

- [ ] **Step 5: Suíte VM inteira**

Run: `flutter test`
Expected: todos passam (a suíte hoje tem ~600 testes; os 3 de `pdfrx_viewer_adapter_test.dart` grupo «magic bytes (B3)» e os de `test/helpers/pdfium_test_init_test.dart` exercitam o PDFium 0.3.0 novo). Se `ensurePdfiumTestModule` acusar «pdfium nativo ausente»: `rm -rf build/native_assets && flutter test` de novo. Qualquer outra falha é para investigar e reportar, não para skipar.

- [ ] **Step 6: Suíte Chrome e build web WASM**

Run: `flutter test --platform chrome --dart-define-from-file=dart_defines/plpcjf.json test/web/`
Expected: passa. (Se não houver Chrome na máquina — `CHROME_EXECUTABLE` — anotar no report como «não rodado localmente; CI cobre».)

Run: `flutter build web --wasm --dart-define-from-file=dart_defines/plpcjf.json`
Expected: build termina sem erro e `find build/web -name 'pdfium*.wasm' | head -1` imprime um caminho (o WASM do `pdfrx_engine` 0.6.0 está no bundle). `build/` é gitignored — nada a commitar.

- [ ] **Step 7: Registrar as versões nos docs**

`docs/DEP_UPGRADE_BACKLOG.md`, linha 39 — de:

```
| `pdfrx` | 2.4.4 | 2.4.4 | Não | Fase C concluída ✅ |
```

para:

```
| `pdfrx` | 2.6.1 | 2.6.1 | Não | Fase C concluída ✅; 2.6.1 em set/2026 (fix de preview cancelado/evictado — Flutter ≥ 3.47) |
```

`docs/adr/ADR-002-pdfx-reader.md`, linha 12 — de:

```
Usar **pdfrx** (^2.4.4, PDFium + SPM via `pdfium_flutter`) como viewer PDF no Flutter.
```

para:

```
Usar **pdfrx** (^2.6.1, PDFium + SPM via `pdfium_flutter`; exige Flutter ≥ 3.47) como viewer PDF no Flutter.
```

- [ ] **Step 8: Commit**

```bash
git add pubspec.yaml pubspec.lock docs/DEP_UPGRADE_BACKLOG.md docs/adr/ADR-002-pdfx-reader.md
# + os arquivos com correção de lint do Step 4, se houver
git commit -m "chore(deps): Flutter 3.47.4 e pdfrx 2.6.1 (fix de preview cancelado/evictado)" -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01X2ZyEPGitn4bV7FhAk7u4j"
```

---

### Task 2: `PdfRenderScalePolicy` — teto de escala único (Fase 1.3)

**Files:**
- Create: `lib/features/pdf_reader/presentation/utils/pdf_render_scale_policy.dart`
- Test: `test/unit/features/pdf_reader/pdf_render_scale_policy_test.dart`

**Interfaces:**
- Consumes: nada.
- Produces: `abstract final class PdfRenderScalePolicy { static const double ceiling = 3.0; static const int dprMultiplier = 2; static double resolve({required double estimatedScale, required double devicePixelRatio}); }` — a Task 3 usa `PdfRenderScalePolicy.ceiling` no `sizeDelegateProvider` e `resolve` no `getPageRenderingScale`.

- [ ] **Step 1: Escrever o teste que falha**

`test/unit/features/pdf_reader/pdf_render_scale_policy_test.dart`:

```dart
import 'package:coldigui/features/pdf_reader/presentation/utils/pdf_render_scale_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PdfRenderScalePolicy.resolve — min(estimada, 2×DPR, 3.0)', () {
    test('estimativa abaixo dos dois tetos passa intacta', () {
      expect(
        PdfRenderScalePolicy.resolve(estimatedScale: 2.5, devicePixelRatio: 3),
        2.5,
      );
    });

    test('tela de alto DPR bate no teto absoluto 3.0', () {
      expect(
        PdfRenderScalePolicy.resolve(estimatedScale: 8, devicePixelRatio: 3),
        3.0,
      );
    });

    test('tela 1× (desktop) bate no teto por DPR (2×1)', () {
      expect(
        PdfRenderScalePolicy.resolve(estimatedScale: 3, devicePixelRatio: 1),
        2.0,
      );
    });

    test('tela 1.5× — os dois tetos coincidem em 3.0', () {
      expect(
        PdfRenderScalePolicy.resolve(estimatedScale: 4, devicePixelRatio: 1.5),
        3.0,
      );
    });

    test('constantes da spec §2.3', () {
      expect(PdfRenderScalePolicy.ceiling, 3.0);
      expect(PdfRenderScalePolicy.dprMultiplier, 2);
    });
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/pdf_reader/pdf_render_scale_policy_test.dart`
Expected: FAIL na compilação — `Target of URI doesn't exist: '.../pdf_render_scale_policy.dart'`.

- [ ] **Step 3: Implementar**

`lib/features/pdf_reader/presentation/utils/pdf_render_scale_policy.dart`:

```dart
import 'dart:math' as math;

/// Política de escala de rasterização do leitor (diagnóstico pdfrx, Fase 1.3).
///
/// As partituras do catálogo são scans de ~210 dpi (≈ 2,9× sobre os 72 pt do
/// PDF): acima de ~3× o PDFium só interpola pixels que já existem, gastando
/// CPU e memória sem ganho visual. Antes o nativo rasterizava sem teto (até
/// 8× no pinch) e a web tinha só o teto por DPR; agora a mesma regra vale
/// para todas as plataformas. Sem import `pdfrx` (ADR-002).
abstract final class PdfRenderScalePolicy {
  /// Teto absoluto (unidades do documento → pixels físicos).
  static const double ceiling = 3.0;

  /// Teto relativo ao DPR — numa tela 1× (desktop) 2× já cobre o zoom usual e
  /// evita bitmaps que a viewport não mostra.
  static const int dprMultiplier = 2;

  /// `min(estimatedScale, dprMultiplier × devicePixelRatio, ceiling)`.
  static double resolve({
    required double estimatedScale,
    required double devicePixelRatio,
  }) {
    final dprCeiling = dprMultiplier * devicePixelRatio;
    return math.min(estimatedScale, math.min(dprCeiling, ceiling));
  }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/unit/features/pdf_reader/pdf_render_scale_policy_test.dart`
Expected: 5 testes PASS. `flutter analyze lib/features/pdf_reader/presentation/utils/pdf_render_scale_policy.dart test/unit/features/pdf_reader/pdf_render_scale_policy_test.dart` → `No issues found!`.

- [ ] **Step 5: Commit**

```bash
git add lib/features/pdf_reader/presentation/utils/pdf_render_scale_policy.dart test/unit/features/pdf_reader/pdf_render_scale_policy_test.dart
git commit -m "feat(leitor): PdfRenderScalePolicy — teto de escala 3× calibrado pelos scans" -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01X2ZyEPGitn4bV7FhAk7u4j"
```

---

### Task 3: `buildPdfReaderViewerParams` — parâmetros do viewer para partitura (Fases 1.2, 1.3, 1.4)

**Files:**
- Modify: `lib/features/pdf_reader/presentation/widgets/pdf_reader_pdf_view.dart:1,22-30,379-457`
- Create: `test/unit/features/pdf_reader/pdf_reader_viewer_params_test.dart`
- Create: `test/widget/features/pdf_reader/pdf_reader_pdf_view_test.dart`
- Modify: `docs/adr/ADR-002-pdfx-reader.md:16-23,40-43`

**Interfaces:**
- Consumes: `PdfRenderScalePolicy.ceiling` e `PdfRenderScalePolicy.resolve({estimatedScale, devicePixelRatio})` (Task 2); de `pdfrx` 2.6.1: `PdfViewerSizeDelegateProviderLegacy`, `PdfViewerScrollInteractionDelegateProviderPhysics`, `PdfTextSelectionParams`, `PdfAnnotationRenderingMode`, `PdfViewerParams.getScrollPhysics(BuildContext)`, typedefs `PdfViewerReadyCallback = void Function(PdfDocument, PdfViewerController)`, `PdfPageChangedCallback = void Function(int?)`, `PdfPageLayoutFunction = PdfPageLayout Function(List<PdfPage>, PdfViewerParams)`. Helpers de teste: `createTrackableHandle`, `FakePdfPage` em `test/unit/features/pdf_reader/pdf_reader_test_helpers.dart`; `sharedPreferencesProvider` em `lib/core/providers/shared_prefs_provider.dart`.
- Produces (top-level em `pdf_reader_pdf_view.dart`):
  - `const kPdfWebMaxImageBytesCachedOnMemory = 64 << 20;`
  - `const kPdfReaderSizeDelegateProvider = PdfViewerSizeDelegateProviderLegacy(onePassRenderingScaleThreshold: PdfRenderScalePolicy.ceiling);`
  - `@visibleForTesting PdfViewerParams buildPdfReaderViewerParams({required bool isWeb, required ScrollPhysics scrollPhysics, required PdfViewerReadyCallback onViewerReady, required PdfPageChangedCallback onPageChanged, PdfPageLayoutFunction? layoutPages})`
  - `kPdfWebRenderScaleDprMultiplier` **deixa de existir** (ninguém fora do arquivo o usa — verificado com grep em `lib/` e `test/`).

- [ ] **Step 1: Escrever os testes unitários da função (falham)**

`test/unit/features/pdf_reader/pdf_reader_viewer_params_test.dart`:

```dart
import 'package:coldigui/features/pdf_reader/presentation/utils/pdf_render_scale_policy.dart';
import 'package:coldigui/features/pdf_reader/presentation/widgets/pdf_reader_pdf_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

import 'pdf_reader_test_helpers.dart';

const _physics = ClampingScrollPhysics();

PdfViewerParams _params({
  bool isWeb = false,
  PdfPageLayoutFunction? layoutPages,
}) {
  return buildPdfReaderViewerParams(
    isWeb: isWeb,
    scrollPhysics: _physics,
    onViewerReady: (_, _) {},
    onPageChanged: (_) {},
    layoutPages: layoutPages,
  );
}

void main() {
  group('Fase 1.2 — desliga o que partitura escaneada não usa', () {
    test('seleção de texto desligada', () {
      expect(_params().textSelectionParams?.enabled, isFalse);
    });

    test('sem anotações, sem sombra por frame, sem limite de cache do PDFium',
        () {
      final params = _params();
      expect(params.annotationRenderingMode, PdfAnnotationRenderingMode.none);
      expect(params.pageDropShadow, isNull);
      expect(params.limitRenderingCache, isFalse);
    });
  });

  group('Fase 1.3 — uma política de escala para todas as plataformas', () {
    test('preview rasterizado no teto da política (3.0), via const provider',
        () {
      expect(_params().sizeDelegateProvider, kPdfReaderSizeDelegateProvider);
      expect(
        kPdfReaderSizeDelegateProvider.onePassRenderingScaleThreshold,
        PdfRenderScalePolicy.ceiling,
      );
      // Demais campos iguais ao default que o app já usava.
      expect(kPdfReaderSizeDelegateProvider.maxScale, 8.0);
      expect(kPdfReaderSizeDelegateProvider.minScale, 0.1);
      expect(kPdfReaderSizeDelegateProvider.useAlternativeFitScaleAsMinScale,
          isTrue);
    });

    testWidgets('getPageRenderingScale segue PdfRenderScalePolicy no nativo e na web',
        (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 3),
          child: Builder(
            builder: (ctx) {
              context = ctx;
              return const SizedBox();
            },
          ),
        ),
      );
      final page = FakePdfPage(1);
      final controller = PdfViewerController();

      for (final isWeb in [false, true]) {
        final scale = _params(isWeb: isWeb).getPageRenderingScale!;
        expect(scale(context, page, controller, 8.0), 3.0,
            reason: 'isWeb=$isWeb: teto absoluto');
        expect(scale(context, page, controller, 2.5), 2.5,
            reason: 'isWeb=$isWeb: estimativa baixa passa');
      }
    });

    testWidgets('em tela 1× o teto por DPR (2.0) vence', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 1),
          child: Builder(
            builder: (ctx) {
              context = ctx;
              return const SizedBox();
            },
          ),
        ),
      );
      final scale = _params().getPageRenderingScale!;
      expect(scale(context, FakePdfPage(1), PdfViewerController(), 3.0), 2.0);
    });

    test('cache de imagem: 64 MiB na web, default do pacote no nativo', () {
      expect(kPdfWebMaxImageBytesCachedOnMemory, 64 << 20);
      expect(
        _params(isWeb: true).maxImageBytesCachedOnMemory,
        kPdfWebMaxImageBytesCachedOnMemory,
      );
      expect(
        _params().maxImageBytesCachedOnMemory,
        const PdfViewerParams().maxImageBytesCachedOnMemory,
      );
    });
  });

  group('Fase 1.4 — física de scroll por plataforma', () {
    test('scrollPhysics é o que o build passou (getScrollPhysics(context))',
        () {
      expect(_params().scrollPhysics, same(_physics));
    });

    test('roda/trackpad com inércia (delegate Physics)', () {
      expect(
        _params().interactionDelegateProvider,
        isA<PdfViewerScrollInteractionDelegateProviderPhysics>(),
      );
    });
  });

  group('inalterados', () {
    test('layoutPages passa direto (spread ou null)', () {
      PdfPageLayout layout(List<PdfPage> pages, PdfViewerParams params) =>
          PdfPageLayout(pageLayouts: const [], documentSize: Size.zero);
      expect(_params().layoutPages, isNull);
      expect(_params(layoutPages: layout).layoutPages, same(layout));
    });

    test('banners de loading e erro continuam definidos', () {
      final params = _params();
      expect(params.loadingBannerBuilder, isNotNull);
      expect(params.errorBannerBuilder, isNotNull);
    });
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/pdf_reader/pdf_reader_viewer_params_test.dart`
Expected: FAIL na compilação — `buildPdfReaderViewerParams` / `kPdfReaderSizeDelegateProvider` não definidos.

- [ ] **Step 3: Escrever o teste de widget (falha)**

`test/widget/features/pdf_reader/pdf_reader_pdf_view_test.dart`:

```dart
import 'dart:io';

import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/widgets/pdf_reader_pdf_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../unit/features/pdf_reader/pdf_reader_test_helpers.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('pdf_view_params_');
    // O PdfViewer chama pdfrxFlutterInitialize, que pede o diretório de cache
    // ao path_provider — mesmo mock do pdfrx_viewer_adapter_test.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => tempDir.path,
        );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  testWidgets(
    'PdfReaderPdfView entrega ao PdfViewer os params do leitor com a física da plataforma',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final handle = createTrackableHandle(pageCount: 2);
      addTearDown(handle.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            home: Scaffold(
              body: PdfReaderPdfView(
                handle: handle,
                navigateToPage: (_) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final viewer = tester.widget<PdfViewer>(find.byType(PdfViewer));
      final params = viewer.params;
      expect(params.textSelectionParams?.enabled, isFalse);
      expect(params.pageDropShadow, isNull);
      expect(params.sizeDelegateProvider, kPdfReaderSizeDelegateProvider);
      expect(params.scrollPhysics, isNotNull);
      expect(
        params.interactionDelegateProvider,
        isA<PdfViewerScrollInteractionDelegateProviderPhysics>(),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    },
  );
}
```

Run: `flutter test test/widget/features/pdf_reader/pdf_reader_pdf_view_test.dart`
Expected: FAIL na compilação (`kPdfReaderSizeDelegateProvider` não definido).

- [ ] **Step 4: Implementar em `pdf_reader_pdf_view.dart`**

(a) Remover a linha 1 `import 'dart:math' as math;` e adicionar, junto dos imports relativos (ordem alfabética, antes de `pdf_spread_layout.dart`):

```dart
import '../utils/pdf_render_scale_policy.dart';
```

(b) Substituir as linhas 22–30 (docs + `kPdfWebRenderScaleDprMultiplier` + `kPdfWebMaxImageBytesCachedOnMemory`) por:

```dart
/// Teto de bytes de imagem cacheados em memória na web — 64 MiB (spec A.13
/// dizia 32 MiB, calibrados para preview a 2,78×). Spread = duas páginas A5
/// (420×586 pt) a 3× ≈ 1260×1758 px × 4 B ≈ 8,9 MB cada, mais os tiles do
/// pinch; com 32 MiB o par visível era evictado e re-renderizado ao voltar
/// (diagnóstico pdfrx, Fase 1.3).
const kPdfWebMaxImageBytesCachedOnMemory = 64 << 20;

/// Provider de tamanho do pdfrx com o preview de cada página rasterizado a
/// [PdfRenderScalePolicy.ceiling] (default do pacote: 200/72 ≈ 2,78×). Com o
/// teto igual ao da política, o preview já é a imagem final na maioria dos
/// zooms e os tiles «real size» só entram em pinch forte. Precisa ser `const`:
/// `PdfViewerParams.doChangesRequireReload` compara o provider por `==`.
/// Demais campos (maxScale 8, minScale 0.1, fit alternativo como mínimo) são
/// os defaults que o app já usava.
const kPdfReaderSizeDelegateProvider = PdfViewerSizeDelegateProviderLegacy(
  onePassRenderingScaleThreshold: PdfRenderScalePolicy.ceiling,
);

/// Monta os [PdfViewerParams] do leitor — função pura para os testes lerem
/// cada parâmetro sem montar um `PdfViewer` (diagnóstico pdfrx, Fase 1).
///
/// [scrollPhysics] vem de `PdfViewerParams.getScrollPhysics(context)` no
/// `build` (precisa de `BuildContext`); [layoutPages] é o spread ou `null`.
@visibleForTesting
PdfViewerParams buildPdfReaderViewerParams({
  required bool isWeb,
  required ScrollPhysics scrollPhysics,
  required PdfViewerReadyCallback onViewerReady,
  required PdfPageChangedCallback onPageChanged,
  PdfPageLayoutFunction? layoutPages,
}) {
  return PdfViewerParams(
    backgroundColor: AppColors.pdfArea,
    onViewerReady: onViewerReady,
    onPageChanged: onPageChanged,
    layoutPages: layoutPages,
    // Fase 1.2 — partitura escaneada não tem texto selecionável nem
    // anotações. Com seleção ligada (default) o pdfrx carrega o texto
    // estruturado de toda página no cacheExtent, no mesmo worker que
    // renderiza, e instala o reconhecedor de long-press. Desligada, o menu
    // de contexto padrão fica vazio — long-press não abre nada.
    textSelectionParams: const PdfTextSelectionParams(enabled: false),
    // Sem FPDF_FFLDraw por página.
    annotationRenderingMode: PdfAnnotationRenderingMode.none,
    // A sombra default é um blur por página em todo frame do CustomPaint.
    pageDropShadow: null,
    // Deixa o PDFium manter o JPEG decodificado entre renders (scans).
    limitRenderingCache: false,
    // Fase 1.3 — uma política de escala para todas as plataformas (antes só
    // a web tinha teto, e sem o 3.0).
    sizeDelegateProvider: kPdfReaderSizeDelegateProvider,
    getPageRenderingScale: (context, page, controller, estimatedScale) =>
        PdfRenderScalePolicy.resolve(
          estimatedScale: estimatedScale,
          devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        ),
    maxImageBytesCachedOnMemory: isWeb
        ? kPdfWebMaxImageBytesCachedOnMemory
        : const PdfViewerParams().maxImageBytesCachedOnMemory,
    // Fase 1.4 — física da plataforma (bounce iOS / overscroll fixo Android;
    // #677 corrigido em 2.4.8) e roda/trackpad com inércia em vez de saltos
    // de 20% por tick.
    scrollPhysics: scrollPhysics,
    interactionDelegateProvider:
        const PdfViewerScrollInteractionDelegateProviderPhysics(),
    loadingBannerBuilder: (context, bytesDownloaded, totalBytes) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    },
    errorBannerBuilder: (context, error, stackTrace, reload) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            error.toString(),
            style: const TextStyle(color: AppColors.textLight),
            textAlign: TextAlign.center,
          ),
        ),
      );
    },
  );
}
```

(c) Em `_buildPdfContent`, substituir o bloco `params: PdfViewerParams(` … `)` (linhas 405–444, do `params:` até o `),` que fecha antes de `),` do `PdfViewer`) por:

```dart
                params: buildPdfReaderViewerParams(
                  isWeb: isWeb,
                  scrollPhysics: PdfViewerParams.getScrollPhysics(context),
                  onViewerReady: (_, _) => handle.markViewerReady(),
                  onPageChanged: _handleVisiblePageChanged,
                  layoutPages: spreadActive
                      ? (pages, params) => spreadPageLayout(
                          pages,
                          params,
                          viewportAspect: viewportAspect,
                          fallback: defaultPdfPageLayout,
                        )
                      : null,
                ),
```

O `context` aí é o do `LayoutBuilder` (`builder: (context, constraints)`), já no escopo. `isWeb` continua vindo de `ref.watch(platformCapabilitiesProvider).isWeb` (linha 384) — não remover.

(d) Atualizar o doc-comment da classe (linhas 32–35) trocando «pontos de import `pdfrx` na presentation restritos a este arquivo e a [spreadPageLayout]/[defaultPdfPageLayout]» para incluir a função: «… restritos a este arquivo ([buildPdfReaderViewerParams] concentra os parâmetros do viewer — diagnóstico pdfrx, Fase 1) e a [spreadPageLayout]/[defaultPdfPageLayout]».

- [ ] **Step 5: Rodar os dois testes novos e ver passar**

Run: `flutter test test/unit/features/pdf_reader/pdf_reader_viewer_params_test.dart test/widget/features/pdf_reader/pdf_reader_pdf_view_test.dart`
Expected: todos PASS. Se o teste de widget falhar por exceção assíncrona vinda do `PdfViewer` com o `FakePdfDocument` (ex.: `MissingPluginException` ou null-check no layout de `FakePdfPage`), comparar com `test/widget/features/pdf_reader/pdf_reader_screen_test.dart` (que já monta `PdfReaderPdfView` com o mesmo `createTrackableHandle`) e alinhar os overrides/mocks — **não** substituir o assert sobre `PdfViewer.params` por algo mais fraco.

- [ ] **Step 6: Regressão do leitor + analyzer**

Run: `flutter analyze`
Expected: `No issues found!` (em especial nenhum `unused_import` de `dart:math` nem `deprecated_member_use` de `onePassRenderingScaleThreshold`/`maxScale` no `PdfViewerParams` — a spec usa o `sizeDelegateProvider` justamente para não cair no caminho deprecado).

Run: `flutter test test/unit/features/pdf_reader test/widget/features/pdf_reader test/helpers`
Expected: tudo PASS (inclui `pdf_reader_screen_test.dart`, `pdf_reattach_guard_test.dart`, `pdf_horizontal_swipe_indicator_test.dart`, `pdf_spread_layout_test.dart`).

Run: `grep -rn 'kPdfWebRenderScaleDprMultiplier' lib test`
Expected: nenhuma ocorrência.

- [ ] **Step 7: ADR-002 — integração e histórico**

`docs/adr/ADR-002-pdfx-reader.md`, seção «## Integração», trocar a última bullet (linha 23):

```
- Único import pdfrx na presentation: `pdf_reader_pdf_view.dart`
```

por:

```
- Único import pdfrx na presentation: `pdf_reader_pdf_view.dart` (+ `pdf_spread_layout.dart` pelos tipos do layout)
- Parâmetros do viewer em `buildPdfReaderViewerParams` (`pdf_reader_pdf_view.dart`): seleção de texto e anotações desligadas, sem sombra por frame, `limitRenderingCache: false`, preview a 3× (`PdfRenderScalePolicy`, todas as plataformas), física de scroll da plataforma + roda/trackpad com inércia — set/2026, diagnóstico «pdfrx sob a lupa»
```

Seção «## Histórico», acrescentar ao final:

```
- set/2026: Flutter 3.47.4 + pdfrx 2.6.1 (fix de preview cancelado/evictado = página em branco «até mexer») e parâmetros para partitura escaneada — spec `docs/superpowers/specs/2026-09-13-leitor-pdfrx-fase1-design.md`
```

- [ ] **Step 8: Commit**

```bash
git add lib/features/pdf_reader/presentation/widgets/pdf_reader_pdf_view.dart test/unit/features/pdf_reader/pdf_reader_viewer_params_test.dart test/widget/features/pdf_reader/pdf_reader_pdf_view_test.dart docs/adr/ADR-002-pdfx-reader.md
git commit -m "feat(leitor): params do PdfViewer para partitura — sem texto/sombra, escala 3×, física da plataforma" -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01X2ZyEPGitn4bV7FhAk7u4j"
```

---

## Verificação final (controlador, após a Task 3)

1. `./scripts/test_all.sh` (analyze + VM + Chrome) verde no worktree.
2. `flutter build web --wasm --dart-define-from-file=dart_defines/plpcjf.json` sem erro (o CI também roda `verify_web_headers_artifact.sh` e o gate de boot `measure_web_boot.sh --check`; se o gate de boot regredir por causa do bundle novo do pdfrx, é finding para o dono decidir — não recalibrar `docs/web_perf_baseline.json` neste plano).
3. `git log web/integration..HEAD --oneline` mostra exatamente 3 commits (Task 1, 2, 3), cada um com as linhas de atribuição.
4. Entregar ao dono a lista de verificação manual da spec §5 (aba visível em v2.plpcg.com após deploy; iOS/Android em `flutter run --profile`) — o plano não a executa.

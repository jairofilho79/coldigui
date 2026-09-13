# Polimento — leitor PDF, URL/histórico web e tema — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fechar os itens P2, P3, P4, P6, P7 e P8 da auditoria `docs/AUDITORIA_POLIMENTO_2026-09-12.md`: virada de página do PDF sem reaplicar fit (e sem cair no rodapé da última página), URL do navegador refletindo `/leitor`/`/cifra`/`/audio`/`/gestos`, sync de URL da busca/filtros sem poluir o histórico, transição de página leve e snackbars flutuantes que não sobrevivem à entrada nos leitores.

**Architecture:** Nenhuma mudança de modelo ou de rotas. O leitor deixa de chamar `applyInitialFit` após cada virada (só na abertura e no toggle de fullscreen). A URL passa a refletir rotas imperativas pela opção global do go_router (`optionURLReflectsImperativeAPIs`), ligada num único ponto chamado por `main()` — evita tocar os openers/carousel que estão sendo editados em outro worktree. O sync de URL da Home/Biblioteca passa por um helper `goReplacingUrl` que envolve `router.go` em `Router.neglect` (vira `replaceState`). Tema ganha `pageTransitionsTheme` e `snackBarTheme`; `showAppSnackbar` ganha largura máxima e `action`; os três leitores stateful limpam snackbars ao montar.

**Tech Stack:** Flutter 3.44.4 / Dart 3.12, Riverpod 3, go_router 17.3.0, pdfrx 2.4.4, `flutter_test`.

**Spec:** `docs/AUDITORIA_POLIMENTO_2026-09-12.md` (seções B, C e D; itens P2, P3, P4, P6, P7, P8). P1 e P5 ficam **fora** deste plano: P1 depende de medição em tablet e decisão sobre o login Google; P5 já está em execução no plano `2026-09-12-nav-listas-perfil.md` (worktree `feat/nav-listas-perfil`).

## Global Constraints

- **Worktree próprio:** branch `feat/polimento-leitor-nav` criada a partir de `web/integration` em `.claude/worktrees/polimento-leitor-nav`. Nunca commitar direto em `web/integration`.
- **Arquivos proibidos neste plano** (estão sendo editados nos worktrees `feat/barra-lista-ativa` e `feat/nav-listas-perfil` — tocar neles gera conflito de merge): `lib/core/routing/app_router.dart`, `lib/core/routing/route_paths.dart`, `lib/core/widgets/plpcg_primary_app_bar.dart`, `lib/core/constants/app_tabs.dart`, `lib/features/app_shell/presentation/shell_scaffold.dart`, `lib/features/app_shell/presentation/pages/profile_screen.dart`, tudo em `lib/features/carousel/`, `lib/features/playlists/`, `lib/features/audio_player/`, `lib/features/social/`, e `lib/features/pdf_reader/presentation/providers/reader_carousel_position_provider.dart`. Se uma task parecer exigir um deles, parar e reportar `BLOCKED` em vez de editar.
- Comentários e docs em português, estilo dos arquivos vizinhos (`///` explicando o *porquê*, com referência ao item da auditoria quando fizer sentido, ex.: «auditoria P3»).
- Antes de cada commit: `flutter analyze lib test` sem erros nos arquivos tocados e os testes da task passando (`flutter test <arquivo>`). Ao final de cada task, também `flutter test test/widget/features/pdf_reader test/unit/features/pdf_reader` quando a task tocar o leitor.
- Commits com prefixo `fix|feat|refactor|test|docs(escopo):` em português, imperativo, uma linha de assunto. Todo commit termina com:
  ```
  Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01DVQ2ezio1U1Na551mqQVRc
  ```
- Não adicionar dependências. Não alterar `pubspec.yaml`.
- Não reformatar arquivos inteiros: `dart format` só nos arquivos tocados (o projeto já está formatado).

---

## Mapa de arquivos

**Criar**
- `lib/core/routing/go_router_options.dart` — `configureGoRouterGlobals()`: liga `GoRouter.optionURLReflectsImperativeAPIs` (P2).
- `lib/core/routing/url_sync_navigation.dart` — `goReplacingUrl(context, router, location)`: `router.go` dentro de `Router.neglect` (P4).
- `test/unit/core/go_router_options_test.dart`, `test/widget/core/url_sync_navigation_test.dart`, `test/unit/core/app_theme_test.dart`, `test/widget/core/app_snackbar_test.dart`, `test/unit/features/pdf_reader/pdf_reattach_guard_test.dart`.

**Modificar**
- `lib/features/pdf_reader/presentation/widgets/pdf_reader_pdf_view.dart` — remove `refreshViewportAfterNavigation`, `_viewportPolicy`, `_scheduleViewportRefresh` (P3/P6).
- `lib/features/pdf_reader/presentation/pages/pdf_reader_screen.dart` — deixa de passar `refreshViewportAfterNavigation`; chama `clearSnackbarsOnEnter` (P3, P8).
- `lib/main.dart` — chama `configureGoRouterGlobals()` (P2).
- `lib/features/catalog/presentation/pages/home_screen.dart` e `lib/features/library/presentation/pages/library_screen.dart` — sync de URL via `goReplacingUrl` (P4).
- `lib/core/theme/app_theme.dart` — `pageTransitionsTheme` e `snackBarTheme` (P7, P8).
- `lib/core/widgets/app_snackbar.dart` — largura máxima, `action`, `clearPrevious`, `clearSnackbarsOnEnter` (P8).
- `lib/features/catalog/presentation/widgets/louvor_group_card.dart` — usa `showAppSnackbar` com `action` (P8).
- `lib/features/chords/presentation/pages/chord_reader_screen.dart`, `lib/features/gestures/presentation/pages/gesture_reader_screen.dart` — `clearSnackbarsOnEnter` (P8).
- `test/widget/features/pdf_reader/pdf_reader_screen_test.dart` — teste novo de virada sem fit (P3).
- `docs/AUDITORIA_POLIMENTO_2026-09-12.md` — seção de execução.

**Apagar**
- `lib/features/pdf_reader/presentation/utils/pdf_reader_viewport_policy.dart` e `test/unit/features/pdf_reader/pdf_reader_viewport_policy_test.dart` (a classe `PdfReattachGuard` duplicada some; a do view fica).

---

### Task 1: Virar página sem reaplicar o fit (P3 + P6)

**Files:**
- Modify: `lib/features/pdf_reader/presentation/widgets/pdf_reader_pdf_view.dart:16,49,64,92,98,111-113,200-209,389`
- Modify: `lib/features/pdf_reader/presentation/pages/pdf_reader_screen.dart:384-386`
- Delete: `lib/features/pdf_reader/presentation/utils/pdf_reader_viewport_policy.dart`
- Delete: `test/unit/features/pdf_reader/pdf_reader_viewport_policy_test.dart`
- Create: `test/unit/features/pdf_reader/pdf_reattach_guard_test.dart`
- Test: `test/widget/features/pdf_reader/pdf_reader_screen_test.dart`

**Interfaces:**
- Produces: `PdfReaderPdfView` **sem** o parâmetro `refreshViewportAfterNavigation`. Nenhuma outra task depende disto.

**Contexto:** hoje `_navigateToPageWithLock` chama `_scheduleViewportRefresh` → `applyInitialFit()` depois de cada `animateToPage`. Em produção isso produz dois saltos por virada e, na última página, o `goTo(matrix)` do fit é clampado contra a borda do documento e deixa a viewport no rodapé (reproduzido 2× em v2.plpcg.com). O fit inicial em `_handleViewerReady` e o do toggle de fullscreen (`ref.listen(readerFullscreenProvider)` na tela) **continuam** — só a reaplicação por página sai.

- [ ] **Step 1: Escrever o teste que falha (virada não chama fit)**

Em `test/widget/features/pdf_reader/pdf_reader_screen_test.dart`, adicionar os imports (mantendo a ordem alfabética do bloco `package:coldigui/...`):

```dart
import 'package:coldigui/features/pdf_reader/data/providers/pdf_reader_viewer_providers.dart';
import 'package:coldigui/features/pdf_reader/domain/entities/pdf_reader_preferences.dart';
import 'package:coldigui/features/pdf_reader/domain/ports/pdf_reader_controller_port.dart';
import 'package:coldigui/features/pdf_reader/domain/usecases/set_zoom_and_fit_mode.dart';
import 'package:flutter/services.dart';
```

Logo após a classe `_RestoreTrackingHandle` (antes de `_createRestoreTrackingHandle`), adicionar a porta fake:

```dart
/// Porta de fit que só conta chamadas (auditoria P3): o teste mede quantas
/// vezes o leitor pede `applyFitMode` — deve ser uma na abertura e nenhuma
/// por virada de página.
class _CountingFitPort extends Fake implements PdfReaderControllerPort {
  final List<PdfFitMode> applyFitModeCalls = [];

  @override
  Future<void> applyFitMode(PdfFitMode mode) async {
    applyFitModeCalls.add(mode);
  }
}
```

No final de `main()` (depois do último `testWidgets`), adicionar:

```dart
  testWidgets('virar página não reaplica o fit — só a abertura aplica (P3)', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final handle = _createRestoreTrackingHandle(pageCount: 3);
    final fitPort = _CountingFitPort();

    await tester.pumpWidget(
      _readerScope(
        prefs: prefs,
        overrides: [
          pdfReaderSessionProvider('asset:fixtures/sample.pdf').overrideWith(
            (ref) async => PdfReaderSession(
              handle: handle,
              filePath: 'asset:fixtures/sample.pdf',
            ),
          ),
          setZoomAndFitModeProvider.overrideWithValue(
            SetZoomAndFitMode(fitPort),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: PdfReaderScreen(
              queryParams: {
                'file': 'asset:fixtures/sample.pdf',
                'pdfId': 'pdf-x',
                'titulo': 'Fixture',
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // O viewer avisa que está pronto depois do primeiro frame; é aqui que o
    // fit inicial (único permitido) acontece.
    handle.loadingState.value = PdfReaderLoadingState.success;
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (fitPort.applyFitModeCalls.isNotEmpty) break;
    }
    expect(fitPort.applyFitModeCalls, hasLength(1));

    // Seta → próxima página: navega, mas NÃO pode pedir fit de novo.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(handle.animateToPageCalls, [2]);
    expect(
      fitPort.applyFitModeCalls,
      hasLength(1),
      reason: 'a virada de página reaplicou o fit (auditoria P3)',
    );
  });
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `flutter test test/widget/features/pdf_reader/pdf_reader_screen_test.dart --plain-name "virar página não reaplica o fit"`
Expected: FAIL — `applyFitModeCalls` tem 2 elementos após a seta (o segundo vem de `_scheduleViewportRefresh`).

- [ ] **Step 3: Remover a reaplicação no view**

Em `lib/features/pdf_reader/presentation/widgets/pdf_reader_pdf_view.dart`:

1. Apagar a linha `import '../utils/pdf_reader_viewport_policy.dart';`.
2. No construtor de `PdfReaderPdfView`, apagar `this.refreshViewportAfterNavigation,` e o campo com seu doc:
   ```dart
     /// Reaplica fit após troca de página.
     final Future<void> Function()? refreshViewportAfterNavigation;
   ```
3. Em `_PdfReaderPdfViewState`, apagar `late PdfReaderViewportPolicy _viewportPolicy;`, a linha `_viewportPolicy = PdfReaderViewportPolicy(initialPage: widget.handle.page);` do `initState`, e o bloco
   ```dart
         _viewportPolicy = PdfReaderViewportPolicy(
           initialPage: widget.handle.page,
         );
   ```
   do `didUpdateWidget`.
4. Apagar o método `_scheduleViewportRefresh` inteiro.
5. Em `_navigateToPageWithLock`, apagar a linha `_scheduleViewportRefresh(pageNumber: targetPage);` e adicionar o comentário acima do `await`:
   ```dart
       try {
         // Só navega. Reaplicar o fit aqui (comportamento antigo) produzia dois
         // saltos por virada e, na última página, o `goTo` do fit era clampado
         // contra a borda do documento e deixava a viewport no rodapé
         // (auditoria P3/P6). O fit é aplicado na abertura e no toggle de
         // fullscreen, pela tela.
         await widget.navigateToPage(targetPage);
       } finally {
   ```
6. Atualizar o doc da classe `PdfReaderPdfView`: trocar a frase «Handles reutilizados do cache LRU exigem…» mantendo-a, e nada mais é preciso; garantir que nenhum `///` cite `refreshViewportAfterNavigation`.

Em `lib/features/pdf_reader/presentation/pages/pdf_reader_screen.dart`, apagar as três linhas:
```dart
          refreshViewportAfterNavigation: () => ref
              .read(pdfReaderViewSettingsProvider.notifier)
              .applyInitialFit(),
```
e, no doc da classe `PdfReaderScreen`, trocar «Fit mode é reaplicado pós-frame quando a sessão PDF carrega ou ao alternar fullscreen» por «Fit mode é aplicado quando o viewer fica pronto ([_handleViewerReady]) e ao alternar fullscreen — nunca por virada de página (auditoria P3).»

- [ ] **Step 4: Apagar a policy morta e preservar o teste do guard**

```bash
git rm lib/features/pdf_reader/presentation/utils/pdf_reader_viewport_policy.dart
git rm test/unit/features/pdf_reader/pdf_reader_viewport_policy_test.dart
```

Criar `test/unit/features/pdf_reader/pdf_reattach_guard_test.dart`:

```dart
import 'package:coldigui/features/pdf_reader/presentation/widgets/pdf_reader_pdf_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PdfReattachGuard', () {
    test('permite apenas um agendamento até complete', () {
      final guard = PdfReattachGuard();

      expect(guard.trySchedule(), isTrue);
      expect(guard.trySchedule(), isFalse);

      guard.complete();
      expect(guard.trySchedule(), isTrue);
    });
  });
}
```

Confirmar que não sobrou referência: `grep -rn "PdfReaderViewportPolicy\|refreshViewportAfterNavigation\|pdf_reader_viewport_policy" lib test` deve retornar vazio.

- [ ] **Step 5: Rodar os testes do leitor**

Run: `flutter analyze lib test && flutter test test/widget/features/pdf_reader test/unit/features/pdf_reader`
Expected: analyze sem issues; todos os testes passando, incluindo o novo.

- [ ] **Step 6: Commit**

```bash
git add -A lib/features/pdf_reader test/unit/features/pdf_reader test/widget/features/pdf_reader
git commit -m "fix(pdf_reader): não reaplicar fit a cada virada de página (P3/P6)" -m "Virar para a última página deixava a viewport no rodapé: o applyInitialFit pós-navegação era clampado pelo pdfrx contra a borda do documento. O fit fica só na abertura e no toggle de fullscreen. Remove PdfReaderViewportPolicy (morta) e a cópia duplicada de PdfReattachGuard." -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01DVQ2ezio1U1Na551mqQVRc"
```

---

### Task 2: URL do navegador reflete `/leitor`, `/cifra`, `/audio`, `/gestos` (P2)

**Files:**
- Create: `lib/core/routing/go_router_options.dart`
- Modify: `lib/main.dart:19-21`
- Test: `test/unit/core/go_router_options_test.dart`

**Interfaces:**
- Produces: `void configureGoRouterGlobals()` em `package:coldigui/core/routing/go_router_options.dart`. Chamada uma vez em `main()` antes de `runApp`.

**Contexto:** os openers usam `context.push`/`context.replace` e o go_router 17 só reflete rotas imperativas na URL quando `GoRouter.optionURLReflectsImperativeAPIs == true` (`go_router-17.3.0/lib/src/parser.dart:257-282`). Sem isso, F5 no leitor volta para a Home. Trocar os openers por `go` seria a solução idiomática, mas os arquivos deles estão sendo editados em `feat/barra-lista-ativa` (ver Global Constraints) — a opção global resolve o sintoma sem tocar neles. Verificado em produção que o deep link `/#/leitor?file=…&pdfId=…&titulo=…` já abre o leitor.

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/unit/core/go_router_options_test.dart`:

```dart
import 'package:coldigui/core/routing/go_router_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Router mínimo com a mesma forma do app: `/leitor` filha de `/`.
GoRouter _buildRouter() {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Text('home'),
        routes: [
          GoRoute(path: 'leitor', builder: (_, _) => const Text('leitor')),
        ],
      ),
    ],
  );
}

void main() {
  final original = GoRouter.optionURLReflectsImperativeAPIs;
  tearDown(() => GoRouter.optionURLReflectsImperativeAPIs = original);

  testWidgets('sem a opção, push não muda a URL reportada (controle)', (
    tester,
  ) async {
    GoRouter.optionURLReflectsImperativeAPIs = false;
    final router = _buildRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.push('/leitor?file=x');
    await tester.pumpAndSettle();

    expect(find.text('leitor'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/');
  });

  testWidgets('configureGoRouterGlobals faz push refletir na URL (P2)', (
    tester,
  ) async {
    configureGoRouterGlobals();
    final router = _buildRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.push('/leitor?file=x');
    await tester.pumpAndSettle();

    final uri = router.routeInformationProvider.value.uri;
    expect(uri.path, '/leitor');
    expect(uri.queryParameters['file'], 'x');
  });

  testWidgets('replace na rota empilhada também reflete na URL (P2)', (
    tester,
  ) async {
    configureGoRouterGlobals();
    final router = _buildRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.push('/leitor?file=x');
    await tester.pumpAndSettle();
    router.replace('/leitor?file=y');
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.queryParameters['file'], 'y');
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha por compilação**

Run: `flutter test test/unit/core/go_router_options_test.dart`
Expected: FAIL — `go_router_options.dart` não existe.

- [ ] **Step 3: Criar o helper**

`lib/core/routing/go_router_options.dart`:

```dart
import 'package:go_router/go_router.dart';

/// Opções globais (estáticas) do go_router — chamada uma vez em `main()`.
///
/// `optionURLReflectsImperativeAPIs`: os leitores (`/leitor`, `/cifra`,
/// `/audio`, `/gestos`) entram por `context.push`/`context.replace`, e o
/// go_router só escreve essas rotas na URL do navegador com esta opção. Sem
/// ela, F5 (ou a aba descartada pelo tablet e recarregada ao voltar do
/// WhatsApp) volta para a Home e a partitura aberta some; o link copiado da
/// barra também não leva ao louvor (auditoria P2, medido em v2.plpcg.com).
///
/// A alternativa idiomática — `context.go` nos openers, já que `/leitor` é
/// filha de `/` — fica para quando `feat/barra-lista-ativa` entrar, porque
/// toca os mesmos arquivos do carousel. Só afeta a web.
void configureGoRouterGlobals() {
  GoRouter.optionURLReflectsImperativeAPIs = true;
}
```

Em `lib/main.dart`, adicionar o import `import 'core/routing/go_router_options.dart';` (ordem alfabética entre `core/providers/shared_prefs_provider.dart` e `features/...`) e, dentro de `runZonedGuarded`, logo após `installErrorHandlers(_errorReporter);`:

```dart
      configureGoRouterGlobals();
```

- [ ] **Step 4: Rodar o teste**

Run: `flutter analyze lib test && flutter test test/unit/core/go_router_options_test.dart`
Expected: 3 testes passando.

- [ ] **Step 5: Commit**

```bash
git add lib/core/routing/go_router_options.dart lib/main.dart test/unit/core/go_router_options_test.dart
git commit -m "fix(routing): URL do navegador reflete leitor/cifra/áudio abertos por push (P2)" -m "F5 no leitor voltava à Home porque o go_router não escreve rotas imperativas na URL sem optionURLReflectsImperativeAPIs. Ligado em um ponto único chamado por main()." -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01DVQ2ezio1U1Na551mqQVRc"
```

---

### Task 3: Sync de URL da busca e filtros sem criar histórico (P4)

**Files:**
- Create: `lib/core/routing/url_sync_navigation.dart`
- Modify: `lib/features/catalog/presentation/pages/home_screen.dart:165`
- Modify: `lib/features/library/presentation/pages/library_screen.dart:247`
- Test: `test/widget/core/url_sync_navigation_test.dart`

**Interfaces:**
- Produces: `void goReplacingUrl(BuildContext context, GoRouter router, String location)` em `package:coldigui/core/routing/url_sync_navigation.dart`.

**Contexto:** `HomeScreen._applyUrlSyncFromState` e `LibraryScreen._applyUrlSyncFromState` chamam `goRouter.go(target)` a cada mudança de query/filtro/página. O go_router reporta `go` como `RouteInformationReportingType.none` e, fora do primeiro frame, isso vira `pushState` (`information_provider.dart:130-150`) — o botão voltar do navegador percorre `sangue` → `sangue de` → `sangue de jesus`. `Router.neglect` força o report como `neglect` → `replaceState`.

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/widget/core/url_sync_navigation_test.dart`:

```dart
import 'package:coldigui/core/routing/url_sync_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Captura o que o Router reporta ao navegador (`routeInformationUpdated`):
/// é o mesmo canal que, na web, vira `history.pushState`/`replaceState`.
class _NavigationChannelSpy {
  final List<MethodCall> calls = [];

  void install(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.navigation,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.navigation,
        null,
      ),
    );
  }

  /// Último `routeInformationUpdated` — `null` se nenhum foi reportado.
  MethodCall? get lastUpdate {
    for (final call in calls.reversed) {
      if (call.method == 'routeInformationUpdated') return call;
    }
    return null;
  }

  void clear() => calls.clear();
}

GoRouter _buildRouter() {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Column(
          children: [
            Text('q=${state.uri.queryParameters['pesquisa'] ?? ''}'),
            TextButton(
              onPressed: () => goReplacingUrl(
                context,
                GoRouter.of(context),
                '/?pesquisa=abc',
              ),
              child: const Text('sync'),
            ),
            TextButton(
              onPressed: () => GoRouter.of(context).go('/?pesquisa=xyz'),
              child: const Text('go'),
            ),
          ],
        ),
      ),
    ],
  );
}

void main() {
  testWidgets('goReplacingUrl navega e reporta replace=true (P4)', (
    tester,
  ) async {
    final spy = _NavigationChannelSpy()..install(tester);
    final router = _buildRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    spy.clear();

    await tester.tap(find.text('sync'));
    await tester.pumpAndSettle();

    expect(find.text('q=abc'), findsOneWidget);
    final update = spy.lastUpdate;
    expect(update, isNotNull, reason: 'nada foi reportado ao navegador');
    final args = update!.arguments as Map<Object?, Object?>;
    expect(args['uri'], contains('pesquisa=abc'));
    expect(args['replace'], isTrue);
  });

  testWidgets('go comum reporta replace=false (controle)', (tester) async {
    final spy = _NavigationChannelSpy()..install(tester);
    final router = _buildRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    spy.clear();

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('q=xyz'), findsOneWidget);
    final args = spy.lastUpdate!.arguments as Map<Object?, Object?>;
    expect(args['uri'], contains('pesquisa=xyz'));
    expect(args['replace'], isFalse);
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha por compilação**

Run: `flutter test test/widget/core/url_sync_navigation_test.dart`
Expected: FAIL — `url_sync_navigation.dart` não existe.

- [ ] **Step 3: Criar o helper e usar na Home e na Biblioteca**

`lib/core/routing/url_sync_navigation.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// `router.go(location)` sem criar entrada no histórico do navegador.
///
/// Uso: espelhar estado de UI na URL (texto da busca, filtros, página da
/// Biblioteca). O go_router reporta `go` como navegação normal e, na web,
/// isso vira `history.pushState` — cada termo digitado virava uma entrada e
/// o botão voltar percorria `sangue` → `sangue de` → `sangue de jesus`
/// (auditoria P4). [Router.neglect] marca o report como `neglect`, que o
/// engine traduz em `replaceState`.
///
/// [context] precisa estar abaixo do [Router] (qualquer tela do app serve).
void goReplacingUrl(BuildContext context, GoRouter router, String location) {
  Router.neglect(context, () => router.go(location));
}
```

Em `lib/features/catalog/presentation/pages/home_screen.dart`: adicionar `import '../../../../core/routing/url_sync_navigation.dart';` junto aos imports relativos de `core/` já existentes (ordem alfabética), e em `_applyUrlSyncFromState` trocar

```dart
    _suppressSearchHydrationFromOwnUrlSync = true;
    goRouter.go(target);
```
por
```dart
    _suppressSearchHydrationFromOwnUrlSync = true;
    // replaceState, não pushState: digitar não pode poluir o voltar (P4).
    goReplacingUrl(context, goRouter, target);
```

Em `lib/features/library/presentation/pages/library_screen.dart`: mesmo import (ajustar o número de `../` ao caminho do arquivo — `../../../../core/routing/url_sync_navigation.dart`) e em `_applyUrlSyncFromState` trocar

```dart
    if (buildLibraryLocationFromUri(uri) == target) return;
    goRouter.go(target);
```
por
```dart
    if (buildLibraryLocationFromUri(uri) == target) return;
    // Filtros, ordenação e página espelham estado — replaceState (P4).
    goReplacingUrl(context, goRouter, target);
```

Se o arquivo usar imports `package:coldigui/...` em vez de relativos, seguir o estilo do arquivo.

- [ ] **Step 4: Rodar os testes**

Run: `flutter analyze lib test && flutter test test/widget/core/url_sync_navigation_test.dart test/widget/features/catalog test/widget/features/library`
Expected: tudo passando.

- [ ] **Step 5: Commit**

```bash
git add lib/core/routing/url_sync_navigation.dart lib/features/catalog/presentation/pages/home_screen.dart lib/features/library/presentation/pages/library_screen.dart test/widget/core/url_sync_navigation_test.dart
git commit -m "fix(routing): sync de URL da busca e da Biblioteca sem criar histórico (P4)" -m "Router.neglect em volta do go: o navegador recebe replaceState em vez de pushState, e o voltar deixa de percorrer cada termo digitado." -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01DVQ2ezio1U1Na551mqQVRc"
```

---

### Task 4: Transição de página leve em todas as plataformas (P7)

**Files:**
- Modify: `lib/core/theme/app_theme.dart:28-41`
- Test: `test/unit/core/app_theme_test.dart`

**Interfaces:**
- Produces: `AppTheme.light.pageTransitionsTheme` com `FadeForwardsPageTransitionsBuilder` para todos os `TargetPlatform`. Task 5 adiciona `snackBarTheme` ao mesmo `ThemeData` — não conflita.

**Contexto:** sem `pageTransitionsTheme`, a web usa a transição do `defaultTargetPlatform` (Cupertino slide + parallax em Mac/iPad), animando o shell inteiro a cada push/pop e a cada `replace` do carousel dentro do leitor.

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/unit/core/app_theme_test.dart`:

```dart
import 'package:coldigui/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transição de página é fade em todas as plataformas (P7)', () {
    final builders = AppTheme.light.pageTransitionsTheme.builders;
    for (final platform in TargetPlatform.values) {
      expect(
        builders[platform],
        isA<FadeForwardsPageTransitionsBuilder>(),
        reason: 'plataforma $platform sem fade',
      );
    }
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/unit/core/app_theme_test.dart`
Expected: FAIL — `builders[TargetPlatform.iOS]` é `CupertinoPageTransitionsBuilder`.

- [ ] **Step 3: Configurar o tema**

Em `lib/core/theme/app_theme.dart`, dentro de `ThemeData(` logo após `scaffoldBackgroundColor: AppColors.background,`:

```dart
      // Fade em vez do slide da plataforma: na web o `defaultTargetPlatform`
      // é macOS/iOS em Mac e iPad e o Cupertino slide animava o shell inteiro
      // a cada push/pop e a cada troca de louvor no leitor (auditoria P7).
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          for (final platform in TargetPlatform.values)
            platform: FadeForwardsPageTransitionsBuilder(),
        },
      ),
```

Se o `const` com collection-for não compilar (Dart exige elementos constantes — `FadeForwardsPageTransitionsBuilder()` tem construtor const, então deve compilar), remover o `const` do `PageTransitionsTheme`.

- [ ] **Step 4: Rodar os testes**

Run: `flutter analyze lib test && flutter test test/unit/core/app_theme_test.dart test/widget/features/app_shell`
Expected: passando (os testes do shell não dependem da transição).

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/app_theme.dart test/unit/core/app_theme_test.dart
git commit -m "feat(theme): transição de página em fade em todas as plataformas (P7)" -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01DVQ2ezio1U1Na551mqQVRc"
```

---

### Task 5: Snackbars flutuantes, com largura máxima, e limpos ao entrar nos leitores (P8)

**Files:**
- Modify: `lib/core/widgets/app_snackbar.dart`
- Modify: `lib/core/theme/app_theme.dart` (adicionar `snackBarTheme`)
- Modify: `lib/features/catalog/presentation/widgets/louvor_group_card.dart:179-190`
- Modify: `lib/features/pdf_reader/presentation/pages/pdf_reader_screen.dart` (`initState`)
- Modify: `lib/features/chords/presentation/pages/chord_reader_screen.dart:58-61`
- Modify: `lib/features/gestures/presentation/pages/gesture_reader_screen.dart:50-53`
- Test: `test/widget/core/app_snackbar_test.dart`

**Interfaces:**
- Produces:
  - `const double kAppSnackbarMaxWidth = 480;`
  - `double appSnackbarWidth(double screenWidth)` → `min(kAppSnackbarMaxWidth, screenWidth - 32)`.
  - `void showAppSnackbar(BuildContext context, String message, {SnackBarAction? action, bool clearPrevious = false})` — assinatura compatível com as 34 chamadas existentes (parâmetros novos são opcionais).
  - `void clearSnackbarsOnEnter(BuildContext context)` — agenda `clearSnackBars()` pós-frame.

**Contexto:** em produção a 1568 px o snackbar «Adicionado à lista … Trocar material» ocupa 100 % da largura com texto e ação nos cantos opostos, e continua visível ao entrar no leitor cobrindo o rodapé do PDF/cifra.

- [ ] **Step 1: Escrever os testes que falham**

Criar `test/widget/core/app_snackbar_test.dart`:

```dart
import 'package:coldigui/core/theme/app_theme.dart';
import 'package:coldigui/core/widgets/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tela que limpa snackbars ao montar — o que os leitores fazem (P8).
class _ClearingScreen extends StatefulWidget {
  const _ClearingScreen();

  @override
  State<_ClearingScreen> createState() => _ClearingScreenState();
}

class _ClearingScreenState extends State<_ClearingScreen> {
  @override
  void initState() {
    super.initState();
    clearSnackbarsOnEnter(context);
  }

  @override
  Widget build(BuildContext context) => const Text('leitor');
}

Future<void> _pumpApp(WidgetTester tester, {required double width}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              TextButton(
                onPressed: () => showAppSnackbar(context, 'Olá'),
                child: const Text('mostrar'),
              ),
              TextButton(
                onPressed: () => showAppSnackbar(
                  context,
                  'Com ação',
                  action: SnackBarAction(label: 'Trocar', onPressed: () {}),
                  clearPrevious: true,
                ),
                child: const Text('com ação'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: _ClearingScreen()),
                  ),
                ),
                child: const Text('abrir leitor'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  test('appSnackbarWidth limita a 480 em tela larga e a largura-32 em tela estreita', () {
    expect(appSnackbarWidth(1600), kAppSnackbarMaxWidth);
    expect(appSnackbarWidth(400), 368);
  });

  testWidgets('showAppSnackbar flutua com largura máxima em tela larga (P8)', (
    tester,
  ) async {
    await _pumpApp(tester, width: 1600);
    await tester.tap(find.text('mostrar'));
    await tester.pump();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.behavior, SnackBarBehavior.floating);
    expect(snackBar.width, kAppSnackbarMaxWidth);
  });

  testWidgets('showAppSnackbar cabe em tela estreita', (tester) async {
    await _pumpApp(tester, width: 400);
    await tester.tap(find.text('mostrar'));
    await tester.pump();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.width, 368);
    expect(tester.takeException(), isNull);
  });

  testWidgets('action e clearPrevious substituem o snackbar anterior', (
    tester,
  ) async {
    await _pumpApp(tester, width: 1600);
    await tester.tap(find.text('mostrar'));
    await tester.pump();
    await tester.tap(find.text('com ação'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Olá'), findsNothing);
    expect(find.text('Com ação'), findsOneWidget);
    expect(find.text('Trocar'), findsOneWidget);
  });

  testWidgets('clearSnackbarsOnEnter remove o snackbar ao montar a tela', (
    tester,
  ) async {
    await _pumpApp(tester, width: 1600);
    await tester.tap(find.text('mostrar'));
    await tester.pump();
    expect(find.text('Olá'), findsOneWidget);

    await tester.tap(find.text('abrir leitor'));
    await tester.pumpAndSettle();

    expect(find.text('leitor'), findsOneWidget);
    expect(find.text('Olá'), findsNothing);
  });

  test('tema do app usa snackbar flutuante por padrão', () {
    expect(AppTheme.light.snackBarTheme.behavior, SnackBarBehavior.floating);
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha por compilação**

Run: `flutter test test/widget/core/app_snackbar_test.dart`
Expected: FAIL — `appSnackbarWidth`, `kAppSnackbarMaxWidth`, `clearSnackbarsOnEnter` e o parâmetro `action` não existem.

- [ ] **Step 3: Reescrever `app_snackbar.dart`**

`lib/core/widgets/app_snackbar.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Largura máxima do snackbar flutuante (auditoria P8).
///
/// Em tela larga (1568 px medidos em produção) o snackbar de 100 % da
/// largura punha texto e ação nos cantos opostos da tela.
const double kAppSnackbarMaxWidth = 480;

/// Margem lateral mínima em telas estreitas — igual ao `margin` padrão do
/// `SnackBarBehavior.floating` (16 px de cada lado).
const double _kAppSnackbarSideMargin = 16;

/// Largura do snackbar para uma tela de [screenWidth]: no máximo
/// [kAppSnackbarMaxWidth], e nunca maior que a tela menos as margens.
double appSnackbarWidth(double screenWidth) =>
    math.min(kAppSnackbarMaxWidth, screenWidth - 2 * _kAppSnackbarSideMargin);

/// Exibe toast via [SnackBar] (substitui AppSnackbarHost do SvelteKit).
///
/// Flutuante, com largura limitada por [appSnackbarWidth]. [action] aparece
/// à direita do texto; [clearPrevious] descarta o snackbar em exibição em vez
/// de enfileirar (o padrão do [ScaffoldMessenger] é a fila).
void showAppSnackbar(
  BuildContext context,
  String message, {
  SnackBarAction? action,
  bool clearPrevious = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  if (clearPrevious) messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      action: action,
      behavior: SnackBarBehavior.floating,
      width: appSnackbarWidth(MediaQuery.sizeOf(context).width),
    ),
  );
}

/// Limpa os snackbars pendentes assim que a tela terminar de montar.
///
/// Para os leitores (`/leitor`, `/cifra`, `/gestos`): o «Adicionado à lista»
/// da Home sobrevivia ao push e cobria o rodapé da partitura (auditoria P8).
/// Chamar no `initState` — o [ScaffoldMessenger] só pode ser lido depois do
/// primeiro frame, por isso o pós-frame.
void clearSnackbarsOnEnter(BuildContext context) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
  });
}
```

- [ ] **Step 4: Tema e chamadores**

Em `lib/core/theme/app_theme.dart`, dentro de `ThemeData(`, após o bloco `pageTransitionsTheme` da Task 4:

```dart
      // Flutuante também para os `SnackBar` montados direto (fora de
      // `showAppSnackbar`) — mesma família visual (auditoria P8).
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
```

Em `lib/features/catalog/presentation/widgets/louvor_group_card.dart`, trocar o bloco

```dart
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: key == null
              ? null
              : SnackBarAction(
                  label: l10n.cardSwapMaterialAction,
                  onPressed: () => unawaited(_openSwapMaterialSheet(key)),
                ),
        ),
      );
```
por
```dart
    showAppSnackbar(
      context,
      message,
      clearPrevious: true,
      action: key == null
          ? null
          : SnackBarAction(
              label: l10n.cardSwapMaterialAction,
              onPressed: () => unawaited(_openSwapMaterialSheet(key)),
            ),
    );
```

Nos três leitores, adicionar a chamada no `initState`, logo após `super.initState();`:

- `lib/features/pdf_reader/presentation/pages/pdf_reader_screen.dart` — já importa `package:coldigui/core/widgets/app_snackbar.dart`:
  ```dart
    @override
    void initState() {
      super.initState();
      clearSnackbarsOnEnter(context);
      _schedulePublishRouteParams();
    }
  ```
- `lib/features/chords/presentation/pages/chord_reader_screen.dart` e `lib/features/gestures/presentation/pages/gesture_reader_screen.dart` — mesma inserção de `clearSnackbarsOnEnter(context);`; adicionar o import `package:coldigui/core/widgets/app_snackbar.dart` (ou relativo, seguindo o estilo do arquivo) se ainda não existir.

- [ ] **Step 5: Rodar os testes**

Run: `flutter analyze lib test && flutter test test/widget/core/app_snackbar_test.dart test/widget/features/catalog test/widget/features/pdf_reader test/widget/features/chords test/widget/features/gestures`
Expected: tudo passando. Se algum teste existente de card procurar `SnackBar` por `find.byType` e falhar por conta do `width` em janela de teste estreita (800 px padrão → width 480, cabe), investigar antes de alterar o teste.

- [ ] **Step 6: Commit**

```bash
git add lib/core/widgets/app_snackbar.dart lib/core/theme/app_theme.dart lib/features/catalog/presentation/widgets/louvor_group_card.dart lib/features/pdf_reader/presentation/pages/pdf_reader_screen.dart lib/features/chords/presentation/pages/chord_reader_screen.dart lib/features/gestures/presentation/pages/gesture_reader_screen.dart test/widget/core/app_snackbar_test.dart
git commit -m "feat(ui): snackbars flutuantes com largura máxima e limpos ao entrar nos leitores (P8)" -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01DVQ2ezio1U1Na551mqQVRc"
```

---

### Task 6: Registrar a execução na auditoria

**Files:**
- Modify: `docs/AUDITORIA_POLIMENTO_2026-09-12.md`

**Interfaces:** nenhuma.

- [ ] **Step 1: Coletar os commits**

Run: `git log --oneline web/integration..HEAD`
Anotar o hash curto de cada commit das Tasks 1–5.

- [ ] **Step 2: Anotar os itens**

Em `docs/AUDITORIA_POLIMENTO_2026-09-12.md`, na tabela da seção **1. Top 8**, acrescentar uma coluna `Status` e preencher:

- P1 — `⏳ decisão pendente (medir em tablet; login redirect/FedCM × single-thread)`
- P2 — `✅ <hash> — optionURLReflectsImperativeAPIs (go nos openers fica para depois de feat/barra-lista-ativa)`
- P3 — `✅ <hash>`
- P4 — `✅ <hash>`
- P5 — `🟡 em execução no plano 2026-09-12-nav-listas-perfil.md`
- P6 — `✅ <hash> (mesma correção de P3)`
- P7 — `✅ <hash>`
- P8 — `✅ <hash>`

Ao final do arquivo, adicionar:

```markdown
## I. Execução — 2026-09-12 (`feat/polimento-leitor-nav`)

Plano: `docs/superpowers/plans/2026-09-12-polimento-leitor-nav.md`. Fechados P2, P3, P4, P6, P7, P8 (commits acima). Decisões:

- **P2 pela opção global do go_router**, não por `go` nos openers: os arquivos do carousel/áudio estão em edição em `feat/barra-lista-ativa`. Revisitar quando aquela branch entrar — `go` também resolveria o crescimento da pilha `/leitor` ↔ `/audio` (item B, «Bônus»).
- **Fit só na abertura e no fullscreen.** Se o usuário fizer pinch-zoom e virar a página, o zoom agora é preservado (antes era resetado pelo fit) — comportamento novo, alinhado ao que um leitor de partitura espera.
- **Fora do plano:** P1 (decisão + medição em dispositivo), P5 (outro plano), `readerCarouselPositionProvider` autoDispose (arquivo do plano `barra-lista-ativa`), `PdfViewer` fora dos `ValueListenableBuilder` (sem ganho medido), recentes deduplicados e chip sintética com catálogo (UX, decidir com produto).
```

- [ ] **Step 3: Commit**

```bash
git add docs/AUDITORIA_POLIMENTO_2026-09-12.md
git commit -m "docs(auditoria): registrar execução de P2, P3, P4, P6, P7 e P8" -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01DVQ2ezio1U1Na551mqQVRc"
```

---

## Verificação final (controlador, após a Task 6)

- `flutter analyze` → 0 issues.
- `flutter test` → 0 falhas (suíte inteira; a baseline era 2309 passando / 7 skipped).
- `grep -rn "PdfReaderViewportPolicy\|refreshViewportAfterNavigation" lib test` → vazio.
- `git diff --stat web/integration..HEAD -- <arquivos proibidos>` → vazio.

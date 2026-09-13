# Navegação Listas · Pesquisar · Perfil — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Barra inferior com **Listas · Pesquisar · Perfil**; a antiga aba Social vira a sub-rota **Listas públicas** dentro de Listas; Biblioteca sai da barra e entra no hub Perfil (Biblioteca · Offline · Sobre).

**Architecture:** `AppTab` passa a `{events, playlists, home, profile}` e `appTabsFor` continua sendo a única fonte dos índices de branch/aba (router e shell derivam dela). A branch Listas ganha a sub-rota `/listas/publicas` (registrada só com `FF_SOCIAL`), a branch Perfil absorve `/biblioteca`. `SocialScreen` é renomeada para `PublicPlaylistsScreen`; um botão `PublicPlaylistsEntryButton` em `PlaylistsScreen` faz `push` para ela, e a `PlpcgPrimaryAppBar` mostra a seta de voltar nessa rota.

**Tech Stack:** Flutter 3.44 / Dart 3, Riverpod, go_router (`StatefulShellRoute.indexedStack`), `flutter gen-l10n` (ARB → `lib/l10n/app_localizations*.dart`, versionados), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-12-nav-listas-perfil-design.md`

## Global Constraints

- Ordem da barra (esq → dir): `[Eventos se FF_EVENTS] Listas · Pesquisar · Perfil`. Ícone de Listas: `Icons.playlist_play`; rótulo `Listas` (spec D1).
- Índices de branch/aba **nunca** fixos: sempre a posição em `appTabsFor(flags)` (regra já existente em `app_tabs.dart`).
- `/listas/publicas` só existe com `FeatureFlags.social == true`; a flag mantém o nome `social` (spec D2).
- URL `/biblioteca` (e query params) **não muda** — só a branch dona (spec D3).
- Tiles do Perfil, de cima para baixo: Biblioteca · Offline · Sobre (spec D3).
- Textos (spec D4): aba `Listas`; título do browser em `/listas/publicas` = `Listas públicas`; l10n `publicPlaylistsTitle` pt `Listas públicas` / en `Public playlists`; `socialSignInRequired` pt `Entre com o Google para explorar as listas públicas.` / en `Sign in with Google to explore public playlists.`
- l10n `pt` **e** `en` para toda string nova; regenerar com `flutter gen-l10n` e commitar os `.dart` gerados.
- Comentários e docs em português, no estilo dos arquivos vizinhos (`///` explicando o *porquê*). Onde um `///` tocado ainda diz «aba Social» ou «aba Biblioteca», atualizar.
- Antes de cada commit: `flutter analyze lib test` sem erros nos arquivos tocados e os testes do task passando. Commits com prefixo `feat|refactor|test|docs(escopo):` em português.
- Comandos: `flutter test <caminho>` (um arquivo), `flutter analyze lib test`, `flutter gen-l10n`.
- Todo commit termina com:
  ```
  Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01NpgwPYi3yU5tGhJGayxsw4
  ```
- Atenção: há outro worktree (`feat/barra-lista-ativa`) mexendo em `PlaylistsScreen` (remove o `PlaylistMediaFaceToggle`). Não tocar na linha do toggle; o botão novo entra numa linha própria logo após `const PlaylistSyncErrorBanner(),`.

---

## Mapa de arquivos

**Renomear**
- `lib/features/social/presentation/pages/social_screen.dart` → `lib/features/social/presentation/pages/public_playlists_screen.dart` (classe `SocialScreen` → `PublicPlaylistsScreen`).

**Criar**
- `lib/features/social/presentation/widgets/public_playlists_entry_button.dart` — botão «Listas públicas» usado em `PlaylistsScreen`.
- `test/unit/features/social/public_playlists_l10n_test.dart`
- `test/widget/core/widgets/plpcg_primary_app_bar_test.dart`
- `test/widget/features/app_shell/profile_screen_tiles_test.dart`

**Modificar**
- `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb` (+ gerados `lib/l10n/app_localizations*.dart`)
- `lib/core/constants/app_tabs.dart`
- `lib/core/constants/feature_flags.dart` (só doc)
- `lib/core/routing/route_paths.dart`
- `lib/core/routing/app_router.dart`
- `lib/features/app_shell/presentation/shell_scaffold.dart`
- `lib/features/app_shell/presentation/widgets/nav_item.dart` (switch de ícones)
- `lib/features/app_shell/presentation/pages/profile_screen.dart`
- `lib/features/playlists/presentation/pages/playlists_screen.dart`
- `lib/core/widgets/plpcg_primary_app_bar.dart`
- `test/unit/core/app_tabs_test.dart`, `test/unit/core/app_router_test.dart`
- `test/widget/features/app_shell/shell_scaffold_test.dart`
- `test/widget/features/playlists/playlists_screen_test.dart`

---

### Task 1: Renomear `SocialScreen` → `PublicPlaylistsScreen` e textos l10n

**Files:**
- Rename: `lib/features/social/presentation/pages/social_screen.dart` → `lib/features/social/presentation/pages/public_playlists_screen.dart`
- Modify: `lib/core/routing/app_router.dart` (import + uso da classe, só o necessário para compilar — a rota muda no Task 2)
- Modify: `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb`
- Generated: `lib/l10n/app_localizations.dart`, `lib/l10n/app_localizations_pt.dart`, `lib/l10n/app_localizations_en.dart`
- Test: `test/unit/features/social/public_playlists_l10n_test.dart`

**Interfaces:**
- Produces: `class PublicPlaylistsScreen extends ConsumerWidget` (construtor `const PublicPlaylistsScreen({super.key})`), em `package:coldigui/features/social/presentation/pages/public_playlists_screen.dart`; `AppLocalizations.publicPlaylistsTitle` (`String`).

- [ ] **Step 1: Escrever o teste de l10n (falha porque a chave não existe)**

Criar `test/unit/features/social/public_playlists_l10n_test.dart`:

```dart
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec D4 — os textos da antiga aba Social passam a falar em «listas
/// públicas», em pt e en.
void main() {
  late AppLocalizations pt;
  late AppLocalizations en;

  setUpAll(() async {
    pt = await AppLocalizations.delegate.load(const Locale('pt'));
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('publicPlaylistsTitle', () {
    expect(pt.publicPlaylistsTitle, 'Listas públicas');
    expect(en.publicPlaylistsTitle, 'Public playlists');
  });

  test('socialSignInRequired não cita mais a «aba Social»', () {
    expect(
      pt.socialSignInRequired,
      'Entre com o Google para explorar as listas públicas.',
    );
    expect(
      en.socialSignInRequired,
      'Sign in with Google to explore public playlists.',
    );
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/social/public_playlists_l10n_test.dart`
Expected: falha de compilação — `publicPlaylistsTitle` não definido.

- [ ] **Step 3: Editar os ARBs**

Em `lib/l10n/app_pt.arb`, trocar a linha de `socialSignInRequired` e adicionar a chave nova logo acima dela:

```json
  "publicPlaylistsTitle": "Listas públicas",
  "socialSignInRequired": "Entre com o Google para explorar as listas públicas.",
```

Em `lib/l10n/app_en.arb`, idem:

```json
  "publicPlaylistsTitle": "Public playlists",
  "socialSignInRequired": "Sign in with Google to explore public playlists.",
```

- [ ] **Step 4: Regenerar l10n**

Run: `flutter gen-l10n`
Expected: `lib/l10n/app_localizations*.dart` atualizados com `publicPlaylistsTitle`.

- [ ] **Step 5: Renomear a tela**

```bash
git mv lib/features/social/presentation/pages/social_screen.dart lib/features/social/presentation/pages/public_playlists_screen.dart
```

No arquivo renomeado: `class SocialScreen` → `class PublicPlaylistsScreen`, `const SocialScreen({super.key})` → `const PublicPlaylistsScreen({super.key})`, e o doc da classe passa a:

```dart
/// Listas públicas (antiga aba Social) — busca de pessoas por @usuário e
/// importação das listas públicas delas. Sub-rota de Listas
/// (`/listas/publicas`), aberta pelo `PublicPlaylistsEntryButton`.
```

Em `lib/core/routing/app_router.dart`: trocar o import de `social_screen.dart` por `public_playlists_screen.dart` e `const SocialScreen()` por `const PublicPlaylistsScreen()` (a rota continua `/social` por enquanto — o Task 2 a move).

- [ ] **Step 6: Rodar o teste e o analyze**

Run: `flutter test test/unit/features/social/public_playlists_l10n_test.dart && flutter analyze lib test`
Expected: 2 testes PASS; analyze sem erros.

- [ ] **Step 7: Commit**

```bash
git add lib/features/social/presentation/pages lib/core/routing/app_router.dart lib/l10n test/unit/features/social/public_playlists_l10n_test.dart
git commit -m "refactor(social): SocialScreen vira PublicPlaylistsScreen; textos «listas públicas»"
```

---

### Task 2: Abas, rotas e shell — Listas · Pesquisar · Perfil

**Files:**
- Modify: `lib/core/constants/app_tabs.dart`
- Modify: `lib/core/constants/feature_flags.dart` (doc de `social`)
- Modify: `lib/core/routing/route_paths.dart`
- Modify: `lib/core/routing/app_router.dart`
- Modify: `lib/features/app_shell/presentation/shell_scaffold.dart`
- Modify: `lib/features/app_shell/presentation/widgets/nav_item.dart`
- Test: `test/unit/core/app_tabs_test.dart`, `test/unit/core/app_router_test.dart`, `test/widget/features/app_shell/shell_scaffold_test.dart`

**Interfaces:**
- Consumes: `PublicPlaylistsScreen` (Task 1).
- Produces: `enum AppTab { events, playlists, home, profile }`; `RoutePaths.publicPlaylists = '/listas/publicas'`; `RoutePaths.social` mantido só para redirect.

- [ ] **Step 1: Reescrever `test/unit/core/app_tabs_test.dart`**

```dart
import 'package:coldigui/core/constants/app_tabs.dart';
import 'package:coldigui/core/constants/feature_flags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('appTabsFor', () {
    test('com as flags padrão: Listas, Pesquisar, Perfil', () {
      expect(appTabsFor(const FeatureFlags()), [
        AppTab.playlists,
        AppTab.home,
        AppTab.profile,
      ]);
    });

    test('events: true inclui a aba Eventos como primeira', () {
      expect(appTabsFor(const FeatureFlags(events: true)), [
        AppTab.events,
        AppTab.playlists,
        AppTab.home,
        AppTab.profile,
      ]);
    });

    test('social não é mais aba — a flag não muda a lista', () {
      expect(
        appTabsFor(const FeatureFlags(social: false)),
        appTabsFor(const FeatureFlags(social: true)),
      );
    });
  });
}
```

- [ ] **Step 2: Reescrever os testes de rota em `test/unit/core/app_router_test.dart`**

Manter o cabeçalho, `buildRouter` e os testes de `/eventos` (os dois primeiros), da Home e do número de branches e do redirect de `/eventos`. **Substituir** os dois testes de `/social` por estes quatro:

```dart
    test('com social: false, /listas/publicas não é registrada', () {
      final router = buildRouter(const FeatureFlags(social: false));

      final match = router.configuration.findMatch(
        Uri.parse(RoutePaths.publicPlaylists),
      );

      expect(match.isError, isTrue);
    });

    test('com as flags padrão, /listas/publicas é registrada', () {
      final router = buildRouter(const FeatureFlags());

      final match = router.configuration.findMatch(
        Uri.parse(RoutePaths.publicPlaylists),
      );

      expect(match.isError, isFalse);
    });

    test('/listas e /biblioteca continuam registradas com qualquer flag', () {
      final router = buildRouter(
        const FeatureFlags(events: true, social: false),
      );

      expect(
        router.configuration.findMatch(Uri.parse(RoutePaths.playlists)).isError,
        isFalse,
      );
      expect(
        router.configuration.findMatch(Uri.parse(RoutePaths.library)).isError,
        isFalse,
      );
    });

    testWidgets('/social (aba antiga) redireciona para /listas/publicas', (
      tester,
    ) async {
      final router = buildRouter(const FeatureFlags());
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (innerContext) {
              context = innerContext;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final legacyMatch = router.configuration.findMatch(
        Uri.parse(RoutePaths.social),
      );
      expect(legacyMatch.isError, isTrue);

      final redirected = await Future.value(
        router.configuration.redirect(
          context,
          legacyMatch,
          redirectHistory: [],
        ),
      );

      expect(redirected.isError, isFalse);
      expect(redirected.uri.path, RoutePaths.publicPlaylists);
    });
```

- [ ] **Step 3: Atualizar `test/widget/features/app_shell/shell_scaffold_test.dart`**

Em `buildRouter`, substituir as quatro branches por três, nesta ordem (Listas, Home, Perfil):

```dart
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutePaths.playlists,
                  builder: (_, _) => const Scaffold(body: Text('Listas')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutePaths.home,
                  builder: (_, _) => const Scaffold(body: Text('Home')),
                  routes: [
                    GoRoute(
                      path: 'leitor',
                      builder: (_, _) => const Scaffold(body: Text('Leitor')),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutePaths.profile,
                  builder: (_, _) => const Scaffold(body: Text('Perfil')),
                ),
              ],
            ),
          ],
```

Atualizar o comentário acima de `buildRouter` para:

```dart
  // Branches na mesma ordem de `appTabsFor` com as flags padrão em teste
  // (FF_EVENTS=false): playlists, home, profile — para exercitar
  // `goBranch`/`selectedIndex` com o mesmo índice que
  // `PlpcgBottomNavBar`/`PlpcgNavigationRail` recebem no shell real.
```

No teste «selecionar a última destination do rail…», trocar o bloco final por:

```dart
      // Flags padrão de teste → tabs [playlists, home, profile];
      // última destination = Perfil (índice 2).
      final rail = tester.widget<PlpcgNavigationRail>(
        find.byType(PlpcgNavigationRail),
      );
      expect(rail.destinations.length, 3);
      expect(rail.selectedIndex, 1);

      rail.onDestinationSelected(2);
      await tester.pumpAndSettle();

      final updatedRail = tester.widget<PlpcgNavigationRail>(
        find.byType(PlpcgNavigationRail),
      );
      expect(
        updatedRail.selectedIndex,
        2,
        reason:
            'goBranch(2) — a última posição de appTabsFor — tem que mover '
            'o navigationShell para a branch Perfil',
      );
```

- [ ] **Step 4: Rodar os três arquivos e ver falhar**

Run: `flutter test test/unit/core/app_tabs_test.dart test/unit/core/app_router_test.dart test/widget/features/app_shell/shell_scaffold_test.dart`
Expected: falha de compilação (`AppTab.playlists`, `RoutePaths.publicPlaylists` não existem).

- [ ] **Step 5: `app_tabs.dart`**

Substituir o arquivo inteiro:

```dart
import 'feature_flags.dart';

/// Abas do shell principal (UC-14), ordem fixa de exibição.
///
/// [events] só aparece quando [FeatureFlags.events] está ligada — ver
/// [appTabsFor]. [playlists], [home] e [profile] são sempre exibidas.
///
/// Biblioteca vive na branch Perfil e Listas públicas (a antiga aba Social)
/// é sub-rota de Listas — nenhuma das duas é aba.
enum AppTab { events, playlists, home, profile }

/// Abas visíveis para [flags], na ordem fixa de [AppTab].
///
/// Router (`appRouterProvider`) e shell (`ShellScaffold`) montam suas
/// `StatefulShellBranch`/destinations a partir desta mesma lista — os
/// índices de branch/aba são sempre a posição do item nesta lista, nunca um
/// valor fixo.
List<AppTab> appTabsFor(FeatureFlags flags) => [
  if (flags.events) AppTab.events,
  AppTab.playlists,
  AppTab.home,
  AppTab.profile,
];
```

- [ ] **Step 6: `feature_flags.dart` — só o doc de `social`**

Trocar a linha `/// [social]: aba Social. \`FF_SOCIAL\`, padrão \`true\`.` por:

```dart
/// [social]: Listas públicas (`/listas/publicas`, antiga aba Social) e o
/// botão que abre essa tela em Listas. `FF_SOCIAL`, padrão `true`.
```

- [ ] **Step 7: `route_paths.dart`**

Substituir os docs/constantes de `events` em diante por:

```dart
  /// Eventos — placeholder, primeira aba quando `FF_EVENTS` está ligada.
  static const String events = '/eventos';

  /// Rota antiga da aba Social — só existe para o `redirect` do router
  /// mandar links antigos para [publicPlaylists]. Nenhuma rota é registrada.
  static const String social = '/social';

  /// Perfil — hub Biblioteca/Offline/Sobre (última aba).
  static const String profile = '/perfil';

  /// Offline UC-09/10 ([OfflineSettingsScreen]) — branch Perfil.
  static const String offline = '/offline';

  /// Playlists UC-06/07 ([PlaylistsScreen]) — raiz da aba Listas.
  static const String playlists = '/listas';

  /// Listas públicas ([PublicPlaylistsScreen]) — sub-rota de [playlists],
  /// registrada só com `FF_SOCIAL`.
  static const String publicPlaylists = '/listas/publicas';

  /// Sobre UC-14 ([AboutScreen]) — branch Perfil.
  static const String about = '/sobre';
```

E o doc de `library` passa a: `/// Biblioteca paginada UC-03 ([LibraryScreen]) — branch Perfil.`

- [ ] **Step 8: `app_router.dart`**

Doc da classe: trocar a linha `/// Branch Perfil também hospeda \`/sobre\`, \`/offline\` e \`/listas\`.` por:

```dart
/// Branch Listas: `/listas` + sub-rota `/listas/publicas` (só com
/// `FF_SOCIAL`). Branch Perfil: `/perfil`, `/biblioteca`, `/offline`, `/sobre`.
/// `/social` (aba antiga) redireciona para `/listas/publicas`.
```

No provider:

```dart
final appRouterProvider = Provider<GoRouter>((ref) {
  final flags = ref.read(featureFlagsProvider);
  final tabs = appTabsFor(flags);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RoutePaths.home,
    // `/social` era aba própria; hoje é sub-rota de Listas — links antigos
    // seguem funcionando. Qualquer outra rota desconhecida/escondida
    // (`/eventos` com a flag off não registra a rota — comentário acima)
    // não pode parar na página de erro padrão do GoRouter: manda pra Home.
    redirect: (context, state) {
      if (state.uri.path == RoutePaths.social) {
        return RoutePaths.publicPlaylists;
      }
      return state.error != null ? RoutePaths.home : null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellScaffold(navigationShell: navigationShell),
        branches: [for (final tab in tabs) _branchFor(tab, flags)],
      ),
    ],
  );
});
```

`_branchFor` passa a receber as flags: `StatefulShellBranch _branchFor(AppTab tab, FeatureFlags flags)` (importar `../../core/constants/feature_flags.dart`). Remover os cases `AppTab.library` e `AppTab.social`; adicionar o case `AppTab.playlists` e mover a `GoRoute` de `/biblioteca` (inalterada) para a branch Perfil, removendo de lá a `GoRoute` de `/listas`:

```dart
    AppTab.playlists => StatefulShellBranch(
      routes: [
        GoRoute(
          path: RoutePaths.playlists,
          builder: (context, state) =>
              const StorageRequiredGate(child: PlaylistsScreen()),
          routes: [
            if (flags.social)
              GoRoute(
                path: 'publicas',
                builder: (context, state) => const PublicPlaylistsScreen(),
              ),
          ],
        ),
      ],
    ),
```

```dart
    AppTab.profile => StatefulShellBranch(
      routes: [
        GoRoute(
          path: RoutePaths.profile,
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: RoutePaths.library,
          builder: (context, state) {
            final params = safeQueryParameters(state.uri);
            return LibraryScreen(
              initialFonte: params[UrlSyncParams.fonte],
              initialMateriais: params[UrlSyncParams.materiais],
              initialArranjo: params[UrlSyncParams.arranjo],
              initialArranjoEspecial: params[UrlSyncParams.arranjoEspecial],
              initialTonality: params[UrlSyncParams.tonality],
              initialRhythm: params[UrlSyncParams.rhythm],
              initialCategory: params[UrlSyncParams.category],
              initialTags: params[UrlSyncParams.tags],
              initialMaterialKinds: params[UrlSyncParams.materialKinds],
              initialOrdenar: params[UrlSyncParams.ordenar],
              initialItensPorPagina: params[UrlSyncParams.itensPorPagina],
              initialPagina: params[UrlSyncParams.pagina],
            );
          },
        ),
        GoRoute(
          path: RoutePaths.about,
          builder: (context, state) => const AboutScreen(),
        ),
        GoRoute(
          path: RoutePaths.offline,
          builder: (context, state) =>
              const StorageRequiredGate(child: OfflineSettingsScreen()),
        ),
      ],
    ),
```

- [ ] **Step 9: `shell_scaffold.dart`**

No doc da classe, trocar o parágrafo «Navegação: Eventos (se …), Biblioteca, Pesquisar, Social (se …), Perfil — …» por:

```dart
/// Navegação: Eventos (se [FeatureFlags.events]), Listas, Pesquisar, Perfil
/// — mesma lista de [appTabsFor] usada pelo router, então os índices de
/// [StatefulNavigationShell] sempre batem com a posição na lista. Em largura
/// ≥ [kRailBreakpoint] (C6), usa [PlpcgNavigationRail] à esquerda do corpo em
/// vez de [PlpcgBottomNavBar]. Ambas ocultas em `/leitor`, `/audio` e
/// `/cifra`. Destino central: **Pesquisar** (logo PLPCG, [RoutePaths.home]).
/// Aba Perfil: avatar + nome quando autenticado.
```

Em `_destinations`, substituir os cases `AppTab.library` e `AppTab.social` por um único:

```dart
          AppTab.playlists => const PlpcgBottomNavDestination(
            icon: Icons.playlist_play,
            label: 'Listas',
          ),
```

Em `_tabLabel`: manter `RoutePaths.library => 'Biblioteca'` (a rota continua existindo, na branch Perfil); remover `RoutePaths.social => 'Social'`; adicionar `RoutePaths.publicPlaylists => 'Listas públicas',` logo após `RoutePaths.playlists => 'Listas',`.

- [ ] **Step 10: `nav_item.dart` — switch de ícones**

No `switch (destination.icon)` de `_NavIcon`, remover os cases `Icons.library_books` e `Icons.groups` (nenhum destino da barra usa mais esses ícones; `Icons.playlist_play` já está lá).

- [ ] **Step 11: Rodar testes + analyze**

Run: `flutter test test/unit/core/app_tabs_test.dart test/unit/core/app_router_test.dart test/widget/features/app_shell && flutter analyze lib test`
Expected: tudo PASS; analyze sem erros.

- [ ] **Step 12: Commit**

```bash
git add lib/core/constants lib/core/routing lib/features/app_shell/presentation/shell_scaffold.dart lib/features/app_shell/presentation/widgets/nav_item.dart test/unit/core test/widget/features/app_shell/shell_scaffold_test.dart
git commit -m "feat(app_shell): barra Listas · Pesquisar · Perfil; /listas/publicas e /biblioteca em Perfil"
```

---

### Task 3: Botão «Listas públicas» em Listas e seta de voltar na app bar

**Files:**
- Create: `lib/features/social/presentation/widgets/public_playlists_entry_button.dart`
- Modify: `lib/features/playlists/presentation/pages/playlists_screen.dart`
- Modify: `lib/core/widgets/plpcg_primary_app_bar.dart`
- Test: `test/widget/features/playlists/playlists_screen_test.dart`, `test/widget/core/widgets/plpcg_primary_app_bar_test.dart`

**Interfaces:**
- Consumes: `RoutePaths.publicPlaylists`, `RoutePaths.playlists` (Task 2); `AppLocalizations.publicPlaylistsTitle` (Task 1); `featureFlagsProvider` (`lib/core/providers/feature_flags_provider.dart`).
- Produces: `class PublicPlaylistsEntryButton extends StatelessWidget` (`const PublicPlaylistsEntryButton({super.key})`).

- [ ] **Step 1: Testes do botão em `playlists_screen_test.dart`**

Adicionar imports:

```dart
import 'package:coldigui/core/constants/feature_flags.dart';
import 'package:coldigui/core/providers/feature_flags_provider.dart';
```

Trocar a assinatura de `buildSubject` por `Widget buildSubject(List<PlaylistViewItem> items, {FeatureFlags flags = const FeatureFlags()})` e adicionar `featureFlagsProvider.overrideWithValue(flags),` à lista de overrides. Adicionar dois testes após «exibe estado vazio»:

```dart
  testWidgets('com FF_SOCIAL, mostra o botão «Listas públicas»', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(const []));
    await tester.pumpAndSettle();

    expect(find.text('Listas públicas'), findsOneWidget);
    expect(find.byIcon(Icons.public), findsOneWidget);
  });

  testWidgets('sem FF_SOCIAL, o botão «Listas públicas» não aparece', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(const [], flags: const FeatureFlags(social: false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Listas públicas'), findsNothing);
  });
```

- [ ] **Step 2: Teste da app bar — criar `test/widget/core/widgets/plpcg_primary_app_bar_test.dart`**

```dart
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/widgets/plpcg_primary_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Spec D2 — em `/listas/publicas` a barra mostra a seta de voltar (mesmo
/// padrão das rotas imersivas); em `/listas` não.
void main() {
  GoRouter buildRouter(String initialLocation) {
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: RoutePaths.playlists,
          builder: (_, _) => const Scaffold(
            appBar: PlpcgPrimaryAppBar(),
            body: Text('Listas'),
          ),
          routes: [
            GoRoute(
              path: 'publicas',
              builder: (_, _) => const Scaffold(
                appBar: PlpcgPrimaryAppBar(),
                body: Text('Públicas'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> pump(WidgetTester tester, String location) async {
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: buildRouter(location)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('em /listas não há seta de voltar', (tester) async {
    await pump(tester, RoutePaths.playlists);

    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets(
    'em /listas/publicas (deep link, sem pilha) a seta volta para /listas',
    (tester) async {
      await pump(tester, RoutePaths.publicPlaylists);
      expect(find.text('Públicas'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Listas'), findsOneWidget);
      expect(find.text('Públicas'), findsNothing);
    },
  );
}
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `flutter test test/widget/features/playlists/playlists_screen_test.dart test/widget/core/widgets/plpcg_primary_app_bar_test.dart`
Expected: os testes novos falham (botão não existe; sem seta em `/listas/publicas`).

- [ ] **Step 4: Criar `public_playlists_entry_button.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../l10n/app_localizations.dart';

/// Entrada para as listas públicas (antiga aba Social) dentro de Listas —
/// linha própria, alinhada à direita, logo abaixo do banner de sync.
///
/// `push` (não `go`): a tela abre em cima de `/listas`, e a seta da
/// `PlpcgPrimaryAppBar` volta para a lista com `pop`.
class PublicPlaylistsEntryButton extends StatelessWidget {
  const PublicPlaylistsEntryButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(
          onPressed: () => context.push(RoutePaths.publicPlaylists),
          icon: const Icon(Icons.public, size: 18),
          label: Text(l10n.publicPlaylistsTitle),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textLight,
            side: BorderSide(color: AppColors.gold.withValues(alpha: 0.6)),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Inserir o botão em `playlists_screen.dart`**

Imports novos:

```dart
import '../../../../core/providers/feature_flags_provider.dart';
import '../../../social/presentation/widgets/public_playlists_entry_button.dart';
```

No `Column` do `body`, logo após `const PlaylistSyncErrorBanner(),` (e **antes** do `Padding` do `PlaylistMediaFaceToggle`, sem tocar nele):

```dart
          if (ref.watch(featureFlagsProvider).social)
            const PublicPlaylistsEntryButton(),
```

No doc da classe, acrescentar ao fim do parágrafo **Layout**: `Com \`FF_SOCIAL\`, o [PublicPlaylistsEntryButton] («Listas públicas») fica logo abaixo do banner de sync.`

- [ ] **Step 6: Seta de voltar em `plpcg_primary_app_bar.dart`**

Substituir o cálculo de `isImmersiveMedia` e o `leading` por:

```dart
    final path = GoRouterState.of(context).uri.path;
    // Rotas empilhadas sobre uma aba: seta volta com `pop`; sem pilha (deep
    // link direto), cai na raiz da aba dona.
    final backFallback = switch (path) {
      RoutePaths.reader ||
      RoutePaths.audio ||
      RoutePaths.chords ||
      RoutePaths.gestos => RoutePaths.home,
      RoutePaths.publicPlaylists => RoutePaths.playlists,
      _ => null,
    };

    return AppBar(
      automaticallyImplyLeading: false,
      leading: backFallback == null
          ? null
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Voltar',
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  goToShellDestination(context, backFallback);
                }
              },
            ),
```

Atualizar o doc da classe: `/// Em \`/leitor\`, \`/audio\`, \`/cifra\`, \`/gestos\` e \`/listas/publicas\`, exibe voltar` `/// (pop → raiz da aba dona) para padronizar.`

- [ ] **Step 7: Rodar testes + analyze**

Run: `flutter test test/widget/features/playlists/playlists_screen_test.dart test/widget/core/widgets/plpcg_primary_app_bar_test.dart test/widget/features/app_shell/app_shortcuts_test.dart && flutter analyze lib test`
Expected: tudo PASS; analyze sem erros.

- [ ] **Step 8: Commit**

```bash
git add lib/features/social/presentation/widgets/public_playlists_entry_button.dart lib/features/playlists/presentation/pages/playlists_screen.dart lib/core/widgets/plpcg_primary_app_bar.dart test/widget/features/playlists/playlists_screen_test.dart test/widget/core/widgets/plpcg_primary_app_bar_test.dart
git commit -m "feat(playlists): botão «Listas públicas» em Listas e seta de voltar em /listas/publicas"
```

---

### Task 4: Hub Perfil — Biblioteca · Offline · Sobre

**Files:**
- Modify: `lib/features/app_shell/presentation/pages/profile_screen.dart`
- Test: `test/widget/features/app_shell/profile_screen_tiles_test.dart`

**Interfaces:**
- Consumes: `RoutePaths.library`, `RoutePaths.offline`, `RoutePaths.about`.

- [ ] **Step 1: Criar `test/widget/features/app_shell/profile_screen_tiles_test.dart`**

```dart
import 'package:coldigui/features/app_shell/presentation/pages/profile_screen.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _LoggedOutAuth extends AuthNotifier {
  @override
  Future<AuthUser?> build() async => null;
}

/// Spec D3 — tiles do hub Perfil, de cima para baixo: Biblioteca, Offline,
/// Sobre. «Listas» virou aba própria e saiu daqui.
void main() {
  testWidgets('tiles na ordem Biblioteca, Offline, Sobre — sem Listas', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authStateProvider.overrideWith(_LoggedOutAuth.new)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: const Scaffold(body: ProfileScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final biblioteca = tester.getTopLeft(find.text('Biblioteca'));
    final offline = tester.getTopLeft(find.text('Offline'));
    final sobre = tester.getTopLeft(find.text('Sobre'));

    expect(biblioteca.dy, lessThan(offline.dy));
    expect(offline.dy, lessThan(sobre.dy));
    expect(find.byIcon(Icons.library_books), findsOneWidget);
    expect(find.text('Listas'), findsNothing);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/widget/features/app_shell/profile_screen_tiles_test.dart`
Expected: FAIL — `Biblioteca` não encontrado / `Listas` encontrado.

- [ ] **Step 3: Trocar os tiles em `profile_screen.dart`**

Doc da classe: `/// Hub do Perfil — login Google, Biblioteca, Offline e Sobre.`

Substituir os três `_ProfilePageTile` (e os `SizedBox` entre eles) por:

```dart
            _ProfilePageTile(
              icon: Icons.library_books,
              title: 'Biblioteca',
              onTap: () => goToShellDestination(context, RoutePaths.library),
            ),
            const SizedBox(height: 10),
            _ProfilePageTile(
              icon: Icons.cloud_download,
              title: 'Offline',
              onTap: () => goToShellDestination(context, RoutePaths.offline),
            ),
            const SizedBox(height: 10),
            _ProfilePageTile(
              icon: Icons.info_outline,
              title: 'Sobre',
              onTap: () => goToShellDestination(context, RoutePaths.about),
            ),
```

- [ ] **Step 4: Rodar testes + analyze**

Run: `flutter test test/widget/features/app_shell/profile_screen_tiles_test.dart test/widget/features/app_shell/profile_screen_errors_test.dart && flutter analyze lib test`
Expected: PASS; analyze sem erros.

- [ ] **Step 5: Commit**

```bash
git add lib/features/app_shell/presentation/pages/profile_screen.dart test/widget/features/app_shell/profile_screen_tiles_test.dart
git commit -m "feat(app_shell): hub Perfil com Biblioteca, Offline e Sobre"
```

---

## Verificação final (após o Task 4)

Run: `flutter analyze lib test && flutter test`
Expected: analyze limpo; suíte inteira verde. Se algum teste fora dos arquivos tocados falhar por citar `AppTab.library`/`AppTab.social`/`/social`, ajustá-lo à nova estrutura (não relaxar a asserção).

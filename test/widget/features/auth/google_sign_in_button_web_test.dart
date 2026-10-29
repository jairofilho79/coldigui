// test/widget/features/auth/google_sign_in_button_web_test.dart
//
// Importa a variante web diretamente: depois da spec D2 ela não usa
// `package:web` nem o plugin, então roda na VM com o navegador fake.
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/auth/data/oidc/oidc_callback.dart';
import 'package:coldigui/features/auth/data/oidc/oidc_redirect_request.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/auth/presentation/widgets/google_logo.dart';
import 'package:coldigui/features/auth/presentation/widgets/google_sign_in_button_web.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/fakes/fake_oidc_browser.dart';

class _LoggedOut extends AuthNotifier {
  @override
  Future<AuthUser?> build() async => null;
}

class _ContextMismatch extends AuthNotifier {
  @override
  Future<AuthUser?> build() async =>
      throw const OidcContextMismatchException('request_missing');
}

class _GenericError extends AuthNotifier {
  @override
  Future<AuthUser?> build() async => throw StateError('boom');
}

void main() {
  late AppLocalizations pt;

  setUpAll(() async {
    pt = await AppLocalizations.delegate.load(const Locale('pt'));
  });

  Future<void> pump(
    WidgetTester tester, {
    required FakeOidcBrowser browser,
    AuthNotifier Function() auth = _LoggedOut.new,
    String clientId = 'cid-test',
    String location = '/perfil',
  }) async {
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/perfil',
          builder: (_, _) => const Scaffold(body: GoogleSignInButton()),
        ),
        GoRoute(
          path: '/listas/publicas',
          builder: (_, _) => const Scaffold(body: GoogleSignInButton()),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authStateProvider.overrideWith(auth),
          googleClientIdProvider.overrideWithValue(clientId),
          oidcBrowserProvider.overrideWithValue(browser),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('deslogado: botão com rótulo l10n e logo', (tester) async {
    await pump(tester, browser: FakeOidcBrowser());
    expect(find.text(pt.authSignInWithGoogle), findsOneWidget);
    expect(find.byType(GoogleLogo), findsOneWidget);
  });

  testWidgets('deslogado: botão dourado com elevação, não texto vinho', (
    tester,
  ) async {
    await pump(tester, browser: FakeOidcBrowser());

    // Sobre o fundo vinho do app, o `OutlinedButton` default do M3 (texto e
    // borda em `primary`, também vinho) lia como texto vermelho solto — o
    // botão de entrar é a ação principal do perfil e precisa parecer botão.
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    final style = button.style!;
    expect(style.backgroundColor!.resolve(const {}), AppColors.gold);
    expect(style.foregroundColor!.resolve(const {}), AppColors.title);
    expect(style.elevation!.resolve(const {}), greaterThan(0));
  });

  testWidgets('tap navega para o Google com a rota atual no state', (
    tester,
  ) async {
    final browser = FakeOidcBrowser();
    await pump(tester, browser: browser, location: '/listas/publicas');

    await tester.tap(find.text(pt.authSignInWithGoogle));
    await tester.pump();

    expect(browser.navigated, hasLength(1));
    final uri = browser.navigated.single;
    expect(uri.host, 'accounts.google.com');
    final request = OidcRedirectRequest.fromJson(browser.storedRequest)!;
    expect(OidcRedirectRequest.decodeState(uri.queryParameters['state']), {
      'csrf': request.csrf,
      'returnTo': '/listas/publicas',
    });
  });

  testWidgets('client id vazio: texto de indisponível, sem botão', (
    tester,
  ) async {
    await pump(tester, browser: FakeOidcBrowser(), clientId: '');
    expect(find.text(pt.authSignInUnavailable), findsOneWidget);
    expect(find.text(pt.authSignInWithGoogle), findsNothing);
  });

  testWidgets('erro genérico: «Tentar novamente»', (tester) async {
    await pump(tester, browser: FakeOidcBrowser(), auth: _GenericError.new);
    expect(find.text(pt.authSignInUnavailable), findsOneWidget);
    expect(find.text(pt.authSignInRetry), findsOneWidget);
  });

  testWidgets('erro de contexto: título, texto e botão que reinicia o login', (
    tester,
  ) async {
    final browser = FakeOidcBrowser();
    await pump(tester, browser: browser, auth: _ContextMismatch.new);

    expect(find.text(pt.authSignInContextMismatchTitle), findsOneWidget);
    expect(find.text(pt.authSignInContextMismatchBody), findsOneWidget);
    expect(find.text(pt.authSignInOpenInBrowserHint), findsNothing);
    expect(find.text(pt.authSignInRetry), findsNothing);

    await tester.tap(find.text(pt.authSignInWithGoogle));
    await tester.pump();
    expect(browser.navigated, hasLength(1));
    expect(browser.storedRequest, isNotNull);
  });

  testWidgets('erro de contexto em standalone: mostra a dica do Safari', (
    tester,
  ) async {
    await pump(
      tester,
      browser: FakeOidcBrowser(standalone: true),
      auth: _ContextMismatch.new,
    );
    expect(find.text(pt.authSignInOpenInBrowserHint), findsOneWidget);
  });
}

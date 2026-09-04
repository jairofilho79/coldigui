import 'package:coldigui/features/app_shell/presentation/pages/profile_screen.dart';
import 'package:coldigui/features/auth/data/auth_remote_datasource.dart';
import 'package:coldigui/features/auth/data/auth_session_store.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

class _FakeAuthRemoteDatasource extends AuthRemoteDatasource {
  _FakeAuthRemoteDatasource(this._behavior) : super(Dio());

  final Future<AuthUser> Function(String idToken) _behavior;

  @override
  Future<AuthUser> establishSession(String idToken) => _behavior(idToken);
}

void main() {
  const user = AuthUser(
    googleSub: 'sub-1',
    idToken: 'token-1',
    name: 'Jairo',
    email: 'a@b.com',
  );

  Future<Stream<GoogleSignInAuthenticationEvent>> noopInitializer() async =>
      const Stream<GoogleSignInAuthenticationEvent>.empty();

  late AppLocalizations pt;

  setUpAll(() async {
    pt = await AppLocalizations.delegate.load(const Locale('pt'));
  });

  Future<void> pumpProfile(
    WidgetTester tester, {
    required List<Override> overrides,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: const Scaffold(body: ProfileScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<Override> baseOverrides({
    required Future<AuthUser> Function(String) behavior,
    AuthSessionStore? store,
  }) => [
    authSessionStoreProvider.overrideWithValue(
      store ?? (AuthSessionStore()..write(user)),
    ),
    authRemoteDatasourceProvider.overrideWithValue(
      _FakeAuthRemoteDatasource(behavior),
    ),
    googleSignInInitializerProvider.overrideWithValue(noopInitializer),
  ];

  testWidgets('estado de erro do authStateProvider usa userMessageFor', (
    tester,
  ) async {
    await pumpProfile(
      tester,
      overrides: [
        ...baseOverrides(behavior: (_) async => user),
        authStateProvider.overrideWith(_AlwaysFailingAuthNotifier.new),
      ],
    );

    expect(find.text(pt.errorGeneric), findsOneWidget);
    expect(find.textContaining('detalhe_interno_feio'), findsNothing);
  });

  testWidgets('sessão expirada mostra banner com ação de entrar de novo', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: baseOverrides(behavior: (_) async => user),
    );
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);
    container.read(sessionExpiredProvider.notifier).markExpired();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: const Scaffold(body: ProfileScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(pt.sessionExpiredBanner), findsOneWidget);
    expect(find.text(pt.errorSessionExpired), findsOneWidget);
    expect(find.text(pt.sessionExpiredSignInAgain), findsOneWidget);
  });

  testWidgets('sem sessão expirada não mostra banner', (tester) async {
    await pumpProfile(
      tester,
      overrides: baseOverrides(behavior: (_) async => user),
    );

    expect(find.text(pt.sessionExpiredBanner), findsNothing);
  });
}

/// Notifier que sempre falha, para exercitar o ramo `error` da tela.
class _AlwaysFailingAuthNotifier extends AuthNotifier {
  @override
  Future<AuthUser?> build() async => throw StateError('detalhe_interno_feio');
}

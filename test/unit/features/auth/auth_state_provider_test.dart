import '../../../support/fakes/fake_auth_remote_datasource.dart';
import '../../../support/fakes/fake_oidc_browser.dart';

import 'package:coldigui/features/auth/data/auth_remote_datasource.dart';
import 'package:coldigui/features/auth/data/auth_session_store.dart';
import 'package:coldigui/features/auth/data/oidc/oidc_callback.dart';
import 'package:coldigui/features/auth/data/oidc/oidc_callback_inbox.dart';
import 'package:coldigui/features/auth/data/oidc/oidc_redirect_request.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() {
  const storedUser = AuthUser(
    googleSub: 'sub-1',
    sessionToken: 'token-1',
    email: 'a@b.com',
  );

  AuthSessionStore seededStore() {
    final store = AuthSessionStore();
    store.write(storedUser);
    return store;
  }

  ProviderContainer buildContainer({
    required Future<AuthUser> Function(String) behavior,
    required AuthSessionStore store,
    GoogleSignInInitializer? initializer,
    GoogleSilentIdTokenRefresher? refresher,
    OidcCallbackInbox? inbox,
    FakeOidcBrowser? browser,
  }) {
    return ProviderContainer(
      overrides: [
        authSessionStoreProvider.overrideWithValue(store),
        authRemoteDatasourceProvider.overrideWithValue(
          FakeAuthRemoteDatasource(behavior),
        ),
        if (initializer != null)
          googleSignInInitializerProvider.overrideWithValue(initializer),
        if (refresher != null)
          googleSilentIdTokenRefresherProvider.overrideWithValue(refresher),
        if (inbox != null) oidcCallbackInboxProvider.overrideWithValue(inbox),
        if (browser != null) oidcBrowserProvider.overrideWithValue(browser),
        googleClientIdProvider.overrideWithValue('cid-test'),
      ],
      // Riverpod 3 re-tenta `build()` que lança; num container sem listener
      // o `.future` nunca resolve. `main.dart` já desliga o retry no
      // `ProviderScope` de produção — aqui é só o harness de teste igualando.
      retry: (_, _) => null,
    );
  }

  group('AuthNotifier.build — resiliência de sessão (B1)', () {
    test('401 do Worker limpa a sessão local e retorna null', () async {
      final store = seededStore();
      final container = buildContainer(
        store: store,
        behavior: (_) async => throw AuthUnauthorizedException(401),
      );
      addTearDown(container.dispose);

      final result = await container.read(authStateProvider.future);

      expect(result, isNull);
      expect(store.read(), isNull);
    });

    test('403 do Worker limpa a sessão local e retorna null', () async {
      final store = seededStore();
      final container = buildContainer(
        store: store,
        behavior: (_) async => throw AuthUnauthorizedException(403),
      );
      addTearDown(container.dispose);

      final result = await container.read(authStateProvider.future);

      expect(result, isNull);
      expect(store.read(), isNull);
    });

    test(
      'timeout de rede mantém a sessão armazenada (não verificada)',
      () async {
        final store = seededStore();
        final container = buildContainer(
          store: store,
          behavior: (_) async => throw DioException(
            requestOptions: RequestOptions(path: '/api/auth/session'),
            type: DioExceptionType.connectionTimeout,
          ),
        );
        addTearDown(container.dispose);

        final result = await container.read(authStateProvider.future);

        expect(result, same(storedUser));
        expect(store.read(), same(storedUser));
      },
    );

    test('503 do Worker mantém a sessão armazenada (não verificada)', () async {
      final store = seededStore();
      final container = buildContainer(
        store: store,
        behavior: (_) async {
          final requestOptions = RequestOptions(path: '/api/auth/session');
          throw DioException(
            requestOptions: requestOptions,
            type: DioExceptionType.badResponse,
            response: Response(requestOptions: requestOptions, statusCode: 503),
          );
        },
      );
      addTearDown(container.dispose);

      final result = await container.read(authStateProvider.future);

      expect(result, same(storedUser));
      expect(store.read(), same(storedUser));
    });

    test('sem sessão armazenada retorna null sem chamar a rede', () async {
      var called = false;
      final store = AuthSessionStore();
      final container = buildContainer(
        store: store,
        behavior: (_) async {
          called = true;
          return storedUser;
        },
      );
      addTearDown(container.dispose);

      final result = await container.read(authStateProvider.future);

      expect(result, isNull);
      expect(called, isFalse);
    });

    test(
      'sucesso atualiza a sessão armazenada com a resposta do Worker',
      () async {
        final store = seededStore();
        const refreshed = AuthUser(
          googleSub: 'sub-1',
          sessionToken: 'token-1',
          email: 'a@b.com',
          username: 'joao',
        );
        final container = buildContainer(
          store: store,
          behavior: (_) async => refreshed,
        );
        addTearDown(container.dispose);

        final result = await container.read(authStateProvider.future);

        expect(result, same(refreshed));
        expect(store.read(), same(refreshed));
      },
    );
  });

  group('AuthNotifier.build — SDK do Google indisponível (A5)', () {
    test('falha de init não apaga a sessão armazenada', () async {
      final store = seededStore();
      final container = buildContainer(
        store: store,
        behavior: (_) async => storedUser,
        initializer: () async => throw StateError('gis bloqueado'),
      );
      addTearDown(container.dispose);

      final result = await container.read(authStateProvider.future);

      expect(
        result,
        same(storedUser),
        reason: 'SDK bloqueado não pode fazer o usuário parecer deslogado',
      );
      expect(store.read(), same(storedUser));
    });

    test('falha de init marca o login como indisponível', () async {
      final container = buildContainer(
        store: seededStore(),
        behavior: (_) async => storedUser,
        initializer: () async => throw StateError('gis bloqueado'),
      );
      addTearDown(container.dispose);

      expect(container.read(googleSignInUnavailableProvider), isFalse);

      await container.read(authStateProvider.future);

      expect(container.read(googleSignInUnavailableProvider), isTrue);
    });

    test('init bem-sucedido mantém o login disponível', () async {
      final container = buildContainer(
        store: seededStore(),
        behavior: (_) async => storedUser,
        initializer: () async =>
            const Stream<GoogleSignInAuthenticationEvent>.empty(),
      );
      addTearDown(container.dispose);

      await container.read(authStateProvider.future);

      expect(container.read(googleSignInUnavailableProvider), isFalse);
    });
  });

  group('AuthNotifier.refreshIdToken — transitório vs conclusivo (D.4)', () {
    Future<ProviderContainer> containerWithSession({
      required GoogleSilentIdTokenRefresher refresher,
    }) async {
      final container = buildContainer(
        store: seededStore(),
        behavior: (_) async => storedUser,
        refresher: refresher,
      );
      addTearDown(container.dispose);
      await container.read(authStateProvider.future);
      return container;
    }

    test(
      'refresher que lança não marca sessão expirada e mantém o token',
      () async {
        final container = await containerWithSession(
          refresher: () async => throw StateError('gis bloqueado'),
        );

        final token = await container
            .read(authStateProvider.notifier)
            .refreshIdToken();

        expect(token, isNull, reason: 'não houve token novo para dar');
        expect(
          container.read(sessionExpiredProvider),
          isFalse,
          reason: 'falha transitória não pode exigir login manual',
        );
        expect(
          container.read(authStateProvider).value?.sessionToken,
          storedUser.sessionToken,
          reason: 'o token corrente segue em uso até um 401 conclusivo',
        );
      },
    );

    test('refresher que devolve o mesmo token marca expirada', () async {
      final container = await containerWithSession(
        refresher: () async => storedUser.sessionToken,
      );

      final token = await container
          .read(authStateProvider.notifier)
          .refreshIdToken();

      expect(token, isNull);
      expect(container.read(sessionExpiredProvider), isTrue);
    });
  });

  group('AuthNotifier.build — callback OIDC pendente (spec D9/D15)', () {
    const oidcUser = AuthUser(
      googleSub: 'sub-oidc',
      sessionToken: 'tok-oidc',
      email: 'o@b.com',
    );

    test('Success: establishSession recebe o id_token e a sessão é gravada, ignorando a armazenada', () async {
      final store = seededStore(); // sessão antiga 'token-1'
      final received = <String>[];
      final container = buildContainer(
        store: store,
        behavior: (token) async {
          received.add(token);
          return oidcUser;
        },
        inbox: OidcCallbackInbox(
          const OidcCallbackSuccess(idToken: 'tok-oidc', returnTo: '/perfil'),
        ),
      );
      addTearDown(container.dispose);

      final result = await container.read(authStateProvider.future);

      expect(received, ['tok-oidc']);
      expect(result?.googleSub, 'sub-oidc');
      expect(store.read()?.sessionToken, 'tok-oidc');
    });

    test(
      'Success + Worker 401: AsyncError, store limpo, inbox vazio',
      () async {
        final store = seededStore();
        final inbox = OidcCallbackInbox(
          const OidcCallbackSuccess(idToken: 'tok-oidc', returnTo: '/'),
        );
        final container = buildContainer(
          store: store,
          behavior: (_) async => throw AuthUnauthorizedException(401),
          inbox: inbox,
        );
        addTearDown(container.dispose);

        await expectLater(
          container.read(authStateProvider.future),
          throwsA(isA<AuthUnauthorizedException>()),
        );
        expect(store.read(), isNull);
        expect(inbox.take(), isNull);
      },
    );

    test('Cancelled: segue para a sessão armazenada', () async {
      final store = seededStore();
      final container = buildContainer(
        store: store,
        behavior: (_) async => storedUser,
        inbox: OidcCallbackInbox(
          const OidcCallbackCancelled(error: 'access_denied', returnTo: '/'),
        ),
      );
      addTearDown(container.dispose);

      final result = await container.read(authStateProvider.future);
      expect(result?.googleSub, 'sub-1');
    });

    test('Invalid(nonce_mismatch): AsyncError com StateError', () async {
      final container = buildContainer(
        store: AuthSessionStore(),
        behavior: (_) async => storedUser,
        inbox: OidcCallbackInbox(
          const OidcCallbackInvalid(reason: 'nonce_mismatch', returnTo: '/'),
        ),
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(authStateProvider.future),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'oidc_nonce_mismatch',
          ),
        ),
      );
    });

    test('Invalid(request_missing) com sessão armazenada: mantém a sessão, sem lançar (Back após login)', () async {
      final container = buildContainer(
        store: seededStore(),
        behavior: (_) async => storedUser,
        inbox: OidcCallbackInbox(
          const OidcCallbackInvalid(reason: 'request_missing', returnTo: '/'),
        ),
      );
      addTearDown(container.dispose);

      final result = await container.read(authStateProvider.future);
      expect(result?.googleSub, 'sub-1');
    });

    for (final reason in ['request_missing', 'csrf_mismatch']) {
      test(
        'Invalid($reason): AsyncError com OidcContextMismatchException',
        () async {
          final container = buildContainer(
            store: AuthSessionStore(),
            behavior: (_) async => storedUser,
            inbox: OidcCallbackInbox(
              OidcCallbackInvalid(reason: reason, returnTo: '/'),
            ),
          );
          addTearDown(container.dispose);

          await expectLater(
            container.read(authStateProvider.future),
            throwsA(
              isA<OidcContextMismatchException>().having(
                (e) => e.reason,
                'reason',
                reason,
              ),
            ),
          );
        },
      );
    }

    test('inbox vazio: comportamento atual (sessão armazenada)', () async {
      final container = buildContainer(
        store: seededStore(),
        behavior: (_) async => storedUser,
        inbox: OidcCallbackInbox(),
      );
      addTearDown(container.dispose);
      expect(
        (await container.read(authStateProvider.future))?.googleSub,
        'sub-1',
      );
    });
  });

  group('AuthNotifier.startGoogleRedirect (spec §3.6)', () {
    test('grava o request e navega para o Google com state.returnTo', () async {
      final browser = FakeOidcBrowser();
      final container = buildContainer(
        store: AuthSessionStore(),
        behavior: (_) async => storedUser,
        browser: browser,
      );
      addTearDown(container.dispose);
      await container.read(authStateProvider.future);

      container
          .read(authStateProvider.notifier)
          .startGoogleRedirect(returnTo: '/listas/publicas');

      final request = OidcRedirectRequest.fromJson(browser.storedRequest);
      expect(request, isNotNull);
      expect(browser.navigated, hasLength(1));
      final q = browser.navigated.single.queryParameters;
      expect(browser.navigated.single.host, 'accounts.google.com');
      expect(q['client_id'], 'cid-test');
      expect(q['redirect_uri'], 'https://v2.plpcg.com/');
      expect(q['nonce'], request!.nonce);
      expect(OidcRedirectRequest.decodeState(q['state']), {
        'csrf': request.csrf,
        'returnTo': '/listas/publicas',
      });
    });

    test('client id vazio: StateError e nada navega', () async {
      final browser = FakeOidcBrowser();
      final container = ProviderContainer(
        overrides: [
          authSessionStoreProvider.overrideWithValue(AuthSessionStore()),
          authRemoteDatasourceProvider.overrideWithValue(
            FakeAuthRemoteDatasource.returning(storedUser),
          ),
          googleClientIdProvider.overrideWithValue(''),
          oidcBrowserProvider.overrideWithValue(browser),
        ],
        retry: (_, _) => null,
      );
      addTearDown(container.dispose);

      expect(
        () => container
            .read(authStateProvider.notifier)
            .startGoogleRedirect(returnTo: '/'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'google_client_id_missing',
          ),
        ),
      );
      expect(browser.navigated, isEmpty);
      expect(browser.storedRequest, isNull);
    });
  });
}

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

/// Store só-memória que finge ter uma sessão no formato antigo em
/// `sessionStorage` — o stub nativo devolve sempre `null` ali.
class _LegacyStore extends AuthSessionStore {
  _LegacyStore(this._legacyRaw);

  String? _legacyRaw;
  bool legacyTaken = false;

  @override
  String? takeLegacySessionStorage() {
    legacyTaken = true;
    final raw = _legacyRaw;
    _legacyRaw = null;
    return raw;
  }
}

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
    OidcCallbackInbox? inbox,
    FakeOidcBrowser? browser,
  }) {
    return ProviderContainer(
      overrides: [
        authSessionStoreProvider.overrideWithValue(store),
        authRemoteDatasourceProvider.overrideWithValue(
          FakeAuthRemoteDatasource(behavior),
        ),
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

  group('AuthNotifier.build — boot sem rede (spec D7)', () {
    test('sessão guardada é devolvida sem chamar o Worker', () async {
      final store = seededStore();
      var calls = 0;
      final container = buildContainer(
        store: store,
        behavior: (_) async {
          calls++;
          return storedUser;
        },
      );
      addTearDown(container.dispose);

      expect(await container.read(authStateProvider.future), same(storedUser));
      expect(calls, 0);
    });

    test('sem sessão guardada retorna null sem chamar a rede', () async {
      var calls = 0;
      final container = buildContainer(
        store: AuthSessionStore(),
        behavior: (_) async {
          calls++;
          return storedUser;
        },
      );
      addTearDown(container.dispose);

      expect(await container.read(authStateProvider.future), isNull);
      expect(calls, 0);
    });
  });

  group('AuthNotifier.build — migração da sessão antiga (spec D12)', () {
    test(
      'sessionStorage antigo com id_token vira sessão nova gravada',
      () async {
        final store = _LegacyStore('{"googleSub":"sub-1","idToken":"eyJ.a.b"}');
        String? received;
        final container = buildContainer(
          store: store,
          behavior: (idToken) async {
            received = idToken;
            return storedUser;
          },
        );
        addTearDown(container.dispose);

        expect(
          await container.read(authStateProvider.future),
          same(storedUser),
        );
        expect(received, 'eyJ.a.b');
        expect(store.read(), same(storedUser));
        expect(store.legacyTaken, isTrue);
      },
    );

    test(
      'id_token antigo recusado → null, e o sessionStorage foi consumido',
      () async {
        final store = _LegacyStore('{"googleSub":"sub-1","idToken":"eyJ.a.b"}');
        final container = buildContainer(
          store: store,
          behavior: (_) async => throw AuthUnauthorizedException(401),
        );
        addTearDown(container.dispose);

        expect(await container.read(authStateProvider.future), isNull);
        expect(store.read(), isNull);
        expect(store.legacyTaken, isTrue);
      },
    );
  });

  group('AuthNotifier.onUnauthorized / signOut (spec D8)', () {
    test('onUnauthorized limpa a store e o estado vira null', () async {
      final store = seededStore();
      final container = buildContainer(
        store: store,
        behavior: (_) async => storedUser,
      );
      addTearDown(container.dispose);
      await container.read(authStateProvider.future);

      container.read(authStateProvider.notifier).onUnauthorized('token-1');

      expect(
        container.read(authStateProvider),
        const AsyncData<AuthUser?>(null),
      );
      expect(store.read(), isNull);
    });

    test(
      '401 de um token que já não é o corrente não apaga a sessão nova',
      () async {
        final store = seededStore(); // storedUser.sessionToken == 'token-1'
        final container = buildContainer(
          store: store,
          behavior: (_) async => storedUser,
        );
        addTearDown(container.dispose);
        await container.read(authStateProvider.future);

        container
            .read(authStateProvider.notifier)
            .onUnauthorized('token-velho');

        expect(
          container.read(authStateProvider).asData?.value,
          same(storedUser),
        );
        expect(store.read(), same(storedUser));
      },
    );

    test('onUnauthorized é idempotente', () async {
      final store = seededStore();
      final container = buildContainer(
        store: store,
        behavior: (_) async => storedUser,
      );
      addTearDown(container.dispose);
      await container.read(authStateProvider.future);

      container.read(authStateProvider.notifier).onUnauthorized('token-1');
      container.read(authStateProvider.notifier).onUnauthorized('token-1');

      expect(
        container.read(authStateProvider),
        const AsyncData<AuthUser?>(null),
      );
      expect(store.read(), isNull);
    });

    test(
      'signOut revoga a sessão no Worker e limpa mesmo se a revogação falhar',
      () async {
        final store = seededStore();
        final remote = FakeAuthRemoteDatasource(
          (_) async => storedUser,
          onRevoke: (_) async => throw DioException(
            requestOptions: RequestOptions(path: '/api/auth/session'),
            type: DioExceptionType.connectionTimeout,
          ),
        );
        final container = ProviderContainer(
          overrides: [
            authSessionStoreProvider.overrideWithValue(store),
            authRemoteDatasourceProvider.overrideWithValue(remote),
            googleClientIdProvider.overrideWithValue('cid-test'),
          ],
          retry: (_, _) => null,
        );
        addTearDown(container.dispose);
        await container.read(authStateProvider.future);

        await container.read(authStateProvider.notifier).signOut();

        expect(remote.revoked, ['token-1']);
        expect(
          container.read(authStateProvider),
          const AsyncData<AuthUser?>(null),
        );
        expect(store.read(), isNull);
      },
    );
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

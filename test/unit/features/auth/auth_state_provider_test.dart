import '../../../support/fakes/fake_auth_remote_datasource.dart';
import 'package:coldigui/features/auth/data/auth_remote_datasource.dart';
import 'package:coldigui/features/auth/data/auth_session_store.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() {
  const storedUser = AuthUser(
    googleSub: 'sub-1',
    idToken: 'token-1',
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
      ],
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
          idToken: 'token-1',
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
          container.read(authStateProvider).value?.idToken,
          storedUser.idToken,
          reason: 'o token corrente segue em uso até um 401 conclusivo',
        );
      },
    );

    test('refresher que devolve o mesmo token marca expirada', () async {
      final container = await containerWithSession(
        refresher: () async => storedUser.idToken,
      );

      final token = await container
          .read(authStateProvider.notifier)
          .refreshIdToken();

      expect(token, isNull);
      expect(container.read(sessionExpiredProvider), isTrue);
    });
  });
}

import 'package:coldigui/features/auth/data/auth_remote_datasource.dart';
import 'package:coldigui/features/auth/data/auth_session_store.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake que substitui a chamada de rede real por um comportamento controlado
/// pelo teste (sucesso, [AuthUnauthorizedException] ou [DioException]).
class _FakeAuthRemoteDatasource extends AuthRemoteDatasource {
  _FakeAuthRemoteDatasource(this._behavior) : super(Dio());

  final Future<AuthUser> Function(String idToken) _behavior;

  @override
  Future<AuthUser> establishSession(String idToken) => _behavior(idToken);
}

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
  }) {
    return ProviderContainer(
      overrides: [
        authSessionStoreProvider.overrideWithValue(store),
        authRemoteDatasourceProvider.overrideWithValue(
          _FakeAuthRemoteDatasource(behavior),
        ),
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

    test('timeout de rede mantém a sessão armazenada (não verificada)', () async {
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
    });

    test('503 do Worker mantém a sessão armazenada (não verificada)', () async {
      final store = seededStore();
      final container = buildContainer(
        store: store,
        behavior: (_) async {
          final requestOptions = RequestOptions(path: '/api/auth/session');
          throw DioException(
            requestOptions: requestOptions,
            type: DioExceptionType.badResponse,
            response: Response(
              requestOptions: requestOptions,
              statusCode: 503,
            ),
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

    test('sucesso atualiza a sessão armazenada com a resposta do Worker', () async {
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
    });
  });
}

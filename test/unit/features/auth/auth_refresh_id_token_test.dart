import 'package:coldigui/features/auth/data/auth_remote_datasource.dart';
import 'package:coldigui/features/auth/data/auth_session_store.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

class _FakeAuthRemoteDatasource extends AuthRemoteDatasource {
  _FakeAuthRemoteDatasource(this._behavior) : super(Dio());

  final Future<AuthUser> Function(String idToken) _behavior;

  @override
  Future<AuthUser> establishSession(String idToken) => _behavior(idToken);
}

void main() {
  const storedUser = AuthUser(
    googleSub: 'sub-1',
    idToken: 'token-antigo',
    email: 'a@b.com',
    username: 'jairo',
  );

  /// Inicializador que não toca no plugin — o stream nunca emite.
  Future<Stream<GoogleSignInAuthenticationEvent>> noopInitializer() async =>
      const Stream<GoogleSignInAuthenticationEvent>.empty();

  AuthSessionStore seededStore() {
    final store = AuthSessionStore();
    store.write(storedUser);
    return store;
  }

  ProviderContainer buildContainer({
    required AuthSessionStore store,
    required GoogleSilentIdTokenRefresher refresher,
  }) {
    return ProviderContainer(
      overrides: [
        authSessionStoreProvider.overrideWithValue(store),
        authRemoteDatasourceProvider.overrideWithValue(
          _FakeAuthRemoteDatasource((_) async => storedUser),
        ),
        googleSignInInitializerProvider.overrideWithValue(noopInitializer),
        googleSilentIdTokenRefresherProvider.overrideWithValue(refresher),
      ],
    );
  }

  group('sessionExpiredProvider', () {
    test('começa false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(sessionExpiredProvider), isFalse);
    });
  });

  group('AuthNotifier.refreshIdToken', () {
    test('token novo do Google atualiza sessão, store e estado', () async {
      final store = seededStore();
      final container = buildContainer(
        store: store,
        refresher: () async => 'token-novo',
      );
      addTearDown(container.dispose);
      await container.read(authStateProvider.future);

      final token = await container
          .read(authStateProvider.notifier)
          .refreshIdToken();

      expect(token, 'token-novo');
      expect(container.read(authStateProvider).value?.idToken, 'token-novo');
      // Campos da sessão anterior sobrevivem ao refresh.
      expect(container.read(authStateProvider).value?.username, 'jairo');
      expect(store.read()?.idToken, 'token-novo');
      expect(container.read(sessionExpiredProvider), isFalse);
    });

    test('refresh devolvendo null marca sessionExpired', () async {
      final store = seededStore();
      final container = buildContainer(
        store: store,
        refresher: () async => null,
      );
      addTearDown(container.dispose);
      await container.read(authStateProvider.future);

      final token = await container
          .read(authStateProvider.notifier)
          .refreshIdToken();

      expect(token, isNull);
      expect(container.read(sessionExpiredProvider), isTrue);
    });

    test('refresh devolvendo token vazio marca sessionExpired', () async {
      final container = buildContainer(
        store: seededStore(),
        refresher: () async => '',
      );
      addTearDown(container.dispose);
      await container.read(authStateProvider.future);

      expect(
        await container.read(authStateProvider.notifier).refreshIdToken(),
        isNull,
      );
      expect(container.read(sessionExpiredProvider), isTrue);
    });

    test(
      'refresh que lança não propaga a exceção e marca sessionExpired',
      () async {
        final container = buildContainer(
          store: seededStore(),
          refresher: () async => throw StateError('sdk bloqueado'),
        );
        addTearDown(container.dispose);
        await container.read(authStateProvider.future);

        expect(
          await container.read(authStateProvider.notifier).refreshIdToken(),
          isNull,
        );
        expect(container.read(sessionExpiredProvider), isTrue);
      },
    );

    test('sessão local preservada quando o refresh falha', () async {
      final store = seededStore();
      final container = buildContainer(
        store: store,
        refresher: () async => null,
      );
      addTearDown(container.dispose);
      await container.read(authStateProvider.future);

      await container.read(authStateProvider.notifier).refreshIdToken();

      expect(store.read()?.idToken, 'token-antigo');
    });

    test('sem usuário logado devolve null sem marcar sessionExpired', () async {
      final container = buildContainer(
        store: AuthSessionStore(),
        refresher: () async => fail('não deve tentar refresh sem sessão'),
      );
      addTearDown(container.dispose);
      await container.read(authStateProvider.future);

      expect(
        await container.read(authStateProvider.notifier).refreshIdToken(),
        isNull,
      );
      expect(container.read(sessionExpiredProvider), isFalse);
    });

    test('chamadas concorrentes compartilham um único refresh', () async {
      var calls = 0;
      final container = buildContainer(
        store: seededStore(),
        refresher: () async {
          calls++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return 'token-novo';
        },
      );
      addTearDown(container.dispose);
      await container.read(authStateProvider.future);
      final notifier = container.read(authStateProvider.notifier);

      final results = await Future.wait([
        notifier.refreshIdToken(),
        notifier.refreshIdToken(),
        notifier.refreshIdToken(),
      ]);

      expect(calls, 1);
      expect(results, ['token-novo', 'token-novo', 'token-novo']);
    });

    test(
      'refresh bem-sucedido depois de expirar limpa sessionExpired',
      () async {
        var token = <String?>[null, 'token-novo'];
        var index = 0;
        final container = buildContainer(
          store: seededStore(),
          refresher: () async => token[index++],
        );
        addTearDown(container.dispose);
        await container.read(authStateProvider.future);
        final notifier = container.read(authStateProvider.notifier);

        await notifier.refreshIdToken();
        expect(container.read(sessionExpiredProvider), isTrue);

        await notifier.refreshIdToken();
        expect(container.read(sessionExpiredProvider), isFalse);
      },
    );

    test('token idêntico conta como refresh falho (Critical 1)', () async {
      final store = seededStore();
      final container = buildContainer(
        store: store,
        refresher: () async => 'token-antigo',
      );
      addTearDown(container.dispose);
      await container.read(authStateProvider.future);

      final token = await container
          .read(authStateProvider.notifier)
          .refreshIdToken();

      expect(token, isNull);
      expect(container.read(sessionExpiredProvider), isTrue);
      expect(store.read()?.idToken, 'token-antigo');
    });

    test(
      'refresh com token idêntico não reemite estado (evita laço de 401)',
      () async {
        final container = buildContainer(
          store: seededStore(),
          refresher: () async => 'token-antigo',
        );
        addTearDown(container.dispose);
        await container.read(authStateProvider.future);

        var emissions = 0;
        container.listen(
          authStateProvider,
          (_, _) => emissions++,
          fireImmediately: false,
        );

        await container.read(authStateProvider.notifier).refreshIdToken();
        await container.read(authStateProvider.notifier).refreshIdToken();

        // Zero: quem observa authStateProvider e dispara request não pode ser
        // reconstruído por um refresh que não trouxe token novo.
        expect(emissions, 0);
      },
    );

    test('token novo reemite estado normalmente', () async {
      final container = buildContainer(
        store: seededStore(),
        refresher: () async => 'token-novo',
      );
      addTearDown(container.dispose);
      await container.read(authStateProvider.future);

      var emissions = 0;
      container.listen(authStateProvider, (_, _) => emissions++);

      await container.read(authStateProvider.notifier).refreshIdToken();

      expect(emissions, 1);
    });

    test('signOut limpa a marca de sessão expirada', () async {
      final container = buildContainer(
        store: seededStore(),
        refresher: () async => null,
      );
      addTearDown(container.dispose);
      await container.read(authStateProvider.future);
      final notifier = container.read(authStateProvider.notifier);
      await notifier.refreshIdToken();
      expect(container.read(sessionExpiredProvider), isTrue);

      await notifier.signOut();

      expect(container.read(sessionExpiredProvider), isFalse);
    });
  });
}

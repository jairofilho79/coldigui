import '../../../support/fakes/fake_auth_remote_datasource.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:coldigui/core/network/auth_refresh_interceptor.dart';
import 'package:coldigui/core/network/retry_interceptor.dart';
import 'package:coldigui/core/providers/dio_provider.dart';
import 'package:coldigui/features/auth/data/auth_session_store.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_dio_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.statuses);

  final List<int> statuses;
  final List<String?> authHeaders = [];

  int get calls => authHeaders.length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final status = statuses[authHeaders.length.clamp(0, statuses.length - 1)];
    authHeaders.add(options.headers['Authorization'] as String?);
    return ResponseBody.fromString(
      '{}',
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

String _b64(Map<String, Object?> json) =>
    base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

/// JWT de mentira — só o payload é lido (a assinatura nunca é validada).
String _jwtExpiringIn(Duration delta) =>
    '${_b64({'alg': 'RS256'})}.'
    '${_b64({'exp': DateTime.now().toUtc().add(delta).millisecondsSinceEpoch ~/ 1000})}.assinatura-falsa';

void main() {
  const storedUser = AuthUser(googleSub: 'sub-1', idToken: 'token-velho');

  Future<Stream<GoogleSignInAuthenticationEvent>> noopInitializer() async =>
      const Stream<GoogleSignInAuthenticationEvent>.empty();

  ProviderContainer buildContainer({
    GoogleSilentIdTokenRefresher? refresher,
    AuthUser user = storedUser,
  }) {
    final store = AuthSessionStore()..write(user);
    return ProviderContainer(
      overrides: [
        authSessionStoreProvider.overrideWithValue(store),
        authRemoteDatasourceProvider.overrideWithValue(
          FakeAuthRemoteDatasource.returning(user),
        ),
        googleSignInInitializerProvider.overrideWithValue(noopInitializer),
        if (refresher != null)
          googleSilentIdTokenRefresherProvider.overrideWithValue(refresher),
      ],
    );
  }

  test('dioProvider tem AuthRefreshInterceptor antes do RetryInterceptor', () {
    final container = buildContainer();
    addTearDown(container.dispose);

    final interceptors = container
        .read(dioProvider)
        .interceptors
        .whereType<Interceptor>()
        .toList();

    final authIndex = interceptors.indexWhere(
      (i) => i is AuthRefreshInterceptor,
    );
    final retryIndex = interceptors.indexWhere((i) => i is RetryInterceptor);

    expect(authIndex, greaterThanOrEqualTo(0));
    expect(retryIndex, greaterThan(authIndex));
  });

  test('coldigomDioProvider tem retry mas não refresh (API pública)', () {
    final container = buildContainer();
    addTearDown(container.dispose);

    final interceptors = container.read(coldigomDioProvider).interceptors;

    expect(interceptors.whereType<RetryInterceptor>(), hasLength(1));
    expect(interceptors.whereType<AuthRefreshInterceptor>(), isEmpty);
  });

  test(
    '401 no dioProvider renova o token e repete com o Bearer novo',
    () async {
      final container = buildContainer(refresher: () async => 'token-novo');
      addTearDown(container.dispose);
      await container.read(authStateProvider.future);

      final adapter = _ScriptedAdapter([401, 200]);
      final dio = container.read(dioProvider)..httpClientAdapter = adapter;

      final response = await dio.get<Object?>(
        '/api/playlists',
        options: Options(headers: {'Authorization': 'Bearer token-velho'}),
      );

      expect(response.statusCode, 200);
      expect(adapter.authHeaders, ['Bearer token-velho', 'Bearer token-novo']);
      expect(container.read(sessionExpiredProvider), isFalse);
      expect(container.read(authStateProvider).value?.idToken, 'token-novo');
    },
  );

  test(
    'token idêntico do Google não vira laço de refresh (Critical 1)',
    () async {
      var refreshes = 0;
      final container = buildContainer(
        refresher: () async {
          refreshes++;
          return 'token-velho'; // o Google reemite o mesmo token
        },
      );
      addTearDown(container.dispose);
      await container.read(authStateProvider.future);

      final adapter = _ScriptedAdapter([401]);
      final dio = container.read(dioProvider)..httpClientAdapter = adapter;

      Future<void> call() => expectLater(
        dio.get<Object?>(
          '/api/playlists',
          options: Options(headers: {'Authorization': 'Bearer token-velho'}),
        ),
        throwsA(isA<DioException>()),
      );

      await call();
      await call();
      await call();

      expect(container.read(sessionExpiredProvider), isTrue);
      expect(refreshes, 1, reason: 'só a primeira request tenta renovar');
      expect(adapter.calls, 3, reason: 'uma ida por chamada, sem repetição');
    },
  );

  // A5: `AuthUserExpiry.expiresSoon` deixou de ser código morto — o
  // `dioProvider` liga o `exp` do id_token guardado ao refresh preventivo.
  test('token expirando é renovado antes da request (sem 401)', () async {
    final container = buildContainer(
      user: AuthUser(
        googleSub: 'sub-1',
        idToken: _jwtExpiringIn(const Duration(seconds: 30)),
      ),
      refresher: () async => 'token-novo',
    );
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);

    final adapter = _ScriptedAdapter([200]);
    final dio = container.read(dioProvider)..httpClientAdapter = adapter;

    final response = await dio.get<Object?>(
      '/api/playlists',
      options: Options(headers: {'Authorization': 'Bearer token-velho'}),
    );

    expect(response.statusCode, 200);
    expect(adapter.authHeaders, ['Bearer token-novo']);
    expect(container.read(authStateProvider).value?.idToken, 'token-novo');
  });

  test('token ainda longe do vencimento não é renovado', () async {
    var refreshes = 0;
    final container = buildContainer(
      user: AuthUser(
        googleSub: 'sub-1',
        idToken: _jwtExpiringIn(const Duration(hours: 1)),
      ),
      refresher: () async {
        refreshes++;
        return 'token-novo';
      },
    );
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);

    final adapter = _ScriptedAdapter([200]);
    final dio = container.read(dioProvider)..httpClientAdapter = adapter;

    await dio.get<Object?>(
      '/api/playlists',
      options: Options(headers: {'Authorization': 'Bearer token-velho'}),
    );

    expect(refreshes, 0);
    expect(adapter.authHeaders, ['Bearer token-velho']);
  });

  test('401 com refresh impossível marca sessão expirada', () async {
    final container = buildContainer(refresher: () async => null);
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);

    final adapter = _ScriptedAdapter([401]);
    final dio = container.read(dioProvider)..httpClientAdapter = adapter;

    await expectLater(
      dio.get<Object?>(
        '/api/playlists',
        options: Options(headers: {'Authorization': 'Bearer token-velho'}),
      ),
      throwsA(isA<DioException>()),
    );

    expect(adapter.calls, 1);
    expect(container.read(sessionExpiredProvider), isTrue);
  });
}

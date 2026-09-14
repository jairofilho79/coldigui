import '../../../support/fakes/fake_auth_remote_datasource.dart';

import 'dart:typed_data';

import 'package:coldigui/core/network/auth_unauthorized_interceptor.dart';
import 'package:coldigui/core/network/retry_interceptor.dart';
import 'package:coldigui/core/providers/dio_provider.dart';
import 'package:coldigui/features/auth/data/auth_session_store.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_dio_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.statuses);

  final List<int> statuses;
  final List<String?> authHeaders = [];

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

void main() {
  const storedUser = AuthUser(googleSub: 'sub-1', sessionToken: 'sess_velho');

  ProviderContainer buildContainer({AuthUser user = storedUser}) {
    final store = AuthSessionStore()..write(user);
    return ProviderContainer(
      overrides: [
        authSessionStoreProvider.overrideWithValue(store),
        authRemoteDatasourceProvider.overrideWithValue(
          FakeAuthRemoteDatasource.returning(user),
        ),
      ],
    );
  }

  test(
    'dioProvider tem AuthUnauthorizedInterceptor antes do RetryInterceptor',
    () {
      final container = buildContainer();
      addTearDown(container.dispose);

      final interceptors = container.read(dioProvider).interceptors.toList();
      final authIndex = interceptors.indexWhere(
        (i) => i is AuthUnauthorizedInterceptor,
      );
      final retryIndex = interceptors.indexWhere((i) => i is RetryInterceptor);

      expect(authIndex, greaterThanOrEqualTo(0));
      expect(retryIndex, greaterThan(authIndex));
    },
  );

  test('coldigomDioProvider tem retry mas não o interceptor de sessão (API pública)', () {
    final container = buildContainer();
    addTearDown(container.dispose);

    final interceptors = container.read(coldigomDioProvider).interceptors;
    expect(interceptors.whereType<RetryInterceptor>(), hasLength(1));
    expect(interceptors.whereType<AuthUnauthorizedInterceptor>(), isEmpty);
  });

  test(
    '401 no dioProvider com Bearer sess_ desloga e não repete a request',
    () async {
      final container = buildContainer();
      addTearDown(container.dispose);
      expect(await container.read(authStateProvider.future), same(storedUser));

      final adapter = _ScriptedAdapter([401, 200]);
      final dio = container.read(dioProvider)..httpClientAdapter = adapter;

      await expectLater(
        dio.get<Object?>(
          '/api/playlists',
          options: Options(headers: {'Authorization': 'Bearer sess_velho'}),
        ),
        throwsA(isA<DioException>()),
      );

      expect(adapter.authHeaders, ['Bearer sess_velho']);
      expect(container.read(authStateProvider).asData?.value, isNull);
    },
  );

  test('401 em rota pública não mexe na sessão', () async {
    final container = buildContainer();
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);

    final dio = container.read(dioProvider)
      ..httpClientAdapter = _ScriptedAdapter([401]);
    await expectLater(
      dio.get<Object?>('/api/catalog/x'),
      throwsA(isA<DioException>()),
    );

    expect(container.read(authStateProvider).asData?.value, same(storedUser));
  });
}

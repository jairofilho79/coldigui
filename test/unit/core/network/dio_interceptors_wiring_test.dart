import '../../../support/fakes/fake_auth_remote_datasource.dart';

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

void main() {
  const storedUser = AuthUser(googleSub: 'sub-1', sessionToken: 'token-velho');

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
}

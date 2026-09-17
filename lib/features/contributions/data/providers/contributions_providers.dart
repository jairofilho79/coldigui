import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/auth_unauthorized_interceptor.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../coldigom/data/constants/coldigom_api_config.dart';
import '../datasources/contributions_remote_datasource.dart';

/// Dio próprio: o `coldigomDioProvider` é público e sem auth; aqui vai Bearer
/// `sess_…` e o interceptor de 401. Sem `RetryInterceptor` — um POST multipart
/// repetido criaria a contribuição duas vezes.
final contributionsDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ColdigomApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );
  dio.interceptors.add(
    AuthUnauthorizedInterceptor(
      onUnauthorized: (token) =>
          ref.read(authStateProvider.notifier).onUnauthorized(token),
    ),
  );
  return dio;
});

final contributionsRemoteDatasourceProvider =
    Provider<ContributionsRemoteDatasource>(
      (ref) =>
          ContributionsRemoteDatasource(ref.watch(contributionsDioProvider)),
    );

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/retry_interceptor.dart';
import '../constants/coldigom_api_config.dart';

/// Cliente HTTP dedicado à API coldigom (separado do PLPCG).
///
/// Só [RetryInterceptor]: a API é pública, não manda `Authorization`, então não
/// há token para renovar.
final coldigomDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ColdigomApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  dio.interceptors.add(RetryInterceptor(dio: dio));

  return dio;
});

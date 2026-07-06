import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/coldigom_api_config.dart';

/// Cliente HTTP dedicado à API coldigom (separado do PLPCG).
final coldigomDioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: ColdigomApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
});

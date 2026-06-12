import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_config.dart';
import '../../domain/entities/offline_manifest.dart';
import '../models/offline_manifest_dto.dart';

/// Fonte remota do manifesto de pacotes offline — UC-09.
class OfflineManifestRemoteDatasource {
  const OfflineManifestRemoteDatasource(this._dio);

  final Dio _dio;

  Future<OfflineManifest> fetchManifest() async {
    if (AppConfig.apiBaseUrl.isEmpty) {
      throw StateError(
        'PLPCG_API_BASE_URL não definido. '
        'Use --dart-define=PLPCG_API_BASE_URL=https://...',
      );
    }

    final response = await _dio.get<dynamic>(ApiEndpoints.offlineManifest);
    final data = response.data;

    if (data is! Map<String, dynamic>) {
      throw const FormatException(
        'offline-manifest.json deve ser um objeto JSON',
      );
    }

    return OfflineManifestDto.fromJson(data);
  }
}

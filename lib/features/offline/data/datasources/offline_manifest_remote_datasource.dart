import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_config.dart';
import '../../domain/entities/offline_manifest.dart';
import '../models/offline_manifest_dto.dart';

/// Fonte remota do manifesto de pacotes offline — UC-09.
class OfflineManifestRemoteDatasource {
  OfflineManifestRemoteDatasource(this._dio);

  static const _cacheTtl = Duration(hours: 24);

  final Dio _dio;

  OfflineManifest? _cachedManifest;
  DateTime? _cacheTime;

  Future<OfflineManifest> fetchManifest() async {
    if (_cachedManifest != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheTtl) {
      return _cachedManifest!;
    }

    final manifest = await _fetchFromNetwork();
    _cachedManifest = manifest;
    _cacheTime = DateTime.now();
    return manifest;
  }

  Future<OfflineManifest> _fetchFromNetwork() async {
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

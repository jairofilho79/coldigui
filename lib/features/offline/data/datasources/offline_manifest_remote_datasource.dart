import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_config.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../domain/entities/offline_manifest.dart';
import '../models/offline_manifest_dto.dart';

/// Fonte remota do manifesto de pacotes offline — UC-09.
class OfflineManifestRemoteDatasource {
  OfflineManifestRemoteDatasource(
    this._dio,
    this._prefs, {
    Future<OfflineManifest> Function()? networkOverride,
  }) : _networkOverride = networkOverride;

  static const _cacheTtl = Duration(hours: 24);

  final Dio _dio;
  final SharedPreferences _prefs;
  final Future<OfflineManifest> Function()? _networkOverride;

  OfflineManifest? _cachedManifest;
  DateTime? _cacheTime;

  Future<OfflineManifest> fetchManifest() async {
    if (_cachedManifest != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheTtl) {
      return _cachedManifest!;
    }

    try {
      final manifest = await _fetchFromNetwork();
      _cachedManifest = manifest;
      _cacheTime = DateTime.now();
      await _persistManifest(manifest);
      return manifest;
    } on Object {
      final persisted = await _loadPersistedManifest();
      if (persisted != null) {
        _cachedManifest = persisted;
        _cacheTime = _loadPersistedCacheTime();
        return persisted;
      }
      rethrow;
    }
  }

  Future<OfflineManifest> _fetchFromNetwork() async {
    if (_networkOverride != null) {
      return _networkOverride();
    }

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

  Future<void> _persistManifest(OfflineManifest manifest) async {
    await _prefs.setString(
      StorageKeys.offlineManifestJson,
      jsonEncode(OfflineManifestDto.toJson(manifest)),
    );
    await _prefs.setInt(
      StorageKeys.offlineManifestCacheTime,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<OfflineManifest?> _loadPersistedManifest() async {
    final raw = _prefs.getString(StorageKeys.offlineManifestJson);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return OfflineManifestDto.fromJson(decoded);
    } on Object {
      return null;
    }
  }

  DateTime? _loadPersistedCacheTime() {
    final epochMs = _prefs.getInt(StorageKeys.offlineManifestCacheTime);
    if (epochMs == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(epochMs);
  }
}

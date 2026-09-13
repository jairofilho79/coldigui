import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../auth/data/auth_remote_datasource.dart';
import '../../domain/entities/material_kind_prefs.dart';

/// `409` do PUT: o Worker tem um documento mais novo — o chamador o adota.
class MaterialKindPrefsConflict implements Exception {
  MaterialKindPrefsConflict(this.remote);

  final MaterialKindPrefs remote;

  @override
  String toString() => 'MaterialKindPrefsConflict(${remote.updatedAt})';
}

/// `GET`/`PUT /api/material-kind-prefs` com Bearer do `id_token`.
class MaterialKindPrefsRemoteDatasource {
  MaterialKindPrefsRemoteDatasource(this._dio);

  final Dio _dio;

  Options _auth(String idToken) => Options(
    headers: {'Authorization': 'Bearer $idToken'},
    // 401/403/409 são respostas do contrato, não falhas de transporte.
    validateStatus: (status) => status != null && status < 500,
  );

  /// `null` quando a conta nunca salvou (`204`).
  Future<MaterialKindPrefs?> fetch(String idToken) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.materialKindPrefs,
      options: _auth(idToken),
    );
    _throwIfUnauthorized(response.statusCode);
    if (response.statusCode == 204 || response.data == null) return null;
    if (response.statusCode != 200) {
      throw StateError('material_kind_prefs_fetch_${response.statusCode}');
    }
    return _parse(response.data!);
  }

  Future<MaterialKindPrefs> put({
    required String idToken,
    required MaterialKindPrefs prefs,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      ApiEndpoints.materialKindPrefs,
      data: {
        'kindIds': prefs.kindIds,
        'updatedAt': prefs.updatedAt.toUtc().toIso8601String(),
      },
      options: _auth(idToken),
    );
    _throwIfUnauthorized(response.statusCode);
    final data = response.data;
    if (response.statusCode == 409 && data != null) {
      throw MaterialKindPrefsConflict(_parse(data));
    }
    if (response.statusCode != 200 || data == null) {
      throw StateError('material_kind_prefs_put_${response.statusCode}');
    }
    return _parse(data);
  }

  void _throwIfUnauthorized(int? status) {
    if (status == 401 || status == 403) {
      throw AuthUnauthorizedException(status!);
    }
  }

  /// O documento do Worker nunca tem `pendingPush`: o que veio da nuvem já
  /// está lá.
  MaterialKindPrefs _parse(Map<String, dynamic> data) {
    final parsed = MaterialKindPrefs.fromJson({
      'kindIds': data['kindIds'],
      'updatedAt': data['updatedAt'],
      'pendingPush': false,
    });
    if (parsed == null) {
      debugPrint('[material-kind-prefs] documento remoto ilegível: $data');
      throw const FormatException('material_kind_prefs_invalid');
    }
    return parsed;
  }
}

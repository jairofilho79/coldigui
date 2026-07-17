import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../domain/entities/remote_audio_flag.dart';

/// CRUD remoto de audio flags autenticados.
class AudioFlagRemoteDatasource {
  AudioFlagRemoteDatasource(this._dio);

  final Dio _dio;

  Options _auth(String idToken) =>
      Options(headers: {'Authorization': 'Bearer $idToken'});

  Future<List<RemoteAudioFlag>> fetchAll(String idToken) async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.audioFlags,
      options: _auth(idToken),
    );
    final data = response.data ?? const [];
    return data
        .whereType<Map>()
        .map((e) => RemoteAudioFlag.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<RemoteAudioFlag> upsert({
    required String idToken,
    required RemoteAudioFlag flag,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      ApiEndpoints.audioFlag(flag.id),
      data: flag.toJson(),
      options: _auth(idToken),
    );
    final data = response.data;
    if (data == null) {
      throw StateError('Empty upsert response');
    }
    return RemoteAudioFlag.fromJson(data);
  }

  Future<void> softDelete({
    required String idToken,
    required String flagId,
  }) async {
    await _dio.delete<void>(
      ApiEndpoints.audioFlag(flagId),
      options: _auth(idToken),
    );
  }
}

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../domain/entities/remote_audio_flag.dart';

/// CRUD remoto de audio flags autenticados.
class AudioFlagRemoteDatasource {
  AudioFlagRemoteDatasource(this._dio);

  final Dio _dio;

  Options _auth(String idToken) =>
      Options(headers: {'Authorization': 'Bearer $idToken'});

  /// Lista os marcadores do usuário, **por item**.
  ///
  /// Um registro malformado (campo obrigatório ausente, `audioId` vazio,
  /// `positionMs` não numérico, data inválida) é descartado com log em vez de
  /// derrubar o pull inteiro — a mesma regra das playlists (spec A.7). Sem
  /// isso, a tolerância de [RemoteAudioFlag.fromJson] seria inalcançável: a
  /// exceção subiria por `fetchAll` e mataria pull, push e tombstones.
  Future<List<RemoteAudioFlag>> fetchAll(String idToken) async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.audioFlags,
      options: _auth(idToken),
    );
    final data = response.data ?? const [];
    final flags = <RemoteAudioFlag>[];
    for (final raw in data.whereType<Map>()) {
      try {
        flags.add(RemoteAudioFlag.fromJson(Map<String, dynamic>.from(raw)));
      } on FormatException catch (e) {
        debugPrint('[audio-flags] flag remota ignorada: $e');
      }
    }
    return List<RemoteAudioFlag>.unmodifiable(flags);
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

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../domain/entities/remote_audio_flag.dart';

/// CRUD remoto de audio flags autenticados.
class AudioFlagRemoteDatasource {
  AudioFlagRemoteDatasource(this._dio);

  final Dio _dio;

  Options _auth(String sessionToken) =>
      Options(headers: {'Authorization': 'Bearer $sessionToken'});

  /// Lista os marcadores do usuário, **por item**.
  ///
  /// Um registro malformado (campo obrigatório ausente, `audioId` vazio,
  /// `positionMs` não numérico, data inválida) é descartado com log em vez de
  /// derrubar o pull inteiro — a mesma regra das playlists (spec A.7). Sem
  /// isso, a tolerância de [RemoteAudioFlag.fromJson] seria inalcançável: a
  /// exceção subiria por `fetchAll` e mataria pull, push e tombstones.
  ///
  /// `includeDeleted=1` traz também os tombstones do servidor: sem eles o
  /// cliente teria de deduzir exclusão por ausência, e um pull parcial apagaria
  /// marcador vivo (spec A.2). Um Worker que ignore o parâmetro devolve só as
  /// linhas vivas — que é o comportamento de antes.
  Future<List<RemoteAudioFlag>> fetchAll(String sessionToken) async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.audioFlags,
      queryParameters: {'includeDeleted': '1'},
      options: _auth(sessionToken),
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

  /// `PUT` do marcador.
  ///
  /// `409` (a linha do servidor é mais nova que a `updatedAt` enviada) vira
  /// [AudioFlagConflictException] com a linha remota do corpo — o caso de uso
  /// resolve por last-write-wins. Um 409 sem corpo legível continua sendo a
  /// [DioException] original.
  Future<RemoteAudioFlag> upsert({
    required String sessionToken,
    required RemoteAudioFlag flag,
  }) async {
    final Response<Map<String, dynamic>> response;
    try {
      response = await _dio.put<Map<String, dynamic>>(
        ApiEndpoints.audioFlag(flag.id),
        data: flag.toJson(),
        options: _auth(sessionToken),
      );
    } on DioException catch (e) {
      final conflict = _conflictFrom(e);
      if (conflict != null) throw conflict;
      rethrow;
    }
    final data = response.data;
    if (data == null) {
      throw StateError('Empty upsert response');
    }
    return RemoteAudioFlag.fromJson(data);
  }

  /// Corpo do 409 como [AudioFlagConflictException]; `null` se não for um 409
  /// com um marcador legível dentro.
  AudioFlagConflictException? _conflictFrom(DioException error) {
    if (error.response?.statusCode != 409) return null;
    final body = error.response?.data;
    if (body is! Map) return null;
    try {
      return AudioFlagConflictException(
        RemoteAudioFlag.fromJson(Map<String, dynamic>.from(body)),
      );
    } on FormatException catch (e) {
      debugPrint('[audio-flags] corpo do 409 ilegível: $e');
      return null;
    }
  }

  Future<void> softDelete({
    required String sessionToken,
    required String flagId,
  }) async {
    await _dio.delete<void>(
      ApiEndpoints.audioFlag(flagId),
      options: _auth(sessionToken),
    );
  }
}

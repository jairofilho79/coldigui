import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../domain/entities/remote_playlist.dart';

/// CRUD remoto de playlists autenticadas (UC-15).
class PlaylistRemoteDatasource {
  PlaylistRemoteDatasource(this._dio);

  final Dio _dio;

  Options _auth(String idToken) =>
      Options(headers: {'Authorization': 'Bearer $idToken'});

  /// Lista as playlists do usuário, **por item**.
  ///
  /// Um registro malformado (campo obrigatório ausente, data inválida, `items`
  /// com forma inesperada) é descartado com log em vez de derrubar o pull
  /// inteiro: uma linha ruim no D1 não pode custar todas as outras (spec A.7).
  ///
  /// `includeDeleted=1` traz também os tombstones (`deletedAt` não-nulo), para
  /// o sync apagar aqui o que sumiu em outro aparelho (spec A.2). Um Worker que
  /// ainda não conhece o parâmetro simplesmente o ignora e devolve só as vivas.
  Future<List<RemotePlaylist>> fetchAll(String idToken) async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.playlists,
      queryParameters: {'includeDeleted': '1'},
      options: _auth(idToken),
    );
    final data = response.data ?? const [];
    final playlists = <RemotePlaylist>[];
    for (final raw in data.whereType<Map>()) {
      try {
        playlists.add(RemotePlaylist.fromJson(Map<String, Object?>.from(raw)));
      } on FormatException catch (e) {
        debugPrint('[playlists] registro remoto ignorado: $e');
      }
    }
    return List<RemotePlaylist>.unmodifiable(playlists);
  }

  /// `PUT` da playlist.
  ///
  /// `409` (a linha do servidor é mais nova que a `updatedAt` enviada) vira
  /// [PlaylistConflictException] com a linha remota do corpo — o caso de uso
  /// resolve por last-write-wins. Um 409 sem corpo legível continua sendo a
  /// [DioException] original.
  Future<RemotePlaylist> upsert({
    required String idToken,
    required RemotePlaylist playlist,
  }) async {
    final Response<Map<String, dynamic>> response;
    try {
      response = await _dio.put<Map<String, dynamic>>(
        ApiEndpoints.playlist(playlist.id),
        data: playlist.toJson(),
        options: _auth(idToken),
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
    return RemotePlaylist.fromJson(data);
  }

  /// Corpo do 409 como [PlaylistConflictException]; `null` se não for um 409
  /// com uma playlist legível dentro.
  PlaylistConflictException? _conflictFrom(DioException error) {
    if (error.response?.statusCode != 409) return null;
    final body = error.response?.data;
    if (body is! Map) return null;
    try {
      return PlaylistConflictException(
        RemotePlaylist.fromJson(Map<String, Object?>.from(body)),
      );
    } on FormatException catch (e) {
      debugPrint('[playlists] corpo do 409 ilegível: $e');
      return null;
    }
  }

  Future<void> softDelete({
    required String idToken,
    required String playlistId,
  }) async {
    await _dio.delete<void>(
      ApiEndpoints.playlist(playlistId),
      options: _auth(idToken),
    );
  }
}

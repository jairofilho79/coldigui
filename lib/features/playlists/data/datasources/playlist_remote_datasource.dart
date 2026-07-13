import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../domain/entities/remote_playlist.dart';

/// CRUD remoto de playlists autenticadas (UC-15).
class PlaylistRemoteDatasource {
  PlaylistRemoteDatasource(this._dio);

  final Dio _dio;

  Options _auth(String idToken) =>
      Options(headers: {'Authorization': 'Bearer $idToken'});

  Future<List<RemotePlaylist>> fetchAll(String idToken) async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.playlists,
      options: _auth(idToken),
    );
    final data = response.data ?? const [];
    return data
        .whereType<Map>()
        .map((e) => RemotePlaylist.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<RemotePlaylist> upsert({
    required String idToken,
    required RemotePlaylist playlist,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      ApiEndpoints.playlist(playlist.id),
      data: playlist.toJson(),
      options: _auth(idToken),
    );
    final data = response.data;
    if (data == null) {
      throw StateError('Empty upsert response');
    }
    return RemotePlaylist.fromJson(data);
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

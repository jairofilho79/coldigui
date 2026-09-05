import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/public_playlist.dart';
import '../../domain/entities/social_user.dart';

/// Endpoints autenticados de descoberta social.
class SocialRemoteDatasource {
  SocialRemoteDatasource(this._dio);

  final Dio _dio;

  static final _log = AppLogger.of('social');

  Options _auth(String idToken) =>
      Options(headers: {'Authorization': 'Bearer $idToken'});

  Future<List<SocialUser>> searchUsers({
    required String idToken,
    required String query,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.socialUsers,
      queryParameters: {'q': query},
      options: _auth(idToken),
    );
    final data = response.data ?? const [];
    return data
        .whereType<Map>()
        .map((e) => SocialUser.fromJson(Map<String, dynamic>.from(e)))
        .where((u) => u.username.isNotEmpty)
        .toList(growable: false);
  }

  /// Lista as playlists públicas de [username], **por item**.
  ///
  /// Um registro malformado (`id` ausente/inválido, `items` com forma
  /// inesperada) é descartado com log em vez de derrubar a página inteira —
  /// mesma tolerância do pull autenticado (spec A.7).
  Future<List<PublicPlaylist>> fetchUserPlaylists({
    required String idToken,
    required String username,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.socialUserPlaylists(username),
      options: _auth(idToken),
    );
    final data = response.data ?? const [];
    final playlists = <PublicPlaylist>[];
    for (final raw in data.whereType<Map>()) {
      try {
        playlists.add(PublicPlaylist.fromJson(Map<String, dynamic>.from(raw)));
      } on FormatException catch (e) {
        _log.warn('registro remoto ignorado', e);
      }
    }
    return List<PublicPlaylist>.unmodifiable(playlists);
  }
}

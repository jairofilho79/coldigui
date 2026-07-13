import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../domain/entities/public_playlist.dart';
import '../../domain/entities/social_user.dart';

/// Endpoints autenticados de descoberta social.
class SocialRemoteDatasource {
  SocialRemoteDatasource(this._dio);

  final Dio _dio;

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

  Future<List<PublicPlaylist>> fetchUserPlaylists({
    required String idToken,
    required String username,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.socialUserPlaylists(username),
      options: _auth(idToken),
    );
    final data = response.data ?? const [];
    return data
        .whereType<Map>()
        .map((e) => PublicPlaylist.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }
}

import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';

/// Sala «ao vivo» do usuário — devolvida por
/// [LiveRoomRemoteDatasource.ensureRoom]/[LiveRoomRemoteDatasource.regenerate].
final class LiveRoomInfo {
  const LiveRoomInfo({
    required this.code,
    required this.url,
    required this.ownerName,
  });
  final String code;
  final String url;
  final String ownerName;

  static LiveRoomInfo fromJson(Map<String, dynamic> json) => LiveRoomInfo(
    code: json['code'] as String,
    url: json['url'] as String,
    ownerName: json['ownerName'] as String? ?? '',
  );
}

/// `POST /api/live/room[/regenerate]` no Worker `plpcg-catalog`.
class LiveRoomRemoteDatasource {
  LiveRoomRemoteDatasource(this._dio, {required this.sessionToken});

  final Dio _dio;

  /// Token de sessão corrente; `null` = deslogado → [StateError].
  final String? Function() sessionToken;

  Future<LiveRoomInfo> ensureRoom() => _post(ApiEndpoints.liveRoom);

  Future<LiveRoomInfo> regenerate() => _post(ApiEndpoints.liveRoomRegenerate);

  Future<LiveRoomInfo> _post(String path) async {
    final token = sessionToken();
    if (token == null || token.isEmpty) throw StateError('unauthenticated');
    final response = await _dio.post<Map<String, dynamic>>(
      path,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return LiveRoomInfo.fromJson(response.data!);
  }
}

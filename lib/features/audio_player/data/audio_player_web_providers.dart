import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio_media_session.dart';
import 'web_audio_source_resolver.dart';

Future<List<int>> _fetchAudioBytes(String url, {String? fallbackUrl}) async {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 2),
    ),
  );
  try {
    try {
      return await _getBytes(dio, url);
    } on Object {
      if (fallbackUrl == null || fallbackUrl == url) rethrow;
      return await _getBytes(dio, fallbackUrl);
    }
  } finally {
    dio.close();
  }
}

Future<List<int>> _getBytes(Dio dio, String url) async {
  final response = await dio.get<List<int>>(
    url,
    options: Options(responseType: ResponseType.bytes),
  );
  final data = response.data;
  if (data == null || data.isEmpty) {
    throw StateError('Resposta de áudio vazia');
  }
  return data;
}

final webAudioSourceResolverProvider = Provider<WebAudioSourceResolver>((ref) {
  final resolver = createWebAudioSourceResolver(
    fetchBytes: (url, {fallbackUrl}) =>
        _fetchAudioBytes(url, fallbackUrl: fallbackUrl),
  );
  ref.onDispose(resolver.revokeAll);
  return resolver;
});

final audioMediaSessionControllerProvider =
    Provider<AudioMediaSessionController>((ref) {
      final controller = createAudioMediaSessionController();
      ref.onDispose(controller.detach);
      return controller;
    });

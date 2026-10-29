import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio_media_session.dart';
import 'web_audio_source_resolver.dart';

final webAudioSourceResolverProvider = Provider<WebAudioSourceResolver>((ref) {
  final resolver = createWebAudioSourceResolver();
  ref.onDispose(resolver.revokeAll);
  return resolver;
});

final audioMediaSessionControllerProvider =
    Provider<AudioMediaSessionController>((ref) {
      final controller = createAudioMediaSessionController();
      ref.onDispose(controller.detach);
      return controller;
    });

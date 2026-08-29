import 'dart:js_interop';

import 'package:just_audio/just_audio.dart';
import 'package:web/web.dart';

/// CORS no `<audio>` e `play()` da faixa escolhida ainda no tap (iOS Safari).
///
/// Não usar WAV + [AudioPlayer.stop]: `stop()` destrói o elemento desbloqueado
/// e o índice vai a 0 (sempre o primeiro material).
Future<void> unlockWebAudioIfNeeded(
  AudioPlayer player, {
  String? immediateUrl,
}) async {
  await player.setWebCrossOrigin(WebCrossOrigin.anonymous);
  final url = immediateUrl;
  if (url == null || url.isEmpty) return;

  final nodes = document.querySelectorAll('audio');
  for (var i = 0; i < nodes.length; i++) {
    final node = nodes.item(i);
    if (node == null) continue;
    final el = node as HTMLAudioElement;
    el.crossOrigin = 'anonymous';
    if (el.src != url) {
      el.src = url;
    }
    el.play().toDart.then((_) => null, onError: (_) => null);
  }
}

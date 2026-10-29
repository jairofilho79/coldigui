import 'dart:js_interop';

import 'package:just_audio/just_audio.dart';
import 'package:web/web.dart';

/// CORS no `<audio>` e `play()` da faixa escolhida ainda no tap (iOS Safari).
///
/// `crossOrigin` é condicional (O7 fix round 1): a URL de rede (proxy
/// plpcg.com) precisa de `anonymous` pra Web Audio API não recusar o
/// elemento; um `blob:` (faixa já baixada, sem round-trip de CORS nenhum)
/// quebra a reprodução em Chrome/Safari se marcado `anonymous` — o chamador
/// passa `null` quando a faixa inicial já resolveu pra blob.
///
/// Não usar WAV + [AudioPlayer.stop]: `stop()` destrói o elemento desbloqueado
/// e o índice vai a 0 (sempre o primeiro material).
Future<void> unlockWebAudioIfNeeded(
  AudioPlayer player, {
  String? immediateUrl,
  WebCrossOrigin? crossOrigin = WebCrossOrigin.anonymous,
}) async {
  await player.setWebCrossOrigin(crossOrigin);
  final url = immediateUrl;
  if (url == null || url.isEmpty) return;

  final nodes = document.querySelectorAll('audio');
  for (var i = 0; i < nodes.length; i++) {
    final node = nodes.item(i);
    if (node == null) continue;
    final el = node as HTMLAudioElement;
    el.crossOrigin = crossOrigin == null ? null : 'anonymous';
    if (el.src != url) {
      el.src = url;
    }
    el.play().toDart.then((_) => null, onError: (_) => null);
  }
}

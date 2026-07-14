import 'package:flutter/foundation.dart';
import 'package:just_audio_background/just_audio_background.dart';

/// Inicializa [JustAudioBackground] em Android/iOS.
///
/// Na Web fica no-op — o navegador não garante segundo plano nem controles
/// de sistema equivalentes (ver `docs/features/AUDIO_BACKGROUND_CONTRACT.md`).
Future<void> ensureAudioBackgroundInitialized() async {
  if (kIsWeb) return;
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.plpcg.audio',
    androidNotificationChannelName: 'Áudio PLPCG',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
  );
}

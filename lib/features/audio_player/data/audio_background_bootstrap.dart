import 'package:flutter/foundation.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'audio_web_platform.dart';

/// Inicializa [JustAudioBackground] em Android/iOS.
///
/// Na Web registra [JustAudioPlugin] e fica no-op para background —
/// o navegador não garante segundo plano nem controles de sistema
/// equivalentes (ver `docs/features/AUDIO_BACKGROUND_CONTRACT.md`).
Future<void> ensureAudioBackgroundInitialized() async {
  ensureAudioWebPlatformRegistered();
  if (kIsWeb) return;
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.plpcg.audio',
    androidNotificationChannelName: 'Áudio PLPCG',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
  );
}

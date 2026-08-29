import 'package:just_audio/just_audio.dart';

/// No-op for native — unlock iOS Safari só na web.
Future<void> unlockWebAudioIfNeeded(
  AudioPlayer player, {
  String? immediateUrl,
}) async {}

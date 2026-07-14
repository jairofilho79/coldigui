import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:just_audio_web/just_audio_web.dart';

/// Garante [JustAudioPlugin] mesmo se o `web_plugin_registrant` gerado estiver
/// em cache sem o plugin (build WASM incremental).
void ensureAudioWebPlatformRegistered() {
  // ponytail: registrant stale omite just_audio_web → MissingPluginException
  JustAudioPlugin.registerWith(webPluginRegistrar);
}

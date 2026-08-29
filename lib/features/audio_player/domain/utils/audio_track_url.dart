import 'package:coldigui/core/constants/app_config.dart';
import 'package:coldigui/core/utils/coldigom_asset_url.dart';
import 'package:flutter/foundation.dart';

import '../entities/audio_track.dart';

/// Resolve URL HTTP para streaming / fetch de [AudioTrack.r2Key].
abstract final class AudioTrackUrl {
  /// URL direta (Coldigom ou PLPCG) — fallback streaming e builds nativos.
  static String fromTrack(AudioTrack track) => directUrlForKey(track.r2Key);

  /// URL usada para fetch na web — proxy same-policy em plpcg.com quando disponível.
  static String fetchUrlForTrack(AudioTrack track) {
    if (!kIsWeb) return fromTrack(track);
    return fetchUrlForKey(track.r2Key, apiBase: AppConfig.apiBaseUrl);
  }

  /// Monta URL de fetch via proxy — testável sem [kIsWeb].
  static String fetchUrlForKey(String r2Key, {required String apiBase}) {
    return ColdigomAssetUrl.fetchUrlForKey(r2Key, apiBase: apiBase);
  }

  static String directUrlForKey(String r2Key) {
    return ColdigomAssetUrl.directUrlForKey(r2Key);
  }
}

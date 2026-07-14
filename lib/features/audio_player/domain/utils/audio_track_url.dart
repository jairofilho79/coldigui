import 'package:coldigui/core/utils/asset_base_url_resolver.dart';

import '../entities/audio_track.dart';

/// Resolve URL HTTP streaming a partir de [AudioTrack.r2Key].
abstract final class AudioTrackUrl {
  static String fromTrack(AudioTrack track) {
    final key = track.r2Key.trim();
    if (key.startsWith('http://') || key.startsWith('https://')) {
      return key;
    }
    return AssetBaseUrlResolver.joinAssetUrl(key);
  }
}

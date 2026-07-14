import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../domain/entities/playlist_media_face.dart';

const _prefsKey = 'playlist_media_face';

/// Face global da playlist (PDF ou Áudio). Persistida em SharedPreferences.
final playlistMediaFaceProvider =
    NotifierProvider<PlaylistMediaFaceNotifier, PlaylistMediaFace>(
      PlaylistMediaFaceNotifier.new,
    );

class PlaylistMediaFaceNotifier extends Notifier<PlaylistMediaFace> {
  @override
  PlaylistMediaFace build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(_prefsKey);
    if (raw == PlaylistMediaFace.audio.name) {
      return PlaylistMediaFace.audio;
    }
    return PlaylistMediaFace.pdf;
  }

  Future<void> setFace(PlaylistMediaFace face) async {
    state = face;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_prefsKey, face.name);
  }

  Future<void> toggle() async {
    await setFace(
      state == PlaylistMediaFace.pdf
          ? PlaylistMediaFace.audio
          : PlaylistMediaFace.pdf,
    );
  }
}

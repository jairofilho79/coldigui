import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import 'playlist_session_prefs.dart';

/// ID da playlist ativa no leitor/carousel (UC-06, Fase 4.8).
///
/// Persistido em SharedPreferences — define qual lista o carousel espelha.
class ActivePlaylistNotifier extends Notifier<String?> {
  @override
  String? build() {
    final raw = ref
        .watch(sharedPreferencesProvider)
        .getString(kActivePlaylistIdPrefsKey);
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  void set(String? playlistId) {
    state = playlistId;
    unawaited(_persist(playlistId));
  }

  void clear() => set(null);

  Future<void> _persist(String? playlistId) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (playlistId == null || playlistId.isEmpty) {
      await prefs.remove(kActivePlaylistIdPrefsKey);
    } else {
      await prefs.setString(kActivePlaylistIdPrefsKey, playlistId);
    }
  }
}

/// Playlist em uso no leitor — mutações do carousel sincronizam seus [pdfIds].
final activePlaylistIdProvider =
    NotifierProvider<ActivePlaylistNotifier, String?>(
      ActivePlaylistNotifier.new,
    );

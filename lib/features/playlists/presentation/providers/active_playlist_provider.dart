import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../domain/entities/saved_playlist.dart';
import 'playlist_session_prefs.dart';
import 'playlists_provider.dart';

/// ID da playlist ativa (UC-06, Fase 4.8).
///
/// Persistido em SharedPreferences — é a única coisa que a sessão guarda sobre
/// a seleção; o conteúdo vive em `SavedPlaylist.entries` da lista apontada.
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

/// Playlist em uso — a seleção do app inteiro (carousel, leitor, player).
final activePlaylistIdProvider =
    NotifierProvider<ActivePlaylistNotifier, String?>(
      ActivePlaylistNotifier.new,
    );

/// A lista ativa resolvida — `null` quando não há id ou ele aponta pra nada.
///
/// Resolve [activePlaylistIdProvider] contra o estado de [playlistsProvider]
/// (que é recarregado a cada mutação), para que a seleção derivada não precise
/// de nenhuma leitura de Isar por rebuild.
final activePlaylistProvider = Provider<SavedPlaylist?>((ref) {
  final activeId = ref.watch(activePlaylistIdProvider);
  if (activeId == null) return null;
  final items = ref.watch(playlistsProvider);
  for (final item in items) {
    if (item.playlist.playlistId == activeId) return item.playlist;
  }
  return null;
});

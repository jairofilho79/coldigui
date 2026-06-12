import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/playlist_tab.dart';

/// Estado de UI da tela Listas — aba ativa e scroll pós-transição.
class PlaylistsUiState {
  const PlaylistsUiState({
    this.tab = PlaylistTab.unsaved,
    this.scrollToPlaylistId,
  });

  /// Aba visível na [PlaylistsScreen].
  final PlaylistTab tab;

  /// Após salvar/favoritar, scroll até este [SavedPlaylist.playlistId].
  final String? scrollToPlaylistId;

  PlaylistsUiState copyWith({
    PlaylistTab? tab,
    String? scrollToPlaylistId,
    bool clearScrollTarget = false,
  }) {
    return PlaylistsUiState(
      tab: tab ?? this.tab,
      scrollToPlaylistId: clearScrollTarget
          ? null
          : (scrollToPlaylistId ?? this.scrollToPlaylistId),
    );
  }
}

/// Controla aba e scroll da [PlaylistsScreen] (Fase 4.8).
class PlaylistsUiNotifier extends Notifier<PlaylistsUiState> {
  @override
  PlaylistsUiState build() => const PlaylistsUiState();

  /// Troca aba e opcionalmente agenda scroll até [scrollToPlaylistId].
  void selectTab(PlaylistTab tab, {String? scrollToPlaylistId}) {
    state = PlaylistsUiState(
      tab: tab,
      scrollToPlaylistId: scrollToPlaylistId,
    );
  }

  void clearScrollTarget() {
    state = state.copyWith(clearScrollTarget: true);
  }
}

final playlistsUiProvider =
    NotifierProvider<PlaylistsUiNotifier, PlaylistsUiState>(
  PlaylistsUiNotifier.new,
);

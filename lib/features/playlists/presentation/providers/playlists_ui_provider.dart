import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/playlist_tab.dart';

/// Estado de UI da tela Listas — aba ativa e scroll pós-transição.
class PlaylistsUiState {
  const PlaylistsUiState({
    this.tab = PlaylistTab.unsaved,
    this.scrollToPlaylistId,
    this.expandPlaylistId,
  });

  /// Aba visível na [PlaylistsScreen].
  final PlaylistTab tab;

  /// Após salvar/favoritar, scroll até este [SavedPlaylist.playlistId].
  final String? scrollToPlaylistId;

  /// Expande o tile desta playlist ao navegar da barra do carousel.
  final String? expandPlaylistId;

  PlaylistsUiState copyWith({
    PlaylistTab? tab,
    String? scrollToPlaylistId,
    String? expandPlaylistId,
    bool clearScrollTarget = false,
    bool clearExpandTarget = false,
  }) {
    return PlaylistsUiState(
      tab: tab ?? this.tab,
      scrollToPlaylistId: clearScrollTarget
          ? null
          : (scrollToPlaylistId ?? this.scrollToPlaylistId),
      expandPlaylistId: clearExpandTarget
          ? null
          : (expandPlaylistId ?? this.expandPlaylistId),
    );
  }
}

/// Controla aba e scroll da [PlaylistsScreen] (Fase 4.8).
class PlaylistsUiNotifier extends Notifier<PlaylistsUiState> {
  @override
  PlaylistsUiState build() => const PlaylistsUiState();

  /// Troca aba e opcionalmente agenda scroll até [scrollToPlaylistId].
  void selectTab(PlaylistTab tab, {String? scrollToPlaylistId}) {
    state = PlaylistsUiState(tab: tab, scrollToPlaylistId: scrollToPlaylistId);
  }

  /// Aba correta, scroll e expansão da playlist ativa (barra do carousel).
  void focusPlaylist(PlaylistTab tab, String playlistId) {
    state = PlaylistsUiState(
      tab: tab,
      scrollToPlaylistId: playlistId,
      expandPlaylistId: playlistId,
    );
  }

  void clearScrollTarget() {
    state = state.copyWith(clearScrollTarget: true, clearExpandTarget: true);
  }
}

final playlistsUiProvider =
    NotifierProvider<PlaylistsUiNotifier, PlaylistsUiState>(
      PlaylistsUiNotifier.new,
    );

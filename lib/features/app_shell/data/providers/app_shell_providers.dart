import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../playlists/data/providers/playlist_providers.dart';
import '../../domain/usecases/sync_deep_link_state.dart';

/// DI — cliente [AppLinks] para deep links nativos (UC-14, Fase 4.5).
///
/// Consumido por [DeepLinkListener] para `getInitialLink` e `uriLinkStream`.
final appLinksProvider = Provider<AppLinks>((ref) => AppLinks());

/// DI — [SyncDeepLinkState] via [importSharedPlaylistFromUrlProvider].
final syncDeepLinkStateProvider = Provider<SyncDeepLinkState>((ref) {
  return SyncDeepLinkState(ref.watch(importSharedPlaylistFromUrlProvider));
});

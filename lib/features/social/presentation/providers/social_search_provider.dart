import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../data/providers/social_providers.dart';
import '../../domain/entities/public_playlist.dart';
import '../../domain/entities/social_user.dart';

/// Texto imediato digitado na busca social.
final socialSearchRawQueryProvider = StateProvider<String>((ref) => '');

/// Query debounced 300ms.
final socialSearchDebouncedQueryProvider =
    NotifierProvider<SocialSearchDebouncer, String>(SocialSearchDebouncer.new);

class SocialSearchDebouncer extends Notifier<String> {
  Timer? _timer;

  @override
  String build() {
    ref.onDispose(() => _timer?.cancel());
    ref.listen(socialSearchRawQueryProvider, (_, next) {
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 300), () {
        state = _normalizeSocialQuery(next);
      });
    });
    return _normalizeSocialQuery(ref.read(socialSearchRawQueryProvider));
  }
}

String _normalizeSocialQuery(String raw) {
  var q = raw.trim().toLowerCase();
  while (q.startsWith('@')) {
    q = q.substring(1);
  }
  return q;
}

/// Resultados da busca social (auth obrigatória).
final socialSearchResultsProvider =
    FutureProvider.autoDispose<List<SocialUser>>((ref) async {
      final query = ref.watch(socialSearchDebouncedQueryProvider);
      if (query.isEmpty) return const [];

      final user = ref.watch(authStateProvider).asData?.value;
      if (user == null) {
        throw StateError('not_authenticated');
      }

      return ref
          .read(socialRemoteDatasourceProvider)
          .searchUsers(idToken: user.idToken, query: query);
    });

/// Listas públicas de um username (lazy ao expandir).
final socialUserPlaylistsProvider = FutureProvider.autoDispose
    .family<List<PublicPlaylist>, String>((ref, username) async {
      final user = ref.watch(authStateProvider).asData?.value;
      if (user == null) {
        throw StateError('not_authenticated');
      }
      return ref
          .read(socialRemoteDatasourceProvider)
          .fetchUserPlaylists(idToken: user.idToken, username: username);
    });

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ID da playlist ativa no leitor/carousel (UC-06, Fase 4.8).
///
/// Mantido em memória — define qual lista o carousel espelha.
class ActivePlaylistNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? playlistId) => state = playlistId;

  void clear() => state = null;
}

/// Playlist em uso no leitor — mutações do carousel sincronizam seus [pdfIds].
final activePlaylistIdProvider =
    NotifierProvider<ActivePlaylistNotifier, String?>(
  ActivePlaylistNotifier.new,
);

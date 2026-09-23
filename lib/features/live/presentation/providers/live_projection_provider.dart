import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../playlists/domain/entities/playlist_entry.dart';

/// A lista do gestor, como o consumidor a vê (spec D4: projeção read-only).
///
/// Holder sem lógica: quem escreve é o `LiveSessionController`; quem lê é
/// `activeEntriesProvider`, que a prefere sobre a lista ativa local enquanto
/// não for `null`. Nada disto toca o Isar — ao sair, a lista local volta
/// intacta.
final class LiveProjection {
  LiveProjection({
    required this.ownerName,
    required this.playlistId,
    required this.name,
    required List<PlaylistEntry> entries,
  }) : entries = List<PlaylistEntry>.unmodifiable(entries);

  final String ownerName;
  final String playlistId;
  final String name;
  final List<PlaylistEntry> entries;
}

class LiveProjectionNotifier extends Notifier<LiveProjection?> {
  @override
  LiveProjection? build() => null;

  void set(LiveProjection? projection) => state = projection;

  void clear() => state = null;
}

final liveProjectionProvider =
    NotifierProvider<LiveProjectionNotifier, LiveProjection?>(
      LiveProjectionNotifier.new,
    );

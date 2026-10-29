import '../../../playlists/domain/entities/playlist_entry.dart';

export '../../../playlists/domain/entities/playlist_entry.dart';

/// Estado da sala no DO (spec 2026-09-12-lista-ao-vivo, D8). `scheduled` só
/// existe a partir da Fase 2; `retired` é a sala cujo link foi regenerado.
enum LiveRoomStatus { idle, scheduled, live, ended, retired }

LiveRoomStatus? liveRoomStatusFromWire(Object? raw) {
  if (raw is! String) return null;
  for (final status in LiveRoomStatus.values) {
    if (status.name == raw) return status;
  }
  return null;
}

enum LiveRole { leader, consumer }

enum LiveEndReason { leader, inactivity, replaced, expired, retired }

/// A lista do gestor como o DO a guarda: inteira, tipada, com o foco por
/// **chave de ocorrência** (`entryKeyFor`) — a mesma que a lista ativa usa.
final class LiveSnapshot {
  LiveSnapshot({
    required this.playlistId,
    required this.name,
    required List<PlaylistEntry> entries,
    required this.focusKey,
  }) : entries = List<PlaylistEntry>.unmodifiable(entries);

  final String playlistId;
  final String name;
  final List<PlaylistEntry> entries;
  final String? focusKey;

  Map<String, Object?> toJson() => {
    'playlistId': playlistId,
    'name': name,
    'entries': [for (final e in entries) e.toJson()],
    'focusKey': focusKey,
  };

  /// Lança [FormatException] se faltar `playlistId`/`entries`.
  static LiveSnapshot fromJson(Map<String, Object?> json) {
    final playlistId = json['playlistId'];
    final entries = json['entries'];
    if (playlistId is! String || entries is! List) {
      throw FormatException('LiveSnapshot inválido: $json');
    }
    return LiveSnapshot(
      playlistId: playlistId,
      name: json['name'] as String? ?? '',
      entries: [
        for (final raw in entries) PlaylistEntry.fromJson(raw as Object),
      ],
      focusKey: json['focusKey'] as String?,
    );
  }

  LiveSnapshot copyWith({
    List<PlaylistEntry>? entries,
    String? focusKey,
    bool clearFocus = false,
  }) => LiveSnapshot(
    playlistId: playlistId,
    name: name,
    entries: entries ?? this.entries,
    focusKey: clearFocus ? null : (focusKey ?? this.focusKey),
  );
}

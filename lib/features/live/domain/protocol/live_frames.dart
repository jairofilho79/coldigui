import 'dart:convert';

import '../entities/live_snapshot.dart';

/// Frames DO → cliente (spec §5, Fase 1). Todo frame leva [room]; o controller
/// descarta os de sala diferente da atual.
sealed class LiveServerFrame {
  const LiveServerFrame(this.room);
  final String room;
}

final class LiveRoomFrame extends LiveServerFrame {
  const LiveRoomFrame(
    super.room, {
    required this.status,
    required this.ownerName,
    required this.role,
    required this.version,
    required this.snapshot,
    required this.leaderPresent,
    required this.viewers,
  });
  final LiveRoomStatus status;
  final String ownerName;
  final LiveRole role;
  final int version;
  final LiveSnapshot? snapshot;
  final bool leaderPresent;
  final int viewers;
}

final class LiveSnapshotFrame extends LiveServerFrame {
  const LiveSnapshotFrame(
    super.room, {
    required this.version,
    required this.snapshot,
    required this.viewers,
  });
  final int version;
  final LiveSnapshot snapshot;
  final int viewers;
}

final class LivePresenceFrame extends LiveServerFrame {
  const LivePresenceFrame(
    super.room, {
    required this.leaderPresent,
    required this.viewers,
  });
  final bool leaderPresent;
  final int viewers;
}

final class LiveAckFrame extends LiveServerFrame {
  const LiveAckFrame(
    super.room, {
    required this.version,
    required this.viewers,
  });
  final int version;
  final int viewers;
}

final class LiveEndedFrame extends LiveServerFrame {
  const LiveEndedFrame(super.room, {required this.reason});
  final LiveEndReason reason;
}

final class LiveErrorFrame extends LiveServerFrame {
  const LiveErrorFrame(super.room, {required this.code});

  /// `bad_frame | not_leader | not_live | too_large | not_found | unauthorized`.
  final String code;
}

/// `null` para qualquer coisa que não seja um frame conhecido e bem formado —
/// inclusive o `pong` do ping de prova de vida.
LiveServerFrame? decodeLiveServerFrame(String text) {
  Object? raw;
  try {
    raw = jsonDecode(text);
  } on FormatException {
    return null;
  }
  if (raw is! Map<String, Object?>) return null;
  final room = raw['room'];
  if (room is! String) return null;
  try {
    switch (raw['t']) {
      case 'room':
        final status = liveRoomStatusFromWire(raw['status']);
        final role = raw['role'] == 'leader'
            ? LiveRole.leader
            : raw['role'] == 'consumer'
            ? LiveRole.consumer
            : null;
        if (status == null || role == null) return null;
        final snapshotRaw = raw['snapshot'];
        return LiveRoomFrame(
          room,
          status: status,
          ownerName: raw['ownerName'] as String? ?? '',
          role: role,
          version: raw['version'] as int,
          snapshot: snapshotRaw is Map<String, Object?>
              ? LiveSnapshot.fromJson(snapshotRaw)
              : null,
          leaderPresent: raw['leaderPresent'] == true,
          viewers: raw['viewers'] as int? ?? 0,
        );
      case 'snapshot':
        return LiveSnapshotFrame(
          room,
          version: raw['version'] as int,
          snapshot: LiveSnapshot.fromJson(
            raw['snapshot'] as Map<String, Object?>,
          ),
          viewers: raw['viewers'] as int? ?? 0,
        );
      case 'presence':
        return LivePresenceFrame(
          room,
          leaderPresent: raw['leaderPresent'] == true,
          viewers: raw['viewers'] as int? ?? 0,
        );
      case 'ack':
        return LiveAckFrame(
          room,
          version: raw['version'] as int,
          viewers: raw['viewers'] as int? ?? 0,
        );
      case 'ended':
        // `raw` (mutável, capturada) não fica promovida a Map dentro do
        // closure — extrai o valor antes de comparar.
        final reasonName = raw['reason'];
        final reason = LiveEndReason.values
            .where((r) => r.name == reasonName)
            .firstOrNull;
        return reason == null ? null : LiveEndedFrame(room, reason: reason);
      case 'error':
        final code = raw['code'];
        return code is String ? LiveErrorFrame(room, code: code) : null;
      default:
        return null;
    }
  } on TypeError {
    return null;
  } on FormatException {
    return null;
  }
}

String encodeLiveHello({
  required String room,
  required int since,
  required String clientId,
  String? sessionToken,
}) => jsonEncode({
  't': 'hello',
  'room': room,
  'since': since,
  'clientId': clientId,
  if (sessionToken != null && sessionToken.isNotEmpty)
    'sessionToken': sessionToken,
});

String encodeLiveStart(LiveSnapshot snapshot) =>
    jsonEncode({'t': 'start', 'snapshot': snapshot.toJson()});

String encodeLiveSet(LiveSnapshot snapshot) =>
    jsonEncode({'t': 'set', 'snapshot': snapshot.toJson()});

String encodeLiveEnd() => jsonEncode({'t': 'end'});

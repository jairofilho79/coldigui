import 'dart:convert';

import 'package:coldigui/features/live/domain/entities/live_snapshot.dart';
import 'package:coldigui/features/live/domain/protocol/live_frames.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const snapshotJson = {
    'playlistId': 'p1',
    'name': 'Culto',
    'entries': [
      {'id': 'abc', 'kind': 'pdf'},
      {'id': 'abc', 'kind': 'pdf'},
      {'id': 'trk', 'kind': 'audio'},
    ],
    'focusKey': 'abc#1',
  };

  test('room frame decodifica status, papel, snapshot e presença', () {
    final frame = decodeLiveServerFrame(
      jsonEncode({
        't': 'room',
        'room': 'k7x2m9q',
        'status': 'live',
        'ownerName': 'Fulano',
        'role': 'consumer',
        'version': 4,
        'snapshot': snapshotJson,
        'leaderPresent': true,
        'viewers': 12,
      }),
    );
    expect(frame, isA<LiveRoomFrame>());
    final room = frame! as LiveRoomFrame;
    expect(room.room, 'k7x2m9q');
    expect(room.status, LiveRoomStatus.live);
    expect(room.role, LiveRole.consumer);
    expect(room.version, 4);
    expect(room.snapshot!.entries, [
      const PlaylistEntry(id: 'abc', kind: MaterialKind.pdf),
      const PlaylistEntry(id: 'abc', kind: MaterialKind.pdf),
      const PlaylistEntry(id: 'trk', kind: MaterialKind.audio),
    ]);
    expect(room.snapshot!.focusKey, 'abc#1');
    expect(room.leaderPresent, isTrue);
    expect(room.viewers, 12);
  });

  test('snapshot, presence, ack, ended e error decodificam', () {
    expect(
      decodeLiveServerFrame(
        jsonEncode({
          't': 'snapshot',
          'room': 'r',
          'version': 5,
          'snapshot': snapshotJson,
          'viewers': 3,
        }),
      ),
      isA<LiveSnapshotFrame>().having((f) => f.version, 'version', 5),
    );
    expect(
      decodeLiveServerFrame(
        jsonEncode({
          't': 'presence',
          'room': 'r',
          'leaderPresent': false,
          'viewers': 2,
        }),
      ),
      isA<LivePresenceFrame>().having(
        (f) => f.leaderPresent,
        'leaderPresent',
        false,
      ),
    );
    expect(
      decodeLiveServerFrame(
        jsonEncode({'t': 'ack', 'room': 'r', 'version': 6, 'viewers': 2}),
      ),
      isA<LiveAckFrame>().having((f) => f.version, 'version', 6),
    );
    expect(
      decodeLiveServerFrame(
        jsonEncode({'t': 'ended', 'room': 'r', 'reason': 'inactivity'}),
      ),
      isA<LiveEndedFrame>().having(
        (f) => f.reason,
        'reason',
        LiveEndReason.inactivity,
      ),
    );
    expect(
      decodeLiveServerFrame(
        jsonEncode({'t': 'error', 'room': 'r', 'code': 'not_leader'}),
      ),
      isA<LiveErrorFrame>().having((f) => f.code, 'code', 'not_leader'),
    );
  });

  test('frames malformados, sem room ou de tipo desconhecido viram null', () {
    expect(decodeLiveServerFrame('{'), isNull);
    expect(decodeLiveServerFrame('pong'), isNull);
    expect(
      decodeLiveServerFrame(jsonEncode({'t': 'ack', 'version': 1})),
      isNull,
    );
    expect(
      decodeLiveServerFrame(jsonEncode({'t': 'party', 'room': 'r'})),
      isNull,
    );
    expect(
      decodeLiveServerFrame(
        jsonEncode({'t': 'room', 'room': 'r', 'status': 'weird'}),
      ),
      isNull,
    );
  });

  test('encoders produzem o JSON que o DO valida', () {
    expect(
      jsonDecode(encodeLiveHello(room: 'k7x2m9q', since: 3, clientId: 'c1')),
      {'t': 'hello', 'room': 'k7x2m9q', 'since': 3, 'clientId': 'c1'},
    );
    expect(
      jsonDecode(
        encodeLiveHello(
          room: 'k7x2m9q',
          since: 0,
          clientId: 'c1',
          sessionToken: 'sess_x',
        ),
      ),
      {
        't': 'hello',
        'room': 'k7x2m9q',
        'since': 0,
        'clientId': 'c1',
        'sessionToken': 'sess_x',
      },
    );
    final snapshot = LiveSnapshot.fromJson(snapshotJson);
    expect(jsonDecode(encodeLiveStart(snapshot)), {
      't': 'start',
      'snapshot': snapshotJson,
    });
    expect(jsonDecode(encodeLiveSet(snapshot)), {
      't': 'set',
      'snapshot': snapshotJson,
    });
    expect(jsonDecode(encodeLiveEnd()), {'t': 'end'});
  });
}

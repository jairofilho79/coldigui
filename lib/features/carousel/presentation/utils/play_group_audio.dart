import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../audio_player/domain/entities/audio_track.dart';
import '../../../audio_player/domain/utils/find_material_for_group.dart';
import '../../../audio_player/presentation/utils/active_list_audio_queue.dart';
import '../../../audio_player/presentation/utils/open_audio_in_player.dart';

/// Toca a faixa preferida de [groupTracks] (D4/D10/D5).
///
/// Fila pela regra única de [queueForTrack]: quando a faixa preferida do
/// grupo já está na lista ativa, a fila é a lista inteira — tocar emenda no
/// próximo da reunião; senão, a fila é só o grupo.
Future<void> playGroupAudio(WidgetRef ref, List<AudioTrack> groupTracks) async {
  if (groupTracks.isEmpty) return;
  final target = findAudioForGroup(groupTracks.first.groupId, groupTracks);
  if (target == null) return;

  await playAudioInSession(
    ref: ref,
    track: target,
    queue: queueForTrack(
      track: target,
      groupTracks: groupTracks,
      activeQueue: activeListAudioQueue(ref),
    ),
  );
}

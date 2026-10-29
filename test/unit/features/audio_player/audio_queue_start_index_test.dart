import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/audio_player/presentation/utils/open_audio_in_player.dart';
import 'package:flutter_test/flutter_test.dart';

AudioTrack _track({required String audioId, required String categoria}) {
  return AudioTrack(
    audioId: audioId,
    r2Key: 'assets/praises/shekinah/$audioId.mp3',
    nome: 'Shekinah',
    numero: '042',
    groupId: 'shekinah',
    categoria: categoria,
    classificacao: 'Congregacional',
  );
}

void main() {
  final geral = _track(audioId: 'geral', categoria: 'MIDI Geral');
  final tenor = _track(audioId: 'tenor', categoria: 'MIDI Tenor I');
  final tracks = [geral, tenor];

  test('escolhe MIDI Tenor I pelo audioId, não o primeiro da fila', () {
    expect(audioQueueStartIndex(tracks: tracks, track: tenor), 1);
  });

  test('respeita startIndex quando a playlist já conhece a posição', () {
    expect(
      audioQueueStartIndex(tracks: tracks, track: tenor, startIndex: 1),
      1,
    );
  });

  test('currentIndexStream em 0 durante troca de fonte não troca a faixa', () {
    expect(
      resolveSessionQueueIndex(
        pendingIndex: 1,
        playerIndex: 0,
        applyingSources: true,
      ),
      1,
    );
  });

  test('depois da carga, o índice do player vale', () {
    expect(
      resolveSessionQueueIndex(
        pendingIndex: 1,
        playerIndex: 1,
        applyingSources: false,
      ),
      1,
    );
  });
}

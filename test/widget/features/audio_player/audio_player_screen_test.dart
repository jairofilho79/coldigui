import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/pages/audio_player_screen.dart';
import 'package:flutter_test/flutter_test.dart';

const _track = AudioTrack(
  audioId: 'aud-a',
  r2Key: 'assets/praises/a.mp3',
  nome: 'Primeira',
  numero: '001',
  groupId: 'g1',
  categoria: 'Áudio',
  classificacao: 'Coro',
);

void main() {
  group('audioPlayerCanAddFlag (C12)', () {
    test('com faixa em foco, tocando ou pausado, pode marcar', () {
      expect(audioPlayerCanAddFlag(_track), isTrue);
    });

    test('sem faixa em foco, não pode marcar', () {
      expect(audioPlayerCanAddFlag(null), isFalse);
    });
  });

  group('formatAudioSpeed (C12)', () {
    test('velocidade inteira não mostra vírgula', () {
      expect(formatAudioSpeed(1), '1');
    });

    test('velocidades fracionárias usam vírgula decimal', () {
      expect(formatAudioSpeed(0.75), '0,75');
      expect(formatAudioSpeed(1.25), '1,25');
      expect(formatAudioSpeed(1.5), '1,5');
    });
  });
}

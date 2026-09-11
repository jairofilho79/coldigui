import 'package:coldigui/features/audio_player/presentation/pages/audio_player_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

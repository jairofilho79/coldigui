import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/domain/utils/audio_track_url.dart';
import 'package:coldigui/features/coldigom/data/constants/coldigom_api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AudioTrackUrl monta URL coldigom a partir do r2Key', () {
    const track = AudioTrack(
      audioId: 'id',
      r2Key: 'assets/praises/p1/a.mp3',
      nome: 'Louvor',
      numero: '001',
      groupId: 'p1',
      categoria: 'Áudio',
      classificacao: 'Coletânea',
    );

    expect(
      AudioTrackUrl.fromTrack(track),
      '${ColdigomApiConfig.baseUrl}/assets/praises/p1/a.mp3',
    );
  });
}

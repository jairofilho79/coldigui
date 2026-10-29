import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/domain/utils/audio_media_artist.dart';
import 'package:flutter_test/flutter_test.dart';

AudioTrack _track({String author = '', String numero = ''}) => AudioTrack(
  audioId: 'a',
  r2Key: 'assets/praises/p1/audio.mp3',
  nome: 'Louvor',
  numero: numero,
  groupId: 'p1',
  categoria: 'Áudio',
  classificacao: 'Coro',
  author: author,
);

void main() {
  test('autor quando há', () {
    expect(audioMediaArtist(_track(author: 'Fulano', numero: '031')), 'Fulano');
  });

  test('sem autor: o número do louvor', () {
    expect(audioMediaArtist(_track(numero: '031')), '031');
  });

  test('sem autor nem número: a marca PLPCG', () {
    expect(audioMediaArtist(_track()), 'PLPCG');
  });
}

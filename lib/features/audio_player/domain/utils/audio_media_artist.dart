import '../entities/audio_track.dart';

/// Linha «artista» da notificação de áudio (media session nativa e web):
/// autor, senão número do louvor, senão a marca `PLPCG` (spec
/// fim-fonte-plpcg §3.2).
String audioMediaArtist(AudioTrack track) {
  if (track.author.isNotEmpty) return track.author;
  if (track.numero.isNotEmpty) return track.numero;
  return 'PLPCG';
}

import 'package:coldigui/features/chords/domain/entities/chordpro_song.dart';
import 'package:coldigui/features/chords/presentation/theme/chord_reader_theme.dart';
import 'package:coldigui/features/chords/presentation/widgets/chord_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('ChordHeader renderiza titulo, subtitulo, tom, ritmo e artista', (tester) async {
    const song = ChordProSong(
      title: 'Ainda há tempo',
      subtitle: '001',
      key: 'Dm',
      rhythm: 'Básico',
      artist: 'Autor',
    );

    await tester.pumpWidget(
      _host(
        const ChordHeader(
          song: song,
          semitones: 0,
          palette: ChordReaderPalette(
            background: Colors.white,
            lyric: Colors.black,
            chord: Colors.brown,
            bar: Colors.red,
            comment: Colors.grey,
            stripe: Colors.transparent,
          ),
        ),
      ),
    );

    expect(find.text('Ainda há tempo'), findsOneWidget);
    expect(find.text('001 · Dm · Básico · Autor'), findsOneWidget);
  });

  testWidgets('ChordHeader transpoe a chave no subtitulo', (tester) async {
    const song = ChordProSong(
      title: 'Ainda há tempo',
      key: 'Dm',
    );

    await tester.pumpWidget(
      _host(
        const ChordHeader(
          song: song,
          semitones: 2,
          palette: ChordReaderPalette(
            background: Colors.white,
            lyric: Colors.black,
            chord: Colors.brown,
            bar: Colors.red,
            comment: Colors.grey,
            stripe: Colors.transparent,
          ),
        ),
      ),
    );

    expect(find.text('Em'), findsOneWidget);
  });
}

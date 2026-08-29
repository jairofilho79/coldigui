import 'dart:async';

import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/entities/youtube_material.dart';
import 'package:coldigui/features/chords/data/providers/chord_providers.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:coldigui/features/chords/domain/entities/chordpro_song.dart';
import 'package:coldigui/features/chords/domain/usecases/parse_chordpro.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_material_sheet.dart';
import 'package:coldigui/features/coldigom/presentation/widgets/coldigom_material_sheet.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ChordMaterial _chord(String categoria, String key) {
  return ChordMaterial(
    chordId: 'chord-$categoria',
    r2Key: key,
    nome: 'Comigo habita',
    numero: '692',
    groupId: 'p1',
    categoria: categoria,
    classificacao: 'Cancao',
  );
}

LouvorGroup _group(List<ChordMaterial> chords) {
  return LouvorGroup(
    groupId: 'p1',
    numero: '692',
    nome: 'Comigo habita',
    sections: const [],
    chordMaterials: chords,
  );
}

Future<void> _pumpSheet(
  WidgetTester tester, {
  required LouvorGroup group,
  required Map<String, ChordProSong?> songs,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        chordSongProvider.overrideWith((ref, r2Key) async => songs[r2Key]),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Locale fixo: o default do flutter_test e ingles, e os asserts
        // abaixo esperam as strings em portugues.
        locale: const Locale('pt'),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showLouvorMaterialSheet(
                context: context,
                group: group,
                onMaterialSelected: (_) {},
                onChordSelected: (_) {},
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  final song = parseChordPro('{title: X}\n\nA [Bb]noite vem,\n');

  testWidgets('lista so as cifras disponiveis', (tester) async {
    await _pumpSheet(
      tester,
      group: _group([_chord('Cifra I', 'k1'), _chord('Cifra II', 'k2')]),
      songs: {'k1': song, 'k2': null},
    );

    expect(find.text('Cifras'), findsOneWidget);
    expect(find.text('Cifra I'), findsOneWidget);
    expect(find.text('Cifra II'), findsNothing);
  });

  testWidgets('esconde a secao quando nenhuma cifra esta disponivel',
      (tester) async {
    await _pumpSheet(
      tester,
      group: _group([_chord('Cifra I', 'k1')]),
      songs: {'k1': null},
    );

    expect(find.text('Cifras'), findsNothing);
  });

  testWidgets('esconde a secao quando o grupo nao tem cifra', (tester) async {
    await _pumpSheet(tester, group: _group(const []), songs: const {});

    expect(find.text('Cifras'), findsNothing);
  });

  testWidgets('sheet coldigom mostra a aba Cifras so quando ha disponivel',
      (tester) async {
    // Grupo coldigom com PDF + cifra: LouvorGroupCard manda grupos coldigom
    // para este sheet, e toda cifra e coldigom — entao esta e a aba que o
    // usuario realmente ve.
    final group = LouvorGroup(
      groupId: 'p1',
      numero: '692',
      nome: 'Comigo habita',
      sections: const [],
      chordMaterials: [_chord('Cifra I', 'k1'), _chord('Cifra II', 'k2')],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chordSongProvider.overrideWith(
            (ref, r2Key) async => r2Key == 'k1' ? song : null,
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showColdigomMaterialSheet(
                  context: context,
                  group: group,
                  onMaterialSelected: (_) {},
                  onChordSelected: (_) {},
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    // Uma aba so → sem segment bar; a lista de cifras aparece direto.
    expect(find.text('Cifra I'), findsOneWidget);
    expect(find.text('Cifra II'), findsNothing);
  });

  testWidgets('toque na cifra dispara onChordSelected', (tester) async {
    ChordMaterial? selected;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chordSongProvider.overrideWith((ref, r2Key) async => song),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showLouvorMaterialSheet(
                  context: context,
                  group: _group([_chord('Cifra', 'k1')]),
                  onMaterialSelected: (_) {},
                  onChordSelected: (c) => selected = c,
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cifra'));
    await tester.pumpAndSettle();

    expect(selected?.categoria, 'Cifra');
  });

  testWidgets(
    'aba selecionada nao muda de posicao quando a aba Cifras aparece depois',
    (tester) async {
      // Regressao: _selectedKindIndex guardava uma *posicao*. A aba Cifras
      // e inserida entre pdf e audio, renumerando as abas seguintes — quem
      // estava em "audio" (posicao 1) ou "youtube" (posicao 2) era jogado
      // para a aba vizinha quando a cifra resolvia depois do primeiro frame.
      final pdf = Louvor.fromManifest(
        nome: 'Comigo habita',
        numero: '692',
        categoria: 'Partitura',
        classificacao: 'Básico',
        pdf: 'a.pdf',
        pdfId: 'pdf1',
        groupId: 'p1',
        source: LouvorDataSource.coldigom,
      );
      const track = AudioTrack(
        audioId: 'audio1',
        r2Key: 'audio-key',
        nome: 'Comigo habita',
        numero: '692',
        groupId: 'p1',
        categoria: 'Áudio',
        classificacao: 'Básico',
      );
      const yt = YoutubeMaterial(
        id: 'yt1',
        url: 'https://www.youtube.com/watch?v=1Pks43ceAac',
        nome: 'Comigo habita',
        numero: '692',
        groupId: 'p1',
        categoria: 'Gestos CIAs',
        classificacao: 'Básico',
      );
      final group = LouvorGroup.fromLouvores(
        [pdf],
        audioTracks: const [track],
        youtubeMaterials: const [yt],
        chordMaterials: [_chord('Cifra I', 'k1')],
      ).first;

      final chordCompleter = Completer<ChordProSong?>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chordSongProvider.overrideWith(
              (ref, r2Key) => chordCompleter.future,
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => showColdigomMaterialSheet(
                    context: context,
                    group: group,
                    onMaterialSelected: (_) {},
                    onYoutubeSelected: (_) {},
                  ),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      // Cifra ainda nao resolveu: so 3 abas (PDF, Audio, YouTube).
      expect(find.text('Cifras'), findsNothing);

      await tester.tap(find.text('YouTube'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
        2, // [pdf, audio, youtube] — youtube na posicao 2
      );

      chordCompleter.complete(parseChordPro('{title: X}\n\nA [Bb]noite vem,\n'));
      await tester.pumpAndSettle();

      // Cifra apareceu entre PDF e Audio — a selecao deve seguir o kind
      // "youtube", nao a posicao antiga.
      expect(find.text('Cifras'), findsOneWidget);
      expect(
        tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
        3, // [pdf, chord, audio, youtube] — youtube agora na posicao 3
      );
    },
  );
}

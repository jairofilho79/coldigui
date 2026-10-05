import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/entities/material_kind_taxonomy.dart';
import 'package:coldigui/features/catalog/presentation/widgets/material_sheet.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/features/material_kind_prefs/presentation/providers/material_kind_prefs_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Louvor _pdf(String categoria, String pdfId, {String? kind}) =>
    Louvor.fromManifest(
      nome: 'Louvor de Teste',
      numero: '100',
      categoria: categoria,
      classificacao: 'Coletânea',
      pdf: '$pdfId.pdf',
      pdfId: pdfId,
      groupId: 'g100',
      materialKindId: kind,
    );

AudioTrack _audio(String categoria, String id, {String? kind}) => AudioTrack(
      audioId: id,
      r2Key: '$id.mp3',
      nome: 'Louvor de Teste',
      numero: '100',
      groupId: 'g100',
      categoria: categoria,
      classificacao: 'Coletânea',
      materialKindId: kind,
    );

final _taxonomy = MaterialKindTaxonomy(
  classes: const [
    MaterialKindClass(id: 'regencia', label: 'Regência e geral'),
    MaterialKindClass(id: 'vozes', label: 'Vozes'),
    MaterialKindClass(id: 'metais', label: 'Metais'),
    MaterialKindClass(id: 'audio', label: 'Áudio e acompanhamento'),
  ],
  kinds: const {
    'k-grade': MaterialKindTaxon(name: 'Grade', classId: 'regencia', order: 20),
    'k-partitura': MaterialKindTaxon(
      name: 'Partitura',
      classId: 'regencia',
      order: 10,
    ),
    'k-coro': MaterialKindTaxon(name: 'Coro', classId: 'vozes', order: 10),
    'k-soprano': MaterialKindTaxon(
      name: 'Voz soprano',
      classId: 'vozes',
      order: 20,
    ),
    'k-sax': MaterialKindTaxon(
      name: 'Saxofone alto',
      classId: 'metais',
      order: 30,
    ),
    'k-trompete': MaterialKindTaxon(
      name: 'Trompete',
      classId: 'metais',
      order: 40,
    ),
    'k-play': MaterialKindTaxon(
      name: 'Playback',
      classId: 'audio',
      order: 10,
    ),
    'k-audio-grupo': MaterialKindTaxon(
      name: 'Áudio (grupo)',
      classId: 'audio',
      order: 20,
    ),
  },
);

LouvorGroup _createGroup() => LouvorGroup(
      groupId: 'g100',
      numero: '100',
      nome: 'Louvor de Teste',
      sections: [
        LouvorMaterialSection(
          classificacao: 'Coletânea',
          displayLabel: 'Coletânea',
          materials: [
            LouvorMaterialEntry(
              categoria: 'Grade',
              pdfId: 'p1',
              louvor: _pdf('Grade', 'p1', kind: 'k-grade'),
            ),
            LouvorMaterialEntry(
              categoria: 'Partitura',
              pdfId: 'p2',
              louvor: _pdf('Partitura', 'p2', kind: 'k-partitura'),
            ),
            LouvorMaterialEntry(
              categoria: 'Trompete',
              pdfId: 'p3',
              louvor: _pdf('Trompete', 'p3', kind: 'k-trompete'),
            ),
            LouvorMaterialEntry(
              categoria: 'Saxofone alto',
              pdfId: 'p4',
              louvor: _pdf('Saxofone alto', 'p4', kind: 'k-sax'),
            ),
          ],
        ),
      ],
      audioTracks: [
        _audio('Áudio (grupo)', 'a1', kind: 'k-audio-grupo'),
        _audio('Voz soprano', 'a2', kind: 'k-soprano'),
        _audio('Playback', 'a3', kind: 'k-play'),
      ],
    );

Future<void> _pumpSheet(
  WidgetTester tester, {
  required LouvorGroup group,
  MaterialKindTaxonomy? taxonomy,
  Map<String, int> rank = const {},
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        isarStatusProvider.overrideWithValue(IsarStatus.unavailable),
        activeEntriesProvider.overrideWithValue(const []),
        favoriteMaterialKindRankProvider.overrideWithValue(rank),
        if (taxonomy != null)
          coldigomKindTaxonomyProvider.overrideWithValue(taxonomy),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showMaterialSheet(
                context,
                ref,
                group,
                canAddToPlaylist: false,
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

List<String> _visibleOrder(WidgetTester tester, List<String> labels) {
  final present =
      labels.where((l) => find.text(l).evaluate().isNotEmpty).toList();
  present.sort(
    (a, b) => tester
        .getTopLeft(find.text(a))
        .dy
        .compareTo(tester.getTopLeft(find.text(b)).dy),
  );
  return present;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Zebra striping no bottom sheet de materiais', () {
    testWidgets('itens alternam entre sem fundo e fundo sombreado', (
      tester,
    ) async {
      final group = _createGroup();
      await _pumpSheet(tester, group: group, taxonomy: _taxonomy);

      // Na aba de PDF, há 4 materiais: Partitura, Grade, Saxofone alto, Trompete.
      final tileWidgets = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
      expect(tileWidgets.length, 4);

      // Item 0: não sombreado
      expect(tileWidgets[0].tileColor, isNull);
      // Item 1: sombreado com a cor zebra
      expect(tileWidgets[1].tileColor, const Color(0x0A6A2F2F));
      // Item 2: não sombreado
      expect(tileWidgets[2].tileColor, isNull);
      // Item 3: sombreado com a cor zebra
      expect(tileWidgets[3].tileColor, const Color(0x0A6A2F2F));

      // Todos os ListTiles têm cantos arredondados
      for (final tile in tileWidgets) {
        expect(tile.shape, isA<RoundedRectangleBorder>());
        final border = tile.shape as RoundedRectangleBorder;
        expect(border.borderRadius, BorderRadius.circular(8));
      }
    });
  });

  group('Agrupamento taxonômico no bottom sheet de materiais', () {
    testWidgets('com taxonomia agrupa por classe taxonômica igual na biblioteca e offline', (
      tester,
    ) async {
      final group = _createGroup();
      await _pumpSheet(tester, group: group, taxonomy: _taxonomy);

      // Deve exibir os cabeçalhos das classes com contagem:
      // REGÊNCIA E GERAL (2) e METAIS (2)
      expect(find.text('REGÊNCIA E GERAL'), findsOneWidget);
      expect(find.text('METAIS'), findsOneWidget);

      // Ordem dos materiais dentro de cada seção:
      // Regência: Partitura (ordem 10), Grade (ordem 20)
      // Metais: Saxofone alto (ordem 30), Trompete (ordem 40)
      expect(
        _visibleOrder(
          tester,
          ['Partitura', 'Grade', 'Saxofone alto', 'Trompete'],
        ),
        ['Partitura', 'Grade', 'Saxofone alto', 'Trompete'],
      );
    });

    testWidgets('mantém ordenação dos materiais favoritos dentro de cada classe', (
      tester,
    ) async {
      final group = _createGroup();
      // Define Trompete e Grade como favoritos (rank 0 e 1)
      final rank = {
        'k-trompete': 0,
        'k-grade': 1,
      };

      await _pumpSheet(
        tester,
        group: group,
        taxonomy: _taxonomy,
        rank: rank,
      );

      // Dentro de Regência, Grade (favorito) sobe antes de Partitura.
      // Dentro de Metais, Trompete (favorito) sobe antes de Saxofone alto.
      expect(
        _visibleOrder(
          tester,
          ['Grade', 'Partitura', 'Trompete', 'Saxofone alto'],
        ),
        ['Grade', 'Partitura', 'Trompete', 'Saxofone alto'],
      );
    });

    testWidgets('agrupa faixas de áudio por classe taxonômica na aba de áudio', (
      tester,
    ) async {
      final group = _createGroup();
      await _pumpSheet(tester, group: group, taxonomy: _taxonomy);

      // Alterna para a aba de Áudio
      await tester.tap(find.text('Áudio'));
      await tester.pumpAndSettle();

      // Voz soprano é da classe 'vozes' (1 track)
      // Playback e Áudio (grupo) são da classe 'audio' (2 tracks)
      expect(find.text('VOZES'), findsOneWidget);
      expect(find.text('ÁUDIO E ACOMPANHAMENTO'), findsOneWidget);

      expect(
        _visibleOrder(
          tester,
          ['Voz soprano', 'Playback', 'Áudio (grupo)'],
        ),
        ['Voz soprano', 'Playback', 'Áudio (grupo)'],
      );

      // Verifica zebra na aba de áudio também
      final audioTiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
      expect(audioTiles.length, 3);
      expect(audioTiles[0].tileColor, isNull);
      expect(audioTiles[1].tileColor, const Color(0x0A6A2F2F));
      expect(audioTiles[2].tileColor, isNull);
    });
  });
}

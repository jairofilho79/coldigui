// test/widget/features/catalog/louvor_group_card_multi_material_test.dart
//
// C5: card multi-material — "+" sempre habilitado, adiciona o material
// preferido (PDF principal) e oferece «Trocar material» na snackbar, que
// reabre o sheet no fluxo de troca (`replaceByKey`).
import '../../../support/fakes/fake_active_editor.dart';
import '../../../support/fakes/fake_playlists_notifier.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_group_card.dart';
import 'package:coldigui/features/catalog/presentation/widgets/material_sheet.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

LouvorGroup _multiMaterialGroup() {
  final louvor = Louvor(
    nome: 'Aleluia',
    numero: '001',
    categoria: 'Partitura',
    classificacao: 'Básico',
    pdf: 'pdf1.pdf',
    pdfId: 'pdf1',
    groupId: 'g1',
    searchTitleNorm: 'aleluia',
    searchContentTokens: const [],
    searchCompactContent: '',
    source: LouvorDataSource.plpcg,
  );

  return LouvorGroup(
    groupId: 'g1',
    numero: '001',
    nome: 'Aleluia',
    sections: [
      LouvorMaterialSection(
        classificacao: 'Básico',
        displayLabel: 'Básico',
        materials: [
          LouvorMaterialEntry(
            categoria: 'Partitura',
            pdfId: 'pdf1',
            louvor: louvor,
          ),
        ],
      ),
    ],
    audioTracks: const [
      AudioTrack(
        audioId: 'a1',
        r2Key: 'assets/praises/g1/a1.mp3',
        nome: 'Aleluia',
        numero: '001',
        groupId: 'g1',
        categoria: 'Áudio',
        classificacao: 'Básico',
      ),
    ],
  );
}

void main() {
  late AppLocalizations pt;

  setUpAll(() async {
    pt = await AppLocalizations.delegate.load(const Locale('pt'));
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<FakeActiveEditor> pumpCard(WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    final editor = FakeActiveEditor()..applyAddToActiveToState = true;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          activePlaylistEditorProvider.overrideWith(() => editor),
          playlistsProvider.overrideWith(FakePlaylistsNotifier.new),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: Scaffold(body: LouvorGroupCard(group: _multiMaterialGroup())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return editor;
  }

  testWidgets('«+» sempre habilitado num grupo multi-material (PDF + áudio)', (
    tester,
  ) async {
    await pumpCard(tester);

    expect(find.byType(CarouselLouvorAddButton), findsOneWidget);
  });

  testWidgets(
    'toque no «+» adiciona o PDF principal e mostra «Adicionado à lista»',
    (tester) async {
      final editor = await pumpCard(tester);

      await tester.tap(find.byType(CarouselLouvorAddButton));
      await tester.pumpAndSettle();

      expect(editor.added, [(id: 'pdf1', kind: MaterialKind.pdf)]);
      expect(find.text(pt.cardAddedSwapMaterial), findsOneWidget);
      expect(find.text(pt.cardSwapMaterialAction), findsOneWidget);
    },
  );

  testWidgets(
    '«Trocar material» abre o MaterialSheet e a escolha troca a entrada',
    (tester) async {
      final editor = await pumpCard(tester);

      await tester.tap(find.byType(CarouselLouvorAddButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text(pt.cardSwapMaterialAction));
      await tester.pumpAndSettle();

      expect(find.byType(MaterialSheet), findsOneWidget);

      // O sheet repete o rótulo no cabeçalho da seção e na linha do material.
      await tester.tap(find.text('Áudio').last);
      await tester.pumpAndSettle();

      expect(editor.replaced, [
        (
          key: 'pdf1',
          replacement: const PlaylistEntry(id: 'a1', kind: MaterialKind.audio),
        ),
      ]);
    },
  );
}

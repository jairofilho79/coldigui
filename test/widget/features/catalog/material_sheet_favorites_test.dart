import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/presentation/widgets/material_sheet.dart';
import 'package:coldigui/features/material_kind_prefs/presentation/providers/material_kind_prefs_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Louvor _pdf(String categoria, String pdfId, {String? kind}) =>
    Louvor.fromManifest(
      nome: 'Comigo habita',
      numero: '692',
      categoria: categoria,
      classificacao: 'Coletânea',
      pdf: '$pdfId.pdf',
      pdfId: pdfId,
      groupId: 'g1',
      materialKindId: kind,
    );

AudioTrack _audio(String categoria, String id, {String? kind}) => AudioTrack(
  audioId: id,
  r2Key: '$id.mp3',
  nome: 'Comigo habita',
  numero: '692',
  groupId: 'g1',
  categoria: categoria,
  classificacao: 'Coletânea',
  materialKindId: kind,
);

LouvorGroup _group() => LouvorGroup(
  groupId: 'g1',
  numero: '692',
  nome: 'Comigo habita',
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
          categoria: 'Trompete',
          pdfId: 'p2',
          louvor: _pdf('Trompete', 'p2', kind: 'k-trompete'),
        ),
        LouvorMaterialEntry(
          categoria: 'Partitura',
          pdfId: 'p3',
          louvor: _pdf('Partitura', 'p3', kind: 'k-partitura'),
        ),
      ],
    ),
  ],
  audioTracks: [
    _audio('Coro', 'a1', kind: 'k-coro'),
    _audio('Voz soprano', 'a2', kind: 'k-soprano'),
    _audio('Playback', 'a3'),
  ],
);

Future<void> _pumpSheet(
  WidgetTester tester, {
  required Map<String, int> rank,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        isarStatusProvider.overrideWithValue(IsarStatus.unavailable),
        activeEntriesProvider.overrideWithValue(const []),
        favoriteMaterialKindRankProvider.overrideWithValue(rank),
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
                _group(),
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

/// Ordem vertical dos textos [labels] que estão na tela.
List<String> _visibleOrder(WidgetTester tester, List<String> labels) {
  final present = labels
      .where((l) => find.text(l).evaluate().isNotEmpty)
      .toList();
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

  testWidgets('sem rank a ordem é a do grupo', (tester) async {
    await _pumpSheet(tester, rank: const {});
    expect(_visibleOrder(tester, ['Grade', 'Trompete', 'Partitura']), [
      'Grade',
      'Trompete',
      'Partitura',
    ]);
  });

  testWidgets('favoritos sobem na aba PDF na ordem do rank', (tester) async {
    await _pumpSheet(tester, rank: const {'k-partitura': 0, 'k-trompete': 1});
    expect(_visibleOrder(tester, ['Grade', 'Trompete', 'Partitura']), [
      'Partitura',
      'Trompete',
      'Grade',
    ]);
  });

  testWidgets('favoritos sobem na aba de áudio; sem kind fica onde está', (
    tester,
  ) async {
    await _pumpSheet(tester, rank: const {'k-soprano': 0});
    await tester.tap(find.text('Áudio'));
    await tester.pumpAndSettle();
    expect(_visibleOrder(tester, ['Coro', 'Voz soprano', 'Playback']), [
      'Voz soprano',
      'Coro',
      'Playback',
    ]);
  });
}

import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/presentation/providers/open_material_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/material_sheet.dart';
import 'package:coldigui/features/catalog/presentation/widgets/material_sheet_actions.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _lyrics = LyricsMaterial(
  praiseId: 'p1',
  nome: 'Comigo habita',
  numero: '692',
);

final _pdf = Louvor.fromManifest(
  nome: 'Comigo habita',
  numero: '692',
  categoria: 'Partitura',
  classificacao: 'Básico',
  pdf: 'm1.pdf',
  pdfId: 'pdf-1',
  groupId: 'p1',
);

class _OpenSpy extends OpenMaterial {
  CatalogMaterial? opened;

  @override
  Future<void> open(
    BuildContext context,
    WidgetRef ref,
    CatalogMaterial material, {
    List<AudioTrack>? audioQueue,
  }) async {
    opened = material;
  }
}

Future<_OpenSpy> _pumpSheet(WidgetTester tester, LouvorGroup group) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final spy = _OpenSpy();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        isarStatusProvider.overrideWithValue(IsarStatus.available),
        activeEntriesProvider.overrideWithValue(const []),
        openMaterialProvider.overrideWithValue(spy),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showMaterialSheet(context, ref, group),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return spy;
}

void main() {
  testWidgets('grupo com PDF e letra ganha a aba «Letra» com um tile sem +', (
    tester,
  ) async {
    final group = LouvorGroup.fromLouvores(
      [_pdf],
      lyricsByGroupId: {'p1': _lyrics},
    ).single;
    final spy = await _pumpSheet(tester, group);

    expect(find.text('Letra'), findsOneWidget);
    await tester.tap(find.text('Letra'));
    await tester.pumpAndSettle();

    final tile = find.widgetWithText(ListTile, 'Letra');
    expect(tile, findsOneWidget);
    expect(
      find.descendant(of: tile, matching: find.byType(MaterialAddTrailing)),
      findsNothing,
    );

    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(spy.opened, same(_lyrics));
  });

  testWidgets('grupo só com letra mostra o tile direto, sem abas', (
    tester,
  ) async {
    final group = LouvorGroup(
      groupId: 'p1',
      numero: '692',
      nome: 'Comigo habita',
      sections: const [],
      lyrics: _lyrics,
    );
    await _pumpSheet(tester, group);

    expect(find.widgetWithText(ListTile, 'Letra'), findsOneWidget);
  });
}

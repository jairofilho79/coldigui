import 'package:coldigui/core/database/collections/coldigom_praise_cache.dart';
import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/presentation/providers/open_material_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/coldigom_meta_block.dart';
import 'package:coldigui/features/catalog/presentation/widgets/material_sheet.dart';
import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
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

const _sampleLyrics = 'Comigo habita, ó Deus\nA noite vem\nAs trevas descem\nSenhor comigo fica\nNão me desampares';

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

Future<_OpenSpy> _pumpSheet(
  WidgetTester tester,
  LouvorGroup group, {
  String lyrics = _sampleLyrics,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final spy = _OpenSpy();
  final cacheRow = ColdigomPraiseCache()
    ..praiseId = group.groupId
    ..name = group.nome
    ..number = group.numero
    ..lyrics = lyrics;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        isarStatusProvider.overrideWithValue(IsarStatus.available),
        activeEntriesProvider.overrideWithValue(const []),
        openMaterialProvider.overrideWithValue(spy),
        coldigomSearchIndexProvider.overrideWithValue(ColdigomSearchIndex.empty),
        coldigomCatalogRowProvider(group.groupId).overrideWithValue(cacheRow),
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
  testWidgets('grupo com PDF e letra não tem aba de letra, e prévia de 5 linhas abre o leitor', (
    tester,
  ) async {
    final group = LouvorGroup.fromLouvores(
      [_pdf],
      lyricsByGroupId: {'p1': _lyrics},
    ).single;
    final spy = await _pumpSheet(tester, group);

    // Aba de letra não existe no segment bar
    expect(find.byType(ColdigomMetaBlock), findsOneWidget);
    expect(find.text('LETRA'), findsOneWidget);
    expect(find.textContaining('Comigo habita, ó Deus'), findsOneWidget);

    // Tocar na prévia da letra abre no leitor de letras
    await tester.tap(find.textContaining('Comigo habita, ó Deus'));
    await tester.pumpAndSettle();

    expect(spy.opened, isA<LyricsMaterial>());
    expect(spy.opened?.id, _lyrics.id);
  });

  testWidgets('grupo só com letra exibe a prévia no bloco de meta e ao tocar abre o leitor', (
    tester,
  ) async {
    final group = LouvorGroup(
      groupId: 'p1',
      numero: '692',
      nome: 'Comigo habita',
      sections: const [],
      lyrics: _lyrics,
    );
    final spy = await _pumpSheet(tester, group);

    expect(find.byType(ColdigomMetaBlock), findsOneWidget);
    expect(find.text('LETRA'), findsOneWidget);

    await tester.tap(find.text('LETRA'));
    await tester.pumpAndSettle();

    expect(spy.opened, isA<LyricsMaterial>());
  });

  testWidgets('no mobile o sheet abre com DraggableScrollableSheet e renderiza titulo dentro do card e materiais acessiveis', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final group = LouvorGroup.fromLouvores(
      [_pdf],
      lyricsByGroupId: {'p1': _lyrics},
    ).single;
    await _pumpSheet(tester, group);

    // DraggableScrollableSheet presente
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);

    // Título e número dentro do card
    final metaBlock = find.byType(ColdigomMetaBlock);
    expect(metaBlock, findsOneWidget);
    expect(find.descendant(of: metaBlock, matching: find.text('692')), findsOneWidget);
    expect(find.descendant(of: metaBlock, matching: find.text('Comigo habita')), findsOneWidget);

    // Botões de ação no topo
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.byIcon(Icons.open_in_full), findsOneWidget);

    // Materiais visíveis e acessíveis
    expect(find.text('Partitura'), findsOneWidget);
  });
}

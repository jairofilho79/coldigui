import 'dart:async';

import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/routing/reading_navigation.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/tutorial/presentation/providers/tutorial_provider.dart';
import 'package:coldigui/core/widgets/plpcg_primary_app_bar.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/entities/youtube_material.dart';
import 'package:coldigui/features/catalog/presentation/providers/open_material_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/material_sheet.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:coldigui/features/chords/presentation/providers/available_chords_provider.dart';
import 'package:coldigui/features/gestures/domain/entities/gesture_material.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fakes/fake_active_editor.dart';

final _pdf = PdfMaterial(
  Louvor.fromManifest(
    nome: 'Comigo habita',
    numero: '692',
    categoria: 'Partitura',
    classificacao: 'Básico',
    pdf: 'partitura.pdf',
    pdfId: 'pdf1',
    groupId: 'g1',
  ),
);

const _chord = ChordMaterialRef(
  ChordMaterial(
    chordId: 'chord1',
    r2Key: 'material.chord',
    nome: 'Comigo habita',
    numero: '692',
    groupId: 'g1',
    categoria: 'Cifra I',
    classificacao: 'Básico',
  ),
);

const _gesture = GestureMaterialRef(
  GestureMaterial(
    gestureId: 'gesture1',
    r2Key: 'material.gestures',
    nome: 'Comigo habita',
    numero: '692',
    groupId: 'g1',
    categoria: 'Gestos',
    classificacao: 'Básico',
  ),
);

const _audio = AudioMaterial(
  AudioTrack(
    audioId: 'audio1',
    r2Key: 'material.mp3',
    nome: 'Comigo habita',
    numero: '692',
    groupId: 'g1',
    categoria: 'Playback',
    classificacao: 'Básico',
  ),
);

const _lyrics = LyricsMaterial(
  praiseId: 'g1',
  nome: 'Comigo habita',
  numero: '692',
);

const _youtube = YoutubeMaterialRef(
  YoutubeMaterial(
    id: 'youtube1',
    url: 'https://www.youtube.com/watch?v=1Pks43ceAac',
    nome: 'Comigo habita',
    numero: '692',
    groupId: 'g1',
    categoria: 'Vídeo',
    classificacao: 'Básico',
  ),
);

OpenMaterial _opener() => OpenMaterial(
  openPdf: ({required ref, required context, required louvor}) async {
    openReadingLocation(context, '${RoutePaths.reader}?pdfId=${louvor.pdfId}');
  },
  openChord: ({required ref, required context, required chord}) async {
    openReadingLocation(
      context,
      '${RoutePaths.chords}?chordId=${chord.chordId}',
    );
  },
  openGesture: ({required ref, required context, required gesture}) async {
    openReadingLocation(
      context,
      '${RoutePaths.gestos}?gestureId=${gesture.gestureId}',
    );
  },
  openAudio: ({required ref, required context, required track, queue}) async {
    openReadingLocation(
      context,
      '${RoutePaths.audio}?audioId=${track.audioId}',
    );
  },
  openYoutube: (_, {required capabilities}) async => true,
);

Future<GoRouter> _pumpApp(
  WidgetTester tester, {
  required CatalogMaterial material,
  String origin = '/?pesquisa=habita&tonality=D',
  String? initialLocation,
  MaterialSheetOpener? onMaterialSelected,
  OpenMaterial? opener,
  List<CatalogMaterial> extraMaterials = const [],
}) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final group = LouvorGroup(
    groupId: 'g1',
    numero: '692',
    nome: 'Comigo habita',
    sections: material is PdfMaterial
        ? LouvorGroup.fromLouvores([material.louvor]).first.sections
        : const [],
    extras: [if (material is! PdfMaterial) material, ...extraMaterials],
  );
  final router = GoRouter(
    initialLocation: initialLocation ?? origin,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) =>
            Scaffold(appBar: const PlpcgPrimaryAppBar(), body: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.home,
                builder: (_, _) => Consumer(
                  builder: (context, ref, _) => Scaffold(
                    body: TextButton(
                      onPressed: () => showMaterialSheet(
                        context,
                        ref,
                        group,
                        onMaterialSelected: onMaterialSelected,
                      ),
                      child: const Text('abrir materiais'),
                    ),
                  ),
                ),
                routes: [
                  for (final path in readingRoutePaths)
                    GoRoute(
                      path: path.substring(1),
                      builder: (context, _) => Scaffold(
                        body: Column(
                          children: [
                            Text('leitura $path'),
                            TextButton(
                              onPressed: () => context.pop(),
                              child: const Text('voltar'),
                            ),
                            TextButton(
                              onPressed: () => openReadingLocation(
                                context,
                                RoutePaths.lyrics,
                              ),
                              child: const Text('trocar para letra'),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.library,
        builder: (_, _) => Consumer(
          builder: (context, ref, _) => Scaffold(
            body: TextButton(
              onPressed: () => showMaterialSheet(context, ref, group),
              child: const Text('abrir materiais'),
            ),
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        activePlaylistEditorProvider.overrideWith(FakeActiveEditor.new),
        availableChordsProvider.overrideWith(
          (ref, groupId) async => [
            if (material is ChordMaterialRef) material.chord,
          ],
        ),
        openMaterialProvider.overrideWithValue(opener ?? _opener()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _selectMaterial(
  WidgetTester tester,
  CatalogMaterial material,
) async {
  await tester.tap(find.text('abrir materiais'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, material.categoria));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoRouter.optionURLReflectsImperativeAPIs = true;
  });
  tearDown(() => GoRouter.optionURLReflectsImperativeAPIs = false);

  for (final (material, path) in [
    (_pdf, RoutePaths.reader),
    (_chord, RoutePaths.chords),
    (_gesture, RoutePaths.gestos),
    (_audio, RoutePaths.audio),
    (_lyrics, RoutePaths.lyrics),
  ]) {
    testWidgets(
      '${material.kind}: voltar revela o mesmo sheet e mantém a busca',
      (tester) async {
        final router = await _pumpApp(tester, material: material);
        final origin = router.routerDelegate.currentConfiguration.uri;
        await tester.tap(find.text('abrir materiais'));
        await tester.pumpAndSettle();
        final sheetState = tester.state(find.byType(MaterialSheet));

        await tester.tap(find.widgetWithText(ListTile, material.categoria));
        await tester.pumpAndSettle();
        expect(find.text('leitura $path'), findsOneWidget);
        expect(find.byType(MaterialSheet), findsNothing);

        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        expect(find.byType(MaterialSheet), findsOneWidget);
        expect(tester.state(find.byType(MaterialSheet)), same(sheetState));
        expect(router.routerDelegate.currentConfiguration.uri, origin);

        await tester.tap(find.byTooltip('Fechar'));
        await tester.pumpAndSettle();
        expect(find.byType(MaterialSheet), findsNothing);
        expect(find.text('abrir materiais'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('voltar do sistema após trocar de leitor restaura o sheet', (
    tester,
  ) async {
    final router = await _pumpApp(tester, material: _pdf);
    await _selectMaterial(tester, _pdf);
    await tester.tap(find.text('trocar para letra'));
    await tester.pumpAndSettle();

    expect(find.text('leitura ${RoutePaths.lyrics}'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(MaterialSheet), findsOneWidget);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      RoutePaths.home,
    );

    await tester.tap(find.widgetWithText(ListTile, _pdf.categoria));
    await tester.pumpAndSettle();
    expect(find.text('leitura ${RoutePaths.reader}'), findsOneWidget);
    await tester.tap(find.text('voltar'));
    await tester.pumpAndSettle();
    expect(find.byType(MaterialSheet), findsOneWidget);
  });

  testWidgets('tutorial do leitor não usa o portal do sheet fora de cena', (
    tester,
  ) async {
    await _pumpApp(tester, material: _pdf);
    final container = ProviderScope.containerOf(
      tester.element(find.text('abrir materiais')),
    );
    final tutorial = container.read(tutorialControllerProvider);
    final rootPortal = tutorial.portalController;
    await tester.tap(find.text('abrir materiais'));
    await tester.pumpAndSettle();
    final sheetPortal = tutorial.portalController;
    expect(sheetPortal, isNot(same(rootPortal)));

    await tester.tap(find.widgetWithText(ListTile, _pdf.categoria));
    await tester.pumpAndSettle();
    expect(tutorial.portalController, same(rootPortal));

    await tester.tap(find.text('voltar'));
    await tester.pumpAndSettle();
    expect(tutorial.portalController, same(sheetPortal));
    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();
    expect(tutorial.portalController, same(rootPortal));
  });

  testWidgets('voltar mantém a aba escolhida e permite abrir outro material', (
    tester,
  ) async {
    await _pumpApp(tester, material: _pdf, extraMaterials: const [_lyrics]);
    await tester.tap(find.text('abrir materiais'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Letra'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Letra'));
    await tester.pumpAndSettle();
    expect(find.text('leitura ${RoutePaths.lyrics}'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Letra'), findsOneWidget);
    expect(find.widgetWithText(ListTile, _pdf.categoria), findsNothing);

    await tester.tap(find.text('Partituras'));
    await tester.pumpAndSettle();
    expect(find.text('leitura ${RoutePaths.reader}'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(MaterialSheet), findsOneWidget);
  });

  testWidgets('toques repetidos durante o resolve não empilham leitores', (
    tester,
  ) async {
    final resolve = Completer<void>();
    var opens = 0;
    await _pumpApp(
      tester,
      material: _pdf,
      opener: OpenMaterial(
        openPdf: ({required ref, required context, required louvor}) async {
          opens++;
          await resolve.future;
          if (context.mounted) {
            openReadingLocation(context, RoutePaths.reader);
          }
        },
      ),
    );
    await _selectMaterial(tester, _pdf);
    await tester.tap(find.widgetWithText(ListTile, _pdf.categoria));
    await tester.pump();
    expect(opens, 1);

    resolve.complete();
    await tester.pumpAndSettle();
    expect(find.text('leitura ${RoutePaths.reader}'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(MaterialSheet), findsOneWidget);
  });

  testWidgets('falha na abertura fecha o sheet para exibir a snackbar', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      material: _pdf,
      opener: OpenMaterial(
        openPdf: ({required ref, required context, required louvor}) async {
          throw StateError('falha de abertura');
        },
      ),
    );
    await _selectMaterial(tester, _pdf);
    expect(find.byType(MaterialSheet), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('link direto no leitor não inventa um sheet ao voltar', (
    tester,
  ) async {
    await _pumpApp(tester, material: _pdf, initialLocation: RoutePaths.reader);
    await tester.tap(find.text('voltar'));
    await tester.pumpAndSettle();
    expect(find.byType(MaterialSheet), findsNothing);
    expect(find.text('abrir materiais'), findsOneWidget);
  });

  testWidgets('YouTube continua fechando o sheet', (tester) async {
    await _pumpApp(tester, material: _youtube);
    await _selectMaterial(tester, _youtube);
    expect(find.byType(MaterialSheet), findsNothing);
    expect(find.text('abrir materiais'), findsOneWidget);
  });

  testWidgets('handler de troca de material continua fechando o sheet', (
    tester,
  ) async {
    CatalogMaterial? selected;
    await _pumpApp(
      tester,
      material: _pdf,
      onMaterialSelected: (material) async => selected = material,
    );
    await _selectMaterial(tester, _pdf);
    expect(selected?.id, _pdf.id);
    expect(find.byType(MaterialSheet), findsNothing);
  });

  testWidgets('sheet da Biblioteca mantém o comportamento anterior', (
    tester,
  ) async {
    await _pumpApp(tester, material: _pdf, origin: RoutePaths.library);
    await _selectMaterial(tester, _pdf);
    await tester.tap(find.text('voltar'));
    await tester.pumpAndSettle();
    expect(find.byType(MaterialSheet), findsNothing);
    expect(find.text('abrir materiais'), findsOneWidget);
  });
}

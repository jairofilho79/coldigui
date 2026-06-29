import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/widgets/golden_tagged_container.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_louvores_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvores_manifest_provider.dart';
import 'package:coldigui/features/library/presentation/pages/library_screen.dart';
import 'package:coldigui/features/library/presentation/providers/library_group_results_provider.dart';
import 'package:coldigui/features/library/presentation/providers/library_group_worker.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Louvor _louvor({
  required String nome,
  required String numero,
  String classificacao = 'ColAdultos',
}) => Louvor.fromManifest(
  nome: nome,
  numero: numero,
  categoria: 'Partitura',
  classificacao: classificacao,
  pdf: '$numero.pdf',
  pdfId: 'id-$numero',
);

class _FakeCarouselNotifier extends CarouselLouvoresNotifier {
  @override
  List<CarouselItem> build() => const [];
}

Widget _libraryTestApp({
  required SharedPreferences prefs,
  required List<Louvor> catalog,
  List<Override> extraOverrides = const [],
  Widget? home,
}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      louvoresManifestProvider.overrideWith(
        (ref) async => LouvoresManifest.fromLouvores(catalog),
      ),
      carouselLouvoresProvider.overrideWith(_FakeCarouselNotifier.new),
      libraryGroupPipelineExecutorProvider.overrideWith(
        (ref) =>
            (input) async => runLibraryGroupPipeline(input),
      ),
      ...extraOverrides,
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('pt'),
      home: home ?? const Scaffold(body: LibraryScreen()),
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpLibrary(WidgetTester tester, Widget app) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  testWidgets('LibraryScreen exibe LouvorCards e chips de filtro', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final catalog = List.generate(
      15,
      (i) => _louvor(
        nome: 'Louvor ${i + 1}',
        numero: '${i + 1}'.padLeft(3, '0'),
        classificacao: i.isEven ? 'ColAdultos' : 'ColAdultos (Especial)',
      ),
    );

    await pumpLibrary(tester, _libraryTestApp(prefs: prefs, catalog: catalog));

    await tester.tap(find.text('Filtros'));
    await tester.pumpAndSettle();

    expect(find.text('#001 — Louvor 1'), findsOneWidget);
    expect(find.text('Partitura'), findsWidgets);
    expect(find.text('Arranjo especial'), findsOneWidget);
    expect(find.text('Padrão'), findsOneWidget);
    expect(find.text('Especial'), findsOneWidget);
  });

  testWidgets('LibraryScreen exibe resumo dentro do card Visualização', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final catalog = List.generate(
      15,
      (i) =>
          _louvor(nome: 'Louvor ${i + 1}', numero: '${i + 1}'.padLeft(3, '0')),
    );

    await pumpLibrary(tester, _libraryTestApp(prefs: prefs, catalog: catalog));

    final summary = find.textContaining('Mostrando 1');
    expect(summary, findsOneWidget);
    expect(find.text('10 por página'), findsOneWidget);

    expect(
      find.descendant(
        of: find.ancestor(
          of: summary,
          matching: find.byType(GoldenTaggedContainer),
        ),
        matching: find.text('Visualização'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('LibraryScreen troca página e ordenação', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final catalog = List.generate(
      15,
      (i) =>
          _louvor(nome: 'Louvor ${i + 1}', numero: '${i + 1}'.padLeft(3, '0')),
    );

    await pumpLibrary(tester, _libraryTestApp(prefs: prefs, catalog: catalog));

    expect(find.text('#001 — Louvor 1'), findsOneWidget);
    expect(find.text('#011 — Louvor 11'), findsNothing);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('#011 — Louvor 11'), findsOneWidget);
    expect(find.text('#001 — Louvor 1'), findsNothing);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(find.text('#001 — Louvor 1'), findsOneWidget);

    await tester.tap(find.text('Nome'));
    await tester.pumpAndSettle();

    final louvor1Finder = find.text('#001 — Louvor 1');
    final louvor10Finder = find.text('#010 — Louvor 10');
    expect(
      tester.getTopLeft(louvor1Finder).dy,
      lessThan(tester.getTopLeft(louvor10Finder).dy),
    );
  });
}

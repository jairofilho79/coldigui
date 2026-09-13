import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_bar_action_button.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_navigator_bar.dart';
import 'package:coldigui/features/carousel/presentation/widgets/chip_parts/chip_nav_zone.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _testItem = CarouselItem(
  materialId: 'b',
  index: 1,
  numero: '002',
  nome: 'Louvor B',
  categoria: 'Partitura',
  classificacao: 'ColAdultos',
);

Widget _wrap(Widget child, {double width = 900}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('pt'),
  home: Scaffold(body: SizedBox(width: width, child: child)),
);

void main() {
  testWidgets('chip com setas, Abrir e Lista com legenda; toques chegam', (
    tester,
  ) async {
    var previousTapped = false;
    var nextTapped = false;
    var selectionTapped = false;
    var openTapped = false;

    await tester.pumpWidget(
      _wrap(
        CarouselNavigatorBar(
          item: _testItem,
          canGoPrevious: true,
          canGoNext: true,
          onPrevious: () => previousTapped = true,
          onNext: () => nextTapped = true,
          onOpenSelection: () => selectionTapped = true,
          onOpen: () => openTapped = true,
        ),
      ),
    );

    expect(find.textContaining('Louvor B'), findsOneWidget);
    expect(find.byType(ChipNavZone), findsNWidgets(2));
    expect(find.byIcon(Icons.file_open_outlined), findsOneWidget);
    expect(find.text('Abrir'), findsOneWidget);
    expect(find.byIcon(Icons.queue_music), findsOneWidget);
    expect(find.text('Lista'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    expect(find.byIcon(Icons.open_in_full), findsNothing);

    await tester.tap(find.byTooltip('Louvor anterior'));
    await tester.tap(find.byTooltip('Próximo louvor'));
    await tester.tap(find.text('Lista'));
    await tester.tap(find.text('Abrir'));

    expect(previousTapped, isTrue);
    expect(nextTapped, isTrue);
    expect(selectionTapped, isTrue);
    expect(openTapped, isTrue);
  });

  testWidgets('setas continuam presentes (apagadas) nos extremos', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        CarouselNavigatorBar(
          item: _testItem,
          canGoPrevious: false,
          canGoNext: false,
          onOpenSelection: () {},
        ),
      ),
    );

    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('sem Abrir nem Material, o grupo louvor não aparece', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        CarouselNavigatorBar(
          item: _testItem,
          canGoPrevious: false,
          canGoNext: false,
          onOpenSelection: () {},
        ),
      ),
    );

    expect(find.byType(CarouselBarActionGroup), findsOneWidget);
  });

  testWidgets('showLabels false: só ícones com tooltip', (tester) async {
    await tester.pumpWidget(
      _wrap(
        CarouselNavigatorBar(
          item: _testItem,
          canGoPrevious: false,
          canGoNext: false,
          showLabels: false,
          onOpenSelection: () {},
          onOpen: () {},
        ),
        width: 360,
      ),
    );

    expect(find.text('Abrir'), findsNothing);
    expect(find.byTooltip('Abrir'), findsOneWidget);
    expect(find.byTooltip('Lista'), findsOneWidget);
  });
}

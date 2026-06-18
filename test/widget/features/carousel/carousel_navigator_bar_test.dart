import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_navigator_bar.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _testItem = CarouselItem(
  pdfId: 'b',
  sortOrder: 1,
  numero: '002',
  nome: 'Louvor B',
  categoria: 'Partitura',
  classificacao: 'ColAdultos',
);

void main() {
  testWidgets('exibe chip, setas condicionais e botão de lista',
      (tester) async {
    var previousTapped = false;
    var nextTapped = false;
    var listTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Scaffold(
          body: CarouselNavigatorBar(
            item: _testItem,
            canGoPrevious: true,
            canGoNext: true,
            onPrevious: () => previousTapped = true,
            onNext: () => nextTapped = true,
            onOpenList: () => listTapped = true,
          ),
        ),
      ),
    );

    expect(find.textContaining('Louvor B'), findsOneWidget);
    expect(find.byTooltip('Louvor anterior'), findsOneWidget);
    expect(find.byTooltip('Próximo louvor'), findsOneWidget);
    expect(find.byTooltip('Ver seleção'), findsOneWidget);

    await tester.tap(find.byTooltip('Louvor anterior'));
    await tester.tap(find.byTooltip('Próximo louvor'));
    await tester.tap(find.byTooltip('Ver seleção'));

    expect(previousTapped, isTrue);
    expect(nextTapped, isTrue);
    expect(listTapped, isTrue);
  });

  testWidgets('oculta setas quando navegação indisponível', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Scaffold(
          body: CarouselNavigatorBar(
            item: const CarouselItem(
              pdfId: 'a',
              sortOrder: 0,
              numero: '001',
              nome: 'Louvor A',
              categoria: 'Partitura',
              classificacao: 'ColAdultos',
            ),
            canGoPrevious: false,
            canGoNext: false,
            onOpenList: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.chevron_left), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.byIcon(Icons.view_list), findsOneWidget);
  });

  testWidgets('desabilita setas durante loading mas mantém lista',
      (tester) async {
    var listTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Scaffold(
          body: CarouselNavigatorBar(
            item: _testItem,
            canGoPrevious: true,
            canGoNext: true,
            loading: true,
            onPrevious: () {},
            onNext: () {},
            onOpenList: () => listTapped = true,
          ),
        ),
      ),
    );

    final buttons = tester.widgetList<IconButton>(find.byType(IconButton));
    final arrowButtons = buttons.take(2);
    expect(arrowButtons.every((button) => button.onPressed == null), isTrue);

    await tester.tap(find.byTooltip('Ver seleção'));
    expect(listTapped, isTrue);
  });

  testWidgets('topBar não estoura com textScaler elevado', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: CarouselNavigatorBar(
                item: const CarouselItem(
                  pdfId: 'x',
                  sortOrder: 0,
                  numero: '203',
                  nome: 'Alto Preço',
                  categoria: 'Partitura',
                  classificacao: 'PES',
                ),
                chipVariant: CarouselLouvorChipVariant.topBar,
                canGoPrevious: true,
                canGoNext: true,
                onOpenList: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

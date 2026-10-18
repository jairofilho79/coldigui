import 'package:coldigui/features/catalog/presentation/widgets/coldigom_meta_block.dart';
import 'package:coldigui/features/coldigom/domain/entities/coldigom_praise_metadata.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ColdigomMetaBlock exibe iluminacao biblica discreta em uma linha', (
    tester,
  ) async {
    const meta = ColdigomPraiseMetadata(
      name: 'Salmo 23',
      tonality: 'D',
      rhythm: 'Lento',
      author: 'Davi',
      biblicalSummary: 'Sl 23:1 — O Senhor é meu pastor',
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Scaffold(
          body: Builder(
            builder: (context) => ColdigomMetaBlock(
              l10n: AppLocalizations.of(context)!,
              meta: meta,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Iluminação Bíblica'), findsOneWidget);
    final textFinder = find.text('Sl 23:1 — O Senhor é meu pastor');
    expect(textFinder, findsOneWidget);

    final Text textWidget = tester.widget(textFinder);
    expect(textWidget.maxLines, 1);
    expect(textWidget.overflow, TextOverflow.ellipsis);
  });

  testWidgets('ColdigomMetaBlock exibe titulo e numero no card', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Scaffold(
          body: Builder(
            builder: (context) => ColdigomMetaBlock(
              l10n: AppLocalizations.of(context)!,
              title: 'É somente teu meu coração',
              number: '055',
            ),
          ),
        ),
      ),
    );

    expect(find.text('055'), findsOneWidget);
    expect(find.text('É somente teu meu coração'), findsOneWidget);
  });

  testWidgets('no mobile com collapsibleDetails=true, autor e resumo iniciam recolhidos e expandem ao tocar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const meta = ColdigomPraiseMetadata(
      name: '055',
      tonality: 'D',
      rhythm: 'Básico 2',
      author: 'Cristina Manera Vianna',
      biblicalSummary: 'Consagração',
      tagNames: ['CIAs'],
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Scaffold(
          body: Builder(
            builder: (context) => ColdigomMetaBlock(
              l10n: AppLocalizations.of(context)!,
              title: 'É somente teu meu coração',
              number: '055',
              meta: meta,
              collapsibleDetails: true,
            ),
          ),
        ),
      ),
    );

    // Tom, ritmo e tags visíveis
    expect(find.text('D'), findsOneWidget);
    expect(find.text('Básico 2'), findsOneWidget);
    expect(find.text('CIAs'), findsOneWidget);

    // Autor e iluminação bíblica inicialmente ocultos
    expect(find.text('Cristina Manera Vianna'), findsNothing);
    expect(find.text('Consagração'), findsNothing);

    // Botão de expandir visível
    expect(find.text('Mais detalhes'), findsOneWidget);

    // Toca para expandir
    await tester.tap(find.text('Mais detalhes'));
    await tester.pumpAndSettle();

    // Agora exibe autor e iluminação bíblica
    expect(find.text('Cristina Manera Vianna'), findsOneWidget);
    expect(find.text('Consagração'), findsOneWidget);
    expect(find.text('Menos detalhes'), findsOneWidget);
  });

  testWidgets('letra exibe 2 linhas no mobile e 5 linhas em tela ampla', (
    tester,
  ) async {
    const lyrics = 'Linha 1\nLinha 2\nLinha 3\nLinha 4\nLinha 5\nLinha 6';

    // Mobile: 390 de largura (< 520)
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Scaffold(
          body: Builder(
            builder: (context) => ColdigomMetaBlock(
              l10n: AppLocalizations.of(context)!,
              lyricsText: lyrics,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Linha 1\nLinha 2'), findsOneWidget);

    // Tablet: 800 de largura (>= 520)
    tester.view.physicalSize = const Size(800, 1000);
    await tester.pumpAndSettle();

    expect(find.text('Linha 1\nLinha 2\nLinha 3\nLinha 4\nLinha 5'), findsOneWidget);
  });
}

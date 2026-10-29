import 'package:coldigui/features/app_shell/presentation/pages/about_screen.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

void main() {
  testWidgets('renderiza AboutScreen com os cards e alvos de tutorial',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('pt'),
        home: Scaffold(
          body: AboutScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quem somos'), findsOneWidget);
    expect(find.text('Objetivo'), findsOneWidget);
    expect(find.text('Política de Privacidade'), findsOneWidget);

    final targets = tester.widgetList<SpotlightGuideTarget>(
      find.byType(SpotlightGuideTarget),
    );
    final targetIds = targets.map((t) => t.id).toList();
    expect(
      targetIds,
      containsAll([
        'about-who-we-are',
        'about-mission',
        'about-shortcuts-card',
        'about-welcome-tour-card',
        'about-privacy-policy-card',
      ]),
    );
    expect(find.text('Tour de Boas-Vindas'), findsOneWidget);

    // Toque no card de Atalhos abre o AppShortcutsDialog
    await tester.tap(find.text('Atalhos de Teclado'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Comandos rápidos de produtividade para Desktop e Web'), findsOneWidget);
  });
}

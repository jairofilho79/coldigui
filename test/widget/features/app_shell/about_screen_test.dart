import 'package:coldigui/features/app_shell/presentation/pages/about_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

void main() {
  testWidgets('renderiza AboutScreen com os cards e alvos de tutorial',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AboutScreen(),
        ),
      ),
    );

    expect(find.text('Quem somos'), findsOneWidget);
    expect(find.text('Objetivo'), findsOneWidget);

    final targets = tester.widgetList<SpotlightGuideTarget>(
      find.byType(SpotlightGuideTarget),
    );
    final targetIds = targets.map((t) => t.id).toList();
    expect(targetIds, containsAll(['about-who-we-are', 'about-mission']));
  });
}

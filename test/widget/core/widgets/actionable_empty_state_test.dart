import 'package:coldigui/core/widgets/actionable_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ActionableEmptyState', () {
    testWidgets('renderiza ícone, título e descrição', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ActionableEmptyState(
              icon: Icons.music_note,
              title: 'Título Vazio',
              description: 'Descrição de teste para orientar o usuário.',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.music_note), findsOneWidget);
      expect(find.text('Título Vazio'), findsOneWidget);
      expect(find.text('Descrição de teste para orientar o usuário.'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('executa ação primária e secundária ao tocar', (tester) async {
      var primaryCalled = false;
      var secondaryCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionableEmptyState(
              icon: Icons.star_border,
              title: 'Sem Favoritos',
              description: 'Nenhum item marcado.',
              primaryActionLabel: 'Ação Principal',
              primaryActionIcon: Icons.add,
              onPrimaryAction: () => primaryCalled = true,
              secondaryActionLabel: 'Ação Secundária',
              secondaryActionIcon: Icons.help_outline,
              onSecondaryAction: () => secondaryCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('Ação Principal'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.text('Ação Secundária'), findsOneWidget);
      expect(find.byIcon(Icons.help_outline), findsOneWidget);

      await tester.tap(find.text('Ação Principal'));
      await tester.pumpAndSettle();
      expect(primaryCalled, isTrue);

      await tester.tap(find.text('Ação Secundária'));
      await tester.pumpAndSettle();
      expect(secondaryCalled, isTrue);
    });

    testWidgets('respeita flag compact sem quebrar layout', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ActionableEmptyState(
              icon: Icons.inbox,
              title: 'Modo Compacto',
              description: 'Texto para área reduzida.',
              compact: true,
            ),
          ),
        ),
      );

      expect(find.text('Modo Compacto'), findsOneWidget);
      expect(find.text('Texto para área reduzida.'), findsOneWidget);
    });
  });
}

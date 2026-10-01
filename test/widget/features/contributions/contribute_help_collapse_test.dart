import 'package:coldigui/features/contributions/presentation/widgets/contribute_help_collapse.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/pump_app.dart';

void main() {
  testWidgets('começa fechado e exibe explicações após o toque', (tester) async {
    await pumpApp(tester, const SingleChildScrollView(child: ContributeHelpCollapse()));
    await tester.pumpAndSettle();

    expect(find.text('Precisa de ajuda?'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);

    // Fechado por padrão: descrições das categorias não estão na árvore
    expect(find.textContaining('Problemas no app'), findsNothing);
    expect(find.textContaining('Erros em louvores cadastrados'), findsNothing);

    // Toca no header para expandir
    await tester.tap(find.text('Precisa de ajuda?'));
    await tester.pumpAndSettle();

    // Aberto: explicações e todos os 5 tipos estão presentes
    expect(find.textContaining('Problemas no app'), findsOneWidget);
    expect(find.textContaining('Bug na app: '), findsOneWidget);
    expect(find.textContaining('Informação errada: '), findsOneWidget);
    expect(find.textContaining('Conteúdo: '), findsOneWidget);
    expect(find.textContaining('Melhoria: '), findsOneWidget);
    expect(find.textContaining('Outro: '), findsOneWidget);

    // Toca novamente para fechar
    await tester.tap(find.text('Precisa de ajuda?'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Problemas no app'), findsNothing);
  });
}

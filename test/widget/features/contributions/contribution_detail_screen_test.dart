import 'package:coldigui/features/contributions/domain/entities/contribution_kind.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_summary.dart';
import 'package:coldigui/features/contributions/presentation/pages/contribution_detail_screen.dart';
import 'package:coldigui/features/contributions/presentation/providers/my_contributions_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/pump_app.dart';

ContributionSummary _metadata(Map<String, dynamic> fields) =>
    ContributionSummary(
      id: 'c1',
      kind: ContributionKind.wrongInfo,
      subkind: 'metadata',
      title: 'Metadado errado',
      body: 'Corpo da contribuição',
      status: ContributionStatus.pendente,
      decisionNote: null,
      createdAt: DateTime.utc(2026, 9, 10),
      updatedAt: DateTime.utc(2026, 9, 10),
      links: const [],
      files: const [],
      fields: fields,
    );

Future<void> _pump(WidgetTester tester, ContributionSummary item) async {
  await pumpApp(
    tester,
    ContributionDetailScreen(id: item.id),
    overrides: [
      contributionDetailProvider(item.id).overrideWith((ref) async => item),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('campo conhecido mostra «campo: atual → proposto»', (
    tester,
  ) async {
    await _pump(
      tester,
      _metadata({'field': 'tonality', 'current': 'Dm', 'proposed': 'Em'}),
    );

    expect(find.text('Tom: Dm → Em'), findsOneWidget);
  });

  testWidgets(
    'contribuição antiga com field «category» abre sem a linha de metadado',
    (tester) async {
      await _pump(
        tester,
        _metadata({
          'field': 'category',
          'current': 'Clamor',
          'proposed': 'Louvor',
        }),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Metadado errado'), findsOneWidget);
      expect(find.text('Corpo da contribuição'), findsOneWidget);
      expect(find.textContaining('Clamor'), findsNothing);
      expect(find.textContaining('→'), findsNothing);
    },
  );
}

import 'package:coldigui/features/app_shell/presentation/pages/missing_api_config_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('lista cada define ausente e o comando de reinstalação', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MissingApiConfigScreen(
          missingDefines: ['PLPCG_API_BASE_URL', 'COLDIGOM_API_BASE_URL'],
        ),
      ),
    );

    expect(find.textContaining('PLPCG_API_BASE_URL'), findsOneWidget);
    expect(find.textContaining('COLDIGOM_API_BASE_URL'), findsOneWidget);
    expect(
      find.textContaining('--dart-define-from-file=dart_defines/plpcg.json'),
      findsOneWidget,
    );
  });

  testWidgets('com um só define ausente só ele aparece', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MissingApiConfigScreen(missingDefines: ['COLDIGOM_API_BASE_URL']),
      ),
    );

    expect(find.textContaining('COLDIGOM_API_BASE_URL'), findsOneWidget);
    expect(find.textContaining('PLPCG_API_BASE_URL'), findsNothing);
  });
}

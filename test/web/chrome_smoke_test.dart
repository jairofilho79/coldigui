@TestOn('browser')
library;

import 'package:coldigui/core/constants/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Smoke mínimo para `flutter test --platform chrome` (D9, Fase 7).
///
/// Expansão futura: boot com [ColdiguiApp], catálogo e PDF remoto com mocks.
void main() {
  group('chrome smoke', () {
    test('executa no target web', () {
      expect(kIsWeb, isTrue);
    });

    test('PLPCG_API_BASE_URL injetado no build de teste', () {
      expect(AppConfig.isApiBaseUrlMissing, isFalse);
      expect(AppConfig.apiBaseUrl, isNotEmpty);
    });

    testWidgets('renderiza widget Material básico', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('PLPCG web smoke'))),
      );
      expect(find.text('PLPCG web smoke'), findsOneWidget);
    });
  });
}

import 'package:coldigui/core/constants/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Smoke mínimo para `flutter test --platform chrome` (D9, Fase 7).
///
/// Expansão futura: boot com [ColdiguiApp], catálogo e PDF remoto com mocks.
void main() {
  // DÍVIDA TÉCNICA (skip condicional, documentado em 2026-09-13 — polimento):
  // estes 3 testes só têm sentido compilados para a web e por isso aparecem
  // como «skipped» em todo `flutter test` no VM (a rotina local). Eles rodam
  // de verdade só em `flutter test --platform chrome test/web/` — hoje apenas
  // no CI (`.github/workflows/web.yml`); a auditoria de 2026-09 registrou que
  // essa execução «não foi re-executada» nas últimas ondas localmente. Sanar
  // num polimento futuro: incluir o alvo Chrome no script de verificação
  // local (ou numa tag `@Tags(['web'])` filtrada por `--exclude-tags`) para
  // que a suíte VM não liste skips que ninguém confere.
  final skipOnVm = !kIsWeb;

  group('chrome smoke', () {
    test('executa no target web', () {
      expect(kIsWeb, isTrue);
    }, skip: skipOnVm);

    test('PLPCG_API_BASE_URL injetado no build de teste', () {
      expect(AppConfig.isApiBaseUrlMissing, isFalse);
      expect(AppConfig.apiBaseUrl, isNotEmpty);
    }, skip: skipOnVm);

    testWidgets('renderiza widget Material básico', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('PLPCG web smoke'))),
      );
      expect(find.text('PLPCG web smoke'), findsOneWidget);
    }, skip: skipOnVm);
  });
}

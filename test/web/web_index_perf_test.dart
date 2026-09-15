@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Valida instrumentação de performance em [web/index.html] (Fase H).
///
/// Timing real do cold start é medido por [scripts/measure_web_boot.py],
/// não pelo harness `flutter test --platform chrome`.
void main() {
  late String html;

  setUp(() {
    html = File('web/index.html').readAsStringSync();
  });

  test('contém splash loader HTML', () {
    expect(html, contains('id="loading"'));
    expect(html, contains('#4B2D2B'));
    expect(html, contains('#D4AF37'));
  });

  test('remove loader no flutter-first-frame', () {
    expect(html, contains("'flutter-first-frame'"));
  });

  test('exporta window.__plpcgPerf', () {
    expect(html, contains('window.__plpcgPerf'));
    expect(html, contains('plpcg-perf-ready'));
    expect(html, contains('plpcg-loader-visible'));
    expect(html, contains('plpcg-first-frame'));
  });

  test('preload de WASM críticos (Fase E)', () {
    expect(html, contains('rel="preload" href="main.dart.wasm"'));
    expect(html, contains('rel="preload" href="isar_plus.wasm"'));
  });

  test('preload adaptativo de skwasm (C1)', () {
    expect(html, isNot(contains('rel="preload" href="canvaskit/skwasm.wasm"')));
    expect(html, contains('supportsSkwasmPreload'));
    expect(html, contains('rendererPreload'));
    expect(html, contains('canvaskit/skwasm.wasm'));
  });

  test(
    'avisa depois de 15s sem rede e sem o loader ter saído (Important 3)',
    () {
      // Offline sem o engine em cache o flutter-first-frame nunca chega: sem
      // isto o loader gira para sempre.
      expect(html, contains('window.setTimeout(function () {'));
      expect(html, contains('15000'));
      expect(html, contains('navigator.onLine !== false'));
      expect(
        html,
        contains(
          'Sem ligação — abra o app online uma vez para poder usá-lo offline.',
        ),
      );
    },
  );
}

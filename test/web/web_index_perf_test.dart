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
}

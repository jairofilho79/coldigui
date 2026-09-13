// test/web/web_headers_test.dart
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `web/_headers` é o que o Cloudflare Pages serve. Com o login por redirect
/// (spec D12) o COOP tem de ser `same-origin` exato: `same-origin-allow-popups`
/// desliga `crossOriginIsolated` e volta o skwasm para single-thread (P1).
void main() {
  late List<String> lines;

  setUp(() {
    lines = File('web/_headers')
        .readAsLinesSync()
        .map((l) => l.trim())
        .toList();
  });

  test('COOP same-origin exato', () {
    expect(lines, contains('Cross-Origin-Opener-Policy: same-origin'));
    expect(lines.where((l) => l.contains('allow-popups')), isEmpty);
  });

  test('COEP require-corp', () {
    expect(lines, contains('Cross-Origin-Embedder-Policy: require-corp'));
  });

  test('servidor local envia o mesmo COOP', () {
    final py = File('scripts/web_frontend_server.py').readAsStringSync();
    expect(py, contains('"Cross-Origin-Opener-Policy", "same-origin"'));
    expect(py, isNot(contains('allow-popups')));
  });
}

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

  test('sw.js é no-cache no _headers (registo por ?v=<tag>)', () {
    // A tag na query só deteta SW novo se o próprio sw.js não ficar preso
    // na CDN: o SW velho continuaria a servir o shell velho.
    final at = lines.indexOf('/sw.js');
    expect(at, greaterThan(0), reason: 'falta a regra /sw.js');
    expect(lines[at + 1], 'Cache-Control: no-cache');
  });

  test('servidor local espelha o no-cache do sw.js', () {
    final py = File('scripts/web_frontend_server.py').readAsStringSync();
    expect(py, contains('"sw.js",'));
  });

  test('verify_web_headers_artifact.sh rejeita _headers sem /sw.js', () async {
    final tmp = Directory.systemTemp.createTempSync('headers_test');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final headers = File('${tmp.path}/_headers')
      ..writeAsStringSync(
        File('web/_headers')
            .readAsStringSync()
            .replaceFirst('/sw.js\n  Cache-Control: no-cache\n', ''),
      );
    final result = await Process.run('bash', [
      'scripts/verify_web_headers_artifact.sh',
      headers.path,
    ]);
    expect(result.exitCode, isNot(0));
  });
}

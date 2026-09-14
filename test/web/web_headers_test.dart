// test/web/web_headers_test.dart
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/web_build_fixture.dart';

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
    // build/web precisa de sw.js e index.html sem placeholders (o verify já
    // os exige): sem passar pelo cache-bust, a falha seria por eles faltarem
    // e não pela regra /sw.js em si — deixava de discriminar o caso do teste.
    final tmp = Directory.systemTemp.createTempSync('headers_test');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final webDir = Directory('${tmp.path}/web')..createSync();
    writeFixtureWebBuild(webDir);
    final busted = await Process.run('bash', [
      'scripts/cache_bust_web_entrypoints.sh',
      webDir.path,
    ]);
    expect(busted.exitCode, 0, reason: '${busted.stdout}\n${busted.stderr}');

    final headersFile = File('${webDir.path}/_headers');
    headersFile.writeAsStringSync(
      headersFile.readAsStringSync().replaceFirst(
        '/sw.js\n  Cache-Control: no-cache\n',
        '',
      ),
    );
    final result = await Process.run('bash', [
      'scripts/verify_web_headers_artifact.sh',
      headersFile.path,
    ]);
    expect(result.exitCode, isNot(0));
  });

  test(
    'verify_web_headers_artifact.sh aceita _headers com /sw.js e build pronto',
    () async {
      final tmp = Directory.systemTemp.createTempSync('headers_test_ok');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final webDir = Directory('${tmp.path}/web')..createSync();
      writeFixtureWebBuild(webDir);
      final busted = await Process.run('bash', [
        'scripts/cache_bust_web_entrypoints.sh',
        webDir.path,
      ]);
      expect(busted.exitCode, 0, reason: '${busted.stdout}\n${busted.stderr}');

      final result = await Process.run('bash', [
        'scripts/verify_web_headers_artifact.sh',
        '${webDir.path}/_headers',
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    },
  );
}

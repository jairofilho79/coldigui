@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garante a forma do template `web/sw.js` que `scripts/generate_sw_manifest.py`
/// preenche e o contrato com o Dart (nunca tocar no cache dos PDFs offline).
/// O comportamento em runtime é provado por `scripts/verify_web_sw.py`.
void main() {
  late String sw;

  setUp(() {
    sw = File('web/sw.js').readAsStringSync();
  });

  int count(String needle) => needle.allMatches(sw).length;

  test('placeholders exatamente uma vez cada', () {
    expect(sw, contains("const TAG = '__PLPCG_TAG__';"));
    expect(sw, contains('const CRITICAL = __PLPCG_CRITICAL__;'));
    expect(sw, contains('const WARM = __PLPCG_WARM__;'));
    expect(count('__PLPCG_TAG__'), 1);
    expect(count('__PLPCG_CRITICAL__'), 1);
    expect(count('__PLPCG_WARM__'), 1);
  });

  test('um cache por tag, skipWaiting e claim', () {
    expect(sw, contains('plpcg-shell-'));
    expect(sw, contains('self.skipWaiting()'));
    expect(sw, contains('self.clients.claim()'));
    expect(sw, contains('caches.delete('));
  });

  test('só GET same-origin; navegação network-first; warm por mensagem', () {
    expect(sw, contains("request.method !== 'GET'"));
    expect(sw, contains('url.origin !== self.location.origin'));
    expect(sw, contains("request.mode === 'navigate'"));
    expect(sw, contains("event.data.type !== 'warm'"));
  });

  test('warm aquece a lista used da página e só percorre WARM com full', () {
    // O engine (main.dart.*, canvaskit/<hash>/) não está em nenhuma lista:
    // é a página que diz o que carregou, e só isso entra no cache.
    expect(sw, contains('event.data.used'));
    expect(sw, contains('event.data.full'));
    expect(sw, contains('async function warm(used, full)'));
    expect(sw, contains('if (!full) return;'));
    expect(sw, contains("cache: 'force-cache'"));
  });

  test('mensagem warm de tag antiga descarta used mas mantém WARM', () {
    // Deploy a meio de sessão: a página antiga ainda manda a tag dela — o
    // `used` seria de outra cache e tem de ser descartado (Minor a).
    expect(sw, contains('event.data.tag && event.data.tag !== TAG'));
  });

  test('cache-first restrito ao shell; resto same-origin sem respondWith', () {
    // Important 1: cacheFirst deixou de ser catch-all para qualquer GET
    // same-origin — só assets/, canvaskit/, icons/ e ficheiros na raiz do
    // scope com ?v= ou listados em CRITICAL/WARM.
    expect(sw, contains("SCOPE_PATH + 'assets/'"));
    expect(sw, contains("SCOPE_PATH + 'canvaskit/'"));
    expect(sw, contains("SCOPE_PATH + 'icons/'"));
    expect(sw, contains('sem respondWith'));
  });

  test('nunca apaga o cache dos PDFs offline do Dart', () {
    expect(sw, isNot(contains('plpcg-pdfs-store')));
    expect(sw, contains("startsWith('plpcg-shell-')"));
  });

  test('flutter_bootstrap.js não regista o stub do Flutter', () {
    // O stub flutter_service_worker.js faz unregister + client.navigate:
    // no mesmo scope que o sw.js seria um loop de reload a cada boot.
    final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();
    expect(bootstrap, isNot(contains('serviceWorkerSettings')));
    expect(bootstrap, contains('wasmAllowList: { webkit: true }'));
  });
}

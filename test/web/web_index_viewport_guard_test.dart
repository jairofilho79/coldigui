@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guarda do tamanho da tela em [web/index.html] (barra de navegação de
/// baixo «cortada» ao abrir o PWA).
///
/// O script roda de verdade no Node, com um DOM mínimo falso: o que
/// importa é o comportamento (quando dispara o `resize` sintético no
/// `visualViewport`), não a presença de strings.
void main() {
  final hasNode = Process.runSync('which', ['node']).exitCode == 0;

  late String guard;

  setUpAll(() {
    final html = File('web/index.html').readAsStringSync();
    final match = RegExp(
      r'<script id="plpcg-viewport-guard">([\s\S]*?)</script>',
    ).firstMatch(html);
    expect(match, isNotNull, reason: 'script plpcg-viewport-guard ausente');
    guard = match!.group(1)!;
  });

  /// Roda [scenario] (JS) depois do guarda, com o DOM falso de [_harness], e
  /// devolve o JSON que o cenário imprimir.
  Future<Map<String, dynamic>> run(String scenario) async {
    final dir = await Directory.systemTemp.createTemp('viewport_guard');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/run.js')
      ..writeAsStringSync('$_harness\n$guard\n$scenario');
    final result = await Process.run('node', [file.path]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    final lines = const LineSplitter().convert('${result.stdout}'.trim());
    return jsonDecode(lines.last) as Map<String, dynamic>;
  }

  group('viewport guard', skip: hasNode ? false : 'node ausente', () {
    test('flutter-view mais alto que a página → re-medição', () async {
      final out = await run('''
        view.style.height = '900px';
        root.clientHeight = 850;
        fire(window, 'flutter-first-frame');
        flush();
        report();
      ''');
      expect(out['resizes'], 1);
      expect(out['heals'], 1);
    });

    test('tamanhos batem → nada', () async {
      final out = await run('''
        fire(window, 'flutter-first-frame');
        fire(window, 'resize');
        fire(document, 'visibilitychange');
        flush();
        report();
      ''');
      expect(out['resizes'], 0);
    });

    test('antes do primeiro frame (sem style.height) → nada', () async {
      final out = await run('''
        view.style.height = '';
        root.clientHeight = 850;
        fire(window, 'resize');
        flush();
        report();
      ''');
      expect(out['resizes'], 0);
    });

    test('não insiste no mesmo par de medidas', () async {
      // Engine re-mediu e chegou ao mesmo valor (ex.: Android mede o
      // visualViewport): sem loop de resize.
      final out = await run('''
        view.style.height = '900px';
        root.clientHeight = 850;
        fire(window, 'flutter-first-frame');
        fire(window, 'resize');
        fire(document, 'visibilitychange');
        flush();
        report();
      ''');
      expect(out['resizes'], 1);
    });

    test('volta a corrigir quando a divergência muda', () async {
      final out = await run('''
        view.style.height = '900px';
        root.clientHeight = 850;
        fire(window, 'flutter-first-frame');
        flush();
        root.clientHeight = 800;
        fire(window, 'resize');
        flush();
        report();
      ''');
      expect(out['resizes'], 2);
    });

    test('com campo em edição espera o fim da edição', () async {
      // O engine congela o tamanho enquanto edita: a correção vem no
      // focusout, quando o campo já não está focado.
      final out = await run('''
        view.style.height = '900px';
        root.clientHeight = 850;
        document.activeElement = { tagName: 'INPUT' };
        fire(window, 'resize');
        flush();
        const whileEditing = resizes;
        document.activeElement = { tagName: 'BODY' };
        fire(document, 'focusout');
        flush();
        report({ whileEditing });
      ''');
      expect(out['whileEditing'], 0);
      expect(out['resizes'], 1);
    });

    test('ao voltar para o app (visibilitychange) corrige', () async {
      final out = await run('''
        view.style.height = '900px';
        root.clientHeight = 850;
        fire(document, 'visibilitychange');
        flush();
        report();
      ''');
      expect(out['resizes'], 1);
    });

    test('ResizeObserver na página dispara a verificação', () async {
      final out = await run('''
        view.style.height = '900px';
        root.clientHeight = 850;
        observers.forEach((cb) => cb());
        flush();
        report();
      ''');
      expect(out['resizes'], 1);
    });
  });
}

/// DOM mínimo: timers manuais ([flush]), eventos por alvo e um
/// `visualViewport` que conta os `resize` recebidos.
const _harness = r'''
const listeners = new Map();
function on(target, type, cb) {
  const key = target.__id + ':' + type;
  if (!listeners.has(key)) listeners.set(key, []);
  listeners.get(key).push(cb);
}
function fire(target, type) {
  (listeners.get(target.__id + ':' + type) || []).slice().forEach((cb) => cb({ type }));
}
let timers = [];
function flush() {
  while (timers.length) {
    const batch = timers;
    timers = [];
    batch.sort((a, b) => a.delay - b.delay).forEach((t) => t.fn());
  }
}
let resizes = 0;
const observers = [];
const view = { style: { height: '850px', width: '390px' } };
const root = { clientHeight: 850, clientWidth: 390 };
const document = {
  __id: 'document',
  documentElement: root,
  activeElement: { tagName: 'BODY' },
  visibilityState: 'visible',
  querySelector: (sel) => (sel === 'flutter-view' ? view : null),
  addEventListener: function (type, cb) { on(this, type, cb); },
};
const window = {
  __id: 'window',
  addEventListener: function (type, cb) { on(this, type, cb); },
  setTimeout: (fn, delay) => { timers.push({ fn, delay: delay || 0 }); },
  innerHeight: 850,
  screen: { height: 844 },
  visualViewport: {
    height: 850,
    dispatchEvent: (e) => { if (e.type === 'resize') resizes++; return true; },
  },
};
globalThis.window = window;
globalThis.document = document;
globalThis.ResizeObserver = function (cb) {
  observers.push(cb);
  this.observe = () => {};
};
console.info = () => {};
function report(extra) {
  const state = window.__plpcgViewport || { heals: [] };
  console.log(JSON.stringify(Object.assign({ resizes, heals: state.heals.length }, extra || {})));
}
''';

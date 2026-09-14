@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Registo do service worker em [web/index.html] (spec S6, S9): só depois do
/// `flutter-first-frame`, com a tag do build, e `warm` só sem Save-Data/2g.
void main() {
  late String html;

  setUp(() {
    html = File('web/index.html').readAsStringSync();
  });

  test('regista sw.js?v=<tag> depois do handler do loader', () {
    final register = html.indexOf(
      "navigator.serviceWorker.register('sw.js?v=' + swTag)",
    );
    expect(register, greaterThan(0));
    // A tag é substituída pelo cache_bust_web_entrypoints.sh; em flutter run
    // fica o placeholder e o registo é saltado.
    expect(html, contains("var swTag = '__PLPCG_TAG__';"));
    expect(html, contains(r'/^[0-9a-f]{12}$/.test(swTag)'));

    final hideLoader = html.indexOf(
      "window.addEventListener('flutter-first-frame', hideLoader",
    );
    expect(register, greaterThan(hideLoader));
    final listener = html.lastIndexOf(
      "addEventListener('flutter-first-frame'",
      register,
    );
    expect(listener, greaterThan(hideLoader));
  });

  test('warm envia a lista used sempre e full só sem Save-Data / 2g', () {
    expect(html, contains('navigator.connection'));
    expect(html, contains('saveData'));
    expect(html, contains(r'/(^|-)2g$/'));
    expect(html, contains("performance.getEntriesByType('resource')"));
    expect(html, contains("n.indexOf(location.origin + '/') === 0"));
    expect(html, contains("{ type: 'warm', used: used, full: full }"));
    expect(html, contains("'controllerchange'"));
  });

  test('buffer de resource timing alargado antes de qualquer script', () {
    // O default (250 entradas) enche durante o boot; sem isto a lista `used`
    // perdia o engine e o app não abria offline.
    final buffer = html.indexOf('performance.setResourceTimingBufferSize(600)');
    expect(buffer, greaterThan(0));
    expect(buffer, lessThan(html.indexOf('<base href')));
    expect(buffer, lessThan(html.indexOf('supportsSkwasmPreload')));
  });
}

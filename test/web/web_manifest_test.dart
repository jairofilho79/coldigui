@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `id`/`scope` fixam a identidade do PWA instalado (spec S8): sem `id`, o
/// browser deriva-a do `start_url`, e uma mudança de query no arranque
/// passaria por um app diferente no ecrã inicial.
void main() {
  late Map<String, dynamic> manifest;

  setUp(() {
    manifest = jsonDecode(
      File('web/manifest.json').readAsStringSync(),
    ) as Map<String, dynamic>;
  });

  test('id e scope na raiz', () {
    expect(manifest['id'], '/');
    expect(manifest['scope'], '/');
  });

  test('start_url continua relativo', () {
    expect(manifest['start_url'], '.');
    expect(manifest['display'], 'standalone');
  });
}

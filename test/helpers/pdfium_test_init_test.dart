@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

import 'pdfium_test_init.dart';

void main() {
  tearDown(() => Pdfrx.pdfiumModulePath = null);

  test(
    'aponta Pdfrx.pdfiumModulePath para o pdfium de build/native_assets',
    () async {
      await ensurePdfiumTestModule();

      final path = Pdfrx.pdfiumModulePath;
      expect(path, isNotNull);
      expect(path, contains('/build/native_assets/'));
      expect(File(path!).existsSync(), isTrue);
    },
  );

  test(
    'sem a biblioteca falha na hora com instrução, em vez de travar',
    () async {
      final root = await Directory.systemTemp.createTemp('pdfium_init_');
      addTearDown(() => root.delete(recursive: true));

      await expectLater(
        ensurePdfiumTestModule(projectRoot: root.path),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('pdfium nativo ausente'), contains('flutter test')),
          ),
        ),
      );
      expect(Pdfrx.pdfiumModulePath, isNull);
    },
  );

  test('biblioteca corrompida falha na hora com instrução', () async {
    final root = await Directory.systemTemp.createTemp('pdfium_init_');
    addTearDown(() => root.delete(recursive: true));
    final os = Platform.isMacOS
        ? 'macos'
        : Platform.isLinux
        ? 'linux'
        : 'windows';
    final lib = Platform.isMacOS
        ? 'libpdfium.dylib'
        : Platform.isLinux
        ? 'libpdfium.so'
        : 'pdfium.dll';
    File('${root.path}/build/native_assets/$os/$lib')
      ..createSync(recursive: true)
      ..writeAsStringSync('nao sou uma dylib');

    await expectLater(
      ensurePdfiumTestModule(projectRoot: root.path),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('não carrega'),
        ),
      ),
    );
    expect(Pdfrx.pdfiumModulePath, isNull);
  });
}

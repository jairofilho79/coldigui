@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/web_build_fixture.dart';

/// Valida [scripts/cache_bust_web_entrypoints.sh] sobre um `build/web` mínimo.
///
/// O `_headers` serve `/canvaskit/*` como `immutable` por 1 ano e o nome dos
/// arquivos do engine (`skwasm.js`, `skwasm.wasm`…) não muda entre versões do
/// Flutter: sem hash no caminho, um upgrade de engine deixa o navegador com o
/// `skwasm.js` velho e o `main.dart.wasm` novo (LinkError no boot).
void main() {
  late Directory tmp;
  late Directory webDir;

  Future<ProcessResult> runScript() => Process.run('bash', [
    'scripts/cache_bust_web_entrypoints.sh',
    webDir.path,
  ]);

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('cache_bust_test');
    webDir = Directory('${tmp.path}/web')..createSync();
    writeFixtureWebBuild(webDir);
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  Map<String, dynamic> readVersion() =>
      jsonDecode(File('${webDir.path}/version.json').readAsStringSync())
          as Map<String, dynamic>;

  test(
    'move canvaskit/ para canvaskit/<hash>/ e reaponta loader e preload',
    () async {
      final result = await runScript();
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');

      final tag = readVersion()['canvaskit_tag'];
      expect(tag, isA<String>());
      expect(tag, matches(RegExp(r'^[0-9a-f]{12}$')));

      expect(File('${webDir.path}/canvaskit/skwasm.js').existsSync(), isFalse);
      expect(
        File('${webDir.path}/canvaskit/$tag/skwasm.js').readAsStringSync(),
        'skwasm v1',
      );
      expect(
        File('${webDir.path}/canvaskit/$tag/chromium/canvaskit.js')
            .existsSync(),
        isTrue,
      );

      final bootstrapOut = File('${webDir.path}/flutter_bootstrap.js')
          .readAsStringSync();
      expect(bootstrapOut, contains('canvasKitBaseUrl: "canvaskit/$tag"'));

      final indexOut = File('${webDir.path}/index.html').readAsStringSync();
      expect(indexOut, contains("link.href = 'canvaskit/$tag/skwasm.wasm'"));
      expect(indexOut, isNot(contains("'canvaskit/skwasm.wasm'")));
    },
  );

  test('hash do canvaskit muda quando o engine muda', () async {
    final first = await runScript();
    expect(first.exitCode, 0, reason: '${first.stdout}\n${first.stderr}');
    final tagV1 = readVersion()['canvaskit_tag'] as String;

    // Novo build: tudo plano outra vez, com skwasm.js de outro engine.
    webDir.deleteSync(recursive: true);
    webDir.createSync();
    writeFixtureWebBuild(webDir);
    writeWebFile(webDir, 'canvaskit/skwasm.js', 'skwasm v2');

    final second = await runScript();
    expect(second.exitCode, 0, reason: '${second.stdout}\n${second.stderr}');
    final tagV2 = readVersion()['canvaskit_tag'] as String;

    expect(tagV2, isNot(tagV1));
    expect(
      File('${webDir.path}/canvaskit/$tagV2/skwasm.js').readAsStringSync(),
      'skwasm v2',
    );
  });

  test(
    'mantém o cache-bust já existente dos entrypoints e do MaterialIcons',
    () async {
      final result = await runScript();
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');

      final version = readVersion();
      final tag = version['web_cache_tag'] as String;
      final bootstrapOut = File('${webDir.path}/flutter_bootstrap.js')
          .readAsStringSync();
      expect(bootstrapOut, contains('"mainWasmPath":"main.dart.wasm?v=$tag"'));

      final icons = version['material_icons_tag'] as String;
      expect(
        File('${webDir.path}/assets/fonts/MaterialIcons-Regular.$icons.otf')
            .existsSync(),
        isTrue,
      );
    },
  );
}

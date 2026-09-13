@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Valida [scripts/cache_bust_web_entrypoints.sh] sobre um `build/web` mínimo.
///
/// O `_headers` serve `/canvaskit/*` como `immutable` por 1 ano e o nome dos
/// arquivos do engine (`skwasm.js`, `skwasm.wasm`…) não muda entre versões do
/// Flutter: sem hash no caminho, um upgrade de engine deixa o navegador com o
/// `skwasm.js` velho e o `main.dart.wasm` novo (LinkError no boot).
void main() {
  late Directory tmp;
  late Directory webDir;

  const bootstrap = '''
{"engineRevision":"abc","mainWasmPath":"main.dart.wasm","jsSupportRuntimePath":"main.dart.mjs","mainJsPath":"main.dart.js"}
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit",
  },
});
''';

  const index = '''
<link rel="preload" href="main.dart.wasm" as="fetch" crossorigin>
<script>
  link.href = 'canvaskit/skwasm.wasm';
</script>
<script src="flutter_bootstrap.js" async></script>
''';

  void write(String relative, String content) {
    final file = File('${webDir.path}/$relative');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  Future<ProcessResult> runScript() => Process.run('bash', [
    'scripts/cache_bust_web_entrypoints.sh',
    webDir.path,
  ]);

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('cache_bust_test');
    webDir = Directory('${tmp.path}/web')..createSync();
    write('index.html', index);
    write('flutter_bootstrap.js', bootstrap);
    write('main.dart.js', 'js');
    write('main.dart.wasm', 'wasm');
    write('main.dart.mjs', 'mjs');
    write('version.json', '{"version":"1.0.0"}');
    write(
      'assets/FontManifest.json',
      '[{"family":"MaterialIcons","fonts":[{"asset":"fonts/MaterialIcons-Regular.otf"}]}]',
    );
    write('assets/fonts/MaterialIcons-Regular.otf', 'otf');
    write('canvaskit/skwasm.js', 'skwasm v1');
    write('canvaskit/skwasm.wasm', 'skwasm wasm v1');
    write('canvaskit/chromium/canvaskit.js', 'canvaskit chromium v1');
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

    // Novo build: canvaskit/ volta a ser plano, com skwasm.js de outro engine.
    Directory('${webDir.path}/canvaskit').deleteSync(recursive: true);
    write('canvaskit/skwasm.js', 'skwasm v2');
    write('canvaskit/skwasm.wasm', 'skwasm wasm v1');
    write('canvaskit/chromium/canvaskit.js', 'canvaskit chromium v1');
    write('index.html', index);
    write('flutter_bootstrap.js', bootstrap);
    write('assets/fonts/MaterialIcons-Regular.otf', 'otf');
    write(
      'assets/FontManifest.json',
      '[{"family":"MaterialIcons","fonts":[{"asset":"fonts/MaterialIcons-Regular.otf"}]}]',
    );

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

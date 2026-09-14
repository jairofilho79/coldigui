import 'dart:io';

/// `build/web` mínimo para os testes dos scripts de pós-build
/// (`cache_bust_web_entrypoints.sh` + `generate_sw_manifest.py`).
///
/// Tem tudo o que o gerador do service worker exige em `CRITICAL`: sem um
/// destes ficheiros o script falha de propósito (spec §3.2). Os conteúdos são
/// marcadores curtos — os testes só olham para nomes, tags e listas.
const kFixtureBootstrap = '''
{"engineRevision":"abc","mainWasmPath":"main.dart.wasm","jsSupportRuntimePath":"main.dart.mjs","mainJsPath":"main.dart.js"}
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit",
  },
});
''';

const kFixtureIndex = '''
<link rel="preload" href="main.dart.wasm" as="fetch" crossorigin>
<script>
  link.href = 'canvaskit/skwasm.wasm';
</script>
<script>
  var swTag = '__PLPCG_TAG__';
  navigator.serviceWorker.register('sw.js?v=' + swTag);
</script>
<script src="flutter_bootstrap.js" async></script>
''';

void writeWebFile(Directory webDir, String relative, String content) {
  final file = File('${webDir.path}/$relative');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

/// Engine plano (`canvaskit/` sem hash), como sai do `flutter build web`:
/// duas variantes (o gerador tem de deixar todas fora das listas) e um
/// `.symbols` que também nunca entra.
void writeFixtureCanvaskit(Directory webDir, {String skwasmJs = 'skwasm v1'}) {
  writeWebFile(webDir, 'canvaskit/skwasm.js', skwasmJs);
  writeWebFile(webDir, 'canvaskit/skwasm.wasm', 'skwasm wasm v1');
  writeWebFile(webDir, 'canvaskit/skwasm.js.symbols', 'symbols');
  writeWebFile(
    webDir,
    'canvaskit/chromium/canvaskit.js',
    'canvaskit chromium v1',
  );
  writeWebFile(
    webDir,
    'canvaskit/chromium/canvaskit.wasm',
    'canvaskit chromium wasm v1',
  );
}

/// Escreve o build inteiro (entrypoints, engine, assets, `sw.js` real e
/// `_headers` real). Chamar de novo depois de apagar a pasta para simular um
/// build novo.
void writeFixtureWebBuild(Directory webDir) {
  writeWebFile(webDir, 'index.html', kFixtureIndex);
  writeWebFile(webDir, 'flutter_bootstrap.js', kFixtureBootstrap);
  writeWebFile(webDir, 'flutter.js', 'flutter js');
  writeWebFile(webDir, 'main.dart.js', 'js');
  writeWebFile(webDir, 'main.dart.wasm', 'wasm');
  writeWebFile(webDir, 'main.dart.mjs', 'mjs');
  writeWebFile(webDir, 'isar_plus.js', 'isar js');
  writeWebFile(webDir, 'isar_plus.wasm', 'isar wasm');
  writeWebFile(webDir, 'manifest.json', '{"id":"/"}');
  writeWebFile(webDir, 'version.json', '{"version":"1.0.0"}');
  writeWebFile(webDir, 'flutter_service_worker.js', 'stub');
  writeWebFile(webDir, '.last_build_id', 'abc');
  writeWebFile(webDir, '_headers', File('web/_headers').readAsStringSync());
  writeWebFile(webDir, 'sw.js', File('web/sw.js').readAsStringSync());
  writeWebFile(webDir, 'favicon.png', 'png');
  writeWebFile(webDir, 'icons/Icon-192.png', 'png');
  writeWebFile(webDir, 'assets/AssetManifest.bin', 'bin');
  writeWebFile(webDir, 'assets/AssetManifest.bin.json', '"bin"');
  writeWebFile(
    webDir,
    'assets/FontManifest.json',
    '[{"family":"MaterialIcons","fonts":[{"asset":"fonts/MaterialIcons-Regular.otf"}]}]',
  );
  writeWebFile(webDir, 'assets/fonts/MaterialIcons-Regular.otf', 'otf');
  // Nome literal com %5B: é assim que o Flutter grava a fonte variável.
  writeWebFile(webDir, 'assets/assets/fonts/EBGaramond%5Bwght%5D.ttf', 'ttf');
  writeWebFile(webDir, 'assets/assets/branding/logo.svg', '<svg/>');
  writeWebFile(webDir, 'assets/NOTICES', 'notices');
  writeWebFile(webDir, 'assets/packages/pdfrx/assets/pdfium.wasm', 'pdfium');
  writeWebFile(webDir, 'main_deferred.part.js', 'chunk');
  writeFixtureCanvaskit(webDir);
}

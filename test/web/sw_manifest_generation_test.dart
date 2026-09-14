@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/web_build_fixture.dart';

/// Valida `scripts/generate_sw_manifest.py` (chamado por
/// `cache_bust_web_entrypoints.sh`) sobre um `build/web` mínimo: as listas
/// `CRITICAL`/`WARM` do `sw.js`, o engine fora das duas (é a página que diz
/// ao SW qual variante carregou), a substituição dos placeholders e a falha
/// quando um ficheiro crítico não existe (spec §3.2, §5; plano P1).
void main() {
  late Directory tmp;
  late Directory webDir;

  Future<ProcessResult> runScript() => Process.run('bash', [
    'scripts/cache_bust_web_entrypoints.sh',
    webDir.path,
  ]);

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('sw_manifest_test');
    webDir = Directory('${tmp.path}/web')..createSync();
    writeFixtureWebBuild(webDir);
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  Map<String, dynamic> readVersion() =>
      jsonDecode(File('${webDir.path}/version.json').readAsStringSync())
          as Map<String, dynamic>;

  String readSw() => File('${webDir.path}/sw.js').readAsStringSync();

  /// Extrai o array JSON atribuído a `const <name> = [...];` no sw.js gerado.
  List<String> listFromSw(String sw, String name) {
    final match = RegExp('const $name = (\\[.*?\\]);').firstMatch(sw);
    expect(match, isNotNull, reason: 'sw.js sem const $name = [...]');
    return (jsonDecode(match!.group(1)!) as List).cast<String>();
  }

  test(
    'substitui os placeholders e CRITICAL cobre o shell sem o engine',
    () async {
      final result = await runScript();
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');

      final version = readVersion();
      final tag = version['web_cache_tag'] as String;
      final icons = version['material_icons_tag'] as String;

      final sw = readSw();
      expect(sw, isNot(contains('__PLPCG_')));
      expect(sw, contains("const TAG = '$tag';"));

      final critical = listFromSw(sw, 'CRITICAL');
      expect(critical.first, './');
      expect(
        critical,
        containsAll([
          'flutter_bootstrap.js?v=$tag',
          'flutter.js',
          'isar_plus.js',
          'isar_plus.wasm',
          'manifest.json',
          'version.json',
          'assets/FontManifest.json',
          'assets/AssetManifest.bin.json',
          'assets/AssetManifest.bin',
          'assets/fonts/MaterialIcons-Regular.$icons.otf?v=$tag',
          // %5B no disco → %255B no URL: é o que o engine pede (FontManifest).
          'assets/assets/fonts/EBGaramond%255Bwght%255D.ttf',
          'icons/Icon-192.png',
          'favicon.png',
        ]),
      );
      expect(
        critical.toSet().length,
        critical.length,
        reason: 'sem duplicados',
      );
      expect(result.stdout, contains('CRITICAL='));
      expect(result.stdout, contains('WARM='));
      expect(result.stdout, contains('ENGINE fora das listas='));
    },
  );

  test('engine (main.dart.* e canvaskit/) fica fora das duas listas', () async {
    // A variante do engine é escolhida por browser pelo flutter_bootstrap.js;
    // só a usada entra no cache, via a lista `used` que o index.html envia.
    final result = await runScript();
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');

    final sw = readSw();
    final ck = readVersion()['canvaskit_tag'] as String;
    final all = [...listFromSw(sw, 'CRITICAL'), ...listFromSw(sw, 'WARM')];
    expect(all.where((u) => u.startsWith('main.dart.')), isEmpty);
    expect(all.where((u) => u.startsWith('canvaskit/')), isEmpty);
    // O engine existe no build (o cache-bust moveu-o para canvaskit/<hash>/):
    // não está nas listas por decisão, não por ausência.
    expect(
      File('${webDir.path}/canvaskit/$ck/skwasm.wasm').existsSync(),
      isTrue,
    );
    expect(File('${webDir.path}/main.dart.wasm').existsSync(), isTrue);
  });

  test(
    'WARM tem o resto carregável e exclui SW, stub, symbols e metadados',
    () async {
      final result = await runScript();
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');

      final sw = readSw();
      final critical = listFromSw(sw, 'CRITICAL');
      final warm = listFromSw(sw, 'WARM');
      expect(
        warm,
        containsAll([
          'assets/assets/branding/logo.svg',
          'assets/NOTICES',
          'assets/packages/pdfrx/assets/pdfium.wasm',
          'main_deferred.part.js',
        ]),
      );
      for (final excluded in [
        'sw.js',
        'flutter_service_worker.js',
        '.last_build_id',
        '_headers',
        '.symbols',
      ]) {
        expect(
          [...critical, ...warm].where((u) => u.endsWith(excluded)),
          isEmpty,
          reason: '$excluded não pode entrar em nenhuma lista',
        );
      }
      expect(critical.toSet().intersection(warm.toSet()), isEmpty);
    },
  );

  test('ficheiro crítico ausente faz o pós-build falhar', () async {
    // isar_plus.wasm continua em CRITICAL e o cache-bust não o exige (só o
    // gerador): a falha vem mesmo da verificação das listas.
    File('${webDir.path}/isar_plus.wasm').deleteSync();
    final result = await runScript();
    expect(result.exitCode, isNot(0));
    expect('${result.stdout}${result.stderr}', contains('isar_plus.wasm'));
  });

  test(
    'sw.js sem placeholders (build já processado) faz o pós-build falhar',
    () async {
      writeWebFile(webDir, 'sw.js', "const TAG = 'x';");
      final result = await runScript();
      expect(result.exitCode, isNot(0));
      // O gerador acusa o primeiro placeholder em falta (__PLPCG_TAG__).
      expect('${result.stdout}${result.stderr}', contains('sem placeholder'));
    },
  );
}

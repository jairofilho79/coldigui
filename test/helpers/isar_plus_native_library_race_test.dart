@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reproduz a race de `flutter test` em worktree novo: vários processos
/// `flutter_tester` chamam `ensureIsarPlusTestCore()` ao mesmo tempo sobre um
/// `.dart_tool/isar_plus_test/` vazio. Aqui são [_processes] processos `dart`
/// rodando `isar_plus_native_library.dart` contra um diretório temporário
/// vazio — reproduzia «libisar_plus.a ausente após extração do xcframework».
///
/// O zip do xcframework já baixado é copiado para o diretório temporário para
/// não depender de rede aqui (o próprio `flutter_test_config` já o garantiu).
void main() {
  const processes = 6;

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('isar_plus_race_');
    final cachedZip = File(
      '${Directory.current.path}/.dart_tool/isar_plus_test/'
      'isar_plus_core.xcframework.zip',
    );
    if (cachedZip.existsSync()) {
      cachedZip.copySync('${tempDir.path}/isar_plus_core.xcframework.zip');
    }
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('$processes processos concorrentes sobre diretório vazio '
      'produzem um único binário válido e nenhum resíduo', () async {
    final script = File(
      '${Directory.current.path}/test/helpers/isar_plus_native_library.dart',
    );
    expect(script.existsSync(), isTrue, reason: 'script alvo: ${script.path}');

    final started = await Future.wait(
      List.generate(processes, (_) {
        return Process.start(
          _dartExecutable(),
          [script.path, tempDir.path],
          workingDirectory: Directory.current.path,
          runInShell: Platform.isWindows,
        );
      }),
    );

    final results = await Future.wait(
      started.map((p) async {
        final stdoutFuture = p.stdout.transform(systemEncoding.decoder).join();
        final stderrFuture = p.stderr.transform(systemEncoding.decoder).join();
        final code = await p.exitCode;
        return (
          code: code,
          stdout: await stdoutFuture,
          stderr: await stderrFuture,
        );
      }),
    );

    for (final (i, r) in results.indexed) {
      expect(
        r.code,
        0,
        reason: 'processo #$i falhou:\n${r.stdout}\n${r.stderr}',
      );
    }

    final reportedPaths = results.map((r) => r.stdout.trim()).toSet();
    expect(reportedPaths, hasLength(1));
    final library = File(reportedPaths.single);
    expect(library.existsSync(), isTrue);
    expect(library.lengthSync(), greaterThan(0));

    final leftovers = tempDir
        .listSync()
        .map((e) => e.uri.pathSegments.lastWhere((s) => s.isNotEmpty))
        .where((name) => name != library.uri.pathSegments.last)
        .where((name) => !name.endsWith('.zip'))
        .where((name) => !name.endsWith('.lock'))
        .toList();
    expect(leftovers, isEmpty, reason: 'resíduos de extração/lock');
  }, timeout: const Timeout(Duration(minutes: 3)));
}

String _dartExecutable() {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final candidate = File('$root/bin/dart');
    if (candidate.existsSync()) return candidate.path;
  }
  return 'dart';
}

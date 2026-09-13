// Dart puro (sem Flutter): usado também por scripts executados como processos
// filhos (ver isar_plus_native_library_race_test.dart).
import 'dart:io';
import 'dart:math';

/// Garante um artefato nativo `[libDir]/[fileName]` produzido por [build] e
/// devolve o caminho dele.
///
/// Seguro sob concorrência entre processos (`flutter test` dispara um
/// `flutter_tester` por arquivo; num worktree novo todos chegam aqui juntos):
/// - só o arquivo final em [libDir] conta como "pronto" — nunca um diretório
///   ou arquivo intermediário, que pode estar pela metade;
/// - um lock exclusivo (`[fileName].lock`, `fcntl`/`LockFileEx`) serializa
///   quem produz; os demais esperam e encontram o artefato pronto;
/// - [build] trabalha num diretório `.work_<pid>_<rand>/` próprio do processo
///   e o resultado entra em [libDir] por `rename` (atômico no mesmo sistema de
///   arquivos), então um crash no meio nunca deixa artefato corrompido no
///   caminho final.
///
/// [build] recebe o diretório de trabalho (já criado, apagado ao fim) e deve
/// devolver o arquivo pronto dentro dele. É chamado com o lock em mãos, então
/// pode também popular caches auxiliares em [libDir] — usando rename.
Future<String> ensureNativeTestArtifact({
  required Directory libDir,
  required String fileName,
  required Future<File> Function(Directory work) build,
}) async {
  final target = File('${libDir.path}/$fileName');
  if (target.existsSync()) return target.path;

  libDir.createSync(recursive: true);
  final lock = File(
    '${libDir.path}/$fileName.lock',
  ).openSync(mode: FileMode.write);
  try {
    await lock.lock(FileLock.blockingExclusive);
    // Outro processo pode ter produzido enquanto esperávamos o lock.
    if (target.existsSync()) return target.path;

    final work = Directory(
      '${libDir.path}/.work_${pid}_${Random().nextInt(1 << 32)}',
    )..createSync();
    try {
      final built = await build(work);
      built.renameSync(target.path);
    } finally {
      if (work.existsSync()) work.deleteSync(recursive: true);
    }
    return target.path;
  } finally {
    await lock.unlock();
    await lock.close();
  }
}

/// Baixa [url] para [destination] (via `curl`, sempre presente em macOS/CI).
Future<void> downloadToFile(String url, File destination) async {
  final result = await Process.run('curl', [
    '-fsSL',
    url,
    '-o',
    destination.path,
  ]);
  if (result.exitCode != 0) {
    throw StateError('Download falhou ($url): ${result.stderr}');
  }
}

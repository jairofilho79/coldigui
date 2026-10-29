// Dart puro (sem Flutter): também é executado como script por processos
// filhos em isar_plus_native_library_race_test.dart.
import 'dart:io';

import 'package:archive/archive.dart';

import 'native_test_artifact.dart';

const _releaseTag = 'v1.3.7';
const _baseUrl =
    'https://github.com/ahmtydn/isar_plus/releases/download/$_releaseTag';

/// Garante o binário nativo isar_plus em [libDir] e devolve o caminho dele.
/// Seguro sob concorrência entre processos — ver [ensureNativeTestArtifact].
Future<String> ensureIsarPlusNativeLibrary(Directory libDir) {
  return ensureNativeTestArtifact(
    libDir: libDir,
    fileName: _libraryFileName(),
    build: (work) => _build(libDir, work),
  );
}

String _libraryFileName() {
  if (Platform.isMacOS) return 'libisar_plus.dylib';
  if (Platform.isLinux) return 'libisar_plus.so';
  if (Platform.isWindows) return 'isar_plus.dll';
  throw UnsupportedError(
    'Testes Isar não suportados em ${Platform.operatingSystem}. '
    'Use macOS, Linux ou Windows.',
  );
}

Future<File> _build(Directory libDir, Directory work) async {
  if (Platform.isMacOS) return _buildMacOsDylib(libDir, work);

  final url = Platform.isLinux
      ? '$_baseUrl/libisar_plus_linux_x64.so'
      : '$_baseUrl/isar_plus_windows_x64.dll';
  final out = File('${work.path}/${_libraryFileName()}');
  await downloadToFile(url, out);
  return out;
}

Future<File> _buildMacOsDylib(Directory libDir, Directory work) async {
  // O zip fica em cache em [libDir] (13 MB); entra lá também por rename.
  final zipFile = File('${libDir.path}/isar_plus_core.xcframework.zip');
  if (!zipFile.existsSync()) {
    final partial = File('${work.path}/isar_plus_core.xcframework.zip');
    await downloadToFile('$_baseUrl/isar_plus_core.xcframework.zip', partial);
    partial.renameSync(zipFile.path);
  }

  final extractDir = Directory('${work.path}/xcframework')..createSync();
  final archive = ZipDecoder().decodeBytes(zipFile.readAsBytesSync());
  for (final file in archive) {
    final outPath = '${extractDir.path}/${file.name}';
    if (file.isFile) {
      final out = File(outPath);
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(file.content as List<int>);
    } else {
      Directory(outPath).createSync(recursive: true);
    }
  }

  final staticLib = File(
    '${extractDir.path}/isar_plus_core.xcframework/macos-arm64_x86_64/libisar_plus.a',
  );
  if (!staticLib.existsSync()) {
    throw StateError('libisar_plus.a ausente após extração do xcframework');
  }

  final dylib = File('${work.path}/libisar_plus.dylib');
  final result = await Process.run('clang', [
    '-dynamiclib',
    '-o',
    dylib.path,
    '-Wl,-force_load,${staticLib.path}',
    '-lc++',
    '-lpthread',
    '-framework',
    'Foundation',
    '-framework',
    'Security',
  ]);
  if (result.exitCode != 0) {
    throw StateError(
      'Falha ao gerar libisar_plus.dylib para testes: ${result.stderr}',
    );
  }
  return dylib;
}

/// Ponto de entrada quando executado como processo filho:
/// `dart test/helpers/isar_plus_native_library.dart <libDir>`.
Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('uso: isar_plus_native_library.dart <libDir>');
    exitCode = 64;
    return;
  }
  stdout.writeln(await ensureIsarPlusNativeLibrary(Directory(args[0])));
}

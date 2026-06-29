import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

const _releaseTag = 'v1.3.7';
const _baseUrl =
    'https://github.com/ahmtydn/isar_plus/releases/download/$_releaseTag';

/// Garante binário nativo isar_plus para `flutter test` (VM sem plugin linkado).
Future<void> ensureIsarPlusTestCore() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  final libDir = Directory(
    '${Directory.current.path}/.dart_tool/isar_plus_test',
  );
  if (!libDir.existsSync()) {
    libDir.createSync(recursive: true);
  }

  final libPath = await _ensureNativeLibrary(libDir);
  await Isar.initialize(libPath);
}

Future<String> _ensureNativeLibrary(Directory libDir) async {
  if (Platform.isMacOS) {
    final dylib = File('${libDir.path}/libisar_plus.dylib');
    if (!dylib.existsSync()) {
      await _buildMacOsDylib(libDir);
    }
    return dylib.path;
  }

  if (Platform.isLinux) {
    final so = File('${libDir.path}/libisar_plus.so');
    if (!so.existsSync()) {
      await _download('$_baseUrl/libisar_plus_linux_x64.so', so);
    }
    return so.path;
  }

  if (Platform.isWindows) {
    final dll = File('${libDir.path}/isar_plus.dll');
    if (!dll.existsSync()) {
      await _download('$_baseUrl/isar_plus_windows_x64.dll', dll);
    }
    return dll.path;
  }

  throw UnsupportedError(
    'Testes Isar não suportados em ${Platform.operatingSystem}. '
    'Use macOS, Linux ou Windows.',
  );
}

Future<void> _buildMacOsDylib(Directory libDir) async {
  final zipFile = File('${libDir.path}/isar_plus_core.xcframework.zip');
  if (!zipFile.existsSync()) {
    await _download('$_baseUrl/isar_plus_core.xcframework.zip', zipFile);
  }

  final extractDir = Directory('${libDir.path}/xcframework');
  if (!extractDir.existsSync()) {
    extractDir.createSync(recursive: true);
    final bytes = zipFile.readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);
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
  }

  final staticLib = File(
    '${extractDir.path}/isar_plus_core.xcframework/macos-arm64_x86_64/libisar_plus.a',
  );
  if (!staticLib.existsSync()) {
    throw StateError('libisar_plus.a ausente após extração do xcframework');
  }

  final dylib = File('${libDir.path}/libisar_plus.dylib');
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
}

Future<void> _download(String url, File destination) async {
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

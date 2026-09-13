import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

import 'isar_plus_native_library.dart';

/// Garante binário nativo isar_plus para `flutter test` (VM sem plugin linkado).
///
/// A obtenção do binário (download/extração/clang) fica em
/// [ensureIsarPlusNativeLibrary], que é segura sob concorrência entre os
/// processos `flutter_tester` que `flutter test` dispara em paralelo.
Future<void> ensureIsarPlusTestCore() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  final libDir = Directory(
    '${Directory.current.path}/.dart_tool/isar_plus_test',
  );
  final libPath = await ensureIsarPlusNativeLibrary(libDir);
  await Isar.initialize(libPath);
}

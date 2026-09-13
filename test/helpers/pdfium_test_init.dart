import 'dart:ffi';
import 'dart:io';

import 'package:pdfrx/pdfrx.dart';

/// Aponta [Pdfrx.pdfiumModulePath] para o pdfium nativo que o próprio
/// `flutter test` gera em `build/native_assets/<os>/` — chamar (ex.: em
/// `setUpAll`) antes de qualquer `openDocument` num teste VM.
///
/// Por que existe: o hook de build do `pdfium_dart` roda no `flutter test` e
/// deixa a biblioteca em `build/native_assets/<os>/` (listada em
/// `native_assets.json`), mas `pdfium_dart` 0.2.5 só a procura via
/// `.dart_tool/native_assets.yaml` (convenção do `dart test`), que o Flutter
/// não gera. Sem este helper o `BackgroundWorker` do pdfrx fica pendurado até
/// o timeout de 30 s. Aqui, se a biblioteca não estiver lá ou não carregar,
/// falha na hora com [StateError] dizendo como resolver.
///
/// [projectRoot] só existe para o teste do próprio helper.
Future<void> ensurePdfiumTestModule({String? projectRoot}) async {
  if (Pdfrx.pdfiumModulePath != null) return;

  final (os, lib) = _target();
  final root = projectRoot ?? Directory.current.path;
  final path = '$root/build/native_assets/$os/$lib';
  if (!File(path).existsSync()) {
    throw StateError(
      'pdfium nativo ausente em $path. `flutter test` gera esse arquivo pelo '
      'hook de build do pdfium_dart — não rode com `--no-build-native-assets`; '
      'se persistir, apague build/native_assets/ e rode `flutter test` de novo '
      '(ou `flutter build $os --debug`).',
    );
  }
  try {
    DynamicLibrary.open(path);
  } on ArgumentError catch (e) {
    throw StateError(
      'pdfium em $path não carrega ($e). Apague build/native_assets/ e rode '
      '`flutter test` de novo para o hook baixar a biblioteca outra vez.',
    );
  }
  Pdfrx.pdfiumModulePath = path;
}

/// (`<os>` como em `build/native_assets/<os>/`, nome da biblioteca).
(String, String) _target() {
  if (Platform.isMacOS) return ('macos', 'libpdfium.dylib');
  if (Platform.isLinux) return ('linux', 'libpdfium.so');
  if (Platform.isWindows) return ('windows', 'pdfium.dll');
  throw UnsupportedError(
    'pdfium de teste não suportado em ${Platform.operatingSystem}.',
  );
}

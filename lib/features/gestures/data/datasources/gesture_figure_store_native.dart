import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart' as path_provider;

import 'gesture_figure_store.dart';

/// Assinatura de `getApplicationDocumentsDirectory`, injetável em teste.
typedef GestureFigureDirectoryGetter = Future<Directory> Function();

GestureFigureStorePort createGestureFigureStoreImpl() =>
    GestureFigureStoreNative();

/// Store nativo: `{ApplicationDocumentsDirectory}/plpcg_gestures/figures/`.
class GestureFigureStoreNative implements GestureFigureStorePort {
  GestureFigureStoreNative({
    GestureFigureDirectoryGetter? getApplicationDocumentsDirectory,
  }) : _getDocuments =
           getApplicationDocumentsDirectory ??
           path_provider.getApplicationDocumentsDirectory;

  final GestureFigureDirectoryGetter _getDocuments;
  Directory? _root;

  Future<Directory> _rootDir() async {
    final cached = _root;
    if (cached != null) return cached;
    final docs = await _getDocuments();
    final root = Directory('${docs.path}/$kGestureFigureStoreSubdir');
    if (!await root.exists()) await root.create(recursive: true);
    return _root = root;
  }

  Future<File> _fileFor(String r2Key) async =>
      File('${(await _rootDir()).path}/${gestureFigureFileName(r2Key)}');

  @override
  Future<Uint8List?> read(String r2Key) async {
    if (r2Key.trim().isEmpty) return null;
    try {
      final file = await _fileFor(r2Key);
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } on Object catch (error) {
      debugPrint('[gestos] leitura da figura $r2Key falhou: $error');
      return null;
    }
  }

  /// `.tmp` + rename: uma queda no meio da escrita não deixa PNG truncado.
  @override
  Future<void> write(String r2Key, Uint8List bytes) async {
    if (r2Key.trim().isEmpty) return;
    File? tmp;
    try {
      final file = await _fileFor(r2Key);
      tmp = File('${file.path}.tmp');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(file.path);
    } on Object catch (error) {
      debugPrint('[gestos] escrita da figura $r2Key falhou: $error');
      try {
        if (tmp != null && await tmp.exists()) await tmp.delete();
      } on Object {
        // Melhor esforço.
      }
    }
  }

  @override
  Future<void> deleteAll() async {
    try {
      final root = await _rootDir();
      if (await root.exists()) await root.delete(recursive: true);
      _root = null;
    } on Object catch (error) {
      debugPrint('[gestos] limpeza das figuras falhou: $error');
    }
  }
}

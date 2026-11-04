import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart' as path_provider;

import 'score_byte_store.dart';

ScoreByteStorePort createScoreByteStoreImpl() => ScoreByteStoreNative();

/// Store nativo: `{ApplicationDocumentsDirectory}/plpcg_scores/`.
class ScoreByteStoreNative implements ScoreByteStorePort {
  ScoreByteStoreNative({Future<Directory> Function()? documentsDirectory})
    : _getDocuments =
          documentsDirectory ?? path_provider.getApplicationDocumentsDirectory;

  final Future<Directory> Function() _getDocuments;
  Directory? _root;

  Future<Directory> _rootDir() async {
    final cached = _root;
    if (cached != null) return cached;
    final docs = await _getDocuments();
    final root = Directory('${docs.path}/$kScoreByteStoreSubdir');
    if (!await root.exists()) await root.create(recursive: true);
    return _root = root;
  }

  Future<File> _fileFor(String key) async =>
      File('${(await _rootDir()).path}/${scoreByteStoreFileName(key)}');

  @override
  Future<Uint8List?> read(String key) async {
    if (key.trim().isEmpty) return null;
    try {
      final file = await _fileFor(key);
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } on Object catch (error) {
      debugPrint('[partitura] leitura de $key falhou: $error');
      return null;
    }
  }

  @override
  Future<bool> contains(String key) async {
    if (key.trim().isEmpty) return false;
    try {
      return await (await _fileFor(key)).exists();
    } on Object catch (error) {
      debugPrint('[partitura] presença de $key falhou: $error');
      return false;
    }
  }

  @override
  Future<Set<String>> fileNames() async {
    try {
      final root = await _rootDir();
      return {
        await for (final entity in root.list())
          if (entity is File && !entity.path.endsWith('.tmp'))
            entity.uri.pathSegments.last,
      };
    } on Object catch (error) {
      debugPrint('[partitura] listagem falhou: $error');
      return const {};
    }
  }

  /// `.tmp` + rename: uma queda no meio da escrita não deixa arquivo truncado.
  @override
  Future<void> write(String key, Uint8List bytes) async {
    if (key.trim().isEmpty) return;
    File? tmp;
    try {
      final file = await _fileFor(key);
      tmp = File('${file.path}.tmp');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(file.path);
    } on Object catch (error) {
      debugPrint('[partitura] escrita de $key falhou: $error');
      try {
        if (tmp != null && await tmp.exists()) await tmp.delete();
      } on Object {
        // Melhor esforço.
      }
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      final file = await _fileFor(key);
      if (await file.exists()) await file.delete();
    } on Object catch (error) {
      debugPrint('[partitura] remoção de $key falhou: $error');
    }
  }
}

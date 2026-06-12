import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart' as path_provider;

import '../../../../core/constants/offline_config.dart';

/// Callback injetável para resolver o diretório documents (testes).
typedef GetApplicationDocumentsDirectoryFn = Future<Directory> Function();

/// Store de PDFs offline em `documents/plpcg_pdfs/` (Fase 3.1).
///
/// **Proibido** usar cache ou temp para PDFs persistentes.
class PdfLocalStore {
  PdfLocalStore({
    GetApplicationDocumentsDirectoryFn? getApplicationDocumentsDirectory,
  }) : _getApplicationDocumentsDirectory = getApplicationDocumentsDirectory ??
            path_provider.getApplicationDocumentsDirectory;

  final GetApplicationDocumentsDirectoryFn _getApplicationDocumentsDirectory;
  Directory? _root;

  /// Diretório raiz `{ApplicationDocumentsDirectory}/plpcg_pdfs/`.
  Future<Directory> get rootDirectory async {
    if (_root != null) return _root!;
    final docsDir = await _getApplicationDocumentsDirectory();
    _root = Directory(
      '${docsDir.path}/${OfflineConfig.pdfStorageSubdir}',
    );
    if (!await _root!.exists()) {
      await _root!.create(recursive: true);
    }
    return _root!;
  }

  /// Grava [bytes] em [relPath] via `.tmp` → rename atômico.
  ///
  /// Retorna path absoluto do arquivo final.
  Future<String> writeAtomic(Uint8List bytes, String relPath) async {
    final root = await rootDirectory;
    final normalizedRel = relPath.replaceAll(r'\', '/');
    final targetFile = File('${root.path}/$normalizedRel');
    final tmpFile = File('${targetFile.path}.tmp');

    final parent = targetFile.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }

    try {
      await tmpFile.writeAsBytes(bytes, flush: true);
      await tmpFile.rename(targetFile.path);
      return targetFile.path;
    } on Object {
      if (await tmpFile.exists()) {
        await tmpFile.delete();
      }
      rethrow;
    }
  }

  /// Verifica existência do arquivo em [absolutePath].
  Future<bool> exists(String absolutePath) => File(absolutePath).exists();

  /// Idempotente — ignora se o arquivo já não existir.
  Future<void> delete(String absolutePath) async {
    final file = File(absolutePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Remove a árvore `plpcg_pdfs/` e recria o diretório raiz vazio.
  Future<void> deleteTree() async {
    final root = await rootDirectory;
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
    _root = null;
    await rootDirectory;
  }

  /// PDFs no disco que não constam em [indexedAbsolutePaths] (reconcile 3.6).
  Future<List<String>> listOrphans(Set<String> indexedAbsolutePaths) async {
    final root = await rootDirectory;
    if (!await root.exists()) return const [];

    final orphans = <String>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.pdf')) continue;
      if (entity.path.endsWith('.tmp')) continue;
      if (!indexedAbsolutePaths.contains(entity.path)) {
        orphans.add(entity.path);
      }
    }
    return orphans;
  }
}

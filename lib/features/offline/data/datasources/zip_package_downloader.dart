import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/constants/offline_config.dart';
import 'pdf_local_store.dart';

/// Baixa pacotes ZIP para diretório transitório sob `plpcg_pdfs/_bulk_zips/`.
class ZipPackageDownloader {
  ZipPackageDownloader(this._dio, this._store);

  final Dio _dio;
  final PdfLocalStore _store;

  /// Baixa [url] (ex.: `/packages/Partitura-1.zip`) e retorna path absoluto local.
  ///
  /// Quando [expectedSize] é informado, reutiliza cache apenas se o tamanho
  /// no disco coincidir com o manifest.
  Future<String> download({
    required String url,
    required String filename,
    int? expectedSize,
    CancelToken? cancelToken,
  }) async {
    final zipDir = await _zipDirectory();
    final target = File('${zipDir.path}/$filename');
    final tmp = File('${target.path}.tmp');

    if (await target.exists()) {
      if (expectedSize == null) {
        return target.path;
      }
      final stat = await FileStat.stat(target.path);
      if (stat.size == expectedSize) {
        return target.path;
      }
      await target.delete();
    }

    final absoluteUrl =
        url.startsWith('http') ? url : '${AppConfig.apiBaseUrl}$url';

    try {
      await _dio.download(
        absoluteUrl,
        tmp.path,
        cancelToken: cancelToken,
      );
      await tmp.rename(target.path);
      return target.path;
    } on Object {
      if (await tmp.exists()) {
        await tmp.delete();
      }
      rethrow;
    }
  }

  /// Remove arquivos `.tmp` órfãos de downloads interrompidos (backlog #13).
  Future<void> cleanOrphanedTempFiles() async {
    final zipDir = await _zipDirectory();
    if (!await zipDir.exists()) return;

    await for (final entity in zipDir.list()) {
      if (entity is File && entity.path.endsWith('.tmp')) {
        try {
          await entity.delete();
        } on FileSystemException {
          // Arquivo pode ter sido removido concorrentemente.
        }
      }
    }
  }

  /// Remove ZIP após extração bem-sucedida.
  Future<void> deleteZip(String zipPath) async {
    final file = File(zipPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Directory> _zipDirectory() async {
    final root = await _store.rootDirectory;
    final zipDir = Directory(
      '${root.path}/${OfflineConfig.zipTempSubdir}',
    );
    if (!await zipDir.exists()) {
      await zipDir.create(recursive: true);
    }
    return zipDir;
  }
}

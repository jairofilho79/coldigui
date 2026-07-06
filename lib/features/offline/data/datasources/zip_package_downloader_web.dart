import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/constants/offline_config.dart';
import '../../../../core/utils/pdf_path_normalizer.dart';
import '../../../pdf_opening/data/datasources/pdf_bytes_datasource.dart';
import '../../domain/ports/pdf_storage_port.dart';

/// Bulk offline na web — fetch individual por PDF (Solução C, sem ZIP).
class ZipPackageDownloader {
  ZipPackageDownloader(this._dio, this._store);

  final Dio _dio;
  final PdfStoragePort _store;

  late final PdfBytesDatasource _bytesDatasource = PdfBytesDatasource(_dio);

  /// Retorna chave lógica da part sem baixar o ZIP (web baixa PDFs individualmente).
  Future<String> download({
    required String url,
    required String filename,
    int? expectedSize,
    CancelToken? cancelToken,
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    return _zipKey(filename);
  }

  /// Baixa bytes de um PDF individual a partir do [pdfId] do manifest.
  Future<Uint8List> fetchPdfBytes(String pdfId, {CancelToken? cancelToken}) {
    return _bytesDatasource.fetchBytes(
      _remotePathFromPdfId(pdfId),
      cancelToken: cancelToken,
    );
  }

  /// Legado — não usado no fluxo web Solução C.
  Future<Uint8List> readZipBytes(String zipPath) async {
    throw UnsupportedError(
      'readZipBytes não é usado na web (bulk via fetch individual)',
    );
  }

  /// No-op na web — não há ZIP em cache.
  Future<void> cleanOrphanedTempFiles() async {}

  /// No-op na web — não há ZIP em cache.
  Future<void> deleteZip(String zipPath) async {}

  Future<String> _zipKey(String filename) async {
    final rootPath = await _store.rootPath;
    return '$rootPath/${OfflineConfig.zipTempSubdir}/$filename';
  }

  static String _remotePathFromPdfId(String pdfId) {
    var relPath = PdfPathNormalizer.getPdfRelPath(pdfId);
    if (!relPath.startsWith('assets/')) {
      relPath = 'assets/$relPath';
    }
    return '/$relPath';
  }
}

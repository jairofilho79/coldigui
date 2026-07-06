import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/offline_config.dart';
import '../../../pdf_reader/data/utils/pdf_source_resolver.dart';
import 'pdf_bytes_local_reader_stub.dart'
    if (dart.library.io) 'pdf_bytes_local_reader_native.dart'
    if (dart.library.js_interop) 'pdf_bytes_local_reader_web.dart';

/// Obtém bytes PDF de origem remota, asset ou arquivo local (UC-04 Fase 2.5).
class PdfBytesDatasource {
  PdfBytesDatasource(
    this._dio, {
    PdfSourceResolver? resolver,
    AssetBundle? bundle,
  }) : _resolver = resolver ?? const PdfSourceResolver(),
       _bundle = bundle ?? rootBundle;

  final Dio _dio;
  final PdfSourceResolver _resolver;
  final AssetBundle _bundle;

  /// Baixa ou lê bytes do [filePath] (mesmas convenções de [PdfSourceResolver]).
  Future<Uint8List> fetchBytes(
    String filePath, {
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    final source = _resolver.resolve(filePath);
    return switch (source.kind) {
      PdfSourceKind.remoteUrl => _fetchRemote(
        source.value,
        onReceiveProgress: onReceiveProgress,
        cancelToken: cancelToken,
      ),
      PdfSourceKind.asset => _fetchAsset(source.value),
      PdfSourceKind.localFile => readLocalPdfBytes(source.value),
    };
  }

  Future<Uint8List> _fetchRemote(
    String url, {
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: OfflineConfig.pdfDownloadReceiveTimeout,
        sendTimeout: OfflineConfig.pdfDownloadSendTimeout,
      ),
      onReceiveProgress: onReceiveProgress,
      cancelToken: cancelToken,
    );

    final data = response.data;
    if (data == null || data.isEmpty) {
      throw Exception('Resposta PDF vazia');
    }
    return data is Uint8List ? data : Uint8List.fromList(data);
  }

  Future<Uint8List> _fetchAsset(String assetPath) async {
    final data = await _bundle.load(assetPath);
    return data.buffer.asUint8List();
  }
}

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/offline_config.dart';
import '../../../pdf_reader/data/utils/pdf_source_resolver.dart';

/// Obtém bytes PDF de origem remota, asset ou arquivo local (UC-04 Fase 2.5).
class PdfBytesDatasource {
  PdfBytesDatasource(
    this._dio, {
    PdfSourceResolver? resolver,
    AssetBundle? bundle,
  })  : _resolver = resolver ?? const PdfSourceResolver(),
        _bundle = bundle ?? rootBundle;

  final Dio _dio;
  final PdfSourceResolver _resolver;
  final AssetBundle _bundle;

  /// Baixa ou lê bytes do [filePath] (mesmas convenções de [PdfSourceResolver]).
  Future<Uint8List> fetchBytes(String filePath) async {
    final source = _resolver.resolve(filePath);
    return switch (source.kind) {
      PdfSourceKind.remoteUrl => _fetchRemote(source.value),
      PdfSourceKind.asset => _fetchAsset(source.value),
      PdfSourceKind.localFile => _fetchLocal(source.value),
    };
  }

  Future<Uint8List> _fetchRemote(String url) async {
    final response = await _dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: OfflineConfig.pdfDownloadReceiveTimeout,
        sendTimeout: OfflineConfig.pdfDownloadSendTimeout,
      ),
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

  Future<Uint8List> _fetchLocal(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('Arquivo PDF não encontrado');
    }
    return file.readAsBytes();
  }
}

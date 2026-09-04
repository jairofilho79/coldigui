import 'dart:isolate';

import 'package:archive/archive.dart' show ArchiveException;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../datasources/zip_package_downloader.dart';
import '../../domain/entities/offline_pdf_batch_item.dart';
import '../../domain/exceptions/offline_bulk_exceptions.dart';
import '../../domain/ports/pdf_storage_port.dart';
import '../utils/zip_pdf_extractor.dart';

/// Extrai o ZIP; um ZIP ilegível é apagado para não ficar preso no cache.
///
/// [ArchiveException] é subtipo de [FormatException] — as duas viram
/// [ZipCorruptedException] depois de remover o arquivo, e o usecase decide
/// baixar de novo (uma vez).
Future<ZipExtractResult> runZipExtraction({
  required ZipExtractParams params,
  required ZipPackageDownloader zipDownloader,
  required PdfStoragePort store,
  CancelToken? cancelToken,
  void Function(int extracted, int total)? onExtractProgress,
}) async {
  try {
    return await _runZipExtraction(
      params: params,
      zipDownloader: zipDownloader,
      store: store,
      cancelToken: cancelToken,
      onExtractProgress: onExtractProgress,
    );
  } on ArchiveException catch (e) {
    return _discardCorruptedZip(params.zipPath, zipDownloader, e);
  } on FormatException catch (e) {
    return _discardCorruptedZip(params.zipPath, zipDownloader, e);
  }
}

Future<Never> _discardCorruptedZip(
  String zipPath,
  ZipPackageDownloader zipDownloader,
  Object cause,
) async {
  debugPrint('[offline] ZIP corrompido descartado: $zipPath ($cause)');
  await zipDownloader.deleteZip(zipPath);
  throw ZipCorruptedException(zipPath, cause);
}

Future<ZipExtractResult> _runZipExtraction({
  required ZipExtractParams params,
  required ZipPackageDownloader zipDownloader,
  required PdfStoragePort store,
  CancelToken? cancelToken,
  void Function(int extracted, int total)? onExtractProgress,
}) async {
  if (onExtractProgress == null) {
    return compute(extractZipPdfs, params);
  }

  final receivePort = ReceivePort();
  await Isolate.spawn(extractZipPdfsIsolateEntry, [
    params,
    receivePort.sendPort,
  ]);

  ZipExtractResult? result;
  await for (final message in receivePort) {
    if (message is ZipExtractProgressReport) {
      onExtractProgress(message.extracted, message.total);
    } else if (message is ZipExtractResult) {
      result = message;
      break;
    } else if (message is List<Object?>) {
      receivePort.close();
      Error.throwWithStackTrace(message[0] as Object, message[1] as StackTrace);
    }
  }
  receivePort.close();
  return result!;
}

Future<PersistExtractedOutcome> persistExtractedItems(
  List<ExtractedPdfItem> items,
  PdfStoragePort store,
) async => PersistExtractedOutcome(items: items);

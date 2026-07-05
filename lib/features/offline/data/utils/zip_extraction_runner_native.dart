import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../datasources/zip_package_downloader.dart';
import '../../domain/entities/offline_pdf_batch_item.dart';
import '../../domain/ports/pdf_storage_port.dart';
import '../utils/zip_pdf_extractor.dart';

Future<ZipExtractResult> runZipExtraction({
  required ZipExtractParams params,
  required ZipPackageDownloader zipDownloader,
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

Future<List<ExtractedPdfItem>> persistExtractedItems(
  List<ExtractedPdfItem> items,
  PdfStoragePort store,
) async => items;

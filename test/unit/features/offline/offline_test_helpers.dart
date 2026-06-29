import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:coldigui/core/constants/offline_config.dart';
import 'package:coldigui/core/database/collections/louvor_cache.dart';
import 'package:coldigui/core/database/collections/offline_pdf_index.dart';
import 'package:coldigui/features/offline/data/datasources/favorite_pdf_ids_resolver.dart';
import 'package:coldigui/features/offline/data/datasources/offline_manifest_remote_datasource.dart';
import 'package:coldigui/features/offline/data/repositories/offline_pdf_repository_impl.dart';
import 'package:coldigui/features/offline/domain/entities/offline_manifest.dart';
import 'package:coldigui/features/offline/domain/repositories/offline_pdf_repository.dart';
import 'package:coldigui/features/offline/domain/usecases/fetch_and_store_pdf.dart';
import 'package:coldigui/features/pdf_opening/data/datasources/pdf_bytes_datasource.dart';
import 'package:dio/dio.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

String encodePdfId(String relPath) {
  return base64Url
      .encode(utf8.encode(relPath))
      .replaceAll('+', '-')
      .replaceAll('/', '_')
      .replaceAll('=', '');
}

Isar openOfflineTestIsar(Directory dir) {
  return Isar.open(
    schemas: [OfflinePdfIndexSchema],
    directory: dir.path,
    name: 'offline_test_${DateTime.now().microsecondsSinceEpoch}',
  );
}

Isar openOfflineCatalogTestIsar(Directory dir) {
  return Isar.open(
    schemas: [OfflinePdfIndexSchema, LouvorCacheSchema],
    directory: dir.path,
    name: 'offline_catalog_test_${DateTime.now().microsecondsSinceEpoch}',
  );
}

Future<String> createSampleZip({
  required Directory dir,
  required Map<String, List<int>> pdfEntries,
}) async {
  final archive = Archive();
  for (final entry in pdfEntries.entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }

  final encoded = ZipEncoder().encode(archive);
  final zipPath = '${dir.path}/sample.zip';
  await File(zipPath).writeAsBytes(encoded);
  return zipPath;
}

Future<Directory> createTempDocsDir() async {
  final systemTemp = await getTemporaryDirectory();
  final docs = Directory(
    '${systemTemp.path}/coldigui_offline_test_${DateTime.now().microsecondsSinceEpoch}',
  );
  await docs.create(recursive: true);
  return docs;
}

/// Seed [count] entradas válidas no índice + disco (benchmark reconcile 3.6).
Future<void> seedOfflineEntries({
  required OfflinePdfRepositoryImpl repository,
  required int count,
  String category = 'ColAdultos',
}) async {
  final bytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);
  for (var i = 0; i < count; i++) {
    final rel = '$category/${i.toString().padLeft(5, '0')}.pdf';
    await repository.upsert(
      pdfId: encodePdfId(rel),
      bytes: bytes,
      category: category,
    );
  }
}

FetchAndStorePdf createTestFetchAndStorePdf(
  PdfBytesDatasource bytesDatasource,
  OfflinePdfRepository repository, {
  int cacheQuotaBytes = OfflineConfig.defaultPdfCacheQuotaBytes,
}) {
  return FetchAndStorePdf(
    bytesDatasource,
    repository,
    favoritePdfIdsResolver: FavoritePdfIdsResolver.testing(),
    cacheQuotaBytes: cacheQuotaBytes,
  );
}

/// Datasource de manifest com [fetchManifest] fixo para testes.
class FakeOfflineManifestRemoteDatasource
    extends OfflineManifestRemoteDatasource {
  FakeOfflineManifestRemoteDatasource(this._manifest, SharedPreferences prefs)
    : super(Dio(), prefs, networkOverride: () async => _manifest);

  final OfflineManifest _manifest;

  @override
  Future<OfflineManifest> fetchManifest() async => _manifest;
}

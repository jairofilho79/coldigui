import 'dart:typed_data';

import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/core/utils/pdf_path_normalizer.dart';
import 'package:coldigui/features/offline/data/datasources/zip_package_downloader.dart';
import 'package:coldigui/features/offline/data/utils/zip_extraction_runner_web.dart';
import 'package:coldigui/features/offline/data/utils/zip_pdf_extractor_types.dart';
import 'package:coldigui/features/offline/domain/exceptions/offline_bulk_exceptions.dart';
import 'package:coldigui/features/offline/domain/ports/pdf_storage_port.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

final _validPdfBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x00]);

/// Fake de [PdfStoragePort] que registra gravações e pode falhar de forma
/// fatal (quota) ou não fatal (erro genérico) para um relPath específico.
class _FakePdfStoragePort implements PdfStoragePort {
  _FakePdfStoragePort({
    this.quotaFailureRelPath,
    this.genericFailureRelPaths = const {},
  });

  final String? quotaFailureRelPath;
  final Set<String> genericFailureRelPaths;
  final writes = <String>[];

  @override
  Future<String> get rootPath async => 'plpcg_pdfs';

  @override
  Future<String> writeAtomic(Uint8List bytes, String relPath) async {
    writes.add(relPath);
    if (relPath == quotaFailureRelPath) {
      throw const InsufficientDiskSpaceException(
        requiredBytes: 1024,
        availableBytes: 0,
      );
    }
    if (genericFailureRelPaths.contains(relPath)) {
      throw StateError('falha genérica de escrita simulada');
    }
    return 'plpcg_pdfs/$relPath';
  }

  @override
  Future<bool> exists(String storageKey) async => false;

  @override
  Future<void> delete(String storageKey) async {}

  @override
  Future<void> deleteTree() async {}

  @override
  Future<int> getTotalOfflineBytes() async => 0;

  @override
  Future<List<String>> listOrphans(Set<String> indexedStorageKeys) async =>
      const [];

  @override
  Future<Uint8List?> readBytes(String storageKey, {int? maxBytes}) async =>
      null;

  @override
  Future<void> purgeLegacyStorage() async {}
}

/// Fake de [ZipPackageDownloader] (variante nativa resolvida na VM) — só
/// [fetchPdfBytes] é exercitado por [runZipExtraction].
class _FakeZipPackageDownloader extends ZipPackageDownloader {
  _FakeZipPackageDownloader({this.corruptPdfIds = const {}})
    : super(Dio(), _FakePdfStoragePort());

  final Set<String> corruptPdfIds;
  final fetches = <String>[];

  @override
  Future<Uint8List> fetchPdfBytes(
    String pdfId, {
    CancelToken? cancelToken,
  }) async {
    fetches.add(pdfId);
    if (corruptPdfIds.contains(pdfId)) {
      return Uint8List(0);
    }
    return _validPdfBytes;
  }
}

List<String> _pdfIds(int count) => List.generate(
  count,
  (i) => encodePdfId('ColAdultos/${i.toString().padLeft(3, '0')}.pdf'),
);

void main() {
  test(
    'InsufficientDiskSpaceException de um worker cancela o token compartilhado '
    'e é propagada (não vira failedPdfIds)',
    () async {
      final pdfIds = _pdfIds(20);
      final failingPdfId = pdfIds[5];
      final store = _FakePdfStoragePort(
        quotaFailureRelPath: PdfPathNormalizer.getPdfRelPath(failingPdfId),
      );
      final downloader = _FakeZipPackageDownloader();
      final cancelToken = CancelToken();

      await expectLater(
        runZipExtraction(
          params: ZipExtractParams(
            zipPath: 'unused',
            rootPath: 'plpcg_pdfs',
            expectedPdfIds: pdfIds,
            skipPdfIds: const [],
          ),
          zipDownloader: downloader,
          store: store,
          cancelToken: cancelToken,
        ),
        throwsA(isA<InsufficientDiskSpaceException>()),
      );

      expect(
        cancelToken.isCancelled,
        isTrue,
        reason:
            'token compartilhado deve ser cancelado para abortar os demais workers',
      );
      expect(
        store.writes.length,
        lessThan(pdfIds.length),
        reason: 'workers restantes devem abortar em vez de processar tudo',
      );
    },
  );

  test(
    'falhas não fatais (PDF corrompido ou erro genérico de escrita) continuam '
    'acumulando em failedPdfIds sem abortar os demais',
    () async {
      final pdfIds = _pdfIds(10);
      final corruptId = pdfIds[2];
      final genericFailureId = pdfIds[7];
      final store = _FakePdfStoragePort(
        genericFailureRelPaths: {
          PdfPathNormalizer.getPdfRelPath(genericFailureId),
        },
      );
      final downloader = _FakeZipPackageDownloader(corruptPdfIds: {corruptId});

      final result = await runZipExtraction(
        params: ZipExtractParams(
          zipPath: 'unused',
          rootPath: 'plpcg_pdfs',
          expectedPdfIds: pdfIds,
          skipPdfIds: const [],
        ),
        zipDownloader: downloader,
        store: store,
      );

      expect(result.failedPdfIds.toSet(), {corruptId, genericFailureId});
      expect(result.items.length, pdfIds.length - 2);
      expect(downloader.fetches.length, pdfIds.length);
    },
  );
}

import 'dart:typed_data';

import 'package:coldigui/features/offline/domain/entities/offline_pdf_batch_item.dart';
import 'package:coldigui/features/offline/domain/entities/offline_pdf_entry.dart';
import 'package:coldigui/features/offline/domain/repositories/offline_pdf_repository.dart';
import 'package:coldigui/features/pdf_opening/domain/entities/pdf_offline_availability.dart';
import 'package:coldigui/features/pdf_opening/domain/usecases/validate_pdf_availability.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeOfflinePdfRepository implements OfflinePdfRepository {
  _FakeOfflinePdfRepository({this.entry});

  OfflinePdfEntry? entry;

  @override
  Future<OfflinePdfEntry?> lookup(String pdfId) async => entry;

  @override
  Future<(OfflinePdfEntry? entry, bool hasIndexEntry)> lookupWithIndexState(
    String pdfId,
  ) async =>
      (entry, entry != null);

  @override
  Future<Set<String>> lookupBatch(Set<String> pdfIds) async {
    if (entry != null && pdfIds.contains(entry!.pdfId)) {
      return {entry!.pdfId};
    }
    return {};
  }

  @override
  Future<OfflinePdfEntry?> findIndexEntry(String pdfId) async => entry;

  @override
  Future<OfflinePdfEntry> upsert({
    required String pdfId,
    required Uint8List bytes,
    required String category,
    bool isPersistent = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> remove(String pdfId) async {}

  @override
  Future<String?> findPdfIdByAbsolutePath(String absolutePath) async => null;

  @override
  Future<Map<String, int>> countByCategory() async => {};

  @override
  Future<List<OfflinePdfEntry>> listAll() async => [];

  @override
  Future<void> indexExtractedBatch(List<ExtractedPdfItem> items) async {}

  @override
  Future<void> upsertBatch(List<OfflinePdfBatchItem> items) async {}

  @override
  Future<int> removeIndexEntries(Set<String> pdfIds) async => 0;

  @override
  Future<void> clearAll() async {}

  @override
  Future<int> totalCachedBytes() async => 0;

  @override
  Future<int> evictOldestPdfs({
    required int targetBytes,
    Set<String> excludePdfIds = const {},
  }) async =>
      0;

  @override
  Future<void> flushPendingTouchLastAccessed() async {}
}

void main() {
  const pdfId = 'test-pdf-id';

  test('retorna persistentOffline quando isPersistent é true', () async {
    final repository = _FakeOfflinePdfRepository(
      entry: OfflinePdfEntry(
        pdfId: pdfId,
        absolutePath: '/tmp/plpcg_pdfs/foo.pdf',
        category: 'ColAdultos',
        fileSize: 100,
        downloadedAt: DateTime(2026),
        isPersistent: true,
      ),
    );
    final useCase = ValidatePdfAvailability(repository);

    expect(
      await useCase.call(pdfId: pdfId),
      PdfOfflineAvailability.persistentOffline,
    );
  });

  test('retorna cachedLru quando isPersistent é false', () async {
    final repository = _FakeOfflinePdfRepository(
      entry: OfflinePdfEntry(
        pdfId: pdfId,
        absolutePath: '/tmp/plpcg_pdfs/foo.pdf',
        category: 'ColAdultos',
        fileSize: 100,
        downloadedAt: DateTime(2026),
      ),
    );
    final useCase = ValidatePdfAvailability(repository);

    expect(
      await useCase.call(pdfId: pdfId),
      PdfOfflineAvailability.cachedLru,
    );
  });

  test('retorna notAvailable quando índice ausente', () async {
    final repository = _FakeOfflinePdfRepository();
    final useCase = ValidatePdfAvailability(repository);

    expect(
      await useCase.call(pdfId: pdfId),
      PdfOfflineAvailability.notAvailable,
    );
  });
}

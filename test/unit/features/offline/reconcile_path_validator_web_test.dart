import 'dart:typed_data';

import 'package:coldigui/features/offline/data/utils/pdf_integrity_validator.dart';
import 'package:coldigui/features/offline/data/utils/reconcile_path_validator.dart';
import 'package:coldigui/features/offline/data/utils/reconcile_path_validator_web.dart'
    as web_validator;
import 'package:coldigui/features/offline/domain/ports/pdf_storage_port.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryPdfStoragePort implements PdfStoragePort {
  _MemoryPdfStoragePort(this._files);

  final Map<String, Uint8List> _files;

  @override
  Future<String> get rootPath async => 'plpcg_pdfs';

  @override
  Future<String> writeAtomic(Uint8List bytes, String relPath) async =>
      'plpcg_pdfs/$relPath';

  @override
  Future<bool> exists(String storageKey) async =>
      _files.containsKey(storageKey);

  @override
  Future<void> delete(String storageKey) async => _files.remove(storageKey);

  @override
  Future<void> deleteTree() async => _files.clear();

  @override
  Future<int> getTotalOfflineBytes() async =>
      _files.values.fold<int>(0, (sum, bytes) => sum + bytes.length);

  @override
  Future<List<String>> listOrphans(Set<String> indexedStorageKeys) async =>
      _files.keys.where((key) => !indexedStorageKeys.contains(key)).toList();

  @override
  Future<Uint8List?> readBytes(String storageKey, {int? maxBytes}) async {
    final bytes = _files[storageKey];
    if (bytes == null) return null;
    if (maxBytes == null || bytes.length <= maxBytes) return bytes;
    return Uint8List.fromList(bytes.sublist(0, maxBytes));
  }

  @override
  Future<void> purgeLegacyStorage() async {}
}

void main() {
  test(
    'web validateReconcilePathChunk aceita PDF com magic bytes no store',
    () async {
      const storageKey = 'plpcg_pdfs/ColAdultos/001.pdf';
      final store = _MemoryPdfStoragePort({
        storageKey: Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D]),
      });

      final result = await web_validator.validateReconcilePathChunk([
        const ReconcilePathEntry(pdfId: 'id1', absolutePath: storageKey),
      ], store);

      expect(result.invalidPdfIds, isEmpty);
      expect(result.validAbsolutePaths, [storageKey]);
    },
  );

  test('web validateReconcilePathChunk rejeita ausente ou inválido', () async {
    const storageKey = 'plpcg_pdfs/fake.pdf';
    final store = _MemoryPdfStoragePort({
      storageKey: Uint8List.fromList('<html>'.codeUnits),
    });

    final missing = await web_validator.validateReconcilePathChunk([
      const ReconcilePathEntry(
        pdfId: 'missing',
        absolutePath: 'plpcg_pdfs/missing.pdf',
      ),
    ], store);

    expect(missing.invalidPdfIds, ['missing']);
    expect(missing.validAbsolutePaths, isEmpty);

    final invalid = await web_validator.validateReconcilePathChunk([
      const ReconcilePathEntry(pdfId: 'fake', absolutePath: storageKey),
    ], store);

    expect(invalid.invalidPdfIds, ['fake']);
    expect(invalid.validAbsolutePaths, isEmpty);
    expect(
      PdfIntegrityValidator.hasValidPdfMagicBytes(
        Uint8List.fromList('<html>'.codeUnits),
      ),
      isFalse,
    );
  });
}

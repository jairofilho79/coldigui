import 'dart:typed_data';

import '../../domain/ports/pdf_storage_port.dart';

PdfStoragePort createPdfStoragePortImpl() => const PdfStorageWebStub();

/// Stub web — implementação OPFS/IndexedDB na Fase 4b.
class PdfStorageWebStub implements PdfStoragePort {
  const PdfStorageWebStub();

  Never _unimplemented(String method) => throw UnimplementedError(
    'PdfStoragePort.$method — OPFS/IndexedDB (phase 4b)',
  );

  @override
  Future<String> get rootPath => _unimplemented('rootPath');

  @override
  Future<String> writeAtomic(Uint8List bytes, String relPath) =>
      _unimplemented('writeAtomic');

  @override
  Future<bool> exists(String storageKey) => _unimplemented('exists');

  @override
  Future<void> delete(String storageKey) => _unimplemented('delete');

  @override
  Future<void> deleteTree() => _unimplemented('deleteTree');

  @override
  Future<int> getTotalOfflineBytes() => _unimplemented('getTotalOfflineBytes');

  @override
  Future<List<String>> listOrphans(Set<String> indexedStorageKeys) =>
      _unimplemented('listOrphans');

  @override
  Future<Uint8List?> readBytes(String storageKey) =>
      _unimplemented('readBytes');
}

import 'dart:io';
import 'dart:typed_data';

import '../../domain/ports/pdf_storage_port.dart';
import 'pdf_local_store.dart';

PdfStoragePort createPdfStoragePortImpl({PdfLocalStore? store}) {
  return PdfStorageNative(store: store);
}

/// Wrapper nativo de [PdfLocalStore] — comportamento idêntico ao store atual.
class PdfStorageNative implements PdfStoragePort {
  PdfStorageNative({PdfLocalStore? store}) : _store = store ?? PdfLocalStore();

  final PdfLocalStore _store;

  @override
  Future<String> get rootPath async => (await _store.rootDirectory).path;

  @override
  Future<String> writeAtomic(Uint8List bytes, String relPath) =>
      _store.writeAtomic(bytes, relPath);

  @override
  Future<bool> exists(String storageKey) => _store.exists(storageKey);

  @override
  Future<void> delete(String storageKey) => _store.delete(storageKey);

  @override
  Future<void> deleteTree() => _store.deleteTree();

  @override
  Future<int> getTotalOfflineBytes() => _store.getTotalOfflineBytes();

  @override
  Future<List<String>> listOrphans(Set<String> indexedStorageKeys) =>
      _store.listOrphans(indexedStorageKeys);

  @override
  Future<void> purgeLegacyStorage() async {}

  @override
  Future<Uint8List?> readBytes(String storageKey, {int? maxBytes}) async {
    if (!await _store.exists(storageKey)) return null;
    final file = File(storageKey);
    if (maxBytes != null) {
      final raf = await file.open();
      try {
        final length = await file.length();
        return await raf.read(maxBytes > length ? length : maxBytes);
      } finally {
        await raf.close();
      }
    }
    return file.readAsBytes();
  }
}

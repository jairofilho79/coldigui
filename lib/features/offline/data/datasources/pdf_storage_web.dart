import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart';

import '../../../../core/constants/offline_config.dart';
import '../../domain/ports/pdf_storage_port.dart';

@JS('Reflect.get')
external JSAny? _reflectGet(JSObject target, JSAny propertyKey);

PdfStoragePort createPdfStoragePortImpl() => PdfStorageWeb();

/// Persistência de PDFs offline via OPFS (Origin Private File System).
///
/// Chaves lógicas: `plpcg_pdfs/<relPath>` — compatíveis com [OfflinePdfIndex.storagePath].
class PdfStorageWeb implements PdfStoragePort {
  FileSystemDirectoryHandle? _pdfRoot;

  static const _tmpSuffix = '.tmp';

  @override
  Future<String> get rootPath async => OfflineConfig.pdfStorageSubdir;

  @override
  Future<String> writeAtomic(Uint8List bytes, String relPath) async {
    final storageKey = _storageKey(relPath);
    final tmpKey = '$storageKey$_tmpSuffix';
    try {
      await _writeFileAtKey(tmpKey, bytes);
      await delete(storageKey);
      await _writeFileAtKey(storageKey, bytes);
      await delete(tmpKey);
      return storageKey;
    } on Object {
      await delete(tmpKey);
      rethrow;
    }
  }

  @override
  Future<bool> exists(String storageKey) async {
    try {
      await _resolveFileHandle(storageKey);
      return true;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> delete(String storageKey) async {
    if (!await exists(storageKey)) return;
    final (parentDir, fileName) = await _resolveParentAndFileName(storageKey);
    try {
      await parentDir.removeEntry(fileName).toDart;
    } on Object {
      // Idempotente.
    }
  }

  @override
  Future<void> deleteTree() async {
    final opfsRoot = await _opfsRoot();
    try {
      await opfsRoot
          .removeEntry(
            OfflineConfig.pdfStorageSubdir,
            FileSystemRemoveOptions(recursive: true),
          )
          .toDart;
    } on Object {
      // Diretório ausente — recria abaixo.
    }
    _pdfRoot = null;
    await _pdfRootDir();
  }

  @override
  Future<int> getTotalOfflineBytes() async {
    final root = await _pdfRootDir();
    var total = 0;
    await _walkFiles(root, OfflineConfig.pdfStorageSubdir, (
      storageKey,
      handle,
    ) async {
      if (!storageKey.endsWith('.pdf') || storageKey.endsWith(_tmpSuffix)) {
        return;
      }
      final fileHandle = handle as FileSystemFileHandle;
      final file = await fileHandle.getFile().toDart;
      total += file.size;
    });
    return total;
  }

  @override
  Future<List<String>> listOrphans(Set<String> indexedStorageKeys) async {
    final root = await _pdfRootDir();
    final orphans = <String>[];
    await _walkFiles(root, OfflineConfig.pdfStorageSubdir, (
      storageKey,
      handle,
    ) async {
      if (!storageKey.endsWith('.pdf') || storageKey.endsWith(_tmpSuffix)) {
        return;
      }
      if (!indexedStorageKeys.contains(storageKey)) {
        orphans.add(storageKey);
      }
    });
    return orphans;
  }

  @override
  Future<Uint8List?> readBytes(String storageKey, {int? maxBytes}) async {
    try {
      final fileHandle = await _resolveFileHandle(storageKey);
      final file = await fileHandle.getFile().toDart;
      final blob = maxBytes == null ? file : file.slice(0, maxBytes);
      final buffer = await blob.arrayBuffer().toDart;
      return buffer.toUint8List();
    } on Object {
      return null;
    }
  }

  Future<FileSystemDirectoryHandle> _opfsRoot() =>
      window.navigator.storage.getDirectory().toDart;

  Future<FileSystemDirectoryHandle> _pdfRootDir() async {
    if (_pdfRoot != null) return _pdfRoot!;
    final opfsRoot = await _opfsRoot();
    _pdfRoot = await opfsRoot
        .getDirectoryHandle(
          OfflineConfig.pdfStorageSubdir,
          FileSystemGetDirectoryOptions(create: true),
        )
        .toDart;
    return _pdfRoot!;
  }

  Future<FileSystemFileHandle> _resolveFileHandle(String storageKey) async {
    final (parentDir, fileName) = await _resolveParentAndFileName(storageKey);
    return parentDir
        .getFileHandle(fileName, FileSystemGetFileOptions(create: false))
        .toDart;
  }

  Future<(FileSystemDirectoryHandle, String)> _resolveParentAndFileName(
    String storageKey,
  ) async {
    final relPath = _relPathFromStorageKey(storageKey);
    final segments = relPath.split('/');
    final fileName = segments.removeLast();
    var dir = await _pdfRootDir();
    for (final segment in segments) {
      dir = await dir
          .getDirectoryHandle(
            segment,
            FileSystemGetDirectoryOptions(create: true),
          )
          .toDart;
    }
    return (dir, fileName);
  }

  Future<void> _writeFileAtKey(String storageKey, Uint8List bytes) async {
    final (parentDir, fileName) = await _resolveParentAndFileName(storageKey);
    final handle = await parentDir
        .getFileHandle(fileName, FileSystemGetFileOptions(create: true))
        .toDart;
    await _writeHandle(handle, bytes);
  }

  Future<void> _writeHandle(
    FileSystemFileHandle handle,
    Uint8List bytes,
  ) async {
    final writable = await handle.createWritable().toDart;
    try {
      await writable.write(bytes.toJS).toDart;
      await writable.close().toDart;
    } on Object {
      try {
        await (writable as WritableStream).abort().toDart;
      } on Object {
        // Best-effort.
      }
      rethrow;
    }
  }

  Future<void> _walkFiles(
    FileSystemDirectoryHandle dir,
    String prefix,
    Future<void> Function(String storageKey, FileSystemHandle handle) onFile,
  ) async {
    await for (final entry in _directoryEntries(dir)) {
      final name = entry.$1;
      final handle = entry.$2;
      final childKey = prefix.isEmpty ? name : '$prefix/$name';
      if (handle.kind == 'file') {
        await onFile(childKey, handle);
      } else if (handle.kind == 'directory') {
        await _walkFiles(handle as FileSystemDirectoryHandle, childKey, onFile);
      }
    }
  }

  Stream<(String, FileSystemHandle)> _directoryEntries(
    FileSystemDirectoryHandle dir,
  ) async* {
    final dirObj = dir as JSObject;
    final entriesFn = _reflectGet(dirObj, 'entries'.toJS);
    if (entriesFn == null) return;
    final iterable = (entriesFn as JSFunction).callAsFunction() as JSObject;
    final symbolCtor = globalContext['Symbol'] as JSObject;
    final asyncIteratorSymbol = _reflectGet(symbolCtor, 'asyncIterator'.toJS)!;
    final iteratorFn =
        _reflectGet(iterable, asyncIteratorSymbol)! as JSFunction;
    final iterator = iteratorFn.callAsFunction() as JSObject;

    while (true) {
      final result =
          await (iterator.callMethod('next'.toJS) as JSPromise).toDart
              as JSObject;
      final done = (result['done'] as JSBoolean).toDart;
      if (done) break;
      final value = result['value'] as JSArray;
      final name = (value[0] as JSString).toDart;
      final handle = value[1] as FileSystemHandle;
      yield (name, handle);
    }
  }

  static String _storageKey(String relPath) {
    final normalized = relPath.replaceAll(r'\', '/');
    return '${OfflineConfig.pdfStorageSubdir}/$normalized';
  }

  static String _relPathFromStorageKey(String storageKey) {
    final prefix = '${OfflineConfig.pdfStorageSubdir}/';
    if (!storageKey.startsWith(prefix)) {
      throw ArgumentError.value(storageKey, 'storageKey', 'prefixo inválido');
    }
    return storageKey.substring(prefix.length);
  }
}

extension on JSArrayBuffer {
  Uint8List toUint8List() {
    final byteBuffer = toDart;
    return Uint8List.view(byteBuffer);
  }
}

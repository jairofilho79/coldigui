import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart' as path_provider;

import '../../../../core/constants/offline_config.dart';
import '../../domain/ports/audio_storage_port.dart';
import 'pdf_local_store.dart' show GetApplicationDocumentsDirectoryFn;

AudioStoragePort createAudioStoragePortImpl() => AudioStorageNative();

/// Áudios Coldigom em `documents/plpcg_audio/` — `.tmp` + rename, como
/// [PdfLocalStore]. **Proibido** cache/temp: o download é explícito e o
/// utilizador conta com ele no modo de avião.
class AudioStorageNative implements AudioStoragePort {
  AudioStorageNative({
    GetApplicationDocumentsDirectoryFn? getApplicationDocumentsDirectory,
  }) : _getApplicationDocumentsDirectory =
           getApplicationDocumentsDirectory ??
           path_provider.getApplicationDocumentsDirectory;

  final GetApplicationDocumentsDirectoryFn _getApplicationDocumentsDirectory;
  Directory? _root;

  Future<Directory> get _rootDirectory async {
    if (_root != null) return _root!;
    final docs = await _getApplicationDocumentsDirectory();
    _root = Directory('${docs.path}/${OfflineConfig.audioStorageSubdir}');
    if (!await _root!.exists()) await _root!.create(recursive: true);
    return _root!;
  }

  @override
  Future<String> writeAtomic(Uint8List bytes, String relPath) async {
    final root = await _rootDirectory;
    final target = File('${root.path}/${relPath.replaceAll(r'\', '/')}');
    final tmp = File('${target.path}.tmp');
    if (!await target.parent.exists()) {
      await target.parent.create(recursive: true);
    }
    try {
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(target.path);
      return target.path;
    } on Object {
      if (await tmp.exists()) await tmp.delete();
      rethrow;
    }
  }

  @override
  Future<bool> exists(String storageKey) => File(storageKey).exists();

  @override
  Future<Uint8List?> readBytes(String storageKey) async {
    final file = File(storageKey);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  Future<void> delete(String storageKey) async {
    final file = File(storageKey);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> deleteTree() async {
    final root = await _rootDirectory;
    if (await root.exists()) await root.delete(recursive: true);
    _root = null;
    await _rootDirectory;
  }

  @override
  Future<int> getTotalBytes() async {
    final root = await _rootDirectory;
    var total = 0;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File || entity.path.endsWith('.tmp')) continue;
      total += await entity.length();
    }
    return total;
  }
}

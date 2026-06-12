import '../../domain/entities/offline_manifest.dart';

/// Parser do JSON de `/offline-manifest.json`.
abstract final class OfflineManifestDto {
  static OfflineManifest fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    if (version is! String || version.isEmpty) {
      throw const FormatException('offline-manifest: version ausente');
    }

    final packagesRaw = json['packages'];
    if (packagesRaw is! Map<String, dynamic>) {
      throw const FormatException('offline-manifest: packages inválido');
    }

    final packages = <String, OfflineMaterialPackage>{};
    for (final entry in packagesRaw.entries) {
      packages[entry.key] = _parseMaterialPackage(entry.value);
    }

    return OfflineManifest(version: version, packages: packages);
  }

  static OfflineMaterialPackage _parseMaterialPackage(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('offline-manifest: pacote inválido');
    }

    final partsRaw = raw['parts'];
    if (partsRaw is! List<dynamic>) {
      throw const FormatException('offline-manifest: parts inválido');
    }

    final parts = <OfflinePackagePart>[];
    for (final item in partsRaw) {
      if (item is! Map<String, dynamic>) continue;
      parts.add(_parsePart(item));
    }

    return OfflineMaterialPackage(
      parts: parts,
      totalSize: raw['totalSize'] as int? ?? 0,
      totalParts: raw['totalParts'] as int? ?? parts.length,
    );
  }

  static OfflinePackagePart _parsePart(Map<String, dynamic> json) {
    final filename = json['filename'];
    final url = json['url'];
    final pdfsRaw = json['pdfs'];

    if (filename is! String || filename.isEmpty) {
      throw const FormatException('offline-manifest: filename ausente');
    }
    if (url is! String || url.isEmpty) {
      throw const FormatException('offline-manifest: url ausente');
    }
    if (pdfsRaw is! List<dynamic>) {
      throw const FormatException('offline-manifest: pdfs inválido');
    }

    final pdfs =
        pdfsRaw.whereType<String>().where((id) => id.isNotEmpty).toList();

    return OfflinePackagePart(
      filename: filename,
      size: json['size'] as int? ?? 0,
      url: url,
      pdfs: pdfs,
    );
  }
}

/// Manifesto de pacotes ZIP offline (`/offline-manifest.json`) — UC-09.
class OfflineManifest {
  const OfflineManifest({
    required this.version,
    required this.packages,
  });

  final String version;
  final Map<String, OfflineMaterialPackage> packages;

  /// Soma [OfflineMaterialPackage.totalSize] das [categoryKeys] selecionadas.
  int totalSizeForCategories(Iterable<String> categoryKeys) {
    var total = 0;
    for (final key in categoryKeys) {
      total += packages[key]?.totalSize ?? 0;
    }
    return total;
  }

  OfflineMaterialPackage? packageFor(String materialCategory) =>
      packages[materialCategory];
}

/// Pacote ZIP particionado por material (Partitura, Cifra, Gestos em Gravura).
class OfflineMaterialPackage {
  const OfflineMaterialPackage({
    required this.parts,
    required this.totalSize,
    required this.totalParts,
  });

  final List<OfflinePackagePart> parts;
  final int totalSize;
  final int totalParts;

  int get totalPdfs => parts.fold(0, (sum, part) => sum + part.pdfs.length);
}

/// Parte individual de um pacote ZIP offline.
class OfflinePackagePart {
  const OfflinePackagePart({
    required this.filename,
    required this.size,
    required this.url,
    required this.pdfs,
  });

  final String filename;
  final int size;
  final String url;
  final List<String> pdfs;
}

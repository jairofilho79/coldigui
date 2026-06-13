/// Estatísticas offline agregadas para UI (UC-10).
///
/// [byCategory] e [missingByCategory] usam chaves de material de UI
/// (`Partitura`, `Cifra`, `Gestos em Gravura`) — não classificação Isar crua.
class OfflineStats {
  const OfflineStats({
    required this.byCategory,
    this.missingByCategory = const {},
    this.totalDiskUsageBytes = 0,
  });

  /// Contagem baixada por material de UI (`Partitura`, `Cifra`, etc.).
  final Map<String, int> byCategory;

  /// PDFs do manifest ainda ausentes no índice, por material de UI.
  final Map<String, int> missingByCategory;

  /// Soma de `fileSize` no índice Isar — uso de disco do cache PDF.
  final int totalDiskUsageBytes;

  /// Soma de [byCategory] — total de PDFs offline por material.
  int get totalCount => byCategory.values.fold(0, (sum, count) => sum + count);

  /// Soma de [missingByCategory] — total faltante no manifest remoto.
  int get totalMissing =>
      missingByCategory.values.fold(0, (sum, count) => sum + count);
}

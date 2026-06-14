/// Estatísticas offline agregadas para UI (UC-10).
///
/// [byCategory] e [missingByCategory] usam chaves de material de UI
/// (`Partitura`, `Cifra`, `Gestos em Gravura`) — não classificação Isar crua.
class OfflineStats {
  const OfflineStats({
    required this.byCategory,
    this.missingByCategory = const {},
    this.totalDiskUsageBytes = 0,
    this.missingCountReliable = true,
  });

  /// Contagem baixada por material de UI (`Partitura`, `Cifra`, etc.).
  final Map<String, int> byCategory;

  /// PDFs do manifest ainda ausentes no índice, por material de UI.
  final Map<String, int> missingByCategory;

  /// Bytes totais em `plpcg_pdfs/` (scan do filesystem).
  final int totalDiskUsageBytes;

  /// `false` quando o manifest remoto não pôde ser obtido (ex.: sem rede).
  final bool missingCountReliable;

  /// Soma de [byCategory] — total de PDFs offline por material.
  int get totalCount => byCategory.values.fold(0, (sum, count) => sum + count);

  /// Soma de [missingByCategory] — total faltante no manifest remoto.
  int get totalMissing =>
      missingByCategory.values.fold(0, (sum, count) => sum + count);
}

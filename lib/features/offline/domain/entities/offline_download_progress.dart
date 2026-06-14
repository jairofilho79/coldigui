/// Fases do bulk download UC-09 (paridade PWA: fetching → extracting → storing → syncing).
enum OfflineDownloadPhase {
  fetching,
  extracting,
  storing,
  syncing,
}

/// Progresso reportado por [DownloadOfflinePackages] para a UI.
class OfflineDownloadProgress {
  const OfflineDownloadProgress({
    required this.phase,
    required this.currentCategory,
    required this.categoryIndex,
    required this.totalCategories,
    required this.currentPart,
    required this.totalParts,
    required this.donePdfs,
    required this.totalPdfs,
    this.zipBytesReceived,
    this.zipBytesTotal,
  });

  final OfflineDownloadPhase phase;
  final String currentCategory;
  final int categoryIndex;
  final int totalCategories;
  final int currentPart;
  final int totalParts;
  final int donePdfs;
  final int totalPdfs;
  final int? zipBytesReceived;
  final int? zipBytesTotal;

  double get categoryFraction =>
      totalCategories == 0 ? 0 : (categoryIndex + 1) / totalCategories;

  double get pdfFraction => totalPdfs == 0 ? 0 : donePdfs / totalPdfs;

  double get zipFraction {
    final total = zipBytesTotal;
    if (total == null || total <= 0) return 0;
    return (zipBytesReceived ?? 0) / total;
  }

  OfflineDownloadProgress copyWith({
    OfflineDownloadPhase? phase,
    String? currentCategory,
    int? categoryIndex,
    int? totalCategories,
    int? currentPart,
    int? totalParts,
    int? donePdfs,
    int? totalPdfs,
    int? zipBytesReceived,
    int? zipBytesTotal,
  }) {
    return OfflineDownloadProgress(
      phase: phase ?? this.phase,
      currentCategory: currentCategory ?? this.currentCategory,
      categoryIndex: categoryIndex ?? this.categoryIndex,
      totalCategories: totalCategories ?? this.totalCategories,
      currentPart: currentPart ?? this.currentPart,
      totalParts: totalParts ?? this.totalParts,
      donePdfs: donePdfs ?? this.donePdfs,
      totalPdfs: totalPdfs ?? this.totalPdfs,
      zipBytesReceived: zipBytesReceived ?? this.zipBytesReceived,
      zipBytesTotal: zipBytesTotal ?? this.zipBytesTotal,
    );
  }
}

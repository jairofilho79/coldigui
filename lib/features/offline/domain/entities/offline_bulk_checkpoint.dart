/// Checkpoint de resume do bulk download UC-09 (Fase 3.5).
class OfflineBulkCheckpoint {
  const OfflineBulkCheckpoint({
    required this.categories,
    required this.categoryIndex,
    required this.partIndex,
    required this.extractedPdfCount,
    required this.startedAt,
  });

  /// Categorias solicitadas na sessão (ordem preservada).
  final List<String> categories;

  /// Índice da categoria material em [categories].
  final int categoryIndex;

  /// Índice da part ZIP dentro da categoria atual.
  final int partIndex;

  /// PDFs já indexados na part atual (resume intra-part).
  final int extractedPdfCount;

  final DateTime startedAt;

  String get currentCategory => categories[categoryIndex];

  OfflineBulkCheckpoint copyWith({
    List<String>? categories,
    int? categoryIndex,
    int? partIndex,
    int? extractedPdfCount,
    DateTime? startedAt,
  }) {
    return OfflineBulkCheckpoint(
      categories: categories ?? this.categories,
      categoryIndex: categoryIndex ?? this.categoryIndex,
      partIndex: partIndex ?? this.partIndex,
      extractedPdfCount: extractedPdfCount ?? this.extractedPdfCount,
      startedAt: startedAt ?? this.startedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'categories': categories,
        'categoryIndex': categoryIndex,
        'partIndex': partIndex,
        'extractedPdfCount': extractedPdfCount,
        'startedAt': startedAt.toIso8601String(),
      };

  factory OfflineBulkCheckpoint.fromJson(Map<String, dynamic> json) {
    return OfflineBulkCheckpoint(
      categories: (json['categories'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      categoryIndex: json['categoryIndex'] as int,
      partIndex: json['partIndex'] as int,
      extractedPdfCount: json['extractedPdfCount'] as int? ?? 0,
      startedAt: DateTime.parse(json['startedAt'] as String),
    );
  }
}

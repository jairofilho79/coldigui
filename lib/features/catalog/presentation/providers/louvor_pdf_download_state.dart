/// Estado de download on-demand de um PDF antes de abrir o leitor.
class LouvorPdfDownloadState {
  const LouvorPdfDownloadState({
    this.isLoading = false,
    this.receivedBytes = 0,
    this.totalBytes,
    this.showProgressLabel = false,
  });

  final bool isLoading;
  final int receivedBytes;
  final int? totalBytes;

  /// `true` após 500ms — evita flash de percentual em cache hits rápidos.
  final bool showProgressLabel;

  double? get progressFraction {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return receivedBytes / total;
  }

  LouvorPdfDownloadState copyWith({
    bool? isLoading,
    int? receivedBytes,
    int? totalBytes,
    bool? showProgressLabel,
  }) {
    return LouvorPdfDownloadState(
      isLoading: isLoading ?? this.isLoading,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      showProgressLabel: showProgressLabel ?? this.showProgressLabel,
    );
  }
}

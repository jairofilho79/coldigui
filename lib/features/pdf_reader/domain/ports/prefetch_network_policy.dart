/// Política de rede para prefetch em background no leitor.
abstract class PrefetchNetworkPolicy {
  /// Indica se prefetch de PDFs adjacentes no carousel é permitido agora.
  Future<bool> allowsAdjacentPdfPrefetch();
}

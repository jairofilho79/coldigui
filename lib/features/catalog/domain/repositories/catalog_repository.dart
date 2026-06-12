import '../entities/louvor.dart';

/// Contrato de acesso ao catálogo de louvores (UC-01, UC-12).
abstract class CatalogRepository {
  /// Carrega manifest da rede ou cache Isar local.
  Future<List<Louvor>> loadManifest();

  /// Baixa manifest da rede e persiste em Isar — sem fallback ao cache (UC-12 manual).
  Future<List<Louvor>> forceRefreshManifest();

  /// Persiste louvores no cache Isar (`LouvorCache`).
  Future<void> cacheManifest(List<Louvor> louvores);

  /// Retorna checksum SHA-256 esperado ou `null` se inalterado (204).
  Future<String?> fetchManifestChecksum();
}

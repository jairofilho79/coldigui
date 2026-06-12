import '../entities/louvor.dart';
import '../repositories/catalog_repository.dart';

/// UC-12 — Refresh manual do catálogo (Fase 1.5).
///
/// Delega a [CatalogRepository.forceRefreshManifest] — fetch remoto obrigatório,
/// sem fallback silencioso ao cache Isar.
class ForceRefreshCatalog {
  const ForceRefreshCatalog(this._repository);

  final CatalogRepository _repository;

  /// Baixa manifest da rede, persiste em Isar e retorna a lista atualizada.
  Future<List<Louvor>> call() => _repository.forceRefreshManifest();
}

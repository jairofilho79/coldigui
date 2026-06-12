import '../entities/louvor.dart';
import '../repositories/catalog_repository.dart';

/// UC-12 — Carregar manifest de louvores da rede ou cache Isar.
///
/// Delega a [CatalogRepository.loadManifest] (remoto com fallback offline).
class LoadLouvoresManifest {
  const LoadLouvoresManifest(this._repository);

  final CatalogRepository _repository;

  /// Retorna lista de [Louvor] após fetch remoto ou leitura do cache Isar.
  Future<List<Louvor>> call() => _repository.loadManifest();
}

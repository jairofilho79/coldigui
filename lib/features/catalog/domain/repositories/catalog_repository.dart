import '../entities/louvor.dart';

/// Resultado de [CatalogRepository.syncManifest] (UC-12 boot).
///
/// [cacheReplaced] `false` significa que o cache Isar **não** foi reescrito —
/// nem `clear()` nem os ~4600 `put`, que na web rodam na thread da UI (A1).
class ManifestSyncOutcome {
  const ManifestSyncOutcome({
    required this.louvores,
    required this.cacheReplaced,
    this.checksum,
  });

  /// Lista efetiva — cache reaproveitado ou manifest recém-baixado.
  final List<Louvor> louvores;

  /// `true` quando o cache Isar foi substituído pelo manifest remoto.
  final bool cacheReplaced;

  /// Checksum a persistir em `ManifestChecksumStore`, quando o Worker informou um.
  final String? checksum;
}

/// Contrato de acesso ao catálogo de louvores (UC-01, UC-12).
abstract class CatalogRepository {
  /// Carrega manifest da rede ou cache Isar local.
  Future<List<Louvor>> loadManifest();

  /// Retorna louvores do cache Isar local (pode ser vazio).
  Future<List<Louvor>> loadCachedLouvores();

  /// Sincroniza o catálogo evitando download e gravação desnecessários (A1).
  ///
  /// Com [cached] não vazio e [knownChecksum] informado, consulta
  /// `/api/catalog/checksum` com `If-None-Match` primeiro: se o checksum não
  /// mudou, devolve [cached] sem baixar o manifest nem reescrever o Isar.
  /// Ao baixar, compara com [cached] e pula a gravação se a lista for idêntica.
  /// Falha de rede mantém [cached] (cache-first silencioso); sem cache, propaga.
  Future<ManifestSyncOutcome> syncManifest({
    required List<Louvor> cached,
    String? knownChecksum,
  });

  /// Baixa manifest da rede e persiste em Isar — sem fallback ao cache (UC-12 manual).
  Future<List<Louvor>> forceRefreshManifest();

  /// Persiste louvores no cache Isar (`LouvorCache`).
  Future<void> cacheManifest(List<Louvor> louvores);

  /// Retorna checksum SHA-256 esperado ou `null` se inalterado (204).
  Future<String?> fetchManifestChecksum();

  /// `true` se o catálogo nunca foi sincronizado ou está há >7 dias sem sync.
  Future<bool> isCatalogStale();
}

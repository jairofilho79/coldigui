import '../../domain/ports/network_connection_checker.dart';
import '../../domain/ports/prefetch_network_policy.dart';

/// Prefetch permitido apenas em conexão não medida (WiFi/Ethernet).
///
/// Dados móveis são bloqueados por padrão até existir consentimento explícito
/// do usuário (futuro setting).
class WifiOnlyPrefetchNetworkPolicy implements PrefetchNetworkPolicy {
  const WifiOnlyPrefetchNetworkPolicy(this._connectionChecker);

  final NetworkConnectionChecker _connectionChecker;

  @override
  Future<bool> allowsAdjacentPdfPrefetch() =>
      _connectionChecker.isUnmeteredConnection();
}

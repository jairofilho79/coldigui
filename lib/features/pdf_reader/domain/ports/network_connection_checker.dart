/// Porta para classificar a conexão ativa (WiFi vs dados móveis).
abstract class NetworkConnectionChecker {
  /// `true` quando a conexão principal é WiFi ou Ethernet (não medida).
  Future<bool> isUnmeteredConnection();
}

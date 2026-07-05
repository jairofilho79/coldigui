import 'package:connectivity_plus/connectivity_plus.dart';

import 'connectivity_results.dart';

/// Verifica se o dispositivo tem alguma conexão de rede utilizável.
abstract class DeviceConnectivity {
  Future<bool> hasConnection();
}

/// Implementação via [Connectivity.checkConnectivity].
class ConnectivityDeviceConnectivity implements DeviceConnectivity {
  ConnectivityDeviceConnectivity([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> hasConnection() async {
    final results = await _connectivity.checkConnectivity();
    return connectivityHasUsableConnection(results);
  }
}

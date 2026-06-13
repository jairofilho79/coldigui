import 'package:connectivity_plus/connectivity_plus.dart';

import '../../domain/ports/network_connection_checker.dart';

/// [NetworkConnectionChecker] via [Connectivity.checkConnectivity].
class ConnectivityNetworkConnectionChecker implements NetworkConnectionChecker {
  ConnectivityNetworkConnectionChecker([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> isUnmeteredConnection() async {
    final results = await _connectivity.checkConnectivity();
    return results.any(_isUnmetered);
  }

  static bool _isUnmetered(ConnectivityResult result) {
    return switch (result) {
      ConnectivityResult.wifi ||
      ConnectivityResult.ethernet ||
      ConnectivityResult.vpn =>
        true,
      ConnectivityResult.mobile ||
      ConnectivityResult.bluetooth ||
      ConnectivityResult.satellite ||
      ConnectivityResult.other ||
      ConnectivityResult.none =>
        false,
    };
  }
}

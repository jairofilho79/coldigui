import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../../core/network/connectivity_results.dart';
import '../../domain/ports/network_connection_checker.dart';

/// [NetworkConnectionChecker] via [Connectivity.checkConnectivity].
class ConnectivityNetworkConnectionChecker implements NetworkConnectionChecker {
  ConnectivityNetworkConnectionChecker([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> isUnmeteredConnection() async {
    final results = await _connectivity.checkConnectivity();
    return connectivityIsUnmetered(results);
  }
}

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Indica conexão utilizável (qualquer tipo exceto [ConnectivityResult.none]).
bool connectivityHasUsableConnection(List<ConnectivityResult> results) {
  return results.any((result) => result != ConnectivityResult.none);
}

/// Indica conexão não medida (WiFi/ethernet/VPN, ou fallback web genérico).
///
/// Na web, [Connectivity.checkConnectivity] usa `navigator.onLine` — sem
/// distinção WiFi/celular. Quando online, o plugin costuma retornar
/// [ConnectivityResult.wifi]; tipos genéricos ([ConnectivityResult.other])
/// também são tratados como não medidos para não bloquear prefetch offline.
bool connectivityIsUnmetered(List<ConnectivityResult> results) {
  if (results.any(_isExplicitlyUnmetered)) return true;
  if (kIsWeb &&
      results.any(
        (result) =>
            result != ConnectivityResult.none &&
            result != ConnectivityResult.mobile,
      )) {
    return true;
  }
  return false;
}

bool _isExplicitlyUnmetered(ConnectivityResult result) {
  return switch (result) {
    ConnectivityResult.wifi ||
    ConnectivityResult.ethernet ||
    ConnectivityResult.vpn => true,
    ConnectivityResult.mobile ||
    ConnectivityResult.bluetooth ||
    ConnectivityResult.satellite ||
    ConnectivityResult.other ||
    ConnectivityResult.none => false,
  };
}

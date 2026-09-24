import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connectivity_results.dart';

/// Stream reativo de conectividade — `true` quando há alguma rede utilizável
/// (qualquer resultado além de [ConnectivityResult.none]).
///
/// Usado por Home/Biblioteca (C.8) para recarregar automaticamente o
/// catálogo coldigom quando a conexão volta depois de um erro. Sobrescrever
/// em testes via `ProviderScope(overrides: [connectivityStreamProvider
/// .overrideWith(...)])`.
final connectivityStreamProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map(
    connectivityHasUsableConnection,
  );
});

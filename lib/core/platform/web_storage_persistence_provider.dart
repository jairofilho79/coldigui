import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'web_storage_persistence.dart';

/// Pedido de storage persistente disparado no boot por `BootstrapApp` via
/// `ref.watch` (mesmo padrão do `isarStatusProvider`): fora do caminho
/// crítico e sem ninguém esperar o resultado. Overridável nos testes.
final persistentStorageProvider = FutureProvider<bool?>(
  (_) => requestPersistentStorage(),
);

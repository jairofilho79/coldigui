import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/database/isar_provider.dart';
import 'core/platform/web_storage_persistence_provider.dart';

/// Monta [ColdiguiApp] imediatamente, sem esperar [isarInitializerProvider] (A8).
///
/// A abertura do Isar (WASM + OPFS na web, até `isarOpenTimeout`) deixou de
/// serializar o boot: o router sobe já e a carga do catálogo começa junto
/// com a abertura em vez de depois dela. As telas que realmente precisam do
/// banco local ficam atrás de `StorageRequiredGate`, que mostra spinner
/// enquanto o status é [IsarStatus.opening] e o aviso de indisponível quando a
/// abertura falha (modo degradado: catálogo online + leitor de PDF).
///
/// O `watch` é mantido só para que o provider seja inicializado no boot — sem
/// ele ninguém abriria o Isar até a primeira tela que precisa dele.
class BootstrapApp extends ConsumerWidget {
  const BootstrapApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(isarStatusProvider);
    // Mesmo motivo: só para o pedido sair no boot (web); nativo é no-op.
    ref.watch(persistentStorageProvider);
    return const ColdiguiApp();
  }
}

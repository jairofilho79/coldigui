import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_plus/isar_plus.dart';

import 'isar_bootstrap.dart';

/// Abre Isar em background após o primeiro frame (Fase B web perf).
///
/// [BootstrapApp] monta [ColdiguiApp] mesmo em erro (modo degradado sem storage).
final isarInitializerProvider = FutureProvider<Isar>((ref) async {
  final isar = await openAppIsar();
  ref.onDispose(isar.close);
  return isar;
});

/// Isar quando disponível; `null` em modo degradado (falha de OPFS/WASM).
final optionalIsarProvider = Provider<Isar?>((ref) {
  return ref.watch(isarInitializerProvider).asData?.value;
});

/// `true` quando [isarInitializerProvider] concluiu com sucesso.
final isarAvailableProvider = Provider<bool>((ref) {
  return ref.watch(optionalIsarProvider) != null;
});

/// Provider de instância Isar Plus (ADR-001).
///
/// Schemas: [LouvorCache], [CarouselEntry], [Playlist], [OfflinePdfIndex].
/// Resolve via [isarInitializerProvider] em produção; sobrescrever em testes com
/// [isarProvider.overrideWithValue].
final isarProvider = Provider<Isar>((ref) {
  return ref.watch(isarInitializerProvider).requireValue;
});

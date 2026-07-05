import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_plus/isar_plus.dart';

import 'isar_bootstrap.dart';

/// Abre Isar em background após o primeiro frame (Fase B web perf).
///
/// [BootstrapApp] aguarda este provider e injeta [isarProvider] no subtree.
final isarInitializerProvider = FutureProvider<Isar>((ref) async {
  final isar = await openAppIsar();
  ref.onDispose(isar.close);
  return isar;
});

/// Provider de instância Isar Plus (ADR-001).
///
/// Schemas: [LouvorCache], [CarouselEntry], [Playlist], [OfflinePdfIndex].
/// Sobrescrever via [BootstrapApp] ou em testes com [isarProvider.overrideWithValue].
final isarProvider = Provider<Isar>((ref) {
  throw UnimplementedError(
    'Override isarProvider after isarInitializerProvider resolves',
  );
});

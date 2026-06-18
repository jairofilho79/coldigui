import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../catalog/domain/entities/louvor.dart';
import '../../data/providers/offline_providers.dart';

/// Louvores faltantes por material de UI — catálogo Isar vs índice offline.
final offlineMissingLouvoresProvider = FutureProvider.autoDispose
    .family<List<Louvor>, String>((ref, materialCategory) {
  return ref
      .watch(listMissingLouvoresByMaterialProvider)
      .call(materialCategory);
});

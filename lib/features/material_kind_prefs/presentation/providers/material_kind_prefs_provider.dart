import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../data/providers/material_kind_prefs_providers.dart';
import '../../domain/entities/material_kind_prefs.dart';
import 'material_kind_prefs_sync_provider.dart';

/// Documento de favoritos da conta logada; [MaterialKindPrefs.empty] para
/// quem está deslogado (a preferência é da conta — spec D5).
final materialKindPrefsProvider =
    AsyncNotifierProvider<MaterialKindPrefsNotifier, MaterialKindPrefs>(
      MaterialKindPrefsNotifier.new,
    );

class MaterialKindPrefsNotifier extends AsyncNotifier<MaterialKindPrefs> {
  @override
  Future<MaterialKindPrefs> build() async {
    final user = await ref.watch(authStateProvider.future);
    if (user == null) return MaterialKindPrefs.empty;
    // O repositório só é resolvido com usuário: ele lê SharedPreferences,
    // que em vários testes não tem override.
    final stored = await ref
        .read(materialKindPrefsRepositoryProvider)
        .read(user.googleSub);
    return stored ?? MaterialKindPrefs.empty;
  }

  /// Grava localmente com `updatedAt = agora`, marca `pendingPush` e pede
  /// sync. Deslogado: no-op. Lista inválida (>5, duplicata) lança
  /// [ArgumentError] antes de tocar o estado.
  Future<void> save(List<String> kindIds) async {
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;
    final next = MaterialKindPrefs.validated(
      kindIds: kindIds,
      updatedAt: DateTime.now().toUtc(),
      pendingPush: true,
    );
    await ref
        .read(materialKindPrefsRepositoryProvider)
        .write(user.googleSub, next);
    if (!ref.mounted) return;
    state = AsyncData(next);
    unawaited(_syncQuietly());
  }

  /// A sync após o save é oportunista: falha vira log, nunca erro na tela —
  /// o documento já está local com `pendingPush` e sobe na próxima rodada.
  Future<void> _syncQuietly() async {
    try {
      await ref.read(materialKindPrefsSyncProvider.notifier).sync();
    } on Object catch (e) {
      debugPrint('[material-kind-prefs] sync após save falhou: $e');
    }
  }
}

/// `kindId → posição` que o sheet consome. Vazio enquanto carrega ou deslogado.
final favoriteMaterialKindRankProvider = Provider<Map<String, int>>((ref) {
  return ref.watch(materialKindPrefsProvider).asData?.value.rank ?? const {};
});

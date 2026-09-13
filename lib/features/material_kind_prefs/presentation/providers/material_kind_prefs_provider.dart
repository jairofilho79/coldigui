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
  ///
  /// O estado é otimista (antes do `await`) e o notifier de sync é capturado
  /// antes também: o Riverpod 3 recria este notifier num `invalidate` — se
  /// a sync em curso invalidar durante o `write`, `ref` já não está montado
  /// e um `return` aqui deixaria o documento pendente sem ninguém pedir o
  /// push.
  Future<void> save(List<String> kindIds) async {
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;
    final next = MaterialKindPrefs.validated(
      kindIds: kindIds,
      updatedAt: DateTime.now().toUtc(),
      pendingPush: true,
    );
    final repository = ref.read(materialKindPrefsRepositoryProvider);
    final syncNotifier = ref.read(materialKindPrefsSyncProvider.notifier);
    state = AsyncData(next);
    await repository.write(user.googleSub, next);
    unawaited(_syncQuietly(syncNotifier));
  }

  /// A sync após o save é oportunista: falha vira log, nunca erro na tela —
  /// o documento já está local com `pendingPush` e sobe na próxima rodada.
  Future<void> _syncQuietly(MaterialKindPrefsSyncNotifier syncNotifier) async {
    try {
      await syncNotifier.sync();
    } on Object catch (e) {
      debugPrint('[material-kind-prefs] sync após save falhou: $e');
    }
  }
}

/// `kindId → posição` que o sheet consome. Vazio enquanto carrega ou deslogado.
///
/// `.value` (não `.asData?.value`) segura o rank anterior durante um
/// `invalidate` (ex.: após sync) — no Riverpod 3 ele preserva o dado antigo
/// enquanto o provider recarrega, evitando o sheet piscar desordenado por um
/// frame.
final favoriteMaterialKindRankProvider = Provider<Map<String, int>>((ref) {
  return ref.watch(materialKindPrefsProvider).value?.rank ?? const {};
});

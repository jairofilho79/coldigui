import 'package:flutter/foundation.dart';

import '../../data/datasources/material_kind_prefs_remote_datasource.dart';
import '../entities/material_kind_prefs.dart';
import '../repositories/material_kind_prefs_repository.dart';

enum MaterialKindPrefsSyncOutcome {
  pulled,
  pushed,
  conflictAdopted,
  noop,
  skipped,
}

/// Resultado de [SyncMaterialKindPrefs]. Erros ficam **crus**: quem traduz é a
/// UI com `userMessageFor`.
class MaterialKindPrefsSyncResult {
  const MaterialKindPrefsSyncResult(
    this.outcome, {
    this.pullError,
    this.pushError,
  });

  final MaterialKindPrefsSyncOutcome outcome;
  final Object? pullError;
  final Object? pushError;

  /// Primeiro erro a mostrar — pull é o mais cedo.
  Object? get error => pullError ?? pushError;

  /// O documento local mudou nesta rodada (quem observa deve recarregar).
  bool get changedLocal =>
      outcome == MaterialKindPrefsSyncOutcome.pulled ||
      outcome == MaterialKindPrefsSyncOutcome.pushed ||
      outcome == MaterialKindPrefsSyncOutcome.conflictAdopted;

  static const skippedAuth = MaterialKindPrefsSyncResult(
    MaterialKindPrefsSyncOutcome.skipped,
  );
}

typedef FetchMaterialKindPrefs =
    Future<MaterialKindPrefs?> Function(String idToken);
typedef PutMaterialKindPrefs =
    Future<MaterialKindPrefs> Function({
      required String idToken,
      required MaterialKindPrefs prefs,
    });

/// Sync de um documento só: pull → push, last-write-wins por `updatedAt`.
///
/// 1. Se o remoto existe e é mais novo que o local (ou não há local), adota.
/// 2. Senão, se o local está `pendingPush`, faz PUT; `409` adota o remoto.
/// Um pull que falha não impede o push — o erro volta no resultado.
class SyncMaterialKindPrefs {
  SyncMaterialKindPrefs(this._repository, this._fetch, this._put);

  final MaterialKindPrefsRepository _repository;
  final FetchMaterialKindPrefs _fetch;
  final PutMaterialKindPrefs _put;

  Future<MaterialKindPrefsSyncResult> call({
    required String? idToken,
    required String sub,
  }) async {
    if (idToken == null) return MaterialKindPrefsSyncResult.skippedAuth;

    final local = await _repository.read(sub);

    Object? pullError;
    MaterialKindPrefs? remote;
    try {
      remote = await _fetch(idToken);
    } on Object catch (e) {
      debugPrint('[material-kind-prefs] pull falhou: $e');
      pullError = e;
    }

    if (remote != null &&
        (local == null || remote.updatedAt.isAfter(local.updatedAt))) {
      await _repository.write(sub, remote.copyWith(pendingPush: false));
      return MaterialKindPrefsSyncResult(
        MaterialKindPrefsSyncOutcome.pulled,
        pullError: pullError,
      );
    }

    if (local == null || !local.pendingPush) {
      return MaterialKindPrefsSyncResult(
        MaterialKindPrefsSyncOutcome.noop,
        pullError: pullError,
      );
    }

    try {
      final saved = await _put(idToken: idToken, prefs: local);
      await _repository.write(sub, saved.copyWith(pendingPush: false));
      return MaterialKindPrefsSyncResult(
        MaterialKindPrefsSyncOutcome.pushed,
        pullError: pullError,
      );
    } on MaterialKindPrefsConflict catch (conflict) {
      await _repository.write(
        sub,
        conflict.remote.copyWith(pendingPush: false),
      );
      return MaterialKindPrefsSyncResult(
        MaterialKindPrefsSyncOutcome.conflictAdopted,
        pullError: pullError,
      );
    } on Object catch (e) {
      debugPrint('[material-kind-prefs] push falhou: $e');
      return MaterialKindPrefsSyncResult(
        MaterialKindPrefsSyncOutcome.noop,
        pullError: pullError,
        pushError: e,
      );
    }
  }
}

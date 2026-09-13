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

  /// Um `save` mais novo entrou enquanto a rede rodava: a rodada não gravou
  /// nada (mesmo que o PUT tenha subido o snapshot antigo) e o local segue
  /// `pendingPush` para a próxima rodada — que o notifier já agenda.
  superseded,
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
///
/// Toda gravação passa por [_writeUnlessSuperseded]: o `save` da tela não
/// espera a rodada, então um toque que cai entre o `read` inicial e o
/// `write` final é mais novo que tudo que a rodada viu e não pode ser
/// sobrescrito (nem `pendingPush: false` sem ter subido).
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
      final written = await _writeUnlessSuperseded(
        sub,
        snapshot: local,
        next: remote.copyWith(pendingPush: false),
      );
      return MaterialKindPrefsSyncResult(
        written
            ? MaterialKindPrefsSyncOutcome.pulled
            : MaterialKindPrefsSyncOutcome.superseded,
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
      final written = await _writeUnlessSuperseded(
        sub,
        snapshot: local,
        next: saved.copyWith(pendingPush: false),
      );
      return MaterialKindPrefsSyncResult(
        written
            ? MaterialKindPrefsSyncOutcome.pushed
            : MaterialKindPrefsSyncOutcome.superseded,
        pullError: pullError,
      );
    } on MaterialKindPrefsConflict catch (conflict) {
      final written = await _writeUnlessSuperseded(
        sub,
        snapshot: local,
        next: conflict.remote.copyWith(pendingPush: false),
      );
      return MaterialKindPrefsSyncResult(
        written
            ? MaterialKindPrefsSyncOutcome.conflictAdopted
            : MaterialKindPrefsSyncOutcome.superseded,
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

  /// Grava [next] só se o documento local ainda é o [snapshot] que a rodada
  /// leu no início (ou algo com o mesmo `updatedAt`); `false` quando um
  /// `save` mais novo chegou no meio — esse fica como está, `pendingPush`,
  /// e sobe na rodada seguinte.
  Future<bool> _writeUnlessSuperseded(
    String sub, {
    required MaterialKindPrefs? snapshot,
    required MaterialKindPrefs next,
  }) async {
    final current = await _repository.read(sub);
    final superseded =
        current != null &&
        (snapshot == null || current.updatedAt.isAfter(snapshot.updatedAt));
    if (superseded) {
      debugPrint(
        '[material-kind-prefs] save mais novo durante a sync; mantido',
      );
      return false;
    }
    await _repository.write(sub, next);
    return true;
  }
}

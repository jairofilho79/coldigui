import 'dart:async';

/// Exclusão adiada em [PlaylistsNotifier.deleteWithUndo] (C11, spec B.3).
///
/// O item já saiu do estado quando este objeto é devolvido — [commit] roda a
/// exclusão de verdade (repositório) e [undo] recoloca o item; só um dos dois
/// pode acontecer, e só uma vez ([isSettled]). Sem `commit`/`undo` explícitos,
/// o [Timer] interno comita sozinho depois de `grace`.
class PendingDelete {
  // Dart não aceita identificador privado como rótulo de parâmetro nomeado —
  // a forma sugerida pelo lint perderia os nomes externos `onUndo`/`onCommit`.
  PendingDelete({
    required Duration grace,
    required Future<void> Function() onUndo,
    required Future<void> Function() onCommit,
  })
    // ignore: prefer_initializing_formals
    : _onUndo = onUndo,
       // ignore: prefer_initializing_formals
       _onCommit = onCommit {
    _timer = Timer(grace, () {
      unawaited(commit());
    });
  }

  final Future<void> Function() _onUndo;
  final Future<void> Function() _onCommit;
  Timer? _timer;
  bool _settled = false;

  /// `true` depois que [undo] ou [commit] rodou (inclusive via timer).
  bool get isSettled => _settled;

  /// Cancela a exclusão e recoloca o item — no-op se já [isSettled].
  Future<void> undo() async {
    if (_settled) return;
    _settled = true;
    _timer?.cancel();
    await _onUndo();
  }

  /// Roda a exclusão de verdade agora — no-op se já [isSettled].
  Future<void> commit() async {
    if (_settled) return;
    _settled = true;
    _timer?.cancel();
    await _onCommit();
  }
}

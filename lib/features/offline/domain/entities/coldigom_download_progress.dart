/// Progresso de [DownloadColdigomMaterials] — por kind e total (§5.2).
class ColdigomDownloadProgress {
  const ColdigomDownloadProgress({
    required this.kindId,
    required this.doneInKind,
    required this.totalInKind,
    required this.doneTotal,
    required this.total,
    required this.currentTitle,
  });

  final String kindId;
  final int doneInKind;
  final int totalInKind;
  final int doneTotal;
  final int total;

  /// «001 · Nome» do alvo que acabou de ser processado.
  final String currentTitle;
}

/// Um alvo que falhou — o download segue; a UI oferece «Tentar de novo».
class ColdigomDownloadFailure {
  const ColdigomDownloadFailure({
    required this.materialId,
    required this.cause,
  });

  final String materialId;
  final Object cause;
}

/// Resultado de [DownloadColdigomMaterials] (parcial se cancelado/quota).
class ColdigomDownloadResult {
  const ColdigomDownloadResult({
    required this.done,
    required this.skipped,
    required this.failed,
    required this.bytes,
    this.cancelled = false,
  });

  /// Baixados nesta execução.
  final int done;

  /// Já presentes (índice/cache) — não re-fetchados.
  final int skipped;
  final List<ColdigomDownloadFailure> failed;

  /// Bytes gravados nesta execução.
  final int bytes;

  /// Parado por cancelamento ou falta de espaço.
  final bool cancelled;

  bool get hasFailures => failed.isNotEmpty;
}

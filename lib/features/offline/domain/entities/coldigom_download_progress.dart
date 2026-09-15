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

  /// `''` na emissão inicial (antes de qualquer alvo ser processado) — só
  /// `doneTotal`/`total` são significativos nela.
  final String kindId;
  final int doneInKind;
  final int totalInKind;
  final int doneTotal;
  final int total;

  /// «001 · Nome» do alvo que acabou de ser processado, ou `''` na emissão
  /// inicial (ver [kindId]).
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

  /// Bytes gravados nesta execução — áudio, cifra e gestos.
  ///
  /// **PDF não soma aqui**: `FetchColdigomPdf` é `void` e não devolve o
  /// tamanho baixado; o PDF já fica contabilizado no `fileSize` do próprio
  /// `OfflinePdfRepository`/índice. Uma execução só de PDFs termina com
  /// `bytes == 0` mesmo tendo baixado — a UI não deve ler isso como "nada
  /// foi baixado".
  final int bytes;

  /// Parado por cancelamento ou falta de espaço.
  final bool cancelled;

  bool get hasFailures => failed.isNotEmpty;
}

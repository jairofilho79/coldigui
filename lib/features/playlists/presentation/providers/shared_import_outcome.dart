/// Desfechos de [SharedImportOutcome].
enum SharedImportStatus {
  /// Lista importada (ou a existente reaproveitada pela dedupe) e ativada.
  imported,

  /// Link sem nada importável — a UI mostra «Link inválido».
  invalid,

  /// Link de uma versão antiga (spec fim-fonte-plpcg §4.4) — a UI mostra
  /// `playlistShareLegacyLinkUnsupported`.
  legacy,
}

/// Resultado de `PlaylistsNotifier.importSharedFromUrl` («Importar lista»).
class SharedImportOutcome {
  /// Import feito: [playlistId] virou a lista ativa; [skippedCount] louvores
  /// do link ficaram de fora (fora do catálogo local ou sem material
  /// adicionável).
  const SharedImportOutcome.imported(
    String this.playlistId, {
    this.skippedCount = 0,
  }) : status = SharedImportStatus.imported;

  const SharedImportOutcome._(this.status)
    : playlistId = null,
      skippedCount = 0;

  static const invalid = SharedImportOutcome._(SharedImportStatus.invalid);
  static const legacy = SharedImportOutcome._(SharedImportStatus.legacy);

  final SharedImportStatus status;

  /// Lista importada; `null` fora de [SharedImportStatus.imported].
  final String? playlistId;

  /// Louvores do link que não entraram na lista.
  final int skippedCount;
}

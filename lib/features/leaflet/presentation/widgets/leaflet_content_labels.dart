import '../../../../l10n/app_localizations.dart';
import '../utils/leaflet_header_date.dart';

/// Textos do folheto resolvidos antes da captura off-screen (UC-08).
///
/// Evita depender de [AppLocalizations] no [OverlayEntry] de captura.
/// Usado por [LeafletContent] via [LeafletActionsNotifier.generateAndShare].
class LeafletContentLabels {
  const LeafletContentLabels({
    required this.headerTitle,
    required this.headerDateLine,
    required this.columnNumber,
    required this.columnName,
    required this.footerPeace,
    required this.footerGreeting,
  });

  /// Título do cabeçalho — ex.: `LOUVORES` ([leafletHeaderTitle]).
  final String headerTitle;

  /// Data formatada — ex.: `QUINTA-FEIRA 11/06/2026` ([formatLeafletHeaderDate]).
  final String headerDateLine;

  /// Rótulo da coluna de número ([leafletColumnNumber]).
  final String columnNumber;

  /// Rótulo da coluna de nome ([leafletColumnName]).
  final String columnName;

  /// Mensagem principal do rodapé ([leafletFooterPeace]).
  final String footerPeace;

  /// Saudação do rodapé ([leafletFooterGreeting]).
  final String footerGreeting;

  /// Monta labels a partir de [AppLocalizations] e [generatedAt].
  factory LeafletContentLabels.fromL10n(
    AppLocalizations l10n,
    DateTime generatedAt,
  ) {
    return LeafletContentLabels(
      headerTitle: l10n.leafletHeaderTitle,
      headerDateLine: formatLeafletHeaderDate(l10n, generatedAt),
      columnNumber: l10n.leafletColumnNumber,
      columnName: l10n.leafletColumnName,
      footerPeace: l10n.leafletFooterPeace,
      footerGreeting: l10n.leafletFooterGreeting,
    );
  }
}

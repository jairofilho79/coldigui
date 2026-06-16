import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../core/widgets/plpcg_app_bar_title.dart';
import '../../domain/entities/leaflet_document.dart';
import '../../domain/entities/leaflet_entry.dart';
import 'leaflet_content_labels.dart';

/// Largura fixa ~A4 portrait em 72dpi para PNG legível (UC-08).
const double kLeafletContentWidth = 595;

/// Layout do folheto para captura off-screen (UC-08).
///
/// Identidade PLPCG: moldura dourada, cabeçalho/rodapé marrom, tabela número/nome.
///
/// A raiz usa [Material] com [MaterialType.transparency] porque o widget é
/// inserido em um [OverlayEntry] fora de [Scaffold]. Sem ancestral [Material],
/// os [Text] exibem sublinhação dupla amarela (indicador debug do Flutter) e
/// o artefato aparece no PNG capturado.
class LeafletContent extends StatelessWidget {
  const LeafletContent({
    required this.document,
    required this.labels,
    super.key,
  });

  /// Dados da seleção (número/nome por louvor + data de geração).
  final LeafletDocument document;

  /// Textos localizados resolvidos antes da captura off-screen.
  final LeafletContentLabels labels;

  static const _garamond = AppTypography.garamondFamily;

  /// Grade horizontal única — alinha logo, colunas e rodapé.
  static const _insetH = 20.0;
  static const _numberColumnWidth = 80.0;
  static const _rowMinHeight = 48.0;
  static const _borderWidth = 2.0;
  static const _borderRadius = 6.0;

  /// Ritmo vertical em múltiplos de 4pt.
  static const _headerInsetV = 14.0;
  static const _rowInsetV = 12.0;
  static const _footerInsetV = 16.0;

  /// Escala tipográfica do folheto (corpo 14 → rótulos 12 → meta 11).
  static const _fontDate = 11.0;
  static const _fontColumnLabel = 12.0;
  static const _fontEntryNumber = 18.0;
  static const _fontEntryName = 14.0;
  static const _fontFooterPrimary = 15.0;
  static const _fontFooterSecondary = 12.0;

  static const _rowPadding =
      EdgeInsets.symmetric(horizontal: _insetH, vertical: _rowInsetV);

  /// Uma única espessura dourada em todo o folheto — evita soma de linhas
  /// adjacentes e mantém a moldura externa alinhada às divisórias internas.
  static const _goldBorder = BorderSide(
    color: AppColors.gold,
    width: _borderWidth,
  );

  /// Divisória horizontal desenhada só pelo bloco superior (borda inferior).
  static const _sectionDivider = BoxDecoration(
    border: Border(bottom: _goldBorder),
  );

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      color: AppColors.background,
      child: SizedBox(
        width: kLeafletContentWidth,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.gold, width: _borderWidth),
            borderRadius: BorderRadius.circular(_borderRadius),
            color: AppColors.background,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_borderRadius - _borderWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _HeaderBand(labels: labels),
                _ColumnHeaderRow(labels: labels),
                for (var i = 0; i < document.entries.length; i++)
                  _EntryRow(
                    entry: document.entries[i],
                    shaded: i.isEven,
                  ),
                _FooterBand(labels: labels),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderBand extends StatelessWidget {
  const _HeaderBand({required this.labels});

  final LeafletContentLabels labels;

  static const _leafletLogo = PlpcgAppBarTitle(showLightBeam: false);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: LeafletContent._insetH,
        vertical: LeafletContent._headerInsetV,
      ),
      decoration: LeafletContent._sectionDivider.copyWith(
        color: AppColors.background,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _leafletLogo,
          const Spacer(),
          Text(
            labels.headerDateLine,
            textAlign: TextAlign.right,
            style: _leafletMetaStyle(),
          ),
        ],
      ),
    );
  }
}

class _ColumnHeaderRow extends StatelessWidget {
  const _ColumnHeaderRow({required this.labels});

  final LeafletContentLabels labels;

  @override
  Widget build(BuildContext context) {
    return _LeafletTableRow(
      decoration: LeafletContent._sectionDivider.copyWith(
        color: AppColors.background,
      ),
      numberChild: Text(
        labels.columnNumber,
        textAlign: TextAlign.center,
        style: _leafletColumnLabelStyle(),
      ),
      nameChild: Text(
        labels.columnName,
        textAlign: TextAlign.center,
        style: _leafletColumnLabelStyle(),
      ),
    );
  }
}

/// Linha de duas colunas (número + nome) com grade e padding compartilhados.
class _LeafletTableRow extends StatelessWidget {
  const _LeafletTableRow({
    required this.numberChild,
    required this.nameChild,
    this.decoration,
    this.background,
  });

  final Widget numberChild;
  final Widget nameChild;
  final BoxDecoration? decoration;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final resolvedDecoration = decoration ??
        (background != null
            ? LeafletContent._sectionDivider.copyWith(color: background)
            : null);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        minHeight: LeafletContent._rowMinHeight,
      ),
      padding: LeafletContent._rowPadding,
      decoration: resolvedDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: LeafletContent._numberColumnWidth,
            child: numberChild,
          ),
          Expanded(child: nameChild),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.shaded,
  });

  final LeafletEntry entry;
  final bool shaded;

  @override
  Widget build(BuildContext context) {
    final background = shaded ? AppColors.card : Colors.white;
    final displayNumero =
        entry.numero.isEmpty ? '${entry.index}' : entry.numero;
    final displayNome = entry.nome.toUpperCase();

    return _LeafletTableRow(
      background: background,
      numberChild: Text(
        displayNumero,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: LeafletContent._garamond,
          fontWeight: FontWeight.w700,
          fontSize: LeafletContent._fontEntryNumber,
          height: 1.2,
          color: AppColors.title,
          decoration: TextDecoration.none,
        ),
      ),
      nameChild: Text(
        displayNome,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: LeafletContent._garamond,
          fontWeight: FontWeight.w600,
          fontSize: LeafletContent._fontEntryName,
          height: 1.35,
          letterSpacing: 0.2,
          color: AppColors.textDark,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class _FooterBand extends StatelessWidget {
  const _FooterBand({required this.labels});

  final LeafletContentLabels labels;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: LeafletContent._insetH,
        vertical: LeafletContent._footerInsetV,
      ),
      color: AppColors.background,
      child: Column(
        children: [
          Text(
            labels.footerPeace,
            textAlign: TextAlign.center,
            style: _leafletGoldStyle(
              fontSize: LeafletContent._fontFooterPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            labels.footerGreeting,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: LeafletContent._garamond,
              fontWeight: FontWeight.w500,
              fontSize: LeafletContent._fontFooterSecondary,
              height: 1.3,
              color: AppColors.placeholder.withValues(alpha: 0.95),
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

TextStyle _leafletGoldStyle({
  required double fontSize,
  FontWeight fontWeight = FontWeight.w700,
  double letterSpacing = 0.6,
}) {
  return TextStyle(
    fontFamily: LeafletContent._garamond,
    fontWeight: fontWeight,
    fontSize: fontSize,
    height: 1.2,
    letterSpacing: letterSpacing,
    color: AppColors.gold,
    decoration: TextDecoration.none,
  );
}

TextStyle _leafletColumnLabelStyle() {
  return _leafletGoldStyle(
    fontSize: LeafletContent._fontColumnLabel,
    letterSpacing: 0.5,
  );
}

TextStyle _leafletMetaStyle() {
  return _leafletGoldStyle(
    fontSize: LeafletContent._fontDate,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
  );
}

import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
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
  static const _numberColumnWidth = 88.0;
  static const _rowMinHeight = 52.0;
  static const _bandPadding =
      EdgeInsets.symmetric(horizontal: 20, vertical: 14);

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      color: AppColors.background,
      child: SizedBox(
        width: kLeafletContentWidth,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.gold, width: 2.5),
            borderRadius: BorderRadius.circular(6),
            color: AppColors.background,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: LeafletContent._bandPadding,
      color: AppColors.background,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              labels.headerTitle,
              style: _goldHeaderStyle(fontSize: 22),
            ),
          ),
          Text(
            labels.headerDateLine,
            textAlign: TextAlign.right,
            style: _goldHeaderStyle(fontSize: 13),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.gold, width: 1),
          bottom: BorderSide(color: AppColors.gold, width: 1),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: LeafletContent._numberColumnWidth,
            child: Text(
              labels.columnNumber,
              textAlign: TextAlign.center,
              style: _goldHeaderStyle(fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              labels.columnName,
              textAlign: TextAlign.center,
              style: _goldHeaderStyle(fontSize: 14),
            ),
          ),
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

    return Container(
      width: double.infinity,
      constraints:
          const BoxConstraints(minHeight: LeafletContent._rowMinHeight),
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: LeafletContent._numberColumnWidth,
            child: Text(
              displayNumero,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: LeafletContent._garamond,
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: AppColors.title,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          Expanded(
            child: Text(
              displayNome,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: LeafletContent._garamond,
                fontWeight: FontWeight.w600,
                fontSize: 15,
                height: 1.35,
                letterSpacing: 0.3,
                color: AppColors.textDark,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.gold, width: 1)),
      ),
      child: Column(
        children: [
          Text(
            labels.footerPeace,
            textAlign: TextAlign.center,
            style: _goldHeaderStyle(fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            labels.footerGreeting,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: LeafletContent._garamond,
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: AppColors.placeholder.withValues(alpha: 0.95),
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

TextStyle _goldHeaderStyle({required double fontSize}) {
  return TextStyle(
    fontFamily: LeafletContent._garamond,
    fontWeight: FontWeight.w700,
    fontSize: fontSize,
    letterSpacing: 0.8,
    color: AppColors.gold,
    decoration: TextDecoration.none,
  );
}

import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/core/widgets/golden_tagged_container.dart';
import 'package:coldigui/features/catalog/presentation/widgets/category_filters.dart';
import 'package:coldigui/features/catalog/presentation/widgets/classification_filters.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Painel de filtros colapsável com container dourado (§5.2).
///
/// Usado na Home e na Biblioteca. Estado colapsado exibe
/// [AppLocalizations.filtersTapToExpand]; expandido renderiza
/// [CategoryFilters] e [ClassificationFilters] (lógica UC-02 inalterada).
///
/// Na Biblioteca, passe [SpecialArrangementFilters] em
/// [additionalExpandedSections] (UC-03).
///
/// Cabeçalho compacto: [GoldenTaggedContainer.compactContentPaddingFor] e
/// altura intrínseca alinham texto e chevron.
class FiltersPanel extends StatefulWidget {
  const FiltersPanel({
    super.key,
    this.initiallyExpanded = false,
    this.showPlpcgSections = true,
    this.additionalExpandedSections = const [],
  });

  /// Expande ao montar quando a URL traz `materiais=` ou `arranjo=`.
  final bool initiallyExpanded;

  /// Quando `false`, omite [CategoryFilters]/[ClassificationFilters]
  /// (modo Coldigom usa só [additionalExpandedSections]).
  final bool showPlpcgSections;

  /// Seções extras após [ClassificationFilters] (ex.: arranjo especial na biblioteca).
  final List<Widget> additionalExpandedSections;

  @override
  State<FiltersPanel> createState() => _FiltersPanelState();
}

class _FiltersPanelState extends State<FiltersPanel> {
  late var _expanded = widget.initiallyExpanded;

  @override
  void didUpdateWidget(FiltersPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.initiallyExpanded && widget.initiallyExpanded) {
      _expanded = true;
    }
  }

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Semantics(
      expanded: _expanded,
      child: GoldenTaggedContainer(
        label: l10n.filtersTitle,
        onTap: _expanded ? null : _toggle,
        contentPadding: _expanded
            ? GoldenTaggedContainer.expandedSectionPaddingFor(context)
            : GoldenTaggedContainer.compactContentPaddingFor(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: _toggle,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      _expanded ? l10n.filtersTitle : l10n.filtersTapToExpand,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w500,
                        height: 1.1,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.title,
                    size: 20,
                  ),
                ],
              ),
            ),
            if (_expanded) ...[
              const SizedBox(height: 12),
              if (widget.showPlpcgSections) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: CategoryFilters(),
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: ClassificationFilters(),
                ),
              ],
              for (
                var i = 0;
                i < widget.additionalExpandedSections.length;
                i++
              ) ...[
                if (widget.showPlpcgSections || i > 0)
                  const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: widget.additionalExpandedSections[i],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

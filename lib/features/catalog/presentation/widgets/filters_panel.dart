import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/core/widgets/golden_tagged_container.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_filters_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/catalog_filter_sections.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Painel de filtros colapsável com container dourado (§5.2).
///
/// Usado na página inicial e na /biblioteca, com o mesmo conteúdo
/// ([CatalogFilterSections]). Com algum filtro ativo o cabeçalho mostra
/// [AppLocalizations.filtersActiveCount] (aberto ou colapsado): filtros
/// gravados restringem a busca mesmo sem nada na URL. Sem filtros, colapsado
/// mostra [AppLocalizations.filtersTapToExpand].
///
/// Cabeçalho compacto: [GoldenTaggedContainer.compactContentPaddingFor] e
/// altura intrínseca alinham texto e chevron.
class FiltersPanel extends ConsumerStatefulWidget {
  const FiltersPanel({super.key, this.initiallyExpanded = false});

  /// Expande ao montar quando há filtro ativo (da URL ou gravado).
  final bool initiallyExpanded;

  @override
  ConsumerState<FiltersPanel> createState() => _FiltersPanelState();
}

class _FiltersPanelState extends ConsumerState<FiltersPanel> {
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
    final activeCount = ref.watch(
      catalogFiltersProvider.select((filters) => filters.activeCount),
    );
    final header = activeCount > 0
        ? l10n.filtersActiveCount(activeCount)
        : _expanded
        ? l10n.filtersTitle
        : l10n.filtersTapToExpand;

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
                      header,
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
              const Align(
                alignment: Alignment.centerLeft,
                child: CatalogFilterSections(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

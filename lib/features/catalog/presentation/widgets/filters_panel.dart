import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/core/widgets/golden_tagged_container.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_filters_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/catalog_filter_sections.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier para override programático de expansão do painel de filtros.
class FiltersPanelExpandedNotifier extends Notifier<bool?> {
  FiltersPanelExpandedNotifier(this.scope);

  final CatalogFilterScope scope;

  @override
  bool? build() => null;

  void set(bool? value) => state = value;
}

/// Override programático para expansão do painel de filtros (ex.: tutoriais).
/// Quando `null`, segue o estado interno de expansão do usuário.
final filtersPanelExpandedOverrideProvider =
    NotifierProvider.family<
      FiltersPanelExpandedNotifier,
      bool?,
      CatalogFilterScope
    >(FiltersPanelExpandedNotifier.new);

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
  const FiltersPanel({
    super.key,
    this.initiallyExpanded = false,
    this.scope = CatalogFilterScope.home,
  });

  /// Expande ao montar quando há filtro ativo (da URL ou gravado).
  final bool initiallyExpanded;

  /// Escopo de filtros associado à tela (página inicial ou biblioteca).
  final CatalogFilterScope scope;

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

  void _toggle() {
    final override =
        ref.read(filtersPanelExpandedOverrideProvider(widget.scope));
    final current = override ?? _expanded;
    ref
        .read(filtersPanelExpandedOverrideProvider(widget.scope).notifier)
        .set(null);
    setState(() => _expanded = !current);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final activeCount = ref.watch(
      catalogFiltersProviderFor(widget.scope)
          .select((filters) => filters.activeCount),
    );
    final override =
        ref.watch(filtersPanelExpandedOverrideProvider(widget.scope));
    final isExpanded = override ?? _expanded;

    final header = activeCount > 0
        ? l10n.filtersActiveCount(activeCount)
        : isExpanded
        ? l10n.filtersTitle
        : l10n.filtersTapToExpand;

    return Semantics(
      expanded: isExpanded,
      child: GoldenTaggedContainer(
        label: l10n.filtersTitle,
        onTap: isExpanded ? null : _toggle,
        contentPadding: isExpanded
            ? GoldenTaggedContainer.expandedSectionPaddingFor(context)
            : GoldenTaggedContainer.compactContentPaddingFor(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _toggle,
                    child: Text(
                      header,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w500,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
                if (activeCount > 0) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => ref
                        .read(catalogFiltersProviderFor(widget.scope).notifier)
                        .clear(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.title,
                      side: const BorderSide(color: AppColors.gold, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      minimumSize: const Size(0, 28),
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: AppTypography.label.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    child: Text(l10n.filtersClear),
                  ),
                  const SizedBox(width: 4),
                ],
                InkWell(
                  onTap: _toggle,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppColors.title,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            if (isExpanded) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: CatalogFilterSections(scope: widget.scope),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


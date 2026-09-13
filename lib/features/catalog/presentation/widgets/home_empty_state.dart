import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/connectivity_stream_provider.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/catalog_material.dart';
import '../providers/catalog_filters_provider.dart';
import '../providers/catalog_material_lookup_provider.dart';
import '../providers/home_search_state.dart';
import '../providers/open_material_provider.dart';
import '../providers/recently_opened_provider.dart';

/// Estado vazio da Home (C4) — renderizado por `HomeSearchResultsSliver` no
/// lugar do antigo `SizedBox.shrink()`.
///
/// Dois ramos mutuamente exclusivos, escolhidos só por [HomeSearchState.query]
/// (o chamador só monta este widget quando `state.groups` já está vazio):
/// - sem consulta: chips "abertos recentemente" + hint de busca (o cartão da
///   lista ativa que a onda 4 pôs aqui saiu na 4.2: a barra do carousel já
///   mostra a lista, o louvor em foco e o botão de abrir — product owner);
/// - consulta sem resultado: "nenhum louvor" + dicas + limpar filtros (se
///   houver filtro fora do padrão) + aviso Coldigom (se a busca remota falhou
///   e o dispositivo está offline).
class HomeEmptyState extends ConsumerWidget {
  const HomeEmptyState({required this.state, super.key});

  final HomeSearchState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: state.isEmptyQuery
          ? const _NoQueryContent()
          : _NoResultsContent(state: state),
    );
  }
}

/// Material resolvido por id para os cartões/chips desta tela — mesmo
/// vocabulário do `openMaterialProvider` (C.5).
CatalogMaterial? _resolveMaterial(CatalogMaterialLookup lookup, String id) {
  final louvor = lookup.louvor(id);
  if (louvor != null) return PdfMaterial(louvor);
  final chord = lookup.chord(id);
  if (chord != null) return ChordMaterialRef(chord);
  final gesture = lookup.gesture(id);
  if (gesture != null) return GestureMaterialRef(gesture);
  final track = lookup.audioTrack(id);
  if (track != null) return AudioMaterial(track);
  return null;
}

/// Label de exibição de um material já resolvido (número + nome).
String _materialLabel(CatalogMaterial material) {
  final (numero, nome) = switch (material) {
    PdfMaterial(:final louvor) => (louvor.numero, louvor.nome),
    ChordMaterialRef(:final chord) => (chord.numero, chord.nome),
    GestureMaterialRef(:final gesture) => (gesture.numero, gesture.nome),
    AudioMaterial(:final track) => (track.numero, track.nome),
    YoutubeMaterialRef() => ('', material.categoria),
  };
  return numero.isEmpty ? nome : '$numero $nome';
}

class _NoQueryContent extends ConsumerWidget {
  const _NoQueryContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final recentIds = ref.watch(recentlyOpenedProvider);
    final lookup = ref.watch(catalogMaterialLookupProvider);

    final recentMaterials = <CatalogMaterial>[
      for (final id in recentIds) ?_resolveMaterial(lookup, id),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (recentMaterials.isNotEmpty) ...[
          Text(
            l10n.homeEmptyRecent,
            style: AppTypography.label.copyWith(color: AppColors.textLight),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final material in recentMaterials)
                // `ActionChip` mantém o fundo creme do `ChipThemeData` — texto
                // vinho (`AppColors.title`, padrão do tema) fica correto aqui,
                // mesmo com o restante deste estado vazio no fundo vinho do
                // `Scaffold` da Home.
                ActionChip(
                  key: ValueKey(material.id),
                  label: Text(_materialLabel(material)),
                  onPressed: () => ref
                      .read(openMaterialProvider)
                      .open(context, ref, material),
                ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        Center(
          child: Text(
            l10n.homeEmptyHint,
            // Fundo vinho do `Scaffold` da Home (product owner, onda 4.1):
            // `AppTypography.hint()` é vinho, pensado para o card creme.
            style: AppTypography.hint().copyWith(
              color: AppColors.textLight.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _NoResultsContent extends ConsumerWidget {
  const _NoResultsContent({required this.state});

  final HomeSearchState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final filters = ref.watch(catalogFiltersProvider);
    final hasActiveFilter =
        filters.materiaisUrlValue != null || filters.arranjoUrlValue != null;
    final connectivity = ref.watch(connectivityStreamProvider);
    final isOffline = connectivity.value == false;
    final showColdigomOffline = state.remoteFailed && isOffline;

    // Fundo vinho do `Scaffold` da Home (product owner, onda 4.1):
    // `AppTypography.body`/`hint()` e o `foregroundColor` default de
    // `OutlinedButton` (`colorScheme.primary`) são vinho, pensados para o
    // card creme — este estado vazio precisa de branco explícito.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.homeNoResults(state.query),
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textLight,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.homeNoResultsTips,
          style: AppTypography.hint().copyWith(
            color: AppColors.textLight.withValues(alpha: 0.7),
          ),
        ),
        if (hasActiveFilter) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textLight,
              side: BorderSide(
                color: AppColors.textLight.withValues(alpha: 0.7),
              ),
            ),
            onPressed: () => ref.read(catalogFiltersProvider.notifier).reset(),
            child: Text(l10n.homeClearFilters),
          ),
        ],
        if (showColdigomOffline) ...[
          const SizedBox(height: 12),
          Text(
            l10n.homeColdigomOffline,
            style: AppTypography.body.copyWith(
              color: AppColors.textLight.withValues(alpha: 0.75),
            ),
          ),
        ],
      ],
    );
  }
}

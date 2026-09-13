import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/connectivity_stream_provider.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../carousel/domain/entities/carousel_item.dart';
import '../../../carousel/presentation/widgets/carousel_louvor_chip.dart';
import '../../domain/entities/catalog_material.dart';
import '../../domain/entities/louvor_data_source.dart';
import '../providers/catalog_filters_provider.dart';
import '../providers/catalog_material_lookup_provider.dart';
import '../providers/home_search_state.dart';
import '../providers/open_material_provider.dart';
import '../providers/recently_opened_provider.dart';

/// Largura de cada cartão na «janela deslizante» de recentes (C6).
const _recentCardWidth = 220.0;

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

/// Adapta um [CatalogMaterial] já resolvido para o `item` que
/// [CarouselLouvorChip] espera — mesmo chip da barra de playlist do leitor
/// (C6): dá de graça a cor por [LouvorDataSource] (vermelho PLPCG / preto
/// Coldigom), a borda dourada e a linha "classificação · categoria".
CarouselItem _toCarouselItem(CatalogMaterial material, int index) {
  final (numero, nome, classificacao, source) = switch (material) {
    PdfMaterial(:final louvor) => (
      louvor.numero,
      louvor.nome,
      louvor.classificacao,
      louvor.source,
    ),
    ChordMaterialRef(:final chord) => (
      chord.numero,
      chord.nome,
      chord.classificacao,
      chord.source,
    ),
    GestureMaterialRef(:final gesture) => (
      gesture.numero,
      gesture.nome,
      gesture.classificacao,
      gesture.source,
    ),
    AudioMaterial(:final track) => (
      track.numero,
      track.nome,
      track.classificacao,
      track.source,
    ),
    YoutubeMaterialRef(material: final youtube) => (
      youtube.numero,
      youtube.nome,
      youtube.classificacao,
      youtube.source,
    ),
  };
  return CarouselItem(
    materialId: material.id,
    kind: material.kind,
    index: index,
    numero: numero,
    nome: nome,
    categoria: material.categoria,
    classificacao: classificacao,
    source: source,
  );
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
          // Cartão creme próprio (C6, feedback do product owner): a seção
          // não fica mais solta sobre o fundo vinho do `Scaffold` — mesmo
          // contraste que os demais cards do tema (`AppColors.card` + borda
          // dourada do `CardThemeData`).
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.homeEmptyRecent,
                    style: AppTypography.label.copyWith(
                      color: AppColors.title,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // «Janela deslizante» (C6): rolagem horizontal em vez de
                  // `Wrap` — a seção nunca cresce verticalmente, e o teto de
                  // [kRecentlyOpenedMaxSize] já garante no máximo 5 cartões.
                  SizedBox(
                    height: carouselChipBarHeight,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: recentMaterials.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final material = recentMaterials[index];
                        return SizedBox(
                          width: _recentCardWidth,
                          child: CarouselLouvorChip(
                            key: ValueKey(material.id),
                            item: _toCarouselItem(material, index),
                            onTap: () => ref
                                .read(openMaterialProvider)
                                .open(context, ref, material),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/connectivity_stream_provider.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../playlists/domain/entities/saved_playlist.dart';
import '../../../playlists/presentation/providers/active_playlist_provider.dart';
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
/// - sem consulta: cartão da lista ativa + chips "abertos recentemente" +
///   hint de busca;
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
  final track = lookup.audioTrack(id);
  if (track != null) return AudioMaterial(track);
  return null;
}

/// Label de exibição de um material já resolvido (número + nome).
String _materialLabel(CatalogMaterial material) {
  final (numero, nome) = switch (material) {
    PdfMaterial(:final louvor) => (louvor.numero, louvor.nome),
    ChordMaterialRef(:final chord) => (chord.numero, chord.nome),
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
    final activePlaylist = ref.watch(activePlaylistProvider);
    final recentIds = ref.watch(recentlyOpenedProvider);
    final lookup = ref.watch(catalogMaterialLookupProvider);

    final recentMaterials = <CatalogMaterial>[
      for (final id in recentIds) ?_resolveMaterial(lookup, id),
    ];

    final hasActivePlaylist =
        activePlaylist != null && activePlaylist.entries.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasActivePlaylist) ...[
          _ActivePlaylistCard(playlist: activePlaylist, l10n: l10n),
          const SizedBox(height: 20),
        ],
        if (recentMaterials.isNotEmpty) ...[
          Text(l10n.homeEmptyRecent, style: AppTypography.label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final material in recentMaterials)
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
            style: AppTypography.hint(),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _ActivePlaylistCard extends ConsumerWidget {
  const _ActivePlaylistCard({required this.playlist, required this.l10n});

  final SavedPlaylist playlist;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.homeEmptyActiveList(playlist.nome, playlist.entries.length),
              style: AppTypography.body,
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () {
              final lookup = ref.read(catalogMaterialLookupProvider);
              final material = _resolveMaterial(
                lookup,
                playlist.entries.first.id,
              );
              if (material == null) return;
              ref.read(openMaterialProvider).open(context, ref, material);
            },
            child: Text(l10n.homeEmptyOpenActive),
          ),
        ],
      ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.homeNoResults(state.query),
          style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(l10n.homeNoResultsTips, style: AppTypography.hint()),
        if (hasActiveFilter) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => ref.read(catalogFiltersProvider.notifier).reset(),
            child: Text(l10n.homeClearFilters),
          ),
        ],
        if (showColdigomOffline) ...[
          const SizedBox(height: 12),
          Text(
            l10n.homeColdigomOffline,
            style: AppTypography.body.copyWith(
              color: AppColors.title.withValues(alpha: 0.75),
            ),
          ),
        ],
      ],
    );
  }
}

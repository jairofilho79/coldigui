import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/storage_unavailable_exception.dart';
import '../../../../core/network/connectivity_stream_provider.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/material_id_kind.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../carousel/presentation/providers/carousel_items_provider.dart';
import '../../../offline/presentation/providers/material_availability_map_provider.dart';
import '../../../pdf_opening/domain/entities/pdf_offline_availability.dart';
import '../../../playlists/presentation/providers/active_playlist_editor.dart';
import '../../../chords/domain/entities/chord_material.dart';
import '../../../chords/presentation/providers/available_chords_provider.dart';
import '../../../coldigom/domain/entities/coldigom_praise_metadata.dart';
import '../../../contributions/domain/entities/contribution_kind.dart';
import '../../../contributions/domain/entities/contribution_target.dart';
import '../../../contributions/presentation/utils/open_contribute.dart';
import '../../../material_kind_prefs/domain/usecases/order_by_favorite_kinds.dart';
import '../../../material_kind_prefs/presentation/providers/material_kind_prefs_provider.dart';
import '../../domain/entities/catalog_material.dart';
import '../../domain/entities/louvor_group.dart';
import '../../domain/utils/louvor_material_icons.dart';
import '../providers/open_material_provider.dart';
import 'material_sheet_actions.dart';

/// Abre o material escolhido no sheet. O padrão é o `openMaterialProvider`.
typedef MaterialSheetOpener = Future<void> Function(CatalogMaterial material);

/// Sheet único de escolha de material — PLPCG e Coldigom.
///
/// Substitui `showLouvorMaterialSheet` e `showColdigomMaterialSheet`: o acervo
/// deixou de decidir o layout. O grupo é renderizado sempre igual — uma aba por
/// tipo presente (PDF, cifras, gestos, áudio, YouTube, letra) quando há mais de
/// um, senão a lista direta — e o cabeçalho de metadados aparece quando o
/// grupo tem [LouvorGroup.coldigomMeta].
///
/// [canAddToPlaylist] `false` esconde os `+` — é o caso da troca de material no
/// leitor, onde o louvor já está na lista.
///
/// [onMaterialSelected] substitui a abertura padrão; a troca de material passa
/// o seu próprio handler porque, no leitor, escolher outro PDF **substitui** a
/// entrada do carousel em vez de empilhar uma rota nova.
Future<void> showMaterialSheet(
  BuildContext context,
  WidgetRef ref,
  LouvorGroup group, {
  bool canAddToPlaylist = true,
  MaterialSheetOpener? onMaterialSelected,
}) {
  // O `context`/`ref` capturados aqui são os de quem abriu o sheet: eles
  // sobrevivem ao pop do modal, o `BuildContext` do sheet não.
  //
  // `audioQueue` é a fila do grupo: tocar um arranjo enfileira os irmãos, como
  // os dois sheets antigos faziam com `playAudioInSession(queue: ...)`.
  final open =
      onMaterialSelected ??
      (CatalogMaterial material) => ref
          .read(openMaterialProvider)
          .open(context, ref, material, audioQueue: group.audioTracks);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return MaterialSheet(
        group: group,
        onMaterialSelected: open,
        canAddToPlaylist: canAddToPlaylist,
      );
    },
  );
}

/// Corpo do sheet de materiais. Use [showMaterialSheet] para exibi-lo.
class MaterialSheet extends ConsumerStatefulWidget {
  const MaterialSheet({
    required this.group,
    required this.onMaterialSelected,
    this.canAddToPlaylist = true,
    super.key,
  });

  final LouvorGroup group;
  final MaterialSheetOpener onMaterialSelected;
  final bool canAddToPlaylist;

  @override
  ConsumerState<MaterialSheet> createState() => _MaterialSheetState();
}

class _MaterialSheetState extends ConsumerState<MaterialSheet> {
  String? _addingId;

  /// Aba escolhida; null = a primeira presente.
  MaterialKind? _selectedKind;

  void _handleTap(CatalogMaterial material) {
    Navigator.of(context).pop();

    if (material is AudioMaterial) {
      // Pop primeiro (o modal sai do stack antes de qualquer push), mas ainda
      // no mesmo tap: `play()` num post-frame perde o gesto no iOS Safari.
      unawaited(widget.onMaterialSelected(material));
      return;
    }

    // Pós-frame: evita race push vs pop (modal ainda no stack).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(widget.onMaterialSelected(material));
    });
  }

  Future<void> _handleAdd(CatalogMaterial material) async {
    if (_addingId != null) return;

    setState(() => _addingId = material.id);
    try {
      await addMaterialToActivePlaylist(
        context: context,
        ref: ref,
        material: material,
      );
    } finally {
      if (mounted) setState(() => _addingId = null);
    }
  }

  /// `×` da linha: confirma e tira [material] da lista ativa (todas as
  /// ocorrências — o sheet só sabe que ele «está lá», por id).
  Future<void> _handleRemove(CatalogMaterial material) async {
    if (_addingId != null) return;
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.materialRemoveConfirmTitle,
      message: l10n.materialRemoveConfirmMessage(material.categoria),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _addingId = material.id);
    try {
      await ref
          .read(activePlaylistEditorProvider.notifier)
          .removeById(material.id);
      if (mounted) showAppSnackbar(context, l10n.materialRemoved);
    } on StorageUnavailableException {
      if (mounted) showAppSnackbar(context, l10n.playlistStorageUnavailable);
    } finally {
      if (mounted) setState(() => _addingId = null);
    }
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Text(
        text,
        style: AppTypography.label.copyWith(
          color: AppColors.title,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// [icon] só é passado quando a `categoria` decide o ícone — o caso do PDF,
  /// cujo tipo real (Partitura/Cifra/Gestos) o manifest só diz por texto.
  /// Cifra, gestos, áudio e YouTube têm [CatalogMaterial.kind] confiável e caem em
  /// [LouvorMaterialIcons.forMaterial].
  Widget _materialTile({
    required CatalogMaterial material,
    required Color iconColor,
    required Set<String> activeMaterialIds,
    required AppLocalizations l10n,
    IconData? icon,
    String? subtitle,
    bool enabled = true,
  }) {
    final showAdd =
        widget.canAddToPlaylist && canAddMaterialToPlaylist(material);
    final isAdded = activeMaterialIds.contains(material.id);
    return ListTile(
      enabled: enabled,
      leading: Icon(
        icon ?? LouvorMaterialIcons.forMaterial(material),
        color: iconColor,
      ),
      title: Text(
        material.categoria,
        style: AppTypography.body.copyWith(color: AppColors.textDark),
      ),
      subtitle: subtitle == null || subtitle.isEmpty
          ? null
          : Text(
              subtitle,
              style: AppTypography.label.copyWith(
                color: AppColors.textDark.withValues(alpha: 0.7),
              ),
            ),
      trailing: showAdd
          ? MaterialAddTrailing(
              // As duas faces são a mesma lista (B.1): áudio já adicionado
              // também mostra o × de remover.
              isAdded: isAdded,
              isAdding: _addingId == material.id,
              removeTooltip: l10n.materialRemoveTooltip,
              onAdd: () => _handleAdd(material),
              onRemove: () => _handleRemove(material),
            )
          : null,
      onTap: () => _handleTap(material),
    );
  }

  /// O14: sem rede, só o que está no aparelho abre. Letra nunca desabilita
  /// (vive no Isar); YouTube precisa de rede sempre; o resto consulta o mapa
  /// de disponibilidade. Online nada muda — e se a deteção de rede errar,
  /// o tile fica ativo e o erro de abertura já existente aparece.
  ({bool enabled, String? subtitle}) _availabilityFor(
    CatalogMaterial material, {
    required bool online,
    required Map<String, PdfOfflineAvailability> availability,
    required AppLocalizations l10n,
  }) {
    if (online) return (enabled: true, subtitle: null);
    return switch (material) {
      LyricsMaterial() => (enabled: true, subtitle: null),
      YoutubeMaterialRef() => (
        enabled: false,
        subtitle: l10n.materialNeedsConnection,
      ),
      PdfMaterial() ||
      ChordMaterialRef() ||
      GestureMaterialRef() ||
      AudioMaterial() =>
        availability.containsKey(material.id)
            ? (enabled: true, subtitle: null)
            : (enabled: false, subtitle: l10n.materialNotDownloadedOffline),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final group = widget.group;
    final meta = group.coldigomMeta;
    final activeMaterialIds = ref.watch(activeMaterialIdsProvider);
    // Favoritos da conta (spec D9): sobem dentro de cada aba, o resto mantém
    // a ordem do servidor. Vazio para deslogado e para o acervo PLPCG.
    final rank = ref.watch(favoriteMaterialKindRankProvider);

    // O14: `.value ?? true` cobre o `AsyncLoading` inicial do stream — sem
    // sinal ainda, o sheet trata como online (nada desabilita à toa).
    final online = ref.watch(connectivityStreamProvider).value ?? true;
    final availability = ref.watch(materialAvailabilityMapProvider);

    // Helper local para não repetir `_availabilityFor` nos seis pontos que
    // montam um tile — o subtítulo de indisponibilidade ganha do autor do
    // áudio: é a informação acionável offline.
    Widget tileFor(
      CatalogMaterial material, {
      required Color iconColor,
      IconData? icon,
      String? subtitle,
    }) {
      final state = _availabilityFor(
        material,
        online: online,
        availability: availability,
        l10n: l10n,
      );
      return _materialTile(
        material: material,
        icon: icon,
        iconColor: iconColor,
        activeMaterialIds: activeMaterialIds,
        l10n: l10n,
        enabled: state.enabled,
        subtitle: state.subtitle ?? subtitle,
      );
    }

    // As cifras do grupo já estão no cache Coldigom: quem monta o grupo
    // (busca/browse, detalhe do praise, catálogo em memória) as funde no data
    // pelo `ColdigomCacheWriter` — a presentation só lê (C.3).
    //
    // `.value ?? []` sozinho transformava `AsyncError` em "este louvor não tem
    // cifra"; o estado é lido inteiro para o erro virar uma linha de retry.
    final chordsAsync = group.chordMaterials.isEmpty
        ? const AsyncData<List<ChordMaterial>>(<ChordMaterial>[])
        : ref.watch(availableChordsProvider(group.groupId));
    final availableChords = chordsAsync.value ?? const <ChordMaterial>[];

    final gestureMaterials = group.gestureMaterials;
    final audioTracks = group.audioTracks;
    final youtubeMaterials = group.youtubeMaterials;

    // Abas por tipo (PDF / Cifras / Gestos / Áudio / YouTube / Letra) só quando há mais de um
    // tipo — com 17 PDFs e 14 áudios a lista corrida escondia o áudio no fim
    // (onda 4.3). Dentro da aba de PDF as seções por classificação continuam
    // separadas por rótulo quando há mais de uma.
    final kinds = <MaterialKind>[
      if (group.totalPdfs > 0) MaterialKind.pdf,
      if (availableChords.isNotEmpty || chordsAsync.hasError)
        MaterialKind.chord,
      if (gestureMaterials.isNotEmpty) MaterialKind.gesture,
      if (audioTracks.isNotEmpty) MaterialKind.audio,
      if (youtubeMaterials.isNotEmpty) MaterialKind.youtube,
      if (group.lyrics != null) MaterialKind.lyrics,
    ];
    final showSegments = kinds.length > 1;
    // Aba escolhida que sumiu (cifras que deixaram de carregar) cai na
    // primeira em vez de deixar a lista vazia.
    final selectedIndex = kinds.indexOf(_selectedKind ?? MaterialKind.pdf);
    final selectedKind = kinds.isEmpty
        ? null
        : kinds[selectedIndex < 0 ? 0 : selectedIndex];

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SheetHeader(group: group, l10n: l10n),
            if (meta != null && meta.hasAnyField) ...[
              const SizedBox(height: 16),
              _ColdigomMetaBlock(meta: meta, l10n: l10n),
            ],
            const SizedBox(height: 12),
            const Divider(color: AppColors.gold, height: 1, thickness: 1.5),
            if (!online) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.cloud_off,
                    size: 16,
                    color: AppColors.title.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.materialSheetOfflineBanner,
                      style: AppTypography.label.copyWith(
                        color: AppColors.title.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (showSegments) ...[
              const SizedBox(height: 12),
              _KindSegmentBar(
                labels: [for (final kind in kinds) _kindLabel(l10n, kind)],
                selectedIndex: kinds.indexOf(selectedKind!),
                onSelected: (index) {
                  setState(() => _selectedKind = kinds[index]);
                },
              ),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: switch (selectedKind) {
                  null => const [],
                  MaterialKind.pdf => _pdfTiles(group, l10n, rank, tileFor),
                  MaterialKind.chord => _chordTiles(
                    group,
                    availableChords,
                    chordsAsync.hasError,
                    l10n,
                    rank,
                    tileFor,
                  ),
                  MaterialKind.gesture => [
                    for (final gesture in orderByFavoriteKinds(
                      gestureMaterials,
                      rank,
                      kindIdOf: (g) => g.materialKindId,
                    ))
                      tileFor(
                        GestureMaterialRef(gesture),
                        iconColor: AppColors.title,
                      ),
                  ],
                  MaterialKind.audio => [
                    for (final track in orderByFavoriteKinds(
                      audioTracks,
                      rank,
                      kindIdOf: (t) => t.materialKindId,
                    ))
                      tileFor(
                        AudioMaterial(track),
                        iconColor: AppColors.title,
                        subtitle: track.author,
                      ),
                  ],
                  MaterialKind.youtube => [
                    for (final item in orderByFavoriteKinds(
                      youtubeMaterials,
                      rank,
                      kindIdOf: (y) => y.materialKindId,
                    ))
                      tileFor(
                        YoutubeMaterialRef(item),
                        iconColor: AppColors.youtube,
                      ),
                  ],
                  MaterialKind.lyrics => [
                    tileFor(group.lyrics!, iconColor: AppColors.title),
                  ],
                  // `kinds` só emite os seis acima; se um dia emitir outro,
                  // que falhe alto em vez de mostrar uma aba vazia.
                  MaterialKind.unknown => throw StateError(
                    'kind sem aba: $selectedKind',
                  ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// PDFs por seção; o rótulo da seção só quando há mais de uma. Classificação
  /// vazia (praise Coldigom sem ritmo) cai em «Partituras» em vez de um rótulo
  /// em branco.
  List<Widget> _pdfTiles(
    LouvorGroup group,
    AppLocalizations l10n,
    Map<String, int> rank,
    Widget Function(
      CatalogMaterial, {
      required Color iconColor,
      IconData? icon,
      String? subtitle,
    })
    tileFor,
  ) {
    final showSectionLabels = group.sections.length > 1;
    return [
      for (final section in group.sections) ...[
        if (showSectionLabels)
          _sectionLabel(
            section.displayLabel.trim().isEmpty
                ? l10n.pdfMaterialSection
                : section.displayLabel,
          ),
        // Favoritos sobem dentro da seção; o ícone depende da entry (não do
        // material isolado), então quem é reordenado é a entry, não o PDF.
        for (final entry in orderByFavoriteKinds(
          section.materials,
          rank,
          kindIdOf: (e) => e.louvor.materialKindId,
        ))
          tileFor(
            PdfMaterial(entry.louvor),
            icon: LouvorMaterialIcons.forEntry(entry),
            iconColor: AppColors.title,
          ),
      ],
    ];
  }

  List<Widget> _chordTiles(
    LouvorGroup group,
    List<ChordMaterial> availableChords,
    bool hasError,
    AppLocalizations l10n,
    Map<String, int> rank,
    Widget Function(
      CatalogMaterial, {
      required Color iconColor,
      IconData? icon,
      String? subtitle,
    })
    tileFor,
  ) {
    return [
      for (final chord in orderByFavoriteKinds(
        availableChords,
        rank,
        kindIdOf: (c) => c.materialKindId,
      ))
        tileFor(ChordMaterialRef(chord), iconColor: AppColors.title),
      // Defensivo: `availableChordsProvider` engole falha de rede por cifra
      // (a cifra fica listada), então este ramo só é alcançado por erro
      // inesperado. Fica porque o custo é uma linha e a alternativa — aba
      // vazia sem explicação — é pior. Contrato pinado em
      // `available_chords_provider_test.dart`.
      if (hasError)
        ListTile(
          leading: const Icon(Icons.refresh, color: AppColors.title),
          title: Text(
            l10n.chordUnavailableRetry,
            style: AppTypography.body.copyWith(color: AppColors.textDark),
          ),
          onTap: () => ref.invalidate(availableChordsProvider(group.groupId)),
        ),
    ];
  }

  static String _kindLabel(AppLocalizations l10n, MaterialKind kind) {
    return switch (kind) {
      MaterialKind.pdf => l10n.pdfMaterialSection,
      MaterialKind.chord => l10n.chordMaterialSection,
      MaterialKind.gesture => l10n.gesturesMaterialSection,
      MaterialKind.audio => l10n.audioMaterialSection,
      MaterialKind.youtube => l10n.youtubeMaterialSection,
      MaterialKind.lyrics => l10n.lyricsTab,
      MaterialKind.unknown => throw StateError('kind sem aba: $kind'),
    };
  }
}

/// Barra de segmentos por tipo de material — uma aba por kind presente.
class _KindSegmentBar extends StatelessWidget {
  const _KindSegmentBar({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.title.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: _KindSegmentChip(
                  label: labels[i],
                  selected: i == selectedIndex,
                  onTap: () => onSelected(i),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KindSegmentChip extends StatelessWidget {
  const _KindSegmentChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.gold.withValues(alpha: 0.25)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          alignment: Alignment.center,
          constraints: const BoxConstraints(minHeight: 36),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(color: AppColors.gold, width: 1.5)
                : null,
          ),
          child: Text(
            label,
            style: AppTypography.label.copyWith(
              color: selected
                  ? AppColors.title
                  : AppColors.title.withValues(alpha: 0.55),
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Cabeçalho: número destacado, nome e o botão de fechar.
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.group, required this.l10n});

  final LouvorGroup group;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: group.numero.isNotEmpty
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      group.numero,
                      style: AppTypography.headline.copyWith(
                        color: AppColors.title,
                        fontSize: 22,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        group.nome,
                        style: AppTypography.headline.copyWith(
                          color: AppColors.title,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                )
              : Text(
                  group.nome,
                  style: AppTypography.headline.copyWith(
                    color: AppColors.title,
                  ),
                ),
        ),
        IconButton(
          tooltip: l10n.contributeReportTooltip,
          onPressed: () {
            // `openContribute` primeiro: o push vai para o navigator raiz
            // enquanto o `context` do sheet ainda está montado. Se o `pop`
            // viesse antes, o `context` morreria e `GoRouter.of(context)`
            // dentro de `openContribute` já não teria a quem perguntar.
            openContribute(
              context,
              target: ContributionTarget(
                source: ContributionSource.coldigom,
                praiseId: group.groupId,
              ),
            );
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.flag_outlined, color: AppColors.title),
          style: IconButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(44, 44),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        IconButton(
          tooltip: l10n.carouselListClose,
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, color: AppColors.title),
          style: IconButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(44, 44),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }
}

/// Bloco de metadados do praise Coldigom (tom, ritmo, autor, categoria, tags).
class _ColdigomMetaBlock extends StatelessWidget {
  const _ColdigomMetaBlock({required this.meta, required this.l10n});

  final ColdigomPraiseMetadata meta;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final tonality = meta.tonality.trim();
    final rhythm = meta.rhythm.trim();
    final author = meta.author.trim();
    final category = meta.category.trim();
    final hasPair = tonality.isNotEmpty || rhythm.isNotEmpty;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasPair)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: tonality.isNotEmpty
                        ? _metaField(l10n.coldigomMetaTonality, tonality)
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: rhythm.isNotEmpty
                        ? _metaField(l10n.coldigomMetaRhythm, rhythm)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            if (author.isNotEmpty) ...[
              if (hasPair) const SizedBox(height: 10),
              _metaField(l10n.coldigomMetaAuthor, author),
            ],
            if (category.isNotEmpty) ...[
              if (hasPair || author.isNotEmpty) const SizedBox(height: 10),
              _metaField(l10n.coldigomMetaCategory, category),
            ],
            if (meta.tagNames.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                l10n.coldigomMetaTags.toUpperCase(),
                style: AppTypography.tagLabel.copyWith(
                  color: AppColors.title.withValues(alpha: 0.7),
                  letterSpacing: 1.1,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final tag in meta.tagNames)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.gold, width: 1.5),
                      ),
                      child: Text(
                        tag,
                        style: AppTypography.label.copyWith(
                          color: AppColors.title,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metaField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.label.copyWith(
            color: AppColors.title.withValues(alpha: 0.75),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.body.copyWith(
            color: AppColors.title,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

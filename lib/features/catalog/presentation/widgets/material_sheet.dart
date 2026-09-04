import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../carousel/presentation/providers/carousel_louvores_provider.dart';
import '../../../chords/domain/entities/chord_material.dart';
import '../../../chords/presentation/providers/available_chords_provider.dart';
import '../../../coldigom/data/providers/coldigom_providers.dart';
import '../../../coldigom/domain/entities/coldigom_praise_metadata.dart';
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
/// deixou de decidir o layout. O grupo é renderizado sempre igual (seções de
/// PDF, depois [LouvorGroup.extras] por tipo) e o cabeçalho de metadados
/// aparece quando o grupo tem [LouvorGroup.coldigomMeta].
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
  final open =
      onMaterialSelected ??
      (CatalogMaterial material) =>
          ref.read(openMaterialProvider).open(context, ref, material);

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

  @override
  void initState() {
    super.initState();
    final chords = widget.group.chordMaterials;
    if (chords.isEmpty) return;
    // Pós-frame: mutar provider durante a construção do widget dispara
    // "setState during build" nos ouvintes do cache.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(coldigomChordMaterialsCacheProvider.notifier)
          .mergeChords(chords);
    });
  }

  void _handleTap(CatalogMaterial material) {
    if (material is AudioMaterial) {
      // play() no mesmo tap — post-frame perde o gesto no iOS Safari.
      unawaited(widget.onMaterialSelected(material));
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pop();
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

  Widget _materialTile({
    required CatalogMaterial material,
    required IconData icon,
    required Color iconColor,
    required Set<String> carouselPdfIds,
    String? subtitle,
  }) {
    final showAdd =
        widget.canAddToPlaylist && canAddMaterialToPlaylist(material);
    return ListTile(
      leading: Icon(icon, color: iconColor),
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
              // Áudio nunca vira chip do carousel — o ✓ é só de PDF.
              isAdded:
                  material is PdfMaterial &&
                  carouselPdfIds.contains(material.id),
              isAdding: _addingId == material.id,
              onAdd: () => _handleAdd(material),
            )
          : null,
      onTap: () => _handleTap(material),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final group = widget.group;
    final meta = group.coldigomMeta;
    final carouselPdfIds = ref.watch(carouselPdfIdsProvider);

    // `.value ?? []` sozinho transformava `AsyncError` em "este louvor não tem
    // cifra"; o estado é lido inteiro para o erro virar uma linha de retry.
    final chordsAsync = group.chordMaterials.isEmpty
        ? const AsyncData<List<ChordMaterial>>(<ChordMaterial>[])
        : ref.watch(availableChordsProvider(group.groupId));
    final availableChords = chordsAsync.value ?? const <ChordMaterial>[];

    // Um rótulo só não separa nada — grupos de um arranjo (todo praise
    // Coldigom, por exemplo) mostram a lista direto.
    final showSectionLabels = group.sections.length > 1;
    final audioTracks = group.audioTracks;
    final youtubeMaterials = group.youtubeMaterials;

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
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final section in group.sections) ...[
                    if (showSectionLabels) _sectionLabel(section.displayLabel),
                    for (final entry in section.materials)
                      _materialTile(
                        material: PdfMaterial(entry.louvor),
                        icon: LouvorMaterialIcons.forEntry(entry),
                        iconColor: AppColors.title,
                        carouselPdfIds: carouselPdfIds,
                      ),
                  ],
                  if (availableChords.isNotEmpty || chordsAsync.hasError) ...[
                    _sectionLabel(l10n.chordMaterialSection),
                    for (final chord in availableChords)
                      _materialTile(
                        material: ChordMaterialRef(chord),
                        icon: LouvorMaterialIcons.forKind(
                          LouvorMaterialIcons.kindForCategory(chord.categoria),
                        ),
                        iconColor: AppColors.title,
                        carouselPdfIds: carouselPdfIds,
                      ),
                    if (chordsAsync.hasError)
                      ListTile(
                        leading: const Icon(
                          Icons.refresh,
                          color: AppColors.title,
                        ),
                        title: Text(
                          l10n.chordUnavailableRetry,
                          style: AppTypography.body.copyWith(
                            color: AppColors.textDark,
                          ),
                        ),
                        onTap: () => ref.invalidate(
                          availableChordsProvider(group.groupId),
                        ),
                      ),
                  ],
                  if (audioTracks.isNotEmpty) ...[
                    _sectionLabel(l10n.audioMaterialSection),
                    for (final track in audioTracks)
                      _materialTile(
                        material: AudioMaterial(track),
                        icon: LouvorMaterialIcons.audio,
                        iconColor: AppColors.title,
                        carouselPdfIds: carouselPdfIds,
                        subtitle: track.author,
                      ),
                  ],
                  if (youtubeMaterials.isNotEmpty) ...[
                    _sectionLabel(l10n.youtubeMaterialSection),
                    for (final item in youtubeMaterials)
                      _materialTile(
                        material: YoutubeMaterialRef(item),
                        icon: LouvorMaterialIcons.youtube,
                        iconColor: AppColors.youtube,
                        carouselPdfIds: carouselPdfIds,
                      ),
                  ],
                ],
              ),
            ),
          ],
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

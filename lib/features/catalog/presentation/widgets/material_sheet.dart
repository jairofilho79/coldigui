import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../core/utils/material_id_kind.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../carousel/presentation/utils/related_praises_swapper.dart';
import '../../../coldigom/presentation/providers/coldigom_catalog_providers.dart';
import '../../../contributions/domain/entities/contribution_kind.dart';
import '../../../contributions/domain/entities/contribution_target.dart';
import '../../../contributions/presentation/utils/open_contribute.dart';
import '../../domain/entities/catalog_material.dart';
import '../../domain/entities/louvor_group.dart';
import '../providers/catalog_material_lookup_provider.dart';
import '../providers/open_material_provider.dart';
import 'coldigom_meta_block.dart';
import 'praise_materials_view.dart';
import 'related_praises_bar.dart';

/// Abre o material escolhido no sheet. O padrão é o `openMaterialProvider`.
typedef MaterialSheetOpener = Future<void> Function(CatalogMaterial material);

/// Sheet único de escolha de material — PLPCG e Coldigom.
///
/// Substitui `showLouvorMaterialSheet` e `showColdigomMaterialSheet`: o acervo
/// deixou de decidir o layout. O grupo é renderizado sempre igual — uma aba por
/// tipo presente (PDF, cifras, gestos, áudio, YouTube) quando há mais de
/// um, senão a lista direta — e o cabeçalho de metadados e prévia da letra
/// aparecem quando disponíveis.
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
  MaterialKind? initialKind,
  String? currentMaterialId,
  String? currentEntryKey,
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
        initialKind: initialKind,
        currentMaterialId: currentMaterialId,
        currentEntryKey: currentEntryKey,
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
    this.initialKind,
    this.currentMaterialId,
    this.currentEntryKey,
    super.key,
  });

  final LouvorGroup group;
  final MaterialSheetOpener onMaterialSelected;
  final bool canAddToPlaylist;
  final MaterialKind? initialKind;
  final String? currentMaterialId;
  final String? currentEntryKey;

  @override
  ConsumerState<MaterialSheet> createState() => _MaterialSheetState();
}

class _MaterialSheetState extends ConsumerState<MaterialSheet> {
  late LouvorGroup _currentGroup;

  @override
  void initState() {
    super.initState();
    _currentGroup = widget.group;
  }

  void _handleTap(CatalogMaterial material) {
    Navigator.of(context).pop();

    if (material is AudioMaterial) {
      unawaited(widget.onMaterialSelected(material));
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(widget.onMaterialSelected(material));
    });
  }

  void _handleOpenLyrics() {
    final lyrics = _currentGroup.lyrics ??
        LyricsMaterial(
          praiseId: _currentGroup.groupId,
          nome: _currentGroup.nome,
          numero: _currentGroup.numero,
        );
    _handleTap(lyrics);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final group = _currentGroup;
    final meta = group.coldigomMeta;

    final catalogRow = ref.watch(coldigomCatalogRowProvider(group.groupId));
    final lyricsText = catalogRow?.lyrics.trim() ?? '';

    final index = ref.watch(coldigomSearchIndexProvider);
    final relatedPraises = resolveRelatedPraisesForGroup(group, index);

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
            _SheetHeader(
              group: group,
              l10n: l10n,
            ),
            if (relatedPraises.length > 1) ...[
              const SizedBox(height: 12),
              RelatedPraisesBar(
                praises: relatedPraises,
                selectedPraise: group,
                l10n: l10n,
                onSelected: (target) async {
                  if (target.groupId == group.groupId) return;
                  final effectiveKey = widget.currentEntryKey;
                  if (!widget.canAddToPlaylist && effectiveKey != null) {
                    await swapToRelatedPraise(
                      ref: ref,
                      context: context,
                      targetGroup: target,
                      currentEntryKey: effectiveKey,
                      currentMaterialId: widget.currentMaterialId,
                      allMembers: relatedPraises,
                    );
                  }
                  if (mounted) {
                    setState(() {
                      _currentGroup = ref
                          .read(catalogMaterialLookupProvider)
                          .withPraiseMeta(target);
                    });
                  }
                },
              ),
            ],
            if ((meta != null && meta.hasAnyField) || lyricsText.isNotEmpty) ...[
              const SizedBox(height: 16),
              ColdigomMetaBlock(
                meta: meta,
                lyricsText: lyricsText,
                onOpenLyrics: _handleOpenLyrics,
                l10n: l10n,
              ),
            ],
            const SizedBox(height: 12),
            const Divider(color: AppColors.gold, height: 1, thickness: 1.5),
            const SizedBox(height: 8),
            Expanded(
              child: PraiseMaterialsView(
                group: group,
                canAddToPlaylist: widget.canAddToPlaylist,
                initialKind: widget.initialKind,
                onMaterialSelected: (m) async => _handleTap(m),
                currentMaterialId: widget.currentMaterialId,
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
  const _SheetHeader({
    required this.group,
    required this.l10n,
  });

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
          tooltip: l10n.praiseOpenDetailsTooltip,
          onPressed: () {
            final praiseId =
                group.coldigomMeta?.shortId ?? group.groupId;
            final router = GoRouter.of(context);
            Navigator.of(context).pop();
            router.go(RoutePaths.praiseFor(praiseId));
          },
          icon: const Icon(Icons.open_in_full, color: AppColors.title),
          style: IconButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(44, 44),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: l10n.contributeReportTooltip,
          onPressed: () {
            openContribute(
              context,
              target: ContributionTarget(
                source: ContributionSource.coldigom,
                praiseId: group.groupId,
              ),
            );
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.handshake_outlined, color: AppColors.title),
          style: IconButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(44, 44),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 8),
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



import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../core/tutorial/presentation/providers/tutorial_provider.dart';
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
    backgroundColor: Colors.transparent,
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
  final SpotlightGuidePortalController _portalController =
      SpotlightGuidePortalController();

  @override
  void initState() {
    super.initState();
    _currentGroup = widget.group;
    try {
      ref
          .read(tutorialControllerProvider)
          .pushPortalController(_portalController);
    } catch (_) {}
  }

  @override
  void dispose() {
    try {
      if (_portalController.isShowing) {
        _portalController.hide();
      }
      ref
          .read(tutorialControllerProvider)
          .popPortalController(_portalController);
    } catch (_) {}
    super.dispose();
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final group = _currentGroup;
    final meta = group.coldigomMeta;

    final catalogRow = ref.watch(coldigomCatalogRowProvider(group.groupId));
    final lyricsText = catalogRow?.lyrics.trim() ?? '';

    final index = ref.watch(coldigomSearchIndexProvider);
    final relatedPraises = resolveRelatedPraisesForGroup(group, index);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SpotlightGuidePortal(
          controller: _portalController,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12, bottom: 4),
                  child: _SheetHeader(
                    group: group,
                    l10n: l10n,
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottomInset),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (relatedPraises.length > 1) ...[
                          SpotlightGuideTarget(
                            id: 'material-sheet-related',
                            child: RelatedPraisesBar(
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
                          ),
                          const SizedBox(height: 12),
                        ],
                        SpotlightGuideTarget(
                          id: 'material-sheet-meta',
                          child: ColdigomMetaBlock(
                            title: group.nome,
                            number: group.numero,
                            meta: meta,
                            lyricsText: lyricsText,
                            onOpenLyrics: _handleOpenLyrics,
                            l10n: l10n,
                            collapsibleDetails: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(
                          color: AppColors.gold,
                          height: 1,
                          thickness: 1.5,
                        ),
                        const SizedBox(height: 8),
                        PraiseMaterialsView(
                          group: group,
                          canAddToPlaylist: widget.canAddToPlaylist,
                          initialKind: widget.initialKind,
                          onMaterialSelected: (m) async => _handleTap(m),
                          currentMaterialId: widget.currentMaterialId,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Cabeçalho: ações do topo (abrir página completa, contribuir, tutorial, fechar).
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
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
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
            minimumSize: const Size(40, 40),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 8),
        SpotlightGuideTarget(
          id: 'material-sheet-contribute',
          child: IconButton(
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
              minimumSize: const Size(40, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SpotlightGuideTarget(
          id: 'material-sheet-info',
          child: IconButton(
            tooltip: l10n.tutorialTooltipHowToUseMaterialSheet,
            onPressed: () {
              try {
                final container =
                    ProviderScope.containerOf(context, listen: false);
                container
                    .read(tutorialControllerProvider)
                    .startMaterialSheetTutorial(context);
              } catch (_) {}
            },
            icon: const Icon(Icons.info_outline, color: AppColors.title),
            style: IconButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(40, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: l10n.carouselListClose,
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, color: AppColors.title),
          style: IconButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(40, 40),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }
}



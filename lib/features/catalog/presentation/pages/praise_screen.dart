import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/connectivity_stream_provider.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../core/utils/praise_url_builder.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../carousel/presentation/utils/related_praises_swapper.dart';
import '../../../coldigom/presentation/providers/coldigom_catalog_providers.dart';
import '../../../contributions/domain/entities/contribution_kind.dart';
import '../../../contributions/domain/entities/contribution_target.dart';
import '../../../contributions/presentation/utils/open_contribute.dart';
import '../../../lyrics/presentation/providers/lyrics_reader_font_size_provider.dart';
import '../../../lyrics/presentation/utils/lyrics_reader_url_builder.dart';
import '../../domain/entities/louvor_group.dart';
import '../providers/catalog_material_lookup_provider.dart';
import '../widgets/coldigom_meta_block.dart';
import '../widgets/praise_materials_view.dart';
import '../widgets/related_praises_bar.dart';

/// Tela detalhada do louvor (`/louvor/:id`).
///
/// Apresenta o louvor como página completa equivalente ao `MaterialSheet`,
/// com a adição da letra à mostra, mantendo o header da aplicação e a barra
/// de playlist (`CarouselChips`) ativos no shell.
class PraiseScreen extends ConsumerStatefulWidget {
  const PraiseScreen({
    required this.id,
    this.queryParams = const {},
    super.key,
  });

  /// Identificador do louvor — pode ser um `shortId` (ex: `0a1`) ou `praiseId` (UUID).
  final String id;

  final Map<String, String> queryParams;

  @override
  ConsumerState<PraiseScreen> createState() => _PraiseScreenState();
}

class _PraiseScreenState extends ConsumerState<PraiseScreen> {
  double? _fontSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(catalogIndexStatusProvider) != CatalogIndexStatus.ready) {
        unawaited(ref.read(coldigomCatalogSyncProvider.notifier).sync());
      }
    });
  }

  void _retryCatalog() {
    ref.invalidate(coldigomCatalogHydrationProvider);
    unawaited(ref.read(coldigomCatalogSyncProvider.notifier).sync());
  }

  double _resolveFontSize(double globalFontSize) {
    return _fontSize ?? globalFontSize;
  }

  void _increaseFontSize(double current) {
    setState(() {
      _fontSize = (current + 2).clamp(12.0, 32.0);
    });
  }

  void _decreaseFontSize(double current) {
    setState(() {
      _fontSize = (current - 2).clamp(12.0, 32.0);
    });
  }

  Future<void> _handleShare(LouvorGroup group) async {
    final l10n = AppLocalizations.of(context)!;
    final shareId = group.coldigomMeta?.shortId ?? group.groupId;
    final shareUrl = buildPraiseShareUrl(id: shareId);

    await Clipboard.setData(ClipboardData(text: shareUrl));
    if (mounted) {
      showAppSnackbar(context, l10n.praiseShareLinkCopied);
    }
  }

  void _handleContribute(LouvorGroup group) {
    openContribute(
      context,
      target: ContributionTarget(
        source: ContributionSource.coldigom,
        praiseId: group.groupId,
      ),
    );
  }

  void _handleCopyLyrics(String lyrics) {
    final l10n = AppLocalizations.of(context)!;
    Clipboard.setData(ClipboardData(text: lyrics));
    showAppSnackbar(context, l10n.praiseLyricsCopied);
  }

  void _handleOpenLyricsReader(LouvorGroup group) {
    context.push(
      buildLyricsReaderLocation(
        praiseId: group.groupId,
        titulo: group.nome,
        subtitulo: group.numero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final globalFontSize = ref.watch(lyricsReaderFontSizeProvider);
    final effectiveFontSize = _resolveFontSize(globalFontSize);

    final status = ref.watch(catalogIndexStatusProvider);
    final index = ref.watch(coldigomSearchIndexProvider);

    ref.listen<AsyncValue<bool>>(connectivityStreamProvider, (previous, next) {
      if (next.value != true) return;
      if (ref.read(catalogIndexStatusProvider) == CatalogIndexStatus.failed) {
        _retryCatalog();
      }
    });

    final rawGroup = index.groupByShortId(widget.id) ??
        index.groupById(widget.id) ??
        index.groupForMaterialId(widget.id);

    if (rawGroup == null) {
      if (status == CatalogIndexStatus.loading) {
        return const Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: CircularProgressIndicator(color: AppColors.gold),
          ),
        );
      }

      if (status == CatalogIndexStatus.failed) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Material(
                  color: AppColors.card,
                  elevation: 3,
                  shadowColor: Colors.black.withValues(alpha: 0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.gold, width: 1.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_outlined,
                          size: 48,
                          color: AppColors.title,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.catalogLoadError,
                          textAlign: TextAlign.center,
                          style: AppTypography.headline.copyWith(
                            color: AppColors.title,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _retryCatalog,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.title,
                            foregroundColor: AppColors.textLight,
                          ),
                          child: Text(l10n.retry),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Material(
                color: AppColors.card,
                elevation: 3,
                shadowColor: Colors.black.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.gold, width: 1.5),
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.music_off_outlined,
                        size: 56,
                        color: AppColors.title,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.praiseNotFound,
                        textAlign: TextAlign.center,
                        style: AppTypography.headline.copyWith(
                          color: AppColors.title,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => context.go(RoutePaths.home),
                        icon: const Icon(Icons.arrow_back),
                        label: Text(l10n.praiseBackToSearch),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.title,
                          foregroundColor: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final group = ref.watch(catalogMaterialLookupProvider).withPraiseMeta(rawGroup);
    final meta = group.coldigomMeta;
    final relatedPraises = resolveRelatedPraisesForGroup(group, index);

    final catalogRow = ref.watch(coldigomCatalogRowProvider(group.groupId));
    final lyricsText = catalogRow?.lyrics.trim() ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 768;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Material(
                  color: AppColors.card,
                  elevation: 3,
                  shadowColor: Colors.black.withValues(alpha: 0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.gold, width: 1.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildPraiseHeader(group, l10n),
                      if (relatedPraises.length > 1) ...[
                        const SizedBox(height: 12),
                        RelatedPraisesBar(
                          praises: relatedPraises,
                          selectedPraise: group,
                          l10n: l10n,
                          onSelected: (target) {
                            if (target.groupId == group.groupId) return;
                            final nextId =
                                target.coldigomMeta?.shortId ?? target.groupId;
                            context.go(RoutePaths.praiseFor(nextId));
                          },
                        ),
                      ],
                      if (isWide) ...[
                        if (meta != null && meta.hasAnyField) ...[
                          const SizedBox(height: 16),
                          ColdigomMetaBlock(
                            meta: meta,
                            l10n: l10n,
                            showLyricsPreview: false,
                          ),
                        ],
                        const SizedBox(height: 16),
                        const Divider(
                          color: AppColors.gold,
                          height: 1,
                          thickness: 1.5,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: _buildLyricsSection(
                                lyricsText: lyricsText,
                                fontSize: effectiveFontSize,
                                l10n: l10n,
                                group: group,
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 5,
                              child: _buildMaterialsSection(group, l10n),
                            ),
                          ],
                        ),
                      ] else ...[
                        if ((meta != null && meta.hasAnyField) ||
                            lyricsText.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          ColdigomMetaBlock(
                            meta: meta,
                            lyricsText: lyricsText,
                            onOpenLyrics: () => _handleOpenLyricsReader(group),
                            l10n: l10n,
                          ),
                        ],
                        const SizedBox(height: 16),
                        const Divider(
                          color: AppColors.gold,
                          height: 1,
                          thickness: 1.5,
                        ),
                        const SizedBox(height: 20),
                        _buildMaterialsSection(group, l10n),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
  }

  Widget _buildPraiseHeader(LouvorGroup group, AppLocalizations l10n) {
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
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        group.nome,
                        style: AppTypography.headline.copyWith(
                          color: AppColors.title,
                          fontSize: 20,
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
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        IconButton(
          tooltip: l10n.praiseShareTooltip,
          icon: const Icon(Icons.share_outlined, color: AppColors.title),
          onPressed: () => _handleShare(group),
        ),
        IconButton(
          tooltip: l10n.contributeReportTooltip,
          icon: const Icon(Icons.handshake_outlined, color: AppColors.title),
          onPressed: () => _handleContribute(group),
        ),
      ],
    );
  }

  Widget _buildMaterialsSection(LouvorGroup group, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.library_music_outlined,
              size: 20,
              color: AppColors.title,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.praiseMaterialsSectionTitle,
              style: AppTypography.headline.copyWith(
                fontSize: 18,
                color: AppColors.title,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        PraiseMaterialsView(
          group: group,
          canAddToPlaylist: true,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
        ),
      ],
    );
  }

  Widget _buildLyricsSection({
    required String lyricsText,
    required double fontSize,
    required AppLocalizations l10n,
    required LouvorGroup group,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.lyrics_outlined,
              size: 20,
              color: AppColors.title,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.praiseLyricsSectionTitle,
              style: AppTypography.headline.copyWith(
                fontSize: 18,
                color: AppColors.title,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (lyricsText.isNotEmpty) ...[
              IconButton(
                tooltip: l10n.praiseDecreaseFontSizeTooltip,
                icon: const Icon(Icons.text_decrease, size: 20),
                color: AppColors.title,
                onPressed: () => _decreaseFontSize(fontSize),
              ),
              IconButton(
                tooltip: l10n.praiseIncreaseFontSizeTooltip,
                icon: const Icon(Icons.text_increase, size: 20),
                color: AppColors.title,
                onPressed: () => _increaseFontSize(fontSize),
              ),
              IconButton(
                tooltip: l10n.praiseLyricsCopyTooltip,
                icon: const Icon(Icons.copy_rounded, size: 20),
                color: AppColors.title,
                onPressed: () => _handleCopyLyrics(lyricsText),
              ),
              IconButton(
                tooltip: l10n.praiseOpenLyricsReader,
                icon: const Icon(Icons.play_circle_outline, size: 22),
                color: AppColors.title,
                onPressed: () => _handleOpenLyricsReader(group),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (lyricsText.isEmpty)
          Material(
            color: const Color(0xFFFFFDF5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: AppColors.gold.withValues(alpha: 0.3),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                l10n.praiseNoLyricsAvailable,
                style: AppTypography.body.copyWith(
                  color: AppColors.textDark.withValues(alpha: 0.6),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          )
        else
          Material(
            color: const Color(0xFFFFFDF5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: AppColors.gold.withValues(alpha: 0.35),
              ),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: SelectableText(
                lyricsText,
                style: AppTypography.body.copyWith(
                  color: AppColors.textDark,
                  fontSize: fontSize,
                  height: 1.6,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

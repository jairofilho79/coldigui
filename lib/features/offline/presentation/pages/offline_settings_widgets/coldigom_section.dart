import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/l10n/failure_message.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/theme/color_extensions.dart';
import '../../../../../core/utils/byte_format.dart';
import '../../../../../core/utils/material_id_kind.dart';
import '../../../../../core/widgets/confirm_dialog.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../../auth/presentation/widgets/google_sign_in_button.dart';
import '../../../../coldigom/presentation/providers/coldigom_catalog_providers.dart';
import '../../../../material_kind_prefs/presentation/providers/material_kind_prefs_provider.dart';
import '../../../data/utils/storage_quota_estimator.dart';
import '../../../domain/entities/coldigom_download_progress.dart';
import '../../../domain/entities/coldigom_download_target.dart';
import '../../../domain/exceptions/offline_bulk_exceptions.dart';
import '../../../../catalog/domain/entities/material_kind_taxonomy.dart';
import '../../../../catalog/domain/utils/material_kind_selection.dart';
import '../../../../catalog/presentation/widgets/material_kind_chips.dart';
import '../../providers/offline_cache_status_provider.dart';
import '../../providers/offline_coldigom_download_provider.dart';
import '../../providers/offline_coldigom_kind_selection_provider.dart';
import '../../providers/offline_coldigom_stats_provider.dart';
import '../../providers/offline_maintenance_lock_provider.dart';
import 'offline_kind_chips.dart';

/// Quantos alvos ainda faltam no último `progress` conhecido — usado tanto
/// no snackbar de conclusão quanto na linha persistente sob os botões
/// quando `result.cancelled` (achado do review final: um cancelamento com
/// `done == 0` não pode ler como "nada novo para baixar").
int _remainingCount(OfflineColdigomDownloadState state) {
  final progress = state.progress;
  if (progress == null) return 0;
  final remaining = progress.total - progress.doneTotal;
  return remaining < 0 ? 0 : remaining;
}

bool _hasInsufficientSpace(ColdigomDownloadResult result) =>
    result.failed.any((f) => f.cause is InsufficientDiskSpaceException);

/// Texto da linha persistente/snackbar quando a execução parou sem
/// terminar tudo — falta de espaço tem prioridade (mensagem específica),
/// depois cancelamento («Parado — N restantes»), depois falhas comuns.
String _resultStatusText(
  AppLocalizations l10n,
  OfflineColdigomDownloadState state,
) {
  final result = state.result!;
  if (_hasInsufficientSpace(result)) return l10n.offlineColdigomOutOfSpace;
  if (result.cancelled) {
    return l10n.offlineColdigomStopped(_remainingCount(state));
  }
  return l10n.offlineColdigomFailures(result.failed.length);
}

/// `~1,2 MB` quando há estimativa (O13), `1,2 MB` quando tudo é conhecido.
String coldigomSizeLabel(int bytes, {required bool estimated}) =>
    '${estimated ? '~' : ''}${formatCompactBytes(bytes)}';

/// A secção única do `/offline` — «Baixar para usar offline» (spec
/// 2026-09-23 §3.1): estado do catálogo e do disco, tipos de material,
/// baixar/parar/remover. Sem login mostra todos os tipos; a conta só traz os
/// favoritos para o topo.
class ColdigomOfflineSection extends ConsumerWidget {
  const ColdigomOfflineSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(authStateProvider).asData?.value;
    final sync = ref.watch(coldigomCatalogSyncProvider);
    final cacheStatus = ref.watch(offlineCacheStatusProvider);
    final lockOwner = ref.watch(offlineMaintenanceLockProvider);
    final download = ref.watch(offlineColdigomDownloadProvider);
    // Um estado de ocupado só (§3.1): decide o lock. O nosso não nos
    // desabilita — é o «Parar» que fica ativo.
    final busy =
        lockOwner != null && lockOwner != OfflineMaintenanceOwner.coldigom;

    ref.listen(offlineColdigomDownloadProvider, (previous, next) {
      if (next.failure != null && next.failure != previous?.failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failureMessage(l10n, next.failure!))),
        );
      }
      if (next.status == OfflineColdigomDownloadStatus.done &&
          previous?.status != next.status &&
          next.result != null) {
        final result = next.result!;
        // Cancelado ou com falhas: mensagem específica (achado do review
        // final) — nunca "nada novo para baixar" quando na verdade parou
        // no meio. Sem cancelamento/falhas, a contagem normal de baixados.
        final message = result.cancelled || result.hasFailures
            ? _resultStatusText(l10n, next)
            : l10n.offlineColdigomDone(result.done);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatusLines(
          sync: sync,
          cacheStatus: cacheStatus,
          l10n: l10n,
          busy: busy || download.isActive || download.removing,
        ),
        const SizedBox(height: 12),
        if (user == null) ...[
          _SignInRow(l10n: l10n),
          const SizedBox(height: 8),
        ],
        _KindsBody(
          l10n: l10n,
          busy: busy,
          download: download,
          signedIn: user != null,
        ),
      ],
    );
  }
}

class _StatusLines extends ConsumerWidget {
  const _StatusLines({
    required this.sync,
    required this.cacheStatus,
    required this.l10n,
    required this.busy,
  });

  final ColdigomCatalogSyncState sync;
  final OfflineCacheStatus cacheStatus;
  final AppLocalizations l10n;
  final bool busy;

  String _ago(DateTime? at) {
    if (at == null) return l10n.offlineColdigomAgoJustNow;
    final diff = DateTime.now().toUtc().difference(at.toUtc());
    if (diff.inMinutes < 1) return l10n.offlineColdigomAgoJustNow;
    if (diff.inHours < 1) return l10n.offlineColdigomAgoMinutes(diff.inMinutes);
    if (diff.inDays < 1) return l10n.offlineColdigomAgoHours(diff.inHours);
    return l10n.offlineColdigomAgoDays(diff.inDays);
  }

  String _diskUsage() {
    final used = formatCompactBytes(cacheStatus.diskUsageBytes);
    final free = cacheStatus.freeDiskBytes;
    return free == null
        ? l10n.offlineStatsDiskUsageUsedOnly(used)
        : l10n.offlineStatsDiskUsage(used, formatCompactBytes(free));
  }

  /// Um «Atualizar» (desvio 4 do plano): catálogo (sync por ETag) + índice
  /// offline (reconcile + uso de disco).
  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    unawaited(ref.read(coldigomCatalogSyncProvider.notifier).sync());
    try {
      await ref.read(offlineCacheStatusProvider.notifier).refreshAll();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.offlineRefreshSuccess)));
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.offlineRefreshError)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = sync.count == 0
        ? l10n.offlineColdigomCatalogMissing
        : l10n.offlineColdigomCatalogStatus(
            sync.count,
            _ago(sync.lastSyncedAt),
          );
    final hintStyle = AppTypography.body.copyWith(
      color: AppColors.title.withValues(alpha: 0.75),
    );
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(catalog, style: hintStyle),
              const SizedBox(height: 4),
              Text(_diskUsage(), style: hintStyle),
            ],
          ),
        ),
        if (sync.isSyncing || cacheStatus.isRefreshing)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          TextButton.icon(
            onPressed: busy ? null : () => unawaited(_refresh(context, ref)),
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(l10n.offlineRefreshStats),
          ),
      ],
    );
  }
}

/// Deslogado: convite opcional — os tipos aparecem na mesma (§3.1, M8).
class _SignInRow extends StatelessWidget {
  const _SignInRow({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          l10n.offlineColdigomSignInPrompt,
          textAlign: TextAlign.center,
          style: AppTypography.hint(),
        ),
        const SizedBox(height: 8),
        const GoogleSignInButton(),
      ],
    );
  }
}

class _KindsBody extends ConsumerStatefulWidget {
  const _KindsBody({
    required this.l10n,
    required this.busy,
    required this.download,
    required this.signedIn,
  });

  final AppLocalizations l10n;
  final bool busy;
  final OfflineColdigomDownloadState download;
  final bool signedIn;

  @override
  ConsumerState<_KindsBody> createState() => _KindsBodyState();
}

class _KindsBodyState extends ConsumerState<_KindsBody> {
  final Map<String, bool> _open = {};

  Future<void> _start(
    BuildContext context,
    WidgetRef ref,
    Set<String> kindIds,
    Set<String> selection,
    int bytes,
    bool estimated, {
    MaterialKindTaxonomy? taxonomy,
  }) async {
    final free = await estimateFreeStorageBytes();
    if (free != null && bytes > free && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.l10n.offlineColdigomSpaceWarning(
              coldigomSizeLabel(bytes, estimated: estimated),
              formatCompactBytes(free),
            ),
          ),
        ),
      );
    }
    await ref.read(offlineColdigomDownloadProvider.notifier).start(
      kindIds,
      selection: selection,
      taxonomy: taxonomy,
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: widget.l10n.offlineColdigomRemoveConfirmTitle,
      message: widget.l10n.offlineColdigomRemoveConfirmBody,
    );
    if (confirmed != true || !context.mounted) return;
    final result = await ref
        .read(offlineColdigomDownloadProvider.notifier)
        .removeDownloads();
    if (result == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.l10n.offlineColdigomRemoved(
            result.removedPdfs,
            result.removedAudios,
          ),
        ),
      ),
    );
    unawaited(
      ref
          .read(offlineCacheStatusProvider.notifier)
          .refresh()
          .catchError(
            (Object e) => debugPrint('[offline] uso de disco não relido: $e'),
          ),
    );
  }

  List<Widget> _renderUnit({
    required OfflineKindUnit unit,
    required Set<String> selection,
    required bool enabled,
    required void Function(String) onToggle,
    required void Function(String, MaterialKind, Set<MaterialKind>) onToggleType,
    required void Function(OfflineKindFamilyUnit, MaterialKind) onToggleFamilyType,
  }) {
    switch (unit) {
      case OfflineKindSingleUnit(:final kind):
        return [
          OfflineKindChip(
            kind: kind,
            l10n: widget.l10n,
            checked: selection.contains(kind.kindId),
            enabled: enabled,
            selection: selection,
            onChanged: () => onToggle(kind.kindId),
            onToggleType: (type) =>
                onToggleType(kind.kindId, type, kind.effectiveTypes.keys.toSet()),
          ),
        ];
      case OfflineKindFamilyUnit(:final parentId, :final children):
        final childIds = [for (final c in children) c.kindId];
        final state = materialKindFamilyState(parentId, childIds, selection);
        final open = _open[parentId] ?? state == MaterialKindFamilyState.refined;
        final familyChip = OfflineKindFamilyChip(
          unit: unit,
          state: state,
          expanded: open,
          enabled: enabled,
          selection: selection,
          l10n: widget.l10n,
          onToggle: () => onToggle(parentId),
          onExpand: () => setState(() {
            _open[parentId] = !open;
          }),
          expandTooltip: widget.l10n.materialKindShowVariants(unit.name),
          bodyLabel: widget.l10n.materialKindFamilyVariantsLabel(
            unit.name,
            children.length,
          ),
          refinedValue: widget.l10n.materialKindFamilyRefinedValue,
          onToggleType: (type) => onToggleFamilyType(unit, type),
        );
        if (!open) {
          return [familyChip];
        }
        return [
          OfflineKindFamilyGroup(
            unit: unit,
            familyChip: familyChip,
            children: [
              for (final child in children)
                OfflineKindChip(
                  kind: child,
                  l10n: widget.l10n,
                  checked: state == MaterialKindFamilyState.selected ||
                      selection.contains(child.kindId),
                  enabled: enabled,
                  look: state == MaterialKindFamilyState.selected
                      ? MaterialKindChipLook.included
                      : (selection.contains(child.kindId)
                          ? MaterialKindChipLook.selected
                          : MaterialKindChipLook.normal),
                  selection: selection,
                  onChanged: () => onToggle(child.kindId),
                  onToggleType: (type) =>
                      onToggleType(child.kindId, type, child.effectiveTypes.keys.toSet()),
                ),
            ],
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats =
        ref.watch(offlineColdigomStatsProvider).value ??
        OfflineColdigomStats.empty;
    final taxonomy = ref.watch(coldigomKindTaxonomyProvider);
    final rank = widget.signedIn
        ? ref.watch(favoriteMaterialKindRankProvider)
        : const <String, int>{};
    final favoriteIds = rank.keys.toList()
      ..sort((a, b) => rank[a]!.compareTo(rank[b]!));
    final favorites = [
      for (final id in favoriteIds)
        if (stats.byKind.containsKey(id)) stats.byKind[id]!,
    ];
    final others = [
      for (final s in stats.byKind.values)
        if (!rank.containsKey(s.kindId)) s,
    ];

    ref.watch(offlineColdigomKindSelectionProvider);
    final selection = ref
        .read(offlineColdigomKindSelectionProvider.notifier)
        .effectiveSelection(
          favoriteKindIds: favoriteIds,
          availableKindIds: stats.byKind.keys.toSet(),
        );

    final selectedKindIds = {
      for (final s in selection)
        s.contains(':') ? s.split(':').first : s,
    };
    final effectiveKindIds = effectiveMaterialKindIds(selectedKindIds, taxonomy);
    final pendingBytes = stats.pendingBytes(
      effectiveKindIds,
      selection: selection,
      taxonomy: taxonomy,
    );
    final estimated = effectiveKindIds.any(
      (id) => stats.byKind[id]?.hasEstimate ?? false,
    );
    final canInteract = !widget.busy && !widget.download.isActive;

    void toggleKind(String kindId) {
      unawaited(
        ref
            .read(offlineColdigomKindSelectionProvider.notifier)
            .toggle(kindId, currentEffective: selection, taxonomy: taxonomy),
      );
    }

    void toggleKindType(
      String kindId,
      MaterialKind type,
      Set<MaterialKind> availableTypes,
    ) {
      unawaited(
        ref
            .read(offlineColdigomKindSelectionProvider.notifier)
            .toggleType(
              kindId,
              type,
              availableTypes: availableTypes,
              currentEffective: selection,
            ),
      );
    }

    void toggleFamilyType(OfflineKindFamilyUnit unit, MaterialKind type) {
      final isCurrentlySelected = isOfflineTypeSelected(
        kindId: unit.headId,
        type: type,
        selection: selection,
      );
      for (final child in unit.children) {
        if (child.effectiveTypes.containsKey(type)) {
          final isChildTypeSelected = isOfflineTypeSelected(
            kindId: child.kindId,
            type: type,
            selection: selection,
          );
          if (isChildTypeSelected == isCurrentlySelected) {
            toggleKindType(
              child.kindId,
              type,
              child.effectiveTypes.keys.toSet(),
            );
          }
        }
      }
      if (unit.parentStats != null &&
          unit.parentStats!.effectiveTypes.containsKey(type)) {
        final isParentTypeSelected = isOfflineTypeSelected(
          kindId: unit.parentId,
          type: type,
          selection: selection,
        );
        if (isParentTypeSelected == isCurrentlySelected) {
          toggleKindType(
            unit.parentId,
            type,
            unit.parentStats!.effectiveTypes.keys.toSet(),
          );
        }
      }
    }

    final favoriteUnits = [
      for (final kind in favorites) OfflineKindSingleUnit(kind),
    ];
    final otherSections = buildOfflineKindSections(
      kinds: others,
      taxonomy: taxonomy,
    );

    final result = widget.download.result;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.signedIn) ...[
          OfflineClassHeader(
            label: widget.l10n.offlineColdigomFavoriteKinds,
            count: favorites.length,
          ),
          if (favorites.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(
                widget.l10n.offlineColdigomNoFavorites,
                style: AppTypography.hint(),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final unit in favoriteUnits)
                  ..._renderUnit(
                    unit: unit,
                    selection: selection,
                    enabled: canInteract,
                    onToggle: toggleKind,
                    onToggleType: toggleKindType,
                    onToggleFamilyType: toggleFamilyType,
                  ),
              ],
            ),
          const SizedBox(height: 12),
          if (others.isNotEmpty)
            ExpansionTile(
              title: Text(
                widget.l10n.offlineColdigomOtherKinds,
                style: AppTypography.label.copyWith(
                  color: AppColors.title,
                  fontWeight: FontWeight.w600,
                ),
              ),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 4, bottom: 8),
              children: [
                for (final section in otherSections) ...[
                  if (taxonomy.classes.isNotEmpty)
                    OfflineClassHeader(
                      label: section.label ?? widget.l10n.materialKindOtherClass,
                      count: section.count,
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final unit in section.units)
                        ..._renderUnit(
                          unit: unit,
                          selection: selection,
                          enabled: canInteract,
                          onToggle: toggleKind,
                          onToggleType: toggleKindType,
                          onToggleFamilyType: toggleFamilyType,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
        ] else ...[
          _sectionLabel(widget.l10n.offlineKindsAll),
          for (final section in otherSections) ...[
            if (taxonomy.classes.isNotEmpty)
              OfflineClassHeader(
                label: section.label ?? widget.l10n.materialKindOtherClass,
                count: section.count,
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final unit in section.units)
                  ..._renderUnit(
                    unit: unit,
                    selection: selection,
                    enabled: canInteract,
                    onToggle: toggleKind,
                    onToggleType: toggleKindType,
                    onToggleFamilyType: toggleFamilyType,
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ],
        const SizedBox(height: 12),
        if (widget.download.isActive && widget.download.progress != null) ...[
          if (widget.download.progress!.kindId.isNotEmpty) ...[
            Text(
              widget.l10n.offlineColdigomProgress(
                stats.byKind[widget.download.progress!.kindId]?.kindName ?? '',
                widget.download.progress!.doneInKind,
                widget.download.progress!.totalInKind,
              ),
              style: AppTypography.body.copyWith(color: AppColors.title),
            ),
            Text(widget.download.progress!.currentTitle, style: AppTypography.hint()),
            const SizedBox(height: 6),
          ],
          LinearProgressIndicator(
            value: widget.download.progress!.total == 0
                ? null
                : widget.download.progress!.doneTotal /
                    widget.download.progress!.total,
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed:
                    widget.busy ||
                        widget.download.isActive ||
                        widget.download.removing ||
                        selection.isEmpty
                    ? null
                    : () => unawaited(
                        _start(
                          context,
                          ref,
                          effectiveKindIds,
                          selection,
                          pendingBytes,
                          estimated,
                          taxonomy: taxonomy,
                        ),
                      ),
                child: Text(
                  widget.l10n.offlineColdigomDownloadSelected(
                    coldigomSizeLabel(pendingBytes, estimated: estimated),
                  ),
                ),
              ),
            ),
            if (widget.download.isActive) ...[
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: widget.download.isRunning
                    ? ref.read(offlineColdigomDownloadProvider.notifier).stop
                    : null,
                child: Text(
                  widget.download.status ==
                          OfflineColdigomDownloadStatus.cancelling
                      ? widget.l10n.offlineStoppingDownload
                      : widget.l10n.offlineColdigomStop,
                ),
              ),
            ],
          ],
        ),
        if (!widget.download.isActive &&
            result != null &&
            (result.cancelled || result.hasFailures)) ...[
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                _resultStatusText(widget.l10n, widget.download),
                style: AppTypography.hint(),
              ),
              TextButton(
                onPressed: widget.busy ||
                        selection.isEmpty ||
                        widget.download.removing
                    ? null
                    : () => unawaited(
                        _start(
                          context,
                          ref,
                          effectiveKindIds,
                          selection,
                          pendingBytes,
                          estimated,
                          taxonomy: taxonomy,
                        ),
                      ),
                child: Text(widget.l10n.offlineColdigomRetry),
              ),
            ],
          ),
        ],
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: widget.busy ||
                    widget.download.isActive ||
                    widget.download.removing
                ? null
                : () => unawaited(_remove(context, ref)),
            style: TextButton.styleFrom(foregroundColor: AppColors.title),
            child: Text(widget.l10n.offlineColdigomRemove),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Padding(
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

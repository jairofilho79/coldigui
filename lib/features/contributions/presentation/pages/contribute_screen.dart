import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/connectivity_stream_provider.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../core/utils/material_id_kind.dart';
import '../../../../core/widgets/golden_tagged_container.dart';
import '../../../../core/widgets/plpcg_primary_app_bar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../catalog/presentation/providers/catalog_material_lookup_provider.dart';
import '../../../coldigom/data/providers/coldigom_catalog_source_provider.dart';
import '../../data/device/device_snapshot_provider.dart';
import '../../domain/entities/contribution_target.dart';
import '../../domain/entities/device_snapshot.dart';
import '../../domain/validators/attachment_rules.dart';
import '../providers/contribute_form_provider.dart';
import '../utils/pick_files.dart';
import '../utils/rejection_message.dart';
import '../widgets/contribution_attachments_section.dart';
import '../widgets/contribution_links_section.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import '../../../../core/tutorial/presentation/providers/tutorial_provider.dart';
import '../widgets/extracted_editor/extracted_material_editor_scaffold.dart';
import '../widgets/sign_in_to_contribute.dart';

/// Argumentos da coleta de [DeviceSnapshot] — chave do provider local
/// (autoDispose.family): recalcula só quando tela/densidade/idioma/rede mudam.
typedef _SnapshotArgs = ({
  Size screen,
  double pixelRatio,
  String locale,
  bool online,
});

final _deviceSnapshotProvider = FutureProvider.autoDispose
    .family<DeviceSnapshot, _SnapshotArgs>((ref, args) {
      final port = ref.watch(deviceSnapshotPortProvider);
      return port.collect(
        screen: args.screen,
        pixelRatio: args.pixelRatio,
        locale: args.locale,
        online: args.online,
      );
    });

/// «Ajude a melhorar o PLPCG»: formulário simplificado para o usuário
/// descrever problemas, dúvidas ou sugestões livremente, com opção de anexos,
/// links e envio opcional (marcado por padrão) de dados do aparelho para diagnóstico.
class ContributeScreen extends ConsumerStatefulWidget {
  const ContributeScreen({
    this.target,
    this.from,
    this.pickFiles = platformPickFiles,
    super.key,
  });

  final ContributionTarget? target;
  final String? from;
  final PickFiles pickFiles;

  @override
  ConsumerState<ContributeScreen> createState() => _ContributeScreenState();
}

class _ContributeScreenState extends ConsumerState<ContributeScreen> {
  int _formResetIndex = 0;
  MaterialKind? _selectedExtractedKind;
  final SpotlightGuidePortalController _portalController =
      SpotlightGuidePortalController();

  static MaterialKind? _detectExtractedKind(ContributionTarget? target) {
    if (target == null) return null;
    final matId = target.materialId;
    if (matId == null || matId.isEmpty) return null;
    if (matId.startsWith('lyrics:')) return MaterialKind.lyrics;
    final lower = matId.toLowerCase();
    if (lower.endsWith('.chord') || lower.endsWith('.chordpro')) {
      return MaterialKind.chord;
    }
    if (lower.endsWith('.gestures')) {
      return MaterialKind.gesture;
    }
    final kind = materialIdKindOf(matId);
    if (kind == MaterialKind.chord ||
        kind == MaterialKind.gesture ||
        kind == MaterialKind.lyrics) {
      return kind;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _selectedExtractedKind = _detectExtractedKind(widget.target);
    try {
      ref.read(tutorialControllerProvider).pushPortalController(_portalController);
    } catch (_) {}
  }

  @override
  void dispose() {
    try {
      if (_portalController.isShowing) {
        _portalController.hide();
      }
      ref.read(tutorialControllerProvider).popPortalController(_portalController);
      ref.read(extractedEditorActiveProvider.notifier).set(false);
    } catch (_) {}
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ContributeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) {
      _selectedExtractedKind = _detectExtractedKind(widget.target);
    }
  }

  ContributionTarget? _resolveEffectiveTarget(
    ContributionTarget? target,
    MaterialKind? kind,
  ) {
    if (target == null) return null;
    final targetMaterialId = target.materialId;
    final effectivePraiseId = target.praiseId ??
        (targetMaterialId != null
            ? (ref.watch(catalogMaterialLookupProvider).chord(targetMaterialId)?.groupId ??
               ref.watch(catalogMaterialLookupProvider).gesture(targetMaterialId)?.groupId ??
               ref.watch(coldigomCatalogSourceProvider).findGroupForMaterial(targetMaterialId)?.groupId)
            : null);

    var effective = (effectivePraiseId != null && target.praiseId == null)
        ? target.copyWith(praiseId: effectivePraiseId)
        : target;

    if (kind == MaterialKind.lyrics &&
        (effective.materialId == null ||
            !effective.materialId!.startsWith('lyrics:'))) {
      effective = effective.copyWith(
        materialId: 'lyrics:${effective.praiseId}',
      );
    } else if (kind == MaterialKind.chord &&
        effective.materialId == null &&
        effective.praiseId != null) {
      final chords = ref
          .watch(catalogMaterialLookupProvider)
          .chordsOfGroup(effective.praiseId!);
      final chordsFromSource = ref
          .watch(coldigomCatalogSourceProvider)
          .findGroupById(effective.praiseId!)
          ?.chordMaterials;
      final effectiveChords =
          chords.isNotEmpty ? chords : (chordsFromSource ?? []);
      if (effectiveChords.isNotEmpty) {
        effective =
            effective.copyWith(materialId: effectiveChords.first.chordId);
      }
    } else if (kind == MaterialKind.gesture &&
        effective.materialId == null &&
        effective.praiseId != null) {
      final gestures = ref
          .watch(catalogMaterialLookupProvider)
          .gesturesById
          .values
          .where((g) => g.groupId == effective.praiseId)
          .toList();
      final gesturesFromSource = ref
          .watch(coldigomCatalogSourceProvider)
          .findGroupById(effective.praiseId!)
          ?.gestureMaterials;
      final effectiveGestures =
          gestures.isNotEmpty ? gestures : (gesturesFromSource ?? []);
      if (effectiveGestures.isNotEmpty) {
        effective =
            effective.copyWith(materialId: effectiveGestures.first.gestureId);
      }
    }
    return effective;
  }

  ContributeFormArgs _formArgsFor(ContributionTarget? target) =>
      ContributeFormArgs(target: target ?? widget.target, from: widget.from);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(authStateProvider).asData?.value;

    final effectiveTarget = _resolveEffectiveTarget(
      widget.target,
      _selectedExtractedKind,
    );
    final targetMaterialId = widget.target?.materialId;
    final effectivePraiseId = effectiveTarget?.praiseId ??
        widget.target?.praiseId ??
        (targetMaterialId != null
            ? (ref.watch(catalogMaterialLookupProvider).chord(targetMaterialId)?.groupId ??
               ref.watch(catalogMaterialLookupProvider).gesture(targetMaterialId)?.groupId ??
               ref.watch(coldigomCatalogSourceProvider).findGroupForMaterial(targetMaterialId)?.groupId)
            : null);

    final args = _formArgsFor(effectiveTarget);
    final state = ref.watch(contributeFormProvider(args));
    final notifier = ref.read(contributeFormProvider(args).notifier);
    final draft = state.draft;

    final online = ref.watch(connectivityStreamProvider).value ?? true;
    final snapshotAsync = ref.watch(
      _deviceSnapshotProvider((
        screen: MediaQuery.sizeOf(context),
        pixelRatio: MediaQuery.devicePixelRatioOf(context),
        locale: Localizations.localeOf(context).toLanguageTag(),
        online: online,
      )),
    );
    final snapshot = snapshotAsync.value;

    ref.listen(contributeFormProvider(args), (previous, next) {
      final messenger = ScaffoldMessenger.of(context);
      switch (next.submit) {
        case ContributeSent():
          messenger.showSnackBar(SnackBar(content: Text(l10n.contributeSent)));
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            try {
              context.go(RoutePaths.profile);
            } catch (_) {}
          }
        case ContributeFailed(:final failure):
          messenger.showSnackBar(
            SnackBar(content: Text(_failureMessage(l10n, failure, next))),
          );
        case ContributeIdle():
        case ContributeSending():
          break;
      }
    });

    final tutorialNotifier = ref.watch(tutorialControllerProvider);

    // Se o alvo for um material extraído (ou selecionado pelo usuário)
    final isExtractedActive =
        _selectedExtractedKind != null && effectiveTarget != null;
    if (ref.read(extractedEditorActiveProvider) != isExtractedActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(extractedEditorActiveProvider.notifier).set(
                isExtractedActive,
              );
        }
      });
    }

    final Widget content;
    if (isExtractedActive) {
      content = Scaffold(
        appBar: const PlpcgPrimaryAppBar(),
        body: ExtractedMaterialEditorScaffold(
          target: effectiveTarget,
          materialKind: _selectedExtractedKind!,
          formArgs: args,
          onSwitchToGeneral: () => setState(() => _selectedExtractedKind = null),
          onSend: (snap) => _send(args, snap),
          snapshot: snapshot,
        ),
      );
    } else {
      final canSend =
          draft.isValid &&
          (state.submit is ContributeIdle || state.submit is ContributeFailed);

      content = Scaffold(
        appBar: const PlpcgPrimaryAppBar(),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Theme(
              data: Theme.of(context).copyWith(
                inputDecorationTheme: Theme.of(context).inputDecorationTheme
                    .copyWith(
                      floatingLabelStyle: AppTypography.label.copyWith(
                        color: AppColors.title,
                        fontWeight: FontWeight.w700,
                      ),
                      labelStyle: AppTypography.body.copyWith(
                        color: AppColors.title.withValues(alpha: 0.75),
                      ),
                      counterStyle: AppTypography.body.copyWith(
                        fontSize: 12,
                        color: AppColors.textLight.withValues(alpha: 0.8),
                      ),
                    ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: ValueKey(_formResetIndex),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          l10n.contributeTitle,
                          style: AppTypography.headline.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textLight,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (effectivePraiseId != null) ...[
                        const SizedBox(height: 12),
                        SpotlightGuideTarget(
                          id: 'contribute-target-banner',
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.gold.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.music_note,
                                    size: 16,
                                    color: AppColors.gold,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    l10n.contributeLinkedPraise,
                                    style: AppTypography.label.copyWith(
                                      color: AppColors.gold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            alignment: WrapAlignment.center,
                            children: [
                              ChoiceChip(
                                key: const Key('contribute-chip-general'),
                                label: Text(l10n.contributeEditorGeneralKind),
                                selected: _selectedExtractedKind == null,
                                onSelected: (_) =>
                                    setState(() => _selectedExtractedKind = null),
                                selectedColor:
                                    AppColors.gold.withValues(alpha: 0.25),
                                labelStyle: AppTypography.label.copyWith(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w700,
                                ),
                                side: const BorderSide(color: AppColors.gold),
                              ),
                              ActionChip(
                                key: const Key('contribute-chip-lyrics'),
                                avatar: const Icon(
                                  Icons.article_outlined,
                                  size: 16,
                                  color: AppColors.gold,
                                ),
                                label: Text(l10n.contributeEditorLyricsKind),
                                backgroundColor: AppColors.card,
                                side: const BorderSide(color: Color(0x33D4AF37)),
                                labelStyle: AppTypography.label.copyWith(
                                  color: AppColors.title,
                                ),
                                onPressed: () => setState(
                                  () => _selectedExtractedKind = MaterialKind.lyrics,
                                ),
                              ),
                              ActionChip(
                                key: const Key('contribute-chip-chord'),
                                avatar: const Icon(
                                  Icons.music_note_outlined,
                                  size: 16,
                                  color: AppColors.gold,
                                ),
                                label: Text(l10n.contributeEditorChordKind),
                                backgroundColor: AppColors.card,
                                side: const BorderSide(color: Color(0x33D4AF37)),
                                labelStyle: AppTypography.label.copyWith(
                                  color: AppColors.title,
                                ),
                                onPressed: () => setState(
                                  () => _selectedExtractedKind = MaterialKind.chord,
                                ),
                              ),
                              ActionChip(
                                key: const Key('contribute-chip-gesture'),
                                avatar: const Icon(
                                  Icons.sign_language_outlined,
                                  size: 16,
                                  color: AppColors.gold,
                                ),
                                label: Text(l10n.contributeEditorGestureKind),
                                backgroundColor: AppColors.card,
                                side: const BorderSide(color: Color(0x33D4AF37)),
                                labelStyle: AppTypography.label.copyWith(
                                  color: AppColors.title,
                                ),
                                onPressed: () => setState(
                                  () => _selectedExtractedKind = MaterialKind.gesture,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        SpotlightGuideTarget(
                          id: 'contribute-target-banner',
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.gold.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.lightbulb_outline,
                                  size: 18,
                                  color: AppColors.gold,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    l10n.contributeEditorGeneralHint,
                                    style: AppTypography.body.copyWith(
                                      fontSize: 12.5,
                                      color: AppColors.textLight.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SpotlightGuideTarget(
                        id: 'contribute-body-field',
                        child: GoldenTaggedContainer(
                          label: l10n.contributeBodyField,
                          contentPadding: EdgeInsets.fromLTRB(
                            12,
                            MediaQuery.textScalerOf(context).scale(14),
                            12,
                            MediaQuery.textScalerOf(context).scale(8),
                          ),
                          child: TextFormField(
                            key: const Key('contribute-body'),
                            initialValue: draft.body,
                            maxLength: kMaxBodyLength,
                            minLines: 5,
                            maxLines: null,
                            style: AppTypography.input,
                            decoration: InputDecoration(
                              hintText: l10n.contributeBodyHint,
                              hintStyle: AppTypography.hint(italic: true),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              counterStyle: AppTypography.body.copyWith(
                                fontSize: 12,
                                color: AppColors.title.withValues(alpha: 0.6),
                              ),
                            ),
                            onChanged: notifier.setBody,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SpotlightGuideTarget(
                        id: 'contribute-diagnostics',
                        child: InkWell(
                          key: const Key('contribute-device-toggle'),
                          onTap: () => notifier.setSendDeviceData(!draft.sendDeviceData),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 2,
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  key: const Key('contribute-device-checkbox'),
                                  value: draft.sendDeviceData,
                                  onChanged: (val) =>
                                      notifier.setSendDeviceData(val ?? true),
                                  activeColor: AppColors.gold,
                                  checkColor: AppColors.title,
                                  side: const BorderSide(
                                    color: Color(0x99D4AF37),
                                    width: 1.5,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    l10n.contributeSendDeviceData,
                                    style: AppTypography.body.copyWith(
                                      color: AppColors.textLight.withValues(alpha: 0.9),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SpotlightGuideTarget(
                        id: 'contribute-attachments',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AttachmentsSection(
                              kind: draft.kind,
                              attachments: draft.attachments,
                              pickFiles: widget.pickFiles,
                              onAdd: notifier.addAttachment,
                              onRemove: notifier.removeAttachment,
                            ),
                            const SizedBox(height: 16),
                            LinksSection(
                              links: draft.links,
                              onAdd: notifier.addLink,
                              onRemove: notifier.removeLink,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (state.submit case ContributeSending(:final progress))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: LinearProgressIndicator(
                            value: progress,
                            color: AppColors.gold,
                            backgroundColor: AppColors.gold.withValues(
                              alpha: 0.25,
                            ),
                          ),
                        ),
                      if (user == null)
                        const Center(
                          child: SpotlightGuideTarget(
                            id: 'contribute-submit-button',
                            child: SignInToContribute(),
                          ),
                        )
                      else
                        SpotlightGuideTarget(
                          id: 'contribute-submit-button',
                          child: SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton(
                              key: const Key('contribute-send'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.gold,
                                foregroundColor: AppColors.title,
                                disabledBackgroundColor: AppColors.background,
                                disabledForegroundColor: const Color(0xFF351C1B),
                                side: BorderSide(
                                  color: canSend
                                      ? AppColors.gold
                                      : const Color(0x55D4AF37),
                                  width: canSend ? 2 : 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              onPressed: canSend ? () => _send(args, snapshot) : null,
                              child: Text(
                                l10n.contributeSend,
                                style: canSend
                                    ? AppTypography.body.copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        color: AppColors.title,
                                      )
                                    : AppTypography.body.copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        color: const Color(0xFF351C1B),
                                        shadows: const [
                                          Shadow(
                                            color: Color(0xD0000000),
                                            offset: Offset(0, -1.0),
                                            blurRadius: 1.0,
                                          ),
                                          Shadow(
                                            color: Color(0x35FFE29A),
                                            offset: Offset(0, 1.0),
                                            blurRadius: 1.0,
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          key: const Key('contribute-clear-form'),
                          onPressed: () => _confirmClearForm(context, args),
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: AppColors.gold,
                          ),
                          label: Text(
                            l10n.contributeClearForm,
                            style: AppTypography.body.copyWith(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0x55D4AF37)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
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

    return SpotlightGuidePortal(
      controller: _portalController,
      autoStart: false,
      missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
      barrier: const SpotlightGuideBarrierStyle(
        color: Color(0x99000000),
        blurSigma: 0,
      ),
      barrierDismissBehavior: SpotlightGuideDismissBehavior.anytime,
      onBarrierTap: (c) => tutorialNotifier.hide(),
      onFinish: () => tutorialNotifier.resetTutorialState(),
      child: content,
    );
  }

  Future<void> _confirmClearForm(
    BuildContext context,
    ContributeFormArgs args,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.contributeClearFormConfirmTitle),
        content: Text(l10n.contributeClearFormConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.contributeClearFormCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.gold),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.contributeClearFormConfirm),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ref.read(contributeFormProvider(args).notifier).clearDraft();
      setState(() {
        _formResetIndex++;
      });
    }
  }

  Future<void> _send(ContributeFormArgs args, DeviceSnapshot? snapshot) {
    return ref
        .read(contributeFormProvider(args).notifier)
        .submit(device: snapshot, appVersion: snapshot?.versionLabel ?? '');
  }

  String _failureMessage(
    AppLocalizations l10n,
    ContributeFailure failure,
    ContributeFormState state,
  ) => switch (failure) {
    ContributeFailure.offline => l10n.contributeErrorOffline,
    ContributeFailure.quota => l10n.contributeErrorQuota(
      _formatLocalTime(state.quotaResetAt),
    ),
    ContributeFailure.rejected => rejectionMessage(
      l10n,
      state.rejectedError ?? '',
      state.rejectedFile,
    ),
    ContributeFailure.unauthorized ||
    ContributeFailure.unknown => l10n.contributeErrorUnknown,
  };

  String _formatLocalTime(DateTime? dt) {
    final local = (dt ?? DateTime.now()).toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

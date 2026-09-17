import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/connectivity_stream_provider.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../data/device/device_snapshot_provider.dart';
import '../../domain/entities/contribution_kind.dart';
import '../../domain/entities/contribution_target.dart';
import '../../domain/entities/device_snapshot.dart';
import '../../domain/validators/attachment_rules.dart';
import '../providers/contribute_form_provider.dart';
import '../utils/pick_files.dart';
import '../utils/rejection_message.dart';
import '../widgets/contribution_attachments_section.dart';
import '../widgets/contribution_context_fields.dart';
import '../widgets/contribution_kind_chips.dart';
import '../widgets/contribution_links_section.dart';
import '../widgets/device_consent_card.dart';
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

/// «Ajude a melhorar o PLPCG» (spec §6.2): formulário único para bug,
/// informação errada, conteúdo, melhoria e outro — com anexos, links e,
/// para bug, o cartão de consentimento do dispositivo.
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
  ContributeFormArgs get _args =>
      ContributeFormArgs(target: widget.target, from: widget.from);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(authStateProvider).asData?.value;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.contributeTitle),
          leading: const _ContributeBackButton(),
        ),
        body: const SignInToContribute(),
      );
    }

    final args = _args;
    final state = ref.watch(contributeFormProvider(args));
    final notifier = ref.read(contributeFormProvider(args).notifier);
    final draft = state.draft;
    final isBug = draft.kind == ContributionKind.bug;

    // `appVersion` vai no payload de **todo** kind (não é dado de
    // dispositivo — o servidor guarda `app_version` sempre); por isso o
    // snapshot é coletado sempre. Só o objeto `device` inteiro (tela,
    // plataforma, idioma…) é bug-only — isso o `ContributeFormNotifier`
    // garante ao montar o payload, e o cartão de consentimento (abaixo)
    // só aparece para bug.
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
          // `canPop()` primeiro: um link direto ou um F5 na web abre
          // `/contribuir` como única entrada no histórico — `pop()` sem
          // checar antes lança (`GoException`/assert). `go` manda pro
          // Perfil, que é de onde a maioria dos envios parte.
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(RoutePaths.profile);
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

    // Nem `ContributeSending` nem `ContributeSent` deixam mandar de novo:
    // sending já está a caminho, e sent só demora a fechar a tela por causa
    // do próprio `ref.listen` acima (troca de frame) — sem isto, um segundo
    // toque bem cronometrado duplicaria o envio no servidor.
    final canSend =
        draft.isValid &&
        (state.submit is ContributeIdle || state.submit is ContributeFailed);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.contributeTitle),
        leading: const _ContributeBackButton(),
      ),
      // `SingleChildScrollView` (não `ListView`): o formulário inteiro
      // precisa existir na árvore de elementos de uma vez — um `ListView`
      // (sliver) só constrói os filhos perto do viewport.
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.contributeKindLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                KindChips(selected: draft.kind, onSelected: notifier.setKind),
                if (subkindsOf(draft.kind).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    l10n.contributeSubkindLabel,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  SubkindChips(
                    kind: draft.kind,
                    selected: draft.subkind,
                    onSelected: notifier.setSubkind,
                  ),
                ],
                if (widget.target?.praiseId != null) ...[
                  const SizedBox(height: 16),
                  MaterialDropdown(
                    praiseId: widget.target!.praiseId!,
                    value: draft.target?.materialId,
                    onChanged: notifier.setMaterial,
                  ),
                ],
                if (draft.subkind == ContributionSubkind.wrongMetadata) ...[
                  const SizedBox(height: 16),
                  MetadataFields(
                    praiseId: widget.target?.praiseId,
                    field: draft.metadataField,
                    current: draft.metadataCurrent,
                    proposed: draft.metadataProposed,
                    onFieldChanged: (f) => notifier.setMetadata(field: f),
                    onCurrentChanged: (v) => notifier.setMetadata(current: v),
                    onProposedChanged: (v) => notifier.setMetadata(proposed: v),
                  ),
                ],
                if (draft.subkind == ContributionSubkind.duplicate) ...[
                  const SizedBox(height: 16),
                  DuplicateField(
                    onSelected: ({required praiseId, required source}) =>
                        notifier.setDuplicate(
                          praiseId: praiseId,
                          source: source,
                        ),
                  ),
                ],
                if (draft.kind == ContributionKind.content) ...[
                  const SizedBox(height: 16),
                  SuggestedKindDropdown(
                    value: draft.suggestedKindId,
                    onChanged: notifier.setSuggestedKind,
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('contribute-title'),
                  initialValue: draft.title,
                  maxLength: kMaxTitleLength,
                  decoration: InputDecoration(
                    labelText: l10n.contributeTitleField,
                  ),
                  onChanged: notifier.setTitle,
                ),
                TextFormField(
                  key: const Key('contribute-body'),
                  initialValue: draft.body,
                  maxLength: kMaxBodyLength,
                  minLines: 4,
                  maxLines: null,
                  decoration: InputDecoration(
                    labelText: l10n.contributeBodyField,
                    hintText: draft.kind == ContributionKind.bug
                        ? l10n.contributeBodyHintBug
                        : null,
                  ),
                  onChanged: notifier.setBody,
                ),
                const SizedBox(height: 16),
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
                // Ordem do spec §6.2: o cartão de consentimento do
                // dispositivo vem depois de anexos/links, logo antes do
                // botão de enviar — só para bug.
                if (isBug) ...[
                  const SizedBox(height: 16),
                  DeviceConsentCard(
                    snapshot: snapshot,
                    sameDevice: draft.sameDevice,
                    otherDeviceNote: draft.otherDeviceNote ?? '',
                    onSameDevice: notifier.setSameDevice,
                    onOtherDeviceNote: notifier.setOtherDeviceNote,
                  ),
                ],
                const SizedBox(height: 24),
                if (state.submit case ContributeSending(:final progress))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: LinearProgressIndicator(value: progress),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('contribute-send'),
                    onPressed: canSend ? () => _send(snapshot) : null,
                    child: Text(l10n.contributeSend),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _send(DeviceSnapshot? snapshot) {
    // `appVersion` vem do snapshot em qualquer kind; `device` (o objeto
    // inteiro) só é usado pelo `ContributeFormNotifier` quando o kind é
    // bug — ele zera isso sozinho para os demais (spec P9/§3/§6.2).
    return ref
        .read(contributeFormProvider(_args).notifier)
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

/// Botão de voltar do `AppBar` com o mesmo fallback do `ContributeSent`
/// acima: sem isto, o `AppBar` padrão só mostra a seta quando `canPop()` já
/// era `true` na hora de montar a tela, mas some (sem fallback nenhum) num
/// link direto ou F5 na web — a pessoa fica sem jeito de sair da tela.
class _ContributeBackButton extends StatelessWidget {
  const _ContributeBackButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const BackButtonIcon(),
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: () =>
          context.canPop() ? context.pop() : context.go(RoutePaths.profile),
    );
  }
}

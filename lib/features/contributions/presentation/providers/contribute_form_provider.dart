import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/auth_remote_datasource.dart'
    show AuthUnauthorizedException;
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../data/datasources/contributions_remote_datasource.dart';
import '../../data/providers/contributions_providers.dart';
import '../../domain/entities/contribution_attachment.dart';
import '../../domain/entities/contribution_draft.dart';
import '../../domain/entities/contribution_kind.dart';
import '../../domain/entities/contribution_target.dart';
import '../../domain/entities/device_snapshot.dart';
import '../../domain/validators/attachment_rules.dart';

/// Estado do envio (spec §6.2) — `Idle` até o usuário apertar Enviar.
sealed class ContributeSubmitState {
  const ContributeSubmitState();
}

class ContributeIdle extends ContributeSubmitState {
  const ContributeIdle();
}

class ContributeSending extends ContributeSubmitState {
  const ContributeSending(this.progress);
  final double progress;
}

class ContributeSent extends ContributeSubmitState {
  const ContributeSent(this.id);
  final String id;
}

class ContributeFailed extends ContributeSubmitState {
  const ContributeFailed(this.failure);
  final ContributeFailure failure;
}

enum ContributeFailure { offline, quota, rejected, unauthorized, unknown }

/// Alvo do formulário (`target`) + rota de origem (`from`) — chave do
/// `family`. Igualdade por valor: reabrir o mesmo alvo reusa o rascunho em
/// vez de criar um `Notifier` novo a cada rebuild do `GoRoute`.
@immutable
class ContributeFormArgs {
  const ContributeFormArgs({this.target, this.from});
  final ContributionTarget? target;
  final String? from;

  @override
  bool operator ==(Object other) =>
      other is ContributeFormArgs &&
      other.target?.source == target?.source &&
      other.target?.praiseId == target?.praiseId &&
      other.target?.materialId == target?.materialId &&
      other.from == from;

  @override
  int get hashCode =>
      Object.hash(target?.source, target?.praiseId, target?.materialId, from);
}

@immutable
class ContributeFormState {
  const ContributeFormState({
    required this.draft,
    this.submit = const ContributeIdle(),
    this.quotaResetAt,
    this.rejectedError,
    this.rejectedFile,
  });

  final ContributionDraft draft;
  final ContributeSubmitState submit;
  final DateTime? quotaResetAt;
  final String? rejectedError;
  final String? rejectedFile;

  ContributeFormState copyWith({
    ContributionDraft? draft,
    ContributeSubmitState? submit,
    DateTime? quotaResetAt,
    String? rejectedError,
    String? rejectedFile,
  }) => ContributeFormState(
    draft: draft ?? this.draft,
    submit: submit ?? this.submit,
    quotaResetAt: quotaResetAt ?? this.quotaResetAt,
    rejectedError: rejectedError ?? this.rejectedError,
    rejectedFile: rejectedFile ?? this.rejectedFile,
  );
}

/// Um notifier por (alvo, rota de origem): abrir «Reportar» em dois louvores
/// não mistura rascunhos. Com alvo, o kind padrão é «Informação errada» (P2).
///
/// Riverpod 3 não tem `AutoDisposeFamilyNotifier`: o argumento do `family`
/// chega pelo construtor (`NotifierProvider.autoDispose.family` chama
/// `ContributeFormNotifier.new` com o `arg`), não por `build(arg)`.
class ContributeFormNotifier extends Notifier<ContributeFormState> {
  ContributeFormNotifier(this.arg);

  final ContributeFormArgs arg;

  @override
  ContributeFormState build() => ContributeFormState(
    draft: ContributionDraft(
      kind: arg.target != null
          ? ContributionKind.wrongInfo
          : ContributionKind.other,
      target: arg.target,
      appRoute: arg.from,
    ),
  );

  void _draft(ContributionDraft d) =>
      state = state.copyWith(draft: d, submit: const ContributeIdle());

  void setKind(ContributionKind kind) {
    // Trocar de kind limpa o subkind e os anexos que o novo kind não aceita
    // (bug só imagem).
    final keep = state.draft.attachments
        .where(
          (a) =>
              validateAttachment(
                name: a.name,
                size: a.size,
                kind: kind,
                currentCount: 0,
              ) ==
              null,
        )
        .toList();
    _draft(
      state.draft.copyWith(
        kind: kind,
        subkind: null,
        attachments: keep,
        sameDevice: null,
        otherDeviceNote: null,
      ),
    );
  }

  void setSubkind(ContributionSubkind? s) =>
      _draft(state.draft.copyWith(subkind: s));
  void setTitle(String v) => _draft(state.draft.copyWith(title: v));
  void setBody(String v) => _draft(state.draft.copyWith(body: v));
  void setMaterial(String? materialId) => _draft(
    state.draft.copyWith(
      target: state.draft.target?.copyWith(materialId: materialId),
    ),
  );
  void setMetadata({MetadataField? field, String? current, String? proposed}) =>
      _draft(
        state.draft.copyWith(
          metadataField: field ?? state.draft.metadataField,
          metadataCurrent: current ?? state.draft.metadataCurrent,
          metadataProposed: proposed ?? state.draft.metadataProposed,
        ),
      );
  void setDuplicate({String? praiseId, ContributionSource? source}) => _draft(
    state.draft.copyWith(
      duplicateOtherPraiseId: praiseId,
      duplicateOtherSource: source,
    ),
  );
  void setSuggestedKind(String? kindId) =>
      _draft(state.draft.copyWith(suggestedKindId: kindId));
  void setSameDevice(bool? v) => _draft(state.draft.copyWith(sameDevice: v));
  void setOtherDeviceNote(String v) =>
      _draft(state.draft.copyWith(otherDeviceNote: v));

  AttachmentError? addAttachment(ContributionAttachment a) {
    final err = validateAttachment(
      name: a.name,
      size: a.size,
      kind: state.draft.kind,
      currentCount: state.draft.attachments.length,
    );
    if (err != null) return err;
    _draft(state.draft.copyWith(attachments: [...state.draft.attachments, a]));
    return null;
  }

  void removeAttachment(int i) => _draft(
    state.draft.copyWith(
      attachments: [...state.draft.attachments]..removeAt(i),
    ),
  );

  bool addLink(String url) {
    final v = url.trim();
    if (!isAllowedLink(v) || state.draft.links.length >= kMaxLinks) {
      return false;
    }
    _draft(state.draft.copyWith(links: [...state.draft.links, v]));
    return true;
  }

  void removeLink(int i) =>
      _draft(state.draft.copyWith(links: [...state.draft.links]..removeAt(i)));

  Future<void> submit({
    required DeviceSnapshot? device,
    required String appVersion,
  }) async {
    // `.future` (não `ref.read(authStateProvider).asData`): o build do
    // `AuthNotifier` é assíncrono — ler o `AsyncValue` sem aguardar pegaria
    // `AsyncLoading` (token nulo) sempre que o auth ainda não assentou.
    final token = (await ref.read(authStateProvider.future))?.sessionToken;
    if (token == null) {
      state = state.copyWith(
        submit: const ContributeFailed(ContributeFailure.unauthorized),
      );
      return;
    }
    if (!state.draft.isValid) return;
    state = state.copyWith(submit: const ContributeSending(0));
    final payload = state.draft.toPayload(
      device: device?.toJson(),
      appVersion: appVersion,
    );
    try {
      final out = await ref
          .read(contributionsRemoteDatasourceProvider)
          .submit(
            sessionToken: token,
            payload: payload,
            attachments: state.draft.attachments,
            onProgress: (sent, total) {
              if (total > 0) {
                state = state.copyWith(submit: ContributeSending(sent / total));
              }
            },
          );
      state = state.copyWith(submit: ContributeSent(out.id));
    } on ContributionQuotaExceeded catch (e) {
      state = state.copyWith(
        submit: const ContributeFailed(ContributeFailure.quota),
        quotaResetAt: e.resetAt,
      );
    } on ContributionRejected catch (e) {
      state = state.copyWith(
        submit: const ContributeFailed(ContributeFailure.rejected),
        rejectedError: e.error,
        rejectedFile: e.file,
      );
    } on AuthUnauthorizedException {
      state = state.copyWith(
        submit: const ContributeFailed(ContributeFailure.unauthorized),
      );
    } on DioException catch (e) {
      final offline =
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          (e.response?.statusCode == 503);
      state = state.copyWith(
        submit: ContributeFailed(
          offline ? ContributeFailure.offline : ContributeFailure.unknown,
        ),
      );
    } on Object catch (e) {
      debugPrint('[contributions] submit falhou: $e');
      state = state.copyWith(
        submit: const ContributeFailed(ContributeFailure.unknown),
      );
    }
  }
}

final contributeFormProvider = NotifierProvider.autoDispose
    .family<ContributeFormNotifier, ContributeFormState, ContributeFormArgs>(
      ContributeFormNotifier.new,
    );

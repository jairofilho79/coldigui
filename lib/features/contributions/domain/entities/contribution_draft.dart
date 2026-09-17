import 'contribution_attachment.dart';
import 'contribution_kind.dart';
import 'contribution_target.dart';

/// Estado do formulário, imutável. `toPayload` produz exatamente o JSON que o
/// `parsePayload` do coldigom-api aceita (spec §3.1/§4.2).
class ContributionDraft {
  const ContributionDraft({
    required this.kind,
    this.subkind,
    this.target,
    this.title = '',
    this.body = '',
    this.links = const [],
    this.attachments = const [],
    this.metadataField,
    this.metadataCurrent,
    this.metadataProposed,
    this.duplicateOtherPraiseId,
    this.duplicateOtherSource,
    this.suggestedKindId,
    this.sameDevice,
    this.otherDeviceNote,
    this.appRoute,
  });

  final ContributionKind kind;
  final ContributionSubkind? subkind;
  final ContributionTarget? target;
  final String title;
  final String body;
  final List<String> links;
  final List<ContributionAttachment> attachments;
  final MetadataField? metadataField;
  final String? metadataCurrent;
  final String? metadataProposed;
  final String? duplicateOtherPraiseId;
  final ContributionSource? duplicateOtherSource;
  final String? suggestedKindId;
  final bool? sameDevice;
  final String? otherDeviceNote;
  final String? appRoute;

  /// Regras mínimas de envio — o servidor ainda revalida tudo (spec §4.2).
  bool get isValid {
    if (title.trim().isEmpty || body.trim().isEmpty) return false;
    if (subkindsOf(kind).isNotEmpty &&
        (subkind == null || subkind!.kind != kind)) {
      return false;
    }
    if (kind == ContributionKind.bug) {
      if (sameDevice == null) return false;
      if (sameDevice == false && (otherDeviceNote ?? '').trim().isEmpty) {
        return false;
      }
    }
    if (subkind == ContributionSubkind.wrongMetadata &&
        (metadataField == null || (metadataProposed ?? '').trim().isEmpty)) {
      return false;
    }
    if (subkind == ContributionSubkind.duplicate &&
        ((duplicateOtherPraiseId ?? '').isEmpty ||
            duplicateOtherSource == null)) {
      return false;
    }
    return true;
  }

  Map<String, dynamic> _fields() {
    switch (subkind) {
      case ContributionSubkind.wrongMetadata:
        return {
          'field': metadataField!.name,
          if (metadataCurrent != null) 'current': metadataCurrent,
          'proposed': metadataProposed!.trim(),
        };
      case ContributionSubkind.duplicate:
        return {
          'otherPraiseId': duplicateOtherPraiseId,
          'otherSource': duplicateOtherSource!.wireName,
        };
      case ContributionSubkind.addMaterial:
      case ContributionSubkind.addPraise:
      case ContributionSubkind.replaceMaterial:
      case ContributionSubkind.remove:
        return {
          if (suggestedKindId != null) 'suggestedKindId': suggestedKindId,
        };
      default:
        return <String, dynamic>{};
    }
  }

  Map<String, dynamic> toPayload({
    required Map<String, dynamic>? device,
    required String appVersion,
  }) {
    Map<String, dynamic>? deviceJson = device;
    if (kind == ContributionKind.bug) {
      deviceJson = {
        ...?device,
        'same_device': sameDevice,
        if (sameDevice == false) 'other_device_note': otherDeviceNote!.trim(),
      };
    }
    return {
      'kind': kind.wireName,
      'subkind': subkind?.wireName,
      'target': target?.toJson(),
      'title': title.trim(),
      'body': body.trim(),
      'fields': _fields(),
      'links': links,
      'device': deviceJson,
      'appRoute': appRoute,
      'appVersion': appVersion,
    };
  }

  ContributionDraft copyWith({
    ContributionKind? kind,
    Object? subkind = _sentinel,
    Object? target = _sentinel,
    String? title,
    String? body,
    List<String>? links,
    List<ContributionAttachment>? attachments,
    Object? metadataField = _sentinel,
    Object? metadataCurrent = _sentinel,
    Object? metadataProposed = _sentinel,
    Object? duplicateOtherPraiseId = _sentinel,
    Object? duplicateOtherSource = _sentinel,
    Object? suggestedKindId = _sentinel,
    Object? sameDevice = _sentinel,
    Object? otherDeviceNote = _sentinel,
    Object? appRoute = _sentinel,
  }) {
    return ContributionDraft(
      kind: kind ?? this.kind,
      subkind: subkind == _sentinel
          ? this.subkind
          : subkind as ContributionSubkind?,
      target: target == _sentinel ? this.target : target as ContributionTarget?,
      title: title ?? this.title,
      body: body ?? this.body,
      links: links ?? this.links,
      attachments: attachments ?? this.attachments,
      metadataField: metadataField == _sentinel
          ? this.metadataField
          : metadataField as MetadataField?,
      metadataCurrent: metadataCurrent == _sentinel
          ? this.metadataCurrent
          : metadataCurrent as String?,
      metadataProposed: metadataProposed == _sentinel
          ? this.metadataProposed
          : metadataProposed as String?,
      duplicateOtherPraiseId: duplicateOtherPraiseId == _sentinel
          ? this.duplicateOtherPraiseId
          : duplicateOtherPraiseId as String?,
      duplicateOtherSource: duplicateOtherSource == _sentinel
          ? this.duplicateOtherSource
          : duplicateOtherSource as ContributionSource?,
      suggestedKindId: suggestedKindId == _sentinel
          ? this.suggestedKindId
          : suggestedKindId as String?,
      sameDevice: sameDevice == _sentinel
          ? this.sameDevice
          : sameDevice as bool?,
      otherDeviceNote: otherDeviceNote == _sentinel
          ? this.otherDeviceNote
          : otherDeviceNote as String?,
      appRoute: appRoute == _sentinel ? this.appRoute : appRoute as String?,
    );
  }
}

const Object _sentinel = Object();

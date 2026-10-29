import 'dart:convert';

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
    this.sendDeviceData = true,
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
  final bool sendDeviceData;
  final String? appRoute;

  /// Regras mínimas de envio — o servidor ainda revalida tudo (spec §4.2).
  bool get isValid {
    if (body.trim().isEmpty) return false;
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
    } else if (device != null && sendDeviceData) {
      deviceJson = {
        ...device,
        'same_device': true,
      };
    } else if (!sendDeviceData) {
      deviceJson = null;
    }

    final effectiveTitle = title.trim().isNotEmpty
        ? title.trim()
        : _deriveTitle(body);

    return {
      'kind': kind.wireName,
      'subkind': subkind?.wireName,
      'target': target?.toJson(),
      'title': effectiveTitle,
      'body': body.trim(),
      'fields': _fields(),
      'links': links,
      'device': deviceJson,
      'appRoute': appRoute,
      'appVersion': appVersion,
    };
  }

  static String _deriveTitle(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 'Contribuição';
    final firstLine = trimmed.split('\n').first.trim();
    final candidate = firstLine.isNotEmpty ? firstLine : trimmed;
    if (candidate.length <= 80) return candidate;
    return '${candidate.substring(0, 77)}...';
  }

  Map<String, dynamic> toStorageJson() => {
    'kind': kind.wireName,
    'subkind': subkind?.wireName,
    'target': target?.toJson(),
    'title': title,
    'body': body,
    'links': links,
    'sendDeviceData': sendDeviceData,
    'attachments': [
      for (final a in attachments)
        // Só salva bytes se menores ou iguais a 1 MB para não estourar a cota de localStorage
        if (a.bytes.lengthInBytes <= 1024 * 1024)
          {
            'name': a.name,
            'size': a.size,
            'bytes': base64Encode(a.bytes),
          },
    ],
    'metadataField': metadataField?.name,
    'metadataCurrent': metadataCurrent,
    'metadataProposed': metadataProposed,
    'duplicateOtherPraiseId': duplicateOtherPraiseId,
    'duplicateOtherSource': duplicateOtherSource?.wireName,
    'suggestedKindId': suggestedKindId,
    'sameDevice': sameDevice,
    'otherDeviceNote': otherDeviceNote,
    'appRoute': appRoute,
  };

  factory ContributionDraft.fromStorageJson(Map<String, dynamic> json) {
    ContributionKind? kind;
    final kindWire = json['kind'] as String?;
    if (kindWire != null) {
      for (final k in ContributionKind.values) {
        if (k.wireName == kindWire) {
          kind = k;
          break;
        }
      }
    }

    ContributionSubkind? subkind;
    final subkindWire = json['subkind'] as String?;
    if (subkindWire != null) {
      for (final s in ContributionSubkind.values) {
        if (s.wireName == subkindWire) {
          subkind = s;
          break;
        }
      }
    }

    ContributionTarget? target;
    if (json['target'] is Map) {
      target = ContributionTarget.fromJson(
        Map<String, dynamic>.from(json['target'] as Map),
      );
    }

    final links = (json['links'] as List?)?.cast<String>() ?? const [];

    final attachments = <ContributionAttachment>[];
    final attachmentsRaw = json['attachments'] as List?;
    if (attachmentsRaw != null) {
      for (final item in attachmentsRaw) {
        if (item is Map) {
          final name = item['name'] as String? ?? '';
          final size = item['size'] as int? ?? 0;
          final b64 = item['bytes'] as String?;
          if (b64 != null) {
            try {
              final bytes = base64Decode(b64);
              attachments.add(
                ContributionAttachment(name: name, size: size, bytes: bytes),
              );
            } catch (_) {}
          }
        }
      }
    }

    MetadataField? metadataField;
    final metaFieldName = json['metadataField'] as String?;
    if (metaFieldName != null) {
      for (final m in MetadataField.values) {
        if (m.name == metaFieldName) {
          metadataField = m;
          break;
        }
      }
    }

    ContributionSource? duplicateOtherSource;
    final dupSourceWire = json['duplicateOtherSource'] as String?;
    if (dupSourceWire != null) {
      for (final s in ContributionSource.values) {
        if (s.wireName == dupSourceWire) {
          duplicateOtherSource = s;
          break;
        }
      }
    }

    return ContributionDraft(
      kind: kind ?? ContributionKind.other,
      subkind: subkind,
      target: target,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      links: links,
      attachments: attachments,
      metadataField: metadataField,
      metadataCurrent: json['metadataCurrent'] as String?,
      metadataProposed: json['metadataProposed'] as String?,
      duplicateOtherPraiseId: json['duplicateOtherPraiseId'] as String?,
      duplicateOtherSource: duplicateOtherSource,
      suggestedKindId: json['suggestedKindId'] as String?,
      sameDevice: json['sameDevice'] as bool?,
      otherDeviceNote: json['otherDeviceNote'] as String?,
      sendDeviceData: json['sendDeviceData'] as bool? ?? true,
      appRoute: json['appRoute'] as String?,
    );
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
    Object? sendDeviceData = _sentinel,
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
      sendDeviceData: sendDeviceData == _sentinel
          ? this.sendDeviceData
          : sendDeviceData as bool,
      appRoute: appRoute == _sentinel ? this.appRoute : appRoute as String?,
    );
  }
}

const Object _sentinel = Object();

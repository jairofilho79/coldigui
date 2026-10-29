import 'dart:typed_data';

import 'package:coldigui/features/contributions/domain/entities/contribution_attachment.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_draft.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_kind.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_target.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const target = ContributionTarget(
    source: ContributionSource.coldigom,
    praiseId: 'p1',
    materialId: 'm1',
  );

  test('subkindsOf agrupa por kind e other não tem subkind', () {
    expect(subkindsOf(ContributionKind.bug).length, 8);
    expect(
      subkindsOf(ContributionKind.wrongInfo).first,
      ContributionSubkind.wrongMetadata,
    );
    expect(subkindsOf(ContributionKind.other), isEmpty);
    expect(ContributionSubkind.bugPlaylistLive.wireName, 'playlist_live');
    expect(ContributionSubkind.wrongMetadata.kind, ContributionKind.wrongInfo);
  });

  test('toPayload de wrong_info/metadata leva target e fields', () {
    const draft = ContributionDraft(
      kind: ContributionKind.wrongInfo,
      subkind: ContributionSubkind.wrongMetadata,
      target: target,
      title: 'Tom errado',
      body: 'É Em, não Dm',
      metadataField: MetadataField.tonality,
      metadataCurrent: 'Dm',
      metadataProposed: 'Em',
      links: ['https://youtu.be/abc'],
      appRoute: '/leitor?pdfId=x',
    );
    final payload = draft.toPayload(device: null, appVersion: '2.1.0+45');
    expect(payload, {
      'kind': 'wrong_info',
      'subkind': 'metadata',
      'target': {'source': 'coldigom', 'praiseId': 'p1', 'materialId': 'm1'},
      'title': 'Tom errado',
      'body': 'É Em, não Dm',
      'fields': {'field': 'tonality', 'current': 'Dm', 'proposed': 'Em'},
      'links': ['https://youtu.be/abc'],
      'device': null,
      'appRoute': '/leitor?pdfId=x',
      'appVersion': '2.1.0+45',
    });
  });

  test(
    'bug junta o snapshot com same_device e a nota do outro dispositivo',
    () {
      const draft = ContributionDraft(
        kind: ContributionKind.bug,
        subkind: ContributionSubkind.bugReader,
        title: 'Leitor trava',
        body: 'Ao abrir a página 3',
        sameDevice: false,
        otherDeviceNote: 'iPad da igreja',
      );
      final payload = draft.toPayload(
        device: {'platform': 'web'},
        appVersion: '1',
      );
      expect(payload['device'], {
        'platform': 'web',
        'same_device': false,
        'other_device_note': 'iPad da igreja',
      });
      expect(payload['fields'], <String, dynamic>{});
    },
  );

  test('duplicate e content preenchem fields próprios', () {
    const dup = ContributionDraft(
      kind: ContributionKind.wrongInfo,
      subkind: ContributionSubkind.duplicate,
      title: 't',
      body: 'b',
      duplicateOtherPraiseId: 'p2',
      duplicateOtherSource: ContributionSource.plpcg,
    );
    expect(dup.toPayload(device: null, appVersion: '1')['fields'], {
      'otherPraiseId': 'p2',
      'otherSource': 'plpcg',
    });
    const add = ContributionDraft(
      kind: ContributionKind.content,
      subkind: ContributionSubkind.addMaterial,
      title: 't',
      body: 'b',
      suggestedKindId: 'k-grade',
    );
    expect(add.toPayload(device: null, appVersion: '1')['fields'], {
      'suggestedKindId': 'k-grade',
    });
  });

  group('isValid', () {
    test('exige título, corpo e subkind quando o kind tem subkinds', () {
      expect(
        const ContributionDraft(
          kind: ContributionKind.improvement,
          title: 't',
          body: 'b',
        ).isValid,
        isFalse,
      );
      expect(
        const ContributionDraft(
          kind: ContributionKind.improvement,
          subkind: ContributionSubkind.feature,
          title: 't',
          body: 'b',
        ).isValid,
        isTrue,
      );
      expect(
        const ContributionDraft(
          kind: ContributionKind.other,
          body: 'b',
        ).isValid,
        isTrue,
      );
      expect(
        const ContributionDraft(
          kind: ContributionKind.other,
          body: ' ',
        ).isValid,
        isFalse,
      );
    });

    test('sendDeviceData controla inclusão de dispositivo no payload', () {
      const withDevice = ContributionDraft(
        kind: ContributionKind.other,
        body: 'b',
        sendDeviceData: true,
      );
      expect(
        withDevice.toPayload(
          device: {'platform': 'android'},
          appVersion: '1',
        )['device'],
        {'platform': 'android', 'same_device': true},
      );

      const withoutDevice = ContributionDraft(
        kind: ContributionKind.other,
        body: 'b',
        sendDeviceData: false,
      );
      expect(
        withoutDevice.toPayload(
          device: {'platform': 'android'},
          appVersion: '1',
        )['device'],
        isNull,
      );
    });

    test('bug exige resposta sobre o dispositivo, e nota se não foi este', () {
      const base = ContributionDraft(
        kind: ContributionKind.bug,
        subkind: ContributionSubkind.bugOther,
        title: 't',
        body: 'b',
      );
      expect(base.isValid, isFalse);
      expect(base.copyWith(sameDevice: true).isValid, isTrue);
      expect(base.copyWith(sameDevice: false).isValid, isFalse);
      expect(
        base.copyWith(sameDevice: false, otherDeviceNote: 'PC').isValid,
        isTrue,
      );
    });
    test('metadata exige field e proposed', () {
      const m = ContributionDraft(
        kind: ContributionKind.wrongInfo,
        subkind: ContributionSubkind.wrongMetadata,
        title: 't',
        body: 'b',
      );
      expect(m.isValid, isFalse);
      expect(
        m
            .copyWith(
              metadataField: MetadataField.author,
              metadataProposed: 'X',
            )
            .isValid,
        isTrue,
      );
    });
  });

  test('MetadataField: wireNames sem category (a seção virou tag)', () {
    expect(
      [for (final f in MetadataField.values) f.name],
      ['title', 'number', 'author', 'tonality', 'rhythm', 'tags'],
    );
  });

  group('toStorageJson e fromStorageJson', () {
    test('serializa e restaura rascunho completo', () {
      const draft = ContributionDraft(
        kind: ContributionKind.wrongInfo,
        subkind: ContributionSubkind.wrongMetadata,
        target: target,
        title: 'Título salvo',
        body: 'Descrição salva',
        links: ['https://youtu.be/abc', 'https://drive.google.com/file'],
        metadataField: MetadataField.author,
        metadataCurrent: 'Antigo',
        metadataProposed: 'Novo',
        duplicateOtherPraiseId: 'p-dup',
        duplicateOtherSource: ContributionSource.coldigom,
        suggestedKindId: 'kind-1',
        sameDevice: true,
        otherDeviceNote: null,
        appRoute: '/route-1',
      );

      final json = draft.toStorageJson();
      final restored = ContributionDraft.fromStorageJson(json);

      expect(restored.kind, draft.kind);
      expect(restored.subkind, draft.subkind);
      expect(restored.target?.source, draft.target?.source);
      expect(restored.target?.praiseId, draft.target?.praiseId);
      expect(restored.target?.materialId, draft.target?.materialId);
      expect(restored.title, draft.title);
      expect(restored.body, draft.body);
      expect(restored.links, draft.links);
      expect(restored.metadataField, draft.metadataField);
      expect(restored.metadataCurrent, draft.metadataCurrent);
      expect(restored.metadataProposed, draft.metadataProposed);
      expect(restored.duplicateOtherPraiseId, draft.duplicateOtherPraiseId);
      expect(restored.duplicateOtherSource, draft.duplicateOtherSource);
      expect(restored.suggestedKindId, draft.suggestedKindId);
      expect(restored.sameDevice, draft.sameDevice);
      expect(restored.sendDeviceData, draft.sendDeviceData);
      expect(restored.appRoute, draft.appRoute);
    });

    test('anexos menores que 1MB são preservados com bytes; maiores são omitidos no storage', () {
      final smallBytes = [1, 2, 3, 4];
      final small = ContributionAttachment(
        name: 'foto.jpg',
        size: 4,
        bytes: Uint8List.fromList(smallBytes),
      );
      final big = ContributionAttachment(
        name: 'grande.pdf',
        size: 2 * 1024 * 1024,
        bytes: Uint8List(2 * 1024 * 1024),
      );

      final draft = const ContributionDraft(
        kind: ContributionKind.bug,
        title: 'Bug',
        body: 'Desc',
      ).copyWith(attachments: [small, big]);

      final json = draft.toStorageJson();
      final attachmentsJson = json['attachments'] as List;
      expect(attachmentsJson.length, 1);
      expect((attachmentsJson.first as Map)['name'], 'foto.jpg');

      final restored = ContributionDraft.fromStorageJson(json);
      expect(restored.attachments.length, 1);
      expect(restored.attachments.first.name, 'foto.jpg');
      expect(restored.attachments.first.bytes, smallBytes);
    });
  });
}


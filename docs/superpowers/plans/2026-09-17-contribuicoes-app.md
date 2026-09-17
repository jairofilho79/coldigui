# Contribuições da comunidade — App Flutter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Formulário «Ajude a melhorar o PLPCG» (só logado) com entrada pelo Perfil, pelo sheet do louvor e pelo leitor/player; coleta automática do dispositivo em bugs; tela «Minhas contribuições» com o estado de cada envio.

**Architecture:** Feature `lib/features/contributions/` em `domain / data / presentation` como `material_kind_prefs`. O domínio define o rascunho e o payload; a `data` fala com o coldigom-api (multipart com Bearer `sess_…`); a `presentation` tem `ContributeScreen`, `MyContributionsScreen` e os pontos de entrada. Coleta de dispositivo via port com import condicional (nativo/web).

**Tech Stack:** Flutter 3, Riverpod 3, go_router 17, Dio 5, `file_picker`, `device_info_plus`, `package_info_plus`, l10n ARB (`pt`/`en`), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-17-contribuicoes-comunidade-design.md` §6 (e §3.1/§4.2 para o contrato). Pré-requisito em produção: plano `2026-09-17-contribuicoes-backend.md` (mas o app é testável com fakes sem ele).

## Global Constraints

- Repo `coldigui`, branch de trabalho em worktree. **Git sempre como comando plano** (`git add …`, `git commit …`), nunca `cd X && git …` nem `git -C`.
- Comentários e commits em português, estilo dos arquivos vizinhos (porquê, não o quê).
- `dart format` nos arquivos tocados; `flutter analyze` sem warnings novos; testes com `flutter test <caminho>`. Revisores usam `dart format --output=none --set-exit-if-changed`.
- Strings de UI **sempre** em `lib/l10n/app_pt.arb` e `app_en.arb` (`flutter gen-l10n` corre no build; em teste, `AppLocalizations` real via `test/support/pump_app.dart`).
- Limites (spec §4.2): 5 arquivos, 32 MiB (`33554432` bytes) cada, extensões `pdf|mp3|jpg|jpeg|png|txt|chordpro`; bug só `jpg|jpeg|png`; 5 links, hosts `youtube.com | www.youtube.com | youtu.be | drive.google.com | docs.google.com`; título ≤ 120; corpo ≤ 4000.
- Cores/tipografia: `AppColors` (`lib/core/theme/color_extensions.dart`) e `AppTypography`; não inventar cores.
- Nunca coletar identificador único de dispositivo, localização, contatos ou logs.

---

## File Structure

```
lib/features/contributions/
  domain/
    entities/contribution_kind.dart        # enums Kind/Subkind, MetadataField, ContributionSource
    entities/contribution_target.dart      # ContributionTarget {source, praiseId, materialId}
    entities/contribution_draft.dart       # ContributionDraft + toPayload()
    entities/contribution_attachment.dart  # ContributionAttachment {name, size, bytes}
    entities/contribution_summary.dart     # ContributionSummary/ContributionFileSummary/ContributionStatus
    entities/device_snapshot.dart          # DeviceSnapshot + toJson
    ports/device_snapshot_port.dart        # abstract DeviceSnapshotPort
    validators/attachment_rules.dart       # validateAttachment, validateLink, constantes
  data/
    device/device_snapshot_native.dart     # device_info_plus + package_info_plus
    device/device_snapshot_web.dart        # package:web
    device/device_snapshot_stub.dart       # par do import condicional
    device/device_snapshot_provider.dart   # deviceSnapshotPortProvider
    datasources/contributions_remote_datasource.dart
    providers/contributions_providers.dart # contributionsDioProvider, contributionsRemoteDatasourceProvider
  presentation/
    providers/contribute_form_provider.dart    # ContributeFormNotifier (estado do rascunho + envio)
    providers/my_contributions_provider.dart   # lista paginada
    pages/contribute_screen.dart
    pages/my_contributions_screen.dart
    pages/contribution_detail_screen.dart
    widgets/contribution_status_chip.dart
    widgets/device_consent_card.dart
    widgets/sign_in_to_contribute.dart
    utils/open_contribute.dart                 # openContribute(context, {target, from})
test/unit/features/contributions/…
test/widget/features/contributions/…
```

Modificados: `pubspec.yaml`, `lib/core/routing/route_paths.dart`, `lib/core/routing/app_router.dart`, `lib/features/app_shell/presentation/pages/profile_screen.dart`, `lib/features/catalog/presentation/widgets/material_sheet.dart`, `lib/features/pdf_reader/presentation/pages/pdf_reader_screen.dart`, `lib/features/audio_player/presentation/pages/audio_player_screen.dart`, `lib/features/coldigom/data/constants/coldigom_endpoints.dart`, `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb`.

---

### Task 1: Domínio — enums, rascunho, payload e regras de anexo/link

**Files:**
- Create: `lib/features/contributions/domain/entities/contribution_kind.dart`
- Create: `lib/features/contributions/domain/entities/contribution_target.dart`
- Create: `lib/features/contributions/domain/entities/contribution_attachment.dart`
- Create: `lib/features/contributions/domain/entities/contribution_draft.dart`
- Create: `lib/features/contributions/domain/validators/attachment_rules.dart`
- Test: `test/unit/features/contributions/contribution_draft_test.dart`
- Test: `test/unit/features/contributions/attachment_rules_test.dart`

**Interfaces:**
- Produces:

```dart
enum ContributionKind { bug, wrongInfo, content, improvement, other }   // wireName: 'bug','wrong_info','content','improvement','other'
enum ContributionSubkind {                                              // cada um com `kind` e `wireName`
  bugScreen, bugReader, bugAudio, bugSearch, bugOffline, bugLogin, bugPlaylistLive, bugOther,
  wrongMetadata, wrongLyrics, wrongMaterial, wrongKind, duplicate,
  addMaterial, addPraise, replaceMaterial, remove,
  feature, behavior,
}
extension ContributionSubkindX on ContributionSubkind { ContributionKind get kind; String get wireName; }
List<ContributionSubkind> subkindsOf(ContributionKind kind);            // [] para other
enum MetadataField { title, number, author, tonality, rhythm, category, tags }  // wireName = name
enum ContributionSource { coldigom, plpcg }
class ContributionTarget { final ContributionSource source; final String? praiseId; final String? materialId; }
class ContributionAttachment { final String name; final int size; final Uint8List bytes; String get extension; }
class ContributionDraft {  // imutável, copyWith
  kind, subkind, target, title, body, links (List<String>), attachments (List<ContributionAttachment>),
  metadataField (MetadataField?), metadataCurrent (String?), metadataProposed (String?),
  duplicateOtherPraiseId (String?), duplicateOtherSource (ContributionSource?),
  suggestedKindId (String?), sameDevice (bool?), otherDeviceNote (String?),
  appRoute (String?)
  Map<String, dynamic> toPayload({required Map<String, dynamic>? device, required String appVersion});
  bool get isValid;   // título/corpo não vazios, subkind coerente, bug ⇒ sameDevice != null (&& nota se false)
}
// attachment_rules.dart
const int kMaxAttachmentBytes = 32 * 1024 * 1024; const int kMaxAttachments = 5; const int kMaxLinks = 5;
const Set<String> kAllowedExtensions; const Set<String> kImageExtensions; const Set<String> kAllowedLinkHosts;
enum AttachmentError { tooLarge, typeNotAllowed, tooMany }
AttachmentError? validateAttachment({required String name, required int size, required ContributionKind kind, required int currentCount});
bool isAllowedLink(String url);
```

- [ ] **Step 1: Testes**

`test/unit/features/contributions/contribution_draft_test.dart`:

```dart
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
    expect(subkindsOf(ContributionKind.wrongInfo).first, ContributionSubkind.wrongMetadata);
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

  test('bug junta o snapshot com same_device e a nota do outro dispositivo', () {
    const draft = ContributionDraft(
      kind: ContributionKind.bug,
      subkind: ContributionSubkind.bugReader,
      title: 'Leitor trava',
      body: 'Ao abrir a página 3',
      sameDevice: false,
      otherDeviceNote: 'iPad da igreja',
    );
    final payload = draft.toPayload(device: {'platform': 'web'}, appVersion: '1');
    expect(payload['device'], {
      'platform': 'web',
      'same_device': false,
      'other_device_note': 'iPad da igreja',
    });
    expect(payload['fields'], <String, dynamic>{});
  });

  test('duplicate e content preenchem fields próprios', () {
    const dup = ContributionDraft(
      kind: ContributionKind.wrongInfo,
      subkind: ContributionSubkind.duplicate,
      title: 't', body: 'b',
      duplicateOtherPraiseId: 'p2',
      duplicateOtherSource: ContributionSource.plpcg,
    );
    expect(dup.toPayload(device: null, appVersion: '1')['fields'], {'otherPraiseId': 'p2', 'otherSource': 'plpcg'});
    const add = ContributionDraft(
      kind: ContributionKind.content,
      subkind: ContributionSubkind.addMaterial,
      title: 't', body: 'b',
      suggestedKindId: 'k-grade',
    );
    expect(add.toPayload(device: null, appVersion: '1')['fields'], {'suggestedKindId': 'k-grade'});
  });

  group('isValid', () {
    test('exige título, corpo e subkind quando o kind tem subkinds', () {
      expect(const ContributionDraft(kind: ContributionKind.improvement, title: 't', body: 'b').isValid, isFalse);
      expect(const ContributionDraft(kind: ContributionKind.improvement, subkind: ContributionSubkind.feature, title: 't', body: 'b').isValid, isTrue);
      expect(const ContributionDraft(kind: ContributionKind.other, title: 't', body: 'b').isValid, isTrue);
      expect(const ContributionDraft(kind: ContributionKind.other, title: ' ', body: 'b').isValid, isFalse);
    });
    test('bug exige resposta sobre o dispositivo, e nota se não foi este', () {
      const base = ContributionDraft(kind: ContributionKind.bug, subkind: ContributionSubkind.bugOther, title: 't', body: 'b');
      expect(base.isValid, isFalse);
      expect(base.copyWith(sameDevice: true).isValid, isTrue);
      expect(base.copyWith(sameDevice: false).isValid, isFalse);
      expect(base.copyWith(sameDevice: false, otherDeviceNote: 'PC').isValid, isTrue);
    });
    test('metadata exige field e proposed', () {
      const m = ContributionDraft(kind: ContributionKind.wrongInfo, subkind: ContributionSubkind.wrongMetadata, title: 't', body: 'b');
      expect(m.isValid, isFalse);
      expect(m.copyWith(metadataField: MetadataField.author, metadataProposed: 'X').isValid, isTrue);
    });
  });
}
```

`test/unit/features/contributions/attachment_rules_test.dart`:

```dart
import 'package:coldigui/features/contributions/domain/entities/contribution_kind.dart';
import 'package:coldigui/features/contributions/domain/validators/attachment_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extensões permitidas e jpeg', () {
    expect(validateAttachment(name: 'a.PDF', size: 10, kind: ContributionKind.content, currentCount: 0), isNull);
    expect(validateAttachment(name: 'f.jpeg', size: 10, kind: ContributionKind.bug, currentCount: 0), isNull);
    expect(validateAttachment(name: 'x.exe', size: 10, kind: ContributionKind.content, currentCount: 0), AttachmentError.typeNotAllowed);
  });
  test('bug só aceita imagem', () {
    expect(validateAttachment(name: 'a.pdf', size: 10, kind: ContributionKind.bug, currentCount: 0), AttachmentError.typeNotAllowed);
  });
  test('32 MiB é o teto; 5 é o máximo', () {
    expect(validateAttachment(name: 'a.pdf', size: kMaxAttachmentBytes, kind: ContributionKind.content, currentCount: 0), isNull);
    expect(validateAttachment(name: 'a.pdf', size: kMaxAttachmentBytes + 1, kind: ContributionKind.content, currentCount: 0), AttachmentError.tooLarge);
    expect(validateAttachment(name: 'a.pdf', size: 1, kind: ContributionKind.content, currentCount: 5), AttachmentError.tooMany);
  });
  test('links: https e host da lista', () {
    expect(isAllowedLink('https://youtu.be/a'), isTrue);
    expect(isAllowedLink('https://www.youtube.com/watch?v=a'), isTrue);
    expect(isAllowedLink('https://drive.google.com/file/d/1/view'), isTrue);
    expect(isAllowedLink('http://youtu.be/a'), isFalse);
    expect(isAllowedLink('https://youtube.com.evil.example/a'), isFalse);
    expect(isAllowedLink('não é url'), isFalse);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/contributions/`
Expected: falha de compilação (arquivos inexistentes).

- [ ] **Step 3: Implementar `contribution_kind.dart`**

```dart
/// Taxonomia das contribuições (spec §3.1). Os `wireName` são o contrato com
/// o coldigom-api — mudar aqui sem mudar lá quebra o `400 invalid_kind`.
enum ContributionKind {
  bug('bug'),
  wrongInfo('wrong_info'),
  content('content'),
  improvement('improvement'),
  other('other');

  const ContributionKind(this.wireName);
  final String wireName;
}

enum ContributionSubkind {
  bugScreen(ContributionKind.bug, 'screen'),
  bugReader(ContributionKind.bug, 'reader'),
  bugAudio(ContributionKind.bug, 'audio'),
  bugSearch(ContributionKind.bug, 'search'),
  bugOffline(ContributionKind.bug, 'offline'),
  bugLogin(ContributionKind.bug, 'login'),
  bugPlaylistLive(ContributionKind.bug, 'playlist_live'),
  bugOther(ContributionKind.bug, 'other'),
  wrongMetadata(ContributionKind.wrongInfo, 'metadata'),
  wrongLyrics(ContributionKind.wrongInfo, 'lyrics'),
  wrongMaterial(ContributionKind.wrongInfo, 'wrong_material'),
  wrongKind(ContributionKind.wrongInfo, 'wrong_kind'),
  duplicate(ContributionKind.wrongInfo, 'duplicate'),
  addMaterial(ContributionKind.content, 'add_material'),
  addPraise(ContributionKind.content, 'add_praise'),
  replaceMaterial(ContributionKind.content, 'replace_material'),
  remove(ContributionKind.content, 'remove'),
  feature(ContributionKind.improvement, 'feature'),
  behavior(ContributionKind.improvement, 'behavior');

  const ContributionSubkind(this.kind, this.wireName);
  final ContributionKind kind;
  final String wireName;
}

List<ContributionSubkind> subkindsOf(ContributionKind kind) => [
  for (final s in ContributionSubkind.values)
    if (s.kind == kind) s,
];

enum MetadataField { title, number, author, tonality, rhythm, category, tags }

enum ContributionSource {
  coldigom('coldigom'),
  plpcg('plpcg');

  const ContributionSource(this.wireName);
  final String wireName;
}
```

`contribution_target.dart`:

```dart
import 'contribution_kind.dart';

/// Louvor/material sobre o qual a contribuição fala. `null` = geral.
class ContributionTarget {
  const ContributionTarget({required this.source, this.praiseId, this.materialId});

  final ContributionSource source;
  final String? praiseId;
  final String? materialId;

  Map<String, dynamic> toJson() => {
    'source': source.wireName,
    'praiseId': praiseId,
    'materialId': materialId,
  };

  ContributionTarget copyWith({String? materialId}) =>
      ContributionTarget(source: source, praiseId: praiseId, materialId: materialId ?? this.materialId);
}
```

`contribution_attachment.dart`:

```dart
import 'dart:typed_data';

class ContributionAttachment {
  const ContributionAttachment({required this.name, required this.size, required this.bytes});

  final String name;
  final int size;
  final Uint8List bytes;

  String get extension => name.contains('.') ? name.split('.').last.toLowerCase() : '';
}
```

- [ ] **Step 4: Implementar `attachment_rules.dart`**

```dart
import '../entities/contribution_kind.dart';

/// Espelho das regras do servidor (spec §4.2). O servidor revalida tudo — isto
/// só evita uma ida à rede para receber um 400 previsível.
const int kMaxAttachmentBytes = 32 * 1024 * 1024;
const int kMaxAttachments = 5;
const int kMaxLinks = 5;
const int kMaxTitleLength = 120;
const int kMaxBodyLength = 4000;

const Set<String> kAllowedExtensions = {'pdf', 'mp3', 'jpg', 'jpeg', 'png', 'txt', 'chordpro'};
const Set<String> kImageExtensions = {'jpg', 'jpeg', 'png'};
const Set<String> kAllowedLinkHosts = {
  'youtube.com', 'www.youtube.com', 'youtu.be', 'drive.google.com', 'docs.google.com',
};

enum AttachmentError { tooLarge, typeNotAllowed, tooMany }

String _extensionOf(String name) =>
    name.contains('.') ? name.split('.').last.toLowerCase() : '';

AttachmentError? validateAttachment({
  required String name,
  required int size,
  required ContributionKind kind,
  required int currentCount,
}) {
  if (currentCount >= kMaxAttachments) return AttachmentError.tooMany;
  final ext = _extensionOf(name);
  final allowed = kind == ContributionKind.bug ? kImageExtensions : kAllowedExtensions;
  if (!allowed.contains(ext)) return AttachmentError.typeNotAllowed;
  if (size > kMaxAttachmentBytes) return AttachmentError.tooLarge;
  return null;
}

bool isAllowedLink(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.scheme != 'https') return false;
  return kAllowedLinkHosts.contains(uri.host);
}
```

- [ ] **Step 5: Implementar `contribution_draft.dart`**

```dart
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

  bool get isValid {
    if (title.trim().isEmpty || body.trim().isEmpty) return false;
    if (subkindsOf(kind).isNotEmpty && (subkind == null || subkind!.kind != kind)) return false;
    if (kind == ContributionKind.bug) {
      if (sameDevice == null) return false;
      if (sameDevice == false && (otherDeviceNote ?? '').trim().isEmpty) return false;
    }
    if (subkind == ContributionSubkind.wrongMetadata &&
        (metadataField == null || (metadataProposed ?? '').trim().isEmpty)) {
      return false;
    }
    if (subkind == ContributionSubkind.duplicate &&
        ((duplicateOtherPraiseId ?? '').isEmpty || duplicateOtherSource == null)) {
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
        return {'otherPraiseId': duplicateOtherPraiseId, 'otherSource': duplicateOtherSource!.wireName};
      case ContributionSubkind.addMaterial:
      case ContributionSubkind.addPraise:
      case ContributionSubkind.replaceMaterial:
      case ContributionSubkind.remove:
        return {if (suggestedKindId != null) 'suggestedKindId': suggestedKindId};
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
      subkind: subkind == _sentinel ? this.subkind : subkind as ContributionSubkind?,
      target: target == _sentinel ? this.target : target as ContributionTarget?,
      title: title ?? this.title,
      body: body ?? this.body,
      links: links ?? this.links,
      attachments: attachments ?? this.attachments,
      metadataField: metadataField == _sentinel ? this.metadataField : metadataField as MetadataField?,
      metadataCurrent: metadataCurrent == _sentinel ? this.metadataCurrent : metadataCurrent as String?,
      metadataProposed: metadataProposed == _sentinel ? this.metadataProposed : metadataProposed as String?,
      duplicateOtherPraiseId: duplicateOtherPraiseId == _sentinel ? this.duplicateOtherPraiseId : duplicateOtherPraiseId as String?,
      duplicateOtherSource: duplicateOtherSource == _sentinel ? this.duplicateOtherSource : duplicateOtherSource as ContributionSource?,
      suggestedKindId: suggestedKindId == _sentinel ? this.suggestedKindId : suggestedKindId as String?,
      sameDevice: sameDevice == _sentinel ? this.sameDevice : sameDevice as bool?,
      otherDeviceNote: otherDeviceNote == _sentinel ? this.otherDeviceNote : otherDeviceNote as String?,
      appRoute: appRoute == _sentinel ? this.appRoute : appRoute as String?,
    );
  }
}

const Object _sentinel = Object();
```

- [ ] **Step 6: Rodar e passar**

Run: `flutter test test/unit/features/contributions/ && dart format lib/features/contributions test/unit/features/contributions && flutter analyze lib/features/contributions`
Expected: PASS, sem issues.

- [ ] **Step 7: Commit**

```bash
git add lib/features/contributions/domain test/unit/features/contributions
git commit -m "feat(contributions): domínio — kinds, rascunho, payload e regras de anexo/link"
```

---

### Task 2: `DeviceSnapshot` e o port de coleta (nativo/web)

**Files:**
- Modify: `pubspec.yaml` (`flutter pub add device_info_plus package_info_plus`)
- Create: `lib/features/contributions/domain/entities/device_snapshot.dart`
- Create: `lib/features/contributions/domain/ports/device_snapshot_port.dart`
- Create: `lib/features/contributions/data/device/device_snapshot_stub.dart`
- Create: `lib/features/contributions/data/device/device_snapshot_native.dart`
- Create: `lib/features/contributions/data/device/device_snapshot_web.dart`
- Create: `lib/features/contributions/data/device/device_snapshot_provider.dart`
- Create: `test/support/fakes/fake_device_snapshot_port.dart`
- Test: `test/unit/features/contributions/device_snapshot_test.dart`

**Interfaces:**
- Produces:

```dart
class DeviceSnapshot {
  final String appVersion, buildNumber, platform; final String locale;
  final int screenW, screenH; final double pixelRatio;
  final bool online, pwaStandalone;
  final String? manufacturer, model, osVersion, userAgent;
  Map<String, dynamic> toJson();          // chaves snake_case: app_version, build_number, platform, locale, screen_w, screen_h, pixel_ratio, online, pwa_standalone, manufacturer, model, os_version, user_agent
  List<(String, String)> humanLines();    // pares (rótulo curto, valor) para o cartão «Isto será enviado»
}
abstract class DeviceSnapshotPort {
  /// [screen]/[locale]/[online] vêm do widget (MediaQuery/Localizations/connectivity); o port só sabe do que é do SO.
  Future<DeviceSnapshot> collect({required Size screen, required double pixelRatio, required String locale, required bool online});
}
final deviceSnapshotPortProvider = Provider<DeviceSnapshotPort>(…);
class FakeDeviceSnapshotPort implements DeviceSnapshotPort { … devolve um snapshot fixo }
```

- [ ] **Step 1: Deps**

Run: `flutter pub add device_info_plus package_info_plus`
Expected: `pubspec.yaml`/`pubspec.lock` atualizados sem conflito.

- [ ] **Step 2: Teste**

`test/unit/features/contributions/device_snapshot_test.dart`:

```dart
import 'package:coldigui/features/contributions/domain/entities/device_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const snap = DeviceSnapshot(
    appVersion: '2.1.0', buildNumber: '45', platform: 'android', locale: 'pt',
    screenW: 1080, screenH: 2340, pixelRatio: 2.75, online: true, pwaStandalone: false,
    manufacturer: 'Samsung', model: 'SM-A515F', osVersion: '13',
  );

  test('toJson em snake_case, sem chaves nulas', () {
    expect(snap.toJson(), {
      'app_version': '2.1.0', 'build_number': '45', 'platform': 'android', 'locale': 'pt',
      'screen_w': 1080, 'screen_h': 2340, 'pixel_ratio': 2.75, 'online': true, 'pwa_standalone': false,
      'manufacturer': 'Samsung', 'model': 'SM-A515F', 'os_version': '13',
    });
  });

  test('humanLines mostra o que vai ser enviado, sem campos vazios', () {
    final labels = snap.humanLines().map((l) => l.$1).toList();
    expect(labels, containsAll(['App', 'Plataforma', 'Dispositivo', 'Sistema', 'Tela']));
    expect(labels, isNot(contains('Navegador')));
  });
}
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `flutter test test/unit/features/contributions/device_snapshot_test.dart`

- [ ] **Step 4: Entidade e port**

`device_snapshot.dart`:

```dart
/// O que vai junto com um bug (spec §6.3). Nada aqui identifica a pessoa ou o
/// aparelho de forma única — é o suficiente para reproduzir, não para rastrear.
class DeviceSnapshot {
  const DeviceSnapshot({
    required this.appVersion,
    required this.buildNumber,
    required this.platform,
    required this.locale,
    required this.screenW,
    required this.screenH,
    required this.pixelRatio,
    required this.online,
    required this.pwaStandalone,
    this.manufacturer,
    this.model,
    this.osVersion,
    this.userAgent,
  });

  final String appVersion;
  final String buildNumber;
  /// `android` | `ios` | `web` | `macos` | `windows` | `linux`.
  final String platform;
  final String locale;
  final int screenW;
  final int screenH;
  final double pixelRatio;
  final bool online;
  final bool pwaStandalone;
  final String? manufacturer;
  final String? model;
  final String? osVersion;
  final String? userAgent;

  String get versionLabel => '$appVersion+$buildNumber';

  Map<String, dynamic> toJson() => {
    'app_version': appVersion,
    'build_number': buildNumber,
    'platform': platform,
    'locale': locale,
    'screen_w': screenW,
    'screen_h': screenH,
    'pixel_ratio': pixelRatio,
    'online': online,
    'pwa_standalone': pwaStandalone,
    if (manufacturer != null) 'manufacturer': manufacturer,
    if (model != null) 'model': model,
    if (osVersion != null) 'os_version': osVersion,
    if (userAgent != null) 'user_agent': userAgent,
  };

  /// Linhas do cartão «Isto será enviado». Rótulos curtos e fixos (o cartão
  /// é técnico; não passa por l10n de propósito — o valor é o que importa).
  List<(String, String)> humanLines() => [
    ('App', versionLabel),
    ('Plataforma', platform),
    if (manufacturer != null || model != null)
      ('Dispositivo', [manufacturer, model].whereType<String>().join(' ')),
    if (osVersion != null) ('Sistema', osVersion!),
    if (userAgent != null) ('Navegador', userAgent!),
    ('Tela', '${screenW}×$screenH @${pixelRatio}x'),
    ('Idioma', locale),
    ('Online', online ? 'sim' : 'não'),
    if (platform == 'web') ('PWA instalada', pwaStandalone ? 'sim' : 'não'),
  ];
}
```

`ports/device_snapshot_port.dart`:

```dart
import 'dart:ui' show Size;

import '../entities/device_snapshot.dart';

/// Coleta o que é do SO/navegador. O que é do Flutter (tela, idioma,
/// conectividade) vem por parâmetro — assim o port não precisa de BuildContext
/// e é trivial de falsear em teste.
abstract class DeviceSnapshotPort {
  Future<DeviceSnapshot> collect({
    required Size screen,
    required double pixelRatio,
    required String locale,
    required bool online,
  });
}
```

- [ ] **Step 5: Implementações**

`data/device/device_snapshot_native.dart`:

```dart
import 'dart:io' show Platform;
import 'dart:ui' show Size;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../domain/entities/device_snapshot.dart';
import '../../domain/ports/device_snapshot_port.dart';

class NativeDeviceSnapshotPort implements DeviceSnapshotPort {
  @override
  Future<DeviceSnapshot> collect({
    required Size screen,
    required double pixelRatio,
    required String locale,
    required bool online,
  }) async {
    final pkg = await PackageInfo.fromPlatform();
    final info = DeviceInfoPlugin();
    String? manufacturer;
    String? model;
    String? osVersion;
    if (Platform.isAndroid) {
      final a = await info.androidInfo;
      manufacturer = a.manufacturer;
      model = a.model;
      osVersion = 'Android ${a.version.release} (SDK ${a.version.sdkInt})';
    } else if (Platform.isIOS) {
      final i = await info.iosInfo;
      manufacturer = 'Apple';
      model = i.utsname.machine;
      osVersion = '${i.systemName} ${i.systemVersion}';
    }
    return DeviceSnapshot(
      appVersion: pkg.version,
      buildNumber: pkg.buildNumber,
      platform: Platform.operatingSystem,
      locale: locale,
      screenW: screen.width.round(),
      screenH: screen.height.round(),
      pixelRatio: pixelRatio,
      online: online,
      pwaStandalone: false,
      manufacturer: manufacturer,
      model: model,
      osVersion: osVersion,
    );
  }
}

DeviceSnapshotPort createDeviceSnapshotPort() => NativeDeviceSnapshotPort();
```

`data/device/device_snapshot_web.dart`:

```dart
import 'dart:ui' show Size;

import 'package:package_info_plus/package_info_plus.dart';
import 'package:web/web.dart' as web;

import '../../domain/entities/device_snapshot.dart';
import '../../domain/ports/device_snapshot_port.dart';

class WebDeviceSnapshotPort implements DeviceSnapshotPort {
  @override
  Future<DeviceSnapshot> collect({
    required Size screen,
    required double pixelRatio,
    required String locale,
    required bool online,
  }) async {
    final pkg = await PackageInfo.fromPlatform();
    return DeviceSnapshot(
      appVersion: pkg.version,
      buildNumber: pkg.buildNumber,
      platform: 'web',
      locale: locale,
      screenW: screen.width.round(),
      screenH: screen.height.round(),
      pixelRatio: pixelRatio,
      online: online,
      pwaStandalone: web.window.matchMedia('(display-mode: standalone)').matches,
      userAgent: web.window.navigator.userAgent,
    );
  }
}

DeviceSnapshotPort createDeviceSnapshotPort() => WebDeviceSnapshotPort();
```

`data/device/device_snapshot_stub.dart`:

```dart
import '../../domain/ports/device_snapshot_port.dart';

/// Par do import condicional — nunca chega a rodar (nativo e web têm impl).
DeviceSnapshotPort createDeviceSnapshotPort() =>
    throw UnsupportedError('DeviceSnapshotPort sem implementação nesta plataforma');
```

`data/device/device_snapshot_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/ports/device_snapshot_port.dart';
import 'device_snapshot_stub.dart'
    if (dart.library.io) 'device_snapshot_native.dart'
    if (dart.library.js_interop) 'device_snapshot_web.dart';

final deviceSnapshotPortProvider = Provider<DeviceSnapshotPort>(
  (ref) => createDeviceSnapshotPort(),
);
```

`test/support/fakes/fake_device_snapshot_port.dart`:

```dart
import 'dart:ui' show Size;

import 'package:coldigui/features/contributions/domain/entities/device_snapshot.dart';
import 'package:coldigui/features/contributions/domain/ports/device_snapshot_port.dart';

class FakeDeviceSnapshotPort implements DeviceSnapshotPort {
  FakeDeviceSnapshotPort([this.snapshot = const DeviceSnapshot(
    appVersion: '0.0.0', buildNumber: '1', platform: 'test', locale: 'pt',
    screenW: 400, screenH: 800, pixelRatio: 2, online: true, pwaStandalone: false,
    model: 'Fake', osVersion: 'Test 1',
  )]);

  final DeviceSnapshot snapshot;

  @override
  Future<DeviceSnapshot> collect({required Size screen, required double pixelRatio, required String locale, required bool online}) async => snapshot;
}
```

- [ ] **Step 6: Rodar e passar**

Run: `flutter test test/unit/features/contributions/device_snapshot_test.dart && flutter analyze lib/features/contributions test/support/fakes && dart format lib/features/contributions test/support/fakes/fake_device_snapshot_port.dart test/unit/features/contributions`

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/contributions/domain/entities/device_snapshot.dart lib/features/contributions/domain/ports lib/features/contributions/data/device test/support/fakes/fake_device_snapshot_port.dart test/unit/features/contributions/device_snapshot_test.dart
git commit -m "feat(contributions): DeviceSnapshot e port de coleta (nativo via device_info_plus, web via package:web)"
```

---

### Task 3: Datasource remoto e providers de rede

**Files:**
- Modify: `lib/features/coldigom/data/constants/coldigom_endpoints.dart`
- Create: `lib/features/contributions/domain/entities/contribution_summary.dart`
- Create: `lib/features/contributions/data/datasources/contributions_remote_datasource.dart`
- Create: `lib/features/contributions/data/providers/contributions_providers.dart`
- Test: `test/unit/features/contributions/contributions_remote_datasource_test.dart`

**Interfaces:**
- Consumes: `ContributionDraft.toPayload` (Task 1), `AuthUnauthorizedInterceptor` (`lib/core/network/auth_unauthorized_interceptor.dart`), `ColdigomApiConfig.baseUrl`, `authStateProvider`.
- Produces:

```dart
// coldigom_endpoints.dart
static const contributions = '/api/contributions';
static const contributionsMine = '/api/contributions/mine';
static String contribution(String id) => '/api/contributions/$id';

// contribution_summary.dart
enum ContributionStatus { recebida, bloqueada, pendente, emAnalise, aceita, recusada, aplicada; static ContributionStatus fromWire(String s); }
class ContributionFileSummary { final String id, originalName, scanStatus; final int size; }
class ContributionSummary {
  final String id; final ContributionKind kind; final String? subkind; final String title, body;
  final ContributionStatus status; final String? decisionNote; final DateTime createdAt, updatedAt;
  final List<String> links; final List<ContributionFileSummary> files; final Map<String, dynamic> fields;
  factory ContributionSummary.fromJson(Map<String, dynamic> json);
}
class ContributionsPage { final List<ContributionSummary> items; final String? nextCursor; }

// datasource
class ContributionQuotaExceeded implements Exception { final DateTime resetAt; }
class ContributionRejected implements Exception { final int status; final String error; final String? file; }
class ContributionsRemoteDatasource {
  ContributionsRemoteDatasource(Dio dio);
  Future<({String id, ContributionStatus status})> submit({required String sessionToken, required Map<String, dynamic> payload, required List<ContributionAttachment> attachments, void Function(int sent, int total)? onProgress});
  Future<ContributionsPage> fetchMine({required String sessionToken, String? cursor});
  Future<ContributionSummary> fetchOne({required String sessionToken, required String id});
}
// providers
final contributionsDioProvider = Provider<Dio>(…);   // baseUrl Coldigom + AuthUnauthorizedInterceptor; sem RetryInterceptor (POST multipart não é idempotente)
final contributionsRemoteDatasourceProvider = Provider<ContributionsRemoteDatasource>(…);
```

- [ ] **Step 1: Teste**

`test/unit/features/contributions/contributions_remote_datasource_test.dart` (adapter falso igual ao de `material_kind_prefs_remote_datasource_test.dart`):

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:coldigui/features/auth/data/auth_remote_datasource.dart';
import 'package:coldigui/features/contributions/data/datasources/contributions_remote_datasource.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_attachment.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_summary.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedAdapter implements HttpClientAdapter {
  _FixedAdapter(this.statusCode, this.body);
  final int statusCode;
  final Object? body;
  RequestOptions? lastRequest;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    lastRequest = options;
    return ResponseBody.fromString(body == null ? '' : jsonEncode(body), statusCode, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }
  @override
  void close({bool force = false}) {}
}

(ContributionsRemoteDatasource, _FixedAdapter) _make(int status, Object? body) {
  final adapter = _FixedAdapter(status, body);
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  dio.httpClientAdapter = adapter;
  return (ContributionsRemoteDatasource(dio), adapter);
}

void main() {
  final payload = {'kind': 'improvement', 'subkind': 'feature', 'title': 't', 'body': 'b'};

  test('submit manda multipart com payload e file[], Bearer, e devolve id/status', () async {
    final (ds, adapter) = _make(201, {'id': 'c1', 'status': 'recebida'});
    final out = await ds.submit(sessionToken: 'sess_x', payload: payload, attachments: [ContributionAttachment(name: 'a.pdf', size: 3, bytes: Uint8List.fromList([1, 2, 3]))]);
    expect(out.id, 'c1');
    expect(out.status, ContributionStatus.recebida);
    final req = adapter.lastRequest!;
    expect(req.path, '/api/contributions');
    expect(req.headers['Authorization'], 'Bearer sess_x');
    final form = req.data as FormData;
    expect(form.fields.single.key, 'payload');
    expect(jsonDecode(form.fields.single.value), payload);
    expect(form.files.single.key, 'file');
    expect(form.files.single.value.filename, 'a.pdf');
  });

  test('429 vira ContributionQuotaExceeded com resetAt', () async {
    final (ds, _) = _make(429, {'error': 'quota_exceeded', 'resetAt': '2026-09-18T00:00:00Z'});
    expect(() => ds.submit(sessionToken: 's', payload: payload, attachments: const []), throwsA(isA<ContributionQuotaExceeded>().having((e) => e.resetAt.toUtc().hour, 'hora', 0)));
  });

  test('400/413 viram ContributionRejected com error e file', () async {
    final (ds, _) = _make(413, {'error': 'file_too_large', 'file': 'g.pdf'});
    expect(() => ds.submit(sessionToken: 's', payload: payload, attachments: const []), throwsA(isA<ContributionRejected>().having((e) => e.error, 'error', 'file_too_large').having((e) => e.file, 'file', 'g.pdf')));
  });

  test('401 vira AuthUnauthorizedException', () async {
    final (ds, _) = _make(401, {'error': 'unauthorized'});
    expect(() => ds.fetchMine(sessionToken: 's'), throwsA(isA<AuthUnauthorizedException>()));
  });

  test('fetchMine parseia página, status em_analise e cursor', () async {
    final (ds, adapter) = _make(200, {
      'data': [{'id': 'c1', 'kind': 'wrong_info', 'subkind': 'metadata', 'title': 'T', 'body': 'B', 'fields': {'field': 'tonality'}, 'links': ['https://youtu.be/a'], 'status': 'em_analise', 'decision_note': null, 'created_at': '2026-09-17 10:00:00', 'updated_at': '2026-09-17 11:00:00', 'files': [{'id': 'f1', 'original_name': 'g.pdf', 'size': 12, 'scan_status': 'limpa'}]}],
      'nextCursor': 'abc',
    });
    final page = await ds.fetchMine(sessionToken: 's', cursor: 'prev');
    expect(adapter.lastRequest!.queryParameters['cursor'], 'prev');
    expect(page.nextCursor, 'abc');
    final c = page.items.single;
    expect(c.status, ContributionStatus.emAnalise);
    expect(c.createdAt.isUtc, isTrue);
    expect(c.files.single.originalName, 'g.pdf');
    expect(c.links, ['https://youtu.be/a']);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/contributions/contributions_remote_datasource_test.dart`

- [ ] **Step 3: Endpoints e entidade**

Em `coldigom_endpoints.dart` acrescentar:

```dart
  /// Contribuições da comunidade (Bearer `sess_…`).
  static const contributions = '/api/contributions';
  static const contributionsMine = '/api/contributions/mine';
  static String contribution(String id) => '/api/contributions/$id';
```

`contribution_summary.dart`:

```dart
import 'contribution_kind.dart';

enum ContributionStatus {
  recebida, bloqueada, pendente, emAnalise, aceita, recusada, aplicada;

  static ContributionStatus fromWire(String s) => switch (s) {
    'recebida' => recebida, 'bloqueada' => bloqueada, 'pendente' => pendente,
    'em_analise' => emAnalise, 'aceita' => aceita, 'recusada' => recusada, 'aplicada' => aplicada,
    _ => pendente,
  };
}

class ContributionFileSummary {
  const ContributionFileSummary({required this.id, required this.originalName, required this.size, required this.scanStatus});
  final String id;
  final String originalName;
  final int size;
  final String scanStatus;
}

/// O que o próprio usuário vê de um envio (spec §4.2, `toUserJson`).
class ContributionSummary {
  const ContributionSummary({
    required this.id, required this.kind, required this.subkind, required this.title, required this.body,
    required this.status, required this.decisionNote, required this.createdAt, required this.updatedAt,
    required this.links, required this.files, required this.fields,
  });

  final String id;
  final ContributionKind kind;
  final String? subkind;
  final String title;
  final String body;
  final ContributionStatus status;
  final String? decisionNote;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> links;
  final List<ContributionFileSummary> files;
  final Map<String, dynamic> fields;

  /// D1 grava `datetime('now')` como `YYYY-MM-DD HH:MM:SS` em UTC, sem `Z`.
  static DateTime _utc(String s) => DateTime.parse('${s.replaceFirst(' ', 'T')}${s.endsWith('Z') ? '' : 'Z'}');

  factory ContributionSummary.fromJson(Map<String, dynamic> json) => ContributionSummary(
    id: json['id'] as String,
    kind: ContributionKind.values.firstWhere((k) => k.wireName == json['kind'], orElse: () => ContributionKind.other),
    subkind: json['subkind'] as String?,
    title: json['title'] as String? ?? '',
    body: json['body'] as String? ?? '',
    status: ContributionStatus.fromWire(json['status'] as String? ?? 'pendente'),
    decisionNote: json['decision_note'] as String?,
    createdAt: _utc(json['created_at'] as String),
    updatedAt: _utc(json['updated_at'] as String),
    links: [for (final l in (json['links'] as List? ?? const [])) l as String],
    files: [
      for (final f in (json['files'] as List? ?? const []))
        ContributionFileSummary(id: f['id'] as String, originalName: f['original_name'] as String, size: (f['size'] as num).toInt(), scanStatus: f['scan_status'] as String),
    ],
    fields: (json['fields'] as Map?)?.cast<String, dynamic>() ?? const {},
  );
}

class ContributionsPage {
  const ContributionsPage({required this.items, required this.nextCursor});
  final List<ContributionSummary> items;
  final String? nextCursor;
}
```

- [ ] **Step 4: Datasource**

```dart
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../auth/data/auth_remote_datasource.dart' show AuthUnauthorizedException;
import '../../../coldigom/data/constants/coldigom_endpoints.dart';
import '../../domain/entities/contribution_attachment.dart';
import '../../domain/entities/contribution_summary.dart';

class ContributionQuotaExceeded implements Exception {
  ContributionQuotaExceeded(this.resetAt);
  final DateTime resetAt;
}

/// `400`/`413` do contrato — o formulário traduz `error` em mensagem.
class ContributionRejected implements Exception {
  ContributionRejected({required this.status, required this.error, this.file});
  final int status;
  final String error;
  final String? file;
}

class ContributionsRemoteDatasource {
  ContributionsRemoteDatasource(this._dio);

  final Dio _dio;

  Options _auth(String sessionToken, {Duration? sendTimeout}) => Options(
    headers: {'Authorization': 'Bearer $sessionToken'},
    sendTimeout: sendTimeout,
    // 4xx são respostas do contrato, não falhas de transporte.
    validateStatus: (status) => status != null && status < 500,
  );

  void _throwIfUnauthorized(int? status) {
    if (status == 401) throw AuthUnauthorizedException();
  }

  Future<({String id, ContributionStatus status})> submit({
    required String sessionToken,
    required Map<String, dynamic> payload,
    required List<ContributionAttachment> attachments,
    void Function(int sent, int total)? onProgress,
  }) async {
    final form = FormData.fromMap({'payload': jsonEncode(payload)});
    for (final a in attachments) {
      form.files.add(MapEntry('file', MultipartFile.fromBytes(a.bytes, filename: a.name)));
    }
    final response = await _dio.post<Map<String, dynamic>>(
      ColdigomEndpoints.contributions,
      data: form,
      options: _auth(sessionToken, sendTimeout: const Duration(minutes: 5)),
      onSendProgress: onProgress,
    );
    _throwIfUnauthorized(response.statusCode);
    final data = response.data ?? const <String, dynamic>{};
    if (response.statusCode == 429) {
      throw ContributionQuotaExceeded(DateTime.tryParse(data['resetAt'] as String? ?? '') ?? DateTime.now().toUtc().add(const Duration(days: 1)));
    }
    if (response.statusCode != 201) {
      throw ContributionRejected(status: response.statusCode ?? 0, error: data['error'] as String? ?? 'unknown', file: data['file'] as String?);
    }
    return (id: data['id'] as String, status: ContributionStatus.fromWire(data['status'] as String));
  }

  Future<ContributionsPage> fetchMine({required String sessionToken, String? cursor}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ColdigomEndpoints.contributionsMine,
      queryParameters: {if (cursor != null) 'cursor': cursor},
      options: _auth(sessionToken),
    );
    _throwIfUnauthorized(response.statusCode);
    if (response.statusCode != 200 || response.data == null) throw StateError('contributions_mine_${response.statusCode}');
    final data = response.data!;
    return ContributionsPage(
      items: [for (final j in data['data'] as List) ContributionSummary.fromJson((j as Map).cast<String, dynamic>())],
      nextCursor: data['nextCursor'] as String?,
    );
  }

  Future<ContributionSummary> fetchOne({required String sessionToken, required String id}) async {
    final response = await _dio.get<Map<String, dynamic>>(ColdigomEndpoints.contribution(id), options: _auth(sessionToken));
    _throwIfUnauthorized(response.statusCode);
    if (response.statusCode != 200 || response.data == null) throw StateError('contribution_${response.statusCode}');
    return ContributionSummary.fromJson((response.data!['data'] as Map).cast<String, dynamic>());
  }
}
```

- [ ] **Step 5: Providers**

`data/providers/contributions_providers.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/auth_unauthorized_interceptor.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../coldigom/data/constants/coldigom_api_config.dart';
import '../datasources/contributions_remote_datasource.dart';

/// Dio próprio: o `coldigomDioProvider` é público e sem auth; aqui vai Bearer
/// `sess_…` e o interceptor de 401. Sem `RetryInterceptor` — um POST multipart
/// repetido criaria a contribuição duas vezes.
final contributionsDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ColdigomApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );
  dio.interceptors.add(
    AuthUnauthorizedInterceptor(
      onUnauthorized: (token) => ref.read(authStateProvider.notifier).onUnauthorized(token),
    ),
  );
  return dio;
});

final contributionsRemoteDatasourceProvider = Provider<ContributionsRemoteDatasource>(
  (ref) => ContributionsRemoteDatasource(ref.watch(contributionsDioProvider)),
);
```

- [ ] **Step 6: Rodar e passar**

Run: `flutter test test/unit/features/contributions/ && flutter analyze lib/features/contributions lib/features/coldigom && dart format lib/features/contributions lib/features/coldigom/data/constants/coldigom_endpoints.dart test/unit/features/contributions`

- [ ] **Step 7: Commit**

```bash
git add lib/features/coldigom/data/constants/coldigom_endpoints.dart lib/features/contributions/domain/entities/contribution_summary.dart lib/features/contributions/data/datasources lib/features/contributions/data/providers test/unit/features/contributions/contributions_remote_datasource_test.dart
git commit -m "feat(contributions): datasource multipart com Bearer sess_ e entidades de leitura"
```

---

### Task 4: Formulário — notifier, `ContributeScreen`, rota e i18n

**Files:**
- Modify: `pubspec.yaml` (`flutter pub add file_picker`)
- Modify: `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb`
- Modify: `lib/core/routing/route_paths.dart` (`contribute = '/contribuir'`, `myContributions = '/contribuicoes'`)
- Modify: `lib/core/routing/app_router.dart` (rota `/contribuir` no navigator raiz)
- Create: `lib/features/contributions/presentation/providers/contribute_form_provider.dart`
- Create: `lib/features/contributions/presentation/widgets/device_consent_card.dart`
- Create: `lib/features/contributions/presentation/widgets/sign_in_to_contribute.dart`
- Create: `lib/features/contributions/presentation/pages/contribute_screen.dart`
- Create: `lib/features/contributions/presentation/utils/open_contribute.dart`
- Test: `test/unit/features/contributions/contribute_form_provider_test.dart`
- Test: `test/widget/features/contributions/contribute_screen_test.dart`

**Interfaces:**
- Consumes: Task 1 (draft, regras), Task 2 (`deviceSnapshotPortProvider`, `DeviceSnapshot`), Task 3 (datasource, exceções), `authStateProvider`, `connectivityStreamProvider`, `catalogMaterialLookupProvider` (`lib/features/catalog/presentation/providers/catalog_material_lookup_provider.dart`), `coldigomMaterialKindsProvider`, `GoogleSignInButton`.
- Produces:

```dart
// contribute_form_provider.dart
sealed class ContributeSubmitState { Idle | Sending(progress 0..1) | Sent(id) | Failed(ContributeFailure) }
enum ContributeFailure { offline, quota, rejected, unauthorized, unknown }
class ContributeFormState { final ContributionDraft draft; final ContributeSubmitState submit; final DateTime? quotaResetAt; final String? rejectedError; final String? rejectedFile; }
class ContributeFormNotifier extends AutoDisposeFamilyNotifier<ContributeFormState, ContributeFormArgs> {
  void setKind(ContributionKind); void setSubkind(ContributionSubkind?); void setTitle(String); void setBody(String);
  void setMaterial(String? materialId); void setMetadata({MetadataField? field, String? current, String? proposed});
  void setDuplicate({String? praiseId, ContributionSource? source}); void setSuggestedKind(String?);
  void setSameDevice(bool?); void setOtherDeviceNote(String);
  AttachmentError? addAttachment(ContributionAttachment); void removeAttachment(int index);
  bool addLink(String); void removeLink(int index);
  Future<void> submit({required DeviceSnapshot? device, required String appVersion});
}
class ContributeFormArgs { final ContributionTarget? target; final String? from; }   // == / hashCode por valor
final contributeFormProvider = NotifierProvider.autoDispose.family<ContributeFormNotifier, ContributeFormState, ContributeFormArgs>(…);

// open_contribute.dart
void openContribute(BuildContext context, {ContributionTarget? target});   // context.push('/contribuir?source=&praiseId=&materialId=&from=<rota atual>')
ContributionTarget? targetFromQuery(Map<String, String> q);

// RoutePaths
static const String contribute = '/contribuir';
static const String myContributions = '/contribuicoes';
```

- [ ] **Step 1: Dep e strings**

Run: `flutter pub add file_picker`

Acrescentar em `app_pt.arb` (e a tradução em `app_en.arb`):

```json
"contributeTitle": "Ajude a melhorar o PLPCG",
"contributeSignInPrompt": "Entre com Google para contribuir.",
"contributeKindLabel": "O que você quer contar?",
"contributeKindBug": "Bug na app",
"contributeKindWrongInfo": "Informação errada",
"contributeKindContent": "Conteúdo",
"contributeKindImprovement": "Melhoria",
"contributeKindOther": "Outro",
"contributeSubkindLabel": "Sobre o quê?",
"contributeSubkindBugScreen": "Uma tela",
"contributeSubkindBugReader": "Leitor",
"contributeSubkindBugAudio": "Áudio",
"contributeSubkindBugSearch": "Busca",
"contributeSubkindBugOffline": "Offline",
"contributeSubkindBugLogin": "Login",
"contributeSubkindBugPlaylistLive": "Listas / ao vivo",
"contributeSubkindBugOther": "Outro",
"contributeSubkindWrongMetadata": "Título, número, tom…",
"contributeSubkindWrongLyrics": "Letra",
"contributeSubkindWrongMaterial": "Material de outro louvor",
"contributeSubkindWrongKind": "Tipo de material errado",
"contributeSubkindDuplicate": "Louvor duplicado",
"contributeSubkindAddMaterial": "Adicionar material",
"contributeSubkindAddPraise": "Adicionar louvor",
"contributeSubkindReplaceMaterial": "Substituir material",
"contributeSubkindRemove": "Remover",
"contributeSubkindFeature": "Funcionalidade nova",
"contributeSubkindBehavior": "Mudar um comportamento",
"contributeMaterialLabel": "Sobre qual material?",
"contributeMaterialWhole": "O louvor em geral",
"contributeMetadataField": "Campo",
"contributeMetadataCurrent": "Valor atual",
"contributeMetadataProposed": "Valor correto",
"contributeMetadataTitle": "Título",
"contributeMetadataNumber": "Número",
"contributeMetadataAuthor": "Autor",
"contributeMetadataTonality": "Tom",
"contributeMetadataRhythm": "Ritmo",
"contributeMetadataCategory": "Categoria",
"contributeMetadataTags": "Tags",
"contributeDuplicateOf": "É o mesmo que (número ou título)",
"contributeSuggestedKind": "Tipo de material (opcional)",
"contributeTitleField": "Título",
"contributeBodyField": "Descrição",
"contributeBodyHintBug": "O que você fez, o que esperava e o que aconteceu",
"contributeAttachments": "Anexos",
"contributeAddFile": "Anexar arquivo",
"contributeAttachmentTooLarge": "Acima de 32 MB, envie pelo link do Drive.",
"contributeAttachmentTypeNotAllowed": "Tipo de arquivo não aceito.",
"contributeAttachmentTooMany": "No máximo 5 arquivos.",
"contributeLinks": "Links (YouTube / Drive)",
"contributeAddLink": "Adicionar link",
"contributeLinkNotAllowed": "Só links do YouTube ou do Google Drive.",
"contributeDeviceTitle": "Isto será enviado",
"contributeSameDeviceQuestion": "O bug aconteceu neste dispositivo?",
"contributeSameDeviceYes": "Sim",
"contributeSameDeviceNo": "Não",
"contributeOtherDevice": "Em qual dispositivo?",
"contributeSend": "Enviar",
"contributeSent": "Recebido, obrigado!",
"contributeErrorOffline": "Sem ligação. Tente de novo.",
"contributeErrorQuota": "Limite diário atingido; volta às {time}.",
"@contributeErrorQuota": {"placeholders": {"time": {"type": "String"}}},
"contributeErrorRejected": "O envio foi recusado: {error}",
"@contributeErrorRejected": {"placeholders": {"error": {"type": "String"}}},
"contributeErrorUnknown": "Não foi possível enviar. Tente de novo.",
"contributeReportTooltip": "Reportar",
"myContributionsTitle": "Minhas contribuições",
"myContributionsEmpty": "Você ainda não enviou nenhuma contribuição.",
"contributionStatusRecebida": "Enviada · verificando anexos",
"contributionStatusPendente": "Aguardando análise",
"contributionStatusEmAnalise": "Em análise",
"contributionStatusAceita": "Aceita",
"contributionStatusRecusada": "Recusada",
"contributionStatusAplicada": "Aplicada",
"contributionStatusBloqueada": "Não pôde ser analisada: anexo recusado pela verificação de segurança",
"contributionDecisionNote": "Nota da equipe",
"contributionFilesTitle": "Anexos",
"contributionFileScanPending": "verificando",
"contributionFileScanClean": "ok",
"contributionFileScanBlocked": "recusado"
```

- [ ] **Step 2: Teste do notifier**

`test/unit/features/contributions/contribute_form_provider_test.dart`:

```dart
import 'dart:typed_data';

import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/contributions/data/datasources/contributions_remote_datasource.dart';
import 'package:coldigui/features/contributions/data/providers/contributions_providers.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_attachment.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_kind.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_summary.dart';
import 'package:coldigui/features/contributions/domain/validators/attachment_rules.dart';
import 'package:coldigui/features/contributions/presentation/providers/contribute_form_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fakes/fake_auth_notifier.dart';

class _FakeDs extends ContributionsRemoteDatasource {
  _FakeDs(this.onSubmit) : super(Dio());
  final Future<({String id, ContributionStatus status})> Function(Map<String, dynamic> payload) onSubmit;
  Map<String, dynamic>? lastPayload;
  @override
  Future<({String id, ContributionStatus status})> submit({required String sessionToken, required Map<String, dynamic> payload, required List<ContributionAttachment> attachments, void Function(int, int)? onProgress}) {
    lastPayload = payload;
    return onSubmit(payload);
  }
}

ProviderContainer _container(_FakeDs ds) {
  final c = ProviderContainer(overrides: [
    contributionsRemoteDatasourceProvider.overrideWithValue(ds),
    authStateProvider.overrideWith(() => FakeAuthNotifier(const AuthUser(googleSub: 'u', sessionToken: 'sess_t'))),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  const args = ContributeFormArgs();

  test('kind muda limpa subkind; bug exige sameDevice para ficar válido', () {
    final c = _container(_FakeDs((_) async => (id: 'x', status: ContributionStatus.pendente)));
    final n = c.read(contributeFormProvider(args).notifier);
    n.setKind(ContributionKind.improvement);
    n.setSubkind(ContributionSubkind.feature);
    n.setKind(ContributionKind.bug);
    expect(c.read(contributeFormProvider(args)).draft.subkind, isNull);
    n.setSubkind(ContributionSubkind.bugReader);
    n.setTitle('t');
    n.setBody('b');
    expect(c.read(contributeFormProvider(args)).draft.isValid, isFalse);
    n.setSameDevice(true);
    expect(c.read(contributeFormProvider(args)).draft.isValid, isTrue);
  });

  test('addAttachment aplica as regras e addLink a allowlist', () {
    final c = _container(_FakeDs((_) async => (id: 'x', status: ContributionStatus.pendente)));
    final n = c.read(contributeFormProvider(args).notifier);
    n.setKind(ContributionKind.content);
    expect(n.addAttachment(ContributionAttachment(name: 'a.exe', size: 1, bytes: Uint8List(1))), AttachmentError.typeNotAllowed);
    expect(n.addAttachment(ContributionAttachment(name: 'a.pdf', size: 1, bytes: Uint8List(1))), isNull);
    expect(c.read(contributeFormProvider(args)).draft.attachments.length, 1);
    expect(n.addLink('http://x'), isFalse);
    expect(n.addLink('https://youtu.be/a'), isTrue);
    expect(c.read(contributeFormProvider(args)).draft.links, ['https://youtu.be/a']);
  });

  test('submit feliz → Sent; payload leva appVersion e device', () async {
    final ds = _FakeDs((_) async => (id: 'c9', status: ContributionStatus.recebida));
    final c = _container(ds);
    final n = c.read(contributeFormProvider(args).notifier);
    n.setKind(ContributionKind.other);
    n.setTitle('t');
    n.setBody('b');
    await n.submit(device: null, appVersion: '1.2.3+4');
    expect(c.read(contributeFormProvider(args)).submit, isA<ContributeSent>().having((s) => s.id, 'id', 'c9'));
    expect(ds.lastPayload!['appVersion'], '1.2.3+4');
  });

  test('429 → Failed(quota) com resetAt; 413 → Failed(rejected) com file; DioException de rede → offline', () async {
    final reset = DateTime.utc(2026, 9, 18);
    final c1 = _container(_FakeDs((_) async => throw ContributionQuotaExceeded(reset)));
    final n1 = c1.read(contributeFormProvider(args).notifier);
    n1.setKind(ContributionKind.other); n1.setTitle('t'); n1.setBody('b');
    await n1.submit(device: null, appVersion: '1');
    final s1 = c1.read(contributeFormProvider(args));
    expect(s1.submit, isA<ContributeFailed>().having((f) => f.failure, 'failure', ContributeFailure.quota));
    expect(s1.quotaResetAt, reset);
    expect(s1.draft.title, 't'); // formulário preservado

    final c2 = _container(_FakeDs((_) async => throw ContributionRejected(status: 413, error: 'file_too_large', file: 'g.pdf')));
    final n2 = c2.read(contributeFormProvider(args).notifier);
    n2.setKind(ContributionKind.other); n2.setTitle('t'); n2.setBody('b');
    await n2.submit(device: null, appVersion: '1');
    expect(c2.read(contributeFormProvider(args)).rejectedFile, 'g.pdf');

    final c3 = _container(_FakeDs((_) async => throw DioException.connectionError(requestOptions: RequestOptions(), reason: 'x')));
    final n3 = c3.read(contributeFormProvider(args).notifier);
    n3.setKind(ContributionKind.other); n3.setTitle('t'); n3.setBody('b');
    await n3.submit(device: null, appVersion: '1');
    expect(c3.read(contributeFormProvider(args)).submit, isA<ContributeFailed>().having((f) => f.failure, 'failure', ContributeFailure.offline));
  });
}
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `flutter test test/unit/features/contributions/contribute_form_provider_test.dart`

- [ ] **Step 4: Notifier**

`presentation/providers/contribute_form_provider.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/auth_remote_datasource.dart' show AuthUnauthorizedException;
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../data/datasources/contributions_remote_datasource.dart';
import '../../data/providers/contributions_providers.dart';
import '../../domain/entities/contribution_attachment.dart';
import '../../domain/entities/contribution_draft.dart';
import '../../domain/entities/contribution_kind.dart';
import '../../domain/entities/contribution_target.dart';
import '../../domain/entities/device_snapshot.dart';
import '../../domain/validators/attachment_rules.dart';

sealed class ContributeSubmitState { const ContributeSubmitState(); }
class ContributeIdle extends ContributeSubmitState { const ContributeIdle(); }
class ContributeSending extends ContributeSubmitState { const ContributeSending(this.progress); final double progress; }
class ContributeSent extends ContributeSubmitState { const ContributeSent(this.id); final String id; }
class ContributeFailed extends ContributeSubmitState { const ContributeFailed(this.failure); final ContributeFailure failure; }

enum ContributeFailure { offline, quota, rejected, unauthorized, unknown }

@immutable
class ContributeFormArgs {
  const ContributeFormArgs({this.target, this.from});
  final ContributionTarget? target;
  final String? from;
  @override
  bool operator ==(Object other) => other is ContributeFormArgs && other.target?.source == target?.source && other.target?.praiseId == target?.praiseId && other.target?.materialId == target?.materialId && other.from == from;
  @override
  int get hashCode => Object.hash(target?.source, target?.praiseId, target?.materialId, from);
}

@immutable
class ContributeFormState {
  const ContributeFormState({required this.draft, this.submit = const ContributeIdle(), this.quotaResetAt, this.rejectedError, this.rejectedFile});
  final ContributionDraft draft;
  final ContributeSubmitState submit;
  final DateTime? quotaResetAt;
  final String? rejectedError;
  final String? rejectedFile;

  ContributeFormState copyWith({ContributionDraft? draft, ContributeSubmitState? submit, DateTime? quotaResetAt, String? rejectedError, String? rejectedFile}) =>
      ContributeFormState(draft: draft ?? this.draft, submit: submit ?? this.submit, quotaResetAt: quotaResetAt ?? this.quotaResetAt, rejectedError: rejectedError ?? this.rejectedError, rejectedFile: rejectedFile ?? this.rejectedFile);
}

/// Um notifier por (alvo, rota de origem): abrir «Reportar» em dois louvores
/// não mistura rascunhos. Com alvo, o kind padrão é «Informação errada» (P2).
class ContributeFormNotifier extends AutoDisposeFamilyNotifier<ContributeFormState, ContributeFormArgs> {
  @override
  ContributeFormState build(ContributeFormArgs arg) => ContributeFormState(
    draft: ContributionDraft(
      kind: arg.target != null ? ContributionKind.wrongInfo : ContributionKind.other,
      target: arg.target,
      appRoute: arg.from,
    ),
  );

  void _draft(ContributionDraft d) => state = state.copyWith(draft: d, submit: const ContributeIdle());

  void setKind(ContributionKind kind) {
    // Trocar de kind limpa o subkind e os anexos que o novo kind não aceita (bug só imagem).
    final keep = state.draft.attachments.where((a) => validateAttachment(name: a.name, size: a.size, kind: kind, currentCount: 0) == null).toList();
    _draft(state.draft.copyWith(kind: kind, subkind: null, attachments: keep, sameDevice: null, otherDeviceNote: null));
  }

  void setSubkind(ContributionSubkind? s) => _draft(state.draft.copyWith(subkind: s));
  void setTitle(String v) => _draft(state.draft.copyWith(title: v));
  void setBody(String v) => _draft(state.draft.copyWith(body: v));
  void setMaterial(String? materialId) => _draft(state.draft.copyWith(target: state.draft.target?.copyWith(materialId: materialId)));
  void setMetadata({MetadataField? field, String? current, String? proposed}) => _draft(state.draft.copyWith(
    metadataField: field ?? state.draft.metadataField,
    metadataCurrent: current ?? state.draft.metadataCurrent,
    metadataProposed: proposed ?? state.draft.metadataProposed,
  ));
  void setDuplicate({String? praiseId, ContributionSource? source}) => _draft(state.draft.copyWith(duplicateOtherPraiseId: praiseId, duplicateOtherSource: source));
  void setSuggestedKind(String? kindId) => _draft(state.draft.copyWith(suggestedKindId: kindId));
  void setSameDevice(bool? v) => _draft(state.draft.copyWith(sameDevice: v));
  void setOtherDeviceNote(String v) => _draft(state.draft.copyWith(otherDeviceNote: v));

  AttachmentError? addAttachment(ContributionAttachment a) {
    final err = validateAttachment(name: a.name, size: a.size, kind: state.draft.kind, currentCount: state.draft.attachments.length);
    if (err != null) return err;
    _draft(state.draft.copyWith(attachments: [...state.draft.attachments, a]));
    return null;
  }

  void removeAttachment(int i) => _draft(state.draft.copyWith(attachments: [...state.draft.attachments]..removeAt(i)));

  bool addLink(String url) {
    final v = url.trim();
    if (!isAllowedLink(v) || state.draft.links.length >= kMaxLinks) return false;
    _draft(state.draft.copyWith(links: [...state.draft.links, v]));
    return true;
  }

  void removeLink(int i) => _draft(state.draft.copyWith(links: [...state.draft.links]..removeAt(i)));

  Future<void> submit({required DeviceSnapshot? device, required String appVersion}) async {
    final token = ref.read(authStateProvider).asData?.value?.sessionToken;
    if (token == null) { state = state.copyWith(submit: const ContributeFailed(ContributeFailure.unauthorized)); return; }
    if (!state.draft.isValid) return;
    state = state.copyWith(submit: const ContributeSending(0));
    final payload = state.draft.toPayload(device: device?.toJson(), appVersion: appVersion);
    try {
      final out = await ref.read(contributionsRemoteDatasourceProvider).submit(
        sessionToken: token,
        payload: payload,
        attachments: state.draft.attachments,
        onProgress: (sent, total) { if (total > 0) state = state.copyWith(submit: ContributeSending(sent / total)); },
      );
      state = state.copyWith(submit: ContributeSent(out.id));
    } on ContributionQuotaExceeded catch (e) {
      state = state.copyWith(submit: const ContributeFailed(ContributeFailure.quota), quotaResetAt: e.resetAt);
    } on ContributionRejected catch (e) {
      state = state.copyWith(submit: const ContributeFailed(ContributeFailure.rejected), rejectedError: e.error, rejectedFile: e.file);
    } on AuthUnauthorizedException {
      state = state.copyWith(submit: const ContributeFailed(ContributeFailure.unauthorized));
    } on DioException catch (e) {
      final offline = e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.sendTimeout || (e.response?.statusCode == 503);
      state = state.copyWith(submit: ContributeFailed(offline ? ContributeFailure.offline : ContributeFailure.unknown));
    } on Object catch (e) {
      debugPrint('[contributions] submit falhou: $e');
      state = state.copyWith(submit: const ContributeFailed(ContributeFailure.unknown));
    }
  }
}

final contributeFormProvider = NotifierProvider.autoDispose.family<ContributeFormNotifier, ContributeFormState, ContributeFormArgs>(ContributeFormNotifier.new);
```

Riverpod 3: se `AutoDisposeFamilyNotifier` não existir com esse nome, usar `Notifier<ContributeFormState>` com `NotifierProvider.autoDispose.family` e `build(ContributeFormArgs arg)` conforme a API da versão em `pubspec.lock` (`flutter_riverpod ^3.3.2` — a família de `Notifier` recebe o argumento em `build`). Ajustar o import de `flutter_riverpod/misc.dart` se o analyzer pedir.

- [ ] **Step 5: Rodar o teste do notifier**

Run: `flutter test test/unit/features/contributions/contribute_form_provider_test.dart`
Expected: PASS.

- [ ] **Step 6: Teste de widget**

`test/widget/features/contributions/contribute_screen_test.dart`:

```dart
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/contributions/data/device/device_snapshot_provider.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_kind.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_target.dart';
import 'package:coldigui/features/contributions/presentation/pages/contribute_screen.dart';
import 'package:coldigui/features/contributions/presentation/widgets/device_consent_card.dart';
import 'package:coldigui/core/network/connectivity_stream_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fakes/fake_auth_notifier.dart';
import '../../../support/fakes/fake_device_snapshot_port.dart';
import '../../../support/pump_app.dart';

List<Override> _logged() => [
  authStateProvider.overrideWith(() => FakeAuthNotifier(const AuthUser(googleSub: 'u', sessionToken: 'sess_t'))),
  deviceSnapshotPortProvider.overrideWithValue(FakeDeviceSnapshotPort()),
  connectivityStreamProvider.overrideWith((ref) => Stream.value(true)),
];

void main() {
  testWidgets('deslogado vê o convite para entrar', (tester) async {
    await pumpApp(tester, const ContributeScreen(), overrides: [
      authStateProvider.overrideWith(() => FakeAuthNotifier(null)),
      deviceSnapshotPortProvider.overrideWithValue(FakeDeviceSnapshotPort()),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Entre com Google para contribuir.'), findsOneWidget);
  });

  testWidgets('bug: Enviar só habilita depois de responder sobre o dispositivo', (tester) async {
    await pumpApp(tester, const ContributeScreen(), overrides: _logged());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bug na app'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leitor'));
    await tester.enterText(find.byKey(const Key('contribute-title')), 'Trava');
    await tester.enterText(find.byKey(const Key('contribute-body')), 'Na página 3');
    await tester.pumpAndSettle();
    expect(find.byType(DeviceConsentCard), findsOneWidget);
    expect(find.text('Isto será enviado'), findsOneWidget);
    final sendBefore = tester.widget<FilledButton>(find.byKey(const Key('contribute-send')));
    expect(sendBefore.onPressed, isNull);
    await tester.tap(find.text('Sim'));
    await tester.pumpAndSettle();
    final sendAfter = tester.widget<FilledButton>(find.byKey(const Key('contribute-send')));
    expect(sendAfter.onPressed, isNotNull);
  });

  testWidgets('com alvo, «Informação errada» vem selecionada e o seletor de material aparece', (tester) async {
    await pumpApp(tester, const ContributeScreen(target: ContributionTarget(source: ContributionSource.coldigom, praiseId: 'p1')), overrides: _logged());
    await tester.pumpAndSettle();
    final chip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Informação errada'));
    expect(chip.selected, isTrue);
    expect(find.text('Sobre qual material?'), findsOneWidget);
  });

  testWidgets('kind bug não mostra o botão de anexar PDF (só imagens) e o texto do limite aparece', (tester) async {
    await pumpApp(tester, const ContributeScreen(), overrides: _logged());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conteúdo'));
    await tester.pumpAndSettle();
    expect(find.text('Anexar arquivo'), findsOneWidget);
    expect(find.textContaining('32 MB'), findsOneWidget);
  });
}
```

Nota: o `FilePicker` não roda em teste de widget; a tela injeta a função de escolher arquivo por parâmetro (`pickFiles`) com default que chama o `FilePicker.platform` — o teste não a aciona.

- [ ] **Step 7: Tela, cartão de dispositivo, gate de login, rota**

`presentation/widgets/sign_in_to_contribute.dart` — reproduz o `_signedOut` da tela de favoritos: texto `l10n.contributeSignInPrompt` + `GoogleSignInButton()`.

`presentation/widgets/device_consent_card.dart`:

```dart
class DeviceConsentCard extends StatelessWidget {
  const DeviceConsentCard({required this.snapshot, required this.sameDevice, required this.otherDeviceNote, required this.onSameDevice, required this.onOtherDeviceNote, super.key});
  final DeviceSnapshot? snapshot;          // null enquanto coleta
  final bool? sameDevice;
  final String otherDeviceNote;
  final ValueChanged<bool?> onSameDevice;
  final ValueChanged<String> onOtherDeviceNote;
  // build: Card com título l10n.contributeDeviceTitle, uma linha por `snapshot.humanLines()` (rótulo em label, valor em body),
  // depois l10n.contributeSameDeviceQuestion + SegmentedButton<bool>(Sim/Não) e, se sameDevice == false,
  // TextField(key: 'contribute-other-device', label: l10n.contributeOtherDevice).
}
```

`presentation/pages/contribute_screen.dart` — `ConsumerStatefulWidget` com `target`, `from` e `pickFiles` (default: `file_picker`):

- Deslogado (`ref.watch(authStateProvider).asData?.value == null`) → `SignInToContribute`.
- Logado: `ListView` com padding 16, `maxWidth` 640 centralizado, seções na ordem do spec §6.2:
  1. `Wrap` de `ChoiceChip` para os 5 kinds (`Key('kind-<wireName>')`, rótulo por l10n), `selected` = `draft.kind`; `onSelected` → `setKind`.
  2. Se `subkindsOf(kind)` não vazio: `Wrap` de `ChoiceChip` dos subkinds.
  3. Se `target?.praiseId != null`: `DropdownButtonFormField<String?>` «Sobre qual material?» com `null` → «O louvor em geral» e um item por material do grupo. Grupo resolvido por `ref.watch(catalogMaterialLookupProvider)`: PDFs de `plpcgLouvoresByPdfId`/`coldigomLouvoresByPdfId` cujo `groupId == praiseId` (rótulo `categoria`), `audioTracksById` com `groupId == praiseId` (rótulo `categoria`/nome), `chordsById` idem. Valor = `pdfId`/`audioId`/`chordId`.
  4. `subkind == wrongMetadata`: `DropdownButtonFormField<MetadataField>` (rótulos `contributeMetadata*`), `TextField` «Valor atual» (pré-preenchido de `lookup.praiseMeta(praiseId)` — `name/tonality/author/rhythm` — quando o campo muda e o usuário ainda não editou) e «Valor correto» (`Key('contribute-proposed')`).
  5. `subkind == duplicate`: `TextField` «É o mesmo que» (`Key('contribute-duplicate')`) que filtra `homeLocalSearchProvider`-like? **Não** — para não acoplar com a Home, o campo é texto livre com um `Autocomplete<LouvorGroup>` sobre `ref.read(catalogSourceProvider)`-independente: usa `lookup.plpcgLouvoresByPdfId.values` + `lookup.coldigomLouvoresByPdfId.values` filtrados por `numero`/`nome` contendo o texto (máx. 8 sugestões); ao escolher, `setDuplicate(praiseId: louvor.groupId, source: louvor.source == LouvorDataSource.coldigom ? coldigom : plpcg)`.
  6. `kind == content`: `DropdownButtonFormField<String?>` de kinds (`coldigomMaterialKindsProvider`), opcional.
  7. `TextField` título (`Key('contribute-title')`, `maxLength: kMaxTitleLength`) e descrição (`Key('contribute-body')`, `maxLength: kMaxBodyLength`, `minLines: 4`, hint `contributeBodyHintBug` se bug).
  8. Anexos: `OutlinedButton.icon(Icons.attach_file, contributeAddFile)` → `pickFiles(allowedExtensions: kind == bug ? kImageExtensions : kAllowedExtensions)` → para cada `PlatformFile` com `bytes != null`, `addAttachment(ContributionAttachment(name: f.name, size: f.size, bytes: f.bytes!))`; erro → `SnackBar` com a mensagem correspondente (`tooLarge` → `contributeAttachmentTooLarge`). Lista dos anexos com `Chip(onDeleted)`. Texto auxiliar abaixo do botão: `contributeAttachmentTooLarge` (é a explicação do limite; o teste procura «32 MB»).
  9. Links: `TextField` + `IconButton(Icons.add)`; `addLink` false → `SnackBar(contributeLinkNotAllowed)`; lista com `Chip(onDeleted)`.
  10. `kind == bug`: `DeviceConsentCard` com o snapshot de um `FutureProvider.autoDispose` local que chama `deviceSnapshotPortProvider.collect(screen: MediaQuery.sizeOf, pixelRatio, locale: Localizations.localeOf(context).toLanguageTag(), online: ref.watch(connectivityStreamProvider).value ?? true)`. `onSameDevice` → `setSameDevice`.
  11. `FilledButton(key: Key('contribute-send'))`: `onPressed` = `draft.isValid && submit is! ContributeSending ? _send : null`. `_send` → `notifier.submit(device: snapshot, appVersion: snapshot?.versionLabel ?? '')`. Durante `ContributeSending` mostra `LinearProgressIndicator(value: progress)`.
- `ref.listen(contributeFormProvider(args), …)`: `ContributeSent` → `SnackBar(contributeSent)` + `context.pop()`; `ContributeFailed` → `SnackBar` conforme `failure` (`offline` → `contributeErrorOffline`; `quota` → `contributeErrorQuota(HH:mm local de quotaResetAt)`; `rejected` → `contributeErrorRejected(rejectedError + (file != null ? ' ($file)' : ''))`; `unknown/unauthorized` → `contributeErrorUnknown`). O formulário **não** é limpo em falha.

`presentation/utils/open_contribute.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/route_paths.dart';
import '../../domain/entities/contribution_kind.dart';
import '../../domain/entities/contribution_target.dart';

/// Abre o formulário com o alvo e a rota de origem (`from`), que vira
/// `app_route` no payload — é o que mais ajuda a reproduzir um bug.
void openContribute(BuildContext context, {ContributionTarget? target}) {
  final from = GoRouterState.of(context).uri.toString();
  final uri = Uri(path: RoutePaths.contribute, queryParameters: {
    if (target != null) 'source': target.source.wireName,
    if (target?.praiseId != null) 'praiseId': target!.praiseId,
    if (target?.materialId != null) 'materialId': target!.materialId,
    'from': from,
  });
  context.push(uri.toString());
}

ContributionTarget? targetFromQuery(Map<String, String> q) {
  final source = ContributionSource.values.where((s) => s.wireName == q['source']).firstOrNull;
  if (source == null) return null;
  return ContributionTarget(source: source, praiseId: q['praiseId'], materialId: q['materialId']);
}
```

`route_paths.dart`: `static const String contribute = '/contribuir';` e `static const String myContributions = '/contribuicoes';`.

`app_router.dart` — rota **fora** do shell, irmã do `StatefulShellRoute` (abre por cima de qualquer aba):

```dart
    routes: [
      GoRoute(
        path: RoutePaths.contribute,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final q = safeQueryParameters(state.uri);
          return ContributeScreen(target: targetFromQuery(q), from: q['from']);
        },
      ),
      StatefulShellRoute.indexedStack(…),
    ],
```

`ContributeScreen` tem o próprio `Scaffold` com `AppBar(title: l10n.contributeTitle)` (é raiz; o teste monta dentro de `pumpApp`, que também dá um `Scaffold` — `Scaffold` aninhado é aceitável aqui).

- [ ] **Step 8: Rodar tudo da feature**

Run: `flutter test test/unit/features/contributions test/widget/features/contributions && flutter analyze lib/features/contributions lib/core/routing && dart format lib/features/contributions lib/core/routing test/widget/features/contributions test/unit/features/contributions`
Expected: PASS. Se o `gen-l10n` não rodou, `flutter gen-l10n` antes.

- [ ] **Step 9: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/l10n/app_pt.arb lib/l10n/app_en.arb lib/core/routing/route_paths.dart lib/core/routing/app_router.dart lib/features/contributions/presentation test/unit/features/contributions/contribute_form_provider_test.dart test/widget/features/contributions/contribute_screen_test.dart
git commit -m "feat(contributions): formulário «Ajude a melhorar o PLPCG» com anexos, links e consentimento do dispositivo"
```

---

### Task 5: Pontos de entrada — Perfil, sheet do louvor, leitor e player

**Files:**
- Modify: `lib/features/app_shell/presentation/pages/profile_screen.dart`
- Modify: `lib/features/catalog/presentation/widgets/material_sheet.dart` (`_SheetHeader`)
- Modify: `lib/features/pdf_reader/presentation/pages/pdf_reader_screen.dart` (barra: `actions`)
- Modify: `lib/features/audio_player/presentation/pages/audio_player_screen.dart` (`AppBar.actions`)
- Test: `test/widget/features/contributions/entry_points_test.dart`

**Interfaces:**
- Consumes: `openContribute`, `targetFromQuery` (Task 4), `ContributionTarget`, `catalogMaterialLookupProvider`, `LouvorGroup.isColdigom`, `LouvorDataSource`.

- [ ] **Step 1: Teste**

`test/widget/features/contributions/entry_points_test.dart`:

```dart
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/app_shell/presentation/pages/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fakes/fake_auth_notifier.dart';
import '../../../support/pump_app.dart';

void main() {
  testWidgets('Perfil logado mostra «Ajude a melhorar» e «Minhas contribuições»', (tester) async {
    await pumpApp(tester, const ProfileScreen(), overrides: [
      authStateProvider.overrideWith(() => FakeAuthNotifier(const AuthUser(googleSub: 'u', sessionToken: 'sess_t'))),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Ajude a melhorar o PLPCG'), findsOneWidget);
    expect(find.text('Minhas contribuições'), findsOneWidget);
  });

  testWidgets('Perfil deslogado mostra «Ajude a melhorar» (abre o convite) mas não «Minhas contribuições»', (tester) async {
    await pumpApp(tester, const ProfileScreen(), overrides: [authStateProvider.overrideWith(() => FakeAuthNotifier(null))]);
    await tester.pumpAndSettle();
    expect(find.text('Ajude a melhorar o PLPCG'), findsOneWidget);
    expect(find.text('Minhas contribuições'), findsNothing);
  });
}
```

Se o `ProfileScreen` exigir mais overrides para montar (conferir `test/widget/features/app_shell/` para o padrão existente), copiar os overrides de lá.

Para o `MaterialSheet`, acrescentar ao teste existente mais próximo (`test/widget/features/catalog/material_sheet_*_test.dart` — localizar com `ls test/widget/features/catalog | grep sheet`) um caso: «header tem o botão Reportar com tooltip» (`find.byTooltip('Reportar')`, `findsOneWidget`).

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/widget/features/contributions/entry_points_test.dart`

- [ ] **Step 3: Perfil**

Em `profile_screen.dart`, depois do tile «Biblioteca» e antes do bloco `if (auth.asData?.value != null)` dos favoritos:

```dart
            const SizedBox(height: 10),
            _ProfilePageTile(
              icon: Icons.volunteer_activism_outlined,
              title: l10n.contributeTitle,
              onTap: () => context.push(RoutePaths.contribute),
            ),
```

e **dentro** do bloco logado, após o tile de favoritos:

```dart
              const SizedBox(height: 10),
              _ProfilePageTile(
                icon: Icons.inbox_outlined,
                title: l10n.myContributionsTitle,
                onTap: () => goToShellDestination(context, RoutePaths.myContributions),
              ),
```

Import `package:go_router/go_router.dart` se ainda não houver. (`/contribuir` é rota raiz → `push`; `/contribuicoes` é da branch Perfil → `goToShellDestination`, Task 6 registra a rota.)

- [ ] **Step 4: Sheet do louvor**

Em `material_sheet.dart`, `_SheetHeader` vira `ConsumerWidget`-independente (não precisa de ref): acrescentar, antes do `IconButton` de fechar:

```dart
        IconButton(
          tooltip: l10n.contributeReportTooltip,
          onPressed: () {
            Navigator.of(context).pop();
            openContribute(
              context,
              target: ContributionTarget(
                source: group.isColdigom ? ContributionSource.coldigom : ContributionSource.plpcg,
                praiseId: group.groupId,
              ),
            );
          },
          icon: const Icon(Icons.flag_outlined, color: AppColors.title),
          style: IconButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(44, 44), tapTargetSize: MaterialTapTargetSize.shrinkWrap, visualDensity: VisualDensity.compact),
        ),
```

Atenção: o `context` do sheet morre no `pop()`; capturar `final router = GoRouter.of(context)` e a `uri` **antes** do `pop`, ou chamar `openContribute` primeiro e `pop` depois — escolher `openContribute` primeiro (o push vai para o navigator raiz e o sheet fecha em seguida com `Navigator.of(context).pop()`); testar manualmente que a tela abre e o sheet some.

- [ ] **Step 5: Leitor e player**

`pdf_reader_screen.dart`, na `AppBar` da barra (`actions`), antes do botão de share:

```dart
                IconButton(
                  tooltip: l10n.contributeReportTooltip,
                  icon: const Icon(Icons.flag_outlined),
                  onPressed: () {
                    final lookup = ref.read(catalogMaterialLookupProvider);
                    final louvor = lookup.plpcgLouvoresByPdfId[pdfId] ?? lookup.coldigomLouvoresByPdfId[pdfId];
                    openContribute(context, target: louvor == null ? null : ContributionTarget(
                      source: louvor.source == LouvorDataSource.coldigom ? ContributionSource.coldigom : ContributionSource.plpcg,
                      praiseId: louvor.groupId,
                      materialId: pdfId,
                    ));
                  },
                ),
```

(O widget da barra recebe `pdfId` — se a barra for um widget separado sem `ref`, passar um callback `onReport` construído no `_PdfReaderScreenState`, onde `ref` e `pdfId` existem; seguir o padrão do `onShare`.)

`audio_player_screen.dart`, em `AppBar.actions` (criar `actions` se não existir):

```dart
          if (track != null)
            IconButton(
              tooltip: l10n.contributeReportTooltip,
              icon: const Icon(Icons.flag_outlined),
              onPressed: () => openContribute(context, target: ContributionTarget(
                source: track.source == LouvorDataSource.coldigom ? ContributionSource.coldigom : ContributionSource.plpcg,
                praiseId: track.groupId,
                materialId: track.audioId,
              )),
            ),
```

- [ ] **Step 6: Rodar**

Run: `flutter test test/widget/features/contributions test/widget/features/catalog test/widget/features/app_shell test/widget/features/pdf_reader test/widget/features/audio_player && flutter analyze lib/features && dart format lib/features/app_shell/presentation/pages/profile_screen.dart lib/features/catalog/presentation/widgets/material_sheet.dart lib/features/pdf_reader/presentation/pages/pdf_reader_screen.dart lib/features/audio_player/presentation/pages/audio_player_screen.dart test/widget/features/contributions`
Expected: PASS (inclusive as suítes existentes das telas tocadas).

- [ ] **Step 7: Commit**

```bash
git add lib/features/app_shell/presentation/pages/profile_screen.dart lib/features/catalog/presentation/widgets/material_sheet.dart lib/features/pdf_reader/presentation/pages/pdf_reader_screen.dart lib/features/audio_player/presentation/pages/audio_player_screen.dart test/widget/features/contributions/entry_points_test.dart test/widget/features/catalog
git commit -m "feat(contributions): entradas — Perfil, «Reportar» no sheet do louvor, no leitor e no player"
```

---

### Task 6: «Minhas contribuições» — provider, lista, detalhe e rota

**Files:**
- Create: `lib/features/contributions/presentation/providers/my_contributions_provider.dart`
- Create: `lib/features/contributions/presentation/widgets/contribution_status_chip.dart`
- Create: `lib/features/contributions/presentation/pages/my_contributions_screen.dart`
- Create: `lib/features/contributions/presentation/pages/contribution_detail_screen.dart`
- Modify: `lib/core/routing/app_router.dart` (branch Perfil: `/contribuicoes` e `/contribuicoes/:id`)
- Test: `test/unit/features/contributions/my_contributions_provider_test.dart`
- Test: `test/widget/features/contributions/my_contributions_screen_test.dart`

**Interfaces:**
- Consumes: Task 3 (`fetchMine`, `fetchOne`, `ContributionSummary`, `ContributionStatus`), `authStateProvider`.
- Produces:

```dart
class MyContributionsState { final List<ContributionSummary> items; final String? nextCursor; final bool loadingMore; final Object? error; }
class MyContributionsNotifier extends AsyncNotifier<MyContributionsState> { Future<void> refresh(); Future<void> loadMore(); }
final myContributionsProvider = AsyncNotifierProvider<MyContributionsNotifier, MyContributionsState>(…);
final contributionDetailProvider = FutureProvider.autoDispose.family<ContributionSummary, String>(…);
String contributionStatusLabel(AppLocalizations l10n, ContributionStatus s);
```

- [ ] **Step 1: Teste do provider**

`test/unit/features/contributions/my_contributions_provider_test.dart`:

```dart
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/contributions/data/datasources/contributions_remote_datasource.dart';
import 'package:coldigui/features/contributions/data/providers/contributions_providers.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_kind.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_summary.dart';
import 'package:coldigui/features/contributions/presentation/providers/my_contributions_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fakes/fake_auth_notifier.dart';

ContributionSummary _c(String id) => ContributionSummary(
  id: id, kind: ContributionKind.other, subkind: null, title: id, body: '', status: ContributionStatus.pendente,
  decisionNote: null, createdAt: DateTime.utc(2026, 9, 17), updatedAt: DateTime.utc(2026, 9, 17), links: const [], files: const [], fields: const {},
);

class _PagedDs extends ContributionsRemoteDatasource {
  _PagedDs() : super(Dio());
  final cursors = <String?>[];
  @override
  Future<ContributionsPage> fetchMine({required String sessionToken, String? cursor}) async {
    cursors.add(cursor);
    return cursor == null
        ? ContributionsPage(items: [_c('a'), _c('b')], nextCursor: 'c2')
        : ContributionsPage(items: [_c('c')], nextCursor: null);
  }
}

void main() {
  test('carrega a primeira página e loadMore anexa com o cursor', () async {
    final ds = _PagedDs();
    final c = ProviderContainer(overrides: [
      contributionsRemoteDatasourceProvider.overrideWithValue(ds),
      authStateProvider.overrideWith(() => FakeAuthNotifier(const AuthUser(googleSub: 'u', sessionToken: 'sess_t'))),
    ]);
    addTearDown(c.dispose);
    final first = await c.read(myContributionsProvider.future);
    expect(first.items.map((e) => e.id), ['a', 'b']);
    expect(first.nextCursor, 'c2');
    await c.read(myContributionsProvider.notifier).loadMore();
    final after = c.read(myContributionsProvider).value!;
    expect(after.items.map((e) => e.id), ['a', 'b', 'c']);
    expect(after.nextCursor, isNull);
    expect(ds.cursors, [null, 'c2']);
    await c.read(myContributionsProvider.notifier).loadMore(); // sem cursor: no-op
    expect(ds.cursors.length, 2);
  });

  test('deslogado devolve lista vazia sem chamar a rede', () async {
    final ds = _PagedDs();
    final c = ProviderContainer(overrides: [
      contributionsRemoteDatasourceProvider.overrideWithValue(ds),
      authStateProvider.overrideWith(() => FakeAuthNotifier(null)),
    ]);
    addTearDown(c.dispose);
    final s = await c.read(myContributionsProvider.future);
    expect(s.items, isEmpty);
    expect(ds.cursors, isEmpty);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/contributions/my_contributions_provider_test.dart`

- [ ] **Step 3: Provider**

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../data/providers/contributions_providers.dart';
import '../../domain/entities/contribution_summary.dart';

@immutable
class MyContributionsState {
  const MyContributionsState({this.items = const [], this.nextCursor, this.loadingMore = false});
  final List<ContributionSummary> items;
  final String? nextCursor;
  final bool loadingMore;
  MyContributionsState copyWith({List<ContributionSummary>? items, String? nextCursor, bool clearCursor = false, bool? loadingMore}) =>
      MyContributionsState(items: items ?? this.items, nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor), loadingMore: loadingMore ?? this.loadingMore);
}

/// Observa o auth: trocar de conta (ou sair) recarrega — a lista é da pessoa.
class MyContributionsNotifier extends AsyncNotifier<MyContributionsState> {
  @override
  Future<MyContributionsState> build() async {
    final token = ref.watch(authStateProvider.select((a) => a.asData?.value?.sessionToken));
    if (token == null) return const MyContributionsState();
    final page = await ref.read(contributionsRemoteDatasourceProvider).fetchMine(sessionToken: token);
    return MyContributionsState(items: page.items, nextCursor: page.nextCursor);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> loadMore() async {
    final current = state.value;
    final token = ref.read(authStateProvider).asData?.value?.sessionToken;
    if (current == null || current.nextCursor == null || current.loadingMore || token == null) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await ref.read(contributionsRemoteDatasourceProvider).fetchMine(sessionToken: token, cursor: current.nextCursor);
      state = AsyncData(MyContributionsState(items: [...current.items, ...page.items], nextCursor: page.nextCursor));
    } on Object catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final myContributionsProvider = AsyncNotifierProvider<MyContributionsNotifier, MyContributionsState>(MyContributionsNotifier.new);

final contributionDetailProvider = FutureProvider.autoDispose.family<ContributionSummary, String>((ref, id) async {
  final token = ref.watch(authStateProvider.select((a) => a.asData?.value?.sessionToken));
  if (token == null) throw StateError('unauthorized');
  // Se já está na lista, mostra na hora e revalida em segundo plano.
  return ref.read(contributionsRemoteDatasourceProvider).fetchOne(sessionToken: token, id: id);
});
```

- [ ] **Step 4: Widget test**

`test/widget/features/contributions/my_contributions_screen_test.dart`:

```dart
// pumpApp com authStateProvider logado e myContributionsProvider.overrideWith(() => _FixedNotifier([...]))
// onde _FixedNotifier extends MyContributionsNotifier e build() devolve itens fixos com status
// pendente, emAnalise, aceita (decisionNote 'ok') e bloqueada.
// Asserções:
//   - 'Aguardando análise', 'Em análise', 'Aceita' e o texto de bloqueada aparecem;
//   - lista vazia → 'Você ainda não enviou nenhuma contribuição.';
//   - tocar num item navega (usar um GoRouter mínimo com a rota '/contribuicoes/:id' que monta
//     ContributionDetailScreen com contributionDetailProvider(id).overrideWith((ref) async => item))
//     e o detalhe mostra 'Nota da equipe' + 'ok' e a lista de anexos com 'ok'/'verificando'.
```

Escrever os três `testWidgets` por extenso seguindo esse roteiro (mesma estrutura dos testes da Task 4).

- [ ] **Step 5: Telas e rotas**

`widgets/contribution_status_chip.dart`:

```dart
String contributionStatusLabel(AppLocalizations l10n, ContributionStatus s) => switch (s) {
  ContributionStatus.recebida => l10n.contributionStatusRecebida,
  ContributionStatus.pendente => l10n.contributionStatusPendente,
  ContributionStatus.emAnalise => l10n.contributionStatusEmAnalise,
  ContributionStatus.aceita => l10n.contributionStatusAceita,
  ContributionStatus.recusada => l10n.contributionStatusRecusada,
  ContributionStatus.aplicada => l10n.contributionStatusAplicada,
  ContributionStatus.bloqueada => l10n.contributionStatusBloqueada,
};

Color contributionStatusColor(ContributionStatus s) => switch (s) {
  ContributionStatus.aceita || ContributionStatus.aplicada => AppColors.offlineReady,
  ContributionStatus.recusada || ContributionStatus.bloqueada => AppColors.offlineMissing,
  ContributionStatus.emAnalise => AppColors.gold,
  _ => AppColors.placeholder,
};

class ContributionStatusChip extends StatelessWidget { /* Chip com label e cor acima, texto em AppTypography.label */ }
```

`pages/my_contributions_screen.dart`: deslogado → `SignInToContribute`; logado → `RefreshIndicator(onRefresh: notifier.refresh)` + `ListView.builder` com `ListTile(title, subtitle: kind label + data dd/MM/yyyy, trailing: ContributionStatusChip, onTap: context.push('${RoutePaths.myContributions}/${c.id}'))`; último item dispara `loadMore()` quando `nextCursor != null`; vazio → texto `myContributionsEmpty`; erro → texto + botão tentar de novo. Kind label por l10n (`contributeKind*`).

`pages/contribution_detail_screen.dart`: `ref.watch(contributionDetailProvider(id))` → título, `ContributionStatusChip`, corpo, `fields` (para `metadata`: «campo: atual → proposto»), links (texto selecionável), anexos (`contributionFilesTitle`: nome · tamanho em KB/MB · estado `contributionFileScan*` por `scanStatus` — `limpa` → clean; `suspeita|infectada` → blocked; resto → pending), e se `decisionNote != null` uma seção `contributionDecisionNote`.

`app_router.dart`, branch Perfil, após `favoriteMaterialKinds`:

```dart
        GoRoute(
          path: RoutePaths.myContributions,
          builder: (context, state) => const MyContributionsScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) => ContributionDetailScreen(id: state.pathParameters['id']!),
            ),
          ],
        ),
```

- [ ] **Step 6: Rodar tudo**

Run: `flutter test test/unit/features/contributions test/widget/features/contributions && flutter analyze && dart format lib/features/contributions lib/core/routing/app_router.dart test/unit/features/contributions test/widget/features/contributions`
Expected: PASS; `flutter analyze` limpo no projeto inteiro.

- [ ] **Step 7: Commit**

```bash
git add lib/features/contributions/presentation lib/core/routing/app_router.dart test/unit/features/contributions/my_contributions_provider_test.dart test/widget/features/contributions/my_contributions_screen_test.dart
git commit -m "feat(contributions): «Minhas contribuições» com estado, nota da equipe e detalhe"
```

---

### Task 7: Suíte completa, FEATURE_INDEX e verificação manual

**Files:**
- Modify: `docs/features/FEATURE_INDEX.md` (ou o índice de features usado no repo — conferir com `ls docs/features`)

- [ ] **Step 1: Suíte inteira**

Run: `flutter test && flutter analyze && dart format --output=none --set-exit-if-changed lib test`
Expected: tudo verde.

- [ ] **Step 2: Build web**

Run: `flutter build web --release --dart-define-from-file=dart_defines/plpcg.prod.json` (conferir o nome do arquivo em `dart_defines/`)
Expected: build sem erros (o import condicional de `device_snapshot_web.dart` compila com `package:web`).

- [ ] **Step 3: Índice de features**

Acrescentar a entrada «Contribuições da comunidade» apontando para o spec e listando: rotas `/contribuir`, `/contribuicoes`, `/contribuicoes/:id`; entradas (Perfil, sheet, leitor, player); providers principais; deps novas.

- [ ] **Step 4: Commit**

```bash
git add docs/features
git commit -m "docs(features): índice — contribuições da comunidade"
```

---

## Self-review

- **Spec coverage §6:** entradas (6.1) → Task 5 e Task 4 (rota raiz); formulário (6.2) itens 1–6 → Task 4; coleta (6.3) → Task 2; «Minhas contribuições» (6.4) → Task 6; rede/deps/i18n (6.5) → Tasks 3–4. Testes do §9 (Flutter) → Tasks 1, 2, 4, 6.
- **Placeholders:** o roteiro do teste de widget da Task 6 (Step 4) está descrito em comentário porque depende dos widgets escritos no Step 5 da mesma task; o executor escreve os três `testWidgets` seguindo o roteiro — não é "TBD", é a lista exata de asserções.
- **Type consistency:** `ContributionTarget.copyWith(materialId)` (Task 1) usado em `setMaterial` (Task 4); `ContributionStatus.fromWire` (Task 3) usado no `submit` (Task 3) e em `contributionStatusLabel` (Task 6); `ContributeFormArgs` (Task 4) só é construído na `ContributeScreen`; `openContribute`/`targetFromQuery` (Task 4) usados no router (Task 4) e nas entradas (Task 5); `DeviceSnapshot.versionLabel` (Task 2) usado como `appVersion` no `submit` (Task 4).

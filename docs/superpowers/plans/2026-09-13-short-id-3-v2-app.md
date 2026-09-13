# shortId — Plano 3/3: app v2 (coldigui) — catálogo, link curto, import, sheet de 2 opções, QR no folheto

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** O app v2 lê `shortId` do catálogo, **importa** links `?s=…&n=…` (deep link e colar), **emite** o link curto quando toda a lista é PDF PLPCG com `shortId` (senão o longo de hoje), reduz o sheet de share a «Folheto» e «Só o link» (removendo o fluxo WhatsApp em dois passos), e imprime **QR code** do link curto no folheto.

**Architecture:** `shortId` atravessa DTO → `Louvor` → Isar (`LouvorCache`) e ganha um índice `shortId → pdfId` construído uma vez por manifest. A gramática do link fica toda em `core/utils/playlist_share_url_builder.dart` (`PlaylistShareParams` ganha `shortIds`; parser dá prioridade a `s`). A importação passa a receber `PlaylistShareParams` inteiro (em vez de 4 strings soltas) e um `ShortIdResolver` que espera o manifest antes de resolver. A geração devolve `PlaylistShareLink {url, isShort}` para o folheto decidir o QR sem re-parsear. O `/l/` (encurtador logado) não é tocado e só se aplica ao formato longo.

**Tech Stack:** Flutter 3.47 / Dart, Riverpod 3, Isar Plus (`build_runner`), `share_plus`, `qr_flutter` (novo), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-13-short-id-share-design.md` (§0 D1, D6–D10; §1; §4; §5 passo 4)

## Global Constraints

- Contrato §1: `s` = tokens `[0-9a-f]{4,8}` separados por `-`, minúsculos na emissão; leitura normaliza maiúsculas e ignora token inválido/desconhecido; `n` obrigatório; `s` presente ⇒ ignorar `shareitems`/`sharepdfs`/`shareaudios`/`sharename`; `s`/`n` removidos na limpeza da URL.
- `shortId` é `String?` em todo lugar; nunca `int.parse`; `"0000"` válido. Comparação textual.
- Emite curto **só** quando todas as entradas são `MaterialKind.pdf` com `shortId` no manifest (D7). Senão formato longo inalterado (incluindo a tentativa de `/l/` quando logado).
- QR **só** quando o link é curto (D10).
- Sheet: 2 opções — «Folheto» (`PlaylistShareOption.linkWithLeaflet`) e «Só o link» (`link`). `PlaylistShareOption.leaflet` continua no enum (menu «Gerar folheto» do tile). `linkAndLeafletWhatsApp` e tudo que só ele usa saem.
- Worktree `.claude/worktrees/short-id-share`, branch `feat/short-id-share`. Rodar `flutter test <arquivo>` por task e a suíte `test/unit test/widget` no fim.
- l10n: editar `lib/l10n/app_pt.arb` e `app_en.arb`; regenerar com `flutter gen-l10n`. Isar: `dart run build_runner build --delete-conflicting-outputs`.
- Commits terminam com as duas linhas de atribuição da sessão.

---

## Mapa de arquivos

**Catálogo**
- Modify: `lib/features/catalog/data/models/louvor_dto.dart`, `lib/features/catalog/domain/entities/louvor.dart`, `lib/core/database/collections/louvor_cache.dart` (+ `.g.dart` gerado), `lib/features/catalog/data/mappers/louvor_cache_mapper.dart`
- Create: `lib/features/catalog/presentation/providers/pdf_ids_by_short_id_provider.dart`
- Test: `test/unit/features/catalog/louvor_short_id_test.dart`, `test/unit/features/catalog/pdf_ids_by_short_id_provider_test.dart`

**URL**
- Modify: `lib/core/utils/url_sync_params.dart`, `lib/core/utils/playlist_share_url_builder.dart`
- Test: `test/unit/core/playlist_share_url_builder_test.dart`

**Importação**
- Create: `lib/features/playlists/domain/ports/short_id_resolver.dart`
- Modify: `lib/features/playlists/domain/usecases/import_shared_playlist_from_url.dart`, `lib/features/playlists/data/providers/playlist_providers.dart`, `lib/features/app_shell/domain/usecases/sync_deep_link_state.dart`, `lib/features/playlists/presentation/providers/playlists_provider.dart` (`importSharedFromUrl`), `lib/features/playlists/presentation/widgets/import_playlist_dialog.dart`, `lib/features/playlists/presentation/pages/playlists_screen.dart`, `test/support/fakes/fake_playlists_notifier.dart`
- Test: `test/unit/features/playlists/import_shared_playlist_from_url_test.dart`, `test/unit/features/app_shell/sync_deep_link_state_test.dart`, `test/widget/features/app_shell/deep_link_listener_test.dart`, `test/unit/features/playlists/playlists_provider_import_activates_test.dart`, `test/widget/features/playlists/playlists_screen_test.dart`

**Geração**
- Create: `lib/features/playlists/domain/entities/playlist_share_link.dart`
- Modify: `lib/features/playlists/domain/usecases/generate_playlist_share_url.dart`, `lib/features/playlists/data/providers/playlist_providers.dart`, `lib/features/playlists/presentation/providers/playlist_share_actions_provider.dart`, `lib/features/playlists/presentation/providers/playlists_provider.dart` (`sharePlaylist`)
- Test: `test/unit/features/playlists/generate_playlist_share_url_test.dart`, `test/unit/features/playlists/playlist_share_actions_test.dart`

**Sheet / share**
- Modify: `lib/features/playlists/domain/entities/playlist_share_option.dart`, `lib/features/playlists/presentation/widgets/playlist_share_sheet.dart`, `lib/features/playlists/presentation/providers/playlist_share_actions_provider.dart`, `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb`
- Delete: `lib/features/playlists/presentation/widgets/playlist_share_whatsapp_step_dialog.dart`
- Test: `test/widget/features/playlists/playlist_share_sheet_test.dart`, `test/widget/features/carousel/carousel_chips_test.dart`

**Folheto**
- Modify: `pubspec.yaml` (`qr_flutter`), `lib/features/leaflet/domain/entities/leaflet_document.dart`, `lib/features/leaflet/domain/usecases/generate_leaflet_from_entries.dart`, `lib/features/leaflet/presentation/providers/leaflet_actions_provider.dart` (`resolveLeafletDocument`), `lib/features/leaflet/presentation/widgets/leaflet_content.dart`, `lib/features/leaflet/presentation/widgets/leaflet_content_labels.dart`, l10n
- Test: `test/unit/features/leaflet/generate_leaflet_from_entries_test.dart`, `test/widget/features/leaflet/leaflet_content_test.dart`, `test/unit/features/playlists/playlist_share_actions_test.dart`

**Docs**
- Modify: `docs/features/FEATURE_INDEX.md:1250`, `lib/core/constants/deep_link_config.dart:7`

---

### Task 1: `shortId` no catálogo (DTO, entidade, Isar, mapper) + índice `shortId → pdfId`

**Files:**
- Modify: `lib/features/catalog/data/models/louvor_dto.dart`
- Modify: `lib/features/catalog/domain/entities/louvor.dart:13-26, 60-105`
- Modify: `lib/core/database/collections/louvor_cache.dart` (+ regenerar `louvor_cache.g.dart`)
- Modify: `lib/features/catalog/data/mappers/louvor_cache_mapper.dart`
- Create: `lib/features/catalog/presentation/providers/pdf_ids_by_short_id_provider.dart`
- Test: `test/unit/features/catalog/louvor_short_id_test.dart`, `test/unit/features/catalog/pdf_ids_by_short_id_provider_test.dart`

**Interfaces (Produces):**
- `LouvorDto.shortId: String?`, `Louvor.shortId: String?` (param opcional em `Louvor(...)` e `Louvor.fromManifest(...)`), `LouvorCache.shortId: String?`.
- `final pdfIdsByShortIdProvider = Provider<Map<String, String>>` — `shortId → pdfId`, vazio até o manifest carregar.

- [ ] **Step 1: Testes que falham**

`test/unit/features/catalog/louvor_short_id_test.dart`:
```dart
import 'package:coldigui/core/database/collections/louvor_cache.dart';
import 'package:coldigui/features/catalog/data/mappers/louvor_cache_mapper.dart';
import 'package:coldigui/features/catalog/data/models/louvor_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final json = <String, dynamic>{
    'nome': 'Teste',
    'numero': '1',
    'categoria': 'Partitura',
    'classificacao': 'ColAdultos',
    'pdf': '001.pdf',
    'pdfId': 'Q29sQWR1bHRvcy8wMDEucGRm',
    'groupId': '001:teste',
  };

  test('DTO lê shortId como string e preserva "0000"', () {
    final dto = LouvorDto.fromJson({...json, 'shortId': '0000'});
    expect(dto.shortId, '0000');
    expect(dto.toEntity().shortId, '0000');
  });

  test('DTO sem shortId → null (catálogo antigo)', () {
    final dto = LouvorDto.fromJson(json);
    expect(dto.shortId, isNull);
    expect(dto.toEntity().shortId, isNull);
  });

  test('DTO ignora shortId que não é string (nunca converte número)', () {
    final dto = LouvorDto.fromJson({...json, 'shortId': 0});
    expect(dto.shortId, isNull);
  });

  test('cache Isar ida e volta preserva shortId e ausência', () {
    final com = LouvorDto.fromJson({...json, 'shortId': '1a2f'}).toEntity();
    final sem = LouvorDto.fromJson(json).toEntity();
    expect(com.toCache().shortId, '1a2f');
    expect(com.toCache().toEntity().shortId, '1a2f');
    expect(sem.toCache().shortId, isNull);
    expect(sem.toCache().toEntity().shortId, isNull);
    expect(LouvorCache().shortId, isNull);
  });
}
```

`test/unit/features/catalog/pdf_ids_by_short_id_provider_test.dart`:
```dart
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/catalog/presentation/providers/pdf_ids_by_short_id_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/louvores_manifest_test_helpers.dart';

Louvor _louvor(String pdfId, {String? shortId}) => Louvor.fromManifest(
      nome: 'L $pdfId',
      numero: '001',
      categoria: 'Partitura',
      classificacao: 'ColAdultos',
      pdf: '$pdfId.pdf',
      pdfId: pdfId,
      shortId: shortId,
    );

void main() {
  test('mapeia shortId → pdfId e ignora louvor sem shortId', () async {
    final container = ProviderContainer(
      overrides: [
        louvoresManifestOverride(
          LouvoresManifest.fromLouvores([
            _louvor('pdf-a', shortId: '0000'),
            _louvor('pdf-b', shortId: '1a2f'),
            _louvor('pdf-c'),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(louvoresManifestProvider.future);

    expect(container.read(pdfIdsByShortIdProvider), {
      '0000': 'pdf-a',
      '1a2f': 'pdf-b',
    });
  });

  test('vazio enquanto o manifest não carregou', () {
    final container = ProviderContainer(
      overrides: [louvoresManifestLoadingOverride()],
    );
    addTearDown(container.dispose);
    expect(container.read(pdfIdsByShortIdProvider), isEmpty);
  });
}
```
(o segundo arquivo também precisa de `import 'package:coldigui/features/catalog/presentation/providers/louvores_manifest_provider.dart';`).

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/catalog/louvor_short_id_test.dart test/unit/features/catalog/pdf_ids_by_short_id_provider_test.dart`
Expected: erro de compilação (`shortId` não existe).

- [ ] **Step 3: Implementar**

`louvor_dto.dart` — construtor ganha `this.shortId,`; campo:
```dart
  /// Id curto de share (hex minúsculo, **string** — `"0000"` é válido).
  /// `null` no catálogo antigo ou no material ainda não atribuído.
  final String? shortId;
```
`fromJson`: `shortId: json['shortId'] is String ? json['shortId'] as String : null,`. `toEntity`: `shortId: shortId,`.

`louvor.dart` — construtor: `this.shortId,` (após `this.materialKindId`); campo:
```dart
  /// Id curto de share (spec short-id-share D1): hex minúsculo como string,
  /// atribuído pelo admin, imutável. `null` para Coldigom e para material
  /// ainda sem atribuição — aí o link de share cai no formato longo.
  final String? shortId;
```
`fromManifest`: parâmetro `String? shortId,` e repasse `shortId: shortId,`.

`louvor_cache.dart`:
```dart
  /// Id curto de share — espelha [Louvor.shortId]; `null` quando ausente.
  String? shortId;
```
Depois: `dart run build_runner build --delete-conflicting-outputs` (regenera `louvor_cache.g.dart`).

`louvor_cache_mapper.dart`: `..shortId = shortId` no `toCache()`; `shortId: shortId,` no `toEntity()`.

`pdf_ids_by_short_id_provider.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'louvores_manifest_provider.dart';

/// `shortId → pdfId` do manifest PLPCG, construído **uma vez por manifest**
/// (mesmo padrão de `louvoresByPdfIdProvider`, A4). Vazio enquanto o
/// manifest não carregou. Só o que tem `shortId` entra.
final pdfIdsByShortIdProvider = Provider<Map<String, String>>((ref) {
  final louvores = ref.watch(
    louvoresManifestProvider.select((manifest) => manifest.value?.louvores),
  );
  if (louvores == null) return const {};
  return Map<String, String>.unmodifiable({
    for (final louvor in louvores)
      if (louvor.shortId case final shortId?) shortId: louvor.pdfId,
  });
});
```

- [ ] **Step 4: Rodar**

Run: `flutter test test/unit/features/catalog/`
Expected: tudo verde (os novos + os existentes, que constroem `Louvor` sem `shortId`).

- [ ] **Step 5: Commit**

```bash
git add lib/features/catalog lib/core/database/collections/louvor_cache.dart lib/core/database/collections/louvor_cache.g.dart test/unit/features/catalog/louvor_short_id_test.dart test/unit/features/catalog/pdf_ids_by_short_id_provider_test.dart
git commit -m "feat(catalog): shortId no DTO, entidade e cache Isar; índice shortId→pdfId por manifest"
```

---

### Task 2: Gramática do link curto em `playlist_share_url_builder.dart`

**Files:**
- Modify: `lib/core/utils/url_sync_params.dart`
- Modify: `lib/core/utils/playlist_share_url_builder.dart`
- Test: `test/unit/core/playlist_share_url_builder_test.dart`

**Interfaces (Produces):**
```dart
// url_sync_params.dart
static const String shortItems = 's';
static const String shortName = 'n';

// playlist_share_url_builder.dart
bool isShortId(Object? value);                       // String [0-9a-f]{4,8}
String encodeShortShareIds(List<String> shortIds);   // 'a-b' minúsculo; ignora inválidos
List<String> decodeShortShareIds(String raw);        // válidos, minúsculos, ordem, repetições
String buildShortPlaylistShareLocation({required List<String> shortIds, required String shareName}); // '/?s=…&n=…'
String buildShortPlaylistShareUrl({required String origin, required List<String> shortIds, required String shareName});
class PlaylistShareParams { …; final List<String>? shortIds; bool get isShortFormat; bool get hasMaterial; }
```
`parsePlaylistShareParams`: `s`+`n` → `shortIds`/`shareName`; `stripPlaylistShareParams` remove `s`/`n`; `extractShareParamsFromUserInput` usa `hasMaterial`.

- [ ] **Step 1: Testes que falham** — acrescentar ao fim de `main()` em `test/unit/core/playlist_share_url_builder_test.dart` (vetores idênticos aos do contrato do plpcjf):

```dart
  group('formato curto (contrato ?s=&n=, espelhado no plpcjf)', () {
    test('isShortId aceita 4–8 hex minúsculos e recusa o resto', () {
      expect(isShortId('0000'), isTrue);
      expect(isShortId('1a2f'), isTrue);
      expect(isShortId('10000'), isTrue);
      expect(isShortId('1A2F'), isFalse);
      expect(isShortId('abc'), isFalse);
      expect(isShortId('123456789'), isFalse);
      expect(isShortId(0), isFalse);
      expect(isShortId(null), isFalse);
    });

    test('encode emite minúsculo com "-", preserva ordem e repetição', () {
      expect(encodeShortShareIds(['1a2f', '0000', '1a2f']), '1a2f-0000-1a2f');
      expect(encodeShortShareIds(['00AB', 'zz', '']), '00ab');
    });

    test('decode normaliza maiúsculas e ignora tokens inválidos', () {
      expect(decodeShortShareIds('00AB-zz--1a2f-123456789'), ['00ab', '1a2f']);
      expect(decodeShortShareIds(''), isEmpty);
    });

    test('buildShortPlaylistShareLocation — vetor do contrato', () {
      expect(
        buildShortPlaylistShareLocation(
          shortIds: const ['1a2f', '0000'],
          shareName: 'Culto de domingo',
        ),
        '/?s=1a2f-0000&n=Culto%20de%20domingo',
      );
      expect(
        buildShortPlaylistShareUrl(
          origin: 'https://plpcg.com/',
          shortIds: const ['0000'],
          shareName: 'x',
        ),
        'https://plpcg.com/?s=0000&n=x',
      );
    });

    test('build lança com lista vazia ou nome em branco', () {
      expect(
        () => buildShortPlaylistShareLocation(shortIds: const [], shareName: 'x'),
        throwsArgumentError,
      );
      expect(
        () => buildShortPlaylistShareLocation(shortIds: const ['0000'], shareName: ' '),
        throwsArgumentError,
      );
    });

    test('parse: s+n vence os params legados na mesma URL', () {
      final params = parsePlaylistShareParams(
        Uri.parse(
          'https://plpcg.com/?s=0000-1A2F-zzzz&n=Culto&sharepdfs=lixo&sharename=outro',
        ),
      );
      expect(params, isNotNull);
      expect(params!.isShortFormat, isTrue);
      expect(params.shortIds, ['0000', '1a2f']);
      expect(params.shareName, 'Culto');
      expect(params.hasMaterial, isTrue);
      expect(params.entries, isEmpty, reason: 'curto exige o catálogo para resolver');
    });

    test('parse: s sem n não é share curto (cai no fluxo por sharename)', () {
      expect(parsePlaylistShareParams(Uri.parse('/?s=0000')), isNull);
      final legado = parsePlaylistShareParams(
        Uri.parse('/?s=0000&sharename=X&sharepdfs=a'),
      );
      expect(legado!.isShortFormat, isFalse);
      expect(legado.entries.map((e) => e.id), ['a']);
    });

    test('parse: s só com tokens inválidos → share curto sem material', () {
      final params = parsePlaylistShareParams(Uri.parse('/?s=zz-&n=X'));
      expect(params!.isShortFormat, isTrue);
      expect(params.hasMaterial, isFalse);
    });

    test('strip remove s e n e preserva o resto', () {
      final stripped = stripPlaylistShareParams(
        Uri.parse('/?s=0000&n=Culto&utm_source=wa'),
      );
      expect(stripped.queryParameters, {'utm_source': 'wa'});
    });

    test('extractShareParamsFromUserInput aceita link curto colado', () {
      final params = extractShareParamsFromUserInput(
        'abre isto: https://plpcg.com/?s=1a2f-0000&n=Culto',
      );
      expect(params!.shortIds, ['1a2f', '0000']);
      expect(params.shareName, 'Culto');
    });
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/core/playlist_share_url_builder_test.dart`
Expected: erro de compilação (`isShortId`, `shortIds` etc. inexistentes).

- [ ] **Step 3: Implementar**

`url_sync_params.dart`, após `shareItems`:
```dart
  /// Link curto de lista PLPCG (spec short-id-share §1): `shortId`s hex
  /// separados por `-`. Presente ⇒ [shareItems]/[sharePdfs]/[shareAudios]/
  /// [shareName] são ignorados.
  static const String shortItems = 's';

  /// Nome da lista no link curto — obrigatório, marca a URL como share.
  static const String shortName = 'n';
```

`playlist_share_url_builder.dart` — após `decodeShareItems`, acrescentar:
```dart
final RegExp _shortIdPattern = RegExp(r'^[0-9a-f]{4,8}$');

/// `shortId` válido (spec short-id-share D1/D5): **string** hex minúscula de
/// 4 a 8 caracteres. Nunca é número — `"0000"` é um id.
bool isShortId(Object? value) =>
    value is String && _shortIdPattern.hasMatch(value);

/// Serializa `shortId`s para o param `s` — minúsculo, separados por `-`
/// (não sofre URL-encode e nunca ocorre em hex). Ignora o que não é shortId.
String encodeShortShareIds(List<String> shortIds) => [
      for (final id in shortIds)
        if (isShortId(id.toLowerCase())) id.toLowerCase(),
    ].join('-');

/// Lê o param `s`: normaliza maiúsculas, ignora token fora do padrão,
/// preserva ordem e repetições (a lista pode repetir um louvor).
List<String> decodeShortShareIds(String raw) => [
      for (final part in raw.split('-'))
        if (isShortId(part.trim().toLowerCase())) part.trim().toLowerCase(),
    ];

/// Monta `/?s=…&n=…` (spec §1). Lança [ArgumentError] se [shortIds] vazio
/// ou [shareName] em branco.
String buildShortPlaylistShareLocation({
  required List<String> shortIds,
  required String shareName,
}) {
  if (shortIds.isEmpty) {
    throw ArgumentError.value(shortIds, 'shortIds', 'must not be empty');
  }
  if (shareName.trim().isEmpty) {
    throw ArgumentError.value(shareName, 'shareName', 'must not be empty');
  }
  return '${RoutePaths.home}'
      '?${UrlSyncParams.shortItems}=${encodeShortShareIds(shortIds)}'
      '&${UrlSyncParams.shortName}=${Uri.encodeComponent(shareName)}';
}

/// URL absoluta do link curto ([origin] + [buildShortPlaylistShareLocation]).
String buildShortPlaylistShareUrl({
  required String origin,
  required List<String> shortIds,
  required String shareName,
}) {
  final normalizedOrigin =
      origin.endsWith('/') ? origin.substring(0, origin.length - 1) : origin;
  return '$normalizedOrigin'
      '${buildShortPlaylistShareLocation(shortIds: shortIds, shareName: shareName)}';
}
```

Em `PlaylistShareParams`: novo campo + getters:
```dart
  const PlaylistShareParams({
    required this.shareName,
    this.sharePdfs = '',
    this.shareAudios = '',
    this.shareItems,
    this.shortIds,
  });

  /// `shortId`s do link curto (`s`), já validados e minúsculos. **Não nulo**
  /// significa «este share está no formato curto»: [entries] fica vazio e a
  /// resolução `shortId → pdfId` exige o catálogo (`ShortIdResolver`).
  final List<String>? shortIds;

  /// `true` quando o link veio como `?s=…&n=…`.
  bool get isShortFormat => shortIds != null;

  /// Há material para importar — tokens curtos ou entradas longas. É o que
  /// distingue «share inválido» de «share por resolver».
  bool get hasMaterial =>
      isShortFormat ? shortIds!.isNotEmpty : entries.isNotEmpty;
```
Na doc de `entries`, acrescentar: «No formato curto devolve `[]` — ver [shortIds].» e no início do getter:
```dart
    if (isShortFormat) return const [];
```

`parsePlaylistShareParams`:
```dart
PlaylistShareParams? parsePlaylistShareParams(Uri uri) {
  final query = safeQueryParameters(uri);

  // Formato curto (spec §1): `s` + `n` vencem os params legados.
  final shortRaw = query[UrlSyncParams.shortItems];
  final shortName = query[UrlSyncParams.shortName];
  if (shortRaw != null && shortName != null && shortName.isNotEmpty) {
    return PlaylistShareParams(
      shareName: shortName,
      shortIds: decodeShortShareIds(shortRaw),
    );
  }

  final shareName = query[UrlSyncParams.shareName];
  if (shareName == null || shareName.isEmpty) return null;
  return PlaylistShareParams(
    sharePdfs: query[UrlSyncParams.sharePdfs] ?? '',
    shareAudios: query[UrlSyncParams.shareAudios] ?? '',
    shareName: shareName,
    shareItems: query[UrlSyncParams.shareItems],
  );
}
```

`stripPlaylistShareParams`: acrescentar `..remove(UrlSyncParams.shortItems)` e `..remove(UrlSyncParams.shortName)`.

`extractShareParamsFromUserInput`: em `withEntries`, trocar `params.entries.isNotEmpty` por `params.hasMaterial`; e na heurística do terceiro bloco:
```dart
  final hasShareName = trimmed.contains('${UrlSyncParams.shareName}=');
  final hasList =
      trimmed.contains('${UrlSyncParams.shareItems}=') ||
      trimmed.contains('${UrlSyncParams.sharePdfs}=') ||
      trimmed.contains('${UrlSyncParams.shareAudios}=');
  final hasShort =
      trimmed.contains('${UrlSyncParams.shortItems}=') &&
      trimmed.contains('${UrlSyncParams.shortName}=');
  if ((hasShareName && hasList) || hasShort) {
```

- [ ] **Step 4: Rodar**

Run: `flutter test test/unit/core/playlist_share_url_builder_test.dart`
Expected: verde (antigos + novos).

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/url_sync_params.dart lib/core/utils/playlist_share_url_builder.dart test/unit/core/playlist_share_url_builder_test.dart
git commit -m "feat(share): gramática do link curto ?s=&n= — encode/decode, parse com prioridade, strip"
```

---

### Task 3: Importação por `shortId` — `ShortIdResolver` e `ImportSharedPlaylistFromUrl(params:)`

**Files:**
- Create: `lib/features/playlists/domain/ports/short_id_resolver.dart`
- Modify: `lib/features/playlists/domain/usecases/import_shared_playlist_from_url.dart`
- Modify: `lib/features/playlists/data/providers/playlist_providers.dart:122-126`
- Modify: `lib/features/app_shell/domain/usecases/sync_deep_link_state.dart:79-115`
- Modify: `lib/features/playlists/presentation/providers/playlists_provider.dart:530-565` (`importSharedFromUrl`)
- Modify: `lib/features/playlists/presentation/widgets/import_playlist_dialog.dart` (remove `ImportPlaylistDialogResult`, devolve `PlaylistShareParams`)
- Modify: `lib/features/playlists/presentation/pages/playlists_screen.dart:105-118`
- Modify: `test/support/fakes/fake_playlists_notifier.dart:42, 110-120`
- Test: `test/unit/features/playlists/import_shared_playlist_from_url_test.dart`, `test/unit/features/app_shell/sync_deep_link_state_test.dart`, `test/widget/features/app_shell/deep_link_listener_test.dart`, `test/unit/features/playlists/playlists_provider_import_activates_test.dart`, `test/widget/features/playlists/playlists_screen_test.dart`

**Interfaces (Produces):**
```dart
typedef ShortIdResolver = Future<Map<String, String>> Function();   // shortId → pdfId, após o manifest
class ImportSharedPlaylistFromUrl {
  const ImportSharedPlaylistFromUrl(this._playlistRepository, {required ShortIdResolver resolveShortIds});
  Future<ImportResult> call({required PlaylistShareParams params, String? excludePlaylistId});
}
final shortIdResolverProvider = Provider<ShortIdResolver>(...);
Future<String?> PlaylistsNotifier.importSharedFromUrl({required PlaylistShareParams params});
Future<PlaylistShareParams?> showImportPlaylistDialog(BuildContext context);
```

- [ ] **Step 1: Migrar chamadas existentes para `params:` (refactor sem mudar comportamento)**

Em `import_shared_playlist_from_url.dart`:
```dart
import '../ports/short_id_resolver.dart';
…
class ImportSharedPlaylistFromUrl {
  const ImportSharedPlaylistFromUrl(
    this._playlistRepository, {
    required ShortIdResolver resolveShortIds,
  }) : _resolveShortIds = resolveShortIds;

  final PlaylistRepository _playlistRepository;
  final ShortIdResolver _resolveShortIds;

  Future<ImportResult> call({
    required PlaylistShareParams params,
    String? excludePlaylistId,
  }) async {
    final entries = params.isShortFormat
        ? await _entriesFromShortIds(params.shortIds!)
        : params.entries;
    final nome = params.shareName.trim();
    if (entries.isEmpty || nome.isEmpty) {
      throw const InvalidSharePlaylistException();
    }
    // … resto igual (fingerprint, dedupe, create) …
  }

  /// `shortId → pdfId` pelo catálogo (D8): desconhecido é ignorado com aviso;
  /// repetições são preservadas (a lista pode repetir um louvor). Espera o
  /// manifest — [ShortIdResolver] só resolve depois de ele existir.
  Future<List<PlaylistEntry>> _entriesFromShortIds(List<String> shortIds) async {
    final pdfIdByShortId = await _resolveShortIds();
    final entries = <PlaylistEntry>[];
    for (final shortId in shortIds) {
      final pdfId = pdfIdByShortId[shortId];
      if (pdfId == null) {
        _log.warn('shortId desconhecido no catálogo — ignorado: $shortId');
        continue;
      }
      entries.add(PlaylistEntry.classified(pdfId));
    }
    return entries;
  }
}
```
(adicionar `import '../../../../core/logging/app_logger.dart';` e `final _log = AppLogger.of('playlists');` no topo, como em `generate_playlist_share_url.dart`.)

`short_id_resolver.dart`:
```dart
/// Resolve `shortId → pdfId` pelo catálogo PLPCG (spec short-id-share D8).
///
/// Devolve o mapa **depois** de o manifest existir — quem implementa aguarda
/// o carregamento, para um deep link que chega antes do catálogo não ser
/// descartado como «nenhum id conhecido». Vazio se o catálogo não tem
/// `shortId` (versão antiga do Worker).
typedef ShortIdResolver = Future<Map<String, String>> Function();
```

`playlist_providers.dart`:
```dart
/// `shortId → pdfId` esperando o manifest (spec short-id-share D8).
final shortIdResolverProvider = Provider<ShortIdResolver>((ref) {
  return () async {
    await ref.read(louvoresManifestProvider.future);
    return ref.read(pdfIdsByShortIdProvider);
  };
});

final importSharedPlaylistFromUrlProvider =
    Provider<ImportSharedPlaylistFromUrl>((ref) {
      return ImportSharedPlaylistFromUrl(
        ref.watch(playlistRepositoryProvider),
        resolveShortIds: ref.watch(shortIdResolverProvider),
      );
    });
```
(imports: `../../domain/ports/short_id_resolver.dart`, `../../../catalog/presentation/providers/louvores_manifest_provider.dart`, `../../../catalog/presentation/providers/pdf_ids_by_short_id_provider.dart`.)

`sync_deep_link_state.dart`: o `call` passa `params` inteiro:
```dart
      final result = await _importSharedPlaylist(params: params);
```
e a doc da classe: «Detecta `s`+`n` (curto) ou `sharename` (longo) na URI e delega…».

`playlists_provider.dart` — `importSharedFromUrl`:
```dart
  Future<String?> importSharedFromUrl({
    required PlaylistShareParams params,
  }) async {
    try {
      // … pendingDelete igual …
      final result = await ref.read(importSharedPlaylistFromUrlProvider)(
        params: params,
        excludePlaylistId: excludePlaylistId,
      );
      // … igual …
```

`import_playlist_dialog.dart`: apagar `ImportPlaylistDialogResult`; `showImportPlaylistDialog` devolve `Future<PlaylistShareParams?>`; em `submit()`:
```dart
            final params = extractShareParamsFromUserInput(controller.text);
            if (params == null) {
              setState(() => invalidInput = true);
              return;
            }
            Navigator.of(dialogContext).pop(params);
```
e o `showDialog<PlaylistShareParams>`.

`playlists_screen.dart` (~linha 105–118): `final result = await showImportPlaylistDialog(context); if (result == null) return;` … `importSharedFromUrl(params: result)`.

`test/support/fakes/fake_playlists_notifier.dart`: `PlaylistShareParams? lastImport;` e
```dart
  @override
  Future<String?> importSharedFromUrl({
    required PlaylistShareParams params,
  }) async {
    lastImport = params;
    return importedPlaylistId;
  }
```
(ajuste os imports: remover `import_playlist_dialog.dart`, adicionar `package:coldigui/core/utils/playlist_share_url_builder.dart`.)

Testes existentes — trocar as chamadas:
- `import_shared_playlist_from_url_test.dart`: `useCase = ImportSharedPlaylistFromUrl(playlistRepository, resolveShortIds: () async => resolverMap);` com `var resolverMap = <String, String>{};` no `setUp`; cada `useCase(sharePdfs: 'a,b', shareName: 'X')` vira `useCase(params: const PlaylistShareParams(sharePdfs: 'a,b', shareName: 'X'))` (idem `shareItems`/`shareAudios`).
- `sync_deep_link_state_test.dart` e `deep_link_listener_test.dart`: `ImportSharedPlaylistFromUrl(repo, resolveShortIds: () async => const {})`.
- `playlists_provider_import_activates_test.dart` e `playlists_screen_test.dart`: `importSharedFromUrl(params: PlaylistShareParams(...))` / asserções sobre `lastImport?.shareName` etc.

Run: `flutter test test/unit/features/playlists/import_shared_playlist_from_url_test.dart test/unit/features/app_shell test/widget/features/app_shell test/unit/features/playlists/playlists_provider_import_activates_test.dart test/widget/features/playlists/playlists_screen_test.dart`
Expected: verde — mesmo comportamento, nova assinatura.

- [ ] **Step 2: Commit do refactor**

```bash
git add -A lib test
git commit -m "refactor(playlists): import recebe PlaylistShareParams inteiro; porta ShortIdResolver"
```

- [ ] **Step 3: Testes do formato curto que falham** — acrescentar a `import_shared_playlist_from_url_test.dart`:

```dart
  group('formato curto (shortIds)', () {
    test('resolve shortId → pdfId na ordem, preservando repetição', () async {
      resolverMap = {'0000': 'pdf-a', '1a2f': 'pdf-b'};
      final result = await useCase(
        params: const PlaylistShareParams(
          shareName: 'Curta',
          shortIds: ['1a2f', '0000', '1a2f'],
        ),
      );
      final saved = await playlistRepository.getById(result.playlist.playlistId);
      expect(saved?.pdfIds, ['pdf-b', 'pdf-a', 'pdf-b']);
      expect(saved?.entries.every((e) => !e.isAudio), isTrue);
    });

    test('ignora shortId desconhecido e importa o resto', () async {
      resolverMap = {'0000': 'pdf-a'};
      final result = await useCase(
        params: const PlaylistShareParams(shareName: 'X', shortIds: ['ffff', '0000']),
      );
      final saved = await playlistRepository.getById(result.playlist.playlistId);
      expect(saved?.pdfIds, ['pdf-a']);
    });

    test('nenhum shortId conhecido → InvalidSharePlaylistException', () async {
      resolverMap = {};
      expect(
        () => useCase(params: const PlaylistShareParams(shareName: 'X', shortIds: ['0000'])),
        throwsA(isA<InvalidSharePlaylistException>()),
      );
    });

    test('dedupe por conteúdo entre link curto e link longo da mesma lista', () async {
      resolverMap = {'0000': 'pdf-a', '1a2f': 'pdf-b'};
      final longo = await useCase(
        params: const PlaylistShareParams(shareName: 'A', sharePdfs: 'pdf-a,pdf-b'),
      );
      final curto = await useCase(
        params: const PlaylistShareParams(shareName: 'B', shortIds: ['0000', '1a2f']),
      );
      expect(curto.alreadyExisted, isTrue);
      expect(curto.playlist.playlistId, longo.playlist.playlistId);
    });

    test('resolver é aguardado (deep link antes do catálogo)', () async {
      final completer = Completer<Map<String, String>>();
      final lateUseCase = ImportSharedPlaylistFromUrl(
        playlistRepository,
        resolveShortIds: () => completer.future,
      );
      final future = lateUseCase(
        params: const PlaylistShareParams(shareName: 'X', shortIds: ['0000']),
      );
      completer.complete({'0000': 'pdf-a'});
      final result = await future;
      expect(result.playlist.pdfIds, ['pdf-a']);
    });
  });
```
(`import 'dart:async';` no topo.) E em `sync_deep_link_state_test.dart`:
```dart
  test('importa link curto ?s=&n= resolvendo pelo catálogo', () async {
    final shortUseCase = SyncDeepLinkState(
      ImportSharedPlaylistFromUrl(
        playlistRepository,
        resolveShortIds: () async => {'0000': 'pdf-a', '1a2f': 'pdf-b'},
      ),
    );
    final result = await shortUseCase(
      uri: Uri.parse('https://plpcg.com/?s=1a2f-0000&n=Culto'),
    );
    expect(result.outcome, SyncDeepLinkOutcome.success);
    final saved = await playlistRepository.getById(result.playlistId!);
    expect(saved?.pdfIds, ['pdf-b', 'pdf-a']);
    expect(saved?.nome, 'Culto');
  });
```

- [ ] **Step 4: Rodar e ver falhar**

Run: `flutter test test/unit/features/playlists/import_shared_playlist_from_url_test.dart test/unit/features/app_shell/sync_deep_link_state_test.dart`
Expected: os casos novos falham se o Step 1 ainda não incluiu `_entriesFromShortIds` (se você já implementou tudo no Step 1, eles passam — o que também é aceitável: o refactor e a feature foram escritos juntos; confirme que **falhariam** comentando `_entriesFromShortIds` temporariamente não é necessário).

- [ ] **Step 5: Rodar tudo do import**

Run: `flutter test test/unit/features/playlists test/unit/features/app_shell test/widget/features/app_shell test/widget/features/playlists/playlists_screen_test.dart`
Expected: verde.

- [ ] **Step 6: Commit**

```bash
git add -A lib test
git commit -m "feat(playlists): importa lista por shortId (deep link e colar) aguardando o catálogo"
```

---

### Task 4: Geração — `PlaylistShareLink` e formato curto em `GeneratePlaylistShareUrl`

**Files:**
- Create: `lib/features/playlists/domain/entities/playlist_share_link.dart`
- Modify: `lib/features/playlists/domain/usecases/generate_playlist_share_url.dart`
- Modify: `lib/features/playlists/data/providers/playlist_providers.dart:112-120`
- Modify: `lib/features/playlists/presentation/providers/playlist_share_actions_provider.dart:120-130, 246-256`
- Modify: `lib/features/playlists/presentation/providers/playlists_provider.dart:485-495`
- Test: `test/unit/features/playlists/generate_playlist_share_url_test.dart`, `test/unit/features/playlists/playlist_share_actions_test.dart`

**Interfaces (Produces):**
```dart
class PlaylistShareLink { const PlaylistShareLink({required this.url, required this.isShort}); final String url; final bool isShort; }
typedef ShortIdLookup = String? Function(String pdfId);
class GeneratePlaylistShareUrl {
  const GeneratePlaylistShareUrl(this._repository, {this.shareOrigin = AppConfig.apiBaseUrl, this.shortener, this.shortIdOf});
  Future<PlaylistShareLink> call({required String playlistId, bool short = false});
}
```
`PlaylistShareActionsNotifier._generateUrl` passa a devolver `Future<PlaylistShareLink>`.

- [ ] **Step 1: Testes que falham** — em `generate_playlist_share_url_test.dart`, trocar `final url = await useCase(...)` por `final link = await useCase(...)` e `url` → `link.url` nos testes existentes (e `expect(link.isShort, isFalse)` no primeiro); acrescentar:

```dart
  group('formato curto (D7)', () {
    final repo = _FakePlaylistRepository({
      'p1': SavedPlaylist(
        playlistId: 'p1',
        nome: 'Culto de domingo',
        entries: const [
          PlaylistEntry(id: 'pdf-b', kind: MaterialKind.pdf),
          PlaylistEntry(id: 'pdf-a', kind: MaterialKind.pdf),
        ],
        createdAt: DateTime(2026, 1, 1),
      ),
      'mista': SavedPlaylist(
        playlistId: 'mista',
        nome: 'Mista',
        entries: const [
          PlaylistEntry(id: 'pdf-a', kind: MaterialKind.pdf),
          PlaylistEntry(id: 'aud-1', kind: MaterialKind.audio),
        ],
        createdAt: DateTime(2026, 1, 1),
      ),
    });
    String? lookup(String pdfId) =>
        const {'pdf-a': '0000', 'pdf-b': '1a2f'}[pdfId];

    test('todas as entradas PDF com shortId → link curto (vetor do contrato)', () async {
      final useCase = GeneratePlaylistShareUrl(repo, shareOrigin: origin, shortIdOf: lookup);
      final link = await useCase(playlistId: 'p1');
      expect(link.isShort, isTrue);
      expect(link.url, 'https://plpcg.com/?s=1a2f-0000&n=Culto%20de%20domingo');
    });

    test('lista com áudio → formato longo', () async {
      final useCase = GeneratePlaylistShareUrl(repo, shareOrigin: origin, shortIdOf: lookup);
      final link = await useCase(playlistId: 'mista');
      expect(link.isShort, isFalse);
      expect(link.url, contains('shareitems='));
    });

    test('PDF sem shortId no catálogo → formato longo', () async {
      final useCase = GeneratePlaylistShareUrl(
        repo, shareOrigin: origin, shortIdOf: (id) => id == 'pdf-a' ? '0000' : null,
      );
      final link = await useCase(playlistId: 'p1');
      expect(link.isShort, isFalse);
    });

    test('sem lookup (shortIdOf null) → formato longo', () async {
      final useCase = GeneratePlaylistShareUrl(repo, shareOrigin: origin);
      expect((await useCase(playlistId: 'p1')).isShort, isFalse);
    });

    test('short: true com link curto NÃO chama o encurtador /l/', () async {
      var chamado = false;
      final useCase = GeneratePlaylistShareUrl(
        repo,
        shareOrigin: origin,
        shortIdOf: lookup,
        shortener: _FakeShortener((_) async { chamado = true; return 'https://plpcg.com/l/abc'; }),
      );
      final link = await useCase(playlistId: 'p1', short: true);
      expect(link.isShort, isTrue);
      expect(chamado, isFalse);
    });
  });
```
(`_FakeShortener` — se o arquivo já tem um fake de `ShareLinkShortener` para os testes de D7, reaproveite-o com o mesmo nome; senão declare `class _FakeShortener implements ShareLinkShortener { _FakeShortener(this._fn); final Future<String> Function(String) _fn; @override Future<String> shorten(String query) => _fn(query); }`.)

Em `playlist_share_actions_test.dart`, as duas construções `GeneratePlaylistShareUrl(_FakePlaylistRepository(), shareOrigin: …)` continuam válidas (sem lookup → longo); nenhuma asserção muda nesta task.

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/playlists/generate_playlist_share_url_test.dart`
Expected: erro de compilação (`link.url`, `shortIdOf`).

- [ ] **Step 3: Implementar**

`playlist_share_link.dart`:
```dart
/// Link de share já montado (spec short-id-share §4.5).
///
/// [isShort] diz se saiu no formato curto `?s=…&n=…` — quem imprime o QR no
/// folheto decide por ele (D10) sem re-parsear [url].
class PlaylistShareLink {
  const PlaylistShareLink({required this.url, required this.isShort});

  final String url;
  final bool isShort;
}
```

`generate_playlist_share_url.dart`:
```dart
/// `pdfId → shortId` do catálogo; `null` quando o material não tem.
typedef ShortIdLookup = String? Function(String pdfId);

class GeneratePlaylistShareUrl {
  const GeneratePlaylistShareUrl(
    this._repository, {
    this.shareOrigin = AppConfig.apiBaseUrl,
    this.shortener,
    this.shortIdOf,
  });

  final PlaylistRepository _repository;
  final String shareOrigin;
  final ShareLinkShortener? shortener;

  /// Lookup de `shortId` (spec short-id-share D7). `null` = sem catálogo →
  /// sempre formato longo.
  final ShortIdLookup? shortIdOf;

  /// Formato curto quando **todas** as entradas são PDF com `shortId`; senão
  /// o longo (`shareitems` + legados), com a tentativa de `/l/` se `short`.
  Future<PlaylistShareLink> call({
    required String playlistId,
    bool short = false,
  }) async {
    final playlist = await _repository.getById(playlistId);
    if (playlist == null) throw const PlaylistNotFoundException();
    if (playlist.entries.isEmpty) throw const EmptyPlaylistShareException();

    final shortIds = _shortIdsFor(playlist.entries);
    if (shortIds != null) {
      return PlaylistShareLink(
        url: buildShortPlaylistShareUrl(
          origin: shareOrigin,
          shortIds: shortIds,
          shareName: playlist.nome,
        ),
        isShort: true,
      );
    }

    final longUrl = buildPlaylistShareUrlFromEntries(
      origin: shareOrigin,
      entries: playlist.entries,
      shareName: playlist.nome,
    );
    final shortenerInstance = shortener;
    if (!short || shortenerInstance == null) {
      return PlaylistShareLink(url: longUrl, isShort: false);
    }
    try {
      final shortened = await shortenerInstance.shorten(Uri.parse(longUrl).query);
      return PlaylistShareLink(url: shortened, isShort: false);
    } on Object catch (e, stackTrace) {
      _log.warn('encurtador falhou — caindo na URL longa', e);
      _log.debug('$stackTrace');
      return PlaylistShareLink(url: longUrl, isShort: false);
    }
  }

  /// `null` se alguma entrada não é PDF ou não tem `shortId` (D7).
  List<String>? _shortIdsFor(List<PlaylistEntry> entries) {
    final lookup = shortIdOf;
    if (lookup == null) return null;
    final shortIds = <String>[];
    for (final entry in entries) {
      if (entry.kind != MaterialKind.pdf) return null;
      final shortId = lookup(entry.id);
      if (shortId == null) return null;
      shortIds.add(shortId);
    }
    return shortIds;
  }
}
```
(imports: `../entities/playlist_share_link.dart`, `../entities/saved_playlist.dart` para `PlaylistEntry`/`MaterialKind`.) Nota: o `/l/` devolve `isShort: false` de propósito — é outro mecanismo e o QR não deve depender dele.

`playlist_providers.dart`:
```dart
final generatePlaylistShareUrlProvider = Provider<GeneratePlaylistShareUrl>((ref) {
  return GeneratePlaylistShareUrl(
    ref.watch(playlistRepositoryProvider),
    shortener: ref.watch(shareLinkShortenerProvider),
    shortIdOf: (pdfId) => ref.read(louvoresByPdfIdProvider)[pdfId]?.shortId,
  );
});
```
(import `../../../catalog/presentation/providers/louvores_by_pdf_id_provider.dart`.)

`playlist_share_actions_provider.dart`: `_generateUrl` devolve `Future<PlaylistShareLink>`; em `_shareLinkOnly` e `_shareLinkWithLeaflet` use `final link = await _generateUrl(...)` e `link.url` onde era `url`.

`playlists_provider.dart` (`sharePlaylist`, ~485–495): `final link = await generateUrl(playlistId: playlistId);` e `link.url` no `shareFn` e no log.

- [ ] **Step 4: Rodar**

Run: `flutter test test/unit/features/playlists/generate_playlist_share_url_test.dart test/unit/features/playlists/playlist_share_actions_test.dart test/unit/features/playlists/playlists_provider_*`
Expected: verde.

- [ ] **Step 5: Commit**

```bash
git add -A lib test
git commit -m "feat(share): link curto por shortId quando toda a lista é PDF PLPCG; PlaylistShareLink"
```

---

### Task 5: Sheet com 2 opções; remover o fluxo WhatsApp em dois passos

**Files:**
- Modify: `lib/features/playlists/domain/entities/playlist_share_option.dart`
- Modify: `lib/features/playlists/presentation/widgets/playlist_share_sheet.dart`
- Modify: `lib/features/playlists/presentation/providers/playlist_share_actions_provider.dart`
- Delete: `lib/features/playlists/presentation/widgets/playlist_share_whatsapp_step_dialog.dart`
- Modify: `lib/l10n/app_pt.arb:580-592`, `lib/l10n/app_en.arb:565-577`
- Test: `test/widget/features/playlists/playlist_share_sheet_test.dart`, `test/widget/features/carousel/carousel_chips_test.dart:405-431`

- [ ] **Step 1: Teste do sheet que falha** — substituir o conteúdo do `testWidgets` em `playlist_share_sheet_test.dart`:

```dart
  testWidgets('exibe Folheto e Só o link, nesta ordem, e devolve a opção',
      (tester) async {
    PlaylistShareOption? selected;
    // … mesmo pumpWidget/Builder de antes …
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Compartilhar'), findsOneWidget);
    expect(find.text('Folheto'), findsOneWidget);
    expect(find.text('Só o link'), findsOneWidget);
    expect(find.text('Só o folheto'), findsNothing);
    expect(find.text('Link com folheto'), findsNothing);
    expect(find.text('Link + folheto'), findsNothing);
    expect(find.byType(ListTile), findsNWidgets(2));

    final folhetoY = tester.getTopLeft(find.text('Folheto')).dy;
    final linkY = tester.getTopLeft(find.text('Só o link')).dy;
    expect(folhetoY, lessThan(linkY));

    await tester.tap(find.text('Folheto'));
    await tester.pumpAndSettle();
    expect(selected, PlaylistShareOption.linkWithLeaflet);
  });

  testWidgets('Só o link devolve PlaylistShareOption.link', (tester) async {
    PlaylistShareOption? selected;
    // … mesmo pumpWidget …
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Só o link'));
    await tester.pumpAndSettle();
    expect(selected, PlaylistShareOption.link);
  });
```

Em `carousel_chips_test.dart` (~linha 426), o teste que tocava `'Só o folheto'` passa a tocar `'Folheto'` e esperar `PlaylistShareOption.linkWithLeaflet` (renomeie o teste para «compartilhar folheto pelo sheet da barra»).

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/widget/features/playlists/playlist_share_sheet_test.dart test/widget/features/carousel/carousel_chips_test.dart`
Expected: FAIL (4 tiles; texto «Folheto» não existe).

- [ ] **Step 3: Implementar**

`playlist_share_option.dart`:
```dart
/// Modo de compartilhamento (UC-07/UC-08, spec short-id-share D9).
enum PlaylistShareOption {
  /// Só a URL da lista.
  link,

  /// Só a imagem PNG do folheto — usado pelo «Gerar folheto» do menu do tile
  /// (não aparece no sheet).
  leaflet,

  /// Folheto + link na mesma mensagem (imagem com legenda). Padrão do sheet.
  linkWithLeaflet,
}
```

`playlist_share_sheet.dart`: manter só dois `_ShareOptionTile`, nesta ordem:
```dart
              _ShareOptionTile(
                icon: Icons.description_outlined,
                title: l10n.playlistShareOptionLinkWithLeaflet,
                subtitle: l10n.playlistShareOptionLinkWithLeafletSubtitle,
                onTap: () =>
                    Navigator.pop(context, PlaylistShareOption.linkWithLeaflet),
              ),
              _ShareOptionTile(
                icon: Icons.link,
                title: l10n.playlistShareOptionLink,
                subtitle: l10n.playlistShareOptionLinkSubtitle,
                onTap: () => Navigator.pop(context, PlaylistShareOption.link),
              ),
```
Remover `_whatsappGreen`. Doc do arquivo: «Bottom sheet — Folheto (imagem + link) ou Só o link (spec short-id-share D9)».

`playlist_share_actions_provider.dart`: remover o `case PlaylistShareOption.linkAndLeafletWhatsApp`, o método `_shareWhatsAppTwoStep`, o parâmetro `showWhatsAppStepDialog` e a variável `whatsAppDialogFn`, o import do diálogo, e reescrever a doc de `share` — o retorno `false` passa a significar **falha** (o provider mostra o snackbar; quem chama não mostra outro). Doc da classe: «Orquestra os 3 modos: link, folheto, folheto+link».

`git rm lib/features/playlists/presentation/widgets/playlist_share_whatsapp_step_dialog.dart`.

l10n (`app_pt.arb`): remover `playlistShareOptionLeaflet`, `playlistShareOptionLeafletSubtitle`, `playlistShareOptionWhatsApp`, `playlistShareOptionWhatsAppSubtitle`, `playlistShareWhatsAppStepTitle`, `playlistShareWhatsAppStepMessage`, `playlistShareWhatsAppStepContinue`, `playlistShareWhatsAppStepCancel` (confirme com `grep -rn "playlistShareOptionLeaflet\b" lib --include=*.dart` que só o sheet usava). Alterar:
```json
  "playlistShareOptionLinkWithLeaflet": "Folheto",
  "playlistShareOptionLinkWithLeafletSubtitle": "Imagem da lista com o link e QR code",
```
`app_en.arb`: mesmas remoções; `"Leaflet"` / `"List image with link and QR code"`. Depois `flutter gen-l10n`.

- [ ] **Step 4: Rodar**

Run: `flutter analyze && flutter test test/widget/features/playlists test/widget/features/carousel test/unit/features/playlists/playlist_share_actions_test.dart`
Expected: `analyze` sem erros (nenhuma referência órfã a `linkAndLeafletWhatsApp`/strings removidas); testes verdes.

- [ ] **Step 5: Commit**

```bash
git add -A lib test
git commit -m "feat(share): sheet com Folheto e Só o link; remove fluxo WhatsApp em dois passos"
```

---

### Task 6: QR code no folheto (só com link curto)

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/features/leaflet/domain/entities/leaflet_document.dart`
- Modify: `lib/features/leaflet/domain/usecases/generate_leaflet_from_entries.dart:30-55`
- Modify: `lib/features/leaflet/presentation/providers/leaflet_actions_provider.dart:137-147` (`resolveLeafletDocument`)
- Modify: `lib/features/leaflet/presentation/widgets/leaflet_content_labels.dart`, `lib/features/leaflet/presentation/widgets/leaflet_content.dart:86-95, 255+`
- Modify: `lib/features/playlists/presentation/providers/playlist_share_actions_provider.dart` (`_shareLeafletOnly`, `_shareLinkWithLeaflet`, `_captureLeafletXFile`)
- Modify: l10n (`leafletShareQrCaption`)
- Test: `test/unit/features/leaflet/generate_leaflet_from_entries_test.dart`, `test/widget/features/leaflet/leaflet_content_test.dart`, `test/unit/features/playlists/playlist_share_actions_test.dart`

**Interfaces (Produces):**
- `LeafletDocument({required entries, required generatedAt, String? shareUrl})`, campo `shareUrl`.
- `GenerateLeafletFromEntries.call({required entries, required now, String? shareUrl})`.
- `resolveLeafletDocument(ref, {required entries, required fromCarousel, String? shareUrl})`.
- `LeafletContentLabels.shareQrCaption: String`.
- `PlaylistShareActionsNotifier._captureLeafletXFile(..., {String? shareUrl})`.

- [ ] **Step 1: Dependência**

Run: `flutter pub add qr_flutter`
Expected: `pubspec.yaml` ganha `qr_flutter: ^<última>`; `flutter pub get` ok.

- [ ] **Step 2: Testes que falham**

`generate_leaflet_from_entries_test.dart` — acrescentar (use o mesmo `lookup` fake dos testes existentes):
```dart
  test('repassa shareUrl para o documento; ausente por padrão', () {
    final com = useCase(entries: entries, now: now, shareUrl: 'https://plpcg.com/?s=0000&n=x');
    expect(com.shareUrl, 'https://plpcg.com/?s=0000&n=x');
    final sem = useCase(entries: entries, now: now);
    expect(sem.shareUrl, isNull);
  });
```

`leaflet_content_test.dart` — acrescentar dois `testWidgets` (reaproveitando `labels`, que ganha `shareQrCaption: 'Abrir lista no PLPCG'`):
```dart
  testWidgets('sem shareUrl não desenha QR', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: LeafletContent(document: document, labels: labels),
    ))));
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('Abrir lista no PLPCG'), findsNothing);
  });

  testWidgets('com shareUrl desenha QR, legenda e o link', (tester) async {
    final comQr = LeafletDocument(
      generatedAt: generatedAt,
      entries: document.entries,
      shareUrl: 'https://plpcg.com/?s=1a2f-0000&n=Culto',
    );
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: LeafletContent(document: comQr, labels: labels),
    ))));
    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(qr.data, 'https://plpcg.com/?s=1a2f-0000&n=Culto');
    expect(find.text('Abrir lista no PLPCG'), findsOneWidget);
    expect(find.text('plpcg.com/?s=1a2f-0000&n=Culto'), findsOneWidget);
  });
```
(`import 'package:qr_flutter/qr_flutter.dart';`.)

`playlist_share_actions_test.dart` — acrescentar um caso que prova a regra D10 no fluxo real:
```dart
  testWidgets('linkWithLeaflet com link curto passa shareUrl ao folheto; longo não',
      (tester) async {
    Future<({String? capturedUrl, String? text})> run({required bool comShortId}) async {
      String? text;
      LeafletDocument? doc;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          playlistRepositoryProvider.overrideWithValue(_FakePlaylistRepository()),
          louvoresManifestOverride(LouvoresManifest.fromLouvores([
            Louvor.fromManifest(
              nome: 'Louvor A', numero: '001', categoria: 'Partitura',
              classificacao: 'ColAdultos', pdf: 'a.pdf', pdfId: 'pdf-a',
              shortId: comShortId ? '0000' : null,
            ),
          ])),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: const Scaffold(body: SizedBox()),
        ),
      ));
      final context = tester.element(find.byType(Scaffold));
      final container = ProviderScope.containerOf(context);
      await container.read(louvoresManifestProvider.future);
      final notifier = container.read(playlistShareActionsProvider.notifier);
      await notifier.share(
        context, shareContext, PlaylistShareOption.linkWithLeaflet,
        sharePositionOrigin: null,
        shareXFiles: (files, {subject, text: t, sharePositionOrigin}) async { text = t; },
        capture: (boundaryKey) async {
          final content = tester.widget<LeafletContent>(find.byType(LeafletContent));
          doc = content.document;
          return const [1, 2, 3];
        },
      );
      return (capturedUrl: doc?.shareUrl, text: text);
    }

    final curto = await run(comShortId: true);
    expect(curto.capturedUrl, 'https://plpcg.com/?s=0000&n=Ensaio');
    expect(curto.text, contains('https://plpcg.com/?s=0000&n=Ensaio'));

    final longo = await run(comShortId: false);
    expect(longo.capturedUrl, isNull);
    expect(longo.text, contains('shareitems='));
  });
```
Este teste depende de `generatePlaylistShareUrlProvider` real (com `shortIdOf` do provider) e de `AppConfig.apiBaseUrl` — se `apiBaseUrl` estiver vazio no ambiente de teste, override `generatePlaylistShareUrlProvider` com `GeneratePlaylistShareUrl(_FakePlaylistRepository(), shareOrigin: 'https://plpcg.com', shortIdOf: (id) => container.read(louvoresByPdfIdProvider)[id]?.shortId)` dentro de `run` (crie o container antes, via `ProviderContainer`, ou use `overrideWith` lendo `ref`). Note que `capture` roda **enquanto** o `LeafletContent` está montado no overlay — por isso dá para ler o `document` dele ali.

- [ ] **Step 3: Rodar e ver falhar**

Run: `flutter test test/unit/features/leaflet test/widget/features/leaflet test/unit/features/playlists/playlist_share_actions_test.dart`
Expected: erro de compilação (`shareUrl`, `shareQrCaption`).

- [ ] **Step 4: Implementar**

`leaflet_document.dart`:
```dart
  const LeafletDocument({
    required this.entries,
    required this.generatedAt,
    this.shareUrl,
  });

  /// Link curto da lista para o QR do rodapé (spec short-id-share D10).
  /// `null` = sem QR (link longo, ou folheto sem lista salva).
  final String? shareUrl;
```
(as factories `fromCarouselItems`/`fromPdfIds` ganham `String? shareUrl` e repassam.)

`generate_leaflet_from_entries.dart`: `call({required entries, required now, String? shareUrl})` e `return LeafletDocument(generatedAt: now, entries: leafletEntries, shareUrl: shareUrl);`.

`leaflet_actions_provider.dart` — `resolveLeafletDocument(ref, {required entries, required fromCarousel, String? shareUrl})` repassa `shareUrl:`.

`leaflet_content_labels.dart`: campo `final String shareQrCaption;` (obrigatório no construtor), `shareQrCaption: l10n.leafletShareQrCaption` em `fromL10n`. l10n: `"leafletShareQrCaption": "Abrir lista no PLPCG"` / en `"Open the list in PLPCG"`; `flutter gen-l10n`. Atualizar as construções `const LeafletContentLabels(...)` nos testes existentes (`leaflet_content_test.dart` e quaisquer outros que `grep -rn "LeafletContentLabels(" test` apontar).

`leaflet_content.dart`: importar `package:qr_flutter/qr_flutter.dart`; na `Column` do `build`, antes de `_FooterBand`:
```dart
                if (document.shareUrl case final shareUrl?)
                  _ShareQrBand(shareUrl: shareUrl, labels: labels),
```
e o widget:
```dart
/// Rodapé com QR do link curto (spec short-id-share D10). Só existe quando
/// [LeafletDocument.shareUrl] veio preenchido — link longo não vira QR.
class _ShareQrBand extends StatelessWidget {
  const _ShareQrBand({required this.shareUrl, required this.labels});

  final String shareUrl;
  final LeafletContentLabels labels;

  static const _qrSize = 132.0;

  /// Link sem esquema para caber numa linha legível sob o QR.
  String get _displayUrl => shareUrl.replaceFirst(RegExp(r'^https?://'), '');

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: LeafletContent._insetH,
        vertical: LeafletContent._footerInsetV,
      ),
      decoration: LeafletContent._sectionDivider.copyWith(
        color: AppColors.background,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(LeafletContent._borderRadius),
              border: Border.all(color: AppColors.gold, width: 1),
            ),
            child: QrImageView(
              data: shareUrl,
              version: QrVersions.auto,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
              size: _qrSize,
              gapless: true,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            labels.shareQrCaption,
            textAlign: TextAlign.center,
            style: _leafletGoldStyle(
              fontSize: LeafletContent._fontColumnLabel,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _displayUrl,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: LeafletContent._garamond,
              fontSize: LeafletContent._fontDate,
              color: AppColors.placeholder.withValues(alpha: 0.95),
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}
```

`playlist_share_actions_provider.dart`:
- `_captureLeafletXFile(overlay, shareContext, l10n, {capture, String? shareUrl})` repassa `shareUrl` a `resolveLeafletDocument`.
- `_shareLinkWithLeaflet`: já gera o link antes da captura; passe `shareUrl: link.isShort ? link.url : null` e use `link.url` na mensagem.
- `_shareLeafletOnly` («Gerar folheto» do tile, D10 também): tentar o link para o QR sem tornar o folheto refém dele:
```dart
    // QR só com link curto (D10). Lista sem registro/sem material no
    // repositório não impede o folheto: fica sem QR.
    String? qrUrl;
    try {
      final link = await _generateUrl(shareContext.playlistId);
      if (link.isShort) qrUrl = link.url;
    } on PlaylistNotFoundException {
      qrUrl = null;
    } on EmptyPlaylistShareException {
      qrUrl = null;
    }
    if (!context.mounted) return false;
    final xFile = await _captureLeafletXFile(overlay, shareContext, l10n, capture: capture, shareUrl: qrUrl);
```

- [ ] **Step 5: Rodar**

Run: `flutter test test/unit/features/leaflet test/widget/features/leaflet test/unit/features/playlists test/widget/features/playlists`
Expected: verde.

- [ ] **Step 6: Verificação visual do PNG (web, prod — memória `test-on-production-v2` diz para validar em `v2.plpcg.com`, mas o PNG pode ser conferido localmente antes)**

Run: `flutter run -d chrome --dart-define-from-file=dart_defines/plpcg.json` → criar lista com 2 partituras → menu do tile → «Gerar folheto» → salvar/abrir a imagem. Expected: rodapé com QR nítido, legenda «Abrir lista no PLPCG» e o link `plpcg.com/?s=…&n=…`; a câmera do celular lê o QR e abre o plpcjf. (Antes do rollout do Plano 1 o catálogo local não tem `shortId` → sem QR: nesse caso valide só o layout com um override temporário no teste de widget, e refaça esta checagem no rollout.)

- [ ] **Step 7: Commit**

```bash
git add -A lib test pubspec.yaml pubspec.lock
git commit -m "feat(leaflet): QR code do link curto no rodapé do folheto (só formato curto)"
```

---

### Task 7: Docs, suíte completa, rollout (passo 4 do §5) e merge

**Files:**
- Modify: `docs/features/FEATURE_INDEX.md:1250` («bottom sheet 4 modos UC-07/08» → «bottom sheet 2 modos — Folheto (imagem + link curto + QR) / Só o link — UC-07/08, spec short-id-share»), e linha 21 (`playlists`): acrescentar «**link curto por shortId set/2026** (`?s=…&n=…`, import por deep link/colar)».
- Modify: `lib/core/constants/deep_link_config.dart:7` — `(`plpcg:///?s=…&n=…` ou legado `?sharepdfs=…`)`.

- [ ] **Step 1: Docs** — editar as três linhas acima.

- [ ] **Step 2: Suíte completa + análise**

Run: `flutter analyze && flutter test test/unit test/widget`
Expected: `No issues found!`; `All tests passed!`.

- [ ] **Step 3: Commit**

```bash
git add docs/features/FEATURE_INDEX.md lib/core/constants/deep_link_config.dart
git commit -m "docs: share por shortId no FEATURE_INDEX e deep link config"
```

- [ ] **Step 4: Rollout** — pré-requisitos: Plano 1 Task 9 e Plano 2 Task 5 concluídos.
  - Merge `feat/short-id-share` em `web/integration` (fluxo do repo), deploy web e builds nativos como de costume.
  - Validação manual em `v2.plpcg.com` e no iOS (spec §4.8):
    1. iOS, lista só de partituras → Compartilhar → **Folheto** → WhatsApp: chega imagem com QR + legenda `nome` + `https://plpcg.com/?s=…&n=…`.
    2. Tocar o link no WhatsApp → abre o plpcjf com a lista.
    3. v2 → Listas → Importar → colar o link curto → lista importada e ativa.
    4. Lista com áudio → **Só o link** → link longo (`shareitems=`), folheto sem QR.
    5. Câmera lê o QR do folheto → abre o plpcjf.

---

## Self-review

- **Cobertura da spec §4:** 4.1 (Plano 1), 4.2 (Task 1), 4.3 (Task 2), 4.4 (Task 3), 4.5 (Task 4), 4.6 (Task 5), 4.7 (Task 6), 4.8 (testes em cada task + manual na 7), §5 passo 4 (Task 7). D7 (Task 4 `_shortIdsFor`), D8 (Task 3 `_entriesFromShortIds` + resolver que espera o manifest), D9 (Task 5), D10 (Task 6 `isShort`).
- **Tipos entre tasks:** `pdfIdsByShortIdProvider` (T1) usado em T3; `PlaylistShareParams.shortIds/isShortFormat/hasMaterial` (T2) usados em T3; `PlaylistShareLink.isShort` (T4) usado em T6; `resolveLeafletDocument(shareUrl:)` (T6) chamado por `_captureLeafletXFile(shareUrl:)` (T6); `LeafletContentLabels.shareQrCaption` obrigatório → testes existentes atualizados na T6; `ImportSharedPlaylistFromUrl(repo, resolveShortIds:)` (T3) em todos os testes que o constroem.
- **Placeholders:** nenhum; a única condicional é o override opcional de `generatePlaylistShareUrlProvider` no teste da T6 caso `AppConfig.apiBaseUrl` esteja vazio, com o código do override dado.
- **Fora do plano, de propósito:** `PlaylistsNotifier.sharePlaylist` (sem chamadores) só é adaptado à nova assinatura, não removido — remoção de código morto é outra conversa.

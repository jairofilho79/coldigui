# Catálogo PLPCG servido pelo coldigom — plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** o app `coldigui` passa a buscar manifest, checksum e PDFs no Worker `coldigom-api`, deixa o modo dual (um card por praise, ids legados preservados) e faz a primeira configuração offline PDF a PDF, sem ZIP nem `plpcg.com`.

**Architecture:** o manifest continua a alimentar `PlpcgCatalogSource`/`PlpcgSearchIndex` (busca e ranking intactos); ganha `praiseId`/`materialId` e `Louvor.effectiveGroupId` passa a ser o `praiseId`. A fusão manifest + extras Coldigom acontece no `CompositeCatalogSource`, que recebe um índice de aliases (`ManifestMaterialAliases`) construído uma vez por manifest. O PDF abre pela URL absoluta do campo `pdf`. O pipeline ZIP do offline é apagado; `OfflineBulkDownloadNotifier` passa a orquestrar `DownloadMissingPdfs` com `CancelToken`.

**Tech Stack:** Flutter 3 + Riverpod 3 (`Notifier`/`Provider`), Dio, `isar_plus` (schema gerado por `build_runner`), `flutter_test`, `flutter gen-l10n`.

**Spec:** `docs/superpowers/specs/2026-09-18-catalogo-coldigom-modo-unico-design.md` — o plano argumenta a partir dele; quem executa lê os dois.

## Global Constraints

- Nada muda no coldigom nem no Worker `plpcg-catalog` (spec, escopo).
- Dois dart-defines obrigatórios, sem `defaultValue`: `PLPCG_API_BASE_URL` (Worker `plpcg-catalog`) e `COLDIGOM_API_BASE_URL` (coldigom) (spec D7).
- Endpoints novos, exatos: `/api/plpcg/manifest` e `/api/plpcg/manifest/checksum` (spec D1).
- `pdfId`, `groupId`, `shortId` do manifest são os originais do PLPCG; o cache `OfflinePdfIndex` (chave `pdfId`) **não** é migrado (spec §3.5).
- `PlpcgSearchIndex`/`runPlpcgSearchPipeline` não mudam (spec D5).
- Gates «Lista ao Vivo só Coldigom» e «share só PLPCG puro» ficam fora (spec D8/§11).
- Testes: `flutter analyze` limpo e `flutter test` verde (VM roda **sem** dart-defines no CI — nenhum teste pode depender do valor de `ColdigomApiConfig.baseUrl`).
- Commits em português, um por unidade lógica, trailer obrigatório:
  `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`.
- Branch `feat/catalogo-coldigom-modo-unico` (já existe, a partir de `web/integration`); PR para `web/integration`.

### Desvios do spec (decididos ao planear; ver justificativa na tarefa)

1. **§5.3 — `ColdigomCacheWriter` não muda.** O writer teria de ler o manifest (`louvoresManifestProvider`), que arranca Isar/rede em todo teste que toca o writer. Quem exclui PDFs cobertos é o `CompositeCatalogSource` ao fundir (ele já tem os aliases). Efeito visível idêntico: uma entrada por material (D4). Tarefa 7.
2. **§4.5 — o alias não é `coldigomPdfIdFor(praiseId, materialId)`.** Medido em 2026-09-18: 64 entradas do manifest (e 1473 PDFs do coldigom) têm `r2_key` numa pasta de **outro** praise (material movido). O id Coldigom correto é `encodePdfId(r2Key)` e o `r2Key` é exatamente o path do campo `pdf` depois da base — para os 4429 (0 divergências). Logo: `coldigomPdfIdFromManifestPdf(pdf)`. Tarefa 5.
3. **§6.2 — sem botão «retomar».** Depois de cancelar, o botão «Baixar selecionados» já é a retomada (`DownloadMissingPdfs` pré-filtra o que existe). Tarefa 12.
4. **§4.2 — o adapter Coldigom também preenche `praiseId`/`materialId`.** Assim `effectiveGroupId` é o `praiseId` nos dois acervos, sem depender do path do `pdfId` (que pode apontar para outro praise, ver desvio 2). Tarefa 2.

## Mapa de ficheiros

| Tarefa | Cria | Modifica | Apaga |
|---|---|---|---|
| 1 Config | `lib/features/app_shell/presentation/pages/missing_api_config_screen.dart`, `test/widget/features/app_shell/missing_api_config_screen_test.dart` | `lib/core/constants/app_config.dart`, `lib/features/coldigom/data/constants/coldigom_api_config.dart`, `lib/app.dart` | — |
| 2 Modelo | `test/unit/features/catalog/louvor_praise_id_test.dart` | `louvor.dart`, `louvor_dto.dart`, `louvor_cache.dart` (+ `.g.dart`), `louvor_cache_mapper.dart`, `catalog_repository_impl.dart`, `louvor_data_source.dart`, `coldigom_louvor_adapter.dart`, testes existentes | — |
| 3 Endpoints | `test/unit/features/catalog/catalog_remote_datasource_test.dart` | `coldigom_endpoints.dart`, `api_endpoints.dart`, `catalog_remote_datasource.dart`, `catalog_providers.dart` | — |
| 4 URL do PDF | — | `louvor_pdf_path.dart`, `catalog_local_datasource.dart`, `download_missing_pdfs.dart`, testes | — |
| 5 Aliases | `manifest_material_aliases.dart`, `coldigom_pdf_id_from_manifest_pdf.dart`, `manifest_material_aliases_provider.dart`, `known_praise_ids_provider.dart`, testes | — | — |
| 6 Partes Coldigom | — | `coldigom_catalog_source.dart`, `catalog_source_test.dart` | — |
| 7 Fusão | — | `composite_catalog_source.dart`, `catalog_source_provider.dart`, `catalog_source_test.dart` | — |
| 8 Home/lookup | — | `catalog_material_lookup_provider.dart`, `home_search_provider.dart`, `home_remote_search_provider.dart`, testes | — |
| 9 Warmup | — | `coldigom_praise_cache_warmup.dart`, teste | — |
| 10 Trocar material | — | `find_louvor_group_by_pdf_id.dart`, `carousel_swap_material_button.dart`, testes | — |
| 11 `DownloadMissingPdfs` cancelável | — | `download_missing_pdfs.dart`, teste | — |
| 12 Bulk sem ZIP | — | `offline_bulk_download_provider.dart`, `offline_download_progress.dart`, `progress_section.dart`, `offline_settings_screen.dart`, `app_pt.arb`, `app_en.arb`, testes | `checkpoint_banner.dart` |
| 13 Apagar ZIP | — | `offline_bulk_exceptions.dart`, `reconcile_offline_index.dart`, `offline_reconcile_provider.dart`, `clear_offline_cache.dart`, `offline_core_providers.dart`, `storage_keys.dart`, `api_endpoints.dart`, `pubspec.yaml`, testes | ZIP pipeline inteiro (lista na tarefa) |
| 14 Docs | — | `README.md`, `docs/features/FEATURE_INDEX.md`, `docs/features/LOUVOR_GROUPING.md`, `MAPEAMENTO_PLPCG_FLUTTER.md`, spec (§12) | — |

Todos os paths abaixo são relativos à raiz do repo. Comandos de teste: `flutter test <path>`; ao fim de cada tarefa, `flutter analyze` também.

---

## Unidade 1 — Configuração

### Task 1: Guard de arranque para os dois dart-defines

**Files:**
- Modify: `lib/features/coldigom/data/constants/coldigom_api_config.dart`
- Modify: `lib/core/constants/app_config.dart`
- Create: `lib/features/app_shell/presentation/pages/missing_api_config_screen.dart`
- Modify: `lib/app.dart`
- Test: `test/widget/features/app_shell/missing_api_config_screen_test.dart`

**Interfaces:**
- Produces: `ColdigomApiConfig.isBaseUrlMissing` (`bool`), `MissingApiConfigScreen({required List<String> missingDefines})`.
- `AppConfig.isApiBaseUrlMissing` continua.

- [ ] **Step 1: Teste do widget**

```dart
// test/widget/features/app_shell/missing_api_config_screen_test.dart
import 'package:coldigui/features/app_shell/presentation/pages/missing_api_config_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('lista cada define ausente e o comando de reinstalação', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MissingApiConfigScreen(
          missingDefines: ['PLPCG_API_BASE_URL', 'COLDIGOM_API_BASE_URL'],
        ),
      ),
    );

    expect(find.textContaining('PLPCG_API_BASE_URL'), findsOneWidget);
    expect(find.textContaining('COLDIGOM_API_BASE_URL'), findsOneWidget);
    expect(
      find.textContaining('--dart-define-from-file=dart_defines/plpcg.json'),
      findsOneWidget,
    );
  });

  testWidgets('com um só define ausente só ele aparece', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MissingApiConfigScreen(missingDefines: ['COLDIGOM_API_BASE_URL']),
      ),
    );

    expect(find.textContaining('COLDIGOM_API_BASE_URL'), findsOneWidget);
    expect(find.textContaining('PLPCG_API_BASE_URL'), findsNothing);
  });
}
```

- [ ] **Step 2: Correr e ver falhar**

Run: `flutter test test/widget/features/app_shell/missing_api_config_screen_test.dart`
Expected: FAIL — `missing_api_config_screen.dart` não existe.

- [ ] **Step 3: `ColdigomApiConfig` sem default + flag**

Substituir o conteúdo de `lib/features/coldigom/data/constants/coldigom_api_config.dart`:

```dart
/// Configuração da API coldigom.
abstract final class ColdigomApiConfig {
  /// URL base do Worker coldigom — catálogo, PDFs e materiais do app.
  ///
  /// `--dart-define=COLDIGOM_API_BASE_URL` ou `dart_defines/*.json`. Sem
  /// default: vazio quando o define não foi injetado — [ColdiguiApp] mostra
  /// a tela de configuração ausente (mesmo tratamento de
  /// `PLPCG_API_BASE_URL`).
  static const String baseUrl = String.fromEnvironment('COLDIGOM_API_BASE_URL');

  /// `true` quando [baseUrl] não foi injetado no build.
  static bool get isBaseUrlMissing => baseUrl.isEmpty;
}
```

- [ ] **Step 4: Doc de `AppConfig`**

Em `lib/core/constants/app_config.dart`, trocar o comentário de `apiBaseUrl` por:

```dart
  /// URL base do Worker `plpcg-catalog` (auth, playlists, links, live).
  ///
  /// Definida em compile-time via `--dart-define` ou
  /// `--dart-define-from-file=dart_defines/plpcg.json`. O catálogo e os PDFs
  /// **não** vêm daqui — vêm de `COLDIGOM_API_BASE_URL`
  /// (`ColdigomApiConfig.baseUrl`).
  ///
  /// iOS: [ios/Flutter/PlpcgDartDefines.xcconfig] injeta o mesmo valor em builds
  /// Xcode/`flutter install` sem flags no terminal.
  ///
  /// Retorna vazio se nenhum define foi aplicado — [ColdiguiApp] exibe tela de
  /// configuração ausente.
```

- [ ] **Step 5: Tela pública**

```dart
// lib/features/app_shell/presentation/pages/missing_api_config_screen.dart
import 'package:flutter/material.dart';

/// Exibida no boot quando algum dos dart-defines de URL base falta
/// (`PLPCG_API_BASE_URL`, `COLDIGOM_API_BASE_URL`).
///
/// Sem router e sem l10n de propósito: é diagnóstico de build, mostrado
/// antes de o app existir.
class MissingApiConfigScreen extends StatelessWidget {
  const MissingApiConfigScreen({required this.missingDefines, super.key});

  /// Nomes dos defines ausentes, na ordem em que devem aparecer.
  final List<String> missingDefines;

  @override
  Widget build(BuildContext context) {
    final names = missingDefines.join(', ');
    return Scaffold(
      appBar: AppBar(title: const Text('PLPCG')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SelectableText(
          '$names não está definido neste build.\n\n'
          'Reinstale com:\n'
          'flutter run --dart-define-from-file=dart_defines/plpcg.json\n\n'
          'ou:\n'
          'flutter build ios --dart-define-from-file=dart_defines/plpcg.json',
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: `app.dart` usa a tela e checa os dois**

Em `lib/app.dart`: adicionar os imports
`import 'features/app_shell/presentation/pages/missing_api_config_screen.dart';`
e `import 'features/coldigom/data/constants/coldigom_api_config.dart';`.
Trocar o bloco `if (AppConfig.isApiBaseUrlMissing) {...}` por:

```dart
    final missingDefines = [
      if (AppConfig.isApiBaseUrlMissing) 'PLPCG_API_BASE_URL',
      if (ColdigomApiConfig.isBaseUrlMissing) 'COLDIGOM_API_BASE_URL',
    ];
    if (missingDefines.isNotEmpty) {
      return MaterialApp(
        title: 'PLPCG',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: MissingApiConfigScreen(missingDefines: missingDefines),
      );
    }
```

Apagar a classe privada `_MissingApiBaseUrlScreen` e atualizar o doc-comment da classe `ColdiguiApp` (linha «Se [AppConfig.isApiBaseUrlMissing]…» → «Se falta `PLPCG_API_BASE_URL` ou `COLDIGOM_API_BASE_URL`, renderiza [MissingApiConfigScreen] (sem router)…»).

- [ ] **Step 7: Conferir o xcconfig**

`ios/Flutter/PlpcgDartDefines.xcconfig` já injeta `COLDIGOM_API_BASE_URL` (base64 na linha `DART_DEFINES`) — nada a mudar; confirmar com `grep COLDIGOM ios/Flutter/PlpcgDartDefines.xcconfig`.

- [ ] **Step 8: Correr testes + analyze**

Run: `flutter test test/widget/features/app_shell/ && flutter analyze`
Expected: PASS, analyze limpo. Também `flutter test test/unit/core/utils/asset_base_url_resolver_test.dart test/unit/features/audio_player/audio_track_url_test.dart` (comparam com `ColdigomApiConfig.baseUrl`, que agora é `''` no VM — devem continuar verdes porque comparam relativamente).

- [ ] **Step 9: Commit**

```bash
git add lib/core/constants/app_config.dart lib/features/coldigom/data/constants/coldigom_api_config.dart lib/features/app_shell/presentation/pages/missing_api_config_screen.dart lib/app.dart test/widget/features/app_shell/missing_api_config_screen_test.dart
git commit -m "feat(config): COLDIGOM_API_BASE_URL obrigatório; guard de arranque cobre os dois defines

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Unidade 2 — Modelo

### Task 2: `praiseId`/`materialId` em `Louvor`, DTO, Isar e adapter; `effectiveGroupId` por praise

**Files:**
- Modify: `lib/features/catalog/domain/entities/louvor.dart`
- Modify: `lib/features/catalog/domain/entities/louvor_data_source.dart`
- Modify: `lib/features/catalog/data/models/louvor_dto.dart`
- Modify: `lib/core/database/collections/louvor_cache.dart` (+ regenerar `louvor_cache.g.dart`)
- Modify: `lib/features/catalog/data/mappers/louvor_cache_mapper.dart`
- Modify: `lib/features/catalog/data/repositories/catalog_repository_impl.dart` (`_isSameManifest`)
- Modify: `lib/features/coldigom/data/adapters/coldigom_louvor_adapter.dart`
- Test: `test/unit/features/catalog/louvor_praise_id_test.dart` (novo), `test/unit/features/coldigom/coldigom_louvor_adapter_test.dart`, `test/unit/features/catalog/catalog_repository_impl_test.dart`

**Interfaces:**
- Produces: `Louvor.praiseId`, `Louvor.materialId` (`String?`); `Louvor.fromManifest(..., String? praiseId, String? materialId)`; `Louvor.effectiveGroupId` = `praiseId ?? LouvorGroupId.effective(...)`; `LouvorDto.praiseId/materialId`; `LouvorCache.praiseId/materialId`.

- [ ] **Step 1: Testes de modelo**

```dart
// test/unit/features/catalog/louvor_praise_id_test.dart
import 'package:coldigui/core/database/collections/louvor_cache.dart';
import 'package:coldigui/features/catalog/data/mappers/louvor_cache_mapper.dart';
import 'package:coldigui/features/catalog/data/models/louvor_dto.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_group_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final json = <String, dynamic>{
    'nome': 'A Ti Senhor',
    'numero': '',
    'categoria': 'Partitura',
    'classificacao': 'Avulsos, GLTM',
    'pdf':
        'https://coldigom.test/assets/praises/13f78240-803a/d7dbbcb4-8929.pdf',
    'pdfId': 'MzAxMDIwMjUvQSBUaSBTZW5ob3IucGRm',
    'groupId': 'avulso:a-ti-senhor',
    'shortId': '000b',
  };

  test('DTO lê praiseId e materialId como string não vazia', () {
    final dto = LouvorDto.fromJson({
      ...json,
      'praiseId': '13f78240-803a',
      'materialId': 'd7dbbcb4-8929',
    });
    expect(dto.praiseId, '13f78240-803a');
    expect(dto.materialId, 'd7dbbcb4-8929');
    final entity = dto.toEntity();
    expect(entity.praiseId, '13f78240-803a');
    expect(entity.materialId, 'd7dbbcb4-8929');
  });

  test('DTO sem praiseId/materialId, vazio ou não-string → null', () {
    expect(LouvorDto.fromJson(json).praiseId, isNull);
    expect(LouvorDto.fromJson({...json, 'praiseId': ''}).praiseId, isNull);
    expect(LouvorDto.fromJson({...json, 'praiseId': 7}).praiseId, isNull);
    expect(LouvorDto.fromJson({...json, 'materialId': ' '}).materialId, isNull);
  });

  test('effectiveGroupId prefere praiseId, depois groupId, depois cálculo', () {
    final comPraise = Louvor.fromManifest(
      nome: 'Clamo a ti',
      numero: '3',
      categoria: 'Partitura',
      classificacao: 'ColAdultos',
      pdf: '003.pdf',
      pdfId: 'id-3',
      groupId: '003:clamo-a-ti-legado',
      praiseId: 'praise-3',
    );
    expect(comPraise.effectiveGroupId, 'praise-3');

    final comGroup = Louvor.fromManifest(
      nome: 'Clamo a ti',
      numero: '3',
      categoria: 'Partitura',
      classificacao: 'ColAdultos',
      pdf: '003.pdf',
      pdfId: 'id-3',
      groupId: '003:clamo-a-ti-legado',
    );
    expect(comGroup.effectiveGroupId, '003:clamo-a-ti-legado');

    final calculado = Louvor.fromManifest(
      nome: 'Clamo a ti',
      numero: '3',
      categoria: 'Partitura',
      classificacao: 'ColAdultos',
      pdf: '003.pdf',
      pdfId: 'id-3',
    );
    expect(
      calculado.effectiveGroupId,
      LouvorGroupId.compute(numero: '3', nome: 'Clamo a ti'),
    );
  });

  test('cache Isar ida e volta preserva praiseId/materialId e ausência', () {
    final com = LouvorDto.fromJson({
      ...json,
      'praiseId': 'p1',
      'materialId': 'm1',
    }).toEntity();
    final sem = LouvorDto.fromJson(json).toEntity();

    expect(com.toCache().praiseId, 'p1');
    expect(com.toCache().materialId, 'm1');
    expect(com.toCache().toEntity().praiseId, 'p1');
    expect(com.toCache().toEntity().materialId, 'm1');
    expect(sem.toCache().praiseId, isNull);
    expect(sem.toCache().toEntity().materialId, isNull);
    expect(LouvorCache().praiseId, isNull);
    expect(LouvorCache().materialId, isNull);
  });
}
```

- [ ] **Step 2: Correr e ver falhar**

Run: `flutter test test/unit/features/catalog/louvor_praise_id_test.dart`
Expected: FAIL — `praiseId` não existe.

- [ ] **Step 3: Entidade**

Em `lib/features/catalog/domain/entities/louvor.dart`:

1. No construtor `const Louvor({...})`, depois de `this.shortId,` adicionar `this.praiseId,` e `this.materialId,`.
2. Depois do campo `shortId`, adicionar:

```dart
  /// Id do praise no coldigom — identidade do louvor lógico nos dois acervos.
  ///
  /// Manifest: vem do `/api/plpcg/manifest`; `null` no cache Isar anterior ao
  /// primeiro sync pós-migração e em fixtures antigas. Coldigom: `praise.id`.
  final String? praiseId;

  /// Id do material no coldigom (nome do ficheiro sem extensão em
  /// `assets/praises/<praiseId>/<materialId>.pdf`). `null` como [praiseId].
  final String? materialId;
```

3. Trocar `effectiveGroupId`:

```dart
  /// Identidade do louvor lógico: [praiseId] quando existe (um card por
  /// praise, spec D3); senão o `groupId` do manifest; senão calculado.
  String get effectiveGroupId =>
      praiseId ??
      LouvorGroupId.effective(groupId: groupId, numero: numero, nome: nome);
```

4. Em `factory Louvor.fromManifest`, adicionar os parâmetros `String? praiseId,` e `String? materialId,` depois de `String? shortId,` e passá-los ao `Louvor(...)` (`praiseId: praiseId, materialId: materialId,`).

Atualizar o doc da classe: «Entidade de domínio — louvor do manifest PLPCG» → «Entidade de domínio — um PDF do catálogo (manifest servido pelo coldigom ou material Coldigom nativo). [praiseId] agrupa materiais do mesmo louvor (ver [LouvorGroup])».

- [ ] **Step 4: `LouvorDataSource` só documenta o espaço de ids**

Substituir `lib/features/catalog/domain/entities/louvor_data_source.dart`:

```dart
/// Espaço de ids de um louvor/material — **não** de onde os bytes vêm.
///
/// Desde a migração do catálogo (set/2026) tudo é servido pelo coldigom; o
/// valor só diz como o id foi cunhado.
enum LouvorDataSource {
  /// Id legado do manifest PLPCG: Base64 de `<classificacao>/<arquivo>.pdf`.
  /// Tem `shortId`; abre pela URL absoluta do campo `pdf`.
  plpcg,

  /// Id nativo Coldigom: Base64 de `assets/praises/<praise>/<material>.<ext>`.
  coldigom,
}
```

- [ ] **Step 5: DTO**

Em `lib/features/catalog/data/models/louvor_dto.dart`:

1. Construtor: depois de `this.shortId,` adicionar `this.praiseId,` e `this.materialId,`; campos:

```dart
  /// Id do praise coldigom; `null` no catálogo antigo.
  final String? praiseId;

  /// Id do material coldigom; `null` no catálogo antigo.
  final String? materialId;
```

2. `fromJson`: adicionar `praiseId: _nonEmptyString(json['praiseId']), materialId: _nonEmptyString(json['materialId']),` e a função privada de topo:

```dart
/// `String` não vazia (após `trim`) ou `null` — o manifest só deve mandar
/// string, mas o parser não quebra com outro tipo.
String? _nonEmptyString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
```

3. `toEntity`: passar `praiseId: praiseId, materialId: materialId,`.
4. Doc da classe: «Shape idêntico ao JSON de `/api/plpcg/manifest` (coldigom) — `praiseId`/`materialId` presentes; o JSON legado do Worker `plpcg-catalog` os omitia.»

- [ ] **Step 6: Isar + mapper**

Em `lib/core/database/collections/louvor_cache.dart`, depois de `String? shortId;`:

```dart
  /// Id do praise coldigom — espelha [Louvor.praiseId]; `null` antes do
  /// primeiro sync do manifest servido pelo coldigom.
  String? praiseId;

  /// Id do material coldigom — espelha [Louvor.materialId].
  String? materialId;
```

Regenerar o schema: `dart run build_runner build --delete-conflicting-outputs` (gera `louvor_cache.g.dart`; commitar o gerado, como em 0f0ec0dc).

Em `lib/features/catalog/data/mappers/louvor_cache_mapper.dart`: `toCache()` ganha `..praiseId = praiseId ..materialId = materialId`; `toEntity()` passa `praiseId: praiseId, materialId: materialId,`.

- [ ] **Step 7: `_isSameManifest` e adapter**

Em `catalog_repository_impl.dart`, na comparação de `_isSameManifest`, adicionar antes de `a.shortId != b.shortId`:

```dart
          a.praiseId != b.praiseId ||
          a.materialId != b.materialId ||
```

Em `lib/features/coldigom/data/adapters/coldigom_louvor_adapter.dart`, `toLouvores`, no `Louvor.fromManifest(...)` adicionar `praiseId: praise.id, materialId: material.id,`.

- [ ] **Step 8: Testes complementares**

Em `test/unit/features/coldigom/coldigom_louvor_adapter_test.dart` adicionar ao `main`:

```dart
  test('toLouvores preenche praiseId e materialId do praise', () {
    const praise = PraiseDetailDto(
      id: 'praise-1',
      name: 'Comigo habita',
      number: '692',
      rhythm: 'Balada',
      materials: [
        MaterialDto(
          id: 'mat-1',
          type: 'pdf',
          r2Key: 'assets/praises/outro-praise/mat-1.pdf',
        ),
      ],
    );

    final louvor = ColdigomLouvorAdapter.toLouvores(praise).single;

    expect(louvor.praiseId, 'praise-1');
    expect(louvor.materialId, 'mat-1');
    // O r2Key pode estar na pasta de outro praise (material movido): a
    // identidade do grupo é o praiseId, não o path.
    expect(louvor.effectiveGroupId, 'praise-1');
  });
```

(Se o ficheiro não importar `PraiseDetailDto`/`MaterialDto`, importar `package:coldigui/features/coldigom/data/models/praise_dto.dart`.)

Em `test/unit/features/catalog/catalog_repository_impl_test.dart`, o helper `_louvor` ganha `String? praiseId` repassado a `Louvor.fromManifest(..., praiseId: praiseId)`, e adicionar o teste (dentro do `group` de sync existente, usando o mesmo padrão de container/`_TestRemote` dos vizinhos — copiar o teste «manifest idêntico ao cache — gravação evitada» e alterar):

```dart
  test('manifest com praiseId novo não é considerado idêntico ao cache', () async {
    final remote = _TestRemote(louvores: [_louvor('a', praiseId: 'p-a')]);
    final local = _TestLocal()..store.add(_louvor('a'));
    final prefs = await SharedPreferences.getInstance();
    final repo = _repo(remote: remote, local: local, prefs: prefs);

    final outcome = await repo.syncManifest();

    expect(outcome.cacheReplaced, isTrue);
    expect(local.store.single.praiseId, 'p-a');
  });
```

(`_TestRemote`, `_TestLocal` e `_repo` já existem no ficheiro; `_TestLocal.store` é a lista que `saveLouvores` substitui.)

- [ ] **Step 9: Correr tudo o que toca `Louvor`**

Run: `flutter test test/unit/features/catalog/ test/unit/features/coldigom/ && flutter analyze`
Expected: PASS (fixtures antigas caem no `groupId` — nada muda para elas).

- [ ] **Step 10: Commit**

```bash
git add lib/features/catalog/domain/entities/louvor.dart lib/features/catalog/domain/entities/louvor_data_source.dart lib/features/catalog/data/models/louvor_dto.dart lib/core/database/collections/louvor_cache.dart lib/core/database/collections/louvor_cache.g.dart lib/features/catalog/data/mappers/louvor_cache_mapper.dart lib/features/catalog/data/repositories/catalog_repository_impl.dart lib/features/coldigom/data/adapters/coldigom_louvor_adapter.dart test/unit/features/catalog/louvor_praise_id_test.dart test/unit/features/coldigom/coldigom_louvor_adapter_test.dart test/unit/features/catalog/catalog_repository_impl_test.dart
git commit -m "feat(catalog): praiseId/materialId no Louvor, DTO e cache Isar; effectiveGroupId por praise

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Unidade 3 — Endpoints e transporte

### Task 3: Manifest e checksum pelo coldigom

**Files:**
- Modify: `lib/features/coldigom/data/constants/coldigom_endpoints.dart`
- Modify: `lib/core/constants/api_endpoints.dart`
- Modify: `lib/features/catalog/data/datasources/catalog_remote_datasource.dart`
- Modify: `lib/features/catalog/data/providers/catalog_providers.dart`
- Test: `test/unit/features/catalog/catalog_remote_datasource_test.dart` (novo)

**Interfaces:**
- Produces: `ColdigomEndpoints.plpcgManifest = '/api/plpcg/manifest'`, `ColdigomEndpoints.plpcgManifestChecksum = '/api/plpcg/manifest/checksum'`; `catalogRemoteDatasourceProvider` construído com `coldigomDioProvider`.
- Remove: `ApiEndpoints.louvoresManifest`, `.louvoresManifestChecksum`, `.uploadLouvor`, `.assetsPdf`, `.packagesZip` (sem chamador). `ApiEndpoints.offlineManifest` sai na Task 13.

- [ ] **Step 1: Teste do datasource**

```dart
// test/unit/features/catalog/catalog_remote_datasource_test.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:coldigui/features/catalog/data/datasources/catalog_remote_datasource.dart';
import 'package:coldigui/features/coldigom/data/constants/coldigom_endpoints.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adapter fixo: devolve [statusCode] + [body] e guarda a última request.
class _FixedAdapter implements HttpClientAdapter {
  _FixedAdapter(this.statusCode, this.body, {this.etag, this.json = true});

  final int statusCode;
  final String body;
  final String? etag;
  final bool json;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [
          json ? Headers.jsonContentType : 'text/plain',
        ],
        if (etag != null) 'etag': [etag!],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _entry = {
  'nome': 'A Ti Senhor',
  'classificacao': 'Avulsos, GLTM',
  'numero': '',
  'categoria': 'Partitura',
  'pdf': 'https://coldigom.test/assets/praises/p1/m1.pdf',
  'pdfId': 'MzAxMDIwMjUvQSBUaSBTZW5ob3IucGRm',
  'groupId': 'avulso:a-ti-senhor',
  'shortId': '000b',
  'praiseId': 'p1',
  'materialId': 'm1',
};

CatalogRemoteDatasource _datasource(_FixedAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://coldigom.test'))
    ..httpClientAdapter = adapter;
  return CatalogRemoteDatasource(dio);
}

void main() {
  test('manifest: GET /api/plpcg/manifest, parse praiseId e ETag sem aspas',
      () async {
    final adapter = _FixedAdapter(
      200,
      jsonEncode([_entry, {..._entry, 'pdfId': ''}]),
      etag: '"abc123"',
    );

    final result = await _datasource(adapter).fetchManifestConditional();

    expect(adapter.lastRequest!.path, ColdigomEndpoints.plpcgManifest);
    expect(adapter.lastRequest!.headers.containsKey('If-None-Match'), isFalse);
    expect(result.etag, 'abc123');
    expect(result.louvores, hasLength(1), reason: 'entrada sem pdfId cai fora');
    final louvor = result.louvores!.single;
    expect(louvor.praiseId, 'p1');
    expect(louvor.materialId, 'm1');
    expect(louvor.pdf, 'https://coldigom.test/assets/praises/p1/m1.pdf');
    expect(louvor.shortId, '000b');
  });

  test('manifest: If-None-Match com aspas e 304 → notModified', () async {
    final adapter = _FixedAdapter(304, '');

    final result =
        await _datasource(adapter).fetchManifestConditional(ifNoneMatch: 'abc');

    expect(adapter.lastRequest!.headers['If-None-Match'], '"abc"');
    expect(result.louvores, isNull);
  });

  test('checksum: GET /api/plpcg/manifest/checksum devolve changed com hex',
      () async {
    final adapter = _FixedAdapter(200, 'deadbeef\n', json: false);

    final result = await _datasource(adapter).fetchChecksumConditional();

    expect(adapter.lastRequest!.path, ColdigomEndpoints.plpcgManifestChecksum);
    expect(result.status, ManifestChecksumStatus.changed);
    expect(result.checksum, 'deadbeef');
  });

  test('checksum: 204 com If-None-Match → unchanged', () async {
    final adapter = _FixedAdapter(204, '', json: false);

    final result = await _datasource(adapter)
        .fetchChecksumConditional(ifNoneMatch: 'deadbeef');

    expect(adapter.lastRequest!.headers['If-None-Match'], '"deadbeef"');
    expect(result.isUnchanged, isTrue);
  });

  test('checksum: falha de rede → unavailable, sem lançar', () async {
    final adapter = _FixedAdapter(500, 'boom', json: false);

    final result = await _datasource(adapter).fetchChecksumConditional();

    expect(result.status, ManifestChecksumStatus.unavailable);
  });
}
```

- [ ] **Step 1b: Fixture com o shape real (spec §8)**

Criar `test/fixtures/manifest_coldigom_sample.json` com seis entradas no shape de `/api/plpcg/manifest` (copiar o shape de `_entry` acima): praise `pf` com dois `materialId` distintos (`mp`, `mc`) e **um `materialId` repetido** (`mp` em dois `pdfId` legados diferentes, F4); praise `pd` cujo `groupId` legado é o mesmo de uma entrada de `pf` (um praise em dois grupos legados, F3); e uma entrada sem `praiseId`/`materialId` (cache antigo). Todas com `pdf` absoluto `https://coldigom.test/assets/praises/<pasta>/<materialId>.pdf`, e uma delas com `<pasta>` ≠ `praiseId` (material movido).

Acrescentar ao teste:

```dart
  test('fixture real: entradas duplicadas e sem praiseId passam pelo parser', () async {
    final adapter = _FixedAdapter(
      200,
      File('test/fixtures/manifest_coldigom_sample.json').readAsStringSync(),
    );

    final result = await _datasource(adapter).fetchManifestConditional();

    final louvores = result.louvores!;
    expect(louvores, hasLength(6));
    expect(louvores.where((l) => l.materialId == 'mp'), hasLength(2));
    expect(louvores.where((l) => l.praiseId == null), hasLength(1));
    expect(louvores.map((l) => l.effectiveGroupId).toSet(), contains('pf'));
  });
```

(`import 'dart:io';`.)

- [ ] **Step 2: Correr e ver falhar**

Run: `flutter test test/unit/features/catalog/catalog_remote_datasource_test.dart`
Expected: FAIL — `ColdigomEndpoints.plpcgManifest` não existe / path errado.

- [ ] **Step 3: Endpoints**

Em `coldigom_endpoints.dart`, depois de `plpcgCatalog`:

```dart
  /// Catálogo PLPCG no shape do manifest (`pdfId`/`groupId`/`shortId`
  /// legados + `praiseId`/`materialId`; `pdf` absoluto). ETag + 304.
  static const plpcgManifest = '/api/plpcg/manifest';

  /// Hex SHA-256 de [plpcgManifest]; `If-None-Match` → 204.
  static const plpcgManifestChecksum = '/api/plpcg/manifest/checksum';
```

Em `api_endpoints.dart`: apagar `louvoresManifest`, `louvoresManifestChecksum` (com os docs), e as quatro linhas finais `offlineManifest`, `uploadLouvor`, `assetsPdf`, `packagesZip` — **exceto** `offlineManifest`, que ainda tem chamador até a Task 13 (deixar só ela). Doc da classe: «Endpoints HTTP do Worker `plpcg-catalog` (auth, social, playlists, flags, links, live). Catálogo e assets vivem em `ColdigomEndpoints`.»

- [ ] **Step 4: Datasource**

Em `catalog_remote_datasource.dart`:
- Trocar `import '../../../../core/constants/api_endpoints.dart';` e `import '../../../../core/constants/app_config.dart';` por `import '../../../coldigom/data/constants/coldigom_endpoints.dart';`.
- Apagar o bloco `if (AppConfig.apiBaseUrl.isEmpty) { throw StateError(...); }`.
- `ApiEndpoints.louvoresManifest` → `ColdigomEndpoints.plpcgManifest`; `ApiEndpoints.louvoresManifestChecksum` → `ColdigomEndpoints.plpcgManifestChecksum`.
- Docs: substituir toda menção a `/api/catalog/louvores` por `/api/plpcg/manifest`, `/api/catalog/checksum` por `/api/plpcg/manifest/checksum`, «Worker + D1» por «coldigom»; a doc da classe: «Fonte remota do catálogo — coldigom `GET /api/plpcg/manifest` (UC-12). Mesmo contrato condicional (`If-None-Match` → 304/204) do antigo Worker `plpcg-catalog`.»

Em `catalog_providers.dart`: trocar `import '../../../../core/providers/dio_provider.dart';` por `import '../../../coldigom/data/providers/coldigom_dio_provider.dart';` e `CatalogRemoteDatasource(ref.watch(dioProvider))` por `CatalogRemoteDatasource(ref.watch(coldigomDioProvider))`; doc: «Cliente remoto do catálogo (manifest + checksum) — Dio do coldigom, só `RetryInterceptor`.»

- [ ] **Step 5: Correr + analyze**

Run: `flutter test test/unit/features/catalog/ && flutter analyze`
Expected: PASS. Se `flutter analyze` acusar import de `app_config.dart` sem uso em `app_config.dart`-dependentes, remover.

- [ ] **Step 6: Commit**

```bash
git add lib/features/coldigom/data/constants/coldigom_endpoints.dart lib/core/constants/api_endpoints.dart lib/features/catalog/data/datasources/catalog_remote_datasource.dart lib/features/catalog/data/providers/catalog_providers.dart test/unit/features/catalog/catalog_remote_datasource_test.dart test/fixtures/manifest_coldigom_sample.json
git commit -m "feat(catalog): manifest e checksum vêm do coldigom (/api/plpcg/manifest)

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Unidade 4 — URL do PDF

### Task 4: PDF pela URL absoluta do manifest (leitor e UC-10)

**Files:**
- Modify: `lib/features/pdf_opening/domain/utils/louvor_pdf_path.dart`
- Modify: `lib/features/catalog/data/datasources/catalog_local_datasource.dart`
- Modify: `lib/features/offline/domain/usecases/download_missing_pdfs.dart`
- Test: `test/unit/features/pdf_opening/louvor_pdf_path_test.dart`, `test/unit/features/offline/download_missing_pdfs_test.dart`

**Interfaces:**
- Produces: `LouvorPdfPath.remotePath({required String pdf, required String pdfId})`; `LouvorPdfPath.fromLouvor(louvor)` = `remotePath(pdf: louvor.pdf, pdfId: louvor.pdfId)`; `CatalogLocalDatasource.loadPdfIdToPdfMap()` → `Future<Map<String, String>>` (pdfId → `pdf`).
- Consumers já existentes de `fromLouvor` (leitor, prefetch, «baixar de novo») não mudam.

- [ ] **Step 1: Testes**

Acrescentar a `test/unit/features/pdf_opening/louvor_pdf_path_test.dart` (dentro de `main`):

```dart
  test('pdf absoluto (manifest coldigom) vence a derivação por pdfId', () {
    final louvor = Louvor.fromManifest(
      nome: 'Teste',
      numero: '001',
      categoria: 'Partitura',
      classificacao: 'ColAdultos',
      pdf: 'https://coldigom.test/assets/praises/p1/m1.pdf',
      pdfId: _encodePdfId('ColAdultos/001.pdf'),
    );

    expect(
      LouvorPdfPath.fromLouvor(louvor),
      'https://coldigom.test/assets/praises/p1/m1.pdf',
    );
  });

  test('pdf só com nome de ficheiro continua na derivação legada', () {
    final louvor = _louvorWithPdfId('ColAdultos/001.pdf'); // pdf: '001.pdf'
    expect(LouvorPdfPath.fromLouvor(louvor), '/assets/ColAdultos/001.pdf');
  });

  test('remotePath aceita http e ignora espaços à volta', () {
    expect(
      LouvorPdfPath.remotePath(pdf: ' http://x/a.pdf ', pdfId: 'ignored'),
      'http://x/a.pdf',
    );
  });
```

Em `test/unit/features/offline/download_missing_pdfs_test.dart`: `_seedCatalogLouvor` ganha `String pdf = '001.pdf'` e grava `..pdf = pdf`; `_FakePdfBytesDatasource` passa a guardar `final paths = <String>[];` e faz `paths.add(filePath);` em `fetchBytes`. Adicionar teste (mesmo setup dos vizinhos — copiar o de «baixa apenas PDFs ausentes no índice» para obter `isar`, `repo`, `useCase`):

```dart
  test('usa a URL absoluta do campo pdf quando o catálogo a tem', () async {
    // setup igual ao teste "baixa apenas PDFs ausentes no índice"
    await _seedCatalogLouvor(
      isar,
      pdfId: encodePdfId('ColAdultos/001.pdf'),
      pdf: 'https://coldigom.test/assets/praises/p1/m1.pdf',
    );
    await _seedCatalogLouvor(isar, pdfId: encodePdfId('ColAdultos/002.pdf'));

    await useCase();

    expect(
      fakeBytes.paths,
      unorderedEquals([
        'https://coldigom.test/assets/praises/p1/m1.pdf',
        '/assets/ColAdultos/002.pdf',
      ]),
    );
  });
```

- [ ] **Step 2: Correr e ver falhar**

Run: `flutter test test/unit/features/pdf_opening/louvor_pdf_path_test.dart test/unit/features/offline/download_missing_pdfs_test.dart`
Expected: FAIL (`remotePath` não existe; UC-10 pede `/assets/ColAdultos/001.pdf`).

- [ ] **Step 3: `LouvorPdfPath`**

Substituir o conteúdo de `louvor_pdf_path.dart`:

```dart
import '../../../../core/utils/pdf_path_normalizer.dart';
import '../../../catalog/domain/entities/louvor.dart';

/// Path/URL remoto do PDF de um [Louvor] para [PdfSourceResolver] (UC-04).
abstract final class LouvorPdfPath {
  /// URL absoluta do manifest (`pdf` começa por `http(s)://`) ou, senão,
  /// `/assets/...` derivado do [Louvor.pdfId].
  static String fromLouvor(Louvor louvor) =>
      remotePath(pdf: louvor.pdf, pdfId: louvor.pdfId);

  /// [pdf] absoluto vence; caso contrário deriva de [pdfId].
  ///
  /// O manifest servido pelo coldigom traz `pdf` absoluto
  /// (`https://coldigom-api…/assets/praises/<praise>/<material>.pdf`). O
  /// fallback cobre o cache Isar anterior ao primeiro sync, fixtures e os
  /// materiais Coldigom nativos (`pdf` é só o nome do ficheiro): aí o path
  /// `/assets/...` passa por [AssetBaseUrlResolver], que escolhe a base pelo
  /// prefixo `assets/praises/`.
  static String remotePath({required String pdf, required String pdfId}) {
    final trimmed = pdf.trim();
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('https://') || lower.startsWith('http://')) {
      return trimmed;
    }
    var relPath = PdfPathNormalizer.getPdfRelPath(pdfId);
    if (!relPath.startsWith('assets/')) {
      relPath = 'assets/$relPath';
    }
    return '/$relPath';
  }
}
```

- [ ] **Step 4: Datasource local + UC-10**

Em `catalog_local_datasource.dart`, depois de `loadPdfIdToCategoriaMap`:

```dart
  /// Mapa pdfId → [Louvor.pdf] (URL absoluta no manifest servido pelo
  /// coldigom) para o download em massa (UC-09/UC-10).
  Future<Map<String, String>> loadPdfIdToPdfMap() async {
    final isar = _isar;
    if (isar == null) return const {};
    final caches = isar.louvorCaches.where().findAll();
    return {for (final cache in caches) cache.pdfId: cache.pdf};
  }
```

Em `download_missing_pdfs.dart`:
- trocar `import '../../../../core/utils/pdf_path_normalizer.dart';` por `import '../../../pdf_opening/domain/utils/louvor_pdf_path.dart';`
- em `call`, logo após `final allPdfIds = await _collectPdfIds(materialCategories);` adicionar `final pdfById = await _catalogLocal.loadPdfIdToPdfMap();`
- no worker: `remotePath: LouvorPdfPath.remotePath(pdf: pdfById[pdfId] ?? '', pdfId: pdfId),`
- apagar `_remotePathFromPdfId`.
- Doc da classe: acrescentar «O PDF vem da URL absoluta do manifest (`LouvorCache.pdf`); sem ela cai no path legado `/assets/...`.»

- [ ] **Step 5: Correr + analyze**

Run: `flutter test test/unit/features/pdf_opening/ test/unit/features/offline/download_missing_pdfs_test.dart test/unit/features/offline/get_offline_stats_by_category_test.dart test/unit/features/offline/clear_offline_cache_test.dart && flutter analyze`
Expected: PASS. (Fakes que estendem `CatalogLocalDatasource` herdam `loadPdfIdToPdfMap` de `.unavailable()` → `{}`.)

- [ ] **Step 6: Commit**

```bash
git add lib/features/pdf_opening/domain/utils/louvor_pdf_path.dart lib/features/catalog/data/datasources/catalog_local_datasource.dart lib/features/offline/domain/usecases/download_missing_pdfs.dart test/unit/features/pdf_opening/louvor_pdf_path_test.dart test/unit/features/offline/download_missing_pdfs_test.dart
git commit -m "feat(pdf): PDF abre pela URL absoluta do manifest; UC-10 idem

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Unidade 5 — Aliases e fusão

### Task 5: `ManifestMaterialAliases` + providers `manifestMaterialAliasesProvider` e `knownPraiseIdsProvider`

**Files:**
- Create: `lib/features/catalog/domain/utils/coldigom_pdf_id_from_manifest_pdf.dart`
- Create: `lib/features/catalog/domain/entities/manifest_material_aliases.dart`
- Create: `lib/features/catalog/presentation/providers/manifest_material_aliases_provider.dart`
- Create: `lib/features/catalog/presentation/providers/known_praise_ids_provider.dart`
- Test: `test/unit/features/catalog/manifest_material_aliases_test.dart`, `test/unit/features/catalog/known_praise_ids_provider_test.dart`

**Interfaces:**
- Produces:
  - `String? coldigomPdfIdFromManifestPdf(String pdf)` — `encodePdfId('assets/praises/…')` extraído da URL; `null` se a URL não contém `/assets/praises/`.
  - `class ManifestMaterialAliases { Set<String> praiseIds; Map<String, Louvor> byMaterialId; Map<String, String> legacyPdfIdByColdigomPdfId; static const empty; factory fromLouvores(List<Louvor>) }`.
  - `manifestMaterialAliasesProvider: Provider<ManifestMaterialAliases>` (observa só `louvoresManifestProvider.select(louvores)`).
  - `knownPraiseIdsProvider: Provider<Set<String>>` = `coldigomSearchIndexProvider.catalogIds ∪ aliases.praiseIds`.

- [ ] **Step 1: Testes**

```dart
// test/unit/features/catalog/manifest_material_aliases_test.dart
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/catalog/domain/entities/manifest_material_aliases.dart';
import 'package:coldigui/features/catalog/domain/utils/coldigom_pdf_id_from_manifest_pdf.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvores_manifest_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/manifest_material_aliases_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/louvores_manifest_test_helpers.dart';

Louvor _louvor(
  String pdfId, {
  String? praiseId,
  String? materialId,
  String pdf = '001.pdf',
}) => Louvor.fromManifest(
  nome: 'L $pdfId',
  numero: '001',
  categoria: 'Partitura',
  classificacao: 'ColAdultos',
  pdf: pdf,
  pdfId: pdfId,
  praiseId: praiseId,
  materialId: materialId,
);

void main() {
  group('coldigomPdfIdFromManifestPdf', () {
    test('extrai o r2Key da URL absoluta e codifica como o adapter', () {
      expect(
        coldigomPdfIdFromManifestPdf(
          'https://coldigom.test/assets/praises/outro-praise/m1.pdf',
        ),
        encodePdfId('assets/praises/outro-praise/m1.pdf'),
      );
    });

    test('null sem /assets/praises/ (nome de ficheiro ou URL estranha)', () {
      expect(coldigomPdfIdFromManifestPdf('001.pdf'), isNull);
      expect(coldigomPdfIdFromManifestPdf('https://x/assets/PES/a.pdf'), isNull);
      expect(coldigomPdfIdFromManifestPdf(''), isNull);
    });
  });

  group('ManifestMaterialAliases.fromLouvores', () {
    test('indexa praiseIds, materialId e alias coldigom → legado', () {
      final a = _louvor(
        'legado-a',
        praiseId: 'p1',
        materialId: 'm1',
        pdf: 'https://coldigom.test/assets/praises/p1/m1.pdf',
      );
      final b = _louvor(
        'legado-b',
        praiseId: 'p2',
        materialId: 'm2',
        // r2Key na pasta de outro praise (material movido): o alias sai da
        // URL, não do praiseId.
        pdf: 'https://coldigom.test/assets/praises/p9/m2.pdf',
      );
      final semPraise = _louvor('legado-c');

      final aliases = ManifestMaterialAliases.fromLouvores([a, b, semPraise]);

      expect(aliases.praiseIds, {'p1', 'p2'});
      expect(aliases.byMaterialId['m1'], same(a));
      expect(aliases.byMaterialId['m2'], same(b));
      expect(
        aliases.legacyPdfIdByColdigomPdfId,
        {
          encodePdfId('assets/praises/p1/m1.pdf'): 'legado-a',
          encodePdfId('assets/praises/p9/m2.pdf'): 'legado-b',
        },
      );
    });

    test('materialId repetido fica com a primeira ocorrência (F4)', () {
      final primeiro = _louvor(
        'legado-1',
        praiseId: 'p1',
        materialId: 'm1',
        pdf: 'https://coldigom.test/assets/praises/p1/m1.pdf',
      );
      final segundo = _louvor(
        'legado-2',
        praiseId: 'p1',
        materialId: 'm1',
        pdf: 'https://coldigom.test/assets/praises/p1/m1.pdf',
      );

      final aliases = ManifestMaterialAliases.fromLouvores([primeiro, segundo]);

      expect(aliases.byMaterialId['m1'], same(primeiro));
      expect(
        aliases.legacyPdfIdByColdigomPdfId[encodePdfId('assets/praises/p1/m1.pdf')],
        'legado-1',
      );
    });

    test('vazio sem praiseId em nenhuma entrada', () {
      final aliases = ManifestMaterialAliases.fromLouvores([_louvor('x')]);
      expect(aliases.praiseIds, isEmpty);
      expect(aliases.byMaterialId, isEmpty);
      expect(aliases.legacyPdfIdByColdigomPdfId, isEmpty);
    });
  });

  group('manifestMaterialAliasesProvider', () {
    test('constrói uma vez por manifest', () async {
      final container = ProviderContainer(
        overrides: [
          louvoresManifestOverride(
            LouvoresManifest.fromLouvores([
              _louvor(
                'legado-a',
                praiseId: 'p1',
                materialId: 'm1',
                pdf: 'https://coldigom.test/assets/praises/p1/m1.pdf',
              ),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(louvoresManifestProvider.future);

      final first = container.read(manifestMaterialAliasesProvider);
      expect(first.praiseIds, {'p1'});
      expect(identical(first, container.read(manifestMaterialAliasesProvider)), isTrue);
    });

    test('empty enquanto o manifest não carregou', () {
      final container = ProviderContainer(
        overrides: [louvoresManifestLoadingOverride()],
      );
      addTearDown(container.dispose);
      expect(
        identical(
          container.read(manifestMaterialAliasesProvider),
          ManifestMaterialAliases.empty,
        ),
        isTrue,
      );
    });
  });
}
```

```dart
// test/unit/features/catalog/known_praise_ids_provider_test.dart
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/catalog/presentation/providers/known_praise_ids_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvores_manifest_provider.dart';
import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/louvores_manifest_test_helpers.dart';

void main() {
  test('união dos ids do índice Coldigom com os praises do manifest', () async {
    final container = ProviderContainer(
      overrides: [
        louvoresManifestOverride(
          LouvoresManifest.fromLouvores([
            Louvor.fromManifest(
              nome: 'A',
              numero: '001',
              categoria: 'Partitura',
              classificacao: 'ColAdultos',
              pdf: 'https://coldigom.test/assets/praises/p-manifest/m.pdf',
              pdfId: 'legado',
              praiseId: 'p-manifest',
              materialId: 'm',
            ),
          ]),
        ),
        coldigomSearchIndexProvider.overrideWithValue(
          ColdigomSearchIndex.build(const [], catalogIds: {'p-index'}),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(louvoresManifestProvider.future);

    expect(container.read(knownPraiseIdsProvider), {'p-index', 'p-manifest'});
  });
}
```

(`ColdigomSearchIndex.build(List<ColdigomIndexedPraise> entries, {Set<String>? catalogIds})` — com `entries` vazio e `catalogIds` preenchido o índice fica só com `catalogIds`.)

- [ ] **Step 2: Correr e ver falhar**

Run: `flutter test test/unit/features/catalog/manifest_material_aliases_test.dart test/unit/features/catalog/known_praise_ids_provider_test.dart`
Expected: FAIL — ficheiros não existem.

- [ ] **Step 3: Utilitário do alias**

```dart
// lib/features/catalog/domain/utils/coldigom_pdf_id_from_manifest_pdf.dart
import '../../../../core/utils/pdf_id_codec.dart';

const _praisesPrefix = '/assets/praises/';

/// Id Coldigom nativo do PDF que o manifest aponta em [pdf] (URL absoluta
/// `https://…/assets/praises/<praise>/<material>.pdf`).
///
/// É `encodePdfId(r2Key)` — o mesmo id que `ColdigomLouvorAdapter` cunha para
/// o material —, com o `r2Key` lido da URL e **não** montado a partir de
/// `praiseId`/`materialId`: 64 entradas do manifest (e 1473 PDFs do coldigom)
/// vivem na pasta de outro praise (material movido) e só a URL diz o path real.
///
/// `null` quando [pdf] não contém `/assets/praises/` (nome de ficheiro, cache
/// antigo, fixtures).
String? coldigomPdfIdFromManifestPdf(String pdf) {
  final index = pdf.indexOf(_praisesPrefix);
  if (index < 0) return null;
  final r2Key = pdf.substring(index + 1); // sem a barra inicial
  final rest = r2Key.substring('assets/praises/'.length);
  if (rest.isEmpty || !rest.contains('/')) return null;
  return encodePdfId(Uri.decodeComponent(r2Key));
}
```

(`Uri.decodeComponent` cobre URL com `%20`; os ids do coldigom são UUIDs, então na prática é identidade. Se `decodeComponent` lançar por `%` inválido, devolver `null`: envolver em `try { … } on ArgumentError { return null; }`.)

- [ ] **Step 4: Entidade de aliases**

```dart
// lib/features/catalog/domain/entities/manifest_material_aliases.dart
import '../utils/coldigom_pdf_id_from_manifest_pdf.dart';
import 'louvor.dart';

/// Índices do manifest que ligam o espaço de ids legado ao Coldigom.
///
/// Construído **uma vez por manifest** (`manifestMaterialAliasesProvider`).
/// Vazio ([empty]) enquanto o manifest não tem `praiseId` — cache anterior à
/// migração ou ainda a carregar —, e nesse caso o composite se comporta como
/// antes da fusão.
final class ManifestMaterialAliases {
  const ManifestMaterialAliases({
    required this.praiseIds,
    required this.byMaterialId,
    required this.legacyPdfIdByColdigomPdfId,
  });

  static const empty = ManifestMaterialAliases(
    praiseIds: {},
    byMaterialId: {},
    legacyPdfIdByColdigomPdfId: {},
  );

  /// Praises cobertos pelo manifest — «um card por praise» (spec D3).
  final Set<String> praiseIds;

  /// `materialId` Coldigom → entrada do manifest (primeira ocorrência: dois
  /// `pdfId` legados podem apontar o mesmo ficheiro, F4).
  final Map<String, Louvor> byMaterialId;

  /// Id Coldigom nativo (`encodePdfId('assets/praises/…')`) → `pdfId` legado.
  /// É por aqui que uma playlist recente com ids Coldigom de materiais
  /// cobertos continua a abrir sem rede (spec D4/§7).
  final Map<String, String> legacyPdfIdByColdigomPdfId;

  bool get isEmpty => praiseIds.isEmpty;

  /// `true` quando [groupId] é um praise coberto pelo manifest.
  bool coversPraise(String groupId) => praiseIds.contains(groupId);

  /// `true` quando [coldigomPdfId] é um PDF que o manifest também lista.
  bool coversColdigomPdf(String coldigomPdfId) =>
      legacyPdfIdByColdigomPdfId.containsKey(coldigomPdfId);

  factory ManifestMaterialAliases.fromLouvores(List<Louvor> louvores) {
    final praiseIds = <String>{};
    final byMaterialId = <String, Louvor>{};
    final legacyByColdigom = <String, String>{};
    for (final louvor in louvores) {
      final praiseId = louvor.praiseId;
      if (praiseId == null) continue;
      praiseIds.add(praiseId);
      final materialId = louvor.materialId;
      if (materialId != null) {
        byMaterialId.putIfAbsent(materialId, () => louvor);
      }
      final coldigomPdfId = coldigomPdfIdFromManifestPdf(louvor.pdf);
      if (coldigomPdfId != null) {
        legacyByColdigom.putIfAbsent(coldigomPdfId, () => louvor.pdfId);
      }
    }
    if (praiseIds.isEmpty) return empty;
    return ManifestMaterialAliases(
      praiseIds: Set.unmodifiable(praiseIds),
      byMaterialId: Map.unmodifiable(byMaterialId),
      legacyPdfIdByColdigomPdfId: Map.unmodifiable(legacyByColdigom),
    );
  }
}
```

- [ ] **Step 5: Providers**

```dart
// lib/features/catalog/presentation/providers/manifest_material_aliases_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/manifest_material_aliases.dart';
import 'louvores_manifest_provider.dart';

/// [ManifestMaterialAliases] do manifest corrente, construído **uma vez por
/// manifest** (mesmo padrão de `pdfIdsByShortIdProvider`). [ManifestMaterialAliases.empty]
/// enquanto o manifest não carregou ou não traz `praiseId`.
final manifestMaterialAliasesProvider = Provider<ManifestMaterialAliases>((ref) {
  final louvores = ref.watch(
    louvoresManifestProvider.select((manifest) => manifest.value?.louvores),
  );
  if (louvores == null) return ManifestMaterialAliases.empty;
  return ManifestMaterialAliases.fromLouvores(louvores);
});
```

```dart
// lib/features/catalog/presentation/providers/known_praise_ids_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'manifest_material_aliases_provider.dart';

/// Praises que o app já conhece localmente: o Isar Coldigom hidratado
/// ([ColdigomSearchIndex.catalogIds]) **e** os praises do manifest.
///
/// É contra isto que a Home decide o chip «novo» e a adoção dos «novos» da
/// pesquisa remota (spec §5.4): um praise do manifest nunca é novidade e
/// nunca entra no Isar Coldigom.
final knownPraiseIdsProvider = Provider<Set<String>>((ref) {
  final index = ref.watch(coldigomSearchIndexProvider).catalogIds;
  final manifest = ref.watch(manifestMaterialAliasesProvider).praiseIds;
  if (manifest.isEmpty) return index;
  if (index.isEmpty) return manifest;
  return Set.unmodifiable({...index, ...manifest});
});
```

- [ ] **Step 6: Correr + analyze**

Run: `flutter test test/unit/features/catalog/manifest_material_aliases_test.dart test/unit/features/catalog/known_praise_ids_provider_test.dart && flutter analyze`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/catalog/domain/utils/coldigom_pdf_id_from_manifest_pdf.dart lib/features/catalog/domain/entities/manifest_material_aliases.dart lib/features/catalog/presentation/providers/manifest_material_aliases_provider.dart lib/features/catalog/presentation/providers/known_praise_ids_provider.dart test/unit/features/catalog/manifest_material_aliases_test.dart test/unit/features/catalog/known_praise_ids_provider_test.dart
git commit -m "feat(catalog): aliases do manifest (praiseIds, materialId, id Coldigom → legado) e knownPraiseIds

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

### Task 6: `ColdigomCatalogSource.partsOfGroup`

**Files:**
- Modify: `lib/features/coldigom/data/sources/coldigom_catalog_source.dart`
- Test: `test/unit/features/catalog/catalog_source_test.dart` (grupo `ColdigomCatalogSource`)

**Interfaces:**
- Produces:

```dart
final class ColdigomGroupParts {
  const ColdigomGroupParts({
    required this.pdfs, required this.audioTracks, required this.chords,
    required this.gestures, required this.youtube, this.lyrics, this.meta,
  });
  static const empty = ColdigomGroupParts(pdfs: [], audioTracks: [], chords: [], gestures: [], youtube: []);
  final List<Louvor> pdfs; final List<AudioTrack> audioTracks; final List<ChordMaterial> chords;
  final List<GestureMaterial> gestures; final List<YoutubeMaterial> youtube;
  final LyricsMaterial? lyrics; final ColdigomPraiseMetadata? meta;
  /// Sem material endereçável nem letra (YouTube sozinho não sustenta grupo).
  bool get isEmpty;
}
ColdigomGroupParts ColdigomCatalogSource.partsOfGroup(String praiseId);
```

- [ ] **Step 1: Teste**

No grupo `ColdigomCatalogSource` de `catalog_source_test.dart`, adicionar:

```dart
    test('partsOfGroup devolve os caches do praise sem montar grupo', () {
      final parts = _coldigomSource(
        youtube: {'p1': [_coldigomYoutube]},
      ).partsOfGroup('p1');

      expect(parts.pdfs.single.pdfId, _coldigomPdfId);
      expect(parts.chords.single.chordId, _coldigomChordId);
      expect(parts.audioTracks.single.audioId, _coldigomAudioId);
      expect(parts.youtube.single.id, 'yt-1');
      expect(parts.lyrics, isNull);
      expect(parts.meta, isNull);
      expect(parts.isEmpty, isFalse);
    });

    test('partsOfGroup de praise desconhecido é empty', () {
      final parts = _coldigomSource().partsOfGroup('nope');
      expect(parts.isEmpty, isTrue);
      expect(_coldigomSource().partsOfGroup('').isEmpty, isTrue);
    });
```

- [ ] **Step 2: Correr e ver falhar**

Run: `flutter test test/unit/features/catalog/catalog_source_test.dart`
Expected: FAIL — `partsOfGroup` não existe.

- [ ] **Step 3: Implementar e reusar em `findGroupById`**

Em `coldigom_catalog_source.dart`, antes da classe `ColdigomCatalogSource`:

```dart
/// Tudo o que os caches Coldigom têm de um praise, por tipo — o insumo que
/// o `CompositeCatalogSource` funde com os PDFs do manifest (spec §5.1).
final class ColdigomGroupParts {
  const ColdigomGroupParts({
    required this.pdfs,
    required this.audioTracks,
    required this.chords,
    required this.gestures,
    required this.youtube,
    this.lyrics,
    this.meta,
  });

  static const empty = ColdigomGroupParts(
    pdfs: [],
    audioTracks: [],
    chords: [],
    gestures: [],
    youtube: [],
  );

  final List<Louvor> pdfs;
  final List<AudioTrack> audioTracks;
  final List<ChordMaterial> chords;
  final List<GestureMaterial> gestures;
  final List<YoutubeMaterial> youtube;
  final LyricsMaterial? lyrics;
  final ColdigomPraiseMetadata? meta;

  /// Sem material endereçável nem letra. YouTube sozinho não sustenta um
  /// grupo (não é endereçável); a letra sustenta (`lyrics:<praiseId>`).
  bool get isEmpty =>
      pdfs.isEmpty &&
      audioTracks.isEmpty &&
      chords.isEmpty &&
      gestures.isEmpty &&
      lyrics == null;
}
```

Dentro da classe, substituir `findGroupById` por:

```dart
  /// Caches do praise [praiseId], por tipo; [ColdigomGroupParts.empty] para
  /// id vazio ou desconhecido. Nunca toca a rede.
  ColdigomGroupParts partsOfGroup(String praiseId) {
    if (praiseId.isEmpty) return ColdigomGroupParts.empty;
    return ColdigomGroupParts(
      pdfs: louvoresOfGroup(praiseId),
      audioTracks: [
        for (final track in audioTracks.values)
          if (track.groupId == praiseId) track,
      ],
      chords: [
        for (final chord in chords.values)
          if (chord.groupId == praiseId) chord,
      ],
      gestures: [
        for (final gesture in gestures.values)
          if (gesture.groupId == praiseId) gesture,
      ],
      youtube: youtube[praiseId] ?? const [],
      lyrics: lyrics[praiseId],
      meta: praiseMeta[praiseId],
    );
  }

  /// Versão síncrona de [groupById] — os caches já estão em memória.
  ///
  /// Devolve o grupo mesmo com um material só — o corte "sem alternativa" é
  /// de quem chama. Um praise só com link de YouTube continua `null`
  /// ([ColdigomGroupParts.isEmpty]).
  LouvorGroup? findGroupById(String groupId) {
    final parts = partsOfGroup(groupId);
    if (parts.isEmpty) return null;
    final groups = LouvorGroup.fromLouvores(
      parts.pdfs,
      audioTracks: parts.audioTracks,
      chordMaterials: parts.chords,
      gestureMaterials: parts.gestures,
      youtubeMaterials: parts.youtube,
      lyricsByGroupId: parts.lyrics == null ? null : {groupId: parts.lyrics!},
      coldigomMetaByGroupId: praiseMeta,
    );
    return groups.isEmpty ? null : groups.first;
  }
```

- [ ] **Step 4: Correr + analyze**

Run: `flutter test test/unit/features/catalog/catalog_source_test.dart test/unit/features/coldigom/ && flutter analyze`
Expected: PASS (comportamento de `findGroupById` inalterado).

- [ ] **Step 5: Commit**

```bash
git add lib/features/coldigom/data/sources/coldigom_catalog_source.dart test/unit/features/catalog/catalog_source_test.dart
git commit -m "refactor(coldigom): partsOfGroup expõe os caches de um praise por tipo

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

### Task 7: Fusão no `CompositeCatalogSource`

**Files:**
- Modify: `lib/features/catalog/data/sources/composite_catalog_source.dart`
- Modify: `lib/features/catalog/data/providers/catalog_source_provider.dart`
- Test: `test/unit/features/catalog/catalog_source_test.dart` (grupo `CompositeCatalogSource`)

**Interfaces:**
- Produces:
  - `CompositeCatalogSource({required PlpcgCatalogSource plpcg, required ColdigomCatalogSource coldigom, ManifestMaterialAliases aliases = ManifestMaterialAliases.empty})` (campos agora concretos).
  - Síncronos: `LouvorGroup? findGroupById(String)`, `LouvorGroup? findGroupForMaterial(String)`, `CatalogMaterial? findMaterialById(String)`.
  - Função de topo `List<LouvorGroup> mergeLocalSearchResults({required List<LouvorGroup> plpcg, required List<LouvorGroup> coldigom, required Set<String> manifestPraiseIds})`.
  - `compositeCatalogSourceProvider: Provider<CompositeCatalogSource>`; `catalogSourceProvider: Provider<CatalogSource>` passa a devolvê-lo.
- Consumes: `ManifestMaterialAliases` (Task 5), `ColdigomCatalogSource.partsOfGroup` (Task 6), `PlpcgCatalogSource.louvoresOfGroup/findGroupById/findMaterialById/findGroupForMaterial`.

- [ ] **Step 1: Testes de fusão**

No topo de `catalog_source_test.dart` adicionar imports:
`import 'package:coldigui/features/catalog/domain/entities/manifest_material_aliases.dart';`
`import 'package:coldigui/features/catalog/presentation/providers/manifest_material_aliases_provider.dart';`
e as fixtures fundidas (depois de `_coldigomYoutube`):

```dart
/// Praise `pf` presente no manifest (2 PDFs legados) e com extras Coldigom
/// em cache: um PDF coberto (mesmo ficheiro de `_fusedPartitura`), um PDF
/// só-coldigom e uma faixa.
const _fusedPraiseId = 'pf';
final _fusedPartituraColdigomId = encodePdfId('assets/praises/pf/mp.pdf');
final _fusedExtraPdfId = encodePdfId('assets/praises/pf/mx.pdf');
final _fusedAudioId = encodePdfId('assets/praises/pf/a.mp3');

final _fusedPartitura = Louvor.fromManifest(
  nome: 'Firme nas promessas',
  numero: '010',
  categoria: 'Partitura',
  classificacao: 'ColAdultos',
  pdf: 'https://coldigom.test/assets/praises/pf/mp.pdf',
  pdfId: encodePdfId('ColAdultos/010.pdf'),
  groupId: '010:firme-nas-promessas',
  shortId: '0010',
  praiseId: _fusedPraiseId,
  materialId: 'mp',
);

final _fusedCifra = Louvor.fromManifest(
  nome: 'Firme nas promessas',
  numero: '010',
  categoria: 'Cifra nível I',
  classificacao: 'ColAdultos',
  pdf: 'https://coldigom.test/assets/praises/pf/mc.pdf',
  pdfId: encodePdfId('ColAdultos/010-cifra.pdf'),
  groupId: '010:firme-nas-promessas',
  praiseId: _fusedPraiseId,
  materialId: 'mc',
);

Louvor _coldigomLouvor(String pdfId, String pdf, String categoria) =>
    Louvor.fromManifest(
      nome: 'Firme nas promessas',
      numero: '010',
      categoria: categoria,
      classificacao: 'Balada',
      pdf: pdf,
      pdfId: pdfId,
      groupId: _fusedPraiseId,
      source: LouvorDataSource.coldigom,
      praiseId: _fusedPraiseId,
    );

final _fusedCoveredPdf =
    _coldigomLouvor(_fusedPartituraColdigomId, 'mp.pdf', 'Partitura');
final _fusedExtraPdf = _coldigomLouvor(_fusedExtraPdfId, 'mx.pdf', 'Gestos');

final _fusedTrack = AudioTrack(
  audioId: _fusedAudioId,
  r2Key: 'assets/praises/pf/a.mp3',
  nome: 'Firme nas promessas',
  numero: '010',
  groupId: _fusedPraiseId,
  categoria: 'Áudio',
  classificacao: 'Balada',
  source: LouvorDataSource.coldigom,
);

final _fusedManifest = [_plpcgPartitura, _plpcgCifra, _fusedPartitura, _fusedCifra];

CompositeCatalogSource _fusedComposite({ColdigomSearchRepository? searchRepository}) =>
    CompositeCatalogSource(
      plpcg: PlpcgCatalogSource(
        catalog: _fusedManifest,
        index: PlpcgSearchIndex.build(_fusedManifest),
      ),
      coldigom: ColdigomCatalogSource(
        louvores: {
          _coldigomPdfId: _coldigomPdf,
          _fusedPartituraColdigomId: _fusedCoveredPdf,
          _fusedExtraPdfId: _fusedExtraPdf,
        },
        chords: {_coldigomChordId: _coldigomChord},
        audioTracks: {_coldigomAudioId: _coldigomTrack, _fusedAudioId: _fusedTrack},
        searchRepository: searchRepository,
      ),
      aliases: ManifestMaterialAliases.fromLouvores(_fusedManifest),
    );
```

Novo grupo de testes (depois do grupo `CompositeCatalogSource` existente):

```dart
  group('CompositeCatalogSource — fusão por praise', () {
    test('groupById de praise do manifest funde PDFs legados, extras e áudio', () async {
      final group = await _fusedComposite().groupById(_fusedPraiseId);

      expect(group, isNotNull);
      expect(group!.groupId, _fusedPraiseId);
      final pdfIds = group.flatPdfMaterials.map((m) => m.pdfId).toList();
      expect(pdfIds, containsAll([_fusedPartitura.pdfId, _fusedCifra.pdfId, _fusedExtraPdfId]));
      expect(pdfIds, isNot(contains(_fusedPartituraColdigomId)),
          reason: 'PDF coberto pelo manifest aparece uma vez, pelo id legado');
      expect(group.audioTracks.single.audioId, _fusedAudioId);
      expect(group.totalPdfs, 3);
    });

    test('groupForMaterial resolve legado, alias Coldigom e extra para o mesmo grupo', () async {
      final source = _fusedComposite();

      final byLegacy = await source.groupForMaterial(_fusedPartitura.pdfId);
      final byAlias = await source.groupForMaterial(_fusedPartituraColdigomId);
      final byExtra = await source.groupForMaterial(_fusedExtraPdfId);
      final byAudio = await source.groupForMaterial(_fusedAudioId);

      for (final group in [byLegacy, byAlias, byExtra, byAudio]) {
        expect(group?.groupId, _fusedPraiseId);
        expect(group?.totalPdfs, 3);
      }
    });

    test('materialById: cache Coldigom primeiro, alias sem cache', () async {
      final quente = await _fusedComposite().materialById(_fusedPartituraColdigomId);
      expect((quente! as PdfMaterial).louvor.source, LouvorDataSource.coldigom);

      final frio = CompositeCatalogSource(
        plpcg: PlpcgCatalogSource(catalog: _fusedManifest),
        coldigom: const ColdigomCatalogSource(),
        aliases: ManifestMaterialAliases.fromLouvores(_fusedManifest),
      );
      final material = await frio.materialById(_fusedPartituraColdigomId);
      expect(material, isA<PdfMaterial>());
      expect((material! as PdfMaterial).louvor.pdfId, _fusedPartitura.pdfId);
      expect(await frio.groupForMaterial(_fusedPartituraColdigomId), isNotNull);
    });

    test('praise fora do manifest continua a vir do cache Coldigom', () async {
      final group = await _fusedComposite().groupById('p1');
      expect(group!.groupId, 'p1');
      expect(group.chordMaterials.single.chordId, _coldigomChordId);
    });

    test('pré-sync (sem praiseId) cai no comportamento antigo', () async {
      final source = CompositeCatalogSource(
        plpcg: _plpcgSource(),
        coldigom: _coldigomSource(),
      );
      expect((await source.groupById(_plpcgGroupId))!.totalPdfs, 2);
      expect((await source.groupForMaterial(_plpcgPdfId))!.groupId, _plpcgGroupId);
    });

    test('searchLocal mantém a ordem PLPCG e filtra grupos Coldigom cobertos', () {
      final plpcgGroups = LouvorGroup.fromLouvores([_fusedPartitura, _fusedCifra]);
      final coldigomGroups = [
        ...LouvorGroup.fromLouvores([_fusedExtraPdf]), // coberto: cai
        ...LouvorGroup.fromLouvores([_coldigomPdf]), // p1: fica
      ];

      final merged = mergeLocalSearchResults(
        plpcg: plpcgGroups,
        coldigom: coldigomGroups,
        manifestPraiseIds: {_fusedPraiseId},
      );

      expect(merged.map((g) => g.groupId).toList(), [_fusedPraiseId, 'p1']);
    });

    test('search substitui grupo remoto de praise do manifest pelo fundido', () async {
      final remoteGroup = LouvorGroup.fromLouvores(
        [_fusedCoveredPdf, _fusedExtraPdf],
        audioTracks: [_fusedTrack],
      ).single;
      final repository = _RecordingSearchRepository(
        ColdigomSearchResult(
          groups: [remoteGroup, ...LouvorGroup.fromLouvores([_coldigomPdf])],
          louvores: const [],
          page: 1,
          hasNextPage: false,
        ),
      );

      final page = await _fusedComposite(searchRepository: repository)
          .search(_query('firme'));

      expect(page.groups, hasLength(2));
      final fused = page.groups.first;
      expect(fused.groupId, _fusedPraiseId);
      expect(fused.totalPdfs, 3, reason: '2 legados + 1 extra, sem o coberto');
      expect(fused.audioTracks.single.audioId, _fusedAudioId);
      expect(page.groups.last.groupId, 'p1');
    });
  });
```

E no teste existente `catalogSourceProvider compõe as duas fontes` acrescentar, no fim:

```dart
      expect(
        identical(
          container.read(compositeCatalogSourceProvider).aliases,
          container.read(manifestMaterialAliasesProvider),
        ),
        isTrue,
      );
```

(`ColdigomSearchResult` só exige `groups` e `louvores`; os demais têm default.)

- [ ] **Step 2: Correr e ver falhar**

Run: `flutter test test/unit/features/catalog/catalog_source_test.dart`
Expected: FAIL — `aliases`, `mergeLocalSearchResults`, `compositeCatalogSourceProvider` não existem.

- [ ] **Step 3: Composite**

Substituir o conteúdo de `composite_catalog_source.dart`:

```dart
import '../../../../core/utils/material_id_kind.dart';
import '../../../../core/utils/pdf_id_codec.dart';
import '../../../coldigom/data/sources/coldigom_catalog_source.dart';
import '../../domain/entities/catalog_material.dart';
import '../../domain/entities/catalog_query.dart';
import '../../domain/entities/louvor.dart';
import '../../domain/entities/louvor_data_source.dart';
import '../../domain/entities/louvor_group.dart';
import '../../domain/entities/manifest_material_aliases.dart';
import '../../domain/ports/catalog_source.dart';
import '../../domain/ports/search_cancellation.dart';
import 'plpcg_catalog_source.dart';

/// [CatalogSource] único — manifest + caches Coldigom fundidos **por praise**.
///
/// Um louvor lógico é um praise do coldigom. Quando o praise está no manifest
/// ([aliases]), o grupo sai daqui com os PDFs legados do manifest (ids e
/// `shortId` originais) mais o que os caches Coldigom têm além deles
/// (PDFs não cobertos, áudio, cifra, gestos, letra, YouTube, meta). Praises
/// fora do manifest continuam a vir só do cache Coldigom; antes do primeiro
/// sync pós-migração ([aliases] vazio) tudo se comporta como no modo dual.
///
/// Os métodos síncronos existem para quem decide durante o build (barra do
/// carrossel) — os caches e o manifest já estão em memória.
class CompositeCatalogSource implements CatalogSource {
  const CompositeCatalogSource({
    required this.plpcg,
    required this.coldigom,
    this.aliases = ManifestMaterialAliases.empty,
  });

  final PlpcgCatalogSource plpcg;
  final ColdigomCatalogSource coldigom;
  final ManifestMaterialAliases aliases;

  /// Entrada do manifest para [materialId] — id legado direto ou id Coldigom
  /// de material coberto (alias). `null` para cifra/áudio/gesto/letra e para
  /// PDFs fora do manifest.
  Louvor? _manifestLouvorFor(String materialId) {
    final legacyId = aliases.legacyPdfIdByColdigomPdfId[materialId] ?? materialId;
    final material = plpcg.findMaterialById(legacyId);
    return material is PdfMaterial ? material.louvor : null;
  }

  /// Grupo do praise [praiseId] do manifest, fundido com os caches Coldigom.
  LouvorGroup? _fusedGroup(String praiseId) {
    final manifestPdfs = plpcg.louvoresOfGroup(praiseId);
    final parts = coldigom.partsOfGroup(praiseId);
    final extraPdfs = [
      for (final louvor in parts.pdfs)
        if (!aliases.coversColdigomPdf(louvor.pdfId)) louvor,
    ];
    if (manifestPdfs.isEmpty && parts.isEmpty) return null;
    final groups = LouvorGroup.fromLouvores(
      [...manifestPdfs, ...extraPdfs],
      audioTracks: parts.audioTracks,
      chordMaterials: parts.chords,
      gestureMaterials: parts.gestures,
      youtubeMaterials: parts.youtube,
      lyricsByGroupId: parts.lyrics == null ? null : {praiseId: parts.lyrics!},
      coldigomMetaByGroupId: parts.meta == null ? null : {praiseId: parts.meta!},
    );
    return groups.isEmpty ? null : groups.first;
  }

  /// Grupo remoto [group] (página de busca) refeito com os PDFs do manifest.
  ///
  /// Não lê o cache Coldigom: a página acabou de gravar nele e esta instância
  /// ainda tem os mapas antigos — os extras vêm do próprio grupo remoto.
  LouvorGroup _fuseRemoteGroup(LouvorGroup group) {
    final praiseId = group.groupId;
    final remotePdfs = [
      for (final section in group.sections)
        for (final entry in section.materials)
          if (!aliases.coversColdigomPdf(entry.pdfId)) entry.louvor,
    ];
    final pdfs = [...plpcg.louvoresOfGroup(praiseId), ...remotePdfs];
    final base = LouvorGroup.fromLouvores(pdfs).first;
    return LouvorGroup(
      groupId: praiseId,
      numero: base.numero,
      nome: base.nome,
      sections: base.sections,
      extras: group.extras,
      coldigomMeta: group.coldigomMeta,
    );
  }

  /// Versão síncrona de [groupById]: praise do manifest → fundido; senão
  /// cache Coldigom; senão (pré-sync) manifest pelo `groupId` legado.
  LouvorGroup? findGroupById(String groupId) {
    if (aliases.coversPraise(groupId)) return _fusedGroup(groupId);
    return coldigom.findGroupById(groupId) ?? plpcg.findGroupById(groupId);
  }

  /// Versão síncrona de [groupForMaterial], **sem** a regra "material único
  /// → `null`" (quem quer esconder o grupo sem alternativa aplica o corte).
  LouvorGroup? findGroupForMaterial(String materialId) {
    final manifestLouvor = _manifestLouvorFor(materialId);
    if (manifestLouvor != null) {
      return findGroupById(manifestLouvor.effectiveGroupId);
    }
    final isColdigomId =
        louvorDataSourceFromPdfId(materialId) == LouvorDataSource.coldigom ||
        materialIdKindOf(materialId) == MaterialKind.lyrics;
    if (!isColdigomId) return plpcg.findGroupForMaterial(materialId);
    final group = coldigom.findGroupForMaterial(materialId);
    if (group == null) return null;
    return aliases.coversPraise(group.groupId) ? _fusedGroup(group.groupId) : group;
  }

  /// Versão síncrona de [materialById]: legado → manifest; Coldigom → cache,
  /// e sem cache o alias devolve o [PdfMaterial] do manifest (sem rede).
  CatalogMaterial? findMaterialById(String materialId) {
    if (louvorDataSourceFromPdfId(materialId) != LouvorDataSource.coldigom) {
      return plpcg.findMaterialById(materialId);
    }
    final cached = coldigom.findMaterialById(materialId);
    if (cached != null) return cached;
    final aliased = _manifestLouvorFor(materialId);
    return aliased == null ? null : PdfMaterial(aliased);
  }

  @override
  Future<LouvorGroup?> groupById(String groupId) async => findGroupById(groupId);

  @override
  Future<CatalogMaterial?> materialById(String materialId) async =>
      findMaterialById(materialId);

  @override
  Future<LouvorGroup?> groupForMaterial(String materialId) async =>
      findGroupForMaterial(materialId);

  /// PLPCG primeiro (ranking UC-01 intacto), Coldigom depois sem os praises
  /// que o manifest já cobre (O16 + spec D5). Não funde: custo por tecla.
  @override
  List<LouvorGroup> searchLocal(CatalogQuery query) => mergeLocalSearchResults(
    plpcg: plpcg.searchLocal(query),
    coldigom: coldigom.searchLocal(query),
    manifestPraiseIds: aliases.praiseIds,
  );

  /// Página Coldigom; cada grupo cujo praise está no manifest sai fundido —
  /// é assim que a página remota **valida** a lista local em vez de anexar
  /// uma cópia (spec §5.4).
  @override
  Future<CatalogSearchPage> search(
    CatalogQuery query, {
    SearchCancellation? cancellation,
  }) async {
    final page = await coldigom.search(query, cancellation: cancellation);
    if (aliases.isEmpty || page.groups.isEmpty) return page;
    return CatalogSearchPage(
      groups: [
        for (final group in page.groups)
          aliases.coversPraise(group.groupId) ? _fuseRemoteGroup(group) : group,
      ],
      page: page.page,
      hasNextPage: page.hasNextPage,
    );
  }
}

/// Lista local da Home: [plpcg] na ordem do ranking, depois os grupos
/// [coldigom] cujo praise **não** está em [manifestPraiseIds].
///
/// Partilhada por `CompositeCatalogSource.searchLocal` e
/// `homeLocalSearchProvider` (que compõe as fontes por conta própria para o
/// índice PLPCG não ser arrastado pelos merges Coldigom).
List<LouvorGroup> mergeLocalSearchResults({
  required List<LouvorGroup> plpcg,
  required List<LouvorGroup> coldigom,
  required Set<String> manifestPraiseIds,
}) => [
  ...plpcg,
  for (final group in coldigom)
    if (!manifestPraiseIds.contains(group.groupId)) group,
];
```

- [ ] **Step 4: Providers**

Substituir `catalog_source_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../coldigom/data/providers/coldigom_catalog_source_provider.dart';
import '../../domain/ports/catalog_source.dart';
import '../../presentation/providers/manifest_material_aliases_provider.dart';
import '../sources/composite_catalog_source.dart';
import 'plpcg_catalog_source_provider.dart';

/// Composite concreto — para quem precisa dos métodos **síncronos**
/// (`findGroupById`, `findGroupForMaterial`) durante o build.
///
/// Compõe as fontes em vez de construí-las: uma página de busca Coldigom
/// recompõe só a fonte Coldigom, e o índice PLPCG (caro) e os aliases do
/// manifest sobrevivem.
final compositeCatalogSourceProvider = Provider<CompositeCatalogSource>((ref) {
  return CompositeCatalogSource(
    plpcg: ref.watch(plpcgCatalogSourceProvider),
    coldigom: ref.watch(coldigomCatalogSourceProvider),
    aliases: ref.watch(manifestMaterialAliasesProvider),
  );
});

/// Porta única de leitura e busca do catálogo — o que os use cases observam.
final catalogSourceProvider = Provider<CatalogSource>((ref) {
  return ref.watch(compositeCatalogSourceProvider);
});
```

- [ ] **Step 5: Correr + analyze**

Run: `flutter test test/unit/features/catalog/ test/unit/features/coldigom/ test/widget/features/catalog/ && flutter analyze`
Expected: PASS. Se o teste antigo «groupForMaterial não mistura PLPCG e Coldigom» continuar verde (aliases vazio nesse composite), nada a ajustar.

- [ ] **Step 6: Commit**

```bash
git add lib/features/catalog/data/sources/composite_catalog_source.dart lib/features/catalog/data/providers/catalog_source_provider.dart test/unit/features/catalog/catalog_source_test.dart
git commit -m "feat(catalog): CompositeCatalogSource funde manifest e extras Coldigom por praise

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

### Task 8: Lookup síncrono com alias; Home usa `knownPraiseIds` e filtra cobertos

**Files:**
- Modify: `lib/features/catalog/presentation/providers/catalog_material_lookup_provider.dart`
- Modify: `lib/features/catalog/presentation/providers/home_search_provider.dart`
- Modify: `lib/features/catalog/presentation/providers/home_remote_search_provider.dart`
- Test: `test/unit/features/catalog/catalog_material_lookup_test.dart`, `test/unit/features/catalog/home_search_provider_test.dart`, `test/unit/features/catalog/home_remote_search_provider_test.dart`

**Interfaces:**
- Produces: `CatalogMaterialLookup({..., Map<String, String> legacyPdfIdByColdigomPdfId = const {}})`; `louvor(id)` = `plpcg[id] ?? coldigom[id] ?? plpcg[legacy[id]]`.
- Consumes: `manifestMaterialAliasesProvider`, `knownPraiseIdsProvider` (Task 5), `mergeLocalSearchResults` (Task 7).

- [ ] **Step 1: Testes**

Em `catalog_material_lookup_test.dart` (usar os helpers de `Louvor` já existentes no ficheiro; se não houver, criar `Louvor.fromManifest` inline como nos outros testes):

```dart
  test('louvor(): id Coldigom de material coberto cai no manifest via alias', () {
    final legado = Louvor.fromManifest(
      nome: 'A',
      numero: '001',
      categoria: 'Partitura',
      classificacao: 'ColAdultos',
      pdf: 'https://coldigom.test/assets/praises/p1/m1.pdf',
      pdfId: 'legado-a',
      praiseId: 'p1',
      materialId: 'm1',
    );
    final coldigomId = encodePdfId('assets/praises/p1/m1.pdf');
    final lookup = CatalogMaterialLookup(
      plpcgLouvoresByPdfId: {'legado-a': legado},
      legacyPdfIdByColdigomPdfId: {coldigomId: 'legado-a'},
    );

    expect(lookup.louvor(coldigomId), same(legado));
    expect(lookup.louvor('desconhecido'), isNull);
  });

  test('louvor(): cache Coldigom quente vence o alias', () {
    final coldigomId = encodePdfId('assets/praises/p1/m1.pdf');
    final nativo = Louvor.fromManifest(
      nome: 'A',
      numero: '001',
      categoria: 'Partitura',
      classificacao: 'Balada',
      pdf: 'm1.pdf',
      pdfId: coldigomId,
      groupId: 'p1',
      source: LouvorDataSource.coldigom,
      praiseId: 'p1',
    );
    final lookup = CatalogMaterialLookup(
      coldigomLouvoresByPdfId: {coldigomId: nativo},
      legacyPdfIdByColdigomPdfId: {coldigomId: 'legado-a'},
    );

    expect(lookup.louvor(coldigomId), same(nativo));
  });
```

Em `home_search_provider_test.dart`, adicionar (usa `createContainer`, `keepStateAlive`, `_coldigomGroup`, `_RecordingCatalogSource` já definidos; o manifest do container passa a ter um louvor com `praiseId`):

```dart
  test('praise do manifest devolvido pelo remoto não é «novo» nem candidato a adoção',
      () async {
    final manifestComPraise = LouvoresManifest.fromLouvores([
      ...catalog,
      Louvor.fromManifest(
        nome: 'Firme',
        numero: '010',
        categoria: 'Partitura',
        classificacao: 'ColAdultos',
        pdf: 'https://coldigom.test/assets/praises/pf/m.pdf',
        pdfId: 'id-010',
        praiseId: 'pf',
        materialId: 'm',
      ),
    ]);
    final source = _RecordingCatalogSource(
      (query) async => CatalogSearchPage(
        groups: [_coldigomGroup('pf'), _coldigomGroup('novo')],
        page: query.page,
      ),
    );
    final container = createContainer(
      source,
      manifest: _MutableManifestNotifier(manifestComPraise),
    );
    keepStateAlive(container);
    await container.read(louvoresManifestProvider.future);

    container.read(homeSearchDebouncedQueryProvider.notifier).setImmediate('zzz');
    await container.read(
      homeRemoteSearchProvider(const HomeRemoteSearchKey(query: 'zzz', page: 1)).future,
    );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(homeSearchStateProvider);
    expect(state.newGroupIds, {'novo'});
    expect(adopter.calls.single, ['novo']);
    expect(adopter.knownSeen, contains('pf'));
  });
```

(Adaptar `newGroupIds`/`knownSeen` aos nomes reais em `home_search_state.dart` e no `_RecordingAdopter` do ficheiro — os dois existem com estes nomes hoje.)

- [ ] **Step 2: Correr e ver falhar**

Run: `flutter test test/unit/features/catalog/catalog_material_lookup_test.dart test/unit/features/catalog/home_search_provider_test.dart`
Expected: FAIL (`legacyPdfIdByColdigomPdfId` não existe; `pf` conta como novo).

- [ ] **Step 3: Lookup**

Em `catalog_material_lookup_provider.dart`:
- construtor: `this.legacyPdfIdByColdigomPdfId = const {},`; campo:

```dart
  /// Id Coldigom → `pdfId` legado dos materiais que o manifest cobre
  /// (`manifestMaterialAliasesProvider`). Serve o alias sem rede de
  /// [louvor] para playlists recentes com ids Coldigom.
  final Map<String, String> legacyPdfIdByColdigomPdfId;
```

- `louvor`:

```dart
  /// PDF de [materialId] — manifest, cache Coldigom, e por fim o alias
  /// (id Coldigom de material que o manifest também lista).
  Louvor? louvor(String materialId) {
    final direct =
        plpcgLouvoresByPdfId[materialId] ?? coldigomLouvoresByPdfId[materialId];
    if (direct != null) return direct;
    final legacyId = legacyPdfIdByColdigomPdfId[materialId];
    return legacyId == null ? null : plpcgLouvoresByPdfId[legacyId];
  }
```

- provider: `import 'manifest_material_aliases_provider.dart';` e `legacyPdfIdByColdigomPdfId: ref.watch(manifestMaterialAliasesProvider).legacyPdfIdByColdigomPdfId,`.

- [ ] **Step 4: Home**

Em `home_search_provider.dart`:
- imports: `import '../../data/sources/composite_catalog_source.dart';`, `import 'known_praise_ids_provider.dart';`, `import 'manifest_material_aliases_provider.dart';`.
- `homeLocalSearchProvider` devolve:

```dart
  return mergeLocalSearchResults(
    plpcg: plpcg.searchLocal(catalogQuery),
    coldigom: coldigom.searchLocal(catalogQuery),
    manifestPraiseIds: ref.watch(manifestMaterialAliasesProvider).praiseIds,
  );
```

(doc: «…Coldigom depois, sem os praises que o manifest já cobre (spec §5.2)».)
- `homeSearchStateProvider`: trocar `ref.watch(coldigomSearchIndexProvider).catalogIds` por `ref.watch(knownPraiseIdsProvider)`; o import de `coldigom_catalog_providers.dart` continua a ser usado por `coldigomCatalogHydrationProvider`.
- Atualizar o diagrama do doc: `homeLocalSearchProvider (PLPCG + filtros, depois Coldigom local fora do manifest)`.

Em `home_remote_search_provider.dart`: `import 'known_praise_ids_provider.dart';` e `final known = ref.read(knownPraiseIdsProvider);` (comentário: «índice Coldigom ∪ praises do manifest — um praise do manifest nunca é adotado para o Isar Coldigom»). Se `coldigom_catalog_providers.dart` ficar sem uso no ficheiro, remover o import.

- [ ] **Step 5: Correr + analyze**

Run: `flutter test test/unit/features/catalog/ test/widget/features/catalog/ test/widget/features/carousel/ && flutter analyze`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/catalog/presentation/providers/catalog_material_lookup_provider.dart lib/features/catalog/presentation/providers/home_search_provider.dart lib/features/catalog/presentation/providers/home_remote_search_provider.dart test/unit/features/catalog/catalog_material_lookup_test.dart test/unit/features/catalog/home_search_provider_test.dart
git commit -m "feat(catalog): lookup com alias Coldigom→legado; Home conhece os praises do manifest

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

### Task 9: Warmup por `praiseId` com curto-circuito por meta

**Files:**
- Modify: `lib/features/coldigom/data/coldigom_praise_cache_warmup.dart`
- Test: `test/unit/features/coldigom/coldigom_praise_cache_warmup_test.dart`

**Interfaces:**
- Consumes: `Louvor.praiseId` (Task 2), `coldigomPraiseMetaCacheProvider`.
- Comportamento: `warmupColdigomPraiseIds` pula ids com `praiseMeta[praiseId] != null`; `ensureColdigomPraiseMaterialsCached(louvor)` usa `louvor.praiseId ?? coldigomPraiseIdFromPdfId(louvor.pdfId)`, aceita louvor do manifest (source `plpcg`), só grava o louvor no cache Coldigom quando `source == coldigom`, e pula quando já há meta.

- [ ] **Step 1: Testes**

Em `coldigom_praise_cache_warmup_test.dart`, adicionar um helper e dois testes:

```dart
Louvor _manifestLouvor({required String praiseId}) => Louvor.fromManifest(
  nome: 'Firme nas promessas',
  numero: '010',
  categoria: 'Partitura',
  classificacao: 'ColAdultos',
  pdf: 'https://coldigom.test/assets/praises/$praiseId/m.pdf',
  pdfId: 'legado-010',
  praiseId: praiseId,
  materialId: 'm',
);
```

No grupo `ensureColdigomPraiseMaterialsCachedProvider`:

```dart
    test('louvor do manifest com praiseId aquece o praise sem entrar no cache Coldigom',
        () async {
      final datasource = _ControllableColdigomDatasource(
        (praiseId) async => _detailFor(praiseId),
      );
      final container = ProviderContainer(
        overrides: [
          coldigomRemoteDatasourceProvider.overrideWithValue(datasource),
        ],
      );
      addTearDown(container.dispose);

      await container.read(ensureColdigomPraiseMaterialsCachedProvider)(
        _manifestLouvor(praiseId: 'pf'),
      );

      expect(datasource.calls, ['pf']);
      expect(container.read(coldigomPraiseMetaCacheProvider).keys, contains('pf'));
      expect(
        container.read(coldigomLouvoresCacheProvider).containsKey('legado-010'),
        isFalse,
      );
    });

    test('não busca de novo quando o praise já tem meta em cache', () async {
      final datasource = _ControllableColdigomDatasource(
        (praiseId) async => _detailFor(praiseId),
      );
      final container = ProviderContainer(
        overrides: [
          coldigomRemoteDatasourceProvider.overrideWithValue(datasource),
        ],
      );
      addTearDown(container.dispose);
      container.read(coldigomPraiseMetaCacheProvider.notifier).mergeMeta({
        'pf': const ColdigomPraiseMetadata(name: 'Firme'),
      });

      await container.read(ensureColdigomPraiseMaterialsCachedProvider)(
        _manifestLouvor(praiseId: 'pf'),
      );

      expect(datasource.calls, isEmpty);
    });
```

No grupo `warmupColdigomPraiseIds`:

```dart
    test('pula praise que já tem meta em cache', () async {
      final datasource = _ControllableColdigomDatasource(
        (praiseId) async => _detailFor(praiseId),
      );
      final container = ProviderContainer(
        overrides: [
          coldigomRemoteDatasourceProvider.overrideWithValue(datasource),
        ],
      );
      addTearDown(container.dispose);
      container.read(coldigomPraiseMetaCacheProvider.notifier).mergeMeta({
        'p-quente': const ColdigomPraiseMetadata(name: 'Quente'),
      });

      await container.read(_warmupRunnerProvider.notifier).run([
        'p-quente',
        'p-frio',
      ]);

      expect(datasource.calls, ['p-frio']);
    });
```

(Import `package:coldigui/features/coldigom/domain/entities/coldigom_praise_metadata.dart`; conferir o construtor mínimo de `ColdigomPraiseMetadata` — `home_search_provider_test.dart` usa `const ColdigomPraiseMetadata(name: 'Coldigom')`.)

- [ ] **Step 2: Correr e ver falhar**

Run: `flutter test test/unit/features/coldigom/coldigom_praise_cache_warmup_test.dart`
Expected: FAIL (louvor `plpcg` volta cedo; meta não curto-circuita).

- [ ] **Step 3: Implementar**

Em `coldigom_praise_cache_warmup.dart`:

`warmupColdigomPraiseIds`: substituir o bloco `hasPdf`/`hasAudio`/`if (hasPdf && hasAudio) continue;` por:

```dart
    // Meta só entra no cache junto com o detalhe completo do praise (busca,
    // browse, hidratação, warmup): com ela, não há o que aquecer.
    if (ref.read(coldigomPraiseMetaCacheProvider).containsKey(praiseId)) {
      continue;
    }
```

`ensureColdigomPraiseMaterialsCachedProvider`: substituir o corpo da closure por:

```dart
      return (Louvor louvor) async {
        final praiseId =
            louvor.praiseId ?? coldigomPraiseIdFromPdfId(louvor.pdfId);
        if (praiseId == null) return;

        // Só materiais Coldigom nativos entram no cache Coldigom; um louvor
        // do manifest já vive na fonte PLPCG e o composite funde os dois.
        if (louvor.source == LouvorDataSource.coldigom) {
          ref.read(coldigomLouvoresCacheProvider.notifier).mergeLouvores([
            louvor,
          ]);
        }

        if (ref.read(coldigomPraiseMetaCacheProvider).containsKey(praiseId)) {
          return;
        }

        await _warmupOnePraise(
          ref.read(coldigomRemoteDatasourceProvider),
          ref.read(coldigomCacheWriterProvider),
          praiseId,
          coldigomWarmupDefaultTimeout,
        );
      };
```

Docs: no topo de `ensureColdigomPraiseMaterialsCachedProvider`, «Busca sob demanda os materiais do praise ao abrir o leitor — também para PDFs do manifest (`praiseId`): é assim que o sheet de um louvor legado ganha áudio/cifra/letra (spec §5.5).» Remover o import de `louvor_data_source.dart` só se ficar sem uso (continua usado).

- [ ] **Step 4: Correr + analyze**

Run: `flutter test test/unit/features/coldigom/ test/unit/features/playlists/ test/unit/features/live/ && flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/coldigom/data/coldigom_praise_cache_warmup.dart test/unit/features/coldigom/coldigom_praise_cache_warmup_test.dart
git commit -m "feat(coldigom): warmup pelo praiseId do manifest; curto-circuito por meta em cache

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

### Task 10: `findSwapMaterialGroup` sobre o composite

**Files:**
- Modify: `lib/features/catalog/domain/utils/find_louvor_group_by_pdf_id.dart`
- Modify: `lib/features/carousel/presentation/widgets/carousel_swap_material_button.dart`
- Test: `test/unit/features/audio_player/swap_material_group_test.dart`, `test/unit/features/catalog/find_louvor_by_pdf_id_test.dart` (grupo `findSwapMaterialGroup`)

**Interfaces:**
- Produces: `LouvorGroup? findSwapMaterialGroup({String? pdfId, String? audioId, required CompositeCatalogSource source})`.
- `resolveCarouselSwapMaterialGroup` passa `ref.watch(compositeCatalogSourceProvider)`.
- `findLouvorGroupByPdfId(catalog, pdfId)` fica.

- [ ] **Step 1: Reescrever os testes**

Substituir `test/unit/features/audio_player/swap_material_group_test.dart` por:

```dart
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/catalog/data/sources/composite_catalog_source.dart';
import 'package:coldigui/features/catalog/data/sources/plpcg_catalog_source.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/catalog/domain/entities/manifest_material_aliases.dart';
import 'package:coldigui/features/catalog/domain/utils/find_louvor_group_by_pdf_id.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:coldigui/features/coldigom/data/sources/coldigom_catalog_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// Precedência do botão layers com uma entrada de áudio focada: manda a
/// faixa tocando — agora sobre o composite fundido por praise.
void main() {
  final focusedPdfId = encodePdfId('assets/praises/p1/partitura.pdf');
  final focusedChordId = encodePdfId('assets/praises/p1/cifra.chord');
  final playingPdfId = encodePdfId('assets/praises/p9/partitura.pdf');
  final playingOtherPdfId = encodePdfId('assets/praises/p9/gestos.pdf');

  Louvor coldigomLouvor(String pdfId, String praiseId) => Louvor.fromManifest(
    nome: 'Louvor $praiseId',
    numero: '001',
    categoria: 'Partitura',
    classificacao: 'Coro',
    pdf: 'x.pdf',
    pdfId: pdfId,
    groupId: praiseId,
    source: LouvorDataSource.coldigom,
    praiseId: praiseId,
  );

  const playingTrack = AudioTrack(
    audioId: 'aud-p9',
    r2Key: 'assets/praises/p9/a.mp3',
    nome: 'Louvor p9',
    numero: '002',
    groupId: 'p9',
    categoria: 'Áudio',
    classificacao: 'Coro',
  );

  final chord = ChordMaterial(
    chordId: focusedChordId,
    r2Key: 'assets/praises/p1/cifra.chord',
    nome: 'Louvor p1',
    numero: '001',
    groupId: 'p1',
    categoria: 'Cifra',
    classificacao: 'Coro',
  );

  CompositeCatalogSource source({
    List<Louvor> manifest = const [],
    Map<String, Louvor> coldigom = const {},
    Map<String, AudioTrack> audio = const {},
    Map<String, ChordMaterial> chords = const {},
  }) => CompositeCatalogSource(
    plpcg: PlpcgCatalogSource(catalog: manifest),
    coldigom: ColdigomCatalogSource(
      louvores: coldigom,
      audioTracks: audio,
      chords: chords,
    ),
    aliases: ManifestMaterialAliases.fromLouvores(manifest),
  );

  final coldigomCache = <String, Louvor>{
    focusedPdfId: coldigomLouvor(focusedPdfId, 'p1'),
    playingPdfId: coldigomLouvor(playingPdfId, 'p9'),
    playingOtherPdfId: coldigomLouvor(playingOtherPdfId, 'p9'),
  };

  test('grupo da faixa tocando vence o pdfId de outro louvor', () {
    final group = findSwapMaterialGroup(
      pdfId: focusedPdfId,
      audioId: playingTrack.audioId,
      source: source(
        coldigom: coldigomCache,
        audio: {playingTrack.audioId: playingTrack},
      ),
    );

    expect(group, isNotNull);
    expect(group!.groupId, 'p9');
  });

  test('pdfId do mesmo louvor da faixa continua montando o grupo', () {
    final group = findSwapMaterialGroup(
      pdfId: playingPdfId,
      audioId: playingTrack.audioId,
      source: source(
        coldigom: coldigomCache,
        audio: {playingTrack.audioId: playingTrack},
      ),
    );

    expect(group, isNotNull);
    expect(group!.groupId, 'p9');
    expect(group.totalPdfs, 2);
    expect(group.audioTracks.single.audioId, playingTrack.audioId);
  });

  test('não perde PDFs do manifest do praise da faixa tocando', () {
    final partitura = Louvor.fromManifest(
      nome: 'Louvor p9',
      numero: '002',
      categoria: 'Partitura',
      classificacao: 'ColAdultos',
      pdf: 'https://coldigom.test/assets/praises/p9/legado.pdf',
      pdfId: 'legado-p9',
      groupId: '002:louvor-p9',
      praiseId: 'p9',
      materialId: 'legado',
    );

    final group = findSwapMaterialGroup(
      pdfId: focusedPdfId,
      audioId: playingTrack.audioId,
      source: source(
        manifest: [partitura],
        coldigom: coldigomCache,
        audio: {playingTrack.audioId: playingTrack},
      ),
    );

    expect(group!.groupId, 'p9');
    expect(
      group.flatPdfMaterials.map((m) => m.pdfId),
      containsAll(['legado-p9', playingPdfId, playingOtherPdfId]),
    );
  });

  test('cifra focada resolve o grupo do praise pelo id da cifra', () {
    final group = findSwapMaterialGroup(
      pdfId: focusedChordId,
      source: source(
        coldigom: coldigomCache,
        chords: {focusedChordId: chord},
      ),
    );

    expect(group, isNotNull);
    expect(group!.groupId, 'p1');
    expect(group.totalMaterials, 2);
  });

  test('só a faixa: grupo pelo groupId da faixa', () {
    final group = findSwapMaterialGroup(
      audioId: playingTrack.audioId,
      source: source(
        coldigom: coldigomCache,
        audio: {playingTrack.audioId: playingTrack},
      ),
    );
    expect(group!.groupId, 'p9');
  });

  test('null sem alternativa de material', () {
    expect(
      findSwapMaterialGroup(
        pdfId: focusedPdfId,
        source: source(coldigom: {focusedPdfId: coldigomCache[focusedPdfId]!}),
      ),
      isNull,
    );
    expect(findSwapMaterialGroup(source: source()), isNull);
  });
}
```

Em `find_louvor_by_pdf_id_test.dart`, no grupo `findSwapMaterialGroup`, substituir cada chamada pelos mesmos argumentos via `source:` — os dois testes PLPCG passam a:

```dart
    CompositeCatalogSource plpcgSource({Map<String, AudioTrack> audio = const {}}) =>
        CompositeCatalogSource(
          plpcg: PlpcgCatalogSource(catalog: [plpcgPartitura]),
          coldigom: ColdigomCatalogSource(audioTracks: audio),
        );

    test('inclui áudio mesmo com um só PDF', () {
      final group = findSwapMaterialGroup(
        pdfId: plpcgPartitura.pdfId,
        source: plpcgSource(audio: {track.audioId: track}),
      );
      expect(group, isNotNull);
      expect(group!.totalMaterials, 2);
    });

    test('retorna null sem alternativa', () {
      expect(
        findSwapMaterialGroup(pdfId: plpcgPartitura.pdfId, source: plpcgSource()),
        isNull,
      );
    });
```

e os testes Coldigom desse grupo («inclui cifra do cache…», «resolve grupo a partir do id da cifra», e seguintes) recebem `source: CompositeCatalogSource(plpcg: const PlpcgCatalogSource(), coldigom: ColdigomCatalogSource(louvores: {...}, chords: {...}))` com os mesmos mapas que hoje passam em `coldigomCache`/`chordCache`/`gestureCache`. (O teste PLPCG «inclui áudio» depende de `track.groupId == plpcgPartitura.effectiveGroupId` — já é assim no ficheiro.)

- [ ] **Step 2: Correr e ver falhar**

Run: `flutter test test/unit/features/audio_player/swap_material_group_test.dart test/unit/features/catalog/find_louvor_by_pdf_id_test.dart`
Expected: FAIL — parâmetro `source` não existe.

- [ ] **Step 3: Implementar**

Substituir tudo a partir de `findSwapMaterialGroup` (inclusive) em `find_louvor_group_by_pdf_id.dart` por:

```dart
/// Grupo para o botão layers da barra: inclui áudios/cifras do cache e aceita
/// 1 PDF se [LouvorGroup.totalMaterials] > 1.
///
/// Precedência quando os dois ids chegam (face de áudio): manda a faixa
/// tocando ([audioId]) se o [pdfId] for de **outro** louvor — o chip focado no
/// carousel não tem relação com o que está tocando. Com os dois no mesmo
/// grupo o [pdfId] segue mandando.
///
/// Continua síncrono (a UI decide se mostra o botão durante o build) e por
/// isso usa os métodos síncronos do composite, que já funde manifest e caches
/// Coldigom por praise.
LouvorGroup? findSwapMaterialGroup({
  String? pdfId,
  String? audioId,
  required CompositeCatalogSource source,
}) {
  final playingTrack = (audioId == null || audioId.isEmpty)
      ? null
      : source.coldigom.audioTracks[audioId];
  final playingGroupId =
      (playingTrack == null || playingTrack.groupId.isEmpty)
      ? null
      : playingTrack.groupId;

  final materialGroup = (pdfId == null || pdfId.isEmpty)
      ? null
      : source.findGroupForMaterial(pdfId);

  if (playingGroupId != null && playingGroupId != materialGroup?.groupId) {
    return _multipleOnly(source.findGroupById(playingGroupId));
  }
  if (materialGroup != null) return _multipleOnly(materialGroup);
  if (playingGroupId != null) {
    return _multipleOnly(source.findGroupById(playingGroupId));
  }
  return null;
}

/// Descarta o grupo que sobrou com um material só — não há o que trocar.
LouvorGroup? _multipleOnly(LouvorGroup? group) {
  if (group == null || group.totalMaterials <= 1) return null;
  return group;
}
```

Imports do ficheiro passam a ser só: `../../data/sources/composite_catalog_source.dart`, `../../data/sources/plpcg_catalog_source.dart`, `../entities/louvor.dart`, `../entities/louvor_group.dart`.

Em `carousel_swap_material_button.dart`: `resolveCarouselSwapMaterialGroup` vira

```dart
LouvorGroup? resolveCarouselSwapMaterialGroup(
  WidgetRef ref, {
  String? materialId,
  String? audioId,
}) {
  return findSwapMaterialGroup(
    pdfId: materialId,
    audioId: audioId,
    source: ref.watch(compositeCatalogSourceProvider),
  );
}
```

com `import 'package:coldigui/features/catalog/data/providers/catalog_source_provider.dart';` e sem os imports de `catalog_material_lookup_provider.dart`/`louvores_manifest_provider.dart` se ficarem sem uso.

- [ ] **Step 4: Correr + analyze**

Run: `flutter test test/unit/features/audio_player/ test/unit/features/catalog/ test/widget/features/carousel/ && flutter analyze`
Expected: PASS (o widget test `carousel_chips_swap_material_test.dart` lê o manifest real sem override — já era assim via `catalogMaterialLookupProvider`).

- [ ] **Step 5: Commit**

```bash
git add lib/features/catalog/domain/utils/find_louvor_group_by_pdf_id.dart lib/features/carousel/presentation/widgets/carousel_swap_material_button.dart test/unit/features/audio_player/swap_material_group_test.dart test/unit/features/catalog/find_louvor_by_pdf_id_test.dart
git commit -m "refactor(carousel): trocar material resolve o grupo pelo composite fundido

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

### Verificação da fusão (fim da unidade)

- [ ] `LouvorGroup.isColdigom` — chamadores levantados em 2026-09-18: `material_sheet.dart` (origem do «Reportar»: um grupo do manifest com extras reporta como `coldigom` com `praiseId = group.groupId`, que agora **é** o praise id — válido) e `adopt_coldigom_search_novelties.dart` (`known` inclui os praises do manifest, Task 8). Nenhum depende de «PLPCG puro»; nada a mudar. Registar isto na spec §12 (Task 14).
- [ ] Rodar `./scripts/test_all.sh --vm-only` inteiro antes de seguir para o offline.

---

## Unidade 6 — Offline sem ZIP

### Task 11: `DownloadMissingPdfs` cancelável

**Files:**
- Modify: `lib/features/offline/domain/usecases/download_missing_pdfs.dart`
- Test: `test/unit/features/offline/download_missing_pdfs_test.dart`

**Interfaces:**
- Produces: `DownloadMissingPdfs.call({Set<String>? materialCategories, void Function(int done, int total)? onProgress, CancelToken? cancelToken})` — repassa o token a `FetchAndStorePdf`; quando cancelado, os workers param de puxar ids e o use case termina com `OfflineBulkCancelledException` (de `offline_bulk_exceptions.dart`, que fica).

- [ ] **Step 1: Teste**

Em `download_missing_pdfs_test.dart`, um datasource que só completa quando mandado:

```dart
class _GatedPdfBytesDatasource extends PdfBytesDatasource {
  _GatedPdfBytesDatasource() : super(Dio());

  final gate = Completer<void>();
  int fetchCount = 0;

  @override
  Future<Uint8List> fetchBytes(
    String filePath, {
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    fetchCount++;
    await gate.future;
    if (cancelToken?.isCancelled ?? false) {
      throw DioException.requestCancelled(
        requestOptions: RequestOptions(path: filePath),
        reason: 'cancelled',
      );
    }
    return Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);
  }
}
```

e o teste (setup igual ao de «baixa PDFs faltantes em paralelo…», trocando o datasource):

```dart
  test('cancelToken interrompe: workers não puxam mais ids e o use case lança', () async {
    // setup: 6 louvores no catálogo, índice vazio, datasource _GatedPdfBytesDatasource
    final token = CancelToken();
    final future = useCase(cancelToken: token);
    await Future<void>.delayed(Duration.zero);
    expect(gated.fetchCount, 3, reason: 'concorrência 3 em voo');

    token.cancel('user');
    gated.gate.complete();

    await expectLater(future, throwsA(isA<OfflineBulkCancelledException>()));
    expect(gated.fetchCount, 3, reason: 'nenhum id novo depois do cancel');
  });
```

(`import 'dart:async';` e `import 'package:coldigui/features/offline/domain/exceptions/offline_bulk_exceptions.dart';`.)

- [ ] **Step 2: Correr e ver falhar**

Run: `flutter test test/unit/features/offline/download_missing_pdfs_test.dart`
Expected: FAIL — `cancelToken` não é parâmetro.

- [ ] **Step 3: Implementar**

Em `download_missing_pdfs.dart`: `import 'package:dio/dio.dart';` e `import '../exceptions/offline_bulk_exceptions.dart';`. Assinatura:

```dart
  Future<DownloadMissingResult> call({
    Set<String>? materialCategories,

    /// Chamado após cada fetch (ou falha). [total] = quantidade de faltantes.
    void Function(int done, int total)? onProgress,

    /// Cancelamento do utilizador (UC-09 «Parar»): os workers deixam de
    /// puxar ids e o use case termina com [OfflineBulkCancelledException].
    /// O que já foi gravado fica — a próxima chamada pré-filtra.
    CancelToken? cancelToken,
  }) async {
```

No worker:

```dart
      Future<void> worker() async {
        while (true) {
          if (cancelToken?.isCancelled ?? false) break;
          if (nextIndex >= missingPdfIds.length) break;
          final index = nextIndex++;
          final pdfId = missingPdfIds[index];

          try {
            await _fetchAndStorePdf(
              pdfId: pdfId,
              remotePath: LouvorPdfPath.remotePath(
                pdf: pdfById[pdfId] ?? '',
                pdfId: pdfId,
              ),
              category: OfflineCategoryResolver.fromPdfId(pdfId),
              persistentDownload: true,
              cancelToken: cancelToken,
            );
            downloaded++;
          } on Object {
            if (cancelToken?.isCancelled ?? false) break;
            failed++;
          }

          completed++;
          onProgress?.call(completed, missingPdfIds.length);
        }
      }

      final workerCount = min(_maxConcurrentDownloads, missingPdfIds.length);
      await Future.wait(List.generate(workerCount, (_) => worker()));
      if (cancelToken?.isCancelled ?? false) {
        throw const OfflineBulkCancelledException();
      }
```

- [ ] **Step 4: Correr + analyze**

Run: `flutter test test/unit/features/offline/download_missing_pdfs_test.dart test/unit/features/offline/offline_missing_download_provider_test.dart && flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/offline/domain/usecases/download_missing_pdfs.dart test/unit/features/offline/download_missing_pdfs_test.dart
git commit -m "feat(offline): DownloadMissingPdfs aceita CancelToken e termina com OfflineBulkCancelledException

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

### Task 12: `OfflineBulkDownloadNotifier` sobre `DownloadMissingPdfs`

**Files:**
- Modify: `lib/features/offline/domain/entities/offline_download_progress.dart`
- Modify: `lib/features/offline/presentation/providers/offline_bulk_download_provider.dart`
- Modify: `lib/features/offline/presentation/pages/offline_settings_widgets/progress_section.dart`
- Modify: `lib/features/offline/presentation/pages/offline_settings_screen.dart`
- Delete: `lib/features/offline/presentation/pages/offline_settings_widgets/checkpoint_banner.dart`
- Modify: `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb` (+ `flutter gen-l10n`)
- Test: `test/unit/features/offline/offline_bulk_download_provider_test.dart`, `test/widget/features/offline/offline_settings_screen_test.dart`, `test/unit/features/offline/offline_bulk_completion_message_test.dart` (só se referir ZIP)

**Interfaces:**
- Produces:
  - `OfflineDownloadProgress({required String currentCategory, required int donePdfs, required int totalPdfs})`, `pdfFraction`; enum `OfflineDownloadPhase` apagado.
  - `OfflineBulkDownloadState({status, progress, failure, failedCount})` — sem `checkpoint`/`unmatchedZipEntries`/`hasCheckpoint`; `copyWith({status, progress, failure, failedCount, clearError, clearProgress})`.
  - `OfflineBulkDownloadNotifier.start(List<String> categories)`, `cancel()`, `pauseForBackground()`; `resumeFromCheckpoint`/`dismissCheckpoint` apagados.
- Consumes: `downloadMissingPdfsProvider` (existe em `offline_core_providers.dart`), `DownloadMissingPdfs.call(cancelToken:)` (Task 11).

- [ ] **Step 1: Reescrever o teste do notifier**

Em `offline_bulk_download_provider_test.dart`:
1. Apagar os imports de `offline_bulk_checkpoint_store`, `offline_manifest_remote_datasource`, `zip_package_downloader`, `offline_bulk_providers`, `offline_bulk_checkpoint`, `download_offline_packages`, `extract_and_store_pdfs`, `reconcile_offline_index`, `offline_download_progress`; adicionar `package:coldigui/features/catalog/data/datasources/catalog_local_datasource.dart`, `package:coldigui/features/offline/data/providers/offline_core_providers.dart`, `package:coldigui/features/offline/domain/usecases/download_missing_pdfs.dart`, `package:coldigui/features/offline/domain/usecases/fetch_and_store_pdf.dart`, `package:coldigui/features/offline/data/datasources/favorite_pdf_ids_resolver.dart`, `package:coldigui/features/pdf_opening/data/datasources/pdf_bytes_datasource.dart`.
2. Trocar as quatro classes `_Throwing/_Success/_Result/_CountingDownloadOfflinePackages` por fakes de `DownloadMissingPdfs` com um construtor base comum:

```dart
/// Base dos fakes: dependências inertes — nenhum teste aqui exercita o
/// download real, só a orquestração do notifier.
abstract class _FakeDownloadMissingPdfs extends DownloadMissingPdfs {
  _FakeDownloadMissingPdfs()
    : super(
        const CatalogLocalDatasource.unavailable(),
        _StubRepo(),
        FetchAndStorePdf(
          PdfBytesDatasource(Dio()),
          _StubRepo(),
          favoritePdfIdsResolver: FavoritePdfIdsResolver.testing(),
        ),
      );
}

class _ThrowingDownloadMissingPdfs extends _FakeDownloadMissingPdfs {
  _ThrowingDownloadMissingPdfs(this.error);
  final Object error;

  @override
  Future<DownloadMissingResult> call({
    Set<String>? materialCategories,
    void Function(int done, int total)? onProgress,
    CancelToken? cancelToken,
  }) async => throw error;
}

class _ResultDownloadMissingPdfs extends _FakeDownloadMissingPdfs {
  _ResultDownloadMissingPdfs(this.result);
  final DownloadMissingResult result;
  int callCount = 0;
  Set<String>? lastCategories;

  @override
  Future<DownloadMissingResult> call({
    Set<String>? materialCategories,
    void Function(int done, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    callCount++;
    lastCategories = materialCategories;
    return result;
  }
}

/// Emite progresso e só termina quando [gate] completa — para testar
/// «Parar» e a `ProgressSection`.
class _GatedDownloadMissingPdfs extends _FakeDownloadMissingPdfs {
  final gate = Completer<void>();
  CancelToken? token;

  @override
  Future<DownloadMissingResult> call({
    Set<String>? materialCategories,
    void Function(int done, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    token = cancelToken;
    onProgress?.call(0, 10);
    onProgress?.call(3, 10);
    await gate.future;
    if (cancelToken?.isCancelled ?? false) {
      throw const OfflineBulkCancelledException();
    }
    return const DownloadMissingResult(
      downloadedCount: 10,
      skippedCount: 0,
      failedCount: 0,
    );
  }
}

const _success = DownloadMissingResult(
  downloadedCount: 5,
  skippedCount: 0,
  failedCount: 0,
);
```

(`FavoritePdfIdsResolver.testing()` é o construtor `@visibleForTesting` sem Isar, já usado por `fetch_and_store_pdf_test.dart`.)

3. `createContainer` passa a:

```dart
  ProviderContainer createContainer(
    Object error, {
    BulkDownloadWakelock? wakelock,
    DownloadMissingPdfs? useCase,
  }) {
    final fakeWakelock = wakelock ?? _FakeWakelock();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        bulkDownloadWakelockProvider.overrideWithValue(fakeWakelock),
        downloadMissingPdfsProvider.overrideWithValue(
          useCase ?? _ThrowingDownloadMissingPdfs(error),
        ),
        offlineModeProvider.overrideWith(_IdleOfflineModeNotifier.new),
        offlineCacheStatusProvider.overrideWith(_IdleCacheStatusNotifier.new),
        isarAvailableProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }
```

e `setUp` deixa de criar `store`/`checkpointStore` (apagar `PdfLocalStore` e imports de `dart:io` se ficarem sem uso).

4. Mapear os testes existentes, mantendo os nomes: onde havia `_SuccessDownloadOfflinePackages(...)` → `_ResultDownloadMissingPdfs(_success)`; `_CountingDownloadOfflinePackages` → `_ResultDownloadMissingPdfs(_success)` lendo `callCount`; `DownloadOfflinePackagesResult(failedPdfIds: [...10 ids...], totalPdfs: 10)` → `DownloadMissingResult(downloadedCount: 8, skippedCount: 0, failedCount: 2)` (2 falhas em 10) e, no caso «todas falham», `DownloadMissingResult(downloadedCount: 0, skippedCount: 0, failedCount: 10)`; qualquer referência a `checkpoint`/`hasCheckpoint`/`unmatchedZipEntries` sai.

5. Novos testes:

```dart
  test('start repassa as categorias e o cancel token ao use case', () async {
    final useCase = _ResultDownloadMissingPdfs(_success);
    final container = createContainer(Object(), useCase: useCase);

    await container
        .read(offlineBulkDownloadProvider.notifier)
        .start(['Partitura', 'Cifra']);

    expect(useCase.lastCategories, {'Partitura', 'Cifra'});
    expect(
      container.read(offlineBulkDownloadProvider).status,
      OfflineBulkDownloadStatus.completed,
    );
  });

  test('progresso (done, total) chega ao estado com as categorias como rótulo',
      () async {
    final useCase = _GatedDownloadMissingPdfs();
    final container = createContainer(Object(), useCase: useCase);
    final notifier = container.read(offlineBulkDownloadProvider.notifier);

    final running = notifier.start(['Partitura']);
    await pumpMicrotasks();

    final progress = container.read(offlineBulkDownloadProvider).progress;
    expect(progress, isNotNull);
    expect(progress!.donePdfs, 3);
    expect(progress.totalPdfs, 10);
    expect(progress.currentCategory, 'Partitura');

    useCase.gate.complete();
    await running;
  });

  test('cancel cancela o token e termina em cancelled sem checkpoint', () async {
    final useCase = _GatedDownloadMissingPdfs();
    final container = createContainer(Object(), useCase: useCase);
    final notifier = container.read(offlineBulkDownloadProvider.notifier);

    final running = notifier.start(['Partitura']);
    await pumpMicrotasks();
    notifier.cancel();
    expect(
      container.read(offlineBulkDownloadProvider).status,
      OfflineBulkDownloadStatus.cancelling,
    );
    expect(useCase.token!.isCancelled, isTrue);

    useCase.gate.complete();
    await running;

    final state = container.read(offlineBulkDownloadProvider);
    expect(state.status, OfflineBulkDownloadStatus.cancelled);
    expect(state.progress, isNull);
  });
```

- [ ] **Step 2: Correr e ver falhar**

Run: `flutter test test/unit/features/offline/offline_bulk_download_provider_test.dart`
Expected: FAIL (compilação: `downloadMissingPdfsProvider` não é lido pelo notifier, `checkpoint` ainda existe).

- [ ] **Step 3: Entidade de progresso**

Substituir `offline_download_progress.dart`:

```dart
/// Progresso do download em massa UC-09 (PDF a PDF) para a UI.
class OfflineDownloadProgress {
  const OfflineDownloadProgress({
    required this.currentCategory,
    required this.donePdfs,
    required this.totalPdfs,
  });

  /// Rótulo do que está a baixar — as categorias pedidas, separadas por `, `.
  final String currentCategory;

  /// PDFs concluídos (baixados ou falhados) nesta execução.
  final int donePdfs;

  /// PDFs faltantes no início da execução.
  final int totalPdfs;

  double get pdfFraction => totalPdfs == 0 ? 0 : donePdfs / totalPdfs;
}
```

- [ ] **Step 4: Notifier**

Substituir `offline_bulk_download_provider.dart` do `enum OfflineBulkDownloadStatus` até ao fim por:

```dart
/// Estado do bulk download UC-09 na UI.
enum OfflineBulkDownloadStatus {
  idle,
  running,
  cancelling,
  completed,
  completedWithWarnings,
  failed,
  cancelled,
}

class OfflineBulkDownloadState {
  const OfflineBulkDownloadState({
    this.status = OfflineBulkDownloadStatus.idle,
    this.progress,
    this.failure,
    this.failedCount = 0,
  });

  final OfflineBulkDownloadStatus status;
  final OfflineDownloadProgress? progress;

  /// Falha classificada (E8) da última execução — a UI traduz via
  /// `failureMessage`.
  final AppFailure? failure;

  /// PDFs que falharam na última execução — diferencia `completed` de
  /// `completedWithWarnings` e alimenta "N falhas".
  final int failedCount;

  bool get isRunning => status == OfflineBulkDownloadStatus.running;
  bool get isCancelling => status == OfflineBulkDownloadStatus.cancelling;
  bool get isActive => isRunning || isCancelling;
  bool get completedWithWarnings =>
      status == OfflineBulkDownloadStatus.completedWithWarnings;

  OfflineBulkDownloadState copyWith({
    OfflineBulkDownloadStatus? status,
    OfflineDownloadProgress? progress,
    AppFailure? failure,
    int? failedCount,
    bool clearError = false,
    bool clearProgress = false,
  }) {
    return OfflineBulkDownloadState(
      status: status ?? this.status,
      progress: clearProgress ? null : (progress ?? this.progress),
      failure: clearError ? null : (failure ?? this.failure),
      failedCount: failedCount ?? this.failedCount,
    );
  }
}

final offlineBulkDownloadProvider =
    NotifierProvider<OfflineBulkDownloadNotifier, OfflineBulkDownloadState>(
      OfflineBulkDownloadNotifier.new,
    );

/// Orquestra [DownloadMissingPdfs] (PDF a PDF, do coldigom) com progresso,
/// cancelamento, [offlineModeProvider.markConfigured]
/// (`OFFLINE_AVAILABLE=TRUE`) e refresh de [offlineCacheStatusProvider].
///
/// Sem checkpoint: «retomar» é carregar em «Baixar selecionados» de novo — o
/// use case pré-filtra o que já está no índice (spec §6.2).
class OfflineBulkDownloadNotifier extends Notifier<OfflineBulkDownloadState> {
  CancelToken? _cancelToken;
  var _wakelockHeld = false;
  List<String> _lastStartedCategories = const [];

  BulkDownloadWakelock get _wakelock => ref.read(bulkDownloadWakelockProvider);

  @override
  OfflineBulkDownloadState build() {
    ref.onDispose(() {
      _cancelToken?.cancel();
      _releaseWakelock();
    });
    return const OfflineBulkDownloadState();
  }

  Future<void> _acquireWakelock() async {
    if (_wakelockHeld) return;
    await _wakelock.enable();
    _wakelockHeld = true;
  }

  Future<void> _releaseWakelock() async {
    if (!_wakelockHeld) return;
    await _wakelock.disable();
    _wakelockHeld = false;
  }

  Future<void> start(List<String> categories) async {
    if (state.isRunning) return;
    if (!_ensureStorageAvailable()) return;
    if (!_acquireMaintenanceLock()) return;

    // Tudo o que pode lançar fica dentro do try: o `finally` é a única
    // garantia de que o lock de manutenção não vaza pela sessão inteira.
    try {
      _lastStartedCategories = List<String>.from(categories);
      final label = categories.join(', ');
      final cancelToken = _cancelToken = CancelToken();
      state = state.copyWith(
        status: OfflineBulkDownloadStatus.running,
        clearError: true,
        clearProgress: true,
        failedCount: 0,
      );
      await _acquireWakelock();

      final result = await ref
          .read(downloadMissingPdfsProvider)
          .call(
            materialCategories: categories.toSet(),
            cancelToken: cancelToken,
            onProgress: (done, total) => _onDownloadProgress(
              OfflineDownloadProgress(
                currentCategory: label,
                donePdfs: done,
                totalPdfs: total,
              ),
            ),
          );

      await _completeBulkDownload(result);
    } on OfflineBulkCancelledException {
      await _releaseWakelock();
      state = state.copyWith(
        status: OfflineBulkDownloadStatus.cancelled,
        clearProgress: true,
      );
      await ref.read(offlineCacheStatusProvider.notifier).refreshAll();
    } on Object catch (e) {
      await _failBulkDownload(e);
    } finally {
      _releaseMaintenanceLock();
    }
  }

  /// `false` (com estado `failed`) quando o Isar não abriu — spec C.1: não
  /// baixar um byte sem ter onde indexar.
  bool _ensureStorageAvailable() {
    if (ref.read(isarAvailableProvider)) return true;
    debugPrint('[offline] bulk abortado: índice offline indisponível');
    state = state.copyWith(
      status: OfflineBulkDownloadStatus.failed,
      failure: const StorageFailure(
        StorageUnavailableException('offline.bulk'),
      ),
      clearProgress: true,
    );
    return false;
  }

  bool _acquireMaintenanceLock() {
    final acquired = ref
        .read(offlineMaintenanceLockProvider.notifier)
        .tryAcquire(OfflineMaintenanceOwner.bulk);
    if (!acquired) {
      debugPrint('[offline] bulk adiado: manutenção offline em andamento');
    }
    return acquired;
  }

  void _releaseMaintenanceLock() {
    ref
        .read(offlineMaintenanceLockProvider.notifier)
        .release(OfflineMaintenanceOwner.bulk);
  }

  void _onDownloadProgress(OfflineDownloadProgress progress) {
    if (state.status == OfflineBulkDownloadStatus.cancelling) {
      state = state.copyWith(progress: progress);
      return;
    }
    state = state.copyWith(
      status: OfflineBulkDownloadStatus.running,
      progress: progress,
    );
  }

  Future<void> _failBulkDownload(Object error) async {
    await _releaseWakelock();
    state = state.copyWith(
      status: OfflineBulkDownloadStatus.failed,
      failure: AppFailure.from(error),
      clearProgress: true,
    );
    await ref.read(offlineCacheStatusProvider.notifier).refreshAll();
  }

  Future<void> _completeBulkDownload(DownloadMissingResult result) async {
    await _releaseWakelock();
    final failedCount = result.failedCount;
    final attempted = result.downloadedCount + failedCount;
    // Nada foi de fato gravado neste lote — não é honesto marcar
    // OFFLINE_AVAILABLE=TRUE (Task 3/B4).
    final nothingWasStored = attempted > 0 && result.downloadedCount == 0;
    state = state.copyWith(
      status: failedCount > 0
          ? OfflineBulkDownloadStatus.completedWithWarnings
          : OfflineBulkDownloadStatus.completed,
      clearProgress: true,
      failedCount: failedCount,
    );
    if (_lastStartedCategories.isNotEmpty) {
      await ref
          .read(offlineCategorySelectionProvider.notifier)
          .registerBulkCompleted(_lastStartedCategories);
    }
    _lastStartedCategories = const [];
    if (!nothingWasStored) {
      await ref.read(offlineModeProvider.notifier).markConfigured();
    }
    await ref.read(offlineCacheStatusProvider.notifier).refreshAll();
  }

  void cancel() {
    if (!state.isRunning) return;
    _cancelToken?.cancel('cancelled by user');
    state = state.copyWith(status: OfflineBulkDownloadStatus.cancelling);
  }

  /// Para o bulk ao ir para background — o que já foi gravado fica.
  void pauseForBackground() {
    if (!state.isRunning) return;
    _cancelToken?.cancel('app backgrounded');
    state = state.copyWith(status: OfflineBulkDownloadStatus.cancelling);
  }
}
```

Imports do ficheiro: remover `offline_bulk_providers.dart`, `offline_bulk_checkpoint.dart`, `download_offline_packages.dart`; manter `offline_core_providers.dart` (traz `downloadMissingPdfsProvider`), `offline_download_progress.dart`, `offline_bulk_exceptions.dart`; adicionar `../../domain/usecases/download_missing_pdfs.dart`. (`InsufficientDiskSpaceException` e `DioException` passam pelo `on Object` — `AppFailure.from` já os classifica; conferir com os testes «DioException … vira NetworkFailure» e «InsufficientDiskSpaceException define estado failed com StorageFailure» que continuam no ficheiro.)

- [ ] **Step 5: `ProgressSection`, tela e l10n**

`progress_section.dart` — substituir o `build`:

```dart
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: progress.pdfFraction,
          color: AppColors.gold,
          backgroundColor: AppColors.title.withValues(alpha: 0.12),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.offlineProgressDetail(
            progress.currentCategory,
            progress.donePdfs,
            progress.totalPdfs,
            l10n.offlinePhaseFetching,
          ),
          style: AppTypography.body.copyWith(
            color: AppColors.title.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }
```

e remover o import de `byte_format.dart`; doc: «Progresso do download em massa (UC-09, PDF a PDF): uma barra e `{categoria} — done/total PDFs`.»

`offline_settings_screen.dart`:
- apagar o import `offline_settings_widgets/checkpoint_banner.dart`;
- em `_OfflineContent`: apagar os parâmetros/campos `onDismissCheckpoint`, `onResumeCheckpoint` e o bloco `if (bulkState.hasCheckpoint && !bulkState.isActive) ...[CheckpointBanner(...)]`;
- no `build` da tela: apagar os argumentos `onDismissCheckpoint:` e `onResumeCheckpoint:`;
- no doc de `offlineBulkCompletionMessage`, apagar a frase sobre `unmatchedZipEntries` (fica: «Decide pelo `failedCount` real.»).
- `git rm lib/features/offline/presentation/pages/offline_settings_widgets/checkpoint_banner.dart`.

l10n — em `app_pt.arb` **e** `app_en.arb`: apagar `offlineResumeBanner`, `offlineResumeDownload`, `offlineDismissCheckpoint`, `offlinePhaseExtracting`, `offlinePhaseStoring`, `offlinePhaseSyncing`, `offlineProgressDetail` (+ `@offlineProgressDetail`), `offlineFetchProgress` (+ `@`); renomear `offlineProgressDetailWeb`/`@offlineProgressDetailWeb` para `offlineProgressDetail`/`@offlineProgressDetail` (texto pt `"{category} — {done}/{total} PDFs ({phase})"`, en `"{category} — {done}/{total} PDFs ({phase})"`). Correr `flutter gen-l10n` e commitar `lib/l10n/app_localizations*.dart`.

Widget test `offline_settings_screen_test.dart`: apagar `_RunningBulkWithFetchProgressNotifier` e o teste «shows zip byte progress during native fetching phase»; nos notifiers restantes, `OfflineDownloadProgress(currentCategory: 'Partitura', donePdfs: 12, totalPdfs: 100)`; o teste «shows only pdf progress without zip bar…» passa a chamar-se «shows pdf progress with one bar» e mantém as asserções `findsOneWidget`/`12/100 PDFs`/`Parar`. Se `_FakeReconcileNotifier.requestReconcile` do ficheiro tiver os parâmetros `materialPackage`/`materialCategory`, removê-los (Task 13 os apaga do notifier; fazer já aqui evita duas passagens).

- [ ] **Step 6: Correr + analyze**

Run: `flutter gen-l10n && flutter test test/unit/features/offline/ test/widget/features/offline/ && flutter analyze`
Expected: PASS nos ficheiros tocados. Os testes do ZIP ainda existem e passam (apagados na Task 13).

- [ ] **Step 7: Commit**

```bash
git add -A lib/features/offline/domain/entities/offline_download_progress.dart lib/features/offline/presentation lib/l10n test/unit/features/offline/offline_bulk_download_provider_test.dart test/widget/features/offline/offline_settings_screen_test.dart
git commit -m "feat(offline): primeira configuração PDF a PDF via DownloadMissingPdfs; sem checkpoint nem ZIP na UI

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

### Task 13: Apagar o pipeline ZIP e o reconcile escopado

**Files:**
- Delete (lib): `offline/data/datasources/{zip_package_downloader,zip_package_downloader_native,zip_package_downloader_web,offline_manifest_remote_datasource,offline_bulk_checkpoint_store}.dart`, `offline/data/models/offline_manifest_dto.dart`, `offline/data/utils/{zip_extraction_runner,zip_extraction_runner_native,zip_extraction_runner_web,zip_pdf_extractor,zip_pdf_extractor_native,zip_pdf_extractor_shared,zip_pdf_extractor_types,zip_pdf_extractor_web}.dart`, `offline/data/providers/offline_bulk_providers.dart`, `offline/domain/entities/{offline_bulk_checkpoint,offline_manifest}.dart`, `offline/domain/usecases/{download_offline_packages,extract_and_store_pdfs}.dart`.
- Delete (test): `test/unit/features/offline/{download_offline_packages,extract_and_store_pdfs,offline_bulk_checkpoint_store,zip_extraction_runner_native,zip_extraction_runner_web,zip_package_downloader,zip_pdf_extractor}_test.dart`.
- Modify: `offline_bulk_exceptions.dart`, `reconcile_offline_index.dart`, `offline_reconcile_provider.dart`, `clear_offline_cache.dart`, `offline_core_providers.dart`, `lib/core/constants/storage_keys.dart`, `lib/core/constants/api_endpoints.dart`, `pubspec.yaml`, `offline_pdf_repository.dart` + `offline_pdf_repository_impl.dart` (só se `indexExtractedBatch`/`ExtractedPdfItem` ficarem sem chamador), testes: `reconcile_offline_index_test.dart`, `offline_reconcile_provider_test.dart`, `offline_cache_status_provider_test.dart`, `migrate_offline_storage_test.dart`, `clear_offline_cache_test.dart`, `offline_test_helpers.dart`, `offline_settings_screen_test.dart`.

**Interfaces:**
- `ReconcileOfflineIndex.call({bool isIndexAvailable = true})` — sem `materialPackage`/`materialCategory`; `OfflineReconcileNotifier.requestReconcile()` sem parâmetros.
- `ClearOfflineCache(repository, catalogLocal, store, bulkCategoriesStore, selectedCategoriesStore, offlineAvailableStore)` — sem checkpoint store.
- `offline_bulk_exceptions.dart` fica com `InsufficientDiskSpaceException`, `OfflineBulkCancelledException`, `PdfStorageWriteException`, `AudioStorageWriteException`.
- `archive` passa de `dependencies` para `dev_dependencies` (só `test/helpers/isar_plus_native_library.dart` a usa).

- [ ] **Step 1: Apagar ficheiros**

```bash
git rm lib/features/offline/data/datasources/zip_package_downloader.dart lib/features/offline/data/datasources/zip_package_downloader_native.dart lib/features/offline/data/datasources/zip_package_downloader_web.dart lib/features/offline/data/datasources/offline_manifest_remote_datasource.dart lib/features/offline/data/datasources/offline_bulk_checkpoint_store.dart lib/features/offline/data/models/offline_manifest_dto.dart lib/features/offline/data/utils/zip_extraction_runner.dart lib/features/offline/data/utils/zip_extraction_runner_native.dart lib/features/offline/data/utils/zip_extraction_runner_web.dart lib/features/offline/data/utils/zip_pdf_extractor.dart lib/features/offline/data/utils/zip_pdf_extractor_native.dart lib/features/offline/data/utils/zip_pdf_extractor_shared.dart lib/features/offline/data/utils/zip_pdf_extractor_types.dart lib/features/offline/data/utils/zip_pdf_extractor_web.dart lib/features/offline/data/providers/offline_bulk_providers.dart lib/features/offline/domain/entities/offline_bulk_checkpoint.dart lib/features/offline/domain/entities/offline_manifest.dart lib/features/offline/domain/usecases/download_offline_packages.dart lib/features/offline/domain/usecases/extract_and_store_pdfs.dart test/unit/features/offline/download_offline_packages_test.dart test/unit/features/offline/extract_and_store_pdfs_test.dart test/unit/features/offline/offline_bulk_checkpoint_store_test.dart test/unit/features/offline/zip_extraction_runner_native_test.dart test/unit/features/offline/zip_extraction_runner_web_test.dart test/unit/features/offline/zip_package_downloader_test.dart test/unit/features/offline/zip_pdf_extractor_test.dart
```

Se `lib/features/offline/data/models/` ficar vazia, apagar a pasta.

- [ ] **Step 2: Reconcile sem escopo**

`reconcile_offline_index.dart`:
- apagar `import '../entities/offline_manifest.dart';` e, se ficar sem uso, `offline_category_resolver.dart`;
- assinatura `Future<ReconcileOutcome> call({bool isIndexAvailable = true}) async {`;
- apagar `scopedPdfIds`/`isFullReconcile`: o corpo usa `if (!isIndexAvailable) { … indexUnavailable }`, `final entries = await _repository.listAll();`, as guardas (`filesOnDisk`) passam a correr sempre, `protectedPaths = indexedPaths`, e a remoção de órfãos é só o ramo `else if (scopedPdfIds == null)` (sem condição);
- apagar `_pdfIdsForScope` e `_pathBelongsToScope`;
- doc da classe: remover as frases sobre reconcile **escopado**.

`offline_reconcile_provider.dart`: apagar o import de `offline_manifest.dart`; `requestReconcile()` sem parâmetros; apagar `isScoped` (o throttle e `_persistLastReconcileAt` correm sempre); a chamada vira `.call(isIndexAvailable: ref.read(isarAvailableProvider))`; doc: apagar «Com [materialPackage]… escopado…».

Testes: em `reconcile_offline_index_test.dart` apagar os testes que passam `materialPackage:` (os que constroem `OfflineMaterialPackage`) e o import; em `offline_reconcile_provider_test.dart`, `offline_cache_status_provider_test.dart`, `offline_settings_screen_test.dart` remover os parâmetros `materialPackage`/`materialCategory` dos fakes de `requestReconcile`, o campo `lastPackage` e o teste que o usa (linha ~318 do provider test), e os imports de `offline_manifest.dart`.

- [ ] **Step 3: `ClearOfflineCache`, providers, exceções, chaves**

`clear_offline_cache.dart`: apagar o parâmetro/campo `_checkpointStore`, o bloco `final checkpoint = await _checkpointStore.load(); …` e a linha `await _checkpointStore.clear();` em `_fullClear`; doc: «tree + bulk/seleção + `OFFLINE_AVAILABLE=FALSE`». `clear_offline_cache_test.dart`: remover o argumento correspondente.

`offline_core_providers.dart`: apagar `offlineManifestRemoteDatasourceProvider`, `offlineBulkCheckpointStoreProvider`, os imports de `offline_bulk_checkpoint_store.dart`, `offline_manifest_remote_datasource.dart` e `dio_provider.dart` (se sem uso); `clearOfflineCacheProvider` deixa de passar o checkpoint store. Doc de `offlineBulkCategoriesStoreProvider`: «categorias com bulk PDF a PDF concluído».

`offline_bulk_exceptions.dart`: apagar `ZipDownloadSizeMismatchException`, `ZipDownloadCancelledException`, `ZipDownloadStalledException`, `ZipCorruptedException`. Doc de `InsufficientDiskSpaceException`: «Espaço em disco insuficiente para o download em massa (Coldigom UC-09).»

`storage_keys.dart`: apagar `offlineManifestJson`, `offlineManifestCacheTime` (e o doc de cada). `api_endpoints.dart`: apagar `offlineManifest`.

`pubspec.yaml`: mover `archive: ^4.0.0` de `dependencies` para `dev_dependencies`; `flutter pub get`.

`offline_test_helpers.dart`: apagar `createSampleZip`, `FakeOfflineManifestRemoteDatasource` e os imports `package:archive/archive.dart`, `offline_manifest_remote_datasource.dart`, `offline_manifest.dart`; `migrate_offline_storage_test.dart`: apagar o teste que usa `OfflineManifestRemoteDatasource`/`OfflineManifestDto` (é o teste do cache do manifest offline, sem função agora) e os imports.

`offline_pdf_repository.dart`: se `indexExtractedBatch(List<ExtractedPdfItem>)` ficar sem chamador em `lib/` (`grep -rn indexExtractedBatch lib`), apagar da porta, da impl e do `_StubRepo` dos testes; `ExtractedPdfItem` vivia em `zip_pdf_extractor_types.dart` — se algum ficheiro que fica o importar, mover a classe para `offline_pdf_batch_item.dart` em vez de apagar.

- [ ] **Step 4: Correr tudo**

Run: `flutter pub get && flutter analyze && flutter test`
Expected: analyze limpo, suíte verde. Corrigir imports órfãos que o analyze apontar (todos devem ser dos ficheiros listados acima).

- [ ] **Step 5: Commit**

```bash
git add -A lib/features/offline lib/core/constants pubspec.yaml pubspec.lock test/unit/features/offline test/widget/features/offline
git commit -m "chore(offline): apaga pipeline ZIP, checkpoint e manifest offline; reconcile só completo; archive vira dev dep

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Unidade 7 — Docs e entrega

### Task 14: Documentação e PR

**Files:**
- Modify: `README.md`, `docs/features/FEATURE_INDEX.md`, `docs/features/LOUVOR_GROUPING.md`, `MAPEAMENTO_PLPCG_FLUTTER.md`, `docs/superpowers/specs/2026-09-18-catalogo-coldigom-modo-unico-design.md`.

- [ ] **Step 1: README**

Substituir a secção «Modo dual PLPCG + Coldigom (fase 1)» por:

```markdown
## Catálogo e backends

O catálogo (manifest + checksum), os PDFs e os materiais Coldigom vêm do Worker
`coldigom-api` (`COLDIGOM_API_BASE_URL`). O Worker `plpcg-catalog`
(`PLPCG_API_BASE_URL`) serve auth, playlists, links curtos e Lista ao Vivo.
Os dois defines são obrigatórios — sem um deles o app mostra a tela de
configuração ausente. Ficheiros prontos em `dart_defines/*.json`
(`--dart-define-from-file`).

Um louvor = um praise do coldigom: as entradas legadas do manifest (`pdfId`,
`shortId`) e os materiais Coldigom (áudio, cifra, letra, gestos) aparecem no
mesmo card. Ver `docs/superpowers/specs/2026-09-18-catalogo-coldigom-modo-unico-design.md`.
```

- [ ] **Step 2: FEATURE_INDEX**

- Linha `catalog` (tabela de features): acrescentar ao fim «**catálogo pelo coldigom set/2026** — `GET /api/plpcg/manifest` + `/checksum` ([CatalogRemoteDatasource] no Dio coldigom); `praiseId`/`materialId` no [Louvor]/[LouvorCache]; `effectiveGroupId` = `praiseId`; fusão por praise no [CompositeCatalogSource] com [ManifestMaterialAliases]; [knownPraiseIdsProvider]; spec [catálogo coldigom modo único](../superpowers/specs/2026-09-18-catalogo-coldigom-modo-unico-design.md)».
- Linha `offline`: acrescentar «**UC-09 sem ZIP set/2026** — primeira configuração via [DownloadMissingPdfs] (PDF a PDF, `CancelToken`); pipeline ZIP/checkpoint/`offline-manifest.json` removidos».
- Linha `ApiEndpoints` (APIs públicas — Core): «só rotas do Worker `plpcg-catalog`; catálogo e assets em `ColdigomEndpoints` (`plpcgManifest`, `plpcgManifestChecksum`)».
- Débito técnico do gate de share: trocar «Após a remoção do acervo PLPCG do coldigui» por «Follow-up da spec catálogo-coldigom §11 (o acervo foi fundido em 2026-09-18; o gate ainda decide por entradas Coldigom sem `shortId`)».
- Linhas `Louvor`/`LouvorGroup` (Domain): acrescentar `praiseId`, `materialId`; «`effectiveGroupId` = praiseId → groupId → calculado».

- [ ] **Step 3: LOUVOR_GROUPING**

No topo, depois de `**Status:**`, acrescentar:

```markdown
**Atualização set/2026:** a identidade do louvor lógico passou a ser o `praiseId` do coldigom (`Louvor.effectiveGroupId` = `praiseId` → `groupId` do manifest → calculado). O `groupId` fuzzy do script Python continua no manifest e no Isar, mas só decide quando não há `praiseId` (cache anterior ao primeiro sync). Consequência aceite: 82 grupos fuzzy que juntavam 2 praises separam-se; 64 praises que estavam em 2 grupos fundem-se. Ver spec `docs/superpowers/specs/2026-09-18-catalogo-coldigom-modo-unico-design.md` §4.2.
```

- [ ] **Step 4: MAPEAMENTO**

Em §2.3 e §11.1, antes de cada tabela, inserir: «> **set/2026:** estes endpoints do site `plpcg.com` foram desligados. O app usa `GET /api/plpcg/manifest`, `GET /api/plpcg/manifest/checksum` e `GET /assets/praises/**` do Worker `coldigom-api`; `/offline-manifest.json` e `/packages/**` não têm substituto (offline PDF a PDF).»

- [ ] **Step 5: Spec §12**

Acrescentar ao spec uma secção `## 12. Estado implementado e desvios` com os quatro desvios listados no topo deste plano (writer inalterado; alias pela URL do `pdf`; sem «retomar»; adapter preenche `praiseId`) e a verificação de `isColdigom` (fim da unidade 5).

- [ ] **Step 6: Suíte completa + commit**

Run: `./scripts/test_all.sh` (com Chrome) ou `./scripts/test_all.sh --vm-only` se não houver Chrome — registar qual correu.

```bash
git add README.md docs/features/FEATURE_INDEX.md docs/features/LOUVOR_GROUPING.md MAPEAMENTO_PLPCG_FLUTTER.md docs/superpowers/specs/2026-09-18-catalogo-coldigom-modo-unico-design.md
git commit -m "docs: catálogo servido pelo coldigom — README, índice de features, agrupamento e mapeamento

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 7: PR**

```bash
git push -u origin feat/catalogo-coldigom-modo-unico
gh pr create --base web/integration --title "Catálogo PLPCG servido pelo coldigom — fim do modo dual" --body "$(cat <<'EOF'
## Resumo
- manifest/checksum passam a vir do `coldigom-api` (`/api/plpcg/manifest`); PDFs abrem pela URL absoluta do manifest
- um louvor por praise: `praiseId`/`materialId` no modelo, fusão manifest + extras Coldigom no `CompositeCatalogSource`, ids legados e `shortId` preservados, cache de PDFs intacto
- primeira configuração offline PDF a PDF (`DownloadMissingPdfs` com cancel); pipeline ZIP removido
- `COLDIGOM_API_BASE_URL` obrigatório; guard de arranque cobre os dois defines

Spec: `docs/superpowers/specs/2026-09-18-catalogo-coldigom-modo-unico-design.md` · Plano: `docs/superpowers/plans/2026-09-18-catalogo-coldigom-modo-unico.md`

## Validação
- `./scripts/test_all.sh` verde (indicar VM-only se for o caso)
- Checklist manual em prod v2 (spec §9) — pendente após deploy

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Validação manual pós-deploy (spec §9)

Não faz parte do plano de código; fica aqui para a entrega: (1) PDF de playlist antiga e de link `?s=`; (2) playlist recente com id Coldigom coberto; (3) sheet de louvor do manifest mostra áudio/cifra após warmup; (4) busca «a ti senhor» → um card, remoto «Atualizado»; (5) primeira configuração offline «Gestos em Gravura» até ao fim; (6) rede: PDFs em `coldigom-api…/assets/praises/…`, zero chamadas a `plpcg.com/assets`.

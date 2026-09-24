# Filtro Materiais — plano 2: app (classes, famílias e chips de Tipo)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Organizar a seção «Materiais» dos filtros (Home e /biblioteca): chips de Tipo abaixo do título, uma seção por classe e as variantes recolhidas num chip de família com a regra de refinar das subtags.

**Architecture:**
- O dump do catálogo já traz a taxonomia dos kinds (plano 1). O app a lê no DTO, grava nas SharedPreferences a cada dump novo e a expõe em `coldigomKindTaxonomyProvider`.
- Funções puras montam as seções, calculam a seleção efetiva (refinar, depois expandir o pai) e aplicam as ações de toque. Os widgets são finos em cima delas.
- O filtro continua guardando ids de kind. Só o casamento em `matchesCatalogFilters` passa a expandir pai → filhos.

**Tech Stack:** Flutter, Riverpod 3, SharedPreferences, `flutter_test`; l10n com `flutter gen-l10n` (template `lib/l10n/app_pt.arb`).

**Spec:** `docs/superpowers/specs/2026-09-24-filtro-materiais-classes-design.md` (§4, §5, §6, §7, §8). O plano 1 (coldigom) é `docs/superpowers/plans/2026-09-24-filtro-materiais-1-coldigom.md`. Os dois são independentes: com o coldigom antigo, a taxonomia vem vazia e a seção fica plana como hoje.

## Global Constraints

- **Repo e branch:** `coldigui`, branch `feat/filtro-materiais-classes` a partir de `web/integration`, num worktree: `git -C "/Volumes/SSD 2TB SD/dev/coldigui" worktree add .claude/worktrees/filtro-materiais -b feat/filtro-materiais-classes web/integration`. Use `git -C <worktree>` em vez de `cd … && git …`.
- **Conflito conhecido:** a entrega das subtags da Coletânea (`feat/secoes-coletanea-subtags`, outra sessão) tira a seção Categoria de `catalog_filter_sections.dart`. Antes de mesclar esta branch, faça **rebase sobre `web/integration`** depois do merge dela. Não mexa na seção Categoria nem nas seções Tags/Subtags.
- **Regra de seleção** (a das subtags em produção, commit `d8dd304d`):
  - marcar o pai tira os filhos marcados;
  - desmarcar o pai tira os filhos;
  - filho marcado com o pai marcado refina o pai;
  - pai + filho vale pelo filho.
- **O filtro guarda ids**, não rótulos. A URL e as prefs (`CatalogFilterState`, formato v2) não mudam de formato.
- **Chips de Tipo:** vêm do `MaterialKind` do app (`pdf`, `chord`, `audio`, `youtube`, `gesture`), nessa ordem, e só os que algum kind tem. O estado fica só no widget: não vai para a URL nem para as prefs.
- **Um kind selecionado nunca some** da lista, mesmo fora do tipo marcado.
- **Visual:** o `FilterChip` de hoje (fundo `AppColors.card`, borda `AppColors.title` 1.5; selecionado com fundo `AppColors.gold` a 30% e borda `AppColors.gold` 2; raio 24). Família refinada e filho «incluído» usam borda **tracejada** dourada.
- **l10n:** toda string nova em `app_pt.arb` e `app_en.arb`; rode `flutter gen-l10n` e faça commit dos arquivos gerados.
- **Testes:** `flutter test <arquivo>`; no fim, `flutter test` inteiro e `flutter analyze`.
- **Commits:** em português, terminando com `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.
- **Sem deploy neste plano.** O deploy em v2.plpcg.com e a homologação (spec §8) são com ok do dono.

## Review Focus

1. **App atualizado depois do coldigom:** o ETag guardado é do dump que já trazia a taxonomia, mas o app antigo a ignorou. Sem a autocura, o app novo receberia 304 para sempre e nunca teria classes. Coberto na Task 2: sem taxonomia gravada, o pedido sai sem `If-None-Match`.
2. **Link antigo com pai e filho juntos:** vale só pelo filho. Coberto na Task 4 (`effectiveMaterialKindIds`).
3. **Tipo marcado esconde o pai de uma família com filhos visíveis:** a família continua, com o pai como cabeça; com um filho só, vira chip simples. Coberto na Task 5.
4. **Selecionado de um kind que sumiu do catálogo** (link velho): continua com chip, rotulado pelo nome da taxonomia ou pelo id. Coberto na Task 5.
5. **Coldigom antigo (taxonomia vazia):** a seção fica plana, sem o rótulo «Outros», como hoje. Coberto nas Tasks 5 e 7.

---

## File Structure

| Arquivo | Papel |
|---|---|
| `lib/features/catalog/domain/entities/material_kind_taxonomy.dart` (novo) | `MaterialKindClass`, `MaterialKindTaxon`, `MaterialKindTaxonomy`: parse tolerante do JSON do dump, `toJson`, `childrenOf`, `parentOf`. |
| `lib/features/coldigom/data/models/coldigom_catalog_dto.dart` | `ColdigomCatalogDto.kindTaxonomy`. |
| `lib/core/constants/storage_keys.dart` | Chave `coldigomKindTaxonomy`. |
| `lib/features/coldigom/data/datasources/coldigom_catalog_sync_metadata_store.dart` | `readKindTaxonomy` / `writeKindTaxonomy`. |
| `lib/features/coldigom/domain/usecases/sync_coldigom_catalog.dart` | Grava a taxonomia a cada dump; autocura do ETag. |
| `lib/features/coldigom/presentation/providers/coldigom_catalog_providers.dart` | `coldigomKindTaxonomyProvider` + invalidação depois do sync. |
| `lib/features/catalog/domain/entities/catalog_filter_options.dart` | `CatalogKindOption.types`. |
| `lib/features/catalog/domain/utils/material_kind_selection.dart` (novo) | Seleção efetiva, ação de toque, estado da família. |
| `lib/features/catalog/domain/usecases/matches_catalog_filters.dart` | Casamento com a seleção efetiva. |
| `lib/features/catalog/presentation/providers/catalog_filters_provider.dart` | `toggleMaterialKind` com a regra de família. |
| `lib/features/catalog/presentation/providers/home_search_provider.dart`, `lib/features/library/presentation/providers/library_group_results_provider.dart` | Passam a taxonomia ao casamento. |
| `lib/features/catalog/domain/usecases/build_material_kind_sections.dart` (novo) | Monta seções, unidades (chip ou família), contagem por tipo e ocultos. |
| `lib/features/catalog/presentation/widgets/material_kind_chips.dart` (novo) | `DashedRoundedRectangleBorder`, `MaterialKindChip`, `MaterialKindFamilyChip`, `MaterialTypeChip`. |
| `lib/features/catalog/presentation/widgets/material_kind_filter_section.dart` (novo) | A seção Materiais inteira. |
| `lib/features/catalog/presentation/widgets/catalog_filter_sections.dart` | Troca a seção Materiais antiga pela nova. |
| `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb` + gerados | Strings novas. |

---

### Task 1: Taxonomia no domínio e no DTO do catálogo

**Files:**
- Create: `lib/features/catalog/domain/entities/material_kind_taxonomy.dart`
- Modify: `lib/features/coldigom/data/models/coldigom_catalog_dto.dart` (classe `ColdigomCatalogDto`, perto da linha 160)
- Test: `test/unit/features/catalog/material_kind_taxonomy_test.dart` (novo), `test/unit/features/coldigom/coldigom_catalog_dto_test.dart`

**Interfaces:**
- Produces:

```dart
class MaterialKindClass { const MaterialKindClass({required String id, required String label}); }
class MaterialKindTaxon {
  const MaterialKindTaxon({required String name, String? classId, String? parentId, int? order});
}
class MaterialKindTaxonomy {
  MaterialKindTaxonomy({List<MaterialKindClass> classes, Map<String, MaterialKindTaxon> kinds});
  static final MaterialKindTaxonomy empty;
  factory MaterialKindTaxonomy.fromJson(Map<String, dynamic> json); // lê `kindClasses` e `kinds` do dump
  Map<String, dynamic> toJson();                                   // mesmo formato do dump
  final List<MaterialKindClass> classes;          // ordem de exibição
  final Map<String, MaterialKindTaxon> kinds;
  bool get isEmpty;
  List<String> childrenOf(String id);             // filhos diretos, na ordem do dump
  String? parentOf(String id);
}
// ColdigomCatalogDto ganha: final MaterialKindTaxonomy? kindTaxonomy;
```

- [ ] **Step 1: Criar o worktree**

```bash
git -C "/Volumes/SSD 2TB SD/dev/coldigui" worktree add .claude/worktrees/filtro-materiais -b feat/filtro-materiais-classes web/integration
```

Trabalhe dentro de `"/Volumes/SSD 2TB SD/dev/coldigui/.claude/worktrees/filtro-materiais"` a partir daqui. Rode `flutter pub get` nele.

- [ ] **Step 2: Escrever os testes que falham**

`test/unit/features/catalog/material_kind_taxonomy_test.dart`:

```dart
import 'package:coldigui/features/catalog/domain/entities/material_kind_taxonomy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final json = <String, dynamic>{
    'kindClasses': [
      {'id': 'metais', 'label': 'Metais'},
      {'id': 'banda', 'label': 'Banda'},
    ],
    'kinds': [
      {'id': 'sax', 'name': 'Saxofone', 'class': 'metais', 'order': 30},
      {'id': 'sax-alto', 'name': 'Saxofone alto', 'class': 'metais', 'parent': 'sax', 'order': 50},
      {'id': 'sax-tenor', 'name': 'Saxofone tenor', 'class': 'metais', 'parent': 'sax', 'order': 60},
      {'id': 'novo', 'name': 'Novo'},
    ],
  };

  test('lê classes na ordem e kinds com classe, pai e ordem', () {
    final t = MaterialKindTaxonomy.fromJson(json);
    expect(t.classes, const [
      MaterialKindClass(id: 'metais', label: 'Metais'),
      MaterialKindClass(id: 'banda', label: 'Banda'),
    ]);
    expect(
      t.kinds['sax-alto'],
      const MaterialKindTaxon(name: 'Saxofone alto', classId: 'metais', parentId: 'sax', order: 50),
    );
    expect(t.kinds['novo'], const MaterialKindTaxon(name: 'Novo'));
    expect(t.childrenOf('sax'), ['sax-alto', 'sax-tenor']);
    expect(t.childrenOf('sax-alto'), isEmpty);
    expect(t.parentOf('sax-tenor'), 'sax');
    expect(t.parentOf('sax'), isNull);
    expect(t.isEmpty, isFalse);
  });

  test('toJson volta ao mesmo formato e relê igual', () {
    final t = MaterialKindTaxonomy.fromJson(json);
    final again = MaterialKindTaxonomy.fromJson(t.toJson());
    expect(again.classes, t.classes);
    expect(again.kinds, t.kinds);
  });

  test('tolerante: chaves ausentes, tipos errados e itens quebrados', () {
    final t = MaterialKindTaxonomy.fromJson({
      'kindClasses': 'x',
      'kinds': [
        42,
        {'id': 'a'},
        {'id': 'b', 'name': 'B', 'class': 7, 'parent': 'b', 'order': '3'},
      ],
    });
    expect(t.classes, isEmpty);
    // Sem nome o kind cai; pai de si mesmo e tipos errados viram nulos.
    expect(t.kinds, {'b': const MaterialKindTaxon(name: 'B')});
    expect(MaterialKindTaxonomy.fromJson(const {}).isEmpty, isTrue);
    expect(MaterialKindTaxonomy.empty.isEmpty, isTrue);
  });
}
```

Em `test/unit/features/coldigom/coldigom_catalog_dto_test.dart`, acrescente:

```dart
  test('lê a taxonomia dos kinds (kindClasses + class/parent/order)', () {
    final dto = ColdigomCatalogDto.fromJson({
      'generatedAt': '',
      'kindClasses': [
        {'id': 'metais', 'label': 'Metais'},
      ],
      'kinds': [
        {'id': 'sax', 'name': 'Saxofone', 'class': 'metais', 'order': 30},
        {'id': 'sax-alto', 'name': 'Saxofone alto', 'class': 'metais', 'parent': 'sax', 'order': 50},
      ],
      'praises': [],
    });
    expect(dto.kindNames, {'sax': 'Saxofone', 'sax-alto': 'Saxofone alto'});
    expect(dto.kindTaxonomy!.childrenOf('sax'), ['sax-alto']);
    expect(dto.kindTaxonomy!.classes.single.label, 'Metais');
  });

  test('dump sem taxonomia (coldigom antigo) dá taxonomia vazia', () {
    final dto = ColdigomCatalogDto.fromJson(_fixture());
    expect(dto.kindTaxonomy!.classes, isEmpty);
    expect(dto.kindTaxonomy!.kinds.values.every((k) => k.classId == null), isTrue);
  });
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `flutter test test/unit/features/catalog/material_kind_taxonomy_test.dart test/unit/features/coldigom/coldigom_catalog_dto_test.dart`
Expected: FAIL de compilação (`material_kind_taxonomy.dart` não existe).

- [ ] **Step 4: Implementar a entidade**

`lib/features/catalog/domain/entities/material_kind_taxonomy.dart`:

```dart
import 'package:flutter/foundation.dart';

/// Classe do filtro «Materiais» (Metais, Banda…) — `material_kind_classes`
/// do coldigom (spec filtro-materiais §2.1).
@immutable
class MaterialKindClass {
  const MaterialKindClass({required this.id, required this.label});

  final String id;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is MaterialKindClass && other.id == id && other.label == label;

  @override
  int get hashCode => Object.hash(id, label);

  @override
  String toString() => 'MaterialKindClass($id, $label)';
}

/// Um kind na taxonomia: nome, classe, pai (família de um nível) e ordem de
/// grade dentro da classe. Tudo opcional menos o nome.
@immutable
class MaterialKindTaxon {
  const MaterialKindTaxon({
    required this.name,
    this.classId,
    this.parentId,
    this.order,
  });

  final String name;
  final String? classId;
  final String? parentId;
  final int? order;

  @override
  bool operator ==(Object other) =>
      other is MaterialKindTaxon &&
      other.name == name &&
      other.classId == classId &&
      other.parentId == parentId &&
      other.order == order;

  @override
  int get hashCode => Object.hash(name, classId, parentId, order);

  @override
  String toString() => 'MaterialKindTaxon($name, $classId, $parentId, $order)';
}

/// Classes e famílias dos material kinds, como o dump `GET /api/plpcg/catalog`
/// as manda (`kindClasses` + `class`/`parent`/`order` em `kinds`).
///
/// Vazia quando o coldigom ainda não tem a migração: a seção Materiais fica
/// plana, como antes.
class MaterialKindTaxonomy {
  MaterialKindTaxonomy({
    List<MaterialKindClass> classes = const [],
    Map<String, MaterialKindTaxon> kinds = const {},
  }) : classes = List.unmodifiable(classes),
       kinds = Map.unmodifiable(kinds),
       _children = _indexChildren(kinds);

  static final MaterialKindTaxonomy empty = MaterialKindTaxonomy();

  final List<MaterialKindClass> classes;
  final Map<String, MaterialKindTaxon> kinds;
  final Map<String, List<String>> _children;

  bool get isEmpty => classes.isEmpty && kinds.isEmpty;

  /// Filhos diretos de [id], na ordem em que vieram no dump.
  List<String> childrenOf(String id) => _children[id] ?? const [];

  String? parentOf(String id) => kinds[id]?.parentId;

  /// Mesma tolerância do resto do DTO: item quebrado cai, campo de tipo
  /// errado vira nulo, e um kind pai de si mesmo perde o pai.
  factory MaterialKindTaxonomy.fromJson(Map<String, dynamic> json) {
    final classes = <MaterialKindClass>[];
    final rawClasses = json['kindClasses'];
    for (final item in rawClasses is List<dynamic> ? rawClasses : const []) {
      if (item is! Map<String, dynamic>) continue;
      final id = item['id'];
      final label = item['label'];
      if (id is String && label is String) {
        classes.add(MaterialKindClass(id: id, label: label));
      }
    }
    final kinds = <String, MaterialKindTaxon>{};
    final rawKinds = json['kinds'];
    for (final item in rawKinds is List<dynamic> ? rawKinds : const []) {
      if (item is! Map<String, dynamic>) continue;
      final id = item['id'];
      final name = item['name'];
      if (id is! String || name is! String) continue;
      final classId = item['class'];
      final parentId = item['parent'];
      final order = item['order'];
      kinds[id] = MaterialKindTaxon(
        name: name,
        classId: classId is String ? classId : null,
        parentId: parentId is String && parentId != id ? parentId : null,
        order: order is int ? order : null,
      );
    }
    return MaterialKindTaxonomy(classes: classes, kinds: kinds);
  }

  Map<String, dynamic> toJson() => {
    'kindClasses': [
      for (final c in classes) {'id': c.id, 'label': c.label},
    ],
    'kinds': [
      for (final entry in kinds.entries)
        {
          'id': entry.key,
          'name': entry.value.name,
          if (entry.value.classId != null) 'class': entry.value.classId,
          if (entry.value.parentId != null) 'parent': entry.value.parentId,
          if (entry.value.order != null) 'order': entry.value.order,
        },
    ],
  };

  static Map<String, List<String>> _indexChildren(
    Map<String, MaterialKindTaxon> kinds,
  ) {
    final children = <String, List<String>>{};
    for (final entry in kinds.entries) {
      final parent = entry.value.parentId;
      if (parent != null) children.putIfAbsent(parent, () => []).add(entry.key);
    }
    return {
      for (final entry in children.entries)
        entry.key: List.unmodifiable(entry.value),
    };
  }
}
```

- [ ] **Step 5: Ligar no DTO**

Em `coldigom_catalog_dto.dart`, importe a entidade:

```dart
import '../../../catalog/domain/entities/material_kind_taxonomy.dart';
```

Na classe `ColdigomCatalogDto`: acrescente o campo opcional no construtor `const` e no `fromJson`:

```dart
  const ColdigomCatalogDto({
    required this.generatedAt,
    required this.kindNames,
    required this.praises,
    this.kindTaxonomy,
  });

  // …campos existentes…

  /// Classes e famílias dos kinds (spec filtro-materiais §4.1). Vazia com o
  /// coldigom anterior à migração; `null` só em DTOs montados à mão (testes).
  final MaterialKindTaxonomy? kindTaxonomy;
```

No fim de `fromJson`, no `return ColdigomCatalogDto(…)`, acrescente:

```dart
      kindTaxonomy: MaterialKindTaxonomy.fromJson(json),
```

- [ ] **Step 6: Rodar e ver passar**

Run: `flutter test test/unit/features/catalog/material_kind_taxonomy_test.dart test/unit/features/coldigom/coldigom_catalog_dto_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/catalog/domain/entities/material_kind_taxonomy.dart \
  lib/features/coldigom/data/models/coldigom_catalog_dto.dart \
  test/unit/features/catalog/material_kind_taxonomy_test.dart \
  test/unit/features/coldigom/coldigom_catalog_dto_test.dart
git commit -m "feat(catalog): taxonomia dos material kinds no DTO do catálogo

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Guardar a taxonomia a cada dump e expor num provider

**Files:**
- Modify: `lib/core/constants/storage_keys.dart` (junto de `coldigomCatalogCount`, perto da linha 55)
- Modify: `lib/features/coldigom/data/datasources/coldigom_catalog_sync_metadata_store.dart`
- Modify: `lib/features/coldigom/domain/usecases/sync_coldigom_catalog.dart` (`run`)
- Modify: `lib/features/coldigom/presentation/providers/coldigom_catalog_providers.dart` (novo provider + `_run`)
- Test: `test/unit/features/coldigom/sync_coldigom_catalog_test.dart`

**Interfaces:**
- Consumes: `MaterialKindTaxonomy` e `ColdigomCatalogDto.kindTaxonomy` (Task 1).
- Produces:

```dart
// StorageKeys
static const String coldigomKindTaxonomy = 'coldigomKindTaxonomy';
// ColdigomCatalogSyncMetadataStore
MaterialKindTaxonomy? readKindTaxonomy();          // null = nunca gravada
Future<void> writeKindTaxonomy(MaterialKindTaxonomy taxonomy);
// coldigom_catalog_providers.dart
final coldigomKindTaxonomyProvider = Provider<MaterialKindTaxonomy>(...);
```

- [ ] **Step 1: Escrever os testes que falham**

Em `sync_coldigom_catalog_test.dart`, importe:

```dart
import 'package:coldigui/features/catalog/domain/entities/material_kind_taxonomy.dart';
```

**Ajuste dos testes existentes:** a autocura (abaixo) faz o pedido sair sem `If-None-Match` quando não há taxonomia gravada. Em **todo** teste deste arquivo que espera um `If-None-Match` com valor (por exemplo, o de `304 → noop`), grave a taxonomia junto do ETag, logo depois do `metadata.markReplaced(...)`:

```dart
      await metadata.writeKindTaxonomy(MaterialKindTaxonomy.empty);
```

Acrescente os testes:

```dart
  group('taxonomia dos kinds (spec filtro-materiais §4.1)', () {
    ColdigomCatalogDto comTaxonomia() {
      final json = jsonDecode(
        File('test/fixtures/coldigom_catalog_sample.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      json['kindClasses'] = [
        {'id': 'regencia', 'label': 'Regência e geral'},
      ];
      json['kinds'] = [
        for (final k in json['kinds'] as List<dynamic>)
          {...(k as Map<String, dynamic>), 'class': 'regencia'},
      ];
      return ColdigomCatalogDto.fromJson(json);
    }

    test('200 grava a taxonomia nas prefs', () async {
      final remote = _ScriptedRemote(
        (_) async => ColdigomCatalogFresh(catalog: comTaxonomia(), etag: '"v1"'),
      );

      await usecase(remote).run();

      final stored = metadata.readKindTaxonomy()!;
      expect(stored.classes.single.id, 'regencia');
      expect(stored.kinds.values.every((k) => k.classId == 'regencia'), isTrue);
    });

    test('sem Isar (web) também grava a taxonomia', () async {
      final remote = _ScriptedRemote(
        (_) async => ColdigomCatalogFresh(catalog: comTaxonomia(), etag: '"v1"'),
      );
      final degraded = SyncColdigomCatalog(
        remote: remote,
        local: const ColdigomCatalogLocalDatasource.unavailable(),
        metadata: metadata,
        now: () => fixedNow,
      );

      expect(await degraded.run(), isA<ColdigomCatalogSyncInMemory>());
      expect(metadata.readKindTaxonomy()!.classes.single.id, 'regencia');
    });

    test('autocura: ETag guardado sem taxonomia pede o dump inteiro', () async {
      await metadata.markReplaced(etag: '"v1"', count: 1, at: DateTime.utc(2026, 1, 1));
      await local.replaceAll([_storedRow('antigo', shortId: 'abc')]);
      final remote = _ScriptedRemote(
        (_) async => ColdigomCatalogFresh(catalog: comTaxonomia(), etag: '"v1"'),
      );

      await usecase(remote).run();

      expect(remote.ifNoneMatches, [null]);
      expect(metadata.readKindTaxonomy(), isNotNull);
    });

    test('taxonomia ilegível nas prefs conta como ausente', () async {
      SharedPreferences.setMockInitialValues({'coldigomKindTaxonomy': '{quebrado'});
      final store = ColdigomCatalogSyncMetadataStore(await SharedPreferences.getInstance());
      expect(store.readKindTaxonomy(), isNull);
    });
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/coldigom/sync_coldigom_catalog_test.dart`
Expected: FAIL de compilação (`writeKindTaxonomy`/`readKindTaxonomy` não existem).

- [ ] **Step 3: Chave e store**

Em `storage_keys.dart`, depois de `coldigomCatalogCount`:

```dart
  /// Classes e famílias dos material kinds do último dump (JSON no formato
  /// do dump: `{kindClasses, kinds}`). Ausente = nunca gravada, e o próximo
  /// sync pede o dump inteiro (spec filtro-materiais §4.1).
  static const String coldigomKindTaxonomy = 'coldigomKindTaxonomy';
```

Em `coldigom_catalog_sync_metadata_store.dart`, importe `dart:convert` e a entidade, e acrescente na classe:

```dart
  /// Taxonomia dos kinds do último dump; `null` quando nunca foi gravada ou
  /// o JSON está ilegível.
  MaterialKindTaxonomy? readKindTaxonomy() {
    final raw = _prefs.getString(StorageKeys.coldigomKindTaxonomy);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic>
          ? MaterialKindTaxonomy.fromJson(decoded)
          : null;
    } on FormatException {
      return null;
    }
  }

  /// Gravada a cada dump novo, com ou sem Isar: sem ela o filtro Materiais
  /// não tem classes, e ela não é um ETag (não há risco de `304` órfão).
  Future<void> writeKindTaxonomy(MaterialKindTaxonomy taxonomy) => _prefs
      .setString(StorageKeys.coldigomKindTaxonomy, jsonEncode(taxonomy.toJson()));
```

Imports:

```dart
import 'dart:convert';

import '../../../catalog/domain/entities/material_kind_taxonomy.dart';
```

- [ ] **Step 4: Sync grava e faz a autocura**

Em `sync_coldigom_catalog.dart`, importe a entidade:

```dart
import '../../../catalog/domain/entities/material_kind_taxonomy.dart';
```

Troque a condição do ETag:

```dart
      final etag =
          !persist ||
              _local.count() == 0 ||
              !_local.hasAnyShortId() ||
              _metadata.readKindTaxonomy() == null
          ? null
          : _metadata.readEtag();
```

E acrescente ao comentário acima dela: «Idem sem taxonomia dos kinds gravada: o app anterior ao filtro por classes guardou o ETag de um dump que já a trazia (spec filtro-materiais §4.1).»

No `case ColdigomCatalogFresh`, logo depois do `if (rows.isEmpty) { … }` e **antes** de `if (!persist) return …`:

```dart
          await _metadata.writeKindTaxonomy(
            catalog.kindTaxonomy ?? MaterialKindTaxonomy.empty,
          );
```

- [ ] **Step 5: Provider e invalidação**

Em `coldigom_catalog_providers.dart`, importe a entidade e declare, perto de `coldigomSearchIndexProvider`:

```dart
/// Classes e famílias dos material kinds do último dump (spec filtro-materiais
/// §4.1). Lê as prefs; [ColdigomCatalogSyncNotifier] invalida depois de um
/// dump novo. Vazia antes do primeiro dump com taxonomia.
final coldigomKindTaxonomyProvider = Provider<MaterialKindTaxonomy>((ref) {
  return ref.watch(coldigomCatalogSyncMetadataStoreProvider).readKindTaxonomy() ??
      MaterialKindTaxonomy.empty;
});
```

Em `ColdigomCatalogSyncNotifier._run`:
- no ramo `if (result is ColdigomCatalogSyncInMemory) { … }`, antes do `return result;`, acrescente `ref.invalidate(coldigomKindTaxonomyProvider);`;
- no ramo final `if (result is ColdigomCatalogSyncReplaced) { … }`, junto do `ref.invalidate(coldigomCatalogHydrationProvider);`, acrescente `ref.invalidate(coldigomKindTaxonomyProvider);`.

- [ ] **Step 6: Rodar e ver passar**

Run: `flutter test test/unit/features/coldigom/`
Expected: PASS em tudo, incluindo os testes antigos ajustados no Step 1.

- [ ] **Step 7: Commit**

```bash
git add lib/core/constants/storage_keys.dart \
  lib/features/coldigom/data/datasources/coldigom_catalog_sync_metadata_store.dart \
  lib/features/coldigom/domain/usecases/sync_coldigom_catalog.dart \
  lib/features/coldigom/presentation/providers/coldigom_catalog_providers.dart \
  test/unit/features/coldigom/sync_coldigom_catalog_test.dart
git commit -m "feat(coldigom): guarda a taxonomia dos kinds a cada dump do catálogo

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Tipos de cada kind nas opções do filtro

**Files:**
- Modify: `lib/features/catalog/domain/entities/catalog_filter_options.dart`
- Test: `test/unit/features/catalog/catalog_filter_options_test.dart`

**Interfaces:**
- Produces: `CatalogKindOption({required String id, required String name, Set<MaterialKind> types = const {}})`, com `types` na igualdade. `MaterialKind` vem de `lib/core/utils/material_id_kind.dart`.

- [ ] **Step 1: Ajustar o teste existente e escrever o novo**

Em `catalog_filter_options_test.dart`, importe `package:coldigui/core/utils/material_id_kind.dart` e troque a expectativa de `'tipos de material por id, com o nome do kind, ordenados pelo nome'` por:

```dart
        expect(options.materialKinds, const [
          CatalogKindOption(id: 'k-cifra1', name: 'Cifra I', types: {MaterialKind.pdf}),
          CatalogKindOption(id: 'k-grade', name: 'Grade', types: {MaterialKind.pdf}),
          CatalogKindOption(id: 'k-play', name: 'Playback', types: {MaterialKind.audio}),
        ]);
```

E acrescente no mesmo `group`:

```dart
    test('um kind com PDF num louvor e áudio noutro tem os dois tipos', () {
      final mixed = CatalogFilterOptions.fromGroups([
        catalogGroup(praiseId: 'a', name: 'A', pdfKinds: const {'k-coro': 'Coro'}),
        catalogGroup(
          praiseId: 'b',
          name: 'B',
          pdfKinds: const {},
          audioKinds: const {'k-coro': 'Coro'},
        ),
      ]);
      expect(mixed.materialKinds.single.types, {MaterialKind.pdf, MaterialKind.audio});
    });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/catalog/catalog_filter_options_test.dart`
Expected: FAIL de compilação (parâmetro `types` não existe).

- [ ] **Step 3: Implementar**

Em `catalog_filter_options.dart`:

```dart
import 'package:flutter/foundation.dart';

import '../../../../core/utils/louvor_search_tokens.dart';
import '../../../../core/utils/material_id_kind.dart';
import '../utils/catalog_tag_hierarchy.dart';
import 'louvor_group.dart';

/// Um tipo de material (`material_kind` do coldigom) oferecido como filtro.
///
/// [types]: os `MaterialKind` que esse kind tem no índice — é o que os chips
/// de Tipo da seção Materiais filtram (spec filtro-materiais §4.2).
class CatalogKindOption {
  const CatalogKindOption({
    required this.id,
    required this.name,
    this.types = const {},
  });

  final String id;
  final String name;
  final Set<MaterialKind> types;

  @override
  bool operator ==(Object other) =>
      other is CatalogKindOption &&
      other.id == id &&
      other.name == name &&
      setEquals(other.types, types);

  @override
  int get hashCode => Object.hash(id, name, Object.hashAllUnordered(types));

  @override
  String toString() => 'CatalogKindOption($id, $name, $types)';
}
```

Em `fromGroups`, acrescente um mapa de tipos ao lado de `kindNames`:

```dart
    final kindTypes = <String, Set<MaterialKind>>{};
```

Troque as duas chamadas de `_addKind` por:

```dart
      for (final section in group.sections) {
        for (final entry in section.materials) {
          _addKind(
            kindNames,
            kindTypes,
            entry.louvor.materialKindId,
            entry.louvor.categoria,
            MaterialKind.pdf,
          );
        }
      }
      for (final material in group.extras) {
        _addKind(
          kindNames,
          kindTypes,
          material.materialKindId,
          material.categoria,
          material.kind,
        );
      }
```

Monte as opções com os tipos:

```dart
          for (final entry in kindNames.entries)
            CatalogKindOption(
              id: entry.key,
              name: entry.value,
              types: Set.unmodifiable(kindTypes[entry.key] ?? const {}),
            ),
```

E troque `_addKind`:

```dart
  static void _addKind(
    Map<String, String> names,
    Map<String, Set<MaterialKind>> types,
    String? id,
    String name,
    MaterialKind type,
  ) {
    if (id == null || id.isEmpty) return;
    final label = name.trim();
    names.putIfAbsent(id, () => label.isEmpty ? id : label);
    types.putIfAbsent(id, () => <MaterialKind>{}).add(type);
  }
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/unit/features/catalog/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/catalog/domain/entities/catalog_filter_options.dart \
  test/unit/features/catalog/catalog_filter_options_test.dart
git commit -m "feat(catalog): tipos de material de cada kind nas opções do filtro

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Regra de família na seleção e no casamento

**Files:**
- Create: `lib/features/catalog/domain/utils/material_kind_selection.dart`
- Modify: `lib/features/catalog/domain/usecases/matches_catalog_filters.dart`
- Modify: `lib/features/catalog/presentation/providers/catalog_filters_provider.dart` (`toggleMaterialKind`, linha ~96)
- Modify: `lib/features/catalog/presentation/providers/home_search_provider.dart` (duas chamadas de `matchesCatalogFilters`)
- Modify: `lib/features/library/presentation/providers/library_group_results_provider.dart` (`libraryFilteredGroupsProvider`)
- Test: `test/unit/features/catalog/material_kind_selection_test.dart` (novo), `test/unit/features/catalog/matches_catalog_filters_test.dart`, `test/unit/features/catalog/catalog_filters_provider_test.dart`

**Interfaces:**
- Consumes: `MaterialKindTaxonomy` (Task 1), `coldigomKindTaxonomyProvider` (Task 2).
- Produces:

```dart
enum MaterialKindFamilyState { none, selected, refined }
Set<String> toggleMaterialKindSelection(Set<String> selected, String id, MaterialKindTaxonomy taxonomy);
Set<String> effectiveMaterialKindIds(Set<String> selected, MaterialKindTaxonomy taxonomy);
MaterialKindFamilyState materialKindFamilyState(String parentId, Iterable<String> childIds, Set<String> selected);
bool matchesCatalogFilters(LouvorGroup group, CatalogFilterState filters, {MaterialKindTaxonomy? kindTaxonomy});
```

- [ ] **Step 1: Escrever os testes que falham**

`test/unit/features/catalog/material_kind_selection_test.dart`:

```dart
import 'package:coldigui/features/catalog/domain/entities/material_kind_taxonomy.dart';
import 'package:coldigui/features/catalog/domain/utils/material_kind_selection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t = MaterialKindTaxonomy(
    kinds: const {
      'sax': MaterialKindTaxon(name: 'Saxofone'),
      'alto': MaterialKindTaxon(name: 'Saxofone alto', parentId: 'sax'),
      'tenor': MaterialKindTaxon(name: 'Saxofone tenor', parentId: 'sax'),
      'tuba': MaterialKindTaxon(name: 'Tuba'),
    },
  );

  group('toggleMaterialKindSelection', () {
    test('kind sem filhos liga e desliga', () {
      expect(toggleMaterialKindSelection({}, 'tuba', t), {'tuba'});
      expect(toggleMaterialKindSelection({'tuba'}, 'tuba', t), isEmpty);
    });

    test('marcar o pai tira os filhos marcados', () {
      expect(toggleMaterialKindSelection({'alto', 'tuba'}, 'sax', t), {'sax', 'tuba'});
    });

    test('desmarcar o pai tira os filhos', () {
      expect(toggleMaterialKindSelection({'sax', 'tenor', 'tuba'}, 'sax', t), {'tuba'});
    });

    test('filho com o pai marcado liga junto (refina) e desliga sozinho', () {
      final refinado = toggleMaterialKindSelection({'sax'}, 'tenor', t);
      expect(refinado, {'sax', 'tenor'});
      expect(toggleMaterialKindSelection(refinado, 'tenor', t), {'sax'});
    });
  });

  group('effectiveMaterialKindIds', () {
    test('o pai expande para os filhos', () {
      expect(effectiveMaterialKindIds({'sax'}, t), {'sax', 'alto', 'tenor'});
    });

    test('pai + filho vale pelo filho', () {
      expect(effectiveMaterialKindIds({'sax', 'tenor'}, t), {'tenor'});
    });

    test('sem taxonomia é a própria seleção', () {
      expect(effectiveMaterialKindIds({'sax'}, MaterialKindTaxonomy.empty), {'sax'});
    });
  });

  test('materialKindFamilyState', () {
    expect(materialKindFamilyState('sax', ['alto', 'tenor'], {}), MaterialKindFamilyState.none);
    expect(materialKindFamilyState('sax', ['alto', 'tenor'], {'sax'}), MaterialKindFamilyState.selected);
    expect(materialKindFamilyState('sax', ['alto', 'tenor'], {'sax', 'alto'}), MaterialKindFamilyState.refined);
    expect(materialKindFamilyState('sax', ['alto', 'tenor'], {'alto'}), MaterialKindFamilyState.refined);
  });
}
```

Em `matches_catalog_filters_test.dart`, importe a taxonomia e acrescente:

```dart
  group('família de kinds (spec filtro-materiais §4.3)', () {
    final sax = catalogGroup(praiseId: 's1', name: 'Sax alto', pdfKinds: const {'alto': 'Saxofone alto'});
    final t = MaterialKindTaxonomy(
      kinds: const {
        'sax': MaterialKindTaxon(name: 'Saxofone'),
        'alto': MaterialKindTaxon(name: 'Saxofone alto', parentId: 'sax'),
        'tenor': MaterialKindTaxon(name: 'Saxofone tenor', parentId: 'sax'),
      },
    );
    CatalogFilterState kinds(Set<String> ids) => CatalogFilterState.empty.copyWith(materialKindIds: ids);

    test('o pai casa o louvor que só tem o filho', () {
      expect(matchesCatalogFilters(sax, kinds({'sax'}), kindTaxonomy: t), isTrue);
    });

    test('pai + outro filho refina: o louvor do alto sai', () {
      expect(matchesCatalogFilters(sax, kinds({'sax', 'tenor'}), kindTaxonomy: t), isFalse);
    });

    test('sem taxonomia o pai casa só o próprio id', () {
      expect(matchesCatalogFilters(sax, kinds({'sax'})), isFalse);
    });
  });
```

Em `catalog_filters_provider_test.dart`, acrescente (grava a taxonomia nas prefs, que é de onde o provider lê):

```dart
  test('toggleMaterialKind segue a regra de família da taxonomia', () async {
    await setUpPrefs({
      StorageKeys.coldigomKindTaxonomy: jsonEncode({
        'kindClasses': [],
        'kinds': [
          {'id': 'sax', 'name': 'Saxofone'},
          {'id': 'alto', 'name': 'Saxofone alto', 'parent': 'sax'},
        ],
      }),
    });
    final container = createContainer();
    final notifier = container.read(catalogFiltersProvider.notifier);

    notifier.toggleMaterialKind('alto');
    notifier.toggleMaterialKind('sax');
    expect(container.read(catalogFiltersProvider).materialKindIds, {'sax'});

    notifier.toggleMaterialKind('alto');
    expect(container.read(catalogFiltersProvider).materialKindIds, {'sax', 'alto'});

    notifier.toggleMaterialKind('sax');
    expect(container.read(catalogFiltersProvider).materialKindIds, isEmpty);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/catalog/material_kind_selection_test.dart test/unit/features/catalog/matches_catalog_filters_test.dart test/unit/features/catalog/catalog_filters_provider_test.dart`
Expected: FAIL de compilação (`material_kind_selection.dart` não existe; `kindTaxonomy` não existe).

- [ ] **Step 3: Implementar as funções**

`lib/features/catalog/domain/utils/material_kind_selection.dart`:

```dart
import '../entities/material_kind_taxonomy.dart';

/// Estado do chip de família (spec filtro-materiais §5.2).
enum MaterialKindFamilyState {
  /// Nada da família marcado.
  none,

  /// Só o pai marcado: vale a família inteira.
  selected,

  /// Algum filho marcado, com ou sem o pai: vale só o que está marcado.
  refined,
}

/// Toque num chip de kind com a regra das subtags (`d8dd304d`): marcar o pai
/// vale pela família (tira os filhos), desmarcar o pai tira os filhos, e um
/// filho liga e desliga sozinho — com o pai marcado, ele refina o pai.
Set<String> toggleMaterialKindSelection(
  Set<String> selected,
  String id,
  MaterialKindTaxonomy taxonomy,
) {
  final children = taxonomy.childrenOf(id);
  if (children.isEmpty) {
    return selected.contains(id)
        ? ({...selected}..remove(id))
        : {...selected, id};
  }
  final withoutChildren = {
    for (final s in selected)
      if (!children.contains(s)) s,
  };
  return selected.contains(id)
      ? (withoutChildren..remove(id))
      : (withoutChildren..add(id));
}

/// Os ids que o casamento usa: primeiro refina (pai com filho marcado sai,
/// como `catalogTagsRefined`), depois expande cada pai que sobrou nos filhos
/// (como `catalogTagMatches`).
Set<String> effectiveMaterialKindIds(
  Set<String> selected,
  MaterialKindTaxonomy taxonomy,
) {
  final refined = {
    for (final id in selected)
      if (!taxonomy.childrenOf(id).any(selected.contains)) id,
  };
  return {
    for (final id in refined) ...[id, ...taxonomy.childrenOf(id)],
  };
}

MaterialKindFamilyState materialKindFamilyState(
  String parentId,
  Iterable<String> childIds,
  Set<String> selected,
) {
  if (childIds.any(selected.contains)) return MaterialKindFamilyState.refined;
  if (selected.contains(parentId)) return MaterialKindFamilyState.selected;
  return MaterialKindFamilyState.none;
}
```

- [ ] **Step 4: Casamento**

Em `matches_catalog_filters.dart`, importe:

```dart
import '../entities/material_kind_taxonomy.dart';
import '../utils/material_kind_selection.dart';
```

Mude a assinatura e o critério de tipo de material:

```dart
bool matchesCatalogFilters(
  LouvorGroup group,
  CatalogFilterState filters, {
  MaterialKindTaxonomy? kindTaxonomy,
}) {
```

```dart
  if (filters.materialKindIds.isNotEmpty &&
      !_hasSelectedKind(
        group,
        effectiveMaterialKindIds(
          filters.materialKindIds,
          kindTaxonomy ?? MaterialKindTaxonomy.empty,
        ),
      )) {
    return false;
  }
```

Atualize o comentário do topo, na linha de «Tipo de material»: «algum material do grupo tem um `materialKindId` da seleção efetiva — pai expande nos filhos, pai + filho vale pelo filho ([effectiveMaterialKindIds])».

- [ ] **Step 5: Notifier e chamadores**

Em `catalog_filters_provider.dart`, importe:

```dart
import '../../../coldigom/presentation/providers/coldigom_catalog_providers.dart';
import '../../domain/utils/material_kind_selection.dart';
```

E troque `toggleMaterialKind`:

```dart
  /// Com a regra de família dos kinds (spec filtro-materiais §5.2).
  void toggleMaterialKind(String kindId) => _apply(
    state.copyWith(
      materialKindIds: toggleMaterialKindSelection(
        state.materialKindIds,
        kindId,
        ref.read(coldigomKindTaxonomyProvider),
      ),
    ),
  );
```

Em `home_search_provider.dart`, nos dois providers que chamam `matchesCatalogFilters`, leia a taxonomia com `final kindTaxonomy = ref.watch(coldigomKindTaxonomyProvider);` junto do `ref.watch(catalogFiltersProvider)` e passe `kindTaxonomy: kindTaxonomy` nas duas chamadas. Faça o mesmo em `libraryFilteredGroupsProvider` (`library_group_results_provider.dart`), importando `coldigom_catalog_providers.dart` se ainda não estiver importado.

- [ ] **Step 6: Rodar e ver passar**

Run: `flutter test test/unit/features/catalog/ test/unit/features/library/ test/widget/features/catalog/`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/catalog/domain/utils/material_kind_selection.dart \
  lib/features/catalog/domain/usecases/matches_catalog_filters.dart \
  lib/features/catalog/presentation/providers/catalog_filters_provider.dart \
  lib/features/catalog/presentation/providers/home_search_provider.dart \
  lib/features/library/presentation/providers/library_group_results_provider.dart \
  test/unit/features/catalog/material_kind_selection_test.dart \
  test/unit/features/catalog/matches_catalog_filters_test.dart \
  test/unit/features/catalog/catalog_filters_provider_test.dart
git commit -m "feat(catalog): família de kinds no filtro — pai inclui os filhos, filho refina

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Montagem das seções da lista de materiais

**Files:**
- Create: `lib/features/catalog/domain/usecases/build_material_kind_sections.dart`
- Test: `test/unit/features/catalog/build_material_kind_sections_test.dart` (novo)

**Interfaces:**
- Consumes: `CatalogKindOption.types` (Task 3), `MaterialKindTaxonomy` (Task 1).
- Produces:

```dart
const List<MaterialKind> kMaterialTypeChipOrder;   // pdf, chord, audio, youtube, gesture
sealed class MaterialKindUnit {}
final class MaterialKindSingleUnit extends MaterialKindUnit { final CatalogKindOption option; }
final class MaterialKindFamilyUnit extends MaterialKindUnit {
  final CatalogKindOption parent; final List<CatalogKindOption> children;
}
class MaterialKindSection {
  final String? classId;   // null = «Outros»
  final String? label;     // null = «Outros»
  final int count;         // kinds visíveis na seção (pais + filhos)
  final List<MaterialKindUnit> units;
}
class MaterialKindSectionsView {
  final List<MaterialKindSection> sections;
  final int hiddenCount;                      // kinds escondidos pelos tipos
  final Map<MaterialKind, int> typeCounts;    // na ordem de kMaterialTypeChipOrder, só > 0
}
MaterialKindSectionsView buildMaterialKindSections({
  required List<CatalogKindOption> options,
  required MaterialKindTaxonomy taxonomy,
  required Set<MaterialKind> types,
  required Set<String> selected,
});
```

- [ ] **Step 1: Escrever os testes que falham**

`test/unit/features/catalog/build_material_kind_sections_test.dart`:

```dart
import 'package:coldigui/core/utils/material_id_kind.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_filter_options.dart';
import 'package:coldigui/features/catalog/domain/entities/material_kind_taxonomy.dart';
import 'package:coldigui/features/catalog/domain/usecases/build_material_kind_sections.dart';
import 'package:flutter_test/flutter_test.dart';

const _pdf = {MaterialKind.pdf};
const _audio = {MaterialKind.audio};

final options = <CatalogKindOption>[
  const CatalogKindOption(id: 'tuba', name: 'Tuba', types: _pdf),
  const CatalogKindOption(id: 'sax', name: 'Saxofone', types: _pdf),
  const CatalogKindOption(id: 'alto', name: 'Saxofone alto', types: _pdf),
  const CatalogKindOption(id: 'tenor', name: 'Saxofone tenor', types: _audio),
  const CatalogKindOption(id: 'cifra', name: 'Cifra', types: {MaterialKind.chord}),
  const CatalogKindOption(id: 'novo', name: 'Novo', types: _pdf),
];

final taxonomy = MaterialKindTaxonomy(
  classes: const [
    MaterialKindClass(id: 'metais', label: 'Metais'),
    MaterialKindClass(id: 'banda', label: 'Banda'),
  ],
  kinds: const {
    'sax': MaterialKindTaxon(name: 'Saxofone', classId: 'metais', order: 30),
    'alto': MaterialKindTaxon(name: 'Saxofone alto', classId: 'metais', parentId: 'sax', order: 50),
    'tenor': MaterialKindTaxon(name: 'Saxofone tenor', classId: 'metais', parentId: 'sax', order: 60),
    'tuba': MaterialKindTaxon(name: 'Tuba', classId: 'metais', order: 100),
    'cifra': MaterialKindTaxon(name: 'Cifra', classId: 'banda', order: 10),
  },
);

List<String> labels(MaterialKindSection s) => [
  for (final u in s.units)
    switch (u) {
      MaterialKindSingleUnit(:final option) => option.name,
      MaterialKindFamilyUnit(:final parent, :final children) =>
        '${parent.name}[${children.map((c) => c.name).join(', ')}]',
    },
];

void main() {
  test('classes na ordem, família recolhida, ordem de grade, Outros por último', () {
    final view = buildMaterialKindSections(
      options: options,
      taxonomy: taxonomy,
      types: const {},
      selected: const {},
    );
    expect(view.sections.map((s) => s.label), ['Metais', 'Banda', null]);
    expect(labels(view.sections[0]), ['Saxofone[Saxofone alto, Saxofone tenor]', 'Tuba']);
    expect(view.sections[0].count, 4);
    expect(labels(view.sections[2]), ['Novo']);
    expect(view.hiddenCount, 0);
  });

  test('contagem por tipo na ordem fixa, só tipos presentes', () {
    final view = buildMaterialKindSections(
      options: options,
      taxonomy: taxonomy,
      types: const {},
      selected: const {},
    );
    expect(view.typeCounts.keys.toList(), [MaterialKind.pdf, MaterialKind.chord, MaterialKind.audio]);
    expect(view.typeCounts[MaterialKind.pdf], 4);
  });

  test('tipo esconde kinds; selecionado nunca some; classe vazia some', () {
    final view = buildMaterialKindSections(
      options: options,
      taxonomy: taxonomy,
      types: const {MaterialKind.audio},
      selected: const {'novo'},
    );
    // Só o tenor tem áudio: sem o pai visível e com um membro só, vira chip simples.
    expect(view.sections.map((s) => s.label), ['Metais', null]);
    expect(labels(view.sections[0]), ['Saxofone tenor']);
    expect(labels(view.sections[1]), ['Novo']);
    expect(view.hiddenCount, 4);
  });

  test('pai escondido pelo tipo, dois filhos visíveis: família com o pai como cabeça', () {
    final view = buildMaterialKindSections(
      options: [
        const CatalogKindOption(id: 'sax', name: 'Saxofone', types: _pdf),
        const CatalogKindOption(id: 'alto', name: 'Saxofone alto', types: _audio),
        const CatalogKindOption(id: 'tenor', name: 'Saxofone tenor', types: _audio),
      ],
      taxonomy: taxonomy,
      types: const {MaterialKind.audio},
      selected: const {},
    );
    expect(labels(view.sections.single), ['Saxofone[Saxofone alto, Saxofone tenor]']);
  });

  test('pai sem material no índice: nome da taxonomia', () {
    final view = buildMaterialKindSections(
      options: [
        const CatalogKindOption(id: 'alto', name: 'Saxofone alto', types: _pdf),
        const CatalogKindOption(id: 'tenor', name: 'Saxofone tenor', types: _pdf),
      ],
      taxonomy: taxonomy,
      types: const {},
      selected: const {},
    );
    expect(labels(view.sections.single), ['Saxofone[Saxofone alto, Saxofone tenor]']);
  });

  test('selecionado que sumiu do catálogo continua, pelo nome da taxonomia ou pelo id', () {
    final view = buildMaterialKindSections(
      options: const [],
      taxonomy: taxonomy,
      types: const {},
      selected: const {'tuba', 'k-velho'},
    );
    expect(labels(view.sections[0]), ['Tuba']);
    expect(labels(view.sections[1]), ['k-velho']);
  });

  test('taxonomia vazia: uma seção só, sem classe, em ordem alfabética', () {
    final view = buildMaterialKindSections(
      options: options,
      taxonomy: MaterialKindTaxonomy.empty,
      types: const {},
      selected: const {},
    );
    expect(view.sections.single.classId, isNull);
    expect(labels(view.sections.single), [
      'Cifra',
      'Novo',
      'Saxofone',
      'Saxofone alto',
      'Saxofone tenor',
      'Tuba',
    ]);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/catalog/build_material_kind_sections_test.dart`
Expected: FAIL de compilação.

- [ ] **Step 3: Implementar**

`lib/features/catalog/domain/usecases/build_material_kind_sections.dart`:

```dart
import '../../../../core/utils/louvor_search_tokens.dart';
import '../../../../core/utils/material_id_kind.dart';
import '../entities/catalog_filter_options.dart';
import '../entities/material_kind_taxonomy.dart';

/// Ordem fixa dos chips de Tipo (spec filtro-materiais §4.2).
const List<MaterialKind> kMaterialTypeChipOrder = [
  MaterialKind.pdf,
  MaterialKind.chord,
  MaterialKind.audio,
  MaterialKind.youtube,
  MaterialKind.gesture,
];

/// Um chip da seção: kind sozinho ou família recolhida.
sealed class MaterialKindUnit {
  const MaterialKindUnit();
}

final class MaterialKindSingleUnit extends MaterialKindUnit {
  const MaterialKindSingleUnit(this.option);

  final CatalogKindOption option;
}

final class MaterialKindFamilyUnit extends MaterialKindUnit {
  const MaterialKindFamilyUnit({required this.parent, required this.children});

  final CatalogKindOption parent;
  final List<CatalogKindOption> children;
}

class MaterialKindSection {
  const MaterialKindSection({
    required this.classId,
    required this.label,
    required this.count,
    required this.units,
  });

  /// `null` = «Outros» (kind sem classe, ou taxonomia vazia).
  final String? classId;
  final String? label;

  /// Kinds visíveis na seção, pais e filhos.
  final int count;
  final List<MaterialKindUnit> units;
}

class MaterialKindSectionsView {
  const MaterialKindSectionsView({
    required this.sections,
    required this.hiddenCount,
    required this.typeCounts,
  });

  final List<MaterialKindSection> sections;

  /// Kinds escondidos pelos chips de Tipo marcados.
  final int hiddenCount;

  /// Kinds por tipo, na ordem de [kMaterialTypeChipOrder], só os presentes.
  final Map<MaterialKind, int> typeCounts;
}

typedef _Placed = ({String headId, MaterialKindUnit unit, int members});

/// Seções da lista de Materiais (spec filtro-materiais §5.1):
/// - um kind aparece se tem algum dos [types] (ou [types] vazio) ou está em
///   [selected] — um selecionado nunca some;
/// - filhos visíveis se juntam sob o pai; família com um membro visível só
///   vira chip simples;
/// - seções na ordem de `taxonomy.classes`, «Outros» por último; dentro,
///   pela ordem de grade e depois pelo nome.
MaterialKindSectionsView buildMaterialKindSections({
  required List<CatalogKindOption> options,
  required MaterialKindTaxonomy taxonomy,
  required Set<MaterialKind> types,
  required Set<String> selected,
}) {
  CatalogKindOption synthesized(String id) =>
      CatalogKindOption(id: id, name: taxonomy.kinds[id]?.name ?? id);

  final byId = <String, CatalogKindOption>{for (final o in options) o.id: o};
  for (final id in selected) {
    byId.putIfAbsent(id, () => synthesized(id));
  }

  bool visible(CatalogKindOption o) =>
      types.isEmpty || selected.contains(o.id) || o.types.any(types.contains);

  final shown = [for (final o in byId.values) if (visible(o)) o];
  final hiddenCount = byId.length - shown.length;

  final typeCounts = <MaterialKind, int>{};
  for (final type in kMaterialTypeChipOrder) {
    final n = options.where((o) => o.types.contains(type)).length;
    if (n > 0) typeCounts[type] = n;
  }

  final childrenByParent = <String, List<CatalogKindOption>>{};
  final roots = <CatalogKindOption>[];
  for (final o in shown) {
    final parentId = taxonomy.parentOf(o.id);
    if (parentId == null) {
      roots.add(o);
    } else {
      childrenByParent.putIfAbsent(parentId, () => []).add(o);
    }
  }

  int compare(CatalogKindOption a, CatalogKindOption b) {
    final byOrder = (taxonomy.kinds[a.id]?.order ?? 1 << 30).compareTo(
      taxonomy.kinds[b.id]?.order ?? 1 << 30,
    );
    return byOrder != 0 ? byOrder : _compareLabels(a.name, b.name);
  }

  final placed = <_Placed>[];
  for (final root in roots) {
    final kids = childrenByParent.remove(root.id);
    placed.add(
      kids == null
          ? (headId: root.id, unit: MaterialKindSingleUnit(root), members: 1)
          : (
              headId: root.id,
              unit: MaterialKindFamilyUnit(
                parent: root,
                children: kids..sort(compare),
              ),
              members: 1 + kids.length,
            ),
    );
  }
  // Pai fora da lista visível (escondido pelo tipo, ou sem material).
  for (final entry in childrenByParent.entries) {
    final kids = entry.value..sort(compare);
    if (kids.length == 1) {
      placed.add((
        headId: kids.single.id,
        unit: MaterialKindSingleUnit(kids.single),
        members: 1,
      ));
      continue;
    }
    placed.add((
      headId: entry.key,
      unit: MaterialKindFamilyUnit(
        parent: byId[entry.key] ?? synthesized(entry.key),
        children: kids,
      ),
      members: kids.length,
    ));
  }

  final known = {for (final c in taxonomy.classes) c.id};
  final bySection = <String?, List<_Placed>>{};
  for (final p in placed) {
    final classId = taxonomy.kinds[p.headId]?.classId;
    bySection
        .putIfAbsent(known.contains(classId) ? classId : null, () => [])
        .add(p);
  }

  MaterialKindSection section(String? classId, String? label) {
    final items = bySection[classId]!
      ..sort((a, b) => compare(_head(a.unit), _head(b.unit)));
    return MaterialKindSection(
      classId: classId,
      label: label,
      count: items.fold(0, (sum, p) => sum + p.members),
      units: [for (final p in items) p.unit],
    );
  }

  return MaterialKindSectionsView(
    sections: [
      for (final c in taxonomy.classes)
        if (bySection.containsKey(c.id)) section(c.id, c.label),
      if (bySection.containsKey(null)) section(null, null),
    ],
    hiddenCount: hiddenCount,
    typeCounts: typeCounts,
  );
}

CatalogKindOption _head(MaterialKindUnit unit) => switch (unit) {
  MaterialKindSingleUnit(:final option) => option,
  MaterialKindFamilyUnit(:final parent) => parent,
};

/// Sem acento nem caixa primeiro; desempate pelo texto cru (estável) — a
/// mesma ordem de `CatalogFilterOptions`.
int _compareLabels(String a, String b) {
  final byNormalized = LouvorSearchTokens.normalize(
    a,
  ).compareTo(LouvorSearchTokens.normalize(b));
  return byNormalized != 0 ? byNormalized : a.compareTo(b);
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/unit/features/catalog/build_material_kind_sections_test.dart`
Expected: PASS (7 testes).

- [ ] **Step 5: Commit**

```bash
git add lib/features/catalog/domain/usecases/build_material_kind_sections.dart \
  test/unit/features/catalog/build_material_kind_sections_test.dart
git commit -m "feat(catalog): monta as seções de Materiais por classe e família

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Chips de kind, de família e de tipo (+ strings)

**Files:**
- Create: `lib/features/catalog/presentation/widgets/material_kind_chips.dart`
- Modify: `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb` (depois de `coldigomFilterMaterials`, linha ~127) e os gerados (`flutter gen-l10n`)
- Test: `test/widget/features/catalog/material_kind_chips_test.dart` (novo)

**Interfaces:**
- Consumes: `MaterialKindFamilyState` (Task 4).
- Produces:

```dart
class DashedRoundedRectangleBorder extends RoundedRectangleBorder { const DashedRoundedRectangleBorder({super.side, super.borderRadius}); }
enum MaterialKindChipLook { normal, selected, included }
class MaterialKindChip extends StatelessWidget {
  const MaterialKindChip({super.key, required String label, required MaterialKindChipLook look, required VoidCallback onPressed});
}
class MaterialKindFamilyChip extends StatelessWidget {
  const MaterialKindFamilyChip({super.key, required String label, required int count,
    required MaterialKindFamilyState state, required bool expanded,
    required VoidCallback onToggle, required VoidCallback onExpand, required String expandTooltip});
}
class MaterialTypeChip extends StatelessWidget {
  const MaterialTypeChip({super.key, required String label, int? count, required bool selected, required VoidCallback onPressed});
}
// l10n: materialTypeFilterLabel, materialTypeAll, materialTypePdf, materialTypeChord,
// materialTypeAudio, materialTypeYoutube, materialTypeGesture, materialKindOtherClass,
// materialKindHiddenByType(int count), materialKindShowVariants(String name)
```

- [ ] **Step 1: Strings**

Em `lib/l10n/app_pt.arb`, depois de `"coldigomFilterMaterials": "Materiais",`:

```json
  "materialTypeFilterLabel": "Tipo",
  "materialTypeAll": "Todos",
  "materialTypePdf": "PDF",
  "materialTypeChord": "Cifra",
  "materialTypeAudio": "Áudio",
  "materialTypeYoutube": "YouTube",
  "materialTypeGesture": "Gestos",
  "materialKindOtherClass": "Outros",
  "materialKindHiddenByType": "{count, plural, =1{1 material oculto pelo tipo} other{{count} materiais ocultos pelo tipo}}",
  "@materialKindHiddenByType": { "placeholders": { "count": { "type": "int" } } },
  "materialKindShowVariants": "Ver variantes de {name}",
  "@materialKindShowVariants": { "placeholders": { "name": { "type": "String" } } },
```

Em `lib/l10n/app_en.arb`, depois de `"coldigomFilterMaterials": "Materials",`:

```json
  "materialTypeFilterLabel": "Type",
  "materialTypeAll": "All",
  "materialTypePdf": "PDF",
  "materialTypeChord": "Chords",
  "materialTypeAudio": "Audio",
  "materialTypeYoutube": "YouTube",
  "materialTypeGesture": "Gestures",
  "materialKindOtherClass": "Other",
  "materialKindHiddenByType": "{count, plural, =1{1 material hidden by type} other{{count} materials hidden by type}}",
  "materialKindShowVariants": "Show variants of {name}",
```

Run: `flutter gen-l10n`
Expected: `lib/l10n/app_localizations*.dart` atualizados, sem erro.

- [ ] **Step 2: Escrever os testes que falham**

`test/widget/features/catalog/material_kind_chips_test.dart`:

```dart
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/catalog/domain/utils/material_kind_selection.dart';
import 'package:coldigui/features/catalog/presentation/widgets/material_kind_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpChip(WidgetTester tester, Widget chip) => tester.pumpWidget(
  MaterialApp(home: Scaffold(body: Center(child: chip))),
);

ShapeBorder familyShape(WidgetTester tester) => tester
    .widget<Material>(
      find.descendant(of: find.byType(MaterialKindFamilyChip), matching: find.byType(Material)).first,
    )
    .shape!;

void main() {
  testWidgets('MaterialKindChip: incluído tem borda tracejada; selecionado não', (tester) async {
    await pumpChip(
      tester,
      MaterialKindChip(label: 'Saxofone alto', look: MaterialKindChipLook.included, onPressed: () {}),
    );
    final included = tester.widget<FilterChip>(find.byType(FilterChip));
    expect(included.selected, isFalse);
    expect(included.shape, isA<DashedRoundedRectangleBorder>());

    await pumpChip(
      tester,
      MaterialKindChip(label: 'Saxofone alto', look: MaterialKindChipLook.selected, onPressed: () {}),
    );
    final selected = tester.widget<FilterChip>(find.byType(FilterChip));
    expect(selected.selected, isTrue);
    expect(selected.shape, isNot(isA<DashedRoundedRectangleBorder>()));
  });

  testWidgets('MaterialKindFamilyChip: corpo marca, seta abre, contagem visível', (tester) async {
    var toggles = 0;
    var expands = 0;
    await pumpChip(
      tester,
      MaterialKindFamilyChip(
        label: 'Saxofone',
        count: 4,
        state: MaterialKindFamilyState.none,
        expanded: false,
        onToggle: () => toggles++,
        onExpand: () => expands++,
        expandTooltip: 'Ver variantes de Saxofone',
      ),
    );
    expect(find.text('4'), findsOneWidget);
    await tester.tap(find.text('Saxofone'));
    await tester.tap(find.byTooltip('Ver variantes de Saxofone'));
    expect(toggles, 1);
    expect(expands, 1);
  });

  testWidgets('MaterialKindFamilyChip: refinado é tracejado; marcado é dourado sólido', (tester) async {
    Widget chip(MaterialKindFamilyState state) => MaterialKindFamilyChip(
      label: 'Saxofone',
      count: 4,
      state: state,
      expanded: false,
      onToggle: () {},
      onExpand: () {},
      expandTooltip: 'x',
    );
    await pumpChip(tester, chip(MaterialKindFamilyState.refined));
    expect(familyShape(tester), isA<DashedRoundedRectangleBorder>());

    await pumpChip(tester, chip(MaterialKindFamilyState.selected));
    final shape = familyShape(tester) as RoundedRectangleBorder;
    expect(shape, isNot(isA<DashedRoundedRectangleBorder>()));
    expect(shape.side.color, AppColors.gold);
  });

  testWidgets('MaterialTypeChip: marcado fica preenchido de vinho', (tester) async {
    await pumpChip(tester, MaterialTypeChip(label: 'PDF', count: 71, selected: true, onPressed: () {}));
    final chip = tester.widget<FilterChip>(find.byType(FilterChip));
    expect(chip.selected, isTrue);
    expect(chip.selectedColor, AppColors.title);
    expect(find.text('71'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `flutter test test/widget/features/catalog/material_kind_chips_test.dart`
Expected: FAIL de compilação.

- [ ] **Step 4: Implementar os chips**

`lib/features/catalog/presentation/widgets/material_kind_chips.dart`:

```dart
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../../../core/theme/color_extensions.dart';
import '../../domain/utils/material_kind_selection.dart';

const _pill = BorderRadius.all(Radius.circular(24));

/// Borda arredondada tracejada: família refinada e filho «incluído» (spec
/// filtro-materiais §5.2). `copyWith` preserva o tracejado — o `FilterChip`
/// aplica o `side` por ele.
class DashedRoundedRectangleBorder extends RoundedRectangleBorder {
  const DashedRoundedRectangleBorder({super.side, super.borderRadius});

  static const double _dash = 5;
  static const double _gap = 3;

  @override
  DashedRoundedRectangleBorder copyWith({
    BorderSide? side,
    BorderRadiusGeometry? borderRadius,
  }) => DashedRoundedRectangleBorder(
    side: side ?? this.side,
    borderRadius: borderRadius ?? this.borderRadius,
  );

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    final rrect = borderRadius
        .resolve(textDirection)
        .toRRect(rect)
        .deflate(side.width / 2);
    final path = Path()..addRRect(rrect);
    final paint = side.toPaint();
    for (final PathMetric metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + _dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += _dash + _gap;
      }
    }
  }
}

enum MaterialKindChipLook { normal, selected, included }

/// Chip de um kind — o `FilterChip` de sempre da seção, mais o visual
/// «incluído» (filho de uma família marcada inteira).
class MaterialKindChip extends StatelessWidget {
  const MaterialKindChip({
    super.key,
    required this.label,
    required this.look,
    required this.onPressed,
  });

  final String label;
  final MaterialKindChipLook look;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final selected = look == MaterialKindChipLook.selected;
    final included = look == MaterialKindChipLook.included;
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppColors.gold.withValues(alpha: 0.3),
      backgroundColor: included
          ? AppColors.gold.withValues(alpha: 0.12)
          : AppColors.card,
      side: BorderSide(
        color: look == MaterialKindChipLook.normal
            ? AppColors.title
            : AppColors.gold,
        width: selected ? 2 : 1.5,
      ),
      shape: included
          ? const DashedRoundedRectangleBorder(borderRadius: _pill)
          : const RoundedRectangleBorder(borderRadius: _pill),
      onSelected: (_) => onPressed(),
    );
  }
}

/// Família recolhida: o corpo (nome do pai + nº de variantes) marca o pai;
/// a seta abre as variantes (spec filtro-materiais §5.2).
class MaterialKindFamilyChip extends StatelessWidget {
  const MaterialKindFamilyChip({
    super.key,
    required this.label,
    required this.count,
    required this.state,
    required this.expanded,
    required this.onToggle,
    required this.onExpand,
    required this.expandTooltip,
  });

  final String label;
  final int count;
  final MaterialKindFamilyState state;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onExpand;
  final String expandTooltip;

  @override
  Widget build(BuildContext context) {
    final none = state == MaterialKindFamilyState.none;
    final side = BorderSide(
      color: none ? AppColors.title : AppColors.gold,
      width: none ? 1.5 : 2,
    );
    final labelStyle = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(color: AppColors.title);
    return Material(
      color: state == MaterialKindFamilyState.selected
          ? AppColors.gold.withValues(alpha: 0.3)
          : AppColors.card,
      shape: state == MaterialKindFamilyState.refined
          ? DashedRoundedRectangleBorder(side: side, borderRadius: _pill)
          : RoundedRectangleBorder(side: side, borderRadius: _pill),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              selected: state == MaterialKindFamilyState.selected,
              child: InkWell(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label, style: labelStyle),
                      const SizedBox(width: 6),
                      Container(
                        constraints: const BoxConstraints(minWidth: 18),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: AppColors.title.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          '$count',
                          textAlign: TextAlign.center,
                          style: labelStyle?.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: AppColors.title.withValues(alpha: 0.16),
            ),
            Tooltip(
              message: expandTooltip,
              child: InkWell(
                onTap: onExpand,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: AppColors.title,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip de Tipo (PDF, Cifra…): mais baixo e mais quadrado que o de kind;
/// marcado, fica preenchido de vinho (spec filtro-materiais §5.1).
class MaterialTypeChip extends StatelessWidget {
  const MaterialTypeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.count,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.card : AppColors.title;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count != null) ...[
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                color: color.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
      labelStyle: TextStyle(
        color: color,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      selected: selected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      selectedColor: AppColors.title,
      backgroundColor: Colors.transparent,
      side: BorderSide(color: AppColors.title.withValues(alpha: 0.7)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      onSelected: (_) => onPressed(),
    );
  }
}
```

- [ ] **Step 5: Rodar e ver passar**

Run: `flutter test test/widget/features/catalog/material_kind_chips_test.dart`
Expected: PASS (4 testes).

- [ ] **Step 6: Commit**

```bash
git add lib/features/catalog/presentation/widgets/material_kind_chips.dart \
  lib/l10n/ test/widget/features/catalog/material_kind_chips_test.dart
git commit -m "feat(catalog): chips de kind, de família e de tipo do filtro Materiais

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: A seção Materiais nova no painel de filtros

**Files:**
- Create: `lib/features/catalog/presentation/widgets/material_kind_filter_section.dart`
- Modify: `lib/features/catalog/presentation/widgets/catalog_filter_sections.dart` (a entrada `_ChipSection(title: l10n.coldigomFilterMaterials, …)`)
- Test: `test/widget/features/catalog/catalog_filter_sections_test.dart`

**Interfaces:**
- Consumes: `buildMaterialKindSections`, `MaterialKindSingleUnit`, `MaterialKindFamilyUnit`, `kMaterialTypeChipOrder` (Task 5); os chips e as strings (Task 6); `materialKindFamilyState` (Task 4); `coldigomKindTaxonomyProvider` (Task 2); `catalogFilterOptionsProvider`, `catalogFiltersProvider`.
- Produces: `class MaterialKindFilterSection extends ConsumerStatefulWidget { const MaterialKindFilterSection({super.key}); }`

- [ ] **Step 1: Escrever os testes que falham**

Em `catalog_filter_sections_test.dart`:
- importe `package:coldigui/features/catalog/domain/entities/material_kind_taxonomy.dart` e `package:coldigui/features/catalog/presentation/widgets/material_kind_chips.dart`;
- dê a `pump` um parâmetro opcional `MaterialKindTaxonomy? taxonomy` e, quando vier, acrescente o override `coldigomKindTaxonomyProvider.overrideWithValue(taxonomy)`;
- acrescente um índice e uma taxonomia de metais, e os testes abaixo. O índice atual do arquivo continua servindo aos testes antigos.

```dart
  final metaisIndex = catalogIndexOf([
    catalogGroup(
      praiseId: 'm1',
      name: 'Marcha',
      pdfKinds: const {
        'sax': 'Saxofone',
        'alto': 'Saxofone alto',
        'tenor': 'Saxofone tenor',
        'grade': 'Grade',
      },
      audioKinds: const {'play': 'Playback'},
    ),
  ]);
  final metais = MaterialKindTaxonomy(
    classes: const [MaterialKindClass(id: 'metais', label: 'Metais')],
    kinds: const {
      'sax': MaterialKindTaxon(name: 'Saxofone', classId: 'metais', order: 30),
      'alto': MaterialKindTaxon(name: 'Saxofone alto', classId: 'metais', parentId: 'sax', order: 50),
      'tenor': MaterialKindTaxon(name: 'Saxofone tenor', classId: 'metais', parentId: 'sax', order: 60),
    },
  );

  Finder family(String label) =>
      find.widgetWithText(MaterialKindFamilyChip, label);

  testWidgets('classe com rótulo, família recolhida, Outros por último', (tester) async {
    await pump(tester, index: metaisIndex, taxonomy: metais);

    expect(find.text('METAIS'), findsOneWidget);
    expect(find.text('OUTROS'), findsOneWidget);
    expect(family('Saxofone'), findsOneWidget);
    expect(find.text('Saxofone alto'), findsNothing);
    expect(
      tester.getTopLeft(find.text('METAIS')).dy,
      lessThan(tester.getTopLeft(find.text('OUTROS')).dy),
    );
  });

  testWidgets('marcar a família inclui as variantes; tocar numa refina; desmarcar o pai limpa', (tester) async {
    final container = await pump(tester, index: metaisIndex, taxonomy: metais);

    await tester.tap(find.text('Saxofone'));
    await tester.pumpAndSettle();
    expect(container.read(catalogFiltersProvider).materialKindIds, {'sax'});

    await tester.tap(find.byTooltip('Ver variantes de Saxofone'));
    await tester.pumpAndSettle();
    final alto = tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Saxofone alto'));
    expect(alto.shape, isA<DashedRoundedRectangleBorder>(), reason: 'incluído');

    await tapChip(tester, 'Saxofone tenor');
    expect(container.read(catalogFiltersProvider).materialKindIds, {'sax', 'tenor'});
    expect(isSelected(tester, 'Saxofone tenor'), isTrue);

    await tester.tap(find.text('Saxofone'));
    await tester.pumpAndSettle();
    expect(container.read(catalogFiltersProvider).materialKindIds, isEmpty);
  });

  testWidgets('chip de Tipo esconde kinds, mostra a dica e «Todos» volta', (tester) async {
    await pump(tester, index: metaisIndex, taxonomy: metais);

    await tapChip(tester, 'Áudio');
    expect(find.text('Playback'), findsOneWidget);
    expect(family('Saxofone'), findsNothing);
    expect(find.text('4 materiais ocultos pelo tipo'), findsOneWidget);

    await tapChip(tester, 'Todos');
    expect(family('Saxofone'), findsOneWidget);
    expect(find.textContaining('ocultos pelo tipo'), findsNothing);
  });

  testWidgets('selecionado fora do tipo continua visível', (tester) async {
    await pump(tester, index: metaisIndex, taxonomy: metais);

    await tapChip(tester, 'Grade');
    await tapChip(tester, 'Áudio');
    expect(find.widgetWithText(FilterChip, 'Grade'), findsOneWidget);
  });

  testWidgets('sem taxonomia a lista fica plana, sem o rótulo Outros', (tester) async {
    await pump(tester, index: metaisIndex);

    expect(find.text('OUTROS'), findsNothing);
    expect(find.widgetWithText(FilterChip, 'Saxofone alto'), findsOneWidget);
  });
```

Se o `pump` do arquivo não tiver parâmetro `index`, acrescente `ColdigomSearchIndex? index` (padrão: o `index` atual do arquivo) e use-o no override de `coldigomSearchIndexProvider`. Os testes antigos que tocam «Grade» e «Cifra I» continuam valendo: sem taxonomia, esses kinds seguem como `FilterChip`.

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/widget/features/catalog/catalog_filter_sections_test.dart`
Expected: FAIL nos testes novos (`METAIS` não existe, e não há `MaterialKindFamilyChip`).

- [ ] **Step 3: Implementar a seção**

`lib/features/catalog/presentation/widgets/material_kind_filter_section.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../core/utils/material_id_kind.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../coldigom/presentation/providers/coldigom_catalog_providers.dart';
import '../../domain/entities/catalog_filter_options.dart';
import '../../domain/usecases/build_material_kind_sections.dart';
import '../../domain/utils/material_kind_selection.dart';
import '../providers/catalog_filter_options_provider.dart';
import '../providers/catalog_filters_provider.dart';
import 'material_kind_chips.dart';

/// Seção «Materiais» dos filtros (spec filtro-materiais §5): chips de Tipo,
/// uma seção por classe e as famílias recolhidas.
///
/// Os tipos marcados e as famílias abertas ficam só aqui — não vão para a
/// URL nem para as prefs, e voltam ao padrão quando o painel reabre.
class MaterialKindFilterSection extends ConsumerStatefulWidget {
  const MaterialKindFilterSection({super.key});

  @override
  ConsumerState<MaterialKindFilterSection> createState() =>
      _MaterialKindFilterSectionState();
}

class _MaterialKindFilterSectionState
    extends ConsumerState<MaterialKindFilterSection> {
  final Set<MaterialKind> _types = {};

  /// Abertura escolhida à mão; sem entrada, a família abre sozinha quando
  /// tem um filho marcado.
  final Map<String, bool> _open = {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final options = ref.watch(
      catalogFilterOptionsProvider.select((o) => o.materialKinds),
    );
    final taxonomy = ref.watch(coldigomKindTaxonomyProvider);
    final selected = ref.watch(
      catalogFiltersProvider.select((s) => s.materialKindIds),
    );
    final notifier = ref.read(catalogFiltersProvider.notifier);
    final view = buildMaterialKindSections(
      options: options,
      taxonomy: taxonomy,
      types: _types,
      selected: selected,
    );
    final onlyOthers =
        view.sections.length == 1 && view.sections.single.classId == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.coldigomFilterMaterials, style: AppTypography.label),
        const SizedBox(height: 8),
        if (view.typeCounts.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.materialTypeFilterLabel.toUpperCase(),
                style: AppTypography.label.copyWith(
                  fontSize: 11,
                  letterSpacing: 1,
                  color: AppColors.title.withValues(alpha: 0.7),
                ),
              ),
              MaterialTypeChip(
                label: l10n.materialTypeAll,
                selected: _types.isEmpty,
                onPressed: () => setState(_types.clear),
              ),
              for (final entry in view.typeCounts.entries)
                MaterialTypeChip(
                  label: _typeLabel(l10n, entry.key),
                  count: entry.value,
                  selected: _types.contains(entry.key),
                  onPressed: () => setState(() {
                    if (!_types.remove(entry.key)) _types.add(entry.key);
                  }),
                ),
            ],
          ),
        if (view.hiddenCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.materialKindHiddenByType(view.hiddenCount),
              style: AppTypography.hint(),
            ),
          ),
        for (final section in view.sections) ...[
          const SizedBox(height: 10),
          if (!onlyOthers)
            _ClassHeader(
              label: section.label ?? l10n.materialKindOtherClass,
              count: section.count,
            ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final unit in section.units)
                ..._unit(l10n, unit, selected, notifier.toggleMaterialKind),
            ],
          ),
        ],
      ],
    );
  }

  List<Widget> _unit(
    AppLocalizations l10n,
    MaterialKindUnit unit,
    Set<String> selected,
    void Function(String) toggle,
  ) {
    switch (unit) {
      case MaterialKindSingleUnit(:final option):
        return [_kindChip(option, selected, toggle)];
      case MaterialKindFamilyUnit(:final parent, :final children):
        final childIds = [for (final c in children) c.id];
        final state = materialKindFamilyState(parent.id, childIds, selected);
        final open =
            _open[parent.id] ?? state == MaterialKindFamilyState.refined;
        return [
          MaterialKindFamilyChip(
            label: parent.name,
            count: children.length,
            state: state,
            expanded: open,
            onToggle: () => toggle(parent.id),
            onExpand: () => setState(() {
              _open[parent.id] = !open;
            }),
            expandTooltip: l10n.materialKindShowVariants(parent.name),
          ),
          if (open)
            SizedBox(
              width: double.infinity,
              child: Container(
                margin: const EdgeInsets.only(left: 14, top: 2, bottom: 4),
                padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: AppColors.gold, width: 2),
                  ),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final child in children)
                      state == MaterialKindFamilyState.selected
                          ? MaterialKindChip(
                              label: child.name,
                              look: MaterialKindChipLook.included,
                              onPressed: () => toggle(child.id),
                            )
                          : _kindChip(child, selected, toggle),
                  ],
                ),
              ),
            ),
        ];
    }
  }

  Widget _kindChip(
    CatalogKindOption option,
    Set<String> selected,
    void Function(String) toggle,
  ) => MaterialKindChip(
    label: option.name,
    look: selected.contains(option.id)
        ? MaterialKindChipLook.selected
        : MaterialKindChipLook.normal,
    onPressed: () => toggle(option.id),
  );

  static String _typeLabel(AppLocalizations l10n, MaterialKind type) =>
      switch (type) {
        MaterialKind.pdf => l10n.materialTypePdf,
        MaterialKind.chord => l10n.materialTypeChord,
        MaterialKind.audio => l10n.materialTypeAudio,
        MaterialKind.youtube => l10n.materialTypeYoutube,
        MaterialKind.gesture => l10n.materialTypeGesture,
        MaterialKind.lyrics || MaterialKind.unknown => type.name,
      };
}

/// Rótulo da classe: caixa-alta pequena, contagem e um fio até a borda.
class _ClassHeader extends StatelessWidget {
  const _ClassHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.label.copyWith(
      fontSize: 11.5,
      letterSpacing: 1,
      color: AppColors.title.withValues(alpha: 0.7),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(label.toUpperCase(), style: style),
          const SizedBox(width: 6),
          Text('$count', style: style.copyWith(fontWeight: FontWeight.w400)),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              height: 1,
              thickness: 1,
              color: AppColors.title.withValues(alpha: 0.16),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Ligar no painel**

Em `catalog_filter_sections.dart`:
- importe `material_kind_filter_section.dart`;
- **apague** a entrada `_ChipSection(title: l10n.coldigomFilterMaterials, …)` da lista `sections`;
- no `Column` do `build`, depois do laço das seções, acrescente:

```dart
        if (options.materialKinds.isNotEmpty ||
            selected.materialKindIds.isNotEmpty) ...[
          if (sections.isNotEmpty) const SizedBox(height: 8),
          const MaterialKindFilterSection(),
        ],
```

Atualize o comentário da classe: «tipo de material» agora é a [MaterialKindFilterSection], com classes e famílias.

- [ ] **Step 5: Rodar e ver passar**

Run: `flutter test test/widget/features/catalog/`
Expected: PASS, incluindo os testes antigos do painel (`filters_panel_saved_filters_test.dart`, `filters_url_sync_across_tabs_test.dart`).

- [ ] **Step 6: Commit**

```bash
git add lib/features/catalog/presentation/widgets/material_kind_filter_section.dart \
  lib/features/catalog/presentation/widgets/catalog_filter_sections.dart \
  test/widget/features/catalog/catalog_filter_sections_test.dart
git commit -m "feat(catalog): seção Materiais por classe, com famílias e chips de Tipo

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Verificação final da branch

**Files:** nenhum arquivo novo.

- [ ] **Step 1: Análise e suíte inteira**

Run: `flutter analyze && flutter test`
Expected: `No issues found!` e todos os testes passando. Se algum teste de outra área quebrar porque compara `CatalogKindOption(id:, name:)` sem `types`, ajuste a expectativa com os tipos reais do helper (`{MaterialKind.pdf}` para `pdfKinds`, `{MaterialKind.audio}` para `audioKinds`).

- [ ] **Step 2: Olhar a tela uma vez**

Rode o app no Chrome (`flutter run -d chrome --dart-define-from-file=dart_defines/plpcg.json`), abra os filtros da Home e confira:
- com o coldigom de produção **antes** do plano 1, a lista fica plana, como hoje;
- a família abre e fecha;
- os chips de Tipo escondem e mostram kinds;
- na largura de celular (DevTools, 390 px), a linha das variantes não estoura.

Anote o que viu no relato final. A homologação completa (spec §8) é em produção, depois do deploy.

- [ ] **Step 3: Rebase sobre as subtags, se já mescladas**

```bash
git -C "/Volumes/SSD 2TB SD/dev/coldigui/.claude/worktrees/filtro-materiais" fetch . web/integration:web/integration 2>/dev/null || true
git -C "/Volumes/SSD 2TB SD/dev/coldigui/.claude/worktrees/filtro-materiais" rebase web/integration
```

O conflito esperado em `catalog_filter_sections.dart`: a outra branch tira a seção Categoria, e esta troca a seção Materiais. Mantenha as duas mudanças. Depois do rebase, rode `flutter analyze && flutter test` de novo.

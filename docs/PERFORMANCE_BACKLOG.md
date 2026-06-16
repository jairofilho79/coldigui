# Backlog de Performance — coldigui (PLPCG Flutter)

**Criado em:** 2026-06-13  
**Origem:** auditoria estática do código em `lib/` (~4600 louvores no manifest)  
**Público:** agentes de correção / skill `plpcg-performance-auditor`

Este documento lista oportunidades de melhoria identificadas e **não implementadas**. Use como checklist ao trabalhar em performance de catálogo, biblioteca, UI de listas e offline.

**Referência de padrão já adotado:** pipeline da Home com `compute()` — ver `lib/features/catalog/presentation/providers/home_search_provider.dart` e `home_search_worker.dart`.

---

## Priorização

| # | Item | Impacto | Esforço | Área |
|---|------|---------|---------|------|
| 1 | Pipeline da Biblioteca no thread principal | Alto | Médio | `library` |
| 2 | `carouselItems.any()` linear em cada card | Médio | Baixo | `catalog` / UI |
| 3 | `RegExp` reconstruídos em `normalize()` | Médio | Baixo | `core` |
| 4 | I/O de arquivo sequencial em `_collectValidPdfIds` | Médio (offline) | Baixo | `offline` |
| 5 | Lookup sequencial de skip IDs na extração ZIP | Baixo–Médio | Médio | `offline` |
| 6 | `catalogAvailableArranjosProvider` no thread principal | Baixo | Baixo | `catalog` |
| 7 | `int.tryParse` O(n log n) no sort de grupos | Baixo | Baixo | `catalog` |

**Ordem sugerida de correção:** 1 → 2 → 3 → 4 → 5 → 6 → 7

---

## #1 — Pipeline da Biblioteca executa no thread principal

**Impacto:** Alto  
**Esforço:** Médio  
**UCs relacionados:** UC-03  
**Arquivo principal:** `lib/features/library/presentation/providers/library_group_results_provider.dart`

### Problema

O pipeline `browse → group → sort → paginate` roda de forma **síncrona** dentro de um `Provider` no thread principal. Cada mudança de filtro, ordenação ou página reexecuta filtragem e agrupamento sobre ~4600 louvores na UI thread.

```dart
final libraryGroupResultsProvider = Provider<PaginatedLouvorGroups>((ref) {
  // ...
  return manifestAsync.when(
    data: (catalog) {
      final filtered = browse(catalog, ...);
      final grouped = group(filtered);
      final sorted = sort(grouped, ...);
      return paginate(sorted, ...);
    },
```

A Home já resolve o equivalente com isolate via `HomeSearchPipelineDriver` + `compute(runHomeSearchPipeline, input)`.

### Solução recomendada

1. Extrair pipeline para função top-level ou worker (como `runHomeSearchPipeline`).
2. Criar `AsyncNotifier` / `FutureProvider` com `compute()` ou `Isolate.run`.
3. Manter paginação no provider de UI **após** resultado cacheado do pipeline pesado, ou incluir paginação no worker.
4. Descartar resultados obsoletos com contador de geração (padrão `_generation` em `HomeSearchPipelineDriver`).

### Critério de aceite

- Mudança de filtro/ordenação na Biblioteca não causa jank perceptível (sem frames dropped no profiler).
- Testes unitários existentes de UC-03 continuam passando.
- Paridade de comportamento com implementação atual (mesmos resultados para mesmos inputs).

### Referências

- `lib/features/catalog/presentation/providers/home_search_provider.dart`
- `lib/features/catalog/presentation/providers/home_search_worker.dart`
- `test/unit/features/library/`

---

## #2 — `carouselItems.any()` linear em cada build de `LouvorGroupCard`

**Impacto:** Médio  
**Esforço:** Baixo  
**UCs relacionados:** UC-01, UC-03, UC-05  
**Arquivo principal:** `lib/features/catalog/presentation/widgets/louvor_group_card.dart`

### Problema

Cada card visível observa `carouselLouvoresProvider` e faz busca linear O(K) por `pdfId`:

```dart
final carouselItems = ref.watch(carouselLouvoresProvider);
final isAdded = primary != null &&
    carouselItems.any((item) => item.pdfId == primary.pdfId);
```

Quando o carousel muda, **todos** os cards que observam o provider rebuildam. Com N cards na viewport e K itens no carousel: O(N × K) comparações por evento.

### Solução recomendada

1. Expor `Provider<Set<String>>` (ou `Provider<ReadonlySet<String>>`) com os `pdfId`s do carousel — conversão para `Set` feita **uma vez** quando a lista muda.
2. Nos cards: `carouselPdfIds.contains(primary.pdfId)` — O(1).
3. Opcional: `select` no Riverpod para rebuild só quando membership do `pdfId` específico muda.

### Critério de aceite

- Adicionar/remover louvor do carousel não rebuilda cards cujo `isAdded` não mudou (se usar `select`).
- Widget tests de `LouvorGroupCard` / home / library passam.

### Referências

- `lib/features/carousel/presentation/providers/carousel_louvores_provider.dart`
- `test/widget/features/catalog/louvor_card_share_save_test.dart`

---

## #3 — `RegExp` reconstruídos em cada chamada de `normalize()`

**Impacto:** Médio  
**Esforço:** Baixo  
**UCs relacionados:** UC-01  
**Arquivo principal:** `lib/core/utils/louvor_search_tokens.dart`

### Problema

`LouvorSearchTokens.normalize()` compila 5 `RegExp` a cada chamada:

```dart
static String normalize(String text) {
  return text
      .toLowerCase()
      .replaceAll(RegExp(r'[àáâãäå]'), 'a')
      .replaceAll(RegExp(r'[èéêë]'), 'e')
      // ...
}
```

Chamado em:
- `Louvor.fromManifest` para cada louvor no boot (~4600×)
- ciclo de busca no isolate (repetido por keystroke após debounce)

### Solução recomendada

Declarar padrões como `static final` na classe:

```dart
static final _regA = RegExp(r'[àáâãäå]');
static final _regE = RegExp(r'[èéêë]');
// ...
```

Reutilizar também em `compact()`, `tokenize()` e `hasWordSeparators()` onde aplicável.

### Critério de aceite

- `test/unit/core/utils/louvor_search_tokens_test.dart` passa sem alteração de comportamento.
- Sem regressão em busca UC-01 (`home_search_worker_test`, `search_louvor_by_number_or_text_test`).

---

## #4 — Verificações de arquivo sequenciais em `DownloadMissingPdfs._collectValidPdfIds()`

**Impacto:** Médio (fluxo offline)  
**Esforço:** Baixo  
**UCs relacionados:** UC-10  
**Arquivo principal:** `lib/features/offline/domain/usecases/download_missing_pdfs.dart`

### Problema

Loop sequencial com `await _hasValidFile(entry)` — cada entrada faz `File.exists()` + `File.length()` em série:

```dart
for (final entry in entries) {
  if (await _hasValidFile(entry)) {
    validPdfIds.add(entry.pdfId);
  }
}
```

Com centenas de PDFs offline, a fase de pré-filtro atrasa o início dos downloads.

### Solução recomendada

Paralelizar em lotes (evitar saturar descritores):

```dart
const batchSize = 50;
for (var i = 0; i < entries.length; i += batchSize) {
  final batch = entries.sublist(i, min(i + batchSize, entries.length));
  final results = await Future.wait(batch.map(_hasValidFile));
  for (var j = 0; j < batch.length; j++) {
    if (results[j]) validPdfIds.add(batch[j].pdfId);
  }
}
```

### Critério de aceite

- `test/unit/features/offline/download_missing_pdfs_test.dart` passa.
- Mesmo conjunto de `validPdfIds` que a implementação sequencial.

---

## #5 — Lookup sequencial de skip IDs em `ExtractAndStorePdfs`

**Impacto:** Baixo–Médio  
**Esforço:** Médio  
**UCs relacionados:** UC-09  
**Arquivo principal:** `lib/features/offline/domain/usecases/extract_and_store_pdfs.dart`

### Problema

Antes de extrair ZIP, cada `pdfId` pendente consulta o repositório individualmente:

```dart
for (final pdfId in pendingIds) {
  if (await _repository.lookup(pdfId) != null) {
    skipPdfIds.add(pdfId);
  }
}
```

`lookup()` = Isar + verificação de arquivo por ID, em série.

### Solução recomendada

1. Adicionar `lookupBatch(Set<String> pdfIds) → Set<String>` (ou `Future<Set<String>>`) em `OfflinePdfRepository` / impl.
2. Uma transação Isar + validação de disco em lote (ou confiar no índice quando reconcile recente).
3. Usar resultado para montar `skipPdfIds` antes do `compute(extractZipPdfs, ...)`.

### Critério de aceite

- `test/unit/features/offline/extract_and_store_pdfs_test.dart` passa.
- Extração bulk não regrava PDFs já indexados.

### Referências

- `lib/features/offline/data/repositories/offline_pdf_repository_impl.dart`
- `lib/features/offline/domain/repositories/offline_pdf_repository.dart`

---

## #6 — `catalogAvailableArranjosProvider` varre o catálogo no thread principal

**Impacto:** Baixo  
**Esforço:** Baixo  
**UCs relacionados:** UC-02  
**Arquivo principal:** `lib/features/catalog/presentation/providers/catalog_filters_provider.dart`

### Problema

Provider síncrono recalcula set de arranjos disponíveis varrendo todo o manifest a cada atualização:

```dart
final catalogAvailableArranjosProvider = Provider<Set<String>>((ref) {
  final catalog = ref.watch(louvoresManifestProvider).value;
  if (catalog == null) return const {};
  return catalog
      .map((l) => LouvorClassification.baseClassification(l.classificacao))
      .toSet();
});
```

### Solução recomendada

- Pré-computar `availableArranjos` ao carregar/cachear manifest (repositório ou mapper), **ou**
- Derivar no mesmo isolate do pipeline de busca/biblioteca e expor via provider dedicado atualizado uma vez por carga de manifest.

### Critério de aceite

- Chips de arranjo em `FiltersPanel` / `CategoryFilters` inalterados funcionalmente.
- Testes de filtros UC-02 passam.

---

## #7 — `_compareGroups` chama `int.tryParse` O(n log n) vezes

**Impacto:** Baixo  
**Esforço:** Baixo  
**UCs relacionados:** UC-01, UC-03  
**Arquivo principal:** `lib/features/catalog/domain/entities/louvor_group.dart`

### Problema

Durante `groups.sort(_compareGroups)`, `int.tryParse` roda duas vezes por comparação:

```dart
static int _compareGroups(LouvorGroup a, LouvorGroup b) {
  final na = int.tryParse(a.numero) ?? -1;
  final nb = int.tryParse(b.numero) ?? -1;
  // ...
}
```

Para ~1500 grupos: ~20k parseamentos por sort.

### Solução recomendada

- Pré-parsear `numero → int` uma vez ao construir cada `LouvorGroup` (campo cache `numeroSortKey`), **ou**
- Sort com chave derivada: construir `List<(LouvorGroup, int)>` antes do sort.

### Critério de aceite

- `test/unit/features/catalog/group_louvores_by_material_test.dart` passa.
- Ordenação numérica + desempate por nome idêntica à atual.

---

## O que já está bem implementado (não reimplementar)

Registre aqui para evitar trabalho duplicado:

| Área | Padrão | Onde |
|------|--------|------|
| Busca Home off-main-thread | `compute` + debounce 300ms + generation discard | `home_search_provider.dart` |
| Tokens de busca pré-computados | `Louvor.fromManifest` | `louvor.dart` |
| Reconcile offline em chunks + isolate | `validatePdfPathsChunk` | `reconcile_offline_index.dart` |
| Extração ZIP em isolate | `compute(extractZipPdfs, ...)` | `extract_and_store_pdfs.dart` |
| Isolamento rebuild SearchBar vs resultados | `HomeSearchResultsSliver` | `home_search_results_sliver.dart` |
| Paginação Biblioteca | limita itens renderizados | `library_screen.dart` + `paginate_louvor_groups` |

---

## Verificação após correções

1. `flutter test test/unit/features/catalog/ test/unit/features/library/ test/unit/core/utils/louvor_search_tokens_test.dart`
2. `flutter test test/unit/features/offline/` (itens #4 e #5)
3. Widget tests: `test/widget/features/catalog/home_search_test.dart`, `library_screen_test.dart`
4. Profiler Flutter: scroll + troca de filtros na Biblioteca; digitação na Home; download faltantes offline

---

## Histórico

| Data | Ação |
|------|------|
| 2026-06-13 | Auditoria inicial — 7 itens documentados |

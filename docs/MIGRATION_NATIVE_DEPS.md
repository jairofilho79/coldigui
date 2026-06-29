# Migração de dependências nativas (SPM)

**Status:** Fase A concluída (jun/2026) — Fase B concluída (jun/2026) — Fase C concluída (jun/2026)  
**Data:** junho de 2026  
**Contexto:** Flutter 3.44+ usa Swift Package Manager (SPM) por padrão no iOS/macOS. Plugins sem SPM geram aviso e dependem de fallback CocoaPods (registro read-only em 2/dez/2026).

## Decisões

| # | Decisão | Motivação |
|---|---------|-----------|
| 1 | **Remover `disk_space_plus`** ✅ | Verificação prévia de espaço livre é opcional; o app já trata `ENOSPC` e converte em `InsufficientDiskSpaceException`. Reduz dependência nativa sem SPM. |
| 2 | **Migrar `isar` → `isar_plus`** ✅ | Isar original (`3.1.0+1`, 2023) sem manutenção. `isar_plus` + `isar_plus_flutter_libs` ativos, com SPM desde 1.2.7. |
| 3 | **Migrar `pdfx` → `pdfrx`** ✅ | pdfx sem SPM; pdfrx 2.4.4 + `pdfium_flutter` com SPM. Adapter + handle isolam API. |

## Ordem de execução recomendada

```text
Fase A — disk_space_plus ✅
    ↓
Fase B — isar → isar_plus ✅
    ↓
Fase C — pdfx → pdfrx ✅
```

**Regra para agentes:** uma fase por PR, salvo combinação explícita do mantenedor. Não misturar migrações no mesmo diff.

---

## Instruções gerais (todos os agentes)

### Antes de codar

1. Ler este documento e o ADR da fase atual (Fase B → [ADR-001](adr/ADR-001-isar-storage.md); Fase C → ADR do viewer PDF).
2. Ler [FEATURE_INDEX.md](features/FEATURE_INDEX.md) nas seções tocadas.
3. Confirmar Flutter **≥ 3.44** e Dart **≥ 3.12** (`flutter --version`).
4. Escopo mínimo: alterar só o necessário para a fase atual (regra anti-overengineering do projeto).

### Durante a implementação

- **Domínio** (`lib/features/*/domain/`): não importar pacotes de viewer nem storage nativo.
- **Data**: adapters/datasources concentram dependências de terceiros.
- **Testes**: atualizar fakes/mocks; não remover cobertura de regressão sem substituto equivalente.
- **iOS:** após mudanças nativas, rodar `flutter clean`, `flutter pub get`, `cd ios && pod install`.
- **Verificar SPM:** build iOS simulador **sem** aviso dos plugins alvo da fase.

### Antes de entregar

```bash
dart run build_runner build --delete-conflicting-outputs   # quando houver codegen
flutter analyze
flutter test
flutter build ios --simulator --dart-define-from-file=dart_defines/plpcg.json
```

### Documentação pós-fase

- Atualizar ADR correspondente (status → substituído ou revisado).
- Atualizar entradas relevantes em `FEATURE_INDEX.md`.
- Remover scripts/obsoletos citados na fase.

### O que **não** fazer

- Não desabilitar SPM (`enable-swift-package-manager: false`) como solução permanente.
- Não atualizar Riverpod, go_router ou outras deps não relacionadas **durante fases SPM** — ver [DEP_UPGRADE_BACKLOG.md](DEP_UPGRADE_BACKLOG.md) para upgrades major planejados.
- Não reescrever features fora do escopo da migração.
- Não commitar sem pedido explícito do usuário.

---

## Fase A — Remoção do `disk_space_plus` ✅

**Status:** concluída (jun/2026). Sem ADR associado.

### Escopo

Eliminar a dependência e a verificação **prévia** de espaço em disco. Manter tratamento de falta de espaço **durante** download/extração.

### Arquivos principais

| Arquivo | Ação |
|---------|------|
| `pubspec.yaml` | Remover `disk_space_plus` |
| `lib/features/offline/data/datasources/disk_space_checker.dart` | **Removido** |
| `lib/features/offline/data/providers/offline_providers.dart` | Remover `diskSpaceCheckerProvider` |
| `lib/features/offline/domain/usecases/download_offline_packages.dart` | Remover `_ensureDiskSpace` e injeção de `DiskSpaceChecker` |
| `lib/features/offline/domain/usecases/fetch_and_store_pdf.dart` | Remover `_ensureDeviceDiskSpace` e injeção |
| Testes com `_FakeDiskSpaceChecker`, `UnlimitedDiskSpaceChecker`, etc. | Simplificar construtores dos use cases |
| `docs/features/FEATURE_INDEX.md` | Atualizar referências a `disk_space_plus` |

### Comportamento esperado após a fase

| Cenário | Comportamento |
|---------|---------------|
| Bulk download (UC-09) | Sem checagem prévia de `freeBytes`; falha em `ENOSPC` → `InsufficientDiskSpaceException` (já implementado em `_downloadZip` / `_extractPdfs`) |
| Download unitário (`FetchAndStorePdf`) | Idem — confiar em quota LRU + `ENOSPC` |
| UI | Apenas bytes usados (`offlineStatsDiskUsageUsedOnly`); snackbar `offlineInsufficientDiskSpace` via ENOSPC |
| Simulador | Sem regressão |

### Cuidados

- **Não** remover `InsufficientDiskSpaceException` nem o mapeamento em `offline_bulk_download_provider.dart`.
- Revisar testes que assertam bloqueio **antes** do download por espaço insuficiente — devem passar a assertar falha em `ENOSPC` ou remover o caso se redundante.
- UC afetados: **UC-09**, **UC-10** (download unitário).

### Critérios de aceite

- [x] `disk_space_plus` ausente de `pubspec.yaml` e `pubspec.lock`
- [x] Nenhum `import 'package:disk_space_plus/...'`
- [x] `flutter test` verde (offline + ENOSPC)
- [x] Build iOS simulador sem aviso SPM de `disk_space_plus`

---

## Fase B — Migração `isar` → `isar_plus`

### Escopo

Substituir storage estruturado mantendo as 4 collections e o contrato dos repositórios/datasources.

### Collections (inalteradas em propósito)

| Collection | Arquivo | UCs |
|------------|---------|-----|
| `LouvorCache` | `lib/core/database/collections/louvor_cache.dart` | UC-01, UC-03, UC-12 |
| `CarouselEntry` | `lib/core/database/collections/carousel_entry.dart` | UC-05 |
| `Playlist` | `lib/core/database/collections/playlist.dart` | UC-06, UC-07 |
| `OfflinePdfIndex` | `lib/core/database/collections/offline_pdf_index.dart` | UC-09, UC-10 |

### Pacotes alvo

```yaml
dependencies:
  isar_plus: ^1.3.7
  isar_plus_flutter_libs: ^1.3.7

dev_dependencies:
  # Confirmar no README do isar_plus o pacote gerador correto antes de fixar versão
  build_runner: ^2.4.13
```

Remover: `isar`, `isar_flutter_libs`, `isar_generator`.

### Arquivos a tocar (lista não exaustiva)

- `lib/main.dart` — `Isar.open` → API `isar_plus` equivalente
- `lib/core/database/isar_provider.dart` — tipo `Isar` do novo pacote (renomear provider se desejado, ex. `isarPlusProvider`; manter override em `main()`)
- `lib/core/database/collections/*.dart` + `*.g.dart` — imports e annotations
- Datasources: `catalog_local_datasource.dart`, `carousel_local_datasource.dart`, `playlist_local_datasource.dart`, `offline_pdf_local_datasource.dart`
- `test/unit/core/database/isar_smoke_test.dart` e **todos** os testes que importam `package:isar/isar.dart`
- `docs/adr/ADR-001-isar-storage.md` — revisar após merge

### Migração de dados (crítico)

O binário do Isar original **não** é garantido como compatível com `isar_plus`.

**Estratégia recomendada para o PLPCG:**

1. Abrir banco com **novo nome de arquivo** ou schema version do `isar_plus` (evita crash em upgrade).
2. Na primeira execução pós-migração:
   - Recarregar manifest do catálogo (UC-12) — repopula `LouvorCache`.
   - Executar `ReconcileOfflineIndex` (UC-10) — reindexa PDFs que ainda existem no filesystem.
   - `CarouselEntry` e `Playlist` podem estar vazios após upgrade — aceitável se documentado; avaliar export/import JSON só se produto exigir preservação.
3. PDFs no disco (`path_provider`) **não** são apagados — apenas o índice Isar pode precisar de reconcile.

**Cuidados:**

- Ler changelog `isar_plus` 1.3.x (breaking: `setWorkerCount`, símbolos FFI `isar_plus_*`).
- Regenerar `*.g.dart`: `dart run build_runner build --delete-conflicting-outputs`.
- Consultar documentação oficial em https://pub.dev/packages/isar_plus **no início da fase** (API de codegen pode diferir do `isar_generator`).
- Não alterar campos/indexes das entities sem necessidade — minimiza diff e risco.
- Testes usam `Isar.open` em diretório temporário; atualizar imports e schemas registrados.
- Verificar Android (16 KB page size) e iOS release — `isar_plus_flutter_libs` tem fixes SPM em 1.3.5–1.3.7.

### Queries e padrões a validar

- Filtros `.filter()`, `.sortBy()`, `.watch()` nos datasources de catálogo, carousel, playlists e offline.
- Bulk writes em chunks (`OfflineConfig.bulkIsarChunkSize`).
- Transações se usadas em repositórios.

### Critérios de aceite

- [x] Nenhum import `package:isar/`
- [x] `isar_flutter_libs` removido; `isar_plus_flutter_libs` presente
- [x] Build iOS simulador **sem** aviso de SPM para Isar (verificar após `pod install`)
- [x] `flutter test -j 1` verde nos testes Isar (incl. `isar_smoke_test.dart`)
- [ ] Boot app → catálogo carrega → offline reconcile funciona (validação manual)
- [x] ADR-001 atualizado

### Release notes (upgrade)

- Carousel, playlists e índice offline reiniciam vazios após upgrade (binário Isar incompatível; banco `plpcg_plus` novo).
- PDFs em `plpcg_pdfs/` permanecem no disco; re-download via UC-09/UC-10 necessário para lookup offline sem rede.

---

## Fase C — Migração `pdfx` → `pdfrx` ✅

**Status:** concluída (jun/2026).

### Escopo

Substituir viewer mantendo a **porta de domínio** `PdfReaderControllerPort` e o isolamento do ADR-002.

### Arquitetura alvo

```text
domain/ports/pdf_reader_controller_port.dart   (sem mudança de contrato público)
data/adapters/pdfx_viewer_adapter.dart         → renomear p.ex. pdfrx_viewer_adapter.dart
presentation/widgets/pdfx_pdf_view.dart        → widget pdfrx (PdfViewer.*)
```

**Domínio e use cases** (`OpenPdfDocument`, `NavigatePdfPages`, `SetZoomAndFitMode`) não devem importar `pdfrx`.

### Pacotes

```yaml
dependencies:
  pdfrx: ^2.4.4
  # pdfrx_engine é transitivo; não adicionar manualmente salvo necessidade documentada

# Remover: pdfx
```

### Inicialização

Adicionar em `lib/main.dart` (antes de `runApp`):

```dart
import 'package:pdfrx/pdfrx.dart';

WidgetsFlutterBinding.ensureInitialized();
pdfrxFlutterInitialize();
```

Obrigatório se APIs do engine forem usadas antes de qualquer widget `PdfViewer`.

### Mapeamento conceitual pdfx → pdfrx

| pdfx | pdfrx (referência) |
|------|---------------------|
| `PdfDocument.openFile` / `openData` / `openAsset` | `PdfDocument.openFile` / `openData` / `openAsset` (via `pdfrx_engine`) |
| `PdfControllerPinch` | `PdfViewer` + `PdfViewerController` ou params de `PdfViewerParams` |
| `PdfViewPinch` | `PdfViewer.file` / `.data` / `.uri` |
| `controller.page`, `pagesCount` | API equivalente do controller pdfrx |
| Fit modes (`PdfFitMode`) | Mapear para params de zoom/layout do pdfrx |

### Arquivos principais

| Área | Arquivos |
|------|----------|
| Adapter | `lib/features/pdf_reader/data/adapters/pdfx_viewer_adapter.dart` |
| Providers | `pdf_reader_providers.dart`, `pdf_reader_document_provider.dart`, `pdf_reader_session_provider` (se existir), `pdf_session_cache.dart` |
| UI | `pdf_reader_screen.dart`, `pdfx_pdf_view.dart`, `pdf_reader_page_indicator.dart`, `pdf_page_swipe_policy.dart` |
| Testes | `pdfx_viewer_adapter_test.dart`, `pdf_reader_session_provider_test.dart`, `reader_adjacent_pdf_prefetch_provider_test.dart`, widgets do leitor |
| Scripts | **Remover** `scripts/apply_pdfx_patch.sh`; atualizar `scripts/setup_deps.sh` (só `flutter pub get`) |
| Docs | `docs/adr/ADR-002-pdfx-reader.md` → revisar para pdfrx |

### Cuidados de produto (UC-11)

Preservar comportamento documentado em [UC-11](use-cases/UC-11-read-pdf-reader.md) e [LEITOR_PERFORMANCE_BACKLOG.md](LEITOR_PERFORMANCE_BACKLOG.md):

- Dispose por sessão (`pdfReaderSessionProvider` autoDispose) — **não** singleton de documento.
- `bindController` / `unbindController` — manter semântica na nova API.
- Pré-cache de páginas adjacentes (carousel).
- Modos de navegação e zoom persistidos em `SharedPreferences`.
- Scroll **vertical** como padrão (patch do pdfx era para bug em horizontal — validar se pdfrx precisa de config equivalente).
- Cold-open: medir regressão de tempo; pdfrx usa PDFium (binário maior).

### Cuidados técnicos

- `PdfBytesDatasource` + `PdfSourceResolver` continuam válidos para URLs remotas; adapter deve abrir `Uint8List` via `PdfDocument.openData` quando remoto.
- Remover **todos** os `import 'package:pdfx/pdfx.dart'` da camada `presentation/` onde possível — preferir tipos da porta ou do adapter.
- Renomear providers (`pdfxViewerAdapterProvider` → nome neutro, ex. `pdfViewerAdapterProvider`) e atualizar referências.
- iOS: confirmar ausência de aviso SPM para `pdfx`; `pdfium_flutter` deve resolver via SPM.
- Opcional futuro (não nesta fase): `pdfrx_coregraphics` para reduzir tamanho no iOS — **experimental**; não adotar sem decisão separada.

### Critérios de aceite

- [x] `pdfx` ausente de `pubspec.yaml`
- [x] Nenhum import `package:pdfx/` fora de histórico git
- [x] `scripts/apply_pdfx_patch.sh` removido
- [x] Leitor abre PDF local, asset e remoto
- [x] Navegação, zoom, indicador de página e carousel adjacente funcionam
- [x] Build iOS simulador sem aviso SPM para pdfx
- [x] `flutter test` verde nos testes do leitor
- [x] ADR-002 atualizado
- [x] Skill `plpcg-performance-auditor` e FEATURE_INDEX referenciam novo adapter

---

## Matriz de risco

| Fase | Risco | Mitigação |
|------|-------|-----------|
| A | UX: usuário só descobre disco cheio no meio do download | Manter mensagens `InsufficientDiskSpaceException`; considerar aviso soft na UI offline (sem plugin nativo) em iteracao futura |
| B | Perda de playlists/carousel no upgrade | Aceitar no MVP + release notes; ou script de export JSON pré-migração |
| B | Incompatibilidade API `isar_plus` | Spike em branch: smoke test + um datasource antes do restante |
| C | Regressão performance cold-open | Benchmark antes/depois; checklist LEITOR_PERFORMANCE_BACKLOG |
| C | Tamanho do app (PDFium) | Monitorar IPA/APK; avaliar `pdfrx_coregraphics` depois |

---

## Referências

- [Flutter — SPM for app developers](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers)
- [isar_plus changelog](https://pub.dev/packages/isar_plus_flutter_libs/changelog) — SPM 1.2.7+, fixes 1.3.5–1.3.7
- [pdfrx](https://pub.dev/packages/pdfrx) — PDFium + SPM via `pdfium_flutter`
- [pdfx SPM PR (upstream, não mergeado)](https://github.com/ScerIO/packages.flutter/pull/609)
- [AGENT_PIPELINE.md](AGENT_PIPELINE.md) — fluxo QA/OpSec/Perf após cada fase
- [DEP_UPGRADE_BACKLOG.md](DEP_UPGRADE_BACKLOG.md) — upgrades major Dart/Flutter (pós-SPM)

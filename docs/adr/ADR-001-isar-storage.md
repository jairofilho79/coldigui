# ADR-001 — Isar Plus para storage estruturado

**Status:** Revisado (jun/2026) — migrado de `isar` 3.1 para `isar_plus` 1.3.7  
**Data:** junho de 2026

## Contexto

O PLPCG gerencia ~4600+ louvores no manifest, milhares de PDFs offline, playlists e carousel com consultas frequentes. A PWA usava localStorage e Cache Storage com problemas de dessincronização e lookup O(n).

## Decisão

Usar **isar_plus** (fork mantido do Isar) para metadados estruturados e índice offline. PDFs binários permanecem no **filesystem** via `path_provider`.

## Escopo Isar

| Collection | UC | Propósito |
|------------|-----|-----------|
| `LouvorCache` | UC-01, UC-03, UC-12 | Cache do manifest |
| `CarouselEntry` | UC-05 | Seleção temporária |
| `Playlist` | UC-06, UC-07 | Playlists salvas |
| `OfflinePdfIndex` | UC-09, UC-10 | Lookup O(1) pdfId → path |

## Pacotes

- `isar_plus`, `isar_plus_flutter_libs` ^1.3.7 (runtime; codegen embutido no pacote)
- `build_runner` (dev)

## Boot e migração

- `Isar.open(schemas: [...], directory: ..., name: 'plpcg_plus')` em `main.dart` — nome distinto evita crash com binário legado `default.isar`
- Upgrade de app: carousel, playlists e índice offline **reiniciam vazios**; catálogo repopula com rede (UC-12); PDFs em `plpcg_pdfs/` permanecem no disco mas exigem re-download para lookup offline

## API (breaking vs isar 3.1)

| isar 3.1 | isar_plus 1.3 |
|----------|----------------|
| `Id id = Isar.autoIncrement` | `int id = 0` + `collection.autoIncrement()` no put |
| `collection.filter()` | `collection.where()` |
| `writeTxn()` | `write()` (síncrono na isolate atual) |
| `Isar.open([schemas], directory:)` | `Isar.open(schemas: [...], directory:)` |

## Consequências

- Passo de CI: `dart run build_runner build`
- `core/database/isar_provider.dart` inicializa Isar no boot
- Testes: `test/flutter_test_config.dart` baixa/compila binário nativo em `.dart_tool/isar_plus_test/`; rodar `flutter test -j 1`
- SharedPreferences apenas para flags leves (`OFFLINE_AVAILABLE`, prefs do leitor)

## Alternativas rejeitadas

- **drift** — SQL overhead desnecessário para este domínio
- **hive** — performance inferior em volume alto vs Isar
- **isar 3.1 original** — sem manutenção nem SPM no iOS

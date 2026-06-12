# ADR-001 — Isar para storage estruturado

**Status:** Aceito  
**Data:** junho de 2026

## Contexto

O PLPCG gerencia ~4600+ louvores no manifest, milhares de PDFs offline, playlists e carousel com consultas frequentes. A PWA usava localStorage e Cache Storage com problemas de dessincronização e lookup O(n).

## Decisão

Usar **Isar** para metadados estruturados e índice offline. PDFs binários permanecem no **filesystem** via `path_provider`.

## Escopo Isar

| Collection | UC | Propósito |
|------------|-----|-----------|
| `LouvorCache` | UC-01, UC-03, UC-12 | Cache do manifest |
| `CarouselEntry` | UC-05 | Seleção temporária |
| `Playlist` | UC-06, UC-07 | Playlists salvas |
| `OfflinePdfIndex` | UC-09, UC-10 | Lookup O(1) pdfId → path |

## Pacotes

- `isar`, `isar_flutter_libs` (runtime)
- `isar_generator`, `build_runner` (dev)

## Consequências

- Passo de CI: `dart run build_runner build`
- `core/database/isar_provider.dart` inicializa Isar no boot
- SharedPreferences apenas para flags leves (`OFFLINE_AVAILABLE`, prefs do leitor)

## Alternativas rejeitadas

- **drift** — SQL overhead desnecessário para este domínio
- **hive** — performance inferior em volume alto vs Isar

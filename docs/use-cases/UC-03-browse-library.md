# UC-03 — Navegar biblioteca completa

| Campo | Valor |
|-------|-------|
| **ID** | UC-03 |
| **Feature** | `library` |
| **Prioridade** | Alta |
| **Ator** | Usuário |

## Pré-condições

Manifest carregado

## Fluxo principal

1. Acessa biblioteca. 2. Filtros e ordenação. 3. Paginação 10/25/50/100. 4. Clica card para abrir PDF.

## Fluxos alternativos

Banner atualizar lista → force_refresh_catalog. Sem busca → todos filtrados.

## Pós-condições

Lista paginada visível

## Regras de negócio

Diferente da home: não exige texto de busca

## Componentes Flutter alvo

LibraryScreen, SortLouvores, PaginateLouvores

## Dependências

UC-01, UC-02, UC-04

## Use case Dart

`lib/features/library/domain/usecases/` — ver FEATURE_INDEX.md

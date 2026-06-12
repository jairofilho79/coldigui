# UC-02 — Filtrar por material e arranjo

| Campo | Valor |
|-------|-------|
| **ID** | UC-02 |
| **Feature** | `catalog` |
| **Prioridade** | Alta |
| **Ator** | Usuário |

## Pré-condições

Filtros visíveis (colapsáveis na home)

## Fluxo principal

1. Seleciona materiais. 2. Seleciona arranjos. 3. Biblioteca: arranjo especial. 4. Filtro em tempo real.

## Fluxos alternativos

Cifra expande para Cifra nível I e II

## Pós-condições

Filtros sincronizados com URL

## Regras de negócio

Filtros sincronizados com URL via go_router

## Componentes Flutter alvo

CategoryFilters, filter_by_material_and_arranjo

## Dependências

UC-01

## Use case Dart

`lib/features/catalog/domain/usecases/` — ver FEATURE_INDEX.md

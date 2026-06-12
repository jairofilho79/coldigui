# UC-01 — Buscar louvor por número ou texto (Home)

| Campo | Valor |
|-------|-------|
| **ID** | UC-01 |
| **Feature** | `catalog` |
| **Prioridade** | Alta |
| **Ator** | Usuário (músico/regente) |

## Pré-condições

Manifest carregado; app online ou offline com catálogo cacheado

## Fluxo principal

1. Usuário acessa Home. 2. Expande filtros (opcional). 3. Digita número ou texto. 4. Debounce 300ms. 5. Resultados como LouvorCards.

## Fluxos alternativos

Busca vazia → lista vazia. Número exato → match prioritário. Texto → busca tolerante (acentos, stop words PT).

## Pós-condições

URL atualizada com pesquisa=; resultados visíveis

## Regras de negócio

Stop words PT; tokens pré-computados; home exige texto

## Componentes Flutter alvo

SearchBar, LouvorCard, search_louvor_by_number_or_text

## Dependências

UC-12

## Use case Dart

`lib/features/catalog/domain/usecases/` — ver FEATURE_INDEX.md

# UC-01 — Buscar louvor por número ou texto (Home)

| Campo | Valor |
|-------|-------|
| **ID** | UC-01 |
| **Feature** | `catalog` |
| **Prioridade** | Alta |
| **Ator** | Usuário (músico/regente) |

## Pré-condições

Manifest carregado; app online ou offline com catálogo cacheado (PLPCG em LouvorCache; Coldigom em ColdigomPraiseCache, hidratado no boot)

## Fluxo principal

1. Usuário acessa Home. 2. Expande filtros (opcional). 3. Digita número ou texto. 4. Debounce 300ms. 5. Resultados como LouvorGroupCard — PLPCG primeiro (com filtros UC-02), Coldigom depois (índice local ColdigomSearchIndex, mesmo ranking).

## Fluxos alternativos

Busca vazia → lista vazia. Número exato → match prioritário. Texto → busca tolerante (acentos, stop words PT).

## Pós-condições

URL atualizada com pesquisa=; resultados visíveis

## Regras de negócio

Stop words PT; tokens pré-computados; home exige texto; Coldigom local: número exato → título exato → parcial sobre nome + número + tags + autor (letra fora); sem rede continua a responder do índice.

## Componentes Flutter alvo

SearchBar, LouvorCard, search_louvor_by_number_or_text, ColdigomSearchIndex, coldigomCatalogHydrationProvider, CompositeCatalogSource.searchLocal

## Dependências

UC-12

## Use case Dart

`lib/features/catalog/domain/usecases/` — ver FEATURE_INDEX.md

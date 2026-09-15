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

1. Usuário acessa Home. 2. Expande filtros (opcional). 3. Digita número ou texto. 4. Debounce 300ms. 5. Resultados como LouvorGroupCard — lista única local (PLPCG com filtros, depois Coldigom do índice), linha «Em cache · a verificar…» no topo. 6. A página 1 remota do Coldigom valida: igual → «Atualizado»; louvores que o local não tinha → anexados no fim com o chip «novo», gravados no Isar (AdoptColdigomSearchNovelties) e sync do catálogo disparado.

## Fluxos alternativos

Busca vazia → lista vazia. Número exato → match prioritário. Texto → busca tolerante (acentos, stop words PT). Sem rede → «Em cache · sem ligação» (remoto não é chamado). Remoto falha → «Em cache · não foi possível verificar» (toque = tentar de novo); lista local intacta. Remoto com menos itens que o local → nada é removido (só o sync substitui).

## Pós-condições

URL atualizada com pesquisa=; resultados visíveis

## Regras de negócio

Stop words PT; tokens pré-computados; home exige texto; Coldigom local: número exato → título exato → parcial sobre nome + número + tags + autor (letra fora); sem rede continua a responder do índice. Sem paginação Coldigom na Home (O15); ordem PLPCG → Coldigom → novos (O16). «novo» = novo para o catálogo local: grupos que só o remoto encontrou mas já existem no índice são listados no fim sem chip nem contagem.

## Componentes Flutter alvo

SearchBar, LouvorCard, search_louvor_by_number_or_text, ColdigomSearchIndex, coldigomCatalogHydrationProvider, CompositeCatalogSource.searchLocal, SearchFreshnessLine, homeSearchStateProvider (SearchFreshness), AdoptColdigomSearchNovelties

## Dependências

UC-12

## Use case Dart

`lib/features/catalog/domain/usecases/` — ver FEATURE_INDEX.md

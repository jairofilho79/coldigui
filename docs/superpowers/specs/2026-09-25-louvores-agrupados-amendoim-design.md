# Louvores agrupados no «amendoim»

**Data:** 2026-09-25
**Estado:** design aprovado em conversa (partes 1–4); spec aguardando revisão do dono.
**Mock aprovado:** https://claude.ai/artifact/8MA93EqDCAUzY6aGP1Hiqa. A forma é a variante **E «Coração pleno»**, e a etiqueta a **«Rótulo 1 · Automático»**.
**Repos:**
- `coldigom`: `api/` (dump do catálogo);
- `coldigui`: o app Flutter.

**Branches:**
- `coldigom`: `feat/catalogo-group-id`, a partir de `origin/main`, num worktree próprio (a criar);
- `coldigui`: `feat/louvores-agrupados`, a partir de `web/integration` (@ `d82da886`), no worktree `.claude/worktrees/louvores-agrupados`.

## 0. Objetivo e limites

No coldigom, louvores podem ser **agrupados** (`praises.group_id`): em geral é o mesmo cântico em versões diferentes, como a da Coletânea e o arranjo PES. No app, nem a Home nem a /biblioteca mostram isso, e dois chips «#003 — Clamo a ti» aparecem idênticos, sem nada que os ligue ou diferencie.

A entrega faz o app mostrar cada grupo como **uma forma só**, o «amendoim»:
- os chips dos membros ficam empilhados e colados;
- as juntas têm bico, como o topo de um coração;
- cada gomo leva uma **etiqueta dourada** com o que diferencia aquela versão.

**Não entra (decidido):**
- **Outras telas com chip.** A barra do carrossel, o painel da lista ativa, os detalhes de playlist e o estado vazio da Home continuam com a pílula de hoje. Só a Home (resultados da busca) e a /biblioteca mudam.
- **Mudança na unidade do app.** O louvor (praise) continua sendo a unidade de playlist, do link `?p=`, dos favoritos, do «+» e do offline. O grupo existe só na lista da tela.
- **Rótulo curado no admin.** A etiqueta sai de regra automática sobre as tags (§5), sem campo novo no banco.
- **Editar grupos pelo app.** Os grupos continuam sendo montados no admin do coldigom (botão «Agrupar Louvor»).

## 1. Fatos medidos (2026-09-25)

| # | Fato | Consequência |
|---|---|---|
| F1 | `praises.group_id` existe desde a migração 008. O valor é o id do praise âncora, e o âncora também o recebe (`POST /api/praises/:id/group`, `api/src/routes/praises.ts`). | Todos os membros têm o mesmo `group_id` não nulo. Não precisa de migração. |
| F2 | O dump `GET /api/plpcg/catalog` (`buildPlpcgCatalog`, `api/src/plpcgPraises.ts`) lê só `id, short_id, name, number, author, rhythm, tonality, lyrics`. Ele manda `shortId` só quando existe, e o ETag é o hash do corpo. | `groupId` entra no mesmo molde do `shortId`, e o ETag muda sozinho. |
| F3 | `GET /api/plpcg/praises`, a busca remota que valida a Home, já devolve `group_id`. | Os «novos» da busca remota também sabem o grupo. |
| F4 | No app, nada carrega o grupo: `ColdigomCatalogPraiseDto`, `PraiseDetailDto`, `ColdigomPraiseCache` (Isar), `ColdigomPraiseMetadata`. `LouvorGroup.groupId` é o praiseId (um cartão por praise). | O campo percorre DTO → Isar → metadata, como o `shortId` percorreu em 24/09. |
| F5 | Amostra de 1.100 dos 2.009 praises: 82 `group_id` distintos com 139 membros. Quase todos são pares Coletânea + PES do mesmo número. Há um grupo de 3 (039: SCTB, Solo e Coletânea) e um com números diferentes (034 «Pelo Vale Escuro…» e 307 «Pelo vale escuro…»). | Não dá para contar com número igual. A junção é por `group_id`. |
| F6 | Ordenar não junta os membros. A Home ranqueia número exato → título exato → parcial (`ColdigomSearchIndex.search`), e a /biblioteca ordena por número ou nome (`SortLouvorGroups`) e pagina de 10 em 10 (`PaginateLouvorGroups`). | A junção é um passo explícito depois de ordenar e filtrar, e antes de paginar. |
| F7 | O chip é `CarouselLouvorChip` (pílula vinho `#6A2F2F`, contorno dourado `#D4AF37` de 2 px, raio 24, `shadowMd`). Home e /biblioteca o usam via `LouvorGroupCard`. | O gomo é o mesmo chip, com outra borda (§6). |

## 2. Decisões do dono (2026-09-25)

| # | Decisão |
|---|---|
| D1 | A forma é o amendoim da variante **E**: pontas de pílula, cada lado do gomo uma curva só e bico de 10 px na junta, com costura dourada de bico a bico. |
| D2 | **Grupo puxado em bloco.** O grupo entra na posição do membro mais bem colocado, os outros membros vêm junto, e na paginação o grupo conta como 1 item. |
| D3 | **Grupo sempre completo.** Membros que não casaram com a busca ou os filtros aparecem **esmaecidos**, mas clicáveis. |
| D4 | **Etiqueta automática** a partir das tags (§5). |
| D5 | **Dados vêm do coldigom**, e a junção é feita no app (caminho 1). |
| D6 | **Cada gomo se comporta como o chip de hoje.** Tocar abre os materiais daquela versão, o «+» adiciona aquela versão, e ícones, offline e «novo» são por gomo. |

## 3. Dados

### 3.1 coldigom — dump do catálogo

- A query de praises de `buildPlpcgCatalog` passa a ler também `p.group_id`.
- Cada praise do corpo ganha `groupId` só quando `group_id` não é nulo nem vazio, como já é feito com `shortId`.
- **Sem migração**, sem mudança de rota e sem mudança em `/api/plpcg/praises`.
- Versões antigas do app ignoram o campo.
- O ETag muda uma vez, e cada aparelho baixa o catálogo inteiro no próximo sync.
  - Custo: uma requisição por aparelho, como em qualquer mudança de catálogo.
  - O corpo cresce ~40 bytes × ~150 praises agrupados.

### 3.2 coldigui — do DTO à metadata

| Camada | Mudança |
|---|---|
| `ColdigomCatalogPraiseDto` (`coldigom_catalog_dto.dart`) | `final String? groupId`, lido de `json['groupId']`. Vazio ou só espaços vira `null`. |
| `PraiseDetailDto` (`praise_dto.dart`) | `groupId`, lido de `json['group_id']`, com a mesma normalização. É o caminho dos «novos» da busca remota. |
| `ColdigomPraiseCache` (Isar) | `String? groupId`, campo anulável novo, e o `.g.dart` regerado com `build_runner`. O dump novo substitui as linhas (ETag diferente), então não há migração no aparelho. |
| `ColdigomPraiseCacheMapper` | Leva `groupId` nos dois sentidos, onde hoje leva `shortId`. |
| `ColdigomPraiseMetadata` | `final String? groupId`, que é o que a junção e o chip enxergam. |

### 3.3 Índice — mapa de membros

`ColdigomSearchIndex.build` monta, uma vez por hidratação, `membersOf(String praiseGroupId) → List<LouvorGroup>`:
- traz só os membros que estão em `entries`, ou seja, com material endereçável;
- vem na **ordem fixa** de §4.4;
- só registra grupos com **≥ 2 membros**.

Um `group_id` com 1 membro no índice não é grupo, e o chip dele é normal.

## 4. A junção na lista

### 4.1 Entrada da lista

```dart
sealed class CatalogListEntry {}
final class SingleEntry extends CatalogListEntry { final LouvorGroup group; }
final class ClusterEntry extends CatalogListEntry {
  final String praiseGroupId;
  final List<ClusterMember> members; // ≥ 2, ordem fixa (§4.4)
}
final class ClusterMember { final LouvorGroup group; final bool matched; }
```

### 4.2 A função

```dart
List<CatalogListEntry> clusterCatalogList(
  List<LouvorGroup> ordered,                              // já ordenado e filtrado = os que casaram
  {required List<LouvorGroup> Function(String praiseGroupId) membersOf,
   Iterable<LouvorGroup> extraMembers = const []}          // membros fora do índice (novos remotos)
)
```

A função é pura, fica em `lib/features/catalog/domain/usecases/` e tem testes próprios. A ideia é a seguinte:
1. Percorre `ordered`. No primeiro membro de cada `group_id` com ≥ 2 membros (contando o índice e os `extraMembers`), emite um `ClusterEntry` naquela posição.
2. O `ClusterEntry` leva **todos** os membros. `matched` é verdadeiro para os que estão em `ordered`.
3. As aparições seguintes de membros daquele grupo em `ordered` são puladas.
4. Um praise sem grupo, ou com grupo de 1 membro, vira `SingleEntry`.
5. Um grupo sem nenhum membro em `ordered` não aparece.

### 4.3 Onde entra

**Home** (`HomeSearchState`):
- Ganha `entries = clusterCatalogList([...localGroups, ...newGroups], membersOf: index.membersOf, extraMembers: newGroups)`.
- Um «novo» remoto que é membro de um grupo já na tela entra no amendoim, e não no fim da lista.
- `newGroupIds`, `newCount` e `freshness` não mudam: continuam contando praises.
- `HomeSearchResultsSliver` passa a iterar `entries` com chave `card-${groupId}` ou `cluster-${praiseGroupId}`.

**/biblioteca:**
- `libraryFilteredGroupsProvider` não muda: continua dando os que casaram, já ordenados.
- Um provider novo, `libraryEntriesProvider`, aplica a junção.
- `libraryGroupResultsProvider` pagina **entradas**: cada `ClusterEntry` conta 1 item e nunca se parte entre páginas.
- `PaginatedLouvorGroups` passa a paginar `CatalogListEntry` (ou vira `PaginatedCatalogEntries`).
- `LibraryResultsSummary` mostra o intervalo e o total **em entradas**, que é o que a paginação percorre (ver §9, P1).

### 4.4 Ordem fixa dentro do amendoim

Independe da ordenação da tela, então o amendoim de um grupo é igual na Home e na /biblioteca:
1. `numeroSortKey` crescente (a mesma chave de `SortLouvorGroups`; sem número vai por último);
2. empate: nome normalizado (sem acento, minúsculo);
3. empate: menos tags primeiro, para a versão-base (Coletânea) vir antes do arranjo (PES);
4. empate: `praiseId`.

Com os dados reais:
- «Clamo a ti»: Coletânea, depois GLTM · PES.
- 039: «Jesus, Tu és o meu Deus» (39), depois «(SCTB)», depois «(Solo)».
- «Pelo vale escuro»: 034, depois 307.

## 5. Etiqueta de cada gomo

Função pura `clusterMemberLabel(member, allMembers) → String?`, sobre `ColdigomPraiseMetadata.tagNames` na ordem do catálogo:
1. `comuns` são as tags que **todos** os membros têm.
2. `próprias` são as tags do membro menos as `comuns`, na ordem dele. Se houver alguma, a etiqueta é `próprias.join(' · ')`.
3. Se não houver, a etiqueta é a **primeira tag** do membro cortada antes do primeiro `' · '` («Coletânea · Clamor» vira «Coletânea»).
4. Membro sem tag nenhuma: sem etiqueta.

A etiqueta tem largura máxima de 128 px e corta com «…».

Casos de teste (dados reais):

| Grupo | Membro (tags) | Etiqueta |
|---|---|---|
| Clamo a ti | Coletânea · Clamor | Coletânea |
| | GLTM, PES, Coletânea · Clamor | GLTM · PES |
| 039 | (SCTB) PES, Coletânea · Clamor | PES |
| | (Solo) PES, Coletânea · Clamor | PES |
| | (39) Coletânea · Clamor | Coletânea |
| Pelo vale escuro | (034) Avulsos, PES, Migrados | Avulsos · PES · Migrados |
| | (307) Coletânea · Consolo e Encorajamento | Coletânea · Consolo e Encorajamento (cortada com «…» na tela) |

## 6. Desenho

### 6.1 `PeanutLobeBorder` (ShapeBorder)

Desenha **um gomo**, conforme `LobePosition { first, middle, last }`. Os gomos empilhados sem espaço formam o amendoim.

Geometria, para um gomo de largura `w` e altura `h` (a altura vem do conteúdo, e um gomo com trecho de letra é mais alto):
- **Ponta de pílula** (topo do `first`, base do `last`): raio `R = 24`, o mesmo do chip solto (`carouselChipRadius` modal).
- **Meia-junta de coração** (base do `first`, topo e base do `middle`, topo do `last`):
  - o bico fica **recuado `d = 10`** da lateral, na linha da junta;
  - o arco vai do bico até a lateral, a uma distância vertical `a = min(26, h − R)` da junta, no `first` e no `last`;
  - no `middle` a distância é `a = min(26, h / 2)`;
  - o arco é convexo, de raio `r′ = (d² + a²) / (2d)` (38,8 para `a = 26`), com centro em `(w − r′, y_junta ∓ a)` à direita e espelhado à esquerda;
  - o trecho que sobra da lateral é reto.
- **Contorno**: dourado `AppColors.gold`, 2 px, só nas laterais e nas pontas.
- **Costura**: a linha da junta fica **sem contorno cheio**, só com a costura dourada a 60 % de opacidade e 1 px, de bico a bico. Quem desenha a costura é o gomo de baixo (topo de `middle` e de `last`), para não pintar duas vezes.
- **Preenchimento**: `AppColors.title` (`#6A2F2F`).

A borda também serve de `shape` do `Material`/`InkWell` do gomo, então o ripple fica recortado no gomo.

### 6.2 `CarouselLouvorChip`: parâmetros novos (opcionais)

| Parâmetro | Efeito | Padrão |
|---|---|---|
| `LobePosition? lobePosition` | Troca a pílula pela `PeanutLobeBorder`. Sem sombra própria (quem desenha a sombra é o cluster). O padding esquerdo passa para 20 px, para o texto não encostar no bico. | `null` = pílula de hoje |
| `String? groupLabel` | Etiqueta dourada à direita, antes do «+», no estilo do selo «novo»: fundo `gold@0.14`, borda `gold@0.6` de 1 px, raio 8, texto `goldLight` OpenSans w600 10, máximo de 128 px com «…». | `null` |
| `bool dimmed` | Esmaece **só o conteúdo** (título, trecho, ícones, etiqueta, botões) com `Opacity(0.45)`. O fundo e o contorno ficam inteiros. O toque continua ativo. | `false` |

Nada mais no chip muda.

### 6.3 `LouvorClusterCard`

- Recebe um `ClusterEntry`.
- Empilha um `LouvorGroupCard`-gomo por membro, com `lobePosition`, `groupLabel` (§5) e `dimmed = !matched`, **sem espaço** entre eles.
- Desenha **uma sombra** (`shadowMd`) atrás do conjunto.
- Mantém o `Padding(bottom: 8)` do `LouvorGroupCard` só no fim do cluster.
- `LouvorGroupCard` ganha os mesmos três parâmetros e os repassa ao chip. O resto dele (toque, «+», offline, download) continua por gomo.

## 7. Testes

**coldigom** (`api`, vitest):
- o dump manda `groupId` quando existe e omite quando é `null`;
- o ETag muda quando um `group_id` muda.

**coldigui — unidade:**
- DTOs leem `groupId`/`group_id`, e o vazio vira `null`;
- mapper: ida e volta catálogo → Isar → metadata;
- índice: `membersOf` na ordem de §4.4, e grupo de 1 membro não é registrado;
- `clusterCatalogList`:
  - posição do membro mais bem colocado;
  - grupo completo com `matched` certo;
  - grupo sem membro que casou fica de fora;
  - aparições seguintes puladas;
  - «novo» remoto entrando no cluster;
- paginação: cluster conta 1 e não se parte;
- `clusterMemberLabel`: a tabela de §5.

**coldigui — widget:**
- `LouvorClusterCard` desenha N gomos;
- tocar no gomo *k* abre o praise *k*;
- `dimmed` baixa a opacidade do conteúdo e não a do fundo;
- `PeanutLobeBorder` põe o bico a `d = 10` e aceita gomo mais alto que 52 px, com trecho reto na lateral.

**Conferência visual** (dono): o app rodando contra a API já com `groupId`, olhando «Clamo a ti», o 039 e «Pelo vale escuro» na Home e na /biblioteca.

## 8. Entrega

As duas etapas são independentes:
1. **API** (`coldigom`): PR `feat/catalogo-group-id` → `develop` → `main`; o merge em `main` dispara `Deploy API to Workers`. Pode ir antes do app, porque as versões antigas ignoram o campo.
2. **App** (`coldigui`): `feat/louvores-agrupados`, com merge em `web/integration` como os demais trabalhos do app. Sem `groupId` no dump, a junção não acha grupos e a lista fica como hoje.

## 9. Pontos a confirmar na revisão

- **P1 — resumo da /biblioteca.** «Mostrando 1–10 de N»: proponho que N conte **entradas** (cartões), porque é o que a paginação percorre. Contar só os louvores que casaram deixaria o intervalo e o total em unidades diferentes. Na Home, o «N novos» continua contando louvores.

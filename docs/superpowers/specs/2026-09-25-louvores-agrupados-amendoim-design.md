# Louvores agrupados no «amendoim»

**Data:** 2026-09-25
**Estado:** design aprovado em conversa (partes 1–4); revisado contra o código (subagente, 2026-09-25); spec aguardando revisão do dono.
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
| F1 | `praises.group_id` existe desde a migração 008. O valor é o id do praise âncora, e o âncora também o recebe (`POST /api/praises/:id/group`, `api/src/routes/praises.ts`). Se o âncora for reagrupado noutro lugar, os demais ficam com o id antigo. Não há rota de desagrupar, e o `scripts/validate-acervo` também grava `group_id`. | O `group_id` é uma **chave opaca**: o app nunca o trata como id de praise. Não precisa de migração. |
| F2 | O dump `GET /api/plpcg/catalog` (`buildPlpcgCatalog`, `api/src/plpcgPraises.ts`) lê só `id, short_id, name, number, author, rhythm, tonality, lyrics`. Ele manda `shortId` só quando existe, e o ETag é o hash do corpo. | `groupId` entra no mesmo molde do `shortId`, e o ETag muda sozinho. |
| F3 | `GET /api/plpcg/praises`, a busca remota que valida a Home, já devolve `group_id`. | Os «novos» da busca remota também sabem o grupo. |
| F4 | No app, nada carrega o grupo: `ColdigomCatalogPraiseDto`, `PraiseDetailDto`, `ColdigomPraiseCache` (Isar), `ColdigomPraiseMetadata`. `LouvorGroup.groupId` é o praiseId (um cartão por praise). | O campo percorre DTO → Isar → metadata, como o `shortId` percorreu em 24/09. |
| F5 | Amostra de 1.100 dos 2.009 praises: 82 `group_id` distintos com 139 membros. Quase todos são pares Coletânea + PES do mesmo número. Há um grupo de 3 (039: SCTB, Solo e Coletânea) e um com números diferentes (034 «Pelo Vale Escuro…» e 307 «Pelo vale escuro…»). | Não dá para contar com número igual. A junção é por `group_id`. |
| F6 | Ordenar não junta os membros. A Home ranqueia número exato → título exato → parcial (`ColdigomSearchIndex.search`), e a /biblioteca ordena por número ou nome (`SortLouvorGroups`) e pagina de 10 em 10 (`PaginateLouvorGroups`). | A junção é um passo explícito depois de ordenar e filtrar, e antes de paginar. |
| F7 | O chip é `CarouselLouvorChip` (pílula vinho `#6A2F2F`, contorno dourado `#D4AF37` de 2 px, raio `_modalChipRadius = 24`, `shadowMd`). Home e /biblioteca o usam via `LouvorGroupCard`. O único `InkWell` fica dentro de `ChipBody`, recuado pelo padding 8/6, com `borderRadius: 24`, e o «+» fica fora dele. | O gomo é o mesmo chip, com outra borda (§6). O ripple já é interno e não vaza pelo bico. |
| F8 | `SyncColdigomCatalog.run` só manda `If-None-Match` quando o catálogo local tem algum `shortId` e a taxonomia dos kinds está gravada (`sync_coldigom_catalog.dart`). A trava existe porque um app antigo guarda o ETag de um dump cujos campos novos ele não lia, e aí o servidor responde 304 para sempre. | O `groupId` cai na mesma armadilha se a API sair antes do app. Precisa de trava (§3.4). |

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
| `ColdigomPraiseCache` (Isar) | `String? groupId`, campo anulável novo, com o `.g.dart` regerado por `build_runner` (precedente: `shortId`, commit `6c77feb0`). É aditivo, inclusive no Isar web (sqlite). |
| `ColdigomPraiseCacheMapper` | Leva `groupId` nos **cinco** lugares onde hoje leva `shortId`: `fromCatalogPraise`, `fromPraiseDetail`, `fromLouvorGroup` (adoção dos «novos», via `meta?.groupId`), `toPraiseDetail` e `_row`. A hidratação passa por linha → `toPraiseDetail` → `PraiseDetailDto`. |
| `ColdigomLouvorAdapter.toMetadata` | `groupId: praise.groupId`. É por aqui que toda metadata nasce: hidratação (`coldigom_catalog_providers.dart`), busca remota (`coldigom_search_repository_impl.dart`) e `coldigom_cache_writer.dart`. |
| `ColdigomPraiseMetadata` | `final String? groupId`, que é o que a junção e o chip enxergam. |

### 3.3 Índice — mapa de membros

`ColdigomSearchIndex.build` monta, uma vez por hidratação, `membersOf(String praiseGroupId) → List<LouvorGroup>`:
- traz **todos** os membros que estão em `entries` (com material endereçável), **inclusive quando só há 1**;
- vem na **ordem fixa** de §4.4.

O limite de «≥ 2 membros» não fica no índice, e sim na junção (§4.2), **depois** de somar os membros que vieram da busca remota. Exemplo: o índice tem só A do grupo G, e a busca remota traz B, também de G. `membersOf(G)` devolve `[A]`, a junção soma B e forma o amendoim.

### 3.4 Sincronização — forçar o dump inteiro uma vez

- `ColdigomCatalogSyncMetadataStore` ganha `readCatalogSchemaVersion()` / `writeCatalogSchemaVersion(int)`, em `SharedPreferences` como o ETag.
- O app declara uma constante `coldigomCatalogSchemaVersion = 1`, que é esta entrega (`groupId`), e grava o valor em `markReplaced`.
- Em `SyncColdigomCatalog.run`, a condição que anula o ETag ganha `|| _metadata.readCatalogSchemaVersion() < coldigomCatalogSchemaVersion`, com `null` contando como 0.
- Efeito: no primeiro sync do app novo, o pedido sai sem `If-None-Match`, o corpo vem inteiro e as linhas ganham `groupId`. Depois disso, volta o 304 normal.
- Não se usa `hasAnyGroupId()`: se o app sair antes da API, ou se não existir grupo nenhum, essa checagem baixaria o dump inteiro a cada sync.
- Um campo novo no futuro só precisa subir a constante.

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
1. Os membros de um grupo são `membersOf(g)` ∪ `extraMembers` do mesmo `group_id`, **sem repetir praiseId** (`LouvorGroup.groupId`). Isso importa porque `newGroups` na Home não traz só praises novos: traz todo grupo remoto que a busca local não achou, inclusive os que já estão no índice (`home_search_provider.dart`). Em caso de repetição, vale a instância do índice. Depois, os membros vão para a ordem fixa (§4.4).
2. Percorre `ordered`. No primeiro membro de cada `group_id` com **≥ 2 membros depois da soma**, emite um `ClusterEntry` naquela posição.
3. O `ClusterEntry` leva **todos** os membros. `matched` é verdadeiro para os que estão em `ordered`.
4. As aparições seguintes de membros daquele grupo em `ordered` são puladas.
5. Um praise sem grupo, ou com grupo que continua com 1 membro depois da soma, vira `SingleEntry`.
6. Um grupo sem nenhum membro em `ordered` não aparece.

### 4.3 Onde entra

**Home:**
- `HomeSearchState` não enxerga o índice, então as entradas são calculadas em `homeSearchStateProvider` e passadas no construtor, como `entries`, nos **três** ramos: query vazia, offline e com remoto.
- O cálculo é `clusterCatalogList([...localGroups, ...newGroups], membersOf: index.membersOf, extraMembers: newGroups)`.
- Um «novo» remoto que é membro de um grupo já na tela entra no amendoim, e não no fim da lista.
- `groups`, `newGroupIds`, `newCount` e `freshness` não mudam: continuam contando praises.
- `HomeSearchResultsSliver` passa a iterar `entries`, com chave `card-${groupId}` para o chip solto e `cluster-${praiseGroupId}` para o grupo. O «novo» de cada gomo vem de `state.newGroupIds`.

**/biblioteca:**
- `libraryFilteredGroupsProvider` não muda: continua dando os que casaram, já ordenados.
- Um provider novo, `libraryEntriesProvider`, aplica a junção.
- `libraryGroupResultsProvider` pagina **entradas**: cada `ClusterEntry` conta 1 item e nunca se parte entre páginas. `PaginateLouvorGroups`/`PaginatedLouvorGroups` passam a `PaginateCatalogEntries`/`PaginatedCatalogEntries`, com os mesmos campos de página (`page`, `itemsPerPage`, `totalItems`, `totalPages`) e `items` como `List<CatalogListEntry>`.
- `LibraryResultsSummary` mostra o intervalo e o total **em entradas** (cartões), que é o que a paginação percorre (decisão do dono, §9 P1). O texto `libraryResultsSummary` (`app_pt.arb`/`app_en.arb`) diz hoje «de {total} louvores» e passa a «de {total} resultados» («of {total} results»).

**Código que muda por causa disso** (levantado na revisão):
- `library_screen.dart` (itera `results.items`, perto das linhas 203 e 276–285);
- `library_results_summary.dart`, `library_pagination_controls.dart` (só lê os campos de página);
- `home_search_results_sliver.dart`, `home_search_state.dart`, `home_search_provider.dart`;
- `paginate_louvor_groups.dart`, `paginated_louvor_groups.dart`, `library_providers.dart`.

Testes que leem `.items` e `.groups`: `test/unit/features/library/library_group_results_provider_test.dart`, `test/unit/features/catalog/home_search_state_test.dart` e `home_search_provider_test.dart`. Não há navegação por teclado nem «abrir o primeiro card» sobre essas listas.

### 4.4 Ordem fixa dentro do amendoim

Independe da ordenação da tela, então o amendoim de um grupo é igual na Home e na /biblioteca:
1. `numeroSortKey` crescente, com a mesma chave e a mesma regra de `SortLouvorGroups`: a chave é `-1` para quem não tem número, e esses vão por último, não primeiro;
2. empate: nome normalizado (sem acento, minúsculo);
3. empate: menos tags primeiro, para a versão-base (Coletânea) vir antes do arranjo (PES);
4. empate: `praiseId`.

Com os dados reais:
- «Clamo a ti»: Coletânea, depois GLTM · PES.
- 039: «Jesus, Tu és o meu Deus» (39), depois «(SCTB)», depois «(Solo)».
- «Pelo vale escuro»: 034, depois 307.

## 5. Etiqueta de cada gomo

Função pura `clusterMemberLabel(member, allMembers) → String?`, sobre `ColdigomPraiseMetadata.tagNames`.

A função **ordena as tags ela mesma**, por nome normalizado (sem acento, minúsculo). A ordem que chega não serve: o dump manda `ORDER BY label`, e a busca remota manda `GROUP_CONCAT(DISTINCT …)`, cuja ordem é indefinida. Sem ordenar aqui, o mesmo membro teria etiquetas diferentes na Home e na /biblioteca.
1. `comuns` são as tags que **todos** os membros têm.
2. `próprias` são as tags do membro menos as `comuns`, em ordem alfabética. Se houver alguma, a etiqueta é `próprias.join(' · ')`.
3. Se não houver, a etiqueta é a primeira tag do membro **em ordem alfabética**, cortada antes do primeiro `' · '` («Coletânea · Clamor» vira «Coletânea»).
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
| Pelo vale escuro | (034) Avulsos, PES, Migrados | Avulsos · Migrados · PES |
| | (307) Coletânea · Consolo e Encorajamento | Coletânea · Consolo e Encorajamento (cortada com «…» na tela) |

## 6. Desenho

### 6.1 `PeanutLobeBorder` (ShapeBorder)

Desenha **um gomo**, conforme `LobePosition { first, middle, last }`. Os gomos empilhados sem espaço formam o amendoim.

Geometria, para um gomo de largura `w` e altura `h`. A altura vem do conteúdo, como no chip de hoje, e um gomo com trecho de letra é mais alto.
- **Ponta de pílula** (topo do `first`, base do `last`): raio `R = 24`, o mesmo do chip solto. `_modalChipRadius` (`carousel_louvor_chip.dart`) vira público como `carouselChipModalRadius`, para a borda usar o mesmo valor.
- **Meia-junta de coração** (base do `first`, topo e base do `middle`, topo do `last`):
  - o bico fica **recuado `d = 10`** da lateral, na linha da junta;
  - o arco vai do bico até a lateral, a uma distância vertical `a = min(26, h − R)` da junta, no `first` e no `last`;
  - no `middle` a distância é `a = min(26, h / 2)`;
  - o arco é convexo, de raio `r′ = (d² + a²) / (2d)` (38,8 para `a = 26`), com centro em `(w − r′, y_junta ∓ a)` à direita e espelhado à esquerda;
  - o trecho que sobra da lateral é reto.
- **Contorno**: dourado `AppColors.gold`, 2 px, só nas laterais e nas pontas.
- **Costura**: a linha da junta fica **sem contorno cheio**, só com a costura dourada a 60 % de opacidade e 1 px, de bico a bico. Quem desenha a costura é o gomo de baixo (topo de `middle` e de `last`), para não pintar duas vezes.
- **Preenchimento**: `AppColors.title` (`#6A2F2F`).
- **`dimensions`**: `EdgeInsets.all(2)`, igual ao `Border.all(2)` de hoje. O `Container` soma isso ao padding, e com zero o gomo ficaria 4 px mais baixo que o chip solto, com o conteúdo deslocado.

**Ripple:** continua no `InkWell` de `ChipBody`, que é interno (recuado pelo padding), então não vaza pelo bico. No gomo, `ChipBody` recebe um `borderRadius` por lado: 24 do lado da pílula e 12 do lado da junta.

### 6.2 `CarouselLouvorChip`: parâmetros novos (opcionais)

| Parâmetro | Efeito | Padrão |
|---|---|---|
| `LobePosition? lobePosition` | Troca a pílula pela `PeanutLobeBorder` (`ShapeDecoration`). Sem sombra própria (quem desenha a sombra é o cluster). O padding passa a 20 px à esquerda e 12 px à direita, porque a curva da junta recua ~6 px na altura do «+». Só vale com a variante `modal` e sem setas de navegação (`assert`). | `null` = pílula de hoje |
| `String? groupLabel` | Etiqueta dourada à direita, antes do «+». Estilo próprio, o do mock: fundo `gold@0.14`, borda `gold@0.6` de 1 px, raio 8, texto `goldLight` OpenSans w600 10, máximo de 128 px com «…». A largura dela (medida com `TextPainter`, limitada a 128 + padding) é **reservada antes** do breakpoint de `ChipMetadataRow`, como já é feito com o selo «novo» (`_newChipReserve`), para a linha de ícones não estourar no celular. | `null` |
| `bool dimmed` | Esmaece **só o conteúdo** (o `constrainedBody` e os botões) com `Opacity(0.45)`. O fundo e o contorno ficam inteiros. O toque continua ativo. | `false` |

Nada mais no chip muda.

### 6.3 `LouvorClusterCard`

- Recebe um `ClusterEntry` e o conjunto de ids «novos» (`newGroupIds` na Home; vazio na /biblioteca).
- Empilha um `LouvorGroupCard`-gomo por membro, com `lobePosition`, `groupLabel` (§5), `dimmed = !matched` e `isNew` do próprio membro, **sem espaço** entre eles.
  - Cada gomo tem chave `ValueKey(praiseId)`, porque o card tem estado.
- **Sombra:**
  - O conjunto é montado por um `RenderBox` próprio (um `MultiChildRenderObjectWidget` em coluna). Ele faz o layout dos gomos, soma a silhueta com as alturas medidas (o mesmo cálculo da `PeanutLobeBorder`) e pinta **uma** sombra `shadowMd` desse contorno antes dos filhos.
  - Nem um retângulo arredondado nem as sombras de cada gomo servem. O retângulo mostra uma cunha cinza dentro do bico de 10 px, e as sombras por gomo sangram ~2 px no gomo de cima.
- **Espaçamento:**
  - `LouvorGroupCard` hoje sempre se envolve em `Padding(bottom: 8)`, e passa a só fazer isso quando `lobePosition` é `null` ou `last`.
  - A /biblioteca, que soma mais 8 px por item, conta o cluster como um item só.
- `LouvorGroupCard` ganha os mesmos três parâmetros e os repassa ao chip. O resto dele (toque, «+», offline, download) continua por gomo.

## 7. Testes

**coldigom** (`api`, vitest):
- o dump manda `groupId` quando existe e omite quando é `null`;
- o ETag muda quando um `group_id` muda.

**coldigui — unidade:**
- DTOs leem `groupId`/`group_id`, e o vazio vira `null`;
- mapper: os cinco caminhos de §3.2 levam `groupId`, e o adapter põe o valor na metadata;
- sync (§3.4):
  - versão de esquema ausente ou menor que a atual → pede **sem** `If-None-Match`;
  - igual → usa o ETag;
  - `markReplaced` grava a versão;
- índice: `membersOf` na ordem de §4.4, **inclusive com 1 membro**;
- `clusterCatalogList`:
  - posição do membro mais bem colocado;
  - grupo completo com `matched` certo;
  - grupo sem membro que casou fica de fora;
  - aparições seguintes puladas;
  - membro só no índice + membro só remoto formam o grupo;
  - membro presente nos dois lados **não se repete**;
- paginação: cluster conta 1 e não se parte;
- `clusterMemberLabel`: a tabela de §5, inclusive com as tags chegando em ordem diferente;
- os testes existentes que leem `.items`/`.groups` são atualizados (§4.3).

**coldigui — widget:**
- `LouvorClusterCard` desenha N gomos;
- tocar no gomo *k* abre o praise *k*;
- `dimmed` baixa a opacidade do conteúdo e não a do fundo;
- `isNew` aparece só no gomo certo;
- `PeanutLobeBorder`:
  - põe o bico a `d = 10`;
  - `dimensions` é 2 px, e um gomo tem a mesma altura do chip solto com o mesmo conteúdo;
  - um gomo mais alto (com trecho de letra) ganha trecho reto na lateral sem deformar o bico.

**Conferência visual** (dono): o app rodando contra a API já com `groupId`, olhando «Clamo a ti», o 039 e «Pelo vale escuro» na Home e na /biblioteca.

## 8. Entrega

As duas etapas são independentes:
1. **API** (`coldigom`): PR `feat/catalogo-group-id` → `develop` → `main`; o merge em `main` dispara `Deploy API to Workers`. Pode ir antes do app: as versões antigas ignoram o campo, e a trava de §3.4 garante que o app novo baixa o dump inteiro uma vez, mesmo que a versão antiga já tenha guardado o ETag do dump com `groupId`.
2. **App** (`coldigui`): `feat/louvores-agrupados`, com merge em `web/integration` como os demais trabalhos do app. Sem `groupId` no dump, a junção não acha grupos e a lista fica como hoje. Nesse caso, o primeiro sync baixa o dump inteiro por causa da versão de esquema, e depois volta ao 304.

## 9. Pontos confirmados na revisão

- **P1 — resumo da /biblioteca (decidido pelo dono, 2026-09-25).** Em «Mostrando 1–10 de N», N conta **cartões** (entradas), e o grupo conta 1. É o que a paginação percorre. Na Home, o «N novos» continua contando louvores.

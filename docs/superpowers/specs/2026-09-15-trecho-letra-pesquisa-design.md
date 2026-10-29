# Trecho da letra em dourado — resultados de pesquisa que batem na letra

**Data:** 2026-09-15
**Estado:** implementado — 2026-09-15 (código pronto nos dois repos; falta só o deploy manual do `coldigom-api` e os commits manuais do `coldigom/api`, item 7 abaixo)
**Escopo:** quando a pesquisa da Home bate no louvor pela letra (não pelo título/número), o card do resultado passa a mostrar uma linha com o trecho da letra que deu match, com a parte casada em dourado — mesmo padrão já usado no destaque do título.
**Repos:** `coldigom/api` (novo campo `lyrics_excerpt` em `GET /api/plpcg/praises`) **e** `coldigui` (consumo do campo + UI do card).
**Mockup:** https://claude.ai/artifact/3aS8nemGrbzjkDJPh1Aa1o (opção A escolhida pelo usuário).

## 1. Problema

A Home dispara duas buscas em paralelo por tecla: uma local (só título/número do PLPCG, `LouvorSearchTokens.matchesText`) e uma remota contra `GET /api/plpcg/praises?q=` no Worker `coldigom-api`. O servidor já compara `q` contra a letra (`p.lyrics`, com índice FTS5 `praises_fts` e fallback `LIKE`) — por isso um louvor cuja letra bate aparece na lista mesmo sem bater no título. Só que a query de listagem (`api/src/plpcgPraises.ts`) nunca seleciona `p.lyrics`, então o client não recebe nada para mostrar: o card aparece, mas nada indica *por quê* ele apareceu.

## 2. Decisões (fechadas)

| # | Decisão |
|---|---|
| D1 | **Layout: opção A do mockup** — uma linha simples entre o título e a linha de metadados, itálico, cor muted, trecho casado em dourado (`AppColors.gold`), reaproveitando o widget `HighlightedText` já usado no título. Sem ícone, sem fundo, sem borda extra. |
| D2 | **Trecho calculado no servidor** (`coldigom/api`), não baixando `.chord` no client. O client só recebe uma string curta já pronta pra exibir. |
| D3 | **Uma linha só.** Quebras de linha da letra viram espaço; o trecho é truncado a ~120 caracteres em bordas de palavra (~55 de cada lado do match), com "…" quando corta no meio. |
| D4 | **Só busca textual.** Buscas puramente numéricas (`parseNumericSearch`) ou link de YouTube (`extractYouTubeVideoId`) nunca calculam/retornam trecho — não fazem sentido como "match na letra". |
| D5 | **Campo aditivo e sempre presente quando aplicável**: `lyrics_excerpt: string | null` em cada item de `GET /api/plpcg/praises` — `null` quando não há match na letra ou a busca não é textual. Não quebra outros consumidores do endpoint (web admin) — campo desconhecido é ignorado. |
| D6 | **Sem novo campo em `Louvor`/`CarouselItem`.** O trecho viaja pelo canal que já existe para dados extras do Coldigom: `ColdigomPraiseMetadata` (hoje usada pelo sheet de materiais) ganha o campo e chega ao card via `LouvorGroup.coldigomMeta`. |
| D7 | **Exibido sempre que presente**, mesmo se o título também bateu (ex.: termo comum aparece nos dois) — sem lógica de "só quando o título não bateu". Mantém o card simples e previsível: o campo só volta populado quando é útil de qualquer forma. |
| D8 | **Sem novo endpoint.** O trecho entra na resposta que a Home já consome — nenhuma chamada de rede extra no client. |

## 3. Backend — `coldigom/api`

### 3.1 Novo helper puro `api/src/lyricsExcerpt.ts`

```ts
export function buildLyricsExcerpt(lyrics: string, rawQuery: string): string | null
```

- Normaliza `lyrics` e `rawQuery` (NFD unicode, remove marcas diacríticas, minúsculas) mantendo um mapa de índice normalizado → índice original (a remoção de acento muda o comprimento da string).
- Tenta achar a frase completa normalizada primeiro; sem match, tenta o primeiro token (mesma tokenização de `buildFtsMatchQuery` em `praiseQuery.ts`: remove pontuação, separa por espaço).
- Sem nenhum match → `null`.
- Com match, expande a partir dos índices originais até a borda de palavra mais próxima (~55 caracteres de cada lado, teto de ~120 no total), troca `\n`/`\t`/espaços repetidos por um espaço só, e prefixa/sufixa com "…" quando o corte não coincide com início/fim da letra.

Função pura, sem I/O — testável isolada, no padrão de `escapeLikePattern`/`buildFtsMatchQuery` já existentes em `praiseQuery.ts`.

### 3.2 `listPlpcgPraises` (`api/src/plpcgPraises.ts`)

Depois de obter `rows` (que já tem `has_lyrics`):

1. `isTextSearch = Boolean(query.search) && !parseNumericSearch(query.search) && !extractYouTubeVideoId(query.search)`.
2. Se `isTextSearch`, ids candidatos = `rows.filter(r => r.has_lyrics === 1).map(r => r.id)` (no máximo `limit` linhas — 20 por padrão).
3. Se houver candidatos: `SELECT id, lyrics FROM praises WHERE id IN (...)` (query extra pequena, indexada por PK, só quando necessário).
4. `excerptByPraiseId = new Map(...)` via `buildLyricsExcerpt(lyrics, query.search)`.
5. No `data.map(...)` final, cada item ganha `lyrics_excerpt: excerptByPraiseId.get(row.id) ?? null`.
6. Sem busca, busca numérica ou YouTube → `lyrics_excerpt: null` em todas as linhas, sem query extra nenhuma.

Isso contorna de vez a dualidade FTS/LIKE do `buildWhereClause`: o trecho é calculado direto sobre o texto da letra, independente de qual caminho (FTS ou fallback) achou a linha na busca.

### 3.3 Tipo de retorno

`listPlpcgPraises` passa a devolver `Array<Omit<ListRow, 'has_lyrics'> & { materials: SlimMaterial[]; lyrics_excerpt: string | null }>`.

## 4. Client — `coldigui`

Cadeia completa, sem tocar `Louvor`/`CarouselItem`:

1. **`lib/features/coldigom/data/models/praise_dto.dart`** — `PraiseDetailDto` ganha `final String? lyricsExcerpt;`, parseado de `json['lyrics_excerpt'] as String?` (chave ausente ou `null` → `null`, sem lançar).
2. **`lib/features/coldigom/data/adapters/coldigom_louvor_adapter.dart`** — `toMetadata(praise)` passa `lyricsExcerpt: praise.lyricsExcerpt` para `ColdigomPraiseMetadata`.
3. **`lib/features/coldigom/domain/entities/coldigom_praise_metadata.dart`** — `ColdigomPraiseMetadata` ganha `final String? lyricsExcerpt;` (default `null`).
4. Sem mudança em `LouvorGroup`/`LouvorGroup.fromLouvores` — `coldigomMeta` já carrega o objeto inteiro.
5. **`lib/features/catalog/presentation/widgets/louvor_group_card.dart`** — em `build()`, `final lyricsSnippet = widget.group.coldigomMeta?.lyricsExcerpt;`, passado como novo parâmetro `lyricsSnippet` para `CarouselLouvorChip`.
6. **`lib/features/carousel/presentation/widgets/carousel_louvor_chip.dart`** — novo parâmetro `final String? lyricsSnippet;` (doc curto, ao lado de `highlightQuery`). No `build()`, entre o `HighlightedText` do título e o `ChipMetadataRow`, quando `lyricsSnippet != null && lyricsSnippet!.trim().isNotEmpty`:

```dart
Padding(
  padding: const EdgeInsets.only(top: 2),
  child: HighlightedText(
    text: lyricsSnippet!,
    query: highlightQuery ?? '',
    style: AppTypography.body.copyWith(
      fontStyle: FontStyle.italic,
      fontSize: width < _compactWidth ? 11 : 12.5,
      color: AppColors.textLight.withValues(alpha: 0.64),
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  ),
),
```

`AppTypography.body` é a base (existe `AppTypography.hint({bool italic})` com o mesmo espírito itálico/muted, mas fixa `AppColors.title` — cor certa para superfície creme, errada para o chip escuro do resultado — por isso parte de `body` e sobrescreve `color` com `AppColors.textLight` em vez de reusar `hint()` diretamente).

7. **Comentário desatualizado**: `lib/features/coldigom/data/datasources/coldigom_remote_datasource.dart:94-96` hoje diz *"a resposta não inclui o texto da letra"* — atualizar para descrever `lyrics_excerpt`.

## 5. Fora do escopo

- Busca local PLPCG (sem `coldigom`) — não tem letra indexada no client, não ganha trecho.
- Opções visuais B–E do mockup.
- Múltiplos trechos por louvor (só o primeiro match).
- Alterar o algoritmo de ranking dos resultados (`buildOrderClause`) — só a exibição do trecho.
- Cache/offline do `lyrics_excerpt` — é um campo de busca ao vivo, não precisa sobreviver offline.

## 6. Testes

**Worker (`coldigom/api`, `node --test` ou runner já usado no repo):**
- `lyricsExcerpt.test.ts` (novo): match com acento (busca sem acento acha letra com acento e vice-versa), corte em borda de palavra, "…" só quando corta de verdade, teto de tamanho, múltiplos tokens, sem match → `null`, query vazia → `null`.
- Estender/`plpcgPraisesLyricsExcerpt.test.ts` (novo, seguindo o padrão de `praisesQueryParams.test.ts`): busca textual com match só na letra → `lyrics_excerpt` presente; busca que bate só no título → ainda testar (pode ou não ter letra, conferir os dois casos); busca numérica → `lyrics_excerpt: null` em todas as linhas mesmo com `has_lyrics=1`; sem `q` → `null` em todas, sem query extra ao `db.prepare` (checar contagem de chamadas, como já se faz em `praiseListResilience.test.ts`).

**Flutter (`coldigui`):**
- `praise_dto_test.dart` — `lyricsExcerpt` parseado quando presente, `null` quando ausente/`null` no JSON.
- `coldigom_louvor_adapter_test.dart` (existente) — `toMetadata` propaga `lyricsExcerpt`.
- Widget test de `CarouselLouvorChip` — com `lyricsSnippet` não nulo, a linha aparece com o trecho destacado em dourado quando `highlightQuery` bate nele; com `lyricsSnippet` nulo/vazio, a linha não existe (sem espaço extra no card); trecho maior que a largura trunca com reticências, uma linha só.
- Widget test de `LouvorGroupCard` — `coldigomMeta?.lyricsExcerpt` chega até o chip como `lyricsSnippet`.

**Manual:** rodar `coldigom/api` local (migração + seed já existentes), buscar na Home por um trecho presente só na letra de um louvor Coldigom conhecido, conferir a linha dourada; buscar por título continua sem a linha (quando a letra não repete o termo).

## 7. Entrega

- Dois repos, duas entregas separadas — a do `coldigom/api` precisa ir ao ar (deploy do Worker `coldigom-api.jairofilho79.workers.dev`) antes de a mudança no `coldigui` fazer efeito visível (o campo simplesmente vem `null`/ausente até lá, então a ordem não quebra nada).
- `coldigui`: branch a partir de `web/integration`, worktree `.claude/worktrees/lyric-search-snippet` (já criado).
- `coldigom/api`: branch própria no repo `dev/coldigom` (fora deste worktree) — plano de implementação cobre os dois.

## 8. Riscos e mitigações

| Risco | Mitigação |
|---|---|
| FTS5 encontrou a linha por um caminho que o buscador de trecho (substring simples) não reproduz (ex. stemming) | `buildLyricsExcerpt` devolve `null` nesse caso — card aparece sem trecho, como hoje. Degrada graciosamente, não quebra. |
| Letra muito longa deixa a query `SELECT id, lyrics FROM praises WHERE id IN (...)` pesada | Limitada às linhas da página atual (`limit`, 20 por padrão) e só quando `has_lyrics=1` — no pior caso 20 letras por busca. |
| Trecho cai no meio de uma palavra feia (ex. divide sílaba) | Expansão sempre para a borda de espaço mais próxima, nunca corta no meio de uma palavra. |
| Cliente antigo (versão do app antes desta mudança) recebe `lyrics_excerpt` e ignora | Campo aditivo, sem risco — `PraiseDetailDto.fromJson` de versões antigas simplesmente não lê a chave nova. |

## 9. Ajuste pós-revisão final (2026-09-15)

A revisão final de branch (subagent-driven-development) encontrou que o fallback original de `buildLyricsExcerpt` — cair para o primeiro token quando a frase completa não aparece contígua na letra — devolvia um trecho que o client quase nunca conseguia destacar em dourado (o `HighlightedText` do client só casa substring contíguo da busca inteira, não por token). **Ruling:** o fallback foi removido — `buildLyricsExcerpt` só devolve um trecho quando a frase completa é encontrada contígua; caso contrário devolve `null` (mesmo resultado gracioso já previsto na tabela de riscos acima). Busca de uma palavra só não é afetada. Um teste widget cobrindo `highlightQuery` + `lyricsSnippet` juntos (dourado parcial, uma linha) foi adicionado como guarda de regressão. O algoritmo de truncamento (`extractWindow`) também foi corrigido para orçar o contexto ao redor do match em vez de um corte cego no fim, evitando cortar palavra ou o próprio match.

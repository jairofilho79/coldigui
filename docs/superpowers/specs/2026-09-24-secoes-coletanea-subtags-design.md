# Seções da Coletânea viram subtags — aposentar `praise.category`

**Data:** 2026-09-24
**Estado:** design aprovado em conversa; spec aguardando revisão.
**Repos:**
- `coldigom`: `api/`, `web/` e `scripts/validate-acervo`;
- `coldigui`: o app Flutter.

**Branches (a criar):** `feat/secoes-coletanea-subtags` nos dois repos. No coldigom sai de `origin/main` @ `e614d43`; no coldigui, de `web/integration`.

## 0. Objetivo e limites

O filtro «Categoria» do app mistura quatro coisas diferentes no mesmo campo de texto livre (`praises.category`):
- as **seções temáticas da Coletânea**;
- a **coleção** (Avulso, Avulsos…);
- uma **posição na página** (Contra-Capa);
- **grafias diferentes** da mesma seção.

A seção da Coletânea passa a ser o que já é no modelo do coldigom: uma **subtag da tag raiz `Coletânea`**. O rótulo sai como `Coletânea · Clamor`. O campo `category` é **aposentado**.

**Não entra (decidido):**
- **Apagar a coluna `praises.category`.** Ela é esvaziada na fase 3 (§6) e continua no schema. O `DROP COLUMN` (depois do índice `idx_praises_category`) fica para outra entrega.
- **Reestruturar a tag GLTM.** O único efeito aqui é a subtag `Avulsos · GLTM` para um louvor (§2.3). A raiz `GLTM` continua como está.
- **O plpcjf e o plpcg-admin.** Nenhum dos dois consome o `category` do coldigom (levantamento de 2026-09-24).
- **Os scripts `cifras-agent` (`category_vocabulary`) e `pdf-to-chordpro` (`CATEGORY_NOISE`).** Eles leem `metadata.yml` locais ou uma regex fixa, e continuam funcionando. Adaptá-los às subtags é follow-up (§9).

## 1. Fatos medidos (2026-09-24, `/api/plpcg/catalog` de produção)

| # | Fato | Consequência |
|---|---|---|
| F1 | São 2044 praises. `category` preenchido em 1169 deles e vazio em 875. | — |
| F2 | Valores de seção:<br>• Clamor 76, Consolo e Encorajamento 97, Contra-Capa 1, Corinhos 56, Crianças e Adolescentes 240, Dedicação 112, Grupo de Louvor 96, Invocação e Comunhão 39, Louvor 85, Salmos de Louvor 20, Volta de Jesus e Eternidade 93;<br>• «Morte, Ressureição e Salvação» 90 e «Morte, Ressurreição e Salvação» 6;<br>• «Santificação e Derramamento» 98 e «…do Espírito Santo» 7.<br>Ao todo, **1116**. | Viram 13 subtags (§2.1). |
| F3 | Valores de coleção: Avulso 19, Avulsos 31, Avulso Cias 2, Avulsos das Senhoras 1. | Não viram tag (§2.2). |
| F4 | 1119 praises têm a tag raiz `Coletânea`.<br>• 1112 deles têm seção.<br>• **7 não têm seção**; recebem seção manual (§2.3).<br>• **4 têm seção mas não têm a tag `Coletânea`**; entram na Coletânea pela subtag. | Depois da migração, **nenhum** praise fica ligado direto à raiz `Coletânea`. |
| F5 | O coldigom tem hierarquia de tags de um nível: `tags.parent_id` (migration 010) e o rótulo `pai · filho` (`TAG_LABEL_SQL`, `api/src/praiseQuery.ts:32`). Nome de tag **não pode ter vírgula** (`routes/tags.ts`). | O nome «Morte Ressurreição e Salvação» vai sem separador. |
| F6 | `resolveTagFilterGroups` (`api/src/praiseQuery.ts:41-63`) troca uma tag pai **só pelos filhos**.<br>**Bug já presente em produção:** filtrar por `PES` na API ou no admin traz só os 8 praises de `PES · 9.2026` e ignora os ~237 ligados à raiz. Filtrar por `Diversos` traz 1. | Corrigido em §3.1. |
| F7 | A API recusa ligar um praise a uma tag que tem filhos: «Cannot attach a parent tag; use a subtag» (`routes/praises.ts` no POST de criação, `:678-680` e no merge `:840-848`). | A trava sai (§3.2). Sem isso, `Avulsos` deixaria de poder ser marcada. |
| F8 | No app, `catalogTagMatches` (`lib/features/catalog/domain/utils/catalog_tag_hierarchy.dart`) já casa o pai **e** os filhos. As tags já aparecem na ficha do material e entram nos tokens de busca. A categoria **não** entra nos tokens. | Com as subtags, a seção passa a ser encontrável pela busca local sem mudar código. |
| F9 | A URL dos filtros do app guarda cada filtro como CSV de **nomes** (`CatalogFilterState.parseCsv`). O filtro salvo em prefs guarda `categories` (`persistedVersion = 2`). | Links e filtros salvos com `category` precisam de conversão (§4.2). |

## 2. Dados — mapeamento

### 2.1 As 13 subtags de `Coletânea`

| Subtag | Origem (`category`) | Praises depois |
|---|---|---|
| Clamor | Clamor + 2 manuais | 78 |
| Consolo e Encorajamento | idem | 97 |
| Contra-Capa | idem | 1 |
| Corinhos | idem | 56 |
| Crianças e Adolescentes | idem + 1 manual | 241 |
| Dedicação | idem + 1 manual | 113 |
| Grupo de Louvor | idem | 96 |
| Invocação e Comunhão | idem | 39 |
| Louvor | idem | 85 |
| Morte Ressurreição e Salvação | «Morte, Ressureição e Salvação» + «Morte, Ressurreição e Salvação» | 96 |
| Salmos de Louvor | idem | 20 |
| Santificação e Derramamento do Espírito Santo | «Santificação e Derramamento» + «…do Espírito Santo» | 105 |
| Volta de Jesus e Eternidade | idem + 3 manuais | 96 |
| **Total** | | **1123** |

**A regra vale para todo praise com seção, quaisquer que sejam as outras tags.**
- Os 66 que têm `Avulsos` + `Coletânea` + seção ganham a subtag e mantêm `Avulsos`.
- Os 4 com seção e sem `Coletânea` também ganham a subtag e, com ela, entram na Coletânea:
  - «Alvo Mais Que a Neve»
  - 060 «Tudo está pronto»
  - 255 «Meu Coração Engrandece - ARR OPCIONAL»
  - 609 «Senhor, Meu Deus, Quando Eu Maravilhado (Adaptação TEF 2024)»

Para cada praise que ganha subtag, a ligação direta com a raiz `Coletânea` é removida, se existir. As outras tags não mudam.

### 2.2 Valores de coleção

**Avulso, Avulsos e Avulso Cias** não geram tag nem mudam as tags do praise. As tags `Avulsos`, `PES`, `CIAs` e `GLTM` já cobrem essa informação. O valor some na fase 3.

### 2.3 Casos manuais (por `praise.id`, aprovados pelo dono em 2026-09-24)

| id | shortId | Nº | Louvor | Tags hoje | Recebe |
|---|---|---|---|---|---|
| `90ad7fd8-46d5-4121-a071-96b4fee42196` | 3b4 | 046 | Ao Sentir o teu Perdão | Coletânea | Coletânea · Clamor |
| `b43a21e7-3c12-4a96-b298-e2bd908db2d9` | 488 | 046 | Ao Sentir o teu Perdão | Coletânea, PES | Coletânea · Clamor |
| `3c366df7-52c9-4d64-9ffb-03e6d4699e3e` | 186 | 047 | Tenho no meu coração | CIAs, Coletânea | Coletânea · Crianças e Adolescentes |
| `ffcb930d-b34d-4236-a389-3c7b0e198567` | 679 | 99 | Um dia Jesus achou - me | Avulsos, Coletânea | Coletânea · Dedicação |
| `1f468959-3e72-4000-bd54-1b9c682882db` | 806 | 505 | Os seus cabelos brancos | Coletânea | Coletânea · Volta de Jesus e Eternidade |
| `70845455-7bb1-455a-990b-c6082b75261f` | 807 | 506 | Tu Que Estás Assentado | Coletânea | Coletânea · Volta de Jesus e Eternidade |
| `bbd5f528-1622-4346-a3d7-898223f7292b` | 68b | 566 | O Senhor é meu Pastor (Maranata, Jesus vem) | Avulsos, Coletânea, Diversos · weider | Coletânea · Volta de Jesus e Eternidade |
| `2b309bf1-50a0-48fc-8607-8ccce0031500` | 11e | — | Tu és Maravilhoso (`category` = Avulsos das Senhoras) | GLTM | **Avulsos · GLTM**, subtag nova. Mantém a raiz `GLTM`. |

«Avulsos das Senhoras» não gera tag. Esse praise ganha a subtag `Avulsos · GLTM` por decisão explícita, não por mapeamento do valor.

## 3. coldigom — API

### 3.1 Resolver de tags

`resolveTagFilterGroups` passa a devolver `[id, ...filhos]` em vez de `filhos ?? [id]`. Filtrar pelo pai traz os praises ligados ao pai e aos filhos, a mesma semântica de `catalogTagMatches` no app. Isso corrige F6 para PES, Diversos e, depois de §2.3, para Avulsos.

### 3.2 Fim da trava «parent tag»

Ligar um praise a uma tag raiz passa a ser permitido **mesmo que ela tenha filhos**. Isso vale para:
- `POST /api/praises` (criação);
- `POST /api/praises/:id/tags`;
- o merge (`POST /api/praises/:keeperId/merge`).

A raiz ligada diretamente significa «sem subtag específica». Os testes que verificam a recusa passam a verificar a aceitação.

### 3.3 Merge

`metadata.category` deixa de ser obrigatório em `POST /api/praises/:keeperId/merge`. Hoje a falta da chave dá 400 (`routes/praises.ts:779`); passa a significar «não mexe na categoria». O admin para de enviar a chave (§3.5).

### 3.4 O que continua igual até a fase 3

- **Contribuições:** `METADATA_FIELDS` mantém `'category'` (`api/src/contributions/schema.ts:17`), para que versões antigas do app não recebam 400.
- **`GET /api/praises/filters`:** continua devolvendo a chave `categories`, que fica vazia depois da fase 3.
- **Catálogo e listas:** `/api/plpcg/catalog`, `/api/praises`, `/api/praises/:id` e `/api/plpcg/praises` continuam emitindo `category`, com `''` ou `null` depois da fase 3.
- **Parâmetro `sort=category` e busca LIKE por category:** continuam aceitos. Depois da fase 3 não têm efeito.

### 3.5 Admin web (`web/src`)

Saem:
- em `PraiseDetailPage`: o campo «Categoria» (edição e criação, `:1411-1412`), a exibição (`:1482-1485`) e o estado de edição;
- em `PraiseMergeImportPage`: a linha «Categoria» de `META_FIELDS`. O merge para de enviar `metadata.category`;
- em `FilterBar`, `useFilters` e `HomePage`: o dropdown «Categoria», o parâmetro `?category=` e o chip;
- a opção «Categoria (A-Z)» de `SORT_OPTIONS`;
- a exibição da categoria em `FindingEvidence`.

Muda: `tagSelectOptions` (`PraiseDetailPage.tsx:859`) passa a incluir as tags raiz com filhos (§3.2).

A criação de subtag (`criarEAssociarSubtag`) já existe e não muda.

## 4. coldigui — app

### 4.1 Sai

- a seção **Categoria** dos filtros (`catalog_filter_sections.dart`), `CatalogFilterOptions.categories`, `CatalogFilterState.categories`, `toggleCategory` e o critério em `matches_catalog_filters.dart`;
- a linha «Categoria» da ficha do material (`material_sheet.dart`, `_ColdigomMetaBlock`);
- `MetadataField.category` nas contribuições (o dropdown de `contribution_context_fields.dart`). Contribuições antigas com `field: category` continuam sem aparecer na tela de detalhe, como já acontece com campos desconhecidos;
- as chaves l10n `coldigomFilterCategory`, `coldigomMetaCategory` e `contributeMetadataCategory` (pt e en; `flutter gen-l10n` e commit dos arquivos gerados).

**Fica até a fase 3:** `category` nos DTOs, em `ColdigomPraiseMetadata` e no cache Isar (`ColdigomPraiseCache.category`). Fica também o `categories` de `ColdigomPraisesQuery`, que não tem chamador em produção e sai junto.

### 4.2 Links e filtros salvos antigos

`CatalogFilterState.fromUrl(category: …)` e a leitura do JSON persistido (`'categories'`) **convertem** cada valor antigo numa tag e somam o resultado a `tags`:

| Valor antigo | Tag |
|---|---|
| as 11 seções de nome igual | `Coletânea · <nome>` |
| «Morte, Ressureição e Salvação», «Morte, Ressurreição e Salvação» | `Coletânea · Morte Ressurreição e Salvação` |
| «Santificação e Derramamento», «…do Espírito Santo» | `Coletânea · Santificação e Derramamento do Espírito Santo` |
| Avulso, Avulsos, Avulso Cias, Avulsos das Senhoras, qualquer outro | descartado |

Detalhes:
- **Vírgula na URL:** na URL, «Morte, Ressu…» chega partido pelo CSV em «Morte» e «Ressu… e Salvação». A conversão reconhece os dois pedaços e os junta na tag de Morte.
- **Gravação:** a URL deixa de gravar `category`, e o JSON persistido deixa de gravar `categories`. `persistedVersion` vai para 3, e a leitura das versões 2 e 3 continua aceitando `categories`.
- **A tabela é uma constante do app.** Ela só existe para ler dados antigos e não acompanha mudanças futuras de tags.

### 4.3 Sem mudança de código

- **Tags:** a seção Tags mostra só as raízes `Coletânea` e `Avulsos`; marcá-las revela as 13 subtags e `GLTM` na seção Subtags (rótulo do último nível, ex.: `Clamor`, `GLTM` — spec subtags sob demanda, d8dd304d). Na ficha do material continuam aparecendo com os ancestrais. Também entram na busca local.
- **Resync:** a migração muda o ETag do catálogo, e o app faz um resync completo (desejado).

## 5. Script de dados (`coldigom/scripts/validate-acervo`)

O script segue o padrão existente:
- snapshot do D1 em sqlite;
- simulação por padrão, gravação só com `--execute`;
- SQL em lotes (`core/d1.py`), executados com `wrangler d1 execute --remote`;
- registro em `apply_log.jsonl`, com `--undo <run_id>`.

Como ele se encaixa no `core/apply` (detector + apply ou comando próprio) fica para o plano decidir.

### 5.1 Passos

1. Snapshot fresco do D1 de produção.
2. **Travas.** O script aborta sem gravar nada se:
   - (a) aparecer em `category` um valor fora de §2.1 e §2.2;
   - (b) algum praise com a raiz `Coletânea` ficar sem subtag pelo mapeamento;
   - (c) algum id de §2.3 não existir, ou estiver com tags diferentes das da tabela.
3. Cria as subtags que faltam: as 13 de §2.1 sob `Coletânea` e `GLTM` sob `Avulsos`. Se uma subtag de mesmo nome já existir sob o mesmo pai, reaproveita.
4. Para cada praise: `INSERT` da ligação com a subtag e `DELETE` da ligação com a raiz `Coletânea`.
   - Os dois comandos só valem se o praise ainda estiver como no snapshot. O `INSERT` exige `category` igual ao valor lido; o `DELETE` exige que a ligação exista.
   - `Avulsos · GLTM` não remove a raiz `GLTM`.
5. **A categoria não é alterada.**
6. **Relatório do ensaio** para o dono revisar antes do `--execute`:
   - contagem por subtag, comparada com a coluna «Praises depois» de §2.1;
   - a lista de §2.3;
   - a lista dos 4 que entram na Coletânea;
   - o número de ligações diretas com `Coletânea` removidas (esperado: 1119).

### 5.2 Undo

O `--undo <run_id>` desfaz a execução:
- remove as ligações criadas e recria as ligações diretas removidas;
- apaga as subtags criadas **só se** ficarem sem ligações.

## 6. Entrega, ordem e validação

1. **Deploy da API do coldigom** (§3.1–3.3).
   - Independente dos outros passos.
   - Validação: filtrar por `PES` na API traz a união de `PES` e `PES · 9.2026`, não só os 8 da subtag.
2. **Script, ensaio.** O dono revisa o relatório (§5.1.6).
3. **Script, execução.** Validação em `/api/plpcg/catalog`:
   - contagens da tabela de §2.1;
   - 0 praises com o rótulo `Coletânea` sozinho;
   - `Tu és Maravilhoso` com `Avulsos · GLTM` e `GLTM`.

   Até o passo 4, apps antigos mostram a seção Categoria **e** as subtags. É aceitável.
4. **Deploy do admin web (§3.5) e do app (§4).**
   - O app segue o fluxo habitual: `web/integration`, depois produção v2, depois homologação.
   - Homologação:
     - a seção Categoria sumiu;
     - a seção Tags mostra só `Coletânea`; marcá-la revela as 13 seções na seção Subtags (rótulo do último nível, ex.: `Clamor`) e traz as 1123;
     - um link antigo `?category=Clamor` abre filtrado por `Coletânea · Clamor`;
     - a busca «Clamor» encontra louvores da seção.
5. **Fase 3, depois da homologação do passo 4.**
   - Um comando do mesmo script, também com ensaio e `--execute`, faz `UPDATE praises SET category = NULL WHERE category IS NOT NULL`, guardando os valores no log para o undo.
   - No coldigom:
     - o ZIP deixa de escrever `praise_category` (`praiseZip.ts:110`);
     - o `ingest.ts` passa a ignorar `praise_category`.
   - No app:
     - `category` sai dos DTOs, de `ColdigomPraiseMetadata`, de `ColdigomPraisesQuery` e do cache Isar (`build_runner`);
     - as fixtures de teste perdem `..category = ''`.

## 7. Erros

| Situação | Comportamento |
|---|---|
| Valor de `category` desconhecido no snapshot | O script aborta e lista os praises com o valor. Ninguém adivinha o mapeamento. |
| Um praise mudou entre o snapshot e o `--execute` | A condição do lote não casa. O relatório final lista o que ficou para trás, e o dono roda de novo. |
| Subtag já existe sob o mesmo pai | É reaproveitada; o índice único `idx_tags_child_name` garante que não duplica. |
| Link antigo com categoria Avulso\* ou desconhecida | O valor é descartado em silêncio e o resto do filtro vale. |

## 8. Testes

- **coldigom `api/`:**
  - o resolver devolve pai e filhos: PES com uma subtag traz os praises da raiz e os da subtag;
  - a ligação com tag pai é aceita na criação, no `POST /tags` e no merge (os testes de recusa passam a testar aceitação);
  - o merge sem `metadata.category` é aceito e não mexe na categoria.
- **coldigom `web/`:** saem ou se adaptam os testes de FilterBar, useFilters, HomePage, PraiseDetailPage, PraiseMergeImportPage, FindingEvidence e api que tocam a categoria. `tagSelectOptions` passa a incluir raízes com filhos.
- **validate-acervo (pytest):**
  - mapeamento, incluindo as grafias e a regra «qualquer tag»;
  - as três travas de §5.1.2;
  - a condição de «praise inalterado»;
  - reaproveitamento de subtag existente;
  - o undo, inclusive não apagar uma subtag que ganhou ligações novas.
- **coldigui:**
  - a conversão de §4.2 (URL e prefs, incluindo os pedaços partidos pela vírgula);
  - `persistedVersion` 3;
  - a seção de filtros sem Categoria e a ficha sem Categoria;
  - o dropdown de contribuição sem Categoria;
  - atualização dos testes listados no levantamento (url builders, filters provider/state/options/matches, catalog_filter_sections, material_sheet, filters_url_sync_across_tabs, library_screen).

## 9. Follow-ups (fora desta entrega)

- `DROP COLUMN praises.category`, depois de apagar `idx_praises_category`. Junto, sair o `category` das respostas da API e do `METADATA_FIELDS` das contribuições.
- `cifras-agent/agent/acervo.py` `category_vocabulary()` passa a ler os rótulos `Coletânea · X` em vez de `praise_category`.
- `validate-acervo/core/plpcg_apply.py` `_tag_base` compara com o nome `Coletânea` e não reconhece a subtag. Isso importa só se esse script voltar a rodar.
- `/api/plpcg/manifest` passa a emitir `classificacao` com `Coletânea · X`. Não há consumidor conhecido.
- Ordenar os chips de seção pela ordem do livro, se o dono quiser.

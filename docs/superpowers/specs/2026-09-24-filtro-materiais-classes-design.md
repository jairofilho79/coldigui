# Filtro «Materiais» por classe e família

**Data:** 2026-09-24
**Estado:** design aprovado em conversa (partes 1–3); spec aguardando revisão.
**Mock aprovado:** https://claude.ai/artifact/3Vu8drWP5Gu2dq2NyDAo95, opção 6 «Seções + famílias».
**Repos:**
- `coldigom`: `api/` (migration e dump do catálogo);
- `coldigui`: o app Flutter.

**Branches (a criar):**
- `coldigom`: `feat/material-kind-classes`, a partir de `origin/main` (@ `e614d43` em 2026-09-24), num worktree próprio;
- `coldigui`: `feat/filtro-materiais-classes`, a partir de `web/integration`.

**Convive com:**
- as «subtags sob demanda» nos filtros (`d8dd304d`, já em `web/integration` e em produção), de onde vem a regra de seleção das famílias (F5);
- a spec das subtags da Coletânea (`2026-09-24-secoes-coletanea-subtags-design.md`, branch `feat/secoes-coletanea-subtags`), que também mexe em `catalog_filter_sections.dart` (§6).

## 0. Objetivo e limites

A seção «Materiais» dos filtros (Home e /biblioteca) mostra uns 95 chips soltos em ordem alfabética: MIDI, instrumentos, vozes e acompanhamento misturados. A entrega organiza essa seção e mantém o padrão visual de hoje (título + `Wrap` de `FilterChip`):
- **chips de Tipo** (PDF, Cifra, Áudio…) logo abaixo do título, com seleção múltipla, que escondem da lista os materiais sem arquivo daquele tipo;
- **classes** (Metais, Banda, Vozes…) como rótulos pequenos com um fio, cada uma com o seu `Wrap`;
- **famílias** recolhidas num chip só («Saxofone 4 ▾»), com a mesma regra das subtags que já está em produção: o pai inclui os filhos, e um filho marcado junto com o pai refina o pai.

**Não entra (decidido):**
- **Tela no admin** para editar classe, pai e ordem. Os dados vêm de migration; um kind novo aparece em «Outros» até alguém rodar SQL ou script.
- **`/api/materials/kinds`** e o filtro por material kind da API e do admin continuam como estão.
- **A tela «Materiais favoritos»**, as preferências de tipo por material e o plpcjf.
- **Chip de Tipo filtrando louvores.** O chip só organiza a lista de materiais (decisão do dono).
- **A seção «Tags».** Ela continua com as «subtags sob demanda» (`d8dd304d`). O chip de família fica só em Materiais (decisão do dono, 2026-09-24).

## 1. Fatos medidos (2026-09-24)

| # | Fato | Consequência |
|---|---|---|
| F1 | `material_kinds` tem só `id` e `name UNIQUE`. O rótulo pt-BR vem de `material_kind_translations` (`loadMaterialKindLabels`, `api/src/materialKindLabels.ts`). | A classe, o pai e a ordem entram como colunas novas. O rótulo de exibição continua sendo o traduzido. |
| F2 | O dump `GET /api/plpcg/catalog` já manda `kinds: [{id, name}]` (só os kinds com material), e o ETag é o hash de `{kinds, praises}` (`api/src/plpcgPraises.ts`). | Os campos novos vão em `kinds`. O ETag muda sozinho quando a classificação muda. |
| F3 | No app, `ColdigomCatalogDto.kindNames` lê `kinds` e desnormaliza o nome em cada material do cache Isar. As opções de filtro (`CatalogFilterOptions.fromGroups`) saem do índice local, a partir dos materiais. | A classificação precisa de um lugar próprio no cache, guardado na mesma sincronização. |
| F4 | O filtro guarda `materialKindIds` (ids, não rótulos). `_hasSelectedKind` (`matches_catalog_filters.dart`) casa só o id exato. | O casamento passa a expandir pai → filhos. |
| F5 | As tags já têm hierarquia no app (`lib/features/catalog/domain/utils/catalog_tag_hierarchy.dart`):<br>• `catalogTagMatches`: o pai casa os filhos;<br>• `catalogTagsRefined`: pai + filho selecionados vale pelo filho.<br>Com `d8dd304d` (decisão do dono), o filtro usa a seleção refinada, e `toggleTag` desmarca as subtags quando desmarca o pai. | A regra de família dos kinds copia essa: refinar em vez de trocar, e desmarcar o pai desmarca os filhos. |
| F6 | Produção tem **104** kinds (`GET /api/materials/kinds`); 102 deles têm material e vêm no dump. Os `type` dos materiais no dump são `pdf` 11501, `mp3` 6028, `chord` 2261, `youtube` 409, `gestures` 254, `midi` 120, `m4a` 3, `mpeg` 1 e `mid` 1. Migrations em `origin/main` vão até a `023`; a `022` já foi usada em outra branch. | O mapeamento (§2) cobre os 104 kinds. A migration provavelmente é a `024`; conferir antes de criar. |
| F7 | No coldigom, as tags têm um nível de hierarquia (migration `010`): FK `parent_id` com `ON DELETE RESTRICT` e o pai sempre raiz. O resolver da API exclui o pai quando há filhos (bug, corrigido na spec das subtags), e a trava «Cannot attach a parent tag» vai cair. | Copiar o modelo (um nível, pai raiz, RESTRICT) e **não** copiar o resolver com bug nem a trava. |

## 2. Dados — classificação

### 2.1 Classes

| `id` | Rótulo | `sort_order` |
|---|---|---|
| `regencia` | Regência e geral | 10 |
| `letra` | Letra e projeção | 20 |
| `vozes` | Vozes | 30 |
| `madeiras` | Madeiras | 40 |
| `metais` | Metais | 50 |
| `percussao` | Percussão | 60 |
| `banda` | Banda | 70 |
| `cordas` | Cordas | 80 |
| `audio` | Áudio e acompanhamento | 90 |
| `midi` | MIDI de ensaio | 100 |

Kind sem classe cai em **«Outros»**, que o app mostra depois da última classe. «Outros» não é uma linha da tabela.

### 2.2 Mapeamento dos kinds

A ordem da coluna «Kinds» é a `sort_order` dentro da classe (10, 20, 30…). É a ordem da grade orquestral, e não a alfabética. Dentro de uma família, **pai → filhos** estão entre colchetes; o filho herda a classe do pai.

| Classe | Kinds |
|---|---|
| Regência e geral | Partitura, Grade, Instrumental, Experiência |
| Letra e projeção | Letra, Slide, Gestos CIAs |
| Vozes | Coro, Primeira voz, Segunda voz, Voz cantada ¹, Voz mulheres ¹, Voz homens ¹, [Voz soprano → Voz soprano I, Voz soprano II] ¹, [Voz contralto → Voz contralto I, Voz contralto II] ¹, [Voz tenor → Voz tenor I, Voz tenor II] ¹, Voz barítono ¹, Voz baixo ¹ |
| Madeiras | Madeiras, Flautim, Flauta, Oboé, [Clarinete → Clarinete em Si bemol], Fagote |
| Metais | Metais, Harmonia, [Saxofone → Saxofone soprano, Saxofone alto, Saxofone tenor, Saxofone barítono], [Trompa → Trompa em Fá], [Trompete → Trompete em Si bemol], Corneta, Flugelhorn, Trombone, Eufônio, Tuba |
| Percussão | Percussão, Bateria, Bumbo, Caixa, [Prato → Prato suspenso], Tímpanos, Glockenspiel, Vibrafone, Sinos de orquestra |
| Banda | [Cifra → Cifra I, Cifra II], Violão, Teclado, Piano, Baixo elétrico, Base, Coro e piano |
| Cordas | Cordas, [Violino → Violino I, Violino II], Viola, Violoncelo ¹, Contrabaixo |
| Áudio e acompanhamento | [Áudio → Áudio (grupo), Áudio (solo)], Playback, Versão de ensaio |
| MIDI de ensaio | MIDI ¹, MIDI geral, MIDI grade ¹, MIDI coro, MIDI instrumentos, [MIDI voz → MIDI voz mulheres, MIDI voz homens], MIDI mulheres, MIDI homens, MIDI primeira voz, MIDI segunda voz, [MIDI soprano → MIDI soprano I, MIDI soprano II], [MIDI contralto → MIDI contralto I, MIDI contralto II], [MIDI tenor → MIDI tenor I, MIDI tenor II], MIDI barítono, [MIDI baixo → MIDI baixo I, MIDI baixo II] |
| — (Outros) | Desconhecido ¹ |

¹ **Proposta a conferir pelo dono.** São 18 kinds que ficaram fora do mock porque o print usado estava cortado depois de «Violino II» (a lista é alfabética). Dois deles, «Desconhecido» e «MIDI grade», não têm material e não aparecem no dump. Os outros 86 seguem o mock aprovado, com os ajustes do dono: Harmonia e Saxofone em Metais; Cifra, Base e Coro e piano em Banda.

Decisões do dono no mapeamento:
- «Coro» e «Coro e piano» **não** são família: Coro fica em Vozes e Coro e piano fica em Banda.
- Saxofone fica em Metais por decisão do dono, mesmo sendo madeira na orquestra.
- «MIDI» não é pai dos outros MIDI. A família tem um nível só, e «MIDI soprano» já é pai.

A migration grava por **id** de produção. O plano traz a tabela id → classe/pai/ordem, gerada a partir de `GET /api/materials/kinds` e conferida contra esta seção.

## 3. coldigom

### 3.1 Migration (`0NN_material_kind_classes.sql`; número conferido em `origin/main`)

```sql
CREATE TABLE material_kind_classes (
    id TEXT PRIMARY KEY,
    label TEXT NOT NULL,
    sort_order INTEGER NOT NULL UNIQUE
);

ALTER TABLE material_kinds ADD COLUMN class_id TEXT REFERENCES material_kind_classes(id) ON DELETE SET NULL;
ALTER TABLE material_kinds ADD COLUMN parent_id TEXT REFERENCES material_kinds(id) ON DELETE RESTRICT;
ALTER TABLE material_kinds ADD COLUMN sort_order INTEGER;
CREATE INDEX IF NOT EXISTS idx_material_kinds_parent_id ON material_kinds(parent_id);
```

Em seguida, os `INSERT` das 10 classes e um `UPDATE` por kind com `class_id`, `parent_id` e `sort_order` de §2.2. O `schema.sql` recebe as mesmas definições.

**Regras** (sem tela de edição, conferidas por consulta de verificação e por teste, §7):
- o pai é raiz: `parent.parent_id IS NULL`;
- pai e filho têm a mesma classe;
- um kind não é pai de si mesmo.

`ON DELETE RESTRICT` impede apagar um pai que ainda tem filhos, como nas tags.

### 3.2 Dump do catálogo (`GET /api/plpcg/catalog`)

`kinds` ganha três chaves, omitidas quando nulas (como `shortId`):

```json
{
  "kindClasses": [{ "id": "metais", "label": "Metais" }],
  "kinds": [
    { "id": "a3f9d722-…", "name": "Saxofone", "class": "metais", "order": 30 },
    { "id": "6d35011f-…", "name": "Saxofone alto", "class": "metais", "parent": "a3f9d722-…", "order": 50 }
  ]
}
```

- `kindClasses` vem na ordem de `sort_order` e traz só as classes usadas por algum kind do dump.
- O dump continua mandando só os kinds com material (F2). Um **pai sem material** que tenha filho com material entra em `kinds` mesmo assim, senão o app não monta a família.
- O ETag passa a cobrir `{kinds, kindClasses, praises}`.
- Apps antigos ignoram as chaves novas.

### 3.3 Fica igual

`GET /api/materials/kinds`, `GET /api/materials/kinds/:kindId/types`, as rotas de escrita de material (a validação de kind existente não muda) e o filtro por material kind em `/api/praises`.

## 4. coldigui — dados

### 4.1 Leitura e cache

- `ColdigomCatalogDto` lê `kindClasses` e, em cada kind, `class`, `parent` e `order`. Uma chave ausente vale como nula.
- A sincronização guarda uma **taxonomia de kinds**: a lista de classes e, por kind, a classe, o pai e a ordem. Ela é gravada no cache local na mesma sincronização do catálogo, e é lida offline.
- Um catálogo sem os campos novos (coldigom antigo) gera uma taxonomia vazia. A seção mostra tudo em «Outros», em ordem alfabética, como hoje.

### 4.2 Opções do filtro

`CatalogFilterOptions.materialKinds` passa a trazer, por kind: classe, pai, ordem e o **conjunto de tipos** encontrados nos materiais daquele kind no índice local.

Os tipos são os do app (`MaterialKind`, via `materialKindOfRawType`), e não o `type` cru do coldigom. Os materiais `midi`, `mid`, `m4a` e `mpeg` viram `MaterialKind.unknown` e já são descartados pelo `ColdigomLouvorAdapter`: não entram no índice nem no filtro, então não ganham chip.

| `MaterialKind` | Chip |
|---|---|
| `pdf` | PDF |
| `chord` | Cifra |
| `audio` (`mp3`, `audio`) | Áudio |
| `youtube` | YouTube |
| `gesture` | Gestos |

Só aparecem chips de tipos que algum kind do índice tem, nesta ordem.

### 4.3 Casamento no filtro

Duas etapas, na mesma ordem das tags:
1. **Refinar:** um pai com algum filho também selecionado sai da seleção efetiva. O filho refina o pai, como `catalogTagsRefined`.
2. **Expandir:** cada pai que sobra casa com ele mesmo e com os filhos (`[id, ...filhos]`), como `catalogTagMatches`.

`_hasSelectedKind` recebe a seleção já expandida. O estado guardado (URL e prefs) continua sendo a lista de ids marcados, sem expandir.

**Muda o comportamento:** um filtro salvo com «Saxofone» passa a trazer também as variantes.

## 5. coldigui — tela

### 5.1 Seção Materiais (`catalog_filter_sections.dart`)

A ordem na tela, de cima para baixo:
1. título «Materiais»;
2. **chips de Tipo**: «Todos», seguido de um chip por tipo, cada um com a contagem de kinds;
3. a dica «N materiais ocultos pelo tipo», quando houver;
4. **uma seção por classe**, na ordem de `kindClasses`, e «Outros» por último. Cada seção tem um rótulo pequeno em caixa-alta, a contagem, um fio e o `Wrap`;
5. dentro da classe: a ordem por `order` e depois pelo rótulo (collator pt-BR); as famílias viram um **chip de família**.

**Chips de Tipo:**
- são mais baixos e mais quadrados que os chips de kind; marcados, ficam preenchidos de vinho;
- «Todos» limpa a seleção de tipos, e a seleção é múltipla;
- um kind aparece se tem algum dos tipos marcados **ou se está selecionado**. Um selecionado nunca some, como na regra atual de `_withSelected`;
- uma classe sem kinds visíveis some;
- o estado dos tipos fica só na tela: não vai para a URL nem para as prefs, e volta a «Todos» ao reabrir.

### 5.2 Chip de família

Visual: uma pílula com dois alvos de toque.
- **Corpo:** o rótulo do pai e a contagem de filhos. Marca ou desmarca o pai.
- **Seta:** abre ou fecha os filhos, que aparecem numa linha própria logo abaixo, recuada e com um fio dourado à esquerda.

Estados do chip:

| Estado | Quando | Visual |
|---|---|---|
| marcado | pai selecionado e nenhum filho | igual ao chip selecionado de hoje (dourado, borda 2) |
| refinado | algum filho selecionado, com ou sem o pai | borda dourada tracejada |
| nenhum | nada selecionado | igual ao chip de hoje |

Regras de toque, a mesma regra das subtags em produção (F5):
- **marcar o pai** vale pela família inteira: se havia filhos marcados, eles saem;
- com o pai marcado e nenhum filho, os filhos aparecem **«incluídos»** (borda tracejada, fundo dourado claro);
- com o pai marcado, **tocar num filho** marca o filho, e o pai continua marcado. A partir daí vale só o que está marcado entre os filhos (refinar). Desmarcar o último filho volta a valer a família inteira;
- **desmarcar o pai** desmarca também os filhos, como `toggleTag`;
- sem o pai marcado, cada filho liga e desliga normalmente, e o chip fica «refinado»;
- uma família com um filho selecionado abre sozinha. Abrir e fechar não é salvo;
- uma família com um membro só (depois do filtro de tipo, por exemplo) vira chip simples.

### 5.3 Unidades (lógica fora do widget)

Funções puras, testáveis sem widget:
- montar as seções: kinds + taxonomia + tipos marcados + seleção → classes visíveis com unidades (chip ou família);
- a seleção efetiva do casamento: refinar e depois expandir (§4.3);
- as ações de seleção: marcar o pai (tira os filhos), desmarcar o pai (tira os filhos) e alternar um filho.

O `FamilyFilterChip` e a seção agrupada são widgets finos em cima delas.

## 6. Ordem de entrega

1. **coldigom** (`feat/material-kind-classes`): migration + `schema.sql` + dump + testes.
2. **App — seção Materiais** (`feat/filtro-materiais-classes`): DTO, cache da taxonomia, opções, casamento, chips de Tipo, classes, famílias e testes.
   - Pode ser feito em paralelo com as subtags da Coletânea, mas passa por **rebase sobre o merge delas** em `web/integration` antes de mesclar. As duas mexem em `catalog_filter_sections.dart`: a das subtags tira a seção Categoria.
   - A sessão das subtags avisa quando mesclar.
3. **Deploy**, cada passo com ok do dono:
   1. migration no D1 de produção;
   2. deploy do Worker;
   3. deploy do app em v2.plpcg.com;
   4. homologação em produção (§8).

O app novo funciona com o coldigom antigo (tudo em «Outros»), então os passos 1 e 2 não precisam sair juntos.

## 7. Testes

**coldigom**
- A migration roda no banco de teste.
- A consulta de regras (§3.1) volta vazia.
- O dump traz `kindClasses` na ordem e `class`, `parent` e `order` nos kinds, e omite as chaves nulas.
- Um pai sem material entra em `kinds` quando tem filho com material.
- O ETag muda quando muda a classe de um kind.

**coldigui — unidade**
- DTO com e sem os campos novos.
- A taxonomia é gravada e lida do cache.
- Agrupamento: ordem das classes, «Outros» por último, ordem dentro da classe.
- Famílias: o pai com filhos vira família; um membro só vira chip simples.
- Tipos: o conjunto de `MaterialKind` por kind; um selecionado nunca some; classe vazia some.
- Seleção:
  - marcar o pai tira os filhos;
  - desmarcar o pai tira os filhos;
  - pai + filho vale pelo filho, e desmarcar o último filho volta à família inteira;
  - o casamento refina e expande em `matches_catalog_filters`.

**coldigui — widget**
- O chip de família nos três estados.
- Abrir e fechar.
- Os filhos «incluídos» e o estado «refinado».
- A dica de ocultos.

A suíte inteira roda antes de cada merge.

## 8. Homologação (produção, v2.plpcg.com)

1. As classes aparecem na ordem de §2.1, com «Outros» só se houver kind sem classe.
2. «Saxofone 4 ▾» fica em Metais. Marcar o chip traz louvores de todas as variantes.
3. Abrir a família e marcar «Saxofone alto»: o chip fica «refinado» e só os louvores com sax alto aparecem.
4. Com o pai marcado, tocar em «Saxofone tenor»: o pai continua marcado e vale só o tenor. Desmarcar o pai desmarca o tenor.
5. Tipo «Cifra»: a lista encolhe, aparece a dica de ocultos, e um material marcado fora do tipo continua visível.
6. Um link antigo com um id de pai traz as variantes.
7. Offline (modo avião, depois de uma sincronização): as classes continuam.
8. Largura de celular: as famílias abertas não estouram a tela.
9. A seção Tags continua com as «subtags sob demanda», sem mudança.

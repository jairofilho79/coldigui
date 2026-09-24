# Filtro «Materiais» por classe e família — chip de família compartilhado com as subtags

**Data:** 2026-09-24
**Estado:** design aprovado em conversa (partes 1–3); spec aguardando revisão.
**Mock aprovado:** https://claude.ai/artifact/3Vu8drWP5Gu2dq2NyDAo95, opção 6 «Seções + famílias».
**Repos:**
- `coldigom`: `api/` (migration e dump do catálogo);
- `coldigui`: o app Flutter.

**Branches (a criar):**
- `coldigom`: `feat/material-kind-classes`, a partir de `origin/main` (@ `e614d43` em 2026-09-24), num worktree próprio;
- `coldigui`: `feat/filtro-materiais-classes`, a partir de `web/integration`.

**Depende de:** spec das subtags (`2026-09-24-secoes-coletanea-subtags-design.md`, branch `feat/secoes-coletanea-subtags`). As duas mexem em `catalog_filter_sections.dart` (§6).

## 0. Objetivo e limites

A seção «Materiais» dos filtros (Home e /biblioteca) mostra uns 95 chips soltos em ordem alfabética: MIDI, instrumentos, vozes e acompanhamento misturados. A entrega organiza essa seção e mantém o padrão visual de hoje (título + `Wrap` de `FilterChip`):
- **chips de Tipo** (PDF, Cifra, Áudio…) logo abaixo do título, com seleção múltipla, que escondem da lista os materiais sem arquivo daquele tipo;
- **classes** (Metais, Banda, Vozes…) como rótulos pequenos com um fio, cada uma com o seu `Wrap`;
- **famílias** recolhidas num chip só («Saxofone 4 ▾»), com a semântica das subtags: o pai inclui os filhos.

O **chip de família** é um componente genérico. Depois do merge das subtags, a seção «Tags» passa a usá-lo também («Coletânea 13 ▾»).

**Não entra (decidido):**
- **Tela no admin** para editar classe, pai e ordem. Os dados vêm de migration; um kind novo aparece em «Outros» até alguém rodar SQL ou script.
- **`/api/materials/kinds`** e o filtro por material kind da API e do admin continuam como estão.
- **A tela «Materiais favoritos»**, as preferências de tipo por material e o plpcjf.
- **Chip de Tipo filtrando louvores.** O chip só organiza a lista de materiais (decisão do dono).

## 1. Fatos medidos (2026-09-24)

| # | Fato | Consequência |
|---|---|---|
| F1 | `material_kinds` tem só `id` e `name UNIQUE`. O rótulo pt-BR vem de `material_kind_translations` (`loadMaterialKindLabels`, `api/src/materialKindLabels.ts`). | A classe, o pai e a ordem entram como colunas novas. O rótulo de exibição continua sendo o traduzido. |
| F2 | O dump `GET /api/plpcg/catalog` já manda `kinds: [{id, name}]` (só os kinds com material), e o ETag é o hash de `{kinds, praises}` (`api/src/plpcgPraises.ts`). | Os campos novos vão em `kinds`. O ETag muda sozinho quando a classificação muda. |
| F3 | No app, `ColdigomCatalogDto.kindNames` lê `kinds` e desnormaliza o nome em cada material do cache Isar. As opções de filtro (`CatalogFilterOptions.fromGroups`) saem do índice local, a partir dos materiais. | A classificação precisa de um lugar próprio no cache, guardado na mesma sincronização. |
| F4 | O filtro guarda `materialKindIds` (ids, não rótulos). `_hasSelectedKind` (`matches_catalog_filters.dart`) casa só o id exato. | O casamento passa a expandir pai → filhos. |
| F5 | As tags já têm hierarquia no app: `catalogTagMatches` (o pai casa os filhos), `catalogTagsRefined` (pai + filho selecionados vale pelo filho) e `catalogTagWithAncestors` (`lib/features/catalog/domain/utils/catalog_tag_hierarchy.dart`). A seleção de tags grava o **rótulo completo** (`Coletânea · Clamor`). | A regra de família dos kinds copia a das tags. O chip de tag lê e grava rótulos completos. |
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

Rótulos dos tipos:

| `type` | Chip |
|---|---|
| `pdf` | PDF |
| `chord` | Cifra |
| `mp3`, `audio`, `m4a`, `mpeg` | Áudio (um chip só) |
| `midi`, `mid` | MIDI (um chip só) |
| `gestures` | Gestos |
| `youtube` | YouTube |
| outro | o próprio valor |

Só aparecem chips de tipos que existem no catálogo.

### 4.3 Casamento no filtro

- `_hasSelectedKind` expande a seleção: um id selecionado casa com ele mesmo e com os filhos (`[id, ...filhos]`), igual a `catalogTagMatches`.
- Pai e filho selecionados juntos (por exemplo, num link antigo) valem só pelo filho, igual a `catalogTagsRefined`.
- **Muda o comportamento:** um filtro salvo com «Saxofone» passa a trazer também as variantes.

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

### 5.2 Chip de família (componente genérico)

Visual: uma pílula com dois alvos de toque.
- **Corpo:** o rótulo do pai e a contagem de filhos. Marca ou desmarca o pai.
- **Seta:** abre ou fecha os filhos, que aparecem numa linha própria logo abaixo, recuada e com um fio dourado à esquerda.

Estados do chip:

| Estado | Quando | Visual |
|---|---|---|
| marcado | pai selecionado | igual ao chip selecionado de hoje (dourado, borda 2) |
| parcial | algum filho selecionado e o pai não | borda dourada tracejada |
| nenhum | nada selecionado | igual ao chip de hoje |

Regras de toque:
- **marcar o pai** tira da seleção os filhos que estavam marcados;
- com o pai marcado, os filhos aparecem **«incluídos»** (borda tracejada, fundo dourado claro). Tocar em um deles **troca**: desmarca o pai e marca só aquele filho;
- sem o pai marcado, cada filho liga e desliga normalmente;
- uma família com um filho selecionado abre sozinha. Abrir e fechar não é salvo;
- uma família com um membro só (depois do filtro de tipo, por exemplo) vira chip simples.

O componente não sabe se trata tags ou kinds: recebe o pai, os filhos (id + rótulo curto), a seleção e os callbacks.

### 5.3 Seção Tags (depois do merge das subtags)

- As famílias saem dos rótulos: uma raiz com filhos «raiz · x» vira chip de família. Um filho é exibido pelo **rótulo curto** («Clamor»).
- A seleção grava o **rótulo completo** («Coletânea · Clamor»), como hoje. A conversão de legado das subtags (`?category=` → tag) também gera rótulos completos.
- As regras de toque são as de §5.2. O casamento continua em `catalogTagMatches` e `catalogTagsRefined`, sem mudar.
- As tags não ganham classes.

### 5.4 Unidades (lógica fora do widget)

Funções puras, testáveis sem widget:
- montar as seções: kinds + taxonomia + tipos marcados + seleção → classes visíveis com unidades (chip ou família);
- expandir a seleção para o casamento: id → `[id, ...filhos]`, e pai + filho → filho;
- as ações de seleção: marcar o pai (tira os filhos) e trocar um «incluído» (tira o pai, põe o filho);
- montar as famílias de tags a partir dos rótulos «pai · filho».

O `FamilyFilterChip` e a seção agrupada são widgets finos em cima delas.

## 6. Ordem de entrega

1. **coldigom** (`feat/material-kind-classes`): migration + `schema.sql` + dump + testes.
2. **App — seção Materiais** (`feat/filtro-materiais-classes`): DTO, cache da taxonomia, opções, casamento, chips de Tipo, classes, famílias e testes.
   - Pode ser feito em paralelo com as subtags, mas passa por **rebase sobre o merge das subtags** em `web/integration` antes de mesclar. As duas mexem em `catalog_filter_sections.dart`: a das subtags tira a seção Categoria.
   - A sessão das subtags avisa quando mesclar.
3. **App — famílias na seção Tags:** só depois do merge das subtags.
4. **Deploy**, cada passo com ok do dono:
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
- Tipos: o conjunto de tipos por kind; os tipos de áudio juntos e os de MIDI juntos; um selecionado nunca some; classe vazia some.
- Seleção:
  - marcar o pai tira os filhos;
  - tocar num «incluído» troca;
  - pai + filho vale pelo filho;
  - o casamento pai → filhos em `matches_catalog_filters`.
- Tags: famílias montadas a partir dos rótulos; a seleção grava o rótulo completo.

**coldigui — widget**
- O chip de família nos três estados.
- Abrir e fechar.
- Os filhos «incluídos».
- A dica de ocultos.

A suíte inteira roda antes de cada merge.

## 8. Homologação (produção, v2.plpcg.com)

1. As classes aparecem na ordem de §2.1, com «Outros» só se houver kind sem classe.
2. «Saxofone 4 ▾» fica em Metais. Marcar o chip traz louvores de todas as variantes.
3. Abrir a família e marcar «Saxofone alto»: o chip fica parcial.
4. Com o pai marcado, tocar em «Saxofone tenor»: fica só o tenor.
5. Tipo «Cifra»: a lista encolhe, aparece a dica de ocultos, e um material marcado fora do tipo continua visível.
6. Um link antigo com um id de pai traz as variantes.
7. Offline (modo avião, depois de uma sincronização): as classes continuam.
8. Largura de celular: as famílias abertas não estouram a tela.
9. Depois do passo 3 de §6: «Coletânea 13 ▾» na seção Tags; marcar «Clamor» grava `Coletânea · Clamor` na URL.

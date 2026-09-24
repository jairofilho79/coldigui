# Seções da Coletânea — Plano 3: admin web do coldigom

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** o admin web do coldigom (`web/src`) deixa de mostrar, editar, filtrar, ordenar e enviar `praise.category`. O seletor de tags passa a oferecer as tags raiz que têm subtags. A seção da Coletânea passa a ser só a subtag `Coletânea · <seção>`.

**Architecture:** só remoção e um ajuste de filtro.
- **Filtros:** o campo sai do `FilterState` (`useFilters`), da `FilterBar`, da `HomePage` e dos parâmetros de `searchPraises`/`getFilterOptions`. A opção «Categoria» sai de `SORT_OPTIONS`/`VALID_SORT_FIELDS`.
- **Links antigos:** `?category=` é ignorado na leitura e sai da URL na próxima escrita de `setFilters`. `?sort=category` cai na ordenação padrão pela validação que já existe (`lerOrdenacao`).
- **Formulários:** o campo sai de `PraiseDetailPage` (estado, criação, PATCH, ficha) e de `PraiseMergeImportPage` (linha de metadados e `metadata.category` do merge). Com a trava «parent tag» fora da API (spec §3.2), o bloqueio de tag pai que o cliente fazia no merge também sai.
- **`FindingEvidence`:** deixa de exibir a categoria.
- **Tipos:** `Praise.category` e `FilterOptions.categories` ficam, **opcionais e sem leitor**, porque a API continua mandando os dois até a fase 3 (spec §3.4).

**Tech Stack:** React 19 + TypeScript 5 (`tsc -b`, `tsconfig.app.json` exclui os testes), Vite, vitest 4 + jsdom + Testing Library (`@testing-library/react`, `user-event`), ESLint 9.

**Spec:** `docs/superpowers/specs/2026-09-24-secoes-coletanea-subtags-design.md` (repo coldigui), **§3.5** e a linha «coldigom `web/`» de **§8**. Contexto: §3.2 (API aceita tag raiz com filhos), §3.3 (merge sem `metadata.category`), §3.4 (API segue emitindo `category`/`categories`).

**Worktree/branch:** coldigom `.claude/worktrees/secoes-coletanea` (`/Volumes/SSD 2TB SD/dev/coldigom/.claude/worktrees/secoes-coletanea`), branch `feat/secoes-coletanea-subtags`. O worktree já existe, com HEAD em `5d0f728`. Os planos da API e do script commitam na mesma branch; este plano só toca `web/`.

## Global Constraints

- **Só `web/`.** Nada em `api/`, `scripts/` ou no coldigui. Os paths abaixo são relativos à raiz do worktree.
- **Comandos:**
  - cwd de todos os comandos: `/Volumes/SSD 2TB SD/dev/coldigom/.claude/worktrees/secoes-coletanea`;
  - testes: `cd web && npx vitest run <arquivos>`;
  - git: comando plano a partir da raiz do worktree (`git add web/src/...`). O guard recusa `cd <path> && git …` e `git -C`.
- **Zumbis do vitest:** subagentes deixam processos `vitest --pool=threads` vivos. Rodar `pkill -f vitest` antes de toda execução da suíte inteira.
- **Nunca declarar teste verde sem rodar.** A saída do vitest (`Test Files … passed`, `Tests … passed`) é a evidência. Base medida ao planejar (2026-09-24, HEAD `5d0f728`):
  - `npx vitest run`: **73 arquivos, 963 testes, 0 falhas**;
  - `npx tsc -b` e `npx eslint .`: limpos.
- **`tsc -b` verde a cada commit.** As tarefas estão ordenadas para isso: cada tipo só perde `category` na mesma tarefa em que o último leitor dele sai. O vitest não faz checagem de tipo, e os testes estão fora do `tsc -b`.
- **Não confundir as duas «categorias».** Em `PraiseDetailPage`, `PraiseMergeImportPage`, `MaterialInlineAdmin`, `BulkFilePreviewList`, `SecaoGestos` e `ChordProPage`, «categoria» também é a **categoria do material** (`material_kind`). **Não mexer** nestes pontos:
  - `categoriasErro` e `carregarCategorias`;
  - «Edição de categoria — em breve»;
  - `label="Categoria"` do seletor `new-mat-kind` em «Adicionar material»;
  - `aria-label="Categoria do material"`;
  - «Defina a categoria de todos os arquivos…»;
  - `SecaoGestos` (`categorias`, `ge-novo-categoria`);
  - `PanelRow label="Categoria"` do `ChordProPage`;
  - os testes deles.

  Só sai o campo de metadado `praise.category`.
- **Ordem de deploy (spec §6):** este admin só sobe **depois** do deploy da API com §3.2 e §3.3. Antes disso:
  - o merge sem `metadata.category` leva 400 (`routes/praises.ts:779`);
  - ligar uma raiz com filhos leva 400 «Cannot attach a parent tag».

  O deploy do admin acompanha o passo 4 de §6 e não faz parte deste plano.
- **Nada de push, PR, merge ou deploy** sem pedido do dono.
- **Commits:** um por tarefa, em português, `feat(web): …`/`test(web): …`, terminando com o trailer exato:
  `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`

### Decisões tomadas ao planejar

1. **`Praise.category` fica, opcional (`category?: string | null`).** A API manda `category` em `/api/praises` e `/api/praises/:id` até a fase 3 (§3.4). O tipo não mente, e o admin não lê nem escreve o campo. Por isso as fixtures com `category: ''` nos testes de `ChordProPage`, `GesturesEditorPage`, `MoverMaterialForm`, `ResultsTable(.keyboard)`, `PraiseMergeSelectPage`, `HomePage` e `api(.extra)` **ficam como estão**: espelham a resposta real. Saem na fase 3. (Task 5.)
2. **`FilterOptions.categories` fica opcional (`categories?: string[]`), sem leitor.** `GET /api/praises/filters` continua devolvendo a chave (§3.4). Os mocks de `getFilterOptions` que ainda trazem `categories` ficam: eles provam que a barra ignora a chave. (Task 1.)
3. **Os payloads perdem a chave `category`:**
   - `CreatePraiseInput` e o `Pick` de `updatePraise` (Task 3);
   - `MergePraisesInput.metadata` (Task 4);
   - `SearchParams` (Task 2).

   Os testes conferem a **ausência da chave** (`Object.keys(...)`), não só do valor.
4. **Links antigos do admin:**
   - `?category=…` é ignorado na leitura, não conta em `activeFilterCount`, não vira marca e não vai para a API. `setFilters` o apaga da URL na próxima escrita, para o link não carregar lixo quando for copiado;
   - `?sort=category` cai em `number`: sai de `VALID_SORT_FIELDS`, e `lerOrdenacao` já faz o resto.

   (Tasks 1 e 2.)
5. **Desvio pedido por §3.2 e ausente da lista de §3.5:** `PraiseMergeImportPage` hoje trava a finalização quando o louvor fonte traz uma tag raiz que tem subtags:
   - `tagIdsDeAgrupamento`, `tagIdsDoKeeper` e `tagsQueBloqueiam`;
   - a pílula «agrupamento»;
   - o aviso «agrupa subtags».

   Depois da migração, `Coletânea` e `Avulsos` terão filhos, e a trava bloquearia merges que a API passa a aceitar. A trava sai. O teste de recusa passa a testar aceitação, como §8 manda para a API. (Task 4.)
6. **O aviso «Todas as tags do catálogo já estão associadas.»** exigia `displayTags.length === 0`. Com as raízes oferecidas, o caso só era alcançável com um catálogo patológico, em que toda tag é pai de outra (o teste atual monta exatamente isso). A condição passa a `catalogTags.length > 0`: sem tag a oferecer e com catálogo carregado, o louvor já tem todas. (Task 3.)
7. **Rascunho antigo no `sessionStorage`** (`coldigom_rascunho_louvor`) com `edit.category` continua sendo restaurado sem erro. A chave extra fica no estado, mas nenhum payload a lê, porque criação e PATCH montam os campos um a um. O teste existente «devolve o rascunho ao voltar da autorização» já usa um rascunho com `category: ''` e fica como está, como prova.

## Review Focus

1. **Link antigo não quebra nem filtra:**
   - `/?category=Louvor&rhythm=Valsa` não manda `category` para a API, não vira marca nem contagem e some da URL na próxima escrita;
   - `/?sort=category` cai em `number`.

   Testes:
   - «?category= de link antigo é ignorado e sai da URL na próxima escrita» (useFilters);
   - «manda os filtros aplicados ao pedir as opções — e não o ?category= de link antigo» (FilterBar.facet);
   - «?category= de link antigo não vira marca de filtro» (FilterBar.controls);
   - «?sort=category de link antigo cai na ordenação padrão» (useFilters).

   (Tasks 1–2.)
2. **Nenhum payload leva a chave `category`:** criação, PATCH, merge, busca e opções de filtro. Testes:
   - «cria louvor ao salvar» e «edita número, autor, ritmo e tom e salva tudo junto, sem categoria» (PraiseDetailPage);
   - «finalizar manda metadados e tags resolvidos…» (merge, `toEqual` estrito);
   - «não manda category…» (api.test, dois testes).

   (Tasks 2–4.)
3. **Tag raiz com subtags é oferecida e ligável** (spec §3.2). Na ficha, `Coletânea` aparece junto de `Coletânea · Clamor` e o clique chama `addPraiseTag(id, 'tag1')`. No merge, a raiz vinda do louvor fonte não trava mais o botão. Testes:
   - «oferece a tag raiz que tem subtags, além das subtags (§3.2)»;
   - «avisa quando todas as tags do catálogo já estão no louvor»;
   - «tag raiz com subtags vinda do louvor fonte é aceita sem aviso (§3.2)».

   (Tasks 3–4.)
4. **A categoria do material fica intacta.** Os testes existentes seguem verdes sem edição:
   - «Catálogo de categorias indisponível»;
   - «exibe edição inline de categoria…»;
   - «troca a categoria de um material existente…»;
   - «trocar a categoria de um material salva na hora» (merge);
   - BulkFilePreviewList e SecaoGestos.

   A auditoria por grep da Task 5 confere o que sobrou.
5. **Exibição:** a ficha do louvor e a comparação do `FindingEvidence` não mostram a categoria, mesmo com a API ainda mandando o campo. Testes:
   - «a ficha do louvor não mostra a categoria, mesmo que a API ainda a mande» (Task 3);
   - «merge_praise: não mostra a categoria, mesmo que a API ainda a mande» (Task 5).

## Mapa de arquivos

| Tarefa | Modifica (código) | Modifica (testes) |
|---|---|---|
| 1 Filtros da HomePage | `web/src/hooks/useFilters.ts`, `web/src/components/FilterBar.tsx`, `web/src/pages/HomePage.tsx`, `web/src/types/index.ts` (`FilterOptions`) | `web/src/__tests__/useFilters.test.tsx`, `web/src/__tests__/FilterBar.test.tsx`, `web/src/components/__tests__/FilterBar.keyboard.test.tsx`, `web/src/components/__tests__/FilterBar.facet.test.tsx`, `web/src/components/__tests__/FilterBar.controls.test.tsx`, `web/src/__tests__/HomePage.test.tsx`, `web/src/__tests__/HomePage.race.test.tsx` |
| 2 Busca e ordenação | `web/src/services/api.ts` (`SearchParams`, `searchPraises`, `getFilterOptions`), `web/src/types/index.ts` (`VALID_SORT_FIELDS`, `SORT_OPTIONS`) | `web/src/__tests__/api.test.ts`, `web/src/__tests__/SortSelector.test.tsx`, `web/src/__tests__/useFilters.test.tsx` |
| 3 Ficha do louvor | `web/src/pages/PraiseDetailPage.tsx`, `web/src/services/api.ts` (`CreatePraiseInput`, `updatePraise`) | `web/src/__tests__/PraiseDetailPage.test.tsx` |
| 4 Merge | `web/src/pages/PraiseMergeImportPage.tsx`, `web/src/services/api.ts` (`MergePraisesInput`) | `web/src/__tests__/PraiseMergeImportPage.test.tsx`, `web/src/__tests__/api.extra.test.ts` |
| 5 FindingEvidence + tipo + verificação | `web/src/components/FindingEvidence.tsx`, `web/src/types/index.ts` (`Praise`) | `web/src/components/__tests__/FindingEvidence.test.tsx` |

Sem mudança, por decisão (ver Decisão 1): `PraiseMergeSelectPage.test.tsx`, `ResultsTable.test.tsx`, `components/__tests__/ResultsTable.keyboard.test.tsx`, `components/__tests__/MoverMaterialForm.test.tsx`, `pages/__tests__/ChordProPage.test.tsx`, `pages/__tests__/GesturesEditorPage.test.tsx`, `components/__tests__/ResultsTable.empty.test.tsx`. O último usa a string «Categoria: Louvor» só como rótulo genérico passado por prop.

---

### Task 1: Filtros da HomePage — `useFilters`, `FilterBar`, `HomePage`

**Files:**
- Modify: `web/src/hooks/useFilters.ts:5-17` (`FilterState`), `:65`, `:83`, `:110-113`, `:156-164` (`activeFilterCount`)
- Modify: `web/src/components/FilterBar.tsx:7`, `:32-41`, `:43-47`, `:55`, `:109-113`, `:231-235`, `:352`
- Modify: `web/src/pages/HomePage.tsx:43`, `:69`, `:78`
- Modify: `web/src/types/index.ts:119-124` (`FilterOptions`)
- Test: `web/src/__tests__/useFilters.test.tsx:1-5`, `:33`, `:232-238`, `:297-305`
- Test: `web/src/__tests__/FilterBar.test.tsx:12-31`, `:117-125`
- Test: `web/src/components/__tests__/FilterBar.keyboard.test.tsx:34-72`
- Test: `web/src/components/__tests__/FilterBar.facet.test.tsx:34-66`
- Test: `web/src/components/__tests__/FilterBar.controls.test.tsx:98-120`
- Test: `web/src/__tests__/HomePage.test.tsx:26-45`, `:184-201`
- Test: `web/src/__tests__/HomePage.race.test.tsx:14`, `:21-33`

**Interfaces (depois):**
```ts
export interface FilterState {
  query: string;
  tags: string[];
  rhythm: string[];
  tonality: string[];
  materialKinds: string[];
  numberMin?: number;
  numberMax?: number;
  sort: SortField;
  order: 'asc' | 'desc';
  page: number;
}

export interface FilterOptions {
  rhythms: string[];
  tonalities: string[];
  /** A API ainda devolve até a fase 3 do spec das seções da Coletânea; o admin ignora. */
  categories?: string[];
  tags: TagWithCount[];
}
```

- [ ] **Step 1: testes de `useFilters`**

Em `web/src/__tests__/useFilters.test.tsx`:

(a) Linha 4: trocar
```ts
import { MemoryRouter } from 'react-router-dom';
```
por
```ts
import { MemoryRouter, useLocation } from 'react-router-dom';
```

(b) Linha 33, no teste `should return default values with no URL params`: trocar
```ts
      expect(result.current.filters.category).toEqual([]);
```
por
```ts
      expect(result.current.filters).not.toHaveProperty('category');
```

(c) Linhas 232-238: trocar o teste inteiro
```ts
    it('should count rhythm, tonality, category filters', () => {
      const { result } = renderHook(() => useFilters(), {
        wrapper: createWrapper('/?rhythm=Avulsos&tonality=C&category=Louvor'),
      });

      expect(result.current.activeFilterCount).toBe(3);
    });
```
por
```ts
    it('conta ritmo e tom; ?category= de link antigo não conta', () => {
      const { result } = renderHook(() => useFilters(), {
        wrapper: createWrapper('/?rhythm=Avulsos&tonality=C&category=Louvor'),
      });

      expect(result.current.activeFilterCount).toBe(2);
    });
```

(d) Linhas 297-305: trocar o teste inteiro
```ts
    it('clears category param when empty array', async () => {
      const { result } = renderHook(() => useFilters(), {
        wrapper: createWrapper('/?category=Louvor'),
      });
      await act(async () => {
        result.current.setFilters({ category: [] });
      });
      expect(result.current.filters.category).toEqual([]);
    });
```
por
```ts
    it('?category= de link antigo é ignorado e sai da URL na próxima escrita', async () => {
      // O filtro «Categoria» foi aposentado: as seções da Coletânea viraram
      // subtags. Link antigo não quebra; o valor só não filtra nada e não fica
      // sendo copiado adiante.
      const { result } = renderHook(
        () => ({ hook: useFilters(), location: useLocation() }),
        { wrapper: createWrapper('/?category=Louvor&rhythm=Valsa') }
      );
      expect(result.current.hook.filters).not.toHaveProperty('category');

      await act(async () => {
        result.current.hook.setFilters({ query: 'x' });
      });

      const params = new URLSearchParams(result.current.location.search);
      expect(params.has('category')).toBe(false);
      expect(params.get('rhythm')).toBe('Valsa');
      expect(params.get('q')).toBe('x');
    });
```

- [ ] **Step 2: testes da `FilterBar`**

(a) `web/src/__tests__/FilterBar.test.tsx`: no mock de `useFilters` (linhas 12-31), apagar a linha
```ts
      category: [],
```
e trocar o teste das linhas 117-125
```ts
  it('should render category dropdown', async () => {
    render(
      <MemoryRouter>
        <FilterBar />
      </MemoryRouter>
    );

    expect((await screen.findAllByText('Categoria'))[0]).toBeTruthy();
  });
```
por
```ts
  it('não oferece o filtro Categoria, mesmo com a API ainda mandando categories', async () => {
    // A categoria foi aposentada: as seções da Coletânea são subtags e aparecem
    // nos chips de Coleções. A API segue mandando `categories` até a fase 3 do
    // spec (o mock acima também manda), e a barra ignora.
    render(
      <MemoryRouter>
        <FilterBar />
      </MemoryRouter>
    );

    await screen.findByText('Coleções');
    expect(screen.queryByRole('button', { name: /^categoria/i })).toBeNull();
  });
```

(b) `web/src/components/__tests__/FilterBar.keyboard.test.tsx`: os três testes deixam de usar o dropdown de Categoria e passam a usar o de Ritmo, que tem o mesmo `renderStringDropdown`. Trocar as linhas 34-72 (os três `it`) por:
```ts
  it('as opções são alcançáveis e marcáveis por teclado', async () => {
    // Os checkboxes tinham tabIndex={-1} e os rótulos, role="option" sem serem
    // focáveis: abrir por teclado levava a um beco sem saída, nenhuma opção
    // podia ser marcada sem mouse.
    const usuario = userEvent.setup();
    await montar();

    const gatilho = screen.getByRole('button', { name: /^ritmo/i });
    await usuario.click(gatilho);

    const caixa = screen.getByRole('checkbox', { name: 'Valsa' });
    expect(caixa.getAttribute('tabindex')).not.toBe('-1');

    caixa.focus();
    await usuario.keyboard(' ');
    expect((caixa as HTMLInputElement).checked).toBe(true);
  });

  it('Escape fecha e devolve o foco ao gatilho', async () => {
    const usuario = userEvent.setup();
    await montar();

    const gatilho = screen.getByRole('button', { name: /^ritmo/i });
    await usuario.click(gatilho);
    expect(screen.getByRole('checkbox', { name: 'Valsa' })).toBeTruthy();

    await usuario.keyboard('{Escape}');
    expect(screen.queryByRole('checkbox', { name: 'Valsa' })).toBeNull();
    expect(document.activeElement).toBe(gatilho);
  });

  it('o grupo de opções se anuncia pelo nome do filtro', async () => {
    const usuario = userEvent.setup();
    await montar();

    await usuario.click(screen.getByRole('button', { name: /^ritmo/i }));
    expect(screen.getByRole('group', { name: /ritmo/i })).toBeTruthy();
  });
```
O `montar()` do arquivo já mocka `rhythms: ['Valsa']`. O `categories` do mock fica.

(c) `web/src/components/__tests__/FilterBar.facet.test.tsx`: trocar os três primeiros `it` (linhas 34-66) por:
```ts
  it('manda os filtros aplicados ao pedir as opções — e não o ?category= de link antigo', async () => {
    await montar('/?category=Louvor&rhythm=Valsa');

    const pedido = vi.mocked(getFilterOptions).mock.calls[0][0]!;
    expect(pedido).toMatchObject({ rhythm: ['Valsa'] });
    expect(Object.keys(pedido)).not.toContain('category');
  });

  it('refaz a consulta quando um filtro muda', async () => {
    const usuario = userEvent.setup();
    await montar('/');
    expect(getFilterOptions).toHaveBeenCalledTimes(1);

    await usuario.click(screen.getByRole('button', { name: /^ritmo/i }));
    await usuario.click(screen.getByRole('checkbox', { name: 'Valsa' }));

    await waitFor(() => expect(getFilterOptions).toHaveBeenCalledTimes(2));
    expect(vi.mocked(getFilterOptions).mock.calls[1][0]).toMatchObject({ rhythm: ['Valsa'] });
  });

  it('a barra não some enquanto as opções são refeitas', async () => {
    // Limpar filterOptions antes de refazer faria a barra inteira piscar para
    // spinner a cada clique de filtro.
    const usuario = userEvent.setup();
    await montar('/');

    await usuario.click(screen.getByRole('button', { name: /^ritmo/i }));
    await usuario.click(screen.getByRole('checkbox', { name: 'Valsa' }));

    expect(screen.getByText('Coleções')).toBeTruthy();
    expect(screen.queryByRole('status')).toBeNull();
  });
```
O quarto `it` («mudar só a página não refaz as opções») fica.

(d) `web/src/components/__tests__/FilterBar.controls.test.tsx`, describe «FilterBar — filtros ativos visíveis» (linhas 98-125): trocar os dois primeiros `it` por três:
```ts
  it('mostra cada filtro aplicado como uma marca removível', async () => {
    // Antes só havia um contador numérico no gatilho do dropdown: não dava
    // para ver o que estava aplicado nem remover um filtro sem reabrir o menu
    // certo e caçar a opção marcada.
    await montar('/?rhythm=Valsa&numberMin=10');

    const ativos = screen.getByRole('group', { name: /filtros aplicados/i });
    expect(ativos).toBeTruthy();
    expect(screen.getByRole('button', { name: /remover filtro ritmo: valsa/i })).toBeTruthy();
    expect(screen.getByRole('button', { name: /remover filtro número a partir de 10/i })).toBeTruthy();
  });

  it('?category= de link antigo não vira marca de filtro', async () => {
    await montar('/?category=Louvor');

    expect(screen.queryByRole('group', { name: /filtros aplicados/i })).toBeNull();
    expect(screen.queryByRole('button', { name: /remover filtro categoria/i })).toBeNull();
  });

  it('remover uma marca tira só aquele filtro', async () => {
    const usuario = userEvent.setup();
    await montar('/?rhythm=Valsa&tonality=G');

    await usuario.click(screen.getByRole('button', { name: /remover filtro ritmo: valsa/i }));

    expect(espelho.url).not.toContain('rhythm');
    expect(espelho.url).toContain('tonality=G');
  });
```
O terceiro `it` original («sem filtro aplicado, não mostra a área de filtros ativos») fica.

- [ ] **Step 3: testes da `HomePage`**

(a) `web/src/__tests__/HomePage.test.tsx`: no mock de `useFilters` (linhas 26-45), apagar a linha
```ts
      category: [],
```
No teste `should call searchPraises with filters` (linhas 184-201), trocar
```ts
      expect(vi.mocked(searchPraises).mock.calls[0][0]).toMatchObject({
        query: '',
        page: 1,
        tags: [],
        rhythm: [],
        tonality: [],
        category: [],
        materialKinds: [],
        sort: 'number',
        order: 'asc',
      });
```
por
```ts
      expect(vi.mocked(searchPraises).mock.calls[0][0]).toMatchObject({
        query: '',
        page: 1,
        tags: [],
        rhythm: [],
        tonality: [],
        materialKinds: [],
        sort: 'number',
        order: 'asc',
      });
      // A categoria foi aposentada: a chave não pode nem ir vazia.
      expect(Object.keys(vi.mocked(searchPraises).mock.calls[0][0]!)).not.toContain('category');
```
As fixtures `mockPraises` com `category: 'Louvor'`/`'Adoração'` ficam (Decisão 1).

(b) `web/src/__tests__/HomePage.race.test.tsx`: na linha 14, trocar
```ts
    getFilterOptions: vi.fn().mockResolvedValue({ rhythms: [], tonalities: [], categories: [], tags: [] }),
```
por
```ts
    getFilterOptions: vi.fn().mockResolvedValue({ rhythms: [], tonalities: [], tags: [] }),
```
Em `FILTROS_BASE` (linhas 21-33), apagar a linha
```ts
  category: [] as string[],
```
A fixture `louvor()` com `category: ''` fica.

- [ ] **Step 4: rodar e ver falhar**

```bash
cd web && npx vitest run src/__tests__/useFilters.test.tsx src/__tests__/FilterBar.test.tsx src/components/__tests__/FilterBar.keyboard.test.tsx src/components/__tests__/FilterBar.facet.test.tsx src/components/__tests__/FilterBar.controls.test.tsx src/__tests__/HomePage.test.tsx src/__tests__/HomePage.race.test.tsx
```
Expected: FAIL.
- **useFilters:** os 3 testes novos/alterados.
- **FilterBar.test e HomePage.test/race:** falham em massa com `TypeError` ao ler `.length`/`.map` de `filters.category`, porque os mocks já não têm a chave e o código ainda a lê.
- **FilterBar.facet:** o primeiro teste, porque `category` ainda está na chamada.
- **FilterBar.controls:** «?category= de link antigo não vira marca de filtro».
- **FilterBar.keyboard:** passa, porque o Ritmo já existe e o arquivo só foi adaptado.

- [ ] **Step 5: `FilterOptions` opcional**

Em `web/src/types/index.ts` (linhas 119-124), trocar
```ts
export interface FilterOptions {
  rhythms: string[];
  tonalities: string[];
  categories: string[];
  tags: TagWithCount[];
}
```
por
```ts
export interface FilterOptions {
  rhythms: string[];
  tonalities: string[];
  /** A API ainda devolve até a fase 3 do spec das seções da Coletânea; o admin ignora. */
  categories?: string[];
  tags: TagWithCount[];
}
```

- [ ] **Step 6: `useFilters`**

Em `web/src/hooks/useFilters.ts`:

(a) Em `FilterState`, apagar a linha
```ts
  category: string[];
```
(b) No `useMemo` de `filters`, apagar a linha
```ts
    category: lerLista(searchParams, 'category'),
```
(c) Em `shouldResetPage`, apagar a linha
```ts
          'category' in updates ||
```
(d) Trocar o bloco
```ts
      if ('category' in updates) {
        if (updates.category && updates.category.length > 0) newParams.set('category', updates.category.join(','));
        else newParams.delete('category');
      }
```
por
```ts
      // `?category=` era o filtro «Categoria», aposentado (as seções da
      // Coletânea viraram subtags). Link antigo não quebra: a leitura ignora o
      // valor e a primeira escrita o tira da URL.
      newParams.delete('category');
```
(e) Em `activeFilterCount`, apagar a linha
```ts
    filters.category.length +
```

- [ ] **Step 7: `FilterBar`**

Em `web/src/components/FilterBar.tsx`:

(a) Linha 7: trocar
```ts
type MultiSelectKey = 'category' | 'rhythm' | 'tonality' | 'materialKinds';
```
por
```ts
type MultiSelectKey = 'rhythm' | 'tonality' | 'materialKinds';
```
(b) Em `chaveDosFiltros` (linhas 32-41), apagar a linha
```ts
    filters.category,
```
(c) Linhas 43-47: trocar
```ts
    const correntes = JSON.parse(chaveDosFiltros) as [
      string, string[], string[], string[], string[], string[], number | null, number | null
    ];
    const [query, tags, rhythm, tonality, category, materialKinds, minCru, maxCru] = correntes;
```
por
```ts
    const correntes = JSON.parse(chaveDosFiltros) as [
      string, string[], string[], string[], string[], number | null, number | null
    ];
    const [query, tags, rhythm, tonality, materialKinds, minCru, maxCru] = correntes;
```
(d) Linha 55: trocar
```ts
      getFilterOptions({ query, tags, rhythm, tonality, category, materialKinds, numberMin, numberMax }),
```
por
```ts
      getFilterOptions({ query, tags, rhythm, tonality, materialKinds, numberMin, numberMax }),
```
(e) Linhas 109-110: trocar
```ts
  const renderStringDropdown = (
    key: 'category' | 'rhythm' | 'tonality',
```
por
```ts
  const renderStringDropdown = (
    key: 'rhythm' | 'tonality',
```
(f) Linhas 231-235: trocar
```ts
    for (const [campo, titulo] of [
      ['rhythm', 'Ritmo'],
      ['tonality', 'Tom'],
      ['category', 'Categoria'],
    ] as const) {
```
por
```ts
    for (const [campo, titulo] of [
      ['rhythm', 'Ritmo'],
      ['tonality', 'Tom'],
    ] as const) {
```
(g) Linha 352: apagar
```tsx
        {renderStringDropdown('category', 'Categoria', filterOptions.categories)}
```

- [ ] **Step 8: `HomePage`**

Em `web/src/pages/HomePage.tsx`:

(a) Na chamada de `searchPraises` (linha 43), apagar
```ts
            category: filters.category,
```
(b) Linha 69: trocar
```ts
  }, [filters.query, filters.page, filters.tags, filters.rhythm, filters.tonality, filters.category, filters.materialKinds, filters.numberMin, filters.numberMax, filters.sort, filters.order]);
```
por
```ts
  }, [filters.query, filters.page, filters.tags, filters.rhythm, filters.tonality, filters.materialKinds, filters.numberMin, filters.numberMax, filters.sort, filters.order]);
```
(c) Em `filtrosAplicados` (linha 78), apagar
```ts
    ...filters.category.map((v) => `Categoria: ${v}`),
```

- [ ] **Step 9: rodar e ver passar**

```bash
cd web && npx vitest run src/__tests__/useFilters.test.tsx src/__tests__/FilterBar.test.tsx src/components/__tests__/FilterBar.keyboard.test.tsx src/components/__tests__/FilterBar.facet.test.tsx src/components/__tests__/FilterBar.controls.test.tsx src/components/__tests__/FilterBar.failure.test.tsx src/__tests__/HomePage.test.tsx src/__tests__/HomePage.race.test.tsx
```
Expected: PASS, 8 arquivos, 0 falhas.

```bash
cd web && npx tsc -b && npx eslint .
```
Expected: sem saída e exit 0.

- [ ] **Step 10: commit**

```bash
git add web/src/hooks/useFilters.ts web/src/components/FilterBar.tsx web/src/pages/HomePage.tsx web/src/types/index.ts web/src/__tests__/useFilters.test.tsx web/src/__tests__/FilterBar.test.tsx web/src/components/__tests__/FilterBar.keyboard.test.tsx web/src/components/__tests__/FilterBar.facet.test.tsx web/src/components/__tests__/FilterBar.controls.test.tsx web/src/__tests__/HomePage.test.tsx web/src/__tests__/HomePage.race.test.tsx
git commit -m "$(cat <<'EOF'
feat(web): tira o filtro Categoria da busca do admin

As seções da Coletânea viraram subtags e aparecem nos chips de Coleções.
Saem o dropdown, a marca de filtro ativo, o rótulo do estado vazio e o
campo do FilterState. Link antigo com ?category= não quebra: é ignorado
e sai da URL na primeira escrita.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Busca e ordenação — `SearchParams`, `SORT_OPTIONS`

**Files:**
- Modify: `web/src/services/api.ts:199-213` (`SearchParams`), `:227`, `:263`
- Modify: `web/src/types/index.ts:128-136` (`VALID_SORT_FIELDS`), `:152-160` (`SORT_OPTIONS`)
- Test: `web/src/__tests__/api.test.ts:207-217` e o describe `getFilterOptions` (`:264-300`)
- Test: `web/src/__tests__/SortSelector.test.tsx:32`
- Test: `web/src/__tests__/useFilters.test.tsx` (describe `initial state`)

**Interfaces (depois):**
```ts
export interface SearchParams {
  query?: string;
  page?: number;
  limit?: number;
  tags?: string[];
  rhythm?: string[];
  tonality?: string[];
  materialKinds?: string[];
  numberMin?: number;
  numberMax?: number;
  sort?: SortField;
  order?: 'asc' | 'desc';
}

export const VALID_SORT_FIELDS = ['number', 'name', 'rhythm', 'tonality', 'author', 'created_at'] as const;
```

- [ ] **Step 1: testes**

(a) `web/src/__tests__/api.test.ts`, linhas 207-217: trocar
```ts
    it('should include category parameters', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve(mockResponse),
      });

      await searchPraises({ category: ['Louvor', 'Adoração'] });

      const url = new URL(mockFetch.mock.calls[0][0] as string);
      expect(url.searchParams.get('category')).toBe('Louvor,Adoração');
    });
```
por
```ts
    it('não manda category, mesmo que um chamador antigo passe', async () => {
      // O filtro «Categoria» foi aposentado (seções da Coletânea viraram subtags).
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve(mockResponse),
      });

      await searchPraises({ category: ['Louvor', 'Adoração'] } as never);

      const url = new URL(mockFetch.mock.calls[0][0] as string);
      expect(url.searchParams.has('category')).toBe(false);
    });
```

(b) No mesmo arquivo, describe `getFilterOptions`, logo depois do teste `should return filter options`, acrescentar:
```ts
    it('não manda category ao pedir as opções', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve(mockFilterOptions),
      });

      await getFilterOptions({ category: ['Louvor'], rhythm: ['Valsa'] } as never);

      const url = new URL(mockFetch.mock.calls[0][0] as string);
      expect(url.searchParams.has('category')).toBe(false);
      expect(url.searchParams.get('rhythm')).toBe('Valsa');
    });
```
O `mockFilterOptions` do describe, com `categories`, fica (Decisão 2).

(c) `web/src/__tests__/SortSelector.test.tsx`, linha 32: trocar
```ts
    expect(screen.getByRole('option', { name: 'Categoria' })).toBeTruthy();
```
por
```ts
    expect(screen.queryByRole('option', { name: 'Categoria' })).toBeNull();
```

(d) `web/src/__tests__/useFilters.test.tsx`, describe `initial state`, logo depois do teste `should parse sort and order from URL`, acrescentar:
```ts
    it('?sort=category de link antigo cai na ordenação padrão', () => {
      const { result } = renderHook(() => useFilters(), {
        wrapper: createWrapper('/?sort=category&order=desc'),
      });

      expect(result.current.filters.sort).toBe('number');
      expect(result.current.filters.order).toBe('desc');
    });
```

- [ ] **Step 2: rodar e ver falhar**

```bash
cd web && npx vitest run src/__tests__/api.test.ts src/__tests__/SortSelector.test.tsx src/__tests__/useFilters.test.tsx
```
Expected: FAIL em 4 testes:
- os dois «não manda category…», porque o `category` ainda vai na URL;
- `should render all sort options`, porque a opção Categoria ainda existe;
- «?sort=category de link antigo cai na ordenação padrão», porque `sort` ainda é `'category'`.

- [ ] **Step 3: `services/api.ts`**

(a) Em `SearchParams` (linhas 199-213), apagar
```ts
  category?: string[];
```
(b) Em `searchPraises`, apagar a linha 227
```ts
  if (params.category && params.category.length > 0) urlParams.set('category', params.category.join(','));
```
(c) Em `getFilterOptions`, apagar a linha 263
```ts
  if (params.category?.length) urlParams.set('category', params.category.join(','));
```

- [ ] **Step 4: `types/index.ts`**

(a) Em `VALID_SORT_FIELDS` (linhas 128-136), apagar
```ts
  'category',
```
(b) Em `SORT_OPTIONS`, apagar a linha
```ts
  { field: 'category', label: 'Categoria', ascending: { label: 'Categoria (A-Z)', order: 'asc' }, descending: { label: 'Categoria (Z-A)', order: 'desc' } },
```
A API segue aceitando `sort=category` (§3.4). O admin só deixa de oferecer a opção e de aceitá-la da URL.

- [ ] **Step 5: rodar e ver passar**

```bash
cd web && npx vitest run src/__tests__/api.test.ts src/__tests__/SortSelector.test.tsx src/__tests__/useFilters.test.tsx src/components/__tests__/FilterBar.facet.test.tsx
```
Expected: PASS, 4 arquivos, 0 falhas.

```bash
cd web && npx tsc -b && npx eslint .
```
Expected: sem saída e exit 0.

- [ ] **Step 6: commit**

```bash
git add web/src/services/api.ts web/src/types/index.ts web/src/__tests__/api.test.ts web/src/__tests__/SortSelector.test.tsx web/src/__tests__/useFilters.test.tsx
git commit -m "$(cat <<'EOF'
feat(web): busca e ordenação do admin sem categoria

searchPraises e getFilterOptions deixam de mandar category, e a opção
«Categoria (A-Z)» sai da ordenação. ?sort=category de link antigo cai
na ordenação por número, pela validação que já existia.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Ficha do louvor — campo, exibição e tags raiz

**Files:**
- Modify: `web/src/pages/PraiseDetailPage.tsx`:
  - `:87-97` (`camposDe`);
  - `:109-111` (comentário do rascunho);
  - `:204-212` (estado `edit`);
  - `:849-854` (`availableTags`);
  - `:1056-1065` (`createPraise`);
  - `:1170-1182` (`updatePraise`);
  - `:1410-1413` (input);
  - `:1482-1487` (exibição);
  - `:1561-1565` (aviso de catálogo esgotado).
- Modify: `web/src/services/api.ts:288-297` (`CreatePraiseInput`), `:311-313` (`updatePraise`)
- Test: `web/src/__tests__/PraiseDetailPage.test.tsx`:
  - depois do teste de `:170` (novo teste de exibição);
  - `:370-400` (`cria louvor ao salvar`);
  - `:1208-1223` (nomes acessíveis);
  - `:2287-2317` (describe de tags);
  - `:2224-2261` (edição dos metadados);
  - `:2580-2600` (campos vazios).

**Interfaces (depois):**
```ts
export type CreatePraiseInput = {
  name: string;
  number?: string | null;
  author?: string | null;
  rhythm?: string | null;
  tonality?: string | null;
  lyrics?: string | null;
  tag_ids?: string[];
};

export async function updatePraise(
  id: string,
  updates: Partial<Pick<Praise, 'name' | 'number' | 'author' | 'rhythm' | 'tonality' | 'lyrics'>>,
  ifUpdatedAt?: string
): Promise<PraiseDetail>;
```
`tagSelectOptions` (`PraiseDetailPage.tsx:859`) não muda. O que muda é a lista que o alimenta (`availableTags`): antes ela excluía toda tag com filhos, e agora exclui só as já associadas. `rootSelectOptions` e `criarEAssociarSubtag` não mudam.

- [ ] **Step 1: testes**

Todos em `web/src/__tests__/PraiseDetailPage.test.tsx`.

(a) Exibição. No describe `PraiseDetailPage Component`, logo depois do teste `should render praise details`, acrescentar:
```ts
  it('a ficha do louvor não mostra a categoria, mesmo que a API ainda a mande', async () => {
    // A seção da Coletânea virou subtag e aparece nas tags; `category` só
    // continua na resposta da API até a fase 3 do spec.
    (getPraise as ReturnType<typeof vi.fn>).mockResolvedValue(mockPraiseDetail);

    const { container } = renderWithRouter('1b2b33ab-4dff-4014-8582-dcb9a92efbc8');
    await screen.findByText('Grande Deus');

    const meta = container.querySelector('.detail-meta-row') as HTMLElement;
    expect(meta).toBeTruthy();
    expect(within(meta).queryByText('Categoria')).toBeNull();
    expect(within(meta).queryByText('Louvor')).toBeNull();
  });
```
O `mockPraiseDetail` tem `category: 'Louvor'` e continua tendo (Decisão 1).

(b) Criação. No teste `cria louvor ao salvar` (linhas 370-400), depois do `waitFor` final, acrescentar:
```ts
      expect(Object.keys(vi.mocked(createPraise).mock.calls[0][0])).not.toContain('category');
```

(c) Nomes acessíveis. No teste `cada campo de metadado tem nome acessível` (linhas 1208-1223), trocar
```ts
    for (const rotulo of ['Nome', 'Número', 'Autor', 'Ritmo', 'Tom', 'Categoria']) {
      expect(screen.getAllByLabelText(rotulo).length).toBeGreaterThan(0);
    }
```
por
```ts
    for (const rotulo of ['Nome', 'Número', 'Autor', 'Ritmo', 'Tom']) {
      expect(screen.getAllByLabelText(rotulo).length).toBeGreaterThan(0);
    }
    // «Categoria» ainda nomeia o seletor (um botão) da categoria do MATERIAL em
    // «Adicionar material»; o campo de texto da categoria do louvor saiu.
    expect(screen.queryByRole('textbox', { name: 'Categoria' })).toBeNull();
```

(d) Edição dos metadados. Trocar o teste inteiro das linhas 2224-2261 (`edita número, autor, ritmo, tom e categoria e salva tudo junto`) por:
```ts
  it('edita número, autor, ritmo e tom e salva tudo junto, sem categoria', async () => {
    (updatePraise as ReturnType<typeof vi.fn>).mockResolvedValue(mockPraiseDetail);
    const user = userEvent.setup();
    renderPraisePage('1b2b33ab-4dff-4014-8582-dcb9a92efbc8');
    await waitFor(() => expect(screen.getByRole('button', { name: 'Editar' })).toBeTruthy());
    await user.click(screen.getByRole('button', { name: 'Editar' }));

    await user.clear(screen.getByLabelText('Número'));
    await user.type(screen.getByLabelText('Número'), '099');
    await user.clear(screen.getByLabelText('Autor'));
    await user.type(screen.getByLabelText('Autor'), 'Outro Autor');
    await user.clear(screen.getByLabelText('Ritmo'));
    await user.type(screen.getByLabelText('Ritmo'), 'Coletânea');
    await user.clear(screen.getByLabelText('Tom'));
    await user.type(screen.getByLabelText('Tom'), 'D');

    await user.click(screen.getAllByRole('button', { name: 'Salvar' })[0]);

    await waitFor(() => {
      expect(updatePraise).toHaveBeenCalledWith(
        '1b2b33ab-4dff-4014-8582-dcb9a92efbc8',
        expect.objectContaining({
          number: '099',
          author: 'Outro Autor',
          rhythm: 'Coletânea',
          tonality: 'D',
        }),
        undefined
      );
    });
    // O PATCH não pode reescrever a categoria que o script de dados preserva
    // até a fase 3: a chave não vai, nem vazia.
    expect(Object.keys(vi.mocked(updatePraise).mock.calls[0][1])).not.toContain('category');
  });
```

(e) Campos vazios. No teste `campos vazios no louvor viram texto vazio no formulário de edição` (linhas 2580-2600), apagar a linha
```ts
    expect((screen.getAllByLabelText('Categoria')[0] as HTMLInputElement).value).toBe('');
```
O `category: null` de `praiseEsparso` fica.

(f) Tags. No describe `Tags: hint de catálogo esgotado e adição de tag existente` (linha 2287), trocar o teste `avisa quando não há tag disponível para adicionar` (linhas 2299-2317) por estes dois:
```ts
  it('avisa quando todas as tags do catálogo já estão no louvor', async () => {
    // Antes o aviso exigia também que o louvor não tivesse tag nenhuma — só
    // alcançável com um catálogo em que toda tag era pai de outra. Com as tags
    // raiz oferecidas (§3.2 do spec), o caso real é este: o louvor já tem todas.
    (getTags as ReturnType<typeof vi.fn>).mockResolvedValue([
      { id: 'tag1', name: 'Coletânea', parent_id: null },
      { id: 'tag2', name: 'Avulsos', parent_id: null },
    ]);
    const user = userEvent.setup();
    renderPraisePage('1b2b33ab-4dff-4014-8582-dcb9a92efbc8');
    await waitFor(() => expect(screen.getByRole('button', { name: 'Editar' })).toBeTruthy());
    await user.click(screen.getByRole('button', { name: 'Editar' }));

    expect(
      await screen.findByText('Todas as tags do catálogo já estão associadas.')
    ).toBeTruthy();
    expect(screen.queryByLabelText('Adicionar tag')).toBeNull();
  });

  it('oferece a tag raiz que tem subtags, além das subtags (§3.2)', async () => {
    // A trava «Cannot attach a parent tag» saiu da API: ligar direto à raiz
    // quer dizer «sem subtag específica». Antes a raiz com filhos sumia do
    // seletor, e `Avulsos` deixaria de poder ser marcada depois de ganhar `GLTM`.
    (getTags as ReturnType<typeof vi.fn>).mockResolvedValue([
      { id: 'tag1', name: 'Coletânea', parent_id: null },
      { id: 'tag1a', name: 'Clamor', parent_id: 'tag1' },
      { id: 'tag3', name: 'GLTM', parent_id: null },
    ]);
    const praiseSemTags: PraiseDetail = { ...mockPraiseDetail, tags: [], tag_ids: '' };
    (getPraise as ReturnType<typeof vi.fn>).mockResolvedValue(praiseSemTags);
    (addPraiseTag as ReturnType<typeof vi.fn>).mockResolvedValue({
      ...praiseSemTags,
      tags: [{ id: 'tag1', name: 'Coletânea', parent_id: null }],
    });
    const user = userEvent.setup();
    renderPraisePage('1b2b33ab-4dff-4014-8582-dcb9a92efbc8');
    await waitFor(() => expect(screen.getByRole('button', { name: 'Editar' })).toBeTruthy());
    await user.click(screen.getByRole('button', { name: 'Editar' }));

    await user.click(await screen.findByLabelText('Adicionar tag'));
    expect(screen.getByRole('option', { name: 'Coletânea · Clamor' })).toBeTruthy();
    await user.click(screen.getByRole('option', { name: 'Coletânea' }));
    await user.click(screen.getByRole('button', { name: 'Adicionar' }));

    await waitFor(() => {
      expect(addPraiseTag).toHaveBeenCalledWith('1b2b33ab-4dff-4014-8582-dcb9a92efbc8', 'tag1');
    });
  });
```

- [ ] **Step 2: rodar e ver falhar**

```bash
cd web && npx vitest run src/__tests__/PraiseDetailPage.test.tsx
```
Expected: FAIL em 6 testes:
- «a ficha do louvor não mostra a categoria…»;
- «cria louvor ao salvar», porque a chave `category` vai no corpo;
- «cada campo de metadado tem nome acessível», porque ainda existe um textbox «Categoria»;
- «edita número, autor, ritmo e tom…», porque a chave `category` vai no PATCH;
- «avisa quando todas as tags do catálogo já estão no louvor», porque o aviso não aparece com tags no louvor;
- «oferece a tag raiz que tem subtags…», porque a opção `Coletânea` não existe.

- [ ] **Step 3: `services/api.ts`**

(a) Em `CreatePraiseInput` (linhas 288-297), apagar
```ts
  category?: string | null;
```
(b) Na assinatura de `updatePraise` (linha 313), trocar
```ts
  updates: Partial<Pick<Praise, 'name' | 'number' | 'author' | 'rhythm' | 'tonality' | 'category' | 'lyrics'>>,
```
por
```ts
  updates: Partial<Pick<Praise, 'name' | 'number' | 'author' | 'rhythm' | 'tonality' | 'lyrics'>>,
```

- [ ] **Step 4: `PraiseDetailPage.tsx`**

(a) Em `camposDe` (linha 94), apagar
```ts
    category: p.category || '',
```
(b) No comentário do rascunho (linhas 109-111), trocar
```ts
 * na volta, e tudo que estava digitado — nome, número, autor, ritmo, tom,
 * categoria, letra, tags escolhidas e o próprio link colado — voltava em branco.
```
por
```ts
 * na volta, e tudo que estava digitado — nome, número, autor, ritmo, tom,
 * letra, tags escolhidas e o próprio link colado — voltava em branco.
```
(c) No estado `edit` (linhas 204-212), apagar a linha
```ts
    category: '',
```
do objeto inicial de `useState({ name: '', number: '', author: '', rhythm: '', tonality: '', category: '', lyrics: '' })`. Mexer só no bloco do `useState` de `edit`: `NewMaterialForm` e outros estados têm campos próprios.

(d) `availableTags` (linhas 849-854): trocar
```ts
  const availableTags = useMemo(() => {
    const childParentIds = new Set(
      catalogTags.filter((t) => t.parent_id).map((t) => t.parent_id as string)
    );
    return catalogTags.filter((t) => !assignedTagIds.has(t.id) && !childParentIds.has(t.id));
  }, [catalogTags, assignedTagIds]);
```
por
```ts
  // Tag raiz com subtags também é oferecida: ligar direto à raiz quer dizer «sem
  // subtag específica», e a API deixou de recusar (spec das seções da Coletânea, §3.2).
  const availableTags = useMemo(
    () => catalogTags.filter((t) => !assignedTagIds.has(t.id)),
    [catalogTags, assignedTagIds]
  );
```
(e) Em `createPraise` (linha 1062), apagar
```ts
            category: edit.category || null,
```
(f) Em `updatePraise` (linha 1179), apagar
```ts
              category: edit.category,
```
(g) No formulário (linhas 1410-1413), apagar o bloco
```tsx
            <label className="edit-field">
              <span className="edit-field-label">Categoria</span>
              <input value={edit.category} onChange={(e) => setEdit(s => ({ ...s, category: e.target.value }))} />
            </label>
```
(h) Na ficha (linhas 1482-1487), apagar o bloco
```tsx
            {praise.category && (
            <div className="detail-meta-item">
              <span className="label">Categoria</span>
              <span className="value">{praise.category}</span>
            </div>
            )}
```
(i) Aviso de catálogo esgotado (linhas 1561-1565): trocar
```tsx
            ) : (
              displayTags.length === 0 && catalogTags.length > 0
                ? <span className="detail-tags-hint muted">Todas as tags do catálogo já estão associadas.</span>
                : null
            )}
```
por
```tsx
            ) : (
              catalogTags.length > 0
                ? <span className="detail-tags-hint muted">Todas as tags do catálogo já estão associadas.</span>
                : null
            )}
```
`displayTags` continua sendo usado na lista de tags e fica.

- [ ] **Step 5: rodar e ver passar**

```bash
cd web && npx vitest run src/__tests__/PraiseDetailPage.test.tsx src/__tests__/api.extra.test.ts
```
Expected: PASS, 2 arquivos, 0 falhas. Entre os que passam, os testes da categoria do material seguem inalterados:
- «Catálogo de categorias indisponível»;
- «exibe edição inline de categoria…»;
- «troca a categoria de um material existente…»;
- «Edição de categoria — em breve».

Também passa «devolve o rascunho ao voltar da autorização», com um rascunho antigo que tem `category`.

```bash
cd web && npx tsc -b && npx eslint .
```
Expected: sem saída e exit 0.

- [ ] **Step 6: commit**

```bash
git add web/src/pages/PraiseDetailPage.tsx web/src/services/api.ts web/src/__tests__/PraiseDetailPage.test.tsx
git commit -m "$(cat <<'EOF'
feat(web): ficha do louvor sem categoria e com tags raiz no seletor

O campo Categoria sai da edição, da criação, do PATCH e da ficha: a
seção da Coletânea é uma subtag. O seletor de tags passa a oferecer a
tag raiz que tem subtags, que a API voltou a aceitar, e o aviso de
catálogo esgotado passa a valer quando o louvor já tem todas as tags.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Merge — sem `metadata.category` e sem trava de tag pai

**Files:**
- Modify: `web/src/pages/PraiseMergeImportPage.tsx`:
  - `:15` (`MetaField`);
  - `:17-25` (`META_FIELDS`);
  - `:62-65` (comentário do catálogo);
  - `:125-154` (trava de tag pai);
  - `:158-166` (`resolvedMetadata`);
  - `:326-347` (lista de tags);
  - `:350-358` (aviso);
  - `:502` (botão).
- Modify: `web/src/services/api.ts:613-625` (`MergePraisesInput`)
- Test: `web/src/__tests__/PraiseMergeImportPage.test.tsx:148-171`, `:277-305`, novo teste
- Test: `web/src/__tests__/api.extra.test.ts:182`

**Interfaces (depois):**
```ts
export type MergePraisesInput = {
  source_praise_id: string;
  metadata: {
    name: string;
    number: string | null;
    author: string | null;
    rhythm: string | null;
    tonality: string | null;
    lyrics: string | null;
  };
  tag_ids: string[];
  material_ids_to_import: string[];
};
```
Sem a chave `category` no corpo, a API (spec §3.3) não mexe na categoria do louvor que fica.

- [ ] **Step 1: testes**

Em `web/src/__tests__/PraiseMergeImportPage.test.tsx`:

(a) No teste `finalizar manda metadados e tags resolvidos, não só os ids` (linhas 148-171), trocar
```ts
    expect(corpo.metadata).toEqual({
      name: 'Grande Deus',
      number: '001',
      author: 'Autor A',
      rhythm: 'Avulsos',
      tonality: 'C',
      category: 'Louvor',
      lyrics: 'Letra A',
    });
```
por
```ts
    // Sem `category`: a chave ausente faz a API não mexer na categoria (§3.3).
    expect(corpo.metadata).toEqual({
      name: 'Grande Deus',
      number: '001',
      author: 'Autor A',
      rhythm: 'Avulsos',
      tonality: 'C',
      lyrics: 'Letra A',
    });
```

(b) Logo depois desse teste, acrescentar:
```ts
  it('a seção de metadados não tem mais a linha Categoria', async () => {
    // keeper e fonte ainda trazem categorias diferentes (Louvor × Adoração),
    // como a API manda até a fase 3; antes isso virava uma linha de conflito.
    renderMergeImport();
    await esperarCarregar();

    expect(within(secao('Metadados')).queryByText('Categoria')).toBeNull();
  });
```

(c) Trocar o teste `tag de agrupamento vinda do louvor fonte é apontada e trava a finalização` (linhas 277-305) por:
```ts
  it('tag raiz com subtags vinda do louvor fonte é aceita sem aviso (§3.2)', async () => {
    // A API deixou de recusar a ligação com tag que tem filhos: a raiz ligada
    // direto quer dizer «sem subtag específica». A trava antiga bloquearia toda
    // mesclagem com `Avulsos` depois de ela ganhar `GLTM`.
    const user = userEvent.setup();
    vi.mocked(getTags).mockResolvedValue([
      ...CATALOGO,
      { id: 'tag2a', name: '2026', parent_id: 'tag2' },
    ]);
    (getPraise as ReturnType<typeof vi.fn>).mockImplementation(async (id: string) => {
      if (id === keeperId) return keeper;
      if (id === sourceId) {
        return { ...source, tags: [...source.tags, { id: 'tag2a', name: '2026', parent_id: 'tag2' }] };
      }
      throw new Error('not found');
    });

    renderMergeImport();
    await esperarCarregar();
    // O rótulo «pai · filho» da subtag sem parent_name só sai com o catálogo
    // carregado: daqui em diante, a trava antiga já teria aparecido.
    expect(await screen.findByText('Avulsos · 2026')).toBeTruthy();

    expect(screen.queryByText(/agrupa subtags/i)).toBeNull();
    expect(screen.queryByText('agrupamento')).toBeNull();
    expect(screen.getByRole('button', { name: 'Finalizar mesclagem' })).toBeEnabled();

    await user.click(screen.getByRole('button', { name: 'Finalizar mesclagem' }));
    await waitFor(() => expect(mergePraises).toHaveBeenCalled());
    expect([...vi.mocked(mergePraises).mock.calls[0][1].tag_ids].sort()).toEqual(['tag1', 'tag2', 'tag2a']);
  });
```
Os testes `tag de agrupamento que o louvor que sobrevive já tinha não trava nada` e `catálogo de tags indisponível não impede a mesclagem` ficam como estão; os dois continuam passando.

(d) `web/src/__tests__/api.extra.test.ts`, linha 182: trocar
```ts
      metadata: { name: 'X', number: null, author: null, rhythm: null, tonality: null, category: null, lyrics: null },
```
por
```ts
      metadata: { name: 'X', number: null, author: null, rhythm: null, tonality: null, lyrics: null },
```
Isso é só adaptação ao tipo. O `mockPraiseDetail` do arquivo, com `category: null`, fica.

- [ ] **Step 2: rodar e ver falhar**

```bash
cd web && npx vitest run src/__tests__/PraiseMergeImportPage.test.tsx
```
Expected: FAIL em 3 testes:
- «finalizar manda metadados…», porque o `toEqual` estrito acha a chave `category`;
- «a seção de metadados não tem mais a linha Categoria»;
- «tag raiz com subtags vinda do louvor fonte é aceita sem aviso (§3.2)», porque o aviso «agrupa subtags» aparece e o botão fica desabilitado.

- [ ] **Step 3: `services/api.ts`**

Em `MergePraisesInput.metadata` (linha 621), apagar
```ts
    category: string | null;
```

- [ ] **Step 4: `PraiseMergeImportPage.tsx`**

(a) Linha 15: trocar
```ts
type MetaField = 'name' | 'number' | 'author' | 'rhythm' | 'tonality' | 'category' | 'lyrics';
```
por
```ts
type MetaField = 'name' | 'number' | 'author' | 'rhythm' | 'tonality' | 'lyrics';
```
(b) Em `META_FIELDS`, apagar a linha
```ts
  { key: 'category', label: 'Categoria' },
```
(c) Comentário do efeito de `getTags` (linhas 62-65): trocar
```ts
  // O catálogo inteiro é o único jeito de saber, no cliente, que uma tag tem
  // filhos: o louvor traz `parent_id` da própria tag, não a lista de subtags.
  // Falhar aqui não pode travar a mesclagem — sem catálogo a tela só perde o
  // aviso e volta a ser o que era.
```
por
```ts
  // O catálogo dá o nome do pai das subtags que chegam sem `parent_name`, para a
  // lista mostrar «Pai · Filho». Falhar aqui não pode travar a mesclagem — sem
  // catálogo a lista só mostra o nome curto.
```
(d) Apagar o bloco inteiro das linhas 125-154, de
```ts
  /** Ids de tags que agrupam subtags — o servidor recusa anexar qualquer uma. */
  const tagIdsDeAgrupamento = useMemo(
```
até o fim de `tagsQueBloqueiam`, inclusive:
```ts
    [allTags, selectedTagIds, tagIdsDeAgrupamento, tagIdsDoKeeper]
  );
```
Isso inclui `tagIdsDoKeeper` e o comentário «Basta alguém criar uma subtag de «Coral»…». Deixar uma única linha em branco entre o `allTags` e o `resolvedMetadata`.

(e) Em `resolvedMetadata`, apagar a linha
```ts
      category: null,
```
(f) Lista de tags (linhas 326-347): trocar
```tsx
          {allTags.map((tag) => {
            const agrupamento = tagIdsDeAgrupamento.has(tag.id);
            return (
              <label key={tag.id} className="merge-tag-check">
                <input
                  type="checkbox"
                  checked={selectedTagIds.has(tag.id)}
                  onChange={(e) => {
                    setSelectedTagIds((prev) => {
                      const next = new Set(prev);
                      if (e.target.checked) next.add(tag.id);
                      else next.delete(tag.id);
                      return next;
                    });
                  }}
                />
                {tagLabel(tag, catalogTags)}
                {agrupamento ? <span className="pill">agrupamento</span> : null}
              </label>
            );
          })}
```
por
```tsx
          {allTags.map((tag) => (
            <label key={tag.id} className="merge-tag-check">
              <input
                type="checkbox"
                checked={selectedTagIds.has(tag.id)}
                onChange={(e) => {
                  setSelectedTagIds((prev) => {
                    const next = new Set(prev);
                    if (e.target.checked) next.add(tag.id);
                    else next.delete(tag.id);
                    return next;
                  });
                }}
              />
              {tagLabel(tag, catalogTags)}
            </label>
          ))}
```
(g) Apagar o aviso (linhas 350-358):
```tsx
        {tagsQueBloqueiam.length > 0 ? (
          <div className="error-state" style={{ marginTop: '0.75rem' }}>
            <div className="error-state-desc">
              {tagsQueBloqueiam.length === 1
                ? `A tag «${tagsQueBloqueiam[0].name}» agrupa subtags e não pode ser anexada: desmarque-a, ou marque uma subtag dela.`
                : `As tags «${tagsQueBloqueiam.map((t) => t.name).join('», «')}» agrupam subtags e não podem ser anexadas: desmarque-as, ou marque subtags delas.`}
            </div>
          </div>
        ) : null}
```
(h) Botão (linha 502): trocar
```tsx
          disabled={saving || !resolvedMetadata?.name || tagsQueBloqueiam.length > 0}
```
por
```tsx
          disabled={saving || !resolvedMetadata?.name}
```
O `aria-label="Categoria do material"` das linhas 396 e 483 é a categoria do **material** e fica.

- [ ] **Step 5: rodar e ver passar**

```bash
cd web && npx vitest run src/__tests__/PraiseMergeImportPage.test.tsx src/__tests__/PraiseMergeSelectPage.test.tsx src/__tests__/api.extra.test.ts
```
Expected: PASS, 3 arquivos, 0 falhas. Isso inclui «trocar a categoria de um material salva na hora», que é a categoria do material e fica intacta.

```bash
cd web && npx tsc -b && npx eslint .
```
Expected: sem saída e exit 0. Se o `tsc` acusar `useMemo` ou `Tag` sem uso, não é o caso: os dois seguem usados por `allTags`, `resolvedMetadata` e `tagLabel`. Conferir antes de apagar qualquer import.

- [ ] **Step 6: commit**

```bash
git add web/src/pages/PraiseMergeImportPage.tsx web/src/services/api.ts web/src/__tests__/PraiseMergeImportPage.test.tsx web/src/__tests__/api.extra.test.ts
git commit -m "$(cat <<'EOF'
feat(web): merge sem categoria e sem trava de tag pai

A linha Categoria sai dos metadados e o corpo do merge deixa de mandar
metadata.category; a API, sem a chave, não mexe na categoria. A trava
que impedia anexar tag raiz com subtags sai junto: a API passou a
aceitar, e depois da migração ela bloquearia todo merge com Coletânea
ou Avulsos.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: `FindingEvidence`, tipo `Praise` e verificação final

**Files:**
- Modify: `web/src/components/FindingEvidence.tsx:59`
- Modify: `web/src/types/index.ts:3-15` (`Praise`)
- Test: `web/src/components/__tests__/FindingEvidence.test.tsx:1-2`, novo teste depois de `merge_praise: busca fonte e keeper e mostra os dois lado a lado`

**Interfaces (depois):**
```ts
export interface Praise {
  id: string;
  name: string;
  number: string;
  author: string;
  rhythm: string;
  tonality: string;
  /**
   * Aposentado: as seções da Coletânea viraram subtags. A API ainda manda até a
   * fase 3 do spec (depois, '' ou null); o admin não lê nem escreve.
   */
  category?: string | null;
  lyrics: string;
  group_id: string | null;
  tag_ids: string | null;
  tag_names: string | null;
}
```

- [ ] **Step 1: teste**

Em `web/src/components/__tests__/FindingEvidence.test.tsx`:

(a) Linha 2: trocar
```ts
import { render, screen } from '@testing-library/react';
```
por
```ts
import { render, screen, waitFor } from '@testing-library/react';
```
(b) Depois do teste `merge_praise: busca fonte e keeper e mostra os dois lado a lado`, acrescentar:
```ts
  it('merge_praise: não mostra a categoria, mesmo que a API ainda a mande', async () => {
    vi.mocked(getPraise).mockImplementation(async (id: string) => ({
      id, name: id === 'p-fonte' ? 'Medo tens' : 'Medo tens que o tentador', number: '',
      author: '', rhythm: '', tonality: '', category: 'Consolo e Encorajamento', lyrics: '',
      group_id: null, tag_ids: null, tag_names: 'Coletânea · Consolo e Encorajamento', materials: [],
    }) as never);
    render(<FindingEvidence finding={BASE} />);

    // As duas colunas carregadas: a seção aparece como subtag, uma vez em cada.
    await waitFor(() =>
      expect(screen.getAllByText('Coletânea · Consolo e Encorajamento')).toHaveLength(2)
    );
    expect(screen.queryAllByText('Consolo e Encorajamento')).toHaveLength(0);
  });
```

- [ ] **Step 2: rodar e ver falhar**

```bash
cd web && npx vitest run src/components/__tests__/FindingEvidence.test.tsx
```
Expected: FAIL no teste novo, porque aparecem 2 spans com «Consolo e Encorajamento».

- [ ] **Step 3: implementação**

(a) `web/src/components/FindingEvidence.tsx`, linha 59: apagar
```tsx
            {estado.praise.category && <span>{estado.praise.category}</span>}
```
(b) `web/src/types/index.ts`, em `Praise` (linha 10): trocar
```ts
  category: string;
```
por
```ts
  /**
   * Aposentado: as seções da Coletânea viraram subtags. A API ainda manda até a
   * fase 3 do spec (depois, '' ou null); o admin não lê nem escreve.
   */
  category?: string | null;
```

- [ ] **Step 4: rodar e ver passar**

```bash
cd web && npx vitest run src/components/__tests__/FindingEvidence.test.tsx
```
Expected: PASS, 1 arquivo, 0 falhas.

- [ ] **Step 5: auditoria por grep**

```bash
grep -rn "category" web/src --include='*.ts' --include='*.tsx' | grep -v __tests__
```
Expected: só estas linhas.
- `web/src/types/index.ts`: o `category?: string | null` de `Praise` e o `categories?: string[]` de `FilterOptions`, com os comentários deles.
- `web/src/hooks/useFilters.ts`: o comentário «`?category=` era o filtro…» e `newParams.delete('category');`.

Qualquer outra ocorrência é resto da remoção. Voltar à tarefa que a deixou.

```bash
grep -rn "Categoria" web/src --include='*.ts' --include='*.tsx' | grep -v __tests__
```
Expected: só a categoria do **material**:
- `MaterialInlineAdmin.tsx` («Categoria do material»);
- `BulkFilePreviewList.tsx` («Categoria do material»);
- `BulkFolderScanStatus.tsx` («Categoria não identificada pelo nome»);
- `SecaoGestos.tsx` (`Categoria` do select de gestos);
- `ChordProPage.tsx` (`PanelRow label="Categoria"`);
- `PraiseDetailPage.tsx`: «Edição de categoria — em breve» (duas vezes) e `label="Categoria"` do `new-mat-kind`;
- `PraiseMergeImportPage.tsx` («Categoria do material», duas vezes).

- [ ] **Step 6: suíte inteira, tipos, lint, build e cobertura**

```bash
pkill -f vitest; cd web && npx vitest run
```
Expected: **73 arquivos, 970 testes** (963 da base + 7 novos), 0 falhas. Os 7 novos:
- «?category= de link antigo não vira marca de filtro» (Task 1);
- «não manda category ao pedir as opções» e «?sort=category de link antigo cai na ordenação padrão» (Task 2);
- «a ficha do louvor não mostra a categoria…» e «oferece a tag raiz que tem subtags…» (Task 3);
- «a seção de metadados não tem mais a linha Categoria» (Task 4);
- «merge_praise: não mostra a categoria…» (Task 5).

Se o total diferir, conferir contra esta lista antes de seguir.

```bash
cd web && npx tsc -b && npx eslint . && npm run build
```
Expected: `tsc` e `eslint` sem saída; `vite build` termina com `✓ built in …`.

```bash
pkill -f vitest; cd web && npm run test:coverage
```
Expected: exit 0, sem «ERROR: Coverage for … does not meet global threshold». A catraca de `web/vitest.config.ts` é 91 / 83 / 90 / 94. Este plano só remove código e acrescenta testes, então a catraca não deve cair. Se cair, olhar a tabela de cobertura dos arquivos tocados antes de mexer em qualquer limite; limite não se abaixa.

- [ ] **Step 7: commit**

```bash
git add web/src/components/FindingEvidence.tsx web/src/types/index.ts web/src/components/__tests__/FindingEvidence.test.tsx
git commit -m "$(cat <<'EOF'
feat(web): FindingEvidence sem categoria; Praise.category opcional

A comparação do merge_praise deixa de exibir a categoria: a seção já
aparece nas tags. Praise.category fica no tipo, opcional e sem leitor,
porque a API ainda manda o campo até a fase 3.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 8: estado final**

```bash
git status --short
git log --oneline -6
```
Expected:
- `git status` sem nada em `web/`;
- os 5 commits deste plano no topo da branch, em ordem: filtro, busca/ordenação, ficha, merge, FindingEvidence.

Commits dos planos da API ou do script podem estar intercalados. Sem push.

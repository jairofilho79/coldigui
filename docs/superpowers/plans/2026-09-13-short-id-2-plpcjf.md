# shortId — Plano 2/3: `plpcjf` (PLPCG original) lê e emite o link curto

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** O site `plpcg.com` (SvelteKit, repo `/Volumes/SSD 2TB SD/dev/plpcjf`) passa a **ler** links `?s=<shortIds>&n=<nome>` e a **emitir** esse formato sempre que todos os PDFs da lista têm `shortId` no catálogo; caso contrário continua emitindo o link legado `?sharepdfs=…&sharename=…`.

**Architecture:** Toda a lógica pura fica em `src/lib/utils/playlistShare.js` (encode/parse/resolve/strip) e é testada com `node --test`; `playlistUtils.generatePlaylistShareUrl` decide o formato e ganha o catálogo como terceiro argumento; `routes/+page.svelte` trata `s` antes de `sharepdfs` no mesmo fluxo de import. O catálogo já carrega `shortId` porque a normalização do store usa spread.

**Tech Stack:** SvelteKit (Svelte 4, JS + JSDoc), `node --test`, `svelte-check`.

**Spec:** `docs/superpowers/specs/2026-09-13-short-id-share-design.md` (§1 contrato, §3, §5 passo 3) — caminho relativo ao repo coldigui; copie o §1 para a cabeça de `playlistShare.js` como comentário, porque o plpcjf não vê a spec.

## Global Constraints

- Contrato §1: `s` = tokens `[0-9a-f]{4,8}` separados por `-`, minúsculos na emissão; leitura normaliza maiúsculas e **ignora** token fora do padrão ou desconhecido; `n` obrigatório (`encodeURIComponent`); `s` presente ⇒ ignorar params legados; `stripShareParams` remove `s` e `n` também.
- `shortId` é string; comparação textual; `"0000"` é válido. Nunca `Number()`/`parseInt`.
- Emite curto **só** quando todo `pdfId` da lista resolve para um `shortId` (D7). Senão, legado inalterado.
- Repo: branch `feat/short-id-share` a partir de `main`. Testes: `npm test` (todos os `*.test.js` sob `src/`), `npm run check`.
- Commits terminam com as duas linhas de atribuição da sessão.

---

## Mapa de arquivos

- Modify: `src/lib/utils/playlistShare.js` — novas funções puras (+ contrato no cabeçalho)
- Modify: `src/lib/utils/playlistShare.test.js` — casos novos
- Modify: `src/lib/utils/playlistShare.contrato.test.js` — vetores do contrato §1 (espelhados no v2)
- Modify: `src/lib/utils/playlistUtils.js:52-65` — `generatePlaylistShareUrl(pdfIds, nome, louvores)`
- Modify: `src/lib/components/CarouselChips.svelte:5-19, 538, 627` — importa `louvores`, passa `$louvores`
- Modify: `src/routes/listas/+page.svelte:220` — passa `$louvores`
- Modify: `src/routes/+page.svelte:219-262` — import por `s`
- Modify: `src/lib/stores/louvores.js` — só teste: garantir que `shortId` sobrevive a `prepareLouvoresManifestPayload`

---

### Task 1: Branch + funções puras de `s` em `playlistShare.js`

**Files:**
- Modify: `src/lib/utils/playlistShare.js`
- Modify: `src/lib/utils/playlistShare.test.js`

**Interfaces (Produces):**
```js
export const SHORT_SHARE_PARAM = 's';          // ids
export const SHORT_SHARE_NAME_PARAM = 'n';     // nome
export function isShortId(value): boolean                     // string [0-9a-f]{4,8}
export function encodeShortShareIds(shortIds: string[]): string   // 'a-b-c' (minúsculo; ignora inválidos)
export function parseShortShareIds(param: string|null|undefined): string[]  // válidos, minúsculos, ordem
export function resolveShortIds(shortIds: string[], louvores: Array<{pdfId?, shortId?}>): string[] // pdfIds conhecidos, ordem, dedupe
export function shortIdsForPdfIds(pdfIds: string[], louvores): string[] | null // null se algum não tem shortId
```
`stripShareParams(search)` passa a remover `s` e `n`.

- [ ] **Step 1: Branch**

Run: `cd "/Volumes/SSD 2TB SD/dev/plpcjf" && git status --short | grep -v '^??' ; git checkout -b feat/short-id-share main`
Expected: nada rastreado modificado (os `??` de `.wrangler/`/`.claude/` são lixo local); branch criada.

- [ ] **Step 2: Testes que falham**

Acrescentar ao fim de `src/lib/utils/playlistShare.test.js`:
```js
import {
  encodeShortShareIds,
  isShortId,
  parseShortShareIds,
  resolveShortIds,
  shortIdsForPdfIds
} from './playlistShare.js';

const CATALOGO = [
  { pdfId: ID_CIFRA, shortId: '0000', nome: 'A' },
  { pdfId: ID_GESTOS, shortId: '1a2f', nome: 'B' },
  { pdfId: 'sem-short', nome: 'C' }
];

describe('isShortId', () => {
  it('aceita 4 a 8 hex minúsculos, inclusive "0000"', () => {
    assert.equal(isShortId('0000'), true);
    assert.equal(isShortId('1a2f'), true);
    assert.equal(isShortId('10000'), true);
  });
  it('recusa número, maiúscula, curto, longo, vazio', () => {
    assert.equal(isShortId(0), false);
    assert.equal(isShortId('1A2F'), false);
    assert.equal(isShortId('abc'), false);
    assert.equal(isShortId('123456789'), false);
    assert.equal(isShortId(''), false);
  });
});

describe('encodeShortShareIds / parseShortShareIds', () => {
  it('ida e volta preserva ordem, repetição e zeros à esquerda', () => {
    const s = encodeShortShareIds(['0000', '1a2f', '0000']);
    assert.equal(s, '0000-1a2f-0000');
    const url = new URL(`https://plpcg.com/?s=${s}&n=x`);
    assert.deepEqual(parseShortShareIds(url.searchParams.get('s')), ['0000', '1a2f', '0000']);
  });
  it('emite minúsculo e descarta inválidos', () => {
    assert.equal(encodeShortShareIds(['00AB', 'zz', '', 7]), '00ab');
  });
  it('leitura normaliza maiúsculas e ignora tokens fora do padrão', () => {
    assert.deepEqual(parseShortShareIds('00AB-zz--1a2f-123456789'), ['00ab', '1a2f']);
  });
  it('param ausente ou vazio → []', () => {
    assert.deepEqual(parseShortShareIds(null), []);
    assert.deepEqual(parseShortShareIds(''), []);
  });
});

describe('resolveShortIds', () => {
  it('resolve para pdfIds na ordem pedida, ignorando desconhecidos', () => {
    assert.deepEqual(resolveShortIds(['1a2f', 'ffff', '0000'], CATALOGO), [ID_GESTOS, ID_CIFRA]);
  });
  it('deduplica como resolveKnownPdfIds (a lista salva não repete)', () => {
    assert.deepEqual(resolveShortIds(['0000', '0000'], CATALOGO), [ID_CIFRA]);
  });
  it('compara como string: "0000" não casa com 0', () => {
    assert.deepEqual(resolveShortIds(['0000'], [{ pdfId: 'x', shortId: 0 }]), []);
  });
});

describe('shortIdsForPdfIds', () => {
  it('devolve os shortIds na ordem quando todos existem', () => {
    assert.deepEqual(shortIdsForPdfIds([ID_GESTOS, ID_CIFRA], CATALOGO), ['1a2f', '0000']);
  });
  it('null se algum pdfId não tem shortId ou não está no catálogo', () => {
    assert.equal(shortIdsForPdfIds([ID_CIFRA, 'sem-short'], CATALOGO), null);
    assert.equal(shortIdsForPdfIds([ID_CIFRA, 'nunca-vi'], CATALOGO), null);
  });
  it('lista vazia → null (não há o que encurtar)', () => {
    assert.equal(shortIdsForPdfIds([], CATALOGO), null);
  });
});

describe('stripShareParams com o formato curto', () => {
  it('remove s e n e preserva o resto', () => {
    assert.equal(stripShareParams('?s=0000-1a2f&n=Culto&utm_source=wa'), '?utm_source=wa');
    assert.equal(stripShareParams('?s=0000&n=x'), '');
  });
});
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `node --test src/lib/utils/playlistShare.test.js`
Expected: FAIL — `does not provide an export named 'encodeShortShareIds'`.

- [ ] **Step 4: Implementar**

No cabeçalho de `src/lib/utils/playlistShare.js`, acrescentar ao comentário do módulo:
```js
 *
 * ## Formato curto (2026-09 — contrato compartilhado com o app v2)
 *
 *   `{origin}/?s=1a2f-0c3d-ffe1&n=Culto%20de%20domingo`
 *
 * - `s`: `shortId`s (string hex minúscula, `[0-9a-f]{4,8}`, "0000" é válido)
 *   separados por `-`, na ordem da lista; repetidos permitidos.
 * - `n`: nome da lista (`encodeURIComponent`). Obrigatório — marca a URL como share.
 * - Leitura: normaliza maiúsculas; token inválido ou desconhecido é ignorado;
 *   `s` presente vence os params legados. Nunca converter `shortId` em número.
 * - Emissão: só quando TODOS os pdfIds têm `shortId` no catálogo; senão, legado.
```

Depois de `resolveKnownPdfIds`, acrescentar:
```js
export const SHORT_SHARE_PARAM = 's';
export const SHORT_SHARE_NAME_PARAM = 'n';
const SHORT_ID_PATTERN = /^[0-9a-f]{4,8}$/;

/**
 * `shortId` válido: string hex minúscula de 4 a 8 caracteres.
 * @param {unknown} value
 * @returns {value is string}
 */
export function isShortId(value) {
  return typeof value === 'string' && SHORT_ID_PATTERN.test(value);
}

/**
 * Serializa os shortIds para `s=`. Minúsculo; ignora o que não é shortId.
 * @param {unknown[]} shortIds
 * @returns {string}
 */
export function encodeShortShareIds(shortIds) {
  if (!Array.isArray(shortIds)) return '';
  return shortIds
    .map((id) => (typeof id === 'string' ? id.toLowerCase() : id))
    .filter(isShortId)
    .join('-');
}

/**
 * Lê `s=` já decodificado por `URLSearchParams.get`. Normaliza maiúsculas,
 * ignora tokens fora do padrão, preserva ordem e repetições.
 * @param {string | null | undefined} param
 * @returns {string[]}
 */
export function parseShortShareIds(param) {
  if (typeof param !== 'string' || param === '') return [];
  return param
    .split('-')
    .map((token) => token.trim().toLowerCase())
    .filter(isShortId);
}

/**
 * `shortId → pdfId` pelo catálogo, na ordem pedida, sem repetição (a lista
 * salva não repete, como em `resolveKnownPdfIds`). Desconhecido é ignorado.
 * Comparação textual: um `shortId` numérico no catálogo não casa.
 * @param {string[]} shortIds
 * @param {Array<{pdfId?: string, shortId?: unknown}>} louvores
 * @returns {string[]}
 */
export function resolveShortIds(shortIds, louvores) {
  if (!Array.isArray(shortIds) || !Array.isArray(louvores)) return [];
  const porShortId = new Map();
  for (const louvor of louvores) {
    if (louvor && isShortId(louvor.shortId) && typeof louvor.pdfId === 'string') {
      porShortId.set(louvor.shortId, louvor.pdfId);
    }
  }
  const vistos = new Set();
  const pdfIds = [];
  for (const shortId of shortIds) {
    const pdfId = porShortId.get(shortId);
    if (pdfId === undefined || vistos.has(pdfId)) continue;
    vistos.add(pdfId);
    pdfIds.push(pdfId);
  }
  return pdfIds;
}

/**
 * `pdfId → shortId` para emissão. `null` se a lista está vazia ou se algum
 * pdfId não tem shortId — aí o link tem de sair no formato legado.
 * @param {string[]} pdfIds
 * @param {Array<{pdfId?: string, shortId?: unknown}>} louvores
 * @returns {string[] | null}
 */
export function shortIdsForPdfIds(pdfIds, louvores) {
  if (!Array.isArray(pdfIds) || pdfIds.length === 0 || !Array.isArray(louvores)) return null;
  const porPdfId = new Map();
  for (const louvor of louvores) {
    if (louvor && typeof louvor.pdfId === 'string' && isShortId(louvor.shortId)) {
      porPdfId.set(louvor.pdfId, louvor.shortId);
    }
  }
  const shortIds = [];
  for (const pdfId of pdfIds) {
    const shortId = porPdfId.get(pdfId);
    if (shortId === undefined) return null;
    shortIds.push(shortId);
  }
  return shortIds;
}
```

E em `stripShareParams`, após `params.delete('sharename');`:
```js
  params.delete(SHORT_SHARE_PARAM);
  params.delete(SHORT_SHARE_NAME_PARAM);
```
(as constantes precisam estar declaradas **antes** de `stripShareParams` no arquivo — mova a declaração das duas `const` para logo abaixo dos imports/cabeçalho.)

- [ ] **Step 5: Rodar**

Run: `node --test src/lib/utils/playlistShare.test.js`
Expected: PASS em todos (antigos + novos).

- [ ] **Step 6: Commit**

```bash
git add src/lib/utils/playlistShare.js src/lib/utils/playlistShare.test.js
git commit -m "feat(share): formato curto ?s=&n= — encode/parse/resolve por shortId e limpeza da URL"
```

---

### Task 2: `generatePlaylistShareUrl` decide curto × legado

**Files:**
- Modify: `src/lib/utils/playlistUtils.js:52-65`
- Modify: `src/lib/utils/playlistShare.contrato.test.js`
- Modify: `src/lib/components/CarouselChips.svelte:5-19, 538, 627`
- Modify: `src/routes/listas/+page.svelte:220`

**Interfaces (Produces):** `generatePlaylistShareUrl(pdfIds: string[], nome: string, louvores: Array = []) → string`. Sem `louvores` (ou sem shortIds completos) devolve o legado — os chamadores antigos continuam válidos.

- [ ] **Step 1: Teste de contrato que falha**

Acrescentar ao fim de `src/lib/utils/playlistShare.contrato.test.js` (mesmos vetores serão usados no v2 — não altere os valores):
```js
import { parseShortShareIds, resolveShortIds } from './playlistShare.js';

describe('contrato do link curto (?s=&n=) — espelhado no app v2', () => {
  const catalogo = [
    { pdfId: ID_A, shortId: '0000' },
    { pdfId: ID_B, shortId: '1a2f' }
  ];

  it('emite curto quando todos têm shortId: ids minúsculos com -, nome encodado', () => {
    const url = generatePlaylistShareUrl([ID_B, ID_A], 'Culto de domingo', catalogo);
    assert.equal(url, '/?s=1a2f-0000&n=Culto%20de%20domingo');
  });

  it('emite legado quando falta shortId em algum id', () => {
    const url = generatePlaylistShareUrl([ID_A, ID_B], 'X', [{ pdfId: ID_A, shortId: '0000' }]);
    assert.match(url, /^\/\?sharepdfs=/);
    assert.equal(url.includes('s='), false);
  });

  it('lê o link curto: s vence os params legados presentes na mesma URL', () => {
    const u = new URL('https://plpcg.com/?s=0000-1A2F-zzzz&n=Culto&sharepdfs=lixo&sharename=outro');
    const ids = resolveShortIds(parseShortShareIds(u.searchParams.get('s')), catalogo);
    assert.deepEqual(ids, [ID_A, ID_B]);
    assert.equal(u.searchParams.get('n'), 'Culto');
  });

  it('"0000" atravessa como string com zeros', () => {
    const url = generatePlaylistShareUrl([ID_A], 'x', catalogo);
    assert.equal(url, '/?s=0000&n=x');
  });
});
```
(Nos testes `window` não existe, então `baseUrl` é `''` e a URL começa em `/?` — é o comportamento atual de `generatePlaylistShareUrl` sob `node --test`.)

- [ ] **Step 2: Rodar e ver falhar**

Run: `node --test src/lib/utils/playlistShare.contrato.test.js`
Expected: FAIL nos casos «emite curto» e `"0000"`.

- [ ] **Step 3: Implementar**

`src/lib/utils/playlistUtils.js`:
```js
import {
  encodeSharePdfIds,
  encodeShortShareIds,
  SHORT_SHARE_NAME_PARAM,
  SHORT_SHARE_PARAM,
  shortIdsForPdfIds
} from './playlistShare.js';

/**
 * Generate share URL for a playlist.
 *
 * Formato curto (`?s=…&n=…`) quando todos os pdfIds têm `shortId` no
 * catálogo; senão o legado `?sharepdfs=…&sharename=…`, que todo receptor
 * antigo já lê. Sem `louvores` cai sempre no legado.
 * @param {string[]} pdfIds - Array of PDF IDs in order
 * @param {string} nome - Playlist name
 * @param {Array<{pdfId?: string, shortId?: unknown}>} [louvores] - catálogo
 * @returns {string}
 */
export function generatePlaylistShareUrl(pdfIds, nome, louvores = []) {
  const baseUrl = typeof window !== 'undefined' ? window.location.origin : '';
  const nameParam = encodeURIComponent(nome);
  const shortIds = shortIdsForPdfIds(pdfIds, louvores);
  if (shortIds) {
    return `${baseUrl}/?${SHORT_SHARE_PARAM}=${encodeShortShareIds(shortIds)}&${SHORT_SHARE_NAME_PARAM}=${nameParam}`;
  }
  // Cada id é codificado à parte para proteger o `+` do base64 (§2.4b da
  // investigação). A leitura continua aceitando o formato cru dos links antigos.
  const pdfIdsParam = encodeSharePdfIds(pdfIds);
  return `${baseUrl}/?sharepdfs=${pdfIdsParam}&sharename=${nameParam}`;
}
```

`src/lib/components/CarouselChips.svelte`: adicionar `import { louvores } from '$lib/stores/louvores';` junto dos outros stores (linha ~5) e, nas duas chamadas (linhas ~538 e ~627), `generatePlaylistShareUrl(pdfIds, playlistName, $louvores)`.

`src/routes/listas/+page.svelte:220`: `generatePlaylistShareUrl(playlist.pdfIds, playlist.nome, $louvores)` (o store já está importado na linha 7).

- [ ] **Step 4: Rodar tudo**

Run: `npm test && npm run check`
Expected: todos os `node --test` verdes; `svelte-check` sem erros novos (compare a contagem com `git stash`-free: rode `npm run check` em `main` antes se quiser a linha de base — ou aceite «0 errors»).

- [ ] **Step 5: Commit**

```bash
git add src/lib/utils/playlistUtils.js src/lib/utils/playlistShare.contrato.test.js src/lib/components/CarouselChips.svelte src/routes/listas/+page.svelte
git commit -m "feat(share): links de lista saem no formato curto quando o catálogo tem shortId"
```

---

### Task 3: Import por `s` em `routes/+page.svelte`

**Files:**
- Modify: `src/routes/+page.svelte:15-20` (imports), `:219-262` (`handleSharedPlaylistLink`)
- Modify: `src/lib/utils/playlistShare.contrato.test.js` (helper `lerLinkDeLista` cobre `s`)

- [ ] **Step 1: Estender o helper de caracterização (teste que falha)**

Em `playlistShare.contrato.test.js`, substituir `lerLinkDeLista` por uma versão que reproduz a leitura nova (curto primeiro) e acrescentar um caso:
```js
import { parseShortShareIds, resolveShortIds, SHORT_SHARE_PARAM, SHORT_SHARE_NAME_PARAM } from './playlistShare.js';

/**
 * Reproduz a leitura de src/routes/+page.svelte: `s` (curto) vence; sem `s`,
 * `sharepdfs` como sempre. Recebe o catálogo porque `s` precisa dele.
 */
function lerLinkDeLista(href, louvores = []) {
  const u = new URL(href, 'https://plpcg.com');
  const params = new URLSearchParams(u.search);
  if (params.has(SHORT_SHARE_PARAM)) {
    const pdfIds = resolveShortIds(parseShortShareIds(params.get(SHORT_SHARE_PARAM)), louvores);
    return { pdfIds, sharename: params.get(SHORT_SHARE_NAME_PARAM) };
  }
  const pdfIds = parseSharePdfIds(params.get('sharepdfs'));
  return { pdfIds, sharename: params.get('sharename') };
}
```
(mantenha o que o helper já devolvia hoje além de `pdfIds`/`sharename`, se houver — só troque a parte de leitura.) E o caso:
```js
  it('leitura: link curto resolve pelo catálogo e usa n como nome', () => {
    const lido = lerLinkDeLista('/?s=1a2f-0000&n=Culto%20de%20domingo', catalogo);
    assert.deepEqual(lido.pdfIds, [ID_B, ID_A]);
    assert.equal(lido.sharename, 'Culto de domingo');
  });
```

- [ ] **Step 2: Rodar**

Run: `node --test src/lib/utils/playlistShare.contrato.test.js`
Expected: PASS (o helper é código de teste; este passo garante que os vetores fecham antes de mexer no Svelte).

- [ ] **Step 3: Implementar em `+page.svelte`**

Imports (bloco `from '$lib/utils/playlistShare'`, linha ~15): acrescentar `parseShortShareIds, resolveShortIds, SHORT_SHARE_PARAM, SHORT_SHARE_NAME_PARAM`.

Substituir `handleSharedPlaylistLink`:
```js
  /**
   * Importa a lista compartilhada que veio na query — formato curto
   * (`?s=<shortIds>&n=<nome>`) ou legado (`?sharepdfs=...&sharename=...`).
   * `s` vence quando os dois vêm juntos. A URL é limpa sempre que algum
   * param de share existe, mesmo quando nada é importado.
   */
  function handleSharedPlaylistLink() {
    if (sharedLinkProcessed) return;

    const urlParams = new URLSearchParams($page.url.search);
    const temCurto = urlParams.has(SHORT_SHARE_PARAM);
    if (!temCurto && !urlParams.has('sharepdfs')) return;
    // Sem catálogo não dá para resolver os ids: espera o manifesto (caso C2).
    if ($louvores.length === 0) return;

    sharedLinkProcessed = true;

    let idsResolvidos;
    let sharename;
    if (temCurto) {
      // shortId → pdfId pelo catálogo; token desconhecido é ignorado.
      idsResolvidos = resolveShortIds(parseShortShareIds(urlParams.get(SHORT_SHARE_PARAM)), $louvores);
      sharename = urlParams.get(SHORT_SHARE_NAME_PARAM);
    } else {
      const pdfIds = parseSharePdfIds(urlParams.get('sharepdfs'));
      // A lista salva guarda os mesmos ids que o carrossel mostra: ids fantasmas
      // envenenariam findPlaylistByPdfIds para sempre.
      idsResolvidos = resolveKnownPdfIds(pdfIds, $louvores);
      // URLSearchParams.get já decodificou uma vez; decodificar de novo lançava
      // URIError em qualquer nome com `%` e abortava o save.
      sharename = urlParams.get('sharename');
    }

    if (idsResolvidos.length > 0) {
      carousel.clearCarousel();
      carousel.loadPlaylist(idsResolvidos, $louvores);
      const playlistName = sharename || undefined;
      // Abrir o mesmo link várias vezes não cria listas duplicadas.
      if (!savedPlaylists.findPlaylistByPdfIds(idsResolvidos)) {
        savedPlaylists.savePlaylist(idsResolvidos, playlistName);
      }
    } else {
      console.warn('[share] nenhum id do link foi encontrado no catálogo');
    }

    // Limpa só os params do compartilhamento; utm_source/fbclid seguem vivos.
    // replaceState: voltar não pode reimportar a lista.
    const destino = $page.url.pathname + stripShareParams($page.url.search);
    goto(destino, { replaceState: true, noScroll: true });
  }
```

- [ ] **Step 4: Checagem estática + teste manual local**

Run: `npm run check`
Expected: 0 errors.

Run: `npm run dev` e abrir `http://localhost:5173/?s=<dois shortIds reais do manifest>&n=Teste%20curto` (pegue dois `shortId` em `https://plpcg.com/louvores-manifest.json` **depois** do rollout do Plano 1; antes dele use o manifest local com `shortId` inventado, se o dev server servir `static/`). Expected: carrossel com os dois louvores na ordem, lista salva «Teste curto», URL limpa. Depois clique em compartilhar no carrossel e confira que o link copiado começa com `/?s=`.

- [ ] **Step 5: Commit**

```bash
git add src/routes/+page.svelte src/lib/utils/playlistShare.contrato.test.js
git commit -m "feat(share): importa lista por ?s=&n= (shortId) antes do formato legado"
```

---

### Task 4: `shortId` sobrevive à normalização do catálogo (teste de regressão)

**Files:**
- Create: `src/lib/stores/louvores.shortId.test.js`

- [ ] **Step 1: Teste**

```js
import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { prepareLouvoresManifestPayload } from './louvores.js';

describe('prepareLouvoresManifestPayload preserva shortId', () => {
  it('mantém shortId como string, inclusive "0000"', () => {
    const out = prepareLouvoresManifestPayload([
      { pdfId: 'a', nome: 'A', shortId: '0000' },
      { pdfId: 'b', nome: 'B' }
    ]);
    assert.equal(out[0].shortId, '0000');
    assert.equal(typeof out[0].shortId, 'string');
    assert.equal('shortId' in out[1], false);
  });
});
```

- [ ] **Step 2: Rodar**

Run: `node --test src/lib/stores/louvores.shortId.test.js`
Expected: PASS de primeira (é caracterização do spread já existente). Se falhar porque `louvores.js` importa módulos de browser no topo, mova `prepareLouvoresManifestPayload` para `src/lib/utils/manifestPayload.js` e reexporte de `louvores.js` — aí o teste importa de `utils`.

- [ ] **Step 3: Commit**

```bash
git add src/lib/stores/louvores.shortId.test.js
git commit -m "test(catalog): shortId atravessa a normalização do manifest como string"
```

---

### Task 5: Rollout (passo 3 do §5)

Pré-requisito: Plano 1 Task 9 concluída (manifest publicado com `shortId`).

- [ ] **Step 1:** `npm test && npm run check && npm run build` verdes.
- [ ] **Step 2:** merge em `main` (`git checkout main && git merge --no-ff feat/short-id-share && git push`) — o deploy do Cloudflare Pages segue o fluxo habitual do repo.
- [ ] **Step 3: Validar em produção**
  - Abrir `https://plpcg.com/?s=<dois shortIds do manifest>&n=Teste` → carrossel carrega, lista salva, URL limpa.
  - Compartilhar uma lista do carrossel → link começa com `https://plpcg.com/?s=`.
  - Abrir um link **legado** antigo (`?sharepdfs=…&sharename=…`) → continua importando.

---

## Self-review

- **Cobertura §3:** 3.1 (Task 4), 3.2 (Task 1), 3.3 (Task 2), 3.4 (Task 3), 3.5 (Tasks 1–3, contrato na 2/3), §5 passo 3 (Task 5). D7/D8 (Tasks 1–3). «String, não número» (Task 1: `isShortId`, `resolveShortIds` com `shortId: 0`).
- **Tipos entre tasks:** `generatePlaylistShareUrl(pdfIds, nome, louvores = [])` definido na Task 2, usado por `CarouselChips`/`listas` na mesma task e pelo helper de contrato na 2/3. `SHORT_SHARE_PARAM`/`SHORT_SHARE_NAME_PARAM` definidos na Task 1, usados nas 2 e 3.
- **Placeholders:** nenhum; o único condicional é o fallback de mover `prepareLouvoresManifestPayload` se o import quebrar sob Node, com destino explícito.

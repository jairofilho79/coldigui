# Louvores agrupados no «amendoim» — plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Home (resultados da busca) e /biblioteca mostram cada grupo do coldigom (`praises.group_id`) como um «amendoim»: gomos colados, junta de coração, etiqueta dourada por versão, membros que não casaram esmaecidos.

**Architecture:** A API passa a mandar `groupId` no dump do catálogo. O app leva o campo do DTO até a metadata (e o Isar), força um dump inteiro uma vez por versão de esquema, e monta a lista em duas etapas: uma função pura junta os grupos (`clusterCatalogList`) e a tela desenha cada `ClusterEntry` com gomos (`PeanutLobeBorder`) empilhados num `RenderBox` que pinta uma sombra só.

**Tech Stack:**
- coldigom: Cloudflare Workers + Hono + D1, vitest.
- coldigui: Flutter, Riverpod 3, isar_plus (com `build_runner`), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-25-louvores-agrupados-amendoim-design.md` (neste worktree do coldigui). Leia os dois: o plano argumenta a partir do spec.

## Repositórios e worktrees

| Repo | Worktree | Branch | Base |
|---|---|---|---|
| coldigom | `/Volumes/SSD 2TB SD/dev/coldigom/.claude/worktrees/catalogo-group-id` (criar na Tarefa 1) | `feat/catalogo-group-id` | `origin/main` |
| coldigui | `/Volumes/SSD 2TB SD/dev/coldigui/.claude/worktrees/louvores-agrupados` (já existe) | `feat/louvores-agrupados` | `web/integration` @ `d82da886` |

Nas tarefas, `API` é o worktree do coldigom e `APP` é o worktree do coldigui. Todo comando roda com `cd` no worktree da tarefa.

## Global Constraints

- Textos, comentários e mensagens de commit em português, no tom do código vizinho. Todo commit termina com `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.
- **Só mudam** a Home (resultados da busca) e a /biblioteca. A barra do carrossel, o painel da lista ativa, os detalhes de playlist e o estado vazio da Home continuam com a pílula de hoje.
- A unidade do app continua sendo o praise: playlist, `?p=`, favoritos, «+» e offline não mudam. O grupo existe só na lista da tela.
- `group_id` é **chave opaca**: nunca é tratado como id de praise.
- O dump só manda `groupId` quando `group_id` não é nulo nem vazio (mesmo molde do `shortId`). Sem migração no D1.
- Trava do sync: constante `coldigomCatalogSchemaVersion = 1`, gravada em `markReplaced`. **Não** usar `hasAnyGroupId()`.
- Geometria do gomo:
  - `R = 24`, que é `carouselChipModalRadius`, o antigo `_modalChipRadius`;
  - bico recuado `d = 10`;
  - `a = min(26, h − R)` no primeiro e no último gomo, `a = min(26, h / 2)` no do meio;
  - `r′ = (d² + a²) / (2d)`.
- Pintura do gomo:
  - contorno `AppColors.gold` de 2 px, por dentro;
  - costura de 1 px em `AppColors.gold` a 60 %, pintada pelo gomo de baixo;
  - fundo `AppColors.title`;
  - `dimensions` é `EdgeInsets.all(2)`.
- Etiqueta:
  - fundo `gold` a 0.14 e borda `gold` a 0.6 de 1 px, raio 8, padding 7 × 2;
  - texto `AppColors.goldLight`, `AppTypography.label` com tamanho 10 (w600);
  - no máximo 128 px de texto, cortado com «…».
- Esmaecido: `Opacity(0.45)` só no conteúdo, e o toque continua ativo.
- Padding do gomo: 20 à esquerda, 12 à direita, 6 em cima e embaixo. O gomo não tem sombra própria; o cluster pinta uma sombra `AppColors.shadowMd` da silhueta inteira.
- Ordem fixa dentro do amendoim, com desempate nesta sequência:
  1. `numeroSortKey` crescente, com o `-1` (sem número) por último;
  2. nome normalizado (`LouvorSearchTokens.normalize`);
  3. menos tags primeiro;
  4. `praiseId` (`LouvorGroup.groupId`).
- Texto `libraryResultsSummary`: pt «Mostrando {from}–{to} de {total} resultados», en «Showing {from}–{to} of {total} results».
- **Não** fazer merge nem deploy. A tarefa da API termina com o PR aberto para `develop`, e o merge é do dono. No coldigui, a branch fica pronta, sem merge em `web/integration`.

## Desvios do spec (decididos neste plano)

1. **Qual instância de um membro vale** (spec §4.2 passo 1 dizia «vale a instância do índice»):
   - o membro que está em `ordered` usa **a instância de `ordered`**;
   - entre os demais, a do índice vence a dos `extraMembers`.

   **Por quê:** na Home, o praise que casou pela letra chega pela busca remota com `lyricsExcerpt`, e a instância do índice não tem esse campo. Trocar pela do índice apagaria o trecho da letra, que acabou de voltar (PR #43).
2. **Etiqueta fora do `Expanded`** (spec §6.2 falava em reservar a largura com `TextPainter`):
   - a etiqueta fica na `Row` do chip, entre o corpo `Expanded` e o «+»;
   - assim o `LayoutBuilder` do corpo já recebe a largura sem ela, e o breakpoint de `ChipMetadataRow` sai certo sem medir texto;
   - o efeito é o mesmo, com menos código.
3. **Padding de baixo do cluster** (spec §6.3 mantinha `Padding(bottom: 8)` no gomo `last`):
   - nenhum gomo tem padding de baixo, e o `LouvorClusterCard` põe o `Padding(bottom: 8)` por fora do conjunto;
   - motivo: a silhueta da sombra é calculada com a altura de cada gomo, e 8 px de padding dentro do último gomo a deformariam.
4. **`HomeSearchState.entries` é opcional:**
   - sem valor, o construtor usa um `SingleEntry` por grupo de `groups`;
   - o `homeSearchStateProvider` sempre passa o valor juntado;
   - o fallback existe só para os testes antigos, que constroem o estado na mão, continuarem válidos.

## Review Focus

1. **Praise que casou pela letra e entra num amendoim.** Ele deve manter o trecho da letra no gomo dele. Teste na Tarefa 5 («a instância de `ordered` vence»).
2. **Celular estreito (320 px) com etiqueta longa, selo «novo», ícones e «+».** Nada pode estourar (`RenderFlex overflowed`). Teste na Tarefa 8.
3. **Gomo alto** (trecho da letra, `textScaler` alto). A lateral ganha trecho reto e o bico continua a 10 px, sem deformar. Teste na Tarefa 7.
4. **Página além do fim quando os amendoins reduzem o total de cartões.** Cai na última página, com o grupo inteiro nela. Teste na Tarefa 11.
5. **Gomo esmaecido.** Continua clicável e o «+» adiciona **aquela** versão, não o primeiro membro. Teste na Tarefa 9.

## Mapa de arquivos

**coldigom (API)**
- Modificar `api/src/plpcgPraises.ts`: o tipo `CatalogPraiseRow`, a query e o `map` de `buildPlpcgCatalog`.
- Criar `api/src/__tests__/catalogGroupId.test.ts`.

**coldigui (APP)**

| Arquivo | Ação | Responsabilidade |
|---|---|---|
| `lib/features/coldigom/domain/utils/praise_group_id.dart` | criar | `normalizePraiseGroupId` |
| `lib/features/coldigom/data/models/coldigom_catalog_dto.dart` | modificar | `groupId` do dump |
| `lib/features/coldigom/data/models/praise_dto.dart` | modificar | `group_id` da API |
| `lib/core/database/collections/coldigom_praise_cache.dart` (+ `.g.dart`) | modificar | coluna Isar `groupId` |
| `lib/features/coldigom/data/mappers/coldigom_praise_cache_mapper.dart` | modificar | leva `groupId` nos 5 caminhos |
| `lib/features/coldigom/data/adapters/coldigom_louvor_adapter.dart` | modificar | `toMetadata` |
| `lib/features/coldigom/domain/entities/coldigom_praise_metadata.dart` | modificar | `groupId` |
| `lib/core/constants/storage_keys.dart` | modificar | chave da versão de esquema |
| `lib/features/coldigom/data/datasources/coldigom_catalog_sync_metadata_store.dart` | modificar | ler/gravar versão |
| `lib/features/coldigom/domain/usecases/sync_coldigom_catalog.dart` | modificar | anula o ETag por versão |
| `lib/features/catalog/domain/usecases/cluster_member_order.dart` | criar | `praiseGroupKeyOf`, `compareClusterMembers` |
| `lib/features/coldigom/domain/search/coldigom_search_index.dart` | modificar | `membersOf` |
| `lib/features/catalog/domain/entities/catalog_list_entry.dart` | criar | `CatalogListEntry` e família |
| `lib/features/catalog/domain/usecases/cluster_catalog_list.dart` | criar | `clusterCatalogList` |
| `lib/features/catalog/domain/usecases/cluster_member_label.dart` | criar | `clusterMemberLabel` |
| `lib/features/carousel/presentation/widgets/chip_parts/peanut_lobe_border.dart` | criar | `LobePosition`, `lobePositionAt`, `peanutLobePath`, `PeanutLobeBorder` |
| `lib/features/carousel/presentation/widgets/chip_parts/chip_group_label.dart` | criar | etiqueta dourada |
| `lib/features/carousel/presentation/widgets/carousel_louvor_chip.dart` | modificar | `lobePosition`, `groupLabel`, `dimmed`, raio público |
| `lib/features/catalog/presentation/widgets/louvor_group_card.dart` | modificar | repassa os 3 parâmetros; sem padding no gomo |
| `lib/features/catalog/presentation/widgets/peanut_cluster_column.dart` | criar | `RenderBox` em coluna + sombra da silhueta |
| `lib/features/catalog/presentation/widgets/louvor_cluster_card.dart` | criar | o amendoim |
| `lib/features/catalog/presentation/providers/home_search_state.dart` | modificar | `entries` |
| `lib/features/catalog/presentation/providers/home_search_provider.dart` | modificar | junta nos 3 ramos |
| `lib/features/catalog/presentation/widgets/home_search_results_sliver.dart` | modificar | itera `entries` |
| `lib/features/library/domain/entities/paginated_louvor_groups.dart` → `paginated_catalog_entries.dart` | renomear | página de entradas |
| `lib/features/library/domain/usecases/paginate_louvor_groups.dart` → `paginate_catalog_entries.dart` | renomear | paginar entradas |
| `lib/features/library/data/providers/library_providers.dart` | modificar | `paginateCatalogEntriesProvider` |
| `lib/features/library/presentation/providers/library_group_results_provider.dart` | modificar | `libraryEntriesProvider` e paginação por entradas |
| `lib/features/library/presentation/pages/library_screen.dart` | modificar | desenha `SingleEntry`/`ClusterEntry` |
| `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb` (+ `app_localizations*.dart` gerados) | modificar | «resultados» |
| `test/helpers/coldigom_catalog_test_helpers.dart` | modificar | `catalogGroup(groupId:)`, `describeEntry` |

---

### Tarefa 1: `groupId` no dump do catálogo (coldigom)

**Arquivos:**
- Modificar: `api/src/plpcgPraises.ts` (tipo `CatalogPraiseRow` ~l.324, query de `buildPlpcgCatalog` ~l.410, `map` dos praises ~l.496)
- Criar: `api/src/__tests__/catalogGroupId.test.ts`

**Interfaces:**
- Consome: nada.
- Produz: cada praise do corpo de `GET /api/plpcg/catalog` ganha `"groupId": "<string>"` só quando `praises.group_id` não é nulo nem vazio. O ETag muda junto.

- [ ] **Passo 1: criar o worktree e instalar as dependências**

```bash
cd "/Volumes/SSD 2TB SD/dev/coldigom"
git fetch origin
git worktree add .claude/worktrees/catalogo-group-id -b feat/catalogo-group-id origin/main
cd .claude/worktrees/catalogo-group-id/api
npm ci
```

- [ ] **Passo 2: escrever o teste que falha**

Criar `api/src/__tests__/catalogGroupId.test.ts`:

```ts
import { DatabaseSync } from 'node:sqlite';
import { describe, expect, it, vi } from 'vitest';
import { app } from '../index';
import { buildPlpcgCatalog } from '../plpcgPraises';
import { TAG_LABEL_SQL } from '../praiseQuery';
import { d1DeSqlite, sqliteComSchema } from './sqliteD1';

/**
 * groupId no dump do catálogo (spec coldigui louvores-agrupados §3.1): sai
 * só quando `praises.group_id` tem valor, no molde do `shortId`, e o ETag
 * muda junto — é isso que faz os aparelhos baixarem o dump de novo.
 */
const linhaBase = {
  id: 'p1',
  short_id: '000',
  group_id: null as string | null,
  name: 'A',
  number: '1',
  author: null,
  rhythm: null,
  tonality: null,
  lyrics: null,
};

function d1Falso(linha: object, sqls: string[] = []) {
  return {
    prepare: (sql: string) => {
      sqls.push(sql);
      return {
        all: async () => ({ results: sql.includes('FROM praises p') ? [linha] : [] }),
        bind: () => ({ all: async () => ({ results: [] }) }),
      };
    },
  } as unknown as D1Database;
}

async function praiseDoDump(linha: object) {
  const resultado = await buildPlpcgCatalog(d1Falso(linha), { tagLabelSql: TAG_LABEL_SQL }, undefined);
  return { praise: JSON.parse(resultado.body).praises[0], etag: resultado.headers.ETag };
}

describe('groupId no dump do catálogo', () => {
  it('manda groupId quando o praise está num grupo', async () => {
    const { praise } = await praiseDoDump({ ...linhaBase, group_id: 'ancora-1' });
    expect(praise.groupId).toBe('ancora-1');
  });

  it('group_id nulo, vazio ou só espaços: a chave some', async () => {
    for (const group_id of [null, '', '   ']) {
      const { praise } = await praiseDoDump({ ...linhaBase, group_id });
      expect(praise, String(group_id)).not.toHaveProperty('groupId');
    }
  });

  it('o ETag muda quando o group_id muda', async () => {
    const sem = await praiseDoDump(linhaBase);
    const com = await praiseDoDump({ ...linhaBase, group_id: 'ancora-1' });
    const outro = await praiseDoDump({ ...linhaBase, group_id: 'ancora-2' });
    expect(com.etag).not.toBe(sem.etag);
    expect(outro.etag).not.toBe(com.etag);
  });

  it('a consulta dos praises lê p.group_id', async () => {
    const sqls: string[] = [];
    await buildPlpcgCatalog(d1Falso(linhaBase, sqls), { tagLabelSql: TAG_LABEL_SQL }, undefined);
    expect(sqls.find((s) => s.includes('FROM praises p'))).toContain('p.group_id');
  });

  it('GET /api/plpcg/catalog com SQLite de verdade: groupId só nos agrupados', async () => {
    const sqlite: DatabaseSync = sqliteComSchema();
    const env = {
      DB: d1DeSqlite(sqlite),
      ASSETS: { head: vi.fn(async () => null), put: vi.fn(), delete: vi.fn() },
      AUTH_JWT_SECRET: '0123456789abcdef0123456789abcdef',
      AUTH_ALLOWED_EMAILS: '*',
      WEB_ORIGIN: 'https://web.example',
    };
    sqlite.prepare('INSERT INTO praises (id, name, number, group_id) VALUES (?, ?, ?, ?)').run('a', 'Clamo a ti', '003', 'a');
    sqlite.prepare('INSERT INTO praises (id, name, number, group_id) VALUES (?, ?, ?, ?)').run('b', 'Clamo a ti', '003', 'a');
    sqlite.prepare('INSERT INTO praises (id, name, number) VALUES (?, ?, ?)').run('c', 'Outro', '004');

    const res = await app.request('/api/plpcg/catalog', {}, env as never);
    expect(res.status).toBe(200);
    const json = (await res.json()) as { praises: { id: string; groupId?: string }[] };
    const porId = Object.fromEntries(json.praises.map((p) => [p.id, p.groupId]));
    expect(porId).toEqual({ a: 'a', b: 'a', c: undefined });
  });
});
```

- [ ] **Passo 3: rodar e ver falhar**

Rodar: `cd api && npx vitest run src/__tests__/catalogGroupId.test.ts`
Esperado: FALHA em «manda groupId…», «o ETag muda…», «a consulta… lê p.group_id» e no teste de rota. Os três primeiros com `groupId` `undefined` ou `sqls` sem `p.group_id`.

- [ ] **Passo 4: implementar**

Em `api/src/plpcgPraises.ts`:

1. No tipo `CatalogPraiseRow`, logo depois de `short_id?: string | null;`:

```ts
  group_id?: string | null;
```

2. Na query dos praises de `buildPlpcgCatalog`:

```ts
      `SELECT p.id, p.short_id, p.group_id, p.name, p.number, p.author, p.rhythm, p.tonality, p.lyrics
       FROM praises p
       ORDER BY p.number, p.name, p.id`
```

3. No `map` dos praises, logo depois da linha do `shortId`:

```ts
      // group_id é chave opaca (id do praise âncora); sem grupo a chave some,
      // no molde do shortId — o app junta os membros (spec coldigui §3.1).
      ...(row.group_id && row.group_id.trim() ? { groupId: row.group_id } : {}),
```

- [ ] **Passo 5: rodar e ver passar, depois a suíte e os tipos**

Rodar: `cd api && npx vitest run src/__tests__/catalogGroupId.test.ts`
Esperado: 5 testes passam.

Rodar: `cd .. && npm run typecheck:api && npm run test:api`
Esperado: sem erro de tipo e a suíte da API toda verde.

- [ ] **Passo 6: commit, push e PR (sem merge)**

```bash
git add api/src/plpcgPraises.ts api/src/__tests__/catalogGroupId.test.ts
git commit -m "$(cat <<'EOF'
feat(api): groupId no dump do catálogo do PLPCG

O app junta as versões de um louvor pelo praises.group_id. O campo sai
só quando existe, no molde do shortId, e o ETag muda junto.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
EOF
)"
git push -u origin feat/catalogo-group-id
gh pr create --base develop --title "feat(api): groupId no dump do catálogo" --body "$(cat <<'EOF'
Cada praise do `GET /api/plpcg/catalog` ganha `groupId` quando `praises.group_id` tem valor. Sem migração: a coluna existe desde a 008.

- Versões antigas do app ignoram o campo.
- O app novo força um dump inteiro uma vez, pela versão de esquema do catálogo (spec coldigui louvores-agrupados §3.4).
- O ETag muda uma vez, e cada aparelho baixa o dump no próximo sync.

Testes: `api/src/__tests__/catalogGroupId.test.ts`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Não fazer merge: o dono faz `develop` → `main`, e o push em `main` dispara o `Deploy API to Workers`.

---

### Tarefa 2: `groupId` do DTO até a metadata e o Isar (coldigui)

**Arquivos:**
- Criar: `lib/features/coldigom/domain/utils/praise_group_id.dart`
- Modificar: `coldigom_catalog_dto.dart`, `praise_dto.dart`, `coldigom_praise_cache.dart` (+ `.g.dart` regerado), `coldigom_praise_cache_mapper.dart`, `coldigom_louvor_adapter.dart`, `coldigom_praise_metadata.dart`
- Modificar: `test/helpers/coldigom_catalog_test_helpers.dart` (parâmetro `groupId`)
- Modificar: `test/unit/core/database/coldigom_praise_cache_schema_migration_test.dart` (uma linha)
- Criar: `test/unit/features/coldigom/praise_group_id_test.dart`

**Interfaces:**
- Consome: o JSON do dump (`groupId`) e o de `/api/plpcg/praises` (`group_id`).
- Produz:
  - `String? normalizePraiseGroupId(Object? raw)`
  - `ColdigomCatalogPraiseDto.groupId`, `PraiseDetailDto.groupId` (parâmetro nomeado `groupId` no construtor), `ColdigomPraiseCache.groupId`
  - `ColdigomPraiseMetadata.groupId` (`String?`, parâmetro nomeado `groupId`)
  - `catalogGroup(..., String? groupId)` no helper de teste

- [ ] **Passo 1: preparar o worktree e medir a linha de base**

```bash
cd "/Volumes/SSD 2TB SD/dev/coldigui/.claude/worktrees/louvores-agrupados"
flutter pub get
flutter test 2>&1 | tail -5
```

Anote quantos testes passam ou falham **antes** de mexer. Uma falha que já existe não é desta entrega. Registre-a no relatório da tarefa e siga.

- [ ] **Passo 2: escrever o teste que falha**

Criar `test/unit/features/coldigom/praise_group_id_test.dart`:

```dart
import 'package:coldigui/core/database/collections/coldigom_praise_cache.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/coldigom/data/adapters/coldigom_louvor_adapter.dart';
import 'package:coldigui/features/coldigom/data/mappers/coldigom_praise_cache_mapper.dart';
import 'package:coldigui/features/coldigom/data/models/coldigom_catalog_dto.dart';
import 'package:coldigui/features/coldigom/data/models/praise_dto.dart';
import 'package:coldigui/features/coldigom/domain/utils/praise_group_id.dart';
import 'package:flutter_test/flutter_test.dart';

const _anchor = '3f2a9c1e-0000-4000-8000-000000000001';

void main() {
  group('normalizePraiseGroupId', () {
    test('string não vazia → aparada, com a caixa preservada', () {
      expect(normalizePraiseGroupId(_anchor), _anchor);
      expect(normalizePraiseGroupId('  AbC '), 'AbC');
    });

    test('nulo, vazio, só espaços ou não-string → null (nunca lança)', () {
      for (final raw in <Object?>[null, '', '   ', 7, true]) {
        expect(normalizePraiseGroupId(raw), isNull, reason: '$raw');
      }
    });
  });

  group('groupId atravessa as camadas', () {
    ColdigomCatalogPraiseDto dump(Map<String, dynamic> extra) =>
        ColdigomCatalogPraiseDto.fromJson({
          'id': 'p1',
          'name': 'Hino',
          'materials': <Object>[],
          ...extra,
        });

    test('dump: groupId lido; ausente ou vazio fica null', () {
      expect(dump({'groupId': _anchor}).groupId, _anchor);
      expect(dump({}).groupId, isNull);
      expect(dump({'groupId': ' '}).groupId, isNull);
    });

    test('API: group_id no detalhe; ausente ou vazio fica null', () {
      PraiseDetailDto detail(Map<String, dynamic> extra) =>
          PraiseDetailDto.fromJson({'id': 'p1', 'name': 'Hino', ...extra});

      expect(detail({'group_id': _anchor}).groupId, _anchor);
      expect(detail({}).groupId, isNull);
      expect(detail({'group_id': ''}).groupId, isNull);
    });

    test('dump → linha Isar → detalhe → metadados preservam o groupId', () {
      final row = ColdigomPraiseCacheMapper.fromCatalogPraise(
        dump({'groupId': _anchor}),
        kindNames: const {},
      );

      expect(row.groupId, _anchor);
      final detail = ColdigomPraiseCacheMapper.toPraiseDetail(row);
      expect(detail.groupId, _anchor);
      expect(ColdigomLouvorAdapter.toMetadata(detail).groupId, _anchor);
      expect(ColdigomPraiseCache().groupId, isNull);
    });

    test('página remota e adoção de «novos» levam o groupId à linha', () {
      final detail = PraiseDetailDto.fromJson({
        'id': 'p9',
        'name': 'Novo',
        'number': '9',
        'group_id': _anchor,
        'materials': [
          {
            'id': 'm1',
            'type': 'pdf',
            'r2_key': 'assets/praises/p9/m1.pdf',
            'material_kind': 'k1',
          },
        ],
      });

      expect(
        ColdigomPraiseCacheMapper.fromPraiseDetail(
          detail,
          kindNames: const {},
        ).groupId,
        _anchor,
      );

      final group = LouvorGroup.fromLouvores(
        ColdigomLouvorAdapter.toLouvores(detail),
        coldigomMetaByGroupId: {'p9': ColdigomLouvorAdapter.toMetadata(detail)},
      ).single;
      expect(group.coldigomMeta?.groupId, _anchor);
      expect(ColdigomPraiseCacheMapper.fromLouvorGroup(group).groupId, _anchor);
    });
  });
}
```

- [ ] **Passo 3: rodar e ver falhar**

Rodar: `flutter test test/unit/features/coldigom/praise_group_id_test.dart`
Esperado: FALHA de compilação («Target of URI doesn't exist: …praise_group_id.dart», «The getter 'groupId' isn't defined»).

- [ ] **Passo 4: implementar**

1. Criar `lib/features/coldigom/domain/utils/praise_group_id.dart`:

```dart
/// `group_id` de praise no coldigom (spec louvores-agrupados §3.2): chave
/// **opaca** — hoje o id do praise âncora do grupo —, nunca tratada como id
/// de praise.
///
/// [raw] aparado quando é string não vazia; senão `null`. Tolerante como os
/// DTOs (C.8): tipo errado não lança.
String? normalizePraiseGroupId(Object? raw) {
  if (raw is! String) return null;
  final value = raw.trim();
  return value.isEmpty ? null : value;
}
```

2. `coldigom_catalog_dto.dart`, em `ColdigomCatalogPraiseDto`:
   - importar `'../../domain/utils/praise_group_id.dart'`, com caminho relativo igual ao do import de `praise_short_id.dart` que já existe no arquivo;
   - no construtor, `this.groupId,` depois de `this.shortId,`;
   - campo, depois de `shortId`:

```dart
  /// `groupId` do praise ([normalizePraiseGroupId]) — chave do amendoim
  /// (spec louvores-agrupados §3.2); `null` fora de grupo.
  final String? groupId;
```

   - em `fromJson`, depois de `shortId: …`: `groupId: normalizePraiseGroupId(json['groupId']),`

3. `praise_dto.dart`, em `PraiseDetailDto`:
   - o mesmo import;
   - no construtor, `this.groupId,` depois de `this.shortId,`;
   - campo com o doc `/// `group_id` do praise ([normalizePraiseGroupId]); `null` fora de grupo.` e `final String? groupId;`;
   - em `fromJson`: `groupId: normalizePraiseGroupId(json['group_id']),`

4. `coldigom_praise_cache.dart`, depois de `String? shortId;`:

```dart

  /// `groupId` do praise (chave opaca, spec louvores-agrupados §3.2). Nulo
  /// fora de grupo e em linhas gravadas antes do campo — o sync regrava tudo
  /// uma vez pela versão de esquema do catálogo (§3.4).
  /// Propriedade aditiva, sem migração.
  String? groupId;
```

5. Regerar o Isar e conferir que só o `.g.dart` do cache mudou:

```bash
dart run build_runner build --delete-conflicting-outputs
git status --short
```

Esperado: `lib/core/database/collections/coldigom_praise_cache.g.dart` modificado. Se outro `.g.dart` aparecer modificado, desfaça: `git checkout -- <arquivo>`.

6. `coldigom_praise_cache_mapper.dart`:
   - `fromCatalogPraise`: `groupId: praise.groupId,` depois de `shortId: praise.shortId,`;
   - `fromPraiseDetail`: `groupId: praise.groupId,` depois de `shortId: praise.shortId,`;
   - `fromLouvorGroup`: `groupId: meta?.groupId,` depois de `shortId: meta?.shortId,`;
   - `_row`:
     - parâmetro `String? groupId,` depois de `String? shortId,`;
     - no cascade, `..groupId = groupId` depois de `..shortId = shortId`;
   - `toPraiseDetail`: `groupId: row.groupId,` depois de `shortId: row.shortId,`.

7. `coldigom_praise_metadata.dart`:
   - no construtor, `this.groupId,` depois de `this.shortId,`;
   - campo:

```dart
  /// `groupId` do praise (chave opaca do grupo no coldigom) — é por ele que
  /// a lista junta as versões num amendoim (spec louvores-agrupados §4).
  /// `null` fora de grupo.
  final String? groupId;
```

8. `coldigom_louvor_adapter.dart`, em `toMetadata`: `groupId: praise.groupId,` depois de `shortId: praise.shortId,`.

9. `test/helpers/coldigom_catalog_test_helpers.dart`, em `catalogGroup`:
   - parâmetro `String? groupId,` depois de `String? shortId,`;
   - no `PraiseDetailDto(...)`, `groupId: groupId,` depois de `shortId: shortId,`.

10. `test/unit/core/database/coldigom_praise_cache_schema_migration_test.dart`, depois de `expect(lido.shortId, '2cf');`:

```dart
      expect(lido.groupId, isNull);
```

- [ ] **Passo 5: rodar e ver passar**

Rodar: `flutter test test/unit/features/coldigom/praise_group_id_test.dart test/unit/core/database/coldigom_praise_cache_schema_migration_test.dart test/unit/features/coldigom/`
Esperado: tudo verde, com as duas engines no teste de migração.

- [ ] **Passo 6: commit**

```bash
git add lib/features/coldigom lib/core/database/collections/coldigom_praise_cache.dart lib/core/database/collections/coldigom_praise_cache.g.dart test/helpers/coldigom_catalog_test_helpers.dart test/unit/core/database/coldigom_praise_cache_schema_migration_test.dart test/unit/features/coldigom/praise_group_id_test.dart
git commit -m "$(cat <<'EOF'
feat(coldigom): groupId de praise do dump até aos metadados do grupo

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Tarefa 3: trava do sync pela versão de esquema do catálogo

**Arquivos:**
- Modificar: `lib/core/constants/storage_keys.dart`
- Modificar: `lib/features/coldigom/data/datasources/coldigom_catalog_sync_metadata_store.dart`
- Modificar: `lib/features/coldigom/domain/usecases/sync_coldigom_catalog.dart:83-89`
- Test: `test/unit/features/coldigom/sync_coldigom_catalog_test.dart` (acrescentar testes)

**Interfaces:**
- Consome: nada de tarefas anteriores. Em runtime, a regravação preenche o `groupId` da Tarefa 2.
- Produz:
  - `const int coldigomCatalogSchemaVersion = 1` (no arquivo do store)
  - `int ColdigomCatalogSyncMetadataStore.readCatalogSchemaVersion()`, que devolve `0` quando nunca foi gravado
  - `Future<void> writeCatalogSchemaVersion(int version)`
  - `markReplaced` passa a gravar `coldigomCatalogSchemaVersion`

- [ ] **Passo 1: escrever os testes que falham**

Acrescentar ao fim do `main()` de `sync_coldigom_catalog_test.dart`, com o import `package:coldigui/core/constants/storage_keys.dart` no topo:

```dart
  group('versão de esquema do catálogo (spec louvores-agrupados §3.4)', () {
    /// Remoto que responde 200 sem `If-None-Match` e 304 com ele — o que o
    /// servidor faz quando o ETag guardado é o do dump atual.
    _ScriptedRemote etagAtual() => _ScriptedRemote(
      (ifNoneMatch) async => ifNoneMatch == null
          ? ColdigomCatalogFresh(catalog: _catalog(), etag: '"v1"')
          : const ColdigomCatalogNotModified(),
    );

    Future<void> instalacaoComEtag() async {
      await metadata.writeKindTaxonomy(MaterialKindTaxonomy.empty);
      await local.replaceAll([_storedRow('p-001', shortId: '000')]);
    }

    test('sem versão gravada + ETag guardado → pede sem If-None-Match, '
        'regrava e grava a versão', () async {
      // App anterior a esta entrega: gravou ETag e linhas, nunca a versão.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(StorageKeys.coldigomCatalogEtag, '"v1"');
      await instalacaoComEtag();
      final remote = etagAtual();

      final result = await usecase(remote).run();

      expect(remote.ifNoneMatches, [null]);
      expect(result, isA<ColdigomCatalogSyncReplaced>());
      expect(
        metadata.readCatalogSchemaVersion(),
        coldigomCatalogSchemaVersion,
      );
    });

    test('versão menor que a atual → pede sem If-None-Match', () async {
      await metadata.markReplaced(
        etag: '"v1"',
        count: 1,
        at: DateTime.utc(2026, 1, 1),
      );
      await metadata.writeCatalogSchemaVersion(coldigomCatalogSchemaVersion - 1);
      await instalacaoComEtag();
      final remote = etagAtual();

      await usecase(remote).run();

      expect(remote.ifNoneMatches, [null]);
    });

    test('versão atual → manda o ETag e o 304 vira noop', () async {
      await metadata.markReplaced(
        etag: '"v1"',
        count: 1,
        at: DateTime.utc(2026, 1, 1),
      );
      await instalacaoComEtag();
      final remote = etagAtual();

      final result = await usecase(remote).run();

      expect(remote.ifNoneMatches, ['"v1"']);
      expect(result, isA<ColdigomCatalogSyncNoop>());
    });

    test('markReplaced grava a versão atual; ausente lê como 0', () async {
      expect(metadata.readCatalogSchemaVersion(), 0);

      await metadata.markReplaced(etag: '"v2"', count: 3, at: fixedNow);

      expect(
        metadata.readCatalogSchemaVersion(),
        coldigomCatalogSchemaVersion,
      );
    });

    test('sem Isar o dump não grava a versão (nem ETag)', () async {
      final semIsar = SyncColdigomCatalog(
        remote: etagAtual(),
        local: const ColdigomCatalogLocalDatasource.unavailable(),
        metadata: metadata,
        now: () => fixedNow,
      );

      final result = await semIsar.run();

      expect(result, isA<ColdigomCatalogSyncInMemory>());
      expect(metadata.readCatalogSchemaVersion(), 0);
    });
  });
```

Se `ColdigomCatalogLocalDatasource.unavailable()` não for `const`, tire o `const`. O construtor existe e é usado em `home_search_provider_test.dart`.

- [ ] **Passo 2: rodar e ver falhar**

Rodar: `flutter test test/unit/features/coldigom/sync_coldigom_catalog_test.dart`
Esperado: FALHA de compilação (`readCatalogSchemaVersion`/`coldigomCatalogSchemaVersion` não existem).

- [ ] **Passo 3: implementar**

1. `storage_keys.dart`, depois de `coldigomKindTaxonomy`:

```dart

  /// Versão do formato do dump que as linhas do Isar sabem ler
  /// (`coldigomCatalogSchemaVersion`). Menor que a do app, ou ausente, faz o
  /// próximo sync pedir o dump inteiro (spec louvores-agrupados §3.4).
  static const String coldigomCatalogSchemaVersion =
      'coldigomCatalogSchemaVersion';
```

2. `coldigom_catalog_sync_metadata_store.dart`, antes da classe:

```dart
/// Versão do formato do dump que este app lê (spec louvores-agrupados
/// §3.4). Sobe **uma** vez por campo novo do dump que o app passa a ler: o
/// próximo sync ignora o ETag guardado e regrava as linhas, senão o `304`
/// de um dump já com o campo — cujo ETag o app anterior guardou — manteria
/// as linhas sem ele para sempre.
///
/// 1 = `groupId`.
const coldigomCatalogSchemaVersion = 1;
```

Na classe, depois de `readCount()`:

```dart
  /// Versão do formato com que as linhas atuais foram gravadas; `0` quando
  /// nunca foi gravada (instalação anterior à trava).
  int readCatalogSchemaVersion() =>
      _prefs.getInt(StorageKeys.coldigomCatalogSchemaVersion) ?? 0;

  Future<void> writeCatalogSchemaVersion(int version) =>
      _prefs.setInt(StorageKeys.coldigomCatalogSchemaVersion, version);
```

Em `markReplaced`, antes de `await markValidated(at);`:

```dart
    await writeCatalogSchemaVersion(coldigomCatalogSchemaVersion);
```

3. `sync_coldigom_catalog.dart`:
   - a condição do `etag` fica:

```dart
      final etag =
          !persist ||
              _local.count() == 0 ||
              !_local.hasAnyShortId() ||
              _metadata.readKindTaxonomy() == null ||
              _metadata.readCatalogSchemaVersion() <
                  coldigomCatalogSchemaVersion
          ? null
          : _metadata.readEtag();
```

   - acrescentar ao comentário acima dela:

```dart
      // Idem com versão de esquema antiga: um campo novo do dump (hoje o
      // `groupId`) que as linhas gravadas não têm (spec louvores-agrupados
      // §3.4). Não se usa «alguma linha tem groupId»: sem grupo nenhum no
      // servidor isso baixaria o dump inteiro a cada sync.
```

- [ ] **Passo 4: rodar e ver passar**

Rodar: `flutter test test/unit/features/coldigom/`
Esperado: tudo verde, inclusive os testes antigos do sync, porque `markReplaced` agora grava a versão atual.

- [ ] **Passo 5: commit**

```bash
git add lib/core/constants/storage_keys.dart lib/features/coldigom/data/datasources/coldigom_catalog_sync_metadata_store.dart lib/features/coldigom/domain/usecases/sync_coldigom_catalog.dart test/unit/features/coldigom/sync_coldigom_catalog_test.dart
git commit -m "$(cat <<'EOF'
feat(coldigom): versão de esquema do catálogo força um dump inteiro

Sem ela o app novo mandaria o ETag guardado pelo app anterior e o 304
deixaria as linhas sem groupId para sempre.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Tarefa 4: ordem fixa dos membros e `membersOf` no índice

**Arquivos:**
- Criar: `lib/features/catalog/domain/usecases/cluster_member_order.dart`
- Modificar: `lib/features/coldigom/domain/search/coldigom_search_index.dart`
- Criar: `test/unit/features/coldigom/coldigom_search_index_members_test.dart`

**Interfaces:**
- Consome: `ColdigomPraiseMetadata.groupId` e `catalogGroup(groupId:)` (Tarefa 2).
- Produz:
  - `String? praiseGroupKeyOf(LouvorGroup group)`
  - `int compareClusterMembers(LouvorGroup a, LouvorGroup b)`
  - `List<LouvorGroup> ColdigomSearchIndex.membersOf(String praiseGroupId)`: todos os membros do grupo que estão no índice, na ordem de `compareClusterMembers`. Com 1 membro devolve 1; com chave desconhecida, `const []`.

- [ ] **Passo 1: escrever o teste que falha**

Criar `test/unit/features/coldigom/coldigom_search_index_members_test.dart`:

```dart
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/usecases/cluster_member_order.dart';
import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';

List<String> _ids(List<LouvorGroup> groups) => [
  for (final g in groups) g.groupId,
];

void main() {
  test('membersOf: ordem fixa — número, nome, menos tags, sem número por '
      'último; inclui grupo de 1 membro', () {
    final index = catalogIndexOf([
      catalogGroup(
        praiseId: 'pes',
        number: '003',
        name: 'Clamo a ti',
        tags: const ['GLTM', 'PES', 'Coletânea · Clamor'],
        groupId: 'G1',
      ),
      catalogGroup(
        praiseId: 'avulso',
        name: 'Clamo a ti (avulso)',
        groupId: 'G1',
      ),
      catalogGroup(
        praiseId: 'col',
        number: '003',
        name: 'Clamo a ti',
        tags: const ['Coletânea · Clamor'],
        groupId: 'G1',
      ),
      catalogGroup(
        praiseId: 'so',
        number: '010',
        name: 'Sozinho',
        groupId: 'G2',
      ),
      catalogGroup(praiseId: 'livre', number: '011', name: 'Sem grupo'),
    ]);

    expect(_ids(index.membersOf('G1')), ['col', 'pes', 'avulso']);
    expect(_ids(index.membersOf('G2')), ['so']);
    expect(index.membersOf('desconhecido'), isEmpty);
    expect(ColdigomSearchIndex.empty.membersOf('G1'), isEmpty);
  });

  test('039: «39» e «039» empatam no número e o nome desempata', () {
    final index = catalogIndexOf([
      catalogGroup(
        praiseId: 'solo',
        number: '039',
        name: 'Jesus, Tu és o meu Deus (Solo)',
        groupId: 'G',
      ),
      catalogGroup(
        praiseId: 'sctb',
        number: '039',
        name: 'Jesus, Tu és o meu Deus (SCTB)',
        groupId: 'G',
      ),
      catalogGroup(
        praiseId: 'col',
        number: '39',
        name: 'Jesus, Tu és o meu Deus',
        groupId: 'G',
      ),
    ]);

    expect(_ids(index.membersOf('G')), ['col', 'sctb', 'solo']);
  });

  test('praiseGroupKeyOf lê o groupId da metadata', () {
    expect(
      praiseGroupKeyOf(
        catalogGroup(praiseId: 'a', name: 'A', groupId: 'G'),
      ),
      'G',
    );
    expect(praiseGroupKeyOf(catalogGroup(praiseId: 'b', name: 'B')), isNull);
  });

  test('compareClusterMembers: 034 antes de 307', () {
    final a = catalogGroup(praiseId: 'x', number: '307', name: 'Pelo vale');
    final b = catalogGroup(praiseId: 'y', number: '034', name: 'Pelo Vale');
    expect(_ids([a, b]..sort(compareClusterMembers)), ['y', 'x']);
  });
}
```

- [ ] **Passo 2: rodar e ver falhar**

Rodar: `flutter test test/unit/features/coldigom/coldigom_search_index_members_test.dart`
Esperado: FALHA de compilação (`cluster_member_order.dart` e `membersOf` não existem).

- [ ] **Passo 3: implementar**

1. Criar `lib/features/catalog/domain/usecases/cluster_member_order.dart`:

```dart
import '../../../../core/utils/louvor_search_tokens.dart';
import '../entities/louvor_group.dart';

/// Chave do grupo do coldigom a que [group] pertence (`praises.group_id`),
/// ou `null` fora de grupo. Chave opaca: nunca é um id de praise
/// (spec louvores-agrupados §1 F1).
String? praiseGroupKeyOf(LouvorGroup group) => group.coldigomMeta?.groupId;

/// Ordem fixa dos membros dentro do amendoim (spec §4.4) — independe da
/// ordenação da tela, então o mesmo grupo sai igual na Home e na /biblioteca.
///
/// Número crescente (sem número por último, como [SortLouvorGroups]) → nome
/// normalizado → menos tags (a versão-base antes do arranjo) → praiseId.
int compareClusterMembers(LouvorGroup a, LouvorGroup b) {
  final na = a.numeroSortKey;
  final nb = b.numeroSortKey;
  if (na != nb) {
    if (na == -1) return 1;
    if (nb == -1) return -1;
    return na.compareTo(nb);
  }
  final byName = LouvorSearchTokens.normalize(
    a.nome,
  ).compareTo(LouvorSearchTokens.normalize(b.nome));
  if (byName != 0) return byName;
  final byTags = (a.coldigomMeta?.tagNames.length ?? 0).compareTo(
    b.coldigomMeta?.tagNames.length ?? 0,
  );
  if (byTags != 0) return byTags;
  return a.groupId.compareTo(b.groupId);
}
```

2. `coldigom_search_index.dart`:
   - import: `import '../../../catalog/domain/usecases/cluster_member_order.dart';`
   - construtor privado: novo último parâmetro posicional `this._membersByPraiseGroup,`;
   - `empty`: novo último argumento `<String, List<LouvorGroup>>{},`;
   - em `build`, dentro do `for (final entry in entries)` que já monta `byShortId`, depois do laço de materiais:

```dart
      final praiseGroup = praiseGroupKeyOf(entry.group);
      if (praiseGroup != null) {
        membersByPraiseGroup.putIfAbsent(praiseGroup, () => []).add(entry.group);
      }
```

   - declarar `final membersByPraiseGroup = <String, List<LouvorGroup>>{};` junto de `byMaterialId`;
   - no `return ColdigomSearchIndex._(...)` de `build`, novo último argumento:

```dart
      Map<String, List<LouvorGroup>>.unmodifiable({
        for (final e in membersByPraiseGroup.entries)
          e.key: List<LouvorGroup>.unmodifiable(
            e.value..sort(compareClusterMembers),
          ),
      }),
```

   - campo e método, depois de `groupForMaterialId`:

```dart
  final Map<String, List<LouvorGroup>> _membersByPraiseGroup;

  /// Membros do grupo do coldigom [praiseGroupId] que estão no índice (com
  /// material endereçável), na ordem fixa do amendoim
  /// ([compareClusterMembers]) — **inclusive quando é um só**: o mínimo de 2
  /// fica na junção, depois de somar os membros da busca remota (spec §3.3).
  List<LouvorGroup> membersOf(String praiseGroupId) =>
      _membersByPraiseGroup[praiseGroupId] ?? const [];
```

- [ ] **Passo 4: rodar e ver passar**

Rodar: `flutter test test/unit/features/coldigom/`
Esperado: tudo verde.

- [ ] **Passo 5: commit**

```bash
git add lib/features/catalog/domain/usecases/cluster_member_order.dart lib/features/coldigom/domain/search/coldigom_search_index.dart test/unit/features/coldigom/coldigom_search_index_members_test.dart
git commit -m "$(cat <<'EOF'
feat(catalog): membros de cada grupo do coldigom no índice, em ordem fixa

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Tarefa 5: entradas da lista e `clusterCatalogList`

**Arquivos:**
- Criar: `lib/features/catalog/domain/entities/catalog_list_entry.dart`
- Criar: `lib/features/catalog/domain/usecases/cluster_catalog_list.dart`
- Modificar: `test/helpers/coldigom_catalog_test_helpers.dart` (acrescentar `describeEntry`)
- Criar: `test/unit/features/catalog/cluster_catalog_list_test.dart`

**Interfaces:**
- Consome: `praiseGroupKeyOf`, `compareClusterMembers` e `ColdigomSearchIndex.membersOf` (Tarefa 4).
- Produz:
  - `sealed class CatalogListEntry`
  - `SingleEntry(LouvorGroup group)`
  - `ClusterEntry({required String praiseGroupId, required List<ClusterMember> members})`
  - `ClusterMember({required LouvorGroup group, required bool matched})`
  - `List<CatalogListEntry> clusterCatalogList(List<LouvorGroup> ordered, {required List<LouvorGroup> Function(String praiseGroupId) membersOf, Iterable<LouvorGroup> extraMembers = const []})`
  - no helper de teste, `String describeEntry(CatalogListEntry entry)`: `id` para chip solto e `[a (b)]` para amendoim, com o esmaecido entre parênteses

- [ ] **Passo 1: helper de teste e teste que falha**

Acrescentar ao fim de `test/helpers/coldigom_catalog_test_helpers.dart`, com o import `package:coldigui/features/catalog/domain/entities/catalog_list_entry.dart`:

```dart
/// Resumo legível de uma entrada da lista: o praiseId para chip solto e
/// `[a (b)]` para amendoim — membro que não casou (esmaecido) entre
/// parênteses.
String describeEntry(CatalogListEntry entry) => switch (entry) {
  SingleEntry(:final group) => group.groupId,
  ClusterEntry(:final members) =>
    '[${[for (final m in members) m.matched ? m.group.groupId : '(${m.group.groupId})'].join(' ')}]',
};
```

Criar `test/unit/features/catalog/cluster_catalog_list_test.dart`:

```dart
import 'package:coldigui/features/catalog/domain/entities/catalog_list_entry.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/usecases/cluster_catalog_list.dart';
import 'package:coldigui/features/coldigom/domain/entities/coldigom_praise_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';

LouvorGroup _g(String id, String number, {String? groupId}) =>
    catalogGroup(praiseId: id, number: number, name: 'Louvor $id', groupId: groupId);

void main() {
  // a e b formam o grupo G; x e y são soltos.
  final a = _g('a', '001', groupId: 'G');
  final b = _g('b', '002', groupId: 'G');
  final x = _g('x', '003');
  final y = _g('y', '004');

  List<String> run(
    List<LouvorGroup> ordered,
    List<LouvorGroup> catalog, {
    List<LouvorGroup> extra = const [],
  }) {
    final index = catalogIndexOf(catalog);
    return [
      for (final entry in clusterCatalogList(
        ordered,
        membersOf: index.membersOf,
        extraMembers: extra,
      ))
        describeEntry(entry),
    ];
  }

  test('sem grupos: um chip por item, na ordem recebida', () {
    expect(run([y, x], [x, y]), ['y', 'x']);
  });

  test('o grupo entra na posição do membro mais bem colocado, e as '
      'aparições seguintes somem', () {
    expect(run([x, b, y, a], [a, b, x, y]), ['x', '[a b]', 'y']);
  });

  test('grupo sempre completo: quem não casou vem esmaecido', () {
    expect(run([b], [a, b]), ['[(a) b]']);
  });

  test('grupo sem nenhum membro que casou não aparece', () {
    expect(run([x], [a, b, x]), ['x']);
  });

  test('grupo que continua com 1 membro vira chip solto', () {
    final s = _g('s', '007', groupId: 'S');
    expect(run([s], [s]), ['s']);
  });

  test('membro só no índice + membro só remoto formam o amendoim', () {
    final r = _g('r', '002', groupId: 'G');
    expect(run([a, x, r], [a, x], extra: [r]), ['[a r]', 'x']);
  });

  test('membro presente no índice e no remoto não se repete', () {
    final bRemoto = _g('b', '002', groupId: 'G');
    expect(run([a, x, bRemoto], [a, b, x], extra: [bRemoto]), ['[a b]', 'x']);
  });

  test('a instância de ordered vence: o trecho da letra do remoto fica', () {
    final bRemoto = _g('b', '002', groupId: 'G').withColdigomMeta(
      const ColdigomPraiseMetadata(
        name: 'Louvor b',
        groupId: 'G',
        lyricsExcerpt: '…a ti pertence…',
      ),
    );
    final index = catalogIndexOf([a, b]);

    final cluster =
        clusterCatalogList(
              [a, bRemoto],
              membersOf: index.membersOf,
              extraMembers: [bRemoto],
            ).single
            as ClusterEntry;

    expect(cluster.praiseGroupId, 'G');
    expect(
      cluster.members.last.group.coldigomMeta?.lyricsExcerpt,
      '…a ti pertence…',
    );
  });
}
```

- [ ] **Passo 2: rodar e ver falhar**

Rodar: `flutter test test/unit/features/catalog/cluster_catalog_list_test.dart`
Esperado: FALHA de compilação (arquivos não existem).

- [ ] **Passo 3: implementar**

Criar `lib/features/catalog/domain/entities/catalog_list_entry.dart`:

```dart
import 'louvor_group.dart';

/// Um item da lista da Home e da /biblioteca (spec louvores-agrupados §4.1):
/// um chip solto ou um amendoim. É a unidade da paginação da /biblioteca; a
/// unidade do app (playlist, `?p=`, «+») continua sendo o praise.
sealed class CatalogListEntry {
  const CatalogListEntry();
}

/// Praise fora de grupo — ou num grupo que só tem ele na lista — como hoje.
final class SingleEntry extends CatalogListEntry {
  const SingleEntry(this.group);

  final LouvorGroup group;
}

/// Grupo do coldigom (`praises.group_id`) com ≥ 2 membros, na ordem fixa
/// (`compareClusterMembers`).
final class ClusterEntry extends CatalogListEntry {
  const ClusterEntry({required this.praiseGroupId, required this.members});

  /// Chave opaca do grupo — nunca um id de praise.
  final String praiseGroupId;
  final List<ClusterMember> members;
}

/// Um gomo do amendoim. [matched] `false` = não casou com a busca ou os
/// filtros e aparece esmaecido, mas clicável (D3).
final class ClusterMember {
  const ClusterMember({required this.group, required this.matched});

  final LouvorGroup group;
  final bool matched;
}
```

Criar `lib/features/catalog/domain/usecases/cluster_catalog_list.dart`:

```dart
import '../entities/catalog_list_entry.dart';
import '../entities/louvor_group.dart';
import 'cluster_member_order.dart';

/// Junta os grupos do coldigom da lista [ordered] em amendoins (spec
/// louvores-agrupados §4.2). [ordered] é a lista já filtrada e ordenada — os
/// que casaram.
///
/// - Membros de um grupo = [membersOf] ∪ [extraMembers] do mesmo
///   `group_id`, sem repetir praiseId, na ordem fixa. [extraMembers] são os
///   que o índice não tem (os «novos» da busca remota).
/// - Instância de cada membro: a de [ordered] se ele casou (a do remoto traz
///   o trecho da letra); senão a do índice; senão a de [extraMembers].
/// - O amendoim sai na posição do primeiro membro em [ordered], com **todos**
///   os membros; as aparições seguintes são puladas.
/// - Grupo que fica com 1 membro depois da soma vira [SingleEntry]; grupo
///   sem membro em [ordered] não aparece.
List<CatalogListEntry> clusterCatalogList(
  List<LouvorGroup> ordered, {
  required List<LouvorGroup> Function(String praiseGroupId) membersOf,
  Iterable<LouvorGroup> extraMembers = const [],
}) {
  final orderedById = <String, LouvorGroup>{
    for (final group in ordered) group.groupId: group,
  };
  final extrasByKey = <String, List<LouvorGroup>>{};
  for (final group in extraMembers) {
    final key = praiseGroupKeyOf(group);
    if (key != null) extrasByKey.putIfAbsent(key, () => []).add(group);
  }

  final clustered = <String>{};
  final entries = <CatalogListEntry>[];
  for (final group in ordered) {
    final key = praiseGroupKeyOf(group);
    if (key == null) {
      entries.add(SingleEntry(group));
      continue;
    }
    if (clustered.contains(key)) continue;

    final byId = <String, LouvorGroup>{};
    for (final member in membersOf(key)) {
      byId.putIfAbsent(member.groupId, () => member);
    }
    for (final member in extrasByKey[key] ?? const <LouvorGroup>[]) {
      byId.putIfAbsent(member.groupId, () => member);
    }
    byId[group.groupId] = group;
    if (byId.length < 2) {
      entries.add(SingleEntry(group));
      continue;
    }

    clustered.add(key);
    final members = [
      for (final member in byId.values) orderedById[member.groupId] ?? member,
    ]..sort(compareClusterMembers);
    entries.add(
      ClusterEntry(
        praiseGroupId: key,
        members: [
          for (final member in members)
            ClusterMember(
              group: member,
              matched: orderedById.containsKey(member.groupId),
            ),
        ],
      ),
    );
  }
  return entries;
}
```

- [ ] **Passo 4: rodar e ver passar**

Rodar: `flutter test test/unit/features/catalog/cluster_catalog_list_test.dart`
Esperado: 8 testes passam.

- [ ] **Passo 5: commit**

```bash
git add lib/features/catalog/domain/entities/catalog_list_entry.dart lib/features/catalog/domain/usecases/cluster_catalog_list.dart test/helpers/coldigom_catalog_test_helpers.dart test/unit/features/catalog/cluster_catalog_list_test.dart
git commit -m "$(cat <<'EOF'
feat(catalog): junção dos grupos do coldigom na lista (clusterCatalogList)

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Tarefa 6: etiqueta de cada gomo (`clusterMemberLabel`)

**Arquivos:**
- Criar: `lib/features/catalog/domain/usecases/cluster_member_label.dart`
- Criar: `test/unit/features/catalog/cluster_member_label_test.dart`

**Interfaces:**
- Consome: `ColdigomPraiseMetadata.tagNames`.
- Produz: `String? clusterMemberLabel(LouvorGroup member, List<LouvorGroup> allMembers)`.

- [ ] **Passo 1: escrever o teste que falha**

Criar `test/unit/features/catalog/cluster_member_label_test.dart`:

```dart
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/usecases/cluster_member_label.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';

LouvorGroup _m(String id, List<String> tags) =>
    catalogGroup(praiseId: id, name: 'Louvor $id', tags: tags);

List<String?> _labels(List<LouvorGroup> members) => [
  for (final m in members) clusterMemberLabel(m, members),
];

void main() {
  test('Clamo a ti: comum some; sem próprias, 1ª tag até o « · »', () {
    expect(
      _labels([
        _m('col', ['Coletânea · Clamor']),
        _m('pes', ['GLTM', 'PES', 'Coletânea · Clamor']),
      ]),
      ['Coletânea', 'GLTM · PES'],
    );
  });

  test('039: SCTB e Solo ficam PES; a da Coletânea fica Coletânea', () {
    expect(
      _labels([
        _m('39', ['Coletânea · Clamor']),
        _m('sctb', ['PES', 'Coletânea · Clamor']),
        _m('solo', ['PES', 'Coletânea · Clamor']),
      ]),
      ['Coletânea', 'PES', 'PES'],
    );
  });

  test('Pelo vale escuro: nada em comum, próprias em ordem alfabética', () {
    expect(
      _labels([
        _m('034', ['Avulsos', 'PES', 'Migrados']),
        _m('307', ['Coletânea · Consolo e Encorajamento']),
      ]),
      ['Avulsos · Migrados · PES', 'Coletânea · Consolo e Encorajamento'],
    );
  });

  test('a ordem de chegada das tags não muda a etiqueta', () {
    final ordemDoDump = [
      _m('034', ['Avulsos', 'Migrados', 'PES']),
      _m('307', ['Coletânea · Consolo e Encorajamento']),
    ];
    final ordemDaBusca = [
      _m('034', ['PES', 'Migrados', 'Avulsos']),
      _m('307', ['Coletânea · Consolo e Encorajamento']),
    ];
    expect(_labels(ordemDoDump), _labels(ordemDaBusca));
  });

  test('acento não bagunça a ordem (Éden entre Alfa e Ester)', () {
    expect(
      clusterMemberLabel(_m('a', ['Ester', 'Éden', 'Alfa']), [
        _m('a', ['Ester', 'Éden', 'Alfa']),
        _m('b', const []),
      ]),
      'Alfa · Éden · Ester',
    );
  });

  test('membro sem tag: sem etiqueta', () {
    expect(
      _labels([
        _m('a', const []),
        _m('b', ['PES']),
      ]),
      [null, 'PES'],
    );
  });

  test('todos com as mesmas tags: cada um mostra a 1ª até o « · »', () {
    expect(
      _labels([
        _m('a', ['Coletânea · Clamor']),
        _m('b', ['Coletânea · Clamor']),
      ]),
      ['Coletânea', 'Coletânea'],
    );
  });
}
```

- [ ] **Passo 2: rodar e ver falhar**

Rodar: `flutter test test/unit/features/catalog/cluster_member_label_test.dart`
Esperado: FALHA de compilação.

- [ ] **Passo 3: implementar**

Criar `lib/features/catalog/domain/usecases/cluster_member_label.dart`:

```dart
import '../../../../core/utils/louvor_search_tokens.dart';
import '../entities/louvor_group.dart';

/// Etiqueta dourada do gomo de [member] no amendoim de [allMembers] (spec
/// louvores-agrupados §5): as tags que ele tem e que nem todos têm, em ordem
/// alfabética, juntas por « · ». Sem nenhuma, a primeira tag dele cortada
/// antes do primeiro « · » («Coletânea · Clamor» → «Coletânea»). Sem tag
/// nenhuma, `null` (sem etiqueta).
///
/// Ordena as tags aqui porque a ordem que chega não serve: o dump manda
/// `ORDER BY label` e a busca remota um `GROUP_CONCAT` sem ordem.
String? clusterMemberLabel(LouvorGroup member, List<LouvorGroup> allMembers) {
  final own = _tagsOf(member).toList()..sort(_compareTags);
  if (own.isEmpty) return null;

  Set<String>? common;
  for (final other in allMembers) {
    final tags = _tagsOf(other);
    common = common == null ? tags : common.intersection(tags);
  }
  final distinct = [
    for (final tag in own)
      if (!(common ?? const <String>{}).contains(tag)) tag,
  ];
  if (distinct.isNotEmpty) return distinct.join(' · ');

  final first = own.first;
  final cut = first.indexOf(' · ');
  return cut == -1 ? first : first.substring(0, cut);
}

Set<String> _tagsOf(LouvorGroup group) => {
  for (final tag in group.coldigomMeta?.tagNames ?? const <String>[])
    if (tag.trim().isNotEmpty) tag.trim(),
};

int _compareTags(String a, String b) {
  final byNorm = LouvorSearchTokens.normalize(
    a,
  ).compareTo(LouvorSearchTokens.normalize(b));
  return byNorm != 0 ? byNorm : a.compareTo(b);
}
```

- [ ] **Passo 4: rodar e ver passar**

Rodar: `flutter test test/unit/features/catalog/cluster_member_label_test.dart`
Esperado: 7 testes passam.

- [ ] **Passo 5: commit**

```bash
git add lib/features/catalog/domain/usecases/cluster_member_label.dart test/unit/features/catalog/cluster_member_label_test.dart
git commit -m "$(cat <<'EOF'
feat(catalog): etiqueta automática de cada versão do grupo

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Tarefa 7: `PeanutLobeBorder`, o gomo com junta de coração

**Arquivos:**
- Criar: `lib/features/carousel/presentation/widgets/chip_parts/peanut_lobe_border.dart`
- Criar: `test/unit/features/carousel/peanut_lobe_border_test.dart`

**Interfaces:**
- Consome: `AppColors` (`lib/core/theme/color_extensions.dart`).
- Produz:
  - `enum LobePosition { first, middle, last }`
  - `LobePosition lobePositionAt(int index, int count)`
  - `const peanutLobeTipInset = 10.0`, `const peanutLobeJunctionReach = 26.0`
  - `Path peanutLobePath(Rect rect, LobePosition position, {required double radius})`: o contorno fechado do gomo, e o mesmo desenho que o cluster usa na sombra
  - `class PeanutLobeBorder extends ShapeBorder` com `const PeanutLobeBorder({required LobePosition position, required double radius})`, `==` por posição e raio, e `dimensions == EdgeInsets.all(2)`

- [ ] **Passo 1: escrever o teste que falha**

Criar `test/unit/features/carousel/peanut_lobe_border_test.dart`:

```dart
import 'package:coldigui/features/carousel/presentation/widgets/chip_parts/peanut_lobe_border.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _w = 300.0;
const _r = 24.0;
const _d = peanutLobeTipInset;

Path _lobe(LobePosition p, double h) =>
    peanutLobePath(const Offset(0, 0) & Size(_w, h), p, radius: _r);

void main() {
  test('lobePositionAt: primeiro, meio e último', () {
    expect(
      [for (var i = 0; i < 3; i++) lobePositionAt(i, 3)],
      [LobePosition.first, LobePosition.middle, LobePosition.last],
    );
    expect(
      [for (var i = 0; i < 2; i++) lobePositionAt(i, 2)],
      [LobePosition.first, LobePosition.last],
    );
  });

  test('primeiro gomo: topo de pílula, bico a 10 px na base', () {
    final path = _lobe(LobePosition.first, 58);

    expect(path.contains(const Offset(_w / 2, 29)), isTrue);
    // Canto de cima arredondado (pílula).
    expect(path.contains(const Offset(_w - 1, 1)), isFalse);
    expect(path.contains(const Offset(1, 1)), isFalse);
    // Na linha da junta, o preenchimento vai até o bico e não além.
    expect(path.contains(const Offset(_w - _d - 1, 57.5)), isTrue);
    expect(path.contains(const Offset(_w - 2, 57.5)), isFalse);
    expect(path.contains(const Offset(_d + 1, 57.5)), isTrue);
    expect(path.contains(const Offset(2, 57.5)), isFalse);
  });

  test('último gomo: bico no topo, base de pílula', () {
    final path = _lobe(LobePosition.last, 58);

    expect(path.contains(const Offset(_w - _d - 1, 0.5)), isTrue);
    expect(path.contains(const Offset(_w - 2, 0.5)), isFalse);
    expect(path.contains(const Offset(_w - 1, 57)), isFalse);
  });

  test('gomo do meio: bico em cima e embaixo, lateral cheia no meio', () {
    final path = _lobe(LobePosition.middle, 40);

    expect(path.contains(const Offset(_w - 2, 0.5)), isFalse);
    expect(path.contains(const Offset(_w - 2, 39.5)), isFalse);
    expect(path.contains(const Offset(_w - 1, 20)), isTrue);
  });

  test('gomo alto (trecho da letra): lateral reta, bico no mesmo lugar', () {
    final path = _lobe(LobePosition.first, 100);

    // Entre a pílula (24) e o começo da curva da junta (100 − 26 = 74).
    for (final y in [30.0, 50.0, 70.0]) {
      expect(path.contains(Offset(_w - 0.5, y)), isTrue, reason: 'y=$y');
      expect(path.contains(Offset(0.5, y)), isTrue, reason: 'y=$y');
    }
    expect(path.contains(const Offset(_w - _d - 1, 99.5)), isTrue);
    expect(path.contains(const Offset(_w - 2, 99.5)), isFalse);
  });

  test('borda: 2 px como o Border.all de hoje; igualdade por posição', () {
    const border = PeanutLobeBorder(position: LobePosition.last, radius: _r);

    expect(border.dimensions, const EdgeInsets.all(2));
    expect(
      border,
      const PeanutLobeBorder(position: LobePosition.last, radius: _r),
    );
    expect(
      border == const PeanutLobeBorder(position: LobePosition.first, radius: _r),
      isFalse,
    );
    expect(
      border.getOuterPath(const Offset(0, 0) & const Size(_w, 58)).getBounds(),
      const Offset(0, 0) & const Size(_w, 58),
    );
  });
}
```

- [ ] **Passo 2: rodar e ver falhar**

Rodar: `flutter test test/unit/features/carousel/peanut_lobe_border_test.dart`
Esperado: FALHA de compilação.

- [ ] **Passo 3: implementar**

Criar `lib/features/carousel/presentation/widgets/chip_parts/peanut_lobe_border.dart`:

```dart
import 'dart:math' as math;

import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:flutter/painting.dart';

/// Posição do gomo no amendoim (spec louvores-agrupados §6.1): o primeiro
/// tem topo de pílula, o último base de pílula; as juntas são meio-coração.
enum LobePosition { first, middle, last }

/// Posição do gomo [index] num amendoim de [count] gomos (`count` ≥ 2).
LobePosition lobePositionAt(int index, int count) {
  if (index == 0) return LobePosition.first;
  if (index == count - 1) return LobePosition.last;
  return LobePosition.middle;
}

/// Recuo do bico em relação à lateral, na linha da junta (`d`).
const peanutLobeTipInset = 10.0;

/// Distância vertical máxima entre a junta e o ponto onde a curva encontra a
/// lateral (`a`).
const peanutLobeJunctionReach = 26.0;

const _strokeWidth = 2.0;

/// Contorno fechado do gomo em [rect]: pílula de raio [radius] nas pontas do
/// amendoim; nas juntas, um arco convexo de cada lado, da lateral até o bico
/// recuado [peanutLobeTipInset] — o topo de um coração. Um gomo mais alto só
/// ganha trecho reto na lateral.
///
/// É também a silhueta que `PeanutClusterColumn` usa para a sombra.
Path peanutLobePath(
  Rect rect,
  LobePosition position, {
  required double radius,
}) => _lobePath(rect, position, radius: radius, outline: false);

/// [outline] `true`: o mesmo caminho, mas sem o trecho da junta entre os
/// bicos (a costura é pintada à parte, pelo gomo de baixo) e sem fechar.
Path _lobePath(
  Rect rect,
  LobePosition position, {
  required double radius,
  required bool outline,
}) {
  const d = peanutLobeTipInset;
  final h = rect.height;
  final a = position == LobePosition.middle
      ? math.min(peanutLobeJunctionReach, h / 2)
      : math.max(1.0, math.min(peanutLobeJunctionReach, h - radius));
  final junction = Radius.circular((d * d + a * a) / (2 * d));
  final pill = Radius.circular(radius);
  final topIsPill = position == LobePosition.first;
  final bottomIsPill = position == LobePosition.last;

  final path = Path();
  void seam(double x, double y) =>
      outline ? path.moveTo(x, y) : path.lineTo(x, y);

  // Topo, da lateral esquerda à direita (sentido horário).
  final start = Offset(rect.left, rect.top + (topIsPill ? radius : a));
  path.moveTo(start.dx, start.dy);
  if (topIsPill) {
    path
      ..arcToPoint(Offset(rect.left + radius, rect.top), radius: pill)
      ..lineTo(rect.right - radius, rect.top)
      ..arcToPoint(Offset(rect.right, rect.top + radius), radius: pill);
  } else {
    path.arcToPoint(Offset(rect.left + d, rect.top), radius: junction);
    seam(rect.right - d, rect.top);
    path.arcToPoint(Offset(rect.right, rect.top + a), radius: junction);
  }

  // Lateral direita e base, da direita à esquerda.
  if (bottomIsPill) {
    path
      ..lineTo(rect.right, rect.bottom - radius)
      ..arcToPoint(Offset(rect.right - radius, rect.bottom), radius: pill)
      ..lineTo(rect.left + radius, rect.bottom)
      ..arcToPoint(Offset(rect.left, rect.bottom - radius), radius: pill);
  } else {
    path
      ..lineTo(rect.right, rect.bottom - a)
      ..arcToPoint(Offset(rect.right - d, rect.bottom), radius: junction);
    seam(rect.left + d, rect.bottom);
    path.arcToPoint(Offset(rect.left, rect.bottom - a), radius: junction);
  }

  // Lateral esquerda, de volta ao começo.
  path.lineTo(start.dx, start.dy);
  if (!outline) path.close();
  return path;
}

/// Borda de **um** gomo do amendoim (variante E «Coração pleno»): contorno
/// dourado de 2 px por dentro, só nas laterais e nas pontas; na junta, só a
/// costura dourada a 60 %, de bico a bico, pintada pelo gomo de baixo (topo
/// de `middle` e `last`) para não pintar duas vezes.
///
/// Gomos empilhados sem espaço formam o amendoim; o preenchimento
/// (`AppColors.title`) vem da `ShapeDecoration` que usa esta borda.
class PeanutLobeBorder extends ShapeBorder {
  const PeanutLobeBorder({required this.position, required this.radius});

  final LobePosition position;

  /// Raio das pontas de pílula — `carouselChipModalRadius`.
  final double radius;

  /// Igual ao `Border.all(width: 2)` do chip solto: o `Container` soma isto
  /// ao padding, e com zero o gomo ficaria 4 px mais baixo que o chip.
  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(_strokeWidth);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      peanutLobePath(rect, position, radius: radius);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      peanutLobePath(
        rect.deflate(_strokeWidth),
        position,
        radius: math.max(0, radius - _strokeWidth),
      );

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    // Traço de 4 px centrado no contorno e recortado pelo próprio gomo = 2 px
    // por dentro, e o bico sai exatamente no ponto do preenchimento.
    canvas
      ..save()
      ..clipPath(getOuterPath(rect))
      ..drawPath(
        _lobePath(rect, position, radius: radius, outline: true),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeWidth * 2
          ..color = AppColors.gold,
      )
      ..restore();

    if (position != LobePosition.first) {
      final y = rect.top + 0.5;
      canvas.drawLine(
        Offset(rect.left + peanutLobeTipInset, y),
        Offset(rect.right - peanutLobeTipInset, y),
        Paint()
          ..strokeWidth = 1
          ..color = AppColors.gold.withValues(alpha: 0.6),
      );
    }
  }

  @override
  ShapeBorder scale(double t) => this;

  @override
  bool operator ==(Object other) =>
      other is PeanutLobeBorder &&
      other.position == position &&
      other.radius == radius;

  @override
  int get hashCode => Object.hash(position, radius);
}
```

- [ ] **Passo 4: rodar e ver passar**

Rodar: `flutter test test/unit/features/carousel/peanut_lobe_border_test.dart`
Esperado: 6 testes passam.

Se um `contains` de borda falhar por meio pixel, **não** mexa na geometria. Recalcule o ponto com a fórmula do spec (`r′ = (d² + a²) / (2d)`, centro em `(w − r′, y_junta ∓ a)`) e ajuste só a coordenada do teste, mantendo a intenção de cada caso.

- [ ] **Passo 5: commit**

```bash
git add lib/features/carousel/presentation/widgets/chip_parts/peanut_lobe_border.dart test/unit/features/carousel/peanut_lobe_border_test.dart
git commit -m "$(cat <<'EOF'
feat(carousel): PeanutLobeBorder — gomo do amendoim com junta de coração

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Tarefa 8: o chip vira gomo (`lobePosition`, `groupLabel`, `dimmed`)

**Arquivos:**
- Criar: `lib/features/carousel/presentation/widgets/chip_parts/chip_group_label.dart`
- Modificar: `lib/features/carousel/presentation/widgets/carousel_louvor_chip.dart`
- Criar: `test/widget/features/carousel/carousel_louvor_chip_lobe_test.dart`

**Interfaces:**
- Consome: `LobePosition` e `PeanutLobeBorder` (Tarefa 7).
- Produz:
  - `const carouselChipModalRadius = 24.0` (público; substitui `_modalChipRadius`);
  - em `CarouselLouvorChip`, os parâmetros opcionais `LobePosition? lobePosition`, `String? groupLabel` e `bool dimmed = false`;
  - `ChipGroupLabel({required String label})`, com `static const maxTextWidth = 128.0`.

- [ ] **Passo 1: escrever o teste que falha**

Criar `test/widget/features/carousel/carousel_louvor_chip_lobe_test.dart`:

```dart
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/carousel/presentation/widgets/chip_parts/peanut_lobe_border.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';

const _item = CarouselItem(
  materialId: 'm1',
  index: 0,
  numero: '003',
  nome: 'Clamo a ti',
  categoria: 'Partitura',
  classificacao: 'Coro',
);

Future<void> _pump(WidgetTester tester, Widget child, {double width = 360}) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('pt'),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
}

Iterable<ShapeDecoration> _shapeDecorations(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(find.byType(DecoratedBox))
    .map((box) => box.decoration)
    .whereType<ShapeDecoration>();

void main() {
  testWidgets('gomo usa a PeanutLobeBorder e não tem sombra própria', (
    tester,
  ) async {
    await _pump(
      tester,
      CarouselLouvorChip(
        item: _item,
        lobePosition: LobePosition.first,
        onAdd: () {},
      ),
    );

    final decoration = _shapeDecorations(tester).single;
    expect(
      decoration.shape,
      const PeanutLobeBorder(
        position: LobePosition.first,
        radius: carouselChipModalRadius,
      ),
    );
    expect(decoration.shadows ?? const <BoxShadow>[], isEmpty);
  });

  testWidgets('gomo e chip solto com o mesmo conteúdo têm a mesma altura', (
    tester,
  ) async {
    await _pump(
      tester,
      Column(
        children: [
          CarouselLouvorChip(
            key: const Key('solto'),
            item: _item,
            onAdd: () {},
          ),
          CarouselLouvorChip(
            key: const Key('gomo'),
            item: _item,
            onAdd: () {},
            lobePosition: LobePosition.middle,
          ),
        ],
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('gomo'))).height,
      tester.getSize(find.byKey(const Key('solto'))).height,
    );
  });

  testWidgets('etiqueta aparece e não passa de 128 px de texto', (
    tester,
  ) async {
    await _pump(
      tester,
      CarouselLouvorChip(
        item: _item,
        lobePosition: LobePosition.last,
        groupLabel: 'Coletânea · Consolo e Encorajamento',
        onAdd: () {},
      ),
    );

    final label = find.text('Coletânea · Consolo e Encorajamento');
    expect(label, findsOneWidget);
    expect(tester.getSize(label).width, lessThanOrEqualTo(128));
  });

  testWidgets('celular de 320 px com etiqueta, «novo», ícones e «+» não '
      'estoura', (tester) async {
    await _pump(
      tester,
      CarouselLouvorChip(
        item: _item,
        lobePosition: LobePosition.first,
        groupLabel: 'Avulsos · Migrados · PES',
        isNew: true,
        materialKindsGroup: catalogGroup(
          praiseId: 'p',
          number: '003',
          name: 'Clamo a ti',
          audioKinds: const {'k-audio': 'Playback'},
        ),
        onAdd: () {},
      ),
      width: 320,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('dimmed esmaece só o conteúdo, não o fundo', (tester) async {
    await _pump(
      tester,
      CarouselLouvorChip(
        item: _item,
        lobePosition: LobePosition.last,
        dimmed: true,
        onTap: () {},
      ),
    );

    final opacity = find.ancestor(
      of: find.text('#003 — Clamo a ti'),
      matching: find.byType(Opacity),
    );
    expect(tester.widget<Opacity>(opacity.first).opacity, 0.45);
    expect(
      find.ancestor(
        of: find.byWidgetPredicate(
          (w) => w is DecoratedBox && w.decoration is ShapeDecoration,
        ),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
  });

  test('gomo só na variante modal e sem setas', () {
    expect(
      () => CarouselLouvorChip(
        item: _item,
        variant: CarouselLouvorChipVariant.topBar,
        lobePosition: LobePosition.first,
      ),
      throwsAssertionError,
    );
    expect(
      () => CarouselLouvorChip(
        item: _item,
        showNavArrows: true,
        lobePosition: LobePosition.first,
      ),
      throwsAssertionError,
    );
  });
}
```

- [ ] **Passo 2: rodar e ver falhar**

Rodar: `flutter test test/widget/features/carousel/carousel_louvor_chip_lobe_test.dart`
Esperado: FALHA de compilação (`lobePosition`, `carouselChipModalRadius` não existem).

- [ ] **Passo 3: implementar**

1. Criar `lib/features/carousel/presentation/widgets/chip_parts/chip_group_label.dart`:

```dart
import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:flutter/material.dart';

/// Etiqueta dourada do gomo do amendoim — o que diferencia aquela versão do
/// grupo (spec louvores-agrupados §5, §6.2). Corta com «…» em
/// [maxTextWidth].
class ChipGroupLabel extends StatelessWidget {
  const ChipGroupLabel({required this.label, super.key});

  final String label;

  static const maxTextWidth = 128.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxTextWidth),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.label.copyWith(
            fontSize: 10,
            height: 1.2,
            color: AppColors.goldLight,
          ),
        ),
      ),
    );
  }
}
```

2. `carousel_louvor_chip.dart`:
   - imports: `'chip_parts/chip_group_label.dart'` e `'chip_parts/peanut_lobe_border.dart'`;
   - trocar `const _modalChipRadius = 24.0;` por:

```dart
/// Raio da pílula (variante modal) — também o das pontas do amendoim
/// (`PeanutLobeBorder`).
const carouselChipModalRadius = 24.0;
```

   - trocar o uso `_modalChipRadius` por `carouselChipModalRadius`;
   - no construtor, depois de `this.isNew = false,`, os três parâmetros e o `assert`:

```dart
    this.lobePosition,
    this.groupLabel,
    this.dimmed = false,
    super.key,
  }) : assert(
         lobePosition == null ||
             (variant == CarouselLouvorChipVariant.modal && !showNavArrows),
         'gomo do amendoim só na variante modal, sem setas',
       );
```

   - campos, depois de `isNew`:

```dart
  /// Gomo do amendoim (spec louvores-agrupados §6.2): troca a pílula pela
  /// [PeanutLobeBorder] desta posição, sem sombra própria (o cluster pinta
  /// uma só) e com padding 20/12 — a curva da junta recua na altura do «+».
  final LobePosition? lobePosition;

  /// Etiqueta dourada da versão, entre o corpo e o «+» (§5).
  final String? groupLabel;

  /// Membro do grupo que não casou com a busca ou os filtros: esmaece só o
  /// conteúdo; fundo e contorno ficam inteiros e o toque continua ativo (D3).
  final bool dimmed;
```

   - em `build`:
     - `padding` passa a:

```dart
    final padding = _isTopBar
        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 4)
        : lobePosition != null
        ? const EdgeInsets.fromLTRB(20, 6, 12, 6)
        : const EdgeInsets.symmetric(horizontal: 8, vertical: 6);
```

     - no `ChipBody`: `borderRadius: _inkRadius(chipRadius),`
     - na `Row` de `body`, logo depois do `Expanded(child: ChipBody(...))`:

```dart
          // Fora do `Expanded`: o `LayoutBuilder` do corpo já recebe a largura
          // sem a etiqueta, e o breakpoint da linha de metadados sai certo.
          if (groupLabel != null) ...[
            const SizedBox(width: 6),
            ChipGroupLabel(label: groupLabel!),
          ],
```

     - depois de `constrainedBody`:

```dart
    final content = dimmed
        ? Opacity(opacity: 0.45, child: constrainedBody)
        : constrainedBody;
```

     - no `Container`, `decoration:` passa a `lobePosition == null ? BoxDecoration(...o de hoje...) : ShapeDecoration(color: backgroundColor, shape: PeanutLobeBorder(position: lobePosition!, radius: carouselChipModalRadius))`;
     - o `child` sem setas (`: constrainedBody,` no fim) passa a `: content,`. Com setas o gomo não existe (`assert`), então esse ramo não muda.
   - método novo na classe:

```dart
  /// Ripple do corpo: no gomo, 24 do lado da pílula e 12 do lado da junta
  /// — o `InkWell` fica recuado pelo padding e não vaza pelo bico.
  BorderRadius _inkRadius(double chipRadius) {
    const pill = Radius.circular(carouselChipModalRadius);
    const joint = Radius.circular(12);
    return switch (lobePosition) {
      null => BorderRadius.circular(chipRadius),
      LobePosition.first => const BorderRadius.vertical(
        top: pill,
        bottom: joint,
      ),
      LobePosition.middle => const BorderRadius.all(joint),
      LobePosition.last => const BorderRadius.vertical(
        top: joint,
        bottom: pill,
      ),
    };
  }
```

- [ ] **Passo 4: rodar e ver passar, e a suíte do chip**

Rodar: `flutter test test/widget/features/carousel/`
Esperado: os 6 testes novos e os antigos do chip, verdes.

- [ ] **Passo 5: commit**

```bash
git add lib/features/carousel/presentation/widgets test/widget/features/carousel/carousel_louvor_chip_lobe_test.dart
git commit -m "$(cat <<'EOF'
feat(carousel): chip vira gomo do amendoim (borda, etiqueta, esmaecido)

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Tarefa 9: `LouvorClusterCard` com sombra única

**Arquivos:**
- Modificar: `lib/features/catalog/presentation/widgets/louvor_group_card.dart`
- Criar: `lib/features/catalog/presentation/widgets/peanut_cluster_column.dart`
- Criar: `lib/features/catalog/presentation/widgets/louvor_cluster_card.dart`
- Criar: `test/widget/features/catalog/louvor_cluster_card_test.dart`

**Interfaces:**
- Consome:
  - `ClusterEntry` e `ClusterMember` (Tarefa 5);
  - `clusterMemberLabel` (Tarefa 6);
  - `LobePosition`, `lobePositionAt` e `peanutLobePath` (Tarefa 7);
  - os parâmetros do chip e `carouselChipModalRadius` (Tarefa 8).
- Produz:
  - `LouvorGroupCard({required LouvorGroup group, bool isNew = false, LobePosition? lobePosition, String? groupLabel, bool dimmed = false, Key? key})`. Com `lobePosition` o card não tem `Padding(bottom: 8)`.
  - `PeanutClusterColumn({required List<Widget> children, double radius = carouselChipModalRadius, List<BoxShadow> shadows = AppColors.shadowMd})`
  - `LouvorClusterCard({required ClusterEntry entry, Set<String> newGroupIds = const {}, Key? key})`

- [ ] **Passo 1: escrever o teste que falha**

Criar `test/widget/features/catalog/louvor_cluster_card_test.dart`:

```dart
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/carousel/presentation/widgets/chip_parts/peanut_lobe_border.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_list_entry.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_cluster_card.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_group_card.dart';
import 'package:coldigui/features/catalog/presentation/widgets/material_sheet.dart';
import 'package:coldigui/features/catalog/presentation/widgets/peanut_cluster_column.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';
import '../../../support/fakes/fake_active_editor.dart';
import '../../../support/fakes/fake_playlists_notifier.dart';

// «Clamo a ti»: Coletânea (casou) e PES (não casou). PDF + áudio em cada um,
// para o toque abrir o sheet (multi-material) e o «+» ir pelo editor.
final _col = catalogGroup(
  praiseId: 'col',
  number: '003',
  name: 'Clamo a ti',
  tags: const ['Coletânea · Clamor'],
  audioKinds: const {'k-audio': 'Playback'},
  groupId: 'G',
);
final _pes = catalogGroup(
  praiseId: 'pes',
  number: '003',
  name: 'Clamo a ti',
  tags: const ['GLTM', 'PES', 'Coletânea · Clamor'],
  audioKinds: const {'k-audio': 'Playback'},
  groupId: 'G',
);

final _entry = ClusterEntry(
  praiseGroupId: 'G',
  members: [
    ClusterMember(group: _col, matched: true),
    ClusterMember(group: _pes, matched: false),
  ],
);

void main() {
  late AppLocalizations pt;

  setUpAll(() async {
    pt = await AppLocalizations.delegate.load(const Locale('pt'));
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<FakeActiveEditor> pumpCluster(
    WidgetTester tester, {
    Set<String> newIds = const {},
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final editor = FakeActiveEditor()..applyAddToActiveToState = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          activePlaylistEditorProvider.overrideWith(() => editor),
          playlistsProvider.overrideWith(FakePlaylistsNotifier.new),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: LouvorClusterCard(entry: _entry, newGroupIds: newIds),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return editor;
  }

  Finder lobe(int k) => find.byType(LouvorGroupCard).at(k);

  testWidgets('um gomo por membro, na ordem, com a etiqueta de cada um', (
    tester,
  ) async {
    await pumpCluster(tester);

    final cards = tester
        .widgetList<LouvorGroupCard>(find.byType(LouvorGroupCard))
        .toList();
    expect([for (final c in cards) c.group.groupId], ['col', 'pes']);
    expect([for (final c in cards) c.lobePosition], [
      LobePosition.first,
      LobePosition.last,
    ]);
    expect(
      find.descendant(of: lobe(0), matching: find.text('Coletânea')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: lobe(1), matching: find.text('GLTM · PES')),
      findsOneWidget,
    );
  });

  testWidgets('tocar no gomo esmaecido abre o sheet daquela versão', (
    tester,
  ) async {
    await pumpCluster(tester);

    await tester.tap(
      find.descendant(of: lobe(1), matching: find.text('#003 — Clamo a ti')),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<MaterialSheet>(find.byType(MaterialSheet)).group.groupId,
      'pes',
    );
  });

  testWidgets('«+» do gomo esmaecido adiciona um material daquela versão', (
    tester,
  ) async {
    final editor = await pumpCluster(tester);

    await tester.tap(
      find.descendant(
        of: lobe(1),
        matching: find.byType(CarouselLouvorAddButton),
      ),
    );
    await tester.pumpAndSettle();

    expect(editor.added, hasLength(1));
    expect([for (final m in _pes.materials) m.id], contains(editor.added.single.id));
  });

  testWidgets('esmaecido só no gomo que não casou', (tester) async {
    await pumpCluster(tester);

    bool isDim(Widget w) => w is Opacity && w.opacity == 0.45;
    expect(
      find.descendant(of: lobe(0), matching: find.byWidgetPredicate(isDim)),
      findsNothing,
    );
    expect(
      find.descendant(of: lobe(1), matching: find.byWidgetPredicate(isDim)),
      findsOneWidget,
    );
  });

  testWidgets('«novo» só no gomo do id novo', (tester) async {
    await pumpCluster(tester, newIds: {'pes'});

    expect(
      find.descendant(of: lobe(0), matching: find.text(pt.searchResultNew)),
      findsNothing,
    );
    expect(
      find.descendant(of: lobe(1), matching: find.text(pt.searchResultNew)),
      findsOneWidget,
    );
  });

  testWidgets('gomos colados, sem sombra própria, numa coluna só', (
    tester,
  ) async {
    await pumpCluster(tester);

    expect(find.byType(PeanutClusterColumn), findsOneWidget);
    final column = tester.getRect(find.byType(PeanutClusterColumn));
    final first = tester.getRect(lobe(0));
    final last = tester.getRect(lobe(1));
    expect(first.bottom, last.top);
    expect(column.height, first.height + last.height);
    for (final box in tester.widgetList<DecoratedBox>(
      find.byType(DecoratedBox),
    )) {
      final decoration = box.decoration;
      if (decoration is ShapeDecoration) {
        expect(decoration.shadows ?? const <BoxShadow>[], isEmpty);
      }
    }
  });
}
```

- [ ] **Passo 2: rodar e ver falhar**

Rodar: `flutter test test/widget/features/catalog/louvor_cluster_card_test.dart`
Esperado: FALHA de compilação.

- [ ] **Passo 3: implementar**

1. `louvor_group_card.dart`:
   - import `package:coldigui/features/carousel/presentation/widgets/chip_parts/peanut_lobe_border.dart`;
   - construtor e campos:

```dart
  const LouvorGroupCard({
    required this.group,
    this.isNew = false,
    this.lobePosition,
    this.groupLabel,
    this.dimmed = false,
    super.key,
  });
```

```dart
  /// Gomo do amendoim (`LouvorClusterCard`) — ver `CarouselLouvorChip`.
  /// Com ele o card não leva o espaço de baixo: quem o põe é o cluster.
  final LobePosition? lobePosition;

  /// Etiqueta dourada da versão (`clusterMemberLabel`).
  final String? groupLabel;

  /// Membro que não casou com a busca ou os filtros (D3).
  final bool dimmed;
```

   - no `build`, o `return Padding(... child: CarouselLouvorChip(...))` passa a:

```dart
    final chip = CarouselLouvorChip(
      // ... os mesmos argumentos de hoje, mais:
      lobePosition: widget.lobePosition,
      groupLabel: widget.groupLabel,
      dimmed: widget.dimmed,
    );
    return widget.lobePosition == null
        ? Padding(padding: const EdgeInsets.only(bottom: 8), child: chip)
        : chip;
```

Os argumentos de hoje continuam **todos**, iguais: `item`, `metadataSummary`, `materialKindsGroup`, `onMaterialKindTap`, `highlightQuery`, `lyricsSnippet`, `onTap`, `onLongPress`, `onAdd`, `isAdded`, `loading`, `offlineAvailability` e `isNew`.

2. Criar `lib/features/catalog/presentation/widgets/peanut_cluster_column.dart`:

```dart
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/carousel/presentation/widgets/chip_parts/peanut_lobe_border.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Coluna dos gomos do amendoim (spec louvores-agrupados §6.3): empilha os
/// filhos na largura toda, sem espaço, e pinta **uma** sombra da silhueta
/// somada — com as alturas medidas de cada gomo e o mesmo desenho da
/// `PeanutLobeBorder` — antes dos filhos.
///
/// Nem um retângulo arredondado nem a sombra de cada gomo servem: o
/// retângulo mostra uma cunha cinza no bico, e as sombras por gomo sangram
/// no gomo de cima.
class PeanutClusterColumn extends MultiChildRenderObjectWidget {
  const PeanutClusterColumn({
    required super.children,
    this.radius = carouselChipModalRadius,
    this.shadows = AppColors.shadowMd,
    super.key,
  });

  final double radius;
  final List<BoxShadow> shadows;

  @override
  RenderPeanutClusterColumn createRenderObject(BuildContext context) =>
      RenderPeanutClusterColumn(radius: radius, shadows: shadows);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderPeanutClusterColumn renderObject,
  ) {
    renderObject
      ..radius = radius
      ..shadows = shadows;
  }
}

class _PeanutClusterParentData extends ContainerBoxParentData<RenderBox> {}

class RenderPeanutClusterColumn extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _PeanutClusterParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _PeanutClusterParentData> {
  RenderPeanutClusterColumn({
    required double radius,
    required List<BoxShadow> shadows,
  }) : _radius = radius,
       _shadows = shadows;

  double _radius;
  set radius(double value) {
    if (value == _radius) return;
    _radius = value;
    markNeedsPaint();
  }

  List<BoxShadow> _shadows;
  set shadows(List<BoxShadow> value) {
    if (listEquals(value, _shadows)) return;
    _shadows = value;
    markNeedsPaint();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PeanutClusterParentData) {
      child.parentData = _PeanutClusterParentData();
    }
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final childConstraints = BoxConstraints.tightFor(width: width);
    var y = 0.0;
    var child = firstChild;
    while (child != null) {
      child.layout(childConstraints, parentUsesSize: true);
      final parentData = child.parentData! as _PeanutClusterParentData;
      parentData.offset = Offset(0, y);
      y += child.size.height;
      child = parentData.nextSibling;
    }
    size = constraints.constrain(Size(width, y));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (childCount >= 2 && _shadows.isNotEmpty) {
      final silhouette = Path();
      var index = 0;
      var child = firstChild;
      while (child != null) {
        final parentData = child.parentData! as _PeanutClusterParentData;
        silhouette.addPath(
          peanutLobePath(
            (offset + parentData.offset) & child.size,
            lobePositionAt(index, childCount),
            radius: _radius,
          ),
          Offset.zero,
        );
        index++;
        child = parentData.nextSibling;
      }
      for (final shadow in _shadows) {
        context.canvas.drawPath(
          silhouette.shift(shadow.offset),
          shadow.toPaint(),
        );
      }
    }
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
```

3. Criar `lib/features/catalog/presentation/widgets/louvor_cluster_card.dart`:

```dart
import 'package:coldigui/features/carousel/presentation/widgets/chip_parts/peanut_lobe_border.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_list_entry.dart';
import 'package:coldigui/features/catalog/domain/usecases/cluster_member_label.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_group_card.dart';
import 'package:coldigui/features/catalog/presentation/widgets/peanut_cluster_column.dart';
import 'package:flutter/widgets.dart';

/// Amendoim na Home e na /biblioteca (spec louvores-agrupados §6.3): um
/// `LouvorGroupCard`-gomo por membro, colados, com a etiqueta da versão.
/// Cada gomo se comporta como o chip de hoje (D6): toque, «+», ícones,
/// offline e «novo» são daquela versão.
class LouvorClusterCard extends StatelessWidget {
  const LouvorClusterCard({
    required this.entry,
    this.newGroupIds = const {},
    super.key,
  });

  final ClusterEntry entry;

  /// Ids com o selo «novo» (`HomeSearchState.newGroupIds`); vazio na
  /// /biblioteca.
  final Set<String> newGroupIds;

  @override
  Widget build(BuildContext context) {
    final groups = [for (final member in entry.members) member.group];
    return Padding(
      // O espaço de baixo do cartão fica por fora: dentro do último gomo ele
      // entraria na altura que desenha a silhueta da sombra.
      padding: const EdgeInsets.only(bottom: 8),
      child: PeanutClusterColumn(
        children: [
          for (final (index, member) in entry.members.indexed)
            LouvorGroupCard(
              key: ValueKey(member.group.groupId),
              group: member.group,
              isNew: newGroupIds.contains(member.group.groupId),
              lobePosition: lobePositionAt(index, entry.members.length),
              groupLabel: clusterMemberLabel(member.group, groups),
              dimmed: !member.matched,
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Passo 4: rodar e ver passar, e os testes do card**

Rodar: `flutter test test/widget/features/catalog/`
Esperado: os 6 testes novos e os antigos de `louvor_group_card_*`, verdes.

- [ ] **Passo 5: commit**

```bash
git add lib/features/catalog/presentation/widgets/louvor_group_card.dart lib/features/catalog/presentation/widgets/peanut_cluster_column.dart lib/features/catalog/presentation/widgets/louvor_cluster_card.dart test/widget/features/catalog/louvor_cluster_card_test.dart
git commit -m "$(cat <<'EOF'
feat(catalog): LouvorClusterCard — o amendoim, com uma sombra só

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Tarefa 10: Home mostra os amendoins

**Arquivos:**
- Modificar: `lib/features/catalog/presentation/providers/home_search_state.dart`
- Modificar: `lib/features/catalog/presentation/providers/home_search_provider.dart:70-142`
- Modificar: `lib/features/catalog/presentation/widgets/home_search_results_sliver.dart`
- Test: `test/unit/features/catalog/home_search_provider_test.dart` (acrescentar testes)

**Interfaces:**
- Consome: `clusterCatalogList`, `CatalogListEntry` (Tarefa 5); `ColdigomSearchIndex.membersOf` (Tarefa 4); `LouvorClusterCard` (Tarefa 9).
- Produz: `HomeSearchState.entries` (`List<CatalogListEntry>`) e o parâmetro nomeado opcional `entries` no construtor. `groups`, `newGroupIds`, `newCount` e `freshness` não mudam.

- [ ] **Passo 1: escrever os testes que falham**

Em `home_search_provider_test.dart`, acrescentar ao fim do `main()`. Os imports de `catalogGroup`, `catalogIndexOf` e `describeEntry` já vêm do helper, mas confira que `../../../helpers/coldigom_catalog_test_helpers.dart` está importado.

```dart
  test('membro remoto de um grupo já na tela entra no amendoim, não no '
      'fim', () async {
    final index = catalogIndexOf([
      catalogGroup(
        praiseId: 'p-001',
        number: '001',
        name: 'Aleluia',
        groupId: 'G',
      ),
      catalogGroup(praiseId: 'p-002', number: '002', name: 'São João'),
    ]);
    final remoteMember = catalogGroup(
      praiseId: 'r-1',
      number: '001',
      name: 'Aleluia (PES)',
      groupId: 'G',
    );
    final source = _RecordingCatalogSource(
      (query) async =>
          CatalogSearchPage(groups: [remoteMember], page: query.page),
    );
    final container = createContainer(source, index: index);
    keepStateAlive(container);
    await pumpEventQueue();

    container
        .read(homeSearchDebouncedQueryProvider.notifier)
        .setImmediate('aleluia');
    await pumpEventQueue();

    final state = container.read(homeSearchStateProvider);
    expect([for (final e in state.entries) describeEntry(e)], [
      '[p-001 r-1]',
    ]);
    // O que a linha de estado conta não muda: continua por praise.
    expect([for (final g in state.groups) g.groupId], ['p-001', 'r-1']);
    expect(state.newGroupIds, {'r-1'});
  });

  test('offline: o grupo vem do índice, com o membro que não casou '
      'esmaecido', () async {
    final index = catalogIndexOf([
      catalogGroup(
        praiseId: 'p-001',
        number: '001',
        name: 'Aleluia',
        groupId: 'G',
      ),
      catalogGroup(
        praiseId: 'p-009',
        number: '009',
        name: 'Hino da PES',
        groupId: 'G',
      ),
    ]);
    final container = createContainer(
      _RecordingCatalogSource.ok(),
      online: false,
      index: index,
    );
    keepStateAlive(container);
    await pumpEventQueue();

    container
        .read(homeSearchDebouncedQueryProvider.notifier)
        .setImmediate('aleluia');
    await pumpEventQueue();

    final state = container.read(homeSearchStateProvider);
    expect(state.offline, isTrue);
    expect([for (final e in state.entries) describeEntry(e)], [
      '[p-001 (p-009)]',
    ]);
  });

  test('sem grupos: entries é um chip por grupo, na ordem de groups', () async {
    final container = createContainer(_RecordingCatalogSource.ok());
    keepStateAlive(container);
    await pumpEventQueue();

    container
        .read(homeSearchDebouncedQueryProvider.notifier)
        .setImmediate('aleluia');
    await pumpEventQueue();

    final state = container.read(homeSearchStateProvider);
    expect(
      [for (final e in state.entries) describeEntry(e)],
      [for (final g in state.groups) g.groupId],
    );
  });
```

- [ ] **Passo 2: rodar e ver falhar**

Rodar: `flutter test test/unit/features/catalog/home_search_provider_test.dart`
Esperado: FALHA de compilação (`entries` não existe).

- [ ] **Passo 3: implementar**

1. `home_search_state.dart`:
   - import `'../../domain/entities/catalog_list_entry.dart'`;
   - construtor:

```dart
  HomeSearchState({
    required this.query,
    required this.localGroups,
    required this.remote,
    this.newGroups = const [],
    this.offline = false,
    this.knownIds = const {},
    List<CatalogListEntry>? entries,
  }) : newGroupIds = {
         for (final g in newGroups)
           if (!knownIds.contains(g.groupId)) g.groupId,
       },
       entries =
           entries ??
           [for (final g in [...localGroups, ...newGroups]) SingleEntry(g)];
```

   - campo, depois de `groups`:

```dart
  /// [groups] como a tela os desenha: os grupos do coldigom juntados em
  /// amendoins (`clusterCatalogList`, spec louvores-agrupados §4.3). Um
  /// «novo» que é membro de um grupo já na tela entra no amendoim, não no
  /// fim. Sem valor no construtor, um chip solto por grupo — o provider
  /// sempre passa o valor juntado.
  final List<CatalogListEntry> entries;
```

2. `home_search_provider.dart`:
   - imports `'../../domain/usecases/cluster_catalog_list.dart'` (e o `catalog_list_entry.dart`, se o analisador pedir);
   - em `homeSearchStateProvider`, depois de `final localGroups = …`: `final index = ref.watch(coldigomSearchIndexProvider);`
   - ramo da query vazia, argumento novo: `entries: clusterCatalogList(localGroups, membersOf: index.membersOf),`
   - ramo offline, o mesmo argumento;
   - ramo com remoto:

```dart
    entries: clusterCatalogList(
      [...localGroups, ...newGroups],
      membersOf: index.membersOf,
      extraMembers: newGroups,
    ),
```

3. `home_search_results_sliver.dart`:
   - imports: `package:coldigui/features/catalog/domain/entities/catalog_list_entry.dart` e `package:coldigui/features/catalog/presentation/widgets/louvor_cluster_card.dart`;
   - o `return SliverList(...)` passa a:

```dart
    final entries = state.entries;
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index == 0) return line;
        return switch (entries[index - 1]) {
          SingleEntry(:final group) => LouvorGroupCard(
            key: ValueKey('card-${group.groupId}'),
            group: group,
            isNew: newIds.contains(group.groupId),
          ),
          final ClusterEntry cluster => LouvorClusterCard(
            key: ValueKey('cluster-${cluster.praiseGroupId}'),
            entry: cluster,
            newGroupIds: newIds,
          ),
        };
      }, childCount: entries.length + 1),
    );
```

   - `results` (`state.groups`) continua sendo usado só no teste de lista vazia.

- [ ] **Passo 4: rodar e ver passar**

Rodar: `flutter test test/unit/features/catalog/ test/widget/features/catalog/`
Esperado: tudo verde, inclusive `home_search_state_test.dart` sem mudança (fallback de `entries`).

- [ ] **Passo 5: commit**

```bash
git add lib/features/catalog/presentation test/unit/features/catalog/home_search_provider_test.dart
git commit -m "$(cat <<'EOF'
feat(home): resultados da busca com os grupos do coldigom em amendoim

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Tarefa 11: /biblioteca pagina cartões e mostra os amendoins

**Arquivos:**
- Renomear e modificar: `lib/features/library/domain/entities/paginated_louvor_groups.dart` → `paginated_catalog_entries.dart`
- Renomear e modificar: `lib/features/library/domain/usecases/paginate_louvor_groups.dart` → `paginate_catalog_entries.dart`
- Modificar: `lib/features/library/data/providers/library_providers.dart`
- Modificar: `lib/features/library/presentation/providers/library_group_results_provider.dart`
- Modificar: `lib/features/library/presentation/pages/library_screen.dart` (~l.276–285)
- Modificar: `lib/l10n/app_pt.arb:107`, `lib/l10n/app_en.arb:107` (+ regerar `app_localizations*.dart`)
- Test: `test/unit/features/library/library_group_results_provider_test.dart` (ajustar e acrescentar)
- Criar: `test/unit/features/library/paginate_catalog_entries_test.dart`

**Interfaces:**
- Consome: `clusterCatalogList`, `CatalogListEntry` e `describeEntry` (Tarefa 5); `membersOf` (Tarefa 4); `LouvorClusterCard` (Tarefa 9).
- Produz:
  - `PaginatedCatalogEntries({items: List<CatalogListEntry>, page, itemsPerPage, totalItems, totalPages})`, com `static const empty`
  - `PaginateCatalogEntries`, chamada como `call(List<CatalogListEntry> entries, {required int page, required int itemsPerPage})`
  - `paginateCatalogEntriesProvider`
  - `libraryEntriesProvider` (`Provider<List<CatalogListEntry>>`)
  - `libraryGroupResultsProvider` (`Provider<PaginatedCatalogEntries>`), com o mesmo nome de hoje

- [ ] **Passo 1: escrever os testes que falham**

1. Criar `test/unit/features/library/paginate_catalog_entries_test.dart`:

```dart
import 'package:coldigui/features/catalog/domain/entities/catalog_list_entry.dart';
import 'package:coldigui/features/library/domain/usecases/paginate_catalog_entries.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';

void main() {
  final entries = <CatalogListEntry>[
    for (var i = 1; i <= 12; i++)
      SingleEntry(catalogGroup(praiseId: 'p$i', name: 'L$i')),
  ];

  test('pagina entradas com as regras de sempre (10 por padrão)', () {
    final page = const PaginateCatalogEntries()(
      entries,
      page: 2,
      itemsPerPage: 10,
    );

    expect(page.totalItems, 12);
    expect(page.totalPages, 2);
    expect([for (final e in page.items) describeEntry(e)], ['p11', 'p12']);
  });

  test('tamanho de página fora da lista cai em 10; página além do fim cai '
      'na última', () {
    final page = const PaginateCatalogEntries()(
      entries,
      page: 9,
      itemsPerPage: 7,
    );

    expect(page.itemsPerPage, 10);
    expect(page.page, 2);
  });

  test('vazio → uma página vazia', () {
    final page = const PaginateCatalogEntries()(
      const [],
      page: 1,
      itemsPerPage: 10,
    );

    expect(page.items, isEmpty);
    expect(page.totalPages, 1);
  });
}
```

2. Em `library_group_results_provider_test.dart`:
   - a função `ids` passa a:

```dart
  List<String> ids(ProviderContainer c) => [
    for (final e in c.read(libraryGroupResultsProvider).items) describeEntry(e),
  ];
```

   - em «ordena por número e pagina», `expect(page.items.first.numero, '011');` passa a:

```dart
    expect(describeEntry(page.items.first), 'p11');
```

   - acrescentar os testes:

```dart
  test('amendoim conta 1 na paginação e não se parte entre páginas', () {
    final c = containerWith([
      for (var i = 1; i <= 12; i++)
        catalogGroup(
          praiseId: 'p$i',
          number: '$i'.padLeft(3, '0'),
          name: 'Louvor $i',
          groupId: i == 10 || i == 11 ? 'G' : null,
        ),
    ]);

    final first = c.read(libraryGroupResultsProvider);
    expect(first.totalItems, 11);
    expect(first.totalPages, 2);
    expect(describeEntry(first.items.last), '[p10 p11]');

    c.read(libraryViewSettingsProvider.notifier).setPage(2);
    expect(ids(c), ['p12']);

    // Página além do fim cai na última, que agora é a 2 (11 cartões).
    c.read(libraryViewSettingsProvider.notifier).setPage(9);
    expect(c.read(libraryGroupResultsProvider).page, 2);
    expect(ids(c), ['p12']);
  });

  test('filtro que deixa um membro de fora: o grupo aparece inteiro, com '
      'ele esmaecido', () {
    final c = containerWith([
      catalogGroup(
        praiseId: 'col',
        number: '003',
        name: 'Clamo a ti',
        tonality: 'Dm',
        groupId: 'G',
      ),
      catalogGroup(
        praiseId: 'pes',
        number: '003',
        name: 'Clamo a ti',
        tonality: 'Em',
        tags: const ['PES'],
        groupId: 'G',
      ),
      catalogGroup(praiseId: 'x', number: '004', name: 'Outro', tonality: 'Em'),
    ]);

    c.read(catalogFiltersProvider.notifier).toggleTonality('Em');

    expect(ids(c), ['[(col) pes]', 'x']);
  });
```

- [ ] **Passo 2: rodar e ver falhar**

Rodar: `flutter test test/unit/features/library/`
Esperado: FALHA de compilação (`paginate_catalog_entries.dart` não existe; `describeEntry` recebe `LouvorGroup`).

- [ ] **Passo 3: implementar**

1. Renomear com histórico:

```bash
git mv lib/features/library/domain/entities/paginated_louvor_groups.dart lib/features/library/domain/entities/paginated_catalog_entries.dart
git mv lib/features/library/domain/usecases/paginate_louvor_groups.dart lib/features/library/domain/usecases/paginate_catalog_entries.dart
```

2. `paginated_catalog_entries.dart` inteiro:

```dart
import '../../../catalog/domain/entities/catalog_list_entry.dart';

/// Página da /biblioteca — em **cartões** (`CatalogListEntry`): um amendoim
/// conta 1 e nunca se parte entre páginas (spec louvores-agrupados §4.3).
class PaginatedCatalogEntries {
  const PaginatedCatalogEntries({
    required this.items,
    required this.page,
    required this.itemsPerPage,
    required this.totalItems,
    required this.totalPages,
  });

  static const empty = PaginatedCatalogEntries(
    items: [],
    page: 1,
    itemsPerPage: 10,
    totalItems: 0,
    totalPages: 1,
  );

  final List<CatalogListEntry> items;
  final int page;
  final int itemsPerPage;
  final int totalItems;
  final int totalPages;
}
```

3. `paginate_catalog_entries.dart` inteiro:

```dart
import '../../../catalog/domain/entities/catalog_list_entry.dart';
import '../entities/paginated_catalog_entries.dart';
import 'paginate_louvores.dart';

/// UC-03 — Paginar as entradas da /biblioteca (mesmas regras de
/// [PaginateLouvores]); o amendoim conta como um item.
class PaginateCatalogEntries {
  const PaginateCatalogEntries();

  PaginatedCatalogEntries call(
    List<CatalogListEntry> entries, {
    required int page,
    required int itemsPerPage,
  }) {
    final perPage = PaginateLouvores.allowedPageSizes.contains(itemsPerPage)
        ? itemsPerPage
        : 10;

    final totalItems = entries.length;
    final totalPages =
        totalItems == 0 ? 1 : (totalItems + perPage - 1) ~/ perPage;
    final safePage = page.clamp(1, totalPages);
    final start = (safePage - 1) * perPage;
    final end = (start + perPage).clamp(0, totalItems);

    return PaginatedCatalogEntries(
      items: start < totalItems ? entries.sublist(start, end) : const [],
      page: safePage,
      itemsPerPage: perPage,
      totalItems: totalItems,
      totalPages: totalPages,
    );
  }
}
```

4. `library_providers.dart`:
   - o import `paginate_louvor_groups.dart` passa a `paginate_catalog_entries.dart`;
   - o provider fica:

```dart
/// Use case UC-03 — paginar as entradas da /biblioteca (amendoim conta 1).
final paginateCatalogEntriesProvider = Provider<PaginateCatalogEntries>((ref) {
  return const PaginateCatalogEntries();
});
```

5. `library_group_results_provider.dart`:
   - imports: `'../../../catalog/domain/entities/catalog_list_entry.dart'` e `'../../../catalog/domain/usecases/cluster_catalog_list.dart'`;
   - trocar `'../../domain/entities/paginated_louvor_groups.dart'` por `'../../domain/entities/paginated_catalog_entries.dart'`;
   - trocar o `libraryGroupResultsProvider` por:

```dart
/// Entradas da /biblioteca: [libraryFilteredGroupsProvider] com os grupos
/// do coldigom juntados em amendoins — grupo inteiro, com quem não casou
/// com os filtros esmaecido (spec louvores-agrupados §4.2–4.3).
final libraryEntriesProvider = Provider<List<CatalogListEntry>>((ref) {
  final groups = ref.watch(libraryFilteredGroupsProvider);
  final index = ref.watch(coldigomSearchIndexProvider);
  return clusterCatalogList(groups, membersOf: index.membersOf);
});

/// Página corrente da /biblioteca — [libraryEntriesProvider] paginado em
/// cartões.
final libraryGroupResultsProvider = Provider<PaginatedCatalogEntries>((ref) {
  final entries = ref.watch(libraryEntriesProvider);
  final view = ref.watch(libraryViewSettingsProvider);
  return ref.watch(paginateCatalogEntriesProvider)(
    entries,
    page: view.page,
    itemsPerPage: view.itemsPerPage,
  );
});
```

6. `library_screen.dart`:
   - imports: `catalog_list_entry.dart` e `louvor_cluster_card.dart`, no mesmo estilo de import do arquivo;
   - o `SliverChildBuilderDelegate` passa a:

```dart
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: EdgeInsets.only(
                          bottom: index < results.items.length - 1 ? 8 : 0,
                        ),
                        child: switch (results.items[index]) {
                          SingleEntry(:final group) => LouvorGroupCard(
                            key: ValueKey('card-${group.groupId}'),
                            group: group,
                          ),
                          final ClusterEntry cluster => LouvorClusterCard(
                            key: ValueKey('cluster-${cluster.praiseGroupId}'),
                            entry: cluster,
                          ),
                        },
                      ),
                      childCount: results.items.length,
                    ),
```

7. l10n, a linha 107 de cada arb:
   - `app_pt.arb`: `"libraryResultsSummary": "Mostrando {from}–{to} de {total} resultados",`
   - `app_en.arb`: `"libraryResultsSummary": "Showing {from}–{to} of {total} results",`

Depois, regerar:

```bash
flutter gen-l10n
git status --short lib/l10n
```

Esperado: os dois `.arb` e `app_localizations_pt.dart`/`app_localizations_en.dart` modificados. O `app_localizations.dart` também pode mudar, no doc do getter.

8. Conferir se sobrou uso dos nomes antigos: `grep -rn "PaginatedLouvorGroups\|PaginateLouvorGroups\|paginateLouvorGroupsProvider" lib test`. O esperado é nenhum resultado.

- [ ] **Passo 4: rodar e ver passar**

Rodar: `flutter test test/unit/features/library/ test/widget/features/library/ 2>/dev/null; flutter test test/unit/features/library/`
Esperado: tudo verde, inclusive a medição «2063 grupos» abaixo de 250 ms. Se `test/widget/features/library/` não existir, o primeiro comando só não acha nada.

- [ ] **Passo 5: commit**

```bash
git add -A lib/features/library lib/l10n test/unit/features/library
git commit -m "$(cat <<'EOF'
feat(biblioteca): pagina cartões e mostra os grupos em amendoim

O resumo passa a «de N resultados»: N conta cartões, e o grupo conta 1.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Tarefa 12: verificação da branch inteira

**Arquivos:** nenhum novo. Só conserte o que as verificações apontarem.

- [ ] **Passo 1: análise estática**

Rodar: `flutter analyze`
Esperado: nenhum problema **novo** em relação a `web/integration`. Para comparar, rode `git stash` ou use a contagem da Tarefa 2, passo 1. Conserte o que for desta entrega: import não usado, `prefer_const`, etc.

- [ ] **Passo 2: suíte inteira**

Rodar: `flutter test`
Esperado: o mesmo número de falhas pré-existentes da linha de base (Tarefa 2, passo 1), e nenhuma nova.

- [ ] **Passo 3: sem sobra dos nomes antigos nem do raio privado**

Rodar: `grep -rn "_modalChipRadius\|PaginatedLouvorGroups\|paginateLouvorGroupsProvider" lib test`
Esperado: nada.

- [ ] **Passo 4: relatório para o dono**

Sem commit se nada mudou. Se o passo 1 ou o 2 exigiram conserto, faça um commit `fix(...)` descrevendo o que foi. Relate:
- a lista de commits (`git log --oneline web/integration..HEAD`);
- as falhas pré-existentes, se houver;
- a conferência visual que falta ao dono: com o PR da API já em produção, abrir o app, buscar «clamo a ti», «039» e «pelo vale escuro» na Home, e abrir a /biblioteca no filtro de tom ou tag que pegue um só membro;
- a branch **não** vai para `web/integration` sem o dono.

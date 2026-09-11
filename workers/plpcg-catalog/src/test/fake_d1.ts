/**
 * D1 falso, mínimo, para os testes de `node:test`.
 *
 * ## Limitações — leia antes de usar
 *
 * **Isto não é um SQLite.** Não há parser de SQL: cada consulta é reconhecida
 * por **prefixo/palavra-chave** do texto e executada à mão sobre `Map`s em
 * memória, chaveados por `${user_id}|${id}`. Só as consultas que
 * `src/playlists/handlers.ts`, `src/audio_flags/handlers.ts`,
 * `src/social/handlers.ts` e `src/auth/session.ts` emitem são suportadas:
 *
 * | consulta | reconhecida por |
 * | --- | --- |
 * | `SELECT … FROM user_playlists WHERE user_id = ? AND id = ?` | `FROM user_playlists` + `AND id = ?` |
 * | `SELECT … FROM user_playlists WHERE user_id = ? AND deleted_at IS NULL ORDER BY …` | `FROM user_playlists` sem `AND id = ?` |
 * | `SELECT … FROM user_playlists WHERE user_id = ? ORDER BY …` (`includeDeleted`) | idem, sem `deleted_at IS NULL` — devolve tombstones |
 * | `SELECT … FROM user_playlists WHERE user_id = ? AND is_published = 1 AND deleted_at IS NULL ORDER BY published_at DESC` (rota social) | idem + `is_published = 1` |
 * | `INSERT INTO user_playlists (…) VALUES (…)` | `INSERT` |
 * | `UPDATE user_playlists SET … WHERE user_id = ? AND id = ?` | `UPDATE` |
 * | `SELECT … FROM user_audio_flags …` | as mesmas quatro formas do `user_playlists` (sem `is_published`) |
 * | `INSERT INTO user_audio_flags (…) VALUES (…)` | `INSERT` |
 * | `UPDATE user_audio_flags SET … WHERE user_id = ? AND id = ?` | `UPDATE` |
 * | `SELECT username FROM users WHERE google_sub = ?` (via `getUsername`) | `FROM users` + `google_sub = ?` |
 * | `SELECT google_sub FROM users WHERE username = ?` (rota social) | `FROM users` + `username = ?` |
 * | `SELECT COUNT(*) … FROM short_links WHERE created_by = ? AND created_at >= ?` (teto de abuso, `links/handlers.ts`) | `SELECT COUNT` + `short_links` |
 * | `SELECT code FROM short_links WHERE created_by = ? AND query = ?` (reuso) | `short_links` + `created_by = ?` + `query = ?` |
 * | `SELECT … FROM short_links WHERE code = ?` (`GET /l/:code`) | `short_links` + `WHERE code = ?` |
 * | `INSERT INTO short_links (…) VALUES (…) ON CONFLICT(code) DO NOTHING RETURNING code` | `INSERT INTO short_links` |
 * | `UPDATE short_links SET hits = hits + 1 WHERE code = ?` | `UPDATE short_links` |
 *
 * O soft delete de `softDeletePlaylist`/`softDeleteAudioFlag` é um `UPDATE` e
 * cai no mesmo caminho. `short_links` não segue o modelo `user_id`+`id`
 * das outras duas tabelas — a chave é só `code` — por isso tem um caminho
 * próprio em vez de reaproveitar `tableFor`/`selectRows`.
 * A projeção do `SELECT` **não** é modelada: o fake devolve a linha inteira,
 * então tirar uma coluna de `SELECT_COLS` não faz nenhum teste falhar aqui.
 * A lista de colunas do `INSERT`/`UPDATE` é lida do próprio SQL, então mudar a
 * **ordem** dos `?` no handler continua funcionando; **acrescentar uma consulta
 * nova** exige estender este arquivo (ele lança em vez de devolver algo errado
 * em silêncio).
 *
 * Não implementa: `JOIN` (logo, o `searchSocialUsers`), `LIMIT`, `ORDER BY` de
 * verdade (a listagem ordena na mão por `updated_at` desc, ou por
 * `published_at` desc quando o SQL pede), tipos, constraints, transações,
 * `batch`, `exec`, `dump` nem `withSession`.
 */

export interface PlaylistRow {
  id: string;
  user_id: string;
  nome: string;
  items: string;
  pdf_ids: string;
  audio_ids: string;
  salva: number;
  saved_at: string | null;
  favorita: number;
  favorited_at: string | null;
  created_at: string;
  updated_at: string;
  version: number;
  deleted_at: string | null;
  is_published: number;
  publication_reach: string | null;
  publication_category: string | null;
  published_at: string | null;
}

export interface ShortLinkRow {
  code: string;
  query: string;
  created_by: string;
  created_at: number;
  hits: number;
}

export interface AudioFlagRow {
  id: string;
  user_id: string;
  audio_id: string;
  position_ms: number;
  label: string;
  created_at: string;
  updated_at: string;
  version: number;
  deleted_at: string | null;
}

/** O que as duas tabelas têm em comum para o fake: chave e LWW. */
interface StoredRow {
  id: string;
  user_id: string;
  updated_at: string;
  version: number;
  deleted_at: string | null;
}

export interface FakeD1Options {
  /** Linhas de `users` (a rota social resolve `username` → `google_sub`). */
  users?: Array<{ google_sub: string; username: string }>;
  /** Linhas de `user_audio_flags`. */
  audioFlags?: AudioFlagRow[];
  /** Linhas de `short_links`. */
  shortLinks?: ShortLinkRow[];
}

function key(userId: string, id: string): string {
  return `${userId}|${id}`;
}

/** Uma linha de `user_playlists` com os defaults do schema já aplicados. */
export function playlistRow(overrides: Partial<PlaylistRow> = {}): PlaylistRow {
  return {
    id: 'p1',
    user_id: 'u1',
    nome: 'Ensaio',
    items: '[]',
    pdf_ids: '[]',
    audio_ids: '[]',
    salva: 1,
    saved_at: null,
    favorita: 0,
    favorited_at: null,
    created_at: '2026-09-01T10:00:00.000Z',
    updated_at: '2026-09-01T10:00:00.000Z',
    version: 1,
    deleted_at: null,
    is_published: 0,
    publication_reach: null,
    publication_category: null,
    published_at: null,
    ...overrides,
  };
}

/** Uma linha de `short_links` com os defaults do schema já aplicados. */
export function shortLinkRow(overrides: Partial<ShortLinkRow> = {}): ShortLinkRow {
  return {
    code: 'abc1234',
    query: 'shareitems=p%3Aa',
    created_by: 'u1',
    created_at: Date.parse('2026-09-01T10:00:00.000Z'),
    hits: 0,
    ...overrides,
  };
}

/** Uma linha de `user_audio_flags` com os defaults do schema já aplicados. */
export function audioFlagRow(
  overrides: Partial<AudioFlagRow> = {},
): AudioFlagRow {
  return {
    id: 'f1',
    user_id: 'u1',
    audio_id: 'a1.mp3',
    position_ms: 1000,
    label: 'refrão',
    created_at: '2026-09-01T10:00:00.000Z',
    updated_at: '2026-09-01T10:00:00.000Z',
    version: 1,
    deleted_at: null,
    ...overrides,
  };
}

/** Colunas do `INSERT INTO <tabela> (a, b, c) VALUES (?, ?, 1, …)`. */
function insertPlan(sql: string): { columns: string[]; values: string[] } {
  const columnsMatch = /\(([^)]*)\)\s*VALUES\s*\(([^)]*)\)/is.exec(sql);
  if (!columnsMatch) throw new Error(`fake D1: INSERT não reconhecido: ${sql}`);
  return {
    columns: columnsMatch[1].split(',').map((c) => c.trim()),
    values: columnsMatch[2].split(',').map((v) => v.trim()),
  };
}

/** Pares `coluna = ?` (ou `coluna = <literal>`) de um `UPDATE … SET`. */
function updatePlan(sql: string): Array<{ column: string; value: string }> {
  const setMatch = /SET\s+(.*?)\s+WHERE/is.exec(sql);
  if (!setMatch) throw new Error(`fake D1: UPDATE não reconhecido: ${sql}`);
  return setMatch[1].split(',').map((assignment) => {
    const [column, value] = assignment.split('=');
    if (value === undefined) {
      throw new Error(`fake D1: atribuição não reconhecida: ${assignment}`);
    }
    return { column: column.trim(), value: value.trim() };
  });
}

/**
 * Resolve um token do SQL: `?` consome o próximo binding, senão é literal
 * (`1`, `NULL`, `version + 1`).
 */
function resolveToken(
  token: string,
  bindings: unknown[],
  cursor: { next: number },
  current: { version: number } | undefined,
): unknown {
  if (token === '?') return bindings[cursor.next++];
  if (token === 'NULL') return null;
  if (/^version\s*\+\s*1$/i.test(token)) return (current?.version ?? 0) + 1;
  const asNumber = Number(token);
  if (!Number.isNaN(asNumber)) return asNumber;
  throw new Error(`fake D1: token não reconhecido: ${token}`);
}

// Sem "parameter properties" (`constructor(private x)`): o
// `--experimental-strip-types` do runner de testes só apaga tipos, não gera
// código, então essa açúcar sintático é rejeitado.
class FakeStatement {
  readonly db: FakeD1Database;
  readonly sql: string;
  readonly bindings: unknown[];

  constructor(db: FakeD1Database, sql: string, bindings: unknown[] = []) {
    this.db = db;
    this.sql = sql;
    this.bindings = bindings;
  }

  bind(...values: unknown[]): FakeStatement {
    return new FakeStatement(this.db, this.sql, values);
  }

  async first<T>(): Promise<T | null> {
    const rows = this.db.runQuery(this.sql, this.bindings);
    return (rows[0] as T) ?? null;
  }

  async all<T>(): Promise<{ results: T[]; success: true }> {
    return { results: this.db.runQuery(this.sql, this.bindings) as T[], success: true };
  }

  async run(): Promise<{ success: true }> {
    this.db.runQuery(this.sql, this.bindings);
    return { success: true };
  }
}

export class FakeD1Database {
  /** Linhas de `user_playlists`, por `user_id` + `id`. */
  readonly playlists = new Map<string, PlaylistRow>();
  /** Linhas de `user_audio_flags`, por `user_id` + `id`. */
  readonly audioFlags = new Map<string, AudioFlagRow>();
  /** `user_id` → `username`, para o `getUsername` da publicação. */
  readonly usernames = new Map<string, string>();
  /** `username` → `user_id`, para a rota social. */
  readonly usersByUsername = new Map<string, string>();
  /** Linhas de `short_links`, por `code` — chave simples, não `user_id`+`id`. */
  readonly shortLinks = new Map<string, ShortLinkRow>();
  /** Todo SQL executado, na ordem — útil para asserções de "não escreveu". */
  readonly executed: string[] = [];

  constructor(rows: PlaylistRow[] = [], options: FakeD1Options = {}) {
    for (const row of rows) this.seed(row);
    for (const row of options.audioFlags ?? []) this.seedAudioFlag(row);
    for (const row of options.shortLinks ?? []) this.seedShortLink(row);
    for (const user of options.users ?? []) {
      this.usernames.set(user.google_sub, user.username);
      this.usersByUsername.set(user.username, user.google_sub);
    }
  }

  seed(row: PlaylistRow): this {
    this.playlists.set(key(row.user_id, row.id), row);
    return this;
  }

  seedAudioFlag(row: AudioFlagRow): this {
    this.audioFlags.set(key(row.user_id, row.id), row);
    return this;
  }

  seedShortLink(row: ShortLinkRow): this {
    this.shortLinks.set(row.code, row);
    return this;
  }

  get(userId: string, id: string): PlaylistRow | undefined {
    return this.playlists.get(key(userId, id));
  }

  getAudioFlag(userId: string, id: string): AudioFlagRow | undefined {
    return this.audioFlags.get(key(userId, id));
  }

  getShortLink(code: string): ShortLinkRow | undefined {
    return this.shortLinks.get(code);
  }

  prepare(sql: string): FakeStatement {
    return new FakeStatement(this, sql, []);
  }

  /** @internal — usado pelo `FakeStatement`. */
  runQuery(sql: string, bindings: unknown[]): unknown[] {
    this.executed.push(sql);
    const normalized = sql.replace(/\s+/g, ' ').trim();

    if (/^SELECT/i.test(normalized)) {
      if (/FROM users/i.test(normalized)) {
        return this.selectUsers(normalized, bindings);
      }
      if (/short_links/i.test(normalized)) {
        return this.selectShortLinks(normalized, bindings);
      }
      const table = this.tableFor(normalized);
      if (!table) {
        throw new Error(`fake D1: SELECT não suportado: ${normalized}`);
      }
      return selectRows(table, normalized, bindings);
    }

    if (/^INSERT INTO short_links/i.test(normalized)) {
      return this.insertShortLink(normalized, bindings);
    }

    if (/^INSERT INTO/i.test(normalized)) {
      const table = this.tableFor(normalized);
      if (!table) {
        throw new Error(`fake D1: INSERT não suportado: ${normalized}`);
      }
      const { columns, values } = insertPlan(normalized);
      const cursor = { next: 0 };
      const row = {} as Record<string, unknown>;
      columns.forEach((column, i) => {
        row[column] = resolveToken(values[i], bindings, cursor, undefined);
      });
      const built = row as unknown as StoredRow;
      table.set(key(built.user_id, built.id), built);
      return [];
    }

    if (/^UPDATE short_links/i.test(normalized)) {
      const code = bindings[bindings.length - 1] as string;
      const current = this.shortLinks.get(code);
      if (!current) {
        throw new Error(`fake D1: UPDATE em short_links ausente: ${code}`);
      }
      this.shortLinks.set(code, { ...current, hits: current.hits + 1 });
      return [];
    }

    if (/^UPDATE /i.test(normalized)) {
      const table = this.tableFor(normalized);
      if (!table) {
        throw new Error(`fake D1: UPDATE não suportado: ${normalized}`);
      }
      const assignments = updatePlan(normalized);
      const cursor = { next: 0 };
      // O `WHERE user_id = ? AND id = ?` consome os dois últimos bindings.
      const userId = bindings[bindings.length - 2] as string;
      const id = bindings[bindings.length - 1] as string;
      const current = table.get(key(userId, id));
      if (!current) throw new Error(`fake D1: UPDATE em linha ausente: ${id}`);
      const next = { ...current } as Record<string, unknown>;
      for (const { column, value } of assignments) {
        next[column] = resolveToken(value, bindings, cursor, current);
      }
      table.set(key(userId, id), next as unknown as StoredRow);
      return [];
    }

    throw new Error(`fake D1: consulta não suportada: ${normalized}`);
  }

  /** `user_playlists` / `user_audio_flags` citada no SQL, ou `null`. */
  private tableFor(normalized: string): Map<string, StoredRow> | null {
    if (/user_playlists/i.test(normalized)) {
      return this.playlists as unknown as Map<string, StoredRow>;
    }
    if (/user_audio_flags/i.test(normalized)) {
      return this.audioFlags as unknown as Map<string, StoredRow>;
    }
    return null;
  }

  /** As duas leituras de `users`: por `google_sub` e por `username`. */
  private selectUsers(normalized: string, bindings: unknown[]): unknown[] {
    if (/username = \?/i.test(normalized)) {
      const googleSub = this.usersByUsername.get(bindings[0] as string);
      return googleSub === undefined ? [] : [{ google_sub: googleSub }];
    }
    const username = this.usernames.get(bindings[0] as string);
    return username === undefined ? [] : [{ username }];
  }

  /**
   * As três leituras de `short_links` (`links/handlers.ts`): teto de abuso
   * (`COUNT`), reuso (`created_by` + `query`) e resolução pública (`code`).
   */
  private selectShortLinks(normalized: string, bindings: unknown[]): unknown[] {
    if (/^SELECT COUNT/i.test(normalized)) {
      const createdBy = bindings[0] as string;
      const cutoff = bindings[1] as number;
      const count = [...this.shortLinks.values()].filter(
        (row) => row.created_by === createdBy && row.created_at >= cutoff,
      ).length;
      return [{ count }];
    }

    if (/created_by = \?/i.test(normalized) && /query = \?/i.test(normalized)) {
      const createdBy = bindings[0] as string;
      const query = bindings[1] as string;
      const row = [...this.shortLinks.values()].find(
        (r) => r.created_by === createdBy && r.query === query,
      );
      return row ? [row] : [];
    }

    if (/WHERE code = \?/i.test(normalized)) {
      const row = this.shortLinks.get(bindings[0] as string);
      return row ? [row] : [];
    }

    throw new Error(`fake D1: SELECT short_links não suportado: ${normalized}`);
  }

  /**
   * `INSERT INTO short_links (…) VALUES (…) ON CONFLICT(code) DO NOTHING
   * RETURNING code`: colisão de `code` devolve `[]` (nenhuma linha —
   * `.first()` do chamador lê `null` e tenta outro código); sem colisão,
   * grava e devolve a linha para o `RETURNING`.
   */
  private insertShortLink(normalized: string, bindings: unknown[]): unknown[] {
    const { columns, values } = insertPlan(normalized);
    const cursor = { next: 0 };
    const row = {} as Record<string, unknown>;
    columns.forEach((column, i) => {
      row[column] = resolveToken(values[i], bindings, cursor, undefined);
    });
    const built = row as unknown as ShortLinkRow;
    if (this.shortLinks.has(built.code)) {
      return [];
    }
    this.shortLinks.set(built.code, built);
    return [built];
  }
}

/** Aplica na mão o `WHERE`/`ORDER BY` das listagens e do `first` por id. */
function selectRows(
  table: Map<string, StoredRow>,
  normalized: string,
  bindings: unknown[],
): unknown[] {
  const keepDeleted = !/deleted_at IS NULL/i.test(normalized);

  if (/AND id = \?/i.test(normalized)) {
    const row = table.get(key(bindings[0] as string, bindings[1] as string));
    // O soft delete seleciona a linha mesmo já apagada, para distinguir 404 de
    // "apagar de novo".
    if (!row) return [];
    if (!keepDeleted && row.deleted_at !== null) return [];
    return [row];
  }

  const onlyPublished = /is_published = 1/i.test(normalized);
  const rows = [...table.values()].filter(
    (row) =>
      row.user_id === bindings[0] &&
      (keepDeleted || row.deleted_at === null) &&
      (!onlyPublished ||
        (row as unknown as PlaylistRow).is_published === 1),
  );

  if (/ORDER BY published_at DESC/i.test(normalized)) {
    return rows.sort((a, b) =>
      ((b as unknown as PlaylistRow).published_at ?? '').localeCompare(
        (a as unknown as PlaylistRow).published_at ?? '',
      ),
    );
  }
  return rows.sort((a, b) => b.updated_at.localeCompare(a.updated_at));
}

/** O `FakeD1Database` no formato que os handlers tipam (`D1Database`). */
export function fakeDb(db: FakeD1Database): D1Database {
  return db as unknown as D1Database;
}

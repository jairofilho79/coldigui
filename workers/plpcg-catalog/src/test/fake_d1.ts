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
 * | `SELECT … FROM user_material_kind_prefs WHERE user_id = ?` | `user_material_kind_prefs` (chave só de `user_id`, não passa por `tableFor`) |
 * | `INSERT INTO user_material_kind_prefs (…) VALUES (…)` | idem |
 * | `UPDATE user_material_kind_prefs SET … WHERE user_id = ?` | idem |
 * | `SELECT username, name FROM users WHERE google_sub = ?` (via `getUsername`/`live/handlers.ts`) | `FROM users` + `google_sub = ?` |
 * | `SELECT google_sub FROM users WHERE username = ?` (rota social) | `FROM users` + `username = ?` |
 * | `SELECT code FROM live_rooms WHERE owner_sub = ?` (`live/handlers.ts`) | `live_rooms` + `owner_sub = ?` |
 * | `SELECT code FROM live_rooms WHERE code = ?` | `live_rooms`, sem `owner_sub = ?` |
 * | `INSERT INTO live_rooms (…) VALUES (…) ON CONFLICT DO NOTHING RETURNING code` | `live_rooms` + `INSERT` |
 * | `UPDATE live_rooms SET code = ? WHERE owner_sub = ? RETURNING code` (regenerar) | `live_rooms` + `UPDATE` |
 * | `SELECT COUNT(*) … FROM short_links WHERE created_by = ? AND created_at >= ?` (teto de abuso, `links/handlers.ts`) | `SELECT COUNT` + `short_links` |
 * | `SELECT code FROM short_links WHERE created_by = ? AND query = ?` (reuso) | `short_links` + `created_by = ?` + `query = ?` |
 * | `SELECT … FROM short_links WHERE code = ?` (`GET /l/:code`) | `short_links` + `WHERE code = ?` |
 * | `INSERT INTO short_links (…) VALUES (…) ON CONFLICT DO NOTHING RETURNING code` | `INSERT INTO short_links` |
 * | `UPDATE short_links SET hits = hits + 1 WHERE code = ?` | `UPDATE short_links` |
 * | `DELETE FROM user_sessions WHERE expires_at < ?` (purga, `auth/user_sessions.ts`) | `user_sessions` + `expires_at < ?` |
 * | `INSERT INTO user_sessions (…) VALUES (…)` | `user_sessions` |
 * | `SELECT google_sub, last_seen_at FROM user_sessions WHERE token_hash = ? AND expires_at > ?` | `user_sessions` + `SELECT` |
 * | `UPDATE user_sessions SET last_seen_at = ?, expires_at = ? WHERE token_hash = ?` | `user_sessions` + `UPDATE` |
 * | `DELETE FROM user_sessions WHERE token_hash = ?` (revogação) | `user_sessions` + `token_hash = ?` |
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

/** Linha de `user_material_kind_prefs` (um documento por usuário). */
export interface MaterialKindPrefsRow {
  user_id: string;
  kind_ids: string;
  /** Opcional nos seeds de teste — linhas antigas não tinham a coluna. */
  preferred_types?: string;
  updated_at: string;
  version: number;
}

/** Linha de `user_sessions` (chave `token_hash`). */
export interface SessionRow {
  token_hash: string;
  google_sub: string;
  created_at: string;
  last_seen_at: string;
  expires_at: string;
}

/** Linha de `live_rooms` (chave `code`; `owner_sub` único). */
export interface LiveRoomRow {
  code: string;
  owner_sub: string;
  created_at: string;
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
  users?: Array<{ google_sub: string; username: string; name?: string }>;
  /** Linhas de `user_audio_flags`. */
  audioFlags?: AudioFlagRow[];
  /** Linhas de `short_links`. */
  shortLinks?: ShortLinkRow[];
  /** Linhas de `user_material_kind_prefs`. */
  materialKindPrefs?: MaterialKindPrefsRow[];
  /** Linhas de `user_sessions`. */
  sessions?: SessionRow[];
  /** Linhas de `live_rooms`. */
  liveRooms?: LiveRoomRow[];
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
  /** Linhas de `user_material_kind_prefs`, por `user_id`. */
  readonly materialKindPrefs = new Map<string, MaterialKindPrefsRow>();
  /** Linhas de `user_sessions`, por `token_hash`. */
  readonly sessions = new Map<string, SessionRow>();
  /** `user_id` → `name`, para o `ownerNameOf` da Lista ao Vivo. */
  readonly userNames = new Map<string, string>();
  /** Linhas de `live_rooms`, por `code`. */
  readonly liveRooms = new Map<string, LiveRoomRow>();
  /** Todo SQL executado, na ordem — útil para asserções de "não escreveu". */
  readonly executed: string[] = [];

  constructor(rows: PlaylistRow[] = [], options: FakeD1Options = {}) {
    for (const row of rows) this.seed(row);
    for (const row of options.audioFlags ?? []) this.seedAudioFlag(row);
    for (const row of options.shortLinks ?? []) this.seedShortLink(row);
    for (const row of options.materialKindPrefs ?? []) {
      this.materialKindPrefs.set(row.user_id, row);
    }
    for (const row of options.sessions ?? []) this.sessions.set(row.token_hash, row);
    for (const row of options.liveRooms ?? []) this.liveRooms.set(row.code, row);
    for (const user of options.users ?? []) {
      this.usernames.set(user.google_sub, user.username);
      this.usersByUsername.set(user.username, user.google_sub);
      if (user.name) this.userNames.set(user.google_sub, user.name);
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

    // `user_material_kind_prefs` tem chave só de `user_id` — não passa pelo
    // `tableFor` genérico (que espera `user_id` + `id`) — por isso o
    // despacho próprio, antes das três formas comuns abaixo.
    if (/user_material_kind_prefs/i.test(normalized)) {
      return this.runMaterialKindPrefs(normalized, bindings);
    }

    // `user_sessions` tem chave `token_hash` e é a única tabela com DELETE.
    if (/user_sessions/i.test(normalized)) {
      return this.runUserSessions(normalized, bindings);
    }

    // `live_rooms` tem chave `code` e índice único `owner_sub`.
    if (/live_rooms/i.test(normalized)) {
      return this.runLiveRooms(normalized, bindings);
    }

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

  /**
   * `user_material_kind_prefs` é a única tabela com chave só de `user_id`:
   * SELECT por usuário, INSERT com `version = 1` literal e UPDATE cujo WHERE
   * consome o último binding.
   */
  private runMaterialKindPrefs(normalized: string, bindings: unknown[]): unknown[] {
    if (/^SELECT/i.test(normalized)) {
      const row = this.materialKindPrefs.get(bindings[0] as string);
      return row ? [row] : [];
    }
    if (/^INSERT INTO/i.test(normalized)) {
      const { columns, values } = insertPlan(normalized);
      const cursor = { next: 0 };
      const row = {} as Record<string, unknown>;
      columns.forEach((column, i) => {
        row[column] = resolveToken(values[i], bindings, cursor, undefined);
      });
      const built = row as unknown as MaterialKindPrefsRow;
      this.materialKindPrefs.set(built.user_id, built);
      return [];
    }
    if (/^UPDATE/i.test(normalized)) {
      const assignments = updatePlan(normalized);
      const cursor = { next: 0 };
      const userId = bindings[bindings.length - 1] as string;
      const current = this.materialKindPrefs.get(userId);
      if (!current) throw new Error(`fake D1: UPDATE em prefs ausente: ${userId}`);
      const next = { ...current } as Record<string, unknown>;
      for (const { column, value } of assignments) {
        next[column] = resolveToken(value, bindings, cursor, undefined);
      }
      this.materialKindPrefs.set(userId, next as unknown as MaterialKindPrefsRow);
      return [];
    }
    throw new Error(`fake D1: prefs não suportado: ${normalized}`);
  }

  /**
   * `user_sessions`: SELECT por `token_hash` com `expires_at > ?`, INSERT,
   * UPDATE de renovação (WHERE consome o último binding) e os dois DELETEs
   * (revogação por hash e purga por `expires_at < ?`).
   */
  private runUserSessions(normalized: string, bindings: unknown[]): unknown[] {
    if (/^SELECT/i.test(normalized)) {
      const row = this.sessions.get(bindings[0] as string);
      if (!row) return [];
      return row.expires_at > (bindings[1] as string) ? [row] : [];
    }
    if (/^INSERT INTO/i.test(normalized)) {
      const { columns, values } = insertPlan(normalized);
      const cursor = { next: 0 };
      const row = {} as Record<string, unknown>;
      columns.forEach((column, i) => {
        row[column] = resolveToken(values[i], bindings, cursor, undefined);
      });
      const built = row as unknown as SessionRow;
      this.sessions.set(built.token_hash, built);
      return [];
    }
    if (/^UPDATE/i.test(normalized)) {
      const assignments = updatePlan(normalized);
      const cursor = { next: 0 };
      const hash = bindings[bindings.length - 1] as string;
      const current = this.sessions.get(hash);
      if (!current) throw new Error(`fake D1: UPDATE em sessão ausente: ${hash}`);
      const next = { ...current } as Record<string, unknown>;
      for (const { column, value } of assignments) {
        next[column] = resolveToken(value, bindings, cursor, undefined);
      }
      this.sessions.set(hash, next as unknown as SessionRow);
      return [];
    }
    if (/^DELETE/i.test(normalized)) {
      if (/expires_at < \?/i.test(normalized)) {
        const cutoff = bindings[0] as string;
        for (const [hash, row] of this.sessions) {
          if (row.expires_at < cutoff) this.sessions.delete(hash);
        }
        return [];
      }
      this.sessions.delete(bindings[0] as string);
      return [];
    }
    throw new Error(`fake D1: user_sessions não suportado: ${normalized}`);
  }

  /** As duas leituras de `users`: por `google_sub` e por `username`. */
  private selectUsers(normalized: string, bindings: unknown[]): unknown[] {
    if (/username = \?/i.test(normalized)) {
      const googleSub = this.usersByUsername.get(bindings[0] as string);
      return googleSub === undefined ? [] : [{ google_sub: googleSub }];
    }
    const sub = bindings[0] as string;
    const username = this.usernames.get(sub);
    if (username === undefined) return [];
    return [{ username, name: this.userNames.get(sub) ?? null }];
  }

  /**
   * `live_rooms` (`live/handlers.ts`): SELECT por `owner_sub` ou por `code`,
   * INSERT com `ON CONFLICT DO NOTHING RETURNING code` (colisão de código ou
   * dono que já tem sala) e UPDATE do `code` por `owner_sub` (regenerar).
   */
  private runLiveRooms(normalized: string, bindings: unknown[]): unknown[] {
    if (/^SELECT/i.test(normalized)) {
      if (/owner_sub = \?/i.test(normalized)) {
        for (const row of this.liveRooms.values()) {
          if (row.owner_sub === bindings[0]) return [row];
        }
        return [];
      }
      const row = this.liveRooms.get(bindings[0] as string);
      return row ? [row] : [];
    }
    if (/^INSERT INTO/i.test(normalized)) {
      const { columns, values } = insertPlan(normalized);
      const cursor = { next: 0 };
      const row = {} as Record<string, unknown>;
      columns.forEach((column, i) => {
        row[column] = resolveToken(values[i], bindings, cursor, undefined);
      });
      const built = row as unknown as LiveRoomRow;
      if (this.liveRooms.has(built.code)) return [];
      for (const existing of this.liveRooms.values()) {
        if (existing.owner_sub === built.owner_sub) return [];
      }
      this.liveRooms.set(built.code, built);
      return [{ code: built.code }];
    }
    if (/^UPDATE/i.test(normalized)) {
      const ownerSub = bindings[bindings.length - 1] as string;
      const newCode = bindings[0] as string;
      for (const [code, row] of this.liveRooms) {
        if (row.owner_sub !== ownerSub) continue;
        this.liveRooms.delete(code);
        this.liveRooms.set(newCode, { ...row, code: newCode });
        return [{ code: newCode }];
      }
      return [];
    }
    throw new Error(`fake D1: live_rooms não suportado: ${normalized}`);
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
   * `INSERT INTO short_links (…) VALUES (…) ON CONFLICT DO NOTHING RETURNING
   * code`: colisão de `code` OU do índice único `(created_by, query)`
   * devolve `[]` (nenhuma linha — `.first()` do chamador lê `null`); sem
   * colisão, grava e devolve a linha para o `RETURNING`.
   */
  private insertShortLink(normalized: string, bindings: unknown[]): unknown[] {
    const { columns, values } = insertPlan(normalized);
    const cursor = { next: 0 };
    const row = {} as Record<string, unknown>;
    columns.forEach((column, i) => {
      row[column] = resolveToken(values[i], bindings, cursor, undefined);
    });
    const built = row as unknown as ShortLinkRow;
    const codeConflict = this.shortLinks.has(built.code);
    const queryConflict = [...this.shortLinks.values()].some(
      (r) => r.created_by === built.created_by && r.query === built.query,
    );
    if (codeConflict || queryConflict) {
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

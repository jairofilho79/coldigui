/**
 * D1 falso, mínimo, para os testes de `node:test`.
 *
 * ## Limitações — leia antes de usar
 *
 * **Isto não é um SQLite.** Não há parser de SQL: cada consulta é reconhecida
 * por **prefixo/palavra-chave** do texto e executada à mão sobre um `Map` em
 * memória, chaveado por `${user_id}|${id}`. Só as consultas que
 * `src/playlists/handlers.ts` emite são suportadas:
 *
 * | consulta | reconhecida por |
 * | --- | --- |
 * | `SELECT … FROM user_playlists WHERE user_id = ? AND id = ?` | `SELECT` + `AND id = ?` |
 * | `SELECT … FROM user_playlists WHERE user_id = ? AND deleted_at IS NULL ORDER BY …` | `SELECT` sem `AND id = ?` |
 * | `INSERT INTO user_playlists (…) VALUES (…)` | `INSERT` |
 * | `UPDATE user_playlists SET … WHERE user_id = ? AND id = ?` | `UPDATE` |
 * | `SELECT username FROM users WHERE …` (via `getUsername`) | `FROM users` |
 *
 * O soft delete de `softDeletePlaylist` é um `UPDATE` e cai no mesmo caminho.
 * A projeção do `SELECT` **não** é modelada: o fake devolve a linha inteira,
 * então tirar uma coluna de `SELECT_COLS` não faz nenhum teste falhar aqui.
 * A lista de colunas do `INSERT`/`UPDATE` é lida do próprio SQL, então mudar a
 * **ordem** dos `?` no handler continua funcionando; **acrescentar uma consulta
 * nova** exige estender este arquivo (ele lança em vez de devolver algo errado
 * em silêncio).
 *
 * Não implementa: `JOIN`, `LIMIT`, `ORDER BY` de verdade (a listagem ordena por
 * `updated_at` desc na mão), tipos, constraints, transações, `batch`, `exec`,
 * `dump` nem `withSession`.
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

/** Colunas do `INSERT INTO user_playlists (a, b, c) VALUES (?, ?, 1, …)`. */
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
  current: PlaylistRow | undefined,
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
  /** `user_id` → `username`, para o `getUsername` da publicação. */
  readonly usernames = new Map<string, string>();
  /** Todo SQL executado, na ordem — útil para asserções de "não escreveu". */
  readonly executed: string[] = [];

  seed(row: PlaylistRow): this {
    this.playlists.set(key(row.user_id, row.id), row);
    return this;
  }

  get(userId: string, id: string): PlaylistRow | undefined {
    return this.playlists.get(key(userId, id));
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
        const username = this.usernames.get(bindings[0] as string);
        return username === undefined ? [] : [{ username }];
      }
      if (!/FROM user_playlists/i.test(normalized)) {
        throw new Error(`fake D1: SELECT não suportado: ${normalized}`);
      }
      if (/AND id = \?/i.test(normalized)) {
        const row = this.playlists.get(
          key(bindings[0] as string, bindings[1] as string),
        );
        // `softDeletePlaylist` seleciona a linha mesmo já apagada, para
        // distinguir 404 de "apagar de novo".
        if (!row) return [];
        if (/deleted_at IS NULL/i.test(normalized) && row.deleted_at !== null) {
          return [];
        }
        return [row];
      }
      return [...this.playlists.values()]
        .filter(
          (row) => row.user_id === bindings[0] && row.deleted_at === null,
        )
        .sort((a, b) => b.updated_at.localeCompare(a.updated_at));
    }

    if (/^INSERT INTO user_playlists/i.test(normalized)) {
      const { columns, values } = insertPlan(normalized);
      const cursor = { next: 0 };
      const row = {} as Record<string, unknown>;
      columns.forEach((column, i) => {
        row[column] = resolveToken(values[i], bindings, cursor, undefined);
      });
      const built = row as unknown as PlaylistRow;
      this.playlists.set(key(built.user_id, built.id), built);
      return [];
    }

    if (/^UPDATE user_playlists/i.test(normalized)) {
      const assignments = updatePlan(normalized);
      const cursor = { next: 0 };
      // O `WHERE user_id = ? AND id = ?` consome os dois últimos bindings.
      const userId = bindings[bindings.length - 2] as string;
      const id = bindings[bindings.length - 1] as string;
      const current = this.playlists.get(key(userId, id));
      if (!current) throw new Error(`fake D1: UPDATE em linha ausente: ${id}`);
      const next = { ...current } as Record<string, unknown>;
      for (const { column, value } of assignments) {
        next[column] = resolveToken(value, bindings, cursor, current);
      }
      this.playlists.set(key(userId, id), next as unknown as PlaylistRow);
      return [];
    }

    throw new Error(`fake D1: consulta não suportada: ${normalized}`);
  }
}

/** O `FakeD1Database` no formato que os handlers tipam (`D1Database`). */
export function fakeDb(db: FakeD1Database): D1Database {
  return db as unknown as D1Database;
}

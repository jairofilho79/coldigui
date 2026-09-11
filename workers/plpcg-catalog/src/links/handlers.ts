/**
 * Links curtos de compartilhamento de playlist (D7, spec C.2).
 *
 * `POST /api/links` (autenticado) grava a query string do share e devolve um
 * código de 7 caracteres; `GET /l/:code` (público) resolve o código num
 * `302` de volta para {@link ORIGIN}. A dedupe por `(created_by, query)` e o
 * teto de abuso por usuário vivem aqui, não no roteador (`index.ts`).
 */
import type { GoogleClaims } from '../auth/verify_google_token';
import { json } from '../playlists/wire.ts';

/** Origem para onde `GET /l/:code` redireciona (spec C.2). */
export const ORIGIN = 'https://plpcg.com';

const CODE_ALPHABET = 'abcdefghijklmnopqrstuvwxyz0123456789';
const CODE_LENGTH = 7;
const MAX_CODE_ATTEMPTS = 5;

const MAX_QUERY_BYTES = 4096;

/** Teto de abuso: no máximo 100 links por usuário a cada 24h (spec C.2). */
const RATE_LIMIT_MAX = 100;
const RATE_LIMIT_WINDOW_MS = 24 * 60 * 60 * 1000;

export interface CreateLinkJson {
  code: string;
  url: string;
}

interface ShortLinkRow {
  code: string;
  query: string;
  hits: number;
}

interface CreateLinkBody {
  query?: unknown;
}

function linkUrl(code: string): string {
  return `${ORIGIN}/l/${code}`;
}

/**
 * 7 caracteres `[a-z0-9]` via `crypto.getRandomValues` (spec C.2). O
 * enviesamento de `256 % 36` é aceitável aqui — não é segredo criptográfico,
 * só um identificador curto e não-adivinhável o bastante.
 */
function randomCode(): string {
  const bytes = new Uint8Array(CODE_LENGTH);
  crypto.getRandomValues(bytes);
  let code = '';
  for (let i = 0; i < CODE_LENGTH; i++) {
    code += CODE_ALPHABET[bytes[i] % CODE_ALPHABET.length];
  }
  return code;
}

/**
 * `query` válida: string, até {@link MAX_QUERY_BYTES} bytes UTF-8, contendo
 * `shareitems=` (equivalente server-side de `parsePlaylistShareParams` —
 * sem decodificar os itens, só exigindo que o parâmetro exista).
 */
function isValidQuery(query: unknown): query is string {
  if (typeof query !== 'string' || query.length === 0) return false;
  if (!query.includes('shareitems=')) return false;
  return new TextEncoder().encode(query).length <= MAX_QUERY_BYTES;
}

/** `POST /api/links` — cria ou reusa um link curto para `body.query`. */
export async function createShortLink(
  db: D1Database,
  claims: GoogleClaims,
  request: Request,
): Promise<Response> {
  let body: CreateLinkBody;
  try {
    body = (await request.json()) as CreateLinkBody;
  } catch {
    return json({ error: 'invalid json' }, 400);
  }

  const query = body.query;
  if (!isValidQuery(query)) {
    return json({ error: 'query inválida: precisa conter shareitems' }, 400);
  }

  // Reuso primeiro: devolver um código existente não cria linha nova, então
  // não deve custar quota do teto de abuso abaixo (índice único
  // `(created_by, query)`).
  const existing = await db
    .prepare(
      `SELECT code FROM short_links WHERE created_by = ? AND query = ?`,
    )
    .bind(claims.sub, query)
    .first<{ code: string }>();
  if (existing) {
    return json(
      { code: existing.code, url: linkUrl(existing.code) } satisfies CreateLinkJson,
      200,
    );
  }

  const cutoff = Date.now() - RATE_LIMIT_WINDOW_MS;
  const countRow = await db
    .prepare(
      `SELECT COUNT(*) as count FROM short_links WHERE created_by = ? AND created_at >= ?`,
    )
    .bind(claims.sub, cutoff)
    .first<{ count: number }>();
  if ((countRow?.count ?? 0) >= RATE_LIMIT_MAX) {
    return json({ error: 'muitos links criados — tente amanhã' }, 429);
  }

  for (let attempt = 0; attempt < MAX_CODE_ATTEMPTS; attempt++) {
    const code = randomCode();
    // `ON CONFLICT(code) DO NOTHING RETURNING code`: colisão de código (a
    // astronômica coincidência de duas gerações batendo) devolve nenhuma
    // linha em vez de derrubar a request — a próxima iteração tenta outro
    // código.
    const row = await db
      .prepare(
        `INSERT INTO short_links (code, query, created_by, created_at, hits)
         VALUES (?, ?, ?, ?, 0)
         ON CONFLICT(code) DO NOTHING
         RETURNING code`,
      )
      .bind(code, query, claims.sub, Date.now())
      .first<{ code: string }>();
    if (row) {
      return json(
        { code: row.code, url: linkUrl(row.code) } satisfies CreateLinkJson,
        201,
      );
    }
  }

  return json({ error: 'não foi possível gerar um código' }, 500);
}

/** `GET /l/:code` — 302 público para `ORIGIN/?<query>`, ou 404. */
export async function resolveShortLink(
  db: D1Database,
  code: string,
): Promise<Response> {
  const row = await db
    .prepare(`SELECT code, query, hits FROM short_links WHERE code = ?`)
    .bind(code)
    .first<ShortLinkRow>();

  if (!row) {
    return new Response(null, { status: 404 });
  }

  await db
    .prepare(`UPDATE short_links SET hits = hits + 1 WHERE code = ?`)
    .bind(code)
    .run();

  return new Response(null, {
    status: 302,
    headers: {
      Location: `${ORIGIN}/?${row.query}`,
      'Cache-Control': 'public, max-age=3600',
    },
  });
}

/** Extrai o `code` de `/l/:code`, ou `null` se a rota não bater. */
export function shortLinkCodeFromPath(pathname: string): string | null {
  const match = /^\/l\/([^/]+)$/.exec(pathname);
  if (!match) return null;
  try {
    return decodeURIComponent(match[1]);
  } catch {
    return null;
  }
}

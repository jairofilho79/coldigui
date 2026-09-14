// workers/plpcg-catalog/src/live/handlers.ts
/**
 * Rotas HTTP da Lista ao Vivo (spec 2026-09-12-lista-ao-vivo, §4.1).
 *
 * `POST /api/live/room` (auth) cria-ou-devolve a sala permanente do `sub`;
 * `POST /api/live/room/regenerate` (auth) troca o código (quem tinha o antigo
 * é expulso); `GET /ao-vivo/:code` (público) é um 302 para a app. O estado
 * vivo mora no DO — D1 só liga `code` ↔ `owner_sub`.
 */
import type { GoogleClaims } from '../auth/verify_google_token';
import { ORIGIN } from '../links/handlers.ts';
import { json } from '../playlists/wire.ts';
import { isShortCode, randomShortCode } from '../short_code.ts';

/** Só o que os handlers usam de `DurableObjectNamespace` — testável com um fake. */
export interface LiveRoomNamespace {
  idFromName(name: string): unknown;
  get(id: unknown): { fetch(input: string, init?: RequestInit): Promise<Response> };
}

export interface LiveRoomJson {
  code: string;
  url: string;
  ownerName: string;
}

const MAX_CODE_ATTEMPTS = 5;

export function liveRoomUrl(code: string): string {
  return `${ORIGIN}/ao-vivo/${code}`;
}

async function ownerNameOf(db: D1Database, sub: string): Promise<string> {
  const row = await db
    .prepare(`SELECT name, username FROM users WHERE google_sub = ?`)
    .bind(sub)
    .first<{ name: string | null; username: string | null }>();
  return row?.name?.trim() || row?.username?.trim() || 'Gestor';
}

async function initRoom(live: LiveRoomNamespace, code: string, ownerSub: string, ownerName: string): Promise<void> {
  await live.get(live.idFromName(code)).fetch('https://live/init', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ code, ownerSub, ownerName }),
  });
}

async function retireRoom(live: LiveRoomNamespace, code: string): Promise<void> {
  await live.get(live.idFromName(code)).fetch('https://live/retire', { method: 'POST' });
}

async function findRoomCode(db: D1Database, sub: string): Promise<string | null> {
  const row = await db
    .prepare(`SELECT code FROM live_rooms WHERE owner_sub = ?`)
    .bind(sub)
    .first<{ code: string }>();
  return row?.code ?? null;
}

async function insertRoom(db: D1Database, sub: string): Promise<string | null> {
  for (let attempt = 0; attempt < MAX_CODE_ATTEMPTS; attempt++) {
    const code = randomShortCode();
    const row = await db
      .prepare(
        `INSERT INTO live_rooms (code, owner_sub, created_at) VALUES (?, ?, ?)
         ON CONFLICT DO NOTHING RETURNING code`,
      )
      .bind(code, sub, new Date().toISOString())
      .first<{ code: string }>();
    if (row) return row.code;
    // Sem linha: ou o `code` colidiu (tenta outro) ou o dono já tem sala
    // (corrida entre dois POSTs) — nesse caso devolve a que venceu.
    const raced = await findRoomCode(db, sub);
    if (raced) return raced;
  }
  return null;
}

/** `POST /api/live/room` — cria (ou devolve) a sala do usuário e inicializa o DO. */
export async function ensureLiveRoom(
  db: D1Database,
  live: LiveRoomNamespace,
  claims: GoogleClaims,
): Promise<Response> {
  const ownerName = await ownerNameOf(db, claims.sub);
  const code = (await findRoomCode(db, claims.sub)) ?? (await insertRoom(db, claims.sub));
  if (!code) return json({ error: 'não foi possível gerar um código' }, 500);
  // Idempotente no DO: numa sala existente só atualiza `ownerName`.
  await initRoom(live, code, claims.sub, ownerName);
  return json({ code, url: liveRoomUrl(code), ownerName } satisfies LiveRoomJson, 200);
}

/** `POST /api/live/room/regenerate` — novo código; o DO antigo é aposentado. */
export async function regenerateLiveRoom(
  db: D1Database,
  live: LiveRoomNamespace,
  claims: GoogleClaims,
): Promise<Response> {
  const previous = await findRoomCode(db, claims.sub);
  if (previous === null) return ensureLiveRoom(db, live, claims);

  const ownerName = await ownerNameOf(db, claims.sub);
  for (let attempt = 0; attempt < MAX_CODE_ATTEMPTS; attempt++) {
    const code = randomShortCode();
    let row: { code: string } | null;
    try {
      row = await db
        .prepare(`UPDATE live_rooms SET code = ? WHERE owner_sub = ? RETURNING code`)
        .bind(code, claims.sub)
        .first<{ code: string }>();
    } catch {
      // Colisão de `code` (chave primária): D1 lança em vez de devolver 0
      // linhas — tenta outro código.
      continue;
    }
    if (!row) continue;
    await retireRoom(live, previous);
    await initRoom(live, row.code, claims.sub, ownerName);
    return json({ code: row.code, url: liveRoomUrl(row.code), ownerName } satisfies LiveRoomJson, 200);
  }
  return json({ error: 'não foi possível gerar um código' }, 500);
}

/** `GET /ao-vivo/:code` — 302 para a app (`/?live=<code>`), sem tocar em D1. */
export function liveRoomRedirect(pathname: string): Response {
  const match = /^\/ao-vivo\/([^/]+)$/.exec(pathname);
  const code = match?.[1];
  if (!isShortCode(code)) return new Response(null, { status: 404 });
  return new Response(null, {
    status: 302,
    headers: { Location: `${ORIGIN}/?live=${code}`, 'Cache-Control': 'no-store' },
  });
}

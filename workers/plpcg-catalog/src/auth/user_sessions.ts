import {
  SESSION_TOUCH_INTERVAL_MS,
  SESSION_TTL_MS,
  generateSessionToken,
  hashSessionToken,
} from './session_token.ts';

interface SessionLookupRow {
  google_sub: string;
  last_seen_at: string;
}

function expiresFrom(now: Date): string {
  return new Date(now.getTime() + SESSION_TTL_MS).toISOString();
}

/**
 * Cria uma sessão para `googleSub` e devolve o token **cru** (única vez que
 * ele existe no servidor). Purga antes as sessões vencidas (spec D13).
 */
export async function createSession(
  db: D1Database,
  googleSub: string,
  now: Date = new Date(),
): Promise<string> {
  const nowIso = now.toISOString();
  await db
    .prepare(`DELETE FROM user_sessions WHERE expires_at < ?`)
    .bind(nowIso)
    .run();

  const token = generateSessionToken();
  await db
    .prepare(
      `INSERT INTO user_sessions (token_hash, google_sub, created_at, last_seen_at, expires_at)
       VALUES (?, ?, ?, ?, ?)`,
    )
    .bind(await hashSessionToken(token), googleSub, nowIso, nowIso, expiresFrom(now))
    .run();
  return token;
}

/**
 * `{ sub }` de uma sessão válida, ou `null` — **sem** renovar nada. É o que a
 * introspecção usa: ser consultado pelo coldigom-api não é uso do usuário e
 * não pode empurrar o `expires_at`.
 */
export async function lookupSession(
  db: D1Database,
  token: string,
  now: Date = new Date(),
): Promise<{ sub: string; lastSeenAt: string } | null> {
  const hash = await hashSessionToken(token);
  const row = await db
    .prepare(
      `SELECT google_sub, last_seen_at FROM user_sessions
       WHERE token_hash = ? AND expires_at > ?`,
    )
    .bind(hash, now.toISOString())
    .first<SessionLookupRow>();
  return row ? { sub: row.google_sub, lastSeenAt: row.last_seen_at } : null;
}

/**
 * `{ sub }` de uma sessão válida, ou `null`. Renova `last_seen_at`/`expires_at`
 * (deslizante) só quando a última renovação tem mais de 1 h (spec D3).
 */
export async function findSession(
  db: D1Database,
  token: string,
  now: Date = new Date(),
): Promise<{ sub: string } | null> {
  const found = await lookupSession(db, token, now);
  if (!found) return null;
  const lastSeen = Date.parse(found.lastSeenAt);
  if (now.getTime() - lastSeen > SESSION_TOUCH_INTERVAL_MS) {
    await db
      .prepare(`UPDATE user_sessions SET last_seen_at = ?, expires_at = ? WHERE token_hash = ?`)
      .bind(now.toISOString(), expiresFrom(now), await hashSessionToken(token))
      .run();
  }
  return { sub: found.sub };
}

/** Apaga a sessão; token desconhecido é no-op (idempotente). */
export async function revokeSession(db: D1Database, token: string): Promise<void> {
  await db
    .prepare(`DELETE FROM user_sessions WHERE token_hash = ?`)
    .bind(await hashSessionToken(token))
    .run();
}

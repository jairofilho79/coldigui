import type { GoogleClaims } from './verify_google_token';

export interface SessionUserJson {
  googleSub: string;
  email: string | null;
  name: string | null;
  pictureUrl: string | null;
  username: string | null;
}

interface UserRow {
  google_sub: string;
  email: string | null;
  name: string | null;
  picture_url: string | null;
  username: string | null;
}

export async function upsertUser(
  db: D1Database,
  claims: GoogleClaims,
): Promise<SessionUserJson> {
  const now = new Date().toISOString();
  const email = claims.email ?? null;
  const name = claims.name ?? null;
  const pictureUrl = claims.picture ?? null;

  const row = await db
    .prepare(
      `INSERT INTO users (google_sub, email, name, picture_url, created_at, updated_at, last_login_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(google_sub) DO UPDATE SET
         email = excluded.email,
         name = excluded.name,
         picture_url = excluded.picture_url,
         updated_at = excluded.updated_at,
         last_login_at = excluded.last_login_at
       RETURNING google_sub, email, name, picture_url, username`,
    )
    .bind(claims.sub, email, name, pictureUrl, now, now, now)
    .first<UserRow>();

  return {
    googleSub: claims.sub,
    email: row?.email ?? email,
    name: row?.name ?? name,
    pictureUrl: row?.picture_url ?? pictureUrl,
    username: row?.username ?? null,
  };
}

export async function getUsername(
  db: D1Database,
  googleSub: string,
): Promise<string | null> {
  const row = await db
    .prepare(`SELECT username FROM users WHERE google_sub = ?`)
    .bind(googleSub)
    .first<{ username: string | null }>();
  return row?.username ?? null;
}

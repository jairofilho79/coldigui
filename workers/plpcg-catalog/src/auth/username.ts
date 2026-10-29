import type { GoogleClaims } from './verify_google_token';
import { normalizeUsername, validateUsername } from './username_rules';

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });
}

/** PUT /api/auth/username — define handle único (somente uma vez). */
export async function setUsername(
  db: D1Database,
  claims: GoogleClaims,
  request: Request,
): Promise<Response> {
  let body: { username?: unknown };
  try {
    body = (await request.json()) as { username?: unknown };
  } catch {
    return json({ error: 'invalid json' }, 400);
  }

  const validationError = validateUsername(body.username);
  if (validationError) {
    return json({ error: validationError }, 400);
  }

  const username = normalizeUsername(body.username as string);
  const now = new Date().toISOString();

  const existing = await db
    .prepare(`SELECT username FROM users WHERE google_sub = ?`)
    .bind(claims.sub)
    .first<{ username: string | null }>();

  if (!existing) {
    return json({ error: 'user not found' }, 404);
  }
  if (existing.username) {
    return json({ error: 'username already set' }, 409);
  }

  try {
    const result = await db
      .prepare(
        `UPDATE users SET username = ?, updated_at = ?
         WHERE google_sub = ? AND username IS NULL`,
      )
      .bind(username, now, claims.sub)
      .run();

    if ((result.meta.changes ?? 0) === 0) {
      return json({ error: 'username already set' }, 409);
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    if (message.toLowerCase().includes('unique')) {
      return json({ error: 'username taken' }, 409);
    }
    throw error;
  }

  return json({
    googleSub: claims.sub,
    username,
  });
}

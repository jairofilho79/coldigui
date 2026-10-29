import { isSessionToken } from './session_token.ts';
import { lookupSession } from './user_sessions.ts';

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' },
  });
}

function bearerToken(request: Request): string | null {
  const header = request.headers.get('Authorization');
  if (!header?.startsWith('Bearer ')) return null;
  const token = header.slice(7).trim();
  return token.length > 0 ? token : null;
}

export interface IntrospectJson {
  userId: string;
  email: string | null;
  name: string | null;
  username: string | null;
}

/**
 * `GET /api/auth/introspect` — servidor-a-servidor (coldigom-api). Só aceita
 * `sess_…`: um `id_token` do Google vazado não pode virar identidade aqui.
 * Não renova a sessão (spec contribuições §4.1).
 */
export async function handleIntrospect(
  db: D1Database,
  request: Request,
  now: Date = new Date(),
): Promise<Response> {
  const token = bearerToken(request);
  if (!token || !isSessionToken(token)) return json({ error: 'unauthorized' }, 401);
  const session = await lookupSession(db, token, now);
  if (!session) return json({ error: 'unauthorized' }, 401);
  const row = await db
    .prepare(`SELECT email, name, username FROM users WHERE google_sub = ?`)
    .bind(session.sub)
    .first<{ email: string | null; name: string | null; username: string | null }>();
  return json(
    {
      userId: session.sub,
      email: row?.email ?? null,
      name: row?.name ?? null,
      username: row?.username ?? null,
    } satisfies IntrospectJson,
    200,
  );
}

import type { SessionUserJson } from './session';
import { isSessionToken } from './session_token.ts';
import { createSession, revokeSession } from './user_sessions.ts';

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });
}

function bearerToken(request: Request): string | null {
  const header = request.headers.get('Authorization');
  if (!header?.startsWith('Bearer ')) return null;
  const token = header.slice(7).trim();
  return token.length > 0 ? token : null;
}

/**
 * Resposta do `POST /api/auth/session` (spec D1): o perfil já upsertado mais
 * um `sessionToken` novo. Um login = uma sessão (spec D4).
 */
export async function sessionResponse(
  db: D1Database,
  user: SessionUserJson,
  now: Date = new Date(),
): Promise<Response> {
  const sessionToken = await createSession(db, user.googleSub, now);
  return json({ ...user, sessionToken }, 200);
}

/**
 * `DELETE /api/auth/session`: revoga a sessão do Bearer. Token desconhecido
 * também é `204` — o app vai apagar a sessão local de qualquer jeito.
 */
export async function handleDeleteSession(
  db: D1Database,
  request: Request,
): Promise<Response> {
  const token = bearerToken(request);
  if (!token || !isSessionToken(token)) {
    return json({ error: 'unauthorized' }, 401);
  }
  await revokeSession(db, token);
  return new Response(null, { status: 204 });
}

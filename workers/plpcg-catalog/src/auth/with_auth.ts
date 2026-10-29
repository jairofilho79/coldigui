import type { GoogleClaims } from './verify_google_token';
import { verifyGoogleIdToken } from './verify_google_token.ts';
import { isSessionToken } from './session_token.ts';
import { findSession } from './user_sessions.ts';

export type AuthedHandler = (
  request: Request,
  env: { DB: D1Database; GOOGLE_CLIENT_ID_WEB: string },
  claims: GoogleClaims,
) => Promise<Response>;

function bearerToken(request: Request): string | null {
  const header = request.headers.get('Authorization');
  if (!header?.startsWith('Bearer ')) return null;
  const token = header.slice(7).trim();
  return token.length > 0 ? token : null;
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });
}

export async function withAuth(
  request: Request,
  env: { DB: D1Database; GOOGLE_CLIENT_ID_WEB: string },
  handler: AuthedHandler,
): Promise<Response> {
  const token = bearerToken(request);
  if (!token) {
    return json({ error: 'unauthorized' }, 401);
  }

  // Sessão emitida pelo Worker (spec D5): lookup em D1, sem JWT.
  if (isSessionToken(token)) {
    const session = await findSession(env.DB, token);
    if (!session) {
      return json({ error: 'unauthorized' }, 401);
    }
    return handler(request, env, { sub: session.sub });
  }

  const clientId = env.GOOGLE_CLIENT_ID_WEB;
  if (!clientId) {
    return json({ error: 'auth not configured' }, 503);
  }

  try {
    const claims = await verifyGoogleIdToken(token, clientId);
    return handler(request, env, claims);
  } catch {
    return json({ error: 'unauthorized' }, 401);
  }
}

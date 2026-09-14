// workers/plpcg-catalog/src/live/authenticate_token.ts
import { isSessionToken } from '../auth/session_token.ts';
import { findSession } from '../auth/user_sessions.ts';
import { verifyGoogleIdToken } from '../auth/verify_google_token.ts';

/**
 * `sub` de um Bearer (`sess_…` do Worker ou JWT do Google), ou `null` —
 * o mesmo critério de `withAuth`, sem `Request`/`Response`, para o `hello`
 * do WebSocket.
 */
export async function authenticateToken(
  env: { DB: D1Database; GOOGLE_CLIENT_ID_WEB: string },
  token: string,
): Promise<string | null> {
  if (isSessionToken(token)) {
    return (await findSession(env.DB, token))?.sub ?? null;
  }
  if (!env.GOOGLE_CLIENT_ID_WEB) return null;
  try {
    return (await verifyGoogleIdToken(token, env.GOOGLE_CLIENT_ID_WEB)).sub;
  } catch {
    return null;
  }
}

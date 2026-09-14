/**
 * Token de sessão emitido pelo Worker (spec D2/D3).
 *
 * `sess_` + 32 bytes aleatórios em base64url sem padding. O prefixo é o que
 * permite ao `withAuth` distinguir sessão de JWT do Google sem parsear.
 */
export const SESSION_TOKEN_PREFIX = 'sess_';

/** 60 dias deslizantes. */
export const SESSION_TTL_MS = 60 * 24 * 60 * 60 * 1000;

/** Só reescreve `last_seen_at`/`expires_at` se passou 1 h da última vez. */
export const SESSION_TOUCH_INTERVAL_MS = 60 * 60 * 1000;

function base64Url(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

export function generateSessionToken(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return `${SESSION_TOKEN_PREFIX}${base64Url(bytes)}`;
}

export function isSessionToken(bearer: string): boolean {
  return bearer.startsWith(SESSION_TOKEN_PREFIX);
}

/** SHA-256 hex — é isto que vai para `user_sessions.token_hash`. */
export async function hashSessionToken(token: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(token),
  );
  return [...new Uint8Array(digest)]
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

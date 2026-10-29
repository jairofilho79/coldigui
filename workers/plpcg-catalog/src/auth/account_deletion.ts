import type { GoogleClaims } from './verify_google_token.ts';
import { withAuth } from './with_auth.ts';

/**
 * Deleta em lote (ou em sequência como fallback) todos os dados associados a
 * um usuário em cumprimento aos requisitos de Account Deletion da Google Play.
 *
 * A ordem de deleção limpa primeiro as tabelas filhas e referências antes de
 * deletar o próprio usuário (`users`), respeitando quaisquer constraints de FK.
 */
export async function deleteUserAccount(
  db: D1Database,
  userId: string,
): Promise<void> {
  const statements = [
    db.prepare('DELETE FROM user_playlists WHERE user_id = ?').bind(userId),
    db.prepare('DELETE FROM user_audio_flags WHERE user_id = ?').bind(userId),
    db.prepare('DELETE FROM user_material_kind_prefs WHERE user_id = ?').bind(userId),
    db.prepare('DELETE FROM short_links WHERE created_by = ?').bind(userId),
    db.prepare('DELETE FROM live_rooms WHERE owner_sub = ?').bind(userId),
    db.prepare('DELETE FROM user_sessions WHERE google_sub = ?').bind(userId),
    db.prepare('DELETE FROM users WHERE google_sub = ?').bind(userId),
  ];

  if (typeof db.batch === 'function') {
    await db.batch(statements);
  } else {
    for (const stmt of statements) {
      await stmt.run();
    }
  }
}

function isRequest(value: unknown): value is Request {
  return typeof value === 'object' && value !== null && 'url' in value && 'headers' in value;
}

/**
 * Handler para exclusão de conta (`DELETE /api/auth/account`).
 *
 * Suporta ser chamado como:
 * 1. `handleDeleteAccount(request, env)`: autentica via `withAuth` e deleta os dados.
 * 2. `handleDeleteAccount(db, claims)`: deleta diretamente para o usuário autenticado em `claims`.
 */
export async function handleDeleteAccount(
  requestOrDb: Request | D1Database,
  envOrClaims?: { DB: D1Database; GOOGLE_CLIENT_ID_WEB?: string } | GoogleClaims,
): Promise<Response> {
  if (isRequest(requestOrDb)) {
    const request = requestOrDb;
    const env = envOrClaims as { DB: D1Database; GOOGLE_CLIENT_ID_WEB?: string };

    if (request.method !== 'DELETE') {
      return new Response(JSON.stringify({ error: 'method not allowed' }), {
        status: 405,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Cache-Control': 'no-store',
        },
      });
    }

    return withAuth(
      request,
      { DB: env.DB, GOOGLE_CLIENT_ID_WEB: env.GOOGLE_CLIENT_ID_WEB ?? '' },
      async (_req, e, claims) => {
        await deleteUserAccount(e.DB, claims.sub);
        return new Response(null, { status: 204 });
      },
    );
  }

  const db = requestOrDb;
  const claims = envOrClaims as GoogleClaims;
  if (!claims?.sub) {
    return new Response(JSON.stringify({ error: 'unauthorized' }), {
      status: 401,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Cache-Control': 'no-store',
      },
    });
  }

  await deleteUserAccount(db, claims.sub);
  return new Response(null, { status: 204 });
}

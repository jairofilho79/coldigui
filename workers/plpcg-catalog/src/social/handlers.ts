import type { PublicationCategory, PublicationReach } from '../playlists/publication_rules';

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });
}

interface SocialUserRow {
  username: string;
  playlist_count: number;
}

interface PublicPlaylistRow {
  id: string;
  nome: string;
  pdf_ids: string;
  publication_reach: string | null;
  publication_category: string | null;
  published_at: string | null;
}

function parsePdfIds(raw: string): string[] {
  try {
    const parsed: unknown = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    return parsed.filter((v): v is string => typeof v === 'string');
  } catch {
    return [];
  }
}

function sanitizeLike(q: string): string {
  return q.replace(/%/g, '').replace(/_/g, '');
}

/** Normaliza query social: trim, lower, remove `@` inicial. */
export function normalizeSocialQuery(raw: string): string {
  return raw.trim().toLowerCase().replace(/^@+/, '');
}

/** GET /api/social/users?q= — perfis com username (contagem de listas públicas). */
export async function searchSocialUsers(
  db: D1Database,
  request: Request,
): Promise<Response> {
  const url = new URL(request.url);
  const q = normalizeSocialQuery(url.searchParams.get('q') ?? '');
  if (q.length < 1) {
    return json([]);
  }

  const like = `%${sanitizeLike(q)}%`;
  const result = await db
    .prepare(
      `SELECT u.username AS username, COUNT(p.id) AS playlist_count
       FROM users u
       LEFT JOIN user_playlists p
         ON p.user_id = u.google_sub
        AND p.is_published = 1
        AND p.deleted_at IS NULL
       WHERE u.username IS NOT NULL
         AND u.username LIKE ?
       GROUP BY u.username
       ORDER BY u.username ASC
       LIMIT 50`,
    )
    .bind(like)
    .all<SocialUserRow>();

  return json(
    (result.results ?? []).map((row) => ({
      username: row.username,
      playlistCount: row.playlist_count,
    })),
  );
}

/** GET /api/social/users/:username/playlists — listas públicas do perfil. */
export async function listPublicPlaylistsByUsername(
  db: D1Database,
  username: string,
): Promise<Response> {
  const normalized = username.trim().toLowerCase();
  if (!normalized) {
    return json({ error: 'not found' }, 404);
  }

  const owner = await db
    .prepare(`SELECT google_sub FROM users WHERE username = ?`)
    .bind(normalized)
    .first<{ google_sub: string }>();

  if (!owner) {
    return json({ error: 'not found' }, 404);
  }

  const result = await db
    .prepare(
      `SELECT id, nome, pdf_ids, publication_reach, publication_category, published_at
       FROM user_playlists
       WHERE user_id = ?
         AND is_published = 1
         AND deleted_at IS NULL
       ORDER BY published_at DESC`,
    )
    .bind(owner.google_sub)
    .all<PublicPlaylistRow>();

  return json(
    (result.results ?? []).map((row) => ({
      id: row.id,
      nome: row.nome,
      pdfIds: parsePdfIds(row.pdf_ids),
      publicationReach: row.publication_reach as PublicationReach | null,
      publicationCategory:
        row.publication_category as PublicationCategory | null,
      publishedAt: row.published_at,
    })),
  );
}

export function socialUsernameFromPath(pathname: string): string | null {
  const match = /^\/api\/social\/users\/([^/]+)\/playlists$/.exec(pathname);
  if (!match) return null;
  try {
    return decodeURIComponent(match[1]);
  } catch {
    return null;
  }
}

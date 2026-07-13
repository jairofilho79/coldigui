import type { GoogleClaims } from '../auth/verify_google_token';

interface PlaylistRow {
  id: string;
  user_id: string;
  nome: string;
  pdf_ids: string;
  salva: number;
  saved_at: string | null;
  favorita: number;
  favorited_at: string | null;
  created_at: string;
  updated_at: string;
  version: number;
  deleted_at: string | null;
}

export interface PlaylistJson {
  id: string;
  nome: string;
  pdfIds: string[];
  salva: boolean;
  savedAt: string | null;
  favorita: boolean;
  favoritedAt: string | null;
  createdAt: string;
  updatedAt: string;
  version: number;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });
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

function rowToJson(row: PlaylistRow): PlaylistJson {
  return {
    id: row.id,
    nome: row.nome,
    pdfIds: parsePdfIds(row.pdf_ids),
    salva: row.salva === 1,
    savedAt: row.saved_at,
    favorita: row.favorita === 1,
    favoritedAt: row.favorited_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    version: row.version,
  };
}

function isIsoDate(value: unknown): value is string {
  return (
    typeof value === 'string' &&
    value.length > 0 &&
    !Number.isNaN(Date.parse(value))
  );
}

interface PutBody {
  id?: unknown;
  nome?: unknown;
  pdfIds?: unknown;
  salva?: unknown;
  savedAt?: unknown;
  favorita?: unknown;
  favoritedAt?: unknown;
  createdAt?: unknown;
  updatedAt?: unknown;
  version?: unknown;
}

function validatePutBody(body: PutBody, pathId: string): string | null {
  if (typeof body.id === 'string' && body.id !== pathId) {
    return 'id mismatch';
  }
  if (typeof body.nome !== 'string' || body.nome.trim().length === 0) {
    return 'nome required';
  }
  if (
    !Array.isArray(body.pdfIds) ||
    !body.pdfIds.every((v) => typeof v === 'string')
  ) {
    return 'pdfIds must be string array';
  }
  if (body.salva === false) {
    return 'drafts not allowed';
  }
  if (!isIsoDate(body.createdAt) || !isIsoDate(body.updatedAt)) {
    return 'createdAt/updatedAt required';
  }
  return null;
}

export async function listPlaylists(
  db: D1Database,
  claims: GoogleClaims,
): Promise<Response> {
  const result = await db
    .prepare(
      `SELECT id, user_id, nome, pdf_ids, salva, saved_at, favorita, favorited_at,
              created_at, updated_at, version, deleted_at
       FROM user_playlists
       WHERE user_id = ? AND deleted_at IS NULL
       ORDER BY updated_at DESC`,
    )
    .bind(claims.sub)
    .all<PlaylistRow>();

  return json((result.results ?? []).map(rowToJson));
}

export async function getPlaylist(
  db: D1Database,
  claims: GoogleClaims,
  id: string,
): Promise<Response> {
  const row = await db
    .prepare(
      `SELECT id, user_id, nome, pdf_ids, salva, saved_at, favorita, favorited_at,
              created_at, updated_at, version, deleted_at
       FROM user_playlists
       WHERE user_id = ? AND id = ? AND deleted_at IS NULL`,
    )
    .bind(claims.sub, id)
    .first<PlaylistRow>();

  if (!row) return json({ error: 'not found' }, 404);
  return json(rowToJson(row));
}

export async function upsertPlaylist(
  db: D1Database,
  claims: GoogleClaims,
  id: string,
  request: Request,
): Promise<Response> {
  let body: PutBody;
  try {
    body = (await request.json()) as PutBody;
  } catch {
    return json({ error: 'invalid json' }, 400);
  }

  const validationError = validatePutBody(body, id);
  if (validationError) {
    return json({ error: validationError }, 400);
  }

  const nome = (body.nome as string).trim();
  const pdfIdsJson = JSON.stringify(body.pdfIds);
  const favorita = body.favorita === true ? 1 : 0;
  const savedAt = isIsoDate(body.savedAt) ? body.savedAt : null;
  const favoritedAt = isIsoDate(body.favoritedAt) ? body.favoritedAt : null;
  const createdAt = body.createdAt as string;
  const clientUpdatedAt = body.updatedAt as string;
  const now = new Date().toISOString();
  const pdfIds = body.pdfIds as string[];

  const existing = await db
    .prepare(
      `SELECT id, user_id, nome, pdf_ids, salva, saved_at, favorita, favorited_at,
              created_at, updated_at, version, deleted_at
       FROM user_playlists
       WHERE user_id = ? AND id = ?`,
    )
    .bind(claims.sub, id)
    .first<PlaylistRow>();

  if (!existing) {
    await db
      .prepare(
        `INSERT INTO user_playlists
          (id, user_id, nome, pdf_ids, salva, saved_at, favorita, favorited_at,
           created_at, updated_at, version, deleted_at)
         VALUES (?, ?, ?, ?, 1, ?, ?, ?, ?, ?, 1, NULL)`,
      )
      .bind(
        id,
        claims.sub,
        nome,
        pdfIdsJson,
        savedAt,
        favorita,
        favoritedAt,
        createdAt,
        clientUpdatedAt,
      )
      .run();

    return json({
      id,
      nome,
      pdfIds,
      salva: true,
      savedAt,
      favorita: favorita === 1,
      favoritedAt,
      createdAt,
      updatedAt: clientUpdatedAt,
      version: 1,
    } satisfies PlaylistJson);
  }

  if (existing.deleted_at !== null) {
    const version = existing.version + 1;
    await db
      .prepare(
        `UPDATE user_playlists SET
           nome = ?, pdf_ids = ?, salva = 1, saved_at = ?, favorita = ?,
           favorited_at = ?, updated_at = ?, version = ?, deleted_at = NULL
         WHERE user_id = ? AND id = ?`,
      )
      .bind(
        nome,
        pdfIdsJson,
        savedAt,
        favorita,
        favoritedAt,
        clientUpdatedAt,
        version,
        claims.sub,
        id,
      )
      .run();

    return json({
      id,
      nome,
      pdfIds,
      salva: true,
      savedAt,
      favorita: favorita === 1,
      favoritedAt,
      createdAt: existing.created_at,
      updatedAt: clientUpdatedAt,
      version,
    } satisfies PlaylistJson);
  }

  if (clientUpdatedAt < existing.updated_at) {
    return json(rowToJson(existing), 409);
  }

  const version = existing.version + 1;
  const updatedAt =
    clientUpdatedAt > existing.updated_at ? clientUpdatedAt : now;

  await db
    .prepare(
      `UPDATE user_playlists SET
         nome = ?, pdf_ids = ?, salva = 1, saved_at = ?, favorita = ?,
         favorited_at = ?, updated_at = ?, version = ?
       WHERE user_id = ? AND id = ?`,
    )
    .bind(
      nome,
      pdfIdsJson,
      savedAt,
      favorita,
      favoritedAt,
      updatedAt,
      version,
      claims.sub,
      id,
    )
    .run();

  return json({
    id,
    nome,
    pdfIds,
    salva: true,
    savedAt,
    favorita: favorita === 1,
    favoritedAt,
    createdAt: existing.created_at,
    updatedAt,
    version,
  } satisfies PlaylistJson);
}

export async function softDeletePlaylist(
  db: D1Database,
  claims: GoogleClaims,
  id: string,
): Promise<Response> {
  const existing = await db
    .prepare(
      `SELECT id, deleted_at, version FROM user_playlists
       WHERE user_id = ? AND id = ?`,
    )
    .bind(claims.sub, id)
    .first<{ id: string; deleted_at: string | null; version: number }>();

  if (!existing || existing.deleted_at !== null) {
    return json({ error: 'not found' }, 404);
  }

  const now = new Date().toISOString();
  await db
    .prepare(
      `UPDATE user_playlists SET
         deleted_at = ?, updated_at = ?, version = version + 1
       WHERE user_id = ? AND id = ?`,
    )
    .bind(now, now, claims.sub, id)
    .run();

  return json({ ok: true, deletedAt: now });
}

export function playlistIdFromPath(pathname: string): string | null {
  const match = /^\/api\/playlists\/([^/]+)$/.exec(pathname);
  if (!match) return null;
  try {
    return decodeURIComponent(match[1]);
  } catch {
    return null;
  }
}

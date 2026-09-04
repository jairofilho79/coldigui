import { getUsername } from '../auth/session.ts';
import type { GoogleClaims } from '../auth/verify_google_token';
import {
  resolvePublicationFields,
  validatePublication,
  type PublicationCategory,
  type PublicationReach,
} from './publication_rules.ts';
import {
  itemsFromLegacy,
  listsFromItems,
  parseItems,
  parseItemsColumn,
  type PlaylistItem,
} from './items.ts';

/** Versão do payload que este Worker responde (spec A.3). */
const SCHEMA_VERSION = 2;

interface PlaylistRow {
  id: string;
  user_id: string;
  nome: string;
  /** JSON de `PlaylistItem[]` — a ordem única tipada. `'[]'` em linha legada. */
  items: string;
  pdf_ids: string;
  audio_ids: string;
  salva: number;
  saved_at: string | null;
  favorita: number;
  favorited_at: string | null;
  created_at: string;
  updated_at: string;
  version: number;
  deleted_at: string | null;
  is_published: number;
  publication_reach: string | null;
  publication_category: string | null;
  published_at: string | null;
}

export interface PlaylistJson {
  id: string;
  nome: string;
  schemaVersion: number;
  items: PlaylistItem[];
  pdfIds: string[];
  audioIds: string[];
  salva: boolean;
  savedAt: string | null;
  favorita: boolean;
  favoritedAt: string | null;
  createdAt: string;
  updatedAt: string;
  version: number;
  isPublished: boolean;
  publicationReach: PublicationReach | null;
  publicationCategory: PublicationCategory | null;
  publishedAt: string | null;
}

const SELECT_COLS = `id, user_id, nome, items, pdf_ids, audio_ids, salva, saved_at, favorita, favorited_at,
              created_at, updated_at, version, deleted_at,
              is_published, publication_reach, publication_category, published_at`;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });
}

function parseIdList(raw: string | null | undefined): string[] {
  if (!raw) return [];
  try {
    const parsed: unknown = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    return parsed.filter((v): v is string => typeof v === 'string');
  } catch {
    return [];
  }
}

const parsePdfIds = parseIdList;
const parseAudioIds = parseIdList;

function rowToJson(row: PlaylistRow): PlaylistJson {
  const pdfIds = parsePdfIds(row.pdf_ids);
  const audioIds = parseAudioIds(row.audio_ids);
  // Linha legada (gravada antes da coluna `items`) ou coluna corrompida: a
  // ordem única é derivada das duas listas, com os tipos genéricos. O cliente
  // recupera cifra/gesto pela extensão do id (`resolveWireKind`, A.3).
  const stored = parseItemsColumn(row.items);
  const items = stored.length > 0 ? stored : itemsFromLegacy(pdfIds, audioIds);

  return {
    id: row.id,
    nome: row.nome,
    schemaVersion: SCHEMA_VERSION,
    items,
    pdfIds,
    audioIds,
    salva: row.salva === 1,
    savedAt: row.saved_at,
    favorita: row.favorita === 1,
    favoritedAt: row.favorited_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    version: row.version,
    isPublished: row.is_published === 1,
    publicationReach: row.publication_reach as PublicationReach | null,
    publicationCategory: row.publication_category as PublicationCategory | null,
    publishedAt: row.published_at,
  };
}

function isStringArray(value: unknown): value is string[] {
  return Array.isArray(value) && value.every((v) => typeof v === 'string');
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
  schemaVersion?: unknown;
  items?: unknown;
  pdfIds?: unknown;
  audioIds?: unknown;
  salva?: unknown;
  savedAt?: unknown;
  favorita?: unknown;
  favoritedAt?: unknown;
  createdAt?: unknown;
  updatedAt?: unknown;
  version?: unknown;
  isPublished?: unknown;
  publicationReach?: unknown;
  publicationCategory?: unknown;
}

function validatePutBody(body: PutBody, pathId: string): string | null {
  if (typeof body.id === 'string' && body.id !== pathId) {
    return 'id mismatch';
  }
  if (typeof body.nome !== 'string' || body.nome.trim().length === 0) {
    return 'nome required';
  }
  if (
    body.schemaVersion !== undefined &&
    (!Number.isInteger(body.schemaVersion) ||
      (body.schemaVersion as number) < 1)
  ) {
    return 'schemaVersion must be an integer >= 1';
  }
  if (body.items !== undefined && parseItems(body.items) === null) {
    return 'items must be an array of {id, kind}';
  }
  // `pdfIds` é obrigatório só para o cliente v1: em v2 a ordem única basta e as
  // duas listas são derivadas aqui. Quando vem, tem que ter a forma certa.
  if (body.items === undefined && body.pdfIds === undefined) {
    return 'pdfIds must be string array';
  }
  if (body.pdfIds !== undefined && !isStringArray(body.pdfIds)) {
    return 'pdfIds must be string array';
  }
  if (body.audioIds !== undefined && !isStringArray(body.audioIds)) {
    return 'audioIds must be string array';
  }
  if (body.salva === false) {
    return 'drafts not allowed';
  }
  if (!isIsoDate(body.createdAt) || !isIsoDate(body.updatedAt)) {
    return 'createdAt/updatedAt required';
  }
  return null;
}

function publicationJson(
  isPublished: number,
  reach: PublicationReach | null,
  category: PublicationCategory | null,
  publishedAt: string | null,
): Pick<
  PlaylistJson,
  | 'isPublished'
  | 'publicationReach'
  | 'publicationCategory'
  | 'publishedAt'
> {
  return {
    isPublished: isPublished === 1,
    publicationReach: reach,
    publicationCategory: category,
    publishedAt,
  };
}

export async function listPlaylists(
  db: D1Database,
  claims: GoogleClaims,
): Promise<Response> {
  const result = await db
    .prepare(
      `SELECT ${SELECT_COLS}
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
      `SELECT ${SELECT_COLS}
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

  const existing = await db
    .prepare(
      `SELECT ${SELECT_COLS}
       FROM user_playlists
       WHERE user_id = ? AND id = ?`,
    )
    .bind(claims.sub, id)
    .first<PlaylistRow>();

  const pubError = validatePublication(existing, body);
  if (pubError) {
    return json({ error: pubError }, 400);
  }

  const nome = (body.nome as string).trim();
  // `items` manda: quando vem, as listas do body são ignoradas e recalculadas.
  // Sem `items` (cliente v1), a ordem única é derivada das duas listas.
  const items =
    parseItems(body.items) ??
    itemsFromLegacy(
      isStringArray(body.pdfIds) ? body.pdfIds : [],
      isStringArray(body.audioIds) ? body.audioIds : [],
    );
  const { pdfIds, audioIds } = listsFromItems(items);
  const itemsJson = JSON.stringify(items);
  const pdfIdsJson = JSON.stringify(pdfIds);
  const audioIdsJson = JSON.stringify(audioIds);
  const favorita = body.favorita === true ? 1 : 0;
  const savedAt = isIsoDate(body.savedAt) ? body.savedAt : null;
  const favoritedAt = isIsoDate(body.favoritedAt) ? body.favoritedAt : null;
  const createdAt = body.createdAt as string;
  const clientUpdatedAt = body.updatedAt as string;
  const now = new Date().toISOString();

  const pub = resolvePublicationFields(existing, body);
  if (pub.newlyPublished) {
    const username = await getUsername(db, claims.sub);
    if (!username) {
      return json({ error: 'username required' }, 400);
    }
  }
  const publishedAt = pub.newlyPublished
    ? now
    : pub.publishedAt;

  if (!existing) {
    await db
      .prepare(
        `INSERT INTO user_playlists
          (id, user_id, nome, items, pdf_ids, audio_ids, salva, saved_at, favorita, favorited_at,
           created_at, updated_at, version, deleted_at,
           is_published, publication_reach, publication_category, published_at)
         VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?, ?, ?, ?, 1, NULL, ?, ?, ?, ?)`,
      )
      .bind(
        id,
        claims.sub,
        nome,
        itemsJson,
        pdfIdsJson,
        audioIdsJson,
        savedAt,
        favorita,
        favoritedAt,
        createdAt,
        clientUpdatedAt,
        pub.isPublished,
        pub.publicationReach,
        pub.publicationCategory,
        publishedAt,
      )
      .run();

    return json({
      id,
      nome,
      schemaVersion: SCHEMA_VERSION,
      items,
      pdfIds,
      audioIds,
      salva: true,
      savedAt,
      favorita: favorita === 1,
      favoritedAt,
      createdAt,
      updatedAt: clientUpdatedAt,
      version: 1,
      ...publicationJson(
        pub.isPublished,
        pub.publicationReach,
        pub.publicationCategory,
        publishedAt,
      ),
    } satisfies PlaylistJson);
  }

  if (existing.deleted_at !== null) {
    const version = existing.version + 1;
    await db
      .prepare(
        `UPDATE user_playlists SET
           nome = ?, items = ?, pdf_ids = ?, audio_ids = ?, salva = 1, saved_at = ?, favorita = ?,
           favorited_at = ?, updated_at = ?, version = ?, deleted_at = NULL,
           is_published = ?, publication_reach = ?, publication_category = ?,
           published_at = ?
         WHERE user_id = ? AND id = ?`,
      )
      .bind(
        nome,
        itemsJson,
        pdfIdsJson,
        audioIdsJson,
        savedAt,
        favorita,
        favoritedAt,
        clientUpdatedAt,
        version,
        pub.isPublished,
        pub.publicationReach,
        pub.publicationCategory,
        publishedAt,
        claims.sub,
        id,
      )
      .run();

    return json({
      id,
      nome,
      schemaVersion: SCHEMA_VERSION,
      items,
      pdfIds,
      audioIds,
      salva: true,
      savedAt,
      favorita: favorita === 1,
      favoritedAt,
      createdAt: existing.created_at,
      updatedAt: clientUpdatedAt,
      version,
      ...publicationJson(
        pub.isPublished,
        pub.publicationReach,
        pub.publicationCategory,
        publishedAt,
      ),
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
         nome = ?, items = ?, pdf_ids = ?, audio_ids = ?, salva = 1, saved_at = ?, favorita = ?,
         favorited_at = ?, updated_at = ?, version = ?,
         is_published = ?, publication_reach = ?, publication_category = ?,
         published_at = ?
       WHERE user_id = ? AND id = ?`,
    )
    .bind(
      nome,
      itemsJson,
      pdfIdsJson,
      audioIdsJson,
      savedAt,
      favorita,
      favoritedAt,
      updatedAt,
      version,
      pub.isPublished,
      pub.publicationReach,
      pub.publicationCategory,
      publishedAt,
      claims.sub,
      id,
    )
    .run();

  return json({
    id,
    nome,
    schemaVersion: SCHEMA_VERSION,
    items,
    pdfIds,
    audioIds,
    salva: true,
    savedAt,
    favorita: favorita === 1,
    favoritedAt,
    createdAt: existing.created_at,
    updatedAt,
    version,
    ...publicationJson(
      pub.isPublished,
      pub.publicationReach,
      pub.publicationCategory,
      publishedAt,
    ),
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

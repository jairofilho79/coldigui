import type { GoogleClaims } from '../auth/verify_google_token';

interface AudioFlagRow {
  id: string;
  user_id: string;
  audio_id: string;
  position_ms: number;
  label: string;
  created_at: string;
  updated_at: string;
  version: number;
  deleted_at: string | null;
}

export interface AudioFlagJson {
  id: string;
  audioId: string;
  positionMs: number;
  label: string;
  createdAt: string;
  updatedAt: string;
  version: number;
}

const SELECT_COLS = `id, user_id, audio_id, position_ms, label,
              created_at, updated_at, version, deleted_at`;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });
}

function rowToJson(row: AudioFlagRow): AudioFlagJson {
  return {
    id: row.id,
    audioId: row.audio_id,
    positionMs: row.position_ms,
    label: row.label ?? '',
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
  audioId?: unknown;
  positionMs?: unknown;
  label?: unknown;
  createdAt?: unknown;
  updatedAt?: unknown;
  version?: unknown;
}

function validatePutBody(body: PutBody, pathId: string): string | null {
  if (typeof body.id === 'string' && body.id !== pathId) {
    return 'id mismatch';
  }
  if (typeof body.audioId !== 'string' || body.audioId.trim().length === 0) {
    return 'audioId required';
  }
  if (
    typeof body.positionMs !== 'number' ||
    !Number.isFinite(body.positionMs) ||
    body.positionMs < 0
  ) {
    return 'positionMs must be non-negative number';
  }
  if (body.label !== undefined && typeof body.label !== 'string') {
    return 'label must be string';
  }
  if (!isIsoDate(body.createdAt) || !isIsoDate(body.updatedAt)) {
    return 'createdAt/updatedAt required';
  }
  return null;
}

export async function listAudioFlags(
  db: D1Database,
  claims: GoogleClaims,
): Promise<Response> {
  const result = await db
    .prepare(
      `SELECT ${SELECT_COLS}
       FROM user_audio_flags
       WHERE user_id = ? AND deleted_at IS NULL
       ORDER BY updated_at DESC`,
    )
    .bind(claims.sub)
    .all<AudioFlagRow>();

  return json((result.results ?? []).map(rowToJson));
}

export async function upsertAudioFlag(
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
       FROM user_audio_flags
       WHERE user_id = ? AND id = ?`,
    )
    .bind(claims.sub, id)
    .first<AudioFlagRow>();

  const audioId = (body.audioId as string).trim();
  const positionMs = Math.round(body.positionMs as number);
  const label = typeof body.label === 'string' ? body.label.trim() : '';
  const createdAt = body.createdAt as string;
  const clientUpdatedAt = body.updatedAt as string;
  const now = new Date().toISOString();

  if (!existing) {
    await db
      .prepare(
        `INSERT INTO user_audio_flags
          (id, user_id, audio_id, position_ms, label, created_at, updated_at, version, deleted_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, 1, NULL)`,
      )
      .bind(
        id,
        claims.sub,
        audioId,
        positionMs,
        label,
        createdAt,
        clientUpdatedAt,
      )
      .run();

    return json({
      id,
      audioId,
      positionMs,
      label,
      createdAt,
      updatedAt: clientUpdatedAt,
      version: 1,
    } satisfies AudioFlagJson);
  }

  if (existing.deleted_at !== null) {
    const version = existing.version + 1;
    await db
      .prepare(
        `UPDATE user_audio_flags SET
           audio_id = ?, position_ms = ?, label = ?, updated_at = ?,
           version = ?, deleted_at = NULL
         WHERE user_id = ? AND id = ?`,
      )
      .bind(
        audioId,
        positionMs,
        label,
        clientUpdatedAt,
        version,
        claims.sub,
        id,
      )
      .run();

    return json({
      id,
      audioId,
      positionMs,
      label,
      createdAt: existing.created_at,
      updatedAt: clientUpdatedAt,
      version,
    } satisfies AudioFlagJson);
  }

  if (clientUpdatedAt < existing.updated_at) {
    return json(rowToJson(existing), 409);
  }

  const version = existing.version + 1;
  const updatedAt =
    clientUpdatedAt > existing.updated_at ? clientUpdatedAt : now;

  await db
    .prepare(
      `UPDATE user_audio_flags SET
         audio_id = ?, position_ms = ?, label = ?, updated_at = ?, version = ?
       WHERE user_id = ? AND id = ?`,
    )
    .bind(
      audioId,
      positionMs,
      label,
      updatedAt,
      version,
      claims.sub,
      id,
    )
    .run();

  return json({
    id,
    audioId,
    positionMs,
    label,
    createdAt: existing.created_at,
    updatedAt,
    version,
  } satisfies AudioFlagJson);
}

export async function softDeleteAudioFlag(
  db: D1Database,
  claims: GoogleClaims,
  id: string,
): Promise<Response> {
  const existing = await db
    .prepare(
      `SELECT id, deleted_at, version FROM user_audio_flags
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
      `UPDATE user_audio_flags SET
         deleted_at = ?, updated_at = ?, version = version + 1
       WHERE user_id = ? AND id = ?`,
    )
    .bind(now, now, claims.sub, id)
    .run();

  return json({ ok: true, deletedAt: now });
}

export function audioFlagIdFromPath(pathname: string): string | null {
  const match = /^\/api\/audio-flags\/([^/]+)$/.exec(pathname);
  if (!match) return null;
  try {
    return decodeURIComponent(match[1]);
  } catch {
    return null;
  }
}

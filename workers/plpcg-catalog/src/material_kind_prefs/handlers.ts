import type { GoogleClaims } from '../auth/verify_google_token';
import { json } from '../playlists/wire.ts';

/** Teto da lista — o mesmo `kMaxFavoriteMaterialKinds` do app. */
export const MAX_KIND_IDS = 5;
const MAX_KIND_ID_LENGTH = 128;

interface MaterialKindPrefsRow {
  user_id: string;
  kind_ids: string;
  preferred_types: string;
  updated_at: string;
  version: number;
}

export interface MaterialKindPrefsJson {
  /** Ordem = preferência (índice 0 é o favorito nº 1). */
  kindIds: string[];
  /** Material type preferido (pdf/chord/...) por kind favoritado. */
  preferredTypes: Record<string, string>;
  updatedAt: string;
  version: number;
}

const SELECT_SQL = `SELECT user_id, kind_ids, preferred_types, updated_at, version
       FROM user_material_kind_prefs WHERE user_id = ?`;

function parsePreferredTypes(raw: string | undefined): Record<string, string> {
  if (!raw) return {};
  try {
    const parsed = JSON.parse(raw) as unknown;
    if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
      const result: Record<string, string> = {};
      for (const [k, v] of Object.entries(parsed as Record<string, unknown>)) {
        if (typeof v === 'string') result[k] = v;
      }
      return result;
    }
  } catch {
    // Linha corrompida não derruba o GET: devolve vazio e o próximo PUT conserta.
  }
  return {};
}

function rowToJson(row: MaterialKindPrefsRow): MaterialKindPrefsJson {
  let kindIds: string[] = [];
  try {
    const parsed = JSON.parse(row.kind_ids) as unknown;
    if (Array.isArray(parsed)) {
      kindIds = parsed.filter((v): v is string => typeof v === 'string');
    }
  } catch {
    // Linha corrompida não derruba o GET: devolve vazio e o próximo PUT conserta.
  }
  return {
    kindIds,
    preferredTypes: parsePreferredTypes(row.preferred_types),
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
  kindIds?: unknown;
  preferredTypes?: unknown;
  updatedAt?: unknown;
}

/** Mensagem de erro, ou `null` quando o corpo é válido. */
function validatePutBody(body: PutBody): string | null {
  if (!Array.isArray(body.kindIds)) return 'kindIds must be an array';
  if (body.kindIds.length > MAX_KIND_IDS) {
    return `kindIds must have at most ${MAX_KIND_IDS} items`;
  }
  const seen = new Set<string>();
  for (const id of body.kindIds) {
    if (typeof id !== 'string' || id.trim().length === 0) {
      return 'kindIds must be non-empty strings';
    }
    if (id.length > MAX_KIND_ID_LENGTH) return 'kindId too long';
    if (seen.has(id)) return 'kindIds must be unique';
    seen.add(id);
  }
  if (body.preferredTypes !== undefined) {
    if (
      typeof body.preferredTypes !== 'object' ||
      body.preferredTypes === null ||
      Array.isArray(body.preferredTypes)
    ) {
      return 'preferredTypes must be an object';
    }
    for (const value of Object.values(body.preferredTypes as Record<string, unknown>)) {
      if (typeof value !== 'string' || value.trim().length === 0) {
        return 'preferredTypes values must be non-empty strings';
      }
    }
  }
  if (!isIsoDate(body.updatedAt)) return 'updatedAt required';
  return null;
}

export async function getMaterialKindPrefs(
  db: D1Database,
  claims: GoogleClaims,
): Promise<Response> {
  const row = await db.prepare(SELECT_SQL).bind(claims.sub).first<MaterialKindPrefsRow>();
  if (!row) return new Response(null, { status: 204 });
  return json(rowToJson(row));
}

/**
 * Upsert do documento inteiro, last-write-wins por `updatedAt`.
 *
 * `409` devolve a linha remota quando ela é mais nova que o `updatedAt`
 * enviado — o cliente adota a remota. Mesmo `updatedAt` grava (o cliente
 * repete o PUT depois de uma falha de rede sem saber se chegou).
 */
export async function putMaterialKindPrefs(
  db: D1Database,
  claims: GoogleClaims,
  request: Request,
): Promise<Response> {
  let body: PutBody;
  try {
    body = (await request.json()) as PutBody;
  } catch {
    return json({ error: 'invalid json' }, 400);
  }
  const validationError = validatePutBody(body);
  if (validationError) return json({ error: validationError }, 400);

  const kindIds = body.kindIds as string[];
  const preferredTypes = (body.preferredTypes ?? {}) as Record<string, string>;
  const updatedAt = body.updatedAt as string;
  const serialized = JSON.stringify(kindIds);
  const serializedTypes = JSON.stringify(preferredTypes);

  const existing = await db
    .prepare(SELECT_SQL)
    .bind(claims.sub)
    .first<MaterialKindPrefsRow>();

  if (!existing) {
    await db
      .prepare(
        `INSERT INTO user_material_kind_prefs (user_id, kind_ids, preferred_types, updated_at, version)
         VALUES (?, ?, ?, ?, 1)`,
      )
      .bind(claims.sub, serialized, serializedTypes, updatedAt)
      .run();
    return json({ kindIds, preferredTypes, updatedAt, version: 1 } satisfies MaterialKindPrefsJson);
  }

  if (updatedAt < existing.updated_at) {
    return json(rowToJson(existing), 409);
  }

  const version = existing.version + 1;
  await db
    .prepare(
      `UPDATE user_material_kind_prefs SET kind_ids = ?, preferred_types = ?, updated_at = ?, version = ?
       WHERE user_id = ?`,
    )
    .bind(serialized, serializedTypes, updatedAt, version, claims.sub)
    .run();
  return json({ kindIds, preferredTypes, updatedAt, version } satisfies MaterialKindPrefsJson);
}

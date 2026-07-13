import { upsertUser } from './auth/session';
import { verifyGoogleIdToken } from './auth/verify_google_token';
import { withAuth } from './auth/with_auth';
import {
  getPlaylist,
  listPlaylists,
  playlistIdFromPath,
  softDeletePlaylist,
  upsertPlaylist,
} from './playlists/handlers';

export interface Env {
  DB: D1Database;
  GOOGLE_CLIENT_ID_WEB: string;
}

interface LouvorRow {
  nome: string;
  numero: string;
  classificacao: string;
  categoria: string;
  pdf: string;
  pdf_id: string;
  group_id: string;
}

interface LouvorJson {
  nome: string;
  numero: string;
  classificacao: string;
  categoria: string;
  pdf: string;
  pdfId: string;
  groupId: string;
}

type CorsMode = 'catalog' | 'auth' | 'playlists';

const CACHE_CONTROL = 'public, max-age=300';
const ALLOWED_ORIGINS = new Set([
  'https://v2.plpcg.com',
  'https://plpcg-v2.pages.dev',
  'http://localhost:8080',
  'http://127.0.0.1:8080',
]);

function isAllowedOrigin(origin: string): boolean {
  if (ALLOWED_ORIGINS.has(origin)) return true;
  try {
    const { hostname, protocol } = new URL(origin);
    return (
      protocol === 'https:' &&
      (hostname === 'plpcg-v2.pages.dev' ||
        hostname.endsWith('.plpcg-v2.pages.dev'))
    );
  } catch {
    return false;
  }
}

function corsHeaders(origin: string | null, mode: CorsMode): Headers {
  const headers = new Headers();
  if (origin !== null && isAllowedOrigin(origin)) {
    headers.set('Access-Control-Allow-Origin', origin);
    if (mode === 'playlists') {
      headers.set(
        'Access-Control-Allow-Methods',
        'GET, PUT, DELETE, OPTIONS',
      );
      headers.set(
        'Access-Control-Allow-Headers',
        'Authorization, Content-Type',
      );
    } else if (mode === 'auth') {
      headers.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
      headers.set(
        'Access-Control-Allow-Headers',
        'Authorization, Content-Type',
      );
    } else {
      headers.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
      headers.set(
        'Access-Control-Allow-Headers',
        'Content-Type, If-None-Match',
      );
    }
    headers.set('Vary', 'Origin');
  }
  return headers;
}

function withCors(
  response: Response,
  request: Request,
  mode: CorsMode,
): Response {
  const origin = request.headers.get('Origin');
  const cors = corsHeaders(origin, mode);
  if (cors.get('Access-Control-Allow-Origin') === null) {
    return response;
  }
  const headers = new Headers(response.headers);
  cors.forEach((value, key) => headers.set(key, value));
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

function jsonResponse(body: unknown, init: ResponseInit = {}): Response {
  const headers = new Headers(init.headers);
  headers.set('Content-Type', 'application/json; charset=utf-8');
  if (!headers.has('Cache-Control')) {
    headers.set('Cache-Control', CACHE_CONTROL);
  }
  return new Response(JSON.stringify(body), { ...init, headers });
}

function textResponse(body: string, init: ResponseInit = {}): Response {
  const headers = new Headers(init.headers);
  headers.set('Content-Type', 'text/plain; charset=utf-8');
  headers.set('Cache-Control', CACHE_CONTROL);
  return new Response(body, { ...init, headers });
}

function mapRow(row: LouvorRow): LouvorJson {
  return {
    nome: row.nome,
    numero: row.numero,
    classificacao: row.classificacao,
    categoria: row.categoria,
    pdf: row.pdf,
    pdfId: row.pdf_id,
    groupId: row.group_id,
  };
}

async function fetchLouvores(db: D1Database): Promise<Response> {
  const result = await db
    .prepare(
      `SELECT nome, numero, classificacao, categoria, pdf, pdf_id, group_id
       FROM louvores
       ORDER BY numero, nome`,
    )
    .all<LouvorRow>();

  const louvores = (result.results ?? []).map(mapRow);
  return jsonResponse(louvores);
}

async function fetchChecksum(
  db: D1Database,
  request: Request,
): Promise<Response> {
  const row = await db
    .prepare(`SELECT value FROM catalog_meta WHERE key = 'checksum'`)
    .first<{ value: string }>();

  if (!row?.value) {
    return textResponse('checksum not configured', { status: 503 });
  }

  const etag = `"${row.value}"`;
  const ifNoneMatch = request.headers.get('If-None-Match');
  if (ifNoneMatch === etag || ifNoneMatch === row.value) {
    return new Response(null, {
      status: 204,
      headers: {
        ETag: etag,
        'Cache-Control': CACHE_CONTROL,
      },
    });
  }

  return textResponse(row.value, {
    status: 200,
    headers: { ETag: etag },
  });
}

function bearerToken(request: Request): string | null {
  const header = request.headers.get('Authorization');
  if (!header?.startsWith('Bearer ')) return null;
  const token = header.slice(7).trim();
  return token.length > 0 ? token : null;
}

async function handleAuthSession(
  request: Request,
  env: Env,
): Promise<Response> {
  if (request.method !== 'POST') {
    return jsonResponse({ error: 'method not allowed' }, { status: 405 });
  }

  const clientId = env.GOOGLE_CLIENT_ID_WEB;
  if (!clientId) {
    return jsonResponse({ error: 'auth not configured' }, { status: 503 });
  }

  const token = bearerToken(request);
  if (!token) {
    return jsonResponse({ error: 'unauthorized' }, { status: 401 });
  }

  try {
    const claims = await verifyGoogleIdToken(token, clientId);
    const user = await upsertUser(env.DB, claims);
    return jsonResponse(user, {
      status: 200,
      headers: { 'Cache-Control': 'no-store' },
    });
  } catch {
    return jsonResponse({ error: 'unauthorized' }, { status: 401 });
  }
}

function corsModeForPath(pathname: string): CorsMode {
  if (pathname.startsWith('/api/playlists')) return 'playlists';
  if (pathname.startsWith('/api/auth/')) return 'auth';
  return 'catalog';
}

async function handlePlaylists(
  request: Request,
  env: Env,
  pathname: string,
): Promise<Response> {
  if (pathname === '/api/playlists') {
    if (request.method === 'GET') {
      return withAuth(request, env, (_req, e, claims) =>
        listPlaylists(e.DB, claims),
      );
    }
    return jsonResponse({ error: 'method not allowed' }, { status: 405 });
  }

  const id = playlistIdFromPath(pathname);
  if (id === null) {
    return jsonResponse({ error: 'not found' }, { status: 404 });
  }

  if (request.method === 'GET') {
    return withAuth(request, env, (_req, e, claims) =>
      getPlaylist(e.DB, claims, id),
    );
  }
  if (request.method === 'PUT') {
    return withAuth(request, env, (req, e, claims) =>
      upsertPlaylist(e.DB, claims, id, req),
    );
  }
  if (request.method === 'DELETE') {
    return withAuth(request, env, (_req, e, claims) =>
      softDeletePlaylist(e.DB, claims, id),
    );
  }

  return jsonResponse({ error: 'method not allowed' }, { status: 405 });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const mode = corsModeForPath(url.pathname);

    if (request.method === 'OPTIONS') {
      const cors = corsHeaders(request.headers.get('Origin'), mode);
      if (cors.get('Access-Control-Allow-Origin') === null) {
        return jsonResponse({ error: 'forbidden' }, { status: 403 });
      }
      cors.set('Access-Control-Max-Age', '86400');
      return new Response(null, { status: 204, headers: cors });
    }

    if (url.pathname === '/api/auth/session') {
      return withCors(await handleAuthSession(request, env), request, 'auth');
    }

    if (url.pathname.startsWith('/api/playlists')) {
      return withCors(
        await handlePlaylists(request, env, url.pathname),
        request,
        'playlists',
      );
    }

    if (request.method !== 'GET') {
      return withCors(
        jsonResponse({ error: 'method not allowed' }, { status: 405 }),
        request,
        mode,
      );
    }

    if (url.pathname === '/api/catalog/louvores') {
      return withCors(await fetchLouvores(env.DB), request, 'catalog');
    }

    if (url.pathname === '/api/catalog/checksum') {
      return withCors(await fetchChecksum(env.DB, request), request, 'catalog');
    }

    return withCors(
      jsonResponse({ error: 'not found' }, { status: 404 }),
      request,
      mode,
    );
  },
};

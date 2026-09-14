import { upsertUser } from './auth/session';
import { handleDeleteSession, sessionResponse } from './auth/session_handlers';
import { setUsername } from './auth/username';
import type { GoogleClaims } from './auth/verify_google_token';
import { verifyGoogleIdToken } from './auth/verify_google_token';
import { withAuth } from './auth/with_auth';
import {
  audioFlagIdFromPath,
  listAudioFlags,
  softDeleteAudioFlag,
  upsertAudioFlag,
} from './audio_flags/handlers';
import {
  getMaterialKindPrefs,
  putMaterialKindPrefs,
} from './material_kind_prefs/handlers';
import {
  getPlaylist,
  listPlaylists,
  playlistIdFromPath,
  softDeletePlaylist,
  upsertPlaylist,
} from './playlists/handlers';
import {
  listPublicPlaylistsByUsername,
  searchSocialUsers,
  socialUsernameFromPath,
} from './social/handlers';
import {
  createShortLink,
  resolveShortLink,
  shortLinkCodeFromPath,
} from './links/handlers';
import { isShortCode } from './short_code.ts';
import { ensureLiveRoom, liveRoomRedirect, regenerateLiveRoom } from './live/handlers.ts';
export { LiveRoom } from './live/live_room.ts';
import { proxyColdigomAsset } from './coldigom_assets_proxy';
import { matchesEtag } from './etag';
import { LOUVOR_SELECT_COLUMNS, mapRow, type LouvorRow } from './catalog/louvor_row';

export interface Env {
  DB: D1Database;
  GOOGLE_CLIENT_ID_WEB: string;
  COLDIGOM_API_BASE_URL?: string;
  LIVE: DurableObjectNamespace;
}

type CorsMode = 'catalog' | 'auth' | 'playlists' | 'social' | 'links' | 'live';

const CACHE_CONTROL = 'public, max-age=300';
const ALLOWED_ORIGINS = new Set([
  'https://120826.plpcg.com',
  'https://v2.plpcg.com',
  'https://plpcg.com',
  'https://plpcjf.org',
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
        hostname.endsWith('.plpcg-v2.pages.dev') ||
        hostname === 'plpcg-120826.pages.dev' ||
        hostname.endsWith('.plpcg-120826.pages.dev'))
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
        'Authorization, Content-Type, If-None-Match',
      );
      // Fecha a assimetria com o modo catálogo (A.4): as rotas de playlist não
      // dependem do `ETag` hoje, mas um leitor no browser não consegue lê-lo
      // sem isto, e a revalidação condicional é o próximo passo natural.
      headers.set('Access-Control-Expose-Headers', 'ETag');
    } else if (mode === 'social') {
      headers.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
      headers.set(
        'Access-Control-Allow-Headers',
        'Authorization, Content-Type',
      );
    } else if (mode === 'links') {
      // `POST /api/links` (autenticado) e `GET /l/:code` (público, D7) — o
      // GET não precisa de CORS de verdade (navegação de topo, não fetch),
      // mas herda o mesmo modo por simplicidade de roteamento.
      headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      headers.set(
        'Access-Control-Allow-Headers',
        'Authorization, Content-Type',
      );
    } else if (mode === 'live') {
      headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      headers.set('Access-Control-Allow-Headers', 'Authorization, Content-Type');
    } else if (mode === 'auth') {
      headers.set('Access-Control-Allow-Methods', 'POST, PUT, DELETE, OPTIONS');
      headers.set(
        'Access-Control-Allow-Headers',
        'Authorization, Content-Type',
      );
    } else {
      headers.set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
      headers.set(
        'Access-Control-Allow-Headers',
        'Content-Type, If-None-Match, Range',
      );
      // `ETag` precisa ser exposto: o cliente Dart o lê para salvar o checksum
      // do manifest e revalidar com `If-None-Match` no boot seguinte (A1).
      headers.set(
        'Access-Control-Expose-Headers',
        'Accept-Ranges, Content-Length, Content-Range, ETag',
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

/** Checksum SHA-256 do catálogo em `catalog_meta`; `null` se não configurado. */
async function readChecksum(db: D1Database): Promise<string | null> {
  const row = await db
    .prepare(`SELECT value FROM catalog_meta WHERE key = 'checksum'`)
    .first<{ value: string }>();

  return row?.value || null;
}

/**
 * `true` quando o `If-None-Match` do request corresponde ao checksum atual.
 *
 * A comparação em si mora em `./etag` (lista separada por vírgula, `*`, `W/`),
 * onde é testável sem montar um `Request`.
 */
function requestMatchesChecksum(request: Request, checksum: string): boolean {
  return matchesEtag(request.headers.get('If-None-Match'), `"${checksum}"`);
}

async function fetchLouvores(
  db: D1Database,
  request: Request,
): Promise<Response> {
  const checksum = await readChecksum(db);

  // ETag do manifest = checksum do catálogo: evita baixar ~4600 itens sem mudança.
  if (checksum && requestMatchesChecksum(request, checksum)) {
    return new Response(null, {
      status: 304,
      headers: {
        ETag: `"${checksum}"`,
        'Cache-Control': CACHE_CONTROL,
      },
    });
  }

  const result = await db
    .prepare(
      `SELECT ${LOUVOR_SELECT_COLUMNS}
       FROM louvores
       ORDER BY numero, nome`,
    )
    .all<LouvorRow>();

  const louvores = (result.results ?? []).map(mapRow);
  return jsonResponse(
    louvores,
    checksum ? { headers: { ETag: `"${checksum}"` } } : {},
  );
}

async function fetchChecksum(
  db: D1Database,
  request: Request,
): Promise<Response> {
  const checksum = await readChecksum(db);

  if (!checksum) {
    return textResponse('checksum not configured', { status: 503 });
  }

  const etag = `"${checksum}"`;
  if (requestMatchesChecksum(request, checksum)) {
    return new Response(null, {
      status: 204,
      headers: {
        ETag: etag,
        'Cache-Control': CACHE_CONTROL,
      },
    });
  }

  return textResponse(checksum, {
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
  if (request.method === 'DELETE') {
    return handleDeleteSession(env.DB, request);
  }
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

  let claims: GoogleClaims;
  try {
    claims = await verifyGoogleIdToken(token, clientId);
  } catch {
    return jsonResponse({ error: 'unauthorized' }, { status: 401 });
  }
  const user = await upsertUser(env.DB, claims);
  // Troca o id_token (1 h) por uma sessão do Worker (spec D1). Falha de D1
  // aqui propaga (5xx): o token era válido, o problema não é do cliente.
  return sessionResponse(env.DB, user);
}

function corsModeForPath(pathname: string): CorsMode {
  if (pathname.startsWith('/api/playlists')) return 'playlists';
  if (pathname.startsWith('/api/audio-flags')) return 'playlists';
  if (pathname.startsWith('/api/material-kind-prefs')) return 'playlists';
  if (pathname.startsWith('/api/social')) return 'social';
  if (pathname.startsWith('/api/links')) return 'links';
  if (pathname.startsWith('/l/')) return 'links';
  if (pathname.startsWith('/api/live')) return 'live';
  if (pathname.startsWith('/ao-vivo/')) return 'live';
  if (pathname.startsWith('/api/auth/')) return 'auth';
  if (pathname.startsWith('/api/coldigom/')) return 'catalog';
  return 'catalog';
}

async function handleSocial(
  request: Request,
  env: Env,
  pathname: string,
): Promise<Response> {
  if (pathname === '/api/social/users') {
    if (request.method === 'GET') {
      return withAuth(request, env, (req, e) =>
        searchSocialUsers(e.DB, req),
      );
    }
    return jsonResponse({ error: 'method not allowed' }, { status: 405 });
  }

  const username = socialUsernameFromPath(pathname);
  if (username === null) {
    return jsonResponse({ error: 'not found' }, { status: 404 });
  }
  if (request.method === 'GET') {
    return withAuth(request, env, (_req, e) =>
      listPublicPlaylistsByUsername(e.DB, username),
    );
  }
  return jsonResponse({ error: 'method not allowed' }, { status: 405 });
}

async function handlePlaylists(
  request: Request,
  env: Env,
  pathname: string,
): Promise<Response> {
  if (pathname === '/api/playlists') {
    if (request.method === 'GET') {
      // `?includeDeleted=1` traz também os tombstones (spec A.2).
      const includeDeleted =
        new URL(request.url).searchParams.get('includeDeleted') === '1';
      return withAuth(request, env, (_req, e, claims) =>
        listPlaylists(e.DB, claims, { includeDeleted }),
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

async function handleAudioFlags(
  request: Request,
  env: Env,
  pathname: string,
): Promise<Response> {
  if (pathname === '/api/audio-flags') {
    if (request.method === 'GET') {
      // `?includeDeleted=1` traz também os tombstones (spec A.2).
      const includeDeleted =
        new URL(request.url).searchParams.get('includeDeleted') === '1';
      return withAuth(request, env, (_req, e, claims) =>
        listAudioFlags(e.DB, claims, { includeDeleted }),
      );
    }
    return jsonResponse({ error: 'method not allowed' }, { status: 405 });
  }

  const id = audioFlagIdFromPath(pathname);
  if (id === null) {
    return jsonResponse({ error: 'not found' }, { status: 404 });
  }

  if (request.method === 'PUT') {
    return withAuth(request, env, (req, e, claims) =>
      upsertAudioFlag(e.DB, claims, id, req),
    );
  }
  if (request.method === 'DELETE') {
    return withAuth(request, env, (_req, e, claims) =>
      softDeleteAudioFlag(e.DB, claims, id),
    );
  }

  return jsonResponse({ error: 'method not allowed' }, { status: 405 });
}

async function handleMaterialKindPrefs(
  request: Request,
  env: Env,
  pathname: string,
): Promise<Response> {
  if (pathname !== '/api/material-kind-prefs') {
    return jsonResponse({ error: 'not found' }, { status: 404 });
  }
  if (request.method === 'GET') {
    return withAuth(request, env, (_req, e, claims) =>
      getMaterialKindPrefs(e.DB, claims),
    );
  }
  if (request.method === 'PUT') {
    return withAuth(request, env, (req, e, claims) =>
      putMaterialKindPrefs(e.DB, claims, req),
    );
  }
  return jsonResponse({ error: 'method not allowed' }, { status: 405 });
}

async function handleLinks(
  request: Request,
  env: Env,
  pathname: string,
): Promise<Response> {
  if (pathname === '/api/links') {
    if (request.method === 'POST') {
      return withAuth(request, env, (req, e, claims) =>
        createShortLink(e.DB, claims, req),
      );
    }
    return jsonResponse({ error: 'method not allowed' }, { status: 405 });
  }
  return jsonResponse({ error: 'not found' }, { status: 404 });
}

async function handleShortLinkRedirect(
  request: Request,
  env: Env,
  pathname: string,
): Promise<Response> {
  if (request.method !== 'GET') {
    return jsonResponse({ error: 'method not allowed' }, { status: 405 });
  }
  const code = shortLinkCodeFromPath(pathname);
  if (code === null) {
    return jsonResponse({ error: 'not found' }, { status: 404 });
  }
  return resolveShortLink(env.DB, code);
}

/** `/api/live/:code/ws` → código, ou `null`. */
function liveWsCodeFromPath(pathname: string): string | null {
  const match = /^\/api\/live\/([a-z0-9]{7})\/ws$/.exec(pathname);
  return match ? match[1] : null;
}

async function handleLive(request: Request, env: Env, pathname: string): Promise<Response> {
  const wsCode = liveWsCodeFromPath(pathname);
  if (wsCode !== null) {
    if (request.method !== 'GET') {
      return jsonResponse({ error: 'method not allowed' }, { status: 405 });
    }
    // Roteador magro: o upgrade vai inteiro para o DO da sala. A resposta 101
    // volta **sem** `withCors` — reconstruí-la mataria o `webSocket`.
    const stub = env.LIVE.get(env.LIVE.idFromName(wsCode));
    return stub.fetch(request);
  }
  if (pathname === '/api/live/room' || pathname === '/api/live/room/regenerate') {
    if (request.method !== 'POST') {
      return jsonResponse({ error: 'method not allowed' }, { status: 405 });
    }
    const handler = pathname.endsWith('/regenerate') ? regenerateLiveRoom : ensureLiveRoom;
    return withAuth(request, env, (_req, e, claims) => handler(e.DB, (e as Env).LIVE, claims));
  }
  return jsonResponse({ error: 'not found' }, { status: 404 });
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

    if (url.pathname === '/api/auth/username') {
      if (request.method !== 'PUT') {
        return withCors(
          jsonResponse({ error: 'method not allowed' }, { status: 405 }),
          request,
          'auth',
        );
      }
      return withCors(
        await withAuth(request, env, (req, e, claims) =>
          setUsername(e.DB, claims, req),
        ),
        request,
        'auth',
      );
    }

    if (url.pathname.startsWith('/api/social')) {
      return withCors(
        await handleSocial(request, env, url.pathname),
        request,
        'social',
      );
    }

    if (url.pathname.startsWith('/api/playlists')) {
      return withCors(
        await handlePlaylists(request, env, url.pathname),
        request,
        'playlists',
      );
    }

    if (url.pathname.startsWith('/api/audio-flags')) {
      return withCors(
        await handleAudioFlags(request, env, url.pathname),
        request,
        'playlists',
      );
    }

    if (url.pathname.startsWith('/api/material-kind-prefs')) {
      return withCors(
        await handleMaterialKindPrefs(request, env, url.pathname),
        request,
        'playlists',
      );
    }

    if (url.pathname.startsWith('/api/live')) {
      const response = await handleLive(request, env, url.pathname);
      return response.status === 101 ? response : withCors(response, request, 'live');
    }

    if (url.pathname.startsWith('/api/coldigom/')) {
      return withCors(
        await proxyColdigomAsset(request, env, url.pathname),
        request,
        'catalog',
      );
    }

    if (url.pathname.startsWith('/api/links')) {
      return withCors(
        await handleLinks(request, env, url.pathname),
        request,
        'links',
      );
    }

    if (url.pathname.startsWith('/l/')) {
      return withCors(
        await handleShortLinkRedirect(request, env, url.pathname),
        request,
        'links',
      );
    }

    if (url.pathname.startsWith('/ao-vivo/')) {
      if (request.method !== 'GET') {
        return withCors(jsonResponse({ error: 'method not allowed' }, { status: 405 }), request, 'live');
      }
      return withCors(liveRoomRedirect(url.pathname), request, 'live');
    }

    if (request.method !== 'GET') {
      return withCors(
        jsonResponse({ error: 'method not allowed' }, { status: 405 }),
        request,
        mode,
      );
    }

    if (url.pathname === '/api/catalog/louvores') {
      return withCors(await fetchLouvores(env.DB, request), request, 'catalog');
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

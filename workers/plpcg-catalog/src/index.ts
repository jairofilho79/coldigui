export interface Env {
  DB: D1Database;
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

const CACHE_CONTROL = 'public, max-age=300';
const ALLOWED_ORIGINS = new Set([
  'https://v2.plpcg.com',
  'https://plpcg-v2.pages.dev',
]);

function isAllowedOrigin(origin: string): boolean {
  if (ALLOWED_ORIGINS.has(origin)) return true;
  // Previews do Pages: https://<hash>.plpcg-v2.pages.dev
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

function corsHeaders(origin: string | null): Headers {
  const headers = new Headers();
  if (origin !== null && isAllowedOrigin(origin)) {
    headers.set('Access-Control-Allow-Origin', origin);
    headers.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
    headers.set('Access-Control-Allow-Headers', 'Content-Type, If-None-Match');
    headers.set('Vary', 'Origin');
  }
  return headers;
}

function withCors(response: Response, request: Request): Response {
  const origin = request.headers.get('Origin');
  const cors = corsHeaders(origin);
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
  headers.set('Cache-Control', CACHE_CONTROL);
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

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === 'OPTIONS') {
      const cors = corsHeaders(request.headers.get('Origin'));
      if (cors.get('Access-Control-Allow-Origin') === null) {
        return jsonResponse({ error: 'method not allowed' }, { status: 405 });
      }
      cors.set('Access-Control-Max-Age', '86400');
      return new Response(null, { status: 204, headers: cors });
    }

    if (request.method !== 'GET') {
      return withCors(
        jsonResponse({ error: 'method not allowed' }, { status: 405 }),
        request,
      );
    }

    if (url.pathname === '/api/catalog/louvores') {
      return withCors(await fetchLouvores(env.DB), request);
    }

    if (url.pathname === '/api/catalog/checksum') {
      return withCors(await fetchChecksum(env.DB, request), request);
    }

    return withCors(jsonResponse({ error: 'not found' }, { status: 404 }), request);
  },
};

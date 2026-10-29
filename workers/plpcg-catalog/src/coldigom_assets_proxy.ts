const DEFAULT_COLDIGOM_API_BASE_URL =
  'https://coldigom-api.jairofilho79.workers.dev';

export interface ColdigomProxyEnv {
  COLDIGOM_API_BASE_URL?: string;
}

export function coldigomAssetPathFromRequest(pathname: string): string | null {
  const prefix = '/api/coldigom/';
  if (!pathname.startsWith(prefix)) return null;
  const rest = pathname.slice(prefix.length);
  return rest.length > 0 ? rest : null;
}

export function buildColdigomUpstreamUrl(
  env: ColdigomProxyEnv,
  assetPath: string,
): string {
  const base = (env.COLDIGOM_API_BASE_URL ?? DEFAULT_COLDIGOM_API_BASE_URL).replace(
    /\/$/,
    '',
  );
  const normalized = assetPath.startsWith('/') ? assetPath.slice(1) : assetPath;
  return `${base}/${normalized}`;
}

export async function proxyColdigomAsset(
  request: Request,
  env: ColdigomProxyEnv,
  pathname: string,
): Promise<Response> {
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    return new Response(JSON.stringify({ error: 'method not allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json; charset=utf-8' },
    });
  }

  const assetPath = coldigomAssetPathFromRequest(pathname);
  if (assetPath === null) {
    return new Response(JSON.stringify({ error: 'not found' }), {
      status: 404,
      headers: { 'Content-Type': 'application/json; charset=utf-8' },
    });
  }

  const upstreamUrl = buildColdigomUpstreamUrl(env, assetPath);
  const upstreamHeaders = new Headers();
  const range = request.headers.get('Range') ?? request.headers.get('range');
  if (range) upstreamHeaders.set('Range', range);

  const upstream = await fetch(upstreamUrl, {
    method: 'GET',
    headers: upstreamHeaders,
  });

  const headers = new Headers(upstream.headers);
  headers.set('Cross-Origin-Resource-Policy', 'cross-origin');

  if (request.method === 'HEAD') {
    return new Response(null, {
      status: upstream.status,
      statusText: upstream.statusText,
      headers,
    });
  }

  return new Response(upstream.body, {
    status: upstream.status,
    statusText: upstream.statusText,
    headers,
  });
}

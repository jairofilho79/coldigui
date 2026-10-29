export const APPLE_APP_SITE_ASSOCIATION = {
  applinks: {
    apps: [],
    details: [
      {
        appID: 'PX8Z8276X5.com.plpcg.app',
        paths: ['*'],
      },
      {
        appID: 'PX8Z8276X5.com.example.coldigui',
        paths: ['*'],
      },
    ],
  },
};

const ANDROID_SHA256_CERT_FINGERPRINTS = [
  '34:A1:63:A8:E8:B3:A9:90:DE:0A:F0:D9:1C:24:F8:C3:8C:A4:29:D3:A7:8A:58:76:72:CF:B0:2B:7F:AC:66:C9',
  'B6:0C:C2:12:ED:7B:75:57:A3:C1:8D:EF:89:0B:CE:EB:F7:EE:BE:33:7D:A1:71:8E:7F:8B:8B:A9:58:FF:8F:3D',
];

export const ANDROID_ASSET_LINKS = [
  {
    relation: ['delegate_permission/common.handle_all_urls'],
    target: {
      namespace: 'android_app',
      package_name: 'com.plpcg.app',
      sha256_cert_fingerprints: ANDROID_SHA256_CERT_FINGERPRINTS,
    },
  },
  {
    relation: ['delegate_permission/common.handle_all_urls'],
    target: {
      namespace: 'android_app',
      package_name: 'com.example.coldigui',
      sha256_cert_fingerprints: ANDROID_SHA256_CERT_FINGERPRINTS,
    },
  },
];

/**
 * Parâmetros de query na raiz ('/') que pertencem ao novo app PLPCG / Coldigui v2.
 *
 * NOTA DE COMPATIBILIDADE:
 * Os parâmetros da versão clássica da web ('s', 'sharepdfs', 'shareitems', 'shareaudios')
 * NÃO devem entrar aqui. Eles pertencem ao PLPCG Web (plpcjf / Cloudflare Pages) e devem
 * ser repassados diretamente via fetch(request) para que as listas continuem abrindo
 * normalmente no navegador sem acionar o protocolo nativo plpcg://.
 */
const APP_DEEP_LINK_QUERY_PARAMS = [
  'p',
  'live',
];

export function isRootDeepLinkQuery(searchParams: URLSearchParams): boolean {
  return APP_DEEP_LINK_QUERY_PARAMS.some((key) => searchParams.has(key));
}

function escapeHtmlAttr(raw: string): string {
  return raw
    .replace(/&/g, '&amp;')
    .replace(/"/g, '&quot;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

export function buildCustomSchemeDeepLink(
  pathname: string,
  search: string,
): string {
  const normalizedPath = pathname.startsWith('/') ? pathname : `/${pathname}`;
  return `plpcg://${normalizedPath}${search}`;
}

export function handleDeepLinkRedirect(
  pathname: string,
  search: string,
): Response {
  const deepLink = buildCustomSchemeDeepLink(pathname, search);
  const escapedDeepLink = escapeHtmlAttr(deepLink);
  const jsDeepLink = JSON.stringify(deepLink);

  const html = `<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Abrir no App PLPCG</title>
  <style>
    :root { color-scheme: dark; }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 24px;
      background: #121212;
      color: #f5f5f5;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      text-align: center;
    }
    .card {
      max-width: 400px;
      width: 100%;
      background: #1e1e1e;
      border: 1px solid #2e2e2e;
      border-radius: 16px;
      padding: 32px 24px;
      box-shadow: 0 12px 32px rgba(0, 0, 0, 0.45);
    }
    h1 {
      margin: 0 0 12px;
      font-size: 20px;
      font-weight: 600;
    }
    p {
      margin: 0 0 24px;
      font-size: 14px;
      line-height: 1.5;
      color: #b3b3b3;
    }
    .btn {
      display: inline-block;
      width: 100%;
      padding: 14px 20px;
      border-radius: 12px;
      background: #d4af37;
      color: #121212;
      font-weight: 600;
      font-size: 16px;
      text-decoration: none;
    }
  </style>
  <script>
    window.location.replace(${jsDeepLink});
  </script>
</head>
<body>
  <div class="card">
    <h1>Abrindo o aplicativo PLPCG…</h1>
    <p>Se o aplicativo não abrir automaticamente, toque no botão abaixo.</p>
    <a class="btn" href="${escapedDeepLink}">Abrir no App PLPCG</a>
  </div>
</body>
</html>`;

  return new Response(html, {
    status: 200,
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });
}

export function handleAppleAppSiteAssociation(): Response {
  return new Response(JSON.stringify(APPLE_APP_SITE_ASSOCIATION), {
    status: 200,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'public, max-age=3600',
    },
  });
}

export function handleAssetLinks(): Response {
  return new Response(JSON.stringify(ANDROID_ASSET_LINKS), {
    status: 200,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'public, max-age=3600',
    },
  });
}

export function handleLouvorRedirect(pathname: string, search: string): Response {
  return handleDeepLinkRedirect(pathname, search);
}

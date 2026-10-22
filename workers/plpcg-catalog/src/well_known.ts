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

export const ANDROID_ASSET_LINKS = [
  {
    relation: ['delegate_permission/common.handle_all_urls'],
    target: {
      namespace: 'android_app',
      package_name: 'com.plpcg.app',
      sha256_cert_fingerprints: [
        '34:A1:63:A8:E8:B3:A9:90:DE:0A:F0:D9:1C:24:F8:C3:8C:A4:29:D3:A7:8A:58:76:72:CF:B0:2B:7F:AC:66:C9',
        'B6:0C:C2:12:ED:7B:75:57:A3:C1:8D:EF:89:0B:CE:EB:F7:EE:BE:33:7D:A1:71:8E:7F:8B:8B:A9:58:FF:8F:3D',
      ],
    },
  },
  {
    relation: ['delegate_permission/common.handle_all_urls'],
    target: {
      namespace: 'android_app',
      package_name: 'com.example.coldigui',
      sha256_cert_fingerprints: [],
    },
  },
];

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
  return new Response(null, {
    status: 302,
    headers: {
      Location: `https://v2.plpcg.com${pathname}${search}`,
      'Cache-Control': 'no-store',
    },
  });
}

import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import {
  buildColdigomUpstreamUrl,
  coldigomAssetPathFromRequest,
  proxyColdigomAsset,
} from './coldigom_assets_proxy.ts';

test('extrai path do asset após /api/coldigom/', () => {
  assert.equal(
    coldigomAssetPathFromRequest('/api/coldigom/assets/praises/p1/a.mp3'),
    'assets/praises/p1/a.mp3',
  );
  assert.equal(coldigomAssetPathFromRequest('/api/catalog/louvores'), null);
});

test('monta URL upstream Coldigom', () => {
  assert.equal(
    buildColdigomUpstreamUrl(
      { COLDIGOM_API_BASE_URL: 'https://coldigom.example' },
      'assets/praises/p1/a.mp3',
    ),
    'https://coldigom.example/assets/praises/p1/a.mp3',
  );
});

test('proxy repassa Range e adiciona CORP + CORS upstream', async () => {
  const originalFetch = globalThis.fetch;
  let capturedUrl = '';
  let capturedRange = '';

  globalThis.fetch = (async (input: RequestInfo | URL, init?: RequestInit) => {
    capturedUrl = String(input);
    capturedRange = String(
      (init?.headers as Headers | undefined)?.get?.('Range') ?? '',
    );
    return new Response(new Uint8Array([0xff, 0xfb]), {
      status: 206,
      headers: {
        'Content-Type': 'audio/mpeg',
        'Content-Range': 'bytes 0-1/100',
        'Accept-Ranges': 'bytes',
      },
    });
  }) as typeof fetch;

  try {
    const request = new Request(
      'https://plpcg.com/api/coldigom/assets/praises/p1/a.mp3',
      { headers: { Range: 'bytes=0-1' } },
    );
    const response = await proxyColdigomAsset(
      request,
      { COLDIGOM_API_BASE_URL: 'https://coldigom.example' },
      '/api/coldigom/assets/praises/p1/a.mp3',
    );

    assert.equal(
      capturedUrl,
      'https://coldigom.example/assets/praises/p1/a.mp3',
    );
    assert.equal(capturedRange, 'bytes=0-1');
    assert.equal(response.status, 206);
    assert.equal(
      response.headers.get('Cross-Origin-Resource-Policy'),
      'cross-origin',
    );
    assert.equal(response.headers.get('Content-Type'), 'audio/mpeg');
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('proxy aceita HEAD', async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = (async () =>
    new Response(new Uint8Array([0xff, 0xfb]), {
      status: 200,
      headers: { 'Content-Type': 'audio/mpeg' },
    })) as typeof fetch;

  try {
    const request = new Request(
      'https://plpcg.com/api/coldigom/assets/praises/p1/a.mp3',
      { method: 'HEAD' },
    );
    const response = await proxyColdigomAsset(
      request,
      { COLDIGOM_API_BASE_URL: 'https://coldigom.example' },
      '/api/coldigom/assets/praises/p1/a.mp3',
    );
    assert.equal(response.status, 200);
    assert.equal(await response.text(), '');
  } finally {
    globalThis.fetch = originalFetch;
  }
});

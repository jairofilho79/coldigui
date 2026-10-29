import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import {
  APPLE_APP_SITE_ASSOCIATION,
  ANDROID_ASSET_LINKS,
  handleAppleAppSiteAssociation,
  handleAssetLinks,
  handleDeepLinkRedirect,
  handleLouvorRedirect,
  isRootDeepLinkQuery,
} from './well_known.ts';

test('handleAppleAppSiteAssociation devolve AASA JSON para universal links', async () => {
  const response = handleAppleAppSiteAssociation();

  assert.equal(response.status, 200);
  assert.equal(response.headers.get('Content-Type'), 'application/json; charset=utf-8');
  assert.equal(response.headers.get('Cache-Control'), 'public, max-age=3600');

  const json = (await response.json()) as typeof APPLE_APP_SITE_ASSOCIATION;
  assert.ok(json.applinks);
  assert.ok(json.applinks.details.some(d => d.appID.includes('com.plpcg.app')));
  assert.ok(json.applinks.details.some(d => d.appID.includes('com.example.coldigui')));
});

test('handleAssetLinks devolve assetlinks JSON com fingerprints para ambos os pacotes', async () => {
  const response = handleAssetLinks();

  assert.equal(response.status, 200);
  assert.equal(response.headers.get('Content-Type'), 'application/json; charset=utf-8');
  assert.equal(response.headers.get('Cache-Control'), 'public, max-age=3600');

  const json = (await response.json()) as typeof ANDROID_ASSET_LINKS;
  const plpcg = json.find(item => item.target.package_name === 'com.plpcg.app');
  const legacy = json.find(item => item.target.package_name === 'com.example.coldigui');
  assert.ok(plpcg);
  assert.ok(legacy);
  assert.ok(plpcg.target.sha256_cert_fingerprints.length > 0);
  assert.deepEqual(
    legacy.target.sha256_cert_fingerprints,
    plpcg.target.sha256_cert_fingerprints,
  );
});

test('handleLouvorRedirect devolve página de deep link plpcg:// sem chamar v2.plpcg.com', async () => {
  const response = handleLouvorRedirect('/louvor/abc123', '?q=1');

  assert.equal(response.status, 200);
  assert.equal(response.headers.get('Content-Type'), 'text/html; charset=utf-8');
  assert.equal(response.headers.get('Cache-Control'), 'no-store');

  const html = await response.text();
  assert.ok(html.includes('plpcg:///louvor/abc123?q=1'));
  assert.ok(!html.includes('v2.plpcg.com'));
});

test('handleDeepLinkRedirect na raiz gera plpcg:///?p=...&n=... para listas compartilhadas', async () => {
  const response = handleDeepLinkRedirect('/', '?p=1a2-0c3&n=Culto');

  assert.equal(response.status, 200);
  const html = await response.text();
  assert.ok(html.includes('plpcg:///?p=1a2-0c3&amp;n=Culto'));
  assert.ok(html.includes('window.location.replace("plpcg:///?p=1a2-0c3&n=Culto")'));
  assert.ok(!html.includes('v2.plpcg.com'));
});

test('isRootDeepLinkQuery identifica parâmetros de compartilhamento do app e preserva listas da web', () => {
  assert.equal(isRootDeepLinkQuery(new URLSearchParams('p=1a2&n=Culto')), true);
  assert.equal(isRootDeepLinkQuery(new URLSearchParams('live=abc1234')), true);
  assert.equal(isRootDeepLinkQuery(new URLSearchParams('s=0000&n=Demo')), false);
  assert.equal(isRootDeepLinkQuery(new URLSearchParams('sharepdfs=TEST')), false);
  assert.equal(isRootDeepLinkQuery(new URLSearchParams('')), false);
  assert.equal(isRootDeepLinkQuery(new URLSearchParams('pesquisa=amor')), false);
});

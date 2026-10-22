import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import {
  APPLE_APP_SITE_ASSOCIATION,
  ANDROID_ASSET_LINKS,
  handleAppleAppSiteAssociation,
  handleAssetLinks,
  handleLouvorRedirect,
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

test('handleAssetLinks devolve assetlinks JSON para Android App Links', async () => {
  const response = handleAssetLinks();

  assert.equal(response.status, 200);
  assert.equal(response.headers.get('Content-Type'), 'application/json; charset=utf-8');
  assert.equal(response.headers.get('Cache-Control'), 'public, max-age=3600');

  const json = (await response.json()) as typeof ANDROID_ASSET_LINKS;
  assert.ok(json.some(item => item.target.package_name === 'com.plpcg.app'));
  assert.ok(json.some(item => item.target.package_name === 'com.example.coldigui'));
});

test('handleLouvorRedirect redireciona 302 para fallback web v2.plpcg.com/louvor/:id', () => {
  const response = handleLouvorRedirect('/louvor/abc123', '?q=1');

  assert.equal(response.status, 302);
  assert.equal(response.headers.get('Location'), 'https://v2.plpcg.com/louvor/abc123?q=1');
  assert.equal(response.headers.get('Cache-Control'), 'no-store');
});

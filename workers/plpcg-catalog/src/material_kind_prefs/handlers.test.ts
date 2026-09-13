import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { FakeD1Database, fakeDb } from '../test/fake_d1.ts';
import {
  getMaterialKindPrefs,
  putMaterialKindPrefs,
  type MaterialKindPrefsJson,
} from './handlers.ts';

const claims = { sub: 'u1', email: 'a@b.c' } as never;

function putRequest(body: Record<string, unknown>): Request {
  return new Request('https://example.test/api/material-kind-prefs', {
    method: 'PUT',
    body: JSON.stringify({
      kindIds: ['k1', 'k2'],
      updatedAt: '2026-09-02T10:00:00.000Z',
      ...body,
    }),
  });
}

test('GET sem linha devolve 204', async () => {
  const db = new FakeD1Database();
  const response = await getMaterialKindPrefs(fakeDb(db), claims);
  assert.equal(response.status, 204);
});

test('PUT cria com version 1 e GET devolve o documento', async () => {
  const db = new FakeD1Database();
  const created = (await (
    await putMaterialKindPrefs(fakeDb(db), claims, putRequest({}))
  ).json()) as MaterialKindPrefsJson;
  assert.deepEqual(created, {
    kindIds: ['k1', 'k2'],
    updatedAt: '2026-09-02T10:00:00.000Z',
    version: 1,
  });

  const fetched = (await (
    await getMaterialKindPrefs(fakeDb(db), claims)
  ).json()) as MaterialKindPrefsJson;
  assert.deepEqual(fetched, created);
});

test('PUT mais novo sobrescreve e incrementa version', async () => {
  const db = new FakeD1Database();
  await putMaterialKindPrefs(fakeDb(db), claims, putRequest({}));
  const updated = (await (
    await putMaterialKindPrefs(
      fakeDb(db),
      claims,
      putRequest({ kindIds: ['k9'], updatedAt: '2026-09-03T10:00:00.000Z' }),
    )
  ).json()) as MaterialKindPrefsJson;
  assert.deepEqual(updated, {
    kindIds: ['k9'],
    updatedAt: '2026-09-03T10:00:00.000Z',
    version: 2,
  });
});

test('PUT mais velho devolve 409 com o documento remoto', async () => {
  const db = new FakeD1Database([], {
    materialKindPrefs: [
      {
        user_id: 'u1',
        kind_ids: '["remoto"]',
        updated_at: '2026-09-05T10:00:00.000Z',
        version: 3,
      },
    ],
  });
  const response = await putMaterialKindPrefs(fakeDb(db), claims, putRequest({}));
  assert.equal(response.status, 409);
  const remote = (await response.json()) as MaterialKindPrefsJson;
  assert.deepEqual(remote, {
    kindIds: ['remoto'],
    updatedAt: '2026-09-05T10:00:00.000Z',
    version: 3,
  });
  // Nada foi escrito.
  assert.equal(db.materialKindPrefs.get('u1')?.kind_ids, '["remoto"]');
});

test('PUT mesmo updatedAt (idempotente) grava e devolve version + 1', async () => {
  const db = new FakeD1Database();
  await putMaterialKindPrefs(fakeDb(db), claims, putRequest({}));
  const again = await putMaterialKindPrefs(fakeDb(db), claims, putRequest({}));
  assert.equal(again.status, 200);
  assert.equal(((await again.json()) as MaterialKindPrefsJson).version, 2);
});

test('PUT rejeita 6 ids, duplicata, não-array, id vazio e updatedAt inválido', async () => {
  const db = new FakeD1Database();
  const cases: Array<Record<string, unknown>> = [
    { kindIds: ['1', '2', '3', '4', '5', '6'] },
    { kindIds: ['a', 'a'] },
    { kindIds: 'k1' },
    { kindIds: ['ok', ''] },
    { updatedAt: 'ontem' },
  ];
  for (const body of cases) {
    const response = await putMaterialKindPrefs(fakeDb(db), claims, putRequest(body));
    assert.equal(response.status, 400, JSON.stringify(body));
  }
  assert.equal(db.materialKindPrefs.size, 0);
});

test('PUT com JSON inválido devolve 400', async () => {
  const db = new FakeD1Database();
  const request = new Request('https://example.test/api/material-kind-prefs', {
    method: 'PUT',
    body: '{nope',
  });
  const response = await putMaterialKindPrefs(fakeDb(db), claims, request);
  assert.equal(response.status, 400);
});

test('lista vazia é aceita — "sem favoritos" não é tombstone', async () => {
  const db = new FakeD1Database();
  const response = await putMaterialKindPrefs(
    fakeDb(db),
    claims,
    putRequest({ kindIds: [] }),
  );
  assert.equal(response.status, 200);
  assert.deepEqual(((await response.json()) as MaterialKindPrefsJson).kindIds, []);
});

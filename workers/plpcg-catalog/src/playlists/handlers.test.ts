import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { FakeD1Database, fakeDb, playlistRow } from '../test/fake_d1.ts';
import { getPlaylist, listPlaylists, upsertPlaylist } from './handlers.ts';
import type { PlaylistItem } from './items.ts';

const claims = { sub: 'u1', email: 'a@b.c' } as never;

interface BodyOverrides {
  [key: string]: unknown;
}

function putRequest(body: BodyOverrides): Request {
  return new Request('https://example.test/api/playlists/p1', {
    method: 'PUT',
    body: JSON.stringify({
      id: 'p1',
      nome: 'Ensaio',
      createdAt: '2026-09-01T10:00:00.000Z',
      updatedAt: '2026-09-02T10:00:00.000Z',
      version: 1,
      ...body,
    }),
  });
}

async function put(
  db: FakeD1Database,
  body: BodyOverrides,
): Promise<{ status: number; json: Record<string, unknown> }> {
  const response = await upsertPlaylist(
    fakeDb(db),
    claims,
    'p1',
    putRequest(body),
  );
  return {
    status: response.status,
    json: (await response.json()) as Record<string, unknown>,
  };
}

const v2Items: PlaylistItem[] = [
  { id: 'p-a', kind: 'pdf' },
  { id: 'a-a', kind: 'audio' },
  { id: 'c-a', kind: 'chord' },
];

test('PUT v2 novo grava items e deriva as duas listas', async () => {
  const db = new FakeD1Database();

  const { status, json } = await put(db, { schemaVersion: 2, items: v2Items });

  assert.equal(status, 200);
  assert.deepEqual(json.items, v2Items);
  assert.equal(json.schemaVersion, 2);
  // As listas do body seriam ignoradas; aqui nem vieram — são derivadas.
  assert.deepEqual(json.pdfIds, ['p-a', 'c-a']);
  assert.deepEqual(json.audioIds, ['a-a']);

  const row = db.get('u1', 'p1');
  assert.equal(row?.items, JSON.stringify(v2Items));
  assert.equal(row?.pdf_ids, JSON.stringify(['p-a', 'c-a']));
  assert.equal(row?.audio_ids, JSON.stringify(['a-a']));
  assert.equal(row?.version, 1);
});

test('PUT v2 aceita body sem pdfIds — items basta', async () => {
  const db = new FakeD1Database();

  const { status } = await put(db, { items: v2Items });

  assert.equal(status, 200);
  assert.deepEqual(db.get('u1', 'p1')?.items, JSON.stringify(v2Items));
});

test('items manda sobre as listas do body', async () => {
  const db = new FakeD1Database();

  const { json } = await put(db, {
    items: v2Items,
    // Listas em desacordo de propósito: devem ser recalculadas de `items`.
    pdfIds: ['lixo'],
    audioIds: ['lixo-audio'],
  });

  assert.deepEqual(json.pdfIds, ['p-a', 'c-a']);
  assert.deepEqual(json.audioIds, ['a-a']);
  assert.deepEqual(db.get('u1', 'p1')?.pdf_ids, JSON.stringify(['p-a', 'c-a']));
});

test('PUT v1 sem items deriva items com kinds pdf/audio', async () => {
  const db = new FakeD1Database();

  const { status, json } = await put(db, {
    pdfIds: ['p-a', 'c-a'],
    audioIds: ['a-a'],
  });

  assert.equal(status, 200);
  assert.deepEqual(json.items, [
    { id: 'p-a', kind: 'pdf' },
    { id: 'c-a', kind: 'pdf' },
    { id: 'a-a', kind: 'audio' },
  ]);
  assert.deepEqual(json.pdfIds, ['p-a', 'c-a']);
  assert.deepEqual(json.audioIds, ['a-a']);
});

test('PUT v1 sem audioIds trata a lista como vazia', async () => {
  const db = new FakeD1Database();

  const { json } = await put(db, { pdfIds: ['p-a'] });

  assert.deepEqual(json.items, [{ id: 'p-a', kind: 'pdf' }]);
  assert.deepEqual(json.audioIds, []);
});

test('PUT v2 sobre linha existente atualiza items e sobe version', async () => {
  const db = new FakeD1Database().seed(
    playlistRow({
      items: JSON.stringify([{ id: 'velho', kind: 'pdf' }]),
      pdf_ids: JSON.stringify(['velho']),
      version: 4,
    }),
  );

  const { status, json } = await put(db, { items: v2Items });

  assert.equal(status, 200);
  assert.equal(json.version, 5);
  assert.deepEqual(json.items, v2Items);
  assert.equal(db.get('u1', 'p1')?.items, JSON.stringify(v2Items));
});

test('GET devolve schemaVersion 2 e os items gravados', async () => {
  const db = new FakeD1Database().seed(
    playlistRow({
      items: JSON.stringify(v2Items),
      pdf_ids: JSON.stringify(['p-a', 'c-a']),
      audio_ids: JSON.stringify(['a-a']),
    }),
  );

  const response = await getPlaylist(fakeDb(db), claims, 'p1');
  const json = (await response.json()) as Record<string, unknown>;

  assert.equal(response.status, 200);
  assert.equal(json.schemaVersion, 2);
  assert.deepEqual(json.items, v2Items);
  assert.deepEqual(json.pdfIds, ['p-a', 'c-a']);
  assert.deepEqual(json.audioIds, ['a-a']);
});

test('GET de linha legada (items vazio) deriva items das listas', async () => {
  const db = new FakeD1Database().seed(
    playlistRow({
      items: '[]',
      pdf_ids: JSON.stringify(['p-a']),
      audio_ids: JSON.stringify(['a-a']),
    }),
  );

  const response = await getPlaylist(fakeDb(db), claims, 'p1');
  const json = (await response.json()) as Record<string, unknown>;

  assert.equal(json.schemaVersion, 2);
  assert.deepEqual(json.items, [
    { id: 'p-a', kind: 'pdf' },
    { id: 'a-a', kind: 'audio' },
  ]);
});

test('GET de linha com items corrompido cai nas listas, sem 500', async () => {
  const db = new FakeD1Database().seed(
    playlistRow({ items: 'garbage', pdf_ids: JSON.stringify(['p-a']) }),
  );

  const response = await getPlaylist(fakeDb(db), claims, 'p1');
  const json = (await response.json()) as Record<string, unknown>;

  assert.equal(response.status, 200);
  assert.deepEqual(json.items, [{ id: 'p-a', kind: 'pdf' }]);
});

test('LIST devolve schemaVersion 2 em cada playlist', async () => {
  const db = new FakeD1Database().seed(
    playlistRow({ items: JSON.stringify(v2Items) }),
  );

  const response = await listPlaylists(fakeDb(db), claims);
  const json = (await response.json()) as Array<Record<string, unknown>>;

  assert.equal(json.length, 1);
  assert.equal(json[0].schemaVersion, 2);
  assert.deepEqual(json[0].items, v2Items);
});

test('items com kind inválido é 400 e não escreve nada', async () => {
  const db = new FakeD1Database();

  const { status, json } = await put(db, {
    items: [{ id: 'p-a', kind: 'video' }],
  });

  assert.equal(status, 400);
  assert.match(String(json.error), /items/);
  assert.equal(db.get('u1', 'p1'), undefined);
});

test('items com id vazio é 400', async () => {
  const db = new FakeD1Database();

  const { status } = await put(db, { items: [{ id: '', kind: 'pdf' }] });

  assert.equal(status, 400);
});

test('items que não é array é 400', async () => {
  const db = new FakeD1Database();

  const { status } = await put(db, { items: 'p-a,a-a' });

  assert.equal(status, 400);
});

test('sem items e sem pdfIds continua 400 (v1 exige pdfIds)', async () => {
  const db = new FakeD1Database();

  const { status, json } = await put(db, {});

  assert.equal(status, 400);
  assert.match(String(json.error), /pdfIds/);
});

test('schemaVersion não-inteiro é 400', async () => {
  const db = new FakeD1Database();

  const { status, json } = await put(db, {
    schemaVersion: '2',
    items: v2Items,
  });

  assert.equal(status, 400);
  assert.match(String(json.error), /schemaVersion/);
});

test('schemaVersion 0 é 400', async () => {
  const db = new FakeD1Database();

  const { status } = await put(db, { schemaVersion: 0, items: v2Items });

  assert.equal(status, 400);
});

test('conflito de updatedAt continua 409 com o corpo atual em v2', async () => {
  const db = new FakeD1Database().seed(
    playlistRow({
      items: JSON.stringify([{ id: 'servidor', kind: 'audio' }]),
      audio_ids: JSON.stringify(['servidor']),
      updated_at: '2026-09-10T10:00:00.000Z',
      version: 9,
    }),
  );

  const { status, json } = await put(db, {
    items: v2Items,
    updatedAt: '2026-09-02T10:00:00.000Z',
  });

  assert.equal(status, 409);
  assert.equal(json.schemaVersion, 2);
  assert.deepEqual(json.items, [{ id: 'servidor', kind: 'audio' }]);
  // A linha não pode ter sido tocada.
  assert.equal(db.get('u1', 'p1')?.version, 9);
});

test('resurrect de tombstone regrava items e limpa deleted_at', async () => {
  const db = new FakeD1Database().seed(
    playlistRow({
      items: JSON.stringify([{ id: 'velho', kind: 'pdf' }]),
      deleted_at: '2026-09-01T12:00:00.000Z',
      version: 2,
    }),
  );

  const { status, json } = await put(db, { items: v2Items });

  assert.equal(status, 200);
  assert.equal(json.version, 3);
  assert.deepEqual(json.items, v2Items);
  const row = db.get('u1', 'p1');
  assert.equal(row?.deleted_at, null);
  assert.equal(row?.items, JSON.stringify(v2Items));
});

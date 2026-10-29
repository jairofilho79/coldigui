import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { FakeD1Database, fakeDb, playlistRow } from '../test/fake_d1.ts';
import { listPublicPlaylistsByUsername } from './handlers.ts';

const users = [{ google_sub: 'sub-a', username: 'maria' }];

test('listPublicPlaylistsByUsername responde v2 com items e mantém pdfIds/audioIds', async () => {
  const db = new FakeD1Database(
    [
      playlistRow({
        id: 'pub',
        user_id: 'sub-a',
        is_published: 1,
        published_at: '2026-09-01T00:00:00.000Z',
        items: JSON.stringify([
          { id: 'p1.pdf', kind: 'pdf' },
          { id: 'a1.mp3', kind: 'audio' },
          { id: 'c1.chord', kind: 'chord' },
        ]),
        pdf_ids: JSON.stringify(['p1.pdf', 'c1.chord']),
        audio_ids: JSON.stringify(['a1.mp3']),
      }),
      playlistRow({ id: 'rascunho', user_id: 'sub-a', is_published: 0 }),
      playlistRow({
        id: 'apagada',
        user_id: 'sub-a',
        is_published: 1,
        deleted_at: '2026-09-02T00:00:00.000Z',
      }),
    ],
    { users },
  );

  const body = (await (
    await listPublicPlaylistsByUsername(fakeDb(db), 'maria')
  ).json()) as Array<Record<string, unknown>>;

  assert.equal(body.length, 1);
  assert.equal(body[0].id, 'pub');
  assert.equal(body[0].schemaVersion, 2);
  assert.deepEqual(body[0].items, [
    { id: 'p1.pdf', kind: 'pdf' },
    { id: 'a1.mp3', kind: 'audio' },
    { id: 'c1.chord', kind: 'chord' },
  ]);
  assert.deepEqual(body[0].pdfIds, ['p1.pdf', 'c1.chord']);
  assert.deepEqual(body[0].audioIds, ['a1.mp3']);
  assert.equal(body[0].publishedAt, '2026-09-01T00:00:00.000Z');
});

test('linha legada sem items deriva a ordem das duas listas', async () => {
  const db = new FakeD1Database(
    [
      playlistRow({
        id: 'legada',
        user_id: 'sub-a',
        is_published: 1,
        published_at: '2026-09-01T00:00:00.000Z',
        items: '[]',
        pdf_ids: JSON.stringify(['p1.pdf', 'c1.chord']),
        audio_ids: JSON.stringify(['a1.mp3']),
      }),
    ],
    { users },
  );

  const body = (await (
    await listPublicPlaylistsByUsername(fakeDb(db), 'maria')
  ).json()) as Array<Record<string, unknown>>;

  assert.equal(body.length, 1);
  assert.equal(body[0].schemaVersion, 2);
  // `itemsFromLegacy`: os `pdfIds` (kind `pdf`) e depois os `audioIds`.
  assert.deepEqual(body[0].items, [
    { id: 'p1.pdf', kind: 'pdf' },
    { id: 'c1.chord', kind: 'pdf' },
    { id: 'a1.mp3', kind: 'audio' },
  ]);
  assert.deepEqual(body[0].pdfIds, ['p1.pdf', 'c1.chord']);
  assert.deepEqual(body[0].audioIds, ['a1.mp3']);
});

test('username desconhecido → 404', async () => {
  const db = new FakeD1Database([], { users });

  const response = await listPublicPlaylistsByUsername(fakeDb(db), 'joao');

  assert.equal(response.status, 404);
  assert.deepEqual(await response.json(), { error: 'not found' });
});

import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { audioFlagRow, FakeD1Database, fakeDb } from '../test/fake_d1.ts';
import {
  listAudioFlags,
  softDeleteAudioFlag,
  upsertAudioFlag,
  type AudioFlagJson,
} from './handlers.ts';

const claims = { sub: 'u1', email: 'a@b.c' } as never;

function putRequest(body: Record<string, unknown>): Request {
  return new Request('https://example.test/api/audio-flags/f1', {
    method: 'PUT',
    body: JSON.stringify({
      id: 'f1',
      audioId: 'a1.mp3',
      positionMs: 1000,
      label: 'refrão',
      createdAt: '2026-09-01T10:00:00.000Z',
      updatedAt: '2026-09-02T10:00:00.000Z',
      version: 1,
      ...body,
    }),
  });
}

test('listAudioFlags omite tombstones por padrão e os inclui com includeDeleted', async () => {
  const db = new FakeD1Database([], {
    audioFlags: [
      audioFlagRow({ id: 'viva' }),
      audioFlagRow({
        id: 'morta',
        deleted_at: '2026-09-01T00:00:00.000Z',
        updated_at: '2026-09-01T00:00:00.000Z',
      }),
    ],
  });

  const plain = (await (
    await listAudioFlags(fakeDb(db), claims)
  ).json()) as AudioFlagJson[];
  assert.deepEqual(
    plain.map((f) => f.id),
    ['viva'],
  );
  assert.equal(plain[0].deletedAt, null);

  const all = (await (
    await listAudioFlags(fakeDb(db), claims, { includeDeleted: true })
  ).json()) as AudioFlagJson[];
  assert.deepEqual(
    all.map((f) => f.id).sort(),
    ['morta', 'viva'],
  );
  assert.equal(
    all.find((f) => f.id === 'morta')?.deletedAt,
    '2026-09-01T00:00:00.000Z',
  );
});

test('PUT de marcador devolve deletedAt null na criação e ao ressuscitar', async () => {
  const db = new FakeD1Database();

  const created = (await (
    await upsertAudioFlag(fakeDb(db), claims, 'f1', putRequest({}))
  ).json()) as AudioFlagJson;
  assert.equal(created.deletedAt, null);
  assert.equal(created.version, 1);

  await softDeleteAudioFlag(fakeDb(db), claims, 'f1');

  const resurrected = (await (
    await upsertAudioFlag(fakeDb(db), claims, 'f1', putRequest({}))
  ).json()) as AudioFlagJson;
  assert.equal(resurrected.deletedAt, null);
});

test('409 de marcador devolve a linha remota com deletedAt', async () => {
  const db = new FakeD1Database([], {
    audioFlags: [
      audioFlagRow({ id: 'f1', updated_at: '2026-09-03T10:00:00.000Z' }),
    ],
  });

  const response = await upsertAudioFlag(
    fakeDb(db),
    claims,
    'f1',
    putRequest({ updatedAt: '2026-09-02T10:00:00.000Z' }),
  );
  const json = (await response.json()) as AudioFlagJson;

  assert.equal(response.status, 409);
  assert.equal(json.updatedAt, '2026-09-03T10:00:00.000Z');
  assert.equal(json.deletedAt, null);
});

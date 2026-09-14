import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { FakeD1Database } from '../test/fake_d1.ts';
import type { LiveRoomNamespace } from './handlers.ts';
import { ensureLiveRoom, liveRoomRedirect, liveRoomUrl, regenerateLiveRoom } from './handlers.ts';

const claims = { sub: 'u1' } as never;

/** Namespace falso: grava cada `fetch` por nome de sala. */
function fakeLive() {
  const calls: Array<{ name: string; url: string; body: unknown }> = [];
  const live: LiveRoomNamespace = {
    idFromName: (name) => ({ name }),
    get: (id) => ({
      fetch: async (url, init) => {
        const body = init?.body ? JSON.parse(init.body as string) : null;
        calls.push({ name: (id as { name: string }).name, url, body });
        return new Response(null, { status: 204 });
      },
    }),
  };
  return { live, calls };
}

test('ensureLiveRoom cria a sala uma vez, inicializa o DO com o nome do dono e devolve a mesma sala depois', async () => {
  const db = new FakeD1Database([], { users: [{ google_sub: 'u1', username: 'fulano', name: 'Fulano Silva' }] });
  const { live, calls } = fakeLive();

  const first = await ensureLiveRoom(db as never, live, claims);
  assert.equal(first.status, 200);
  const json = (await first.json()) as { code: string; url: string; ownerName: string };
  assert.match(json.code, /^[a-z0-9]{7}$/);
  assert.equal(json.url, liveRoomUrl(json.code));
  assert.equal(json.ownerName, 'Fulano Silva');
  assert.deepEqual(calls[0], { name: json.code, url: 'https://live/init', body: { code: json.code, ownerSub: 'u1', ownerName: 'Fulano Silva' } });

  const second = await ensureLiveRoom(db as never, live, claims);
  const again = (await second.json()) as { code: string };
  assert.equal(again.code, json.code);
  assert.equal(db.liveRooms.size, 1);
  // Re-init idempotente: mantém o nome fresco sem criar linha.
  assert.equal(calls.length, 2);
});

test('ownerName cai para username e depois para «Gestor»', async () => {
  const { live } = fakeLive();
  const withUsername = new FakeD1Database([], { users: [{ google_sub: 'u1', username: 'fulano' }] });
  assert.equal(((await (await ensureLiveRoom(withUsername as never, live, claims)).json()) as { ownerName: string }).ownerName, 'fulano');
  const unknown = new FakeD1Database();
  assert.equal(((await (await ensureLiveRoom(unknown as never, live, claims)).json()) as { ownerName: string }).ownerName, 'Gestor');
});

test('regenerateLiveRoom troca o código, aposenta o DO antigo e inicializa o novo', async () => {
  const db = new FakeD1Database([], {
    users: [{ google_sub: 'u1', username: 'fulano', name: 'Fulano' }],
    liveRooms: [{ code: 'aaaaaaa', owner_sub: 'u1', created_at: '2026-09-14T00:00:00.000Z' }],
  });
  const { live, calls } = fakeLive();
  const response = await regenerateLiveRoom(db as never, live, claims);
  assert.equal(response.status, 200);
  const json = (await response.json()) as { code: string };
  assert.notEqual(json.code, 'aaaaaaa');
  assert.equal(db.liveRooms.has('aaaaaaa'), false);
  assert.equal(db.liveRooms.get(json.code)?.owner_sub, 'u1');
  assert.deepEqual(calls.map((c) => [c.name, c.url]), [['aaaaaaa', 'https://live/retire'], [json.code, 'https://live/init']]);
});

/**
 * Faz o *primeiro* `UPDATE live_rooms` (o `RETURNING code` da regeneração)
 * lançar, como o D1 real faz na colisão de `PRIMARY KEY` — os demais SQLs, e
 * os `UPDATE live_rooms` seguintes, seguem para o `FakeD1Database` normal.
 * Mesmo padrão do `RacingFakeD1Database` em `links/handlers.test.ts`.
 */
class UpdateCollisionOnceFakeD1Database extends FakeD1Database {
  updateAttempts = 0;

  override runQuery(sql: string, bindings: unknown[]): unknown[] {
    const normalized = sql.replace(/\s+/g, ' ').trim();
    if (/^UPDATE live_rooms/i.test(normalized)) {
      this.updateAttempts++;
      if (this.updateAttempts === 1) {
        throw new Error('fake D1: UNIQUE constraint failed: live_rooms.code');
      }
    }
    return super.runQuery(sql, bindings);
  }
}

test('regenerateLiveRoom tenta de novo quando o novo código colide (UNIQUE em live_rooms.code)', async () => {
  const db = new UpdateCollisionOnceFakeD1Database([], {
    users: [{ google_sub: 'u1', username: 'fulano' }],
    liveRooms: [{ code: 'aaaaaaa', owner_sub: 'u1', created_at: '2026-09-14T00:00:00.000Z' }],
  });
  const { live, calls } = fakeLive();
  const response = await regenerateLiveRoom(db as never, live, claims);
  assert.equal(response.status, 200);
  const json = (await response.json()) as { code: string };
  assert.notEqual(json.code, 'aaaaaaa');
  assert.equal(db.updateAttempts, 2);
  assert.equal(db.liveRooms.size, 1);
  assert.equal(db.liveRooms.get(json.code)?.owner_sub, 'u1');
  assert.deepEqual(calls.map((c) => [c.name, c.url]), [['aaaaaaa', 'https://live/retire'], [json.code, 'https://live/init']]);
});

test('regenerateLiveRoom sem sala existente cria uma (equivale a ensure)', async () => {
  const db = new FakeD1Database([], { users: [{ google_sub: 'u1', username: 'fulano' }] });
  const { live, calls } = fakeLive();
  const response = await regenerateLiveRoom(db as never, live, claims);
  assert.equal(response.status, 200);
  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, 'https://live/init');
});

test('liveRoomRedirect: 302 para a raiz com ?live=, 404 fora do formato', () => {
  const ok = liveRoomRedirect('/ao-vivo/k7x2m9q');
  assert.equal(ok.status, 302);
  assert.equal(ok.headers.get('Location'), 'https://plpcg.com/?live=k7x2m9q');
  assert.equal(ok.headers.get('Cache-Control'), 'no-store');
  assert.equal(liveRoomRedirect('/ao-vivo/K7X2M9Q').status, 404);
  assert.equal(liveRoomRedirect('/ao-vivo/').status, 404);
  assert.equal(liveRoomRedirect('/ao-vivo/k7x2m9q/extra').status, 404);
});

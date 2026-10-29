import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { FakeD1Database, fakeDb } from '../test/fake_d1.ts';
import { handleIntrospect } from './introspect.ts';
import { hashSessionToken } from './session_token.ts';

const NOW = new Date('2026-09-17T12:00:00Z');

async function dbWithSession(token: string, opts: { expired?: boolean } = {}) {
  const db = new FakeD1Database([], {
    users: [{ google_sub: 'u1', username: 'ana', name: 'Ana', email: 'ana@b.c' }],
    sessions: [
      {
        token_hash: await hashSessionToken(token),
        google_sub: 'u1',
        created_at: '2026-09-01T00:00:00Z',
        last_seen_at: '2026-09-01T00:00:00Z',
        expires_at: opts.expired ? '2026-09-02T00:00:00Z' : '2026-11-01T00:00:00Z',
      },
    ],
  });
  return db;
}

function request(bearer?: string): Request {
  return new Request('https://example.test/api/auth/introspect', {
    headers: bearer ? { Authorization: `Bearer ${bearer}` } : {},
  });
}

test('sessão válida devolve userId, email, name, username e não renova a sessão', async () => {
  const db = await dbWithSession('sess_abc');
  const res = await handleIntrospect(fakeDb(db), request('sess_abc'), NOW);
  assert.equal(res.status, 200);
  assert.equal(res.headers.get('Cache-Control'), 'no-store');
  assert.deepEqual(await res.json(), {
    userId: 'u1',
    email: 'ana@b.c',
    name: 'Ana',
    username: 'ana',
  });
  // Introspecção não é uso do usuário: nada de UPDATE em user_sessions.
  assert.ok(!db.executed.some((sql) => /UPDATE user_sessions/i.test(sql)));
});

test('sessão expirada → 401', async () => {
  const db = await dbWithSession('sess_abc', { expired: true });
  const res = await handleIntrospect(fakeDb(db), request('sess_abc'), NOW);
  assert.equal(res.status, 401);
});

test('JWT (não sess_) → 401 sem consultar o banco', async () => {
  const db = await dbWithSession('sess_abc');
  const res = await handleIntrospect(fakeDb(db), request('eyJhbGciOi.jwt.token'), NOW);
  assert.equal(res.status, 401);
  assert.equal(db.executed.length, 0);
});

test('sem Bearer → 401', async () => {
  const db = await dbWithSession('sess_abc');
  const res = await handleIntrospect(fakeDb(db), request(), NOW);
  assert.equal(res.status, 401);
});

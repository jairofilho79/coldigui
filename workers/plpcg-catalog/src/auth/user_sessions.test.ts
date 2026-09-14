import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { FakeD1Database, fakeDb } from '../test/fake_d1.ts';
import { SESSION_TTL_MS, hashSessionToken } from './session_token.ts';
import { createSession, findSession, revokeSession } from './user_sessions.ts';

const t0 = new Date('2026-09-13T12:00:00.000Z');
const plus = (ms: number) => new Date(t0.getTime() + ms);
const HOUR = 60 * 60 * 1000;

test('createSession grava só o hash e devolve o token cru', async () => {
  const db = new FakeD1Database();
  const token = await createSession(fakeDb(db), 'u1', t0);
  assert.ok(token.startsWith('sess_'));
  const row = db.sessions.get(await hashSessionToken(token));
  assert.ok(row);
  assert.equal(row.google_sub, 'u1');
  assert.equal(row.created_at, t0.toISOString());
  assert.equal(row.last_seen_at, t0.toISOString());
  assert.equal(row.expires_at, plus(SESSION_TTL_MS).toISOString());
  assert.ok(![...db.sessions.keys()].includes(token));
});

test('findSession devolve o sub de uma sessão válida', async () => {
  const db = new FakeD1Database();
  const token = await createSession(fakeDb(db), 'u1', t0);
  assert.deepEqual(await findSession(fakeDb(db), token, plus(HOUR / 2)), { sub: 'u1' });
});

test('findSession recusa desconhecida e vencida', async () => {
  const db = new FakeD1Database();
  const token = await createSession(fakeDb(db), 'u1', t0);
  assert.equal(await findSession(fakeDb(db), 'sess_nunca', t0), null);
  assert.equal(await findSession(fakeDb(db), token, plus(SESSION_TTL_MS + 1)), null);
});

test('findSession só renova depois de 1 h (deslizante)', async () => {
  const db = new FakeD1Database();
  const token = await createSession(fakeDb(db), 'u1', t0);
  const hash = await hashSessionToken(token);

  await findSession(fakeDb(db), token, plus(HOUR - 1));
  assert.equal(db.sessions.get(hash)!.last_seen_at, t0.toISOString());

  const later = plus(HOUR + 1);
  await findSession(fakeDb(db), token, later);
  assert.equal(db.sessions.get(hash)!.last_seen_at, later.toISOString());
  assert.equal(
    db.sessions.get(hash)!.expires_at,
    new Date(later.getTime() + SESSION_TTL_MS).toISOString(),
  );
});

test('revokeSession faz o próximo find devolver null e é idempotente', async () => {
  const db = new FakeD1Database();
  const token = await createSession(fakeDb(db), 'u1', t0);
  await revokeSession(fakeDb(db), token);
  assert.equal(await findSession(fakeDb(db), token, t0), null);
  await revokeSession(fakeDb(db), token); // não lança
});

test('createSession purga as vencidas', async () => {
  const db = new FakeD1Database();
  const old = await createSession(fakeDb(db), 'u1', t0);
  await createSession(fakeDb(db), 'u2', plus(SESSION_TTL_MS + 1));
  assert.equal(db.sessions.has(await hashSessionToken(old)), false);
  assert.equal(db.sessions.size, 1);
});

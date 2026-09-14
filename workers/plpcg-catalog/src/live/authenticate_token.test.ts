import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { createSession } from '../auth/user_sessions.ts';
import { FakeD1Database, fakeDb } from '../test/fake_d1.ts';
import { authenticateToken } from './authenticate_token.ts';

test('sess_ existente devolve o sub', async () => {
  const db = new FakeD1Database();
  const token = await createSession(fakeDb(db), 'owner');
  assert.equal(await authenticateToken({ DB: fakeDb(db), GOOGLE_CLIENT_ID_WEB: '' }, token), 'owner');
});

test('sess_ desconhecido devolve null', async () => {
  const db = new FakeD1Database();
  assert.equal(await authenticateToken({ DB: fakeDb(db), GOOGLE_CLIENT_ID_WEB: '' }, 'sess_nunca'), null);
});

test('D1 que rebenta no prepare devolve null em vez de lançar', async () => {
  const broken = { prepare: () => { throw new Error('D1 indisponível'); } } as unknown as D1Database;
  assert.equal(await authenticateToken({ DB: broken, GOOGLE_CLIENT_ID_WEB: '' }, 'sess_qualquer'), null);
});

test('token que não é sess_ com GOOGLE_CLIENT_ID_WEB vazio devolve null sem verificar', async () => {
  const db = new FakeD1Database();
  assert.equal(await authenticateToken({ DB: fakeDb(db), GOOGLE_CLIENT_ID_WEB: '' }, 'eyJhbGciOi.jwt.falso'), null);
});

import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { FakeD1Database, fakeDb } from '../test/fake_d1.ts';
import type { SessionUserJson } from './session.ts';
import { handleDeleteSession, sessionResponse } from './session_handlers.ts';
import { hashSessionToken } from './session_token.ts';
import { findSession } from './user_sessions.ts';

const user: SessionUserJson = {
  googleSub: 'u1',
  email: 'a@b.c',
  name: 'Ana',
  pictureUrl: null,
  username: 'ana',
};

function deleteRequest(bearer?: string): Request {
  return new Request('https://example.test/api/auth/session', {
    method: 'DELETE',
    headers: bearer ? { Authorization: `Bearer ${bearer}` } : {},
  });
}

test('sessionResponse devolve o perfil + sessionToken e grava o hash', async () => {
  const db = new FakeD1Database();
  const response = await sessionResponse(fakeDb(db), user);
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('Cache-Control'), 'no-store');
  const body = (await response.json()) as SessionUserJson & { sessionToken: string };
  assert.equal(body.googleSub, 'u1');
  assert.equal(body.username, 'ana');
  assert.ok(body.sessionToken.startsWith('sess_'));
  assert.ok(db.sessions.has(await hashSessionToken(body.sessionToken)));
});

test('DELETE com sessão válida revoga e devolve 204', async () => {
  const db = new FakeD1Database();
  const { sessionToken } = (await (await sessionResponse(fakeDb(db), user)).json()) as {
    sessionToken: string;
  };
  const response = await handleDeleteSession(fakeDb(db), deleteRequest(sessionToken));
  assert.equal(response.status, 204);
  assert.equal(await findSession(fakeDb(db), sessionToken), null);
});

test('DELETE de sessão desconhecida é 204 (idempotente)', async () => {
  const db = new FakeD1Database();
  const response = await handleDeleteSession(fakeDb(db), deleteRequest('sess_nunca'));
  assert.equal(response.status, 204);
});

test('DELETE sem Bearer ou com Bearer que não é sessão → 401', async () => {
  const db = new FakeD1Database();
  assert.equal((await handleDeleteSession(fakeDb(db), deleteRequest())).status, 401);
  assert.equal(
    (await handleDeleteSession(fakeDb(db), deleteRequest('eyJ.jwt.x'))).status,
    401,
  );
});

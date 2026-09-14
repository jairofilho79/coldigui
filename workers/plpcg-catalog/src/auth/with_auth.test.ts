import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { FakeD1Database, fakeDb } from '../test/fake_d1.ts';
import { createSession, revokeSession } from './user_sessions.ts';
import { withAuth } from './with_auth.ts';

function env(db: FakeD1Database) {
  return { DB: fakeDb(db), GOOGLE_CLIENT_ID_WEB: 'cid' };
}

function request(bearer?: string): Request {
  return new Request('https://example.test/api/playlists', {
    headers: bearer ? { Authorization: `Bearer ${bearer}` } : {},
  });
}

test('sessão válida chama o handler com { sub }', async () => {
  const db = new FakeD1Database();
  const token = await createSession(fakeDb(db), 'u1');
  let seen: unknown;
  const response = await withAuth(request(token), env(db), async (_r, _e, claims) => {
    seen = claims;
    return new Response('ok');
  });
  assert.equal(response.status, 200);
  assert.deepEqual(seen, { sub: 'u1' });
});

test('sessão válida é aceita mesmo sem GOOGLE_CLIENT_ID_WEB', async () => {
  // Fixa a ordem de que a spec depende: o ramo de sessão (D5) roda antes da
  // checagem do client id, então uma sessão do Worker continua valendo
  // mesmo se a env perder a config do login (que só o JWT do Google usa).
  const db = new FakeD1Database();
  const token = await createSession(fakeDb(db), 'u1');
  let seen: unknown;
  const response = await withAuth(
    request(token),
    { DB: fakeDb(db), GOOGLE_CLIENT_ID_WEB: '' },
    async (_r, _e, claims) => {
      seen = claims;
      return new Response('ok');
    },
  );
  assert.equal(response.status, 200);
  assert.deepEqual(seen, { sub: 'u1' });
});

test('sessão revogada/desconhecida → 401 sem chamar o handler', async () => {
  const db = new FakeD1Database();
  const token = await createSession(fakeDb(db), 'u1');
  await revokeSession(fakeDb(db), token);
  let called = false;
  const response = await withAuth(request(token), env(db), async () => {
    called = true;
    return new Response('ok');
  });
  assert.equal(response.status, 401);
  assert.equal(called, false);
});

test('sem Authorization → 401', async () => {
  const db = new FakeD1Database();
  const response = await withAuth(request(), env(db), async () => new Response('ok'));
  assert.equal(response.status, 401);
});

test('Bearer que não é sessão segue pelo JWT e um JWT inválido dá 401', async () => {
  // `jwtVerify` rejeita um token malformado antes de buscar o JWKS — roda
  // offline. É o caminho antigo, mantido para a POST /session e para o app em
  // cache durante o rollout (spec D5).
  const db = new FakeD1Database();
  const response = await withAuth(request('nao-e-jwt'), env(db), async () => new Response('ok'));
  assert.equal(response.status, 401);
});

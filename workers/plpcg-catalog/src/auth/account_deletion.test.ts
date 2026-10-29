import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import {
  FakeD1Database,
  audioFlagRow,
  fakeDb,
  playlistRow,
  shortLinkRow,
} from '../test/fake_d1.ts';
import {
  deleteUserAccount,
  handleDeleteAccount,
} from './account_deletion.ts';
import { generateSessionToken, hashSessionToken } from './session_token.ts';
import { createSession, findSession } from './user_sessions.ts';

function deleteRequest(
  url = 'https://example.test/api/auth/account',
  bearer?: string,
  extraHeaders: Record<string, string> = {},
): Request {
  const headers = new Headers(extraHeaders);
  if (bearer !== undefined) {
    headers.set('Authorization', `Bearer ${bearer}`);
  }
  return new Request(url, {
    method: 'DELETE',
    headers,
  });
}

function env(db: FakeD1Database) {
  return {
    DB: fakeDb(db),
    GOOGLE_CLIENT_ID_WEB: 'test-google-client-id',
    LIVE: {} as never,
  };
}

test('DELETE /api/auth/account com sessão válida remove todos os dados do usuário nas 7 tabelas e retorna 204', async () => {
  const db = new FakeD1Database();

  // 1. user_playlists
  db.seed(playlistRow({ id: 'p1', user_id: 'u1', nome: 'Lista U1' }));
  db.seed(playlistRow({ id: 'p2', user_id: 'u2', nome: 'Lista U2' }));

  // 2. user_audio_flags
  db.seedAudioFlag(audioFlagRow({ id: 'af1', user_id: 'u1', audio_id: 'a1.mp3' }));
  db.seedAudioFlag(audioFlagRow({ id: 'af2', user_id: 'u2', audio_id: 'a2.mp3' }));

  // 3. user_material_kind_prefs
  db.materialKindPrefs.set('u1', {
    user_id: 'u1',
    kind_ids: '["k1"]',
    updated_at: '2026-09-01T00:00:00.000Z',
    version: 1,
  });
  db.materialKindPrefs.set('u2', {
    user_id: 'u2',
    kind_ids: '["k2"]',
    updated_at: '2026-09-01T00:00:00.000Z',
    version: 1,
  });

  // 4. short_links
  db.seedShortLink(shortLinkRow({ code: 'link1', created_by: 'u1' }));
  db.seedShortLink(shortLinkRow({ code: 'link2', created_by: 'u2' }));

  // 5. live_rooms
  db.liveRooms.set('room1', {
    code: 'room1',
    owner_sub: 'u1',
    created_at: '2026-09-01T00:00:00.000Z',
  });
  db.liveRooms.set('room2', {
    code: 'room2',
    owner_sub: 'u2',
    created_at: '2026-09-01T00:00:00.000Z',
  });

  // 6. user_sessions
  const tokenU1 = await createSession(fakeDb(db), 'u1');
  const tokenU2 = await createSession(fakeDb(db), 'u2');

  // 7. users
  db.seedUser({
    google_sub: 'u1',
    username: 'user_one',
    name: 'User One',
    email: 'u1@example.com',
  });
  db.seedUser({
    google_sub: 'u2',
    username: 'user_two',
    name: 'User Two',
    email: 'u2@example.com',
  });

  // Chamada ao handler
  const req = deleteRequest('https://example.test/api/auth/account', tokenU1);
  const response = await handleDeleteAccount(req, env(db));

  assert.equal(response.status, 204);

  // u1: todos os dados apagados
  assert.equal(db.get('u1', 'p1'), undefined);
  assert.equal(db.getAudioFlag('u1', 'af1'), undefined);
  assert.equal(db.materialKindPrefs.has('u1'), false);
  assert.equal(db.getShortLink('link1'), undefined);
  assert.equal(db.liveRooms.has('room1'), false);
  assert.equal(await findSession(fakeDb(db), tokenU1), null);
  assert.equal(db.getUser('u1'), undefined);
  assert.equal(db.usernames.has('u1'), false);
  assert.equal(db.usersByUsername.has('user_one'), false);

  // u2: todos os dados preservados
  assert.ok(db.get('u2', 'p2'));
  assert.ok(db.getAudioFlag('u2', 'af2'));
  assert.equal(db.materialKindPrefs.has('u2'), true);
  assert.ok(db.getShortLink('link2'));
  assert.equal(db.liveRooms.has('room2'), true);
  assert.ok(await findSession(fakeDb(db), tokenU2));
  assert.ok(db.getUser('u2'));
  assert.equal(db.usernames.get('u2'), 'user_two');
  assert.equal(db.usersByUsername.get('user_two'), 'u2');
});

test('handleDeleteAccount(db, claims) apaga diretamente registros do usuário', async () => {
  const db = new FakeD1Database();
  db.seed(playlistRow({ id: 'p1', user_id: 'u1' }));
  db.seedUser({ google_sub: 'u1', username: 'u1' });

  const response = await handleDeleteAccount(fakeDb(db), { sub: 'u1' });
  assert.equal(response.status, 204);
  assert.equal(db.get('u1', 'p1'), undefined);
  assert.equal(db.getUser('u1'), undefined);
});

test('DELETE /api/auth/account sem Bearer token retorna 401', async () => {
  const db = new FakeD1Database();
  const req = deleteRequest('https://example.test/api/auth/account');
  const response = await handleDeleteAccount(req, env(db));

  assert.equal(response.status, 401);
  const body = (await response.json()) as { error: string };
  assert.equal(body.error, 'unauthorized');
});

test('DELETE /api/auth/account com Bearer token inválido retorna 401', async () => {
  const db = new FakeD1Database();

  // Token sess_ inexistente
  const reqUnknownSession = deleteRequest(
    'https://example.test/api/auth/account',
    'sess_0000000000000000000000000000000000000000000000000000000000000000',
  );
  const resp1 = await handleDeleteAccount(reqUnknownSession, env(db));
  assert.equal(resp1.status, 401);

  // Token arbitrário que não é sessão nem JWT válido
  const reqArbitrary = deleteRequest(
    'https://example.test/api/auth/account',
    'token-invalido',
  );
  const resp2 = await handleDeleteAccount(reqArbitrary, env(db));
  assert.equal(resp2.status, 401);
});

test('DELETE /api/auth/account com sessão expirada retorna 401', async () => {
  const db = new FakeD1Database();
  const expiredToken = generateSessionToken();
  const tokenHash = await hashSessionToken(expiredToken);

  const pastIso = '2020-01-01T00:00:00.000Z';
  db.sessions.set(tokenHash, {
    token_hash: tokenHash,
    google_sub: 'u1',
    created_at: pastIso,
    last_seen_at: pastIso,
    expires_at: pastIso, // Já vencida
  });

  const req = deleteRequest('https://example.test/api/auth/account', expiredToken);
  const response = await handleDeleteAccount(req, env(db));

  assert.equal(response.status, 401);
});

test('DELETE /api/auth/account rejeita métodos não-DELETE com 405', async () => {
  const db = new FakeD1Database();
  const token = await createSession(fakeDb(db), 'u1');

  const getReq = new Request('https://example.test/api/auth/account', {
    method: 'GET',
    headers: { Authorization: `Bearer ${token}` },
  });
  const getResp = await handleDeleteAccount(getReq, env(db));
  assert.equal(getResp.status, 405);

  const postReq = new Request('https://example.test/api/auth/account', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
  });
  const postResp = await handleDeleteAccount(postReq, env(db));
  assert.equal(postResp.status, 405);
});

test('deleteUserAccount apaga dados com fallback sequencial se batch não existir', async () => {
  const db = new FakeD1Database();
  db.seed(playlistRow({ id: 'p1', user_id: 'u1' }));
  db.seedUser({ google_sub: 'u1' });

  // Cria um objeto DB sem .batch para exercitar o ramo sequencial
  const dbWithoutBatch = {
    prepare(sql: string) {
      return db.prepare(sql);
    },
  } as unknown as D1Database;

  await deleteUserAccount(dbWithoutBatch, 'u1');
  assert.equal(db.get('u1', 'p1'), undefined);
  assert.equal(db.getUser('u1'), undefined);
});

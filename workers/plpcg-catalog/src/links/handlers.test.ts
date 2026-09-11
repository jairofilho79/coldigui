import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import {
  FakeD1Database,
  fakeDb,
  shortLinkRow,
  type ShortLinkRow,
} from '../test/fake_d1.ts';
import { ORIGIN, createShortLink, resolveShortLink } from './handlers.ts';

const claims = { sub: 'u1', email: 'a@b.c' } as never;

function postRequest(body: unknown): Request {
  return new Request('https://example.test/api/links', {
    method: 'POST',
    body: JSON.stringify(body),
  });
}

async function post(
  db: FakeD1Database,
  body: unknown,
): Promise<{ status: number; json: Record<string, unknown> }> {
  const response = await createShortLink(fakeDb(db), claims, postRequest(body));
  return {
    status: response.status,
    json: (await response.json()) as Record<string, unknown>,
  };
}

const validQuery = 'shareitems=p%3Aa%2Ca%3Ab&sharename=Ensaio';

test('cria um link novo — 201, código de 7 chars [a-z0-9]', async () => {
  const db = new FakeD1Database();

  const { status, json } = await post(db, { query: validQuery });

  assert.equal(status, 201);
  assert.equal((json.code as string).length, 7);
  assert.match(json.code as string, /^[a-z0-9]{7}$/);
  assert.equal(json.url, `${ORIGIN}/l/${json.code}`);
  assert.equal(db.shortLinks.size, 1);
});

test('mesma query do mesmo usuário devolve o mesmo código — 200, sem duplicar', async () => {
  const db = new FakeD1Database();

  const first = await post(db, { query: validQuery });
  assert.equal(first.status, 201);

  const second = await post(db, { query: validQuery });
  assert.equal(second.status, 200);
  assert.equal(second.json.code, first.json.code);
  assert.equal(db.shortLinks.size, 1);
});

test('query sem shareitems — 400', async () => {
  const db = new FakeD1Database();

  const { status, json } = await post(db, {
    query: 'sharepdfs=a%2Cb&sharename=Ensaio',
  });

  assert.equal(status, 400);
  assert.ok(json.error);
  assert.equal(db.shortLinks.size, 0);
});

test('query ausente ou não-string — 400', async () => {
  const db = new FakeD1Database();

  const { status } = await post(db, {});
  assert.equal(status, 400);
});

test('query maior que 4096 bytes — 400', async () => {
  const db = new FakeD1Database();
  const huge = `shareitems=${'a'.repeat(4096)}`;

  const { status } = await post(db, { query: huge });
  assert.equal(status, 400);
});

test('101ª criação em 24h para o mesmo usuário — 429', async () => {
  const now = Date.now();
  const rows: ShortLinkRow[] = [];
  for (let i = 0; i < 100; i++) {
    rows.push(
      shortLinkRow({
        code: String(i).padStart(7, '0'),
        query: `shareitems=p%3A${i}`,
        created_by: 'u1',
        created_at: now - 1000 * i,
      }),
    );
  }
  const db = new FakeD1Database([], { shortLinks: rows });
  assert.equal(db.shortLinks.size, 100);

  const { status, json } = await post(db, { query: validQuery });

  assert.equal(status, 429);
  assert.ok(json.error);
  assert.equal(db.shortLinks.size, 100);
});

test('teto de abuso é por usuário — outro created_by não conta', async () => {
  const now = Date.now();
  const rows: ShortLinkRow[] = [];
  for (let i = 0; i < 100; i++) {
    rows.push(
      shortLinkRow({
        code: `z${String(i).padStart(6, '0')}`,
        query: `shareitems=p%3A${i}`,
        created_by: 'outro-usuario',
        created_at: now - 1000 * i,
      }),
    );
  }
  const db = new FakeD1Database([], { shortLinks: rows });

  const { status } = await post(db, { query: validQuery });

  assert.equal(status, 201);
});

test('GET /l/<code> redireciona 302 para ORIGIN com a query e incrementa hits', async () => {
  const db = new FakeD1Database([], {
    shortLinks: [
      shortLinkRow({
        code: 'abc1234',
        query: 'shareitems=p%3Aa&sharename=Ensaio',
        created_by: 'u1',
        hits: 0,
      }),
    ],
  });

  const response = await resolveShortLink(fakeDb(db), 'abc1234');

  assert.equal(response.status, 302);
  assert.equal(
    response.headers.get('Location'),
    `${ORIGIN}/?shareitems=p%3Aa&sharename=Ensaio`,
  );
  assert.equal(response.headers.get('Cache-Control'), 'public, max-age=3600');
  assert.equal(db.getShortLink('abc1234')?.hits, 1);
});

test('GET /l/<code> desconhecido — 404', async () => {
  const db = new FakeD1Database();

  const response = await resolveShortLink(fakeDb(db), 'nao-existe');

  assert.equal(response.status, 404);
});

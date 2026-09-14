import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import type { RoomStorage, SocketAttachment, SocketPort } from './room_core.ts';
import {
  ALARM_INTERVAL_MS, CLOSE_ENDED, CLOSE_NOT_FOUND, CLOSE_REPLACED, CLOSE_RETIRED,
  ENDED_TTL_MS, LEADER_TTL_MS, ROOM_KEY, RoomCore,
} from './room_core.ts';
import type { RoomRecord } from './room_core.ts';

class FakeStorage implements RoomStorage {
  readonly map = new Map<string, unknown>();
  alarmAt: number | null = null;
  async get<T>(key: string) { return this.map.get(key) as T | undefined; }
  async put<T>(key: string, value: T) { this.map.set(key, structuredClone(value)); }
  async delete(key: string) { this.map.delete(key); }
  async setAlarm(at: number) { this.alarmAt = at; }
  async deleteAlarm() { this.alarmAt = null; }
  room(): RoomRecord { return this.map.get(ROOM_KEY) as RoomRecord; }
}

class FakeSocket implements SocketPort {
  readonly sent: Array<Record<string, unknown>> = [];
  closed: { code: number; reason: string } | null = null;
  private att: SocketAttachment | null = null;
  send(text: string) { this.sent.push(JSON.parse(text)); }
  close(code: number, reason: string) { this.closed = { code, reason }; }
  attachment() { return this.att; }
  attach(a: SocketAttachment) { this.att = a; }
  last() { return this.sent[this.sent.length - 1]; }
  ofType(t: string) { return this.sent.filter((f) => f.t === t); }
}

function harness(opts: { subs?: Record<string, string>; now?: number } = {}) {
  const storage = new FakeStorage();
  const sockets: FakeSocket[] = [];
  const clock = { now: opts.now ?? 1_000_000 };
  const core = new RoomCore({
    storage,
    sockets: () => sockets.filter((s) => s.closed === null),
    authenticate: async (token) => opts.subs?.[token] ?? null,
    now: () => clock.now,
  });
  const open = async () => { const s = new FakeSocket(); sockets.push(s); await core.onOpen(s); return s; };
  const say = (s: FakeSocket, frame: unknown) => core.onMessage(s, JSON.stringify(frame));
  return { storage, sockets, clock, core, open, say };
}

const snap = (focus: string | null = 'a') => ({
  playlistId: 'p1', name: 'Culto', entries: [{ id: 'a', kind: 'pdf' }, { id: 'b', kind: 'audio' }], focusKey: focus,
});
const CODE = 'k7x2m9q';

test('sala sem init responde not_found e fecha 4004', async () => {
  const h = harness();
  const s = await h.open();
  await h.say(s, { t: 'hello', room: CODE, since: 0, clientId: 'c1' });
  assert.deepEqual(s.last(), { t: 'error', room: '', code: 'not_found' });
  assert.equal(s.closed?.code, CLOSE_NOT_FOUND);
});

test('init grava a sala idle; hello de consumidor recebe room e presence sobe', async () => {
  const h = harness();
  await h.core.init({ code: CODE, ownerSub: 'owner', ownerName: 'Fulano' });
  assert.equal(h.storage.room().status, 'idle');

  const a = await h.open();
  await h.say(a, { t: 'hello', room: CODE, since: 0, clientId: 'c1' });
  assert.deepEqual(a.sent[0], {
    t: 'room', room: CODE, status: 'idle', ownerName: 'Fulano', role: 'consumer',
    version: 0, snapshot: null, leaderPresent: false, viewers: 1,
  });
  const b = await h.open();
  await h.say(b, { t: 'hello', room: CODE, since: 0, clientId: 'c2' });
  assert.deepEqual(a.ofType('presence').pop(), { t: 'presence', room: CODE, leaderPresent: false, viewers: 2 });
});

test('hello de sala errada é ignorado com error bad_frame', async () => {
  const h = harness();
  await h.core.init({ code: CODE, ownerSub: 'owner', ownerName: 'Fulano' });
  const s = await h.open();
  await h.say(s, { t: 'hello', room: 'zzzzzzz', since: 0, clientId: 'c1' });
  assert.deepEqual(s.last(), { t: 'error', room: CODE, code: 'bad_frame' });
  assert.equal(s.attachment()?.role, 'pending');
});

test('token do dono vira leader; token de outro ou inválido vira consumer com not_leader', async () => {
  const h = harness({ subs: { sess_owner: 'owner', sess_other: 'someone' } });
  await h.core.init({ code: CODE, ownerSub: 'owner', ownerName: 'Fulano' });

  const leader = await h.open();
  await h.say(leader, { t: 'hello', room: CODE, since: 0, clientId: 'L', sessionToken: 'sess_owner' });
  assert.equal(leader.attachment()?.role, 'leader');
  assert.equal(leader.sent[0].role, 'leader');
  assert.equal(leader.sent[0].leaderPresent, true);

  const other = await h.open();
  await h.say(other, { t: 'hello', room: CODE, since: 0, clientId: 'O', sessionToken: 'sess_other' });
  assert.equal(other.attachment()?.role, 'consumer');
  assert.deepEqual(other.sent[0], { t: 'error', room: CODE, code: 'not_leader' });
  assert.equal(other.sent[1].t, 'room');

  const bad = await h.open();
  await h.say(bad, { t: 'hello', room: CODE, since: 0, clientId: 'B', sessionToken: 'sess_nope' });
  assert.equal(bad.attachment()?.role, 'consumer');
  assert.deepEqual(bad.sent[0], { t: 'error', room: CODE, code: 'unauthorized' });
});

test('segundo leader fecha o primeiro com 4002 replaced', async () => {
  const h = harness({ subs: { sess_owner: 'owner' } });
  await h.core.init({ code: CODE, ownerSub: 'owner', ownerName: 'Fulano' });
  const first = await h.open();
  await h.say(first, { t: 'hello', room: CODE, since: 0, clientId: 'L1', sessionToken: 'sess_owner' });
  const second = await h.open();
  await h.say(second, { t: 'hello', room: CODE, since: 0, clientId: 'L2', sessionToken: 'sess_owner' });
  assert.deepEqual(first.ofType('ended')[0], { t: 'ended', room: CODE, reason: 'replaced' });
  assert.equal(first.closed?.code, CLOSE_REPLACED);
  assert.equal(second.attachment()?.role, 'leader');
});

test('start → live, version 1, room a todos; set incrementa e faz broadcast + ack; alarm armado', async () => {
  const h = harness({ subs: { sess_owner: 'owner' } });
  await h.core.init({ code: CODE, ownerSub: 'owner', ownerName: 'Fulano' });
  const c = await h.open();
  await h.say(c, { t: 'hello', room: CODE, since: 0, clientId: 'c1' });
  const l = await h.open();
  await h.say(l, { t: 'hello', room: CODE, since: 0, clientId: 'L', sessionToken: 'sess_owner' });

  await h.say(l, { t: 'start', snapshot: snap() });
  const room = c.ofType('room').pop()!;
  assert.equal(room.status, 'live');
  assert.equal(room.version, 1);
  assert.deepEqual(room.snapshot, snap());
  assert.equal(h.storage.alarmAt, h.clock.now + ALARM_INTERVAL_MS);

  await h.say(l, { t: 'set', snapshot: snap('b') });
  assert.deepEqual(c.last(), { t: 'snapshot', room: CODE, version: 2, snapshot: snap('b'), viewers: 1 });
  assert.deepEqual(l.last(), { t: 'ack', room: CODE, version: 2, viewers: 1 });
  assert.equal(h.storage.room().version, 2);
});

test('set fora de live é not_live; set/start/end de consumidor é not_leader; frame grande de consumidor é ignorado', async () => {
  const h = harness({ subs: { sess_owner: 'owner' } });
  await h.core.init({ code: CODE, ownerSub: 'owner', ownerName: 'Fulano' });
  const l = await h.open();
  await h.say(l, { t: 'hello', room: CODE, since: 0, clientId: 'L', sessionToken: 'sess_owner' });
  await h.say(l, { t: 'set', snapshot: snap() });
  assert.deepEqual(l.last(), { t: 'error', room: CODE, code: 'not_live' });

  const c = await h.open();
  await h.say(c, { t: 'hello', room: CODE, since: 0, clientId: 'c1' });
  await h.say(c, { t: 'start', snapshot: snap() });
  assert.deepEqual(c.last(), { t: 'error', room: CODE, code: 'not_leader' });
  assert.equal(h.storage.room().status, 'idle');

  const before = c.sent.length;
  await h.core.onMessage(c, JSON.stringify({ t: 'hello', room: CODE, since: 0, clientId: 'x'.repeat(3000) }));
  assert.equal(c.sent.length, before);
});

test('frame antes do hello (pending) é rejeitado com not_leader', async () => {
  const h = harness();
  await h.core.init({ code: CODE, ownerSub: 'owner', ownerName: 'Fulano' });
  const s = await h.open();
  await h.say(s, { t: 'end' });
  assert.deepEqual(s.last(), { t: 'error', room: CODE, code: 'not_leader' });
});

test('end → ended{leader} a todos, consumidores fechados 4001, snapshot preservado, alarm em +24h', async () => {
  const h = harness({ subs: { sess_owner: 'owner' } });
  await h.core.init({ code: CODE, ownerSub: 'owner', ownerName: 'Fulano' });
  const c = await h.open();
  await h.say(c, { t: 'hello', room: CODE, since: 0, clientId: 'c1' });
  const l = await h.open();
  await h.say(l, { t: 'hello', room: CODE, since: 0, clientId: 'L', sessionToken: 'sess_owner' });
  await h.say(l, { t: 'start', snapshot: snap() });
  await h.say(l, { t: 'end' });
  assert.deepEqual(c.last(), { t: 'ended', room: CODE, reason: 'leader' });
  assert.equal(c.closed?.code, CLOSE_ENDED);
  assert.equal(l.closed?.code, CLOSE_ENDED);
  assert.equal(h.storage.room().status, 'ended');
  assert.deepEqual(h.storage.room().snapshot, snap());
  assert.equal(h.storage.alarmAt, h.clock.now + ENDED_TTL_MS);
});

test('hello em sala ended devolve room com o último snapshot (para «Guardar cópia»)', async () => {
  const h = harness({ subs: { sess_owner: 'owner' } });
  await h.core.init({ code: CODE, ownerSub: 'owner', ownerName: 'Fulano' });
  const l = await h.open();
  await h.say(l, { t: 'hello', room: CODE, since: 0, clientId: 'L', sessionToken: 'sess_owner' });
  await h.say(l, { t: 'start', snapshot: snap() });
  await h.say(l, { t: 'end' });
  const late = await h.open();
  await h.say(late, { t: 'hello', room: CODE, since: 0, clientId: 'c9' });
  assert.equal(late.last().status, 'ended');
  assert.deepEqual(late.last().snapshot, snap());
});

test('leader fecha sem end: presence leaderPresent=false; alarm encerra por inatividade após 15 min', async () => {
  const h = harness({ subs: { sess_owner: 'owner' } });
  await h.core.init({ code: CODE, ownerSub: 'owner', ownerName: 'Fulano' });
  const c = await h.open();
  await h.say(c, { t: 'hello', room: CODE, since: 0, clientId: 'c1' });
  const l = await h.open();
  await h.say(l, { t: 'hello', room: CODE, since: 0, clientId: 'L', sessionToken: 'sess_owner' });
  await h.say(l, { t: 'start', snapshot: snap() });

  l.closed = { code: 1006, reason: '' };
  await h.core.onClose(l);
  assert.deepEqual(c.last(), { t: 'presence', room: CODE, leaderPresent: false, viewers: 1 });

  h.clock.now += ALARM_INTERVAL_MS;
  await h.core.onAlarm();
  assert.equal(h.storage.room().status, 'live'); // 5 min: ainda dentro do TTL
  assert.equal(h.storage.alarmAt, h.clock.now + ALARM_INTERVAL_MS);

  h.clock.now += LEADER_TTL_MS;
  await h.core.onAlarm();
  assert.equal(h.storage.room().status, 'ended');
  assert.deepEqual(c.last(), { t: 'ended', room: CODE, reason: 'inactivity' });
  assert.equal(c.closed?.code, CLOSE_ENDED);
});

test('onClose com o socket a fechar ainda em sockets(): presence exclui-o (leader e consumer)', async () => {
  const h = harness({ subs: { sess_owner: 'owner' } });
  await h.core.init({ code: CODE, ownerSub: 'owner', ownerName: 'Fulano' });
  const c1 = await h.open();
  await h.say(c1, { t: 'hello', room: CODE, since: 0, clientId: 'c1' });
  const c2 = await h.open();
  await h.say(c2, { t: 'hello', room: CODE, since: 0, clientId: 'c2' });
  const l = await h.open();
  await h.say(l, { t: 'hello', room: CODE, since: 0, clientId: 'L', sessionToken: 'sess_owner' });
  await h.say(l, { t: 'start', snapshot: snap() });

  // O runtime só tira o socket de `getWebSockets()` depois do handler:
  // `onClose` primeiro, `closed` só depois.
  await h.core.onClose(l);
  assert.deepEqual(c1.last(), { t: 'presence', room: CODE, leaderPresent: false, viewers: 2 });
  assert.deepEqual(c2.last(), { t: 'presence', room: CODE, leaderPresent: false, viewers: 2 });
  assert.equal(l.ofType('presence').length, 0);
  l.closed = { code: 1006, reason: '' };

  await h.core.onClose(c2);
  assert.deepEqual(c1.last(), { t: 'presence', room: CODE, leaderPresent: false, viewers: 1 });
  assert.equal(c2.ofType('presence').filter((f) => f.viewers === 1).length, 0);
  c2.closed = { code: 1000, reason: '' };
});

test('leader que volta antes do TTL mantém a sala live e recebe o snapshot corrente', async () => {
  const h = harness({ subs: { sess_owner: 'owner' } });
  await h.core.init({ code: CODE, ownerSub: 'owner', ownerName: 'Fulano' });
  const l = await h.open();
  await h.say(l, { t: 'hello', room: CODE, since: 0, clientId: 'L', sessionToken: 'sess_owner' });
  await h.say(l, { t: 'start', snapshot: snap() });
  l.closed = { code: 1006, reason: '' };
  await h.core.onClose(l);
  h.clock.now += 2 * 60_000;
  const back = await h.open();
  await h.say(back, { t: 'hello', room: CODE, since: 1, clientId: 'L', sessionToken: 'sess_owner' });
  assert.equal(back.last().status, 'live');
  assert.equal(back.last().version, 1);
  h.clock.now += ALARM_INTERVAL_MS;
  await h.core.onAlarm();
  assert.equal(h.storage.room().status, 'live');
});

test('ended volta a idle 24 h depois, apagando o snapshot; sem alarm novo', async () => {
  const h = harness({ subs: { sess_owner: 'owner' } });
  await h.core.init({ code: CODE, ownerSub: 'owner', ownerName: 'Fulano' });
  const l = await h.open();
  await h.say(l, { t: 'hello', room: CODE, since: 0, clientId: 'L', sessionToken: 'sess_owner' });
  await h.say(l, { t: 'start', snapshot: snap() });
  await h.say(l, { t: 'end' });
  h.clock.now += ENDED_TTL_MS;
  await h.core.onAlarm();
  assert.equal(h.storage.room().status, 'idle');
  assert.equal(h.storage.room().snapshot, null);
  assert.equal(h.storage.alarmAt, null);
});

test('retire fecha todos com 4003 e a sala responde not_found depois', async () => {
  const h = harness();
  await h.core.init({ code: CODE, ownerSub: 'owner', ownerName: 'Fulano' });
  const c = await h.open();
  await h.say(c, { t: 'hello', room: CODE, since: 0, clientId: 'c1' });
  await h.core.retire();
  assert.deepEqual(c.ofType('ended')[0], { t: 'ended', room: CODE, reason: 'retired' });
  assert.equal(c.closed?.code, CLOSE_RETIRED);
  const late = await h.open();
  await h.say(late, { t: 'hello', room: CODE, since: 0, clientId: 'c2' });
  assert.equal(late.last().code, 'not_found');
});

test('init de novo numa sala existente só atualiza ownerName', async () => {
  const h = harness({ subs: { sess_owner: 'owner' } });
  await h.core.init({ code: CODE, ownerSub: 'owner', ownerName: 'Fulano' });
  const l = await h.open();
  await h.say(l, { t: 'hello', room: CODE, since: 0, clientId: 'L', sessionToken: 'sess_owner' });
  await h.say(l, { t: 'start', snapshot: snap() });
  await h.core.init({ code: CODE, ownerSub: 'owner', ownerName: 'Fulano Silva' });
  assert.equal(h.storage.room().status, 'live');
  assert.equal(h.storage.room().ownerName, 'Fulano Silva');
});

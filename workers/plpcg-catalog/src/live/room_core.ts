/**
 * A sala ao vivo como máquina de estados **sem** nenhuma API da Cloudflare
 * (spec 2026-09-12-lista-ao-vivo, §4.3). O Durable Object `LiveRoom`
 * (`live_room.ts`) adapta `ctx.storage`, `ctx.getWebSockets()` e D1 para as
 * portas abaixo; aqui tudo é testável com `node --test`.
 *
 * Invariantes: o DO atribui `version`; todo frame enviado leva `room`;
 * consumidor só pode `hello`; o snapshot sobrevive a `ended` (para «Guardar
 * cópia») e morre 24 h depois, quando a sala volta a `idle`.
 */
import type { ClientFrame, EndReason, ErrorCode, Role, RoomStatus, ServerFrame, Snapshot } from './protocol.ts';
import { MAX_CONSUMER_FRAME_BYTES, MAX_SET_BYTES, parseClientFrame } from './protocol.ts';

export const ROOM_KEY = 'room';
export const ALARM_INTERVAL_MS = 5 * 60 * 1000;
export const LEADER_TTL_MS = 15 * 60 * 1000;
export const ENDED_TTL_MS = 24 * 60 * 60 * 1000;

export const CLOSE_ENDED = 4001;
export const CLOSE_REPLACED = 4002;
export const CLOSE_RETIRED = 4003;
export const CLOSE_NOT_FOUND = 4004;

export interface SocketAttachment {
  role: 'pending' | Role;
  clientId: string;
  sub?: string;
  nick?: string;
}

export interface SocketPort {
  send(text: string): void;
  close(code: number, reason: string): void;
  attachment(): SocketAttachment | null;
  attach(attachment: SocketAttachment): void;
}

export interface RoomStorage {
  get<T>(key: string): Promise<T | undefined>;
  put<T>(key: string, value: T): Promise<void>;
  delete(key: string): Promise<void>;
  setAlarm(at: number): Promise<void>;
  deleteAlarm(): Promise<void>;
}

export interface RoomRecord {
  code: string;
  ownerSub: string;
  ownerName: string;
  status: RoomStatus;
  version: number;
  snapshot: Snapshot | null;
  leaderSeenAt: number | null;
  startedAt: number | null;
  endedAt: number | null;
}

export interface RoomCoreDeps {
  storage: RoomStorage;
  /** Sockets **abertos** desta sala. */
  sockets: () => SocketPort[];
  /** `sub` do token (`sess_…` ou JWT), ou `null`. */
  authenticate: (token: string) => Promise<string | null>;
  now: () => number;
}

const encoder = new TextEncoder();

export class RoomCore {
  private readonly deps: RoomCoreDeps;

  constructor(deps: RoomCoreDeps) {
    this.deps = deps;
  }

  // ---- HTTP interno (Worker → DO) --------------------------------------

  async init(input: { code: string; ownerSub: string; ownerName: string }): Promise<void> {
    const current = await this.room();
    if (current && current.status !== 'retired') {
      await this.save({ ...current, ownerName: input.ownerName });
      return;
    }
    await this.save({
      code: input.code,
      ownerSub: input.ownerSub,
      ownerName: input.ownerName,
      status: 'idle',
      version: 0,
      snapshot: null,
      leaderSeenAt: null,
      startedAt: null,
      endedAt: null,
    });
  }

  /** Link regenerado: esta sala deixa de existir para quem tem o código antigo. */
  async retire(): Promise<void> {
    const room = await this.room();
    if (!room) return;
    this.broadcast(room, { t: 'ended', room: room.code, reason: 'retired' });
    for (const s of this.deps.sockets()) s.close(CLOSE_RETIRED, 'retired');
    await this.save({ ...room, status: 'retired', snapshot: null });
    await this.deps.storage.deleteAlarm();
  }

  // ---- sockets -----------------------------------------------------------

  async onOpen(socket: SocketPort): Promise<void> {
    socket.attach({ role: 'pending', clientId: '' });
  }

  async onMessage(socket: SocketPort, text: string): Promise<void> {
    const att = socket.attachment() ?? { role: 'pending' as const, clientId: '' };
    const bytes = encoder.encode(text).length;
    if (att.role !== 'leader' && bytes > MAX_CONSUMER_FRAME_BYTES) return;
    if (bytes > MAX_SET_BYTES) {
      const room = await this.room();
      this.sendError(socket, room?.code ?? '', 'too_large');
      return;
    }

    const room = await this.room();
    if (!room || room.status === 'retired') {
      this.sendError(socket, room?.code ?? '', 'not_found');
      socket.close(CLOSE_NOT_FOUND, 'not_found');
      return;
    }

    const frame = parseClientFrame(text);
    if ('error' in frame) {
      this.sendError(socket, room.code, frame.error);
      return;
    }

    if (frame.t === 'hello') {
      await this.onHello(socket, room, frame);
      return;
    }
    if (att.role !== 'leader') {
      this.sendError(socket, room.code, 'not_leader');
      return;
    }
    await this.onLeaderFrame(socket, room, frame);
  }

  async onClose(socket: SocketPort): Promise<void> {
    const room = await this.room();
    if (!room) return;
    const att = socket.attachment();
    if (att?.role === 'leader') {
      const updated = { ...room, leaderSeenAt: this.deps.now() };
      await this.save(updated);
      if (updated.status === 'live') await this.armAlarm(ALARM_INTERVAL_MS);
      this.broadcastPresence(updated);
      return;
    }
    if (att?.role === 'consumer') this.broadcastPresence(room);
  }

  async onAlarm(): Promise<void> {
    const room = await this.room();
    if (!room) return;
    const now = this.deps.now();

    if (room.status === 'live') {
      const leaderAway = this.leaders().length === 0;
      const seen = room.leaderSeenAt ?? room.startedAt ?? now;
      if (leaderAway && now - seen >= LEADER_TTL_MS) {
        await this.end(room, 'inactivity');
        return;
      }
      await this.armAlarm(ALARM_INTERVAL_MS);
      return;
    }

    if (room.status === 'ended') {
      const endedAt = room.endedAt ?? now;
      if (now - endedAt >= ENDED_TTL_MS) {
        await this.save({ ...room, status: 'idle', snapshot: null, version: room.version, startedAt: null, endedAt: null });
        await this.deps.storage.deleteAlarm();
        return;
      }
      await this.armAlarm(ENDED_TTL_MS - (now - endedAt));
    }
  }

  // ---- internos ------------------------------------------------------------

  private async onHello(socket: SocketPort, room: RoomRecord, frame: Extract<ClientFrame, { t: 'hello' }>): Promise<void> {
    if (frame.room !== room.code) {
      this.sendError(socket, room.code, 'bad_frame');
      return;
    }

    let role: Role = 'consumer';
    let sub: string | undefined;
    if (frame.sessionToken) {
      const resolved = await this.deps.authenticate(frame.sessionToken);
      if (resolved === null) {
        this.sendError(socket, room.code, 'unauthorized');
      } else if (resolved !== room.ownerSub) {
        this.sendError(socket, room.code, 'not_leader');
      } else {
        role = 'leader';
        sub = resolved;
      }
    }

    if (role === 'leader') {
      for (const other of this.leaders()) {
        if (other === socket) continue;
        this.send(other, { t: 'ended', room: room.code, reason: 'replaced' });
        other.close(CLOSE_REPLACED, 'replaced');
      }
    }

    socket.attach({ role, clientId: frame.clientId, sub, nick: frame.nick });

    const viewers = this.consumers().length;
    this.send(socket, {
      t: 'room',
      room: room.code,
      status: room.status,
      ownerName: room.ownerName,
      role,
      version: room.version,
      snapshot: room.snapshot,
      leaderPresent: this.leaders().length > 0,
      viewers,
    });
    this.broadcastPresence(room, socket);
  }

  private async onLeaderFrame(socket: SocketPort, room: RoomRecord, frame: Exclude<ClientFrame, { t: 'hello' }>): Promise<void> {
    const now = this.deps.now();
    switch (frame.t) {
      case 'start': {
        const updated: RoomRecord = {
          ...room,
          status: 'live',
          version: room.version + 1,
          snapshot: frame.snapshot,
          leaderSeenAt: now,
          startedAt: now,
          endedAt: null,
        };
        await this.save(updated);
        await this.armAlarm(ALARM_INTERVAL_MS);
        for (const s of this.deps.sockets()) {
          const att = s.attachment();
          if (!att || att.role === 'pending') continue;
          this.send(s, {
            t: 'room', room: updated.code, status: 'live', ownerName: updated.ownerName,
            role: att.role, version: updated.version, snapshot: updated.snapshot,
            leaderPresent: true, viewers: this.consumers().length,
          });
        }
        return;
      }
      case 'set': {
        if (room.status !== 'live') {
          this.sendError(socket, room.code, 'not_live');
          return;
        }
        const updated: RoomRecord = { ...room, version: room.version + 1, snapshot: frame.snapshot, leaderSeenAt: now };
        await this.save(updated);
        const viewers = this.consumers().length;
        for (const s of this.deps.sockets()) {
          if (s === socket) continue;
          const att = s.attachment();
          if (!att || att.role === 'pending') continue;
          this.send(s, { t: 'snapshot', room: updated.code, version: updated.version, snapshot: frame.snapshot, viewers });
        }
        this.send(socket, { t: 'ack', room: updated.code, version: updated.version, viewers });
        return;
      }
      case 'end':
        await this.end(room, 'leader');
        return;
    }
  }

  private async end(room: RoomRecord, reason: EndReason): Promise<void> {
    const now = this.deps.now();
    await this.save({ ...room, status: 'ended', endedAt: now, leaderSeenAt: now });
    this.broadcast(room, { t: 'ended', room: room.code, reason });
    for (const s of this.deps.sockets()) s.close(CLOSE_ENDED, 'ended');
    await this.armAlarm(ENDED_TTL_MS);
  }

  private broadcastPresence(room: RoomRecord, except?: SocketPort): void {
    const frame: ServerFrame = {
      t: 'presence', room: room.code, leaderPresent: this.leaders().length > 0, viewers: this.consumers().length,
    };
    for (const s of this.deps.sockets()) {
      if (s === except) continue;
      const att = s.attachment();
      if (!att || att.role === 'pending') continue;
      this.send(s, frame);
    }
  }

  private broadcast(room: RoomRecord, frame: ServerFrame): void {
    for (const s of this.deps.sockets()) {
      const att = s.attachment();
      if (!att || att.role === 'pending') continue;
      this.send(s, frame);
    }
  }

  private leaders(): SocketPort[] {
    return this.deps.sockets().filter((s) => s.attachment()?.role === 'leader');
  }

  private consumers(): SocketPort[] {
    return this.deps.sockets().filter((s) => s.attachment()?.role === 'consumer');
  }

  private send(socket: SocketPort, frame: ServerFrame): void {
    socket.send(JSON.stringify(frame));
  }

  private sendError(socket: SocketPort, room: string, code: ErrorCode): void {
    this.send(socket, { t: 'error', room, code });
  }

  private room(): Promise<RoomRecord | undefined> {
    return this.deps.storage.get<RoomRecord>(ROOM_KEY);
  }

  private save(room: RoomRecord): Promise<void> {
    return this.deps.storage.put(ROOM_KEY, room);
  }

  private armAlarm(inMs: number): Promise<void> {
    return this.deps.storage.setAlarm(this.deps.now() + inMs);
  }
}

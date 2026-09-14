/**
 * Protocolo da Lista ao Vivo (spec 2026-09-12-lista-ao-vivo, §5), Fase 1.
 *
 * Só validação de forma. Quem decide se o remetente **pode** (papel, estado
 * da sala) é o `RoomCore`. Tudo o que o DO manda leva `room` — o cliente
 * descarta frames de outra sala.
 */
export type RoomStatus = 'idle' | 'scheduled' | 'live' | 'ended' | 'retired';
export type Role = 'leader' | 'consumer';

export interface WireEntry {
  id: string;
  kind: string;
}

export interface Snapshot {
  playlistId: string;
  name: string;
  entries: WireEntry[];
  focusKey: string | null;
}

export const MAX_ENTRIES = 200;
export const MAX_SET_BYTES = 32 * 1024;
export const MAX_CONSUMER_FRAME_BYTES = 2048;
export const MAX_NICK_LENGTH = 24;
export const MAX_NAME_LENGTH = 120;

export interface HelloFrame {
  t: 'hello';
  room: string;
  since: number;
  clientId: string;
  nick?: string;
  sessionToken?: string;
}
export interface StartFrame { t: 'start'; snapshot: Snapshot }
export interface SetFrame { t: 'set'; snapshot: Snapshot }
export interface EndFrame { t: 'end' }
export type ClientFrame = HelloFrame | StartFrame | SetFrame | EndFrame;

export type ErrorCode =
  | 'bad_frame'
  | 'not_leader'
  | 'not_live'
  | 'too_large'
  | 'not_found'
  | 'unauthorized';

export type EndReason = 'leader' | 'inactivity' | 'replaced' | 'expired' | 'retired';

export type ServerFrame =
  | {
      t: 'room';
      room: string;
      status: RoomStatus;
      ownerName: string;
      role: Role;
      version: number;
      snapshot: Snapshot | null;
      leaderPresent: boolean;
      viewers: number;
    }
  | { t: 'snapshot'; room: string; version: number; snapshot: Snapshot; viewers: number }
  | { t: 'presence'; room: string; leaderPresent: boolean; viewers: number }
  | { t: 'ack'; room: string; version: number; viewers: number }
  | { t: 'ended'; room: string; reason: EndReason }
  | { t: 'error'; room: string; code: ErrorCode };

const BAD = { error: 'bad_frame' } as const;

function isRecord(v: unknown): v is Record<string, unknown> {
  return typeof v === 'object' && v !== null && !Array.isArray(v);
}

function nonEmptyString(v: unknown): v is string {
  return typeof v === 'string' && v.length > 0;
}

function parseSnapshot(raw: unknown): Snapshot | { error: ErrorCode } {
  if (!isRecord(raw)) return BAD;
  if (!nonEmptyString(raw.playlistId)) return BAD;
  if (typeof raw.name !== 'string') return BAD;
  if (!Array.isArray(raw.entries)) return BAD;
  if (raw.entries.length > MAX_ENTRIES) return { error: 'too_large' };
  const entries: WireEntry[] = [];
  for (const e of raw.entries) {
    if (!isRecord(e) || !nonEmptyString(e.id) || !nonEmptyString(e.kind)) return BAD;
    entries.push({ id: e.id, kind: e.kind });
  }
  const focus = raw.focusKey ?? null;
  if (focus !== null && typeof focus !== 'string') return BAD;
  return {
    playlistId: raw.playlistId,
    name: raw.name.slice(0, MAX_NAME_LENGTH),
    entries,
    focusKey: focus,
  };
}

/** Frame do cliente validado, ou `{ error }` (`bad_frame` / `too_large`). */
export function parseClientFrame(text: string): ClientFrame | { error: ErrorCode } {
  let raw: unknown;
  try {
    raw = JSON.parse(text);
  } catch {
    return BAD;
  }
  if (!isRecord(raw)) return BAD;

  switch (raw.t) {
    case 'hello': {
      if (!nonEmptyString(raw.room) || !nonEmptyString(raw.clientId)) return BAD;
      if (typeof raw.since !== 'number' || !Number.isInteger(raw.since) || raw.since < 0) return BAD;
      const frame: HelloFrame = { t: 'hello', room: raw.room, since: raw.since, clientId: raw.clientId };
      if (nonEmptyString(raw.sessionToken)) frame.sessionToken = raw.sessionToken;
      if (typeof raw.nick === 'string') {
        const nick = raw.nick.trim().slice(0, MAX_NICK_LENGTH);
        if (nick.length > 0) frame.nick = nick;
      }
      return frame;
    }
    case 'start':
    case 'set': {
      const snapshot = parseSnapshot(raw.snapshot);
      if ('error' in snapshot) return snapshot;
      return { t: raw.t, snapshot };
    }
    case 'end':
      return { t: 'end' };
    default:
      return BAD;
  }
}

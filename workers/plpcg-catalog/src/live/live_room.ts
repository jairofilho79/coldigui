// workers/plpcg-catalog/src/live/live_room.ts
/**
 * Durable Object da sala ao vivo — casca fina sobre `RoomCore`.
 *
 * Hibernation WebSocket API: `acceptWebSocket` + handlers `webSocket*`; o
 * papel de cada socket vai no attachment (sobrevive à hibernação); ping/pong
 * respondido na borda sem acordar o objeto. Estado em `ctx.storage` (KV do
 * DO, classe SQLite-backed — `new_sqlite_classes` no wrangler).
 *
 * URLs internas (só o Worker chama): `POST /init`, `POST /retire`,
 * `GET …/ws` (upgrade).
 */
import { DurableObject } from 'cloudflare:workers';
import type { Env } from '../index.ts';
import { authenticateToken } from './authenticate_token.ts';
import type { RoomStorage, SocketAttachment, SocketPort } from './room_core.ts';
import { RoomCore } from './room_core.ts';

function storageAdapter(storage: DurableObjectStorage): RoomStorage {
  return {
    get: (key) => storage.get(key),
    put: (key, value) => storage.put(key, value),
    delete: async (key) => { await storage.delete(key); },
    setAlarm: (at) => storage.setAlarm(at),
    deleteAlarm: () => storage.deleteAlarm(),
  };
}

function port(ws: WebSocket): SocketPort {
  return {
    send: (text) => { try { ws.send(text); } catch { /* socket já fechado */ } },
    close: (code, reason) => { try { ws.close(code, reason); } catch { /* idem */ } },
    attachment: () => (ws.deserializeAttachment() as SocketAttachment | null) ?? null,
    attach: (a) => ws.serializeAttachment(a),
  };
}

export class LiveRoom extends DurableObject<Env> {
  private readonly core: RoomCore;

  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    this.core = new RoomCore({
      storage: storageAdapter(ctx.storage),
      sockets: () => ctx.getWebSockets().map(port),
      authenticate: (token) => authenticateToken(env, token),
      now: () => Date.now(),
    });
    ctx.setWebSocketAutoResponse(new WebSocketRequestResponsePair('ping', 'pong'));
  }

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === 'POST' && url.pathname === '/init') {
      const body = (await request.json()) as { code: string; ownerSub: string; ownerName: string };
      await this.core.init(body);
      return new Response(null, { status: 204 });
    }
    if (request.method === 'POST' && url.pathname === '/retire') {
      await this.core.retire();
      return new Response(null, { status: 204 });
    }
    if (request.method === 'GET' && url.pathname.endsWith('/ws')) {
      if (request.headers.get('Upgrade')?.toLowerCase() !== 'websocket') {
        return new Response('expected websocket', { status: 426 });
      }
      const pair = new WebSocketPair();
      const [client, server] = [pair[0], pair[1]];
      this.ctx.acceptWebSocket(server, ['ws']);
      await this.core.onOpen(port(server));
      return new Response(null, { status: 101, webSocket: client });
    }
    return new Response('not found', { status: 404 });
  }

  async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer): Promise<void> {
    if (typeof message !== 'string') return;
    await this.core.onMessage(port(ws), message);
  }

  async webSocketClose(ws: WebSocket): Promise<void> {
    await this.core.onClose(port(ws));
  }

  async webSocketError(ws: WebSocket): Promise<void> {
    await this.core.onClose(port(ws));
  }

  async alarm(): Promise<void> {
    await this.core.onAlarm();
  }
}

# Lista ao Vivo — Fase 1 (núcleo) — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Um gestor logado inicia «ao vivo» uma lista salva e N pessoas com o link `plpcg.com/ao-vivo/<code>` veem a mesma lista e o mesmo louvor em foco em tempo real, com reconexão automática, encerramento por inatividade e «Guardar cópia» ao fim.

**Architecture:** O Worker `plpcg-catalog` ganha um Durable Object `LiveRoom` (uma sala permanente por pessoa, `idFromName(code)`, Hibernation WebSocket API, storage KV do próprio DO) e a tabela D1 `live_rooms` (índice `code ↔ owner_sub`). A lógica da sala vive em `RoomCore` (puro, testado com `node --test` sobre fakes de storage/socket); o DO é uma casca fina. No app Flutter, `LiveSessionController` (Riverpod, `keepAlive`, única instância) fala com o DO por `LiveTransport` (WebSocket) e, para o consumidor, publica um `LiveProjection` que `activeEntriesProvider` passa a preferir sobre a lista ativa local — a barra, o leitor e o player não mudam. O foco do gestor **só sinaliza** quando o consumidor desviou (D3).

**Tech Stack:** Cloudflare Workers + Durable Objects (TypeScript, `cloudflare:workers`, D1, `node --test` com `FakeD1Database`), Flutter 3 / Dart 3.13, Riverpod 3, GoRouter 17, `web_socket_channel`, `shared_preferences`, `qr_flutter`, `share_plus`.

**Spec:** `docs/superpowers/specs/2026-09-12-lista-ao-vivo-design.md` (Fase 1 da §10; §12 foi reconferido em 2026-09-14 — ver «Divergências da spec» abaixo).

## Global Constraints

- **Transporte só WebSocket** (spec D5). **Sem fallback HTTP/polling.** Quem falha o handshake **3 vezes seguidas** ao entrar vê `unavailable`, terminal.
- Código da sala: **7 chars `[a-z0-9]`**, regenerável pelo dono, gerado por `crypto.getRandomValues` (mesmo alfabeto de `links/handlers.ts`).
- Snapshot inteiro por mensagem; **≤ 200 entradas**, **≤ 32 KB** por `set`; frames de consumidor **> 2 KB ignorados**; `version` **sempre atribuída pelo DO**.
- Alarm do DO a **cada 5 min** em `live`; sem socket de gestor por **> 15 min** → `ended{inactivity}`; `ended` → `idle` após **24 h**.
- Close codes: `4001 ended`, `4002 replaced`, `4003 retired` (link regenerado), `4004 not_found`; cliente fecha com `1000` ao sair.
- Reconexão: backoff **1 → 2 → 4 … 30 s** com jitter 0–1 s; **nunca religar em `AppLifecycleState.paused`**; religar imediatamente em `resumed` e no evento de conectividade; `hello{since}` ao religar; **descartar frames de sala diferente da atual e `version ≤ atual`**.
- Autenticação do gestor no `hello` com o **token de sessão do Worker** (`sess_…`, spec worker-session-persistence) — o DO valida via `findSession(env.DB)`; JWT do Google também aceito (`verifyGoogleIdToken`).
- Nome exibido do gestor: `users.name` (nome Google — o que a aba Perfil mostra), fallback `users.username`, fallback `'Gestor'`.
- Ordem de rollout: **Worker primeiro** (migration D1 `0013` + DO), depois o app. Homologar em `v2.plpcg.com` (memória `test-on-production-v2`), não em build local.
- Formatação: `dart format` **só nos arquivos tocados**. Worker: `npm run typecheck` e `npm test` verdes antes de cada commit.
- Commits em português, `tipo(escopo): resumo`, com as linhas de atribuição da sessão (`Co-Authored-By` e `Claude-Session` do system-reminder).
- Comandos do app rodam de `/Volumes/SSD 2TB SD/dev/coldigui`; do Worker, de `workers/plpcg-catalog`.
- l10n: toda string nova em `lib/l10n/app_pt.arb` **e** `app_en.arb`; regenerar com `flutter gen-l10n`.

## Divergências da spec (decididas na releitura de 2026-09-14)

| Spec | Plano | Porquê |
|---|---|---|
| `hello{idToken}` | `hello{sessionToken}` (`sess_…` ou JWT) | O app já não guarda `id_token`; `withAuth` aceita os dois. |
| Papel por **tag** de socket | Papel no **attachment** (`serializeAttachment`); tag única `'ws'` | Tags são imutáveis no `acceptWebSocket`, e o papel só se decide no `hello`. `getWebSockets()` filtrado por attachment custa nada com ≤ 200 sockets. |
| Storage SQLite (`ctx.storage.sql`) | KV do DO (`ctx.storage.get/put`) numa classe **SQLite-backed** | Um snapshot ≤ 32 KB cabe numa chave; o fake de teste é um `Map`. Continua `new_sqlite_classes` (Free plan). |
| Indicador «AO VIVO» **na barra** do gestor | **Banner** acima da barra, para gestor e consumidor (`LiveSessionBanner`) | A barra já está no limite de largura no telemóvel (spec barra-lista-ativa §3); um banner serve os dois papéis com um widget. |
| Pergunta «Como quer aparecer?» ao entrar | **Não há apelido na Fase 1** (`nick` fica opcional no protocolo) | Nenhuma tela da Fase 1/2 mostra apelido (D7: sugestões sem apelido). YAGNI. |
| Rota web `/ao-vivo/:code` servida pela app | Worker responde `GET /ao-vivo/:code` com **302 → `https://plpcg.com/?live=<code>`**; a app abre a rota interna `/ao-vivo/:code` | O Worker intercepta `plpcg.com/ao-vivo/*` antes do Pages (mesmo padrão de `/l/:code`); a web usa hash-strategy, então deep links vivem na query da raiz. |
| Frame `presence` não existia | `presence{leaderPresent, viewers}` a todos em cada entrada/saída | «gestor ausente» (§7) e a contagem do gestor precisam disso; saída é grátis. |
| `set{version}` | `set` sem `version` | Só faz sentido com co-gestores (Fase 3). |
| `snapshot` sem nome da lista | `snapshot`/`room` levam `playlistId` **e** `name` | O banner do consumidor mostra o nome da lista do gestor. |

Sugestões, votos, agendamento, pré-download, folheto, `live_sessions`: **Fases 2 e 3, planos próprios.**

---

## Mapa de arquivos

**Worker (`workers/plpcg-catalog/`)**
- Create: `migrations/0013_create_live_rooms.sql`
- Create: `src/short_code.ts` (+ `.test.ts`) — gerador de código 7 chars, extraído de `links/handlers.ts`.
- Modify: `src/links/handlers.ts` — usa `randomShortCode`.
- Create: `src/live/protocol.ts` (+ `.test.ts`) — tipos e `parseClientFrame`.
- Create: `src/live/room_core.ts` (+ `.test.ts`) — máquina de estados da sala, sem imports Cloudflare.
- Create: `src/live/live_room.ts` — a classe `LiveRoom extends DurableObject`.
- Create: `src/live/handlers.ts` (+ `.test.ts`) — `POST /api/live/room`, `POST /api/live/room/regenerate`, `GET /ao-vivo/:code`, path do WS.
- Modify: `src/index.ts` — `Env.LIVE`, rotas `/api/live/*` e `/ao-vivo/*`, export da classe.
- Modify: `src/test/fake_d1.ts` — `live_rooms` e `users.name`.
- Modify: `wrangler.jsonc`, `README.md`.

**App (`lib/features/live/`)**
- `domain/entities/live_snapshot.dart` — `LiveSnapshot`, `LiveRoomStatus`.
- `domain/protocol/live_frames.dart` (+ test) — encode/decode dos frames.
- `domain/ports/live_transport.dart` — `LiveTransport`, `LiveConnection`, `LiveDisconnect`.
- `domain/live_reconnect_policy.dart` (+ test) — backoff puro.
- `domain/live_room_link.dart` (+ test) — parse/format de `/ao-vivo/<code>` e `?live=`.
- `domain/usecases/save_live_copy.dart` (+ test) — «Guardar cópia».
- `data/live_transport_ws.dart` — `web_socket_channel`.
- `data/live_room_remote_datasource.dart` (+ test) — `POST /api/live/room[/regenerate]`.
- `data/providers/live_providers.dart` — DI.
- `presentation/providers/live_projection_provider.dart` — holder `LiveProjection?`.
- `presentation/providers/live_session_state.dart` — `LiveSessionState`, enums.
- `presentation/providers/live_session_controller.dart` (+ tests) — o controller.
- `presentation/providers/live_leader_session_prefs.dart` — pref «estava ao vivo».
- `presentation/providers/my_live_room_provider.dart` — sala do usuário logado.
- `presentation/widgets/live_session_banner.dart` (+ test), `live_lifecycle_listener.dart`.
- `presentation/pages/live_room_screen.dart` (+ test).
- `test/support/fakes/fake_live_transport.dart`.

**App (tocados)**
- `pubspec.yaml` (`web_socket_channel`), `lib/core/constants/api_endpoints.dart`, `lib/core/routing/route_paths.dart`, `lib/core/routing/app_router.dart`.
- `lib/features/playlists/presentation/providers/active_playlist_editor.dart` — projeção + guardas.
- `lib/features/carousel/presentation/widgets/active_playlist_name_chip.dart`, `carousel_bar_trailing_actions.dart` — modo «seguindo».
- `lib/features/catalog/presentation/widgets/material_sheet_actions.dart`, `louvor_group_card.dart` — outcome `following`.
- `lib/features/app_shell/presentation/shell_scaffold.dart`, `widgets/deep_link_listener.dart`, `utils/deep_link_initial_uri.dart`, `pages/profile_screen.dart`.
- `lib/features/playlists/presentation/widgets/playlist_tile_actions.dart` — «Iniciar ao vivo».
- `lib/l10n/app_pt.arb`, `app_en.arb`.
- `docs/features/FEATURE_INDEX.md`, spec (estado).

---

## Parte 1 — Worker

### Task 1: Código curto compartilhado + migration `live_rooms` + binding do DO

**Files:**
- Create: `workers/plpcg-catalog/src/short_code.ts`
- Test: `workers/plpcg-catalog/src/short_code.test.ts`
- Modify: `workers/plpcg-catalog/src/links/handlers.ts:14-16,42-54`
- Create: `workers/plpcg-catalog/migrations/0013_create_live_rooms.sql`
- Modify: `workers/plpcg-catalog/wrangler.jsonc`

**Interfaces:**
- Produces: `SHORT_CODE_PATTERN: RegExp`, `randomShortCode(): string`, `isShortCode(value: unknown): value is string`.

- [ ] **Step 1: Teste do gerador**

```ts
// workers/plpcg-catalog/src/short_code.test.ts
import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { SHORT_CODE_PATTERN, isShortCode, randomShortCode } from './short_code.ts';

test('randomShortCode gera 7 chars [a-z0-9]', () => {
  for (let i = 0; i < 50; i++) {
    const code = randomShortCode();
    assert.equal(code.length, 7);
    assert.match(code, SHORT_CODE_PATTERN);
  }
});

test('isShortCode aceita só o formato exato', () => {
  assert.equal(isShortCode('k7x2m9q'), true);
  assert.equal(isShortCode('K7X2M9Q'), false);
  assert.equal(isShortCode('k7x2m9'), false);
  assert.equal(isShortCode('k7x2m9qq'), false);
  assert.equal(isShortCode(42), false);
  assert.equal(isShortCode(null), false);
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd workers/plpcg-catalog && npm test`
Expected: FAIL — `Cannot find module './short_code.ts'`.

- [ ] **Step 3: Implementar `short_code.ts` e usar em `links/handlers.ts`**

```ts
// workers/plpcg-catalog/src/short_code.ts
/**
 * Códigos curtos públicos: links de share (`short_links.code`) e salas ao
 * vivo (`live_rooms.code`). 7 caracteres `[a-z0-9]` via
 * `crypto.getRandomValues`. O enviesamento de `256 % 36` é aceitável — não é
 * segredo criptográfico, só um identificador não-adivinhável o bastante.
 */
const CODE_ALPHABET = 'abcdefghijklmnopqrstuvwxyz0123456789';
const CODE_LENGTH = 7;

export const SHORT_CODE_PATTERN = /^[a-z0-9]{7}$/;

export function randomShortCode(): string {
  const bytes = new Uint8Array(CODE_LENGTH);
  crypto.getRandomValues(bytes);
  let code = '';
  for (let i = 0; i < CODE_LENGTH; i++) {
    code += CODE_ALPHABET[bytes[i] % CODE_ALPHABET.length];
  }
  return code;
}

export function isShortCode(value: unknown): value is string {
  return typeof value === 'string' && SHORT_CODE_PATTERN.test(value);
}
```

Em `src/links/handlers.ts`: apagar `CODE_ALPHABET`, `CODE_LENGTH` e a função `randomCode`; adicionar `import { randomShortCode } from '../short_code.ts';` e trocar `const code = randomCode();` por `const code = randomShortCode();`.

- [ ] **Step 4: Migration**

```sql
-- workers/plpcg-catalog/migrations/0013_create_live_rooms.sql
-- Migration number: 0013  2026-09-14T00:00:00.000Z
-- Sala «ao vivo» permanente por pessoa (spec 2026-09-12-lista-ao-vivo, §4.2).
-- Índice code ↔ dono; o estado vivo (snapshot, versão) fica só no Durable
-- Object LiveRoom. Regenerar o link troca o `code` da mesma linha.
CREATE TABLE live_rooms (
  code       TEXT PRIMARY KEY NOT NULL,
  owner_sub  TEXT NOT NULL UNIQUE REFERENCES users(google_sub) ON DELETE CASCADE,
  created_at TEXT NOT NULL
);
```

- [ ] **Step 5: `wrangler.jsonc`**

Acrescentar, no objeto raiz:

```jsonc
  "durable_objects": {
    "bindings": [{ "name": "LIVE", "class_name": "LiveRoom" }]
  },
  "migrations": [{ "tag": "live-v1", "new_sqlite_classes": ["LiveRoom"] }],
```

e em `routes`:

```jsonc
    { "pattern": "plpcg.com/api/live/*", "zone_name": "plpcg.com" },
    { "pattern": "plpcg.com/ao-vivo/*", "zone_name": "plpcg.com" }
```

- [ ] **Step 6: Testes e typecheck verdes**

Run: `npm test && npm run typecheck`
Expected: PASS (os testes de `links/handlers.test.ts` continuam verdes — o formato do código não mudou). `typecheck` ainda não conhece `LiveRoom`; `wrangler check` só na Task 4.

- [ ] **Step 7: Commit**

```bash
git add workers/plpcg-catalog/src/short_code.ts workers/plpcg-catalog/src/short_code.test.ts workers/plpcg-catalog/src/links/handlers.ts workers/plpcg-catalog/migrations/0013_create_live_rooms.sql workers/plpcg-catalog/wrangler.jsonc
git commit -m "feat(worker): código curto compartilhado, tabela live_rooms e binding do DO LiveRoom"
```

---

### Task 2: Protocolo — tipos e validação dos frames do cliente

**Files:**
- Create: `workers/plpcg-catalog/src/live/protocol.ts`
- Test: `workers/plpcg-catalog/src/live/protocol.test.ts`

**Interfaces:**
- Produces:
  - `type RoomStatus = 'idle' | 'scheduled' | 'live' | 'ended' | 'retired'`
  - `interface WireEntry { id: string; kind: string }`
  - `interface Snapshot { playlistId: string; name: string; entries: WireEntry[]; focusKey: string | null }`
  - `type ClientFrame = Hello | Start | Set | End` (ver código)
  - `type ErrorCode = 'bad_frame' | 'not_leader' | 'not_live' | 'too_large' | 'not_found' | 'unauthorized'`
  - `type ServerFrame` (`room`, `snapshot`, `presence`, `ack`, `ended`, `error`)
  - `parseClientFrame(text: string): ClientFrame | { error: ErrorCode }`
  - constantes `MAX_ENTRIES = 200`, `MAX_SET_BYTES = 32 * 1024`, `MAX_CONSUMER_FRAME_BYTES = 2048`, `MAX_NICK_LENGTH = 24`, `MAX_NAME_LENGTH = 120`.

- [ ] **Step 1: Testes**

```ts
// workers/plpcg-catalog/src/live/protocol.test.ts
import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { MAX_ENTRIES, parseClientFrame } from './protocol.ts';

const snapshot = {
  playlistId: 'p1',
  name: 'Culto',
  entries: [{ id: 'abc', kind: 'pdf' }],
  focusKey: 'abc',
};

test('hello válido, com e sem token; nick é aparado e limitado', () => {
  const plain = parseClientFrame(
    JSON.stringify({ t: 'hello', room: 'k7x2m9q', since: 3, clientId: 'c1' }),
  );
  assert.deepEqual(plain, { t: 'hello', room: 'k7x2m9q', since: 3, clientId: 'c1' });

  const withToken = parseClientFrame(
    JSON.stringify({
      t: 'hello', room: 'k7x2m9q', since: 0, clientId: 'c1',
      sessionToken: 'sess_x', nick: '  Maria Clara Souza de Oliveira Santos  ',
    }),
  );
  assert.equal((withToken as { sessionToken: string }).sessionToken, 'sess_x');
  assert.equal((withToken as { nick: string }).nick, 'Maria Clara Souza de Oli');
});

test('hello sem room/clientId ou since negativo é bad_frame', () => {
  assert.deepEqual(parseClientFrame(JSON.stringify({ t: 'hello', since: 0, clientId: 'c1' })), { error: 'bad_frame' });
  assert.deepEqual(parseClientFrame(JSON.stringify({ t: 'hello', room: 'k7x2m9q', since: -1, clientId: 'c1' })), { error: 'bad_frame' });
  assert.deepEqual(parseClientFrame(JSON.stringify({ t: 'hello', room: 'k7x2m9q', since: 0 })), { error: 'bad_frame' });
});

test('start/set carregam snapshot validado; end não tem corpo', () => {
  assert.deepEqual(parseClientFrame(JSON.stringify({ t: 'start', snapshot })), { t: 'start', snapshot });
  assert.deepEqual(parseClientFrame(JSON.stringify({ t: 'set', snapshot })), { t: 'set', snapshot });
  assert.deepEqual(parseClientFrame(JSON.stringify({ t: 'end' })), { t: 'end' });
});

test('snapshot rejeita entradas malformadas, focusKey não-string e > 200 entradas', () => {
  const badEntry = { ...snapshot, entries: [{ id: 'abc' }] };
  assert.deepEqual(parseClientFrame(JSON.stringify({ t: 'set', snapshot: badEntry })), { error: 'bad_frame' });
  const badFocus = { ...snapshot, focusKey: 7 };
  assert.deepEqual(parseClientFrame(JSON.stringify({ t: 'set', snapshot: badFocus })), { error: 'bad_frame' });
  const tooMany = { ...snapshot, entries: Array.from({ length: MAX_ENTRIES + 1 }, (_, i) => ({ id: `e${i}`, kind: 'pdf' })) };
  assert.deepEqual(parseClientFrame(JSON.stringify({ t: 'set', snapshot: tooMany })), { error: 'too_large' });
});

test('JSON inválido, t desconhecido e frame sem t são bad_frame', () => {
  assert.deepEqual(parseClientFrame('{'), { error: 'bad_frame' });
  assert.deepEqual(parseClientFrame(JSON.stringify({ t: 'dance' })), { error: 'bad_frame' });
  assert.deepEqual(parseClientFrame(JSON.stringify({})), { error: 'bad_frame' });
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `npm test`
Expected: FAIL — módulo `./protocol.ts` não existe.

- [ ] **Step 3: Implementar**

```ts
// workers/plpcg-catalog/src/live/protocol.ts
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
```

- [ ] **Step 4: Rodar**

Run: `npm test && npm run typecheck`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add workers/plpcg-catalog/src/live/protocol.ts workers/plpcg-catalog/src/live/protocol.test.ts
git commit -m "feat(worker): protocolo da Lista ao Vivo — tipos e validação dos frames"
```

---

### Task 3: `RoomCore` — a sala como máquina de estados pura

**Files:**
- Create: `workers/plpcg-catalog/src/live/room_core.ts`
- Test: `workers/plpcg-catalog/src/live/room_core.test.ts`

**Interfaces:**
- Consumes: `protocol.ts` (Task 2).
- Produces:
  - `interface SocketAttachment { role: 'pending' | Role; clientId: string; sub?: string; nick?: string }`
  - `interface SocketPort { send(text: string): void; close(code: number, reason: string): void; attachment(): SocketAttachment | null; attach(a: SocketAttachment): void }`
  - `interface RoomStorage { get<T>(key: string): Promise<T | undefined>; put<T>(key: string, value: T): Promise<void>; delete(key: string): Promise<void>; setAlarm(at: number): Promise<void>; deleteAlarm(): Promise<void> }`
  - `interface RoomRecord { code; ownerSub; ownerName; status: RoomStatus; version: number; snapshot: Snapshot | null; leaderSeenAt: number | null; startedAt: number | null; endedAt: number | null }`
  - `interface RoomCoreDeps { storage: RoomStorage; sockets: () => SocketPort[]; authenticate: (token: string) => Promise<string | null>; now: () => number }`
  - `class RoomCore { init(input: { code; ownerSub; ownerName }); retire(); onOpen(socket); onMessage(socket, text); onClose(socket); onAlarm() }`
  - constantes `ALARM_INTERVAL_MS`, `LEADER_TTL_MS`, `ENDED_TTL_MS`, `CLOSE_ENDED = 4001`, `CLOSE_REPLACED = 4002`, `CLOSE_RETIRED = 4003`, `CLOSE_NOT_FOUND = 4004`, `ROOM_KEY = 'room'`.

- [ ] **Step 1: Fakes + testes**

```ts
// workers/plpcg-catalog/src/live/room_core.test.ts
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
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `npm test`
Expected: FAIL — `./room_core.ts` não existe.

- [ ] **Step 3: Implementar `room_core.ts`**

```ts
// workers/plpcg-catalog/src/live/room_core.ts
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
  constructor(private readonly deps: RoomCoreDeps) {}

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
```

- [ ] **Step 4: Rodar até verde**

Run: `npm test && npm run typecheck`
Expected: PASS em todos os 15 testes. Se `test('sala sem init…')` falhar por `room: ''`, confirmar que `sendError` recebe `room?.code ?? ''`.

- [ ] **Step 5: Commit**

```bash
git add workers/plpcg-catalog/src/live/room_core.ts workers/plpcg-catalog/src/live/room_core.test.ts
git commit -m "feat(worker): RoomCore — máquina de estados da sala ao vivo (hello, start/set/end, presença, alarms)"
```

---

### Task 4: Durable Object `LiveRoom` + rota WebSocket no roteador

**Files:**
- Create: `workers/plpcg-catalog/src/live/live_room.ts`
- Create: `workers/plpcg-catalog/src/live/authenticate_token.ts`
- Modify: `workers/plpcg-catalog/src/index.ts` (`Env`, `CorsMode`, `corsModeForPath`, `handleLive`, export)

**Interfaces:**
- Consumes: `RoomCore` (Task 3), `findSession`, `isSessionToken`, `verifyGoogleIdToken`.
- Produces: `export class LiveRoom extends DurableObject<Env>`; `authenticateToken(env, token): Promise<string | null>`; `Env.LIVE: DurableObjectNamespace`; rota `GET /api/live/:code/ws` (upgrade). As rotas HTTP `/api/live/room*` e `/ao-vivo/*` entram na Task 5 — aqui `handleLive` responde 404 para elas.

Sem teste em `node --test` (o módulo importa `cloudflare:workers`); a lógica está coberta na Task 3. Verificação: `npm run typecheck` + `npx wrangler check` + smoke com `wrangler dev` no Step 5.

- [ ] **Step 1: `authenticate_token.ts`**

```ts
// workers/plpcg-catalog/src/live/authenticate_token.ts
import { isSessionToken } from '../auth/session_token.ts';
import { findSession } from '../auth/user_sessions.ts';
import { verifyGoogleIdToken } from '../auth/verify_google_token.ts';

/**
 * `sub` de um Bearer (`sess_…` do Worker ou JWT do Google), ou `null` —
 * o mesmo critério de `withAuth`, sem `Request`/`Response`, para o `hello`
 * do WebSocket.
 */
export async function authenticateToken(
  env: { DB: D1Database; GOOGLE_CLIENT_ID_WEB: string },
  token: string,
): Promise<string | null> {
  if (isSessionToken(token)) {
    return (await findSession(env.DB, token))?.sub ?? null;
  }
  if (!env.GOOGLE_CLIENT_ID_WEB) return null;
  try {
    return (await verifyGoogleIdToken(token, env.GOOGLE_CLIENT_ID_WEB)).sub;
  } catch {
    return null;
  }
}
```

- [ ] **Step 2: `live_room.ts`**

```ts
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
```

- [ ] **Step 3: `index.ts`**

1. `Env`:

```ts
export interface Env {
  DB: D1Database;
  GOOGLE_CLIENT_ID_WEB: string;
  COLDIGOM_API_BASE_URL?: string;
  LIVE: DurableObjectNamespace;
}
```

2. `type CorsMode = 'catalog' | 'auth' | 'playlists' | 'social' | 'links' | 'live';` e em `corsHeaders`, antes do `else if (mode === 'auth')`:

```ts
    } else if (mode === 'live') {
      headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      headers.set('Access-Control-Allow-Headers', 'Authorization, Content-Type');
```

3. `corsModeForPath`: `if (pathname.startsWith('/api/live')) return 'live';` e `if (pathname.startsWith('/ao-vivo/')) return 'live';`.

4. Imports e handler (o corpo HTTP completo entra na Task 5):

```ts
import { isShortCode } from './short_code.ts';
export { LiveRoom } from './live/live_room.ts';

/** `/api/live/:code/ws` → código, ou `null`. */
function liveWsCodeFromPath(pathname: string): string | null {
  const match = /^\/api\/live\/([a-z0-9]{7})\/ws$/.exec(pathname);
  return match ? match[1] : null;
}

async function handleLive(request: Request, env: Env, pathname: string): Promise<Response> {
  const wsCode = liveWsCodeFromPath(pathname);
  if (wsCode !== null) {
    if (request.method !== 'GET') {
      return jsonResponse({ error: 'method not allowed' }, { status: 405 });
    }
    // Roteador magro: o upgrade vai inteiro para o DO da sala. A resposta 101
    // volta **sem** `withCors` — reconstruí-la mataria o `webSocket`.
    const stub = env.LIVE.get(env.LIVE.idFromName(wsCode));
    return stub.fetch(request);
  }
  return jsonResponse({ error: 'not found' }, { status: 404 });
}
```

5. No `fetch` default, antes do bloco `/api/coldigom/`:

```ts
    if (url.pathname.startsWith('/api/live')) {
      const response = await handleLive(request, env, url.pathname);
      return response.status === 101 ? response : withCors(response, request, 'live');
    }
```

- [ ] **Step 4: Typecheck e check**

Run: `npm run typecheck && npx wrangler check`
Expected: PASS; `wrangler check` lista o binding `LIVE` → `LiveRoom` e a migration `live-v1`. Se `DurableObject` reclamar do genérico `Env`, importar `Env` como `import type` (já é) e confirmar `"types": ["@cloudflare/workers-types"]` no `tsconfig.json`.

- [ ] **Step 5: Smoke local (manual, opcional mas recomendado)**

Run: `npx wrangler dev` e, noutro terminal, `npx wscat -c ws://localhost:8787/api/live/k7x2m9q/ws` (ou o cliente WS do browser em DevTools):
- Enviar `{"t":"hello","room":"k7x2m9q","since":0,"clientId":"c1"}` → resposta `{"t":"error","room":"","code":"not_found"}` e o socket fecha `4004` (sala nunca inicializada — esperado até a Task 5 criar salas).

- [ ] **Step 6: Commit**

```bash
git add workers/plpcg-catalog/src/live/live_room.ts workers/plpcg-catalog/src/live/authenticate_token.ts workers/plpcg-catalog/src/index.ts
git commit -m "feat(worker): Durable Object LiveRoom (Hibernation WS) e rota /api/live/:code/ws"
```

---

### Task 5: Rotas HTTP da sala — criar/regenerar (auth) e redirect `/ao-vivo/:code`

**Files:**
- Create: `workers/plpcg-catalog/src/live/handlers.ts`
- Test: `workers/plpcg-catalog/src/live/handlers.test.ts`
- Modify: `workers/plpcg-catalog/src/test/fake_d1.ts` — tabela `live_rooms`, `users.name`
- Modify: `workers/plpcg-catalog/src/index.ts` — `handleLive` completo, rota `/ao-vivo/*`

**Interfaces:**
- Consumes: `randomShortCode`, `isShortCode` (Task 1), `GoogleClaims`, `json` de `playlists/wire.ts`, `ORIGIN` de `links/handlers.ts`.
- Produces:
  - `interface LiveRoomNamespace { idFromName(name: string): unknown; get(id: unknown): { fetch(input: string, init?: RequestInit): Promise<Response> } }` — `DurableObjectNamespace` satisfaz por estrutura.
  - `ensureLiveRoom(db, live, claims): Promise<Response>` — `POST /api/live/room` → `200 { code, url, ownerName }`.
  - `regenerateLiveRoom(db, live, claims): Promise<Response>` — `POST /api/live/room/regenerate` → `200 { code, url, ownerName }`.
  - `liveRoomRedirect(pathname): Response` — `GET /ao-vivo/:code` → `302 ${ORIGIN}/?live=<code>` ou `404`.
  - `liveRoomUrl(code): string` = `https://plpcg.com/ao-vivo/<code>`.

- [ ] **Step 1: Estender o fake D1**

Em `src/test/fake_d1.ts`:

1. Tipo e opção:

```ts
/** Linha de `live_rooms` (chave `code`; `owner_sub` único). */
export interface LiveRoomRow {
  code: string;
  owner_sub: string;
  created_at: string;
}
```
Em `FakeD1Options`: `users?: Array<{ google_sub: string; username: string; name?: string }>;` e `liveRooms?: LiveRoomRow[];`.

2. Na classe: `readonly userNames = new Map<string, string>();` e `readonly liveRooms = new Map<string, LiveRoomRow>();`. No construtor: `for (const row of options.liveRooms ?? []) this.liveRooms.set(row.code, row);` e, no loop de `users`, `if (user.name) this.userNames.set(user.google_sub, user.name);`.

3. Despacho, logo após o bloco `user_sessions` em `runQuery`:

```ts
    // `live_rooms` tem chave `code` e índice único `owner_sub`.
    if (/live_rooms/i.test(normalized)) {
      return this.runLiveRooms(normalized, bindings);
    }
```

4. Método:

```ts
  /**
   * `live_rooms` (`live/handlers.ts`): SELECT por `owner_sub` ou por `code`,
   * INSERT com `ON CONFLICT DO NOTHING RETURNING code` (colisão de código ou
   * dono que já tem sala) e UPDATE do `code` por `owner_sub` (regenerar).
   */
  private runLiveRooms(normalized: string, bindings: unknown[]): unknown[] {
    if (/^SELECT/i.test(normalized)) {
      if (/owner_sub = \?/i.test(normalized)) {
        for (const row of this.liveRooms.values()) {
          if (row.owner_sub === bindings[0]) return [row];
        }
        return [];
      }
      const row = this.liveRooms.get(bindings[0] as string);
      return row ? [row] : [];
    }
    if (/^INSERT INTO/i.test(normalized)) {
      const { columns, values } = insertPlan(normalized);
      const cursor = { next: 0 };
      const row = {} as Record<string, unknown>;
      columns.forEach((column, i) => {
        row[column] = resolveToken(values[i], bindings, cursor, undefined);
      });
      const built = row as unknown as LiveRoomRow;
      if (this.liveRooms.has(built.code)) return [];
      for (const existing of this.liveRooms.values()) {
        if (existing.owner_sub === built.owner_sub) return [];
      }
      this.liveRooms.set(built.code, built);
      return [{ code: built.code }];
    }
    if (/^UPDATE/i.test(normalized)) {
      const ownerSub = bindings[bindings.length - 1] as string;
      const newCode = bindings[0] as string;
      for (const [code, row] of this.liveRooms) {
        if (row.owner_sub !== ownerSub) continue;
        this.liveRooms.delete(code);
        this.liveRooms.set(newCode, { ...row, code: newCode });
        return [{ code: newCode }];
      }
      return [];
    }
    throw new Error(`fake D1: live_rooms não suportado: ${normalized}`);
  }
```

5. `selectUsers` por `google_sub` passa a devolver também `name`:

```ts
    const sub = bindings[0] as string;
    const username = this.usernames.get(sub);
    if (username === undefined) return [];
    return [{ username, name: this.userNames.get(sub) ?? null }];
```

6. Atualizar a tabela de consultas no doc-comment do topo com as quatro formas de `live_rooms` e a coluna `name` de `users`.

- [ ] **Step 2: Testes dos handlers**

```ts
// workers/plpcg-catalog/src/live/handlers.test.ts
import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { FakeD1Database } from '../test/fake_d1.ts';
import type { LiveRoomNamespace } from './handlers.ts';
import { ensureLiveRoom, liveRoomRedirect, liveRoomUrl, regenerateLiveRoom } from './handlers.ts';

const claims = { sub: 'u1' } as never;

/** Namespace falso: grava cada `fetch` por nome de sala. */
function fakeLive() {
  const calls: Array<{ name: string; url: string; body: unknown }> = [];
  const live: LiveRoomNamespace = {
    idFromName: (name) => ({ name }),
    get: (id) => ({
      fetch: async (url, init) => {
        const body = init?.body ? JSON.parse(init.body as string) : null;
        calls.push({ name: (id as { name: string }).name, url, body });
        return new Response(null, { status: 204 });
      },
    }),
  };
  return { live, calls };
}

test('ensureLiveRoom cria a sala uma vez, inicializa o DO com o nome do dono e devolve a mesma sala depois', async () => {
  const db = new FakeD1Database([], { users: [{ google_sub: 'u1', username: 'fulano', name: 'Fulano Silva' }] });
  const { live, calls } = fakeLive();

  const first = await ensureLiveRoom(db as never, live, claims);
  assert.equal(first.status, 200);
  const json = (await first.json()) as { code: string; url: string; ownerName: string };
  assert.match(json.code, /^[a-z0-9]{7}$/);
  assert.equal(json.url, liveRoomUrl(json.code));
  assert.equal(json.ownerName, 'Fulano Silva');
  assert.deepEqual(calls[0], { name: json.code, url: 'https://live/init', body: { code: json.code, ownerSub: 'u1', ownerName: 'Fulano Silva' } });

  const second = await ensureLiveRoom(db as never, live, claims);
  const again = (await second.json()) as { code: string };
  assert.equal(again.code, json.code);
  assert.equal(db.liveRooms.size, 1);
  // Re-init idempotente: mantém o nome fresco sem criar linha.
  assert.equal(calls.length, 2);
});

test('ownerName cai para username e depois para «Gestor»', async () => {
  const { live } = fakeLive();
  const withUsername = new FakeD1Database([], { users: [{ google_sub: 'u1', username: 'fulano' }] });
  assert.equal(((await (await ensureLiveRoom(withUsername as never, live, claims)).json()) as { ownerName: string }).ownerName, 'fulano');
  const unknown = new FakeD1Database();
  assert.equal(((await (await ensureLiveRoom(unknown as never, live, claims)).json()) as { ownerName: string }).ownerName, 'Gestor');
});

test('regenerateLiveRoom troca o código, aposenta o DO antigo e inicializa o novo', async () => {
  const db = new FakeD1Database([], {
    users: [{ google_sub: 'u1', username: 'fulano', name: 'Fulano' }],
    liveRooms: [{ code: 'aaaaaaa', owner_sub: 'u1', created_at: '2026-09-14T00:00:00.000Z' }],
  });
  const { live, calls } = fakeLive();
  const response = await regenerateLiveRoom(db as never, live, claims);
  assert.equal(response.status, 200);
  const json = (await response.json()) as { code: string };
  assert.notEqual(json.code, 'aaaaaaa');
  assert.equal(db.liveRooms.has('aaaaaaa'), false);
  assert.equal(db.liveRooms.get(json.code)?.owner_sub, 'u1');
  assert.deepEqual(calls.map((c) => [c.name, c.url]), [['aaaaaaa', 'https://live/retire'], [json.code, 'https://live/init']]);
});

test('regenerateLiveRoom sem sala existente cria uma (equivale a ensure)', async () => {
  const db = new FakeD1Database([], { users: [{ google_sub: 'u1', username: 'fulano' }] });
  const { live, calls } = fakeLive();
  const response = await regenerateLiveRoom(db as never, live, claims);
  assert.equal(response.status, 200);
  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, 'https://live/init');
});

test('liveRoomRedirect: 302 para a raiz com ?live=, 404 fora do formato', () => {
  const ok = liveRoomRedirect('/ao-vivo/k7x2m9q');
  assert.equal(ok.status, 302);
  assert.equal(ok.headers.get('Location'), 'https://plpcg.com/?live=k7x2m9q');
  assert.equal(ok.headers.get('Cache-Control'), 'no-store');
  assert.equal(liveRoomRedirect('/ao-vivo/K7X2M9Q').status, 404);
  assert.equal(liveRoomRedirect('/ao-vivo/').status, 404);
  assert.equal(liveRoomRedirect('/ao-vivo/k7x2m9q/extra').status, 404);
});
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `npm test`
Expected: FAIL — `./handlers.ts` (em `live/`) não existe.

- [ ] **Step 4: Implementar `live/handlers.ts`**

```ts
// workers/plpcg-catalog/src/live/handlers.ts
/**
 * Rotas HTTP da Lista ao Vivo (spec 2026-09-12-lista-ao-vivo, §4.1).
 *
 * `POST /api/live/room` (auth) cria-ou-devolve a sala permanente do `sub`;
 * `POST /api/live/room/regenerate` (auth) troca o código (quem tinha o antigo
 * é expulso); `GET /ao-vivo/:code` (público) é um 302 para a app. O estado
 * vivo mora no DO — D1 só liga `code` ↔ `owner_sub`.
 */
import type { GoogleClaims } from '../auth/verify_google_token';
import { ORIGIN } from '../links/handlers.ts';
import { json } from '../playlists/wire.ts';
import { isShortCode, randomShortCode } from '../short_code.ts';

/** Só o que os handlers usam de `DurableObjectNamespace` — testável com um fake. */
export interface LiveRoomNamespace {
  idFromName(name: string): unknown;
  get(id: unknown): { fetch(input: string, init?: RequestInit): Promise<Response> };
}

export interface LiveRoomJson {
  code: string;
  url: string;
  ownerName: string;
}

const MAX_CODE_ATTEMPTS = 5;

export function liveRoomUrl(code: string): string {
  return `${ORIGIN}/ao-vivo/${code}`;
}

async function ownerNameOf(db: D1Database, sub: string): Promise<string> {
  const row = await db
    .prepare(`SELECT name, username FROM users WHERE google_sub = ?`)
    .bind(sub)
    .first<{ name: string | null; username: string | null }>();
  return row?.name?.trim() || row?.username?.trim() || 'Gestor';
}

async function initRoom(live: LiveRoomNamespace, code: string, ownerSub: string, ownerName: string): Promise<void> {
  await live.get(live.idFromName(code)).fetch('https://live/init', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ code, ownerSub, ownerName }),
  });
}

async function retireRoom(live: LiveRoomNamespace, code: string): Promise<void> {
  await live.get(live.idFromName(code)).fetch('https://live/retire', { method: 'POST' });
}

async function findRoomCode(db: D1Database, sub: string): Promise<string | null> {
  const row = await db
    .prepare(`SELECT code FROM live_rooms WHERE owner_sub = ?`)
    .bind(sub)
    .first<{ code: string }>();
  return row?.code ?? null;
}

async function insertRoom(db: D1Database, sub: string): Promise<string | null> {
  for (let attempt = 0; attempt < MAX_CODE_ATTEMPTS; attempt++) {
    const code = randomShortCode();
    const row = await db
      .prepare(
        `INSERT INTO live_rooms (code, owner_sub, created_at) VALUES (?, ?, ?)
         ON CONFLICT DO NOTHING RETURNING code`,
      )
      .bind(code, sub, new Date().toISOString())
      .first<{ code: string }>();
    if (row) return row.code;
    // Sem linha: ou o `code` colidiu (tenta outro) ou o dono já tem sala
    // (corrida entre dois POSTs) — nesse caso devolve a que venceu.
    const raced = await findRoomCode(db, sub);
    if (raced) return raced;
  }
  return null;
}

/** `POST /api/live/room` — cria (ou devolve) a sala do usuário e inicializa o DO. */
export async function ensureLiveRoom(
  db: D1Database,
  live: LiveRoomNamespace,
  claims: GoogleClaims,
): Promise<Response> {
  const ownerName = await ownerNameOf(db, claims.sub);
  const code = (await findRoomCode(db, claims.sub)) ?? (await insertRoom(db, claims.sub));
  if (!code) return json({ error: 'não foi possível gerar um código' }, 500);
  // Idempotente no DO: numa sala existente só atualiza `ownerName`.
  await initRoom(live, code, claims.sub, ownerName);
  return json({ code, url: liveRoomUrl(code), ownerName } satisfies LiveRoomJson, 200);
}

/** `POST /api/live/room/regenerate` — novo código; o DO antigo é aposentado. */
export async function regenerateLiveRoom(
  db: D1Database,
  live: LiveRoomNamespace,
  claims: GoogleClaims,
): Promise<Response> {
  const previous = await findRoomCode(db, claims.sub);
  if (previous === null) return ensureLiveRoom(db, live, claims);

  const ownerName = await ownerNameOf(db, claims.sub);
  for (let attempt = 0; attempt < MAX_CODE_ATTEMPTS; attempt++) {
    const code = randomShortCode();
    const row = await db
      .prepare(`UPDATE live_rooms SET code = ? WHERE owner_sub = ? RETURNING code`)
      .bind(code, claims.sub)
      .first<{ code: string }>();
    if (!row) continue;
    await retireRoom(live, previous);
    await initRoom(live, row.code, claims.sub, ownerName);
    return json({ code: row.code, url: liveRoomUrl(row.code), ownerName } satisfies LiveRoomJson, 200);
  }
  return json({ error: 'não foi possível gerar um código' }, 500);
}

/** `GET /ao-vivo/:code` — 302 para a app (`/?live=<code>`), sem tocar em D1. */
export function liveRoomRedirect(pathname: string): Response {
  const match = /^\/ao-vivo\/([^/]+)$/.exec(pathname);
  const code = match?.[1];
  if (!isShortCode(code)) return new Response(null, { status: 404 });
  return new Response(null, {
    status: 302,
    headers: { Location: `${ORIGIN}/?live=${code}`, 'Cache-Control': 'no-store' },
  });
}
```

Nota sobre o `UPDATE … RETURNING`: com a colisão de `code` (PK) o D1 lança em vez de devolver 0 linhas. Envolver o `first()` em `try { … } catch { continue; }` dentro do loop — e o fake do Step 1 devolve `[]` quando não acha o dono, o que também cai no `continue`.

- [ ] **Step 5: Completar `handleLive` e a rota `/ao-vivo/*` em `index.ts`**

```ts
import { ensureLiveRoom, liveRoomRedirect, regenerateLiveRoom } from './live/handlers.ts';
```

`handleLive` completo:

```ts
async function handleLive(request: Request, env: Env, pathname: string): Promise<Response> {
  const wsCode = liveWsCodeFromPath(pathname);
  if (wsCode !== null) {
    if (request.method !== 'GET') {
      return jsonResponse({ error: 'method not allowed' }, { status: 405 });
    }
    const stub = env.LIVE.get(env.LIVE.idFromName(wsCode));
    return stub.fetch(request);
  }
  if (pathname === '/api/live/room' || pathname === '/api/live/room/regenerate') {
    if (request.method !== 'POST') {
      return jsonResponse({ error: 'method not allowed' }, { status: 405 });
    }
    const handler = pathname.endsWith('/regenerate') ? regenerateLiveRoom : ensureLiveRoom;
    return withAuth(request, env, (_req, e, claims) => handler(e.DB, (e as Env).LIVE, claims));
  }
  return jsonResponse({ error: 'not found' }, { status: 404 });
}
```

E no `fetch`, junto do bloco `/l/`:

```ts
    if (url.pathname.startsWith('/ao-vivo/')) {
      if (request.method !== 'GET') {
        return withCors(jsonResponse({ error: 'method not allowed' }, { status: 405 }), request, 'live');
      }
      return withCors(liveRoomRedirect(url.pathname), request, 'live');
    }
```

- [ ] **Step 6: Verde**

Run: `npm test && npm run typecheck && npx wrangler check`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add workers/plpcg-catalog/src/live/handlers.ts workers/plpcg-catalog/src/live/handlers.test.ts workers/plpcg-catalog/src/test/fake_d1.ts workers/plpcg-catalog/src/index.ts
git commit -m "feat(worker): POST /api/live/room[/regenerate] e redirect /ao-vivo/:code"
```

---

### Task 6: README do Worker, deploy e verificação em produção

**Files:**
- Modify: `workers/plpcg-catalog/README.md`

- [ ] **Step 1: Documentar**

Acrescentar ao README, na seção de rotas, e uma seção «Lista ao Vivo»:

```markdown
## Lista ao Vivo (Durable Object `LiveRoom`)

| Rota | Auth | O quê |
|---|---|---|
| `POST /api/live/room` | Bearer | Cria-ou-devolve a sala permanente do usuário: `{ code, url, ownerName }` |
| `POST /api/live/room/regenerate` | Bearer | Novo código; quem tinha o antigo recebe `ended{retired}` e `4003` |
| `GET /api/live/:code/ws` | — (papel no `hello`) | Upgrade WebSocket, encaminhado ao DO `LIVE.idFromName(code)` |
| `GET /ao-vivo/:code` | — | `302 https://plpcg.com/?live=<code>` |

Protocolo e regras: `docs/superpowers/specs/2026-09-12-lista-ao-vivo-design.md` §5 (Fase 1: `hello`, `start`, `set`, `end` → `room`, `snapshot`, `presence`, `ack`, `ended`, `error`). A lógica está em `src/live/room_core.ts` (testada com fakes); `src/live/live_room.ts` é a casca do DO.

Deploy: `npm run db:migrate:remote` (migration `0013_create_live_rooms.sql`) **antes** de `npm run deploy` — o primeiro deploy aplica a migration `live-v1` (`new_sqlite_classes`) do wrangler. Um deploy fecha todos os WebSockets abertos; os clientes religam sozinhos com jitter.
```

- [ ] **Step 2: Deploy (pedir confirmação ao usuário antes)**

Run: `npm run db:migrate:remote && npm run deploy`
Expected: migration `0013` aplicada; deploy lista `LiveRoom` como Durable Object.

- [ ] **Step 3: Verificar em produção**

- `curl -I https://plpcg.com/ao-vivo/k7x2m9q` → `302` com `Location: https://plpcg.com/?live=k7x2m9q`.
- `curl -X POST https://plpcg.com/api/live/room` → `401`.
- Com um token de sessão real (DevTools → `localStorage['plpcg_auth_session']` em v2.plpcg.com): `curl -X POST -H "Authorization: Bearer sess_…" https://plpcg.com/api/live/room` → `200 { code, url, ownerName }`.
- `npx wscat -c wss://plpcg.com/api/live/<code>/ws`, enviar `{"t":"hello","room":"<code>","since":0,"clientId":"x"}` → `room{status:"idle", ownerName:…}`.

- [ ] **Step 4: Commit**

```bash
git add workers/plpcg-catalog/README.md
git commit -m "docs(worker): rotas e deploy da Lista ao Vivo"
```

---

## Parte 2 — App Flutter

### Task 7: Entidades, frames Dart e porta de transporte (+ `web_socket_channel`)

**Files:**
- Modify: `pubspec.yaml` — `web_socket_channel: ^3.0.0` em `dependencies`.
- Create: `lib/features/live/domain/entities/live_snapshot.dart`
- Create: `lib/features/live/domain/protocol/live_frames.dart`
- Create: `lib/features/live/domain/ports/live_transport.dart`
- Create: `lib/features/live/data/live_transport_ws.dart`
- Create: `test/support/fakes/fake_live_transport.dart`
- Test: `test/unit/features/live/live_frames_test.dart`

**Interfaces:**
- Produces:
  - `enum LiveRoomStatus { idle, scheduled, live, ended, retired }` + `liveRoomStatusFromWire(String) → LiveRoomStatus?`
  - `class LiveSnapshot { playlistId, name, entries: List<PlaylistEntry>, focusKey: String?; toJson(); static fromJson(Map) }`
  - `enum LiveRole { leader, consumer }`, `enum LiveEndReason { leader, inactivity, replaced, expired, retired }`
  - `sealed class LiveServerFrame { room }` com `LiveRoomFrame`, `LiveSnapshotFrame`, `LivePresenceFrame`, `LiveAckFrame`, `LiveEndedFrame`, `LiveErrorFrame`; `decodeLiveServerFrame(String) → LiveServerFrame?`
  - `encodeLiveHello({room, since, clientId, sessionToken})`, `encodeLiveStart(LiveSnapshot)`, `encodeLiveSet(LiveSnapshot)`, `encodeLiveEnd()` → `String`
  - `abstract class LiveConnection { Stream<String> get messages; void send(String); Future<void> close({int code = 1000}); Future<LiveDisconnect> get done }`, `class LiveDisconnect { int? code }`
  - `abstract class LiveTransport { Future<LiveConnection> connect(Uri uri) }` (lança em falha de handshake)
  - `class WebSocketLiveTransport implements LiveTransport`
  - `class FakeLiveTransport implements LiveTransport` (teste) com `connections`, `failNext(int n)`, `FakeLiveConnection.emit(String)`, `.sent`, `.closedWith`, `.drop({int code = 1006})`.

- [ ] **Step 1: Testes dos frames**

```dart
// test/unit/features/live/live_frames_test.dart
import 'dart:convert';

import 'package:coldigui/features/live/domain/entities/live_snapshot.dart';
import 'package:coldigui/features/live/domain/protocol/live_frames.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const snapshotJson = {
    'playlistId': 'p1',
    'name': 'Culto',
    'entries': [
      {'id': 'abc', 'kind': 'pdf'},
      {'id': 'abc', 'kind': 'pdf'},
      {'id': 'trk', 'kind': 'audio'},
    ],
    'focusKey': 'abc#1',
  };

  test('room frame decodifica status, papel, snapshot e presença', () {
    final frame = decodeLiveServerFrame(
      jsonEncode({
        't': 'room', 'room': 'k7x2m9q', 'status': 'live', 'ownerName': 'Fulano',
        'role': 'consumer', 'version': 4, 'snapshot': snapshotJson,
        'leaderPresent': true, 'viewers': 12,
      }),
    );
    expect(frame, isA<LiveRoomFrame>());
    final room = frame! as LiveRoomFrame;
    expect(room.room, 'k7x2m9q');
    expect(room.status, LiveRoomStatus.live);
    expect(room.role, LiveRole.consumer);
    expect(room.version, 4);
    expect(room.snapshot!.entries, [
      const PlaylistEntry(id: 'abc', kind: MaterialKind.pdf),
      const PlaylistEntry(id: 'abc', kind: MaterialKind.pdf),
      const PlaylistEntry(id: 'trk', kind: MaterialKind.audio),
    ]);
    expect(room.snapshot!.focusKey, 'abc#1');
    expect(room.leaderPresent, isTrue);
    expect(room.viewers, 12);
  });

  test('snapshot, presence, ack, ended e error decodificam', () {
    expect(
      decodeLiveServerFrame(jsonEncode({'t': 'snapshot', 'room': 'r', 'version': 5, 'snapshot': snapshotJson, 'viewers': 3})),
      isA<LiveSnapshotFrame>().having((f) => f.version, 'version', 5),
    );
    expect(
      decodeLiveServerFrame(jsonEncode({'t': 'presence', 'room': 'r', 'leaderPresent': false, 'viewers': 2})),
      isA<LivePresenceFrame>().having((f) => f.leaderPresent, 'leaderPresent', false),
    );
    expect(
      decodeLiveServerFrame(jsonEncode({'t': 'ack', 'room': 'r', 'version': 6, 'viewers': 2})),
      isA<LiveAckFrame>().having((f) => f.version, 'version', 6),
    );
    expect(
      decodeLiveServerFrame(jsonEncode({'t': 'ended', 'room': 'r', 'reason': 'inactivity'})),
      isA<LiveEndedFrame>().having((f) => f.reason, 'reason', LiveEndReason.inactivity),
    );
    expect(
      decodeLiveServerFrame(jsonEncode({'t': 'error', 'room': 'r', 'code': 'not_leader'})),
      isA<LiveErrorFrame>().having((f) => f.code, 'code', 'not_leader'),
    );
  });

  test('frames malformados, sem room ou de tipo desconhecido viram null', () {
    expect(decodeLiveServerFrame('{'), isNull);
    expect(decodeLiveServerFrame('pong'), isNull);
    expect(decodeLiveServerFrame(jsonEncode({'t': 'ack', 'version': 1})), isNull);
    expect(decodeLiveServerFrame(jsonEncode({'t': 'party', 'room': 'r'})), isNull);
    expect(decodeLiveServerFrame(jsonEncode({'t': 'room', 'room': 'r', 'status': 'weird'})), isNull);
  });

  test('encoders produzem o JSON que o DO valida', () {
    expect(
      jsonDecode(encodeLiveHello(room: 'k7x2m9q', since: 3, clientId: 'c1')),
      {'t': 'hello', 'room': 'k7x2m9q', 'since': 3, 'clientId': 'c1'},
    );
    expect(
      jsonDecode(encodeLiveHello(room: 'k7x2m9q', since: 0, clientId: 'c1', sessionToken: 'sess_x')),
      {'t': 'hello', 'room': 'k7x2m9q', 'since': 0, 'clientId': 'c1', 'sessionToken': 'sess_x'},
    );
    final snapshot = LiveSnapshot.fromJson(snapshotJson);
    expect(jsonDecode(encodeLiveStart(snapshot)), {'t': 'start', 'snapshot': snapshotJson});
    expect(jsonDecode(encodeLiveSet(snapshot)), {'t': 'set', 'snapshot': snapshotJson});
    expect(jsonDecode(encodeLiveEnd()), {'t': 'end'});
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/live/live_frames_test.dart`
Expected: FAIL — imports não resolvem.

- [ ] **Step 3: `pubspec.yaml`**

Em `dependencies`, depois de `url_launcher`: `web_socket_channel: ^3.0.0`. Rodar `flutter pub get`.

- [ ] **Step 4: Entidades**

```dart
// lib/features/live/domain/entities/live_snapshot.dart
import '../../../playlists/domain/entities/playlist_entry.dart';

export '../../../playlists/domain/entities/playlist_entry.dart';

/// Estado da sala no DO (spec 2026-09-12-lista-ao-vivo, D8). `scheduled` só
/// existe a partir da Fase 2; `retired` é a sala cujo link foi regenerado.
enum LiveRoomStatus { idle, scheduled, live, ended, retired }

LiveRoomStatus? liveRoomStatusFromWire(Object? raw) {
  if (raw is! String) return null;
  for (final status in LiveRoomStatus.values) {
    if (status.name == raw) return status;
  }
  return null;
}

enum LiveRole { leader, consumer }

enum LiveEndReason { leader, inactivity, replaced, expired, retired }

/// A lista do gestor como o DO a guarda: inteira, tipada, com o foco por
/// **chave de ocorrência** (`entryKeyFor`) — a mesma que a lista ativa usa.
final class LiveSnapshot {
  LiveSnapshot({
    required this.playlistId,
    required this.name,
    required List<PlaylistEntry> entries,
    required this.focusKey,
  }) : entries = List<PlaylistEntry>.unmodifiable(entries);

  final String playlistId;
  final String name;
  final List<PlaylistEntry> entries;
  final String? focusKey;

  Map<String, Object?> toJson() => {
    'playlistId': playlistId,
    'name': name,
    'entries': [for (final e in entries) e.toJson()],
    'focusKey': focusKey,
  };

  /// Lança [FormatException] se faltar `playlistId`/`entries`.
  static LiveSnapshot fromJson(Map<String, Object?> json) {
    final playlistId = json['playlistId'];
    final entries = json['entries'];
    if (playlistId is! String || entries is! List) {
      throw FormatException('LiveSnapshot inválido: $json');
    }
    return LiveSnapshot(
      playlistId: playlistId,
      name: json['name'] as String? ?? '',
      entries: [for (final raw in entries) PlaylistEntry.fromJson(raw as Object)],
      focusKey: json['focusKey'] as String?,
    );
  }

  LiveSnapshot copyWith({List<PlaylistEntry>? entries, String? focusKey, bool clearFocus = false}) =>
      LiveSnapshot(
        playlistId: playlistId,
        name: name,
        entries: entries ?? this.entries,
        focusKey: clearFocus ? null : (focusKey ?? this.focusKey),
      );
}
```

- [ ] **Step 5: Frames**

```dart
// lib/features/live/domain/protocol/live_frames.dart
import 'dart:convert';

import '../entities/live_snapshot.dart';

/// Frames DO → cliente (spec §5, Fase 1). Todo frame leva [room]; o controller
/// descarta os de sala diferente da atual.
sealed class LiveServerFrame {
  const LiveServerFrame(this.room);
  final String room;
}

final class LiveRoomFrame extends LiveServerFrame {
  const LiveRoomFrame(super.room, {
    required this.status, required this.ownerName, required this.role,
    required this.version, required this.snapshot, required this.leaderPresent, required this.viewers,
  });
  final LiveRoomStatus status;
  final String ownerName;
  final LiveRole role;
  final int version;
  final LiveSnapshot? snapshot;
  final bool leaderPresent;
  final int viewers;
}

final class LiveSnapshotFrame extends LiveServerFrame {
  const LiveSnapshotFrame(super.room, {required this.version, required this.snapshot, required this.viewers});
  final int version;
  final LiveSnapshot snapshot;
  final int viewers;
}

final class LivePresenceFrame extends LiveServerFrame {
  const LivePresenceFrame(super.room, {required this.leaderPresent, required this.viewers});
  final bool leaderPresent;
  final int viewers;
}

final class LiveAckFrame extends LiveServerFrame {
  const LiveAckFrame(super.room, {required this.version, required this.viewers});
  final int version;
  final int viewers;
}

final class LiveEndedFrame extends LiveServerFrame {
  const LiveEndedFrame(super.room, {required this.reason});
  final LiveEndReason reason;
}

final class LiveErrorFrame extends LiveServerFrame {
  const LiveErrorFrame(super.room, {required this.code});
  /// `bad_frame | not_leader | not_live | too_large | not_found | unauthorized`.
  final String code;
}

/// `null` para qualquer coisa que não seja um frame conhecido e bem formado —
/// inclusive o `pong` do ping de prova de vida.
LiveServerFrame? decodeLiveServerFrame(String text) {
  Object? raw;
  try {
    raw = jsonDecode(text);
  } on FormatException {
    return null;
  }
  if (raw is! Map<String, Object?>) return null;
  final room = raw['room'];
  if (room is! String) return null;
  try {
    switch (raw['t']) {
      case 'room':
        final status = liveRoomStatusFromWire(raw['status']);
        final role = raw['role'] == 'leader' ? LiveRole.leader : raw['role'] == 'consumer' ? LiveRole.consumer : null;
        if (status == null || role == null) return null;
        final snapshotRaw = raw['snapshot'];
        return LiveRoomFrame(room,
          status: status,
          ownerName: raw['ownerName'] as String? ?? '',
          role: role,
          version: raw['version'] as int,
          snapshot: snapshotRaw is Map<String, Object?> ? LiveSnapshot.fromJson(snapshotRaw) : null,
          leaderPresent: raw['leaderPresent'] == true,
          viewers: raw['viewers'] as int? ?? 0,
        );
      case 'snapshot':
        return LiveSnapshotFrame(room,
          version: raw['version'] as int,
          snapshot: LiveSnapshot.fromJson(raw['snapshot'] as Map<String, Object?>),
          viewers: raw['viewers'] as int? ?? 0,
        );
      case 'presence':
        return LivePresenceFrame(room, leaderPresent: raw['leaderPresent'] == true, viewers: raw['viewers'] as int? ?? 0);
      case 'ack':
        return LiveAckFrame(room, version: raw['version'] as int, viewers: raw['viewers'] as int? ?? 0);
      case 'ended':
        final reason = LiveEndReason.values.where((r) => r.name == raw['reason']).firstOrNull;
        return reason == null ? null : LiveEndedFrame(room, reason: reason);
      case 'error':
        final code = raw['code'];
        return code is String ? LiveErrorFrame(room, code: code) : null;
      default:
        return null;
    }
  } on TypeError {
    return null;
  } on FormatException {
    return null;
  }
}

String encodeLiveHello({required String room, required int since, required String clientId, String? sessionToken}) =>
    jsonEncode({
      't': 'hello', 'room': room, 'since': since, 'clientId': clientId,
      if (sessionToken != null && sessionToken.isNotEmpty) 'sessionToken': sessionToken,
    });

String encodeLiveStart(LiveSnapshot snapshot) => jsonEncode({'t': 'start', 'snapshot': snapshot.toJson()});

String encodeLiveSet(LiveSnapshot snapshot) => jsonEncode({'t': 'set', 'snapshot': snapshot.toJson()});

String encodeLiveEnd() => jsonEncode({'t': 'end'});
```

- [ ] **Step 6: Porta e implementação WebSocket**

```dart
// lib/features/live/domain/ports/live_transport.dart
/// Por que a conexão fechou. [code] `null` = erro sem close frame.
final class LiveDisconnect {
  const LiveDisconnect({this.code, this.reason});
  final int? code;
  final String? reason;
}

/// Uma conexão aberta com a sala.
abstract class LiveConnection {
  /// Mensagens de texto do servidor (JSON dos frames, ou `pong`).
  Stream<String> get messages;

  void send(String text);

  /// Fecha com [code] (1000 = saída limpa). Idempotente.
  Future<void> close({int code = 1000, String? reason});

  /// Completa quando o socket fecha por qualquer motivo (inclusive [close]).
  Future<LiveDisconnect> get done;
}

/// Abre conexões. [connect] **lança** quando o handshake falha — é o que o
/// controller conta para chegar a `unavailable` (spec D5).
abstract class LiveTransport {
  Future<LiveConnection> connect(Uri uri);
}
```

```dart
// lib/features/live/data/live_transport_ws.dart
import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../domain/ports/live_transport.dart';

/// [LiveTransport] sobre `web_socket_channel` — o mesmo código em web, iOS e
/// Android (o pacote escolhe `WebSocket` do browser ou `dart:io`).
class WebSocketLiveTransport implements LiveTransport {
  const WebSocketLiveTransport({this.handshakeTimeout = const Duration(seconds: 10)});

  final Duration handshakeTimeout;

  @override
  Future<LiveConnection> connect(Uri uri) async {
    final channel = WebSocketChannel.connect(uri);
    // `ready` rejeita no handshake recusado; o timeout cobre a rede que engole
    // o upgrade sem responder (proxy que bloqueia WS).
    await channel.ready.timeout(handshakeTimeout);
    return _WsConnection(channel);
  }
}

class _WsConnection implements LiveConnection {
  _WsConnection(this._channel) {
    _messages = _channel.stream.map((data) => data.toString()).asBroadcastStream();
    _messages.listen(
      null,
      onError: (_) => _finish(),
      onDone: _finish,
      cancelOnError: false,
    );
  }

  final WebSocketChannel _channel;
  late final Stream<String> _messages;
  final _done = Completer<LiveDisconnect>();

  void _finish() {
    if (_done.isCompleted) return;
    _done.complete(LiveDisconnect(code: _channel.closeCode, reason: _channel.closeReason));
  }

  @override
  Stream<String> get messages => _messages;

  @override
  void send(String text) => _channel.sink.add(text);

  @override
  Future<void> close({int code = 1000, String? reason}) async {
    await _channel.sink.close(code, reason);
    _finish();
  }

  @override
  Future<LiveDisconnect> get done => _done.future;
}
```

- [ ] **Step 7: Fake de teste**

```dart
// test/support/fakes/fake_live_transport.dart
import 'dart:async';

import 'package:coldigui/features/live/domain/ports/live_transport.dart';

/// Conexão de mentira: o teste **emite** frames do "servidor" e lê o que o
/// controller mandou.
class FakeLiveConnection implements LiveConnection {
  FakeLiveConnection(this.uri);

  final Uri uri;
  final _controller = StreamController<String>.broadcast();
  final _done = Completer<LiveDisconnect>();
  final List<String> sent = [];
  int? closedWith;

  @override
  Stream<String> get messages => _controller.stream;

  @override
  void send(String text) => sent.add(text);

  @override
  Future<void> close({int code = 1000, String? reason}) async {
    if (closedWith != null) return;
    closedWith = code;
    await _controller.close();
    if (!_done.isCompleted) _done.complete(LiveDisconnect(code: code));
  }

  @override
  Future<LiveDisconnect> get done => _done.future;

  /// O servidor falou.
  void emit(String text) => _controller.add(text);

  /// A rede caiu (ou o servidor fechou com [code]) — sem `close()` do cliente.
  Future<void> drop({int code = 1006}) async {
    if (closedWith != null) return;
    closedWith = code;
    await _controller.close();
    if (!_done.isCompleted) _done.complete(LiveDisconnect(code: code));
  }

  bool get isOpen => closedWith == null;
}

class FakeLiveTransport implements LiveTransport {
  final List<FakeLiveConnection> connections = [];
  int _failNext = 0;
  int attempts = 0;

  /// As próximas [n] tentativas de `connect` lançam (handshake recusado).
  void failNext(int n) => _failNext = n;

  FakeLiveConnection get last => connections.last;

  @override
  Future<LiveConnection> connect(Uri uri) async {
    attempts++;
    if (_failNext > 0) {
      _failNext--;
      throw StateError('handshake recusado');
    }
    final connection = FakeLiveConnection(uri);
    connections.add(connection);
    return connection;
  }
}
```

- [ ] **Step 8: Verde**

Run: `flutter test test/unit/features/live/live_frames_test.dart && dart format lib/features/live test/support/fakes/fake_live_transport.dart test/unit/features/live`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/live/domain lib/features/live/data/live_transport_ws.dart test/support/fakes/fake_live_transport.dart test/unit/features/live/live_frames_test.dart
git commit -m "feat(live): entidades, frames do protocolo e transporte WebSocket"
```

---

### Task 8: Política de reconexão e parse do link da sala (puros)

**Files:**
- Create: `lib/features/live/domain/live_reconnect_policy.dart`
- Create: `lib/features/live/domain/live_room_link.dart`
- Test: `test/unit/features/live/live_reconnect_policy_test.dart`
- Test: `test/unit/features/live/live_room_link_test.dart`

**Interfaces:**
- Produces:
  - `class LiveReconnectPolicy { const LiveReconnectPolicy({Random? random}); Duration delayFor(int attempt) }` — `attempt` 0-based: base `1s << attempt` limitado a 30 s, mais jitter `[0, 1 s)`.
  - `const int kLiveMaxHandshakeFailures = 3;`
  - `String? parseLiveRoomCode(Uri uri)` — `/ao-vivo/<code>` ou `?live=<code>`; `null` fora de `^[a-z0-9]{7}$`.
  - `String liveRoomShareUrl(String code)` → `https://plpcg.com/ao-vivo/<code>` (host de `AppConfig.apiBaseUrl`; fallback `plpcg.com`).
  - `String liveRoomRouteFor(String code)` → `/ao-vivo/<code>`.

- [ ] **Step 1: Testes**

```dart
// test/unit/features/live/live_reconnect_policy_test.dart
import 'dart:math';

import 'package:coldigui/features/live/domain/live_reconnect_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backoff 1, 2, 4, 8, 16, 30, 30 s (sem jitter)', () {
    final policy = LiveReconnectPolicy(random: _ZeroRandom());
    expect([0, 1, 2, 3, 4, 5, 9].map(policy.delayFor).map((d) => d.inSeconds), [1, 2, 4, 8, 16, 30, 30]);
  });

  test('jitter fica abaixo de 1 s', () {
    final policy = LiveReconnectPolicy(random: Random(7));
    for (var i = 0; i < 20; i++) {
      final d = policy.delayFor(2);
      expect(d, greaterThanOrEqualTo(const Duration(seconds: 4)));
      expect(d, lessThan(const Duration(seconds: 5)));
    }
  });
}

class _ZeroRandom implements Random {
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
  @override
  int nextInt(int max) => 0;
}
```

```dart
// test/unit/features/live/live_room_link_test.dart
import 'package:coldigui/features/live/domain/live_room_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reconhece o path /ao-vivo/<code> e a query ?live=', () {
    expect(parseLiveRoomCode(Uri.parse('https://plpcg.com/ao-vivo/k7x2m9q')), 'k7x2m9q');
    expect(parseLiveRoomCode(Uri.parse('https://plpcg.com/?live=k7x2m9q')), 'k7x2m9q');
    expect(parseLiveRoomCode(Uri.parse('plpcg:///?live=k7x2m9q')), 'k7x2m9q');
    expect(parseLiveRoomCode(Uri.parse('https://plpcg.com/?live=k7x2m9q&s=abc')), 'k7x2m9q');
  });

  test('rejeita formato errado e URLs sem código', () {
    expect(parseLiveRoomCode(Uri.parse('https://plpcg.com/ao-vivo/K7X2M9Q')), isNull);
    expect(parseLiveRoomCode(Uri.parse('https://plpcg.com/ao-vivo/')), isNull);
    expect(parseLiveRoomCode(Uri.parse('https://plpcg.com/?live=')), isNull);
    expect(parseLiveRoomCode(Uri.parse('https://plpcg.com/?s=abc')), isNull);
  });

  test('rota interna e URL de partilha', () {
    expect(liveRoomRouteFor('k7x2m9q'), '/ao-vivo/k7x2m9q');
    expect(liveRoomShareUrl('k7x2m9q'), 'https://plpcg.com/ao-vivo/k7x2m9q');
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/live/`
Expected: FAIL nos dois arquivos novos.

- [ ] **Step 3: Implementar**

```dart
// lib/features/live/domain/live_reconnect_policy.dart
import 'dart:math';

/// Falhas seguidas de handshake ao **entrar** antes de `unavailable` (D5).
const int kLiveMaxHandshakeFailures = 3;

/// Backoff exponencial 1 → 30 s com jitter de até 1 s — o jitter espalha a
/// reconexão em massa depois de um deploy do Worker (§7).
class LiveReconnectPolicy {
  LiveReconnectPolicy({Random? random}) : _random = random ?? Random();

  final Random _random;

  static const _base = Duration(seconds: 1);
  static const _cap = Duration(seconds: 30);

  Duration delayFor(int attempt) {
    final exponent = attempt.clamp(0, 10);
    final base = _base * (1 << exponent);
    final capped = base > _cap ? _cap : base;
    return capped + Duration(milliseconds: _random.nextInt(1000));
  }
}
```

```dart
// lib/features/live/domain/live_room_link.dart
import '../../../core/constants/app_config.dart';
import '../../../core/utils/safe_query_parameters.dart';

final _codePattern = RegExp(r'^[a-z0-9]{7}$');

/// Código da sala num link `plpcg.com/ao-vivo/<code>` (Universal Link) ou
/// `plpcg.com/?live=<code>` (o 302 do Worker para a web). `null` se não houver.
String? parseLiveRoomCode(Uri uri) {
  final segments = uri.pathSegments;
  if (segments.length == 2 && segments[0] == 'ao-vivo') {
    return _codePattern.hasMatch(segments[1]) ? segments[1] : null;
  }
  final fromQuery = safeQueryParameters(uri)['live'];
  if (fromQuery != null && _codePattern.hasMatch(fromQuery)) return fromQuery;
  return null;
}

/// Rota interna do GoRouter.
String liveRoomRouteFor(String code) => '/ao-vivo/$code';

/// O link que o gestor partilha (o Worker responde 302 para a app).
String liveRoomShareUrl(String code) {
  final base = AppConfig.apiBaseUrl;
  final host = base.isEmpty ? 'plpcg.com' : Uri.parse(base).host;
  return 'https://$host/ao-vivo/$code';
}
```

- [ ] **Step 4: Verde e commit**

Run: `flutter test test/unit/features/live/ && dart format lib/features/live/domain test/unit/features/live`

```bash
git add lib/features/live/domain/live_reconnect_policy.dart lib/features/live/domain/live_room_link.dart test/unit/features/live/live_reconnect_policy_test.dart test/unit/features/live/live_room_link_test.dart
git commit -m "feat(live): política de reconexão e parse do link da sala"
```

---

### Task 9: Projeção — a lista ativa do consumidor vira o snapshot do gestor

**Files:**
- Create: `lib/features/live/presentation/providers/live_projection_provider.dart`
- Modify: `lib/features/playlists/presentation/providers/active_playlist_editor.dart` (`activeEntriesProvider`, `AddToActiveOutcome`, guardas)
- Modify: `lib/features/catalog/presentation/widgets/material_sheet_actions.dart:100-102`, `lib/features/catalog/presentation/widgets/louvor_group_card.dart:185-200`
- Test: `test/unit/features/live/live_projection_test.dart`

**Interfaces:**
- Produces:
  - `final class LiveProjection { ownerName, playlistId, name, entries: List<PlaylistEntry> }`
  - `liveProjectionProvider: NotifierProvider<LiveProjectionNotifier, LiveProjection?>` com `set(LiveProjection?)` e `clear()`.
  - `AddToActiveOutcome.following` — novo valor.
  - `ActivePlaylistEditor.isFollowingLive: bool`.
- Consumes: `activeEntriesOf`, `activePlaylistProvider`.

O holder é um provider "burro" de propósito: `active_playlist_editor.dart` importa **só** este arquivo (sem ciclo com o controller, que importa os providers de playlists).

- [ ] **Step 1: Teste**

```dart
// test/unit/features/live/live_projection_test.dart
import 'package:coldigui/features/live/presentation/providers/live_projection_provider.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/test_overrides.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(overrides: standardTestOverrides(prefs: prefs));
    addTearDown(container.dispose);
  });

  test('sem projeção, activeEntries vem da lista ativa local (vazia aqui)', () {
    expect(container.read(activeEntriesProvider), isEmpty);
  });

  test('com projeção, activeEntries são as entradas do gestor com chaves por ocorrência', () {
    container.read(liveProjectionProvider.notifier).set(
      LiveProjection(
        ownerName: 'Fulano', playlistId: 'p1', name: 'Culto',
        entries: const [
          PlaylistEntry(id: 'a', kind: MaterialKind.pdf),
          PlaylistEntry(id: 'a', kind: MaterialKind.pdf),
          PlaylistEntry(id: 't', kind: MaterialKind.audio),
        ],
      ),
    );
    final entries = container.read(activeEntriesProvider);
    expect(entries.map((e) => e.key), ['a', 'a#1', 't']);
    expect(container.read(activePlaylistEditorProvider.notifier).isFollowingLive, isTrue);
  });

  test('mutações da lista ativa são ignoradas enquanto segue', () async {
    container.read(liveProjectionProvider.notifier).set(
      LiveProjection(ownerName: 'Fulano', playlistId: 'p1', name: 'Culto',
        entries: const [PlaylistEntry(id: 'a', kind: MaterialKind.pdf)]),
    );
    final editor = container.read(activePlaylistEditorProvider.notifier);
    expect(await editor.addToActive('zzz'), AddToActiveOutcome.following);
    expect(await editor.addEntriesToActive(const [PlaylistEntry(id: 'b', kind: MaterialKind.pdf)]), 0);
    await editor.removeByKey('a');
    await editor.reorder(const ['a']);
    expect(container.read(activeEntriesProvider).map((e) => e.key), ['a']);
  });

  test('clear() devolve a lista ativa local', () {
    final notifier = container.read(liveProjectionProvider.notifier);
    notifier.set(LiveProjection(ownerName: 'F', playlistId: 'p', name: 'n',
      entries: const [PlaylistEntry(id: 'a', kind: MaterialKind.pdf)]));
    notifier.clear();
    expect(container.read(activeEntriesProvider), isEmpty);
    expect(container.read(activePlaylistEditorProvider.notifier).isFollowingLive, isFalse);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/live/live_projection_test.dart`
Expected: FAIL — provider não existe.

- [ ] **Step 3: Holder**

```dart
// lib/features/live/presentation/providers/live_projection_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../playlists/domain/entities/playlist_entry.dart';

/// A lista do gestor, como o consumidor a vê (spec D4: projeção read-only).
///
/// Holder sem lógica: quem escreve é o `LiveSessionController`; quem lê é
/// `activeEntriesProvider`, que a prefere sobre a lista ativa local enquanto
/// não for `null`. Nada disto toca o Isar — ao sair, a lista local volta
/// intacta.
final class LiveProjection {
  LiveProjection({
    required this.ownerName,
    required this.playlistId,
    required this.name,
    required List<PlaylistEntry> entries,
  }) : entries = List<PlaylistEntry>.unmodifiable(entries);

  final String ownerName;
  final String playlistId;
  final String name;
  final List<PlaylistEntry> entries;
}

class LiveProjectionNotifier extends Notifier<LiveProjection?> {
  @override
  LiveProjection? build() => null;

  void set(LiveProjection? projection) => state = projection;

  void clear() => state = null;
}

final liveProjectionProvider =
    NotifierProvider<LiveProjectionNotifier, LiveProjection?>(
      LiveProjectionNotifier.new,
    );
```

- [ ] **Step 4: `active_playlist_editor.dart`**

1. Import: `import '../../../live/presentation/providers/live_projection_provider.dart';`
2. Enum:

```dart
  /// A lista ativa é a projeção de uma sessão ao vivo: o consumidor não
  /// edita (spec lista-ao-vivo D4). Nada foi gravado.
  following,
```

3. Na classe, depois de `_entries`:

```dart
  /// `true` enquanto a lista ativa é a projeção de um gestor ao vivo — toda
  /// mutação daqui é ignorada (a UI também as desativa).
  bool get isFollowingLive => ref.read(liveProjectionProvider) != null;
```

4. Guardas — primeira linha de cada método:
   - `addToActive`: `if (isFollowingLive) return AddToActiveOutcome.following;`
   - `addEntriesToActive`: `if (isFollowingLive) return 0;`
   - `removeByKey`, `removeById`, `reorder`: `if (isFollowingLive) return;`
   - `replaceByKey`: `if (isFollowingLive) return false;`

5. `activeEntriesProvider`:

```dart
/// Entradas da lista ativa com posição e chave, já com o override otimista.
///
/// Enquanto o app segue um gestor ao vivo ([liveProjectionProvider] não
/// nulo), a lista ativa **é** o snapshot dele — barra, leitor e player não
/// sabem a diferença; a lista local fica intocada e volta ao sair.
final activeEntriesProvider = Provider<List<ActiveEntry>>((ref) {
  final live = ref.watch(liveProjectionProvider);
  if (live != null) return activeEntriesOf(live.entries);
  final override = ref.watch(activePlaylistEditorProvider);
  final entries =
      override ?? ref.watch(activePlaylistProvider)?.entries ?? const [];
  return activeEntriesOf(entries);
});
```

6. Switches exaustivos: `material_sheet_actions.dart` ganha `AddToActiveOutcome.following => l10n.liveFollowingCannotEdit,`; `louvor_group_card.dart` (linhas ~185–200): antes da mensagem `alreadyPresent`, `if (outcome == AddToActiveOutcome.following) { showAppSnackbar(context, l10n.liveFollowingCannotEdit); return; }`. A chave `liveFollowingCannotEdit` entra nos ARBs agora (pt «Você está seguindo a lista de outra pessoa — saia da sessão para editar a sua», en «You're following someone else's list — leave the session to edit yours») e `flutter gen-l10n`.

- [ ] **Step 5: Verde**

Run: `flutter gen-l10n && flutter test test/unit/features/live/live_projection_test.dart test/unit/features/playlists/active_playlist_editor_test.dart test/unit/features/catalog && dart format <arquivos tocados>`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/live/presentation/providers/live_projection_provider.dart lib/features/playlists/presentation/providers/active_playlist_editor.dart lib/features/catalog/presentation/widgets/material_sheet_actions.dart lib/features/catalog/presentation/widgets/louvor_group_card.dart lib/l10n test/unit/features/live/live_projection_test.dart
git commit -m "feat(live): lista ativa vira projeção do gestor enquanto o consumidor segue"
```

---

### Task 10: `LiveSessionController` — entrar, seguir, sair, guardas por sala/versão

**Files:**
- Create: `lib/features/live/data/providers/live_providers.dart`
- Create: `lib/features/live/presentation/providers/live_session_state.dart`
- Create: `lib/features/live/presentation/providers/live_session_controller.dart`
- Test: `test/unit/features/live/live_session_controller_consumer_test.dart`

**Interfaces:**
- Consumes: `LiveTransport`/`FakeLiveTransport` (Task 7), frames (Task 7), `LiveReconnectPolicy` (Task 8), `liveProjectionProvider` (Task 9), `authStateProvider`, `carouselFocusedKeyProvider`, `activeEntriesProvider`, `sharedPreferencesProvider`.
- Produces:
  - DI em `live_providers.dart`: `liveTransportProvider: Provider<LiveTransport>`, `liveWsUriProvider: Provider<Uri Function(String code)>`, `liveClientIdProvider: Provider<String>` (pref `live_client_id`), `liveReconnectPolicyProvider`, `liveMyRoomCodeProvider: NotifierProvider<LiveMyRoomCodeNotifier, String?>` (pref `live_my_room_code`, `set(String?)`), `liveFocusResolverProvider: Provider<Future<String?> Function(String key)>`, `liveNavigatorProvider: Provider<void Function(String location)>`.
  - `enum LivePhase { idle, joining, connected, reconnecting, ended, left, unavailable, notFound }`
  - `class LiveSessionState` (campos abaixo) com `isFollowing`, `isLeading`, `copyWith`.
  - `liveSessionProvider: NotifierProvider<LiveSessionController, LiveSessionState>`; métodos desta task: `Future<void> join(String code)`, `Future<void> leave()`, `void onAppLifecycle(AppLifecycleState)`, `void onConnectivity(bool online)`. (`startLive`, `endLive`, `resumeLeader`, `returnToLeader` chegam nas Tasks 12–13.)
  - Constantes: `kLivePingProbeTimeout = Duration(seconds: 5)`.

Mapeamento para a spec §6.1: `live` da spec = `connected` aqui (o `roomStatus` diz se a sala está `live`).

- [ ] **Step 1: Testes (consumidor)**

```dart
// test/unit/features/live/live_session_controller_consumer_test.dart
import 'dart:convert';

import 'package:coldigui/features/carousel/presentation/providers/carousel_focused_index_provider.dart';
import 'package:coldigui/features/live/data/providers/live_providers.dart';
import 'package:coldigui/features/live/domain/entities/live_snapshot.dart';
import 'package:coldigui/features/live/presentation/providers/live_projection_provider.dart';
import 'package:coldigui/features/live/presentation/providers/live_session_controller.dart';
import 'package:coldigui/features/live/presentation/providers/live_session_state.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fakes/fake_live_transport.dart';
import '../../../support/test_overrides.dart';

const code = 'k7x2m9q';

String roomFrame({String status = 'live', int version = 1, Object? snapshot = _snap, bool leaderPresent = true, int viewers = 3, String room = code, String role = 'consumer'}) =>
    jsonEncode({'t': 'room', 'room': room, 'status': status, 'ownerName': 'Fulano', 'role': role, 'version': version, 'snapshot': snapshot, 'leaderPresent': leaderPresent, 'viewers': viewers});

String snapshotFrame({required int version, String focus = 'a', String room = code, List<Map<String, String>>? entries}) =>
    jsonEncode({'t': 'snapshot', 'room': room, 'version': version, 'snapshot': {'playlistId': 'p1', 'name': 'Culto', 'entries': entries ?? _entries, 'focusKey': focus}, 'viewers': 3});

const _entries = [{'id': 'a', 'kind': 'pdf'}, {'id': 'b', 'kind': 'pdf'}];
const _snap = {'playlistId': 'p1', 'name': 'Culto', 'entries': _entries, 'focusKey': 'a'};

void main() {
  late ProviderContainer container;
  late FakeLiveTransport transport;
  late List<String> resolvedKeys;
  late List<String> navigated;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    transport = FakeLiveTransport();
    resolvedKeys = [];
    navigated = [];
    container = ProviderContainer(
      overrides: [
        ...standardTestOverrides(prefs: prefs),
        liveTransportProvider.overrideWithValue(transport),
        liveWsUriProvider.overrideWithValue((c) => Uri.parse('wss://test/api/live/$c/ws')),
        liveFocusResolverProvider.overrideWithValue((key) async { resolvedKeys.add(key); return '/leitor?key=$key'; }),
        liveNavigatorProvider.overrideWithValue(navigated.add),
      ],
    );
    addTearDown(container.dispose);
  });

  LiveSessionState state() => container.read(liveSessionProvider);
  LiveSessionController controller() => container.read(liveSessionProvider.notifier);

  Future<void> joinAndReceiveRoom() async {
    await controller().join(code);
    transport.last.emit(roomFrame());
    await Future<void>.delayed(Duration.zero);
  }

  test('join conecta ao URI da sala, manda hello sem token e entra em joining', () async {
    await controller().join(code);
    expect(state().phase, LivePhase.joining);
    expect(transport.last.uri.toString(), 'wss://test/api/live/$code/ws');
    final hello = jsonDecode(transport.last.sent.single) as Map<String, Object?>;
    expect(hello['t'], 'hello');
    expect(hello['room'], code);
    expect(hello['since'], 0);
    expect(hello['clientId'], isNotEmpty);
    expect(hello.containsKey('sessionToken'), isFalse);
  });

  test('room live projeta a lista e aplica o foco do gestor', () async {
    await joinAndReceiveRoom();
    expect(state().phase, LivePhase.connected);
    expect(state().roomStatus, LiveRoomStatus.live);
    expect(state().ownerName, 'Fulano');
    expect(state().version, 1);
    expect(state().isFollowing, isTrue);
    expect(container.read(liveProjectionProvider)!.entries.length, 2);
    expect(container.read(activeEntriesProvider).map((e) => e.key), ['a', 'b']);
    expect(resolvedKeys, ['a']);
    expect(navigated, ['/leitor?key=a']);
  });

  test('room idle conecta sem projetar; um room live depois entra', () async {
    await controller().join(code);
    transport.last.emit(roomFrame(status: 'idle', version: 0, snapshot: null, leaderPresent: false));
    await Future<void>.delayed(Duration.zero);
    expect(state().phase, LivePhase.connected);
    expect(state().isFollowing, isFalse);
    expect(container.read(liveProjectionProvider), isNull);
    transport.last.emit(roomFrame());
    await Future<void>.delayed(Duration.zero);
    expect(state().isFollowing, isTrue);
  });

  test('snapshot com versão maior atualiza; versão ≤ atual é descartada', () async {
    await joinAndReceiveRoom();
    transport.last.emit(snapshotFrame(version: 2, focus: 'b'));
    await Future<void>.delayed(Duration.zero);
    expect(state().version, 2);
    expect(state().snapshot!.focusKey, 'b');
    transport.last.emit(snapshotFrame(version: 2, focus: 'a'));
    transport.last.emit(snapshotFrame(version: 1, focus: 'a'));
    await Future<void>.delayed(Duration.zero);
    expect(state().snapshot!.focusKey, 'b');
  });

  test('frames de outra sala são descartados', () async {
    await joinAndReceiveRoom();
    transport.last.emit(snapshotFrame(version: 9, room: 'zzzzzzz'));
    transport.last.emit(jsonEncode({'t': 'ended', 'room': 'zzzzzzz', 'reason': 'leader'}));
    await Future<void>.delayed(Duration.zero);
    expect(state().version, 1);
    expect(state().phase, LivePhase.connected);
  });

  test('presence atualiza leaderPresent e viewers', () async {
    await joinAndReceiveRoom();
    transport.last.emit(jsonEncode({'t': 'presence', 'room': code, 'leaderPresent': false, 'viewers': 7}));
    await Future<void>.delayed(Duration.zero);
    expect(state().leaderPresent, isFalse);
    expect(state().viewers, 7);
  });

  test('ended limpa a projeção, guarda o motivo e mantém o snapshot para «Guardar cópia»', () async {
    await joinAndReceiveRoom();
    transport.last.emit(jsonEncode({'t': 'ended', 'room': code, 'reason': 'inactivity'}));
    await transport.last.drop(code: 4001);
    await Future<void>.delayed(Duration.zero);
    expect(state().phase, LivePhase.ended);
    expect(state().endReason, LiveEndReason.inactivity);
    expect(container.read(liveProjectionProvider), isNull);
    expect(state().snapshot, isNotNull);
    expect(transport.attempts, 1); // não religa depois de ended
  });

  test('error not_found → notFound, sem retry', () async {
    await controller().join(code);
    transport.last.emit(jsonEncode({'t': 'error', 'room': '', 'code': 'not_found'}));
    await transport.last.drop(code: 4004);
    await Future<void>.delayed(Duration.zero);
    expect(state().phase, LivePhase.notFound);
    expect(transport.attempts, 1);
  });

  test('leave fecha com 1000, limpa a projeção e ignora frames tardios', () async {
    await joinAndReceiveRoom();
    final conn = transport.last;
    await controller().leave();
    expect(state().phase, LivePhase.left);
    expect(conn.closedWith, 1000);
    expect(container.read(liveProjectionProvider), isNull);
    conn.emit(snapshotFrame(version: 5));
    await Future<void>.delayed(Duration.zero);
    expect(state().version, 1);
    await controller().leave(); // idempotente
    expect(state().phase, LivePhase.left);
  });

  test('join da mesma sala em curso é single-flight; join de outra sala sai da primeira', () async {
    await controller().join(code);
    await controller().join(code);
    expect(transport.attempts, 1);
    final first = transport.last;
    await controller().join('abcdefg');
    expect(first.closedWith, 1000);
    expect(transport.attempts, 2);
    expect(state().code, 'abcdefg');
    expect(state().phase, LivePhase.joining);
  });

  test('foco: chave do gestor que não existe na lista não navega', () async {
    await controller().join(code);
    transport.last.emit(roomFrame(snapshot: {..._snap, 'focusKey': 'nope'}));
    await Future<void>.delayed(Duration.zero);
    expect(resolvedKeys, isEmpty);
    expect(navigated, isEmpty);
  });

  test('foco: entrada de áudio só foca a chip, sem navegar', () async {
    await controller().join(code);
    transport.last.emit(roomFrame(snapshot: {'playlistId': 'p1', 'name': 'n', 'entries': [{'id': 'trk', 'kind': 'audio'}], 'focusKey': 'trk'}));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(carouselFocusedKeyProvider), 'trk');
    expect(navigated, isEmpty);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/live/live_session_controller_consumer_test.dart`
Expected: FAIL — imports.

- [ ] **Step 3: DI**

```dart
// lib/features/live/data/providers/live_providers.dart
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../../core/routing/app_router.dart';
import '../../../pdf_reader/presentation/providers/reader_carousel_actions_provider.dart';
import '../../domain/live_reconnect_policy.dart';
import '../../domain/ports/live_transport.dart';
import '../live_transport_ws.dart';

const kLiveClientIdPrefsKey = 'live_client_id';
const kLiveMyRoomCodePrefsKey = 'live_my_room_code';

final liveTransportProvider = Provider<LiveTransport>(
  (ref) => const WebSocketLiveTransport(),
);

/// `wss://<host de PLPCG_API_BASE_URL>/api/live/<code>/ws`.
final liveWsUriProvider = Provider<Uri Function(String code)>((ref) {
  return (code) {
    final base = Uri.parse(AppConfig.apiBaseUrl);
    return base.replace(
      scheme: base.scheme == 'http' ? 'ws' : 'wss',
      path: '/api/live/$code/ws',
      query: null,
    );
  };
});

/// Identidade anónima do aparelho (spec D2) — gerada uma vez, persistida.
final liveClientIdProvider = Provider<String>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  final existing = prefs.getString(kLiveClientIdPrefsKey);
  if (existing != null && existing.isNotEmpty) return existing;
  final random = Random.secure();
  final id = List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  prefs.setString(kLiveClientIdPrefsKey, id);
  return id;
});

final liveReconnectPolicyProvider = Provider<LiveReconnectPolicy>(
  (ref) => LiveReconnectPolicy(),
);

/// Código da **minha** sala, cacheado depois do `POST /api/live/room` — é o
/// que diz ao controller quando mandar o token no `hello`.
class LiveMyRoomCodeNotifier extends Notifier<String?> {
  @override
  String? build() => ref.read(sharedPreferencesProvider).getString(kLiveMyRoomCodePrefsKey);

  void set(String? code) {
    state = code;
    final prefs = ref.read(sharedPreferencesProvider);
    if (code == null) {
      prefs.remove(kLiveMyRoomCodePrefsKey);
    } else {
      prefs.setString(kLiveMyRoomCodePrefsKey, code);
    }
  }
}

final liveMyRoomCodeProvider = NotifierProvider<LiveMyRoomCodeNotifier, String?>(
  LiveMyRoomCodeNotifier.new,
);

/// Resolve a rota do leitor para a chave focada pelo gestor (foca a chip como
/// efeito). Sobrescrito em teste — o real precisa de catálogo e PDF.
final liveFocusResolverProvider = Provider<Future<String?> Function(String key)>((ref) {
  return (key) => ref.read(readerCarouselActionsProvider.notifier).navigateToKey(key: key);
});

/// Navega para a rota resolvida. Sobrescrito em teste.
final liveNavigatorProvider = Provider<void Function(String location)>((ref) {
  return (location) => ref.read(appRouterProvider).go(location);
});
```

- [ ] **Step 4: Estado**

```dart
// lib/features/live/presentation/providers/live_session_state.dart
import '../../domain/entities/live_snapshot.dart';

/// Fases do controller (spec §6.1; `live` da spec = [connected]).
///
/// [unavailable] e [notFound] são terminais: sem retry automático.
enum LivePhase { idle, joining, connected, reconnecting, ended, left, unavailable, notFound }

final class LiveSessionState {
  const LiveSessionState({
    this.phase = LivePhase.idle,
    this.code,
    this.role,
    this.roomStatus,
    this.ownerName = '',
    this.version = 0,
    this.snapshot,
    this.leaderPresent = false,
    this.viewers = 0,
    this.followingFocus = true,
    this.endReason,
    this.handshakeFailures = 0,
    this.lastError,
  });

  final LivePhase phase;
  final String? code;
  final LiveRole? role;
  final LiveRoomStatus? roomStatus;
  final String ownerName;
  final int version;
  /// Último snapshot recebido — sobrevive a [LivePhase.ended] para «Guardar cópia».
  final LiveSnapshot? snapshot;
  final bool leaderPresent;
  final int viewers;
  /// D3: `false` depois de o consumidor navegar por conta própria.
  final bool followingFocus;
  final LiveEndReason? endReason;
  final int handshakeFailures;
  /// Último `error{code}` do DO relevante para a UI (`not_leader`, `unauthorized`).
  final String? lastError;

  bool get isConnectedOrRetrying => phase == LivePhase.connected || phase == LivePhase.reconnecting;

  /// Consumidor numa sala `live`: a lista ativa é a projeção.
  bool get isFollowing => role == LiveRole.consumer && isConnectedOrRetrying && roomStatus == LiveRoomStatus.live;

  /// Gestor numa sala `live`, conectado.
  bool get isLeading => role == LiveRole.leader && isConnectedOrRetrying && roomStatus == LiveRoomStatus.live;

  LiveSessionState copyWith({
    LivePhase? phase, String? code, LiveRole? role, LiveRoomStatus? roomStatus, String? ownerName,
    int? version, LiveSnapshot? snapshot, bool clearSnapshot = false, bool? leaderPresent, int? viewers,
    bool? followingFocus, LiveEndReason? endReason, bool clearEndReason = false, int? handshakeFailures,
    String? lastError, bool clearLastError = false,
  }) => LiveSessionState(
    phase: phase ?? this.phase,
    code: code ?? this.code,
    role: role ?? this.role,
    roomStatus: roomStatus ?? this.roomStatus,
    ownerName: ownerName ?? this.ownerName,
    version: version ?? this.version,
    snapshot: clearSnapshot ? null : (snapshot ?? this.snapshot),
    leaderPresent: leaderPresent ?? this.leaderPresent,
    viewers: viewers ?? this.viewers,
    followingFocus: followingFocus ?? this.followingFocus,
    endReason: clearEndReason ? null : (endReason ?? this.endReason),
    handshakeFailures: handshakeFailures ?? this.handshakeFailures,
    lastError: clearLastError ? null : (lastError ?? this.lastError),
  );
}
```

- [ ] **Step 5: Controller (consumidor + reconexão + ciclo de vida)**

```dart
// lib/features/live/presentation/providers/live_session_controller.dart
import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../carousel/presentation/providers/carousel_focused_index_provider.dart';
import '../../../carousel/presentation/providers/carousel_items_provider.dart';
import '../../../playlists/presentation/providers/active_playlist_editor.dart';
import '../../data/providers/live_providers.dart';
import '../../domain/entities/live_snapshot.dart';
import '../../domain/live_reconnect_policy.dart';
import '../../domain/ports/live_transport.dart';
import '../../domain/protocol/live_frames.dart';
import 'live_projection_provider.dart';
import 'live_session_state.dart';

export 'live_session_state.dart';

final _log = AppLogger.of('live');

/// Espera pelo `pong` da prova de vida ao voltar do segundo plano.
const kLivePingProbeTimeout = Duration(seconds: 5);

/// Debounce entre a última mudança da lista ativa do gestor e o `set`.
const kLiveLeaderSetDebounce = Duration(milliseconds: 300);

/// Close codes do DO (`room_core.ts`).
const int kLiveCloseEnded = 4001;
const int kLiveCloseReplaced = 4002;
const int kLiveCloseRetired = 4003;
const int kLiveCloseNotFound = 4004;

/// A sessão ao vivo do app inteiro (spec 2026-09-12-lista-ao-vivo, §6.1).
///
/// Único, `keepAlive` (provider sem `autoDispose`), vive o container todo:
/// sobrevive a rotas, e `ref.onDispose` fecha o socket quando o container
/// morre (hot restart, logout com `ProviderScope` novo). Toda conexão tem uma
/// **geração** (`_gen`): frames e fechos de uma geração antiga são ignorados
/// — é isto que impede o "socket fantasma" depois de `leave()`.
class LiveSessionController extends Notifier<LiveSessionState> {
  LiveConnection? _conn;
  StreamSubscription<String>? _sub;
  int _gen = 0;
  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;
  Timer? _probeTimer;
  bool _paused = false;
  Future<void>? _connecting;
  String? _leaderFocusKey;
  bool _applyingFocus = false;
  Timer? _setDebounce;
  /// `startLive` pediu `start` mas a sala ainda não confirmou `live` — se o
  /// primeiro handshake falhar, o `room{idle}` da reconexão reenvia o `start`.
  bool _pendingStart = false;

  @override
  LiveSessionState build() {
    ref.onDispose(() {
      _reconnectTimer?.cancel();
      _probeTimer?.cancel();
      _setDebounce?.cancel();
      _teardownConnection(closeCode: 1000);
    });
    ref.listen(carouselFocusedKeyProvider, (_, key) => _onLocalFocusChanged(key));
    ref.listen(activeEntriesProvider, (_, __) => _onLocalListChanged());
    return const LiveSessionState();
  }

  // ---- API pública -----------------------------------------------------

  /// Entra na sala [code]. Single-flight: repetir o mesmo código não abre
  /// outro socket; outro código sai da sala atual primeiro.
  Future<void> join(String code) async {
    if (state.code == code && (state.phase == LivePhase.joining || state.isConnectedOrRetrying)) {
      return _connecting ?? Future.value();
    }
    if (state.code != null && state.code != code) await leave();
    _reconnectAttempt = 0;
    state = LiveSessionState(phase: LivePhase.joining, code: code);
    await _connect();
  }

  /// Sai da sala: fecha com 1000, limpa a projeção. Idempotente.
  Future<void> leave() async {
    _reconnectTimer?.cancel();
    _probeTimer?.cancel();
    _setDebounce?.cancel();
    _pendingStart = false;
    _teardownConnection(closeCode: 1000);
    _clearProjection();
    if (state.phase == LivePhase.idle) return;
    state = state.copyWith(phase: LivePhase.left, followingFocus: true);
  }

  /// Ciclo de vida da app: em `paused` nenhum timer religa; em `resumed`
  /// religa na hora (ou prova o socket com `ping`).
  void onAppLifecycle(AppLifecycleState lifecycle) {
    switch (lifecycle) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _paused = true;
        _reconnectTimer?.cancel();
      case AppLifecycleState.resumed:
        _paused = false;
        if (state.phase == LivePhase.reconnecting) {
          _reconnectNow();
        } else if (state.phase == LivePhase.connected) {
          _probe();
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  /// Evento de conectividade: online + `reconnecting` → religa já.
  void onConnectivity(bool online) {
    if (online && !_paused && state.phase == LivePhase.reconnecting) _reconnectNow();
  }

  // ---- conexão -----------------------------------------------------------

  Future<void> _connect() {
    final pending = _connecting;
    if (pending != null) return pending;
    final future = _doConnect();
    _connecting = future;
    return future.whenComplete(() {
      if (identical(_connecting, future)) _connecting = null;
    });
  }

  Future<void> _doConnect() async {
    final code = state.code;
    if (code == null) return;
    final gen = ++_gen;
    LiveConnection conn;
    try {
      conn = await ref.read(liveTransportProvider).connect(ref.read(liveWsUriProvider)(code));
    } on Object catch (e) {
      if (gen != _gen || !ref.mounted) return;
      _log.warn('handshake da sala $code falhou', e);
      _onHandshakeFailure();
      return;
    }
    if (gen != _gen || !ref.mounted) {
      unawaited(conn.close());
      return;
    }
    _conn = conn;
    _sub = conn.messages.listen((text) => _onMessage(gen, text));
    unawaited(conn.done.then((d) => _onDisconnect(gen, d)));
    conn.send(encodeLiveHello(
      room: code,
      since: state.version,
      clientId: ref.read(liveClientIdProvider),
      sessionToken: _sessionTokenFor(code),
    ));
  }

  /// Token só quando faz sentido ser gestor: logado **e** (a sala é a minha
  /// ou ainda não sei qual é a minha). Evita um lookup em D1 por consumidor.
  String? _sessionTokenFor(String code) {
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return null;
    final mine = ref.read(liveMyRoomCodeProvider);
    return (mine == null || mine == code) ? user.sessionToken : null;
  }

  void _onHandshakeFailure() {
    final failures = state.handshakeFailures + 1;
    if (state.phase == LivePhase.joining && failures >= kLiveMaxHandshakeFailures) {
      state = state.copyWith(phase: LivePhase.unavailable, handshakeFailures: failures);
      return;
    }
    state = state.copyWith(
      phase: state.phase == LivePhase.joining ? LivePhase.joining : LivePhase.reconnecting,
      handshakeFailures: failures,
    );
    _scheduleReconnect();
  }

  void _onDisconnect(int gen, LiveDisconnect disconnect) {
    if (gen != _gen || !ref.mounted) return;
    _sub = null;
    _conn = null;
    switch (state.phase) {
      case LivePhase.ended:
      case LivePhase.left:
      case LivePhase.unavailable:
      case LivePhase.notFound:
      case LivePhase.idle:
        return;
      case LivePhase.joining:
      case LivePhase.connected:
      case LivePhase.reconnecting:
        break;
    }
    switch (disconnect.code) {
      case kLiveCloseEnded:
        _finish(LivePhase.ended, reason: state.endReason ?? LiveEndReason.leader);
      case kLiveCloseReplaced:
        _finish(LivePhase.ended, reason: LiveEndReason.replaced);
      case kLiveCloseRetired:
        _finish(LivePhase.ended, reason: LiveEndReason.retired);
      case kLiveCloseNotFound:
        _finish(LivePhase.notFound);
      default:
        state = state.copyWith(phase: LivePhase.reconnecting);
        _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (_paused) return;
    final delay = ref.read(liveReconnectPolicyProvider).delayFor(_reconnectAttempt++);
    _reconnectTimer = Timer(delay, () {
      if (!ref.mounted) return;
      unawaited(_connect());
    });
  }

  void _reconnectNow() {
    _reconnectTimer?.cancel();
    unawaited(_connect());
  }

  /// `ping` → o DO responde `pong` na borda; sem resposta em 5 s o socket
  /// está morto (iOS mata em segundo plano sem close frame).
  void _probe() {
    final conn = _conn;
    if (conn == null) return;
    conn.send('ping');
    _probeTimer?.cancel();
    _probeTimer = Timer(kLivePingProbeTimeout, () {
      if (!ref.mounted || state.phase != LivePhase.connected) return;
      _teardownConnection(closeCode: 1001);
      state = state.copyWith(phase: LivePhase.reconnecting);
      _reconnectNow();
    });
  }

  void _teardownConnection({required int closeCode}) {
    _gen++;
    unawaited(_sub?.cancel());
    _sub = null;
    final conn = _conn;
    _conn = null;
    if (conn != null) unawaited(conn.close(code: closeCode));
  }

  void _finish(LivePhase phase, {LiveEndReason? reason}) {
    _reconnectTimer?.cancel();
    _setDebounce?.cancel();
    _teardownConnection(closeCode: 1000);
    _clearProjection();
    state = state.copyWith(phase: phase, endReason: reason, followingFocus: true);
  }

  // ---- frames ------------------------------------------------------------

  void _onMessage(int gen, String text) {
    if (gen != _gen || !ref.mounted) return;
    if (text == 'pong') {
      _probeTimer?.cancel();
      return;
    }
    final frame = decodeLiveServerFrame(text);
    if (frame == null) return;
    if (frame is LiveErrorFrame && frame.code == 'not_found') {
      _finish(LivePhase.notFound);
      return;
    }
    if (frame.room != state.code) return;

    switch (frame) {
      case LiveRoomFrame():
        _onRoom(frame);
      case LiveSnapshotFrame():
        if (frame.version <= state.version) return;
        state = state.copyWith(version: frame.version, snapshot: frame.snapshot, viewers: frame.viewers);
        _syncProjection();
      case LivePresenceFrame():
        state = state.copyWith(leaderPresent: frame.leaderPresent, viewers: frame.viewers);
      case LiveAckFrame():
        state = state.copyWith(version: frame.version, viewers: frame.viewers);
      case LiveEndedFrame():
        // O DO fecha o socket logo a seguir; `_onDisconnect` respeita `ended`.
        _finish(LivePhase.ended, reason: frame.reason);
      case LiveErrorFrame():
        _log.warn('sala ${state.code}: error ${frame.code}');
        state = state.copyWith(lastError: frame.code);
    }
  }

  void _onRoom(LiveRoomFrame frame) {
    _reconnectAttempt = 0;
    final keepSnapshot = frame.version <= state.version && state.snapshot != null;
    state = state.copyWith(
      phase: LivePhase.connected,
      role: frame.role,
      roomStatus: frame.status,
      ownerName: frame.ownerName,
      version: keepSnapshot ? state.version : frame.version,
      snapshot: keepSnapshot ? state.snapshot : frame.snapshot,
      leaderPresent: frame.leaderPresent,
      viewers: frame.viewers,
      handshakeFailures: 0,
      clearLastError: true,
    );
    _syncProjection();
    _onRoomAsLeader(frame);
  }

  // ---- projeção e foco (consumidor) -----------------------------------------

  void _syncProjection() {
    final snapshot = state.snapshot;
    if (!state.isFollowing || snapshot == null) {
      _clearProjection();
      return;
    }
    ref.read(liveProjectionProvider.notifier).set(LiveProjection(
      ownerName: state.ownerName,
      playlistId: snapshot.playlistId,
      name: snapshot.name,
      entries: snapshot.entries,
    ));
    final focus = snapshot.focusKey;
    if (focus != _leaderFocusKey) {
      _leaderFocusKey = focus;
      if (state.followingFocus && focus != null) unawaited(_applyLeaderFocus(focus));
    }
  }

  void _clearProjection() {
    _leaderFocusKey = null;
    if (ref.read(liveProjectionProvider) != null) {
      ref.read(liveProjectionProvider.notifier).clear();
    }
  }

  Future<void> _applyLeaderFocus(String key) async {
    final items = ref.read(carouselItemsProvider);
    final index = items.indexWhere((item) => item.key == key);
    if (index < 0) return;
    _applyingFocus = true;
    try {
      if (items[index].isAudio) {
        ref.read(carouselFocusedIndexProvider.notifier).focusKey(key);
        return;
      }
      final location = await ref.read(liveFocusResolverProvider)(key);
      if (location == null || !ref.mounted || !state.isFollowing) return;
      ref.read(liveNavigatorProvider)(location);
    } on Object catch (e, stack) {
      _log.error('não foi possível seguir o foco $key', e, stack);
    } finally {
      _applyingFocus = false;
    }
  }

  // Preenchidos na Task 12 (gestor) e na Task 13 (D3).
  void _onLocalFocusChanged(String? key) {}
  void _onLocalListChanged() {}
  void _onRoomAsLeader(LiveRoomFrame frame) {}
}

final liveSessionProvider = NotifierProvider<LiveSessionController, LiveSessionState>(
  LiveSessionController.new,
);
```

`_applyLeaderFocus` guarda `_applyingFocus = true` **antes** do `await`: o `focusKey` dentro de `navigateToKey` dispara o listener de foco de forma síncrona, ainda dentro da janela — a Task 13 depende disso.

- [ ] **Step 6: Verde**

Run: `flutter test test/unit/features/live/ && dart format lib/features/live test/unit/features/live`
Expected: PASS. Se «foco: entrada de áudio» falhar porque `carouselItemsProvider` não enriquece sem catálogo: o `_enrich` devolve um `CarouselItem` de fallback para qualquer id (`fallbackCarouselNome`) — a `key` e `kind` vêm da entrada, então o teste passa sem manifest. Se `activeEntriesProvider` lançar por `sharedPreferencesProvider`, confirmar que `standardTestOverrides(prefs: prefs)` foi passado.

- [ ] **Step 7: Commit**

```bash
git add lib/features/live test/unit/features/live/live_session_controller_consumer_test.dart
git commit -m "feat(live): LiveSessionController — entrar, seguir o gestor, sair, guardas por sala e versão"
```

---

### Task 11: Reconexão, ciclo de vida e dispose — os cenários da §7

**Files:**
- Test: `test/unit/features/live/live_session_controller_reconnect_test.dart`
- Modify (se necessário): `lib/features/live/presentation/providers/live_session_controller.dart`

Cobre da tabela §7: rede cai 2 min; app em segundo plano; deploy (queda com 1006 → religa); hot restart / container novo; 3 falhas → `unavailable`; handshake falha depois de já ter estado ligado (continua tentando).

- [ ] **Step 1: Testes**

```dart
// test/unit/features/live/live_session_controller_reconnect_test.dart
import 'dart:convert';
import 'dart:math';

import 'package:coldigui/features/live/data/providers/live_providers.dart';
import 'package:coldigui/features/live/domain/live_reconnect_policy.dart';
import 'package:coldigui/features/live/presentation/providers/live_projection_provider.dart';
import 'package:coldigui/features/live/presentation/providers/live_session_controller.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fakes/fake_live_transport.dart';
import '../../../support/test_overrides.dart';

const code = 'k7x2m9q';
const _snap = {'playlistId': 'p1', 'name': 'Culto', 'entries': [{'id': 'a', 'kind': 'pdf'}], 'focusKey': null};

String roomFrame({int version = 1}) => jsonEncode({'t': 'room', 'room': code, 'status': 'live', 'ownerName': 'F', 'role': 'consumer', 'version': version, 'snapshot': _snap, 'leaderPresent': true, 'viewers': 1});

class _ZeroRandom implements Random {
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
  @override
  int nextInt(int max) => 0;
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer makeContainer(FakeLiveTransport transport) {
    final container = ProviderContainer(
      overrides: [
        ...standardTestOverrides(prefs: prefs),
        liveTransportProvider.overrideWithValue(transport),
        liveWsUriProvider.overrideWithValue((c) => Uri.parse('wss://test/$c')),
        liveReconnectPolicyProvider.overrideWithValue(LiveReconnectPolicy(random: _ZeroRandom())),
        liveFocusResolverProvider.overrideWithValue((_) async => null),
        liveNavigatorProvider.overrideWithValue((_) {}),
      ],
    );
    return container;
  }

  test('queda com 1006 → reconnecting, religa após 1 s e manda hello{since}', () {
    fakeAsync((async) {
      final transport = FakeLiveTransport();
      final container = makeContainer(transport);
      final controller = container.read(liveSessionProvider.notifier);
      controller.join(code);
      async.flushMicrotasks();
      transport.last.emit(roomFrame(version: 4));
      async.flushMicrotasks();

      transport.last.drop();
      async.flushMicrotasks();
      expect(container.read(liveSessionProvider).phase, LivePhase.reconnecting);
      // Projeção fica de pé durante a reconexão: a tela não pisca vazia.
      expect(container.read(liveProjectionProvider), isNotNull);

      async.elapse(const Duration(milliseconds: 999));
      expect(transport.attempts, 1);
      async.elapse(const Duration(milliseconds: 1));
      async.flushMicrotasks();
      expect(transport.attempts, 2);
      final hello = jsonDecode(transport.last.sent.single) as Map<String, Object?>;
      expect(hello['since'], 4);

      transport.last.emit(roomFrame(version: 4));
      async.flushMicrotasks();
      expect(container.read(liveSessionProvider).phase, LivePhase.connected);
      container.dispose();
    });
  });

  test('backoff cresce 1, 2, 4 s entre handshakes falhados depois de já ter estado ligado', () {
    fakeAsync((async) {
      final transport = FakeLiveTransport();
      final container = makeContainer(transport);
      final controller = container.read(liveSessionProvider.notifier);
      controller.join(code);
      async.flushMicrotasks();
      transport.last.emit(roomFrame());
      async.flushMicrotasks();
      transport.last.drop();
      async.flushMicrotasks();

      transport.failNext(3);
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(transport.attempts, 2);
      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();
      expect(transport.attempts, 3);
      async.elapse(const Duration(seconds: 4));
      async.flushMicrotasks();
      expect(transport.attempts, 4);
      // Nunca vira unavailable depois de já ter estado conectado.
      expect(container.read(liveSessionProvider).phase, LivePhase.reconnecting);
      container.dispose();
    });
  });

  test('3 handshakes falhados ao entrar → unavailable, sem mais tentativas', () {
    fakeAsync((async) {
      final transport = FakeLiveTransport()..failNext(3);
      final container = makeContainer(transport);
      container.read(liveSessionProvider.notifier).join(code);
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();
      expect(transport.attempts, 3);
      expect(container.read(liveSessionProvider).phase, LivePhase.unavailable);
      async.elapse(const Duration(minutes: 1));
      expect(transport.attempts, 3);
      container.dispose();
    });
  });

  test('em paused nenhum timer religa; em resumed religa na hora', () {
    fakeAsync((async) {
      final transport = FakeLiveTransport();
      final container = makeContainer(transport);
      final controller = container.read(liveSessionProvider.notifier);
      controller.join(code);
      async.flushMicrotasks();
      transport.last.emit(roomFrame());
      async.flushMicrotasks();

      controller.onAppLifecycle(AppLifecycleState.paused);
      transport.last.drop();
      async.flushMicrotasks();
      async.elapse(const Duration(minutes: 5));
      expect(transport.attempts, 1);
      expect(container.read(liveSessionProvider).phase, LivePhase.reconnecting);

      controller.onAppLifecycle(AppLifecycleState.resumed);
      async.flushMicrotasks();
      expect(transport.attempts, 2);
      container.dispose();
    });
  });

  test('resumed com socket "vivo" manda ping; sem pong em 5 s religa', () {
    fakeAsync((async) {
      final transport = FakeLiveTransport();
      final container = makeContainer(transport);
      final controller = container.read(liveSessionProvider.notifier);
      controller.join(code);
      async.flushMicrotasks();
      transport.last.emit(roomFrame());
      async.flushMicrotasks();

      controller.onAppLifecycle(AppLifecycleState.resumed);
      expect(transport.last.sent.last, 'ping');
      async.elapse(const Duration(seconds: 5));
      async.flushMicrotasks();
      expect(transport.attempts, 2);

      // Com pong, nada acontece.
      transport.last.emit(roomFrame());
      async.flushMicrotasks();
      controller.onAppLifecycle(AppLifecycleState.resumed);
      transport.last.emit('pong');
      async.elapse(const Duration(seconds: 6));
      expect(transport.attempts, 2);
      container.dispose();
    });
  });

  test('evento de conectividade online em reconnecting religa sem esperar o backoff', () {
    fakeAsync((async) {
      final transport = FakeLiveTransport();
      final container = makeContainer(transport);
      final controller = container.read(liveSessionProvider.notifier);
      controller.join(code);
      async.flushMicrotasks();
      transport.last.emit(roomFrame());
      async.flushMicrotasks();
      transport.last.drop();
      async.flushMicrotasks();
      transport.failNext(2);
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();
      expect(transport.attempts, 3); // próximo só em 4 s
      controller.onConnectivity(true);
      async.flushMicrotasks();
      expect(transport.attempts, 4);
      container.dispose();
    });
  });

  test('dispose do container fecha o socket e nenhum frame tardio é processado', () async {
    final transport = FakeLiveTransport();
    final container = makeContainer(transport);
    final controller = container.read(liveSessionProvider.notifier);
    await controller.join(code);
    transport.last.emit(roomFrame());
    await Future<void>.delayed(Duration.zero);
    final conn = transport.last;
    var projectionAfterDispose = false;
    container.dispose();
    expect(conn.closedWith, 1000);
    // Um container novo (hot restart) começa do zero e não vê o socket velho.
    final fresh = makeContainer(transport);
    conn.emit(roomFrame(version: 9));
    await Future<void>.delayed(Duration.zero);
    projectionAfterDispose = fresh.read(liveProjectionProvider) != null;
    expect(projectionAfterDispose, isFalse);
    expect(fresh.read(liveSessionProvider).phase, LivePhase.idle);
    fresh.dispose();
  });
}
```

- [ ] **Step 2: Rodar**

Run: `flutter test test/unit/features/live/live_session_controller_reconnect_test.dart`
Expected: PASS na maioria; ajustar o que falhar. Pontos prováveis:
- `fakeAsync` + `await` dentro de `_doConnect`: usar `async.flushMicrotasks()` depois de cada `join`/`drop`, como acima.
- O `ping` no fake: `FakeLiveConnection.emit('pong')` chega em `_onMessage` **antes** do decode (o `if (text == 'pong')`).
- Dispose: `ref.onDispose` chama `_teardownConnection`, que incrementa `_gen` — o `conn.emit` tardio bate em `_onMessage` com geração velha e é ignorado; o `_sub` já foi cancelado.

- [ ] **Step 3: Commit**

```bash
git add test/unit/features/live/live_session_controller_reconnect_test.dart lib/features/live/presentation/providers/live_session_controller.dart
git commit -m "test(live): reconexão com backoff, paused/resumed, prova de vida e dispose"
```

---

### Task 12: Gestor — `startLive`, `set` com debounce, `endLive`, retomar depois de fechar a app

**Files:**
- Create: `lib/features/live/presentation/providers/live_leader_session_prefs.dart`
- Modify: `lib/features/live/presentation/providers/live_session_controller.dart`
- Test: `test/unit/features/live/live_session_controller_leader_test.dart`

**Interfaces:**
- Consumes: `liveMyRoomCodeProvider` (Task 10), `activePlaylistProvider`, `activeEntriesProvider`, `carouselFocusedKeyProvider`, `ActivePlaylistEditor.activate`.
- Produces:
  - `class LiveLeaderSessionPrefs { const ({required prefs}); LiveLeaderSession? read(); Future<void> write(LiveLeaderSession); Future<void> clear() }`, `final class LiveLeaderSession { code, playlistId, playlistName }`, pref `live_leader_session` (JSON), `liveLeaderSessionPrefsProvider`, `pendingLeaderSessionProvider: Provider<LiveLeaderSession?>` (lido no boot; `null` depois de `resumeLeader`/`endLive`/`discardLeaderSession`).
  - Controller: `Future<void> startLive({required String code, required String playlistId})`, `Future<void> endLive()`, `Future<void> resumeLeader(LiveLeaderSession)`, `Future<void> discardLeaderSession()`.
  - `LiveSnapshot liveSnapshotOfActiveList(Ref ref)` — helper que lê a lista ativa + foco.

O consumidor vê o gestor "ausente" via `presence`; o gestor que fechou a app sem encerrar vê, ao reabrir, a pref `live_leader_session` e o banner «Retomar / Encerrar» (§7). `startLive` recebe o `code` já resolvido (a Task 14 faz o `POST /api/live/room`; a UI da Task 17 encadeia os dois).

- [ ] **Step 1: Testes**

```dart
// test/unit/features/live/live_session_controller_leader_test.dart
import 'dart:convert';

import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_focused_index_provider.dart';
import 'package:coldigui/features/live/data/providers/live_providers.dart';
import 'package:coldigui/features/live/presentation/providers/live_leader_session_prefs.dart';
import 'package:coldigui/features/live/presentation/providers/live_session_controller.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fakes/fake_live_transport.dart';
import '../../../support/fakes/fake_playlists_notifier.dart';
import '../../../support/test_overrides.dart';

const code = 'k7x2m9q';
const user = AuthUser(googleSub: 'owner', sessionToken: 'sess_owner', name: 'Fulano');

final playlist = SavedPlaylist(
  playlistId: 'p1', nome: 'Culto', createdAt: DateTime(2026, 9, 14),
  entries: const [PlaylistEntry(id: 'a', kind: MaterialKind.pdf), PlaylistEntry(id: 'b', kind: MaterialKind.pdf)],
);

String roomFrame({String status = 'live', int version = 1, String role = 'leader'}) => jsonEncode({
  't': 'room', 'room': code, 'status': status, 'ownerName': 'Fulano', 'role': role, 'version': version,
  'snapshot': null, 'leaderPresent': true, 'viewers': 0,
});

Map<String, Object?> lastSent(FakeLiveTransport t) => jsonDecode(t.last.sent.last) as Map<String, Object?>;

void main() {
  late SharedPreferences prefs;
  late FakeLiveTransport transport;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    transport = FakeLiveTransport();
    container = ProviderContainer(
      overrides: [
        ...standardTestOverrides(prefs: prefs),
        liveTransportProvider.overrideWithValue(transport),
        liveWsUriProvider.overrideWithValue((c) => Uri.parse('wss://test/$c')),
        liveFocusResolverProvider.overrideWithValue((_) async => null),
        liveNavigatorProvider.overrideWithValue((_) {}),
        authStateProvider.overrideWith(() => FakeAuthNotifier(user)),
        // Lista ativa = `playlist`, sem Isar (fake da suíte de playlists).
        playlistsProvider.overrideWith(() => FakePlaylistsNotifier([playlist])),
      ],
    );
    addTearDown(container.dispose);
    container.read(activePlaylistIdProvider.notifier).set('p1');
    container.read(liveMyRoomCodeProvider.notifier).set(code);
  });

  LiveSessionController controller() => container.read(liveSessionProvider.notifier);

  test('startLive manda hello com token e start com a lista ativa e o foco', () async {
    container.read(carouselFocusedKeyProvider.notifier).focus('b');
    await controller().startLive(code: code, playlistId: 'p1');
    final sent = transport.last.sent.map((s) => jsonDecode(s) as Map<String, Object?>).toList();
    expect(sent[0]['t'], 'hello');
    expect(sent[0]['sessionToken'], 'sess_owner');
    expect(sent[1]['t'], 'start');
    final snapshot = sent[1]['snapshot'] as Map<String, Object?>;
    expect(snapshot['playlistId'], 'p1');
    expect(snapshot['name'], 'Culto');
    expect((snapshot['entries'] as List).length, 2);
    expect(snapshot['focusKey'], 'b');
    // Pref de retomada gravada.
    expect(container.read(liveLeaderSessionPrefsProvider).read()?.code, code);
  });

  test('room live como leader → isLeading; mudança de foco dispara set após o debounce', () {
    fakeAsync((async) {
      controller().startLive(code: code, playlistId: 'p1');
      async.flushMicrotasks();
      transport.last.emit(roomFrame());
      async.flushMicrotasks();
      expect(container.read(liveSessionProvider).isLeading, isTrue);

      final before = transport.last.sent.length;
      container.read(carouselFocusedKeyProvider.notifier).focus('b');
      async.elapse(const Duration(milliseconds: 299));
      expect(transport.last.sent.length, before);
      async.elapse(const Duration(milliseconds: 1));
      expect(lastSent(transport)['t'], 'set');
      expect((lastSent(transport)['snapshot'] as Map)['focusKey'], 'b');
    });
  });

  test('ack atualiza version e viewers', () async {
    await controller().startLive(code: code, playlistId: 'p1');
    transport.last.emit(roomFrame());
    transport.last.emit(jsonEncode({'t': 'ack', 'room': code, 'version': 7, 'viewers': 12}));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(liveSessionProvider).version, 7);
    expect(container.read(liveSessionProvider).viewers, 12);
  });

  test('ao religar, o gestor reenvia set com a lista corrente', () async {
    await controller().startLive(code: code, playlistId: 'p1');
    transport.last.emit(roomFrame());
    await Future<void>.delayed(Duration.zero);
    await transport.last.drop();
    await Future<void>.delayed(Duration.zero);
    controller().onConnectivity(true);
    await Future<void>.delayed(Duration.zero);
    transport.last.emit(roomFrame(version: 3));
    await Future<void>.delayed(Duration.zero);
    expect(lastSent(transport)['t'], 'set');
  });

  test('endLive manda end, vai a ended{leader} e apaga a pref', () async {
    await controller().startLive(code: code, playlistId: 'p1');
    transport.last.emit(roomFrame());
    await Future<void>.delayed(Duration.zero);
    await controller().endLive();
    expect(lastSent(transport)['t'], 'end');
    expect(container.read(liveSessionProvider).phase, LivePhase.ended);
    expect(container.read(liveSessionProvider).endReason, LiveEndReason.leader);
    expect(container.read(liveLeaderSessionPrefsProvider).read(), isNull);
  });

  test('segundo dispositivo: ended{replaced} + 4002 → ended, pref apagada', () async {
    await controller().startLive(code: code, playlistId: 'p1');
    transport.last.emit(roomFrame());
    transport.last.emit(jsonEncode({'t': 'ended', 'room': code, 'reason': 'replaced'}));
    await transport.last.drop(code: 4002);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(liveSessionProvider).endReason, LiveEndReason.replaced);
    expect(container.read(liveLeaderSessionPrefsProvider).read(), isNull);
  });

  test('room ended para quem retoma tarde limpa a pref', () async {
    await container.read(liveLeaderSessionPrefsProvider).write(const LiveLeaderSession(code: code, playlistId: 'p1', playlistName: 'Culto'));
    await controller().resumeLeader(const LiveLeaderSession(code: code, playlistId: 'p1', playlistName: 'Culto'));
    transport.last.emit(roomFrame(status: 'ended'));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(liveSessionProvider).roomStatus, LiveRoomStatus.ended);
    expect(container.read(liveLeaderSessionPrefsProvider).read(), isNull);
  });

  test('not_leader no hello (token de outra conta) deixa o consumidor e marca lastError', () async {
    container.read(liveMyRoomCodeProvider.notifier).set(null);
    await controller().join(code);
    transport.last.emit(jsonEncode({'t': 'error', 'room': code, 'code': 'not_leader'}));
    transport.last.emit(roomFrame(role: 'consumer'));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(liveSessionProvider).role, LiveRole.consumer);
  });
}
```

`FakeAuthNotifier` e `FakePlaylistsNotifier`: ver `test/support/fakes/` — se `FakeAuthNotifier` não existir, criar em `test/support/fakes/fake_auth_notifier.dart`:

```dart
class FakeAuthNotifier extends AuthNotifier {
  FakeAuthNotifier(this._user);
  final AuthUser? _user;
  @override
  Future<AuthUser?> build() async => _user;
}
```

e conferir que `FakePlaylistsNotifier` aceita a lista inicial (adaptar o construtor se o fake existente só aceita vazio: acrescentar `FakePlaylistsNotifier([List<SavedPlaylist> initial = const []])` que devolve `[for (p in initial) PlaylistViewItem(playlist: p, pdfLabels: const [])]` no `build`).

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/live/live_session_controller_leader_test.dart`
Expected: FAIL — `startLive` não existe.

- [ ] **Step 3: Prefs**

```dart
// lib/features/live/presentation/providers/live_leader_session_prefs.dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/shared_prefs_provider.dart';

const kLiveLeaderSessionPrefsKey = 'live_leader_session';

/// «Eu estava ao vivo»: gravado em `startLive`, apagado em `endLive`/
/// `ended`. Se a app morrer a meio, o boot mostra «Retomar / Encerrar» (§7).
final class LiveLeaderSession {
  const LiveLeaderSession({required this.code, required this.playlistId, required this.playlistName});
  final String code;
  final String playlistId;
  final String playlistName;

  Map<String, Object?> toJson() => {'code': code, 'playlistId': playlistId, 'playlistName': playlistName};

  static LiveLeaderSession? fromJson(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final code = raw['code'];
    final playlistId = raw['playlistId'];
    if (code is! String || playlistId is! String) return null;
    return LiveLeaderSession(code: code, playlistId: playlistId, playlistName: raw['playlistName'] as String? ?? '');
  }
}

class LiveLeaderSessionPrefs {
  const LiveLeaderSessionPrefs({required SharedPreferences prefs}) : _prefs = prefs;
  final SharedPreferences _prefs;

  LiveLeaderSession? read() {
    final raw = _prefs.getString(kLiveLeaderSessionPrefsKey);
    if (raw == null) return null;
    try {
      return LiveLeaderSession.fromJson(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  Future<void> write(LiveLeaderSession session) =>
      _prefs.setString(kLiveLeaderSessionPrefsKey, jsonEncode(session.toJson()));

  Future<void> clear() => _prefs.remove(kLiveLeaderSessionPrefsKey);
}

final liveLeaderSessionPrefsProvider = Provider<LiveLeaderSessionPrefs>(
  (ref) => LiveLeaderSessionPrefs(prefs: ref.read(sharedPreferencesProvider)),
);

/// Sessão de gestor deixada pendente pelo último processo, ou `null`.
/// Invalidar depois de retomar/encerrar/descartar.
final pendingLeaderSessionProvider = Provider<LiveLeaderSession?>(
  (ref) => ref.read(liveLeaderSessionPrefsProvider).read(),
);
```

- [ ] **Step 4: Controller — parte do gestor**

Imports novos em `live_session_controller.dart`:

```dart
import '../../../playlists/presentation/providers/active_playlist_provider.dart';
import 'live_leader_session_prefs.dart';
```

Helper (nível de arquivo):

```dart
/// A lista ativa (com override otimista) + foco, no formato do DO.
LiveSnapshot liveSnapshotOfActiveList(Ref ref) {
  final playlist = ref.read(activePlaylistProvider);
  final entries = ref.read(activeEntriesProvider);
  final focus = ref.read(carouselFocusedKeyProvider);
  return LiveSnapshot(
    playlistId: playlist?.playlistId ?? '',
    name: playlist?.nome ?? '',
    entries: [for (final e in entries) e.entry],
    focusKey: focus != null && entries.any((e) => e.key == focus) ? focus : null,
  );
}
```

Métodos públicos (após `onConnectivity`):

```dart
  /// Gestor: entra na própria sala e começa a transmitir a lista ativa.
  /// [code] é a sala do usuário (Task 14) e [playlistId] tem de ser a lista
  /// ativa (a UI chama `activate` antes).
  Future<void> startLive({required String code, required String playlistId}) async {
    ref.read(liveMyRoomCodeProvider.notifier).set(code);
    await ref.read(liveLeaderSessionPrefsProvider).write(LiveLeaderSession(
      code: code,
      playlistId: playlistId,
      playlistName: ref.read(activePlaylistProvider)?.nome ?? '',
    ));
    ref.invalidate(pendingLeaderSessionProvider);
    _pendingStart = true;
    if (state.code != code || !state.isConnectedOrRetrying) {
      await join(code);
    }
    _conn?.send(encodeLiveStart(liveSnapshotOfActiveList(ref)));
    state = state.copyWith(role: LiveRole.leader, roomStatus: LiveRoomStatus.live);
  }

  /// Gestor: encerra a sessão para todos.
  Future<void> endLive() async {
    _setDebounce?.cancel();
    _pendingStart = false;
    _conn?.send(encodeLiveEnd());
    await ref.read(liveLeaderSessionPrefsProvider).clear();
    ref.invalidate(pendingLeaderSessionProvider);
    _finish(LivePhase.ended, reason: LiveEndReason.leader);
  }

  /// Boot: retoma a sessão gravada. Se o DO já encerrou por inatividade, o
  /// `room{ended}` que volta limpa a pref (`_onRoomAsLeader`).
  Future<void> resumeLeader(LiveLeaderSession session) async {
    ref.read(liveMyRoomCodeProvider.notifier).set(session.code);
    await join(session.code);
  }

  Future<void> discardLeaderSession() async {
    await ref.read(liveLeaderSessionPrefsProvider).clear();
    ref.invalidate(pendingLeaderSessionProvider);
  }
```

Substituir os stubs do fim da classe:

```dart
  void _onLocalListChanged() => _scheduleLeaderSet();

  void _onLocalFocusChanged(String? key) => _scheduleLeaderSet();

  void _scheduleLeaderSet() {
    if (!state.isLeading || _conn == null) return;
    _setDebounce?.cancel();
    _setDebounce = Timer(kLiveLeaderSetDebounce, () {
      if (!ref.mounted || !state.isLeading) return;
      _conn?.send(encodeLiveSet(liveSnapshotOfActiveList(ref)));
    });
  }

  void _onRoomAsLeader(LiveRoomFrame frame) {
    if (frame.role != LiveRole.leader) return;
    if (frame.status == LiveRoomStatus.live) {
      _pendingStart = false;
      // Religou (ou retomou): o que está no aparelho vence o que o DO tem.
      _conn?.send(encodeLiveSet(liveSnapshotOfActiveList(ref)));
      return;
    }
    if (_pendingStart) {
      // O `start` de `startLive` não chegou (handshake falhou antes): manda agora.
      _conn?.send(encodeLiveStart(liveSnapshotOfActiveList(ref)));
      state = state.copyWith(roomStatus: LiveRoomStatus.live);
      return;
    }
    // Sala idle/ended: a sessão gravada já não vale.
    unawaited(ref.read(liveLeaderSessionPrefsProvider).clear());
    ref.invalidate(pendingLeaderSessionProvider);
  }
```

E em `_finish`, quando `reason == LiveEndReason.replaced || reason == LiveEndReason.inactivity || reason == LiveEndReason.retired` e `state.role == LiveRole.leader`: apagar a pref (`unawaited(ref.read(liveLeaderSessionPrefsProvider).clear()); ref.invalidate(pendingLeaderSessionProvider);`).

Na Task 13 `_onLocalFocusChanged` ganha também o ramo do consumidor; aqui só o do gestor.

- [ ] **Step 5: Verde**

Run: `flutter test test/unit/features/live/ && dart format lib/features/live test/unit/features/live test/support/fakes`
Expected: PASS. Se «ao religar…» falhar: `onConnectivity(true)` só religa em `reconnecting` — confirmar que o `drop()` foi seguido de `flushMicrotasks`/`delayed(Duration.zero)` para `_onDisconnect` rodar.

- [ ] **Step 6: Commit**

```bash
git add lib/features/live test/unit/features/live/live_session_controller_leader_test.dart test/support/fakes
git commit -m "feat(live): gestor — startLive/set com debounce/endLive e retomada após fechar a app"
```

---

### Task 13: D3 — o foco só sinaliza quando o consumidor desviou; «Voltar ao gestor»

**Files:**
- Modify: `lib/features/live/presentation/providers/live_session_controller.dart`
- Test: `test/unit/features/live/live_session_controller_focus_test.dart`

**Interfaces:**
- Produces: `void returnToLeader()`; `LiveSessionState.followingFocus` passa a mudar.

- [ ] **Step 1: Testes**

```dart
// test/unit/features/live/live_session_controller_focus_test.dart
import 'dart:convert';

import 'package:coldigui/features/carousel/presentation/providers/carousel_focused_index_provider.dart';
import 'package:coldigui/features/live/data/providers/live_providers.dart';
import 'package:coldigui/features/live/presentation/providers/live_session_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fakes/fake_live_transport.dart';
import '../../../support/test_overrides.dart';

const code = 'k7x2m9q';
const _entries = [{'id': 'a', 'kind': 'pdf'}, {'id': 'b', 'kind': 'pdf'}, {'id': 'c', 'kind': 'pdf'}];

String roomFrame(String focus) => jsonEncode({'t': 'room', 'room': code, 'status': 'live', 'ownerName': 'F', 'role': 'consumer', 'version': 1,
  'snapshot': {'playlistId': 'p1', 'name': 'n', 'entries': _entries, 'focusKey': focus}, 'leaderPresent': true, 'viewers': 1});
String snapshotFrame(int version, String focus) => jsonEncode({'t': 'snapshot', 'room': code, 'version': version,
  'snapshot': {'playlistId': 'p1', 'name': 'n', 'entries': _entries, 'focusKey': focus}, 'viewers': 1});

void main() {
  late ProviderContainer container;
  late FakeLiveTransport transport;
  late List<String> navigated;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    transport = FakeLiveTransport();
    navigated = [];
    container = ProviderContainer(overrides: [
      ...standardTestOverrides(prefs: prefs),
      liveTransportProvider.overrideWithValue(transport),
      liveWsUriProvider.overrideWithValue((c) => Uri.parse('wss://test/$c')),
      liveFocusResolverProvider.overrideWithValue((key) async {
        container.read(carouselFocusedIndexProvider.notifier).focusKey(key);
        return '/leitor?key=$key';
      }),
      liveNavigatorProvider.overrideWithValue(navigated.add),
    ]);
    addTearDown(container.dispose);
    await container.read(liveSessionProvider.notifier).join(code);
    transport.last.emit(roomFrame('a'));
    await Future<void>.delayed(Duration.zero);
  });

  LiveSessionState state() => container.read(liveSessionProvider);

  test('enquanto segue, cada foco do gestor navega e followingFocus fica true', () async {
    expect(navigated, ['/leitor?key=a']);
    transport.last.emit(snapshotFrame(2, 'b'));
    await Future<void>.delayed(Duration.zero);
    expect(navigated, ['/leitor?key=a', '/leitor?key=b']);
    expect(state().followingFocus, isTrue);
    expect(container.read(carouselFocusedKeyProvider), 'b');
  });

  test('navegação própria do consumidor desliga followingFocus; o próximo foco do gestor só sinaliza', () async {
    container.read(carouselFocusedIndexProvider.notifier).focusKey('c');
    expect(state().followingFocus, isFalse);
    transport.last.emit(snapshotFrame(2, 'b'));
    await Future<void>.delayed(Duration.zero);
    expect(navigated, ['/leitor?key=a']);
    expect(container.read(carouselFocusedKeyProvider), 'c');
  });

  test('returnToLeader volta ao foco do gestor e religa o seguimento', () async {
    container.read(carouselFocusedIndexProvider.notifier).focusKey('c');
    transport.last.emit(snapshotFrame(2, 'b'));
    await Future<void>.delayed(Duration.zero);
    container.read(liveSessionProvider.notifier).returnToLeader();
    await Future<void>.delayed(Duration.zero);
    expect(navigated.last, '/leitor?key=b');
    expect(state().followingFocus, isTrue);
    transport.last.emit(snapshotFrame(3, 'a'));
    await Future<void>.delayed(Duration.zero);
    expect(navigated.last, '/leitor?key=a');
  });

  test('o foco aplicado pelo próprio controller não conta como desvio', () async {
    transport.last.emit(snapshotFrame(2, 'c'));
    await Future<void>.delayed(Duration.zero);
    expect(state().followingFocus, isTrue);
  });

  test('sair reinicia followingFocus', () async {
    container.read(carouselFocusedIndexProvider.notifier).focusKey('c');
    await container.read(liveSessionProvider.notifier).leave();
    expect(state().followingFocus, isTrue);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/live/live_session_controller_focus_test.dart`
Expected: FAIL — `returnToLeader` não existe / `followingFocus` nunca muda.

- [ ] **Step 3: Implementar**

Em `live_session_controller.dart`:

```dart
  /// D3: o consumidor desviou e quer voltar para onde o gestor está.
  void returnToLeader() {
    if (!state.isFollowing) return;
    state = state.copyWith(followingFocus: true);
    final focus = _leaderFocusKey;
    if (focus != null) unawaited(_applyLeaderFocus(focus));
  }

  void _onLocalFocusChanged(String? key) {
    if (state.isFollowing) {
      if (_applyingFocus) return;
      if (key != null && key != _leaderFocusKey && state.followingFocus) {
        state = state.copyWith(followingFocus: false);
      }
      return;
    }
    _scheduleLeaderSet();
  }
```

- [ ] **Step 4: Verde e commit**

Run: `flutter test test/unit/features/live/ && dart format lib/features/live test/unit/features/live`

```bash
git add lib/features/live/presentation/providers/live_session_controller.dart test/unit/features/live/live_session_controller_focus_test.dart
git commit -m "feat(live): foco do gestor só sinaliza quando o consumidor desviou (D3); returnToLeader"
```

---

### Task 14: `LiveRoomRemoteDatasource` + `myLiveRoomProvider`

**Files:**
- Modify: `lib/core/constants/api_endpoints.dart`
- Create: `lib/features/live/data/live_room_remote_datasource.dart`
- Create: `lib/features/live/presentation/providers/my_live_room_provider.dart`
- Test: `test/unit/features/live/live_room_remote_datasource_test.dart`

**Interfaces:**
- Produces:
  - `ApiEndpoints.liveRoom = '/api/live/room'`, `ApiEndpoints.liveRoomRegenerate = '/api/live/room/regenerate'`.
  - `final class LiveRoomInfo { code, url, ownerName }`
  - `class LiveRoomRemoteDatasource { LiveRoomRemoteDatasource(Dio, {required String? Function() sessionToken}); Future<LiveRoomInfo> ensureRoom(); Future<LiveRoomInfo> regenerate() }` — lança `DioException` em 4xx/5xx; `StateError('unauthenticated')` sem token.
  - `liveRoomRemoteDatasourceProvider`, `myLiveRoomProvider: AsyncNotifierProvider<MyLiveRoomNotifier, LiveRoomInfo?>` (`null` deslogado; `Future<LiveRoomInfo> ensure()`, `Future<LiveRoomInfo> regenerate()`; cada resposta grava `liveMyRoomCodeProvider`).

- [ ] **Step 1: Teste do datasource**

```dart
// test/unit/features/live/live_room_remote_datasource_test.dart
import 'dart:convert';

import 'package:coldigui/features/live/data/live_room_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adapter que devolve [status]/[body] e grava a request.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.status, this.body);
  final int status;
  final Map<String, Object?> body;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    last = options;
    return ResponseBody.fromString(jsonEncode(body), status, headers: {'content-type': ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('ensureRoom faz POST /api/live/room com Bearer e devolve LiveRoomInfo', () async {
    final adapter = _RecordingAdapter(200, {'code': 'k7x2m9q', 'url': 'https://plpcg.com/ao-vivo/k7x2m9q', 'ownerName': 'Fulano'});
    final dio = Dio(BaseOptions(baseUrl: 'https://plpcg.com'))..httpClientAdapter = adapter;
    final ds = LiveRoomRemoteDatasource(dio, sessionToken: () => 'sess_x');
    final info = await ds.ensureRoom();
    expect(adapter.last!.method, 'POST');
    expect(adapter.last!.path, '/api/live/room');
    expect(adapter.last!.headers['Authorization'], 'Bearer sess_x');
    expect(info.code, 'k7x2m9q');
    expect(info.ownerName, 'Fulano');
  });

  test('regenerate usa /regenerate', () async {
    final adapter = _RecordingAdapter(200, {'code': 'abcdefg', 'url': 'u', 'ownerName': 'F'});
    final dio = Dio(BaseOptions(baseUrl: 'https://plpcg.com'))..httpClientAdapter = adapter;
    final info = await LiveRoomRemoteDatasource(dio, sessionToken: () => 'sess_x').regenerate();
    expect(adapter.last!.path, '/api/live/room/regenerate');
    expect(info.code, 'abcdefg');
  });

  test('sem token lança StateError sem bater na rede', () async {
    final adapter = _RecordingAdapter(200, {});
    final dio = Dio()..httpClientAdapter = adapter;
    await expectLater(LiveRoomRemoteDatasource(dio, sessionToken: () => null).ensureRoom(), throwsStateError);
    expect(adapter.last, isNull);
  });

  test('401 propaga DioException', () async {
    final adapter = _RecordingAdapter(401, {'error': 'unauthorized'});
    final dio = Dio(BaseOptions(baseUrl: 'https://plpcg.com'))..httpClientAdapter = adapter;
    await expectLater(LiveRoomRemoteDatasource(dio, sessionToken: () => 'sess_x').ensureRoom(), throwsA(isA<DioException>()));
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/live/live_room_remote_datasource_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implementar**

`api_endpoints.dart`, depois de `links`:

```dart
  /// Sala «ao vivo» do usuário — Worker + D1 `live_rooms` + DO `LiveRoom`.
  ///
  /// `POST` + Bearer → `{ code, url, ownerName }` (cria ou devolve).
  static const String liveRoom = '/api/live/room';

  /// `POST` + Bearer → novo código; o link antigo morre.
  static const String liveRoomRegenerate = '/api/live/room/regenerate';
```

```dart
// lib/features/live/data/live_room_remote_datasource.dart
import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';

final class LiveRoomInfo {
  const LiveRoomInfo({required this.code, required this.url, required this.ownerName});
  final String code;
  final String url;
  final String ownerName;

  static LiveRoomInfo fromJson(Map<String, dynamic> json) => LiveRoomInfo(
    code: json['code'] as String,
    url: json['url'] as String,
    ownerName: json['ownerName'] as String? ?? '',
  );
}

/// `POST /api/live/room[/regenerate]` no Worker `plpcg-catalog`.
class LiveRoomRemoteDatasource {
  LiveRoomRemoteDatasource(this._dio, {required this.sessionToken});

  final Dio _dio;

  /// Token de sessão corrente; `null` = deslogado → [StateError].
  final String? Function() sessionToken;

  Future<LiveRoomInfo> ensureRoom() => _post(ApiEndpoints.liveRoom);

  Future<LiveRoomInfo> regenerate() => _post(ApiEndpoints.liveRoomRegenerate);

  Future<LiveRoomInfo> _post(String path) async {
    final token = sessionToken();
    if (token == null || token.isEmpty) throw StateError('unauthenticated');
    final response = await _dio.post<Map<String, dynamic>>(
      path,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return LiveRoomInfo.fromJson(response.data!);
  }
}
```

```dart
// lib/features/live/presentation/providers/my_live_room_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/dio_provider.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../data/live_room_remote_datasource.dart';
import '../../data/providers/live_providers.dart';

final liveRoomRemoteDatasourceProvider = Provider<LiveRoomRemoteDatasource>((ref) {
  return LiveRoomRemoteDatasource(
    ref.watch(dioProvider),
    sessionToken: () => ref.read(authStateProvider).asData?.value?.sessionToken,
  );
});

/// A sala do usuário logado. `null` deslogado; carregada sob demanda
/// ([ensure]) — o boot não bate no Worker por isto.
class MyLiveRoomNotifier extends AsyncNotifier<LiveRoomInfo?> {
  @override
  Future<LiveRoomInfo?> build() async {
    final user = ref.watch(authStateProvider).asData?.value;
    if (user == null) {
      ref.read(liveMyRoomCodeProvider.notifier).set(null);
      return null;
    }
    return null;
  }

  Future<LiveRoomInfo> ensure() async {
    final current = state.asData?.value;
    if (current != null) return current;
    final info = await ref.read(liveRoomRemoteDatasourceProvider).ensureRoom();
    ref.read(liveMyRoomCodeProvider.notifier).set(info.code);
    state = AsyncData(info);
    return info;
  }

  Future<LiveRoomInfo> regenerate() async {
    final info = await ref.read(liveRoomRemoteDatasourceProvider).regenerate();
    ref.read(liveMyRoomCodeProvider.notifier).set(info.code);
    state = AsyncData(info);
    return info;
  }
}

final myLiveRoomProvider = AsyncNotifierProvider<MyLiveRoomNotifier, LiveRoomInfo?>(
  MyLiveRoomNotifier.new,
);
```

- [ ] **Step 4: Verde e commit**

Run: `flutter test test/unit/features/live/ && dart format lib/core/constants/api_endpoints.dart lib/features/live test/unit/features/live`

```bash
git add lib/core/constants/api_endpoints.dart lib/features/live/data/live_room_remote_datasource.dart lib/features/live/presentation/providers/my_live_room_provider.dart test/unit/features/live/live_room_remote_datasource_test.dart
git commit -m "feat(live): datasource da sala (POST /api/live/room, regenerate) e myLiveRoomProvider"
```

---

### Task 15: «Guardar cópia» — `SaveLiveCopy`

**Files:**
- Create: `lib/features/live/domain/usecases/save_live_copy.dart`
- Modify: `lib/features/live/data/providers/live_providers.dart` — `saveLiveCopyProvider`
- Test: `test/unit/features/live/save_live_copy_test.dart`

**Interfaces:**
- Consumes: `PlaylistRepository.create`, `PlaylistSyncStatus.pendingPush`, `LiveSnapshot`.
- Produces: `class SaveLiveCopy { const SaveLiveCopy(PlaylistRepository); Future<SavedPlaylist> call({required LiveSnapshot snapshot, required String copyName}) }`; `saveLiveCopyProvider: Provider<SaveLiveCopy>`.

Mesmo contrato de `DuplicatePlaylist` (spec D4): lista **salva**, `syncStatus: pendingPush`, nunca publicada. O nome vem pronto do chamador (ARB `liveCopyName`: «{nome} (ao vivo com {gestor})»).

- [ ] **Step 1: Teste**

```dart
// test/unit/features/live/save_live_copy_test.dart
import 'package:coldigui/features/live/domain/entities/live_snapshot.dart';
import 'package:coldigui/features/live/domain/usecases/save_live_copy.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/domain/repositories/playlist_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Só o que o use case toca: `create` grava, `getById` devolve.
class _MemoryRepository implements PlaylistRepository {
  final Map<String, SavedPlaylist> rows = {};
  var nextId = 0;

  @override
  Future<String> create({required String nome, List<PlaylistEntry>? entries, List<String> pdfIds = const [], List<String> audioIds = const [],
      String? playlistId, DateTime? createdAt, bool salva = true, DateTime? savedAt, DateTime? updatedAt, int version = 1,
      PlaylistSyncStatus syncStatus = PlaylistSyncStatus.synced, String? ownerSub}) async {
    final id = playlistId ?? 'id-${nextId++}';
    rows[id] = SavedPlaylist(playlistId: id, nome: nome, createdAt: createdAt ?? DateTime(2026), entries: entries ?? const [],
        salva: salva, savedAt: savedAt, syncStatus: syncStatus, ownerSub: ownerSub);
    return id;
  }

  @override
  Future<SavedPlaylist?> getById(String playlistId) async => rows[playlistId];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

void main() {
  test('cria lista salva pendingPush com as entradas do snapshot, na ordem e com repetições', () async {
    final repo = _MemoryRepository();
    final snapshot = LiveSnapshot(playlistId: 'remota', name: 'Culto', entries: const [
      PlaylistEntry(id: 'a', kind: MaterialKind.pdf),
      PlaylistEntry(id: 'a', kind: MaterialKind.pdf),
      PlaylistEntry(id: 't', kind: MaterialKind.audio),
    ], focusKey: null);
    final saved = await const SaveLiveCopy(repo).call(snapshot: snapshot, copyName: 'Culto (ao vivo com Fulano)');
    expect(saved.nome, 'Culto (ao vivo com Fulano)');
    expect(saved.salva, isTrue);
    expect(saved.syncStatus, PlaylistSyncStatus.pendingPush);
    expect(saved.entries, snapshot.entries);
    expect(saved.playlistId, isNot('remota')); // id novo, nunca o do gestor
  });

  test('snapshot vazio lança StateError', () async {
    final snapshot = LiveSnapshot(playlistId: 'r', name: 'n', entries: const [], focusKey: null);
    await expectLater(const SaveLiveCopy(_MemoryRepository()).call(snapshot: snapshot, copyName: 'x'), throwsStateError);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/unit/features/live/save_live_copy_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implementar**

```dart
// lib/features/live/domain/usecases/save_live_copy.dart
import '../../../playlists/domain/entities/saved_playlist.dart';
import '../../../playlists/domain/repositories/playlist_repository.dart';
import '../entities/live_snapshot.dart';

/// «Guardar cópia» (spec D4): a projeção do gestor vira uma lista **salva**
/// do consumidor — mesmo contrato de `DuplicatePlaylist` (`pendingPush`,
/// nunca publicada, id novo). [copyName] já vem formatado (ARB `liveCopyName`).
class SaveLiveCopy {
  const SaveLiveCopy(this._repository);

  final PlaylistRepository _repository;

  /// Lança [StateError] com snapshot vazio.
  Future<SavedPlaylist> call({required LiveSnapshot snapshot, required String copyName}) async {
    if (snapshot.entries.isEmpty) {
      throw StateError('SaveLiveCopy: snapshot sem entradas');
    }
    final now = DateTime.now();
    final id = await _repository.create(
      nome: copyName,
      entries: snapshot.entries,
      salva: true,
      savedAt: now,
      createdAt: now,
      syncStatus: PlaylistSyncStatus.pendingPush,
    );
    final created = await _repository.getById(id);
    if (created == null) {
      throw StateError('SaveLiveCopy: cópia $id não encontrada após criar');
    }
    return created;
  }
}
```

Em `live_providers.dart`:

```dart
import '../../../playlists/data/providers/playlist_providers.dart';
import '../../domain/usecases/save_live_copy.dart';

final saveLiveCopyProvider = Provider<SaveLiveCopy>(
  (ref) => SaveLiveCopy(ref.watch(playlistRepositoryProvider)),
);
```

- [ ] **Step 4: Verde e commit**

Run: `flutter test test/unit/features/live/ && dart format lib/features/live test/unit/features/live`

```bash
git add lib/features/live/domain/usecases/save_live_copy.dart lib/features/live/data/providers/live_providers.dart test/unit/features/live/save_live_copy_test.dart
git commit -m "feat(live): SaveLiveCopy — guardar a lista do gestor como lista salva"
```

---

### Task 16: `LiveSessionBanner` + `LiveLifecycleListener` no shell (+ l10n)

**Files:**
- Create: `lib/features/live/presentation/widgets/live_session_banner.dart`
- Create: `lib/features/live/presentation/widgets/live_lifecycle_listener.dart`
- Modify: `lib/features/app_shell/presentation/shell_scaffold.dart:186-191,193`
- Modify: `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb`
- Test: `test/widget/features/live/live_session_banner_test.dart`

**Interfaces:**
- Consumes: `liveSessionProvider`, `pendingLeaderSessionProvider`, `liveRoomRouteFor`.
- Produces: `class LiveSessionBanner extends ConsumerWidget` (renderiza `SizedBox.shrink` quando não há nada a dizer); `class LiveLifecycleListener extends ConsumerStatefulWidget { child }` (encaminha `didChangeAppLifecycleState` → `onAppLifecycle` e `connectivityStreamProvider` → `onConnectivity`).

Estados do banner (um widget, os dois papéis):

| Estado | Texto | Ações |
|---|---|---|
| consumidor `connected` + sala `live` | «Seguindo {ownerName} · {name}» (+ «gestor ausente» se `!leaderPresent`) | «Voltar ao gestor» (se `!followingFocus`), «Sair» |
| consumidor `connected` + sala `idle`/`ended` | «Aguardando {ownerName}» | «Sair» |
| `reconnecting` (qualquer papel) | «Reconectando…» | «Sair» |
| gestor `isLeading` | «AO VIVO · {viewers}» | «Sala» (→ `/ao-vivo/<code>`), «Encerrar» (confirma) |
| gestor `ended{replaced}` | «Sessão assumida noutro dispositivo» | «OK» (→ `leave()`) |
| `phase == idle` e `pendingLeaderSession != null` | «Você estava ao vivo com «{playlistName}»» | «Retomar», «Encerrar» |

Tudo o resto (idle sem pendente, left, ended de consumidor, unavailable, notFound) → nada; a tela da sala (Task 17) trata esses.

- [ ] **Step 1: ARBs**

Em `app_pt.arb` (e as traduções em `app_en.arb`):

```json
  "liveFollowing": "Seguindo {owner} · {list}",
  "@liveFollowing": {"description": "Banner do consumidor numa sessão ao vivo", "placeholders": {"owner": {"type": "String"}, "list": {"type": "String"}}},
  "liveLeaderAway": "gestor ausente",
  "liveWaitingFor": "Aguardando {owner}",
  "@liveWaitingFor": {"placeholders": {"owner": {"type": "String"}}},
  "liveReconnecting": "Reconectando…",
  "liveReturnToLeader": "Voltar ao gestor",
  "liveLeave": "Sair",
  "liveOnAir": "AO VIVO · {viewers}",
  "@liveOnAir": {"description": "Banner do gestor; viewers = pessoas conectadas", "placeholders": {"viewers": {"type": "int"}}},
  "liveRoom": "Sala",
  "liveEnd": "Encerrar",
  "liveEndConfirmTitle": "Encerrar a sessão ao vivo?",
  "liveEndConfirmBody": "Todos os que estão seguindo vão parar de receber a lista.",
  "liveReplacedElsewhere": "Sessão assumida em outro dispositivo",
  "liveOk": "OK",
  "liveWasLive": "Você estava ao vivo com «{list}»",
  "@liveWasLive": {"placeholders": {"list": {"type": "String"}}},
  "liveResume": "Retomar",
```

en: «Following {owner} · {list}», «host away», «Waiting for {owner}», «Reconnecting…», «Back to host», «Leave», «LIVE · {viewers}», «Room», «End», «End the live session?», «Everyone following will stop receiving the list.», «Session taken over on another device», «OK», «You were live with “{list}”», «Resume».

Run: `flutter gen-l10n`.

- [ ] **Step 2: Teste do banner**

```dart
// test/widget/features/live/live_session_banner_test.dart
import 'package:coldigui/features/live/domain/entities/live_snapshot.dart';
import 'package:coldigui/features/live/presentation/providers/live_leader_session_prefs.dart';
import 'package:coldigui/features/live/presentation/providers/live_session_controller.dart';
import 'package:coldigui/features/live/presentation/widgets/live_session_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/pump_app.dart';
import '../../../support/test_overrides.dart';

/// Controller que só expõe o estado que o teste quer e grava as chamadas.
class _StubController extends LiveSessionController {
  _StubController(this._initial);
  final LiveSessionState _initial;
  final List<String> calls = [];
  @override
  LiveSessionState build() => _initial;
  @override
  Future<void> leave() async { calls.add('leave'); }
  @override
  Future<void> endLive() async { calls.add('endLive'); }
  @override
  void returnToLeader() { calls.add('returnToLeader'); }
  @override
  Future<void> resumeLeader(LiveLeaderSession session) async { calls.add('resume:${session.code}'); }
  @override
  Future<void> discardLeaderSession() async { calls.add('discard'); }
}

void main() {
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  final snapshot = LiveSnapshot(playlistId: 'p', name: 'Culto', entries: const [PlaylistEntry(id: 'a', kind: MaterialKind.pdf)], focusKey: 'a');

  Future<_StubController> pump(WidgetTester tester, LiveSessionState state) async {
    final stub = _StubController(state);
    await pumpApp(tester, const LiveSessionBanner(), overrides: [
      ...standardTestOverrides(prefs: prefs),
      liveSessionProvider.overrideWith(() => stub),
    ]);
    return stub;
  }

  testWidgets('consumidor seguindo: nome do gestor, lista, Sair; sem «Voltar» enquanto segue o foco', (tester) async {
    await pump(tester, LiveSessionState(phase: LivePhase.connected, code: 'c', role: LiveRole.consumer,
        roomStatus: LiveRoomStatus.live, ownerName: 'Fulano', snapshot: snapshot, leaderPresent: true, viewers: 3));
    expect(find.text('Seguindo Fulano · Culto'), findsOneWidget);
    expect(find.text('Sair'), findsOneWidget);
    expect(find.text('Voltar ao gestor'), findsNothing);
  });

  testWidgets('desviou: «Voltar ao gestor» chama returnToLeader; gestor ausente aparece', (tester) async {
    final stub = await pump(tester, LiveSessionState(phase: LivePhase.connected, code: 'c', role: LiveRole.consumer,
        roomStatus: LiveRoomStatus.live, ownerName: 'Fulano', snapshot: snapshot, leaderPresent: false, followingFocus: false));
    expect(find.textContaining('gestor ausente'), findsOneWidget);
    await tester.tap(find.text('Voltar ao gestor'));
    expect(stub.calls, ['returnToLeader']);
  });

  testWidgets('reconectando mostra o estado e Sair chama leave', (tester) async {
    final stub = await pump(tester, const LiveSessionState(phase: LivePhase.reconnecting, code: 'c', role: LiveRole.consumer, roomStatus: LiveRoomStatus.live));
    expect(find.text('Reconectando…'), findsOneWidget);
    await tester.tap(find.text('Sair'));
    expect(stub.calls, ['leave']);
  });

  testWidgets('gestor ao vivo: AO VIVO · N, Sala e Encerrar com confirmação', (tester) async {
    final stub = await pump(tester, const LiveSessionState(phase: LivePhase.connected, code: 'c', role: LiveRole.leader, roomStatus: LiveRoomStatus.live, viewers: 23));
    expect(find.text('AO VIVO · 23'), findsOneWidget);
    await tester.tap(find.text('Encerrar'));
    await tester.pumpAndSettle();
    expect(find.text('Encerrar a sessão ao vivo?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Encerrar').last);
    await tester.pumpAndSettle();
    expect(stub.calls, ['endLive']);
  });

  testWidgets('sessão pendente do gestor: Retomar / Encerrar', (tester) async {
    await prefs.setString(kLiveLeaderSessionPrefsKey, '{"code":"k7x2m9q","playlistId":"p1","playlistName":"Culto"}');
    final stub = await pump(tester, const LiveSessionState());
    expect(find.text('Você estava ao vivo com «Culto»'), findsOneWidget);
    await tester.tap(find.text('Retomar'));
    expect(stub.calls, ['resume:k7x2m9q']);
  });

  testWidgets('idle sem nada pendente não renderiza', (tester) async {
    await pump(tester, const LiveSessionState());
    expect(find.byType(LiveSessionBanner), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byIcon(Icons.sensors), findsNothing);
  });
}
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `flutter test test/widget/features/live/live_session_banner_test.dart`
Expected: FAIL — widget não existe.

- [ ] **Step 4: Banner**

```dart
// lib/features/live/presentation/widgets/live_session_banner.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/live_room_link.dart';
import '../providers/live_leader_session_prefs.dart';
import '../providers/live_session_controller.dart';

/// Faixa persistente acima da barra da lista ativa (spec §6.3): diz a quem
/// segue quem está a seguir, e ao gestor quantos seguem. Um widget para os
/// dois papéis — a barra não tem largura para um indicador próprio.
class LiveSessionBanner extends ConsumerWidget {
  const LiveSessionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(liveSessionProvider);
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(liveSessionProvider.notifier);

    if (state.phase == LivePhase.idle) {
      final pending = ref.watch(pendingLeaderSessionProvider);
      if (pending == null) return const SizedBox.shrink();
      return _Bar(
        icon: Icons.sensors,
        text: l10n.liveWasLive(pending.playlistName),
        actions: [
          _Action(l10n.liveResume, () => unawaited(controller.resumeLeader(pending))),
          _Action(l10n.liveEnd, () => unawaited(controller.discardLeaderSession())),
        ],
      );
    }

    if (state.phase == LivePhase.reconnecting) {
      return _Bar(
        icon: Icons.sync,
        text: l10n.liveReconnecting,
        actions: [_Action(l10n.liveLeave, () => unawaited(controller.leave()))],
      );
    }

    if (state.role == LiveRole.leader) {
      if (state.phase == LivePhase.ended && state.endReason == LiveEndReason.replaced) {
        return _Bar(
          icon: Icons.devices_other,
          text: l10n.liveReplacedElsewhere,
          actions: [_Action(l10n.liveOk, () => unawaited(controller.leave()))],
        );
      }
      if (state.isLeading) {
        final code = state.code!;
        return _Bar(
          icon: Icons.sensors,
          text: l10n.liveOnAir(state.viewers),
          actions: [
            _Action(l10n.liveRoom, () => context.go(liveRoomRouteFor(code))),
            _Action(l10n.liveEnd, () => unawaited(_confirmEnd(context, l10n, controller))),
          ],
        );
      }
      return const SizedBox.shrink();
    }

    if (state.phase != LivePhase.connected) return const SizedBox.shrink();

    if (state.isFollowing) {
      final away = state.leaderPresent ? '' : ' · ${l10n.liveLeaderAway}';
      return _Bar(
        icon: Icons.sensors,
        text: '${l10n.liveFollowing(state.ownerName, state.snapshot?.name ?? '')}$away',
        actions: [
          if (!state.followingFocus) _Action(l10n.liveReturnToLeader, controller.returnToLeader),
          _Action(l10n.liveLeave, () => unawaited(controller.leave())),
        ],
      );
    }
    return _Bar(
      icon: Icons.hourglass_top,
      text: l10n.liveWaitingFor(state.ownerName),
      actions: [_Action(l10n.liveLeave, () => unawaited(controller.leave()))],
    );
  }

  Future<void> _confirmEnd(BuildContext context, AppLocalizations l10n, LiveSessionController controller) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.liveEndConfirmTitle),
        content: Text(l10n.liveEndConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(MaterialLocalizations.of(context).cancelButtonLabel)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.liveEnd)),
        ],
      ),
    );
    if (ok == true) await controller.endLive();
  }
}

class _Action {
  const _Action(this.label, this.onPressed);
  final String label;
  final VoidCallback onPressed;
}

class _Bar extends StatelessWidget {
  const _Bar({required this.icon, required this.text, required this.actions});
  final IconData icon;
  final String text;
  final List<_Action> actions;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.gold.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(icon, color: AppColors.gold, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: AppTypography.body.copyWith(color: AppColors.textLight, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            for (final action in actions)
              TextButton(onPressed: action.onPressed, child: Text(action.label)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Lifecycle listener**

```dart
// lib/features/live/presentation/widgets/live_lifecycle_listener.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/connectivity_stream_provider.dart';
import '../providers/live_session_controller.dart';

/// Liga o ciclo de vida da app e a conectividade ao [LiveSessionController]
/// (spec §6.1: sem retry em `paused`, retry imediato em `resumed`/online).
/// Montado no shell, como `OfflineLifecycleListener`.
class LiveLifecycleListener extends ConsumerStatefulWidget {
  const LiveLifecycleListener({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<LiveLifecycleListener> createState() => _LiveLifecycleListenerState();
}

class _LiveLifecycleListenerState extends ConsumerState<LiveLifecycleListener> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(liveSessionProvider.notifier).onAppLifecycle(state);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(connectivityStreamProvider, (_, next) {
      final online = next.asData?.value;
      if (online != null) ref.read(liveSessionProvider.notifier).onConnectivity(online);
    });
    return widget.child;
  }
}
```

- [ ] **Step 6: Shell**

Em `shell_scaffold.dart`: imports `../../live/presentation/widgets/live_session_banner.dart` e `live_lifecycle_listener.dart`; em `bodyColumn`, entre `DegradedStorageBanner` e `CarouselChips`: `const LiveSessionBanner(),`; envolver `OfflineLifecycleListener(...)` com `LiveLifecycleListener(child: …)`. Atualizar o doc-comment da classe (uma linha: «Banner da sessão ao vivo ([LiveSessionBanner]) entre o banner de storage e as chips»).

- [ ] **Step 7: Verde e commit**

Run: `flutter test test/widget/features/live/ test/widget/features/app_shell && dart format <tocados>`

```bash
git add lib/features/live/presentation/widgets lib/features/app_shell/presentation/shell_scaffold.dart lib/l10n test/widget/features/live/live_session_banner_test.dart
git commit -m "feat(live): banner da sessão ao vivo e listener de ciclo de vida no shell"
```

---

### Task 17: Tela da sala `/ao-vivo/:code` (consumidor e gestor) + rota

**Files:**
- Create: `lib/features/live/presentation/pages/live_room_screen.dart`
- Modify: `lib/core/routing/route_paths.dart`, `lib/core/routing/app_router.dart` (branch Home)
- Modify: `lib/l10n/app_pt.arb`, `app_en.arb`
- Test: `test/widget/features/live/live_room_screen_test.dart`

**Interfaces:**
- Consumes: `liveSessionProvider`, `myLiveRoomProvider`, `saveLiveCopyProvider`, `playlistsProvider.reload`, `playlistSyncProvider.sync`, `liveRoomShareUrl`, `qr_flutter`, `share_plus`.
- Produces: `RoutePaths.liveRoom = '/ao-vivo/:code'`, `RoutePaths.liveRoomFor(code)`; `class LiveRoomScreen extends ConsumerStatefulWidget { code }` — `initState` → `join(code)` (post-frame).

Estados renderizados:

| Estado | Conteúdo |
|---|---|
| `joining` | spinner + «Entrando…» |
| `unavailable` | «Não foi possível conectar à sessão» + «Tentar de novo» (`join(code)`) |
| `notFound` | «Este link não existe ou foi substituído» |
| consumidor + `idle` | «{ownerName} não está ao vivo agora. Fique por aqui — quando começar, você entra sozinho.» |
| consumidor + `live` | «Você está seguindo {ownerName}» + «Ir para a lista» (`context.go(RoutePaths.home)`) |
| consumidor + `ended` / `phase ended` | «Sessão encerrada» + «Guardar cópia» (se `snapshot` não nulo) + «Sair» |
| gestor (`role == leader`) | link + QR + «Copiar link» + «Compartilhar» + «Gerar novo link» (confirma) + «Encerrar» (se `isLeading`) + «{viewers} conectados» |
| `left` | «Você saiu» + «Entrar de novo» |

- [ ] **Step 1: ARBs**

```json
  "liveJoining": "Entrando…",
  "liveUnavailableTitle": "Não foi possível conectar à sessão",
  "liveUnavailableBody": "Esta rede pode bloquear conexões ao vivo. Tente outra rede ou peça o link da lista pública.",
  "liveRetry": "Tentar de novo",
  "liveNotFound": "Este link não existe ou foi substituído por um novo.",
  "liveIdleTitle": "{owner} não está ao vivo agora",
  "@liveIdleTitle": {"placeholders": {"owner": {"type": "String"}}},
  "liveIdleBody": "Fique por aqui — quando começar, você entra sozinho.",
  "liveFollowingTitle": "Você está seguindo {owner}",
  "@liveFollowingTitle": {"placeholders": {"owner": {"type": "String"}}},
  "liveGoToList": "Ir para a lista",
  "liveEndedTitle": "Sessão encerrada",
  "liveSaveCopy": "Guardar cópia",
  "liveCopyName": "{list} (ao vivo com {owner})",
  "@liveCopyName": {"placeholders": {"list": {"type": "String"}, "owner": {"type": "String"}}},
  "liveCopySaved": "Cópia guardada em Listas",
  "liveLeftTitle": "Você saiu da sessão",
  "liveJoinAgain": "Entrar de novo",
  "liveYourRoom": "Sua sala ao vivo",
  "liveShareHint": "Quem abrir este link vê a sua lista em tempo real.",
  "liveCopyLink": "Copiar link",
  "liveLinkCopied": "Link copiado",
  "liveShareLink": "Compartilhar",
  "liveRegenerateLink": "Gerar novo link",
  "liveRegenerateConfirmTitle": "Gerar um novo link?",
  "liveRegenerateConfirmBody": "O link atual deixa de funcionar para todos.",
  "liveViewers": "{count, plural, =0{Ninguém conectado} =1{1 pessoa conectada} other{{count} pessoas conectadas}}",
  "@liveViewers": {"placeholders": {"count": {"type": "int"}}},
  "liveRoomError": "Não foi possível carregar a sua sala",
```

(en equivalentes: «Joining…», «Couldn't connect to the session», «This network may block live connections. Try another network or ask for the public list link.», «Try again», «This link doesn't exist or was replaced by a new one.», «{owner} isn't live right now», «Stay here — when it starts, you'll join automatically.», «You're following {owner}», «Go to the list», «Session ended», «Save a copy», «{list} (live with {owner})», «Copy saved to Lists», «You left the session», «Join again», «Your live room», «Anyone who opens this link sees your list in real time.», «Copy link», «Link copied», «Share», «Generate new link», «Generate a new link?», «The current link stops working for everyone.», plural «Nobody connected / 1 person connected / {count} people connected», «Couldn't load your room».)

- [ ] **Step 2: Rota**

`route_paths.dart`:

```dart
  /// Sala ao vivo ([LiveRoomScreen]) — filha da branch Home; o Worker manda
  /// `plpcg.com/ao-vivo/<code>` para `/?live=<code>` e o [DeepLinkListener]
  /// abre esta rota.
  static const String liveRoom = '/ao-vivo/:code';

  static String liveRoomFor(String code) => '/ao-vivo/$code';
```

`app_router.dart`, nas `routes` filhas de `RoutePaths.home`, depois de `gestos`:

```dart
            GoRoute(
              path: 'ao-vivo/:code',
              builder: (context, state) =>
                  LiveRoomScreen(code: state.pathParameters['code'] ?? ''),
            ),
```

(`liveRoomRouteFor` da Task 8 e `RoutePaths.liveRoomFor` produzem a mesma string; manter só `RoutePaths.liveRoomFor` e fazer `liveRoomRouteFor` delegar nele.)

- [ ] **Step 3: Teste da tela**

```dart
// test/widget/features/live/live_room_screen_test.dart
import 'package:coldigui/features/live/domain/entities/live_snapshot.dart';
import 'package:coldigui/features/live/presentation/pages/live_room_screen.dart';
import 'package:coldigui/features/live/presentation/providers/live_session_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/pump_app.dart';
import '../../../support/test_overrides.dart';

class _StubController extends LiveSessionController {
  _StubController(this._initial);
  final LiveSessionState _initial;
  final List<String> calls = [];
  @override
  LiveSessionState build() => _initial;
  @override
  Future<void> join(String code) async { calls.add('join:$code'); }
  @override
  Future<void> leave() async { calls.add('leave'); }
}

void main() {
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<_StubController> pump(WidgetTester tester, LiveSessionState state) async {
    final stub = _StubController(state);
    await pumpApp(tester, const LiveRoomScreen(code: 'k7x2m9q'), overrides: [
      ...standardTestOverrides(prefs: prefs),
      liveSessionProvider.overrideWith(() => stub),
    ]);
    await tester.pump();
    return stub;
  }

  testWidgets('monta e entra na sala do código', (tester) async {
    final stub = await pump(tester, const LiveSessionState(phase: LivePhase.joining, code: 'k7x2m9q'));
    expect(stub.calls, ['join:k7x2m9q']);
    expect(find.text('Entrando…'), findsOneWidget);
  });

  testWidgets('idle mostra que o gestor não está ao vivo', (tester) async {
    await pump(tester, const LiveSessionState(phase: LivePhase.connected, code: 'k7x2m9q', role: LiveRole.consumer, roomStatus: LiveRoomStatus.idle, ownerName: 'Fulano'));
    expect(find.text('Fulano não está ao vivo agora'), findsOneWidget);
  });

  testWidgets('unavailable oferece tentar de novo', (tester) async {
    final stub = await pump(tester, const LiveSessionState(phase: LivePhase.unavailable, code: 'k7x2m9q'));
    await tester.tap(find.text('Tentar de novo'));
    expect(stub.calls.last, 'join:k7x2m9q');
  });

  testWidgets('ended com snapshot mostra Guardar cópia', (tester) async {
    await pump(tester, LiveSessionState(phase: LivePhase.ended, code: 'k7x2m9q', role: LiveRole.consumer, ownerName: 'Fulano',
        snapshot: LiveSnapshot(playlistId: 'p', name: 'Culto', entries: const [PlaylistEntry(id: 'a', kind: MaterialKind.pdf)], focusKey: null)));
    expect(find.text('Sessão encerrada'), findsOneWidget);
    expect(find.text('Guardar cópia'), findsOneWidget);
  });

  testWidgets('gestor vê o link, o QR e Gerar novo link', (tester) async {
    await pump(tester, const LiveSessionState(phase: LivePhase.connected, code: 'k7x2m9q', role: LiveRole.leader, roomStatus: LiveRoomStatus.live, viewers: 2));
    expect(find.textContaining('/ao-vivo/k7x2m9q'), findsOneWidget);
    expect(find.text('Gerar novo link'), findsOneWidget);
    expect(find.text('2 pessoas conectadas'), findsOneWidget);
  });
}
```

- [ ] **Step 4: Tela**

```dart
// lib/features/live/presentation/pages/live_room_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../core/utils/share_position_origin.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../playlists/presentation/providers/playlist_sync_provider.dart';
import '../../../playlists/presentation/providers/playlists_provider.dart';
import '../../data/providers/live_providers.dart';
import '../../domain/live_room_link.dart';
import '../providers/live_session_controller.dart';
import '../providers/my_live_room_provider.dart';

/// `/ao-vivo/:code` — onde o link cai (spec §6.3). Para o consumidor é a
/// página de estado da sala; para o dono, a sala com link, QR e controlos.
class LiveRoomScreen extends ConsumerStatefulWidget {
  const LiveRoomScreen({required this.code, super.key});
  final String code;

  @override
  ConsumerState<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends ConsumerState<LiveRoomScreen> {
  var _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(liveSessionProvider.notifier).join(widget.code));
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(liveSessionProvider);
    final l10n = AppLocalizations.of(context)!;
    final body = state.role == LiveRole.leader && state.code == widget.code
        ? _leader(context, state, l10n)
        : _consumer(context, state, l10n);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.liveRoom)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(padding: const EdgeInsets.all(24), child: body),
          ),
        ),
      ),
    );
  }

  Widget _consumer(BuildContext context, LiveSessionState state, AppLocalizations l10n) {
    final controller = ref.read(liveSessionProvider.notifier);
    switch (state.phase) {
      case LivePhase.idle:
      case LivePhase.joining:
      case LivePhase.reconnecting:
        return _Message(icon: null, title: l10n.liveJoining, spinner: true);
      case LivePhase.unavailable:
        return _Message(icon: Icons.wifi_off, title: l10n.liveUnavailableTitle, body: l10n.liveUnavailableBody,
            actions: [FilledButton(onPressed: () => unawaited(controller.join(widget.code)), child: Text(l10n.liveRetry))]);
      case LivePhase.notFound:
        return _Message(icon: Icons.link_off, title: l10n.liveNotFound);
      case LivePhase.left:
        return _Message(icon: Icons.logout, title: l10n.liveLeftTitle,
            actions: [FilledButton(onPressed: () => unawaited(controller.join(widget.code)), child: Text(l10n.liveJoinAgain))]);
      case LivePhase.ended:
        return _ended(context, state, l10n);
      case LivePhase.connected:
        break;
    }
    switch (state.roomStatus) {
      case LiveRoomStatus.live:
        return _Message(icon: Icons.sensors, title: l10n.liveFollowingTitle(state.ownerName),
            actions: [FilledButton(onPressed: () => context.go(RoutePaths.home), child: Text(l10n.liveGoToList))]);
      case LiveRoomStatus.ended:
        return _ended(context, state, l10n);
      case LiveRoomStatus.idle:
      case LiveRoomStatus.scheduled:
      case LiveRoomStatus.retired:
      case null:
        return _Message(icon: Icons.hourglass_top, title: l10n.liveIdleTitle(state.ownerName), body: l10n.liveIdleBody);
    }
  }

  Widget _ended(BuildContext context, LiveSessionState state, AppLocalizations l10n) {
    final snapshot = state.snapshot;
    return _Message(
      icon: Icons.stop_circle_outlined,
      title: l10n.liveEndedTitle,
      actions: [
        if (snapshot != null && snapshot.entries.isNotEmpty)
          FilledButton(onPressed: _busy ? null : () => unawaited(_saveCopy(state, l10n)), child: Text(l10n.liveSaveCopy)),
        TextButton(onPressed: () { unawaited(ref.read(liveSessionProvider.notifier).leave()); context.go(RoutePaths.home); }, child: Text(l10n.liveLeave)),
      ],
    );
  }

  Future<void> _saveCopy(LiveSessionState state, AppLocalizations l10n) async {
    final snapshot = state.snapshot;
    if (snapshot == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(saveLiveCopyProvider)(
        snapshot: snapshot,
        copyName: l10n.liveCopyName(snapshot.name, state.ownerName),
      );
      await ref.read(playlistsProvider.notifier).reload();
      unawaited(ref.read(playlistSyncProvider.notifier).sync());
      if (mounted) showAppSnackbar(context, l10n.liveCopySaved);
    } on Object catch (e) {
      if (mounted) showAppSnackbar(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _leader(BuildContext context, LiveSessionState state, AppLocalizations l10n) {
    final url = liveRoomShareUrl(widget.code);
    final controller = ref.read(liveSessionProvider.notifier);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.liveYourRoom, style: AppTypography.headline, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(l10n.liveShareHint, style: AppTypography.body, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Center(child: QrImageView(data: url, size: 200, backgroundColor: Colors.white)),
          const SizedBox(height: 12),
          SelectableText(url, textAlign: TextAlign.center, style: AppTypography.body),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.copy),
                label: Text(l10n.liveCopyLink),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: url));
                  if (context.mounted) showAppSnackbar(context, l10n.liveLinkCopied);
                },
              ),
              OutlinedButton.icon(
                icon: Icon(Icons.adaptive.share),
                label: Text(l10n.liveShareLink),
                onPressed: () => SharePlus.instance.share(ShareParams(text: url, sharePositionOrigin: sharePositionOriginFromContextOrFallback(context))),
              ),
              TextButton(onPressed: _busy ? null : () => unawaited(_regenerate(context, l10n)), child: Text(l10n.liveRegenerateLink)),
            ],
          ),
          const SizedBox(height: 24),
          Text(l10n.liveViewers(state.viewers), textAlign: TextAlign.center, style: AppTypography.body.copyWith(color: AppColors.gold)),
          const SizedBox(height: 16),
          if (state.isLeading)
            FilledButton.icon(icon: const Icon(Icons.stop), label: Text(l10n.liveEnd), onPressed: () async {
              await controller.endLive();
              if (context.mounted) context.go(RoutePaths.playlists);
            }),
        ],
      ),
    );
  }

  Future<void> _regenerate(BuildContext context, AppLocalizations l10n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.liveRegenerateConfirmTitle),
        content: Text(l10n.liveRegenerateConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(MaterialLocalizations.of(context).cancelButtonLabel)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.liveRegenerateLink)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final wasLive = ref.read(liveSessionProvider).isLeading;
      final playlistId = ref.read(liveSessionProvider).snapshot?.playlistId;
      final info = await ref.read(myLiveRoomProvider.notifier).regenerate();
      // A sala antiga foi aposentada pelo Worker: o socket cai com 4003.
      // Reabrir na nova e, se estava ao vivo, recomeçar a transmissão.
      if (wasLive && playlistId != null) {
        await ref.read(liveSessionProvider.notifier).startLive(code: info.code, playlistId: playlistId);
      }
      if (mounted) context.go(RoutePaths.liveRoomFor(info.code));
    } on Object {
      if (mounted) showAppSnackbar(context, l10n.liveRoomError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, this.body, this.actions = const [], this.spinner = false});
  final IconData? icon;
  final String title;
  final String? body;
  final List<Widget> actions;
  final bool spinner;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (spinner) const CircularProgressIndicator() else if (icon != null) Icon(icon, size: 48, color: AppColors.gold),
        const SizedBox(height: 16),
        Text(title, style: AppTypography.headline, textAlign: TextAlign.center),
        if (body != null) ...[const SizedBox(height: 8), Text(body!, style: AppTypography.body, textAlign: TextAlign.center)],
        if (actions.isNotEmpty) ...[const SizedBox(height: 24), Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: actions)],
      ],
    );
  }
}
```

Conferir a assinatura real de `SharePlus.instance.share(ShareParams(...))` em `share_plus ^13` (é a usada em `playlist_share_actions_provider.dart` — copiar de lá) e `sharePositionOriginFromContextOrFallback` de `core/utils/share_position_origin.dart`.

- [ ] **Step 5: Verde e commit**

Run: `flutter gen-l10n && flutter test test/widget/features/live/ test/unit/core/routing && dart format <tocados>`

```bash
git add lib/features/live/presentation/pages/live_room_screen.dart lib/features/live/domain/live_room_link.dart lib/core/routing lib/l10n test/widget/features/live/live_room_screen_test.dart
git commit -m "feat(live): tela da sala /ao-vivo/:code para consumidor e gestor"
```

---

### Task 18: Pontos de entrada — «Iniciar ao vivo» no menu da lista, «Minha sala» no Perfil, deep link

**Files:**
- Modify: `lib/features/playlists/presentation/widgets/playlist_tile_actions.dart:73-103,414-510`
- Modify: `lib/features/app_shell/presentation/pages/profile_screen.dart` (tile novo junto de Biblioteca/Offline/Sobre)
- Modify: `lib/features/app_shell/presentation/widgets/deep_link_listener.dart:83-90`
- Modify: `lib/features/app_shell/presentation/utils/deep_link_initial_uri.dart:16-25`
- Modify: `lib/l10n/*.arb`
- Test: `test/unit/features/app_shell/deep_link_initial_uri_live_test.dart`, `test/widget/features/app_shell/deep_link_listener_live_test.dart` (seguir o padrão dos testes existentes de `DeepLinkListener` — `handleUriForTest`).

**Interfaces:**
- Consumes: `myLiveRoomProvider.ensure()`, `activePlaylistEditorProvider.activate`, `liveSessionProvider.startLive`, `parseLiveRoomCode`, `RoutePaths.liveRoomFor`.
- ARB: `playlistGoLive` «Iniciar ao vivo» / «Go live», `liveLoginRequired` «Entre com o Google para transmitir ao vivo» / «Sign in with Google to go live», `profileLiveRoom` «Minha sala ao vivo» / «My live room`.

- [ ] **Step 1: Testes do deep link**

```dart
// test/unit/features/app_shell/deep_link_initial_uri_live_test.dart
import 'package:coldigui/features/app_shell/presentation/utils/deep_link_initial_uri.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('URL inicial com ?live= é preferida ao app_links', () {
    final base = Uri.parse('https://v2.plpcg.com/?live=k7x2m9q');
    expect(resolveWebInitialDeepLinkUri(null, browserUri: base), base);
    expect(resolveWebInitialDeepLinkUri(Uri.parse('plpcg:///x'), browserUri: base), base);
  });

  test('sem live nem share cai para o app_links', () {
    final fallback = Uri.parse('plpcg:///x');
    expect(resolveWebInitialDeepLinkUri(fallback, browserUri: Uri.parse('https://v2.plpcg.com/')), fallback);
  });
}
```

```dart
// test/widget/features/app_shell/deep_link_listener_live_test.dart
// Montar DeepLinkListener como nos testes existentes de deep link (ver
// test/widget/features/app_shell/deep_link_listener_test.dart), com
// `appRouterProvider` sobrescrito por um GoRouter de teste que registra
// `go(location)` — o padrão já usado lá para asserir a navegação pós-import.
// Casos:
//  - handleUriForTest(Uri.parse('https://plpcg.com/?live=k7x2m9q')) → router.go('/ao-vivo/k7x2m9q'); nenhuma importação de playlist.
//  - handleUriForTest(Uri.parse('https://plpcg.com/ao-vivo/k7x2m9q')) → idem.
//  - handleUriForTest(Uri.parse('https://plpcg.com/?s=abc&n=x')) → continua no fluxo de import (não navega para /ao-vivo).
```

- [ ] **Step 2: Deep link**

`deep_link_initial_uri.dart`: import `../../../live/domain/live_room_link.dart`; trocar `if (parsePlaylistShareParams(base) == null) return fromAppLinks;` por
`if (parsePlaylistShareParams(base) == null && parseLiveRoomCode(base) == null) return fromAppLinks;`.

`deep_link_listener.dart`, no início de `_handleUri` depois do guard de `_handling`:

```dart
    // Sala ao vivo: sem import, só navegar (spec lista-ao-vivo D6).
    final liveCode = parseLiveRoomCode(uri);
    if (liveCode != null) {
      final fingerprint = 'live:$liveCode';
      if (_isRecentlyProcessed(fingerprint)) return;
      _markProcessed(fingerprint);
      ref.read(appRouterProvider).go(RoutePaths.liveRoomFor(liveCode));
      return;
    }
```

(imports: `../../../live/domain/live_room_link.dart`, `../../../../core/routing/route_paths.dart`.)

- [ ] **Step 3: Menu da lista**

Em `playlist_tile_actions.dart`:

```dart
      if (playlist.salva)
        PopupMenuItem(value: 'goLive', child: Text(l10n.playlistGoLive)),
```

(antes de `share`), e no `switch`:

```dart
      case 'goLive':
        await _goLive();
```

```dart
  /// «Iniciar ao vivo»: exige login; garante a sala no Worker, torna a lista
  /// ativa, começa a transmitir e abre a sala (link + QR).
  Future<void> _goLive() async {
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) {
      _showError(l10n.liveLoginRequired);
      return;
    }
    onLoadingChanged(true);
    try {
      final room = await ref.read(myLiveRoomProvider.notifier).ensure();
      await ref.read(activePlaylistEditorProvider.notifier).activate(playlist.playlistId);
      await ref.read(liveSessionProvider.notifier).startLive(code: room.code, playlistId: playlist.playlistId);
      if (context.mounted) context.go(RoutePaths.liveRoomFor(room.code));
    } on Object catch (e) {
      _showError(userMessageFor(e, l10n));
    } finally {
      onLoadingChanged(false);
    }
  }
```

(imports: `../../../live/presentation/providers/live_session_controller.dart`, `../../../live/presentation/providers/my_live_room_provider.dart`, `../../../../core/routing/route_paths.dart`; conferir a assinatura de `userMessageFor` em `core/errors/user_message_for.dart` e usar como as outras ações do arquivo.)

- [ ] **Step 4: Perfil**

Em `profile_screen.dart`, junto dos tiles existentes (mesmo widget `_ProfileTile`/padrão do arquivo), **só quando logado**:

```dart
            if (user != null)
              _ProfileTile(
                icon: Icons.sensors,
                title: l10n.profileLiveRoom,
                onTap: () async {
                  try {
                    final room = await ref.read(myLiveRoomProvider.notifier).ensure();
                    if (context.mounted) context.go(RoutePaths.liveRoomFor(room.code));
                  } on Object {
                    if (context.mounted) showAppSnackbar(context, l10n.liveRoomError);
                  }
                },
              ),
```

Adaptar ao nome real do widget de tile do arquivo (linha ~254: construtor com `onTap`).

- [ ] **Step 5: Verde e commit**

Run: `flutter gen-l10n && flutter test test/unit/features/app_shell test/widget/features/app_shell test/unit/features/playlists && dart format <tocados>`

```bash
git add lib/features/playlists/presentation/widgets/playlist_tile_actions.dart lib/features/app_shell lib/l10n test/unit/features/app_shell/deep_link_initial_uri_live_test.dart test/widget/features/app_shell/deep_link_listener_live_test.dart
git commit -m "feat(live): «Iniciar ao vivo» no menu da lista, «Minha sala» no Perfil e deep link /ao-vivo"
```

---

### Task 19: Trava de edição na UI enquanto segue

**Files:**
- Modify: `lib/features/carousel/presentation/widgets/carousel_bar_trailing_actions.dart:52-83`
- Modify: `lib/features/carousel/presentation/widgets/active_playlist_name_chip.dart:52-60`
- Test: `test/widget/features/carousel/carousel_bar_trailing_actions_live_test.dart`

A camada de dados já ignora mutações (Task 9); aqui é só não oferecer o que não funciona (spec §6.2).

- [ ] **Step 1: Teste**

```dart
// test/widget/features/carousel/carousel_bar_trailing_actions_live_test.dart
import 'package:coldigui/features/carousel/presentation/widgets/carousel_bar_trailing_actions.dart';
import 'package:coldigui/features/live/presentation/providers/live_projection_provider.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/pump_app.dart';
import '../../../support/test_overrides.dart';

class _Projecting extends LiveProjectionNotifier {
  @override
  LiveProjection? build() => LiveProjection(ownerName: 'Fulano', playlistId: 'p', name: 'Culto',
      entries: const [PlaylistEntry(id: 'a', kind: MaterialKind.pdf)]);
}

void main() {
  testWidgets('seguindo: sem lixeira, o share continua', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await pumpApp(tester, const CarouselBarTrailingActions(), overrides: [
      ...standardTestOverrides(prefs: prefs),
      liveProjectionProvider.overrideWith(_Projecting.new),
    ]);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.byIcon(Icons.adaptive.share), findsOneWidget);
  });
}
```

- [ ] **Step 2: Implementar**

`carousel_bar_trailing_actions.dart`: `final following = ref.watch(liveProjectionProvider) != null;` no `build`; a `CarouselBarActionButton` da lixeira só entra `if (!following)`. No `_openShareSheet`, quando `following`, o `PlaylistShareContext` usa `playlistId: live.playlistId`, `nome: live.name` e as `entries` de `activeEntriesProvider` (já são a projeção) — partilhar a lista do gestor é útil e inofensivo.

`active_playlist_name_chip.dart`: `final live = ref.watch(liveProjectionProvider); if (live != null) return _LiveNameChip(name: live.name);` antes de ler `activePlaylistProvider` — mesma `Material`/cores da chip normal, ícone `Icons.sensors` em vez do lápis, sem `onTap`.

- [ ] **Step 3: Verde e commit**

Run: `flutter test test/widget/features/carousel && dart format <tocados>`

```bash
git add lib/features/carousel/presentation/widgets/carousel_bar_trailing_actions.dart lib/features/carousel/presentation/widgets/active_playlist_name_chip.dart test/widget/features/carousel/carousel_bar_trailing_actions_live_test.dart
git commit -m "feat(live): barra em modo «seguindo» — sem limpar, chip com o nome da lista do gestor"
```

---

### Task 20: Documentação, suíte completa e homologação em campo

**Files:**
- Modify: `docs/features/FEATURE_INDEX.md` — linha `live` na tabela de status.
- Modify: `docs/superpowers/specs/2026-09-12-lista-ao-vivo-design.md` — cabeçalho «Estado» e a tabela «Divergências» deste plano (copiar).
- Modify: `docs/USER_AUTH_PLAYLIST_SYNC_SPEC.md` — nota de que o token de sessão também autentica o `hello` do WebSocket.

- [ ] **Step 1: Suíte inteira**

Run: `flutter analyze && flutter test` e, no Worker, `npm run typecheck && npm test`.
Expected: verde. Corrigir `switch` exaustivos que a fase nova de `LivePhase`/`AddToActiveOutcome.following` tenha quebrado.

- [ ] **Step 2: FEATURE_INDEX**

```markdown
| `live` | Lista ao Vivo (Fase 1) | Média | **Em progresso (set/2026)** | DO `LiveRoom` + WS (`/api/live/:code/ws`); [LiveSessionController] (`keepAlive`, reconexão com backoff, prova de vida); consumidor vê a lista do gestor como projeção ([liveProjectionProvider] → [activeEntriesProvider]); foco só sinaliza (D3); [LiveSessionBanner]; `/ao-vivo/:code` ([LiveRoomScreen]); «Guardar cópia» ([SaveLiveCopy]); spec [lista ao vivo](../superpowers/specs/2026-09-12-lista-ao-vivo-design.md) |
```

- [ ] **Step 3: Deploy do app e homologação (spec §9)**

Deploy web (Pages) depois do Worker (Task 6). Em `v2.plpcg.com` (aba visível, memória `test-on-production-v2`):

1. Gestor (browser desktop, logado): Listas → menu de uma lista salva → «Iniciar ao vivo» → tela da sala com QR; banner «AO VIVO · 0».
2. Consumidor A (telemóvel, Safari, sem login): abre o link → `/?live=…` → sala «Você está seguindo» → «Ir para a lista» → barra mostra a lista do gestor; chip com nome + ícone; sem lixeira.
3. Gestor abre o #047 → A vai para o leitor do #047. A navega para outro → banner ganha «Voltar ao gestor»; gestor troca de louvor → A **não** muda; «Voltar ao gestor» → A vai para o louvor do gestor.
4. Gestor reordena / adiciona → A vê em ≤ 1 s. Contagem no banner do gestor sobe/desce ao entrar/sair.
5. A: modo avião 1 min → banner «Reconectando…»; volta a rede → «Seguindo» sem ação do utilizador; foco corrente aplicado.
6. A: app para segundo plano 2 min → volta → reconecta (iOS mata o socket).
7. Gestor abre a mesma sala num segundo dispositivo → o primeiro vê «Sessão assumida em outro dispositivo».
8. Gestor fecha a aba sem encerrar → A vê «gestor ausente»; reabre a app → banner «Você estava ao vivo…» → «Retomar» → volta tudo; esperar 15 min sem gestor → A vê «Sessão encerrada» + «Guardar cópia» → cria lista salva em Listas.
9. `npm run deploy` do Worker a meio de uma sessão → todos os clientes religam sozinhos (0–3 s).
10. «Gerar novo link» → link antigo mostra «Este link não existe ou foi substituído».
11. Tablet no Wi-Fi da igreja (rede que possa bloquear WS): se falhar 3×, tela `unavailable` com «Tentar de novo».

Registrar o resultado (o que passou, o que não) no fim da spec, seção «Homologação Fase 1».

- [ ] **Step 4: Commit**

```bash
git add docs/features/FEATURE_INDEX.md docs/superpowers/specs/2026-09-12-lista-ao-vivo-design.md docs/USER_AUTH_PLAYLIST_SYNC_SPEC.md
git commit -m "docs(live): Fase 1 no FEATURE_INDEX, divergências e homologação na spec"
```

---

## Auto-revisão (feita ao escrever)

**Cobertura da spec (Fase 1, §10):** DO `LiveRoom` (WS, snapshot, papéis, alarm) → Tasks 3–4; rotas + D1 `live_rooms` → 1, 5; `LiveSessionController` + transporte + máquina de estados + dispose → 7, 10–11; lista ativa como projeção → 9, 19; foco D3 → 13; UI gestor/consumidor → 16–18; presença → 3 (`presence`), 16; apelido → **deliberadamente fora** (ver Divergências); l10n → 9, 16–18; «Guardar cópia» (D4) → 15, 17; cenários da §7 → 3 (DO), 10–13 (cliente), 20 (campo). `unavailable` com link para a lista pública do gestor (D5): a tela mostra a mensagem, sem o link — o consumidor anónimo não tem como resolver `username` do gestor sem uma rota pública nova; fica para a Fase 3 com o perfil público.

**Consistência de nomes:** `liveSessionProvider`/`LiveSessionController` (10–19); `liveProjectionProvider`/`LiveProjection(ownerName, playlistId, name, entries)` (9, 10, 19); `LivePhase.{idle, joining, connected, reconnecting, ended, left, unavailable, notFound}` (10–17); `LiveRoomStatus` (7, 10, 16–17); `startLive({code, playlistId})` (12, 17, 18); `RoomCore.{init, retire, onOpen, onMessage, onClose, onAlarm}` (3, 4); `LiveRoomNamespace` (5); `parseLiveRoomCode`/`liveRoomShareUrl`/`RoutePaths.liveRoomFor` (8, 16–18); `kLiveLeaderSessionPrefsKey`/`pendingLeaderSessionProvider` (12, 16).

**Placeholders:** nenhum «TBD». A Task 18 descreve o teste widget do `DeepLinkListener` por referência ao teste existente (`handleUriForTest` + router de teste) porque o helper de router vive naquele arquivo — o executor copia o setup de lá.

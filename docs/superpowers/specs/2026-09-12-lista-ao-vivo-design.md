# Lista ao Vivo — desenho da arquitetura

**Data:** 2026-09-12
**Estado:** desenho aprovado; plano de implementação da Fase 1 escrito em 2026-09-14 (`docs/superpowers/plans/2026-09-14-lista-ao-vivo-fase1.md`) e implementado na branch `feat/lista-ao-vivo` (deploy e homologação em campo pendentes — ver §13)
**Mockups e comparação das 5 opções:** `https://claude.ai/code/artifact/dd1a7ed0-46b1-4f3e-bd5e-30a73b376549` (v2)
**Escopo:** sincronização em tempo real da lista ativa entre um gestor e N consumidores; sugestões com votação; sala permanente com agendamento; pré-download; folheto ao encerrar.

## 1. Problema

Listas públicas hoje são estáticas: outro usuário importa uma cópia. No culto/ESF, a equipe quer estar **no mesmo louvor ao mesmo tempo**: quem gere a lista abre o #047 e todos os que seguem vão para o #047, com a lista (ordem, entradas) refletida na hora.

## 2. Decisões fechadas

| # | Decisão |
|---|---|
| D1 | **Sincroniza conteúdo + louvor em foco.** Entradas e ordem da lista, e qual entrada o gestor abriu. Página do PDF, scroll e posição do áudio ficam locais. |
| D2 | **Qualquer um com o link entra, sem login.** Gestor precisa estar logado (Google). Consumidor é anónimo, identificado por `clientId` aleatório do dispositivo + apelido opcional. |
| D3 | **Segue, mas pode desviar; o foco só sinaliza.** Se o consumidor navegou por conta própria, um novo foco do gestor **não** troca a tela — mostra «Voltar ao gestor» na barra. Enquanto não desviou, o foco troca a tela. |
| D4 | **É um modo de uma lista salva.** «Iniciar ao vivo» numa lista do gestor. Ao encerrar, a lista continua normal. O consumidor recebe uma projeção read-only e pode «Guardar cópia» ao sair (mesmo caminho de `DuplicatePlaylist`, `syncStatus: pendingPush`). |
| D5 | **Transporte: só WebSocket** (Durable Object + Hibernation API). **Sem fallback HTTP/polling** — o polling de todos os consumidores é o que custa. Quem não conseguir o handshake após 3 tentativas vê `unavailable` com link para a lista pública do gestor. |
| D6 | **Uma sala por pessoa** (`LiveRoom`), não um objeto por sessão. Link permanente `plpcg.com/ao-vivo/<code>` (7 chars `[a-z0-9]`, regenerável pelo dono). **Sem alias `@username`** — a página da sala mostra o **nome do perfil** do gestor. |
| D7 | **Sugestões** do consumidor (adicionar, mover), visíveis a **todos** (sem apelido de quem sugeriu), com **votação por duas setas: ↑ e →**. Sem seta para baixo (ofensiva). Gestor vê contagens e ordena por ↑. O gestor decide sempre; o DO nunca altera a lista sozinho. |
| D8 | **Agendamento** na sala: estados `idle → scheduled → live → ended`. Em `scheduled`, a **prévia é a lista inteira** (permite pré-download). |
| D9 | **Pré-download**: «Baixar os materiais de <data>» a partir da prévia agendada, reusando UC-10 (`DownloadMissingPdfs`). |
| D10 | **Folheto ao encerrar**: em `ended`, «Gerar folheto desta reunião» a partir do último snapshot (UC-08 `LeafletContent`). |
| D11 | **Snapshot inteiro por mensagem.** Sem diffs, sem CRDT. Teto de 200 entradas. `version` é sempre atribuída pelo DO. |
| D12 | **Descartado:** SSE, serviço externo (Firebase/Supabase/Ably), modo espelho (página/áudio), consumidor editando a lista ao vivo. |

### 2.1 Semântica das setas de voto (confirmar rótulos ao planejar)

- **↑** = «Quero este» — apoio.
- **→** = «Pode ficar para depois» — o voto neutro que substitui o «não». Conta separado; não subtrai.
- Um voto por `clientId` por sugestão por seta (trocar de seta substitui). Exibição: `↑ 6 · → 2`.

## 3. Por que Durable Objects + WebSocket (resumo da pesquisa)

- Um DO é um objeto único com N WebSockets; `getWebSockets(tag)` faz broadcast. É o modelo «sala».
- **Hibernation API** (`acceptWebSocket`): o objeto é despejado da memória sem eventos; sockets ficam na borda da Cloudflare; **sem duração cobrada enquanto hiberna**. Ping/pong via `setWebSocketAutoResponse` não acorda o objeto.
- `alarm()` é a única coisa que acorda sozinha — serve para TTL («gestor sumiu») e expiração do agendamento.
- Memória perde-se ao hibernar: papel/apelido em `serializeAttachment` (≤ 16 KB); snapshot em `ctx.storage.sql`.
- Deploy do Worker fecha todos os sockets → reconexão automática obrigatória no cliente.
- Custo: mensagens recebidas contam 20:1 como pedidos; **enviadas são grátis**. Culto típico (25 pessoas, 2 h, 30/mês) ≈ **1 924 pedidos e 10 GB-s por mês** — 64 pedidos/dia num Free de 100 000/dia. Stress (100 sessões/dia × 200 pessoas) ≈ 31 k/dia. Free plan tem DO com SQLite; 100 k pedidos/dia; 13 k GB-s/dia; 100 k linhas escritas/dia.
- Fontes (set/2026): developers.cloudflare.com/durable-objects — `best-practices/websockets`, `platform/pricing`, `platform/limits`.

## 4. Arquitetura

```
Flutter (web · iOS · Android)                Worker plpcg-catalog               D1
┌───────────────────────────────┐   wss    ┌───────────────────────────┐   ┌──────────────────┐
│ LiveSessionController         │─────────▶│ /api/live/:code/ws        │   │ live_rooms       │
│  (Riverpod, escopo do shell,  │          │ /ao-vivo/:code (deep link)│──▶│ live_sessions    │
│   keepAlive, única instância) │          │  → LIVE.idFromName(code)  │   │ (índice/histórico│
│ LiveTransport (ws)            │          └────────────┬──────────────┘   │  não estado)     │
│ liga-se a: activePlaylist,    │                       ▼                  └──────────────────┘
│  carouselFocus, AppLifecycle, │          ┌───────────────────────────┐
│  conectividade, auth          │◀─────────│ DO LiveRoom               │
└───────────────────────────────┘ snapshot │  status idle/scheduled/   │
                                            │   live/ended              │
                                            │  snapshot · version       │
                                            │  suggestions[] · votes    │
                                            │  sockets por tag:         │
                                            │   leader ×1+ · consumer×N │
                                            │  alarm 5 min → TTL 15 min │
                                            │  hiberna entre mensagens  │
                                            └───────────────────────────┘
```

### 4.1 Worker

- Novo binding `LIVE` (Durable Object class `LiveRoom`, SQLite) em `wrangler.jsonc`; rotas `plpcg.com/api/live/*` e `plpcg.com/ao-vivo/*`.
- `GET /api/live/:code/ws` → upgrade; encaminha ao DO. Roteador fica magro (Free: 10 ms CPU/invocação).
- `GET /ao-vivo/:code` → 302 para a app com o código (mesma lógica de `/l/:code`).
- `POST /api/live/room` (auth) → cria/retorna a sala do `sub`; `POST /api/live/room/regenerate` (auth) → novo código (expulsa quem tem o antigo).

### 4.2 D1

```sql
CREATE TABLE live_rooms (
  code        TEXT PRIMARY KEY,          -- 7 chars, regenerável
  owner_sub   TEXT NOT NULL UNIQUE,
  created_at  TEXT NOT NULL
);
CREATE TABLE live_sessions (
  id            TEXT PRIMARY KEY,
  room_code     TEXT NOT NULL,
  playlist_id   TEXT NOT NULL,
  scheduled_for TEXT,
  started_at    TEXT,
  ended_at      TEXT,
  peak_viewers  INTEGER
);
```

O estado vivo (snapshot, sugestões, votos) fica **só no DO**; D1 é índice e histórico, escrito pelo DO no `start`/`end`.

### 4.3 DO `LiveRoom`

- `idFromName(code)`. Storage SQLite: `room(status, owner_sub, owner_name, playlist_id, scheduled_for, version, snapshot_json, leader_seen_at)`, `suggestions(id, kind, material_id, entry_key, to_index, nick, created_at, up, right)`, `votes(suggestion_id, client_id, arrow)`.
- **Tags:** `leader` (ID token Google válido do `owner_sub`; fase 3: co-gestores), `consumer` (restante). Papel, `clientId` e apelido em `serializeAttachment`.
- **Regras por tag:** `leader` → `set`, `schedule`, `start`, `end`, `resolve`. `consumer` → `hello`, `suggest`, `vote`. Tudo o resto → `error not_leader`.
- **`set`:** valida (≤ 200 entradas, ≤ 32 KB), grava, `version++`, broadcast `snapshot` a todos, `ack` aos leaders com `viewers = getWebSockets('consumer').length`.
- **Segundo leader** do mesmo `sub`: fecha o anterior com `4002 replaced`. Fase 3 permite vários leaders (co-gestores) com `stale_version` para o atrasado.
- **Alarm** a cada 5 min: em `live`, sem socket `leader` e `leader_seen_at` > 15 min → broadcast `ended{inactivity}`, fecha sockets com `4001`, escreve `ended_at` em D1, apaga sugestões/votos, `status = ended`. Em `scheduled`, `scheduled_for + 24 h` sem `start` → `idle`, avisa ligados. Em `ended`, +24 h → `idle`.
- **Rate-limit** no attachment do socket: 1 `suggest` / 10 s, 1 `vote` / 2 s; máximo 30 sugestões pendentes por sala; frames de consumidor > 2 KB ignorados. `add` duplicado do mesmo `materialId` vira voto ↑.
- `setWebSocketAutoResponse(ping → pong)`.

## 5. Protocolo

```jsonc
// cliente → DO
{ "t": "hello", "room": "k7x2m9q", "since": 42, "clientId": "…", "nick": "Maria" }
{ "t": "hello", "room": "k7x2m9q", "since": 42, "idToken": "…" }             // vira leader se for dono
{ "t": "set", "version": 43, "playlistId": "…", "entries": [{ "id": "…", "kind": "pdf" }], "focus": { "entryKey": "…" } }
{ "t": "schedule", "playlistId": "…", "at": "2026-09-20T09:30:00-03:00" }
{ "t": "start" }  { "t": "end" }
{ "t": "suggest", "id": "s-…", "kind": "add" | "move", "materialId"?, "entryKey"?, "toIndex"? }
{ "t": "vote", "suggestionId": "s-…", "arrow": "up" | "right" }
{ "t": "resolve", "suggestionId": "s-…", "action": "accept" | "dismiss" }

// DO → cliente
{ "t": "room", "room": "k7x2m9q", "status": "idle|scheduled|live|ended", "ownerName": "Fulano",
  "scheduledFor"?, "version", "entries", "focus", "leaderPresent", "viewers" }
{ "t": "snapshot", "version": 44, "entries": [], "focus": {}, "viewers": 23 }
{ "t": "suggestions", "items": [{ "id", "kind", "materialId", "entryKey", "toIndex", "up": 6, "right": 2, "createdAt" }] }  // todos; sem nick
{ "t": "suggestionResolved", "id": "s-…", "action": "accept" }             // a quem sugeriu (por clientId)
{ "t": "ack", "version": 44, "viewers": 23 }                                // leaders
{ "t": "ended", "reason": "leader" | "inactivity" | "replaced" | "expired" }
{ "t": "error", "code": "stale_version" | "not_leader" | "rate_limited" | "already_resolved" | "too_large" | "not_found" }
```

Invariantes: todo frame do DO leva `room`; o cliente descarta frames de sala diferente da atual; descarta `version ≤ atual`; `version` nunca é inventada pelo cliente.

## 6. Cliente Flutter

### 6.1 `LiveSessionController`

- Um único provider, `keepAlive`, no escopo do shell (sobrevive a rotas). `ref.onDispose(close)`. Connect **single-flight**. `leave()` idempotente.
- Estados: `idle → joining → live ⇄ reconnecting → ended | left`; mais `unavailable` (3 falhas de handshake) — terminal, sem retry automático.
- Papel derivado: se `auth.sub == room.ownerSub` envia `idToken` no `hello` e fica leader; senão consumer.
- Reconexão: backoff 1 → 2 → 4 … 30 s com jitter; **não religar em `AppLifecycleState.paused`**; religar imediatamente em `resumed` e no evento de conectividade. Ao religar, `hello{since}`.
- Deep link `/ao-vivo/:code` a frio: `join` só depois de `playlist_session_hydrate`.
- Sugestões pendentes do próprio cliente e votos dados ficam no controller e são limpos em `left`/`ended`.

### 6.2 Integração com a lista ativa

- Enquanto segue, a lista ativa é **projeção** do snapshot: `+`, reordenar e «Limpar» desativados com tooltip «A seguir a lista de <nome>»; `+` vira «Sugerir ao gestor».
- Foco (D3): controller guarda `followingFocus: bool`. Foco do gestor chega → se `followingFocus`, navega; senão mostra «Voltar ao gestor» (que navega e volta a `followingFocus = true`). Navegação própria do consumidor → `followingFocus = false`.
- Gestor: cada mudança na lista ativa/foco dispara `set` **no fim do debounce** do reorder (não a cada arrasto). Trocar de lista ativa a meio → «Encerrar ao vivo?»; a sessão é da `playlistId`.
- Entradas que o consumidor não resolve (Coldigom sem acesso, PDF não baixado) → chip «indisponível»; nunca crash.
- Lista salva alterada entre `schedule` e `start` → app faz `set` na sala ao guardar (prévia atualizada).

### 6.3 UI

- **Gestor:** menu da lista salva → «Iniciar ao vivo agora» / «Agendar ao vivo»; indicador na barra da lista ativa «AO VIVO · 23 · 3 sugestões»; sheet «Sugestões» ordenado por ↑ com Aceitar/Dispensar; tela da sala com QR + link + «Gerar novo link»; «Encerrar» confirma.
- **Consumidor:** página da sala (`idle`: «<nome> não está ao vivo» + listas públicas; `scheduled`: hora + prévia + «Baixar materiais»; `live`: entra; `ended`: «Encerrada há N min» + «Guardar cópia» + «Gerar folheto»). Ao entrar: «Como quer aparecer? (opcional)». Banner persistente acima da barra com nome do gestor, «Voltar ao gestor», «Sair». Sugestão: «Sugerir ao gestor» no card e no sheet de materiais; chip «pendente»; toast ao ser aceite. Votos ↑/→ na lista de sugestões.
- l10n pt/en para todos os estados.

## 7. Cenários de ciclo de vida (o que tem de estar coberto por teste)

| Cenário | Comportamento esperado |
|---|---|
| Consumidor fecha aba/app sem sair | SO fecha o socket → `webSocketClose` → sai da contagem. Nada a limpar. |
| Consumidor troca de lista localmente | `leave()` fecha com 1000; guard por `room` descarta frames tardios. |
| Consumidor perde rede 2 min | `reconnecting` → backoff → `hello{since}` → snapshot. |
| App em segundo plano (iOS mata socket ~30 s) | Sem retry em `paused`; religa em `resumed`. |
| Aba web escondida (timers a 1/min) | Prova de vida do gestor é o socket, não timer; TTL 15 min tolera. |
| Gestor fecha app sem encerrar | Consumidores veem «gestor ausente» na hora; alarm encerra em ≤ 15 min; ao reabrir, «Retomar / Encerrar» (código em SharedPreferences). |
| Gestor em dois dispositivos | Segundo leader fecha o primeiro com `4002`. |
| Deploy do Worker | Todos os sockets caem; reconexão com jitter 0–3 s. |
| Hot restart / novo `ProviderContainer` / logout | Controller antigo fecha o socket (`ref.onDispose`); teste garante zero frames processados depois. |
| Consumidor sugere e sai antes da resposta | Sugestão fica na fila; gestor ainda pode aceitar. |
| Gestor aceita duas vezes | `resolve` idempotente → `already_resolved`. |
| Sala `scheduled` com gente à espera 40 min | Hibernado; iOS cai e religa igual ao `live`. |
| Handshake falha em rede que bloqueia WS | 3 falhas → `unavailable` + link para lista pública. Contador local para medir. |

## 8. Segurança e abuso

- `leader` só com ID token válido (`verify_google_token`) do `owner_sub`.
- Código não adivinhável, regenerável; sem alias público.
- Rate-limits e tetos no DO (§4.3). Apelido: trim, ≤ 24 chars.
- Teto por utilizador: 1 sala; sessões ilimitadas dentro dela.

## 9. Testes

- Worker: `vitest-pool-workers` para o DO — tags, `set`/`version`, `suggest`/`vote`/`resolve`, `schedule`/`start`/`end`, alarms, close codes, rate-limit.
- Flutter: `FakeLiveTransport` (emite frames, simula quedas); testes da máquina de estados cobrindo a tabela do §7; teste de dispose (recriar container); foco «só sinaliza» (D3).
- Smoke web: `/ao-vivo/:code` a frio em `idle`, `scheduled`, `live`.
- Homologação em campo: 2 telemóveis + tablet + browser no Wi-Fi da igreja, com um deploy a meio; um culto em «modo sombra» antes de anunciar.

## 10. Fases (estimativa, uma pessoa)

| Fase | Conteúdo | Dias |
|---|---|---|
| 1 · núcleo | DO `LiveRoom` (WS, snapshot, tags, alarm) + rotas + D1 `live_rooms`; `LiveSessionController` + transporte + máquina de estados + testes de dispose; lista ativa como projeção; foco D3; UI gestor/consumidor; presença + apelido; l10n | 15–19 |
| 2 · sala | Sugestões com votos ↑/→; estados `idle/scheduled/live/ended` + prévia; pré-download; folheto ao encerrar | 12–14 |
| 3 · comunidade | Co-gestores (tag `leader` para usernames nomeados); `live_sessions` + «Últimas reuniões» no perfil | ~5 |
| sempre | Homologação em campo | 2–3 por fase |

## 11. Fora do escopo

- Modo espelho (página do PDF, play/pausa). A arquitetura não impede; é decisão de produto.
- Fallback HTTP/polling. Reconsiderar só com dados do contador `unavailable`.
- Alias `@username` no link.
- Moderação de apelidos/sugestões além dos limites do §4.3.
- Notificações push para sessões agendadas.

## 12. Nota para quando o plano de implementação for escrito

Outras sessões estão a alterar o código em paralelo (barra da lista ativa sem faces, navegação Listas · Pesquisar · Perfil, ondas web). **Antes de escrever o plano, reler:**

- `docs/superpowers/specs/2026-09-12-barra-lista-ativa-design.md` e `2026-09-12-nav-listas-perfil-design.md` — estado real dos providers (`carouselItemsProvider`, foco, `activePlaylistIdProvider`, `CarouselBarTrailingActions`) e onde o indicador «AO VIVO» e o banner encaixam.
- `workers/plpcg-catalog/src/index.ts` (roteador), `links/handlers.ts` (geração de código), `auth/verify_google_token`, `playlists/wire.ts` (formato de `items`).
- `lib/features/playlists/domain/usecases/duplicate_playlist.dart` (guardar cópia), `playlist_session_hydrate` (ordem no boot), UC-10 `DownloadMissingPdfs`, UC-08 `LeafletContent`.
- Se o projeto entretanto migrou de Isar/Riverpod ou mudou o modelo de `PlaylistEntry`, o protocolo do §5 (`entries[{id, kind}]`) tem de acompanhar.
- Confirmar os rótulos das setas de voto (§2.1) e o nome exibido do gestor (username vs. nome Google).

## 13. Divergências da Fase 1 (2026-09-14)

Tabela «Divergências da spec» copiada de `docs/superpowers/plans/2026-09-14-lista-ao-vivo-fase1.md` (decididas na releitura de 2026-09-14, antes de escrever o plano):

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

Notas adicionais descobertas durante a execução (Tasks 1–19), que não constavam do plano:

1. `hello` com `sessionToken` (`sess_…`) — spec §5 `idToken` está superado.
2. Frame `presence{leaderPresent, viewers}`.
3. O DO responde ao `hello` com `room{idle}` **antes** de processar o `start` enfileirado — o cliente usa `_startSentGen` para não duplicar o `start`.
4. `_pendingStart`/retomada via pref `live_leader_session`.
5. `LiveConnection.messages` é single-subscription com buffer.
6. `unavailable` só no join inicial — depois de já ter estado ligado, reconexão indefinida com teto 30 s.
7. A Fase 1 não tem apelido.
8. O link para a lista pública no estado `unavailable` (D5) fica para a Fase 3 (perfil público).

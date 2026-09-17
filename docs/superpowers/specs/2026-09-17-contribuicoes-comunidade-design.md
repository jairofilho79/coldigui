# Contribuições da comunidade — bugs, informação errada, conteúdo e sugestões

**Data:** 2026-09-17
**Estado:** aprovado em brainstorm; spec para revisão
**Escopo deste spec (peças A + B):**
- **A. App (coldigui)** — formulário «Ajude a melhorar o PLPCG» só para logados, com entrada pelo Perfil, pelo sheet de materiais e pelo leitor/player; coleta automática de dados do dispositivo em bugs; tela «Minhas contribuições» com o estado de cada envio.
- **B. Backend (coldigom-api + plpcg-catalog)** — endpoint de envio com anexos e links, quarentena no R2, pipeline assíncrono de verificação (checagem estrutural + Google Safe Browsing + VirusTotal, gratuitos), rotas admin de leitura/decisão já prontas para a peça C.

**Fora deste spec (próximos):** **C** tela de fila no Coldigom web; **D** aplicar a decisão (editar metadado, importar do Drive, anexar material) a partir de uma contribuição aceita; thread de resposta ao usuário; Google Picker; rascunho persistido offline; notificações.

**Repos:** `coldigui` (Flutter + Worker `plpcg-catalog`) e `../coldigom` (API Hono em Workers, D1 `coldigom`, R2 `ASSETS`, Queues).

## 1. Motivação e princípios

O acervo tem milhares de louvores e materiais, e o Coldigom vai ser a única fonte. Um mantenedor sozinho não encontra tudo que está errado; a equipe de louvor que usa a app no culto encontra. A feature transforma esse uso em contribuições estruturadas, com o mínimo de atrito para quem envia e o máximo de segurança para quem revisa.

Princípios decididos:

| # | Decisão |
|---|---|
| P1 | **Só logado.** Deslogado vê o convite «Entre com Google para contribuir» (mesmo padrão dos favoritos/download offline). |
| P2 | **Entrar pelo contexto.** «Reportar» num louvor/material pré-preenche o alvo; o usuário só diz o que está errado. |
| P3 | **Anexo direto é o caminho padrão** (até 32 MB por arquivo, 5 por envio). Link do YouTube/Drive é campo opcional sempre visível; **obrigatório só acima de 32 MB** (a app explica em uma frase). Exigir Drive para tudo foi rejeitado: são 7 passos no celular e o ganho de segurança não compensa o funil. |
| P4 | **Nada enviado por usuário é servido a ninguém antes de passar pelo scan e ser aprovado.** O admin é o único leitor, via rota própria, com viewer sandboxed. |
| P5 | **Scan assíncrono, nunca inline.** Quarentena → Queue → veredito. Scanner indisponível adia; nunca libera sem scan. |
| P6 | **Serviços gratuitos:** Google Safe Browsing Lookup v4 (links) e VirusTotal API v3 (arquivos ≤ 32 MB). O scan do próprio Google Drive (arquivos < 100 MB) é uma camada extra que só se aplica ao importar o arquivo do Drive na peça D. |
| P7 | **O Coldigom é dono dos dados** (`contributions` no D1 `coldigom`, arquivos no R2 `ASSETS`). O `plpcg-catalog` só ganha um endpoint de introspecção da sessão `sess_…`. |
| P8 | **Fechar o ciclo:** «Minhas contribuições» mostra estado e nota de decisão. Só leitura; sem chat. |
| P9 | **Bug pede dispositivo.** Coleta automática mostrada antes do envio, com a pergunta obrigatória «O bug aconteceu neste dispositivo?». Sem localização, contatos, identificadores de publicidade ou logs completos. A rota atual da app **é** coletada (é o que mais ajuda a reproduzir). |

## 2. Arquitetura e fluxo

```
Flutter (coldigui)                coldigom-api (Hono/Workers)              plpcg-catalog
──────────────────                ───────────────────────────              ─────────────
Perfil › Ajude a melhorar   ─┐
Sheet do louvor › 🏳         ─┼─► POST /api/contributions ──► requireAppUser ──► GET /api/auth/introspect
Leitor/player ⋮ › Reportar  ─┘        (multipart: payload + file[])  (Bearer sess_…)    {userId, email, name}
                                        │
                                        ├─ valida schema, tipos, magic bytes, hosts, cota
                                        ├─ R2: quarantine/<contribId>/<fileId>.<ext>
                                        ├─ D1: contributions (status=recebida, scan=pendente) + contribution_files
                                        └─ Queue CONTRIB_SCAN.send({contributionId, phase:'submit'})
                                                  │
                                        consumer scanContribution():
                                          0. dedupe por sha256 já «limpa»
                                          1. estrutural (magic bytes, tokens de PDF, cabeçalhos)
                                          2. Safe Browsing (links)
                                          3. VirusTotal (arquivos) — hash primeiro, upload se desconhecido, poll
                                          → tudo limpo: R2 copy → contributions/…, status=pendente
                                          → infectada/suspeita/unsafe: fica em quarentena, status=bloqueada
                                                  │
Perfil › Minhas contribuições ◄── GET /api/contributions/mine      Coldigom web (peça C) ◄── GET/PATCH /api/admin/contributions
```

**Autenticação do usuário da app no coldigom-api.** Middleware `requireAppUser` (`api/src/appUser.ts`): lê o Bearer; se não começa com `sess_` → `401`; consulta cache em memória do isolate (`Map<sha256(token), {user, exp}>`, 5 min); senão `fetch(PLPCG_AUTH_URL + '/api/auth/introspect')` com o mesmo Bearer. `401` do introspect → `401`; erro de rede/5xx → `503 { error: 'auth_unavailable' }`. Grava `c.set('appUser', { userId, email, name })`. Novo `var` `PLPCG_AUTH_URL` no `wrangler.toml`.

**Drive.** O link fica só como texto até a aprovação. Na peça D, o import server-side existente (`driveImport.ts`) puxa o arquivo — `403 cannotDownloadAbusiveFile` do Google vira `bloqueada` sem retry — e o arquivo entra no mesmo pipeline de scan antes de virar material.

## 3. Modelo de dados — D1 `coldigom`, migration `020_contributions.sql`

```sql
CREATE TABLE IF NOT EXISTS contributions (
  id                  TEXT PRIMARY KEY,          -- uuid
  user_id             TEXT NOT NULL,             -- userId do plpcg-catalog
  user_email          TEXT NOT NULL,
  user_name           TEXT,
  kind                TEXT NOT NULL,             -- bug | wrong_info | content | improvement | other
  subkind             TEXT,                      -- §3.1
  target_source       TEXT,                      -- coldigom | plpcg | NULL
  target_praise_id    TEXT,
  target_material_id  TEXT,
  title               TEXT NOT NULL,             -- ≤ 120 chars
  body                TEXT NOT NULL,             -- ≤ 4000 chars
  fields              TEXT,                      -- JSON por subkind (§3.1)
  links               TEXT,                      -- JSON: [{url, host, safe_browsing: 'pending'|'clean'|'unsafe'}]
  device              TEXT,                      -- JSON (só bug): DeviceSnapshot + same_device + other_device_note
  app_route           TEXT,                      -- rota da app quando abriu o Reportar
  app_version         TEXT,
  status              TEXT NOT NULL DEFAULT 'recebida',
                      -- recebida | bloqueada | pendente | em_analise | aceita | recusada | aplicada
  scan_status         TEXT NOT NULL DEFAULT 'pendente',
                      -- pendente | adiado | limpa | suspeita | infectada | sem_arquivo
  scan_report         TEXT,                      -- JSON: resumo por arquivo/link + reason
  decided_at          TEXT,
  decided_by          TEXT,
  decision_note       TEXT,
  created_at          TEXT DEFAULT (datetime('now')),
  updated_at          TEXT DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_contrib_user   ON contributions(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_contrib_status ON contributions(status, created_at);
CREATE INDEX IF NOT EXISTS idx_contrib_praise ON contributions(target_praise_id);

CREATE TABLE IF NOT EXISTS contribution_files (
  id               TEXT PRIMARY KEY,
  contribution_id  TEXT NOT NULL REFERENCES contributions(id),
  original_name    TEXT NOT NULL,                -- normalizado: sem / \ nem controle, ≤ 200
  declared_type    TEXT NOT NULL,                -- pdf | mp3 | jpg | png | txt | chordpro
  detected_type    TEXT,                         -- preenchido pelo scan estrutural
  size             INTEGER NOT NULL,
  sha256           TEXT NOT NULL,
  r2_key           TEXT NOT NULL,                -- quarantine/… → contributions/… após limpa
  scan_status      TEXT NOT NULL DEFAULT 'pendente',
  scan_detail      TEXT,                         -- JSON: {structural:{ok, tokens[]}, virustotal:{sha256|analysisId, malicious, suspicious, total}}
  created_at       TEXT DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_cfiles_contrib ON contribution_files(contribution_id);
CREATE INDEX IF NOT EXISTS idx_cfiles_sha     ON contribution_files(sha256, scan_status);

-- Cota diária por usuário (20 envios / 200 MB) e contador global do VirusTotal (user_id = '_vt').
CREATE TABLE IF NOT EXISTS contribution_quota (
  user_id  TEXT NOT NULL,
  day      TEXT NOT NULL,                        -- 'YYYY-MM-DD' UTC
  count    INTEGER NOT NULL DEFAULT 0,
  bytes    INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, day)
);
```

### 3.1 Taxonomia (`kind` / `subkind` / `fields`)

| kind | subkind | `fields` (validado no servidor) |
|---|---|---|
| `bug` | `screen`, `reader`, `audio`, `search`, `offline`, `login`, `playlist_live`, `other` | — (usa `device`) |
| `wrong_info` | `metadata` | `{ field: 'title'\|'number'\|'author'\|'tonality'\|'rhythm'\|'category'\|'tags', current: string, proposed: string }` |
| `wrong_info` | `lyrics`, `wrong_material`, `wrong_kind` | `{}` (descrição no `body`) |
| `wrong_info` | `duplicate` | `{ otherPraiseId: string, otherSource: 'coldigom'\|'plpcg' }` |
| `content` | `add_material`, `add_praise`, `replace_material`, `remove` | `{ suggestedKindId?: string, suggestedType?: string }` |
| `improvement` | `feature`, `behavior` | `{}` |
| `other` | `null` | `{}` |

Regras de estado:
- `status` só sai de `recebida` pelo consumer do scan (`→ pendente` ou `→ bloqueada`). `em_analise | aceita | recusada | aplicada` só pelo admin (`PATCH`).
- Sem anexo e sem link: `scan_status = sem_arquivo`, `status = pendente` direto, sem passar pela Queue.
- `bloqueada` aparece ao usuário como «Não pôde ser analisada: anexo recusado pela verificação de segurança», sem detalhe técnico.

## 4. API

### 4.1 plpcg-catalog — `GET /api/auth/introspect`

- Bearer `sess_…` **apenas**; JWT Google → `401` (um id_token vazado não abre contribuição).
- `200 { userId, email, name, username? }` via `findSession` + `users`; `401` se inexistente/expirada.
- **Não** faz `touch` da sessão (introspecção não é uso do usuário).
- Sem CORS de browser: é servidor-a-servidor.
- Teste: `introspect.test.ts` (válida, expirada, JWT recusado, sem Bearer).

### 4.2 coldigom-api

| Método | Rota | Auth | O quê |
|---|---|---|---|
| `POST` | `/api/contributions` | `requireAppUser` | `multipart/form-data`: parte `payload` (JSON) + partes `file[]` (≤ 5). `201 { id, status: 'recebida' \| 'pendente' }` |
| `GET` | `/api/contributions/mine?cursor=` | `requireAppUser` | Só do próprio usuário; 20 por página, mais recente primeiro; cursor = `created_at\|id` opaco em base64url |
| `GET` | `/api/contributions/:id` | `requireAppUser` | Detalhe; `404` se de outro usuário |
| `GET` | `/api/admin/contributions?status=&kind=&praise=&cursor=` | `requireAuth` (admin) | Fila para a peça C |
| `GET` | `/api/admin/contributions/:id` | `requireAuth` | Detalhe completo (inclui `device`, `scan_report`, `scan_detail`) |
| `GET` | `/api/admin/contributions/:id/files/:fileId` | `requireAuth` | Stream do R2 **só se `scan_status = limpa`** (`409 { error: 'file_not_clean' }` caso contrário). Headers: `Content-Type` do `detected_type`, `Content-Disposition: inline; filename="…"`, `X-Content-Type-Options: nosniff`, `Content-Security-Policy: sandbox`, `Cache-Control: private, no-store` |
| `PATCH` | `/api/admin/contributions/:id` | `requireAuth` + `assertTrustedMutationOrigin` | `{ status: 'em_analise'\|'aceita'\|'recusada'\|'aplicada', decision_note?: string }`; grava `decided_at/by` |

Campos de `mine`/`:id` para o usuário: `id, kind, subkind, title, body, fields, links (só url), status, decision_note, created_at, updated_at, files: [{ id, original_name, size, scan_status }]`. Nunca `scan_detail`, `device` cru, nem `r2_key`.

**Validação do `POST`** (síncrona, antes de tocar o R2):
1. `payload` contra o schema de §3.1 (`kind`, `subkind`, `fields`); `title ≤ 120`, `body ≤ 4000`; `target_source ∈ {coldigom, plpcg}` se presente; `device` obrigatório e com `same_device: boolean` quando `kind = bug`.
2. `links ≤ 5`; cada um `https`, host ∈ `youtube.com | www.youtube.com | youtu.be | drive.google.com | docs.google.com`; caso contrário `400 { error: 'link_host_not_allowed', url }`.
3. Arquivos: `≤ 5`; cada `size ≤ 32 MiB` (`413 { error: 'file_too_large', file }`); extensão ∈ `pdf|mp3|jpg|jpeg|png|txt|chordpro` (`400 { error: 'file_type_not_allowed' }`); **magic bytes** dos primeiros 16 bytes conferem com a extensão (`%PDF-`; `ID3` ou frame sync `FF Ex/FF Fx`; `FF D8 FF`; `89 50 4E 47 0D 0A 1A 0A`; txt/chordpro: UTF-8 válido nos primeiros 4 KB) → `400 { error: 'file_type_mismatch', file }`. `kind = bug` aceita **só imagens**.
4. Cota: linha `(user_id, hoje)` de `contribution_quota`; `429 { error: 'quota_exceeded', resetAt }` se `count ≥ 20` ou `bytes + total > 200 MiB`. Incremento no mesmo `batch` D1 do insert.
5. Só então: `put` de cada arquivo em `quarantine/<contribId>/<fileId>.<ext>` calculando `sha256` no stream; ao terminar todos, `batch` D1 (`contributions` + `contribution_files` + quota) e `CONTRIB_SCAN.send({ contributionId, phase: 'submit', attempt: 0 })` se houver arquivo ou link.

Um `put` que falhar apaga os anteriores e responde `500 { error: 'upload_failed' }` — nunca fica lixo no R2 sem linha em D1.

## 5. Pipeline de scan — Queue `contrib-scan`, `api/src/contributions/scan.ts`

`wrangler.toml`: producer binding `CONTRIB_SCAN`, consumer `max_batch_size = 1`, `max_concurrency = 2`, `max_retries = 10`. Mensagem `{ contributionId, phase: 'submit' | 'poll', attempt }`.

| Passo | Módulo | O quê |
|---|---|---|
| 0 | `scan.ts` | **Dedupe:** para cada arquivo, se existe `contribution_files.sha256` igual com `scan_status = limpa`, copia `detected_type` e `scan_detail` e pula os passos 1 e 3 para ele. |
| 1 | `structural.ts` (puro) | Reconfere magic bytes sobre o objeto inteiro e grava `detected_type`. **PDF:** varre por `/JavaScript`, `/JS`, `/Launch`, `/OpenAction`, `/AA`, `/EmbeddedFile`, `/RichMedia`, `/XFA`, `/Encrypt` → `suspeita` com os tokens em `scan_detail.structural.tokens` (limitação documentada: tokens dentro de `/ObjStm` comprimido não são vistos; o VT cobre). **MP3:** frame sync ou ID3 no início; `APIC` > 2 MB → `suspeita`. **JPG/PNG:** cabeçalho + trailer (`FF D9` / `IEND`). **txt/chordpro:** UTF-8 válido, sem byte nulo, ≤ 256 KB. |
| 2 | `links.ts` | Normaliza (só `https`, allowlist, remove `utm_*`/`si`/`feature`), chama **Safe Browsing Lookup v4** `threatMatches:find` (`MALWARE`, `SOCIAL_ENGINEERING`, `UNWANTED_SOFTWARE`; plataformas `ANY_PLATFORM`; tipos `URL`). Match → `unsafe`. Erro/`429` → `adiado`. |
| 3 | `virustotal.ts` | Só para arquivos com estrutural ok e sem dedupe. `GET /api/v3/files/{sha256}`: conhecido → usa `last_analysis_stats`. `404` → `POST /api/v3/files` (upload ≤ 32 MB) → guarda `analysisId`, reenfileira `{ phase: 'poll' }` com `delaySeconds: 60`. `poll`: `GET /api/v3/analyses/{id}`; `queued` → retry 60 s (até 10×, depois `adiado`); `completed` → `malicious ≥ 1` → `infectada`; só `suspicious ≥ 1` → `suspeita`; senão `limpa`. `429`/5xx → `adiado`, retry 15 min. Contador global: linha `('_vt', hoje)` em `contribution_quota.count`; ≥ 450 → `adiado` até o dia virar. |
| 4 | `scan.ts` | Todos `limpa` (ou só links `clean`, ou `sem_arquivo`) → `R2.copy` (`get` + `put`) para `contributions/<contribId>/…`, `delete` do de quarentena, `status = pendente`, `scan_status = limpa`. Qualquer `infectada | suspeita | unsafe` → `status = bloqueada`, `scan_status` = pior veredito, arquivos ficam em `quarantine/`. |

**Adiado:** `message.retry({ delaySeconds })`. Depois de 24 h desde `created_at` (verificado no consumer, não pelo `max_retries`), `bloqueada` com `scan_report.reason = 'timeout'`; o usuário vê «Não pôde ser analisada; tente enviar de novo».

**Cron diário** (`[triggers] crons = ["0 3 * * *"]`, handler `scheduled`): `recebida` há > 6 h → reenfileira `submit`; há > 24 h → `bloqueada(timeout)`. Cobre mensagem perdida.

**Lifecycle rule** no bucket `coldigom-assets`: apagar `quarantine/` após 30 dias (criada uma vez pelo dashboard; documentada no README do coldigom-api).

**Segredos:** `VIRUSTOTAL_API_KEY`, `SAFE_BROWSING_API_KEY` (`wrangler secret put`). Sem eles em dev local, passos 2–3 são pulados com `scan_detail.skipped = 'no_api_key'` e o arquivo **fica `adiado`** (não libera). Em produção a ausência é erro logado.

## 6. App Flutter — `lib/features/contributions/`

Estrutura `data / domain / presentation` como `material_kind_prefs`.

### 6.1 Entradas

- `profile_screen.dart`: tiles «Ajude a melhorar o PLPCG» → `RoutePaths.contribute` (`/contribuir`) e «Minhas contribuições» → `RoutePaths.myContributions` (`/contribuicoes`). Deslogado: as duas rotas mostram o card «Entre com Google para contribuir» + `GoogleSignInButton`.
- `MaterialSheet._SheetHeader`: `IconButton(Icons.flag_outlined, tooltip: «Reportar»)` ao lado do ✕ → `/contribuir?source=<coldigom|plpcg>&praiseId=<id>`. No formulário, com `praiseId`, aparece o seletor **«Sobre qual material?»** (materiais do grupo + «o louvor em geral») que define `target_material_id`.
- `PdfReaderScreen` (barra) e `AudioPlayerScreen` (`PopupMenuButton` existente): item «Reportar» → `/contribuir?source=…&praiseId=…&materialId=…`.
- `app_route` = `GoRouterState.of(context).uri.toString()` da tela de origem, passado como query `from=` e gravado no payload.

### 6.2 Formulário — `ContributeScreen`

Uma página rolável, sem wizard:

1. **Tipo** (chips): Bug · Informação errada · Conteúdo · Melhoria · Outro. Com alvo pré-preenchido o padrão é «Informação errada»; sem alvo, nenhum selecionado.
2. **Subtipo** (chips de §3.1) e campos estruturados: `metadata` → dropdown do campo + «valor atual» (pré-preenchido do catálogo local quando há alvo) + «valor correto»; `duplicate` → campo de busca de louvor (reusa o widget de busca da Home) que preenche `otherPraiseId/otherSource`; `content` → dropdown opcional de kind (lista do catálogo Coldigom local).
3. **Título** (≤ 120) e **descrição** (≤ 4000; para bug, placeholder «O que fez, o que esperava, o que aconteceu»).
4. **Anexos:** `file_picker` com filtro por extensão (bug → só `jpg|jpeg|png`), até 5; arquivo > 32 MiB é recusado no cliente com «Acima de 32 MB, envie pelo link do Drive». **Links** (YouTube / Drive), até 5, validação de host no cliente com a mesma allowlist.
5. **Só bug — Dispositivo:** cartão «Isto será enviado» listando o `DeviceSnapshot` em linguagem humana e a pergunta obrigatória **«O bug aconteceu neste dispositivo?»** Sim/Não; Não abre «Em qual dispositivo?» (texto obrigatório). Enviar fica desabilitado até responder.
6. **Enviar:** `LinearProgressIndicator` com `onSendProgress`; `201` → `SnackBar` «Recebido, obrigado!» e `pop`; `429` → «Limite diário atingido; volta às HH:MM»; `413/400` → mensagem específica do erro; sem rede / `503` → «Sem ligação; tente de novo» **mantendo o formulário preenchido**. Sem rascunho persistido.

### 6.3 Coleta de dispositivo — `DeviceSnapshotPort`

Implementações por conditional import (padrão dos ports de storage): nativa (`device_info_plus` + `package_info_plus`) e web (`window.navigator.userAgent`, `matchMedia('(display-mode: standalone)')`). Produz:

```dart
class DeviceSnapshot {
  final String appVersion, buildNumber, platform;   // 'android' | 'ios' | 'web'
  final String locale;
  final int screenW, screenH; final double pixelRatio;
  final bool online, pwaStandalone;
  final String? manufacturer, model, osVersion;      // nativo
  final String? userAgent;                           // web
  Map<String, dynamic> toJson();
}
```

Fake em testes. Nenhum identificador único de dispositivo é coletado.

### 6.4 «Minhas contribuições» — `MyContributionsScreen`

Lista paginada por cursor, `pull-to-refresh`, chip de estado colorido + tipo + data; toque abre `ContributionDetailScreen` com título, descrição, campos estruturados, anexos (nome, tamanho, estado do scan em linguagem humana), links e `decision_note`. Mapa de estado → texto:

| status | Texto |
|---|---|
| `recebida` | Enviada · verificando anexos |
| `pendente` | Aguardando análise |
| `em_analise` | Em análise |
| `aceita` / `recusada` / `aplicada` | Aceita / Recusada / Aplicada (+ nota) |
| `bloqueada` | Não pôde ser analisada: anexo recusado pela verificação de segurança |

### 6.5 Rede e dependências

- `ContributionsRemoteDatasource` com `Dio` do `coldigomDioProvider`, endpoints em `ColdigomEndpoints` (`contributions`, `contributionsMine`), Bearer = `sessionToken` do `authStateProvider`; `401` → interceptor de deslogar existente (`auth_unauthorized_interceptor.dart`). Upload `FormData` multipart com `onSendProgress`; `sendTimeout` 5 min.
- Deps novas em `pubspec.yaml`: `file_picker`, `device_info_plus`, `package_info_plus` (todas com suporte web).
- Strings em `app_pt.arb` / `app_en.arb`.

## 7. Segurança além do scan

- `contributions/` e `quarantine/` **nunca** passam pelo proxy público de assets (`coldigom_assets_proxy` só conhece `assets/praises/`). O único leitor é a rota admin de §4.2, que exige `scan_status = limpa`.
- `Content-Type` da resposta admin vem do `detected_type`, nunca do nome do arquivo; `CSP: sandbox` + `nosniff` impedem que um «PDF» vire HTML executável.
- `title`, `body`, `fields`, `original_name` são texto e são renderizados como texto no Coldigom web (React escapa). `original_name` normalizado antes do `Content-Disposition`.
- Cota por usuário + `5 × 32 MiB` por pedido limitam um abusador a 200 MiB/dia. Bloqueio de usuário fica fora do escopo (é um `UPDATE` na `users` do `plpcg-catalog`).
- `PLPCG_AUTH_URL` fixo na config; introspect só aceita `sess_`.

## 8. Falhas e comportamento

| Situação | Resultado |
|---|---|
| Upload parcial (rede caiu) | Nenhuma linha em D1; objetos R2 já gravados apagados no `catch` |
| Introspect fora do ar | `503 auth_unavailable`; app «tente de novo» mantendo o formulário |
| Queue não entregou | Cron diário reenfileira (> 6 h) ou bloqueia por timeout (> 24 h) |
| Scanner externo indisponível / cota | `adiado` + retry com delay; nunca libera |
| Arquivo já visto (hash) | Resultado reaproveitado; contribuição segue |
| Sessão expirou durante o preenchimento | `401` → deslogar; formulário perdido (aceite explícito: sem rascunho persistido) |

## 9. Testes

**coldigom-api (vitest):**
- `structural.test.ts`: fixtures mínimas — PDF limpo, PDF com `/JavaScript`, PDF com `/Encrypt`, MP3 com ID3, MP3 com frame sync, PNG válido, PNG truncado, «pdf» que é HTML, txt com byte nulo → veredito e `detected_type` esperados.
- `links.test.ts`: allowlist de hosts (aceita/recusa), normalização, Safe Browsing mockado (match, vazio, `429`).
- `virustotal.test.ts`: hash conhecido (sem upload), upload → poll `queued` → `completed` limpo, `completed` malicioso, `429` → adiado, contador diário ≥ 450 → adiado.
- `scan.test.ts`: dedupe por hash, decisão final (todos limpos → copy/delete/pendente; um infectado → bloqueada; timeout 24 h).
- `contributions.routes.test.ts`: `POST` feliz com e sem arquivos; `400` schema/tipo/magic/host; `413` tamanho; `429` cota; `bug` sem `device.same_device` → `400`; `mine` só do próprio usuário; `:id` de outro → `404`; `admin/files` recusa não-limpo com `409`; `PATCH` admin exige origem confiável.
- `appUser.test.ts`: cache por 5 min, `401` propagado, `503` em falha de rede, token sem `sess_` → `401`.

**plpcg-catalog (vitest):** `introspect.test.ts` — sessão válida, expirada, JWT recusado, sem Bearer; não toca `last_used_at`.

**Flutter:**
- Unit: `ContributionDraft.toPayload()` por `kind/subkind`; validador de anexos (extensão, 32 MiB, bug só imagens) e de links (allowlist); `DeviceSnapshot.toJson()` com fake.
- Widget: `ContributeScreen` — bug exige a pergunta do dispositivo antes de habilitar Enviar; arquivo > 32 MiB mostra a mensagem do Drive; alvo pré-preenchido seleciona «Informação errada»; `429` mostra hora do reset.
- Provider: `myContributionsProvider` com datasource fake (paginação por cursor, refresh).

## 10. Deploy (ordem)

1. `cd ../coldigom/api && npx wrangler d1 execute coldigom --remote --file=migrations/020_contributions.sql`
2. `npx wrangler queues create contrib-scan`
3. `npx wrangler secret put VIRUSTOTAL_API_KEY` e `SAFE_BROWSING_API_KEY`; `PLPCG_AUTH_URL` em `[vars]`
4. Lifecycle rule `quarantine/` → 30 dias, no dashboard do bucket `coldigom-assets`
5. Deploy `plpcg-catalog` (introspect) — antes do coldigom-api, que depende dele
6. Deploy coldigom-api (`npm run deploy` já inclui Queue consumer e cron)
7. App: build web para `v2.plpcg.com` + lojas quando couber

## 11. Sequência de implementação sugerida

1. `plpcg-catalog`: `GET /api/auth/introspect` + teste.
2. coldigom-api: migration 020, `appUser.ts`, `structural.ts`, `links.ts`, `virustotal.ts` (cada um com testes puros).
3. coldigom-api: rotas `POST/GET mine/:id`, `scan.ts` + Queue + cron, rotas admin.
4. Flutter: domain/data (`DeviceSnapshotPort`, datasource, providers) → `ContributeScreen` → entradas (Perfil, sheet, leitor/player) → `MyContributionsScreen` → i18n.
5. Deploy §10 e validação em `v2.plpcg.com` com um envio real de cada `kind`.

# TODO — Coldigui / PLPCG

Lista de trabalho futuro com breve descrição de cada item. Ordem sugerida: lançamento atual → infraestrutura de releases → conteúdo/formatos → integração Coldigom → evolução do app.

---

## Lançamento e releases

### 1. Lançamento Web/PWA (prioridade) e lojas nativas (adiado)

**Foco atual:** PWA de alta qualidade em produção (Cloudflare Pages) — catálogo, biblioteca, leitor PDF, offline, playlists locais, shell com 5 abas. Inclui: `flutter build web` release; `web/manifest.json` e instalabilidade; smoke tests web (`test/web/`); política de privacidade no domínio; validação Worker/catálogo em produção.

**Lojas nativas (iOS/Android):** adiadas por questões jurídicas; checklist de stores permanece como referência futura (certificados, keystore, metadados, `--dart-define-from-file`).

### 2. Estudar versões beta e canais de teste

Definir estratégia para testar features futuras sem impactar usuários em produção. Opções a avaliar: **TestFlight** (iOS) e **Internal/Closed testing** (Google Play); flavors ou `--dart-define` para apontar API/staging; versionamento semver + build number; feature flags; eventual CI que publique builds beta automaticamente; critérios de promoção beta → produção.

---

## Formatos de conteúdo e viewers

### 3. Gestos em Gravura — arquivos `.txt` + ferramenta visual

Especificar e gerar arquivos `.txt` com a representação dos gestos (app separada em desenvolvimento). No Coldigui, criar ferramenta visual para **ler e desenhar** esses gestos — substituindo ou complementando PDFs estáticos, com editor/viewer integrado ao leitor e ao fluxo de busca por material.

### 4. Cifras — arquivos `.txt` + viewer

Levantar o estado atual das cifras no acervo e definir formato `.txt` (notação, acordes, layout). Implementar **viewer** que renderize cifras desenhadas a partir desses arquivos, alinhado aos filtros existentes (`Cifra`, `Cifra nível I/II`) e à abertura de louvores no leitor.

---

## Integração Coldigom

### 5. Desenhar integração inicial com Coldigom

Documentar arquitetura da primeira fase de integração com o **Coldigom** (fonte de dados ampliada), cobrindo apenas: **Pesquisa**, **Leitor** e **Listas**. Demais capacidades (social, eventos, plugins, etc.) ficam para versões posteriores. Entregável: spec com fluxos, endpoints/contratos, fallbacks offline e critérios de “integração mínima utilizável”.

### 6. Adapters Coldigom → estrutura PLPCG

Implementar camada de **adapters** que traduza entidades do Coldigom para o modelo atual do PLPCG (`Louvor`, `LouvorGroup`, `pdfId`, playlists, cache Isar). Objetivo: o restante do app (Home, Biblioteca, Leitor, Listas) consumir dados unificados sem reescrever features existentes.

---

## Navegação e conta do usuário

### 7. Aba Perfil — Sobre, Listas, Offline e sync online

Reorganizar o shell: aba **Perfil** aglutinando **Sobre**, **Listas** e **Offline**. **Login Google + `users` no D1** implementados (ver [docs/GOOGLE_OAUTH_SETUP.md](docs/GOOGLE_OAUTH_SETUP.md)); falta **sync de listas na nuvem** — ver [docs/USER_AUTH_PLAYLIST_SYNC_SPEC.md](docs/USER_AUTH_PLAYLIST_SYNC_SPEC.md). iOS/Android na fase 2.

### 8. Materiais favoritos no Perfil

Permitir que o usuário **fixe materiais preferidos** (Partitura, Cifra, Gestos, etc.) na aba Perfil para acelerar busca e filtros quando o Coldigom estiver totalmente integrado — atalho persistente local (e depois sync remoto, se aplicável).

---

## Features de plataforma (pós-MVP / monetização)

### 9. Aba Social

Nova aba para interação entre usuários: **seguir pessoas**, ver **listas públicas**, seguir ou **copiar listas** de outros perfis. Depende de auth, backend e políticas de privatação/publicação de playlists (extensão natural do sync de listas).

### 10. Aba Eventos

Permitir cadastro de **eventos** na plataforma (cultos, ensaios, congressos) com modelo de **publicidade paga** — primeira linha de **monetização** prevista. Inclui fluxo de criação, moderação, destaque patrocinado e integração com pagamentos (a definir).

### 11. Plugins sob demanda

Arquitetura de **plugins** (mini-módulos instalados/ativados sob demanda): Metrônomo, Afinador e ferramentas similares, sem inflar o binário base. Avaliar lazy loading, feature flags, store interno de plugins e isolamento por pacote/feature module.

---

## Resumo por dependência

| Item | Depende de |
|------|------------|
| 1 Web/PWA | MVP estável (baseline jul/2026) |
| 2 Beta | 1 (processo de release definido) |
| 3 Gestos `.txt` | Spec do formato + app Gestos em dev |
| 4 Cifras `.txt` | Inventário do acervo + spec do formato |
| 5 Spec Coldigom | Contexto Coldigom + modelo PLPCG atual |
| 6 Adapters | 5 |
| 7 Perfil + sync | [USER_AUTH_PLAYLIST_SYNC_SPEC](docs/USER_AUTH_PLAYLIST_SYNC_SPEC.md) |
| 8 Favoritos materiais | 7 (Perfil) + integração Coldigom (6) |
| 9 Social | 7 (auth/conta) |
| 10 Eventos | 7 (auth) + backend/pagamentos |
| 11 Plugins | Shell estável; opcionalmente Perfil como hub |

---

*Última atualização: julho de 2026*

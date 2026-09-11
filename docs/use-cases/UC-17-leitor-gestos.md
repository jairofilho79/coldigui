# UC-17 — Leitor de Gestos CIAs

**Criado em:** 2026-09-11
**Status:** Implementado (set/2026)
**Complementa:** UC-11 (leitor PDF), leitor de cifras, [FEATURE_INDEX.md](../features/FEATURE_INDEX.md)
**Spec:** [2026-09-11-leitor-gestos-design.md](../superpowers/specs/2026-09-11-leitor-gestos-design.md)

## Objetivo

O regente ou instrutor de CIA abre, no celular ou tablet, o documento de gestos de um louvor: figura do gesto à esquerda, letra à direita com o **gatilho em vermelho** e a **leitura em preto**; blocos de repetição, coro, ligação e final desenhados com chaves como no PDF. Um toque num cartão abre o **modo foco** (um gesto por tela, próximo gatilho no rodapé).

## Fluxo principal

1. No sheet de materiais de um louvor Coldigom aparece a seção **Gestos** quando o Worker publica um material `type: gestures`.
2. Toque → `/gestos?pdfId=…` (mesmo espaço de ids do PDF; entra na lista ativa e no carousel).
3. A tela busca o documento (`assets/praises/{pid}/{mid}.gestures`) e o dicionário (`GET /api/gestures/dictionary`, `If-None-Match`), ambos cache-first no Isar; as figuras dos gestos do louvor são pré-buscadas para o store local.
4. `A-`/`A+` (ou `Ctrl+↑/↓`) mudam o corpo da letra (14–28, persistido); `F` tela cheia; `Ctrl+←/→` trocam de louvor pelo carousel.
5. Toque num cartão → modo foco: `←`/`→`, swipe ou toque nas metades; `Esc` fecha e a página rola até o cartão.

## Fluxos alternativos

- Documento 404 → "Este louvor ainda não tem gestos" (marcador negativo no cache).
- Falha de rede sem cache → "indisponível · tentar de novo".
- `gestureId` fora do dicionário → placeholder com o id; item de tipo desconhecido → linha de texto; `schema` com major > 1 → banner e renderiza.
- Modo avião após um primeiro acesso online → documento, dicionário e figuras vêm do cache.

## Fora de escopo (v1)

Duas colunas em tablet paisagem; gestos nos pacotes ZIP offline; GIF fora do foco; edição; busca por gesto.

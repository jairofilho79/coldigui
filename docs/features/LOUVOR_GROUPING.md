# Agrupamento de louvores (`groupId`) — especificação para agentes

> **Para agentes:** documento normativo para backlog de catálogo. Não implementar `groupId` na UI nem no manifest sem seguir este spec. APIs públicas planejadas estão listadas em [FEATURE_INDEX.md § APIs planejadas](./FEATURE_INDEX.md#apis-planejadas--agrupamento-groupid).

**Status:** **parcialmente implementado** (jun/2026) — app agrupa client-side via `LouvorGroupId.compute`; script Python disponível; campo `groupId` no manifest remoto ainda opcional.  
**Relacionado:** UC-01 (Home), UC-03 (Biblioteca), UC-12 (manifest)  
**Índice geral:** [FEATURE_INDEX.md](./FEATURE_INDEX.md) · [AGENT_PIPELINE.md](../AGENT_PIPELINE.md)

---

## Contexto

Hoje cada entrada de `louvores-manifest.json` representa **um PDF**. Na prática, o mesmo louvor pode ter vários materiais:

- Partitura  
- Cifra / Cifra nível I / Cifra nível II  
- Gestos em Gravura  

O app lista e trata cada PDF como se fosse um louvor distinto. O objetivo é agrupar por **louvor lógico** e, ao tocar no card, abrir uma **sublista de materiais** em vez de ir direto ao leitor.

---

## Estado atual do manifest

Cada entrada tem (entre outros):

| Campo | Papel |
|-------|--------|
| `nome` | Título do louvor |
| `numero` | Número na coletânea (pode estar vazio — ~24% das entradas, sobretudo Avulsos) |
| `classificacao` | Coletânea, PES, Avulsos, arranjo especial entre parênteses, etc. |
| `categoria` | Tipo de material: `Partitura`, `Cifra nível I`, `Cifra nível II`, `Cifra`, `Gestos em Gravura` |
| `pdf` | Nome do arquivo |
| `pdfId` | Base64 UTF-8 do caminho relativo — **identificador único do PDF** |

**Regra absoluta:** `pdfId` continua sendo a chave de abertura de PDF, offline, carousel e playlists. `groupId` é apenas a chave de **agrupamento na UI e no catálogo**.

---

## Hierarquia na UI (acordada)

Três níveis. Exemplo real acordado na sessão de design:

```text
[Nível 0 — card na lista principal]
609 — Senhor, meu Deus, quando eu maravilhado
(todas as entradas abaixo compartilham o mesmo groupId)

[Nível 1 — seções na sublista, por classificação]
├── Coletânea Adultos
├── Trombetas e Festas 2025
└── Casamento Fulado de Tal e Fulada

[Nível 2 — folhas, por categoria = 1 PDF cada]
Coletânea Adultos
    Partitura        → pdfId → leitor
    Cifra nível I    → pdfId → leitor
    Cifra nível II   → pdfId → leitor
Trombetas e Festas 2025
    Partitura        → pdfId → leitor
Casamento Fulado de Tal e Fulada
    Partitura        → pdfId → leitor
    Cifra            → pdfId → leitor
```

### Semântica dos níveis

| Nível | Chave | O que representa |
|-------|--------|------------------|
| 0 | `groupId` | O **louvor** (obra musical), independente de coletânea ou material |
| 1 | `classificacao` | **Onde** aquele material se enquadra (coletânea, evento, casamento, PES, arranjo especial) |
| 2 | `categoria` | **Qual** material abrir — sempre um único `pdfId` |

A classificação **não** define o grupo na lista principal; ela organiza a sublista depois do tap.

### Rótulos na UI

- Nível 1: preferir `LouvorClassification.displayLabel(classificacao)` quando for coletânea padrão; para eventos/casamentos, usar a string completa ou o arranjo especial conforme UX.
- Nível 2: valor de `categoria` do manifest (ENUM pt-BR).
- Ordem sugerida das categorias: Partitura → Cifra nível I → Cifra nível II → Cifra → Gestos em Gravura.

---

## Modelo de dados (planejado)

### Manifest — campo novo

```json
{
  "nome": "Senhor, meu Deus, quando eu maravilhado",
  "numero": "609",
  "classificacao": "Coletânea Adultos",
  "categoria": "Partitura",
  "pdf": "609.pdf",
  "pdfId": "...",
  "groupId": "609:senhor-meu-deus-quando-eu-maravilhado"
}
```

### Entidades de domínio (Flutter)

```dart
/// Louvor lógico — 1 card na Home/Biblioteca.
class LouvorGroup {
  final String groupId;
  final String numero;       // pode ser ""
  final String nome;         // título canônico do grupo
  final List<LouvorMaterialSection> sections;
}

/// Subdivisão por classificação do manifest.
class LouvorMaterialSection {
  final String classificacao;   // string completa (com parênteses se houver)
  final String displayLabel;    // LouvorClassification.displayLabel(...)
  final List<LouvorMaterialEntry> materials;
}

/// Folha — exatamente 1 PDF.
class LouvorMaterialEntry {
  final String categoria;
  final String pdfId;
  final Louvor louvor;          // entrada original do manifest (share, offline, etc.)
}
```

### Construção a partir do manifest

1. Agrupar entradas por `groupId`.
2. Dentro do grupo, agrupar por `classificacao` (string **completa**, incluindo arranjo especial).
3. Dentro de cada classificação, listar por `categoria` (ordenar conforme tabela acima).
4. Escolher `nome` canônico do grupo: Partitura da coletânea principal, ou título mais frequente, ou primeiro por ordem estável.
5. Conflito: mais de um PDF para o mesmo `(groupId, classificacao, categoria)` → reportar para revisão manual; **não** fundir automaticamente.

---

## Regras de `groupId`

### Regra principal

```
groupId = f(numero, nomeNormalizado)
```

- `nomeNormalizado` = `LouvorSearchTokens.normalize(nome)` (`lib/core/utils/louvor_search_tokens.dart`).
- **Não incluir** `classificacao` no `groupId`.
- **Não incluir** `categoria` no `groupId`.

### Casos especiais

| Situação | Regra |
|----------|--------|
| Com `numero` preenchido | `slug(numero) + ":" + slug(nomeNormalizado)` — ex.: `609:senhor-meu-deus-quando-eu-maravilhado` |
| Sem `numero` (Avulsos) | `avulso:` + slug(`nomeNormalizado`) ou hash curto estável do título |
| Mesmo número, títulos diferentes | **Grupos distintos** — o número sozinho não identifica o louvor entre coletâneas (ex.: `10` em ColAdultos vs ColCIAs são músicas diferentes) |
| Variantes de título no mesmo louvor | Unir no mesmo grupo se `nomeNormalizado` for igual ou similaridade ≥ 0,85 (`SequenceMatcher`); escolher título canônico |
| PES com colisão de número | **Não** agrupar só por número — exigir par `(numero, nomeNormalizado)` ou prefixo no filename (`PES-003` vs `A003`) |
| Arranjos especiais | Mesmo `numero` + mesmo `nome` em `Coletânea CIAs` e `Coletânea CIAs (Evangelização…)` → **mesmo** `groupId`, **classificações diferentes** na sublista |

### O que `groupId` **não** é

- Não substitui `pdfId`.
- Não é único por coletânea (`classificacao:numero` foi **rejeitado** — geraria cards duplicados do mesmo louvor).
- Não deve ser hash opaco se slug legível for possível (facilita debug e script de revisão).

---

## Critérios do script de atribuição (`assign_louvor_group_ids.py`)

Pipeline em camadas (prioridade decrescente):

### Camada 1 — Alta confiança

Agrupar entradas que compartilham `(numero, nomeNormalizado)` com `numero != ""`.

### Camada 2 — União partitura ↔ materiais via caminho (`pdfId`)

Dois layouts no acervo:

- **Profundidade 2:** `ColAdultos/101.pdf`, `ColCIAs/100.pdf`
- **Profundidade 3:** `Louvores Coletânea CIAs/100 - Título/Cifra I.pdf`

Extrair número da pasta (`^(\d+)\s*-\s*`) e mapear prefixo → classificação base para fundir partitura depth-2 com cifras/gestos depth-3 **no mesmo** `groupId` quando `(numero, nome)` coincidem.

### Camada 3 — Pasta louvor (depth 3)

Agrupar por `{collectionFolder}/{louvorFolder}` e depois fundir com Camada 1/2.

### Camada 4 — Avulsos sem número

- `(nomeNormalizado, classificacao)` quando ambos batem.
- Paths em `Adicionados/` (segmentos base64 decodificam para `Adicionados/{Título}/Cifra.pdf`) pareados com `Avulsos/NNN.pdf` via título normalizado.

### Camada 5 — Fuzzy de título

Dentro de candidatos com mesmo `numero`, unir nomes com similaridade ≥ 0,85.

### Camada 6 — Revisão manual obrigatória

Não fundir automaticamente:

- PES: mesmo `numero`, títulos claramente diferentes.
- Duplicatas: duas Partituras distintas no mesmo `(groupId, classificacao)`.
- Grupos com nomes conflitantes e similaridade &lt; 0,85.

### Saídas do script

- `louvores-manifest.json` com `groupId` em cada entrada.
- `grouping-report.json` — estatísticas, conflitos, singletons.
- `grouping-revisao.csv` — linhas ambíguas para curadoria humana.
- Modo `--dry-run` sem alterar o manifest.

---

## Comportamento na UI (planejado)

| Situação | Comportamento |
|----------|----------------|
| Grupo com **1 PDF** total | Abrir leitor direto **ou** sublista mínima (decisão de UX na implementação) |
| Grupo com **2+ PDFs** | Tap no card → bottom sheet / lista aninhada (classificação → categoria) → tap na categoria → leitor |
| Busca UC-01 | Indexar cada `Louvor`; exibir o **grupo** se qualquer material corresponder |
| Filtros UC-02/03 | Filtrar materiais; exibir grupo se **sobrar** ≥ 1 PDF após filtro |
| Carousel UC-05 | Continua com `pdfId` (material específico escolhido na sublista) |
| Playlists UC-06/07 | Continua com `pdfId` |
| Offline UC-09/10 | Continua com `pdfId` |
| Share UC-04 | Por material (`pdfId`), não por grupo |

---

## Números de referência (análise do manifest remoto, jun/2026)

Úteis para validar o script; recontar após cada atualização do manifest.

| Métrica | Valor aproximado |
|---------|------------------|
| Entradas totais | ~4 627 |
| Grupos óbvios `(numero, classificacao)` com &gt; 1 PDF | ~1 054 (critério antigo — **não** usar como `groupId`) |
| Entradas sem `numero` | ~1 100 |
| Números que aparecem em múltiplas classificações | ~394 (músicas diferentes — não agrupar só por número) |

Categorias no manifest: Partitura, Cifra nível I/II, Cifra, Gestos em Gravura.

---

## Próximos passos de implementação

1. **Script:** `scripts/assign_louvor_group_ids.py` — atribuir `groupId` no manifest.
2. **DTO/entidade:** `groupId` em `LouvorDto`, `Louvor`, cache Isar (`LouvorCache`).
3. **Use case:** `GroupLouvoresByMaterial` — `List<Louvor>` → `List<LouvorGroup>`.
4. **UI:** `LouvorCard` / biblioteca — lista de grupos; widget de sublista por classificação → categoria.
5. **Testes:** unitários do agrupamento + widget da sublista.
6. **Publicação:** atualizar manifest remoto + checksum (skill `plpcg-louvores-manifest`).

---

## Anti-padrões (não fazer)

- Agrupar por `(numero, classificacao)` como `groupId` — isso mantém um card por coletânea, não por louvor.
- Assumir que `numero` é único globalmente.
- Inventar `classificacao` ou `nome` canônico no script sem confirmação humana em casos ambíguos (ver skill `plpcg-louvores-manifest`).
- Trocar `pdfId` por `groupId` em carousel, playlists ou rotas do leitor.
- Abrir PDF automaticamente quando o grupo tem múltiplos materiais sem o usuário escolher a categoria.

---

## Referências no repositório

| Artefato | Caminho |
|----------|---------|
| Entidade atual | `lib/features/catalog/domain/entities/louvor.dart` |
| Normalização de título | `lib/core/utils/louvor_search_tokens.dart` |
| Classificação / arranjo especial | `lib/features/catalog/domain/utils/louvor_classification.dart` |
| Ícones por categoria | `lib/features/catalog/domain/utils/louvor_material_icons.dart` |
| Card atual (1 PDF = 1 tap) | `lib/features/catalog/presentation/widgets/louvor_card.dart` |
| Skill manifest | `~/.cursor/skills/plpcg-louvores-manifest/SKILL.md` |

---

*Documento gerado a partir da sessão de design jun/2026. Atualizar este arquivo quando as regras ou o modelo mudarem antes de implementar.*

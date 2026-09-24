# Seções da Coletânea — Plano 2: script de dados (validate-acervo)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** um comando novo do arnês `scripts/validate-acervo` liga cada praise com seção a uma das 13 subtags de `Coletânea` e liga o praise 11e a `Avulsos · GLTM`. Ele também desliga a raiz `Coletânea` de quem ganhou subtag. Tudo com ensaio por padrão, travas, guardas otimistas no SQL, relatório para o dono, log e `--undo`. A categoria não muda.

**Architecture:** comando próprio, `python3 -m core.secoes_coletanea`, no molde do `core/plpcg_apply.py`, e **não** um par detector + `core.apply`. Motivos:
- o `core.apply` só conhece `merge_praise` e `set_praise_field`;
- ele confere a pós-condição com uma consulta ao D1 por finding (seriam ~2240);
- ele não sabe criar tag;
- os portões dele (faixa alta, alvo repetido) não têm sentido aqui.

Do `core` o comando reusa:
- `core.snapshot.conectar`: lê o espelho `out/snapshot.sqlite`;
- `core.d1.write_sql_chunks` e `run_sql_files`: SQL em lotes, cada arquivo um batch atômico do D1;
- `core.d1.query`: leitura pontual;
- `core.d1.sql_str`;
- `core.plpcg_apply.copiar_execucao` (a cópia do run em `gabaritos/…/execucao/`) e `_erro_texto` (o stderr do wrangler).

Camadas:
- `montar_plano` (puro, só snapshot) → `sql_plano` (puro) → `executar`/`desfazer` (os únicos que chamam o wrangler).
- As constantes da spec (§2.1–2.3, copiadas literalmente) ficam em `core/secoes_coletanea_mapa.py`.

**Tech Stack:** Python 3.9 (stdlib), pytest 8, sqlite3; `wrangler d1` só em produção, nunca nos testes.

**Spec:** `docs/superpowers/specs/2026-09-24-secoes-coletanea-subtags-design.md`, no coldigui. Este plano cobre §2 (mapeamento), §5 (script) e o bloco validate-acervo de §8. A fase 3 (esvaziar `category`), a API, o admin e o app ficam em outros planos.

**Worktree/branch:** coldigom `.claude/worktrees/secoes-coletanea`, `feat/secoes-coletanea-subtags`. Caminho absoluto: `/Volumes/SSD 2TB SD/dev/coldigom/.claude/worktrees/secoes-coletanea`. A suíte do pacote está verde antes do plano: 228 testes.

## Global Constraints

- **Python 3.9.6 do sistema.** Todo arquivo novo começa com `from __future__ import annotations`. Nada de `match` e nada de `X | Y` fora de anotação. Só stdlib; pytest já está instalado.
- **pytest roda de dentro de `scripts/validate-acervo`.** Os imports são `from core import …`, então o comando é `cd "/Volumes/SSD 2TB SD/dev/coldigom/.claude/worktrees/secoes-coletanea/scripts/validate-acervo" && python3 -m pytest …`.
- **git roda a partir da raiz do worktree, com comandos simples** e caminhos relativos a essa raiz. O guard recusa `cd <path> && git …` e `git -C`. Não commitar `out/`, que é gitignored.
- **Nenhum teste toca o D1 remoto.** Os testes trocam `core.secoes_coletanea.query` e `run_sql_files` por funções que rodam num sqlite temporário de "produção", e o ensaio não chama nenhuma das duas. O banco dos testes tem o DDL de `api/schema.sql` para `praises`/`tags`/`praise_tags`, os índices `idx_tags_root_name`/`idx_tags_child_name` e `PRAGMA foreign_keys = ON`, como o D1.
- **`--execute` contra produção NÃO faz parte deste plano.** Quem roda é o dono, depois de ler o relatório do ensaio e depois do deploy da API (spec §6, passo 1). A Task 8 roda só o snapshot, que é leitura, e o ensaio.
- **Não mexer** em `core/apply.py`, `core/plpcg_apply.py` nem `core/d1.py`: só importar.
- **As strings da spec são copiadas byte a byte**, inclusive «Morte, Ressureição e Salvação». O mapeamento não aplica strip, casefold nem NFC. A única exceção é o vazio: `NULL` ou só espaço.
- **Commits** em português, no formato conventional, terminando com o trailer `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.
- **Nunca dizer que um teste passou sem rodá-lo e ler a saída.**

### Decisões do plano e desvios da spec

1. **`--undo` simula por padrão e só grava com `--execute`.** A spec escreve «`--undo <run_id>`». O arnês tem as duas convenções: `core.apply` exige `--undo <id> --execute`, e `core.plpcg_apply` grava direto. Este plano segue o `core.apply` e o «simula por padrão» do README.
2. **A trava (c) aceita também os estados de retomada.** Além das «Tags hoje» da tabela, a trava aceita as tags de hoje mais a subtag alvo, e as tags de hoje menos a raiz `Coletânea` mais a subtag alvo. Sem isso, a nova rodada que a spec §7 manda fazer depois de um `--execute` parcial abortaria na trava (c). Além disso, um id manual cuja `category` dê seção de §2.1 também aborta em (c), porque a tabela da spec não prevê dois alvos.
3. **O `DELETE` da raiz exige a subtag já ligada**, além de exigir que a ligação exista. Se a guarda barrar o `INSERT`, o praise não sai da Coletânea.
4. **O `INSERT` usa `INSERT OR IGNORE … SELECT … WHERE EXISTS (praise com a category do snapshot)`, e não `VALUES`.** Assim, um praise apagado depois do snapshot vira no-op, em vez de violar a FK e derrubar o arquivo inteiro. A comparação usa `category IS <valor>`, que também casa `NULL`. Nos manuais, o `WHERE` exige ainda o mesmo conjunto de tags do snapshot, por contagem.
5. **No `--execute`, produção manda no que o SQL referencia por id:**
   - as raízes, e o script aborta se o id mudou;
   - as subtags, e uma subtag criada pelo admin depois do snapshot é reaproveitada;
   - as ligações que já existiam antes. Essas nunca entram na lista do undo.
6. **`--execute` é recusado** se o log tem uma escrita deste comando (execução ou undo) posterior ao snapshot. É a regra «refazer o snapshot entre dois `--execute`» do README, aplicada no código.
7. **Os arquivos são próprios:** o log vai para `out/secoes_coletanea_log.jsonl`, e a cópia de cada run para `gabaritos/secoes_coletanea/execucao/<run_id>.jsonl`, que entra no git. O ensaio grava `out/secoes_coletanea/<run_id>/relatorio.md` e `…/sql/`.
8. **O relatório compara nomes em NFC.** No snapshot de 17/09, os nomes de praise estão em NFD e as categorias em NFC. Isso vale só para a lista «entram na Coletânea»; o mapeamento continua byte a byte.
9. **O snapshot sem a árvore:** `python3 -m core.snapshot --assets2 /dev/null/sem-arvore`. O script não precisa indexar os 26 GB de `assets2`.

## Review Focus

1. **Praise sai da Coletânea sem ganhar a subtag.** Acontece quando o `DELETE` da raiz roda depois de um `INSERT` barrado pela guarda. Testes: `test_delete_da_raiz_exige_a_subtag_ligada` e `test_guarda_category_mudou_depois_do_snapshot` (Task 3).
2. **Uma FK derruba um batch atômico inteiro.** Um praise apagado entre o snapshot e o `--execute` não pode abortar o arquivo. Teste: `test_guarda_praise_apagado_nao_derruba_o_lote` (Task 3).
3. **O undo apaga o que o run não criou.** Pode ser uma ligação que já existia em produção, ou uma subtag que ganhou ligação nova; como `praise_tags.tag_id` tem `ON DELETE CASCADE`, apagar essa subtag leva a ligação junto. Testes: `test_execute_nao_reclama_ligacao_que_ja_existia_em_producao` (Task 5), `test_undo_nao_apaga_subtag_que_ganhou_ligacao_nova` e `test_undo_nao_apaga_ligacao_que_ja_existia` (Task 6).
4. **A retomada da spec §7 aborta sozinha.** Depois de um `--execute` parcial, um manual já tem a subtag e a trava (c) recusaria. Teste: `test_trava_c_aceita_manual_ja_migrado` (Task 2).
5. **`ok` falso quando a guarda barrou.** O wrangler sai 0 mesmo quando o `WHERE` não casa; quem diz o que pegou é a releitura. E um segundo `--execute` com snapshot velho não pode passar. Testes: `test_execute_guarda_barrou_lista_quem_ficou_para_tras` (Task 5) e `test_main_recusa_execute_com_snapshot_mais_velho_que_a_ultima_escrita` (Task 7).

## Mapa de arquivos

Todos em `scripts/validate-acervo/`:

| Arquivo | Ação | Papel |
|---|---|---|
| `core/secoes_coletanea_mapa.py` | criar | constantes de §2.1–2.3 e `classificar()` |
| `core/secoes_coletanea.py` | criar (Tasks 2–7, uma seção por task) | plano, travas, SQL, relatório, execução, undo, CLI |
| `tests/test_secoes_coletanea_mapa.py` | criar | mapeamento |
| `tests/test_secoes_coletanea.py` | criar (Tasks 2–7, uma seção por task) | plano, travas, guardas, relatório, execução, undo, CLI |
| `README.md` | modificar (Task 7) | como rodar e as regras |

---

### Task 1: Constantes da spec e `classificar()`

**Files:**
- Create: `scripts/validate-acervo/core/secoes_coletanea_mapa.py`
- Create: `scripts/validate-acervo/tests/test_secoes_coletanea_mapa.py`

**Interfaces:**
- Consumes: nada.
- Produces:
  - as constantes `RAIZ_COLETANEA`, `RAIZ_AVULSOS`, `SEP_ROTULO`, `SECAO_POR_CATEGORIA: dict[str, str]`, `ESPERADO_DEPOIS: dict[str, int]`, `ESPERADO_TOTAL`, `ESPERADO_RAIZ_REMOVIDAS`, `ESPERADO_AVULSOS_GLTM`, `CATEGORIAS_COLECAO: frozenset[str]`, `ENTRAM_NA_COLETANEA: tuple[tuple[str, str], ...]`, `MANUAIS: tuple[dict, ...]` (chaves `id, short_id, numero, nome, tags_hoje: frozenset[str], pai, subtag`) e `SUBTAGS: tuple[tuple[str, str], ...]` (13 sob Coletânea e depois `("Avulsos", "GLTM")`);
  - `classificar(category: str | None) -> tuple[str, str | None]`.

- [ ] **Step 1: Escrever o teste que falha**

`scripts/validate-acervo/tests/test_secoes_coletanea_mapa.py`:

```python
# tests/test_secoes_coletanea_mapa.py
from __future__ import annotations

import pytest

from core import secoes_coletanea_mapa as m


@pytest.mark.parametrize("valor, subtag", [
    ("Clamor", "Clamor"),
    ("Crianças e Adolescentes", "Crianças e Adolescentes"),
    ("Contra-Capa", "Contra-Capa"),
    ("Morte, Ressureição e Salvação", "Morte Ressurreição e Salvação"),    # a grafia errada do D1
    ("Morte, Ressurreição e Salvação", "Morte Ressurreição e Salvação"),
    ("Santificação e Derramamento", "Santificação e Derramamento do Espírito Santo"),
    ("Santificação e Derramamento do Espírito Santo", "Santificação e Derramamento do Espírito Santo"),
])
def test_secao_mapeia_para_subtag(valor, subtag):
    assert m.classificar(valor) == ("secao", subtag)


@pytest.mark.parametrize("valor", ["Avulso", "Avulsos", "Avulso Cias", "Avulsos das Senhoras"])
def test_colecao_nao_gera_tag(valor):
    assert m.classificar(valor) == ("colecao", None)


@pytest.mark.parametrize("valor", [None, "", "   "])
def test_vazio(valor):
    assert m.classificar(valor) == ("vazio", None)


@pytest.mark.parametrize("valor", ["Dm", "clamor", "Clamor ", "Morte Ressurreição e Salvação", "Avulsos GLTM"])
def test_qualquer_outra_grafia_e_desconhecida(valor):
    # Sem strip, sem casefold: quem decide um valor novo é o dono, não o script.
    assert m.classificar(valor) == ("desconhecido", None)


def test_treze_secoes_e_totais_da_spec():
    assert len(set(m.SECAO_POR_CATEGORIA.values())) == 13
    assert set(m.SECAO_POR_CATEGORIA.values()) == set(m.ESPERADO_DEPOIS)
    assert sum(m.ESPERADO_DEPOIS.values()) == m.ESPERADO_TOTAL == 1123
    assert m.ESPERADO_RAIZ_REMOVIDAS == 1119
    assert m.ESPERADO_AVULSOS_GLTM == 1


def test_nome_de_subtag_sem_virgula():
    # routes/tags.ts recusa vírgula: o GROUP_CONCAT das tags é separado por vírgula.
    assert all("," not in nome for _, nome in m.SUBTAGS)


def test_subtags_sao_as_13_de_coletanea_mais_gltm_de_avulsos():
    assert len(m.SUBTAGS) == 14
    assert m.SUBTAGS[-1] == ("Avulsos", "GLTM")
    assert all(pai == "Coletânea" for pai, _ in m.SUBTAGS[:-1])


def test_manuais_sao_os_8_ids_da_spec():
    assert [x["id"] for x in m.MANUAIS] == [
        "90ad7fd8-46d5-4121-a071-96b4fee42196",
        "b43a21e7-3c12-4a96-b298-e2bd908db2d9",
        "3c366df7-52c9-4d64-9ffb-03e6d4699e3e",
        "ffcb930d-b34d-4236-a389-3c7b0e198567",
        "1f468959-3e72-4000-bd54-1b9c682882db",
        "70845455-7bb1-455a-990b-c6082b75261f",
        "bbd5f528-1622-4346-a3d7-898223f7292b",
        "2b309bf1-50a0-48fc-8607-8ccce0031500",
    ]
    alvo = {(x["pai"], x["subtag"]) for x in m.MANUAIS}
    assert alvo <= set(m.SUBTAGS)
    gltm = m.MANUAIS[-1]
    assert (gltm["short_id"], gltm["tags_hoje"], gltm["pai"], gltm["subtag"]) == ("11e", frozenset({"GLTM"}), "Avulsos", "GLTM")


def test_rotulos_usam_o_ponto_medio_da_api():
    assert m.SEP_ROTULO == " · "
    assert "Diversos · weider" in m.MANUAIS[6]["tags_hoje"]
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
cd "/Volumes/SSD 2TB SD/dev/coldigom/.claude/worktrees/secoes-coletanea/scripts/validate-acervo" && python3 -m pytest tests/test_secoes_coletanea_mapa.py -q
```

Esperado: erro de coleta com `ModuleNotFoundError: No module named 'core.secoes_coletanea_mapa'`.

- [ ] **Step 3: Implementar**

`scripts/validate-acervo/core/secoes_coletanea_mapa.py`:

```python
# core/secoes_coletanea_mapa.py
"""O mapeamento de `praises.category` para subtags (spec 2026-09-24-secoes-
coletanea-subtags-design §2). Só constantes e uma função pura.

As strings são copiadas da spec byte a byte, inclusive a grafia errada
«Morte, Ressureição e Salvação» — é o valor que está no D1. Nenhuma
normalização (strip, casefold, NFC) é aplicada na comparação: valor que não
bate exatamente é "desconhecido" e a trava (a) aborta. Ninguém adivinha o
mapeamento (spec §7).
"""
from __future__ import annotations

RAIZ_COLETANEA = "Coletânea"
RAIZ_AVULSOS = "Avulsos"
SEP_ROTULO = " · "   # TAG_LABEL_SQL da API: `pai · filho`

# §2.1 — valor de `category` → nome da subtag de Coletânea.
SECAO_POR_CATEGORIA: dict[str, str] = {
    "Clamor": "Clamor",
    "Consolo e Encorajamento": "Consolo e Encorajamento",
    "Contra-Capa": "Contra-Capa",
    "Corinhos": "Corinhos",
    "Crianças e Adolescentes": "Crianças e Adolescentes",
    "Dedicação": "Dedicação",
    "Grupo de Louvor": "Grupo de Louvor",
    "Invocação e Comunhão": "Invocação e Comunhão",
    "Louvor": "Louvor",
    "Morte, Ressureição e Salvação": "Morte Ressurreição e Salvação",
    "Morte, Ressurreição e Salvação": "Morte Ressurreição e Salvação",
    "Salmos de Louvor": "Salmos de Louvor",
    "Santificação e Derramamento": "Santificação e Derramamento do Espírito Santo",
    "Santificação e Derramamento do Espírito Santo": "Santificação e Derramamento do Espírito Santo",
    "Volta de Jesus e Eternidade": "Volta de Jesus e Eternidade",
}

# §2.1, coluna «Praises depois» — o relatório compara, não aborta.
ESPERADO_DEPOIS: dict[str, int] = {
    "Clamor": 78,
    "Consolo e Encorajamento": 97,
    "Contra-Capa": 1,
    "Corinhos": 56,
    "Crianças e Adolescentes": 241,
    "Dedicação": 113,
    "Grupo de Louvor": 96,
    "Invocação e Comunhão": 39,
    "Louvor": 85,
    "Morte Ressurreição e Salvação": 96,
    "Salmos de Louvor": 20,
    "Santificação e Derramamento do Espírito Santo": 105,
    "Volta de Jesus e Eternidade": 96,
}
ESPERADO_TOTAL = 1123
ESPERADO_RAIZ_REMOVIDAS = 1119   # §5.1.6 — ligações diretas com Coletânea removidas
ESPERADO_AVULSOS_GLTM = 1        # §2.3 — só «Tu és Maravilhoso» (11e)

# §2.2 e §2.3 — valores de coleção: não geram tag e não mudam as tags.
CATEGORIAS_COLECAO: frozenset[str] = frozenset({
    "Avulso",
    "Avulsos",
    "Avulso Cias",
    "Avulsos das Senhoras",
})

# §2.1 — os 4 que têm seção e não têm a tag Coletânea (número, nome).
ENTRAM_NA_COLETANEA: tuple[tuple[str, str], ...] = (
    ("", "Alvo Mais Que a Neve"),
    ("060", "Tudo está pronto"),
    ("255", "Meu Coração Engrandece - ARR OPCIONAL"),
    ("609", "Senhor, Meu Deus, Quando Eu Maravilhado (Adaptação TEF 2024)"),
)

# §2.3 — casos manuais, por praise.id (aprovados pelo dono em 2026-09-24).
# `tags_hoje` são rótulos (`pai · filho` para subtag), como na tabela.
MANUAIS: tuple[dict, ...] = (
    {"id": "90ad7fd8-46d5-4121-a071-96b4fee42196", "short_id": "3b4", "numero": "046",
     "nome": "Ao Sentir o teu Perdão", "tags_hoje": frozenset({"Coletânea"}),
     "pai": RAIZ_COLETANEA, "subtag": "Clamor"},
    {"id": "b43a21e7-3c12-4a96-b298-e2bd908db2d9", "short_id": "488", "numero": "046",
     "nome": "Ao Sentir o teu Perdão", "tags_hoje": frozenset({"Coletânea", "PES"}),
     "pai": RAIZ_COLETANEA, "subtag": "Clamor"},
    {"id": "3c366df7-52c9-4d64-9ffb-03e6d4699e3e", "short_id": "186", "numero": "047",
     "nome": "Tenho no meu coração", "tags_hoje": frozenset({"CIAs", "Coletânea"}),
     "pai": RAIZ_COLETANEA, "subtag": "Crianças e Adolescentes"},
    {"id": "ffcb930d-b34d-4236-a389-3c7b0e198567", "short_id": "679", "numero": "99",
     "nome": "Um dia Jesus achou - me", "tags_hoje": frozenset({"Avulsos", "Coletânea"}),
     "pai": RAIZ_COLETANEA, "subtag": "Dedicação"},
    {"id": "1f468959-3e72-4000-bd54-1b9c682882db", "short_id": "806", "numero": "505",
     "nome": "Os seus cabelos brancos", "tags_hoje": frozenset({"Coletânea"}),
     "pai": RAIZ_COLETANEA, "subtag": "Volta de Jesus e Eternidade"},
    {"id": "70845455-7bb1-455a-990b-c6082b75261f", "short_id": "807", "numero": "506",
     "nome": "Tu Que Estás Assentado", "tags_hoje": frozenset({"Coletânea"}),
     "pai": RAIZ_COLETANEA, "subtag": "Volta de Jesus e Eternidade"},
    {"id": "bbd5f528-1622-4346-a3d7-898223f7292b", "short_id": "68b", "numero": "566",
     "nome": "O Senhor é meu Pastor (Maranata, Jesus vem)",
     "tags_hoje": frozenset({"Avulsos", "Coletânea", "Diversos · weider"}),
     "pai": RAIZ_COLETANEA, "subtag": "Volta de Jesus e Eternidade"},
    {"id": "2b309bf1-50a0-48fc-8607-8ccce0031500", "short_id": "11e", "numero": "",
     "nome": "Tu és Maravilhoso", "tags_hoje": frozenset({"GLTM"}),
     "pai": RAIZ_AVULSOS, "subtag": "GLTM"},
)

# As 14 subtags que o script garante: as 13 de §2.1 sob Coletânea e GLTM sob
# Avulsos (§5.1.3). Ordem estável = ordem do relatório.
SUBTAGS: tuple[tuple[str, str], ...] = tuple(
    (RAIZ_COLETANEA, nome) for nome in ESPERADO_DEPOIS
) + ((RAIZ_AVULSOS, "GLTM"),)


def classificar(category: str | None) -> tuple[str, str | None]:
    """('secao', subtag) | ('colecao', None) | ('vazio', None) | ('desconhecido', None).

    Vazio é NULL ou só espaço: é o que os 875 praises sem categoria têm. Todo o
    resto compara byte a byte com as tabelas acima.
    """
    if category is None or category.strip() == "":
        return "vazio", None
    if category in SECAO_POR_CATEGORIA:
        return "secao", SECAO_POR_CATEGORIA[category]
    if category in CATEGORIAS_COLECAO:
        return "colecao", None
    return "desconhecido", None
```

- [ ] **Step 4: Rodar e ver passar**

```bash
cd "/Volumes/SSD 2TB SD/dev/coldigom/.claude/worktrees/secoes-coletanea/scripts/validate-acervo" && python3 -m pytest tests/test_secoes_coletanea_mapa.py -q
```

Esperado: `24 passed`.

- [ ] **Step 5: Commit**

Na raiz do worktree:

```bash
git add scripts/validate-acervo/core/secoes_coletanea_mapa.py scripts/validate-acervo/tests/test_secoes_coletanea_mapa.py
git commit -m "feat(acervo): mapeamento das seções da Coletânea para subtags

Constantes de §2.1–2.3 da spec secoes-coletanea-subtags, copiadas byte a
byte, e classificar(): seção, coleção, vazio ou desconhecido.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Plano e travas (a)(b)(c)

**Files:**
- Create: `scripts/validate-acervo/core/secoes_coletanea.py`: cabeçalho, imports, `Trava`, `Ligacao`, `Plano`, `rotulos`, `montar_plano`.
- Create: `scripts/validate-acervo/tests/test_secoes_coletanea.py`: fixture `mundo` e a seção «plano e travas».

**Interfaces:**
- Consumes: `core.secoes_coletanea_mapa` (Task 1), `core.snapshot.conectar(db: str) -> sqlite3.Connection` (com `row_factory = sqlite3.Row`).
- Produces:
  - `class Trava(Exception)`, com `.problemas: list[str]`; cada problema começa com `(a)`, `(b)` ou `(c)`;
  - `@dataclass(frozen=True) Ligacao(praise_id, pai, subtag, origem, category, tags_snapshot=(), inserir=True, remover_raiz=False)`;
  - `@dataclass Plano(raizes, subtags, ligacoes, ja_ligados, entram_na_coletanea)`;
  - `rotulos(conn) -> dict[str, str]`;
  - `montar_plano(conn) -> Plano`, que levanta `Trava`.
  - O módulo já importa `query`, `run_sql_files`, `write_sql_chunks`, `copiar_execucao` e `_erro_texto`, que as Tasks 5–6 usam. Os testes das Tasks 5–7 fazem monkeypatch em `core.secoes_coletanea.query` e `.run_sql_files`.

- [ ] **Step 1: Escrever o teste que falha**

Criar `scripts/validate-acervo/tests/test_secoes_coletanea.py`. As Tasks 3–7 acrescentam seções ao fim dele.

```python
# tests/test_secoes_coletanea.py
from __future__ import annotations

import json
import os
import sqlite3
import subprocess
import unicodedata

import pytest

from core import secoes_coletanea as sc
from core import secoes_coletanea_mapa as mapa
from core.snapshot import conectar

ESQUEMA = """
    CREATE TABLE praises (id TEXT PRIMARY KEY, name TEXT NOT NULL, number TEXT, author TEXT,
        rhythm TEXT, tonality TEXT, category TEXT, lyrics TEXT, group_id TEXT, short_id TEXT,
        created_at TEXT DEFAULT (datetime('now')), updated_at TEXT DEFAULT (datetime('now')));
    CREATE TABLE tags (id TEXT PRIMARY KEY, name TEXT NOT NULL, parent_id TEXT,
        FOREIGN KEY (parent_id) REFERENCES tags(id) ON DELETE RESTRICT);
    CREATE UNIQUE INDEX idx_tags_root_name ON tags(name) WHERE parent_id IS NULL;
    CREATE UNIQUE INDEX idx_tags_child_name ON tags(parent_id, name) WHERE parent_id IS NOT NULL;
    CREATE TABLE praise_tags (praise_id TEXT NOT NULL, tag_id TEXT NOT NULL,
        PRIMARY KEY (praise_id, tag_id),
        FOREIGN KEY (praise_id) REFERENCES praises(id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE);
"""

TAG_ID = {"Coletânea": "t-col", "Avulsos": "t-avu", "GLTM": "t-gltm", "PES": "t-pes",
          "CIAs": "t-cias", "Diversos": "t-div", "Diversos · weider": "t-weider"}

# (id, número, nome, category, rótulos das tags)
LOUVORES = [
    ("c1", "001", "Clamor A", "Clamor", ["Coletânea"]),
    ("c2", "002", "Morte grafia errada", "Morte, Ressureição e Salvação", ["Coletânea"]),
    ("c3", "003", "Morte grafia certa", "Morte, Ressurreição e Salvação", ["Coletânea", "Avulsos"]),
    ("c4", "004", "Santificação curta", "Santificação e Derramamento", ["Coletânea", "PES"]),
    ("e1", "060", "Tudo está pronto", "Louvor", []),
    ("e2", "", "Alvo Mais Que a Neve", "Dedicação", ["Avulsos"]),
    ("a1", "", "Avulso qualquer", "Avulsos", ["Avulsos"]),
    ("v1", "", "Sem categoria", "", []),
    ("n1", "", "Categoria nula", None, ["PES"]),
]


def _povoar(caminho: str) -> sqlite3.Connection:
    conn = conectar(caminho)
    conn.executescript(ESQUEMA)
    conn.execute("PRAGMA foreign_keys = ON")   # o D1 roda com FK ligada
    for nome, tid in TAG_ID.items():
        if " · " in nome:
            continue
        conn.execute("INSERT INTO tags VALUES (?, ?, NULL)", (tid, nome))
    conn.execute("INSERT INTO tags VALUES ('t-weider', 'weider', 't-div')")
    for pid, numero, nome, cat, tags in LOUVORES:
        conn.execute("INSERT INTO praises (id, number, name, category) VALUES (?, ?, ?, ?)", (pid, numero, nome, cat))
        for t in tags:
            conn.execute("INSERT INTO praise_tags VALUES (?, ?)", (pid, TAG_ID[t]))
    for x in mapa.MANUAIS:
        cat = "Avulsos das Senhoras" if x["short_id"] == "11e" else ""
        conn.execute("INSERT INTO praises (id, number, name, category, short_id) VALUES (?, ?, ?, ?, ?)",
                     (x["id"], x["numero"], x["nome"], cat, x["short_id"]))
        for t in x["tags_hoje"]:
            conn.execute("INSERT INTO praise_tags VALUES (?, ?)", (x["id"], TAG_ID[t]))
    conn.commit()
    return conn


@pytest.fixture
def mundo(tmp_path):
    """Snapshot e produção em arquivos separados: é o intervalo entre os dois
    que as guardas protegem (ver _mundo_dois_bancos em test_apply.py)."""
    return {"snap": _povoar(str(tmp_path / "snap.sqlite")),
            "prod": _povoar(str(tmp_path / "prod.sqlite")),
            "tmp": tmp_path}


def _ligacoes(conn) -> set:
    return {(r["praise_id"], r["tag_id"]) for r in conn.execute("SELECT praise_id, tag_id FROM praise_tags")}


def _tags(conn) -> set:
    return {(r["id"], r["name"], r["parent_id"]) for r in conn.execute("SELECT id, name, parent_id FROM tags")}


def _rotulos_de(conn, pid) -> set:
    rot = sc.rotulos(conn)
    return {rot[r["tag_id"]] for r in conn.execute("SELECT tag_id FROM praise_tags WHERE praise_id = ?", (pid,))}


# --- plano e travas -----------------------------------------------------------------

def test_plano_mapeia_as_grafias_e_liga_qualquer_tag(mundo):
    plano = sc.montar_plano(mundo["snap"])
    por_id = {lig.praise_id: lig for lig in plano.ligacoes}
    assert (por_id["c1"].subtag, por_id["c1"].category, por_id["c1"].remover_raiz) == ("Clamor", "Clamor", True)
    assert por_id["c2"].subtag == por_id["c3"].subtag == "Morte Ressurreição e Salvação"
    assert por_id["c4"].subtag == "Santificação e Derramamento do Espírito Santo"
    assert all(por_id[p].pai == "Coletânea" and por_id[p].origem == "categoria" for p in ("c1", "c2", "c3", "c4"))
    assert not {"a1", "v1", "n1"} & set(por_id)          # coleção e vazio não geram ligação


def test_plano_lista_quem_entra_na_coletanea_pela_subtag(mundo):
    plano = sc.montar_plano(mundo["snap"])
    assert sorted((e["number"], e["name"], e["subtag"]) for e in plano.entram_na_coletanea) == [
        ("", "Alvo Mais Que a Neve", "Dedicação"), ("060", "Tudo está pronto", "Louvor")]
    por_id = {lig.praise_id: lig for lig in plano.ligacoes}
    assert por_id["e1"].remover_raiz is False and por_id["e1"].inserir is True


def test_plano_manuais_e_gltm_sob_avulsos(mundo):
    plano = sc.montar_plano(mundo["snap"])
    manuais = [lig for lig in plano.ligacoes if lig.origem == "manual"]
    assert [lig.praise_id for lig in manuais] == [x["id"] for x in mapa.MANUAIS]
    gltm = manuais[-1]
    assert (gltm.pai, gltm.subtag, gltm.remover_raiz, gltm.tags_snapshot) == ("Avulsos", "GLTM", False, ("t-gltm",))
    assert gltm.category == "Avulsos das Senhoras"
    weider = manuais[6]
    assert (weider.subtag, weider.remover_raiz, weider.tags_snapshot) == (
        "Volta de Jesus e Eternidade", True, ("t-avu", "t-col", "t-weider"))


def test_plano_marca_subtag_existente_e_ligacao_que_ja_existe(mundo):
    snap = mundo["snap"]
    snap.execute("INSERT INTO tags VALUES ('t-clamor', 'Clamor', 't-col')")
    snap.execute("INSERT INTO praise_tags VALUES ('c1', 't-clamor')")
    snap.commit()
    plano = sc.montar_plano(snap)
    assert plano.subtags[("Coletânea", "Clamor")] == "t-clamor"
    assert plano.subtags[("Coletânea", "Louvor")] is None
    assert plano.ja_ligados[("Coletânea", "Clamor")] == {"c1"}
    c1 = next(lig for lig in plano.ligacoes if lig.praise_id == "c1")
    assert c1.inserir is False and c1.remover_raiz is True


def test_quem_ja_esta_numa_subtag_da_coletanea_nao_entra_de_novo(mundo):
    snap = mundo["snap"]
    snap.execute("INSERT INTO tags VALUES ('t-louvor', 'Louvor', 't-col')")
    snap.execute("INSERT INTO praise_tags VALUES ('e1', 't-louvor')")
    snap.commit()
    plano = sc.montar_plano(snap)
    assert [e["id"] for e in plano.entram_na_coletanea] == ["e2"]


def test_trava_a_category_desconhecida(mundo):
    mundo["snap"].execute("UPDATE praises SET category = 'Dm' WHERE id = 'v1'")
    with pytest.raises(sc.Trava) as e:
        sc.montar_plano(mundo["snap"])
    assert len(e.value.problemas) == 1
    assert e.value.problemas[0].startswith("(a)") and "'Dm'" in e.value.problemas[0] and "v1" in e.value.problemas[0]


def test_trava_b_raiz_coletanea_sem_secao(mundo):
    mundo["snap"].execute("INSERT INTO praise_tags VALUES ('a1', 't-col')")   # category 'Avulsos' não dá seção
    with pytest.raises(sc.Trava) as e:
        sc.montar_plano(mundo["snap"])
    assert [p[:3] for p in e.value.problemas] == ["(b)"] and "a1" in e.value.problemas[0]


def test_trava_c_manual_ausente_ou_com_tags_diferentes(mundo):
    snap = mundo["snap"]
    snap.execute("DELETE FROM praises WHERE id = ?", (mapa.MANUAIS[0]["id"],))
    snap.execute("INSERT INTO praise_tags VALUES (?, 't-pes')", (mapa.MANUAIS[4]["id"],))
    with pytest.raises(sc.Trava) as e:
        sc.montar_plano(snap)
    assert len(e.value.problemas) == 2
    assert mapa.MANUAIS[0]["id"] in e.value.problemas[0] and "não existe" in e.value.problemas[0]
    assert mapa.MANUAIS[4]["id"] in e.value.problemas[1] and "PES" in e.value.problemas[1]


def test_trava_c_manual_com_secao_mapeada(mundo):
    mundo["snap"].execute("UPDATE praises SET category = 'Clamor' WHERE id = ?", (mapa.MANUAIS[1]["id"],))
    with pytest.raises(sc.Trava) as e:
        sc.montar_plano(mundo["snap"])
    assert e.value.problemas[0].startswith("(c)") and "seção mapeada" in e.value.problemas[0]


def test_trava_c_aceita_manual_ja_migrado(mundo):
    # A retomada (spec §7) roda o script de novo sobre um acervo parcialmente migrado.
    snap = mundo["snap"]
    x = mapa.MANUAIS[0]
    snap.execute("INSERT INTO tags VALUES ('t-clamor', 'Clamor', 't-col')")
    snap.execute("DELETE FROM praise_tags WHERE praise_id = ? AND tag_id = 't-col'", (x["id"],))
    snap.execute("INSERT INTO praise_tags VALUES (?, 't-clamor')", (x["id"],))
    snap.commit()
    lig = next(lig for lig in sc.montar_plano(snap).ligacoes if lig.praise_id == x["id"])
    assert (lig.inserir, lig.remover_raiz) == (False, False)
    # meio caminho: subtag ligada e a raiz ainda lá (o DELETE caiu num arquivo posterior)
    y = mapa.MANUAIS[1]
    snap.execute("INSERT INTO praise_tags VALUES (?, 't-clamor')", (y["id"],))
    snap.commit()
    lig = next(lig for lig in sc.montar_plano(snap).ligacoes if lig.praise_id == y["id"])
    assert (lig.inserir, lig.remover_raiz) == (False, True)


def test_travas_juntas_e_nenhuma_escrita(mundo):
    snap = mundo["snap"]
    snap.execute("UPDATE praises SET category = 'Dm' WHERE id = 'v1'")
    snap.execute("INSERT INTO praise_tags VALUES ('a1', 't-col')")
    snap.execute("DELETE FROM praises WHERE id = ?", (mapa.MANUAIS[3]["id"],))
    with pytest.raises(sc.Trava) as e:
        sc.montar_plano(snap)
    assert sorted(p[:3] for p in e.value.problemas) == ["(a)", "(b)", "(c)"]


def test_raiz_ausente_trava(mundo):
    mundo["snap"].execute("UPDATE tags SET name = 'Coletanea' WHERE id = 't-col'")
    with pytest.raises(sc.Trava, match="Coletânea"):
        sc.montar_plano(mundo["snap"])


```

- [ ] **Step 2: Rodar e ver falhar**

```bash
cd "/Volumes/SSD 2TB SD/dev/coldigom/.claude/worktrees/secoes-coletanea/scripts/validate-acervo" && python3 -m pytest tests/test_secoes_coletanea.py -q
```

Esperado: erro de coleta com `ModuleNotFoundError: No module named 'core.secoes_coletanea'`.

- [ ] **Step 3: Implementar**

Criar `scripts/validate-acervo/core/secoes_coletanea.py`. As Tasks 3–7 acrescentam seções ao fim dele.

```python
# core/secoes_coletanea.py
"""Seções da Coletânea viram subtags (spec 2026-09-24-secoes-coletanea-subtags-design §5).

    python3 -m core.secoes_coletanea                          # ensaio: travas, relatório, SQL — nada é escrito
    python3 -m core.secoes_coletanea --execute                # grava em produção
    python3 -m core.secoes_coletanea --undo <run_id>          # simula o undo
    python3 -m core.secoes_coletanea --undo <run_id> --execute

Comando próprio, e não detector + core.apply, pelo mesmo motivo do
core.plpcg_apply: o core.apply só conhece merge_praise e set_praise_field,
lê um finding por alvo e confere a pós-condição com uma consulta por finding
(seriam ~2240), e não sabe criar tag. Daqui só se reusa o que é do core:
snapshot (core.snapshot.conectar), SQL em lotes (core.d1.write_sql_chunks +
run_sql_files), leitura pontual (core.d1.query), o log .jsonl com a cópia em
gabaritos/ (core.plpcg_apply.copiar_execucao) e o texto de erro do wrangler.

As camadas são puras até a execução: montar_plano lê só o snapshot;
sql_plano só formata; executar e desfazer são os únicos que falam com o D1.
"""
from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
import time
import unicodedata
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone

from core import secoes_coletanea_mapa as mapa
from core.d1 import query, run_sql_files, sql_str, write_sql_chunks
from core.paths import OUT, PKG, SNAPSHOT_DB
from core.plpcg_apply import _erro_texto, copiar_execucao
from core.snapshot import conectar

LOG_PADRAO = os.path.join(OUT, "secoes_coletanea_log.jsonl")
OUT_PADRAO = os.path.join(OUT, "secoes_coletanea")
EXECUCAO_PADRAO = os.path.join(PKG, "gabaritos", "secoes_coletanea", "execucao")
LOTE_SQL = 300  # statements por arquivo .sql — cada arquivo é um batch atômico do D1


class Trava(Exception):
    """§5.1.2: aborta antes de qualquer escrita. Carrega TODOS os problemas,
    para o dono corrigir de uma vez em vez de descobrir um por rodada."""

    def __init__(self, problemas: list[str]):
        super().__init__(f"{len(problemas)} problema(s): " + "; ".join(problemas[:3]))
        self.problemas = problemas


@dataclass(frozen=True)
class Ligacao:
    praise_id: str
    pai: str                     # nome da raiz: "Coletânea" ou "Avulsos"
    subtag: str                  # nome da subtag
    origem: str                  # "categoria" | "manual"
    category: str | None         # valor lido no snapshot: a guarda do INSERT
    tags_snapshot: tuple = ()    # ids das tags do praise no snapshot, ordenados (guarda dos manuais)
    inserir: bool = True         # False: o snapshot já tem a ligação com a subtag
    remover_raiz: bool = False   # True: o snapshot tem a ligação direta com Coletânea


@dataclass
class Plano:
    raizes: dict                 # nome da raiz -> id
    subtags: dict                # (pai, nome) -> id no snapshot, ou None (a criar)
    ligacoes: list               # [Ligacao]
    ja_ligados: dict             # (pai, nome) -> set de praise_id já ligados no snapshot
    entram_na_coletanea: list    # [{id, number, name, subtag}]


def rotulos(conn: sqlite3.Connection) -> dict[str, str]:
    """tag id -> rótulo como a API mostra: `nome` na raiz, `pai · nome` na subtag."""
    tags = {r["id"]: (r["name"], r["parent_id"]) for r in conn.execute("SELECT id, name, parent_id FROM tags")}
    saida = {}
    for tid, (nome, pai) in tags.items():
        saida[tid] = nome if pai is None or pai not in tags else f"{tags[pai][0]}{mapa.SEP_ROTULO}{nome}"
    return saida


def _descricao(p: dict) -> str:
    numero = (p.get("number") or "").strip()
    return f"{p['id']} {numero + ' ' if numero else ''}«{p['name']}»"


def montar_plano(conn: sqlite3.Connection) -> Plano:
    """Lê o snapshot e decide cada ligação. Levanta Trava com as três travas
    de §5.1.2 — nada de SQL é gerado antes disso."""
    raizes: dict[str, str] = {}
    for nome in (mapa.RAIZ_COLETANEA, mapa.RAIZ_AVULSOS):
        r = conn.execute("SELECT id FROM tags WHERE name = ? AND parent_id IS NULL", (nome,)).fetchone()
        if r is None:
            raise Trava([f"a tag raiz {nome!r} não existe no snapshot"])
        raizes[nome] = r["id"]
    col = raizes[mapa.RAIZ_COLETANEA]

    subtags: dict[tuple, str | None] = {}
    for pai, nome in mapa.SUBTAGS:
        r = conn.execute("SELECT id FROM tags WHERE parent_id = ? AND name = ?", (raizes[pai], nome)).fetchone()
        subtags[(pai, nome)] = r["id"] if r else None
    filhos_col = {r["id"] for r in conn.execute("SELECT id FROM tags WHERE parent_id = ?", (col,))}

    tags_de: dict[str, set] = {}
    for r in conn.execute("SELECT praise_id, tag_id FROM praise_tags"):
        tags_de.setdefault(r["praise_id"], set()).add(r["tag_id"])
    ja_ligados = {
        chave: {pid for pid, ts in tags_de.items() if tid in ts} if tid else set()
        for chave, tid in subtags.items()
    }
    rot = rotulos(conn)
    praises = {r["id"]: dict(r) for r in conn.execute("SELECT * FROM praises")}
    manuais = {x["id"]: x for x in mapa.MANUAIS}

    problemas: list[str] = []
    ligacoes: list[Ligacao] = []
    entram: list[dict] = []

    for pid in sorted(praises):
        p = praises[pid]
        tipo, subtag = mapa.classificar(p["category"])
        tags = tags_de.get(pid, set())
        if tipo == "desconhecido":
            problemas.append(f"(a) category fora de §2.1/§2.2 {p['category']!r}: {_descricao(p)}")
            continue
        if pid in manuais:
            if tipo == "secao":
                problemas.append(f"(c) caso manual com seção mapeada {p['category']!r}: {_descricao(p)}")
            continue
        if tipo == "secao":
            chave = (mapa.RAIZ_COLETANEA, subtag)
            ligacoes.append(Ligacao(
                praise_id=pid, pai=chave[0], subtag=chave[1], origem="categoria",
                category=p["category"], inserir=pid not in ja_ligados[chave], remover_raiz=col in tags,
            ))
            if col not in tags and not (tags & filhos_col):
                entram.append({"id": pid, "number": (p.get("number") or "").strip(),
                               "name": p["name"], "subtag": subtag})
        elif col in tags:
            problemas.append(f"(b) tem a raiz Coletânea e a category {p['category']!r} não dá seção: {_descricao(p)}")

    for x in mapa.MANUAIS:
        pid = x["id"]
        p = praises.get(pid)
        if p is None:
            problemas.append(f"(c) caso manual {pid} ({x['short_id']} «{x['nome']}») não existe no snapshot")
            continue
        chave = (x["pai"], x["subtag"])
        tags = tags_de.get(pid, set())
        hoje = frozenset(rot.get(t, t) for t in tags)
        alvo = f"{x['pai']}{mapa.SEP_ROTULO}{x['subtag']}"
        # Aceita a tabela da spec e os dois estados de uma retomada: subtag já
        # ligada com e sem a raiz Coletânea. Sem isso, rodar de novo depois de
        # um --execute parcial (spec §7) abortaria na trava (c).
        aceitos = (x["tags_hoje"], x["tags_hoje"] | {alvo},
                   (x["tags_hoje"] - {mapa.RAIZ_COLETANEA}) | {alvo})
        if hoje not in aceitos:
            problemas.append(f"(c) caso manual {_descricao(p)}: tags {sorted(hoje)} ≠ {sorted(x['tags_hoje'])} da spec")
            continue
        ligacoes.append(Ligacao(
            praise_id=pid, pai=chave[0], subtag=chave[1], origem="manual", category=p["category"],
            tags_snapshot=tuple(sorted(tags)), inserir=pid not in ja_ligados[chave], remover_raiz=col in tags,
        ))

    if problemas:
        raise Trava(problemas)
    return Plano(raizes=raizes, subtags=subtags, ligacoes=ligacoes,
                 ja_ligados=ja_ligados, entram_na_coletanea=entram)


```

- [ ] **Step 4: Rodar e ver passar**

```bash
cd "/Volumes/SSD 2TB SD/dev/coldigom/.claude/worktrees/secoes-coletanea/scripts/validate-acervo" && python3 -m pytest tests/test_secoes_coletanea.py -q
```

Esperado: `12 passed`.

- [ ] **Step 5: Commit**

```bash
git add scripts/validate-acervo/core/secoes_coletanea.py scripts/validate-acervo/tests/test_secoes_coletanea.py
git commit -m "feat(acervo): plano das subtags da Coletânea com as travas (a)(b)(c)

montar_plano lê só o snapshot e junta todos os problemas numa Trava antes de
qualquer SQL. A trava (c) aceita o estado de retomada do caso manual.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: SQL com guardas otimistas e reaproveitamento de subtag

**Files:**
- Modify: `scripts/validate-acervo/core/secoes_coletanea.py`: acrescentar ao fim a seção `# --- SQL ---`.
- Modify: `scripts/validate-acervo/tests/test_secoes_coletanea.py`: acrescentar ao fim a seção `# --- SQL ---`.

**Interfaces:**
- Consumes: `Plano`, `Ligacao` e `montar_plano` (Task 2); `core.d1.sql_str(s: str | None) -> str`, em que `None` vira `NULL`.
- Produces:
  - `resolver_subtags(plano, tags: list[dict], novo_id=...) -> tuple[dict[(pai, nome), id], list[{"id","name","parent_id"}]]`;
  - `sql_plano(plano, ids, novas) -> list[str]`, na ordem: `INSERT INTO tags`, depois `INSERT OR IGNORE INTO praise_tags … SELECT … WHERE`, depois `DELETE FROM praise_tags … AND EXISTS (subtag)`. Um statement por linha, que é o que `write_sql_chunks` espera.

- [ ] **Step 1: Escrever o teste que falha**

Acrescentar ao fim de `tests/test_secoes_coletanea.py`:

```python
# --- SQL ---------------------------------------------------------------------------

def _ids_fixos():
    n = iter(range(1, 100))
    return lambda: f"novo-{next(n):02d}"


def _aplicar(conn, stmts):
    """Um batch atômico, como o wrangler executa cada arquivo."""
    try:
        conn.executescript("BEGIN;\n" + "\n".join(stmts) + "\nCOMMIT;")
    except sqlite3.Error:
        conn.rollback()
        raise


def _sql(mundo, tags_de=None):
    plano = sc.montar_plano(mundo["snap"])
    tags = [dict(r) for r in (tags_de or mundo["snap"]).execute("SELECT id, name, parent_id FROM tags")]
    ids, novas = sc.resolver_subtags(plano, tags, _ids_fixos())
    return plano, ids, novas, sc.sql_plano(plano, ids, novas)


def test_sql_cria_liga_e_depois_desliga(mundo):
    plano, ids, novas, stmts = _sql(mundo)
    assert len(novas) == 14 and ids[("Avulsos", "GLTM")] == "novo-14"
    tipos = [s.split(" (")[0].split(" SELECT")[0] for s in stmts]
    n_lig = sum(1 for lig in plano.ligacoes if lig.inserir)
    n_des = sum(1 for lig in plano.ligacoes if lig.remover_raiz)
    assert tipos == (["INSERT INTO tags"] * 14 + ["INSERT OR IGNORE INTO praise_tags"] * n_lig
                     + [s for s in tipos if s.startswith("DELETE")])
    assert sum(1 for s in stmts if s.startswith("DELETE FROM praise_tags")) == n_des
    assert stmts[0] == "INSERT INTO tags (id, name, parent_id) VALUES ('novo-01', 'Clamor', 't-col');"


def test_sql_em_producao_faz_a_migracao(mundo):
    prod = mundo["prod"]
    _, ids, _, stmts = _sql(mundo)
    _aplicar(prod, stmts)
    rot = sc.rotulos(prod)
    assert _rotulos_de(prod, "c1") == {"Coletânea · Clamor"}
    assert _rotulos_de(prod, "c3") == {"Coletânea · Morte Ressurreição e Salvação", "Avulsos"}
    assert _rotulos_de(prod, "e2") == {"Coletânea · Dedicação", "Avulsos"}
    assert _rotulos_de(prod, "a1") == {"Avulsos"} and _rotulos_de(prod, "v1") == set()
    assert _rotulos_de(prod, mapa.MANUAIS[-1]["id"]) == {"GLTM", "Avulsos · GLTM"}      # a raiz GLTM fica
    assert _rotulos_de(prod, mapa.MANUAIS[6]["id"]) == {
        "Avulsos", "Diversos · weider", "Coletânea · Volta de Jesus e Eternidade"}
    diretas = prod.execute("SELECT COUNT(*) FROM praise_tags WHERE tag_id = 't-col'").fetchone()[0]
    assert diretas == 0 and rot["t-col"] == "Coletânea"


def test_guarda_category_mudou_depois_do_snapshot(mundo):
    prod = mundo["prod"]
    prod.execute("UPDATE praises SET category = 'Louvor' WHERE id = 'c1'")
    prod.commit()
    _, _, _, stmts = _sql(mundo)
    _aplicar(prod, stmts)
    assert _rotulos_de(prod, "c1") == {"Coletânea"}      # não ligou E não saiu da Coletânea


def test_guarda_manual_com_tags_mudadas(mundo):
    prod = mundo["prod"]
    x = mapa.MANUAIS[0]
    prod.execute("INSERT INTO praise_tags VALUES (?, 't-pes')", (x["id"],))
    prod.commit()
    _, _, _, stmts = _sql(mundo)
    _aplicar(prod, stmts)
    assert _rotulos_de(prod, x["id"]) == {"Coletânea", "PES"}


def test_guarda_praise_apagado_nao_derruba_o_lote(mundo):
    prod = mundo["prod"]
    prod.execute("DELETE FROM praises WHERE id = 'c2'")
    prod.commit()
    _, _, _, stmts = _sql(mundo)
    _aplicar(prod, stmts)                                  # sem IntegrityError de FK
    assert _rotulos_de(prod, "c1") == {"Coletânea · Clamor"}


def test_delete_da_raiz_exige_a_subtag_ligada(mundo):
    prod = mundo["prod"]
    _, _, novas, stmts = _sql(mundo)
    so_tags_e_deletes = [s for s in stmts if not s.startswith("INSERT OR IGNORE")]
    _aplicar(prod, so_tags_e_deletes)
    assert prod.execute("SELECT COUNT(*) FROM praise_tags WHERE tag_id = 't-col'").fetchone()[0] == 11


def test_reaproveita_subtag_existente(mundo):
    for conn in (mundo["snap"], mundo["prod"]):
        conn.execute("INSERT INTO tags VALUES ('t-clamor', 'Clamor', 't-col')")
        conn.commit()
    _, ids, novas, stmts = _sql(mundo)
    assert ids[("Coletânea", "Clamor")] == "t-clamor" and len(novas) == 13
    assert not any("'Clamor'" in s for s in stmts if s.startswith("INSERT INTO tags"))
    _aplicar(mundo["prod"], stmts)
    assert ("c1", "t-clamor") in _ligacoes(mundo["prod"])
    assert mundo["prod"].execute("SELECT COUNT(*) FROM tags WHERE name = 'Clamor'").fetchone()[0] == 1


```

- [ ] **Step 2: Rodar e ver falhar**

```bash
cd "/Volumes/SSD 2TB SD/dev/coldigom/.claude/worktrees/secoes-coletanea/scripts/validate-acervo" && python3 -m pytest tests/test_secoes_coletanea.py -q
```

Esperado: `7 failed, 12 passed`, com `AttributeError: module 'core.secoes_coletanea' has no attribute 'resolver_subtags'`.

- [ ] **Step 3: Implementar**

Acrescentar ao fim de `core/secoes_coletanea.py`:

```python
# --- SQL -------------------------------------------------------------------------

def resolver_subtags(plano: Plano, tags: list[dict], novo_id=lambda: str(uuid.uuid4())) -> tuple[dict, list[dict]]:
    """(pai, nome) -> id de cada uma das 14 subtags, e as que faltam criar.

    `tags` é a tabela inteira: a do snapshot no ensaio, a de produção no
    --execute. Subtag de mesmo nome sob o mesmo pai é reaproveitada (§5.1.3)."""
    existentes = {(t["parent_id"], t["name"]): t["id"] for t in tags if t["parent_id"] is not None}
    ids: dict[tuple, str] = {}
    novas: list[dict] = []
    for pai, nome in mapa.SUBTAGS:
        pai_id = plano.raizes[pai]
        tid = existentes.get((pai_id, nome))
        if tid is None:
            tid = novo_id()
            novas.append({"id": tid, "name": nome, "parent_id": pai_id})
        ids[(pai, nome)] = tid
    return ids, novas


def _sql_criar_subtag(s: dict) -> str:
    return (f"INSERT INTO tags (id, name, parent_id) VALUES "
            f"({sql_str(s['id'])}, {sql_str(s['name'])}, {sql_str(s['parent_id'])});")


def _sql_ligar(lig: Ligacao, tag_id: str) -> str:
    """INSERT guardado: só liga se o praise ainda está como no snapshot.

    Categoria: a mesma do snapshot (`IS` compara NULL também). Manual: além
    disso, exatamente o mesmo conjunto de tags. SELECT ... WHERE em vez de
    VALUES também evita a FK: praise apagado depois do snapshot vira no-op em
    vez de derrubar o arquivo inteiro."""
    p = sql_str(lig.praise_id)
    cond = [f"EXISTS (SELECT 1 FROM praises WHERE id = {p} AND category IS {sql_str(lig.category)})"]
    if lig.origem == "manual":
        n = len(lig.tags_snapshot)
        lista = ", ".join(sql_str(t) for t in lig.tags_snapshot)
        cond.append(f"(SELECT COUNT(*) FROM praise_tags WHERE praise_id = {p}) = {n}")
        cond.append(f"(SELECT COUNT(*) FROM praise_tags WHERE praise_id = {p} AND tag_id IN ({lista})) = {n}")
    return (f"INSERT OR IGNORE INTO praise_tags (praise_id, tag_id) SELECT {p}, {sql_str(tag_id)} "
            f"WHERE {' AND '.join(cond)};")


def _sql_desligar_raiz(lig: Ligacao, raiz_id: str, tag_id: str) -> str:
    """DELETE da raiz Coletânea só quando a subtag já está ligada: se o INSERT
    foi barrado pela guarda, o praise não sai da Coletânea."""
    p = sql_str(lig.praise_id)
    return (f"DELETE FROM praise_tags WHERE praise_id = {p} AND tag_id = {sql_str(raiz_id)} "
            f"AND EXISTS (SELECT 1 FROM praise_tags WHERE praise_id = {p} AND tag_id = {sql_str(tag_id)});")


def sql_plano(plano: Plano, ids: dict, novas: list[dict]) -> list[str]:
    """Ordem fixa: cria subtags, liga, desliga a raiz. Um arquivo que falha
    no meio não deixa praise sem Coletânea: o DELETE exige a subtag ligada."""
    col = plano.raizes[mapa.RAIZ_COLETANEA]
    stmts = [_sql_criar_subtag(s) for s in novas]
    stmts += [_sql_ligar(lig, ids[(lig.pai, lig.subtag)]) for lig in plano.ligacoes if lig.inserir]
    stmts += [_sql_desligar_raiz(lig, col, ids[(lig.pai, lig.subtag)]) for lig in plano.ligacoes if lig.remover_raiz]
    return stmts


```

- [ ] **Step 4: Rodar e ver passar**

```bash
cd "/Volumes/SSD 2TB SD/dev/coldigom/.claude/worktrees/secoes-coletanea/scripts/validate-acervo" && python3 -m pytest tests/test_secoes_coletanea.py -q
```

Esperado: `19 passed`.

- [ ] **Step 5: Commit**

```bash
git add scripts/validate-acervo/core/secoes_coletanea.py scripts/validate-acervo/tests/test_secoes_coletanea.py
git commit -m "feat(acervo): SQL guardado das subtags da Coletânea

INSERT só com a category do snapshot (e as mesmas tags, nos manuais); DELETE
da raiz só com a subtag já ligada; subtag de mesmo nome sob o mesmo pai é
reaproveitada.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Relatório do ensaio (§5.1.6)

**Files:**
- Modify: `scripts/validate-acervo/core/secoes_coletanea.py`: acrescentar ao fim a seção `# --- relatório ---`.
- Modify: `scripts/validate-acervo/tests/test_secoes_coletanea.py`: acrescentar ao fim a seção `# --- relatório ---`.

**Interfaces:**
- Consumes: `Plano`, `rotulos` (Task 2) e `resolver_subtags` (Task 3); `ESPERADO_*` e `ENTRAM_NA_COLETANEA` (Task 1).
- Produces:
  - `contagens(plano) -> dict[(pai, nome), int]`;
  - `divergencias(plano) -> list[str]`, que lista divergências e não aborta;
  - `relatorio(plano, conn, run_id, novas) -> str` (markdown);
  - `_escrever_relatorio(pasta, texto) -> str`, que devolve o caminho de `relatorio.md`.

O relatório traz:
- as divergências;
- a tabela de subtags com a coluna «Spec»;
- as ligações diretas removidas contra 1119;
- a tabela de §2.3 com as tags do snapshot e a ação;
- a lista dos que entram na Coletânea.

- [ ] **Step 1: Escrever o teste que falha**

Acrescentar ao fim de `tests/test_secoes_coletanea.py`:

```python
# --- relatório ---------------------------------------------------------------------

def _esperado_da_fixture(monkeypatch):
    depois = {nome: 0 for nome in mapa.ESPERADO_DEPOIS}
    depois.update({"Clamor": 3, "Morte Ressurreição e Salvação": 2, "Santificação e Derramamento do Espírito Santo": 1,
                   "Louvor": 1, "Dedicação": 2, "Crianças e Adolescentes": 1, "Volta de Jesus e Eternidade": 3})
    monkeypatch.setattr(mapa, "ESPERADO_DEPOIS", depois)
    monkeypatch.setattr(mapa, "ESPERADO_TOTAL", 13)
    monkeypatch.setattr(mapa, "ESPERADO_RAIZ_REMOVIDAS", 11)
    monkeypatch.setattr(mapa, "ENTRAM_NA_COLETANEA", (("", "Alvo Mais Que a Neve"), ("060", "Tudo está pronto")))


def test_contagens_e_divergencias(mundo, monkeypatch):
    _esperado_da_fixture(monkeypatch)
    plano = sc.montar_plano(mundo["snap"])
    n = sc.contagens(plano)
    assert n[("Coletânea", "Clamor")] == 3 and n[("Avulsos", "GLTM")] == 1
    assert sc.divergencias(plano) == []
    monkeypatch.setattr(mapa, "ESPERADO_DEPOIS", dict(mapa.ESPERADO_DEPOIS, Clamor=4))
    monkeypatch.setattr(mapa, "ESPERADO_RAIZ_REMOVIDAS", 1119)
    assert sc.divergencias(plano) == [
        "Coletânea · Clamor: 3 praises depois, a spec diz 4",
        "ligações diretas com Coletânea removidas: 11, a spec diz 1119",
    ]


def test_divergencia_de_quem_entra_ignora_nfd_e_nomeia_a_diferenca(mundo, monkeypatch):
    _esperado_da_fixture(monkeypatch)
    snap = mundo["snap"]
    snap.execute("UPDATE praises SET name = ? WHERE id = 'e1'", (unicodedata.normalize("NFD", "Tudo está pronto"),))
    plano = sc.montar_plano(snap)
    assert sc.divergencias(plano) == []
    monkeypatch.setattr(mapa, "ENTRAM_NA_COLETANEA", (("", "Alvo Mais Que a Neve"), ("609", "Senhor")))
    assert sc.divergencias(plano) == [
        "entram na Coletânea: 2 praises (spec: 2); a mais: 060 Tudo está pronto; faltam: 609 Senhor"]


def test_contagem_inclui_quem_ja_estava_na_subtag(mundo):
    snap = mundo["snap"]
    snap.execute("INSERT INTO tags VALUES ('t-clamor', 'Clamor', 't-col')")
    snap.execute("INSERT INTO praise_tags VALUES ('v1', 't-clamor')")   # ligado à mão, sem categoria
    snap.commit()
    assert sc.contagens(sc.montar_plano(snap))[("Coletânea", "Clamor")] == 4


def test_relatorio_tem_as_secoes_do_ensaio(mundo, monkeypatch):
    _esperado_da_fixture(monkeypatch)
    plano = sc.montar_plano(mundo["snap"])
    _, novas = sc.resolver_subtags(plano, [dict(r) for r in mundo["snap"].execute("SELECT * FROM tags")], _ids_fixos())
    texto = sc.relatorio(plano, mundo["snap"], "run-x", novas)
    assert texto.startswith("# Seções da Coletânea — run-x")
    assert "## Divergências da spec\n\nNenhuma." in texto
    assert "| Coletânea · Clamor | nova | 3 | 3 | 3 |" in texto
    assert "| Avulsos · GLTM | nova | 1 | 1 | 1 |" in texto
    assert "| **Total Coletânea** | | | 13 | 13 |" in texto
    assert "11 (spec: 11)." in texto
    assert "Ligações novas: 6 pela categoria, 8 manuais." in texto
    assert ("| `bbd5f528-1622-4346-a3d7-898223f7292b` | 68b | 566 | O Senhor é meu Pastor (Maranata, Jesus vem) | "
            "Avulsos, Coletânea, Diversos · weider | Coletânea · Volta de Jesus e Eternidade | "
            "liga; tira a raiz Coletânea |") in texto
    assert "| `2b309bf1-50a0-48fc-8607-8ccce0031500` | 11e | — | Tu és Maravilhoso | GLTM | Avulsos · GLTM | liga |" in texto
    assert "## Entram na Coletânea pela subtag (2; spec: 2)" in texto
    assert "| `e1` | 060 | Tudo está pronto | Louvor |" in texto


```

- [ ] **Step 2: Rodar e ver falhar**

```bash
cd "/Volumes/SSD 2TB SD/dev/coldigom/.claude/worktrees/secoes-coletanea/scripts/validate-acervo" && python3 -m pytest tests/test_secoes_coletanea.py -q
```

Esperado: `4 failed, 19 passed`, com `AttributeError: module 'core.secoes_coletanea' has no attribute 'contagens'`.

- [ ] **Step 3: Implementar**

Acrescentar ao fim de `core/secoes_coletanea.py`:

```python
# --- relatório -------------------------------------------------------------------

def contagens(plano: Plano) -> dict[tuple, int]:
    """(pai, nome) -> praises ligados à subtag depois da migração."""
    depois = {chave: set(ps) for chave, ps in plano.ja_ligados.items()}
    for lig in plano.ligacoes:
        depois[(lig.pai, lig.subtag)].add(lig.praise_id)
    return {chave: len(ps) for chave, ps in depois.items()}


def divergencias(plano: Plano) -> list[str]:
    """O que não bate com os números da spec. Não aborta: o dono lê e decide."""
    n = contagens(plano)
    saida = []
    for nome, esperado in mapa.ESPERADO_DEPOIS.items():
        obtido = n[(mapa.RAIZ_COLETANEA, nome)]
        if obtido != esperado:
            saida.append(f"Coletânea · {nome}: {obtido} praises depois, a spec diz {esperado}")
    total = sum(v for (pai, _), v in n.items() if pai == mapa.RAIZ_COLETANEA)
    if total != mapa.ESPERADO_TOTAL:
        saida.append(f"total da Coletânea: {total}, a spec diz {mapa.ESPERADO_TOTAL}")
    gltm = n[(mapa.RAIZ_AVULSOS, "GLTM")]
    if gltm != mapa.ESPERADO_AVULSOS_GLTM:
        saida.append(f"Avulsos · GLTM: {gltm} praises depois, a spec diz {mapa.ESPERADO_AVULSOS_GLTM}")
    removidas = sum(1 for lig in plano.ligacoes if lig.remover_raiz)
    if removidas != mapa.ESPERADO_RAIZ_REMOVIDAS:
        saida.append(f"ligações diretas com Coletânea removidas: {removidas}, a spec diz {mapa.ESPERADO_RAIZ_REMOVIDAS}")
    # Nome de praise no D1 pode estar em NFD (medido no snapshot de 17/09);
    # a spec está em NFC. A comparação é só do relatório, não do mapeamento.
    entram = _nfc_pares((e["number"], e["name"]) for e in plano.entram_na_coletanea)
    esperado = _nfc_pares(mapa.ENTRAM_NA_COLETANEA)
    if entram != esperado:
        a_mais = [f"{n} {s}".strip() for n, s in entram if (n, s) not in esperado]
        faltam = [f"{n} {s}".strip() for n, s in esperado if (n, s) not in entram]
        saida.append(f"entram na Coletânea: {len(entram)} praises (spec: {len(esperado)}); "
                     f"a mais: {', '.join(a_mais) or '—'}; faltam: {', '.join(faltam) or '—'}")
    return saida


def _nfc_pares(pares) -> list[tuple[str, str]]:
    return sorted((n, unicodedata.normalize("NFC", s)) for n, s in pares)


def relatorio(plano: Plano, conn: sqlite3.Connection, run_id: str, novas: list[dict]) -> str:
    """O relatório do ensaio (§5.1.6), em markdown."""
    n = contagens(plano)
    rot = rotulos(conn)
    nome_da_raiz = {v: k for k, v in plano.raizes.items()}
    novas_chaves = {(nome_da_raiz[s["parent_id"]], s["name"]) for s in novas}
    por_id = {lig.praise_id: lig for lig in plano.ligacoes}
    div = divergencias(plano)

    linhas = [f"# Seções da Coletânea — {run_id}", "",
              "Relatório gerado a partir do snapshot. `category` não é alterada (§5.1.5).", "",
              "## Divergências da spec", ""]
    linhas += [f"- {d}" for d in div] or ["Nenhuma."]
    linhas += ["", "## Subtags (§2.1)", "",
               "| Subtag | Situação | Ligações novas | Praises depois | Spec |",
               "|---|---|---:|---:|---:|"]
    for pai, nome in mapa.SUBTAGS:
        chave = (pai, nome)
        novas_lig = sum(1 for lig in plano.ligacoes if (lig.pai, lig.subtag) == chave and lig.inserir)
        esperado = mapa.ESPERADO_DEPOIS[nome] if pai == mapa.RAIZ_COLETANEA else mapa.ESPERADO_AVULSOS_GLTM
        situacao = "nova" if chave in novas_chaves else "existente"
        linhas.append(f"| {pai}{mapa.SEP_ROTULO}{nome} | {situacao} | {novas_lig} | {n[chave]} | {esperado} |")
    total = sum(v for (pai, _), v in n.items() if pai == mapa.RAIZ_COLETANEA)
    linhas.append(f"| **Total Coletânea** | | | {total} | {mapa.ESPERADO_TOTAL} |")

    removidas = sum(1 for lig in plano.ligacoes if lig.remover_raiz)
    por_origem = {o: sum(1 for lig in plano.ligacoes if lig.origem == o and lig.inserir) for o in ("categoria", "manual")}
    linhas += ["", "## Ligações diretas com `Coletânea` removidas", "",
               f"{removidas} (spec: {mapa.ESPERADO_RAIZ_REMOVIDAS}).", "",
               f"Ligações novas: {por_origem['categoria']} pela categoria, {por_origem['manual']} manuais.", "",
               "## Casos manuais (§2.3)", "",
               "| id | shortId | Nº | Louvor | Tags no snapshot | Recebe | Ação |",
               "|---|---|---|---|---|---|---|"]
    for x in mapa.MANUAIS:
        lig = por_id.get(x["id"])
        tags = sorted(rot.get(r["tag_id"], r["tag_id"]) for r in conn.execute(
            "SELECT tag_id FROM praise_tags WHERE praise_id = ?", (x["id"],)))
        acao = ("liga" if lig.inserir else "já ligado") + ("; tira a raiz Coletânea" if lig.remover_raiz else "")
        linhas.append(f"| `{x['id']}` | {x['short_id']} | {x['numero'] or '—'} | {x['nome']} | "
                      f"{', '.join(tags)} | {x['pai']}{mapa.SEP_ROTULO}{x['subtag']} | {acao} |")

    linhas += ["", f"## Entram na Coletânea pela subtag ({len(plano.entram_na_coletanea)}; "
                   f"spec: {len(mapa.ENTRAM_NA_COLETANEA)})", "",
               "| id | Nº | Louvor | Seção |", "|---|---|---|---|"]
    for e in sorted(plano.entram_na_coletanea, key=lambda e: (e["number"], e["name"])):
        linhas.append(f"| `{e['id']}` | {e['number'] or '—'} | {e['name']} | {e['subtag']} |")
    return "\n".join(linhas) + "\n"


def _escrever_relatorio(pasta: str, texto: str) -> str:
    os.makedirs(pasta, exist_ok=True)
    caminho = os.path.join(pasta, "relatorio.md")
    with open(caminho, "w", encoding="utf-8") as f:
        f.write(texto)
    return caminho


```

- [ ] **Step 4: Rodar e ver passar**

```bash
cd "/Volumes/SSD 2TB SD/dev/coldigom/.claude/worktrees/secoes-coletanea/scripts/validate-acervo" && python3 -m pytest tests/test_secoes_coletanea.py -q
```

Esperado: `23 passed`.

- [ ] **Step 5: Commit**

```bash
git add scripts/validate-acervo/core/secoes_coletanea.py scripts/validate-acervo/tests/test_secoes_coletanea.py
git commit -m "feat(acervo): relatório do ensaio das subtags da Coletânea

Contagem por subtag contra a spec, casos manuais, quem entra na Coletânea e
ligações diretas removidas, com as divergências no topo.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Ensaio e `--execute` com log, releitura e cópia para `gabaritos/`

**Files:**
- Modify: `scripts/validate-acervo/core/secoes_coletanea.py`: acrescentar ao fim a seção `# --- execução ---`.
- Modify: `scripts/validate-acervo/tests/test_secoes_coletanea.py`: acrescentar ao fim a seção `# --- execução ---`.

**Interfaces:**
- Consumes:
  - Tasks 2–4;
  - `core.d1.query(sql, remote=True) -> list[dict]`;
  - `core.d1.run_sql_files(arquivos, remote=True) -> None`;
  - `core.d1.write_sql_chunks(statements, out_dir, prefix, per_file=300) -> list[str]`;
  - `core.plpcg_apply.copiar_execucao(run_id, log_path, execucao_dir) -> str`;
  - `core.plpcg_apply._erro_texto(erro) -> str`.
- Produces:
  - `conferir_raizes(plano, tags) -> None`, que levanta `Trava`;
  - `executar(plano, conn, execute, run_id, log_path=LOG_PADRAO, out_dir=None, execucao_dir=None, remote=True, novo_id=...) -> dict`. O dict tem as chaves `run_id, executado, pasta, ligar, desligar_raiz, subtags_novas, statements, divergencias, criadas, removidas, atrasadas{ligar, desligar_raiz}, falhou, relatorio`.
  - Cada linha do log tem `run_id`, `raiz_coletanea`, `subtags_novas`, `ligar` (pares `[praise_id, tag_id]` que não existiam antes em produção), `desligar_raiz` (pares que existiam antes), `estado` (`pendente` → `escrevendo` → `ok` | `guarda_barrou` | `falhou`), `escreveu` e `ts`. O undo da Task 6 consome esse formato.

- [ ] **Step 1: Escrever o teste que falha**

Acrescentar ao fim de `tests/test_secoes_coletanea.py`:

```python
# --- execução -----------------------------------------------------------------------

@pytest.fixture
def d1(mundo, monkeypatch):
    """query e run_sql_files contra o sqlite de "produção". Cada arquivo é um
    batch atômico, como no wrangler. Nada toca rede nem credencial."""
    prod = mundo["prod"]
    chamadas = {"query": [], "sql": []}
    falhar = {"sql_no_arquivo": None, "erro": None}

    def query(sql, remote=True):
        chamadas["query"].append(sql)
        cur = prod.execute(sql)
        cols = [d[0] for d in cur.description]
        return [dict(zip(cols, r)) for r in cur.fetchall()]

    def run_sql_files(arquivos, remote=True):
        for i, caminho in enumerate(arquivos):
            if falhar["sql_no_arquivo"] == i:
                raise falhar["erro"] or RuntimeError("wrangler caiu")
            chamadas["sql"].append(caminho)
            with open(caminho, encoding="utf-8") as f:
                _aplicar(prod, f.read().splitlines())

    monkeypatch.setattr(sc, "query", query)
    monkeypatch.setattr(sc, "run_sql_files", run_sql_files)
    return {"chamadas": chamadas, "falhar": falhar}


def _kw(mundo):
    t = mundo["tmp"]
    return dict(log_path=str(t / "log.jsonl"), out_dir=str(t / "out"), execucao_dir=str(t / "exec"))


def _log(mundo):
    return [json.loads(x) for x in open(mundo["tmp"] / "log.jsonl", encoding="utf-8") if x.strip()]


def test_ensaio_nao_toca_producao_e_grava_sql_e_relatorio(mundo, d1):
    plano = sc.montar_plano(mundo["snap"])
    r = sc.executar(plano, mundo["snap"], False, "run-e", novo_id=_ids_fixos(), **_kw(mundo))
    assert d1["chamadas"] == {"query": [], "sql": []}
    assert not (mundo["tmp"] / "log.jsonl").exists()
    assert os.path.exists(r["relatorio"]) and r["relatorio"].endswith("run-e/relatorio.md")
    assert (r["ligar"], r["desligar_raiz"], r["subtags_novas"]) == (14, 11, 14)
    assert r["statements"] == 14 + 14 + 11
    assert os.listdir(mundo["tmp"] / "out" / "run-e" / "sql") == ["ensaio_000.sql"]


def test_execute_migra_loga_e_copia_para_gabaritos(mundo, d1):
    plano = sc.montar_plano(mundo["snap"])
    r = sc.executar(plano, mundo["snap"], True, "run-1", novo_id=_ids_fixos(), **_kw(mundo))
    assert r["falhou"] is False and (r["criadas"], r["removidas"]) == (14, 11)
    assert r["atrasadas"] == {"ligar": [], "desligar_raiz": []}
    assert mundo["prod"].execute("SELECT COUNT(*) FROM praise_tags WHERE tag_id = 't-col'").fetchone()[0] == 0
    linhas = _log(mundo)
    assert [x["estado"] for x in linhas] == ["pendente", "escrevendo", "ok"]
    assert [x["escreveu"] for x in linhas] == [False, True, True]
    assert len(linhas[-1]["ligar"]) == 14 and len(linhas[-1]["desligar_raiz"]) == 11
    assert len(linhas[-1]["subtags_novas"]) == 14
    assert (mundo["tmp"] / "exec" / "run-1.jsonl").read_text(encoding="utf-8").count("\n") == 3


def test_execute_guarda_barrou_lista_quem_ficou_para_tras(mundo, d1):
    mundo["prod"].execute("UPDATE praises SET category = 'Louvor' WHERE id = 'c1'")
    mundo["prod"].commit()
    plano = sc.montar_plano(mundo["snap"])
    r = sc.executar(plano, mundo["snap"], True, "run-g", novo_id=_ids_fixos(), **_kw(mundo))
    assert r["falhou"] is True
    assert r["atrasadas"] == {"ligar": ["c1"], "desligar_raiz": ["c1"]}
    fim = _log(mundo)[-1]
    assert (fim["estado"], fim["ok"]) == ("guarda_barrou", False)


def test_execute_usa_subtag_criada_em_producao_depois_do_snapshot(mundo, d1):
    mundo["prod"].execute("INSERT INTO tags VALUES ('t-clamor-admin', 'Clamor', 't-col')")
    mundo["prod"].commit()
    plano = sc.montar_plano(mundo["snap"])
    r = sc.executar(plano, mundo["snap"], True, "run-p", novo_id=_ids_fixos(), **_kw(mundo))
    assert r["falhou"] is False and r["subtags_novas"] == 13
    assert ("c1", "t-clamor-admin") in _ligacoes(mundo["prod"])
    assert "Clamor" not in {s["name"] for s in _log(mundo)[-1]["subtags_novas"]}


def test_execute_nao_reclama_ligacao_que_ja_existia_em_producao(mundo, d1):
    mundo["prod"].execute("INSERT INTO tags VALUES ('t-clamor', 'Clamor', 't-col')")
    mundo["prod"].execute("INSERT INTO praise_tags VALUES ('c1', 't-clamor')")
    mundo["prod"].commit()
    plano = sc.montar_plano(mundo["snap"])
    sc.executar(plano, mundo["snap"], True, "run-j", novo_id=_ids_fixos(), **_kw(mundo))
    assert ["c1", "t-clamor"] not in _log(mundo)[-1]["ligar"]     # o undo não vai apagá-la


def test_execute_falha_do_wrangler_fica_desfazivel(mundo, d1):
    d1["falhar"]["sql_no_arquivo"] = 0
    d1["falhar"]["erro"] = subprocess.CalledProcessError(1, ["wrangler"], stderr="D1_ERROR: boom")
    plano = sc.montar_plano(mundo["snap"])
    r = sc.executar(plano, mundo["snap"], True, "run-f", novo_id=_ids_fixos(), **_kw(mundo))
    assert r["falhou"] is True
    fim = _log(mundo)[-1]
    assert (fim["estado"], fim["escreveu"], fim["ok"]) == ("falhou", True, False)
    assert "D1_ERROR: boom" in fim["erro"]


def test_execute_raiz_trocada_em_producao_trava_sem_log(mundo, d1):
    prod = mundo["prod"]
    prod.execute("UPDATE tags SET name = 'Coletânea antiga' WHERE id = 't-col'")
    prod.execute("INSERT INTO tags VALUES ('t-col-2', 'Coletânea', NULL)")
    prod.commit()
    plano = sc.montar_plano(mundo["snap"])
    with pytest.raises(sc.Trava, match="Coletânea"):
        sc.executar(plano, mundo["snap"], True, "run-r", novo_id=_ids_fixos(), **_kw(mundo))
    assert d1["chamadas"]["sql"] == [] and not (mundo["tmp"] / "log.jsonl").exists()


```

- [ ] **Step 2: Rodar e ver falhar**

```bash
cd "/Volumes/SSD 2TB SD/dev/coldigom/.claude/worktrees/secoes-coletanea/scripts/validate-acervo" && python3 -m pytest tests/test_secoes_coletanea.py -q
```

Esperado: `7 failed, 23 passed`, com `AttributeError: module 'core.secoes_coletanea' has no attribute 'executar'`.

- [ ] **Step 3: Implementar**

Acrescentar ao fim de `core/secoes_coletanea.py`:

```python
# --- execução --------------------------------------------------------------------

def conferir_raizes(plano: Plano, tags: list[dict]) -> None:
    """As raízes de produção são as do snapshot? Todo o SQL usa esses ids."""
    problemas = []
    for nome, tid in plano.raizes.items():
        prod = [t["id"] for t in tags if t["name"] == nome and t["parent_id"] is None]
        if prod != [tid]:
            problemas.append(f"a raiz {nome!r} em produção ({prod}) não é a do snapshot ({tid})")
    if problemas:
        raise Trava(problemas)


def _ligacoes_producao(tag_ids: list[str], remote: bool) -> set:
    lista = ", ".join(sql_str(t) for t in tag_ids)
    return {(r["praise_id"], r["tag_id"]) for r in query(
        f"SELECT praise_id, tag_id FROM praise_tags WHERE tag_id IN ({lista})", remote=remote)}


def executar(plano: Plano, conn: sqlite3.Connection, execute: bool, run_id: str,
             log_path: str = LOG_PADRAO, out_dir: str | None = None, execucao_dir: str | None = None,
             remote: bool = True, novo_id=lambda: str(uuid.uuid4())) -> dict:
    pasta = os.path.join(out_dir or OUT_PADRAO, run_id)
    col = plano.raizes[mapa.RAIZ_COLETANEA]
    resumo = {"run_id": run_id, "executado": execute, "pasta": pasta,
              "ligar": sum(1 for lig in plano.ligacoes if lig.inserir),
              "desligar_raiz": sum(1 for lig in plano.ligacoes if lig.remover_raiz),
              "subtags_novas": 0, "statements": 0, "divergencias": len(divergencias(plano)),
              "criadas": 0, "removidas": 0, "atrasadas": {"ligar": [], "desligar_raiz": []}, "falhou": False}

    if not execute:
        # Portão do ensaio: sem rede, sem credencial. As subtags vêm do snapshot.
        tags = [dict(r) for r in conn.execute("SELECT id, name, parent_id FROM tags")]
        ids, novas = resolver_subtags(plano, tags, novo_id)
        stmts = sql_plano(plano, ids, novas)
        write_sql_chunks(stmts, os.path.join(pasta, "sql"), prefix="ensaio", per_file=LOTE_SQL)
        resumo["relatorio"] = _escrever_relatorio(pasta, relatorio(plano, conn, run_id, novas))
        resumo.update(subtags_novas=len(novas), statements=len(stmts))
        return resumo

    # Produção manda sobre o snapshot no que o SQL referencia por id: as raízes
    # e as subtags (uma subtag criada pelo admin depois do snapshot é reaproveitada).
    tags_prod = query("SELECT id, name, parent_id FROM tags", remote=remote)
    conferir_raizes(plano, tags_prod)
    ids, novas = resolver_subtags(plano, tags_prod, novo_id)
    stmts = sql_plano(plano, ids, novas)
    alvo = sorted({col, *ids.values()})
    antes = _ligacoes_producao(alvo, remote)
    ligar = sorted({(lig.praise_id, ids[(lig.pai, lig.subtag)]) for lig in plano.ligacoes if lig.inserir})
    desligar = sorted({(lig.praise_id, col) for lig in plano.ligacoes if lig.remover_raiz})
    # O que o undo pode tocar: só ligações que não existiam antes (para apagar)
    # e só ligações com a raiz que existiam antes (para repor).
    base = {"run_id": run_id, "raiz_coletanea": col, "subtags_novas": novas,
            "ligar": [list(x) for x in ligar if x not in antes],
            "desligar_raiz": [list(x) for x in desligar if x in antes]}
    resumo.update(subtags_novas=len(novas), statements=len(stmts))
    resumo["relatorio"] = _escrever_relatorio(pasta, relatorio(plano, conn, run_id, novas))

    os.makedirs(os.path.dirname(log_path) or ".", exist_ok=True)
    log = open(log_path, "a", encoding="utf-8")

    def gravar(linha: dict) -> None:
        log.write(json.dumps(dict(linha, ts=time.time()), ensure_ascii=False) + "\n")
        log.flush()

    try:
        gravar(dict(base, estado="pendente", escreveu=False))
        arquivos = write_sql_chunks(stmts, os.path.join(pasta, "sql"), prefix="lote", per_file=LOTE_SQL)
        # A partir daqui SQL pode chegar a produção: a linha vai para o disco
        # ANTES do wrangler, para um processo morto no meio ser desfazível.
        gravar(dict(base, estado="escrevendo", escreveu=True))
        try:
            run_sql_files(arquivos, remote=remote)
            depois = _ligacoes_producao(alvo, remote)
        except Exception as erro:
            gravar(dict(base, estado="falhou", escreveu=True, ok=False, erro=_erro_texto(erro)))
            resumo["falhou"] = True
            return resumo
        # §7: o wrangler sai 0 mesmo quando a guarda barra — quem diz o que
        # pegou é a releitura de produção.
        atras_ligar = sorted(p for p, t in ligar if (p, t) not in depois)
        atras_desligar = sorted(p for p, t in desligar if (p, t) in depois)
        ok = not atras_ligar and not atras_desligar
        resumo["criadas"] = sum(1 for x in base["ligar"] if tuple(x) in depois)
        resumo["removidas"] = sum(1 for x in base["desligar_raiz"] if tuple(x) not in depois)
        resumo["atrasadas"] = {"ligar": atras_ligar, "desligar_raiz": atras_desligar}
        resumo["falhou"] = not ok
        gravar(dict(base, estado="ok" if ok else "guarda_barrou", escreveu=True, ok=ok,
                    criadas=resumo["criadas"], removidas=resumo["removidas"], atrasadas=resumo["atrasadas"]))
        return resumo
    finally:
        log.close()
        copiar_execucao(run_id, log_path, execucao_dir or EXECUCAO_PADRAO)


```

- [ ] **Step 4: Rodar e ver passar**

```bash
cd "/Volumes/SSD 2TB SD/dev/coldigom/.claude/worktrees/secoes-coletanea/scripts/validate-acervo" && python3 -m pytest tests/test_secoes_coletanea.py -q
```

Esperado: `30 passed`.

- [ ] **Step 5: Commit**

```bash
git add scripts/validate-acervo/core/secoes_coletanea.py scripts/validate-acervo/tests/test_secoes_coletanea.py
git commit -m "feat(acervo): ensaio e --execute das subtags da Coletânea

Ensaio sem rede; --execute relê tags e ligações de produção, grava o log
antes do wrangler, relê depois e lista quem a guarda deixou para trás.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: `--undo` (§5.2)

**Files:**
- Modify: `scripts/validate-acervo/core/secoes_coletanea.py`: acrescentar ao fim a seção `# --- undo ---`.
- Modify: `scripts/validate-acervo/tests/test_secoes_coletanea.py`: acrescentar ao fim a seção `# --- undo ---`.

**Interfaces:**
- Consumes: o formato do log da Task 5.
- Produces:
  - `_ler_log(log_path) -> list[dict]`, que tolera linha truncada;
  - `sql_undo(linha) -> list[str]`, na ordem: repõe a raiz (`INSERT OR IGNORE … WHERE EXISTS praise AND EXISTS tag`), tira as ligações criadas, apaga a subtag criada só `NOT EXISTS` ligação e `NOT EXISTS` filha;
  - `desfazer(run_id, log_path, execute, remote=True, out_dir=None, execucao_dir=None) -> dict`, com as chaves `run_id, executado, statements, falhou, motivo`.
  - O undo acrescenta ao log uma linha `{"run_id", "estado": "desfeito", "ok", "statements", "ts"}`. Um `ok: true` fecha o run; um `ok: false` deixa repetir.

- [ ] **Step 1: Escrever o teste que falha**

Acrescentar ao fim de `tests/test_secoes_coletanea.py`:

```python
# --- undo -----------------------------------------------------------------------------

def _executar(mundo, run_id="run-1"):
    plano = sc.montar_plano(mundo["snap"])
    return sc.executar(plano, mundo["snap"], True, run_id, novo_id=_ids_fixos(), **_kw(mundo))


def _desfazer(mundo, run_id="run-1", execute=True):
    k = _kw(mundo)
    return sc.desfazer(run_id, k["log_path"], execute, out_dir=k["out_dir"], execucao_dir=k["execucao_dir"])


def test_undo_simulado_nao_escreve(mundo, d1):
    _executar(mundo)
    d1["chamadas"]["sql"].clear()
    r = _desfazer(mundo, execute=False)
    assert r["statements"] == 11 + 14 + 14 and d1["chamadas"]["sql"] == []
    assert _log(mundo)[-1]["estado"] == "ok"                 # o ensaio do undo não grava no log


def test_undo_volta_ao_estado_de_antes(mundo, d1):
    antes = (_ligacoes(mundo["prod"]), _tags(mundo["prod"]))
    _executar(mundo)
    r = _desfazer(mundo)
    assert r["falhou"] is False
    assert (_ligacoes(mundo["prod"]), _tags(mundo["prod"])) == antes
    fim = _log(mundo)[-1]
    assert (fim["estado"], fim["ok"]) == ("desfeito", True)
    assert _desfazer(mundo)["motivo"] == "já desfeito"


def test_undo_nao_apaga_subtag_que_ganhou_ligacao_nova(mundo, d1):
    _executar(mundo)
    clamor = mundo["prod"].execute("SELECT id FROM tags WHERE name = 'Clamor'").fetchone()[0]
    mundo["prod"].execute("INSERT INTO praise_tags VALUES ('v1', ?)", (clamor,))   # o admin ligou depois
    mundo["prod"].commit()
    _desfazer(mundo)
    assert mundo["prod"].execute("SELECT COUNT(*) FROM tags WHERE id = ?", (clamor,)).fetchone()[0] == 1
    assert ("v1", clamor) in _ligacoes(mundo["prod"])
    assert mundo["prod"].execute("SELECT COUNT(*) FROM tags WHERE name = 'Louvor'").fetchone()[0] == 0
    assert ("c1", "t-col") in _ligacoes(mundo["prod"])


def test_undo_nao_apaga_ligacao_que_ja_existia(mundo, d1):
    for conn in (mundo["snap"], mundo["prod"]):
        conn.execute("INSERT INTO tags VALUES ('t-clamor', 'Clamor', 't-col')")
        conn.execute("INSERT INTO praise_tags VALUES ('c1', 't-clamor')")
        conn.commit()
    _executar(mundo)
    _desfazer(mundo)
    assert {("c1", "t-clamor"), ("c1", "t-col")} <= _ligacoes(mundo["prod"])
    assert mundo["prod"].execute("SELECT COUNT(*) FROM tags WHERE id = 't-clamor'").fetchone()[0] == 1


def test_undo_de_run_que_caiu_no_meio(mundo, d1, monkeypatch):
    monkeypatch.setattr(sc, "LOTE_SQL", 10)                  # 39 statements, 4 arquivos
    d1["falhar"]["sql_no_arquivo"] = 2                        # os 2 primeiros entram, o 3º cai
    antes = (_ligacoes(mundo["prod"]), _tags(mundo["prod"]))
    r = _executar(mundo)
    assert r["falhou"] is True and len(d1["chamadas"]["sql"]) == 2
    d1["falhar"]["sql_no_arquivo"] = None
    assert _desfazer(mundo)["falhou"] is False
    assert (_ligacoes(mundo["prod"]), _tags(mundo["prod"])) == antes


def test_undo_que_falhou_pode_ser_repetido(mundo, d1):
    _executar(mundo)
    d1["falhar"]["sql_no_arquivo"] = 0
    assert _desfazer(mundo)["falhou"] is True
    assert (_log(mundo)[-1]["estado"], _log(mundo)[-1]["ok"]) == ("desfeito", False)
    d1["falhar"]["sql_no_arquivo"] = None
    r = _desfazer(mundo)
    assert r["falhou"] is False and r["statements"] == 39


def test_undo_de_run_que_nao_escreveu(mundo, d1):
    with open(mundo["tmp"] / "log.jsonl", "w", encoding="utf-8") as f:
        f.write(json.dumps({"run_id": "run-z", "estado": "pendente", "escreveu": False,
                            "ligar": [], "desligar_raiz": [], "subtags_novas": []}) + "\n")
        f.write('{"run_id": "run-z", "estado": "escre')      # linha truncada por um processo morto
    r = _desfazer(mundo, run_id="run-z")
    assert r["motivo"].startswith("nada a desfazer") and d1["chamadas"]["sql"] == []


```

- [ ] **Step 2: Rodar e ver falhar**

```bash
cd "/Volumes/SSD 2TB SD/dev/coldigom/.claude/worktrees/secoes-coletanea/scripts/validate-acervo" && python3 -m pytest tests/test_secoes_coletanea.py -q
```

Esperado: `7 failed, 30 passed`, com `AttributeError: module 'core.secoes_coletanea' has no attribute 'desfazer'`.

- [ ] **Step 3: Implementar**

Acrescentar ao fim de `core/secoes_coletanea.py`:

```python
# --- undo ------------------------------------------------------------------------

def _ler_log(log_path: str) -> list[dict]:
    """Linha truncada (processo morto no meio do write) é pulada: o --undo é a
    ferramenta de emergência e não pode morrer justo depois de um crash."""
    if not os.path.exists(log_path):
        return []
    linhas = []
    with open(log_path, encoding="utf-8") as f:
        for linha in f:
            linha = linha.strip()
            if not linha:
                continue
            try:
                linhas.append(json.loads(linha))
            except json.JSONDecodeError:
                continue
    return linhas


def sql_undo(linha: dict) -> list[str]:
    """Repõe a raiz, tira as ligações criadas, apaga as subtags criadas que
    ficaram sem ligação (§5.2). Nessa ordem: um arquivo que falha no meio
    deixa o praise com a raiz E a subtag, nunca sem nenhuma das duas."""
    stmts = []
    for p, t in linha["desligar_raiz"]:
        stmts.append(f"INSERT OR IGNORE INTO praise_tags (praise_id, tag_id) SELECT {sql_str(p)}, {sql_str(t)} "
                     f"WHERE EXISTS (SELECT 1 FROM praises WHERE id = {sql_str(p)}) "
                     f"AND EXISTS (SELECT 1 FROM tags WHERE id = {sql_str(t)});")
    for p, t in linha["ligar"]:
        stmts.append(f"DELETE FROM praise_tags WHERE praise_id = {sql_str(p)} AND tag_id = {sql_str(t)};")
    for s in linha["subtags_novas"]:
        i = sql_str(s["id"])
        stmts.append(f"DELETE FROM tags WHERE id = {i} "
                     f"AND NOT EXISTS (SELECT 1 FROM praise_tags WHERE tag_id = {i}) "
                     f"AND NOT EXISTS (SELECT 1 FROM tags WHERE parent_id = {i});")
    return stmts


def desfazer(run_id: str, log_path: str, execute: bool, remote: bool = True,
             out_dir: str | None = None, execucao_dir: str | None = None) -> dict:
    """Simula por padrão, como o core.apply. A última linha do run que
    escreveu é a que vale; um undo com ok:true fecha o run."""
    alvo = None
    desfeito = False
    for r in _ler_log(log_path):
        if r.get("run_id") != run_id:
            continue
        if r.get("estado") == "desfeito":
            desfeito = desfeito or bool(r.get("ok"))
            continue
        if r.get("escreveu"):
            alvo = r
    resumo = {"run_id": run_id, "executado": execute, "statements": 0, "falhou": False, "motivo": ""}
    if alvo is None:
        resumo["motivo"] = "nada a desfazer: o run não chegou a escrever"
        return resumo
    if desfeito:
        resumo["motivo"] = "já desfeito"
        return resumo
    stmts = sql_undo(alvo)
    resumo["statements"] = len(stmts)
    if not execute:
        for s in stmts[:10]:
            print("   ", s)
        return resumo

    carimbo = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    arquivos = write_sql_chunks(stmts, os.path.join(out_dir or OUT_PADRAO, run_id, f"undo-{carimbo}"),
                                prefix="undo", per_file=LOTE_SQL)
    saida = {"run_id": run_id, "estado": "desfeito", "statements": len(stmts)}
    try:
        run_sql_files(arquivos, remote=remote)
        saida["ok"] = True
    except Exception as erro:
        saida["ok"] = False
        saida["erro"] = _erro_texto(erro)
        resumo["falhou"] = True
    os.makedirs(os.path.dirname(log_path) or ".", exist_ok=True)
    with open(log_path, "a", encoding="utf-8") as log:
        log.write(json.dumps(dict(saida, ts=time.time()), ensure_ascii=False) + "\n")
    copiar_execucao(run_id, log_path, execucao_dir or EXECUCAO_PADRAO)
    return resumo


```

- [ ] **Step 4: Rodar e ver passar**

```bash
cd "/Volumes/SSD 2TB SD/dev/coldigom/.claude/worktrees/secoes-coletanea/scripts/validate-acervo" && python3 -m pytest tests/test_secoes_coletanea.py -q
```

Esperado: `37 passed`.

- [ ] **Step 5: Commit**

```bash
git add scripts/validate-acervo/core/secoes_coletanea.py scripts/validate-acervo/tests/test_secoes_coletanea.py
git commit -m "feat(acervo): undo das subtags da Coletânea

Repõe a raiz, tira só as ligações que o run criou e apaga a subtag criada só
se ficou sem ligação. Simula por padrão; grava com --execute.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: CLI e README

**Files:**
- Modify: `scripts/validate-acervo/core/secoes_coletanea.py`: acrescentar ao fim a seção `# --- CLI ---`.
- Modify: `scripts/validate-acervo/tests/test_secoes_coletanea.py`: acrescentar ao fim a seção `# --- CLI ---`.
- Modify: `scripts/validate-acervo/README.md`.

**Interfaces:**
- Consumes: Tasks 2–6.
- Produces:
  - `snapshot_velho(log_path, snapshot) -> bool`;
  - `main(argv=None) -> int`, com as flags `--snapshot --execute --undo RUN_ID --log --out-dir --execucao-dir --local`.
  - Códigos de saída: 0 para ok; 1 para falha, atrasados ou snapshot ausente; 2 para `Trava` ou snapshot velho.
  - O `run_id` é `AAAA-MM-DDTHHMMSSZ-secoes_coletanea` ou `…-secoes_coletanea-ensaio`.

- [ ] **Step 1: Escrever o teste que falha**

Acrescentar ao fim de `tests/test_secoes_coletanea.py`:

```python
# --- CLI ------------------------------------------------------------------------------

def _argv(mundo, *extra):
    k = _kw(mundo)
    return ["--snapshot", str(mundo["tmp"] / "snap.sqlite"), "--log", k["log_path"],
            "--out-dir", k["out_dir"], "--execucao-dir", k["execucao_dir"], *extra]


def test_main_ensaio(mundo, d1, capsys):
    rc = sc.main(_argv(mundo))
    out = capsys.readouterr().out
    assert rc == 0
    assert "ensaio (nada foi escrito)" in out and "ligar 14 · desligar raiz 11 · subtags novas 14" in out
    assert "relatório: " in out and d1["chamadas"] == {"query": [], "sql": []}


def test_main_trava_sai_2_sem_escrever(mundo, d1, capsys):
    mundo["snap"].execute("UPDATE praises SET category = 'Dm' WHERE id = 'v1'")
    mundo["snap"].commit()
    rc = sc.main(_argv(mundo, "--execute"))
    err = capsys.readouterr().err
    assert rc == 2 and "ABORTADO — nada foi escrito" in err and "'Dm'" in err
    assert d1["chamadas"] == {"query": [], "sql": []} and not (mundo["tmp"] / "log.jsonl").exists()


def test_main_execute_e_undo(mundo, d1, capsys):
    assert sc.main(_argv(mundo, "--execute")) == 0
    out = capsys.readouterr().out
    run_id = out.split("EXECUTADO ")[1].split(":")[0]
    assert run_id.endswith("-secoes_coletanea") and f"--undo {run_id} --execute" in out
    assert sc.main(_argv(mundo, "--undo", run_id)) == 0                     # simula
    assert "simulado" in capsys.readouterr().out
    assert sc.main(_argv(mundo, "--undo", run_id, "--execute")) == 0
    assert mundo["prod"].execute("SELECT COUNT(*) FROM praise_tags WHERE tag_id = 't-col'").fetchone()[0] == 11


def test_main_recusa_execute_com_snapshot_mais_velho_que_a_ultima_escrita(mundo, d1, capsys):
    assert sc.main(_argv(mundo, "--execute")) == 0
    passado = os.path.getmtime(mundo["tmp"] / "snap.sqlite") - 3600
    os.utime(mundo["tmp"] / "snap.sqlite", (passado, passado))
    rc = sc.main(_argv(mundo, "--execute"))
    assert rc == 2 and "core.snapshot" in capsys.readouterr().err


def test_main_sem_snapshot(mundo, capsys):
    rc = sc.main(["--snapshot", str(mundo["tmp"] / "nao-existe.sqlite")])
    assert rc == 1 and "sem snapshot" in capsys.readouterr().err
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
cd "/Volumes/SSD 2TB SD/dev/coldigom/.claude/worktrees/secoes-coletanea/scripts/validate-acervo" && python3 -m pytest tests/test_secoes_coletanea.py -q
```

Esperado: `5 failed, 37 passed`, com `AttributeError: module 'core.secoes_coletanea' has no attribute 'main'`.

- [ ] **Step 3: Implementar**

Acrescentar ao fim de `core/secoes_coletanea.py`:

```python
# --- CLI -------------------------------------------------------------------------

def snapshot_velho(log_path: str, snapshot: str) -> bool:
    """Houve escrita deste comando (execução ou undo) depois do snapshot?
    Então o snapshot não descreve mais produção: refaça antes do --execute."""
    tirado = os.path.getmtime(snapshot)
    return any((r.get("escreveu") or r.get("estado") == "desfeito") and r.get("ts", 0) >= tirado
               for r in _ler_log(log_path))


def _imprimir_trava(t: Trava) -> None:
    print(f"ABORTADO — nada foi escrito. {len(t.problemas)} problema(s):", file=sys.stderr)
    for p in t.problemas:
        print(f"  {p}", file=sys.stderr)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--snapshot", default=SNAPSHOT_DB)
    ap.add_argument("--execute", action="store_true", help="grava em produção (o padrão é o ensaio)")
    ap.add_argument("--undo", metavar="RUN_ID")
    ap.add_argument("--log", default=LOG_PADRAO)
    ap.add_argument("--out-dir", default=OUT_PADRAO)
    ap.add_argument("--execucao-dir", default=EXECUCAO_PADRAO)
    ap.add_argument("--local", action="store_true", help="wrangler --local (D1 local)")
    a = ap.parse_args(argv)
    remote = not a.local

    if a.undo:
        r = desfazer(a.undo, a.log, a.execute, remote=remote, out_dir=a.out_dir, execucao_dir=a.execucao_dir)
        modo = "EXECUTADO" if a.execute else "simulado"
        print(f"undo {a.undo} ({modo}): {r['statements']} statements"
              + (f" — {r['motivo']}" if r["motivo"] else ""))
        return 1 if r["falhou"] else 0

    if not os.path.exists(a.snapshot):
        print(f"sem snapshot: {a.snapshot} (rode python3 -m core.snapshot)", file=sys.stderr)
        return 1
    if a.execute and snapshot_velho(a.log, a.snapshot):
        print("RECUSADO: houve escrita deste comando depois do snapshot. "
              "Rode python3 -m core.snapshot e o ensaio de novo.", file=sys.stderr)
        return 2

    conn = conectar(a.snapshot)
    sufixo = "secoes_coletanea" if a.execute else "secoes_coletanea-ensaio"
    run_id = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H%M%SZ") + f"-{sufixo}"
    try:
        plano = montar_plano(conn)
        r = executar(plano, conn, a.execute, run_id, a.log, a.out_dir, a.execucao_dir, remote=remote)
    except Trava as t:
        _imprimir_trava(t)
        return 2

    modo = "EXECUTADO" if a.execute else "ensaio (nada foi escrito)"
    print(f"{modo} {run_id}: ligar {r['ligar']} · desligar raiz {r['desligar_raiz']} · "
          f"subtags novas {r['subtags_novas']} · statements {r['statements']}")
    print(f"divergências da spec: {r['divergencias']}")
    print(f"relatório: {r['relatorio']}")
    if a.execute:
        atras = r["atrasadas"]
        print(f"criadas {r['criadas']} · removidas {r['removidas']} · "
              f"atrasadas: ligar {len(atras['ligar'])}, desligar raiz {len(atras['desligar_raiz'])}")
        for pid in (atras["ligar"] + atras["desligar_raiz"])[:30]:
            print(f"  ficou para trás: {pid}")
        print(f"log: {a.log}\nundo: python3 -m core.secoes_coletanea --undo {run_id} --execute")
    return 1 if r["falhou"] else 0


if __name__ == "__main__":
    sys.exit(main())
```

No `README.md`, inserir o bloco abaixo imediatamente antes da linha `` Testes: `python3 -m pytest tests/ -v` ``:

````markdown
### Seções da Coletânea viram subtags (spec 2026-09-24-secoes-coletanea-subtags-design §5)

```bash
python3 -m core.snapshot --assets2 /dev/null/sem-arvore   # D1 fresco; este comando não precisa da árvore
python3 -m core.secoes_coletanea                          # ensaio: travas, relatório, SQL — nada é escrito
python3 -m core.secoes_coletanea --execute                # grava (só depois do deploy da API, spec §6)
python3 -m core.secoes_coletanea --undo <run_id>          # simula o undo
python3 -m core.secoes_coletanea --undo <run_id> --execute
```

O ensaio grava `out/secoes_coletanea/<run_id>/relatorio.md` (contagem por
subtag contra a spec, os casos manuais, quem entra na Coletânea, ligações
diretas com a raiz removidas) e o SQL em `sql/`. As travas (a) valor de
`category` fora do mapeamento, (b) raiz `Coletânea` sem seção e (c) caso
manual ausente ou com outras tags abortam com código 2 antes de qualquer
escrita e listam todos os problemas de uma vez.

`--execute` relê as tags de produção (as raízes têm que ser as do snapshot;
subtag criada depois do snapshot é reaproveitada), guarda quais ligações já
existiam, roda os lotes e relê as ligações. O `INSERT` só pega se a
`category` (e, nos manuais, o conjunto de tags) ainda for a do snapshot, e o
`DELETE` da raiz só pega com a subtag já ligada — quem a guarda barrou sai
como "ficou para trás" (código 1): refaça o snapshot e rode de novo. O
`--execute` é recusado se o snapshot for mais velho que a última escrita
deste comando. Log em `out/secoes_coletanea_log.jsonl`; a cópia do run vai
para `gabaritos/secoes_coletanea/execucao/<run_id>.jsonl` (git).

O undo repõe a raiz `Coletânea`, tira só as ligações que não existiam antes
do run e apaga as subtags criadas só se ficaram sem nenhuma ligação.
`category` nunca é alterada por este comando.
````

Na tabela «Arquivos» do mesmo README, logo depois da linha que começa com `` | `core/plpcg_apply.py` | ``, acrescentar:

```markdown
| `core/secoes_coletanea_mapa.py` | as constantes da spec das seções da Coletânea (§2.1–2.3), copiadas byte a byte, e `classificar()` |
| `core/secoes_coletanea.py` | seções da Coletânea → subtags: travas, SQL guardado, relatório do ensaio, execução, log, undo |
```

- [ ] **Step 4: Rodar e ver passar (arquivo novo e suíte inteira)**

```bash
cd "/Volumes/SSD 2TB SD/dev/coldigom/.claude/worktrees/secoes-coletanea/scripts/validate-acervo" && python3 -m pytest tests/test_secoes_coletanea.py -q && python3 -m pytest tests/ -q
```

Esperado: `42 passed` e depois `294 passed` (228 de antes + 24 + 42).

- [ ] **Step 5: Commit**

```bash
git add scripts/validate-acervo/core/secoes_coletanea.py scripts/validate-acervo/tests/test_secoes_coletanea.py scripts/validate-acervo/README.md
git commit -m "feat(acervo): comando core.secoes_coletanea e README

Ensaio por padrão, --execute, --undo <run_id> [--execute]; trava sai com 2
sem escrever; --execute recusado com snapshot mais velho que a última
escrita.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Ensaio contra um snapshot fresco (só leitura) e entrega ao dono

O `core.snapshot` só **lê** o D1 (`wrangler d1 export --remote`, uma tabela por vez) e escreve em `out/`, que é gitignored. É a rotina que o arnês já usa antes de todo apply. O ensaio não chama o wrangler. Nesta task **não** se roda `--execute` nem `--undo --execute`.

**Files:** nenhum arquivo versionado muda.

- [ ] **Step 1: Snapshot fresco, sem indexar a árvore de 26 GB**

```bash
cd "/Volumes/SSD 2TB SD/dev/coldigom/.claude/worktrees/secoes-coletanea/scripts/validate-acervo" && python3 -m core.snapshot --assets2 /dev/null/sem-arvore
```

Esperado: `baixando o D1:`, seis linhas `exportando <tabela>...`, `N louvores, M materiais` (N perto de 2044) e `árvore AUSENTE em /dev/null/sem-arvore`.

Se o wrangler falhar (deslogado, sem rede, sem permissão), **pare aqui**. Devolva ao controlador o stderr e os comandos do Step 4; não tente contornar.

- [ ] **Step 2: Ensaio**

```bash
cd "/Volumes/SSD 2TB SD/dev/coldigom/.claude/worktrees/secoes-coletanea/scripts/validate-acervo" && python3 -m core.secoes_coletanea; echo "rc=$?"
```

Os resultados possíveis:
- **`rc=0`:** a saída mostra `ensaio (nada foi escrito) <run_id>: ligar … · desligar raiz … · subtags novas 14 · statements …`, `divergências da spec: N` e o caminho de `relatorio.md`.
  - Pela spec, `ligar` fica perto de 1123 e `desligar raiz` perto de 1119.
  - Um ensaio contra o snapshot de 17/09, corrigido à mão, deu 1125 e 1120, com Clamor em 79 em vez de 78.
- **`rc=2`:** a saída é `ABORTADO — nada foi escrito` com a lista de travas. Isso é resultado válido do ensaio, não falha do plano. O snapshot de 17/09 tinha `category = 'Dm'` em «Ainda há tempo» (trava a) e ainda não tinha os praises 806 e 807 (trava c). Não corrigir dados: relatar.

- [ ] **Step 3: Relatar ao controlador**

Colar no relatório final:
- a saída do Step 2;
- a seção «Divergências da spec» do `relatorio.md`;
- a tabela «Subtags»;
- a lista «Entram na Coletânea».

Não commitar nada de `out/`.

- [ ] **Step 4: Comandos para o dono (não executar)**

Pré-condição: a API do plano da spec §6, passo 1, já em produção. Depois deste script, `Coletânea` e `Avulsos` passam a ter filhos, e a API antiga recusa ligar tag-pai («Cannot attach a parent tag»).

```bash
cd "/Volumes/SSD 2TB SD/dev/coldigom/.claude/worktrees/secoes-coletanea/scripts/validate-acervo"
python3 -m core.snapshot --assets2 /dev/null/sem-arvore
python3 -m core.secoes_coletanea                 # ensaio: ler out/secoes_coletanea/<run_id>/relatorio.md
python3 -m core.secoes_coletanea --execute       # grava; imprime o run_id e o comando de undo
# se "ficou para trás" > 0: snapshot de novo e --execute de novo (spec §7)
python3 -m core.secoes_coletanea --undo <run_id>             # simula o undo
python3 -m core.secoes_coletanea --undo <run_id> --execute   # desfaz
```

Depois do `--execute`, o dono commita a cópia do run em `scripts/validate-acervo/gabaritos/secoes_coletanea/execucao/<run_id>.jsonl`. A validação em produção segue a spec §6, passo 3:
- as contagens de §2.1 em `/api/plpcg/catalog`;
- 0 praises com o rótulo `Coletânea` sozinho;
- «Tu és Maravilhoso» com `Avulsos · GLTM` e `GLTM`.

---

## Cobertura da spec (self-review)

| Spec | Onde |
|---|---|
| §2.1: 13 subtags, grafias, «qualquer tag», os 4 que entram | Task 1 (`SECAO_POR_CATEGORIA`, `ESPERADO_DEPOIS`, `ENTRAM_NA_COLETANEA`); Task 2 (`test_plano_mapeia_as_grafias_e_liga_qualquer_tag`, `test_plano_lista_quem_entra_na_coletanea_pela_subtag`); Task 4 (divergências) |
| §2.2: coleção não gera tag | Task 1 (`CATEGORIAS_COLECAO`, `test_colecao_nao_gera_tag`); Task 3 (`a1` intocado em `test_sql_em_producao_faz_a_migracao`) |
| §2.3: 8 manuais; `Avulsos · GLTM` mantém a raiz `GLTM` | Task 1 (`MANUAIS`); Task 2 (`test_plano_manuais_e_gltm_sob_avulsos`); Task 3 (rótulos do 11e depois da migração) |
| §5.1.1: snapshot fresco | Task 8 (`core.snapshot`); Task 7 (`snapshot_velho`) |
| §5.1.2: travas (a)(b)(c), aborto sem escrita | Task 2 (`test_trava_*`, `test_travas_juntas_e_nenhuma_escrita`); Task 7 (`test_main_trava_sai_2_sem_escrever`) |
| §5.1.3: cria as que faltam, reaproveita | Task 3 (`resolver_subtags`, `test_reaproveita_subtag_existente`); Task 5 (`test_execute_usa_subtag_criada_em_producao_depois_do_snapshot`) |
| §5.1.4: INSERT com `category` igual; DELETE só se a ligação existe; GLTM não sai | Task 3 (`test_guarda_*`, `test_delete_da_raiz_exige_a_subtag_ligada`) |
| §5.1.5: `category` não muda | Nenhum statement toca `praises`; `sql_plano` só escreve em `tags`/`praise_tags` (Task 3) |
| §5.1.6: relatório | Task 4 (`test_relatorio_tem_as_secoes_do_ensaio`); Task 5 (ensaio grava `relatorio.md`) |
| §5.2: undo, subtag só sem ligações | Task 6 |
| §7: guarda barrou → lista, rodar de novo | Task 5 (`test_execute_guarda_barrou_lista_quem_ficou_para_tras`); Task 2 (retomada na trava c) |
| §8 validate-acervo: mapeamento, travas, «praise inalterado», reaproveitamento, undo | Tasks 1–6 |

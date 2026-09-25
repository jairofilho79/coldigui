# Fase 3 das seções da Coletânea — coldigom (script, ZIP, ingest) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** esvaziar `praises.category` no D1 com ensaio, `--execute` e undo, e parar de escrever/ler `praise_category` no ZIP e no ingest.

**Architecture:** um módulo novo em `scripts/validate-acervo` (`core.secoes_coletanea_categoria`) com a mesma forma do `core.secoes_coletanea`: ensaio lê só o snapshot, `--execute` lê a produção, grava em lotes guardados e relê; o log `.jsonl` guarda `[id, valor antigo]` do que de fato zerou, e o undo repõe só onde ainda está `NULL`. O undo reaproveita `secoes_coletanea.desfazer`, que ganha o parâmetro `sql_undo_fn`. No `api/`, `buildMetadataYaml` deixa de emitir `praise_category` e o ingest passa a gerar o `INSERT` sem a coluna `category` (função pura exportada).

**Tech Stack:** Python 3 + pytest (validate-acervo), TypeScript + vitest (api).

**Spec:** `coldigui/docs/superpowers/specs/2026-09-24-secoes-coletanea-subtags-design.md` §6 item 5 (Fase 3) e §1 (a coluna continua no schema; `DROP COLUMN` é outra entrega).

## Global Constraints

- Repositório: coldigom. Worktree `/Volumes/SSD 2TB SD/dev/coldigom/.claude/worktrees/categoria-fase3`, branch `feat/secoes-coletanea-fase3`, a partir de `origin/develop`.
- Nunca rodar `--execute` nem `wrangler d1 execute --remote`: só o dono grava em produção.
- SQL de escrita: `UPDATE praises SET category = NULL WHERE id = <id> AND category = <valor lido>;` — a guarda por valor impede apagar um valor editado depois da leitura.
- SQL do undo: `UPDATE praises SET category = <valor antigo> WHERE id = <id> AND category IS NULL;` — nunca sobrescreve um valor posto depois.
- `updated_at` não muda (limpeza em massa, não edição; o ETag do catálogo é hash do corpo e muda sozinho).
- `category = ''` também vira `NULL` (spec: `WHERE category IS NOT NULL`); o log guarda `''` para o undo.
- Lotes de 300 statements (`LOTE_SQL = 300`), um arquivo por lote.
- Estados do log, iguais aos do `secoes_coletanea`: `pendente` → `escrevendo` → `ok` | `guarda_barrou` | `falhou` | `releitura_falhou`; undo: `desfazendo` → `desfeito`.
- Git: nunca `git stash` puro; commits com o trailer `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`; rodar git como comando plano no worktree (sem `cd X && git`, sem `git -C`).
- O `cifras-agent` lê `praise_category` dos `metadata.yml` locais antigos, não do ZIP: fora do escopo.

## Review Focus

1. Um praise cuja `category` foi editada entre a leitura e a escrita não pode ser zerado (guarda por valor) e aparece como «atrasado» no resumo.
2. `--undo` depois de um run parcial (`falhou`) repõe só o que chegou a zerar — a releitura parcial alimenta o log.
3. `--undo` não sobrescreve um praise que ganhou `category` nova depois do run.
4. Valores com aspas simples e acentos (NFC como está no banco) sobrevivem ida e volta.
5. O undo do `secoes_coletanea` continua idêntico depois do parâmetro novo (testes antigos passam sem mudança).

---

### Task 1: registro da execução de 2026-09-25 e `desfazer` com `sql_undo_fn`

**Files:**
- Create: `scripts/validate-acervo/gabaritos/secoes_coletanea/execucao/2026-09-25T004808Z-secoes_coletanea.jsonl` (cópia do arquivo não versionado em `/Volumes/SSD 2TB SD/dev/coldigom/.claude/worktrees/secoes-coletanea/scripts/validate-acervo/gabaritos/secoes_coletanea/execucao/`)
- Modify: `scripts/validate-acervo/core/secoes_coletanea.py` (função `desfazer`)
- Test: `scripts/validate-acervo/tests/test_secoes_coletanea.py`

**Interfaces:**
- Produces: `desfazer(run_id, log_path, execute, remote=True, out_dir=None, execucao_dir=None, sql_undo_fn=sql_undo) -> dict` — mesmo resumo de hoje; `sql_undo_fn(linha: dict) -> list[str]` recebe a última linha `escreveu` do run.

- [ ] **Step 1: copiar o registro e commitar**

```bash
mkdir -p scripts/validate-acervo/gabaritos/secoes_coletanea/execucao
cp "/Volumes/SSD 2TB SD/dev/coldigom/.claude/worktrees/secoes-coletanea/scripts/validate-acervo/gabaritos/secoes_coletanea/execucao/2026-09-25T004808Z-secoes_coletanea.jsonl" scripts/validate-acervo/gabaritos/secoes_coletanea/execucao/
git add scripts/validate-acervo/gabaritos/secoes_coletanea/execucao/2026-09-25T004808Z-secoes_coletanea.jsonl
git commit -m "docs(acervo): registro do --execute das subtags da Coletânea em 25/09

run 2026-09-25T004808Z-secoes_coletanea: 1123 ligações criadas, 1118
ligações diretas com a raiz removidas, 14 subtags novas.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 2: teste que falha — `desfazer` usa o `sql_undo_fn` recebido**

Acrescentar ao fim de `tests/test_secoes_coletanea.py`:

```python
def test_desfazer_aceita_sql_undo_proprio(tmp_path, monkeypatch):
    log = tmp_path / "log.jsonl"
    log.write_text(json.dumps({"run_id": "r1", "estado": "ok", "escreveu": True, "x": ["a"]}) + "\n",
                   encoding="utf-8")
    rodados = []
    monkeypatch.setattr(sc, "run_sql_files", lambda arquivos, remote=True: rodados.extend(arquivos))
    r = sc.desfazer("r1", str(log), execute=True, out_dir=str(tmp_path / "out"),
                    execucao_dir=str(tmp_path / "exec"),
                    sql_undo_fn=lambda linha: [f"SELECT '{v}';" for v in linha["x"]])
    assert r["statements"] == 1 and not r["falhou"]
    assert open(rodados[0], encoding="utf-8").read() == "SELECT 'a';\n"
```

- [ ] **Step 3: rodar e ver falhar**

Run: `cd scripts/validate-acervo && python3 -m pytest tests/test_secoes_coletanea.py -q -k sql_undo_proprio`
Expected: FAIL com `TypeError: desfazer() got an unexpected keyword argument 'sql_undo_fn'`

- [ ] **Step 4: implementar**

Em `core/secoes_coletanea.py`, trocar a assinatura e a chamada:

```python
def desfazer(run_id: str, log_path: str, execute: bool, remote: bool = True,
             out_dir: str | None = None, execucao_dir: str | None = None,
             sql_undo_fn=sql_undo) -> dict:
```

e, dentro dela, `stmts = sql_undo(alvo)` vira `stmts = sql_undo_fn(alvo)`. Acrescentar à docstring: «`sql_undo_fn` monta o SQL a partir da última linha `escreveu` do run — o `core.secoes_coletanea_categoria` passa o seu.»

- [ ] **Step 5: rodar a suíte inteira do script**

Run: `cd scripts/validate-acervo && python3 -m pytest -q`
Expected: todos passam (305 + 1).

- [ ] **Step 6: commit**

```bash
git add scripts/validate-acervo/core/secoes_coletanea.py scripts/validate-acervo/tests/test_secoes_coletanea.py
git commit -m "refactor(acervo): desfazer aceita o SQL de undo de outro comando

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: `core.secoes_coletanea_categoria` — ensaio, `--execute`, undo, CLI e README

**Files:**
- Create: `scripts/validate-acervo/core/secoes_coletanea_categoria.py`
- Create: `scripts/validate-acervo/tests/test_secoes_coletanea_categoria.py`
- Modify: `scripts/validate-acervo/README.md` (seção nova logo depois da do `core.secoes_coletanea`)

**Interfaces:**
- Consumes: `core.secoes_coletanea.desfazer(..., sql_undo_fn=...)`, `_copiar_execucao_segura(run_id, log_path, execucao_dir)`; `core.d1.query/run_sql_files/sql_str/write_sql_chunks`; `core.snapshot.conectar`; `core.plpcg_apply._erro_texto`.
- Produces: `alvos_snapshot(conn) -> list[tuple[str, str]]`, `sql_zerar(alvos) -> list[str]`, `sql_undo(linha) -> list[str]`, `relatorio(alvos, run_id, executado) -> str`, `executar(conn, execute, run_id, log_path, out_dir, execucao_dir, remote=True) -> dict`, `main(argv=None) -> int`.

- [ ] **Step 1: testes que falham**

Criar `tests/test_secoes_coletanea_categoria.py`:

```python
# tests/test_secoes_coletanea_categoria.py
from __future__ import annotations

import json
import sqlite3

import pytest

from core import secoes_coletanea_categoria as cc
from core.snapshot import conectar

ESQUEMA = """
    CREATE TABLE praises (id TEXT PRIMARY KEY, name TEXT NOT NULL, category TEXT,
        updated_at TEXT DEFAULT '2026-01-01');
"""
LINHAS = [("p1", "A", "Clamor"), ("p2", "B", "Avulsos"), ("p3", "C", ""),
          ("p4", "D", None), ("p5", "E", "Morte, Ressurreição e Salvação"), ("p6", "F", "D'Ávila")]


def _povoar(caminho):
    conn = conectar(caminho)
    conn.executescript(ESQUEMA)
    conn.executemany("INSERT INTO praises (id, name, category) VALUES (?, ?, ?)", LINHAS)
    conn.commit()
    return conn


@pytest.fixture
def mundo(tmp_path, monkeypatch):
    snap = _povoar(str(tmp_path / "snap.sqlite"))
    prod = _povoar(str(tmp_path / "prod.sqlite"))
    falhar = {"no_arquivo": None}

    def query(sql, remote=True):
        cur = prod.execute(sql)
        cols = [d[0] for d in cur.description]
        return [dict(zip(cols, r)) for r in cur.fetchall()]

    def run_sql_files(arquivos, remote=True):
        for i, caminho in enumerate(arquivos):
            if falhar["no_arquivo"] == i:
                raise RuntimeError("wrangler caiu")
            with open(caminho, encoding="utf-8") as f:
                prod.executescript("BEGIN;" + f.read() + "COMMIT;")

    monkeypatch.setattr(cc, "query", query)
    monkeypatch.setattr(cc, "run_sql_files", run_sql_files)
    monkeypatch.setattr(cc.sc, "run_sql_files", run_sql_files)
    kw = dict(log_path=str(tmp_path / "log.jsonl"), out_dir=str(tmp_path / "out"),
              execucao_dir=str(tmp_path / "exec"))
    return {"snap": snap, "prod": prod, "falhar": falhar, "kw": kw, "tmp": tmp_path}


def _cats(conn):
    return {r["id"]: r["category"] for r in conn.execute("SELECT id, category FROM praises")}


def _log(m):
    return [json.loads(x) for x in open(m["kw"]["log_path"], encoding="utf-8") if x.strip()]


def test_alvos_sao_todos_os_nao_nulos_inclusive_vazio(mundo):
    assert cc.alvos_snapshot(mundo["snap"]) == [
        ("p1", "Clamor"), ("p2", "Avulsos"), ("p3", ""),
        ("p5", "Morte, Ressurreição e Salvação"), ("p6", "D'Ávila")]


def test_sql_guarda_pelo_valor_e_escapa_aspas():
    assert cc.sql_zerar([("p6", "D'Ávila")]) == [
        "UPDATE praises SET category = NULL WHERE id = 'p6' AND category = 'D''Ávila';"]
    assert cc.sql_undo({"zerados": [["p6", "D'Ávila"]]}) == [
        "UPDATE praises SET category = 'D''Ávila' WHERE id = 'p6' AND category IS NULL;"]


def test_ensaio_nao_toca_producao_e_escreve_relatorio(mundo):
    r = cc.executar(mundo["snap"], False, "r-ensaio", **mundo["kw"])
    assert r["alvos"] == 5 and r["statements"] == 5 and not r["executado"]
    assert _cats(mundo["prod"])["p1"] == "Clamor"
    texto = open(r["relatorio"], encoding="utf-8").read()
    assert "| Clamor | 1 |" in texto and "| (vazio) | 1 |" in texto


def test_execute_zera_e_loga_so_o_que_pegou(mundo):
    r = cc.executar(mundo["snap"], True, "r1", **mundo["kw"])
    assert r["zerados"] == 5 and r["atrasados"] == [] and not r["falhou"]
    assert set(_cats(mundo["prod"]).values()) == {None}
    final = _log(mundo)[-1]
    assert final["estado"] == "ok" and len(final["zerados"]) == 5
    assert [x["estado"] for x in _log(mundo)] == ["pendente", "escrevendo", "ok"]


def test_execute_le_producao_e_guarda_barra_valor_editado(mundo, monkeypatch):
    real = cc.query
    def query_e_edita(sql, remote=True):
        linhas = real(sql, remote)
        if "IS NOT NULL" in sql and not mundo.get("editou"):
            mundo["editou"] = True       # edição entre a leitura e a escrita
            mundo["prod"].execute("UPDATE praises SET category = 'Louvor' WHERE id = 'p1'")
            mundo["prod"].commit()
        return linhas
    monkeypatch.setattr(cc, "query", query_e_edita)
    r = cc.executar(mundo["snap"], True, "r1", **mundo["kw"])
    assert r["atrasados"] == ["p1"] and r["falhou"]
    assert _cats(mundo["prod"])["p1"] == "Louvor"
    final = _log(mundo)[-1]
    assert final["estado"] == "guarda_barrou" and ["p1", "Clamor"] not in final["zerados"]


def test_falha_do_wrangler_loga_releitura_parcial_e_undo_repoe_so_isso(mundo, monkeypatch):
    monkeypatch.setattr(cc, "LOTE_SQL", 2)                  # 5 statements, 3 arquivos
    mundo["falhar"]["no_arquivo"] = 1
    r = cc.executar(mundo["snap"], True, "r1", **mundo["kw"])
    assert r["falhou"] and r["zerados"] == 2
    final = _log(mundo)[-1]
    assert final["estado"] == "falhou" and len(final["zerados"]) == 2
    mundo["falhar"]["no_arquivo"] = None
    u = cc.sc.desfazer("r1", mundo["kw"]["log_path"], True, out_dir=mundo["kw"]["out_dir"],
                       execucao_dir=mundo["kw"]["execucao_dir"], sql_undo_fn=cc.sql_undo)
    assert u["statements"] == 2 and not u["falhou"]
    assert _cats(mundo["prod"]) == {pid: cat for pid, _, cat in LINHAS}


def test_undo_nao_sobrescreve_valor_novo(mundo):
    cc.executar(mundo["snap"], True, "r1", **mundo["kw"])
    mundo["prod"].execute("UPDATE praises SET category = 'Nova' WHERE id = 'p2'")
    mundo["prod"].commit()
    assert cc.main(["--undo", "r1", "--execute", "--log", mundo["kw"]["log_path"],
                    "--out-dir", mundo["kw"]["out_dir"], "--execucao-dir", mundo["kw"]["execucao_dir"]]) == 0
    cats = _cats(mundo["prod"])
    assert cats["p2"] == "Nova" and cats["p1"] == "Clamor" and cats["p6"] == "D'Ávila" and cats["p3"] == ""


def test_updated_at_nao_muda(mundo):
    cc.executar(mundo["snap"], True, "r1", **mundo["kw"])
    assert {r[0] for r in mundo["prod"].execute("SELECT updated_at FROM praises")} == {"2026-01-01"}


def test_main_ensaio_sem_snapshot_falha(tmp_path, capsys):
    assert cc.main(["--snapshot", str(tmp_path / "nao.sqlite")]) == 1
    assert "sem snapshot" in capsys.readouterr().err
```

- [ ] **Step 2: rodar e ver falhar**

Run: `cd scripts/validate-acervo && python3 -m pytest tests/test_secoes_coletanea_categoria.py -q`
Expected: FAIL com `ImportError: cannot import name 'secoes_coletanea_categoria'`

- [ ] **Step 3: implementar `core/secoes_coletanea_categoria.py`**

```python
# core/secoes_coletanea_categoria.py
"""Fase 3 das seções da Coletânea: praises.category vira NULL (spec
2026-09-24-secoes-coletanea-subtags-design §6, item 5).

    python3 -m core.secoes_coletanea_categoria                          # ensaio: relatório e SQL do snapshot
    python3 -m core.secoes_coletanea_categoria --execute                # grava em produção
    python3 -m core.secoes_coletanea_categoria --undo <run_id>          # simula o undo
    python3 -m core.secoes_coletanea_categoria --undo <run_id> --execute

As seções já são subtags de Coletânea; o valor antigo só fica no log, para o
undo. A coluna continua no schema (o DROP COLUMN é outra entrega). O ensaio
lê só o snapshot; o --execute lê a produção na hora (é ela que manda) e
guarda cada UPDATE pelo valor lido, então uma edição feita no meio não é
apagada — vira «atrasado». O undo é o do core.secoes_coletanea, com o SQL
daqui, e só repõe onde a categoria ainda está NULL.
"""
from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
import time
from collections import Counter
from datetime import datetime, timezone

from core import secoes_coletanea as sc
from core.d1 import query, run_sql_files, sql_str, write_sql_chunks
from core.paths import OUT, PKG, SNAPSHOT_DB
from core.plpcg_apply import _erro_texto
from core.snapshot import conectar

LOG_PADRAO = os.path.join(OUT, "secoes_coletanea_categoria_log.jsonl")
OUT_PADRAO = os.path.join(OUT, "secoes_coletanea_categoria")
EXECUCAO_PADRAO = os.path.join(PKG, "gabaritos", "secoes_coletanea", "execucao")
LOTE_SQL = 300
_SQL_ALVOS = "SELECT id, category FROM praises WHERE category IS NOT NULL ORDER BY id"


def alvos_snapshot(conn: sqlite3.Connection) -> list[tuple[str, str]]:
    return [(r[0], r[1]) for r in conn.execute(_SQL_ALVOS)]


def _alvos_producao(remote: bool) -> list[tuple[str, str]]:
    return [(r["id"], r["category"]) for r in query(_SQL_ALVOS, remote=remote)]


def sql_zerar(alvos: list[tuple[str, str]]) -> list[str]:
    return [f"UPDATE praises SET category = NULL WHERE id = {sql_str(p)} AND category = {sql_str(c)};"
            for p, c in alvos]


def sql_undo(linha: dict) -> list[str]:
    return [f"UPDATE praises SET category = {sql_str(c)} WHERE id = {sql_str(p)} AND category IS NULL;"
            for p, c in linha["zerados"]]


def relatorio(alvos: list[tuple[str, str]], run_id: str, executado: bool) -> str:
    linhas = [f"# Fase 3 — category vira NULL ({run_id})", "",
              f"- modo: {'EXECUTADO' if executado else 'ensaio (nada foi escrito)'}",
              f"- praises com category não nula: {len(alvos)}", "",
              "| Valor | Praises |", "|---|---:|"]
    for valor, n in sorted(Counter(c for _, c in alvos).items(), key=lambda kv: (-kv[1], kv[0])):
        linhas.append(f"| {valor if valor else '(vazio)'} | {n} |")
    return "\n".join(linhas) + "\n"


def _escrever(pasta: str, texto: str) -> str:
    os.makedirs(pasta, exist_ok=True)
    caminho = os.path.join(pasta, "relatorio.md")
    with open(caminho, "w", encoding="utf-8") as f:
        f.write(texto)
    return caminho


def _restantes(ids: set[str], remote: bool) -> set[str]:
    return {r["id"] for r in query("SELECT id FROM praises WHERE category IS NOT NULL", remote=remote)} & ids


def executar(conn: sqlite3.Connection, execute: bool, run_id: str, log_path: str = LOG_PADRAO,
             out_dir: str | None = None, execucao_dir: str | None = None, remote: bool = True) -> dict:
    pasta = os.path.join(out_dir or OUT_PADRAO, run_id)
    alvos = _alvos_producao(remote) if execute else alvos_snapshot(conn)
    stmts = sql_zerar(alvos)
    resumo = {"run_id": run_id, "executado": execute, "pasta": pasta, "alvos": len(alvos),
              "statements": len(stmts), "zerados": 0, "atrasados": [], "falhou": False,
              "relatorio": _escrever(pasta, relatorio(alvos, run_id, execute))}
    if not execute:
        write_sql_chunks(stmts, os.path.join(pasta, "sql"), prefix="ensaio", per_file=LOTE_SQL)
        return resumo

    ids = {p for p, _ in alvos}
    base = {"run_id": run_id, "alvos": len(alvos)}
    os.makedirs(os.path.dirname(log_path) or ".", exist_ok=True)
    log = open(log_path, "a", encoding="utf-8")

    def gravar(linha: dict) -> None:
        log.write(json.dumps(dict(linha, ts=time.time()), ensure_ascii=False) + "\n")
        log.flush()

    def pegou(restantes: set[str]) -> list[list[str]]:
        return [[p, c] for p, c in alvos if p not in restantes]

    try:
        gravar(dict(base, estado="pendente", escreveu=False, zerados=[]))
        arquivos = write_sql_chunks(stmts, os.path.join(pasta, "sql"), prefix="lote", per_file=LOTE_SQL)
        # Antes do wrangler, com a lista inteira: um processo morto no meio
        # ainda é desfazível (o undo só repõe onde está NULL).
        gravar(dict(base, estado="escrevendo", escreveu=True, zerados=[[p, c] for p, c in alvos]))
        try:
            run_sql_files(arquivos, remote=remote)
        except Exception as erro:
            texto = _erro_texto(erro)
            zerados = [[p, c] for p, c in alvos]
            try:
                zerados = pegou(_restantes(ids, remote))
            except Exception:
                pass
            gravar(dict(base, estado="falhou", escreveu=True, ok=False, erro=texto, zerados=zerados))
            resumo.update(falhou=True, erro=texto, zerados=len(zerados))
            return resumo
        try:
            restantes = _restantes(ids, remote)
        except Exception as erro:
            texto = _erro_texto(erro)
            gravar(dict(base, estado="releitura_falhou", escreveu=True, ok=False, erro=texto,
                        zerados=[[p, c] for p, c in alvos]))
            resumo.update(falhou=True, erro=texto)
            return resumo
        zerados = pegou(restantes)
        ok = not restantes
        gravar(dict(base, estado="ok" if ok else "guarda_barrou", escreveu=True, ok=ok,
                    zerados=zerados, atrasados=sorted(restantes)))
        resumo.update(zerados=len(zerados), atrasados=sorted(restantes), falhou=not ok)
        return resumo
    finally:
        log.close()
        sc._copiar_execucao_segura(run_id, log_path, execucao_dir or EXECUCAO_PADRAO)


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
        r = sc.desfazer(a.undo, a.log, a.execute, remote=remote, out_dir=a.out_dir,
                        execucao_dir=a.execucao_dir, sql_undo_fn=sql_undo)
        modo = "EXECUTADO" if a.execute else "simulado"
        print(f"undo {a.undo} ({modo}): {r['statements']} statements"
              + (f" — {r['motivo']}" if r["motivo"] else ""))
        return 1 if r["falhou"] else 0

    conn = None
    if not a.execute:
        if not os.path.exists(a.snapshot):
            print(f"sem snapshot: {a.snapshot} (rode python3 -m core.snapshot)", file=sys.stderr)
            return 1
        conn = conectar(a.snapshot)
    sufixo = "secoes_coletanea_categoria" if a.execute else "secoes_coletanea_categoria-ensaio"
    run_id = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H%M%SZ") + f"-{sufixo}"
    r = executar(conn, a.execute, run_id, a.log, a.out_dir, a.execucao_dir, remote=remote)

    modo = "EXECUTADO" if a.execute else "ensaio (nada foi escrito)"
    print(f"{modo} {run_id}: praises com category {r['alvos']} · statements {r['statements']}")
    print(f"relatório: {r['relatorio']}")
    if a.execute:
        print(f"zerados {r['zerados']} · atrasados {len(r['atrasados'])}")
        for pid in r["atrasados"][:30]:
            print(f"  ficou para trás: {pid}")
        if r.get("erro"):
            print(f"erro: {r['erro']}", file=sys.stderr)
        print(f"log: {a.log}\nundo: python3 -m core.secoes_coletanea_categoria --undo {run_id} --execute")
    return 1 if r["falhou"] else 0


if __name__ == "__main__":
    sys.exit(main())
```

Nota: o `--execute` não abre o snapshot (lê a produção); o teste `test_undo_nao_sobrescreve_valor_novo` chama `executar` direto e o `main` só para o undo.

- [ ] **Step 4: rodar os testes**

Run: `cd scripts/validate-acervo && python3 -m pytest -q`
Expected: todos passam (306 + 9).

- [ ] **Step 5: README**

Em `scripts/validate-acervo/README.md`, logo depois da seção do `core.secoes_coletanea`, acrescentar:

```markdown
### Fase 3: `praises.category` vira NULL (`core.secoes_coletanea_categoria`)

Só depois da homologação das subtags (spec 2026-09-24-secoes-coletanea-subtags-design §6, item 5).

    python3 -m core.snapshot --assets2 /dev/null/sem-arvore
    python3 -m core.secoes_coletanea_categoria                  # ensaio: out/secoes_coletanea_categoria/<run>/relatorio.md
    python3 -m core.secoes_coletanea_categoria --execute        # dono; lê a produção na hora
    python3 -m core.secoes_coletanea_categoria --undo <run_id> --execute

Cada UPDATE é guardado pelo valor lido: quem teve a categoria editada no meio fica «atrasado» e não é
zerado. O log guarda `[id, valor antigo]` do que zerou; o undo só repõe onde a categoria ainda está NULL.
`updated_at` não muda. A coluna continua no schema.
```

- [ ] **Step 6: commit**

```bash
git add scripts/validate-acervo/core/secoes_coletanea_categoria.py scripts/validate-acervo/tests/test_secoes_coletanea_categoria.py scripts/validate-acervo/README.md
git commit -m "feat(acervo): comando da fase 3 — praises.category vira NULL com undo

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: ZIP sem `praise_category` e ingest sem `category`

**Files:**
- Modify: `api/src/praiseZip.ts` (`PraiseRow`, `buildMetadataYaml`, `fetchPraiseForZip`)
- Modify: `api/scripts/ingest.ts` (`Metadata`, novo `export function praiseInsertSql`, `processPraiseDirectory`)
- Test: `api/src/__tests__/praiseZip.test.ts`, `api/src/__tests__/ingest.test.ts`

**Interfaces:**
- Produces: `export function praiseInsertSql(metadata: Metadata): string` e `export interface Metadata` em `api/scripts/ingest.ts`.

- [ ] **Step 1: testes que falham**

Em `praiseZip.test.ts`, tirar `category: 'Louvor',` de `mockPraise` e acrescentar dentro de `describe('praiseZip helpers', ...)`:

```ts
  it('buildMetadataYaml não escreve praise_category (fase 3 das seções da Coletânea)', () => {
    const text = buildMetadataYaml(mockPraise, [], []);
    expect(text).not.toContain('praise_category');
  });
```

Em `ingest.test.ts`, trocar o import por `import { praiseInsertSql, resolveLocalFile } from '../../scripts/ingest';` e acrescentar:

```ts
describe('praiseInsertSql', () => {
  it('ignora praise_category de ZIPs antigos', () => {
    const sql = praiseInsertSql({
      praise_id: 'p1',
      praise_name: "D'Ávila",
      praise_category: 'Clamor',
    } as Parameters<typeof praiseInsertSql>[0] & { praise_category: string });
    expect(sql).toBe(
      "INSERT INTO praises (id, name, number, author, rhythm, tonality, lyrics) VALUES ('p1', 'D''Ávila', NULL, NULL, NULL, NULL, NULL);"
    );
  });
});
```

- [ ] **Step 2: rodar e ver falhar**

Run: `cd api && npx vitest run src/__tests__/praiseZip.test.ts src/__tests__/ingest.test.ts`
Expected: FAIL — TS/erro de tipo em `mockPraise` (propriedade `category` exigida) ou `praiseInsertSql is not a function`.

- [ ] **Step 3: implementar**

`api/src/praiseZip.ts`: remover `category: string;` de `PraiseRow`, a linha `praise_category: praise.category || undefined,` de `buildMetadataYaml`, e `p.category, ` do SELECT de `fetchPraiseForZip` (fica `p.id, p.name, p.number, p.author, p.rhythm, p.tonality, p.lyrics,`).

`api/scripts/ingest.ts`: `interface Metadata` vira `export interface Metadata` sem `praise_category?: string;` (comentário acima: `// praise_category de ZIPs antigos é ignorado: as seções da Coletânea são subtags (fase 3).`). Acrescentar, antes de `processPraiseDirectory`:

```ts
export function praiseInsertSql(metadata: Metadata): string {
  return `INSERT INTO praises (id, name, number, author, rhythm, tonality, lyrics) VALUES (${[
    escapeSql(metadata.praise_id),
    escapeSql(metadata.praise_name),
    escapeSql(metadata.praise_number ?? null),
    escapeSql(metadata.praise_author ?? null),
    escapeSql(metadata.praise_rhythm ?? null),
    escapeSql(metadata.praise_tonality ?? null),
    escapeSql(metadata.praise_lyrics ?? null),
  ].join(', ')});`;
}
```

e em `processPraiseDirectory` trocar o `sqlStatements.push(\`INSERT INTO praises (...category...)\`)` por `sqlStatements.push(praiseInsertSql(metadata));`. Conferir se `escapeSql` de uma string já produz `'D''Ávila'` (se o formato divergir do teste, ajustar o teste ao formato real de `escapeSql`, nunca o contrário).

- [ ] **Step 4: rodar API inteira + tsc**

Run: `cd api && CI=1 npx vitest run && npx tsc --noEmit -p .`
Expected: todos passam; tsc sem erro. Se `api/scripts` não estiver no `tsconfig`, rodar também `npx tsc --noEmit scripts/ingest.ts --esModuleInterop --skipLibCheck --target es2022 --moduleResolution node`.

- [ ] **Step 5: commit**

```bash
git add api/src/praiseZip.ts api/scripts/ingest.ts api/src/__tests__/praiseZip.test.ts api/src/__tests__/ingest.test.ts
git commit -m "feat(api): ZIP sem praise_category e ingest sem category (fase 3)

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

#!/usr/bin/env python3
"""
Atribui groupId às entradas de louvores-manifest.json.

Regra principal (ver docs/features/LOUVOR_GROUPING.md):
  groupId = f(numero, nomeNormalizado)  — sem classificacao/categoria

Uso:
  python scripts/assign_louvor_group_ids.py --input tmp/louvores-manifest.json
  python scripts/assign_louvor_group_ids.py --input manifest.json --dry-run
  python scripts/assign_louvor_group_ids.py --input manifest.json --output manifest.out.json
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from collections import Counter, defaultdict
from difflib import SequenceMatcher
from pathlib import Path
from typing import Any

FUZZY_THRESHOLD = 0.85


def normalize_nome(text: str) -> str:
    """Espelha LouvorSearchTokens.normalize (Dart)."""
    s = text.lower()
    for pattern, repl in [
        (r"[àáâãäå]", "a"),
        (r"[èéêë]", "e"),
        (r"[ìíîï]", "i"),
        (r"[òóôõö]", "o"),
        (r"[ùúûü]", "u"),
    ]:
        s = re.sub(pattern, repl, s)
    s = s.replace("ç", "c").replace("ñ", "n")
    return s


def slug(text: str) -> str:
    s = normalize_nome(text)
    s = re.sub(r"[^a-z0-9]+", "-", s).strip("-")
    return s or "sem-titulo"


def compute_group_id(numero: str, nome: str) -> str:
    nome_norm = normalize_nome(nome.strip())
    num = numero.strip()
    if num:
        return f"{num}:{slug(nome_norm)}"
    return f"avulso:{slug(nome_norm)}"


def similarity(a: str, b: str) -> float:
    return SequenceMatcher(None, normalize_nome(a), normalize_nome(b)).ratio()


def fuzzy_canonical_nomes(entries: list[dict[str, Any]]) -> dict[int, str]:
    """
    Para entradas com mesmo numero, unifica nomes similares (>= FUZZY_THRESHOLD).
    Retorna mapa id(entry) -> nome canônico escolhido.
    """
    by_num: dict[str, list[tuple[int, str]]] = defaultdict(list)
    for idx, e in enumerate(entries):
        num = (e.get("numero") or "").strip()
        if not num:
            continue
        by_num[num].append((idx, e.get("nome") or ""))

    canonical: dict[int, str] = {}
    for _num, items in by_num.items():
        clusters: list[list[tuple[int, str]]] = []
        for idx, nome in items:
            placed = False
            for cluster in clusters:
                if similarity(nome, cluster[0][1]) >= FUZZY_THRESHOLD:
                    cluster.append((idx, nome))
                    placed = True
                    break
            if not placed:
                clusters.append([(idx, nome)])

        for cluster in clusters:
            names = [n for _, n in cluster]
            counter = Counter(names)
            best = counter.most_common(1)[0][0]
            for idx, _ in cluster:
                canonical[idx] = best
    return canonical


def assign_group_ids(
    entries: list[dict[str, Any]],
) -> tuple[list[dict[str, Any]], dict[str, Any], list[dict[str, str]]]:
    canonical_nome = fuzzy_canonical_nomes(entries)
    conflicts: list[dict[str, str]] = []
    group_sizes: Counter[str] = Counter()
    duplicate_keys: list[dict[str, str]] = []

    seen_slot: dict[tuple[str, str, str], str] = {}

    out: list[dict[str, Any]] = []
    for idx, entry in enumerate(entries):
        row = dict(entry)
        numero = (row.get("numero") or "").strip()
        nome = canonical_nome.get(idx, row.get("nome") or "")
        gid = compute_group_id(numero, nome)
        row["groupId"] = gid
        group_sizes[gid] += 1

        slot = (gid, row.get("classificacao") or "", row.get("categoria") or "")
        if slot in seen_slot and seen_slot[slot] != row.get("pdfId"):
            duplicate_keys.append(
                {
                    "groupId": gid,
                    "classificacao": slot[1],
                    "categoria": slot[2],
                    "pdfId_a": seen_slot[slot],
                    "pdfId_b": row.get("pdfId") or "",
                    "nome": nome,
                }
            )
        else:
            seen_slot[slot] = row.get("pdfId") or ""

        out.append(row)

    multi_nome_by_num: dict[str, set[str]] = defaultdict(set)
    for idx, entry in enumerate(entries):
        num = (entry.get("numero") or "").strip()
        if not num:
            continue
        multi_nome_by_num[num].add(normalize_nome(entry.get("nome") or ""))

    for num, nomes in sorted(multi_nome_by_num.items()):
        if len(nomes) <= 1:
            continue
        pairs = list(nomes)
        max_sim = max(
            (similarity(pairs[i], pairs[j]) for i in range(len(pairs)) for j in range(i + 1, len(pairs))),
            default=1.0,
        )
        if max_sim < FUZZY_THRESHOLD:
            conflicts.append(
                {
                    "tipo": "numero_nomes_distintos",
                    "numero": num,
                    "nomes": " | ".join(sorted(nomes)),
                    "max_similaridade": f"{max_sim:.2f}",
                }
            )

    for dup in duplicate_keys:
        conflicts.append(
            {
                "tipo": "duplicate_categoria",
                "groupId": dup["groupId"],
                "classificacao": dup["classificacao"],
                "categoria": dup["categoria"],
                "pdfId_a": dup["pdfId_a"],
                "pdfId_b": dup["pdfId_b"],
            }
        )

    multi_groups = sum(1 for c in group_sizes.values() if c > 1)
    singletons = sum(1 for c in group_sizes.values() if c == 1)

    report = {
        "total_entries": len(out),
        "unique_group_ids": len(group_sizes),
        "groups_with_multiple_pdfs": multi_groups,
        "singleton_groups": singletons,
        "duplicate_categoria_slots": len(duplicate_keys),
        "conflict_rows": len(conflicts),
    }

    return out, report, conflicts


def main() -> int:
    parser = argparse.ArgumentParser(description="Atribui groupId no louvores-manifest.json")
    parser.add_argument("--input", "-i", required=True, help="Caminho do manifest JSON")
    parser.add_argument(
        "--output",
        "-o",
        help="Saída JSON (default: sobrescreve --input se não --dry-run)",
    )
    parser.add_argument("--dry-run", action="store_true", help="Não grava manifest")
    parser.add_argument(
        "--report",
        default="grouping-report.json",
        help="Relatório JSON (default: grouping-report.json)",
    )
    parser.add_argument(
        "--revisao-csv",
        default="grouping-revisao.csv",
        help="CSV de conflitos (default: grouping-revisao.csv)",
    )
    args = parser.parse_args()

    input_path = Path(args.input)
    if not input_path.is_file():
        print(f"Erro: arquivo não encontrado: {input_path}", file=sys.stderr)
        return 1

    with input_path.open(encoding="utf-8") as f:
        data = json.load(f)

    if not isinstance(data, list):
        print("Erro: manifest deve ser um array JSON", file=sys.stderr)
        return 1

    updated, report, conflicts = assign_group_ids(data)

    report_path = Path(args.report)
    if not args.dry_run:
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    if conflicts:
        revisao_path = Path(args.revisao_csv)
        if not args.dry_run:
            with revisao_path.open("w", encoding="utf-8", newline="") as f:
                writer = csv.DictWriter(f, fieldnames=sorted({k for row in conflicts for k in row}))
                writer.writeheader()
                writer.writerows(conflicts)

    print(json.dumps(report, ensure_ascii=False, indent=2))

    if args.dry_run:
        print("(dry-run — manifest não alterado)", file=sys.stderr)
        return 0

    output_path = Path(args.output) if args.output else input_path
    output_path.write_text(
        json.dumps(updated, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Manifest atualizado: {output_path}", file=sys.stderr)
    if conflicts:
        print(f"Revisão: {args.revisao_csv} ({len(conflicts)} linhas)", file=sys.stderr)
    print(f"Relatório: {report_path}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

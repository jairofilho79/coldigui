#!/usr/bin/env python3
"""
Gera SQL de seed para D1 a partir de louvores-manifest-grouped.json.

Uso:
  python scripts/seed_d1_louvores.py
  python scripts/seed_d1_louvores.py --input tmp/louvores-manifest-grouped.json
  python scripts/seed_d1_louvores.py --output workers/plpcg-catalog/seed/001_louvores.sql

Depois:
  wrangler d1 execute plpcg-catalog --local --file workers/plpcg-catalog/seed/001_louvores.sql

Só para D1 local, após a migration 0011 aplicada; no remoto o catálogo é do
admin (nunca rodar este seed contra --remote).
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

BATCH_SIZE = 100
CANONICAL_FIELDS = (
    "nome",
    "numero",
    "classificacao",
    "categoria",
    "pdf",
    "pdfId",
    "groupId",
    "shortId",
)


def sql_escape(value: str) -> str:
    return value.replace("'", "''")


def canonical_entry(entry: dict) -> dict:
    return {field: entry.get(field, "") or "" for field in CANONICAL_FIELDS}


# O valor aqui é só o ETag inicial do Worker (D1 recém-semeado). O admin
# recalcula o dele com sua própria implementação (ordenação localeCompare +
# escaping de JSON do JS), então os dois não são byte-a-byte iguais por design.
def compute_checksum(entries: list[dict]) -> str:
    canonical = [canonical_entry(e) for e in entries]
    canonical.sort(key=lambda e: e["pdfId"])
    payload = json.dumps(canonical, ensure_ascii=False, separators=(",", ":"))
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def validate_entries(entries: list[dict]) -> tuple[list[dict], int]:
    valid: list[dict] = []
    skipped = 0
    for item in entries:
        if not isinstance(item, dict):
            skipped += 1
            continue
        pdf_id = item.get("pdfId")
        if not isinstance(pdf_id, str) or not pdf_id.strip():
            skipped += 1
            continue
        valid.append(item)
    return valid, skipped


def check_short_ids(entries: list[dict]) -> None:
    """Avisa sobre shortId ausente e aborta em shortId duplicado.

    Com o índice UNIQUE em `short_id`, um INSERT OR REPLACE colidindo em
    shortId apagaria silenciosamente a outra linha — por isso duplicata é
    erro fatal, não warning.
    """
    seen: dict[str, str] = {}
    missing = 0
    for entry in entries:
        short_id = entry.get("shortId")
        pdf_id = str(entry.get("pdfId", "?"))
        if not isinstance(short_id, str) or not short_id:
            missing += 1
            continue
        if short_id in seen:
            print(
                f"Erro: shortId duplicado {short_id!r} em pdfId={pdf_id!r} "
                f"e pdfId={seen[short_id]!r} — INSERT OR REPLACE apagaria uma "
                "das duas linhas (índice UNIQUE em short_id). Corrija o "
                "manifest antes de gerar o seed.",
                file=sys.stderr,
            )
            raise SystemExit(1)
        seen[short_id] = pdf_id
    if missing:
        print(
            f"Aviso: {missing} entrada(s) sem shortId string — essas linhas "
            "vão para o D1 com short_id = NULL. Rode o backfill da migration "
            "0011 (ou renomeie/salve a linha no admin, que aloca um shortId) "
            "antes de considerar o catálogo completo.",
            file=sys.stderr,
        )


def build_insert(entry: dict) -> str:
    nome = sql_escape(str(entry.get("nome", "")))
    numero = sql_escape(str(entry.get("numero", "") or ""))
    classificacao = sql_escape(str(entry.get("classificacao", "")))
    categoria = sql_escape(str(entry.get("categoria", "")))
    pdf = sql_escape(str(entry.get("pdf", "")))
    pdf_id = sql_escape(str(entry["pdfId"]))
    group_id = sql_escape(str(entry.get("groupId", "") or ""))
    short_id = entry.get("shortId")
    # shortId é string hex ("0000" é válido) — nunca int(); NULL quando o
    # manifest ainda não traz o campo (o backfill da migration 0011 preenche).
    short_id_sql = f"'{sql_escape(str(short_id))}'" if isinstance(short_id, str) and short_id else "NULL"
    return (
        f"INSERT OR REPLACE INTO louvores "
        f"(pdf_id, nome, numero, classificacao, categoria, pdf, group_id, short_id) "
        f"VALUES ('{pdf_id}', '{nome}', '{numero}', '{classificacao}', "
        f"'{categoria}', '{pdf}', '{group_id}', {short_id_sql});"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Gera seed SQL para D1 plpcg-catalog")
    parser.add_argument(
        "--input",
        type=Path,
        default=Path("tmp/louvores-manifest-grouped.json"),
        help="Manifest agrupado (JSON array)",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("workers/plpcg-catalog/seed/001_louvores.sql"),
        help="Arquivo SQL de saída",
    )
    args = parser.parse_args()

    if not args.input.is_file():
        print(f"Erro: input não encontrado: {args.input}", file=sys.stderr)
        return 1

    raw = json.loads(args.input.read_text(encoding="utf-8"))
    if not isinstance(raw, list):
        print("Erro: manifest deve ser um array JSON", file=sys.stderr)
        return 1

    entries, skipped = validate_entries(raw)
    if not entries:
        print("Erro: nenhuma entrada válida", file=sys.stderr)
        return 1

    check_short_ids(entries)

    checksum = compute_checksum(entries)
    args.output.parent.mkdir(parents=True, exist_ok=True)

    lines: list[str] = [
        "-- Gerado por scripts/seed_d1_louvores.py — não editar manualmente",
        "DELETE FROM louvores;",
        "DELETE FROM catalog_meta WHERE key IN ('checksum', 'row_count');",
    ]

    for i in range(0, len(entries), BATCH_SIZE):
        batch = entries[i : i + BATCH_SIZE]
        for entry in batch:
            lines.append(build_insert(entry))

    lines.append(
        "INSERT OR REPLACE INTO catalog_meta (key, value) "
        f"VALUES ('checksum', '{checksum}');"
    )
    lines.append(
        "INSERT OR REPLACE INTO catalog_meta (key, value) "
        f"VALUES ('row_count', '{len(entries)}');"
    )

    args.output.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"Entradas válidas: {len(entries)}")
    if skipped:
        print(f"Ignoradas (sem pdfId): {skipped}")
    print(f"Checksum SHA-256: {checksum}")
    print(f"SQL escrito em: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

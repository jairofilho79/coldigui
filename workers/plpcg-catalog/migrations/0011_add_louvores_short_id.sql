-- Migration number: 0011  2026-09-13T00:00:00.000Z
-- shortId por material PDF (spec 2026-09-13-short-id-share-design §0 D1–D5).
-- String hex minúscula, 4 chars hoje; UNIQUE; nunca reutilizado.
-- Backfill determinístico: ordem (numero, nome, categoria, pdf_id) a partir de '0000'.
-- Este arquivo é a versão CANÔNICA. plpcg-admin/worker/migrations/0003_add_short_id.sql
-- é um espelho só para o D1 local do admin — no remoto, aplicar SOMENTE daqui.
ALTER TABLE louvores ADD COLUMN short_id TEXT;

UPDATE louvores
SET short_id = numbered.short_id
FROM (
  SELECT
    pdf_id,
    printf('%04x', ROW_NUMBER() OVER (ORDER BY numero, nome, categoria, pdf_id) - 1) AS short_id
  FROM louvores
) AS numbered
WHERE louvores.pdf_id = numbered.pdf_id;

CREATE UNIQUE INDEX idx_louvores_short_id ON louvores(short_id);

INSERT OR REPLACE INTO catalog_meta (key, value)
VALUES ('short_id_next', (SELECT printf('%04x', COUNT(*)) FROM louvores));

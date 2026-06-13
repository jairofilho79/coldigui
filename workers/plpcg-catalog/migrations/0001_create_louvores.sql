-- Migration number: 0001 	 2026-06-12T00:00:00.000Z
CREATE TABLE louvores (
  pdf_id        TEXT PRIMARY KEY NOT NULL,
  nome          TEXT NOT NULL,
  numero        TEXT NOT NULL DEFAULT '',
  classificacao TEXT NOT NULL,
  categoria     TEXT NOT NULL,
  pdf           TEXT NOT NULL,
  group_id      TEXT NOT NULL DEFAULT ''
);

CREATE INDEX idx_louvores_group_id ON louvores(group_id);
CREATE INDEX idx_louvores_numero ON louvores(numero);

CREATE TABLE catalog_meta (
  key   TEXT PRIMARY KEY NOT NULL,
  value TEXT NOT NULL
);

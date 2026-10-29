-- Migration number: 0013  2026-09-14T00:00:00.000Z
-- Sala «ao vivo» permanente por pessoa (spec 2026-09-12-lista-ao-vivo, §4.2).
-- Índice code ↔ dono; o estado vivo (snapshot, versão) fica só no Durable
-- Object LiveRoom. Regenerar o link troca o `code` da mesma linha.
CREATE TABLE live_rooms (
  code       TEXT PRIMARY KEY NOT NULL,
  owner_sub  TEXT NOT NULL UNIQUE REFERENCES users(google_sub) ON DELETE CASCADE,
  created_at TEXT NOT NULL
);

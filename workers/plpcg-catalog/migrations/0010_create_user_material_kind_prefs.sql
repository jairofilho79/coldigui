-- Migration number: 0010  2026-09-12T00:00:00.000Z
-- Um documento por usuário: a lista ordenada (≤ 5) dos material_kinds Coldigom
-- favoritos. Sem tombstone — "sem favoritos" é kind_ids = '[]'.
CREATE TABLE user_material_kind_prefs (
  user_id     TEXT PRIMARY KEY,
  kind_ids    TEXT NOT NULL,
  updated_at  TEXT NOT NULL,
  version     INTEGER NOT NULL DEFAULT 1
);

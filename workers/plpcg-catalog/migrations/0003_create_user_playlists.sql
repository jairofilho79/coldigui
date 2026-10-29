-- Migration number: 0003  2026-07-13T00:00:00.000Z
CREATE TABLE user_playlists (
  id           TEXT NOT NULL,
  user_id      TEXT NOT NULL,
  nome         TEXT NOT NULL,
  pdf_ids      TEXT NOT NULL,
  salva        INTEGER NOT NULL DEFAULT 1,
  saved_at     TEXT,
  favorita     INTEGER NOT NULL DEFAULT 0,
  favorited_at TEXT,
  created_at   TEXT NOT NULL,
  updated_at   TEXT NOT NULL,
  version      INTEGER NOT NULL DEFAULT 1,
  deleted_at   TEXT,
  PRIMARY KEY (user_id, id)
);

CREATE INDEX idx_user_playlists_user_updated
  ON user_playlists(user_id, updated_at);

CREATE INDEX idx_user_playlists_user_deleted
  ON user_playlists(user_id, deleted_at);

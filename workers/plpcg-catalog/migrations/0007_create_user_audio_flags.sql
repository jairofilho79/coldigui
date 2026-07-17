-- Migration number: 0007  2026-07-16T00:00:00.000Z
CREATE TABLE user_audio_flags (
  id           TEXT NOT NULL,
  user_id      TEXT NOT NULL,
  audio_id     TEXT NOT NULL,
  position_ms  INTEGER NOT NULL,
  label        TEXT NOT NULL DEFAULT '',
  created_at   TEXT NOT NULL,
  updated_at   TEXT NOT NULL,
  version      INTEGER NOT NULL DEFAULT 1,
  deleted_at   TEXT,
  PRIMARY KEY (user_id, id)
);

CREATE INDEX idx_user_audio_flags_user_updated
  ON user_audio_flags(user_id, updated_at);

CREATE INDEX idx_user_audio_flags_user_deleted
  ON user_audio_flags(user_id, deleted_at);

CREATE INDEX idx_user_audio_flags_user_audio
  ON user_audio_flags(user_id, audio_id);

-- workers/plpcg-catalog/migrations/0012_create_user_sessions.sql
-- Migration number: 0012  2026-09-13T00:00:00.000Z
-- Sessões emitidas pelo Worker (spec 2026-09-13-worker-session-persistence).
-- Uma linha por login/aparelho. Só o SHA-256 hex do token é gravado; o token
-- cru só existe na resposta do POST /api/auth/session e no aparelho.
CREATE TABLE user_sessions (
  token_hash   TEXT PRIMARY KEY NOT NULL,
  google_sub   TEXT NOT NULL REFERENCES users(google_sub) ON DELETE CASCADE,
  created_at   TEXT NOT NULL,
  last_seen_at TEXT NOT NULL,
  expires_at   TEXT NOT NULL   -- ISO 8601, last_seen_at + 60 d (deslizante)
);
CREATE INDEX idx_user_sessions_sub ON user_sessions(google_sub);
CREATE INDEX idx_user_sessions_expires ON user_sessions(expires_at);

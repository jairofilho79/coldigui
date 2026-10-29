-- Migration number: 0002  2026-07-13T00:00:00.000Z
CREATE TABLE users (
  google_sub    TEXT PRIMARY KEY NOT NULL,
  email         TEXT,
  name          TEXT,
  picture_url   TEXT,
  created_at    TEXT NOT NULL,
  updated_at    TEXT NOT NULL,
  last_login_at TEXT NOT NULL
);

CREATE INDEX idx_users_email ON users(email);

-- Migration number: 0005  2026-07-13T18:00:00.000Z
ALTER TABLE users ADD COLUMN username TEXT;
CREATE UNIQUE INDEX idx_users_username ON users(username);

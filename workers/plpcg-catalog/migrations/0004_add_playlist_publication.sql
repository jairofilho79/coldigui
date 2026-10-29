-- Migration number: 0004  2026-07-13T15:00:00.000Z
ALTER TABLE user_playlists ADD COLUMN is_published INTEGER NOT NULL DEFAULT 0;
ALTER TABLE user_playlists ADD COLUMN publication_reach TEXT;
ALTER TABLE user_playlists ADD COLUMN publication_category TEXT;
ALTER TABLE user_playlists ADD COLUMN published_at TEXT;

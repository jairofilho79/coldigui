-- Parallel audio collection on user playlists (Coldigom).
ALTER TABLE user_playlists ADD COLUMN audio_ids TEXT NOT NULL DEFAULT '[]';

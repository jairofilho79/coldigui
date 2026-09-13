-- Migration number: 0011  2026-09-13T00:00:00.000Z
-- Material type (pdf/chord/mp3/...) preferido por kind favoritado, no mesmo
-- documento por usuário. JSON `{ kindId: type }`; ausente/'{}' = sem preferência
-- (o app usa o primeiro type disponível como padrão).
ALTER TABLE user_material_kind_prefs
  ADD COLUMN preferred_types TEXT NOT NULL DEFAULT '{}';

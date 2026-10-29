-- Links curtos de compartilhamento de playlist (D7, spec C.2).
--
-- `query` é a query string do share (`shareitems=…&sharepdfs=…&…`), até 4 KB
-- (validada no handler, não aqui). `created_by` é o `google_sub` de quem
-- gerou o link — todo link exige autenticação na criação (`POST
-- /api/links`); a leitura (`GET /l/:code`) é pública e não toca esta coluna
-- além do `hits`.
--
-- Índice único em `(created_by, query)`: o mesmo usuário pedindo o mesmo
-- conteúdo de novo reusa o código existente em vez de gerar outro (D7).
-- `idx_short_links_owner_created` cobre o teto de 100 links/24h por usuário
-- (`COUNT … WHERE created_by = ? AND created_at >= ?`).
CREATE TABLE short_links (
  code TEXT PRIMARY KEY,
  query TEXT NOT NULL,
  created_by TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  hits INTEGER NOT NULL DEFAULT 0
);

CREATE UNIQUE INDEX idx_short_links_owner_query ON short_links(created_by, query);
CREATE INDEX idx_short_links_owner_created ON short_links(created_by, created_at);

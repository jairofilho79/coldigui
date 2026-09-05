/**
 * Peças compartilhadas do wire de playlists (spec A.1).
 *
 * `playlists/handlers.ts` e `social/handlers.ts` respondem o mesmo formato de
 * `items`; antes cada um tinha a sua cópia de `SCHEMA_VERSION`, `parseIdList` e
 * `json`. Aqui elas existem uma vez só.
 */

/** Versão do payload que este Worker responde (spec A.3). */
export const SCHEMA_VERSION = 2;

/** Opções das rotas de listagem de playlists e de marcadores (spec A.2). */
export interface ListOptions {
  /** `true` devolve também as linhas com `deleted_at IS NOT NULL`. */
  includeDeleted?: boolean;
}

/** Resposta JSON sem cache — todo dado de usuário é `no-store`. */
export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });
}

/**
 * Lê uma coluna que guarda `string[]` em JSON. Coluna nula, JSON corrompido ou
 * elemento que não é string são descartados em vez de derrubar a listagem.
 */
export function parseIdList(raw: string | null | undefined): string[] {
  if (!raw) return [];
  try {
    const parsed: unknown = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    return parsed.filter((v): v is string => typeof v === 'string');
  } catch {
    return [];
  }
}

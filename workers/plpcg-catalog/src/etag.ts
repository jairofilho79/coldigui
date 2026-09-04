/**
 * Comparação de `If-None-Match` (RFC 9110 §13.1.2).
 *
 * Função pura, fora de `index.ts`, para ser testável com `node:test` sem
 * arrastar a árvore de imports do Worker (D1, `jose`, handlers).
 */

/** Tira o prefixo weak (`W/`), as aspas e os espaços de um valor de ETag. */
function normalize(value: string): string {
  const withoutWeak = value.trim().replace(/^W\/\s*/i, '');
  return withoutWeak.trim().replace(/^"(.*)"$/s, '$1');
}

/**
 * `true` quando o `If-None-Match` do cliente corresponde a [etag].
 *
 * Aceita:
 * - `*` (casa com qualquer etag existente);
 * - lista separada por vírgula (`'"a", "b"'`), com espaços em volta;
 * - validador weak (`W/"a"`), dos dois lados — o Worker só serve respostas
 *   completas, então weak e strong são equivalentes aqui;
 * - o checksum **cru**, sem aspas, que é o formato que o cliente Dart persiste
 *   em `ManifestChecksumStore` e reenvia.
 *
 * `If-None-Match` ausente ou vazio nunca casa.
 */
export function matchesEtag(
  ifNoneMatch: string | null | undefined,
  etag: string,
): boolean {
  if (!ifNoneMatch) return false;
  if (ifNoneMatch.trim() === '*') return true;

  const wanted = normalize(etag);
  return ifNoneMatch
    .split(',')
    .some((candidate) => {
      const normalized = normalize(candidate);
      // Uma entrada vazia (`'"a", , "b"'`) não pode casar com um etag vazio.
      return normalized.length > 0 && normalized === wanted;
    });
}

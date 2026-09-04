/**
 * Ordem única tipada de uma playlist (wire v2, spec A.3/A.4).
 *
 * Funções puras — sem D1, sem `Request` — para poderem ser testadas com
 * `node:test` sem nenhum runtime de Worker.
 */

/** Espelha `MaterialKind` do cliente Dart (`core/utils/material_id_kind.dart`). */
export type MaterialKind =
  | 'pdf'
  | 'chord'
  | 'audio'
  | 'youtube'
  | 'gesture'
  | 'unknown';

export interface PlaylistItem {
  id: string;
  kind: MaterialKind;
}

/**
 * Valores aceitos em `kind`.
 *
 * O Worker **não** interpreta o tipo (não classifica por extensão, não decide
 * face): só valida e devolve. Quem refina `pdf`/`unknown` pela extensão do id é
 * o cliente, em `resolveWireKind` (A.3).
 */
export const MATERIAL_KINDS: ReadonlySet<string> = new Set([
  'pdf',
  'chord',
  'audio',
  'youtube',
  'gesture',
  'unknown',
]);

/**
 * Valida `items` vindo do body do PUT.
 *
 * Devolve `null` quando o valor é inválido — **`null` significa "rejeite com
 * 400"**, e é diferente de `[]` (uma playlist legitimamente vazia).
 */
export function parseItems(raw: unknown): PlaylistItem[] | null {
  if (!Array.isArray(raw)) return null;

  const items: PlaylistItem[] = [];
  for (const entry of raw) {
    if (typeof entry !== 'object' || entry === null || Array.isArray(entry)) {
      return null;
    }
    const { id, kind } = entry as { id?: unknown; kind?: unknown };
    if (typeof id !== 'string' || id.length === 0) return null;
    if (typeof kind !== 'string' || !MATERIAL_KINDS.has(kind)) return null;
    // Reconstrói a entrada: campos extras do cliente não são persistidos.
    items.push({ id, kind: kind as MaterialKind });
  }
  return items;
}

/**
 * Deriva `items` das duas listas v1 de um cliente antigo.
 *
 * Toda partitura vira `pdf` — o Worker não sabe distinguir cifra de PDF. O
 * cliente recupera `chord`/`gesture` pela extensão do id na leitura (A.3).
 */
export function itemsFromLegacy(
  pdfIds: string[],
  audioIds: string[],
): PlaylistItem[] {
  return [
    ...pdfIds.map((id): PlaylistItem => ({ id, kind: 'pdf' })),
    ...audioIds.map((id): PlaylistItem => ({ id, kind: 'audio' })),
  ];
}

/**
 * Projeta `items` nas duas listas v1, para um leitor v1 continuar funcionando.
 *
 * Face de partituras = tudo que **não** é áudio (PDF, cifra, gesto, YouTube e
 * ids legados `unknown`), para que nenhuma família suma das duas faces (A7).
 */
export function listsFromItems(items: PlaylistItem[]): {
  pdfIds: string[];
  audioIds: string[];
} {
  const pdfIds: string[] = [];
  const audioIds: string[] = [];
  for (const item of items) {
    if (item.kind === 'audio') {
      audioIds.push(item.id);
    } else {
      pdfIds.push(item.id);
    }
  }
  return { pdfIds, audioIds };
}

/**
 * Lê a coluna `items` do D1 (JSON) de forma tolerante.
 *
 * Coluna ausente, JSON quebrado ou com forma inesperada devolve `[]` — uma
 * linha corrompida não pode derrubar o `GET` da lista inteira. O chamador trata
 * `[]` como "sem ordem única gravada" e cai nas duas listas v1.
 */
export function parseItemsColumn(text: string | null): PlaylistItem[] {
  if (!text) return [];
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    return [];
  }
  return parseItems(parsed) ?? [];
}

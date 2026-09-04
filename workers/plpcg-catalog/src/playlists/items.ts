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
 *
 * Aceita duas formas de entrada, na mesma lista:
 *
 * - **objeto** `{id, kind}` — o formato v2 definitivo;
 * - **string** solta — o rascunho v2 da fatia 1. O tipo dela não vem no wire,
 *   então é decidido por pertencimento a [declaredAudio] (o `audioIds` do mesmo
 *   body): dentro → `audio`, fora → `pdf`. Mesma regra do cliente Dart
 *   (`PlaylistEntry.fromJson` com `declaredAudio`), para os dois lados lerem um
 *   payload legado igual.
 */
export function parseItems(
  raw: unknown,
  declaredAudio: Iterable<string> = [],
): PlaylistItem[] | null {
  return parseEntries(raw, new Set(declaredAudio), true);
}

/**
 * @param allowLooseIds aceita string solta como entrada (só o body do PUT; a
 *   coluna do D1 é sempre objeto — ver [parseItemsColumn]).
 */
function parseEntries(
  raw: unknown,
  declaredAudio: ReadonlySet<string>,
  allowLooseIds: boolean,
): PlaylistItem[] | null {
  if (!Array.isArray(raw)) return null;

  const items: PlaylistItem[] = [];
  for (const entry of raw) {
    if (typeof entry === 'string') {
      if (!allowLooseIds || entry.length === 0) return null;
      items.push({
        id: entry,
        kind: declaredAudio.has(entry) ? 'audio' : 'pdf',
      });
      continue;
    }
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
 * Como [itemsFromLegacy], mas **reaproveitando o `kind` já gravado** para os
 * ids que continuam na playlist.
 *
 * Um PUT v1 (sem `items`) sobre uma linha v2 é last-write-wins **de
 * pertencimento e ordem** — quem manda são as duas listas do request. O que ele
 * não pode fazer é *rebaixar o tipo*: sem isto, um cliente v1 mexendo no nome
 * da playlist transformaria toda cifra (`chord`), gesto (`gesture`) e vídeo
 * (`youtube`) gravados em `pdf`, e a perda seria permanente.
 *
 * O `kind` gravado só é reaproveitado quando **concorda com a face** em que o
 * request pôs o id: um id que sai de `pdfIds` para `audioIds` (ou o contrário)
 * segue o request, porque aí a informação nova é mais recente que a antiga.
 */
export function itemsFromLegacyPreservingKinds(
  pdfIds: string[],
  audioIds: string[],
  stored: PlaylistItem[],
): PlaylistItem[] {
  const storedKinds = new Map(stored.map((item) => [item.id, item.kind]));

  const resolve = (id: string, face: 'pdf' | 'audio'): PlaylistItem => {
    const previous = storedKinds.get(id);
    const sameFace = (previous === 'audio') === (face === 'audio');
    return previous !== undefined && sameFace
      ? { id, kind: previous }
      : { id, kind: face };
  };

  return [
    ...pdfIds.map((id) => resolve(id, 'pdf')),
    ...audioIds.map((id) => resolve(id, 'audio')),
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
 *
 * **Mais estrita que [parseItems] de propósito:** esta coluna é escrita só por
 * este Worker, sempre como objetos. Uma coluna que contivesse ids soltos
 * (`["p1","a1"]`) não traz o tipo de nada, e aceitá-la marcaria todo áudio como
 * `pdf`; devolver `[]` é melhor, porque o chamador então deriva das colunas
 * `pdf_ids`/`audio_ids`, que **sabem** quem é áudio.
 */
export function parseItemsColumn(text: string | null): PlaylistItem[] {
  if (!text) return [];
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    return [];
  }
  return parseEntries(parsed, new Set(), false) ?? [];
}

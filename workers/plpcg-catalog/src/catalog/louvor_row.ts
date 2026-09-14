/**
 * Linha de `louvores` e sua projeção JSON pública (`/api/catalog/louvores`).
 *
 * `short_id` (spec short-id-share D1) é string hex — nunca converter em
 * número. Omitido do JSON enquanto for NULL (transição), para o cliente não
 * ver `"shortId": null`.
 */
export interface LouvorRow {
  nome: string;
  numero: string;
  classificacao: string;
  categoria: string;
  pdf: string;
  pdf_id: string;
  group_id: string;
  short_id: string | null;
}

export interface LouvorJson {
  nome: string;
  numero: string;
  classificacao: string;
  categoria: string;
  pdf: string;
  pdfId: string;
  groupId: string;
  shortId?: string;
}

export const LOUVOR_SELECT_COLUMNS =
  'nome, numero, classificacao, categoria, pdf, pdf_id, group_id, short_id';

export function mapRow(row: LouvorRow): LouvorJson {
  const json: LouvorJson = {
    nome: row.nome,
    numero: row.numero,
    classificacao: row.classificacao,
    categoria: row.categoria,
    pdf: row.pdf,
    pdfId: row.pdf_id,
    groupId: row.group_id,
  };
  if (row.short_id) {
    json.shortId = row.short_id;
  }
  return json;
}

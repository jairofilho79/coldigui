/**
 * Migração única dos ids legados das playlists no D1 (spec
 * docs/superpowers/specs/2026-09-23-fim-fonte-plpcg-design.md §6.3).
 *
 * Funções puras — sem D1, sem rede — testadas com `node:test`. A casca que
 * fala com o wrangler e com o crosswalk é `migrate-legacy-playlist-ids.ts`.
 * As regras espelham o app (`lib/core/utils/pdf_id_codec.dart`).
 */
import {
  itemsFromLegacy,
  listsFromItems,
  parseItemsColumn,
  type PlaylistItem,
} from '../src/playlists/items.ts';

/** Linha de `user_playlists` que o script lê. */
export interface PlaylistRow {
  user_id: string;
  id: string;
  items: string | null;
  pdf_ids: string | null;
  audio_ids: string | null;
  version: number;
}

/** O que muda numa linha. */
export interface RowRewrite {
  userId: string;
  id: string;
  version: number;
  items: PlaylistItem[];
  pdfIds: string[];
  replaced: Array<[string, string]>;
  unknown: string[];
}

export interface MigrationReport {
  generatedAt: string;
  rowsScanned: number;
  rowsChanged: number;
  legacyIds: number;
  resolvedIds: number;
  unknownIds: string[];
  /** Linhas planeadas cuja guarda `AND version = N` rejeitou a escrita (§6.3). */
  skipped: Array<{ userId: string; id: string }>;
  rows: Array<{
    userId: string;
    id: string;
    replaced: Array<[string, string]>;
    unknown: string[];
    skipped: boolean;
  }>;
  /** `final_bookmark` do import remoto (`wrangler d1 … --file`), quando houve. */
  finalBookmark?: string;
}

const strictUtf8 = new TextDecoder('utf-8', { fatal: true });
const PRAISES_MARKER = '/assets/praises/';
const PRAISES_R2_PREFIX = 'assets/praises/';

/** Opções da CLI já validadas — ver [parseArgs]. */
export interface CliOptions {
  dryRun: boolean;
  target: '--local' | '--remote';
}

const KNOWN_FLAGS: ReadonlySet<string> = new Set(['--dry-run', '--local', '--remote']);

/**
 * Analisa `process.argv.slice(2)`.
 *
 * Rejeita qualquer flag desconhecida — um typo como `--dryrun` não pode virar
 * escrita real, silenciosamente ignorado. Exige exatamente um de
 * `--local`/`--remote`, **sem default**: um default de `--remote` faria um
 * `--dry-run` esquecido do `--local` escrever direto na produção.
 */
export function parseArgs(argv: readonly string[]): CliOptions {
  for (const arg of argv) {
    if (!KNOWN_FLAGS.has(arg)) throw new Error(`flag desconhecida: ${arg}`);
  }
  const hasLocal = argv.includes('--local');
  const hasRemote = argv.includes('--remote');
  if (hasLocal === hasRemote) {
    throw new Error('use exatamente um de --local ou --remote');
  }
  return { dryRun: argv.includes('--dry-run'), target: hasLocal ? '--local' : '--remote' };
}

/** Path que [id] codifica (base64url UTF-8), ou `null`. Espelha `PdfPathNormalizer.getPdfRelPath`. */
export function decodePdfId(id: string): string | null {
  if (id.length === 0 || !/^[A-Za-z0-9_-]+$/.test(id)) return null;
  try {
    return strictUtf8.decode(Buffer.from(id, 'base64url'));
  } catch {
    return null;
  }
}

/** Espelha `encodePdfId`: base64url do UTF-8, sem padding. */
export function encodePdfId(path: string): string {
  return Buffer.from(path, 'utf8').toString('base64url');
}

/** Espelha `isLegacyPdfId`: PDF cujo path não está em `assets/praises/`. */
export function isLegacyPdfId(id: string): boolean {
  const path = decodePdfId(id);
  if (path === null) return false;
  return path.toLowerCase().endsWith('.pdf') && !path.startsWith(PRAISES_R2_PREFIX);
}

/** Corta [url] no primeiro `?` ou `#`, o que vier primeiro. Espelha `_stripQueryAndFragment`. */
function stripQueryAndFragment(url: string): string {
  let end = url.length;
  const queryIndex = url.indexOf('?');
  if (queryIndex !== -1 && queryIndex < end) end = queryIndex;
  const fragmentIndex = url.indexOf('#');
  if (fragmentIndex !== -1 && fragmentIndex < end) end = fragmentIndex;
  return url.substring(0, end);
}

/**
 * Espelha `coldigomPdfIdFromAssetUrl`: `encodePdfId(r2Key)` lido da URL.
 *
 * Query string (`?…`) e fragment (`#…`) são descartados antes de procurar o
 * path — não fazem parte do `r2Key` (ruling do pre-flight 6.7).
 */
export function coldigomPdfIdFromAssetUrl(url: string): string | null {
  const withoutQueryAndFragment = stripQueryAndFragment(url);
  const index = withoutQueryAndFragment.indexOf(PRAISES_MARKER);
  if (index < 0) return null;
  const r2Key = withoutQueryAndFragment.substring(index + 1);
  const rest = r2Key.substring(PRAISES_R2_PREFIX.length);
  if (rest.length === 0 || !rest.includes('/')) return null;
  try {
    return encodePdfId(decodeURIComponent(r2Key));
  } catch {
    return null;
  }
}

/** Legado → id coldigom a partir do `items` de uma resposta do crosswalk. */
export function resolvedFromCrosswalk(items: unknown): Map<string, string> {
  const resolved = new Map<string, string>();
  if (typeof items !== 'object' || items === null) return resolved;
  for (const [pdfId, value] of Object.entries(items as Record<string, unknown>)) {
    if (typeof value !== 'object' || value === null) continue;
    const url = (value as { url?: unknown }).url;
    if (typeof url !== 'string') continue;
    const coldigomId = coldigomPdfIdFromAssetUrl(url);
    if (coldigomId !== null) resolved.set(pdfId, coldigomId);
  }
  return resolved;
}

function parseIdList(text: string | null): string[] {
  if (!text) return [];
  try {
    const parsed: unknown = JSON.parse(text);
    return Array.isArray(parsed)
      ? parsed.filter((x): x is string => typeof x === 'string')
      : [];
  } catch {
    return [];
  }
}

/**
 * Ordem única da linha: `items`; linhas anteriores à migration 0008
 * (`items = '[]'`) derivam das duas colunas v1, como o `rowToJson` do handler.
 */
export function rowItems(row: PlaylistRow): PlaylistItem[] {
  const stored = parseItemsColumn(row.items);
  if (stored.length > 0) return stored;
  return itemsFromLegacy(parseIdList(row.pdf_ids), parseIdList(row.audio_ids));
}

/** Ids legados de todas as [rows] (áudio nunca é legado). */
export function collectLegacyIds(rows: PlaylistRow[]): Set<string> {
  const ids = new Set<string>();
  for (const row of rows) {
    for (const item of rowItems(row)) {
      if (item.kind !== 'audio' && isLegacyPdfId(item.id)) ids.add(item.id);
    }
  }
  return ids;
}

/**
 * [row] com os legados resolvidos trocados (kind e ordem mantidos), ou `null`
 * se nenhum legado desta linha foi resolvido. Desconhecidos ficam — o app
 * mostra-os como indisponíveis.
 */
export function rewriteRow(
  row: PlaylistRow,
  resolved: ReadonlyMap<string, string>,
): RowRewrite | null {
  const replaced: Array<[string, string]> = [];
  const unknown: string[] = [];
  const items = rowItems(row).map((item): PlaylistItem => {
    if (item.kind === 'audio' || !isLegacyPdfId(item.id)) return item;
    const mapped = resolved.get(item.id);
    if (mapped === undefined) {
      unknown.push(item.id);
      return item;
    }
    replaced.push([item.id, mapped]);
    return { id: mapped, kind: item.kind };
  });
  if (replaced.length === 0) return null;
  return {
    userId: row.user_id,
    id: row.id,
    version: row.version,
    items,
    pdfIds: listsFromItems(items).pdfIds,
    replaced,
    unknown,
  };
}

/** Aspa e escapa [value] para embutir num literal SQL. */
export function sqlString(value: string): string {
  return `'${value.replaceAll("'", "''")}'`;
}

/** Chaves por SELECT de releitura — bem abaixo do limite de statement do D1. */
export const SELECT_KEYS_BATCH = 200;

/**
 * SELECTs que relêem só as linhas de [keys] (a conferência pós-escrita,
 * `detectSkipped`), em lotes de [batchSize] chaves: com ~1200 linhas
 * reescritas um `OR` único passaria do tamanho máximo de statement do D1.
 */
export function selectRowsByKeysSql(
  keys: ReadonlyArray<{ userId: string; id: string }>,
  batchSize: number = SELECT_KEYS_BATCH,
): string[] {
  const statements: string[] = [];
  for (let start = 0; start < keys.length; start += batchSize) {
    const where = keys
      .slice(start, start + batchSize)
      .map((k) => `(user_id = ${sqlString(k.userId)} AND id = ${sqlString(k.id)})`)
      .join(' OR ');
    statements.push(
      'SELECT user_id, id, items, pdf_ids, audio_ids, version FROM user_playlists ' +
        `WHERE deleted_at IS NULL AND (${where})`,
    );
  }
  return statements;
}

function rowKey(userId: string, id: string): string {
  return `${userId}\u0000${id}`;
}

/**
 * [rewrites] cuja guarda `AND version = N` rejeitou a escrita: lidas de novo
 * depois do UPDATE ([afterRows]), ainda têm algum legado que [resolved]
 * resolveria — outra escrita concorrente mudou a `version` entretanto, e a
 * linha fica para a próxima passada. Uma linha ausente de [afterRows] (ex.:
 * soft delete concorrente) não conta como pulada — já não importa a ninguém.
 */
export function detectSkipped(
  rewrites: RowRewrite[],
  afterRows: PlaylistRow[],
  resolved: ReadonlyMap<string, string>,
): RowRewrite[] {
  const after = new Map(afterRows.map((row) => [rowKey(row.user_id, row.id), row]));
  return rewrites.filter((r) => {
    const row = after.get(rowKey(r.userId, r.id));
    return row !== undefined && rewriteRow(row, resolved) !== null;
  });
}

/**
 * UPDATE de uma linha: `items` e `pdf_ids` novos, `version + 1` e
 * **`updated_at` intacto** (spec §6.3, facto M10) — um cliente sem push
 * pendente puxa a linha (mesmo `updatedAt`, `version` maior) e ninguém leva
 * 409 nem cópia de conflito. `AND version = N` não pisa uma escrita que
 * chegou entretanto: essa linha fica para uma segunda passada.
 */
export function updateSql(rewrite: RowRewrite): string {
  return (
    `UPDATE user_playlists SET items = ${sqlString(JSON.stringify(rewrite.items))}, ` +
    `pdf_ids = ${sqlString(JSON.stringify(rewrite.pdfIds))}, ` +
    `version = version + 1 ` +
    `WHERE user_id = ${sqlString(rewrite.userId)} AND id = ${sqlString(rewrite.id)} ` +
    `AND version = ${Math.trunc(rewrite.version)};`
  );
}

/**
 * [skipped] (default `[]`) são as [rewrites] que [detectSkipped] apontou como
 * rejeitadas pela guarda de versão — chamado antes da escrita (planeado, sem
 * `skipped`) e de novo depois (final, com `skipped`); ver o runbook do README.
 */
export function buildReport(
  rows: PlaylistRow[],
  rewrites: RowRewrite[],
  legacy: ReadonlySet<string>,
  resolved: ReadonlyMap<string, string>,
  now: Date = new Date(),
  skipped: RowRewrite[] = [],
): MigrationReport {
  const all = [...legacy];
  const skippedKeys = new Set(skipped.map((r) => rowKey(r.userId, r.id)));
  return {
    generatedAt: now.toISOString(),
    rowsScanned: rows.length,
    rowsChanged: rewrites.length - skipped.length,
    legacyIds: legacy.size,
    resolvedIds: all.filter((id) => resolved.has(id)).length,
    unknownIds: all.filter((id) => !resolved.has(id)).sort(),
    skipped: skipped.map((r) => ({ userId: r.userId, id: r.id })),
    rows: rewrites.map((r) => ({
      userId: r.userId,
      id: r.id,
      replaced: r.replaced,
      unknown: r.unknown,
      skipped: skippedKeys.has(rowKey(r.userId, r.id)),
    })),
  };
}

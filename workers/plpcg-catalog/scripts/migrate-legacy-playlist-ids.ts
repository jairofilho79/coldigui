/**
 * Migração única dos ids legados das playlists no D1 (spec 2026-09-23 §6.3).
 *
 * Corre **depois** do deploy do app novo (senão um cliente antigo repõe ids
 * legados logo a seguir) e só com pedido do dono. Ver o runbook no README.
 *
 *   COLDIGOM_API_BASE_URL=https://coldigom-api.jairofilho79.workers.dev \
 *     npm run migrate:legacy-ids -- --dry-run --local
 */
import { execFileSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

import {
  buildReport,
  collectLegacyIds,
  detectSkipped,
  parseArgs,
  resolvedFromCrosswalk,
  rewriteRow,
  selectRowsByKeysSql,
  updateSql,
  type MigrationReport,
  type PlaylistRow,
  type RowRewrite,
} from './legacy_playlist_ids.ts';

const DATABASE = 'plpcg-catalog';
const CROSSWALK_BATCH = 500;

function d1(target: string, extra: string[]): unknown {
  const out = execFileSync(
    'npx',
    ['wrangler', 'd1', 'execute', DATABASE, target, '--json', ...extra],
    { encoding: 'utf8', maxBuffer: 512 * 1024 * 1024 },
  );
  return JSON.parse(out);
}

function runSelect(target: string, sql: string): PlaylistRow[] {
  const parsed = d1(target, ['--command', sql]);
  const first = Array.isArray(parsed) ? parsed[0] : parsed;
  const results = (first as { results?: unknown } | undefined)?.results;
  if (!Array.isArray(results)) throw new Error('resposta inesperada do wrangler');
  return results as PlaylistRow[];
}

function selectRows(target: string): PlaylistRow[] {
  return runSelect(
    target,
    'SELECT user_id, id, items, pdf_ids, audio_ids, version FROM user_playlists WHERE deleted_at IS NULL',
  );
}

/** Relê só as linhas de [keys] — a conferência pós-escrita (`detectSkipped`). */
function selectRowsByKeys(
  target: string,
  keys: Array<{ userId: string; id: string }>,
): PlaylistRow[] {
  return selectRowsByKeysSql(keys).flatMap((sql) => runSelect(target, sql));
}

/**
 * Executa o `.sql` de [sqlPath] contra [target]. Devolve o `final_bookmark`
 * quando a resposta do wrangler traz um (import `--remote` via `--file`) —
 * `--local` nunca traz.
 */
function importFile(target: string, sqlPath: string): string | undefined {
  const parsed = d1(target, ['--file', sqlPath]);
  const first = Array.isArray(parsed) ? parsed[0] : parsed;
  const bookmark = (first as { finalBookmark?: unknown } | undefined)?.finalBookmark;
  return typeof bookmark === 'string' ? bookmark : undefined;
}

async function resolve(base: string, ids: string[]): Promise<Map<string, string>> {
  const resolved = new Map<string, string>();
  for (let start = 0; start < ids.length; start += CROSSWALK_BATCH) {
    const batch = ids.slice(start, start + CROSSWALK_BATCH);
    const asked = new Set(batch);
    const response = await fetch(`${base}/api/plpcg/crosswalk`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ pdfIds: batch }),
    });
    if (!response.ok) throw new Error(`crosswalk respondeu ${response.status}`);
    const body = (await response.json()) as { items?: unknown };
    // Um `200` cujo corpo não traz um `items` mapa válido (ausente, `null` ou
    // de outro tipo) também aborta — nunca é tratado como "todos
    // desconhecidos" (mesma regra de `resolveLegacyPdfIds` no app).
    if (typeof body.items !== 'object' || body.items === null || Array.isArray(body.items)) {
      throw new Error('crosswalk respondeu 200 sem `items` mapa válido');
    }
    for (const [legacy, coldigom] of resolvedFromCrosswalk(body.items)) {
      if (asked.has(legacy)) resolved.set(legacy, coldigom);
    }
  }
  return resolved;
}

async function main(): Promise<void> {
  const { dryRun, target } = parseArgs(process.argv.slice(2));
  const base = (process.env.COLDIGOM_API_BASE_URL ?? '').replace(/\/$/, '');
  if (!base) throw new Error('defina COLDIGOM_API_BASE_URL');

  const rows = selectRows(target);
  const legacy = collectLegacyIds(rows);
  const resolved = await resolve(base, [...legacy]);
  const rewrites = rows
    .map((row) => rewriteRow(row, resolved))
    .filter((r): r is RowRewrite => r !== null);
  const now = new Date();
  const plannedReport = buildReport(rows, rewrites, legacy, resolved, now);

  for (const r of rewrites) {
    console.log(`${r.userId}/${r.id} (v${r.version} → v${r.version + 1}):`);
    for (const [from, to] of r.replaced) console.log(`  - ${from}\n  + ${to}`);
    for (const id of r.unknown) console.log(`  ? ${id} (desconhecido, fica)`);
  }
  console.log(
    `${plannedReport.rowsScanned} linhas lidas; ${plannedReport.rowsChanged} a reescrever; ` +
      `${plannedReport.legacyIds} ids legados: ${plannedReport.resolvedIds} resolvidos, ` +
      `${plannedReport.unknownIds.length} desconhecidos.`,
  );
  if (dryRun) {
    console.log('--dry-run: nada gravado.');
    return;
  }

  const outDir = join(import.meta.dirname, 'out');
  mkdirSync(outDir, { recursive: true });
  const stamp = plannedReport.generatedAt.replaceAll(':', '-');
  const reportPath = join(outDir, `migrate-legacy-playlist-ids-${stamp}.json`);

  // Grava o relatório PLANEADO antes de tocar no D1: se o `wrangler --file`
  // escrever com sucesso mas algo falhar depois (ex.: stdout inesperado ao
  // relê a linhas), ainda sobra um relatório em disco — não fica preso só no
  // stdout que já rolou.
  writeFileSync(reportPath, JSON.stringify(plannedReport, null, 2) + '\n');

  const sqlPath = join(outDir, `migrate-legacy-playlist-ids-${stamp}.sql`);
  writeFileSync(sqlPath, rewrites.map(updateSql).join('\n') + '\n');

  let finalBookmark: string | undefined;
  let skipped: RowRewrite[] = [];
  if (rewrites.length > 0) {
    finalBookmark = importFile(target, sqlPath);
    const afterRows = selectRowsByKeys(
      target,
      rewrites.map((r) => ({ userId: r.userId, id: r.id })),
    );
    skipped = detectSkipped(rewrites, afterRows, resolved);
  }

  const finalReport: MigrationReport = {
    ...buildReport(rows, rewrites, legacy, resolved, now, skipped),
    ...(finalBookmark !== undefined ? { finalBookmark } : {}),
  };
  writeFileSync(reportPath, JSON.stringify(finalReport, null, 2) + '\n');
  console.log(`Gravado. SQL: ${sqlPath}\nRelatório: ${reportPath}`);
  if (skipped.length > 0) {
    console.log(
      `${skipped.length} linha(s) não gravada(s) (a versão mudou entretanto) — rode de novo.`,
    );
  }
}

main().catch((error: unknown) => {
  console.error(error);
  process.exit(1);
});

/**
 * Migração única dos ids legados das playlists no D1 (spec 2026-09-23 §6.3).
 *
 * Corre **depois** do deploy do app novo (senão um cliente antigo repõe ids
 * legados logo a seguir) e só com pedido do dono. Ver o runbook no README.
 *
 *   COLDIGOM_API_BASE_URL=https://coldigom-api.jairofilho79.workers.dev \
 *     npm run migrate:legacy-ids -- --dry-run [--local]
 */
import { execFileSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

import {
  buildReport,
  collectLegacyIds,
  resolvedFromCrosswalk,
  rewriteRow,
  updateSql,
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

function selectRows(target: string): PlaylistRow[] {
  const parsed = d1(target, [
    '--command',
    'SELECT user_id, id, items, pdf_ids, audio_ids, version FROM user_playlists WHERE deleted_at IS NULL',
  ]);
  const first = Array.isArray(parsed) ? parsed[0] : parsed;
  const results = (first as { results?: unknown } | undefined)?.results;
  if (!Array.isArray(results)) throw new Error('resposta inesperada do wrangler');
  return results as PlaylistRow[];
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
  const args = new Set(process.argv.slice(2));
  const dryRun = args.has('--dry-run');
  const target = args.has('--local') ? '--local' : '--remote';
  const base = (process.env.COLDIGOM_API_BASE_URL ?? '').replace(/\/$/, '');
  if (!base) throw new Error('defina COLDIGOM_API_BASE_URL');

  const rows = selectRows(target);
  const legacy = collectLegacyIds(rows);
  const resolved = await resolve(base, [...legacy]);
  const rewrites = rows
    .map((row) => rewriteRow(row, resolved))
    .filter((r): r is RowRewrite => r !== null);
  const report = buildReport(rows, rewrites, legacy, resolved);

  for (const r of rewrites) {
    console.log(`${r.userId}/${r.id} (v${r.version} → v${r.version + 1}):`);
    for (const [from, to] of r.replaced) console.log(`  - ${from}\n  + ${to}`);
    for (const id of r.unknown) console.log(`  ? ${id} (desconhecido, fica)`);
  }
  console.log(
    `${report.rowsScanned} linhas lidas; ${report.rowsChanged} a reescrever; ` +
      `${report.legacyIds} ids legados: ${report.resolvedIds} resolvidos, ` +
      `${report.unknownIds.length} desconhecidos.`,
  );
  if (dryRun) {
    console.log('--dry-run: nada gravado.');
    return;
  }

  const outDir = join(import.meta.dirname, 'out');
  mkdirSync(outDir, { recursive: true });
  const stamp = report.generatedAt.replaceAll(':', '-');
  const sqlPath = join(outDir, `migrate-legacy-playlist-ids-${stamp}.sql`);
  writeFileSync(sqlPath, rewrites.map(updateSql).join('\n') + '\n');
  if (rewrites.length > 0) d1(target, ['--file', sqlPath]);
  const reportPath = join(outDir, `migrate-legacy-playlist-ids-${stamp}.json`);
  writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n');
  console.log(`Gravado. SQL: ${sqlPath}\nRelatório: ${reportPath}`);
}

main().catch((error: unknown) => {
  console.error(error);
  process.exit(1);
});

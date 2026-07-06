#!/usr/bin/env bash
# Purga cache CDN de v2.plpcg.com (zone plpcg.com).
#
# Necessário após deploys quando /*.js tinha Cache-Control: immutable —
# o domínio customizado servia bundle antigo enquanto previews *.pages.dev ficavam corretos.
#
# Requer token com permissão "Cache Purge" na zone plpcg.com:
#   export CLOUDFLARE_API_TOKEN="..."
#   ./scripts/purge_v2_cache.sh
set -euo pipefail

ZONE_ID="${CLOUDFLARE_ZONE_ID:-955b720a65982ace96b20108feb35d4f}"
HOST="${PLPCG_WEB_HOST:-v2.plpcg.com}"

if [[ -z "${CLOUDFLARE_API_TOKEN:-}" ]]; then
  echo "Defina CLOUDFLARE_API_TOKEN (Cache Purge na zone plpcg.com)." >&2
  echo "Ou purge manual: Cloudflare Dashboard → plpcg.com → Caching → Purge Cache → Custom Purge → Host: ${HOST}" >&2
  exit 1
fi

echo "==> Purging CDN cache for host ${HOST} (zone ${ZONE_ID})..."
curl -sf -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/purge_cache" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"hosts\":[\"${HOST}\"]}"

echo
echo "OK: cache purged for ${HOST}"

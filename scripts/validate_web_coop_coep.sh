#!/usr/bin/env bash
# Valida cabeçalhos COOP/COEP em deploy web (Fase D — WEB_PERFORMANCE_AND_LOADING.md).
#
# Uso:
#   ./scripts/validate_web_coop_coep.sh https://v2.plpcg.com
#   ./scripts/validate_web_coop_coep.sh https://<hash>.plpcg-v2.pages.dev
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Uso: $0 <base-url> [<base-url> ...]" >&2
  echo "Ex.: $0 https://v2.plpcg.com" >&2
  exit 2
fi

failures=0

header_value() {
  local url="$1"
  local name="$2"
  curl -sI --max-time 30 "$url" | tr -d '\r' | awk -v n="$(echo "$name" | tr '[:upper:]' '[:lower:]')" '
    BEGIN { IGNORECASE = 1 }
    $1 ~ /^[^:]+:$/ {
      key = tolower(substr($1, 1, length($1) - 1))
      if (key == n) {
        val = $2
        for (i = 3; i <= NF; i++) val = val " " $i
        print val
        exit
      }
    }
  '
}

http_status() {
  curl -sI --max-time 30 -o /dev/null -w '%{http_code}' "$1"
}

check_url() {
  local base="${1%/}"
  echo "==> Validando $base"

  local coop coep sw_cache wasm_status
  coop="$(header_value "$base/" "cross-origin-opener-policy")"
  coep="$(header_value "$base/" "cross-origin-embedder-policy")"
  sw_cache="$(header_value "$base/flutter_service_worker.js" "cache-control")"
  wasm_status="$(http_status "$base/isar_plus.wasm")"

  if [[ "$coop" == "same-origin" || "$coop" == "same-origin-allow-popups" ]]; then
    echo "  OK  COOP: $coop"
  else
    echo "  FAIL COOP: esperado 'same-origin' ou 'same-origin-allow-popups', obtido '${coop:-<ausente>}'" >&2
    failures=$((failures + 1))
  fi

  if [[ "$coep" == "require-corp" ]]; then
    echo "  OK  COEP: $coep"
  else
    echo "  FAIL COEP: esperado 'require-corp', obtido '${coep:-<ausente>}'" >&2
    failures=$((failures + 1))
  fi

  if [[ "$sw_cache" == *"no-cache"* ]]; then
    echo "  OK  flutter_service_worker.js Cache-Control: $sw_cache"
  else
    echo "  FAIL flutter_service_worker.js Cache-Control: esperado 'no-cache', obtido '${sw_cache:-<ausente>}'" >&2
    failures=$((failures + 1))
  fi

  if [[ "$wasm_status" == "200" ]]; then
    echo "  OK  isar_plus.wasm HTTP $wasm_status"
  else
    echo "  FAIL isar_plus.wasm HTTP $wasm_status (esperado 200)" >&2
    failures=$((failures + 1))
  fi

  echo
}

for url in "$@"; do
  check_url "$url"
done

if [[ "$failures" -gt 0 ]]; then
  echo "Validação falhou: $failures problema(s)." >&2
  exit 1
fi

echo "Validação COOP/COEP concluída com sucesso."

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

  local coop coep sw_cache wasm_status own_sw_cache own_sw_type
  coop="$(header_value "$base/" "cross-origin-opener-policy")"
  coep="$(header_value "$base/" "cross-origin-embedder-policy")"
  sw_cache="$(header_value "$base/flutter_service_worker.js" "cache-control")"
  wasm_status="$(http_status "$base/isar_plus.wasm")"
  own_sw_cache="$(header_value "$base/sw.js" "cache-control")"
  own_sw_type="$(header_value "$base/sw.js" "content-type")"

  if [[ "$coop" == "same-origin" ]]; then
    echo "  OK  COOP: $coop"
  else
    echo "  FAIL COOP: esperado 'same-origin' (login web é por redirect, sem popup), obtido '${coop:-<ausente>}'" >&2
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

  # sw.js próprio: tem de ser JS (não o index.html do fallback SPA) e no-cache;
  # o ?v=<tag> protege o registo, mas um objeto preso na zone atrasaria o WARM.
  if [[ "$own_sw_type" == *"javascript"* && "$own_sw_cache" == *"no-cache"* ]]; then
    echo "  OK  sw.js: $own_sw_type; Cache-Control: $own_sw_cache"
  else
    echo "  FAIL sw.js: esperado javascript + no-cache, obtido '${own_sw_type:-<ausente>}' / '${own_sw_cache:-<ausente>}'" >&2
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
